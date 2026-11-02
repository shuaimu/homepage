
# Query Optimization (System R)

Paper: Selinger, Astrahan, Chamberlin, Lorie, and Price, *Access Path Selection in a Relational Database Management System* (SIGMOD 1979).

* So far the storage engine gave us Get / Put / scan and indexes (Postgres, LSM, B-trees)
* SQL says *what* rows you want, not *how* to get them
* Today: how the DBMS picks the *how*. We will reinvent the System R optimizer piece by piece
* Optional companion: Leis et al., *How Good Are Query Optimizers, Really?* (VLDB 2015) — what held up after 36 years

## The job

* Paper's running example: clerks in Denver, with their department and job title

```
SELECT NAME, TITLE, SAL, DNAME
FROM   EMP, DEPT, JOB
WHERE  TITLE = 'CLERK'
  AND  LOC = 'DENVER'
  AND  EMP.DNO = DEPT.DNO
  AND  EMP.JOB = JOB.JOB
```

* The user did not say:
  * which table to read first
  * whether to use an index, and which one
  * which join algorithm
  * in what order to join three tables
* All of those change the running time by orders of magnitude; none change the answer
* Goal: a plan whose cost is close to the best one
  * not *the* best: the paper is explicit that estimates are rough
  * cheap enough to run at compile time, then amortize over many executions

## The tables

* The paper's Figure 1 shows the three tables with three or four rows each and no sizes. The sizes here are ours, the same as the slides, picked so the trade-offs show

```
EMP (NAME, DNO, JOB, SAL)    10,000 rows, 20 to a page: 500 pages, stored in DNO order
  index on DNO    clustered              100 values, 100 rows each     50 pages
  index on JOB    non-clustered          50 values, 200 rows each      50 pages
  index on SAL    non-clustered          values 5,000 to 25,000        40 pages

DEPT (DNO, DNAME, LOC)       100 rows on 5 pages, stored in DNO order
  index on DNO    clustered, unique                                     2 pages
  index on LOC    non-clustered          10 cities, 10 rows each        2 pages

JOB (JOB, TITLE)             50 rows on 2 pages, stored in JOB order
  index on JOB    clustered, unique                                     1 page
  index on TITLE  non-clustered, unique                                 1 page
```

* "Stored in DNO order": EMP's rows were inserted sorted by DNO and kept that way, so one department's 100 employees sit together on 5 pages
  * nothing forces this; it is a choice made when the table was set up, a sensible one if employees are usually fetched by department
* An index lists rows in its own column's order
  * *clustered*: the table is stored in that same order, so the rows the index finds sit together. EMP's DNO index
  * *non-clustered*: the table is stored in some other order, so the rows it finds are scattered across pages. EMP's JOB and SAL indexes
  * a table is stored in one order, so at most one of its indexes is clustered
* An index is small next to its table: EMP's are 40 to 50 pages against 500
* The query's answer: 200 clerks (1 job title in 50), 1 in 10 of them in a Denver department, so about 20 rows

## From text to a tree

* Parse
  * a query block = SELECT list + FROM list + WHERE tree
  * a predicate can contain another query → more blocks (nested queries, later)
* Catalog lookup
  * do the tables and columns exist, what are the types
  * also: statistics about the tables and their indexes (below)
* Relational algebra: the tree the optimizer works on
  * `σ` select (filter rows), `π` project (drop columns), `⋈` join, `×` cross product

```
        π NAME,TITLE,SAL,DNAME
              |
        σ TITLE='CLERK' ∧ LOC='DENVER' ∧ EMP.DNO=DEPT.DNO ∧ EMP.JOB=JOB.JOB
              |
           × (EMP, DEPT, JOB)
```

* Everything downstream is: pick an *equivalent* tree, then an algorithm for each node
* Rewrite (System R does a little; later systems a lot)
  * WHERE → conjunctive normal form; each conjunct is a boolean factor
  * every output row satisfies every boolean factor, so each can be applied as early as you like
  * push filters down to the table they mention
  * later systems add much more: push projections, expand views, flatten and unnest subqueries. System R keeps each subquery as its own block
