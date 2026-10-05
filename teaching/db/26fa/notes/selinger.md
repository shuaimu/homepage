
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
  * push filters down to the table they mention; push projections down
  * expand views, flatten simple subqueries
* Physical plan: each node becomes an operator with an algorithm (segment scan, index scan, nested loop, merge)
* Code generation
  * System R compiled the plan to machine code; Postgres interprets; Spanner (next class) does its own thing
  * plan is stored for programs and rerun many times → optimization cost is amortized

## Strawman 1: run the tree as parsed

* Cross product first, filter last
  * 10,000 EMP × 100 DEPT × 50 JOB = 50 M intermediate rows to build and throw away
* Fix: pushdown. `σ TITLE='CLERK'` sits on EMP, `σ LOC='DENVER'` on DEPT, and the equality predicates turn `×` into `⋈`

```
                 ⋈ EMP.JOB=JOB.JOB
                /               \
        ⋈ EMP.DNO=DEPT.DNO      JOB
        /             \
  σ TITLE='CLERK'   σ LOC='DENVER'
      EMP               DEPT
```

* Rewriting removes the obviously stupid plans. It does not tell you which of the remaining ones is good

## Strawman 2: fixed rules

* Always use an index if one exists. Always join in FROM order. Filters as early as possible
* Where it breaks
  * index on TITLE, but a quarter of employees are clerks: a non-clustered index touches a data page per *tuple*; a plain scan touches each page once and wins
  * FROM order `EMP, DEPT, JOB` may be the worst of the six orders; the user did not mean anything by it
  * whether to sort for a merge join depends on how many rows are left after the filters
* Lesson: the right choice depends on the *data*. Rules that ignore the data pick wrong on some data
* So: estimate the cost of each candidate, pick the cheapest. Three things to invent
  1. a cost measure
  2. statistics about the data
  3. a way to search the candidates without enumerating all of them

## Cost: what are we minimizing

```
COST = PAGE FETCHES + W × RSI CALLS
```

* Page fetches: I/O. RSI calls: tuples handed up from the storage layer, a stand-in for CPU
* `W` is a knob: how many tuple-handoffs equal one disk page
* Single-user total resource use, not latency; no parallelism, no memory pressure, no network
  * every later optimizer widens this (Spanner: network and shard fan-out)

## Statistics

* Per table `T`
  * `NCARD(T)` rows
  * `TCARD(T)` pages holding rows of `T`
  * `P(T)` fraction of the segment's pages that hold `T` (tables can share a segment)
* Per index `I`
  * `ICARD(I)` distinct keys
  * `NINDX(I)` index pages
* Refreshed by a manual UPDATE STATISTICS, not on every write
  * updating the catalog on every INSERT would make the catalog a hot lock
  * Postgres `ANALYZE` is the same decision

## Selectivity: how many rows survive a predicate

* Each boolean factor gets a selectivity factor `F`: expected fraction of rows that pass
* Paper's Table 1, abridged:

```
col = v            1/ICARD(col)        if indexed, else 1/10
col1 = col2        1/max(ICARD(col1), ICARD(col2))
col > v            (high − v)/(high − low)  if numeric, else 1/3
col BETWEEN a,b    (b − a)/(high − low)     if numeric, else 1/4
col IN (list)      n × F(col = v), at most 1/2
p1 OR p2           F1 + F2 − F1·F2
p1 AND p2          F1 · F2
NOT p              1 − F
```

* Result size of a block: `QCARD = Π NCARD(T) × Π F(boolean factors)`
* Rows the storage layer hands up: `RSICARD` uses only the *sargable* factors
  * sargable = `column op constant`; can be pushed into the scan as a search argument, filtered below the RSI
* Read the assumptions
  * uniform: every key value equally common
  * independent: `AND` multiplies
  * magic constants (1/10, 1/3, 1/4) when there is no index to consult
  * `LOC='DENVER'` and `ZIP LIKE '802%'` are not independent. Multiply and you underestimate by a lot
  * this is the piece that aged worst; hold that thought for the end

## One table: pick an access path

* Access paths on a table
  * segment scan: every page of the segment, once
  * index scan: B-tree leaves in key order; optional start/stop keys; clustered or not
  * both accept search arguments so rejected rows never cross the RSI
* An index *matches* a boolean factor if the factor is sargable and its column is a prefix of the index key
  * `(NAME, LOCATION)` index matches `NAME='SMITH' AND LOCATION='SAN JOSE'`
* Cost per path (Table 2, abridged; `F` = product of matched factors)

```
unique index, equality             1 + 1 + W
clustered index, matching          F × (NINDX + TCARD) + W × RSICARD
non-clustered index, matching      F × (NINDX + NCARD) + W × RSICARD
                                   (TCARD instead of NCARD if the pages fit in the buffer)
segment scan                       TCARD / P + W × RSICARD
```

