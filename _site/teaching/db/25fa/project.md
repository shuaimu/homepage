# Project Ideas CSE 532 - Database Systems

In your final project, you will explore state-of-the-art techniques and apply them to Mako (OSDI '25), a database built on the same lab frameworks used in this class.
You are encouraged to explore the ideas that interest you, and/or develop your own ideas.
This document lists a few potential project topics you can refer to.

## Project Ideas

### 1. CXL-Enhanced Memory Architecture for Mako

**Motivation**: Compute Express Link (CXL) is revolutionizing database memory architectures by enabling coherent memory pooling across servers. Recent work like Tigon (OSDI'25) demonstrates up to 2.5× throughput improvements for distributed databases using CXL. Mako could benefit from CXL's memory disaggregation to reduce replication overhead and enable faster cross-shard transactions.

**Related Work**:
- Tigon: A Distributed Database for a CXL Pod, OSDI 2025
- Motor: Enabling Multi-Versioning for Distributed Transactions on Disaggregated Memory, OSDI 2024
- CXL and the Return of Scale-Up Database Engines, arXiv 2024
- An Examination of CXL Memory Use Cases for SAP HANA, VLDB 2024

**Project Tasks**:
1. **Survey existing approaches**: Study how Tigon, Motor, and SAP HANA leverage CXL for distributed transactions
2. **Design CXL integration for Mako**:
   - Identify which Mako components benefit most from CXL (e.g., shared lock tables, dependency graphs, commit logs)
   - Design memory coherence protocol for cross-shard coordination
   - Determine optimal placement of data structures in local vs. CXL memory
3. **Implementation**:
   - Integrate CXL memory pools into Mako's memory allocator
   - Modify critical data structures (e.g., Masstree nodes, transaction metadata) to leverage CXL
   - Implement hybrid approach: hot data in local DRAM, cold metadata in CXL memory
4. **Evaluation**:
   - Compare performance with baseline Mako on TPC-C and YCSB workloads
   - Measure memory bandwidth utilization and access latency
   - Evaluate scalability with varying numbers of CXL-connected nodes

**Expected Outcomes**: Demonstrate whether CXL can reduce cross-shard coordination overhead in Mako's speculative 2PC protocol, potentially achieving 1.5-2× throughput improvement.

**Fallback Plan**: If CXL hardware is unavailable, simulate CXL memory access patterns using shared memory or a software emulator to evaluate the design under emulated conditions.

---

### 2. Enhanced Optimistic Concurrency Control with Modern Techniques

**Motivation**: Mako currently implements a relatively basic version of Optimistic Concurrency Control (OCC). While OCC performs well under low contention, it suffers from high abort rates and wasted work under contention. Recent research has demonstrated significant OCC improvements: Mostly-Optimistic Concurrency Control (MOCC) achieves 8-23× better performance than traditional OCC on high-conflict workloads, while BCC reduces false aborts by up to 3.68×. Enhancing Mako's OCC implementation with modern techniques could dramatically improve performance on contentious workloads while maintaining its simplicity.

**Related Work**:
- Mostly-Optimistic Concurrency Control for Highly Contended Dynamic Workloads, VLDB 2017
- BCC: Reducing False Aborts in Optimistic Concurrency Control, VLDB 2016
- Improving Optimistic Concurrency Control through Transaction Batching and Operation Reordering, VLDB 2019
- Rethinking Serializable Multiversion Concurrency Control, VLDB 2015
- Adaptive Optimistic Concurrency Control for Heterogeneous Workloads, VLDB 2019

**Project Tasks**:
1. **Analyze Mako's current OCC implementation**:
   - Identify performance bottlenecks in validation phase
   - Measure abort rates under varying contention levels
   - Profile false abort scenarios (aborts that could have been avoided)
2. **Design OCC enhancements**:
   - **Early abort detection**: Detect conflicts during execution rather than at validation
   - **Parallel validation**: Batch multiple transactions and validate them in parallel
   - **Reduced false aborts**: Implement fine-grained dependency tracking (e.g., BCC-style)
   - **Operation reordering**: Reorder reads/writes within transactions to reduce conflicts
   - **Hybrid approach**: Add selective pessimistic locking for highly contended objects (MOCC-style)
3. **Implementation in Mako**:
   - Implement efficient data structures for enhanced OCC
   - Add batching logic to validator
   - Modify transaction execution to detect conflicts early
4. **Evaluation**:
   - Compare with baseline Mako OCC on TPC-C with varying contention levels
   - Measure abort rate reduction and throughput improvement
   - Test on skewed workloads with hotspots
   - Compare CPU and memory overhead

**Expected Outcomes**: Reduce abort rates by 40-60% on high-contention workloads and improve throughput by 2-5× compared to baseline OCC implementation.

**Fallback Plan**: If implementing multiple optimizations is too complex, focus on one technique (e.g., parallel validation or early abort detection) and evaluate its impact thoroughly.

---

### 3. Optimizing Geo-Distributed Transactions with Advanced Techniques

**Motivation**: While Mako achieves impressive performance with its speculative 2PC protocol, recent research demonstrates multiple promising approaches to further optimize geo-distributed transactions. Tiga (SOSP'25) achieves 1.3-7.2× higher throughput than state-of-the-art systems by consolidating concurrency control and consensus using synchronized clocks to commit transactions within a single wide-area roundtrip. Other approaches like decentralized coordination (D2PC, VLDB'24) reduce commit latency by 43%, while clock-based techniques (K2, VLDB'25) leverage precise timestamps for optimization. Applying these techniques to Mako could push its geo-replication performance even further.

**Related Work**:
- Tiga: Accelerating Geo-Distributed Transactions with Synchronized Clocks, SOSP 2025
- Fast Commitment for Geo-Distributed Transactions via Decentralized Co-Coordinators (D2PC), VLDB 2024
- K2: Optimizing Distributed Transactions with True-time Clocks, VLDB 2025
- SunStorm: Geographically distributed transactions over Aurora-style systems, VLDB 2025
- Bonspiel: Low Tail Latency Transactions in Geo-Distributed Databases, VLDB 2025

**Project Tasks**:
1. **Survey state-of-the-art approaches**: Study Tiga, D2PC, K2, SunStorm, and Bonspiel to understand:
   - How Tiga uses synchronized clocks to consolidate concurrency control and consensus
   - Decentralized coordination mechanisms in D2PC
   - True-time clock utilization in K2
   - Trade-offs between different approaches
2. **Choose and design optimization for Mako**:
   - **Option A - Synchronized Clock Protocol**: Adapt Tiga's approach to assign future timestamps and commit in 1 WRTT
   - **Option B - Decentralized Coordination**: Replace single coordinator with regional co-coordinators (D2PC-style)
   - **Option C - Hybrid Logical Clocks**: Implement clock-based ordering without requiring hardware support
   - **Option D - Optimized Commit Protocol**: Reduce coordination rounds through batching or pipelining
3. **Implementation**:
   - Integrate clock synchronization infrastructure (for Options A/C)
   - Modify Mako's commit protocol based on chosen approach
   - Extend transaction coordinator and replication layer
   - Implement necessary consensus mechanisms
4. **Evaluation**:
   - Deploy on geo-distributed testbed across 3-7 datacenters (AWS/Azure/GCP multi-region)
   - Measure commit latency (especially tail latency p99)
   - Compare throughput with baseline Mako
   - Test under varying network conditions and failures
   - Evaluate clock synchronization overhead (if applicable)

**Expected Outcomes**: Reduce commit latency by 30-50% and improve throughput by 1.5-3× on geo-distributed workloads, approaching 1 WRTT commit time for most transactions.

**Fallback Plan**: If the chosen approach proves too complex, implement a simplified version (e.g., clock-based ordering for single-datacenter transactions only, or decentralized coordination for read-only transactions).

---

### 4. Read-Only Transaction Fast Path with True-Time Support

**Motivation**: Many distributed database workloads are read-heavy. Mako's speculative protocol applies to all transactions, but read-only transactions don't need full 2PC coordination. By implementing a fast path for read-only transactions using snapshot isolation with true-time or hybrid logical clocks, we can achieve linearizable reads with near-zero coordination overhead.

**Related Work**:
- Spanner's TrueTime for lock-free read-only transactions (Google, OSDI 2012)
- K2: Optimizing Distributed Transactions with True-time Clocks, VLDB 2025
- Calvin's read-only transaction optimization
- CockroachDB's follower reads

**Project Tasks**:
1. **Survey timestamp-based approaches**: Study Spanner, K2, CockroachDB, and Calvin
2. **Design read-only fast path**:
   - Choose between true-time API (if available), hybrid logical clocks, or NTP-based timestamps
   - Design snapshot acquisition protocol that doesn't block on commit log
   - Ensure linearizability guarantees
3. **Implementation in Mako**:
   - Modify `TxnScheduler` to detect read-only transactions
   - Implement timestamp oracle or integrate HLC library
   - Add fast-path execution that bypasses 2PC
   - Maintain snapshot metadata per shard
4. **Evaluation**:
   - Test on read-heavy workloads (90% reads, 10% writes)
   - Measure latency improvement for read-only transactions
   - Verify correctness with linearizability checker
   - Compare with Spanner and CockroachDB if possible

**Expected Outcomes**: Reduce read-only transaction latency by 5-10× and improve overall system throughput by 2-3× on read-heavy workloads.

---

### 5. Early Lock Release for Reduced Contention in Geo-Replicated Mako

**Motivation**: Early Lock Release (ELR) allows transactions to release locks before commit, reducing lock hold time and improving throughput on contentious workloads. While traditionally applied to single-node databases, extending ELR to geo-distributed systems with replication is challenging but could significantly reduce the window of contention in Mako.

**Related Work**:
- Lock Violation for Fault-tolerant Distributed Database Systems, ICDE 2021
- Controlled Lock Violation, SIGMOD 2013
- Partial Strictness in Two-Phase Locking, ICDT 1995

**Project Tasks**:
1. **Survey ELR techniques**: Study controlled lock violation, partial strictness, and distributed ELR approaches
2. **Design ELR for Mako's speculative protocol**:
   - Determine safe points for early lock release in speculative 2PC
   - Design dependency tracking to ensure recoverability
   - Handle cascading aborts when speculation fails
3. **Implementation**:
   - Extend Mako's lock manager to support early release
   - Modify abort handling to cascade aborts correctly
   - Add logging mechanism to support recovery
4. **Evaluation**:
   - Test on high-contention workloads (e.g., TPC-C with hotspot skew)
   - Measure abort rate vs. throughput trade-off
   - Compare with baseline Mako and 2PL

**Expected Outcomes**: Improve throughput on contentious workloads by 20-40% with acceptable increase in abort rate.

**Fallback Plan**: Implement ELR only for read locks initially, which is safer and easier to reason about.

---

### 6. Learned Index Structures for Masstree

**Motivation**: Mako uses Masstree, a high-performance B+tree, for in-memory indexing. Recent learned index research (e.g., Google's Learned Index, PGM-Index, ALEX) shows that ML models can replace or augment traditional indexes with lower memory footprint and faster lookups. Integrating learned indexes into Masstree could reduce cache misses and improve transaction throughput.

**Related Work**:
- The Case for Learned Index Structures, SIGMOD 2018
- ALEX: An Updatable Adaptive Learned Index, SIGMOD 2020
- PGM-Index: Fully-Dynamic Compressed Learned Index, VLDB 2020
- Learned indexes for dynamic workloads, ICDE 2022

**Project Tasks**:
1. **Survey learned index structures**: Study RMI, ALEX, PGM-Index, and recent adaptations
2. **Design integration with Masstree**:
   - Identify whether to replace Masstree entirely or create hybrid structure
   - Design model training pipeline for Mako's key distributions
   - Handle updates and concurrent modifications
3. **Implementation**:
   - Integrate learned index library (e.g., ALEX) as alternative to Masstree
   - Implement fallback to B+tree for worst-case performance
   - Add online model retraining for workload drift
4. **Evaluation**:
   - Compare lookup latency, memory footprint, and update performance
   - Test on skewed and uniform key distributions
   - Measure impact on end-to-end transaction throughput

**Expected Outcomes**: Reduce index memory footprint by 2-3× and improve lookup latency by 20-30% on skewed workloads.

**Fallback Plan**: If full replacement is too complex, implement learned index as a top-level routing layer that directs queries to Masstree partitions.

---

### 7. Storage Disaggregation with Delta-Based Replication

**Motivation**: Cloud-native databases increasingly adopt storage disaggregation (e.g., AWS Aurora). Traditional replication rewrites full values, causing I/O amplification. A Key-Delta-Value (KDV) store that only replicates deltas could reduce cross-datacenter bandwidth and storage costs in Mako's geo-replication architecture.

**Related Work**:
- Key-Delta-Value stores for storage disaggregation
- FlexPushdownDB: Hybrid Pushdown and Caching in Cloud DBMS, VLDB 2021
- PushdownDB: Accelerating a DBMS using S3 Computation, ICDE 2020
- Aurora: On Avoiding Consensus for I/Os, SIGMOD 2018

**Project Tasks**:
1. **Survey delta-based storage**: Study Aurora, differential updates, and delta compression techniques
2. **Design KDV store for Mako**:
   - Define delta format (e.g., binary diff, operation log, column-level deltas)
   - Design read path that reconstructs values from base + deltas
   - Implement compaction policy to prevent long delta chains
   - Integrate with Mako's RocksDB backend
3. **Implementation**:
   - Extend RocksDB integration to store deltas
   - Modify write path to compute and store deltas
   - Implement efficient delta merging on read path
   - Add background compaction to collapse deltas
4. **Evaluation**:
   - Measure write bandwidth reduction
   - Compare read latency with baseline (full value storage)
   - Test on workloads with varying update sizes
   - Evaluate using YCSB with different read/write ratios

**Expected Outcomes**: Reduce cross-datacenter replication bandwidth by 50-70% for small updates, with acceptable read overhead.

---

### 8. Deterministic Execution Mode for Mako

**Motivation**: Deterministic databases like Calvin eliminate coordination overhead by pre-determining transaction order. While Mako's speculative approach differs fundamentally, adding a deterministic execution mode could benefit certain workloads (e.g., batch analytics, blockchain-style auditing) and provide stronger reproducibility guarantees.

**Related Work**:
- Calvin: Fast Distributed Transactions for Partitioned Database Systems, SIGMOD 2012
- Wait and See: Delayed Transaction Partitioning in Deterministic Databases, SIGMOD 2025
- Aria: A Fast and Practical Deterministic OLTP Database, VLDB 2020

**Project Tasks**:
1. **Survey deterministic protocols**: Study Calvin, Aria, and the SIGMOD 2025 delayed partitioning approach
2. **Design deterministic mode for Mako**:
   - Add sequencer component to order transactions globally
   - Design execution engine that follows predetermined order
   - Handle multi-partition transactions
   - Allow switching between speculative and deterministic modes
3. **Implementation**:
   - Implement transaction sequencer (can reuse Paxos layer)
   - Modify `TxnScheduler` to support deterministic execution
   - Add mode selection logic based on workload characteristics
4. **Evaluation**:
   - Compare with baseline Mako on low-contention and high-contention workloads
   - Measure determinism overhead
   - Test reproducibility and auditing use cases

**Expected Outcomes**: Enable deterministic execution for use cases requiring auditability, potentially matching or exceeding Calvin's performance.

**Fallback Plan**: Implement simplified deterministic mode for single-partition transactions only.

---

### 9. Cross-Shard Query Optimization with Minimal WAN Traffic

**Motivation**: Mako focuses on transactional workloads, but many applications require analytical queries that span multiple shards. Optimizing cross-shard queries to minimize wide-area network (WAN) traffic could enable Mako to support hybrid OLTP/OLAP workloads more efficiently.

**Related Work**:
- Distributed query optimization literature
- Choosing a Cloud DBMS: Architectures and Tradeoffs, VLDB 2019
- Predicate Transfer optimization techniques
- Distributed join algorithms with CXL (DaMon 2024)

**Project Tasks**:
1. **Survey distributed query optimization**: Study predicate pushdown, bloom filter shipping, semi-joins
2. **Design cross-shard query optimizer for Mako**:
   - Implement cost model for WAN vs. local computation
   - Add predicate transfer to reduce cross-shard data movement
   - Design distributed join strategies (broadcast vs. shuffle)
3. **Implementation**:
   - Extend Mako with basic query language (SQL subset or KV-based API)
   - Implement query planner and optimizer
   - Add distributed query execution engine
4. **Evaluation**:
   - Test on Join Order Benchmark (JOB) or TPC-H queries
   - Measure WAN bandwidth reduction
   - Compare with naive cross-shard query execution

**Expected Outcomes**: Reduce cross-datacenter traffic by 50-80% for analytical queries through intelligent optimization.

---

### 10. RDMA-Accelerated Replication for Mako

**Motivation**: Mako currently uses traditional TCP/IP networking for replication. Recent work like Motor (OSDI 2024) shows that RDMA operations can dramatically improve distributed transaction performance by bypassing the remote CPU and reducing network latency. Adding RDMA support to Mako's replication layer, particularly one-sided RDMA operations, could significantly reduce replication latency and improve throughput.

**Related Work**:
- Motor: Enabling Multi-Versioning for Distributed Transactions on Disaggregated Memory, OSDI 2024
- Fast and Scalable In-network Lock Management Using Lock Fission, OSDI 2024
- FaRM: Fast Remote Memory, NSDI 2014
- DrTM: Distributed Transactional Memory, SOSP 2015

**Project Tasks**:
1. **Survey RDMA-based distributed transactions**: Study Motor, FaRM, DrTM, and NAM-DB
2. **Design RDMA integration for Mako**:
   - Identify which replication operations can benefit from RDMA (e.g., log shipping, commit notifications)
   - Design remote memory layout for replicated data
   - Determine whether to use two-sided (verbs) or one-sided RDMA operations
   - Ensure consistency despite asynchronous RDMA operations
3. **Implementation**:
   - Add RDMA support to Mako's RRR communication framework
   - Implement RDMA connection management and memory registration
   - Modify Paxos replication layer to use RDMA for log shipping
   - Add RDMA-based commit notifications
4. **Evaluation**:
   - Measure replication latency reduction compared to TCP/IP baseline
   - Compare CPU utilization with traditional networking
   - Test scalability with varying number of replicas
   - Evaluate performance under different network conditions

**Expected Outcomes**: Reduce replication latency by 30-50% and lower CPU overhead by 40-60%.

---

### 11. Formal Verification of Critical Mako Components using Verus

**Motivation**: Distributed transaction systems like Mako involve complex concurrency control and consensus protocols where subtle bugs can lead to data corruption, consistency violations, or livelock. Traditional testing cannot exhaustively cover all possible interleavings and failure scenarios. Formal verification provides mathematical guarantees that critical components satisfy their specifications. Verus (SOSP'24), a practical verification tool for Rust, has been successfully used to verify distributed systems, OS kernels, and concurrent data structures—achieving 3-61× faster verification than prior tools. Applying Verus to verify Mako's critical components could catch bugs that testing misses and provide strong correctness guarantees.

**Related Work**:
- Verus: A Practical Foundation for Systems Verification, SOSP 2024
- Atmosphere: Practical Verified Kernels with Rust and Verus, SOSP 2025
- IronFleet: Proving Practical Distributed Systems Correct, SOSP 2015
- VerIso: Isolating DBMS bugs using formal verification, SIGMOD 2023
- Pushing the Limit: Verified Performance-Optimal Causally-Consistent Database Transactions, 2024

**Project Tasks**:
1. **Survey formal verification approaches for distributed systems**:
   - Study how Verus works and its verification methodology
   - Examine IronFleet's approach to verifying distributed protocols
   - Understand VerIso's verification of concurrency control protocols
   - Review verification case studies (Atmosphere OS kernel, concurrent allocators)
2. **Identify critical Mako components to verify**:
   - **Option A - OCC Validator**: Verify that validation logic correctly detects conflicts
   - **Option B - Paxos Consensus**: Verify safety properties (agreement, validity) of replication
   - **Option C - Speculative 2PC Protocol**: Verify that speculation doesn't violate serializability
   - **Option D - Lock Manager**: Verify deadlock-freedom and correct lock acquisition/release
   - **Option E - Dependency Graph**: Verify acyclicity guarantees and topological ordering
3. **Write formal specifications**:
   - Define invariants (e.g., "committed transactions are serializable")
   - Specify pre/post-conditions for critical functions
   - Model failure scenarios (network partitions, crashes)
   - Express liveness properties where applicable
4. **Port component to Rust and add Verus annotations**:
   - Extract the chosen component from Mako's C++ codebase
   - Rewrite in Rust with equivalent logic
   - Add Verus proof annotations (requires, ensures, invariant)
   - Use ghost code to track abstract state
5. **Verify and iterate**:
   - Run Verus verifier to check proofs
   - Debug failed proof attempts and fix bugs or strengthen specifications
   - Refine implementation to make verification tractable
6. **Evaluation**:
   - Document bugs found during verification (if any)
   - Compare verification effort (lines of proof vs. lines of code)
   - Measure verification time
   - Validate that verified Rust component has equivalent behavior to C++ original

**Expected Outcomes**: Successfully verify at least one critical component with formal guarantees of correctness properties. Potentially discover 1-3 subtle bugs during the verification process. Demonstrate that Verus can be applied to transaction system components with reasonable effort.

**Fallback Plan**: If full verification proves too difficult, focus on verifying a simplified version of the component (e.g., single-threaded OCC validator, or Paxos without reconfiguration). Alternatively, write specifications and partial proofs that identify verification challenges without completing the full proof.

---

## General Guidelines

### Project Structure

All projects should follow this general structure:

1. **Proposal Phase**
   - Read 5-10 relevant papers
   - Summarize state-of-the-art approaches
   - Identify gaps or opportunities
   - Propose clear design with diagrams
   - Analyze trade-offs
   - Get feedback from instructor/TA

2. **Implementation Phase**
   - Implement core functionality
   - Write unit and integration tests
   - Document code changes

3. **Evaluation Phase**
   - Run experiments on Mako benchmarks (e.g.,TPC-C, TPC-A, YCSB)
   - Collect performance metrics (throughput, latency, CPU, memory)
   - Create graphs and analysis

### Testing

All implementations must pass Mako's existing test suite:
```bash
./ci/ci.sh all
```

Additional project-specific tests should be added under `test/`.

### Getting Started with Mako

1. Clone and build:
```bash
git clone --recursive https://github.com/makodb/mako.git
cd mako
bash apt_packages.sh
make -j32
```

2. Run basic tests:
```bash
./ci/ci.sh simpleTransaction
./ci/ci.sh shard2Replication
```

3. Read the architecture docs:
- `CLAUDE.md` - Development guide
- `README.md` - High-level overview
- `src/mako/` - Mako-specific code
- `src/deptran/` - Transaction protocol implementations

### Evaluation Infrastructure

- **Local testing**: Use Docker Compose with multiple containers
- **Distributed testing**: Use cloud VMs (AWS/Azure/GCP)
- **Benchmarks**: TPC-C (default), TPC-A, YCSB, micro-benchmarks
- **Metrics**: Throughput (TPS), latency (p50, p99), abort rate, CPU/memory usage

---

## Additional Resources

### Conference Proceedings

- **OSDI**: [https://www.usenix.org/conferences/byname/179](https://www.usenix.org/conferences/byname/179)
- **SOSP**: [https://sigops.org/s/conferences/sosp/](https://sigops.org/s/conferences/sosp/)
- **VLDB**: [https://vldb.org/](https://vldb.org/)
- **SIGMOD**: [https://sigmod.org/](https://sigmod.org/)

### Mako Resources

- **GitHub**: [https://github.com/makodb/mako](https://github.com/makodb/mako)
- **OSDI'25 Paper**: Check conference proceedings (July 2025)
- **Development Guide**: See `doc` folder in repository

### Contact

For questions about specific projects or to propose your own ideas, please contact the course instructor.

---

**Last Updated**: 10/22/2025
