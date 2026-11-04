
# Spanner SQL

Paper: Bacon et al., *Spanner: Becoming a SQL System* (SIGMOD 2017).

Last time ([slides](../slides/DB26fa-QueryOpt.pdf)): System R plans a query for one machine; cost = page fetches. Today: SQL inside Spanner (Oct 19, [notes](spanner.html)), where every table is sharded across machines, shards move mid-query, and what a plan must avoid is calls between machines.

## The job

* Spanner started as a key-value store: "NoSQL methods for point lookups and range scans", multi-row transactions, reads at a timestamp
  * by the 2012 paper (Oct 19) it already had schematized tables, interleaving, and "a SQL-based query language"
* What Google developers lacked on Bigtable: a schema, cross-row transactions, consistent replication, a real query language
  * Megastore put transactions on top of Bigtable, still with no robust query language
  * so application code did its own joins and aggregations
* Two ways to add SQL
  * *loosely coupled*: SQL is a separate service over the storage API. F1 (2012, the AdWords database) did this over Spanner's key-range reads
  * *tightly coupled*: the compiler and executor live inside the Spanner servers and know where shards are, how they are replicated, and how they move. This paper
  * TiDB (Aug 31; its pushdown is in the paper, not our notes) sits in between: SQL in its own processes, but it ships single-table plan pieces (filters, aggregates, TopN) into TiKV; the rest runs in the SQL layer
* Spanner's own first query engine was "bolted on": it "used high-level APIs almost like an external application"
* Making it tight changed both sides: how Spanner stores data changed how queries run (distribution, range extraction, restarts), and what queries need changed how it stores data (Ressi)
* Workload: OLTP (point lookups, small joins, milliseconds) and analytics (long scans and aggregations, seconds to hours) in one system

## The machine we have

From earlier lectures:

* Rows sorted by primary key and cut into contiguous key ranges, *shards*: TiDB's Regions (Aug 31) under another name
* Each shard belongs to one Paxos group, whose replicas sit in different datacenters
  * a Spanner group holds many shards; a TiDB Region, or a Mako shard (Oct 21), is its own group
  * Paxos group = unit of replication; shard = unit of key range
* Read-write transactions: 2PL + 2PC (Oct 19). A wound-wait abort already makes the client retry
* Lock-free reads at a timestamp, *strong* (`s_read = TT.now().latest`) or *stale* (an older one the client picks), served by any replica with `t_safe ≥` it (Oct 19). The paper calls both "snapshot" reads

New to us today (1 and 3 are already in the 2012 paper, as moving directories and INTERLEAVE IN PARENT):

1. Shards move. Spanner splits, merges, and moves shards between Paxos groups to balance load, at any time, *including while a query is reading them*, and nothing tells the query
2. Calls are addressed to key ranges, not machines: the *coprocessor framework*
   * takes "run this on keys [250, 500)"
   * finds the Paxos group that owns that range now; picks the nearest replica fresh enough for the read
   * reroutes if the range moves mid-call; retries transient faults
3. Interleaving. A child table can be stored inside its parent

```
CREATE TABLE Customer (ckey INT64, name STRING, city STRING) PRIMARY KEY (ckey)
CREATE TABLE Sales (ckey INT64, skey INT64, type STRING, amount INT64)
  PRIMARY KEY (ckey, skey), INTERLEAVE IN PARENT Customer

stored in key order:
  Customer(7)
    Sales(7, 1)
    Sales(7, 2)
  Customer(8)
    Sales(8, 1)
  ...
```

* A child's key starts with its parent's key, so they sort together
* Shard boundaries fall between parent keys: a customer and all its sales are in one shard (the paper: boundaries "preserve row co-location"; the rules below assume it)
* `ckey` is the *sharding key*: the key prefix shard boundaries are cut on. It can be several columns; an interleaved child uses its parent's
* A physical design choice, like "EMP stored in DNO order" last time: the schema author decides what sits together, and some plans get cheap because of it

Shard map for the examples:

```
shard   Customer keys    Paxos group
S1      [−∞, 250)        G1
S2      [250, 500)       G2
S3      [500, 750)       G1
S4      [750, +∞)        G3
```

## The running query

The paper's Figure 1, called Q1 below:

```
SELECT ANY_VALUE(c.name) AS name, SUM(s.amount) AS total
FROM   Customer c JOIN Sales s ON c.ckey = s.ckey
WHERE  s.type = 'global' AND c.ckey IN UNNEST(@customer_key_arr)
GROUP  BY c.ckey
ORDER  BY total DESC
LIMIT  5
```

* The 5 customers, out of a list passed in, with the most 'global' sales
* `@customer_key_arr` (`@arr` below) is a query parameter: the plan is compiled once, cached, and run with different arrays. `UNNEST(@arr)` turns the array into rows, so `c.ckey IN UNNEST(@arr)` means "ckey is one of its elements"
* `ANY_VALUE(c.name)`: all rows with one `ckey` are one customer and share a name; take any
* Joins are written as *correlated joins*
  * `CrossApply(input, map)`: for each row of `input`, run `map` with that row's columns bound, and concatenate the results (`OuterApply`: the left-outer version, NULLs when `map` is empty)
  * it runs like last lecture's nested-loop join, with the same cost formula, `C = C_outer + outer_rows × C_inner`
  * as there, the outer row's columns are constants in the map, so `s.ckey = c.ckey` becomes `s.ckey = 7`: sargable, a seek into Sales
  * what differs is the inner. Last lecture's join inner was always one base table through one access path, and a correlated subquery stayed a separate block; the map is any plan over the outer row's columns: a filter, a union over shards, an aggregate, another Apply
  * the map needs nothing from the input but those column values, so it can be shipped, with a batch of input rows, to each shard the batch touches (`DistributedApply`, below)
