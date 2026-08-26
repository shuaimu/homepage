
# Postgres

## Context
* INGRES (1970s, Berkeley) was Stonebraker's first system
  * proved the relational model could be implemented
* Postgres:
  * mid-1980s: INGRES was "hacked up enough" that big new features would not fit
  * so they built a *new* system: POSTGRES = POST inGRES
* Motivating applications were not payroll
  * CAD, GIS, graphics, etc.
  * polygons, rectangles, text, nested objects — not just ints and strings
* Hellerstein: this is Stonebraker's most ambitious project
  * a "second system" that *succeeded* (Brooks usually predicts the opposite)
  * today's PostgreSQL is still recognizably that architecture

## Design goals (1986 paper)
1. Complex objects
2. User-extendible types, operators, and access methods
3. Active databases: alerters, triggers, inferencing
4. Simpler crash recovery
5. New hardware: optical disks, multiprocessor workstations, custom VLSI
6. Change the relational model as little as possible

## Why a conventional RDBMS fails on "objects"

Example from the paper: paint a map.

* polygons, circles, lines each in their own relation
* a DISPLAY relation holds color / position / scale, plus `(obj-type, object-id)`
* to draw the screen you issue *one query per object type*
* too many round trips; you cannot paint in 1–2 seconds

What they wanted:
* store the object *in a field* of DISPLAY
* one query fetches the whole thing

This is the object-relational bet:
* keep tables as the outermost type
* let columns be nested / opaque / user-defined
* "have your cake and eat it too" vs flattening everything into 1NF

## Complex objects and ADTs

### Nested data
* a column can hold nested tuples or tables
* also "QUEL as a data type": a field whose value is a query
* later: XML, JSON — same idea, new syntax
* Hellerstein: every "NoSQL then add queries" cycle ends here

### Opaque ADTs + UDFs
* store a type the core engine does *not* interpret
  * Codd already allowed any atomic type with predicates
  * the software problem is registering operators
* User-defined functions (UDFs) and aggregates (UDAs)
  * put in the catalog, call them from queries
* Why in the DBMS instead of the application?
  * push code to data, not data to code
  * modest catalog + foreign-code invocation
  * query language and architecture stay relational

Security was not a 1980s concern.
* Illustra / Informix DataBlades ran unprotected C on the server
* Oracle's marketing used that
* today: UDFs exist, with sandboxes

MapReduce / Big Data UDFs are the same architecture with parallelism bolted on.

### Extensible access methods
* B-trees: equality + 1-D range
* GIS / CAD want 2-D range → R-trees (Guttman, Stonebraker group)
* inventing an index is not enough
  * can you *plug it in*?
  * can the optimizer *recognize* when to use it?
  * concurrency / recovery for the new structure?
* Postgres: register an access method + the operators it supports
  * B-tree works for any operator set that obeys the usual order axioms
  * optimizer gets: pages touched, tuples examined, join method legality
* Survived: B-tree, GiST, SP-GiST, GIN, PostGIS
  * GiST = templated "generalized search tree" (later Hellerstein work)

## Active databases: alerters, triggers, rules
* **Alerters / triggers** (`always`): run *forever*
  * alerter: retrieve that fires when matching data changes
  * trigger: append / replace / delete that fires on a condition
  * example: `delete always DEPT where count(employees in that dept) = 0`

Implementation idea (1986): special locks
* **I-locks** ("invalidate me"): cached plan / answer; a write invalidates
* **T-locks**: sleeping `always` command; a write wakes it
* **D-locks**: `demand` rule; a read *rewrites* the query (query modification)

Two implementation styles (Hellerstein / PRS2):
* query rewrite (Ingres-style view modification)
* row-level triggers (locks that run an action instead of waiting)

Neither "won." PostgreSQL still has statement-level *and* row-level triggers.
The AI-winter problem remains: a pile of rules becomes unintelligible.
Fast deployments often just avoid triggers.

Descendants: materialized views, CEP, streaming.

## Process structure
* DBMS must be a *separate process* from the app (protection)
* two models:
  * **process-per-user**: one backend per client — simpler, worse sharing
  * **server**: one DBMS for all clients — better, needs a mini-OS
* they chose process-per-user on 4.3BSD ("limited programming resources")
* POSTMASTER: one per machine, started at boot
  * lock manager (no shared memory segments on 4.3BSD)
  * demons (compile queries in the background, vacuum, …)
* POSTGRES backend: executes commands for one app
* request/answer messages; frontend *pulls* a bounded number of tuples
  * unlike INGRES, the backend does not flood the channel

This process model is still how PostgreSQL looks: postmaster + one backend per connection.

## Storage: log as data (no overwrite)

Stonebraker's "missionary zeal to do something different."
Commercial systems used WAL. INGRES already had a WAL-ish manager.
They did not want to write another one — especially if users can add access methods
(recovery code must stay simple).

### Tuple format
Every tuple carries:
* immutable 64-bit tuple id
* `tmin`, `BXID` — when / which xact created it
* `tmax`, `EXID` — when / which xact killed it
* version pointer, descriptor (null bitmap / field offsets)

Update = insert a new tuple + stamp `tmax` on the old one.
**No in-place overwrite.**

To read as of time `T`, find tuples with `tmin < T < tmax` whose creating xact committed
(and whose deleter has not committed, depending on the case).

### The "log"
* xact ids assigned sequentially
* commit: force dirty pages, then write *one bit* (committed / aborted / in-progress)
* assumed a little non-volatile "secure main memory" for the tail of this bit log
* vacuum:
  * drop aborted versions
  * migrate old committed tuples to optical disk
  * after that, archive needs no log — everything there committed

### Why this was counter-cultural
* TPC winners were competing on fancy WAL
* log shipping / replication is natural with WAL, awkward here
* Postgres storage never won on OLTP speed

### What PostgreSQL actually does today (Hellerstein)
* no-overwrite time travel was *removed*
* replaced by WAL
* but they *kept* versioned tuples for MVCC / snapshot isolation
  * that was *not* a Berkeley Postgres goal
  * result: WAL complexity *plus* version overhead
* echoes elsewhere:
  * NoSQL: replication instead of fancy WAL
  * in-memory DBs: multi-version + a compressed commit log
  * cheap storage + streaming: time travel is due for a comeback

## What survived vs what died

Survived (in PostgreSQL or the industry):
* object-relational: UDFs, nested types, JSON/XML
* extensible indexes (GiST, PostGIS)
* postmaster / process-per-user
* SQL (added by the pickup team, not the 1986 design)
* triggers (rewritten, both granularities)
* extension / DataBlade ecosystem (MADlib, Citus, …)
* a pile of companies

Died or was replaced:
* POSTQUEL
* no-overwrite + time travel as primary storage
* optical-disk vacuum
* the original rules implementations
* expensive-UDF optimizer (temporarily)

Hellerstein's number (2019): PostgreSQL among the most popular independent open-source DBMSs;
Postgres-based companies totaling > $2.6B in acquisitions.

## Lessons (Hellerstein)
* extensibility let the second system carry too many ideas *without* collapsing
  * try many extensions; the strong ones stick
* "one size fits many" can beat "one size fits all is dead"
  * later "MIT Stonebraker" argued specialization; Postgres is the counterexample
* open-sourcing a research prototype can outlive the lab
  * Stonebraker: a pickup team, none of them Berkeley, shepherded it after 1995
  * "do something important and set it free"
