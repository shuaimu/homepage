
# Query Optimization (System R)

Paper: Selinger, Astrahan, Chamberlin, Lorie, and Price, *Access Path Selection in a Relational Database Management System* (SIGMOD 1979).

* So far the storage engine gave us Get / Put / scan and indexes (Postgres, LSM, B-trees)
* SQL says *what* rows you want, not *how* to get them
* Today: how the DBMS picks the *how*. We will reinvent the System R optimizer piece by piece
* Optional companion: Leis et al., *How Good Are Query Optimizers, Really?* (VLDB 2015) — what held up after 36 years

## The job

* Paper's running example: name, salary, job title and department of every clerk in a Denver department

```
SELECT NAME, TITLE, SAL, DNAME
FROM   EMP, DEPT, JOB
WHERE  TITLE = 'CLERK'
  AND  LOC = 'DENVER'
  AND  EMP.DNO = DEPT.DNO
  AND  EMP.JOB = JOB.JOB
```

* Two local predicates (`TITLE` on JOB, `LOC` on DEPT), two join predicates; nothing filters EMP, the biggest table
* The user did not say:
  * the order: which table to read first, and in what order to join the rest
  * the access: scan the whole table, or go through an index, and which one
  * the join: how to join two tables
  * sorting: whether to sort rows along the way
* Each can change the running time by orders of magnitude (more than 100× for the join order alone); none changes the answer
* Goal: a plan close to the best, not *the* best (the paper is explicit that estimates are rough), cheap enough to find at compile time and amortize over many runs

## The tables

* The paper's Figure 1 has a few rows per table and no sizes. These sizes are ours; every number below comes from them

```
EMP (NAME, DNO, JOB, SAL)    10,000 rows, 20 to a page: 500 pages, stored in DNO order
  index on DNO    clustered              100 values, 100 rows each     50 pages
  index on JOB    non-clustered          50 values, 200 rows each      50 pages
  index on SAL    non-clustered          2,000 values, 5,000 to 25,000   40 pages

DEPT (DNO, DNAME, LOC)       100 rows on 5 pages, stored in DNO order
  index on DNO    clustered, unique      100 values, 1 row each         2 pages
  index on LOC    non-clustered          10 cities, 10 rows each        2 pages

JOB (JOB, TITLE)             50 rows on 2 pages, stored in JOB order
  index on JOB    clustered, unique      50 values, 1 row each          1 page
  index on TITLE  non-clustered, unique  50 titles, 1 row each          1 page
```

* Stored in DNO order: EMP's rows were inserted sorted by DNO and kept that way, so a department's 100 employees sit together on 5 pages
* An index lists rows in its own column's order, and is small: EMP's are 40 to 50 pages against its 500
  * *clustered*: the table is stored in the same order (so at most one per table), and the rows it finds sit together. `DNO = 50`: 100 rows on 5 adjacent pages
  * *non-clustered*: the rows it finds are scattered. `JOB = 5`: 200 rows, about a page each
  * *unique*: at most one row per key
* The answer: 200 clerks (1 title in 50), 1 in 10 of them in Denver, about 20 rows

## From text to a tree