* Why clustered vs non-clustered differ: `TCARD` vs `NCARD`
  * clustered: rows in key order on disk, one page fetch per *page*
  * non-clustered: one page fetch per *row*, and the same page can come back many times
* Worked: EMP has 10,000 rows on 500 pages, non-clustered TITLE index, 4 titles
  * index path: `1/4 × (NINDX + 10,000)` ≈ 2,500+ pages
  * segment scan: 500 pages
  * the "obvious" index loses by 5×
* Interesting orders
  * an index scan or a sort produces rows in some order
  * an order is *interesting* if GROUP BY / ORDER BY (or, later, a join column) wants it
  * keep the cheapest path for each interesting order *and* the cheapest unordered path
  * at the end compare "ordered path" vs "cheapest path + sort"

## Two tables: join algorithms

* Outer and inner: read one outer row, then find its matches in the inner
* Nested loops
  * for each outer row, scan the inner for matches
  * with an index on the inner join column that scan is an index probe
  * `C = C_outer + N × C_inner`, `N` = outer rows that survive their predicates
* Merge scan
  * both inputs in join-column order; sort whichever is not
  * walk both once; the inner "scan" per outer row is the contiguous group with the same key
  * `C = C_outer + N × C_inner`, same shape, but `C_inner` is tiny
  * sorted temp: `C_inner ≈ TEMPPAGES / N + W × RSICARD`
* Why only two: Blasgen and Eswaran (1976) found one of these was near-optimal except for tiny tables
  * hash join is a 1980s addition; today most engines have all three
* Equi-join only for merge; other join predicates become ordinary filters on the composite
* n-way join = a chain of 2-way joins: composite-so-far is the outer, the new table is the inner
  * pipelined: a composite row can flow into the next join as soon as it exists
  * materialize only when the next step needs a sort

## Many tables: the order problem

* Join result does not depend on order; join cost does, hugely
* Candidates: `n!` orders × join methods × access paths. 3 tables: 6 orders. 8 tables: 40,320
* Observation that saves you
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
  * singles: EMP via DNO index (DNO order), EMP via JOB index (JOB order), EMP scan pruned; DEPT via DNO index; JOB via index and via scan, both kept
  * pairs: nested loop EMP→DEPT using DEPT.DNO index; EMP→JOB using JOB.JOB index; merge EMP(DNO order)⋈DEPT(DNO order) with no sort; or sort EMP by DNO first
  * for each (set, order) keep the cheapest, drop the rest
  * triples: extend each surviving pair with the remaining table, both methods
* Cost of optimizing: "a few thousand bytes and a few tenths of a second"; 8 tables in seconds on a 370/158
  * a 2-way join costs about 5–20 page retrievals to optimize
* What lives on
  * Postgres runs exactly this DP up to ~12 tables, then a genetic search
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
  * exhaustive enumeration is still worth it; DP with bad estimates still beats heuristics
  * the 1979 *search* survived; the 1979 *statistics* did not
* Not in 1979: hash join, histograms, bushy plans, parallel plans, re-optimizing when estimates turn out wrong, plan caching that notices data changed

## The design, assembled

1. Parse into blocks; rewrite to CNF, push filters and projections
2. Cost = pages + W × tuples
3. Catalog statistics, refreshed by hand
4. Per-predicate selectivity from Table 1; multiply
5. Per table: cheapest access path per interesting order
6. Two join methods; nested loop vs merge decided by cost
7. Left-deep, no cross products, DP over subsets keeping one plan per (subset, order)
8. Nested queries evaluated once if uncorrelated, per outer row if correlated

## Questions to review

* Why is `×` then `σ` the same answer as `σ` then `⋈`? Which rewrite made strawman 1 die?
* Give a query where "use the index" is wrong. Which two statistics tell you so?
* Why is `W` a knob rather than a constant?
* What breaks if `LOC` and `ZIP` are correlated and the optimizer multiplies their selectivities? Over- or underestimate?
* Clustered vs non-clustered index: which statistic switches from `TCARD` to `NCARD`, and why?
* What is a sargable predicate? Why does the optimizer care whether a filter runs below the RSI?
* What is an interesting order? Why keep a more expensive plan that produces one?
* Nested loop and merge scan have the same cost shape. Where does merge win?
* Why can the best plan for `{EMP, DEPT, JOB}` be built from the best plans for its 2-subsets? Where does that argument need "per interesting order"?
* What does left-deep rule out? What does it buy?
* When is a cross product unavoidable?
* A correlated subquery: which join algorithm is it secretly?
* Leis 2015: if the cost model is crude and the estimates are bad, why does exhaustive DP still help?
