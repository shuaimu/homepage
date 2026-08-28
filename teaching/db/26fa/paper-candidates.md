---
layout: page
---

[
[Home](./index.html) |
[Schedule](./schedule.html) |
[Policy](./policy.html)
]

# Paper candidates for student presentations

Each presentation day has **four slots** (~15 min talk plus ~3 min Q&A). Pick  
**one paper** from the list that matches your date. Email the staff the title  
before you start preparing slides (first come, first served).

A paper may appear under more than one session if it fits both.

---

## Session II — Replication

Lectures: Raft; MongoDB pull-based replication. Consensus, primary-backup,  
leases, geo-replication, and replicated logs.

- Jetpack: Consensus Made Generally Fast. OSDI 2026. Ze Tang, Zihao Zhang, Weihai Shen, Jicheng Shi, Shuai Mu.
- Bodega: Localized Linearizable Reads at Anywhere Anytime via Roster Leases. OSDI 2026. Guanzhou Hu, Andrea C. Arpaci-Dusseau, Remzi H. Arpaci-Dusseau.
- LeaseGuard: Raft Leases Done Right. SIGMOD 2026. A. Jesse Jiryu Davis, Murat Demirbas, Lingzhi Deng (MongoDB). Direct sequel to the MongoDB lecture.
- Scalable Leader Leases For Multi Consensus Groups in CockroachDB. SIGMOD 2026 (industry). Ibrahim Kettaneh, Tsvetomira Radeva, Arul Ajmani, Sumeer Bhola, Nathan VanBenschoten, Rebecca Taft.
- Pineapple: Unifying Multi-Paxos and Atomic Shared Registers. NSDI 2025.
- Picsou: Enabling Replicated State Machines to Communicate Efficiently. OSDI 2025.
- One-Size-Fits-None: Understanding and Enhancing Slow-Fault Tolerance in Modern Distributed Systems. NSDI 2025.

---



## Session III — LSM

Lectures: LSM-Tree; RocksDB. Compaction, KV engines, write stalls, LSM
secondary indexes, disaggregated KV.

- Rethinking The Compaction Policies in LSM-trees. SIGMOD 2025. Hengrui Wang, Jiansheng Qiu, Fangzhou Yuan, Huanchen Zhang.
- How to Grow an LSM-tree: Towards Bridging The Gap Between Theory and Practice. SIGMOD 2025. Dingheng Mo, Siqiang Luo, Stratos Idreos.
- How Much Can RocksDB Chew? Achieving Near-Zero Write Stalls with Sustainable RocksDB (S-RocksDB). VLDB 2026. Hojin Shin, Yongmin Lee, Seehwan Yoo, Jongmoo Choi.
- Twenty Years of Bigtable. SIGMOD 2026 (industry). Fabio Baltieri et al. (Google).
- Disco: A Compact Index for LSM-trees. SIGMOD 2025. Wenshao Zhong, Chen Chen, Xingbo Wu, Jakob Eriksson.
- Mnemosyne: Dynamic Workload-Aware BF Tuning via Accurate Statistics in LSM trees. SIGMOD 2025. Zichen Zhu, Yanpeng Wei, Ju Hyoung Mun, Manos Athanassoulis.
- Optimizing LSM-trees via Active Learning. SIGMOD 2025. Weiping Yu, Siqiang Luo, Zihao Yu, Gao Cong.
- DFlush: DPU-Offloaded Flush for Disaggregated LSM-based Key-Value Stores. SIGMOD 2025. Chen Ding et al.
- Aster: Enhancing LSM-structures for Scalable Graph Database. SIGMOD 2025. Dingheng Mo, Junfeng Liu, Fan Wang, Siqiang Luo.
- O3-LSM: Maximizing Disaggregated LSM Write Performance via Three-Layer Offloading. SIGMOD 2026. Qi Lin et al.
- Improving Range Scan Performance in LSM-trees with Group Caching. SIGMOD 2026. Hengrui Wang, Jiaoyi Zhang, Jiansheng Qiu, Fangzhou Yuan, Huanchen Zhang.
- Making LSM-Tree-based Key-Value Store Practical and Efficient for Multi-Tenant Serverless Cloud Databases. SIGMOD 2026. Yingjia Wang et al. (Alibaba / CUHK).
- PartitionKV: Redesigning LSM-tree KV stores on NVMs with Adaptive Partitioning for Reducing Write stalls and Amplification. SIGMOD 2026. Xingye Huang et al.
- Fawkes: Finding Data Durability Bugs in DBMSs via Recovered Data State Verification. SOSP 2025. Zhiyong Wu, Jie Liang, Jingzhou Fu, Wenqian Deng, Yu Jiang.
- XLL: Cross-Layer Logging for Data Deduplication in Consensus-Based Storage. NSDI 2026. (TiKV Raft + WAL; also replication.)
- LSM-Raft: Optimizing Raft for LSM-tree Store. SIGMOD 2026. Xiaojian Zhang, Xinyu Tan, Shaoxu Song, Xiangdong Huang, Jianmin Wang.

