
# TiDB

Paper: Huang et al., *TiDB: A Raft-based HTAP Database* (PVLDB 2020, PingCAP).

Last time: Postgres — one machine, heap + indexes, extend the type system. Today: how do you get SQL + ACID when the data no longer fits on one box? The full Raft paper is Wednesday; below is only the background TiDB assumes.

## A little history

### The problem they were selling
* LAMP in 2000s: Linux, Apache, MySQL, PHP
  * e.g. Facebook
* Mid-2010s “NewSQL”: people had outgrown one MySQL / one Postgres
  * writes do not scale on a single primary
  * the industry answer was shard in the app (proxy, `user_id % N`)
* Bigtable / Spanner showed a prettier picture: range shards + consensus + SQL
  * not something you could download and point JDBC at
* PingCAP (~2015, China): a Spanner-shaped system that existing apps can speak to

### Why the MySQL *wire*, not Postgres
* Who they were selling to. 
  * China internet was LAMP: MySQL + sharding proxies, not Postgres
  * Huang (CTO): MySQL
* CockroachDB / Yugabyte later took the Postgres wire — different home market

### Why not MySQL + a distributed storage engine?
* first week they tried “MySQL + a distributed storage engine”
  * dropped it: MySQL’s optimizer / executor are single-node
* So: new SQL layer (Go) + TiKV (Rust) + MySQL on the wire
  * pitch: keep the client; hide the shards
  * reuse drivers, ORMs, `mysqldump`, DBA tools.

Takeaway: they cloned Spanner’s architecture, not MySQL’s storage. MySQL is the front door.

## Architecture

Three processes. You deploy all of them. A lone TiKV is not a database.

```
app  --MySQL proto-->  TiDB SQL (stateless)  -->  TiKV (rows)
                              |                    ^
                              +----->  PD  --------+
```

* TiDB SQL: parse, optimize, execute. No durable rows. Scale by adding nodes
* PD (Placement Driver): control plane — where is this key, who should move, timestamps
* TiKV: data plane — the shards, Raft, RocksDB

### From a table to a key-value map
No Postgres heap file. The whole cluster is one ordered KV map:

```
key   = {tableID, rowID}     (rowID often the PK)
value = {col0, col1, …}
```

Secondary indexes are more KV pairs (index key → primary key).  
The SQL engine is a translator from SQL to KV reads/writes.

### Raft background (for this lecture)
* The network is asynchronous
  * messages can be delayed, dropped, reordered; the network can partition
  * no shared clock; a node cannot tell crash from “slow”
* Split brain: two servers both think they are primary and accept writes
  * replicas diverge; no single copy is truth
* Consensus (Raft): agree on a log of commands so everyone applies the same sequence
  * leader + majority (quorum)
  * any two majorities overlap → two leaders cannot both commit
  * a minority can be down or partitioned; they just do not get to decide
* Log: an array of log entries
  * each entry has a command or a group of commands
  * committed = a majority has the entry, and it will not be forgotten
* Wednesday: the full details of Raft


### Region = range + Raft group
Cut the map into Regions: contiguous key ranges.

* paper default: ~96 MB. 
* one Region = one Raft group (usually 3 peers; one leader serves reads/writes)
* many groups on one machine = multi-Raft
* PD places groups so replicas sit on different TiKV nodes (and AZs)

Why many Raft groups, not one group per machine?

* Raft group = unit of placement and failover
* Region A’s copies can live on `{1,2,3}`, Region B’s on `{1,4,5}`
* move / split a hot range without shipping the rest of the node
* many leaders ⇒ write parallelism

Split / merge are themselves Raft commands (metadata). Idle groups heartbeat more slowly.

PD vs TiKV:
* PD has the cluster-wide Region map + TSO. 
* TiKV has only local peers. It does not answer “which node has this key?” for the whole cluster

### TiKV write / read path (OLTP)
Naive Raft is one request at a time (append, ship, wait majority, apply, reply). Leader is the bottleneck.
Tricks in the paper:
* append locally in parallel with shipping to followers
* batch log RPCs
* pipeline: don’t wait for ack before the next batch
* async apply on another thread once committed

