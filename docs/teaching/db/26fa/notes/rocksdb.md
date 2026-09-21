
# RocksDB

Paper: Dong, Kryczka, Jin, and Stumm, *Evolution of Development Priorities in Key-value Stores Serving Large-scale Applications: The RocksDB Experience* (FAST 2021).

Last time: 1996 LSM — C0 in RAM, C1…CK on disk, geometric sizes, one-pass merge, tombstones.

This paper is not a new tree. It is eight years of running LevelDB's grandchild as an embedded engine at Facebook, and watching the bottleneck *move*.

## What it is

* A KV *library* on one machine. Not a distributed database
  * TiKV, MyRocks, ZippyDB, Flink state, MongoRocks sit *on top*
  * replication, sharding, SQL, checkpoints: the application's job
  * RocksDB's job: durable sorted Get / Put / Iterator on local files, plus hooks so those jobs are possible
* Fork of Google LevelDB (2012), aimed at local SSDs
* Highly configurable — that is both the product and the headache
* Why one engine for 30+ Facebook services (and MySQL, TiDB, Kafka Streams, …)?
  * checksums, crash consistency, `fsync` order, file-system errors: you do not want every team inventing this
  * same dashboards, same debug tools, same on-call lore

## From last lecture to RocksDB

```
C0            → MemTable (skiplist) + optional WAL
frozen C0     → immutable memtable, flushed as an L0 SSTable
C1 … CK       → levels of SSTables
one-pass merge → compaction
delete-note   → tombstone, dropped when compacted
```

* Disk side is a pile of *files*, not one B-tree per component
  * last lecture: that packaging is later; here it is
* SSTable = sorted string table: key order, ~block-sized chunks, an index for binary search
* Level 0 is special: several files, key ranges *overlap* (each flush is a full sorted run)
* Later levels: one sorted run, cut into files with *non-overlapping* ranges
* Classic size ratio: each level ~10× the previous (the modern default; not the 1996 worked example)

```
  MemTable  ──flush──►  L0  (overlapping files)
                          │ compact
                          ▼
                        L1  (one run, partitioned)   ~10× L0
                          │
                          ▼
                        L2  ~10× L1   …   LK
```

* Write: Put goes to the memtable (and maybe the WAL). Memtable full → freeze it, open a new one, write the frozen one out as an L0 file
* Read: memtables, then every L0 file that might contain the key, then at most one file per later level. Newest wins
* Compaction: pick file(s) at L, merge with overlapping files at L+1, write new files, drop the old. Same two-list merge as last time, file at a time rather than rewriting a whole component

## Why LSM on flash (short)