* Parse: a query block = SELECT list + FROM list + WHERE tree; a nested query is another block (later)
* Catalog lookup: do the tables and columns exist, what types; also the statistics (below)
* Relational algebra: the tree the optimizer works on, read bottom-up from stored tables to the answer
  * `σ` select: keep the rows where a predicate holds. `π` project: keep only these columns
  * `×` cross product: every row with every row. EMP × DEPT is 1,000,000 rows
  * `⋈` join: a `×` with a `σ` on the join column. EMP ⋈ DEPT on DNO keeps 10,000
  * the signs fix what the answer is, not how to compute it (Codd's algebra, 1970; the paper itself works in query blocks)
* Rewrite: System R converts WHERE to conjunctive normal form and pushes each part to the tables it names (strawman 1's fix)
  * later systems also expand views and flatten or unnest subqueries; System R keeps each subquery its own block
* Physical plan: each node becomes an operator with an algorithm (segment scan, index scan, nested loop, merge)
  * everything downstream is: pick an *equivalent* tree, then an algorithm for each node
* Code generation: System R compiled to machine code (Postgres interprets); the plan is stored and rerun, so optimization is amortized

## Strawman 1: run the tree as parsed

* The literal reading: cross product first, filter last

```
        π NAME,TITLE,SAL,DNAME
              |
        σ TITLE='CLERK' ∧ LOC='DENVER' ∧ EMP.DNO=DEPT.DNO ∧ EMP.JOB=JOB.JOB
              |
           × (EMP, DEPT, JOB)
```

* 10,000 × 100 × 50 = 50 M intermediate rows, about 5 M page reads and writes, to return 20 rows from tables of 507 pages
* Fix: pushdown. Write WHERE in conjunctive normal form; each conjunct is a *boolean factor* (it can itself be an OR)
  * every output row satisfies every boolean factor, so each can be applied as early as you like
  * `σ TITLE='CLERK'` moves onto JOB, `σ LOC='DENVER'` onto DEPT
  * a `σ` on the join column over a `×` is a `⋈`; `π` is applied on the way out

```
                 ⋈ EMP.JOB=JOB.JOB
                /               \
        ⋈ EMP.DNO=DEPT.DNO    σ TITLE='CLERK'
        /             \             JOB
      EMP        σ LOC='DENVER'
  (no filter)        DEPT
```

* Rows going up: EMP 10,000, DEPT 10, JOB 1; the joins keep 1,000, then 20
* Rewriting removes the obviously stupid plans, not the choice among the rest: four join orders without a cross product, four ways to read EMP, two join methods

## Strawman 2: fixed rules

* Replace the search with a rule book. Each rule is right on plenty of queries; in 1979 rule books were the serious alternative
* Why they sound right: an index skips pages; FROM order needs no search, and people tend to name first the table they filter
* Rough counts: a disk read brings a whole page. A scan reads EMP in 500 reads; a clustered index finds rows 20 to a read, a non-clustered one about a read per row
* Rule 1: always use an index if one exists
  * Makes sense: `SELECT NAME FROM EMP WHERE DNO = 50`, 100 rows stored together, about 5 reads against 500. Few scattered rows win too: `JOB = 5`, about 200
  * Breaks: `WHERE SAL > 20000` keeps 2,500 scattered rows, about 2,500 reads against 500. The scan wins 5×
  * The index pays per row it finds, the scan per page: past about 500 scattered rows, scan
* Rule 2: always join in FROM order, as a chain of *lookups*: one row of the first table, then its matches in the second
  * Makes sense: `SELECT DNAME, NAME FROM DEPT, EMP WHERE DEPT.LOC = 'DENVER' AND EMP.DNO = DEPT.DNO`
    * DEPT first keeps 10 rows: 10 lookups into EMP. EMP first: 10,000 lookups into DEPT
  * Breaks: `SELECT DNAME, NAME FROM EMP, DEPT WHERE EMP.SAL > 20000 AND EMP.DNO = DEPT.DNO`
    * EMP first still keeps 2,500 rows: 2,500 lookups. DEPT first: 100
  * "Fewest rows first" is just another rule: lookups differ in price (one into EMP fetches a department, one into DEPT a single row), and on ours it starts from JOB, 1 row, which loses too (230 against 163, below)
  * The paper's `FROM EMP, DEPT, JOB` starts with EMP, the one table nothing filters
* Lesson: each rule is right on some queries and wrong on others, and only the data says which. The rule that survives is strawman 1's fix: filters as early as possible
* So: estimate each candidate's cost, pick the cheapest. Three things to invent: a cost measure, statistics about the data, and a search that does not enumerate every candidate

## Cost: what are we minimizing

```
COST ≈ PAGE FETCHES
```

* A page fetch is one page read from disk, data or index. Why pages:
  * disk is slow: a page read takes milliseconds, the CPU work on its rows microseconds
  * disk moves whole pages: one row costs as much as the page it sits on
  * so count pages: close enough to rank plans
* The same unit strawman 2 counted as reads, now made exact. Rows matter only through the pages they touch; how many, for a scan and for each kind of index, is the access-path section (below)
* The `≈`: the paper adds a CPU term, `COST = PAGE FETCHES + W × RSI CALLS` (rows passed up from storage, times a machine weight). `W` gets no value, and on one table every path returns the same rows, so we drop it
* Single-user total resource use, not latency; no parallelism, memory pressure or network. Later optimizers widen this (Spanner: network, shard fan-out)

## Statistics

* Per table `T`: `rows(T)`, and `pages(T)`, the pages a scan reads
* Per index `I`: `distinct(I)`, its distinct keys (`distinct(col)` for one column), and `index_pages(I)`
* No histogram, no sample: these four numbers are all System R knows. An un-indexed column has no `distinct`
* The paper's names: `NCARD` = rows, `TCARD` = pages, `ICARD` = distinct, `NINDX` = index_pages; below, `QCARD` = result_rows
* Refreshed by a manual UPDATE STATISTICS (Postgres: `ANALYZE`), not on every write, which would make the catalog a hot lock
  * so costs come from numbers that may be stale, and the optimizer cannot tell
* Sorting is ours: the paper prices no sort, so sorting `Q` rows here is one pass out and one back at 20 rows a page, `2 × ceil(Q / 20)` pages

## Selectivity: how many rows survive a predicate

* Each boolean factor gets a selectivity factor `F`, the expected fraction of rows that pass. Paper's Table 1, abridged:

```
col = v            1/distinct(col)     if indexed, else 1/10
col1 = col2        1/max(distinct(col1), distinct(col2)) if both indexed,
                   1/distinct of the indexed one if one is, else 1/10
col > v            (high − v)/(high − low)  if numeric, else 1/3
col BETWEEN a,b    (b − a)/(high − low)     if numeric, else 1/4
col IN (list)      n × F(col = v), at most 1/2
p1 OR p2           F1 + F2 − F1·F2
p1 AND p2          F1 · F2
NOT p              1 − F
```

* `high`, `low`: the index's largest and smallest key. "Numeric" also needs the value known when the plan is chosen; a host variable is not
* Why 1/10 without an index: "a lack of statistics implies that the relation is small, so an arbitrary factor is chosen"
  * the constants have "no significance" beyond their order: equality smallest, a range 1/3 because "few queries use predicates that are satisfied by more than half the tuples", BETWEEN in between
  * Postgres keeps statistics on every column; its rare defaults are 1/200 for equality, 1/3 for a range
* Result size of a block: `result_rows = Π rows(T) × Π F(boolean factors)`. On our query:

```
EMP × DEPT × JOB     10,000 × 100 × 50                50,000,000
TITLE = 'CLERK'      × 1/distinct(TITLE) = 1/50        1,000,000
LOC = 'DENVER'       × 1/distinct(LOC)   = 1/10          100,000
EMP.DNO = DEPT.DNO   × 1/max(100, 100)   = 1/100           1,000
EMP.JOB = JOB.JOB    × 1/max(50, 50)     = 1/50               20   the answer
```

* Two-table results, the same product: EMP and DEPT `10,000 × 10 × 1/100 = 1,000`; EMP and JOB `10,000 × 1 × 1/50 = 200`
* The max rule assumes every key on the side with fewer distinct values finds a match
* A range, on rule 1's query: `SAL > 20000`, `F = (25,000 − 20,000) / (25,000 − 5,000) = 1/4`, 2,500 rows. A high key, a low key and a straight line between: the closest thing in 1979 to a histogram
* Read the assumptions: uniform key values, independent columns (`AND` multiplies), magic constants where there is no index
* `LOC='DENVER'` and `ZIP LIKE '802%'` are not independent (DNO 57 and the ZIPs are ours):

```
DNO   LOC       ZIP
50    DENVER    80202
51    BOULDER   80301
52    DENVER    80216
57    DENVER    80237
```

* Every Denver department has an 802 ZIP: multiplied, `100 × 1/10 × 1/10` = 1 department; actual: 10
  * real predicates tend to be positively correlated, so multiplying underestimates
* Histograms are the eventual fix, not in this paper. This is the piece that aged worst; hold that thought for the end

## What is left: one table, two tables, three

* We can now price a plan. What is left is choosing one, a table at a time, each part reusing the one before
  * one table: the cheapest way to read it, a scan or an index
  * two tables: the cheapest way to join them, pricing the ways to read each
  * three or more: the order to join them in, pricing joins, without trying every order

## One table: pick an access path

* Example: rule 1's `SELECT NAME FROM EMP WHERE SAL > 20000`; the running query puts no predicate on EMP
* Two ways to read a table
  * segment scan: every page, once, in no order (a segment is the disk area a table lives in)
  * index scan: B-tree leaves in key order, optionally between a start and a stop key; clustered or not
* A filter of the form `column op value` is *sargable*, a search argument
  * both scans test it as they read, so a failing row costs no extra page: predicate pushdown, in 1979. A scan of DEPT reads 5 pages and keeps the 10 Denver rows
  * an index whose key starts with that column also uses it to start and stop: `SAL > 20000` is start key 20,000
  * `column = column` inside one table is not sargable: it is tested after the row is read
* An index *matches* a set of boolean factors if they are sargable and their columns are a prefix of the index key
  * `(NAME, LOCATION)` matches `NAME='SMITH' AND LOCATION='SAN JOSE'`; `LOCATION='SAN JOSE'` alone matches nothing, though it still rides along as a search argument
* Cost per path (Table 2, abridged; `F` = product of matched factors)

```
unique index, equality             1 + 1
clustered, matching                F × (index_pages + pages)
non-clustered, matching            F × (index_pages + rows)
clustered, matching nothing        index_pages + pages
non-clustered, matching nothing    index_pages + rows
segment scan                       pages
```

* Unique index, equality: JOB's TITLE index on `TITLE = 'CLERK'` is 2
* Matching nothing: the whole index, then the whole table. The running query puts no predicate on EMP, so every EMP index path matches nothing: the DNO index 550, the JOB index 10,050
* Buffer variant: if the fetched pages fit in memory, a non-clustered index pays per page, not per row
* Clustered vs non-clustered: the matching rows differ only in `pages` vs `rows`, 500 against 10,000 for EMP
  * clustered: matching rows share pages; one fetch per *page*
  * non-clustered: neighbouring entries point at different pages; one fetch per *row*, and a page can come back many times
  * the paper assumes the table is far bigger than the buffer. That, not the B-tree, turns `pages` into `rows`
* Worked: `SAL > 20000`. EMP is stored in DNO order, so the SAL index is non-clustered: forced, not unlucky

  ```
  SAL index, were it clustered    1/4 × (40 + 500)       135
  segment scan                    pages                  500
  SAL index, non-clustered        1/4 × (40 + 10,000)    2,510
  ```

  * rule 1's pick loses to the scan by 5×; the two statistics that say so are `pages` and `rows`
* Break-even: the index loses once the qualifying rows outnumber the table's pages
  * `F × 10,040 = 500`: F = 500 / 10,040, about 5%, or 498 rows, just under EMP's 500 pages (the index's own 40 pages tip it). Strawman 2's rough figure, made exact
  * it moves with the physical design: rows per page, clustering, buffer size. No rule book can encode it

## Two tables: join methods

* A join as two loops, EMP with DEPT on DNO

```
for each d in DEPT:
    for each e in EMP:
        if e.DNO = d.DNO:
            emit (d, e)
```

* *Outer*: the outside loop's table, read once. *Inner*: read again for every outer row; one lookup into it is a *probe*, strawman 2's lookup (nothing to do with an outer join)
* As written: a million pairs examined to keep 10,000. Every join method is a cheaper way to the same pairs
* Nested loops: add the filter and an index

  ```
  for each d in DEPT with LOC = 'DENVER':
      for each e in EMP with e.DNO = d.DNO:
          emit (d, e)
  ```

  * the filter runs on the outer first: 10 rows reach the inner loop, not 100
  * the inner line is an access path, chosen by Table 2 with `d.DNO` as the constant: once the outer row supplies a value, the join predicate is sargable
  * one probe of EMP's clustered DNO index: `1/100 × (50 + 500)` = 5.5 pages
  * `C = C_outer + outer_rows × C_inner`: `5 + 10 × 5.5` = 60. The outer is paid once, the inner `outer_rows` times
  * without the index each probe scans 500 pages: 5,000, not 55
* Merge scan (a *merge join*)
  * put both in join-column order, then walk them side by side like two sorted lists: output on a match, step the side that is behind
  * each table read once, no lookups; the price is getting both into that order. Worth it when lookups would be many: 10,000 (rule 2's EMP first), not 10 (DEPT first)
  * equi-join only; other join predicates become filters on the joined rows
  * why only two methods: Blasgen and Eswaran (1976) found one of these near-optimal except for tiny tables. Hash join came in the 1980s
  * the paper: the two cost formulas are essentially the same, but a sorted inner is read once in total
* Trace on the paper's Figure 1 rows: DEPT with EMP on DNO, after `LOC = 'DENVER'` (51 BILLING is in Boulder). Both are stored in DNO order, so neither is sorted

```
DEPT, in DNO order       EMP, stored in DNO order
  50  MFG                  SMITH   50
  52  SHIPPING             JONES   50
                           DOE     51

50 MFG       vs  SMITH 50    equal: output (MFG, SMITH), next EMP row
50 MFG       vs  JONES 50    equal: output (MFG, JONES), next EMP row
50 MFG       vs  DOE   51    50 < 51: next DEPT row
52 SHIPPING  vs  DOE   51    51 < 52: next EMP row: none left, done
```

* The smaller side steps: nothing later on the other side can match it. DOE is passed over without a lookup
* On a match only EMP moves: DNO is unique in DEPT, but the next EMP row may share it
* Merge cost: each input read once, in join order
  * through a clustered index: index + table pages. EMP 50 + 500, DEPT 2 + 5: 557
  * otherwise: table pages + a sort, out and back. EMP scanned and sorted is 500 + 1,000 = 1,500; with DEPT's 7, 1,507
  * a non-clustered index in that order pays a page per row, so it rarely beats the sort
* Which goes outside: four plans for EMP and DEPT, 1,000 rows out every way

```
DEPT scan outer, probe EMP.DNO          5 + 10 × 5.5        60
DEPT.DNO index outer, probe EMP.DNO     7 + 10 × 5.5        62
EMP scan outer, probe DEPT.DNO          500 + 10,000 × 2    20,500
merge, both via clustered DNO indexes   550 + 7             557
```

* A probe of DEPT's unique DNO index is 1 + 1 = 2; all of DEPT through it, 2 + 5 = 7
* Rows one and three are rule 2's two orders, priced: 10 probes against 10,000. Row two is 2 dearer but arrives in DNO order
* The merge loses here: 550 to read EMP in order, to save ten probes worth 55. It wins when one pass replaces 1,000 probes (below)

## Many tables: the order problem

* Every join order returns the same rows; on ours, the cost is 163 or 20,603 page fetches
* Naive search: price every order, each with a method per join and a path per table. `n!` orders: 6 for 3 tables, 40,320 for 8 (Leis's benchmark averages 8 joins), 2.4 × 10^18 for 20. At a generous 1 µs an order: 0.04 seconds at 8 tables, 8 minutes at 12, 77,000 years at 20
* Observation: {EMP, DEPT} can be built with DEPT outside (60) or EMP outside (20,500). Adding JOB sees only the result: the same 1,000 rows, the same predicates applied
  * the paper: adding the `(k+1)`-th table is "independent of the order of joining the first k". It depends only on *which* `k` tables, and on the order their rows arrive in
  * order is the one catch: merging JOB costs + 3 if the composite is already in JOB order, + 100 + 3 if not; nested loops into JOB, + 2,000 either way
* Exchange argument: put each way to add JOB on top of both

```
continuation                              on the 20,500    on the 60
nested loops into JOB:   + 1,000 × 2             22,500        2,060
sort on JOB, merge JOB:  + 100 + 3               20,603          163
any continuation:        + X                 20,500 + X       60 + X
```

* Every total falls by the same 20,440: a plan built on the 20,500 can always be improved, so no optimal plan contains it. 22,500 is the rule book's plan; 20,603 the FROM order as written
* The one thing a cheaper plan can fail to deliver is order. On EMP alone the scan, 500, is cheapest, but the DNO index, 550, delivers DNO order for a merge with DEPT

```
EMP --+-- DNO index scan   550, in DNO order  --------------------->  merge DEPT + 7     557
      |
      +-- segment scan     500, unordered     -->  SORT + 1,000  -->  merge DEPT + 7   1,507
```

* Keep only the cheapest, and the merge must sort all 10,000 rows: spend 50 on the path that lost, save 950 at the merge
* So keep the cheapest plan, plus the cheapest in each order a later step may want
  * the paper's term: an *interesting order* (in plain words, a useful order), one a merge join, GROUP BY or ORDER BY can use
  * the paper's rule: keep "the cheapest access path which produces tuples in each interesting order and the cheapest unordered access path"
  * here the interesting orders are the join columns, DNO and JOB. EMP keeps the scan, the DNO index and the JOB index (10,050, only for its order); the SAL index is pruned
  * equivalence classes: once `EMP.DNO = DEPT.DNO` is applied, both columns give the same order, so one entry covers both
* The state is a pair, (subset, order). On this data the 557 merge still loses to the 60: cheap insurance, not a guarantee
* So: dynamic programming over *subsets*, one level per subset size

```
for each single table:
    keep the best plan, plus the best in each interesting order
for each pair {A, B}:
    every kept plan for {A} ⋈ B and for {B} ⋈ A, both methods; best per order
for each triple:
    every kept plan for each pair in it ⋈ the remaining table; best per order
...
```

* Each level reads only the level below: how a subset was built no longer matters. The added table is always the inner, a base table
* `2^n` subsets instead of `n!` orders: at 3 tables a loss, 8 against 6; at 8 tables, 256 against 40,320
  * the paper's bound: at most `2^n` × (number of interesting orders) plans stored
* Two heuristics on top
  * no cross products: add a table only if it shares a join predicate with the tables joined so far
    * ours has EMP–DEPT and EMP–JOB, no DEPT–JOB: {DEPT, JOB} is never entered, 4 legal orders of 6
    * unavoidable only when the join graph is disconnected; then take it as late as possible
  * left-deep: each join adds one base table, the *inner*, to the composite so far, the *outer*. Bushy trees are not considered: the one 1979 restriction later evidence overturned (what held up, below)

```
left-deep: considered          bushy: not considered
          ⋈                              ⋈
         / \                           /   \
        ⋈   D                         ⋈     ⋈
       / \                           / \   / \
      ⋈   C                         A   B C   D
     / \
    A   B                          the top join's inner is a composite
```

* Left-deep buys: a plan is just an order of tables; a base-table inner can be probed through an index; a composite, only ever an outer, pipelines unless a merge must sort it
* With three tables there is no bushy tree; left-deep still excludes JOB ⋈ (DEPT ⋈ EMP), the pair as an inner

## The search, run by hand

* Bottom-up, one level per subset size; each subset keeps one plan per order. Read from the bottom

```
                   kept, one per order           priced, then pruned
{EMP, DEPT, JOB}   163 = 60 + 100 + 3            230 · 603 · 2,060 · 20,557 · 30,053
{EMP, DEPT}        60 · 62 DNO · 30,050 JOB      557 · 1,507 · 20,500 · 20,550
{EMP, JOB}         203 · 204 JOB · 20,550 DNO    1,503 · 10,053 · 20,500 · 30,050
{DEPT, JOB}        never entered: no join predicate
DEPT               5 · 7 DNO                     10.2
EMP                500 · 550 DNO · 10,050 JOB    10,040
JOB                2 · 3 JOB                     2 (the scan, a tie)
```

* Singles: DEPT's LOC index, `1/10 × (2 + 100)` = 10.2, loses to the 5-page scan; nobody wants EMP in SAL order; JOB's scan ties its TITLE index at 2
* Pairs: extend each kept single by one table, both methods
  * a probe costs 5.5 into EMP by DNO, 201 into EMP by JOB (`1/50 × (50 + 10,000)`), 2 through a unique index
  * {EMP, JOB}: 203 = JOB's TITLE index 2 + 201; 204 from its JOB index, 3 + 201
  * 30,050 and 20,550 start from EMP's index scans and probe 10,000 times, kept only for their order
  * pruned: merges of EMP in order (DNO index 550, JOB index 10,050, or scan + sort 1,500) with DEPT's 7 or JOB's 3; EMP outside (scan 500 or an index) + 10,000 × 2
* Triple: extend each kept pair by the remaining table; no ORDER BY, so only the cheapest is kept
  * 163 = the 60 + 100 to sort its 1,000 rows on JOB + 3 to merge JOB
  * 230 = {EMP, JOB}'s 203 + 20 to sort its 200 rows on DNO + 7 to merge DEPT; 603 = 203 + 200 × 2 lookups into DEPT; 2,060 = 60 + 1,000 × 2 lookups into JOB
  * the ordered entries need no sort and still lose, 30,050 + 3 and 20,550 + 7: the sort they save costs only 100 or 20
* The merge that lost on the pair wins at the top, 100 + 3 against 1,000 × 2 probes: the winner uses both join methods and a sort, which no rule book reaches
* The paper's own example prunes EMP's scan and keeps JOB's: its assumed costs differ, the mechanism is the same
* The plan it picks, read bottom-up

```
            ⋈ merge          + 3: one pass of JOB, TITLE = 'CLERK'      163, 20 rows
           /       \
  SORT on JOB       JOB      + 100: sort the 1,000 rows on JOB          160
       |
       ⋈ nested loop         + 10 × 5.5: probe EMP's DNO index          60, 1,000 rows
      /     \
   DEPT      EMP             5: scan DEPT, LOC = 'DENVER'               5, 10 rows
```

* The same 20 rows other ways: the rule book 22,500, the FROM order 20,603, the tree as parsed about 5,000,000
* The search itself: "a few thousand bytes and a few tenths of a second", 8 tables in seconds on a 370/158; a 2-way join takes about 5 to 20 database retrievals (rows fetched through the storage layer) to optimize, once per compiled plan
* What lives on, mostly with bushy plans added
  * Postgres runs the same subset DP, bushy joins included, below 12 FROM items (`geqo_threshold`), then a genetic search
  * Cascades-style optimizers (SQL Server, Calcite, CockroachDB, Spanner) do the same subset memoization top-down with rules

## Recap

* Rules: each held on one query and broke on the next; only filters as early as possible survives
* Cost: page fetches, the one number every plan is ranked by
* Estimates: four catalog numbers and a factor per predicate, multiplied, assuming uniform values and independent columns
* One table: the cheapest access path, plus the cheapest per interesting order
* Two tables: nested loops or merge scan, whichever costs less
* Many tables: DP over subsets, one plan per (subset, order)
* 163 page fetches for the 20 rows, against 22,500 for the rule book
* Next class, Spanner: the cost measure grows a network term and a shard fan-out term
* The core lecture ends here. The next three sections are optional: run on if time is left, otherwise leave them for reading

## Nested queries

* Uncorrelated: the subquery names no outer column, so it has one answer: `SELECT NAME FROM EMP WHERE SAL = (SELECT AVG(SAL) FROM EMP)`
  * evaluate once, before the outer block, and plug in the value: the outer block then optimizes a sargable `SAL = 15000`
* Correlated: the subquery references the outer row, so re-evaluate it per outer row
  * `SELECT NAME FROM EMP X WHERE SAL > (SELECT AVG(SAL) FROM EMP WHERE EMP.DNO = X.DNO)`: who earns more than their department's average (the paper compares with the manager)
  * a nested-loop join wearing a different syntax: the outer block is the outer, the subquery the inner
  * if the referenced column repeats, reuse the last result; sort the outer on it if that pays. EMP read in DNO order: 100 averages, not 10,000
* System R stops there: each subquery stays its own block, invisible to the join-order search. Unnesting is later work

## What held up, what did not

* Paper's own check, stated as preliminary: absolute costs often wrong, *ranking* of plans usually right, the best plan picked "in a large majority of cases"
* The test came 36 years later: Leis et al. 2015 (journal version 2018), 113 queries, 3 to 16 joins, on real data (IMDB): synthetic data obeys the optimizer's own assumptions
* Statistics: base-table estimates are fine; join estimates are off by orders of magnitude, mostly *under*
  * each join multiplies as if columns were independent, so the error compounds: the failure is in combining the statistics, not in them
* Cost measure: matters less. Bad cardinalities hurt far more than a crude cost model
  * with true cardinalities, Postgres's cost model is off by 30–40%; a model that just counts rows picks plans nearly as good (in main memory; on disk the model matters more)
* Search: exhaustive enumeration still pays, in the tail and with rich indexes; with primary-key indexes only, a greedy heuristic edges DP at the median (journal version)
  * left-deep is the restriction that lost: with foreign-key indexes the best left-deep plan is about 2× the best bushy one at the median, up to 1,252×
* The line to remember
  * the 1979 enumeration survived; its search space had to widen, from left-deep to bushy
  * its statistics were replaced, by histograms and samples
  * its assumptions, uniform and independent, are still with us, and they were the real problem
* Not in 1979: hash join, histograms, bushy plans, parallel plans, re-optimizing when estimates turn out wrong, plan caching that notices data changed

## The design, assembled

1. Rewrite: parse into blocks, convert WHERE to CNF, push each filter to its table
2. Cost: page fetches (the paper adds a CPU term we leave out)
3. Statistics: kept in the catalog, refreshed by hand
4. Selectivity: one factor per predicate from Table 1; multiply
5. Access paths: per table, the cheapest overall and the cheapest per interesting order
6. Join methods: nested loops or merge scan, decided by cost
7. Join order: DP over subsets, one plan per (subset, order); left-deep, no cross products
8. Nested queries: once if uncorrelated, per outer row if correlated

## Questions to review

* Why is `×` then `σ` the same answer as `σ` then `⋈`? Which rewrite made strawman 1 die?
* Give a query where "use the index" is wrong. Which two statistics tell you so?
* Why is cost counted in pages rather than rows? What would rule 1 look like if it were rows?
* What breaks if `LOC` and `ZIP` are correlated and the optimizer multiplies their selectivities? Over- or underestimate?
* Clustered vs non-clustered index: which statistic switches from `pages` to `rows`, and why?
* What is a sargable predicate, and what can a scan or an index do with one?
* What is an interesting order? Why keep a more expensive plan that produces one?
* Nested loop and merge scan have the same cost shape. Where does merge win?
* Why can the best plan for `{EMP, DEPT, JOB}` be built from the best plans for its 2-subsets? Where does that argument need "per interesting order"?
* What does left-deep rule out? What does it buy?
* When is a cross product unavoidable?
* A correlated subquery: which join algorithm is it secretly?
* Leis 2015: if the cost model is crude and the estimates are bad, why does exhaustive DP still help?
