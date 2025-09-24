# Masstree
## Goals
* Fast key-value store for multicore servers
  * All data fits in memory (in-memory)
  * Persistent across crashes
  * Support range queries
* Handle hard workloads
  * Skewed key popularity
  * Small key-value pairs
  * Many puts (writes)
  * Variable-length arbitrary keys

## Problem: DRAM is the bottleneck
* Network/disk can be optimized away
* Binary tree: O(log N) serial DRAM latencies
* Cache-craftiness: careful use of cache and memory

## Key Design: Trie of B+ Trees
* Each trie level = B+ tree indexed by 8-byte key slice
  * Level 0: k[0:7], Level 1: k[8:15], ...
* Combines benefits:
  * B+ tree: balanced, wide fanout
  * Trie: handles long common prefixes efficiently
* Example: keys with P-byte prefix
  * Masstree: O(log N) comparisons and DRAM accesses
  * Single B+ tree: O(P log N) for both

## Cache-Crafty Optimizations

### Wide Fanout (4-tree → B+ tree)
* 4-tree: fanout 4, one cache line per node
  * ½ levels vs binary tree → ½ DRAM latencies
  * Problem: unbalanced for sequential inserts
* B+ tree: fanout 15, balanced
  * 4 cache lines per node (256 bytes)

### Prefetching
* Software prefetch all cache lines of a node
* Result: 1 DRAM latency per node (vs 2-4)
* 9-31% throughput improvement

### Permuter
* Problem: B+ tree inserts rearrange keys → intermediate states
* Solution: store keys unsorted, use 64-bit permutation field
  * Encodes sort order + number of keys
  * Insert appears atomic to concurrent lookups
* No retry needed for concurrent reads

## Concurrency Control
* Optimistic concurrency control (OCC) for reads
  * No locks, no writing to shared data
  * Version checking: retry if inconsistent
* Fine-grained locking for writes
  * Lock only affected nodes (≤ 3 per operation)
  * Allows parallel updates to different parts

### RCU (Read-Copy-Update)
* Masstree inspired by RCU techniques
* What is RCU?
  * Synchronization mechanism allowing reads without locks
  * Readers access data structures without synchronization
  * Writers create new versions instead of modifying in-place
  * Old versions kept until all readers finish
* In Masstree:
  * Readers never block or use locks
  * Writers update by creating new versions
  * Epoch-based reclamation for garbage collection
  * Ensures readers always see consistent data

### Version Management
* Version field per node includes:
  * locked bit (for writers)
  * inserting/splitting bits (dirty markers)
  * vinsert/vsplit counters
* Writers mark dirty → make changes → clear & increment
* Readers snapshot version → read → check version

## Handling Splits
* Problem: splits move keys between nodes
* Solution: hand-over-hand validation
  * Check child version before parent
  * Detect splits via vsplit counter change
  * Retry from root on split detection

## Performance Results
* 140M keys, 16 cores:
  * Binary tree: 3.7M ops/sec
  * Masstree: 5.8M puts/sec, 8M gets/sec
* 1.7× improvement from cache-craftiness
* Scales to 12× on 16 cores

## Tradeoffs

### Single Tree vs Partitioning
* Partitioned (per-core trees):
  * Pro: no remote DRAM, no concurrency control
  * Con: load imbalance with skewed workloads
* Masstree (single shared tree):
  * Pro: handles skew well (3.5× better at δ=9)
  * Con: 1.5× slower for uniform workloads

### Range Queries vs Hash Table
* Hash table: 2.5× Masstree throughput
* Cost of range query support: 2.5× performance

## System Components
* Network: 10Gb NIC with multiple queues
* Logging: per-core logs to multiple SSDs
  * Batch writes, force every 200ms
* Checkpointing: periodic snapshots for recovery
* Values: multi-column support with atomic updates

## Key Insights
* DRAM latency dominates performance
* Wide fanout + prefetching reduces tree depth
* Permuter enables lock-free reads during inserts
* Trie structure efficiently handles long prefixes
* Single tree better for skewed workloads