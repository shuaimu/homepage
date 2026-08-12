# Spanner SQL: From Key-Value to Relational Database

## Evolution
* Spanner started as a key-value store (2012)
  * Multi-row transactions
  * External consistency
  * Transparent failover across datacenters
* Evolved into full SQL relational database system (2012-2017)
  * Strongly-typed schema system
  * SQL query processor
  * Initially "bolted on" but became tightly integrated

## Key Design Philosophy
* Storage architecture drives query execution design
* Query processor demands drive storage evolution
* Preserve massive scalability while offering full SQL
* Hide transient failures completely from users

## Architecture Overview
* Geo-replicated, sharded relational database
* Horizontal row-range sharding within datacenters
* Shards replicated across geographically separated datacenters
* Paxos consensus for replication (see Paxos notes)
* External consistency via TrueTime
* Snapshot isolation for reads (see isolation notes)
* Two-phase locking (2PL) + two-phase commit (2PC) for transactions
* LSM-tree based storage (evolved from SSTables to Ressi)

### Table Interleaving
* Child tables co-located with parent tables
* Rows with matching key prefixes stored together
* Example:
  ```
  Parent(key, name)
  Child(parent_key, child_key, value) INTERLEAVE IN PARENT

  Storage layout:
  Parent(K1) → [Child(K1,C1), Child(K1,C2), Child(K1,C3)]
  Parent(K2) → [Child(K2,C1), Child(K2,C2)]
  ```
* Shard boundaries preserve co-location

## Background: Database Query Processing Basics

### Relational Algebra
* Mathematical foundation for query processing
* Set of operations on relations (tables)
* Basic operators:
  * **Scan**: Read rows from table
  * **Filter (σ)**: Select rows matching condition
  * **Project (π)**: Select specific columns
  * **Join (⋈)**: Combine rows from two tables
  * **GroupBy/Aggregate**: Group rows and compute aggregates
  * **Sort**: Order rows by column values
  * **Union/Intersection/Difference**: Set operations

### Relational Algebra Tree
* Tree representation of query execution plan
* Leaves: Base table scans
* Internal nodes: Operators (joins, filters, etc.)
* Root: Final result
* Example:
  ```
  Query: SELECT name FROM Customer WHERE age > 30

  Relational Algebra Tree:
       Project(name)
            ↓
        Filter(age > 30)
            ↓
       Scan(Customer)

  Execution: bottom-up
  1. Scan Customer table
  2. Filter rows where age > 30
  3. Project only 'name' column
  ```

### Logical vs Physical Plans

#### Logical Plan
* Abstract representation using relational algebra
* Describes WHAT to compute
* Independent of execution strategy
* Example: `Join(Customer, Orders)`

#### Physical Plan
* Concrete execution strategy
* Describes HOW to compute
* Specifies algorithms and data movement
* Example: `HashJoin(Customer, Orders)` or `NestedLoopJoin(Customer, Orders)`

```
Logical Plan:              Physical Plan:
    Join                      HashJoin
   /    \                    /        \
Customer Orders     Scan(Customer)  Scan(Orders)
                      ↓                ↓
                   Build Hash      Probe Hash
```

### Query Compilation Pipeline
```
SQL Text
  ↓
Parsing → Abstract Syntax Tree (AST)
  ↓
Semantic Analysis → Resolved AST (with types, schema)
  ↓
Logical Optimization → Logical Plan
  ↓
Physical Planning → Physical Plan
  ↓
Code Generation → Executable Query Plan
  ↓
Execution
```

### Common Join Operators

#### CrossApply (Correlated Join)
* For each row from left input, evaluate right expression
* Right side can reference columns from left row
* Concatenates all results
* Example:
  ```
  CrossApply(
    Scan(Customer),
    λc. Scan(Orders WHERE customer_id = c.id)
  )

  For each customer c:
    Find all orders for c
    Output: (c.name, c.id, order.id, order.amount)
  ```

