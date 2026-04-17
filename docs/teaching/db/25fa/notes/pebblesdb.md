# PebblesDB
## Goals
* Reduce write amplification in key-value stores
  * LSM trees (LevelDB, RocksDB) suffer from high write amplification
  * Write amplification = Total write IO / User data written
  * Critical for SSDs with limited write cycles
* Maintain high performance
  * High write throughput
  * Good read throughput
  * Support range queries
* Work with existing infrastructure
  * API-compatible with LevelDB family
  * Drop-in replacement for applications

## Problem: LSM Write Amplification
* Root cause: maintaining sorted order requires rewriting data
  * Compaction merges overlapping sstables
  * Data rewritten multiple times as it moves through levels
  * Example: 500M key-value pairs (45GB) → 1868GB write IO (42× amplification)
* Impact on SSDs:
  * Limited write cycles (P/E cycles)
  * Device wear-out and replacement costs
  * Reduced write throughput (10% of read throughput in RocksDB)

## Key Design: Fragmented LSM Trees (FLSM)
* Core insight: Don't rewrite data in the same level
  * Fragment sstables into smaller units
  * Append new fragments instead of merging
  * Organize with guards (inspired by skip lists)

### Guards: Organizing Fragmented Data
* What are guards?
  * Keys selected from inserted data that divide key space
  * Each guard has associated sstables
  * Guards form a skip-list-like structure across levels
* Guard selection:
  * Probabilistically chosen from inserted keys
  * If key K is guard at level i, also guard at levels > i
  * More guards at deeper levels (progressively finer-grained)
* Example structure:
  ```
  Level 1: Guard 5 ──────────────────────────
  Level 2: Guard 5 ────── Guard 375 ─────────
  Level 3: Guard 5 ─ Guard 100 ─ Guard 375 ─ Guard 1023
  ```

### FLSM Compaction
* Instead of merging sstables:
  1. Sort sstables in guard
  2. Fragment (partition) based on child guards
  3. Append fragments to child guards in next level
* Benefits:
  * Data written once per level (except highest)
  * Compaction is parallelizable (guards are independent)
  * 2.5× faster compaction than LSM
* Example: Guard with keys {1, 20, 45, 101, 245}
  * Next level has guards 1, 40, 200
  * Partitioned into: {1, 20}, {45, 101}, {245}
  * Fragments appended to respective guards

## Lookup Complexity: FLSM vs LSM

### Normal LSM
* **O(L)** disk accesses where L = number of levels
  * Exactly 1 sstable per level examined (disjoint key ranges)
  * Binary search to find right sstable, then search within
* With bloom filters: Often just 1 disk access in practice

### PebblesDB (FLSM)
* **O(L × G)** disk accesses worst case
  * L = number of levels
  * G = number of sstables per guard
  * Must examine all sstables within one guard per level
* With bloom filters: **O(L)** disk accesses
  * Bloom filters eliminate ~99% of unnecessary reads
  * Usually examining 1+o(1) sstables per level

### Theoretical Analysis (Disk Access Model)
* Assumptions: Block size B, n total items
* FLSM with bloom filters:
  * O(log₂n × logᵦn) in-memory operations for finding guards
  * O(1) amortized disk reads (bloom filters indicate ~1 sstable)
* LSM with bloom filters: Also O(1) disk reads

### Practical Impact
* Without bloom filters: FLSM has significant overhead
* With bloom filters: Comparable complexity
  * PebblesDB achieves 27% better read throughput than RocksDB
  * Larger sstables = better cache utilization
* **Key insight**: Bloom filters are critical for FLSM performance

## Optimizations for Read Performance

### Sstable Bloom Filters
* Problem: FLSM reads multiple sstables per guard
* Solution: Bloom filter per sstable
  * Space-efficient probabilistic data structure
  * Eliminates ~99% of unnecessary sstable reads
  * Critical for maintaining read performance

### Parallel Seeks
* Problem: Range queries examine multiple sstables
* Solution: Multi-threaded sstable search
  * Each thread reads one sstable
  * Binary search in parallel
  * Merge results
  * Used only for last level (not cached)

### Seek-Based Compaction
* Triggered by consecutive seek operations (default: 10)
* Merges sstables within guard to reduce seek overhead
* Aggressive level compaction when level i within 25% of level i+1

## Performance Results

### Write Amplification Reduction
* 500M key-value pairs insertion:
  * PebblesDB: 756GB IO (17× amplification)
  * RocksDB: 1868GB IO (42× amplification)
  * HyperLevelDB: 1822GB IO (40× amplification)
* 2.4-3× reduction in write amplification

### Throughput Improvements
* Random writes: 6.7× better than RocksDB
* Random reads: 27% better than RocksDB
* Updates: 2.15× better than HyperLevelDB
* Real applications:
  * MongoDB: 18-105% throughput increase
  * HyperDex: up to 59% throughput increase

### Trade-offs
* Small range queries on fully compacted store: 30% overhead
  * Overhead drops to 11% for large range queries
  * Disappears when interspersed with writes
* Sequential inserts: Higher write IO than LSM
  * LSM can just move sstables without rewriting
  * FLSM must partition even non-overlapping data

## Key Insights
* Write amplification isn't fundamental to sorted storage
  * Can maintain partial sorting with guards
  * Fragment and organize instead of merge and rewrite
* Guards enable efficient parallel compaction
  * Each guard compacts independently
  * Better utilization of SSD parallelism
* Bloom filters crucial for fragmented designs
  * Overhead of checking multiple sstables
  * Probabilistic filters make this practical

## When to Use PebblesDB
* Good for:
  * Write-intensive workloads
  * Mixed read-write workloads
  * Large datasets that don't fit in memory
  * Applications sensitive to write amplification
* Not ideal for:
  * Small datasets that fit in memory
  * Sequential key insertions
  * Read-only workloads after initial bulk load
  * Workloads dominated by small range queries