---



## Session IV — B+ Trees

Lectures: Lehman–Yao B-link B-tree (Postgres nbtree); Masstree. Concurrent
trees, ART/radix trees, cache-conscious / pageable layouts, learned *tree*
indexes. Not vector ANN.

- Arctic: a practical lock-free adaptive radix tree. OSDI 2026. Newton Ni, Nicolas Garza, Jenny Stinehour, Michael Goppert, Michal Friedman, Emmett Witchel. 
- B-Trees Are Back: Engineering Fast and Pageable Node Layouts. SIGMOD 2025. Marcus Müller, Lawrence Benson, Viktor Leis.
- Buffered Persistence in B+ Trees. SIGMOD 2025. Mingzhe Du, Michael L. Scott.
- ART That Lasts: Persistent Multiversion Adaptive Radix Trees with Fast Atomic Range Queries. SIGMOD 2026. Mohammad Khalaji, Trevor Brown, Khuzaima Daudjee.
- Operation-Aware Hybrid Locking for Modern In-Memory Indexes (OPAL). VLDB 2026. Vishal Gupta et al. Evaluated on a B+ tree and ART.
- SIDLE: Tree-structure Aware Indexes for CXL-based Heterogeneous Memory. VLDB 2026. Haoru Zhao, Mingkai Dong, Fangnuo Wu, Haibo Chen. 
- DART: A Lock-free Two-layer Hashed ART Index for Disaggregated Memory. SIGMOD 2026. Bowen Zhang et al.
- Concurrent Path-Copying Update to Tree Structures. SIGMOD 2026. Guanhao Hou et al.
- Parallel kd-tree with Batch Updates. SIGMOD 2025. Ziyang Men, Zheqi Shen, Yan Gu, Yihan Sun.

---

## Session V — Transaction

Lectures: serializability (Franklin); Spanner. Distributed commit, OCC/2PL,
geo-transactions, deterministic scheduling.