* Physical plan: each node becomes an operator with an algorithm (segment scan, index scan, nested loop, merge)
* Code generation
  * System R compiled the plan to machine code; Postgres interprets; Spanner (next class) does its own thing
  * plan is stored for programs and rerun many times → optimization cost is amortized

## Strawman 1: run the tree as parsed

* Cross product first, filter last
  * 10,000 EMP × 100 DEPT × 50 JOB = 50 M intermediate rows to build and throw away
* Fix: pushdown. `σ TITLE='CLERK'` sits on JOB, `σ LOC='DENVER'` on DEPT, and the equality predicates turn `×` into `⋈`

```
                 ⋈ EMP.JOB=JOB.JOB
                /               \
        ⋈ EMP.DNO=DEPT.DNO    σ TITLE='CLERK'
        /             \             JOB
      EMP        σ LOC='DENVER'
                     DEPT
```

* Rewriting removes the obviously stupid plans. It does not tell you which of the remaining ones is good

## Strawman 2: fixed rules

* Replace the search with a rule book. Each rule is right on plenty of queries, which is why rule books were the serious alternative in 1979
* Rough counts, as in strawman 1, on the tables above
  * a disk read brings in a whole page. A scan reads EMP's 10,000 rows in 500 reads
  * rows found through a clustered index sit together, 20 to a read; through a non-clustered one, about a read per row
* Rule 1: always use an index if one exists
  * Makes sense: `SELECT NAME FROM EMP WHERE DNO = 50`
    * 100 rows, stored together: about 5 reads, against 500 for the scan
    * scattered rows win too if they are few: `WHERE JOB = 5` is 200 rows, about 200 reads
  * Breaks: `WHERE SAL > 20000` keeps a quarter, 2,500 rows scattered across the table: about 2,500 reads, against 500. The scan wins 5×
  * The index pays per row it finds, the scan per page. Past about 500 scattered rows, scan
* Rule 2: always join in FROM order
  * Makes sense: people tend to name first the table they are filtering
    * `SELECT DNAME, NAME FROM DEPT, EMP WHERE DEPT.LOC = 'DENVER' AND EMP.DNO = DEPT.DNO`
    * DEPT first keeps 10 rows: 10 lookups into EMP
    * EMP first keeps all 10,000: 10,000 lookups into DEPT
    * the order the user wrote is the best one, and it took no search to find
  * Breaks: `SELECT DNAME, NAME FROM EMP, DEPT WHERE EMP.SAL > 20000 AND EMP.DNO = DEPT.DNO`
    * EMP is filtered too, but still keeps 2,500 rows: 2,500 lookups into DEPT
    * DEPT first keeps all 100: 100 lookups into EMP
  * Start from the table that keeps the fewest rows. The FROM list does not know which one that is
  * The paper's `FROM EMP, DEPT, JOB` starts with EMP, the one table its WHERE clause does not filter at all
* Filters as early as possible is the rule that survives: it is strawman 1's fix, and the optimizer keeps it
* Lesson: each rule is right on some queries and wrong on others, and only the data says which
* So: estimate the cost of each candidate, pick the cheapest. Three things to invent
  1. a cost measure
  2. statistics about the data
  3. a way to search the candidates without enumerating all of them

## Cost: what are we minimizing

```
COST = PAGE FETCHES
```

* A page fetch is one page read from disk, a data page or an index page. The same unit strawman 2 counted as "reads"
  * rows matter because they decide how many pages a plan touches: a scan pays per page, a non-clustered index about a page per row it finds, a clustered index per page of matching rows
* The paper's formula has a second, CPU term: `COST = PAGE FETCHES + W × RSI CALLS`
  * RSI calls count the rows the storage layer passes up to the rest of the plan; `W` is a machine-specific weight that turns them into page-equivalents
  * the paper gives `W` no value, and on one table the term is the same for every path anyway (they all return the same rows). We count pages only
* Single-user total resource use, not latency; no parallelism, no memory pressure, no network
  * every later optimizer widens this (Spanner: network and shard fan-out)

## Statistics

