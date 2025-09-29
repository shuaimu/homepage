# RocksDB
## Goals
* Persistent key-value store for large-scale distributed systems
  * Optimized for SSDs (flash memory)
  * Embedded library (single node)
  * Highly customizable for different workloads
* Support diverse use cases
  * Databases (MySQL, MongoDB, TiDB)
  * Stream processing (Flink, Kafka Streams)
  * Logging/queuing services
  * Index services
  * SSD caching

## Problem: SSDs have unique characteristics
* Asymmetric read/write performance
* Limited write endurance (P/E cycles)
* High IOPS but write amplification matters
* Shifted bottleneck: I/O → Network/CPU

## Key Design: LSM Trees
* Log-Structured Merge trees as primary data structure
  * Writes: MemTable → SSTable (Level 0)
  * Compaction: merge levels to remove dead data
* Why multiple levels (not just 2)?
  * With 2 levels: may rewrite entire dataset on each compaction
  * With N levels: amortize compaction cost
  * Each level ~10x larger than previous
  * Example: 1GB L0 → 10GB L1 → 100GB L2 → 1TB L3
  * Trade-off: more levels = lower write amp but higher read cost
* Benefits for SSDs:
  * Sequential writes (flash-friendly)
  * Tunable write amplification
  * Efficient space reclamation

### Reducing Read Cost: Bloom Filters
* What: probabilistic data structure to test set membership
  * Can definitively say "key NOT in SSTable"
  * May have false positives ("key might be in SSTable")
  * Never false negatives
* How it works:
  * Array of bits + multiple hash functions
  * Insert: hash key multiple ways, set corresponding bits to 1
  * Query: hash key, check if all corresponding bits are 1
* Use in RocksDB:
  * Each SSTable has bloom filter in its metadata
  * Read path: check bloom filter before reading SSTable
  * Eliminates ~99% of unnecessary SSTable reads (with 10 bits/key)
  * Critical for read performance with multiple levels
* Example read path:
  * Looking for key "foo"
  * L0: 5 SSTables → check 5 bloom filters → only read 1 SSTable
  * L1: check bloom filter → skip entire level
  * L2: check bloom filter → read SSTable (key found)
  * Saved: 4 unnecessary SSTable reads in L0, entire L1 scan

### Compaction Strategies
  * Leveled: balanced read/write (10-30x write amp)
    * Each level has non-overlapping key ranges
    * Size limit per level (exponentially increasing)
    * When level full → pick SSTable, merge with overlapping SSTables in next level
    * Maintains sorted runs per level
  * Tiered: write-optimized (4-10x write amp)
    * Also called Universal Compaction in RocksDB
    * Can use multiple levels, but differently than leveled compaction
    * Structure:
      * Smaller sorted runs: stored as files in Level 0
      * Larger sorted runs: stored as "levels" (L1, L2, etc.) with partitioned SSTables
      * Each sorted run contains non-overlapping keys within itself
      * Different sorted runs can have overlapping key ranges
    * Level usage:
      * num_levels=1: all sorted runs in L0 (limited by 4GB file size)
      * num_levels>1: larger sorted runs promoted to higher levels for partitioning
    * Compaction triggers:
      * Too many sorted runs (e.g., > 10-12)
      * Space amplification too high (total size / largest run > threshold)
    * When triggered: merge multiple sorted runs into one larger sorted run
    * Example:
      * L0: Run1(1GB), Run2(1GB), Run3(1GB) - smaller runs
      * L1: Run4(10GB split into multiple SSTs) - larger run
      * Read key A: must check all sorted runs
    * Trade-offs:
      * Lower write amp: data written fewer times
      * Higher read cost: must check all sorted runs
      * Higher space overhead: duplicate keys across runs
  * FIFO: cache workloads (2x write amp)
    * NO levels at all - just a queue of SSTable files
    * Simply discard old files when DB hits size limit
    * Minimal compaction (only within Level 0 for deduplication)

## Evolution of Optimization Targets