Linearizable reads without a dummy log entry per read:

* Read index: record commit index, heartbeat to prove you are still leader, wait until applied
* Lease read: during a lease, no extra RPCs (clocks must be close enough)
* Follower read: follower asks the leader for a read index, then waits — spreads hot Region reads

### Transactions
* A transaction: a group of reads/writes that should commit all-or-nothing and look isolated from other txns
* One SQL txn can touch many Regions — i.e. many Raft groups
* Raft only orders the log inside one Region. It does not run the SQL txn
* So you still need:
  * timestamps to order txns (PD’s TSO = timestamp oracle)
  * a commit protocol across Regions (two-phase commit; the paper uses Google Percolator)
* Locks live next to the keys in TiKV, not in a central lock manager
* MVCC: keep old versions so a reader can see a consistent snapshot


## HTAP: OLTP + OLAP

OLTP and OLAP want different layouts and different machines.

* OLTP (online transaction processing): many small reads/writes, indexes, latest row
  * “debit this account,” `SELECT … WHERE pk = ?`
* OLAP (online analytic processing): scan lots of rows, few columns, aggregations / joins
  * `SUM(bal) GROUP BY region` over the whole table
* NewSQL (Spanner, CRDB, TiKV) is the first, not the second
* Stonebraker: “one size does not fit all” — two systems are expensive, and the warehouse is stale

HTAP extra requirements (on top of NewSQL):

* Freshness: how recent is the analytic replica?
* Isolation: OLAP must not crush OLTP (and vice versa)

### Why the obvious designs fail
* ETL (extract / transform / load) every few hours: dump OLTP into a warehouse; consistent-ish, not fresh
* Stream the log into a second system: fresher, no global txn story
* One in-memory engine (HyPer, HANA, MemSQL): fresh, same cores/RAM
  * why it fails: analytics steal CPU / cache / memory bandwidth from txns (no resource isolation)
  * CH-benCHmark: HANA OLTP ~3× slower with analytics; HyPer ~5×
* More Raft *followers*: still in the quorum
  * leader waits on a larger majority → OLTP slower
  * a follower can still become leader → not a dedicated OLAP box

Need: a replica that is up to date, columnar, and not in the write quorum.

### Idea: Raft *learners* + a column store
* Standard group: leader + followers (row, OLTP) on TiKV
* Add a learner (TiFlash) on other machines:
  * asynchronously tails the leader’s log
  * not in the election / quorum → leader does not wait on it at commit
  * at read time, catch up to a snapshot timestamp, then scan
* Apply the log into a column store (not another row store)
  * drop aborted txns, decode rows, transpose to columns
  * cannot rewrite huge compressed column files on every small write; a plain LSM makes analytic reads merge many files
  * so: stable columnar chunks (good for `SUM` / `COUNT`) plus a small delta of recent updates (paper: DeltaTree)
* Freshness = log lag (paper: often < 1 s). Isolation = other machines.

### Row store vs column store
A row store keeps a tuple together. A column store keeps a column together.

Row store (Postgres heap, InnoDB, TiKV): on disk you see

```
[id=1, name=Ann, bal=10] [id=2, name=Bob, bal=20] …
```

* one I/O brings the whole row
* point lookup / UPDATE of a few rows is cheap
* `SUM(bal)` still reads `name` (and everything else) off the page

Column store (MonetDB, C-Store/Vertica, Parquet, TiFlash): on disk you see

```
id:   [1, 2, 3, …]
name: [Ann, Bob, …]
bal:  [10, 20, …]
```

* `SUM(bal)` reads only the `bal` file
* values in one column are similar → compress well
* engines run vectorized loops on arrays of one type
* reconstructing “row 17” gathers from many files; an UPDATE may touch every column file

So OLTP wants rows; analytics (few columns, many rows) wants columns.
TiDB’s bet: same logical table, two physical layouts, glued by the Raft log.


### Query processing: SQL vs logical plan vs physical plan