#### OuterApply
* Like CrossApply but emits row even if right side is empty
* Similar to LEFT OUTER JOIN
* Example:
  ```
  OuterApply(
    Scan(Customer),
    λc. Scan(Orders WHERE customer_id = c.id)
  )

  Customer with no orders → (c.name, c.id, NULL, NULL)
  ```

#### Nested Loop Join
* Simple join algorithm
* For each row in outer table, scan inner table
* Inefficient but works for any join condition
```
for each row r1 in Table1:
  for each row r2 in Table2:
    if join_condition(r1, r2):
      output (r1, r2)
```

#### Hash Join
* Build hash table on one input
* Probe with other input
* Efficient for equi-joins
```
Build phase:
  for each row r in Table1:
    hash_table[r.key] = r

Probe phase:
  for each row s in Table2:
    if s.key in hash_table:
      output (hash_table[s.key], s)
```

### Query Optimization Concepts

#### Predicate Pushdown
* Move filters closer to data sources
* Reduces data movement
```
Before:                     After:
  Filter(age > 30)           Join
       ↓                    /    \
     Join          Filter(age>30) Orders
    /    \         ↓
Customer Orders   Scan(Customer)

Fewer rows sent to join!
```

#### Projection Pushdown
* Select only needed columns early
* Reduces data size in pipeline

#### Transformation Rules
* Equivalence rules for rewriting plans
* Examples:
  * Filter(A AND B) = Filter(A) ∘ Filter(B)
  * Join is commutative: R ⋈ S = S ⋈ R
  * Join is associative: (R ⋈ S) ⋈ T = R ⋈ (S ⋈ T)

### Distributed Query Execution Basics

#### Data Partitioning
* Horizontal partitioning: Split rows across servers
* Range partitioning: Rows with keys in [a,b) on server 1
* Hash partitioning: Hash(key) mod N determines server

#### Distributed Operators
* **Partition**: Route data to servers based on key
* **Gather**: Collect data from multiple servers
* **Broadcast**: Send data to all servers
* **Shuffle**: Redistribute data (e.g., for distributed join)

#### Example: Distributed GroupBy
```
Query: SELECT dept, SUM(salary) FROM Employee GROUP BY dept

If data partitioned by employee_id (not dept):

Plan:
  1. Local partial aggregation (each server)
     GroupBy(dept) → partial sums

  2. Shuffle by dept
     Partition data so same dept goes to same server

  3. Final aggregation
     Merge partial sums per dept
```

### Spanner-Specific Concepts

#### Sharding
* Table split into contiguous key ranges
* Each shard = one key range
* Example: Table with keys 1-1000
  * Shard 1: [1, 250)
  * Shard 2: [250, 500)
  * Shard 3: [500, 750)
  * Shard 4: [750, 1000]

#### Coprocessor Framework
* RPC addressed to key/key range, not server
* Framework determines:
  * Which Paxos group owns the data
  * Which replica to use (nearest, most up-to-date)
* Transparently handles:
  * Data movement (resharding)
  * Server failures
  * Network issues

#### Distribution vs Execution
* **Distribution**: Decide which servers to query
* **Execution**: Run query logic on each server
* Distribution operators: DistributedUnion, DistributedApply
* Execution operators: Scan, Filter, Join, etc.

## Query Distribution

### From Logic to Physical Plan

#### Distributed Union Operator
* Core building block for distributed execution
* Inserted above every table scan in relational algebra
* Transforms global scan into distributed local scans:
  ```
  Scan(T) ⇒ DistributedUnion[shard ⊆ T](Scan(shard))
  ```

#### Partitionability Property
* Key requirement for pushing operations down to shards
* For operation F to be pushed down:
  ```
  F(Scan(T)) = OrderedUnionAll[shard ⊆ T](F(Scan(shard)))
  ```
* Operations that can be pushed down:
  * Projection and filtering (always)
  * Sorting/GroupBy when sharding columns are prefix
  * Joins between interleaved tables