### Write Amplification (2012-2015)
* Initial focus: minimize flash wear
* Leveled compaction: 10-30x write amplification
* Tiered compaction: 4-10x write amplification
* Trade-off: write amp vs read performance

### Space Amplification (2015-2018)
* Shift: flash endurance less critical than space
* Dynamic Leveled Compaction:
  * Automatically adjust level sizes
  * Reduce dead data to ~13% overhead
  * Previous: up to 90% worst-case overhead
* Result: 50% space reduction for Facebook UDB

### CPU Utilization (2018-present)
* Current bottleneck: CPU efficiency
* Most workloads space-constrained (not IOPS)
* Optimizations:
  * Prefix bloom filters
  * Parallel compactions
  * Batched MultiGet with parallel I/O

## Lessons from Large-Scale Systems

### Resource Management
* Challenge: multiple instances per host (10s-100s)
* Global limits needed:
  * Memory (write buffer, block cache)
  * Compaction I/O bandwidth
  * Compaction threads
  * Disk usage
* Resource controllers for fairness

### Data Format Compatibility
* Problem: incremental software rollouts
* Solution: forward + backward compatibility
  * Understand old formats indefinitely
  * Forward compatible for ≥1 year
  * Generic encoding (Protocol Buffers)

### Configuration Management
* Problem: too many knobs (100s of options)
* 25+ distinct configs across 39 ZippyDB deployments
* Current focus: automatic adaptivity
* Challenge: optimal config depends on workload

### WAL Treatment
* Traditional: sync every write (durability)
* RocksDB options:
  * Synchronous writes
  * Buffered writes (periodic flush)
  * No WAL (rely on replication)
* Distributed systems often have own logs (Paxos)

## Failure Handling

### Corruption Frequency
* ~1 corruption per 3 months per 100PB
* 40% already propagated to replicas
* Sources: CPU/memory bitflips, software bugs

### Multi-Layer Checksums
```
Application → Per-KV checksums (planned)
     ↓
MemTable/Cache → Currently unprotected
     ↓
SSTable → Block checksums + File checksums
     ↓
File System → Handoff checksums
     ↓
Storage Device → ECC/CRC
```

### Detection Strategy
* Detect early at every layer
* Block checksums: on every read
* File checksums: on file transfer (2020)
* Handoff checksums: write-time verification
* End-to-end KV checksums: future work

### Error Handling
* Differentiated by severity:
  * Transient (network): auto-retry
  * Permanent (corruption): fail fast
  * Out-of-space: automatic recovery
* Periodic retry for transient errors

## Key-Value Interface Evolution

### Current Limitations
* No built-in versioning
* No cross-shard consistent reads
* Performance issues with timestamps in keys/values

### User-Defined Timestamps
* New feature: timestamps as metadata
* Benefits:
  * 1.2-2x throughput improvement
  * Point lookups instead of scans
  * Bloom filter effectiveness
* Use cases:
  * MVCC transactions
  * Distributed transactions
  * Multi-master replication

## Hardware Trends

### Remote/Disaggregated Storage
* Current priority with faster networks
* Benefits: independent CPU/storage scaling
* Challenges: I/O latency, parallelization

### Storage Class Memory (SCM)
* Options being explored:
  * DRAM extension
  * Main storage (but space-constrained)
  * WAL storage only

### Future Technologies
* Open-channel SSDs: limited benefit (space-constrained)
* Multi-stream SSDs: minority of workloads
* ZNS: delegation to file system
* In-storage computing: unclear benefits

## Performance Characteristics
* Write amplification:
  * Leveled: 10-30x
  * Tiered: 4-10x
  * FIFO: 2x
* Space overhead:
  * Dynamic leveled: ~13%
  * Traditional leveled: up to 90%
* Resource utilization (typical):
  * CPU: 11-47%
  * Space: 45-78%
  * Flash endurance: <10%
  * Read bandwidth: 1-10%

## Key Insights
* Space efficiency dominates for SSD workloads
* CPU efficiency increasingly important
* LSM trees remain good fit for SSDs
* Customizability essential for diverse workloads
* Early corruption detection critical
* Forward compatibility necessary for operations