* The single-machine tree, before anything is distributed (Figure 1 without its unions): filters pushed down, the join as a `CrossApply`. Children are indented under their parent; `CrossApply`'s input comes first, its map second

```
Top(5) ORDER BY total DESC
  GroupBy(c.ckey)  name = ANY_VALUE(c.name), total = SUM(s.amount)
    CrossApply
      Filter c.ckey IN UNNEST(@arr)
        Scan(Customer c)
      Filter s.ckey = c.ckey AND s.type = 'global'
        Scan(Sales s)
```

* `Filter` over `Scan` is logical: how a predicate turns into seeks is range extraction, below

## Strawman 1: SQL beside the store, key-range reads only

* Run that tree on one SQL server; each `Scan` becomes key-range reads against Spanner
* With the array it is tolerable: point reads for its few customers and their sales
* Drop the array ("top 5 customers overall") and the SQL server pulls every Customer and Sales row across the network, global or not (a key-range read cannot test `type`), to keep five
* The filters, the join, and the aggregation could all have run next to the data
* Fix: ship operators to the data. Which operators, and where to?

## Strawman 2: split the plan by the shard map, at compile time

* What a classic parallel database does: partitioning is fixed, so the optimizer writes "run this subplan on servers A, B, C; combine at the root"
* In Spanner the map does not hold still
  * plans are cached and reused; by the next run S2 may have split into [250, 400) and [400, 500), and one half moved to another Paxos group
  * a shard can move *during* the query
  * which shards Q1 needs depends on `@arr`, which the compiler has not seen
    * System R hit the same wall: a host variable in a stored plan has no value when the plan is chosen, so Table 1 fell back to fixed guesses (1/3 for a range). Spanner does not guess; it decides at run time
* The paper: "we do not rely on static partitioning during query planning"
* Fix: the plan says *what* to run on each piece of a table. *Which* pieces, and *where* they live, is decided at run time, by key range

## Distribution as an operator: DistributedUnion

* At the start of compilation, put an explicit operator above every table scan:

```
Scan(T)  ⇒  DistributedUnion[shard ⊆ T]( Scan(shard) )
```

* Meaning: for each shard of `T`, run the subtree on a server hosting that shard; concatenate the results, in key order when the plan needs it
  * `T` is the table whose shards hold the rows. An interleaved child has no shards of its own: `Scan(Sales)` gets `DistributedUnion(Customer)` (Figure 1, both dashed boxes)
* The plan stays one tree. At run time the edge under a union becomes a 1-to-N call: the subtree goes to the N shards it needs, chosen then
  * the subtree can itself contain a union: multi-level distribution (Q2, below)
* The *root server* is the server the query was sent to. It runs everything above the outermost union. Any Spanner server can be root
* Optimization now has a direction: pull the union *up*. Everything below it runs next to the data, in parallel; everything above it runs on the root, on what came back
* Last lecture promised a network term and a shard fan-out term in the cost. The paper writes no cost formula
  * it pulls the union up "where possible", as far as partitionability (next) allows. Calls and rows shipped are cut by rules: pull-up, pruning, batching, affinity. Whether anything is ever priced, it does not say
  * the compiler is described as rewrites "via transformation rules": push predicates down, pick indexes, remove subqueries. Join order and statistics are not described: "we have barely touched on query optimization"

## How far up: partitionability

* Pulling the union above an operator `F` is correct only if running `F` per shard and concatenating gives the same answer as running it on the whole table:

```
F(Scan(T))  =  OrderedUnionAll[shard ⊆ T]( F(Scan(shard)) )        shards concatenated in key order
```

* `OrderedUnionAll`: the paper's name for what the union does once its subtrees return
* Passes
  * Filter, Project: per row, always
  * GroupBy whose grouping columns include the sharding key: shard boundaries never fall inside one `ckey` value, so every group lives in one shard. Needs only co-location: hash sharding on `ckey` would do (our reading; the paper credits range sharding for both this and Sort)
  * Sort whose sort columns start with the sharding key, in the key's direction: sort each shard, concatenate in key order. This needs *range* sharding
    * last lecture's interesting order: a key-ordered union delivers `ckey` order for free, like a clustered index scan
* Fails
  * GroupBy on columns without the sharding key (`GROUP BY type`): one type's rows span shards
  * Top-k, in any order: N shards each keep k, so the union returns up to N·k rows, not k
    * ordered by the key, same direction: Top = Limit ∘ Sort. The Sort passes; only "keep the first k of the ordered union" stays above
    * ordered by anything else (`ORDER BY total DESC LIMIT 5`): a real Top over the N per-shard lists
* Partial push: write `Op = OpFinal ∘ OpLocal`, run `OpLocal` on each shard and `OpFinal` above

```
Op( DistributedUnion[shard ⊆ T]( F(Scan(shard)) ) )
  =  OpFinal( DistributedUnion[shard ⊆ T]( OpLocal( F(Scan(shard)) ) ) )
```

* Top(5) = top 5 of the per-shard top 5s: each of the global top 5 rows is in its own shard's top 5
* SUM = SUM of per-shard SUMs; COUNT = SUM of COUNTs; AVG = SUM of SUMs / SUM of COUNTs
* Joins have two inputs. Two unions *on the same table*, pulled up through an inner or semi join (a semi join keeps an input row if a match exists: `EXISTS`, `IN (subquery)`), merge into one when the equi-join names every sharding-key column. In our notation:

```
CrossApply( DistributedUnion[shard ⊆ T]( C(shard) ),  DistributedUnion[shard ⊆ T]( S(shard) ) )
  =  DistributedUnion[shard ⊆ T]( CrossApply( C(shard), S(shard) ) )

holds when every S row that matches a C row of shard i is itself in shard i
```

* The rules, collected:

```
pull DistributedUnion(T) up through
  Filter, Project                          always; a filter on the sharding key is also
                                           copied into the union (its sharding-key filter)
  Apply, union on its input side           always: the map runs per input row, like a Filter
                                           (our reading; Q2 below needs it)
  GroupBy ⊇ sharding key                   always
  Sort starting with the sharding key,     yes, as an ordered union
    in the key's direction
  inner/semi join of two unions on T,      merge the two unions into one
    equi-join on every sharding column
  Top, GroupBy without the key             split: OpLocal below, OpFinal above; stop
  anything else                            stop
```

## Q1, rewritten

Start with a union over each scan:

```
Top(5) ORDER BY total DESC
  GroupBy(c.ckey)  name = ANY_VALUE(c.name), total = SUM(s.amount)
    CrossApply
      Filter c.ckey IN UNNEST(@arr)
        DistributedUnion(Customer)
          Scan(Customer c)
      Filter s.ckey = c.ckey AND s.type = 'global'
        DistributedUnion(Customer)            Sales has no shards of its own
          Scan(Sales s)
```