#### Multi-Stage Processing
* Operations pushed down even when not fully partitionable
* Example: Top-K query
  ```
  Top(N) ⇒ TopFinal(DistributedUnion[shard](TopLocal(N, shard)))
  ```
* Each shard computes local Top N
* Final stage merges results

#### Example Query Plan
```
Query: SELECT ANY_VALUE(c.name), SUM(s.amount) total
       FROM Customer c JOIN Sales s ON c.ckey=s.ckey
       WHERE s.type='global' AND c.ckey IN UNNEST(@array)
       GROUP BY c.ckey ORDER BY total DESC LIMIT 5

Initial Plan:
    Top(5)
      ↓
    GroupBy(ckey)
      ↓
    CrossApply (Join)
    /         \
  Scan(Customer)  Scan(Sales)

After Distribution Optimization:
           Top(5) ← final
             ↓
    DistributedUnion
             ↓
         Top(5) ← local per shard
             ↓
       GroupBy(ckey) ← pushed to shards
             ↓
       CrossApply
       /         \
  Scan(Customer)  Scan(Sales) ← executed locally on each shard
  Filter: ckey IN @array
```

### Distributed Execution

#### Shard Pruning
* Extract sharding key ranges from query predicates
* Only query relevant shards
* Example: `WHERE ckey IN (1, 5, 10)` → query only 3 shards

#### Parallel Execution
* Dispatch subqueries to shards in parallel
* Use coprocessor framework to route to nearest replica
* Adjustable parallelism for load isolation

#### Batching Strategy
* Single call per server (hosting multiple shards)
* vs. one call per shard
* Minimizes cross-machine calls

#### Shard Affinity Optimization
* Detect when shards are co-located locally
* Avoid remote calls for small databases
* Important for queries on shared sharding keys (e.g., User object)

### Distributed Joins

#### Batched Apply Join
* Problem: Naive apply join = 1 RPC per row (too expensive!)
* Solution: Batch rows before remote calls

```
Transformation:
  CrossApply(<input>, <map>)
    ↓
  DistributedApply
    ↓
  Batch(<input>) → $batch
    ↓
  DistributedUnion
    ↓
  Unnest($batch) → CrossApply(<row>, <map>)
```

* Example use cases:
  * Join secondary index with base table
  * Inner/Left/Semi-joins on remote table keys
  * Turn full table scans into minimal range scans

#### Batched Apply Shard Pruning
1. Evaluate sharding key filter for each row in batch
2. Merge sharding key ranges across all rows
3. Compute minimal set of shards
4. Construct minimal batch per shard
5. Execute in parallel on relevant shards

### Query Distribution APIs

#### Single-Consumer API
* Query sent to root server
* Location hint extraction:
  * Analyze outermost distribution operator
  * Extract pattern for sharding keys from query parameters
  * Cache on client for subsequent executions
* Direct routing to relevant server
* Example:
  ```sql
  SELECT * FROM Parent WHERE key = @t
  ```
  → Sent directly to server owning shard with key=@t

#### Parallel-Consumer API
* For large-scale data processing pipelines
* Two-stage process:
  1. Partition query into N parts (returns partition descriptors)
  2. Execute each partition from separate machines in parallel
* Requires root-partitionable queries
  * Must have DistributedUnion at root after compilation
* Example:
  ```
  Table Parent with 10 shards [0,100), [100,200), ..., [900,1000)
  Request 5-way parallelism
  → Returns 5 descriptors, each covering 2 shards
  → 5 clients execute in parallel, each queries 2 shards
  ```

## Query Range Extraction

### Three Types of Range Extraction

#### 1. Distribution Range Extraction
* Determines which shards to query
* Uses sharding key prefix (e.g., ProjectId)
* Routes query to correct servers

#### 2. Seek Range Extraction
* Determines what data to read from storage
* Uses full or longer key prefix
* Converts full-shard scans to targeted seeks
* Trade-off: cost of extraction vs. benefit of smaller reads