- Tiga: Accelerating Geo-Distributed Transactions with Synchronized Clocks. SOSP 2025. Jinkun Geng, Shuai Mu, Anirudh Sivaraman, Balaji Prabhakar.
- SunStorm: Geographically distributed transactions over Aurora-style systems. VLDB 2026. Cuong Nguyen, Pooja Nilangekar, Heikki Linnakangas, Daniel Abadi.
- Sonata: Multi-Database Transactions Made Fast and Serializable. VLDB 2025. Chuzhe Tang, Zhaoguo Wang, Jinyang Li, Haibo Chen.
- Epoch-based Optimistic Concurrency Control in Geo-replicated Databases. SIGMOD 2026. Yunhao Mao et al.
- RIOT: Replicated Independently-Ordered Transactions. SIGMOD 2026 (industry). Jim Webber, Georgios Theodorakis, Hugo Firth, Natacha Crooks.
- Oze: Decentralized Graph-based Concurrency Control for Long-running Update Transactions. VLDB 2025.
- PolarDB’s Journey to Achieving 2 Billion tpmC. VLDB 2025 (industry). Xinjun Yang, Feifei Li, et al. (Alibaba).
- Tigon: A Distributed Database for a CXL Pod. OSDI 2025. Yibo Huang et al.
- BPF-DB: A Kernel-Embedded Transactional Database Management System For eBPF Applications. SIGMOD 2025. Matthew Butrovich, Samuel Arch, Wan Shen Lim, William Zhang, Jignesh Patel, Andrew Pavlo.
- Low-Latency Transaction Scheduling via Userspace Interrupts: Why Wait or Yield When You Can Preempt? SIGMOD 2025. Kaisong Huang, Jiatang Zhou, Zhuoyue Zhao, Dong Xie, Tianzheng Wang.
- Wait and See: A Delayed Transactions Partitioning Approach in Deterministic Database Systems. SIGMOD 2025. Yuan Sui et al.
- Are database system researchers making correct assumptions about transaction workloads? SIGMOD 2025. Cuong Nguyen, Kevin Chen, Christopher DeCarolis, Daniel Abadi.
- Brook-2PL: Tolerating High Contention Workloads with A Deadlock-Free Two-Phase Locking Protocol. SIGMOD 2026. Farzad Habibi, Juncheng Fang, Tania Lorido-Botran, Faisal Nawab.
- Focus! Fast On-disk Concurrency-control Using Sketches. SIGMOD 2026. Deukyeon Hwang et al.
- Modeling Concurrency Control as a Learnable Function. SIGMOD 2026. Hexiang Pan et al.
- Styx: Transactional Stateful Functions on Streaming Dataflows. SIGMOD 2025. Kyriakos Psarakis et al.
- GTX: A Write-Optimized Latch-free Graph Data System with Transactional Support. SIGMOD 2025. Libin Zhou, Yeasir Rayhan, Lu Xing, Walid Aref.
- Design and Modular Verification of Distributed Transactions in MongoDB. VLDB 2025 (industry). William Schultz, Murat Demirbas.
- Moving on From Group Commit: Autonomous Commit Enables High Throughput and Low Latency on NVMe SSDs. SIGMOD 2025. Lam-Duy Nguyen et al.

---



## Session VI — SQL

Lectures: Selinger access-path selection / System R optimizer; Spanner SQL.
Join order, cardinality, cost models, execution engines, distributed SQL.

- Automatic Indexing in Oracle. VLDB 2025 (industry). Sunil Chakkappen et al.
- SQL:Trek Automated Index Design at Airbnb. VLDB 2025 (industry). Sam Lightstone, Ping Wang.
- Ultron: History-Based Query Optimization at Databricks. VLDB 2026 (industry).
- Aurora PostgreSQL Limitless Database: Building a Highly Scalable OLTP Database. SIGMOD 2026 (industry). Dima Arkhangelskiy, Sergey Melnik, et al. (AWS).
- veDB-HTAP: a Highly Integrated, Efficient and Adaptive HTAP System. VLDB 2025 (industry). Jianjun Chen, Li Zhang, et al. (ByteDance).
- TDSQL-Boundless: A Distributed Database System for Large-scale Heterogeneous Multi-Table Workloads. SIGMOD 2026 (industry). Yuxing Chen et al. (Tencent).
- SERON: Smart Query Router for Multi-Primary Cloud-Native Databases with Shared Storage. VLDB 2026 (industry).
- AnalyticDB-PG: A Cloud-native High-performance Data Warehouse in Alibaba Cloud. VLDB 2025 (industry).
- Hermes – an High-Performance OLAP Accelerator for MySQL. VLDB 2025 (industry). Tim Gubner, Rune Humborstad, Manyi Lu.
- Grouping, subsumption, and disjunctive join optimisations in Oracle. VLDB 2025 (industry). Rafi Ahmed et al.
- GRewriter: Practical Query Rewriting with Automatic Rule Set Expansion in GaussDB. VLDB 2025 (industry). Zhe Jiang, Zhaoguo Wang, et al.
- R-Bot: An LLM-based Query Rewrite System. VLDB 2025 (industry). Zhaoyan Sun, Xuanhe Zhou, Guoliang Li, et al.
- The HANA Native Query Engine for Lakehouse Systems. VLDB 2025 (industry). Daniel Ritter et al. (SAP).
- Towards Industrial-Scale Parametric Query Optimization. VLDB 2026 (industry).
- Learned Query Optimizer in Alibaba MaxCompute: Challenges, Analysis, and Solutions. SIGMOD 2026 (industry).
- CoddSpeed: Hardware Accelerated Query Processing in Microsoft Fabric. SIGMOD 2026 (industry).
- Bitmap Filtering in the Fabric Data Warehouse. SIGMOD 2026 (industry). Nicolas Bruno et al.
- Cortex AISQL: A Production SQL Engine for Unstructured Data. SIGMOD 2026 (industry). Pawel Liskowski et al. (Snowflake).