* Per table `T`
  * `rows(T)`: how many rows
  * `pages(T)`: how many pages hold `T`'s rows; a scan reads all of them
* Per index `I`
  * `distinct(I)`: how many distinct key values. For an index on one column, that column's distinct values, written `distinct(col)`
  * `index_pages(I)`: how many pages the index takes
* On our tables

```
EMP             rows 10,000    pages 500         a scan reads 500 pages
DEPT            rows 100       pages 5
JOB             rows 50        pages 2
EMP DNO index   distinct 100   index_pages 50    100 departments
EMP JOB index   distinct 50    index_pages 50    50 job codes
```

* The paper's names, for reading it: `NCARD` = rows, `TCARD` = pages, `ICARD` = distinct, `NINDX` = index_pages; below, `QCARD` = result_rows
  * CARD is short for cardinality, "how many"; the letters before it are not consistent (the N in `NCARD` counts rows, the N in `NINDX` pages), hence the plain names here
  * the paper keeps one more, `P`: several tables can share a disk segment, and a scan then reads the whole segment. Here every table has its own, so a scan reads exactly `pages(T)`

* Refreshed by a manual UPDATE STATISTICS, not on every write
  * updating the catalog on every INSERT would make the catalog a hot lock
  * Postgres `ANALYZE` is the same decision

## Selectivity: how many rows survive a predicate

* Each boolean factor gets a selectivity factor `F`: expected fraction of rows that pass
* Paper's Table 1, abridged:

```
col = v            1/distinct(col)     if indexed, else 1/10
col1 = col2        1/max(distinct(col1), distinct(col2))
col > v            (high − v)/(high − low)  if numeric, else 1/3
col BETWEEN a,b    (b − a)/(high − low)     if numeric, else 1/4
col IN (list)      n × F(col = v), at most 1/2
p1 OR p2           F1 + F2 − F1·F2
p1 AND p2          F1 · F2
NOT p              1 − F
```

* Why 1/10 when the column has no index
  * `distinct` is kept per index, so an un-indexed column has no count to divide by: the optimizer knows nothing about its values
  * the paper: "a lack of statistics implies that the relation is small, so an arbitrary factor is chosen". A big table that people search would have been given an index; no index suggests a small table, where a bad guess costs little
  * the paper says the constants have "no significance" beyond their order. Equality, the most selective test, gets the smallest guess, 1/10; a range gets 1/3, less selective than that but under 1/2, because "few queries use predicates that are satisfied by more than half the tuples"; BETWEEN gets 1/4, "between the default selectivity factors for an equal predicate and a range predicate"
  * Postgres gathers statistics on every column (`ANALYZE`), so it rarely needs a default; when it does, it guesses 1/200 for equality and 1/3 for a range
* Result size of a block: `result_rows = Π rows(T) × Π F(boolean factors)`
* Search arguments: a filter of the form `column op value` is *sargable*. A scan tests it as it reads, so failing rows are dropped at no extra page cost, and an index whose key starts with that column can use it to start and stop its range
  * `SAL > 20000` on EMP: `F = (25,000 − 20,000) / (25,000 − 5,000) = 1/4`, 2,500 of 10,000 rows
  * `column = column` inside one table is not sargable: it is tested after the rows are read
* Read the assumptions
  * uniform: every key value equally common
  * independent: `AND` multiplies
  * magic constants (1/10, 1/3, 1/4) when there is no index to consult
  * `LOC='DENVER'` and `ZIP LIKE '802%'` are not independent. Multiply and you underestimate by a lot
  * this is the piece that aged worst; hold that thought for the end

## One table: pick an access path