#### 3. Lock Range Extraction
* Determines what ranges to lock for transactions
* Fine-grained locks improve concurrency
* Trade-off: many fine locks vs. few coarse locks
* Spanner supports column-level locking

#### Example
```sql
Table Documents(ProjectId, DocumentPath, Timestamp)
Sharding key: ProjectId

Query:
SELECT * FROM Documents
WHERE ProjectId = 'P001'
  AND STARTS_WITH(DocumentPath, '/proposals')
  AND Version = '2017-01-01'

Distribution ranges: (P001)
Seek ranges: (P001, /proposals/doc1, 2017-01-01),
             (P001, /proposals/doc2, 2017-01-01), ...
Lock ranges: Key columns: (P001, /proposals)
             Non-key columns: Same as seek ranges
```

### Compile-Time Rewriting

#### Correlated Self-Joins
* Transform filtered scan into tree of correlated scans
* One scan per key column
* Extract ranges for successive key columns

```
Original:
  Scan(Documents)
  Filter: ProjectId=@p AND STARTS_WITH(path,'/proposals') AND Version=@v

Rewritten:
         CrossApply
        /          \
   CrossApply    Scan3(Documents.*)
   /        \    Filter: ProjectId=@pid AND
Scan1      Scan2      DocumentPath=@dpath AND Version=@v
(ProjectId) (DocumentPath)
Filter:     Filter:
ProjectId   ProjectId=@pid AND
=@p         STARTS_WITH(path,'/proposals')
Outputs:    Outputs:
@pid        @dpath
```

#### Expression Normalization
* Push NOT to leaf predicates
* Isolate key column references
  * `1 > k` becomes `k < 1`
  * `NOT(k > 1)` becomes `k <= 1`
* Discretize small integer intervals
  * `k BETWEEN 5 AND 7` → explicit enumeration: 5, 6, 7
  * `k BETWEEN 5 AND 7000` → non-enumerable, requires table read
* Eliminate complex conditions (subqueries, expensive functions)

#### Post-Filtering
* Rewritten plan may not fully absorb original filter
* Add post-filter for conditions not expressible as seeks
* Example:
  ```sql
  (k1=1 AND k2="a" AND REGEXP_MATCH(value, @param)) OR
  (k1=2 AND k2<"b")

  Rewritten plan:
  - Seek to (1, "a") + post-filter with REGEXP
  - Seek to (2, *) with k2 < "b"
  ```

### Filter Tree

#### Dual Purpose Data Structure
* Simultaneously used for:
  1. Range extraction via interval arithmetic
  2. Post-filtering of emitted rows

#### How It Works
```
Filter: (k1=1 AND k2="a" AND REGEXP(...)) OR (k1=2 AND k2<"b")

Filter Tree:
                    OR (union)
                   /          \
         AND (intersection)  AND (intersection)
        /      |      \           /        \
      k1=1   k2="a"  REGEXP    k1=2      k2<"b"

Extract k1 ranges:
  Left AND:  [1,1] ∩ (-∞,+∞) ∩ (-∞,+∞) = [1,1]
  Right AND: [2,2] ∩ (-∞,+∞) = [2,2]
  OR:        [1,1] ∪ [2,2] = [1,2]

Extract k2 ranges (given k1=1):
  Left AND:  ["a","a"] but REGEXP unknown → ["a","a"]
  Right AND: Unsatisfiable (k1≠2) → empty
  OR:        ["a","a"]

Extract k2 ranges (given k1=2):
  Left AND:  Unsatisfiable (k1≠1) → empty
  Right AND: (-∞,"b")
  OR:        (-∞,"b")
```

#### Memoization and Pruning
* Cache predicate values that haven't changed
* Prune unsatisfiable branches (empty intervals)
* Skip tautologies (infinite intervals)
* Efficient post-filter evaluation