* 1996 scarce resource: disk arm. 2012 scarce resource: flash *erase cycles*, then *space*
* SSD: huge IOPS, writes wear the device, you cannot sustain peak write bandwidth
* B-tree: rewrite a page per small update. LSM: append new files, drop dead data at compaction
* Local SSD is often faster than the network → embed the engine in the app (TiKV on the box, not a remote disk service)
* Paper in 2021: LSM is still the right shape. People still want *lower* write amp than leveled LSM gives → BlobDB (values in a separate log, keys stay in the tree; WiscKey's idea)

## Compaction is the design knob

One engine, three merge policies. That is how the same library is "read friendly" or "write friendly."

* Leveled (from LevelDB)
  * L1+ files do not overlap. When L is full, compact *one* file into the overlapping files in L+1
  * write amp ~10–30. Space tight. A point Get is about one SST per level
  * databases (MyRocks, ZippyDB)
* Tiered (Universal in RocksDB)
  * lazily merge several whole sorted runs, when there are too many or space amp is high
  * write amp ~4–10. More overlapping runs → more files a Get must consider. More leftover copies of old values
  * logging, stream processing
* FIFO
  * size-capped cache: drop the oldest files. Almost no merge
  * SSD caches that can lose data (EVCache, Redis overflow)

Paper microbench (Table 3), gist:

* leveled: write amp ~16, space overhead ~10%, Get with bloom ~1 I/O
* tiered: write amp ~5, space overhead ~45–90%, more I/Os if you skip the filter
* FIFO: write amp ~2; without a filter a Get can be hundreds of I/Os

Lazier merge: cheaper writes, worse reads and space. Application picks. Write-heavy services compact less; databases compact more.

### Bloom filters (why L0 does not kill reads)

* A Get may have to consider *every* L0 file, plus one file per later level
* Each SST carries a filter: "this key is definitely not in this file" (or "maybe")
  * never a false negative; false positives just cost an extra SST read
* Check the filter before touching the file. Misses skip the I/O
* This is how many levels stay tolerable for point reads. Scans still visit every level

## The bottleneck moved

The paper's thesis: they did not change the tree. They changed *what they optimized*.

* ~2012: write amplification (save flash P/E)
  * leveled 10–30 is already much better than a B-tree (LinkBench / MyRocks: ~5% of InnoDB's writes)
  * still too high for ingest-heavy services → add tiered
* Then they measured the fleet: most deployments are *space*-bound, not IOPS- or endurance-bound
  * flash endurance often a few percent of the 2–5 year budget
  * read bandwidth similarly idle
  * write amp stopped being the #1 goal
* Space amplification = extra bytes from dead / not-yet-compacted data
  * static level size caps: overhead wanders; worst case ~90% extra
  * *dynamic* leveled: size each level off the *actual* last level → ~13% overhead, stable
  * UDB: replacing InnoDB with RocksDB cut space about in half
* CPU later
  * not "SSD is so fast the software cannot keep up" on their boxes — a decent CPU saturates one SSD
  * most hosts not CPU-full (headroom for growth and DC failure)
  * CPU and DRAM got expensive relative to flash → prefix bloom, filter before the index, parallel compaction, batched `MultiGet`
  * a write-heavy workload plus heavy compression *can* CPU-bound; then lighter compression, or that workload should not live on flash

Hardware they mostly *did not* specialize for:

* open-channel / multi-stream / ZNS: help latency and erase cycles — minority of their apps; maybe the FS should absorb this
* in-storage compute: unclear who benefits
* they *are* chasing remote / disaggregated SSD: provision CPU and flash independently; long I/O, transient failures, QoS
* storage-class memory: DRAM extension? main store? WAL only? WAL-only may not pay for the device

## Lessons from running at scale

### Many instances per host

* Shard = one RocksDB. A server holds tens to hundreds of shards
* Caps needed *per host*, not just per instance: memtable + block cache, compaction bandwidth, compaction threads, disk, file-delete rate
* Caps per instance too, so one shard cannot eat the box
* Liberally spawning threads: context-switch storms, I/O spikes, undebuggable. Use a pool
* Separate processes: even harder. Conservative local config (leave unused capacity) vs gossip about usage

### WAL is optional

* Textbook DB: `fsync` the WAL on every write
* Replicated system already has a Raft / Paxos log. Then the memtable WAL is a second log — often skip it
* Three modes: sync, buffered (periodic, low priority), none
* Same split you saw in TiKV / Mongo: consensus log is the durability story; the storage engine can be less paranoid

### Deleting files can stall reads

* Compaction drops old SSTs. The FS issues TRIM. SSD firmware journals the map and may GC
* A burst of deletes → latency spike on *foreground* I/O
* Fix: rate-limit file deletion. (Not in the 1996 paper.)

### Formats and knobs

* Monthly release, rolling upgrade *and* rollback, copy SST files between hosts on different versions
* Must read every old on-disk format forever. Aim for ~1 year of *forward* compatibility (protobuf-style "ignore unknown fields")
* Config: 25+ distinct setups among 39 ZippyDB deployments
  * changing a default on upgrade surprises people
  * string options, an options file next to the DB, a validator, a (limited) migrator
  * they want adaptivity; they still cannot drop the knobs

### Replication and backup are outside

* Logical copy: iterate keys, write them on the new replica (scan without trashing the block cache; bulk-load on the destination)
* Physical copy: copy the SST files
  * RocksDB will list files as of a point in time and *pin* them so compaction cannot delete them mid-copy
  * this is why they stay on a filesystem rather than talking to the SSD FTL / a raw device — each app already has copy tools
* Backup ≈ the same choice, plus retaining several copies. They ship a small backup engine for the simple case

## Failures

* Silent corruption at the RocksDB layer: roughly once per 3 months per 100 PB (MyRocks: primary vs secondary index disagree)
  * 40% of those already on another replica
* Copy path is sloppier: ~17 checksum mismatches per PB transferred (bugs, not cosmic rays)
* Checksums at every layer, catch *early* (or you replace the last good replica too late):
  * block checksum, inherited from LevelDB: verify on every read, do not serve garbage
  * file checksum (2020): backups and SST shipping
  * WAL handoff checksum: catch a bad write at write time — local FS often will not
  * per-KV checksum (then in progress): memtable and block cache are otherwise unprotected; a bitflip there can be *flushed* and become permanent
* Errors are not one severity:
  * transient (remote disk, network): retry, do not make the operator restart the instance
  * permanent corruption: fail fast, throw the replica away
  * early RocksDB: return the error or halt all writes. That was the wrong default

## The KV API is too small

* Get / Put / Iterator is portable and enough for almost every workload — that is why KV stores won
* Pain they hit:
  * transactions (they added them for MyRocks)
  * versioning is an internal 56-bit sequence number plus snapshots. The app cannot name a time. No snapshot of the past. No cross-shard consistent read (each instance numbers itself)
  * stuffing a timestamp *in the key*: a point Get becomes a scan; bloom helps less
  * stuffing it *in the value*: out-of-order writes and old versions are ugly
* User-defined timestamps as metadata, not part of key or value
  * point Get + bloom + "this SST's time range cannot contain what you asked"
  * their microbench: ~1.2–2× vs timestamp-in-key
  * intended for MVCC, distributed transactions, multi-master — at the cost of a pickier API and extra space

## What to remember

* Same LSM as last time, packaged as memtable + SSTables + compaction
* The *choice* is how lazily you merge (leveled vs tiered vs FIFO), not a new structure
* Bottleneck walked: write amp → space → CPU / DRAM; LSM survived all three
* A library used under 100 shards/box is an ops problem: global resource caps, optional WAL, rate-limited deletes, forward-compatible files, pin files for physical copy
* Detect corruption at every layer, early; retry only the errors that are actually transient
* A byte-array KV API will get you adopted, then you will wish timestamps were first-class