* SQL: syntax and sugar (`IN` / `EXISTS`, views, `SELECT *`, join written as comma-FROM)
* Optimizer pipeline: SQL → (many) logical plans → (many) physical plans → run one.
* Logical plan: a tree of relational algebra (`σ`, `⋈`, `π`, `γ`). What to compute, not how
  * binding has happened: `bal` is now `Account.bal` (table id, type)
  * one SQL can rewrite to many equivalent logical trees (join order, unnest a subquery)
  * different SQL can become the same logical join
* Physical plan: algorithms + access paths. How to compute it
  * heap scan vs index vs column store
  * hash join vs index nested-loop vs sort-merge
  * sort vs hash aggregate
* Optimizer:
  * RBO (rule-based optimizer): rewrite with fixed algebraic rules. No “is this table big?”
    * Push a filter below a join, fold constants, unnest a subquery. Produces a nicer logical plan.
  * CBO (cost-based optimizer): estimate cost from stats (row counts, tuple/column size, seeks vs scans, Region count) and pick the cheapest physical plan.
  * TiDB: RBO first (logical), then CBO (physical). Three scan shapes: TiKV row, TiKV index, TiFlash column. A plan can mix stores (index into T on TiKV, hash-join S from TiFlash).

### Evaluation (what to remember)
* TPC-C: OLTP — many small txns (new order, payment, …) on a wholesale warehouse schema; indexed lookups and updates
* TPC-H: OLAP — ~22 long queries (scans, joins, aggregations) on a *different* sales/supply-chain schema (parts, suppliers, orders)
  * a manager asking e.g. revenue by nation, not a clerk ringing up an order (“decision support”)
* CH-benCHmark = TPC-C txns + TPC-H-*style* queries rewritten onto the TPC-C schema (same data, both workloads)
* OLTP: often beats CRDB in their setup
* OLAP: TiKV + TiFlash together often beats either store alone (joins)
* HTAP: extra AP clients cut TP by ≤ ~10%; MemSQL TP drops >5×
* Learner lag: tens–hundreds of ms; ~1 s “fresh enough” on 100 warehouses

## Questions to review
* Why MySQL on the wire if they threw away MySQL’s engine?
* PD vs TiKV: who knows the cluster-wide key → node map?
* Why many Raft groups but one RocksDB per node?
* Region 96 MB: too big? too small? who splits?
* Why encode a row as `{tableID,rowID} → columns` instead of a heap file like Postgres?
* SQL vs logical plan: same query, two join orders — which object changed?
* Row store vs column store: why is `SUM(bal)` cheaper on TiFlash? why is `UPDATE` cheaper on TiKV?
* Percolator vs “one Raft group for the whole txn”?
* Why not ETL? Why not “just add Raft followers”?
* Learner vs follower: who waits at write time? at read time?
* Will the analytic replica always match the leader before the client’s OLTP commit returns?
* Percolator logs on the learner: why compact rollbacks before building columns?
* DeltaTree vs feeding TiFlash from RocksDB: what hurts analytic reads?
* When is an index join on TiKV cheaper than a hash join on TiFlash?
* PD as timestamp oracle: what breaks if PD is partitioned from TiKV?
* “One size fits all is dead” vs TiDB: one system, or two stores glued by a log?

## Extra details

### One RocksDB, many Regions
Default TiKV (the paper, and still Dedicated / self-managed):

* one KV RocksDB per node — all Regions on that machine share it
* one log store per node (paper: another RocksDB; today usually Raft Engine)
* Region id is in the key prefix; the LSM does not know about Raft

Why not one RocksDB per Region? A node has thousands of Regions. RocksDB is heavy (memtables, WAL, open SSTs, compaction). A 96–256 MB tree is a lot of overhead per byte. One shared LSM batches puts into one WAL and one compaction pipeline.

Cost they accepted: compacting or moving one range rewrites mixed SSTs.  
(Later they tried “one RocksDB per Region” — still experimental. Cloud elastic tiers use a new per-Region LSM on S3, TiDB X. Not this paper.)