### Properties
* Produces minimal key ranges when possible
* Range computation is an approximation
  * Exact isolation may require solving polynomials
  * Diminishing returns for complex expressions
* Distribution range extraction is heuristic
  * May send subquery to irrelevant shard
  * Empty result returned if no matching data
* Trade-offs:
  * Seeks vs. scans (I/O cost vs. CPU cost)
  * Lock granularity (concurrency vs. overhead)

## Query Restarts

### What Are Query Restarts?
* Automatic recovery from transient failures
* Query continues from where it left off
* No client retry loops needed
* Works even after partial results consumed

### Hidden Transient Failures
* Network disconnects
* Machine reboots
* Process crashes
* Distributed wait (replica not caught up)
* Data movement (resharding during query)

### Benefits

#### Simpler Programming Model
* No retry loops in application code
* No complex backoff logic
* Multi-module queries possible
* Just set realistic deadlines

#### Streaming Pagination
* Long-running queries instead of:
  ```sql
  -- Traditional paging (can eliminate ORDER BY!)
  SELECT ... LIMIT @page_size OFFSET @skip
  SELECT ... WHERE col > @last_value LIMIT @page_size
  ```
* Can pause consumption without holding server resources
* Query transparently resumes on next read

#### Improved Tail Latency
* Minimal wasted work on restart
* Important for parallel queries across many machines
* Automatic retry from best replica

#### Forward Progress for Long Queries
* Queries can run longer than mean-time-to-failure
* Guaranteed completion (within garbage collection window)

#### Rolling Upgrades
* Deploy new server versions without disrupting queries
* Recurrent upgrades with no downtime
* Critical for Google's rapid development cycle

### Restart Contract

#### Restart Tokens
* Opaque blob sent with each result batch
* Added to original request to prevent duplicates
* No repeatability guarantee
  ```sql
  SELECT * FROM T LIMIT 100

  After returning 30 rows → restart with token
  → Returns 70 different rows (but no duplicates)
  ```

#### Streaming Implementation
* No persistent buffering of results
* Capture distributed state of query plan
* Small size, cheap to produce

### Technical Challenges

#### Dynamic Resharding
* Shard boundaries change during query
* Server may lose/gain ownership
* Example:
  ```
  Server executes query on shard [20, 30)
  → Interrupted
  → Same server now hosts merged shard [10, 40)
  → Must not re-execute [20, 30) portion
  ```
* Solution: Track progress in key space, not shard IDs

#### Non-Determinism Sources
* Parallel subquery execution (network/load dependent)
* Blocking operator memory allocation
* Floating point computation order
* Must ensure repeatable results across restarts

#### Cross-Version Compatibility
* Must support restart across server versions N and N+1
* Requirements:
  * Restart token wire format versioned
  * Query plan must remain same across versions
  * Operator behavior must be compatible
  * Even without restart token, operators must not change order

#### Version Compatibility Example
```
Query starts on version N
  ↓
Returns 1000 rows
  ↓
Binary rollout: server upgrades to N+1
  ↓
Query restarts with token from version N
  ↓
Version N+1 must:
- Parse token from version N
- Use same query plan as version N
- Respect operator ordering from version N
```

### Engineering Cost
* Restart token versioning mechanism
* Processes to force explicit versioning
* Framework to catch incompatibilities
* But worth it for stability and operational flexibility

## Common SQL Dialect (Standard SQL)

### Motivation
* Shared across Spanner, F1, Dremel, BigQuery
* Lower barrier for users working across systems
* Consistent syntax, semantics, NULL handling, etc.

### Design Choices
* Fill gaps left by SQL standard
* Google-specific extensions
* Protocol Buffer integration
  * MESSAGE and ENUM as first-class types
* UTF8 STRING type (not CHAR/VARCHAR)
* Nested data support (ARRAY, STRUCT)

### Shared Components