---



## Session VII — Weaker Isolation and Consistency

Lectures: ANSI isolation / snapshot isolation; CockroachDB (geo-distributed SQL,
MVCC). Snapshot isolation, MVCC, weaker consistency, isolation bugs, freshness
vs. isolation.

- Running Consistent Applications Closer to Users with Radical for Lower Latency. SOSP 2025. Nicolaas Kaashoek, Oleg A. Golev, Austin T. Li, Amit Levy, Wyatt Lloyd.
- Skybridge: bounded staleness for asynchronously replicated caches at Meta. OSDI 2025.
- MD-MVCC: Multi-version Concurrency Control for Schema Changes in Azure SQL Database. VLDB 2025 (industry). Panagiotis Antonopoulos et al. (Microsoft).
- Swan: Hybrid MVCC Management for Efficient Transaction Processing in LSM-Tree-Based Key-Value Stores. VLDB 2026. Yang Guo, Jin Xue, Zili Shao.
- TxnSails: Achieving Serializable Transaction Scheduling with Self-Adaptive Isolation Level Selection. VLDB 2025. PostgreSQL RC / SI / SSI.
- VerIso: Verifiable Isolation Guarantees for Database Transactions. VLDB 2025. Formal SI / SSER.
- Perseus: Achieving Strong Consistency and High Data Freshness for Scalable Geo-distributed HTAP. SIGMOD 2026. Haoze Song et al.
- ART That Lasts: Persistent Multiversion Adaptive Radix Trees with Fast Atomic Range Queries. SIGMOD 2026. Mohammad Khalaji, Trevor Brown, Khuzaima Daudjee. (MVCC on ART.)
- Pisco: An Isolation Bug Case Reduction and Deduplication Framework. VLDB 2026. Siyang Weng et al.
- Translytical Processing via DB-OS Co-designed Buffer: Cross-Engine Isolation and Tunable Update Visibility for HTAP. SIGMOD 2026. Dongkwang Kim, Keonwook Park, Cheolmin Choi, Hyungsoo Jung.
- Breaking the Isolation-Freshness Trade-off (Jasper on TiDB). VLDB 2026.
- CRDV: Conflict-free Replicated Data Views. SIGMOD 2025. Nuno Faria, José Pereira. (CRDTs / weaker consistency.)
- Epoch-based Optimistic Concurrency Control in Geo-replicated Databases. SIGMOD 2026. Yunhao Mao et al.
- BACH (VLDB 2025) includes a lightweight MVCC / snapshot-isolation scheme on an LSM graph store.
- Sonata: Multi-Database Transactions Made Fast and Serializable. VLDB 2025. Also SI middleware (Epoxy) as a baseline.
- Focus! Fast On-disk Concurrency-control Using Sketches. SIGMOD 2026. Deukyeon Hwang et al.
- Performant Synchronization in Geo-Distributed Databases. SIGMOD 2026. Duling Xu et al.
- Fast Verification of Strong Database Isolation (serializability and snapshot isolation). VLDB 2026. Zhiheng Cai, Si Liu, Hengfeng Wei, Yuxing Chen, Anqun Pan.