* Access paths on a table
  * segment scan: every page of the table, once (the paper's name; a segment is the disk area a table lives in)
  * index scan: B-tree leaves in key order; optional start/stop keys; clustered or not
  * both test search arguments as they read
* An index *matches* a boolean factor if the factor is sargable and its column is a prefix of the index key
  * `(NAME, LOCATION)` index matches `NAME='SMITH' AND LOCATION='SAN JOSE'`
* Cost per path (Table 2, abridged; `F` = product of matched factors)

```
unique index, equality             1 + 1
clustered index, matching          F × (index_pages + pages)
non-clustered index, matching      F × (index_pages + rows)
index matching nothing             index_pages + pages, or index_pages + rows if non-clustered
segment scan                       pages
```

* A matching-nothing index scan reads the whole index and the whole table; it is worth it only for the order it delivers (interesting orders, below)
* The paper adds a buffer variant: if the fetched pages fit in memory, a non-clustered index pays per page, not per row

* Why clustered vs non-clustered differ (strawman 2): `pages` vs `rows`
  * clustered: rows were inserted in the index's key order and kept that way, so matching rows share pages; one page fetch per *page*
  * non-clustered: the table is stored in some other order, so neighbouring index entries point at different pages; one page fetch per *row*, and the same page can come back many times
* Worked: `SAL > 20000` on EMP, 10,000 rows on 500 pages, a quarter of them qualify. EMP is stored in DNO order, so the SAL index is non-clustered
  * index path: `1/4 × (index_pages + rows)` = `1/4 × (40 + 10,000)` = 2,510 pages
  * segment scan: 500 pages
  * the "obvious" index loses by 5×
* Interesting orders
  * an index scan or a sort produces rows in some order
  * an order is *interesting* if GROUP BY / ORDER BY (or, later, a join column) wants it: a merge join, in the join section below, needs both inputs in join-column order
  * keep the cheapest path for each interesting order *and* the cheapest unordered path
  * at the end compare "ordered path" vs "cheapest path + sort"

## Two tables: join algorithms

* Outer and inner: read one outer row, then find its matches in the inner
* Nested loops: rule 2's lookups
  * for each outer row, scan the inner for matches
  * with an index on the inner join column that scan is an index probe
  * `C = C_outer + outer_rows × C_inner`, `outer_rows` = outer rows that survive their predicates
* Merge scan (a *merge join*): the other way to join two tables
  * walk both tables side by side in join-column order, the way you merge two sorted lists
  * each table is read once, with no lookups. The price: both must be in that order first; sort whichever is not
  * worth it when the lookups would be many (rule 2's EMP first: 10,000), not few (DEPT first: 10)
  * On the paper's Figure 1 rows, joining EMP with JOB on `EMP.JOB = JOB.JOB`. EMP is stored in DNO order (SMITH, JONES, DOE), so it is sorted into JOB order first

    ```
    EMP, in JOB order        JOB, stored in JOB order
      JONES    5               5  CLERK
      DOE      5               6  TYPIST
      SMITH   12               9  SALES
                              12  MECHANIC

    JONES  5  vs   5 CLERK      equal: output (JONES, CLERK), next EMP row
    DOE    5  vs   5 CLERK      equal: output (DOE, CLERK), next EMP row
    SMITH 12  vs   5 CLERK      5 < 12: next JOB row
    SMITH 12  vs   6 TYPIST     6 < 12: next JOB row
    SMITH 12  vs   9 SALES      9 < 12: next JOB row
    SMITH 12  vs  12 MECHANIC   equal: output (SMITH, MECHANIC), next EMP row: none left, done
    ```

    * the smaller side steps forward: both sides are sorted, so nothing later on the other side can match it. TYPIST and SALES have no employees and are passed over
    * on a match only EMP moves on: JOB values are unique in JOB, but the next EMP row may share one (DOE after JONES)
  * the inner "scan" per outer row is the contiguous group with the same key
  * `C = C_outer + outer_rows × C_inner`, same shape, but `C_inner` is tiny
  * a sorted inner is read once in total: summed over all outer rows, `outer_rows × C_inner` is its pages, once
* Why only two: Blasgen and Eswaran (1976) found one of these was near-optimal except for tiny tables
  * hash join is a 1980s addition; today most engines have all three
* Equi-join only for merge; other join predicates become ordinary filters on the composite
* n-way join = a chain of 2-way joins: composite-so-far is the outer, the new table is the inner
  * pipelined: a composite row can flow into the next join as soon as it exists
  * materialize only when the next step needs a sort

## Many tables: the order problem

* Join result does not depend on order; join cost does, hugely
* Candidates: `n!` orders × join methods × access paths. 3 tables: 6 orders. 8 tables: 40,320
* Observation that saves us
  * once the first `k` tables are joined, the best way to add the `(k+1)`-th depends only on *which* `k` tables, not on how they were ordered
  * same predicates apply, same interesting orders, same methods
* So: dynamic programming over *subsets*

```
for each single table:      best plan (per interesting order + unordered)
for each pair of tables:    best of (best plan for {A}) ⋈ B, (best plan for {B}) ⋈ A, each method
for each triple:            best of (best plan for each pair) ⋈ remaining table
...
```

* `2^n` subsets instead of `n!` orders; each subset keeps one plan per interesting order
* Two heuristics on top
  * no cross products unless unavoidable: only add a table that has a join predicate with the set so far. `T1-T3-T2` is skipped if T1 and T3 have no predicate
  * left-deep: the inner is always a base table. Bushy trees (join two composites) are not considered
    * base-table inner means an index probe is possible
    * composites pipeline without being stored
    * search space shrinks again
* Interesting-order equivalence classes: `E.DNO = D.DNO` and `D.DNO = F.DNO` make all three the same order, so one plan covers them
* The paper's example, in prose
  * singles: EMP via DNO index (DNO order), EMP via JOB index (JOB order), EMP scan pruned; DEPT via DNO index; JOB via index and via scan, both kept (the paper's assumed costs; on our sizes EMP's 500-page scan is the cheapest unordered path and is kept, and JOB's 2-page scan ties its TITLE index, so only one of them is kept)
  * pairs: nested loop EMP→DEPT using DEPT.DNO index; EMP→JOB using JOB.JOB index; merge EMP(DNO order)⋈DEPT(DNO order) with no sort; or sort EMP by DNO first
  * for each (set, order) keep the cheapest, drop the rest
  * triples: extend each surviving pair with the remaining table, both methods
* Cost of optimizing: "a few thousand bytes and a few tenths of a second"; 8 tables in seconds on a 370/158
  * a 2-way join costs about 5–20 database retrievals to optimize (calls into the storage system, not page fetches)
* What lives on
  * Postgres runs the same subset DP, bushy joins included, below 12 FROM items (`geqo_threshold`), then a genetic search
  * Cascades-style optimizers (SQL Server, Calcite, CockroachDB, Spanner) do the same subset memoization top-down with rules
  * most also consider bushy plans now

## Nested queries

* Uncorrelated subquery: evaluate once, before the outer block; plug in the value or the list
* Correlated subquery (references the outer row): re-evaluate per outer row
  * a nested-loop join wearing a different syntax
  * if the referenced column repeats, reuse the last result; sort the outer on it if that pays
* System R stops there. Turning correlated subqueries into joins (unnesting) is later work

## What held up, what did not

* Paper's own check: absolute costs often wrong, *ranking* of plans usually right
* Leis et al. 2015, real data (IMDB), 113 queries
  * cardinality estimates off by orders of magnitude, mostly *under*, because of independence
  * bad cardinalities hurt far more than a crude cost model
  * exhaustive enumeration still pays, in the tail and with rich indexes; with primary-key indexes only, a greedy heuristic ties DP at the median (journal version, 2018)
  * the 1979 *enumeration* survived, though its left-deep search space had to widen to bushy plans; the 1979 *statistics* did not
* Not in 1979: hash join, histograms, bushy plans, parallel plans, re-optimizing when estimates turn out wrong, plan caching that notices data changed

## The design, assembled

1. Parse into blocks; rewrite to CNF, push filters and projections
2. Cost = page fetches (the paper adds a CPU term we leave out)
3. Catalog statistics, refreshed by hand
4. Per-predicate selectivity from Table 1; multiply
5. Per table: cheapest access path per interesting order
6. Two join methods; nested loop vs merge decided by cost
7. Left-deep, no cross products, DP over subsets keeping one plan per (subset, order)
8. Nested queries evaluated once if uncorrelated, per outer row if correlated

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