#### 1. Compiler Front-End
* Parsing, name resolution, type checking
* Prevents subtle divergences (coercion rules, scoping)
* Consistent error messages
* Outputs: Resolved Abstract Syntax Tree (AST)
* Systems convert Resolved AST to their algebras

#### 2. Scalar Function Library
* Shared implementation of functions
* Consistency in corner cases
* Uniform overflow checking and runtime errors

#### 3. Testing Framework

##### Compliance Tests
* Developer-written queries with expected results
* Cover primary use cases and corner cases
* Systems enable tests as they implement features

##### Coverage Tests - Random Query Generation
* Graph of node generators
* One generator per Resolved AST node type
* Example: FilterScanNodeGenerator
  ```
  FilterScanNodeGenerator
    ↓ edges to
    - Boolean expression generators (for condition)
    - Scan generators (for input)
  ```
* Special generators for important patterns (e.g., key joins)
* Configurable: query size, scalar functions, etc.

##### Reference Implementation
* Produces annotated results
  * Imprecise values (e.g., AVG with floats)
  * Ordered vs. unordered lists
* Skips verification when unique result impossible
  * Example: LIMIT without ORDER BY
* ~10% of random queries skip verification in unit tests

##### Continuous Testing
* Millions of random queries per day
* Random schema and data generation
* Bug reports help identify gaps in coverage

## Blockwise-Columnar Storage (Ressi)

### Background: Storage Concepts

#### OLTP vs OLAP Workloads
* **OLTP (Online Transaction Processing)**
  * Short transactions (ms to seconds)
  * Read/write small number of rows
  * Examples: Insert order, update account balance
  * Access pattern: Random reads/writes by key
  * Metrics: Transactions per second, latency

* **OLAP (Online Analytical Processing)**
  * Long-running queries (seconds to hours)
  * Scan large portions of tables
  * Examples: Sum sales by region, compute trends
  * Access pattern: Sequential scans, many columns
  * Metrics: Query throughput, data scanned

#### Row-Major vs Column-Major Layout
* **Row-Major** (traditional databases)
  ```
  Row 1: [id=1, name="Alice", age=30, salary=100k]
  Row 2: [id=2, name="Bob",   age=25, salary=80k]
  Row 3: [id=3, name="Carol", age=35, salary=120k]

  Storage: [1,"Alice",30,100k, 2,"Bob",25,80k, 3,"Carol",35,120k]
  ```
  * Good for OLTP: Fetching entire row is one I/O
  * Bad for OLAP: Reading one column scans all data

* **Column-Major** (analytical databases)
  ```
  Col id:     [1, 2, 3]
  Col name:   ["Alice", "Bob", "Carol"]
  Col age:    [30, 25, 35]
  Col salary: [100k, 80k, 120k]

  Storage: [1,2,3, "Alice","Bob","Carol", 30,25,35, 100k,80k,120k]
  ```
  * Good for OLAP: Reading one column is efficient
  * Bad for OLTP: Reconstructing row requires multiple I/Os

* **PAX Layout** (Partition Attributes Across)
  ```
  Block 1 (rows 1-2):
    id: [1, 2]
    name: ["Alice", "Bob"]
    age: [30, 25]
    salary: [100k, 80k]

  Block 2 (rows 3-4):
    id: [3, 4]
    name: ["Carol", "Dave"]
    age: [35, 40]
    salary: [120k, 90k]
  ```
  * Hybrid: Row-major across blocks, column-major within blocks
  * Benefits both OLTP and OLAP
  * Ressi uses this approach

#### LSM-Tree (Log-Structured Merge Tree)
* Write-optimized data structure
* Key idea: Turn random writes into sequential writes