Pull up, bottom to top (the dotted lines in the paper's Figure 1):

1. Through `Filter c.ckey IN UNNEST(@arr)`: partitionable. The filter is on the sharding key, so the union also keeps a copy, its *sharding-key filter*, for picking shards at run time
2. Through `Filter s.ckey = c.ckey AND s.type = 'global'` on the Sales side: partitionable. The union notes `s.ckey = c.ckey`: the shard it needs is the one holding the input row's `ckey`
3. Through `CrossApply`: both unions are over Customer, and `s.ckey = c.ckey` names the whole sharding key. Customer c in shard i has its sales only in shard i: merge
4. Through `GroupBy(c.ckey)`: groups on the full sharding key, partitionable
5. At `Top(5) ORDER BY total DESC`: not partitionable. Split it: a local Top(5) goes below the union, the final Top(5) stays above. Stop
   * the per-shard totals are already final (step 4: a customer's rows are all in one shard), so the local Top ranks true totals

```
Top(5) ORDER BY total DESC                                   root server
  DistributedUnion(Customer)   sharding-key filter: ckey IN UNNEST(@arr)
    Top(5) ORDER BY total DESC                               each shard
      GroupBy(c.ckey)  name = ANY_VALUE(c.name), total = SUM(s.amount)
        CrossApply
          Filter c.ckey IN UNNEST(@arr)
            Scan(Customer c)
          Filter s.ckey = c.ckey AND s.type = 'global'
            Scan(Sales s)
```

* Everything but the final Top runs on the shards. At most 5 rows per shard cross the network
* What made it cheap is the interleaving the schema chose. Without it, Sales has shards of its own, step 3 fails, and the `CrossApply` becomes a distributed join (below)

## At run time: which shards, which servers

* The union holds `ckey IN UNNEST(@arr)`. Before calling anyone, evaluate it with this run's parameters into key ranges (range extraction, below)
  * `@arr = [7, 412, 7, 950]` → remove duplicates → points 7, 412, 950
  * intersect with the shard map → S1, S2, S4. S3 is never contacted: *shard pruning*
* Safe: the sharding-key filter is implied by the filters of the scans below the union, so every row the subquery could return lies in an extracted range
* If the ranges cover the whole table: one call per *Paxos group* rather than per shard. G1 hosts S1 and S3: one call for both, 3 calls instead of 4
* Calls go out in parallel, up to a cap that keeps one query from swamping the servers; big shards can be split further into sub-shards
* Shard affinity: if a target shard is hosted on this server, run the subtree in-process. No call at all
  * common: many queries read one object (a user and its interleaved rows) under one sharding key, and most such row sets fit in one shard

## Joins across shards: DistributedApply

* What interleaving does not cover: a global secondary index. It is its own table, sharded on the indexed column

```
CREATE INDEX CustomerByCity ON Customer(city)
  -- stored as a table with key (city, ckey), sharded on city

Q2:  SELECT c.* FROM Customer c WHERE c.city = 'Denver'
```

* On one machine Q2 is not even a join: last lecture's access path through a non-clustered index, about a page fetch per row found
* Here the index is a table of its own, so the access path becomes a join, and a union sits over each scan:

```
CrossApply
  DistributedUnion(CustomerByCity)
    Scan(CustomerByCity)  city = 'Denver'                → ckeys, from one index shard
  DistributedUnion(Customer)
    Scan(Customer)        ckey = (the input row's ckey)  → one row, in any Customer shard
```

* The map's union cannot be pulled up: the two tables are sharded differently. So it fires once per input row: `C = C_outer + outer_rows × C_inner`, and `C_inner` is a call to another machine, not a page fetch
  * 1,000 Denver customers: 1,000 calls, one after another
* The other plan, scan all of Customer and filter on city, reads the whole table, which is what the index was for
* Fix: send the input rows in batches. One join becomes two (the paper's Figure 2): a distributed one that ships batches, and a local one that applies each row of a batch on the shard

```
CrossApply(input, DistributedUnion(map))     one remote call per input row
  ⇒  DistributedApply                        the apply and the union, fused into one operator
        Batch(input) => $batch               on the caller: cut the input rows into arrays,
                                             each one named $batch in turn
        CrossApply(Unnest($batch), map)      shipped to each shard the batch touches;
                                             Unnest turns $batch back into rows
```

* For each batch, before calling (the paper's four steps)
  1. evaluate the map's sharding-key filter (`ckey =` the row's ckey) on each row of the batch → key ranges per row
  2. merge them into one set
  3. intersect with the shard boundaries → the shards to call
  4. per shard, keep only the batch rows whose ranges overlap it; a row whose range spans two shards goes to both
* Trace, a batch of five ckeys from the index:

```
batch  7, 300, 310, 820, 990

S1 [−∞, 250)    ← 7
S2 [250, 500)   ← 300, 310
S3 [500, 750)     none: not called
S4 [750, +∞)    ← 820, 990

3 calls, in parallel, instead of 5 in a row
```

* Calls per batch = shards touched, not rows. Often the whole input fits in one batch: one round of calls
* Last lecture's Table 2 again: a non-clustered index pays per row, a clustered one per page. Batching makes the index pay per shard touched
* On the shard, the per-row map seeks to its keys instead of scanning
* Q2's final plan, two levels of distribution (the index's union pulled above the apply, by the Apply row of the rules):

```
DistributedUnion(CustomerByCity)   sharding-key filter: city = 'Denver'     → the index shard(s) with Denver
  DistributedApply                                                        runs on each such index shard
    Batch( Scan(CustomerByCity) city = 'Denver' ) => $batch
    CrossApply(Unnest($batch), Scan(Customer) ckey = (the row's ckey))     on each Customer shard called
```

* Where it fits: the input is small, and the join condition constrains the map table's sharding key (equality or range). Index → base table, foreign key → parent; inner, left outer, and semi joins
* Where it does not: two big tables joined on a non-key column. Nothing to route on, so every batch goes to every shard. The paper calls distributed joins "too large to cover exhaustively" and shows only this one

## Getting the query in and the rows out

* Single consumer: one client reads all the results
  * a root that holds none of the data costs an extra hop: a point lookup that needs one cross-machine call makes two
  * *location hint*: route the query to the data, not to any root
    * first run: take the outermost union's sharding-key filter, written in terms of the parameters; cache it on the client as a pattern
    * later runs: plug in the parameters, get a key, address the query to that key. The coprocessor framework finds the server

```
SELECT c.*, s.* FROM Customer c JOIN Sales s ON c.ckey = s.ckey WHERE c.ckey = @k
  hint: Customer key = @k              to the server holding customer @k; Sales is
                                       interleaved, so the whole query runs there

SELECT c.* FROM Customer c WHERE c.city = @city
  hint: CustomerByCity key = @city     to the server holding that index shard
```

* The paper's examples use tables named Parent, Child, and Index; the shapes are the same
* Parallel consumer: results too big for one machine, e.g., a MapReduce-style pipeline that joins Spanner data with other data
  1. send the query and the parallelism wanted; get back opaque *partition descriptors*
  2. workers each run one descriptor, calling the shards directly. Together they return the single-consumer result, up to order (all at one snapshot timestamp)
  * Customer's 4 shards, 2 partitions: each descriptor covers 2 shards
  * only for *root-partitionable* queries: the compiled plan's root is a `DistributedUnion`, so a descriptor is just a subset of its shards
  * Q1 is not: its final `Top(5)` sits above the union, and no single worker can do it

## Range extraction: which keys can a predicate touch?

* Every step so far needed it: the union's shard list, the per-row ranges of a `DistributedApply`, the seek in place of a scan on each shard
* Locking needs it too: which keys a read-write transaction must lock
* Done at run time: parameters, and the values earlier scans read, are known only then
* The paper's example

```
Documents   PRIMARY KEY (ProjectId, DocumentPath, Version), sharded on ProjectId

SELECT d.* FROM Documents d
WHERE  d.ProjectId = @param1
  AND  STARTS_WITH(d.DocumentPath, '/proposals')
  AND  d.Version = @param2

@param1 = P001, @param2 = 2017-01-01; ten documents under /proposals, many versions each
```

* (The paper's text calls the third key column Timestamp once, and Figure 3 labels Scan2 DocumentId. Both are slips)

## Strawman: one start key, one stop key

* Last lecture's index scan reads one key range, from a start key to a stop key
* By last lecture's definition all three factors match: they are sargable, and their columns form a prefix of the key. But only equalities on the leading columns, then one range, narrow the scan. That fine print is new today
* Here: `ProjectId = P001` (equality), then `DocumentPath` in `['/proposals', '/proposalt')` (a range). `Version = @param2` comes after the range: tested on every version read, narrowing nothing
* With 1,000 versions per document, 1,000 times the rows needed
* Wanted: for each distinct `DocumentPath` in the range, one seek to `(P001, path, 2017-01-01)`

## Key columns one at a time: correlated self-joins

* Pin one key column, then constrain the next given its value: a nested loop over key columns
* The compiler rewrites the filtered scan into a chain of `CrossApply`s over the same table, one scan per key column (the paper's Figure 3). The lowercase `filter` and `emits` lines are each scan's own attributes, not children

```
CrossApply
  CrossApply
    Scan1(Documents.ProjectId)
      filter  ProjectId = @param1
      emits   @project_id              no read: the filter pins the value
    Scan2(Documents.DocumentPath)
      filter  ProjectId = @project_id AND STARTS_WITH(DocumentPath, '/proposals')
      emits   @document_path           one per distinct path
  Scan3(Documents.*)
    filter  ProjectId = @project_id AND DocumentPath = @document_path
            AND Version = @param2
    emits   the rows                   one seek per path
```

* Scan2 skips: find the first path under the prefix (`/proposals/doc1`), emit it, then seek straight past all its versions to the next path in key order (`/proposals/doc10`: strings compare character by character, so doc10 sorts before doc2; the paper's text says doc2, which holds only if there is no doc10)
* Cost: about two seeks per document instead of one row per version
  * if every document had one version, plain scanning would win: the seeks would cost more than they skip

## Three uses, three prefix lengths

```
distribution   (P001)                                   1 key column: which shards to call
seek           (P001, /proposals/doc1, 2017-01-01),     3 columns: what Scan3 reads
               (P001, /proposals/doc10, 2017-01-01), ...
lock           key columns:      (P001, /proposals)     2 columns, one range
               non-key columns:  the seek ranges
```

* Shorthand, as in the paper: `(P001)` is every key starting with P001; `(P001, /proposals)` is ProjectId = P001 with DocumentPath in `['/proposals', '/proposalt')`, the strawman's one range. Seek tuples are full keys
* Seek ranges need a read to find them: which documents exist under `/proposals` is in the table, not in the query (Scan2)
* Spanner locks per column
  * the key columns of a range stand for which rows exist there: an insert or delete in the range conflicts
  * a non-key column of a row stands for its value: an update of that row conflicts
* Why the key-column lock covers the whole range (our reading): the answer also depends on which documents are *absent*. Oct 19's 2PL locks the items read; `/proposals/doc11` is not an item yet, so lock the range its insert would land in. That is a *phantom*, Nov 11
* Snapshot reads lock nothing; for them the ranges say which prepared, uncommitted writes to wait out, rather than every one in the Paxos group (Oct 19's `t_safe`; a refinement already in the 2012 paper)
* Trade-off the paper leaves open: fine ranges read and lock less, but cost more to compute and to hold

## Messier predicates

* Normalization at compile time
  * push NOT down to the leaves: `NOT(a OR b)` → `NOT a AND NOT b`. Linear in the size of the predicate
  * isolate the key column in each leaf: `1 > k` → `k < 1`, `NOT(k > 1)` → `k <= 1`
  * enumerate small integer ranges: `k BETWEEN 5 AND 7` → 5, 6, 7, three points, so the *next* key column can be pinned per point (the Version problem again). `k BETWEEN 5 AND 7000` is not enumerated: read the `k` values that exist, as Scan2 did
  * leaves too complex for extraction (subqueries, expensive functions, arithmetic) constrain nothing: their interval is (−∞, +∞). They stay in the post-filter
* No conversion to CNF or DNF
  * last lecture: WHERE in CNF, and only a sargable factor (`column op value`) could start or stop an index scan
  * `(k1 = 1 AND k2 = "a") OR (k1 = 2 AND k2 = "b")` is one boolean factor headed by OR: not sargable, so System R reads every row and tests it
  * normalizing to dig out sargable pieces can blow up: `(a1 OR b1) AND ... AND (an OR bn)` has 2ⁿ DNF terms
  * Spanner keeps the AND/OR tree (NOT pushed down) and extracts ranges from it directly. The example above becomes two seeks, (1, "a") and (2, "b"), fully absorbed
* Post-filter: when the scans cannot absorb the whole predicate, what is left is checked on each row they emit
  * the original predicate would always do as the post-filter; it just re-tests what the seeks already guarantee

## The filter tree

* A table with key (k1 INT64, k2 STRING) and another column `value`; the predicate is below. Rewritten as before: Scan1 over k1, Scan2 over k2
* One run-time structure (the paper's Figure 4), shared by all the correlated scans, used twice: compute ranges, then post-filter
* The scans drive it: Scan1 asks it for k1 ranges and emits 1, then 2; for each value, Scan2 asks for k2 ranges with k1 bound
* Ranges, one key column at a time, bottom up
  * a leaf gets the interval it allows on that column; a leaf that says nothing usable about the column gets (−∞, +∞)
  * AND intersects its children's intervals; OR takes their ∪
  * once earlier key columns are fixed, a leaf they decide gets its exact value: false → empty, true → (−∞, +∞)
    * under AND: empty empties the AND (prune the branch); true drops out
    * under OR: empty drops out; true makes the whole OR (−∞, +∞)
    * `k1 = 1 OR k2 = "a"`, given k1 = 1: every k2 qualifies. Dropping the true leaf would leave ["a", "a"] and lose the row (1, "z")

```
(k1 = 1 AND k2 = "a" AND REGEXP_MATCH(value, @param)) OR (k1 = 2 AND k2 < "b")

                            OR
                 /                       \
              AND                         AND
       /       |        \               /      \
   k1 = 1   k2 = "a"   REGEXP_MATCH   k1 = 2   k2 < "b"

k1 ranges
  left AND:   [1, 1] ∩ (−∞, +∞) ∩ (−∞, +∞)      = [1, 1]
  right AND:  [2, 2] ∩ (−∞, +∞)                 = [2, 2]
  OR:         [1, 1] ∪ [2, 2]                   = [1, 2]   integers: adjacent points merge

k2 ranges, given k1 = 1
  left AND:   k1 = 1 true, drops out;  ["a", "a"] ∩ (−∞, +∞) = ["a", "a"]
  right AND:  k1 = 2 false → empty, pruned
  OR:         ["a", "a"]

k2 ranges, given k1 = 2
  left AND:   k1 = 1 false → empty, pruned
  right AND:  (−∞, "b")
  OR:         (−∞, "b")

result: seek (1, "a") with REGEXP_MATCH as a post-filter; range k1 = 2, k2 < "b"
```

* Post-filtering a row from the seek at (1, "a"): `k1 = 1` and `k2 = "a"` are already known true (memoized), the right branch is already pruned, so only `REGEXP_MATCH` is evaluated
* Rows from the k1 = 2 range: the range itself guarantees the right branch, so nothing is left to evaluate (our reading; the paper shows only the (1, "a") case)

## Why extraction is safe

* Each leaf's interval contains every value that could make the leaf true. "Don't know" is (−∞, +∞)
* ∩ and ∪ keep that property: if each child's interval covers the values that make the child true, the AND's intersection and the OR's union cover theirs
* Fixing earlier key columns keeps it too: a decided leaf is exactly empty or exactly (−∞, +∞)
* NOT would not: the complement of a too-big set is a too-small set. Hence NOT goes to the leaves first; a NOT inside a leaf that cannot be analyzed leaves that leaf at (−∞, +∞)
  * last lecture's Table 1 took 1 − F for NOT: an estimate may err either way. A guaranteed superset may not
* So extracted ranges ⊇ the rows that satisfy the predicate, and the post-filter removes the extra. The answer is exact
* Too big is the safe side every time
  * distribution: an extra shard runs the subquery and returns nothing
  * seek: extra rows are read, then filtered out
  * lock: extra locks cost concurrency, not correctness
  * too small would lose rows, or miss a conflicting write
* Often the ranges are exact (Q1, Documents). Approximate on purpose otherwise: isolating a key column can mean solving polynomials, with diminishing returns. The paper calls distribution-range extraction a heuristic, though a heavily used one

## Failures in the middle of a query

* A long query reads 50 shards at one snapshot timestamp and streams a million rows to the client over half a minute. The client has consumed 400,000. Then:
  * a server it reads from restarts. Spanner is always upgrading somewhere: the paper reports "very few moments" when no zone was being upgraded
  * a shard it reads splits, and half moves to another Paxos group (*data movement*)
  * a later or retried call lands on a replica that is overloaded, or not yet caught up to the query's timestamp (`t_safe < s_read`). Rather than block, give up and retry at another replica (*distributed wait*)
* Strawman: return an error, the client retries from the start
  * every application writes a retry loop with backoff, and those loops are a known source of bugs
  * a snapshot transaction whose reads are spread across modules of an application cannot be retried cleanly
  * a query that runs about as long as the time between failures may not finish before its snapshot is garbage-collected, retry loop or not
  * one bad shard sets the latency of a query that touched 50
* Strawman: make results durable. Buffer the results, or each operator's intermediate output, in storage as reliable as the database, and resume from there
  * every query pays latency to protect the few that fail
* Strawman: rewrite the query so it can resume. Tag every intermediate row with an identity column, or page by key (`WHERE col > @last ORDER BY col LIMIT n`)
  * the paper: identity columns "looked impossible in the general case" (our guess at why: aggregates and joins make rows with no identity of their own)
  * paging adds a sort the query did not otherwise need
* Insight: the query processor knows how far it got. Have it say so, cheaply, with every batch of results

## Restart tokens

* Every batch of results carries an opaque *restart token*. To resume, the client library resends the original request plus the last token it received
  * the calls between Spanner servers (a union's calls to its shards) are restartable the same way
* Contract: the rows before and after a restart together are a correct answer, none returned twice. No promise that it is the answer an uninterrupted run would have given
  * `SELECT * FROM T LIMIT 100`, restarted after 30 rows: 70 more rows, none repeated, not necessarily the 70 the first attempt would have sent
* Streaming: nothing is written to persistent storage for the sake of restarts
* Simplest case, a range scan with filters and projections: token = last primary key returned + the snapshot timestamp. Resume = seek just past that key, at that timestamp
* Why the timestamp
  * the part after the restart must read the same state as the part before. A scan stopped at key 50 resumes at a newer timestamp: a transaction that meanwhile deleted the row at key 10 (returned) and reinserted its data at 90 (not yet reached) makes it show up twice; one that moved a row from 90 to 10 makes it vanish
  * every replica with `t_safe` past it returns the same data (Oct 19), so the resume may run on any of them, even in another datacenter
  * the limit: old versions are garbage-collected. "Snapshot data has been garbage collected" is an error the client still sees, as is "deadline exceeded"
* Covers strong reads too: their timestamp is picked once, at the start, and travels in the token. Snapshot queries, strong ones included, are most of Spanner's queries
* Read-write transactions do not get this
  * their reads have no snapshot timestamp: they read the latest data, which stays valid only while their locks are held
  * locks taken as the transaction runs live only in leader memory (the prepare record is what goes through Paxos, Oct 21). A failure "often" loses them, and another transaction may then change rows already read
  * so: abort, and the client retries, as it already must after a wound-wait abort

## What makes tokens hard

The paper names the problems and defers the mechanisms to another paper. What a token has to capture:

* Resharding: the server that resumes may own a different range from the one that stopped

```
before   server A serves [20, 30) at ts 105       returned keys 20 .. 24; A restarts
token    ts 105; [20, 30) done up to key 24
after    [10, 40) is now one shard, on server B
         the resume, still addressed to [20, 30), reaches B: seek just past 24, stop at 30, ts 105
```

* "shard 3, 400 rows done" would mean nothing on B: progress must be recorded in *key space*
* Non-determinism: row order depends on which shard answers first and how much memory a blocking operator got; a floating-point SUM's value depends on the order of its inputs
  * so "rerun and skip the first 400,000 rows" fails: a rerun produces a different sequence
  * each source has to be recorded or compensated; for a union, say, one key position per range it called instead of one row count (our example)
* Server versions: the resume may land on the next release
  * token format versioned, readable by the previous and the next release
  * same plan: a query started on version N resumes with N's operator tree, even if N+1 would compile the SQL differently. The token is positions inside N's operators; another tree could not tell which rows were already returned
  * operators read their part of a token the same way across versions. One rerun from scratch (no token part of its own) must still emit rows in the order its parent's token counted on; a release may change that order only together with a new token version
* Engineering cost: token versioning, processes that force explicit versioning on incompatible changes, a framework to catch incompatibilities

## What restarts bought

* The first strawman's problems, gone: no retry loops (set a realistic deadline instead), little work redone, forward progress for long queries, one bad shard costs one resume
* Streaming instead of paging: no `ORDER BY ... LIMIT ... OFFSET` just to page; the server holds no resources while the client pauses
* Rolling upgrades: a release reaches every machine over a week or so, several versions live at once, queries undisturbed. Why Spanner can ship a fix quickly
* Simpler internals: an overloaded server, or one with a problem shard, returns "retry", and the request resumes on another replica with little lost

## Why inside, not beside

* What each piece got from being inside the store (our summary)
  * DistributedUnion: the current shard map, and the right to run a subtree in the process that holds the shard (affinity, location hints). A SQL tier beside the store adds a hop
  * interleaving: the parent-child join runs inside the shard. A tier beside the store can read the co-located range in one call, but must ship all of it
  * range extraction: one predicate analysis feeds routing, storage seeks, and the lock manager
  * restarts: progress in key space at a snapshot timestamp, on every call, server-to-server ones included, across resharding and releases
* The paper's verdict is milder: loose (F1) and tight designs both work, "even simultaneously" on the same core, and "a detailed exploration of the pros and cons of these designs is still outstanding"
* SQL vs NoSQL is a stack, not a choice: scale and manageability (a key-value store, Bigtable) → cross-row ACID (a transactional key-value store, "the lowest common denominator") → SQL on top, loose or tight. "The SQL vs. NoSQL dichotomy may no longer be relevant"
* The core lecture ends here. The next three sections are optional: run on if time is left, otherwise leave them for reading

## One SQL across Google

* Spanner, F1, and Dremel (BigQuery outside Google) each had their own SQL: the same query could differ in syntax, NULL handling, type coercion, name scoping
* An open-source front end such as Postgres's was rejected: Google's data is Protocol Buffers, wanted as first-class SQL types; and a UTF-8 `STRING` instead of `CHAR`/`VARCHAR`
* Instead, one ANSI-based dialect, Standard SQL, with `ARRAY` and `STRUCT` for nested data, and shared pieces (the GoogleSQL library): one front end (parse, resolve names, check types → a *resolved AST* that each system translates into its own algebra), one scalar-function library
* Tests: hand-written compliance queries per feature, plus millions of random queries a day, on random schemas and data, compared against a reference engine
  * reference results are annotated: imprecise (a floating-point AVG), ordered or unordered
  * a query with no unique answer (`LIMIT` without enough `ORDER BY`) is not checked, only run: about 10% of random queries in unit tests

## Storage that suits SQL: Ressi

* Spanner started on Bigtable's SSTables (Sep 21: RocksDB's files descend from the same design): built for schemaless data and large strings, self-describing and so redundant, slow to walk one column across rows. Scale-out hid the cost, but they "leave a lot of performance on the table"
* Ressi, entering production in 2017: still an LSM tree whose layers are compacted (Sep 16), with a new file format
  * blocks in key order; inside a block, one array per column (the PAX layout)
    * a point lookup for the newest values reads one block
    * a scan of two columns still loads the same blocks: PAX changes the layout inside a block, not which blocks are read. The gain is mostly CPU: walk two dense, same-typed arrays instead of decoding every cell; typed arrays also compress better, so blocks hold more rows (our reading)
    * a pure column store would cut the bytes a scan reads, but a point lookup would then read one block per column
    * Aug 31: TiDB answered OLTP plus analytics with two copies, rows in TiKV and columns in a TiFlash learner. Ressi keeps one copy and splits the difference inside each block
  * I/O is saved by splitting files
    * an *active* file holds only the newest value of each cell, an *inactive* file the older versions. A read of the latest data never loads old versions
    * large (multi-page) values live in separate files, read only when needed
  * interleaved child rows go in or near their parent's block; operators work on compressed vectors directly

```
one block, three Customer rows

row-major (SSTable)          PAX (Ressi)
  7, Ann, Denver               ckey:  7, 8, 9
  8, Bob, Boston               name:  Ann, Bob, Cy
  9, Cy,  Denver               city:  Denver, Boston, Denver
```

* Changing the format of a live, replicated database: reuse the machinery that moves shards
  * change a Paxos group's specification (which includes each replica's storage format), then *move* its data to a new group, converting on the way; the old group serves until the new one takes over
  * group by group, reversible: to Ressi, to mixed replicas (to compare), or back to SSTables
* The shard moves that forced DistributedUnion and restarts also made a storage migration routine

## Lessons the paper reports

* Scale first. Horizontal scaling got Spanner deployed; per-machine speed (Ressi) came later
* SQL beat the key-value API for anything past simple lookups: SQL volume grew 2× in the year before the common dialect, 5× in the year after, and queries grew more complex
* Read your own writes: unsupported, since a transaction's writes are buffered at the client until commit (2012 paper). Little demand inside Google, but other SQL systems allow it. Cloud Spanner's DML has since added it
* TrueTime's ε kept shrinking
  * a read at `TT.now().latest` may wait about ε for replicas' `t_safe` to pass it (our reading); a query analyzed for the oldest timestamp that still sees every change it needs (Oct 19's one-group aside, for every group) waits less and can use more replicas
  * with small ε, reading at `TT.now().latest` is good enough, and the analysis is skipped
* Many physical design knobs (placement, replication, protocol buffers vs interleaved tables, vertical partitioning): Spanner engineers review new schemas
* Optimizer stability: a new release about every two weeks, and a changed plan can swing latency by an order of magnitude. Hard to improve the optimizer without hurting someone
* One system for OLTP, analytics, and text search is still what customers want most, despite the critique of "one size fits all"
* What a DBMS had to unlearn for this scale (the conclusions)
  * it runs only as a service: one team operates every database
  * no static partitioning; calls go to key ranges, not machines
  * several replication configurations, chosen per workload; one shard can be down while the rest of its table serves
  * metadata (schema versions, placement) is managed as data: there is too much of it to keep any other way (TiDB keeps its Region map in PD, Aug 31)
  * the control plane (health, SLOs, placement, lock conflicts) is a database application of its own
* Advice: once a scalable, available storage core exists, go relational early

## The design, assembled

1. Joins as Apply; a `DistributedUnion` over every scan, pulled up while partitionability holds; Top and aggregates split into local and final parts
2. Interleaving makes parent-child joins local; `DistributedApply` batches the rest
3. At run time: prune shards with the sharding-key filter, one call per Paxos group, in-process when local; location hints; root-partitionable queries split across consumers
4. Range extraction for distribution, seek, and lock: correlated self-joins over key columns, a filter tree that computes ranges and post-filters; a superset, sometimes too big, never too small
5. Restart tokens on every batch: snapshot timestamp, progress in key space, the same plan across releases
6. Optional part: one dialect across Google, checked against a reference engine; Ressi, PAX blocks with the newest versions apart, migrated by moving data between groups

## Where the idea went

* Cloud Spanner's public API exposes these pieces: streamed results carry a `resume_token`, and `PartitionQuery` is the parallel-consumer API, for root-partitionable queries only
* The GoogleSQL front end was open-sourced as ZetaSQL (2019) and renamed GoogleSQL in 2026
* F1 Query (VLDB 2018): F1's engine as a stand-alone, federated service over Spanner, Bigtable, and files. The loosely coupled path, kept
* TiKV's *coprocessor* (the Aug 31 paper) runs pushed-down operators; Spanner's coprocessor framework routes calls by key range. Same word, different job
* CockroachDB (Nov 16): range-sharded key-value storage with SQL in the same process; predicates become key spans, and plans are shipped to the nodes holding the ranges
* Next: Spanner's default is strict serializability (Oct 19's external consistency). Most SQL systems default to something weaker, and Spanner itself now also offers repeatable read, built as snapshot isolation. Nov 11: what the weaker levels let through, phantoms included

## Questions to review

* Why can't Spanner split a query by the shard map at compile time, as a classic parallel database does? Give three reasons
* State partitionability. Which of these pass: Filter, Project, `GroupBy(ckey)`, `GroupBy(type)`, Sort by `ckey`, `Top(5)` by `ckey`, `Top(5)` by total? What happens to the ones that fail?
* `GroupBy(ckey)` would stay partitionable under hash sharding on `ckey`; Sort by `ckey` would not. Why?
* Write SUM, COUNT, AVG, and MAX as `OpFinal ∘ OpLocal`. Why can't `COUNT(DISTINCT type)` ship one number per shard, as COUNT does? What must its OpLocal ship instead, and how big can that get?
* Why do the two unions in Q1 merge? If Sales were its own table sharded on `ckey`, not interleaved, which step of the Q1 walk fails, and what does the `CrossApply` become?
* On one machine, Q2 was an access path through a non-clustered index. Why does it become a join in Spanner, and what does batching change in `outer_rows × C_inner`?
* What does a location hint cache, and why can it be computed once per query text rather than once per run?
* Which queries can use the parallel-consumer API? Is Q1 one? `SELECT c.name, s.amount FROM Customer c JOIN Sales s ON c.ckey = s.ckey WHERE s.type = 'global'`? `SELECT type, SUM(amount) FROM Sales GROUP BY type`?
* For `Documents`, why can't one start/stop key pair answer the query well? How do correlated self-joins fix it, and when is a plain scan cheaper?
* Why is the key-column lock range a whole range, while non-key columns are locked only on the rows read?
* Why push NOT to the leaves before interval arithmetic? Why not convert to CNF or DNF first?
* Filter tree, key (k1, k2): compute the ranges for `(k1 = 3 AND k2 > "m") OR (k1 = 3 AND k2 = "c") OR (k1 = 4 AND LENGTH(k2) = 2)`, and say where a post-filter is needed. Then for `k1 = 1 OR k2 = "a"`: k1 ranges, k2 ranges given k1 = 1, and given k1 = 2
* Extracted ranges may cover too many keys, never too few. Why is that the right direction for distribution, seek, and lock ranges each?
* A scan's restart token is a key and a timestamp. Why the timestamp? Why can't it say "shard 3, 400 rows done", and what does it say instead?
* Why do restarts work for snapshot queries, strong reads included, but not for read-write transactions?
* Why must a query restarted on a newer server release still run its old plan?
* Name two things the tightly coupled design does that a SQL tier beside the store cannot do as cheaply. What is the paper's own verdict on loose vs tight?
* (Optional part) What does PAX save over a row-major block, and what does it not? How did TiDB answer the same OLTP-plus-analytics problem?
* (Optional part) Shard movement between Paxos groups forced two designs in this paper and made a third cheap. Which three?