**Structure:**
```
Writes → MemTable (in-memory, sorted)
           ↓ (when full)
         Flush to disk
           ↓
        Level 0 (multiple sorted files, may overlap)
           ↓ (compaction)
        Level 1 (sorted files, non-overlapping within level)
           ↓ (compaction)
        Level 2 (10x larger than L1)
           ↓
        Level 3 (10x larger than L2)
         ...

Example:
  MemTable: [5→v5, 10→v10, 15→v15]
  L0 File1: [1→v1, 10→v10_old, 20→v20]
  L0 File2: [5→v5_old, 12→v12]
  L1 File1: [1→v1, 5→v5_old, 8→v8]
  L1 File2: [15→v15_old, 20→v20_old]
```

**Operations:**
* **Write**: Insert into MemTable (fast, in-memory)
* **Read**: Check MemTable → L0 → L1 → L2 → ...
  * May need to check multiple files (slower than B-tree)
  * Bloom filters help skip files without the key
* **Compaction**: Merge files from Lᵢ into Lᵢ₊₁
  * Removes deleted/old versions
  * Maintains sorted order
  * Background process

#### Bloom Filters
* Space-efficient probabilistic data structure
* Answers: "Is key X in this file?"
* Properties:
  * **Never false negatives**: If says "no", definitely not in file
  * **May have false positives**: If says "yes", might not be in file
  * Very small: ~10 bits per key for 1% false positive rate

**How It Works:**
```
Bloom filter = bit array + k hash functions

Insert key "foo":
  h1("foo") = 3   → Set bit[3] = 1
  h2("foo") = 7   → Set bit[7] = 1
  h3("foo") = 15  → Set bit[15] = 1

Check if "bar" exists:
  h1("bar") = 3   → bit[3] = 1 ✓
  h2("bar") = 7   → bit[7] = 1 ✓
  h3("bar") = 10  → bit[10] = 0 ✗
  Result: Definitely NOT in file

Check if "baz" exists:
  h1("baz") = 3   → bit[3] = 1 ✓
  h2("baz") = 7   → bit[7] = 1 ✓
  h3("baz") = 15  → bit[15] = 1 ✓
  Result: MAYBE in file (could be false positive)
```

**Use in LSM-Trees:**
* Each SSTable has a bloom filter
* Read path: Check bloom filter before reading file
* Example:
  ```
  Read(key=500):
    Check MemTable: Not found
    L0: Check bloom filter → "No" → Skip file
    L1: Check bloom filter → "Yes" → Read file → Found!

  Saved expensive disk I/O on L0 file
  ```

**Write Amplification:**
* Data written multiple times during compactions
* Example: 1KB written by user → 10KB actual disk writes
* Trade-off: Fast writes vs. read performance

#### SSTables (Sorted String Tables)
* On-disk file format for LSM-tree levels
* Properties:
  * Sorted by key
  * Immutable (never modified, only created/deleted)
  * Self-describing (stores schema with data)
* Structure:
  ```
  SSTable File:
    [Index Block] → Points to data blocks
    [Data Block 1]: Keys [a, f), sorted
    [Data Block 2]: Keys [f, m), sorted
    [Data Block 3]: Keys [m, z), sorted
    [Metadata]: Schema, stats, bloom filter
  ```
* Used by Bigtable, original Spanner, RocksDB, LevelDB

### Motivation for Change
* SSTables inherited from Bigtable
  * Optimized for schemaless NoSQL, large strings
  * Self-describing, highly redundant
  * Inefficient column traversal
* Spanner's workload:
  * Schematized data, small values
  * Frequent column-wise access
  * Hybrid OLTP/OLAP

### Ressi Data Layout

#### LSM-Tree Structure
* Same overall structure as SSTables
* Periodic compaction of layers
* But different on-disk format (PAX instead of row-major)

#### Block Organization
```
Layer:
  Block 1: [Row1, Row2, Row3, ...]  ← Row-major order
  Block 2: [Row50, Row51, Row52, ...]
  ...

Within Block (Column-major, PAX layout):
  Col1: [val1_1, val1_2, val1_3, ...]
  Col2: [val2_1, val2_2, val2_3, ...]
  Col3: [val3_1, val3_2, val3_3, ...]
```

#### Table Interleaving Support
* Child table rows in same/nearby blocks as parent rows
* Preserves co-location for efficient joins

#### Multi-Level Index
* Fast binary search for random key access

### File Organization

#### Active vs Inactive Files
* Active file: most recent values only
* Inactive file: older versions
* Benefit: Recent data queries avoid loading old versions

#### Large Value Segregation
* Multi-page values in separate files
* Fast scans without I/O cost of large values
* Load large values only when needed

### Fundamental Data Structure: Vector
* Ordinally indexed sequence of homogeneous values
* Each column = one or multiple vectors
* Operate directly on compressed vectors
  * No decompression needed for many operations

### Live Migration from SSTables

#### Requirements
* Preserve data integrity
* Minimal impact on live workloads
* Reversible rollout

#### Migration Strategy
1. Change group specification (including storage format)
2. Use Spanner's data movement mechanism
3. Copy and convert data from old group to new group
4. Old group continues serving live traffic
5. New group takes over when ready
6. Gradual per-group conversion

#### Flexibility
* Convert to Ressi replicas
* Mixed format replicas (testing/verification)
* Rollback to SSTables if needed

```
Migration Flow:
  Group A (SSTables)        Group B (Ressi)
  [Replica 1, 2, 3]    →    [Replica 4, 5, 6]
        ↓                           ↓
  Serving live traffic      Copying + converting
        ↓                           ↓
  Still serving            Ready to serve
        ↓                           ↓
                 Handoff
        ↓                           ↓
  Decommissioned           Now serving traffic
```

## Lessons Learned

### Scalability First, Then Performance
* Horizontal scalability enabled deployment at scale
* Single-machine performance improved later
* Aggressive focus on distribution over single-node optimization

### SQL Adoption Trajectory
* NoSQL API initially (simple point lookups, range scans)
* SQL added significant value for complex queries
* Switching to common dialect accelerated adoption:
  * 2× increase in year before common dialect
  * 5× increase in year after common dialect
  * 4× increase in distributed query complexity

### Transaction Guarantees
* External consistency (global ordering)
* Constraint: All updates committed at transaction end
* Limitation: Can't read uncommitted results within transaction
* Low internal demand, but important for compatibility

### TrueTime Epsilon Improvements
* Continued reduction in clock drift
* Simplified timestamp picking for queries
* Reads at now+epsilon avoids complex analysis
* Increases replica selection freedom

### Schema Design Complexity
* Many physical layout options:
  * Geographic placement
  * Replication configuration
  * Protocol buffers vs. interleaved tables
  * Vertical partitioning
* Internal schema reviews prevent production issues

### Query Optimization Challenges
* Declarative SQL + varying user sophistication
* Bi-weekly deployment cycle
* Optimizer changes can cause order-of-magnitude swings
* Challenge: Innovate while preserving workload stability

### One-Size-Fits-All Remains Goal
* Combine OLTP, OLAP, full-text search in single system
* Reduces operational burden vs. multiple systems
* Single transactional semantics, API, deployment
* Focus on broad spectrum performance and cost-effectiveness

## Key Insights

### Architectural Rethinking for Scale
* Static partitioning → Dynamic resharding
* Node-addressed RPC → Data-range-addressed RPC
* Single replication config → Multiple configs for different workloads
* In-memory metadata → Metadata as data
* Simple control plane → Complex monitoring/management system

### SQL vs NoSQL Reconciliation
* Scalable, manageable, transactional key-value = foundation
* Can support both loosely coupled (F1) and tightly coupled (Spanner) SQL
* SQL provides value for complex access patterns
* Recommendation: Start with relational model early
  * Once scalable, available storage core exists
  * Speeds development, reduces future migration costs

### Evolution Path
1. Scalability
2. Manageability
3. ACID transactions
4. Relational model
5. Schema DDL with nested data indexing
6. SQL

For other systems following similar path: Start relational early!
