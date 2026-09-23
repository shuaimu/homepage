// CSE 532, Fall 2026. September 21, 2026.
// typst compile DB26fa-RocksDB.typ
// typst compile --input handout=true DB26fa-RocksDB.typ DB26fa-RocksDB-handout.pdf
// Measurements and feature status refer to the 2021 paper, not current releases.
#import "@preview/touying:0.7.4": *
#import "rocksdb-theme.typ": *
#import "rocksdb-diagrams.typ": *
#show: lecture-theme

// 1
#lecture-slide(source: [§1], notes: [1 minute. The FAST 2021 experience paper. Full title: Evolution of Development Priorities in Key-value Stores Serving Large-scale Applications: The RocksDB Experience. This lecture describes its historical setting.])[RocksDB][
  #v(32pt)
  #text(font: title-font, size: 44pt, weight: "semibold")[An LSM engine in production]
  #v(24pt)
  CSE 532 · Database Systems\
  September 21, 2026
  #v(35pt)
  #text(size: 19pt, fill: muted)[Dong, Kryczka, Jin, and Stumm\ _The RocksDB Experience_ · FAST 2021]
]

// LevelDB history and the RocksDB fork.
// 2
#lecture-slide(notes: [1 minute. Jeff Dean and Sanjay Ghemawat developed LevelDB at Google. Its public open-source announcement was July 27, 2011; this is the release date, not a claim about when work first began. Google's announcement describes a small, portable C++ library and a building block for higher-level storage systems. Bigtable's tablet storage used a precursor. Batched updates across a large key space, including indexes larger than memory, were a design target. Chrome's IndexedDB and Riak's per-node storage were early uses. Source: https://opensource.googleblog.com/2011/07/leveldb-fast-persistent-key-value-store.html Authors also identified at https://github.com/google/leveldb])[LevelDB at Google, 2011][
  #comparison(columns: (.55fr, 2.45fr),
    [*Who*], [Jeff Dean and Sanjay Ghemawat at Google],
    [*When*], [Open-sourced July 27, 2011],
    [*Why*], [Portable, embedded storage for ordered key/value data],
    [*Workload*], [Efficient batch updates over a large key space],
    [*Roots*], [Ideas from Bigtable's tablet storage],
  )
  #caption[Early uses: Chrome's IndexedDB and Riak's per-node storage.]
  #takeaway[An LSM storage library that applications could embed directly.]
]

// 3
#lecture-slide(source: [§1, Appendix A], notes: [1 minute. Facebook created RocksDB from the LevelDB code base in 2012, as stated in the FAST paper. Facebook announced the open-source release on November 21, 2013. The release announcement reports write stalls from single-threaded LevelDB compaction on some server workloads; this is historical evidence, not a claim about every LevelDB workload. RocksDB added parallel compaction, reduced write amplification, and customizable components to use fast SSDs and many CPU cores. Local embedded access also avoided an extra network request for each engine operation. Explain this as a fork with different engineering goals, not a rename or a Google successor release. Release and motivation source: https://engineering.fb.com/2013/11/21/core-infra/under-the-hood-building-and-open-sourcing-rocksdb/])[Facebook's fork: RocksDB][
  #small[*2012:* Facebook's database team forks LevelDB.]
  #v(18pt)
  #small[*November 21, 2013:* RocksDB released as open source.]
  #v(30pt)
  #columns[
    #text(size: 27pt, weight: "bold")[Why fork?]
    #v(18pt)
    LevelDB's single compaction thread caused write stalls on some server workloads.
  ][
    #text(size: 27pt, weight: "bold")[What changed?]
    #v(18pt)
    Parallel compaction, less write amplification, and tunable components for fast SSDs and many CPU cores.
  ]
  #takeaway[RocksDB retained LevelDB's embedded, ordered key/value interface.]
]

// 4
#lecture-slide(talk-pages: [4–5], source: [§1, §2.1], notes: [1 minute. Created at Facebook in 2012 from LevelDB. MyRocks, TiKV, and stream processors illustrate applications above the library. A shared engine also shares monitoring, debugging, and durability expertise.])[Where RocksDB sits][
  #architecture()
  #takeaway[One embedded library, many application architectures.]
  #caption[Targets high throughput on SSDs and multicore CPUs; replication stays in the application.]
]

// 5
#lecture-slide(source: [§2.2], notes: [1 minute. Map abstract LSM components to their concrete implementation. Disk components are sets of immutable files. Tombstones remain until they are safe to discard.])[From the previous LSM lecture][
  #comparison(columns: (1fr, 1.4fr),
    [*1996 LSM concept*], [*RocksDB representation*],
    [In-memory component C₀], [Memtable, typically a skiplist],
    [A frozen memory component], [Immutable memtable, then an L0 SSTable],
    [Disk components C₁ … Cₖ], [Levels of immutable SSTable files],
    [One-pass merge], [Compaction of selected files],
    [Deletion record], [Tombstone],
  )
]

// 6
#lecture-slide(source: [§2.2, §4: WAL treatment], notes: [1 minute. A full memtable freezes while a fresh one accepts writes. The WAL records recovery information when enabled. Arrows show logical paths, not precise synchronization or acknowledgment order. Durability settings come later.])[The write path][
  #write-path(stage: 3)
  #takeaway[Flush turns a mutable buffer into an immutable sorted file.]
]

// 7
#lecture-slide(source: [§2.2], notes: [1 minute. Conceptual inventory, not exact byte layout. Index entries locate sorted data blocks. Filters and properties help avoid unnecessary work.])[Inside an SSTable][
  #sstable()
  #v(8pt)
  #small[The index locates a data block. The filter can rule out a file.]
  #caption[Conceptual structure. Block sizes and metadata layout are simplified.]
]

// 8
#lecture-slide(source: [§2.2, Figure 1], notes: [1 minute. Each flush is a sorted run. L0 file ranges may overlap. Later levels partition the key space into nonoverlapping files within each level. Toy keys and values are illustrative. Width encodes key range, not bytes. Deeper levels are omitted.])[L0 overlap and L1 partitioning][
  #lsm()
  #caption[Key ranges overlap in L0. Within each later level, they do not.]
]

// 9
#lecture-slide(source: [§2.2], notes: [1 minute. Get(g) misses memory and finds g=7 in L0, without reading g=2 in L1. Newest visible version wins. Snapshots affect visibility. Filters and caches can avoid physical I/O. Simplified leveled lookup.])[Point lookup: Get(g)][
  #lsm(mode: "lookup")
  #caption[Search memtables, relevant L0 files, then at most one file per later level.]
]

// 10
#lecture-slide(source: [§2.2], notes: [1 minute. L0 is special: a-m overlaps h-s, so both L0 files join this input set. Together they overlap all three L1 files. Moving newer overlapping data below older L0 data would break the simplified lookup order. This example makes overlap closure visible.])[Compaction inputs][
  #lsm(mode: "select")
  #caption[Select overlapping L0 inputs and every L1 file their ranges overlap.]
]

// 11
#lecture-slide(source: [§2.2], notes: [1 minute. The selected files are merged by key and sequence number. The figure shows selected records from the preceding example; other keys are omitted. Sequence numbers and the older k=3 are illustrative. No snapshot needs the overwritten versions. The three output ranges match the preceding L1 ranges. Install the new version before retiring inputs. The memtable k=9 remains outside compaction and newer than disk k=6.])[Compaction outputs][
  #compaction-records()
  #caption[Selected records shown; other keys omitted. No snapshot needs the old versions.]
]

// Section divider before the HDD and SSD examples.
// 12
#lecture-slide(section: true, notes: [0 minutes. Introduce why the write behavior of flash motivates LSM storage. The next slides compare an HDD in-place page update with SSD copying, then connect this to LSM batching.])[Why do we need LSM on SSD?][]

// Matched four-page examples before the LSM motivation.
// 13
#lecture-slide(notes: [1 minute. Read each cell as an equal-size page. A1 and A2 are the old and new contents of page A. A conventional HDD can overwrite A at the same location without moving B, C, or D. The block here is a conceptual grouping of four pages to align with the next example, not a physical erase unit: HDDs address sectors and do not have NAND's block-erase constraint. Assume full-page aligned writes and omit metadata and drive-specific behavior such as SMR. Background: OSTEP, Flash-based SSDs, section 44.5, https://pages.cs.wisc.edu/~remzi/OSTEP/file-ssd.pdf])[HDD: update one page in place][
  #small[Change page A from A1 to A2. Each cell below is one page.]
  #v(16pt)
  #hdd-page-update()
  #takeaway[One page update writes one page; the other pages are untouched.]
  #caption[Four pages shown for illustration.]
]

// Restore the block-copy example while keeping reclamation timing explicit.
// 14
#lecture-slide(notes: [2 minutes. NAND flash programs pages but erases whole blocks. A2 is written to an erased page elsewhere, making A1 obsolete. To reclaim the old block, preserve its live pages B, C, and D by copying them to fresh space, then erase the old block. The figure combines the update and later reclamation, placing A2 and the three copied pages in one fresh block for clarity. An SSD does not immediately copy a whole block for every update, and valid pages need not all go to the same destination block. Here four equal-size page writes inside the SSD divided by one page received from the host gives device write amplification of four. These are illustrative counts, not a measured result; metadata is omitted. Device WA is normally measured over an interval in bytes. Extra writes consume bandwidth and program/erase endurance; wear leveling spreads wear across cells. NAND pages are not necessarily database pages. Source: OSTEP, Flash-based SSDs, sections 44.4, 44.7, and 44.10, https://pages.cs.wisc.edu/~remzi/OSTEP/file-ssd.pdf])[SSD: copying creates write amplification][
  #small[Flash erases whole blocks. Live pages must be saved before erasing.]
  #v(16pt)
  #ssd-block-copy()
  #takeaway[1 updated page + 3 copied pages = 4 page writes (4×).]
  #caption[Four-page example, including later reclamation. The SSD can defer this copying.]
]

// 15
#lecture-slide(talk-pages: [8–11], source: [§2.1, §3: write amplification], notes: [2 minutes. A database page and a NAND page are different units; do not equate them. A small in-place record update can cause a database page rewrite before the SSD even sees the write. LSM batching amortizes such small updates, but compaction creates engine-level write amplification. The SSD independently creates device-level amplification through GC and other internal work. Sequential host writes do not guarantee device amplification of one. Endurance is finite because NAND tolerates a limited number of program/erase cycles. Local SSD access also motivated the embedded engine.])[Why LSM on flash?][
  #lsm-flash-writes()
  - Batch small updates instead of rewriting a database page for each one.
  - Compaction and internal SSD copying both create extra writes.
  #takeaway[LSM changes the write pattern; it does not eliminate write amplification.]
]

// Section divider before the three individual policies.
// 16
#lecture-slide(section: true, notes: [0 minutes. Transition to the choice of compaction policy. The next three slides explain leveled, universal/tiered, and FIFO.])[Compaction policies][]

// 17
#lecture-slide(source: [§2.2], notes: [2 minutes. In leveled compaction, levels below L0 partition the key space into nonoverlapping files. Pick the L1 g–n file and merge it with L2 files g–k and l–p. Output replaces the selected g–p range; a–f and q–z are untouched. Older versions can be dropped only when snapshot and deletion rules allow it. L0 is special because its files overlap. The earlier compaction input/output slides give the record-level walkthrough. Smaller retained overlap generally helps reads and space but requires more rewriting. Reference: https://github.com/facebook/rocksdb/wiki/Compaction])[Leveled: merge overlapping key ranges][
  #leveled-policy()
  - Keep nonoverlapping file ranges within each level below L0.
  - Merge selected files with the overlapping files in the next level.
  #takeaway[More rewriting buys lower read and space amplification.]
]

// 18
#lecture-slide(source: [§2.2], notes: [2 minutes. A sorted run may contain one file or several key-partitioned files. Universal is RocksDB's tiered-style policy. This illustrative selection merges the two older runs and leaves the newest alone. Output keeps the latest selected value per key, assuming no snapshot needs older versions: a=5, g=2, m=3, z=6. The newest run still contains g=7, which wins globally. Real selection depends on configured size/run-count/space triggers; it does not always pick exactly two or always pick the oldest. Reference: https://github.com/facebook/rocksdb/wiki/Compaction])[Universal / tiered: merge whole sorted runs][
  #universal-policy()
  - Let overlapping sorted runs accumulate; merge selected runs together.
  - Defer merges to reduce rewriting, while keeping more runs to read.
  #takeaway[Usually cheaper writes, with more read work and retained space.]
]

// 19
#lecture-slide(source: [§2.2, Table 3], notes: [2 minutes. In the basic FIFO policy, SSTs live in L0. Once total file size exceeds the limit, delete oldest files until it fits. Equal-size files make the example's size limit easy to see. Keys found only in the discarded file are lost intentionally; FIFO is appropriate only when the application permits this retention rule. File age is not a per-key TTL guarantee. Optional merging and TTL variants exist, so do not promise a universal write amplification of one or replace the paper's measured FIFO result. Reference: https://github.com/facebook/rocksdb/wiki/FIFO-compaction-style])[FIFO: discard the oldest files][
  #fifo-policy()
  - Reclaim space by deleting whole files, without merging their records.
  - Use only when the application permits old data to disappear.
  #takeaway[Low write cost comes from a different retention contract.]
]

// 20
#lecture-slide(source: [Table 3 and caption, RocksDB 5.9 microbenchmark], notes: [4 minutes. Denominators matter: SST bytes include flush and compaction output, excluding WAL and SSD-internal writes. Space amplification 1.095 means 9.5 percent overhead. Tiered uses 12 sorted runs. FIFO uses 20 Bloom bits per key. Direct I/O, cache at 10 percent of fully compacted DB size. FIFO space is N/A because it discards data. Filters make these point reads look similar, while write cost and retained space differ sharply. Physical read I/O depends on access pattern, filters, and cache. Distinguish a point Get from an iterator seek or scan; more read metrics are in the appendix. This experiment is not a prediction for every workload.])[Measured compaction tradeoffs][
  #comparison(columns: (1.2fr, 1fr, 1.2fr, 1.2fr),
    [*Policy*], [*Write amp.*], [*Avg. space\ overhead*], [*Point Get I/O\ with Bloom*],
    [Leveled], [16.07×], [9.5%], [0.99],
    [Tiered], [4.80×], [45.5%], [1.03],
    [FIFO], [2.14×], [N/A], [1.16],
  )
  #v(20pt)
  #small[
    *Write amp.* = SST bytes written / memtable bytes flushed.\
    *Space overhead* = (current size / fully compacted size − 1) × 100%.
  ]
  #caption[RocksDB 5.9. Write amp. includes flush and compaction, excluding WAL and SSD-internal writes. FIFO discards data.]
]

// 21
#lecture-slide(source: [§1, §2.2, §3], notes: [3 minutes. Answers are visible beside each application. Ask what changes these choices. A write-heavy workload may still choose leveled for read latency or capacity. FIFO requires explicit permission to discard data. These are starting points for the stated constraints, not universal application defaults.])[Which policy fits the application?][
  #comparison(columns: (1.05fr, 1.15fr, 2fr),
    [*Application*], [*Suggested policy*], [*Why it fits*],
    [User database], [*Leveled*], [Frequent reads and tight capacity favor fewer files and lower space overhead.],
    [Stream state], [*Universal / tiered*], [Heavy ingestion favors fewer rewrites, with room for more retained runs.],
    [Overflow cache], [*FIFO*], [Fixed capacity, old data may disappear. Delete old files without merging.],
  )
]

// 22
#lecture-slide(section: true, notes: [0 minutes. Introduce Bloom filters from first principles before returning to RocksDB's read path.])[Bloomfilter][]

// 23
#lecture-slide(notes: [1 minute. A membership query asks whether a key belongs to a set. Here the set is the keys represented by one SST. A Bloom filter is a compact summary made of bits, not another copy of the keys and values. Its negative answer rules out membership; its positive answer requires checking the actual data. Source: Bloom, Space/Time Trade-offs in Hash Coding with Allowable Errors, 1970, https://www.cs.princeton.edu/courses/archive/spr05/cos598E/bib/p422-bloom.pdf])[A small test before reading an SST][
  #small[A Bloom filter summarizes a set of keys using a small array of bits.]
  #v(20pt)
  #bloom-membership()
  #takeaway[It tests membership; it does not return the value.]
]

// 24
#lecture-slide(notes: [2 minutes. Each hash function deterministically maps a key to an array index. This toy filter has eight bits and uses three hash positions per key. Start at all zeros. Insert k at positions 0, 2, 4, then m at 2, 5, 7. Position 2 is shared and stays 1. The final bit vector is 10101101. The hash outputs are chosen for illustration, not computed using a production hash. Source: https://github.com/facebook/rocksdb/wiki/RocksDB-Bloom-Filter])[Building a filter: set bits with hashes][
  #small[Three hash functions each map a key to one bit position.]
  #v(18pt)
  #bloom-build()
  #takeaway[Each key sets three positions to 1. Existing 1s stay 1.]
  #caption[Eight-bit example. The same key always gives the same positions.]
]

// 25
#lecture-slide(notes: [2 minutes. Reuse exactly the same hash functions and bit array. Query g probes positions 1, 3, 5, which contain 0, 0, 1. One zero is enough to reject it. An inserted key would have set all its queried bits, so it cannot be rejected by this intact insertion-only filter. This is the no-false-negatives property. Source: Bloom, 1970, https://www.cs.princeton.edu/courses/archive/spr05/cos598E/bib/p422-bloom.pdf])[A zero means “definitely absent”][
  #small[Query g uses the same hash functions as insertion.]
  #v(18pt)
  #bloom-negative()
  #takeaway[No false negatives: an inserted key cannot be ruled out.]
  #caption[Assumes the same hashes and an intact filter.]
]

// 26
#lecture-slide(notes: [2 minutes. For k, positions 0, 2, 4 are all 1 and the SST contains k: true positive. For w, positions 0, 5, 7 are also all 1, but only k and m were inserted: false positive. Bits set by different keys can collectively satisfy another query. The actual SST lookup resolves membership, so the filter does not produce a wrong database value. Shared bits also explain why a basic Bloom filter cannot delete a key by simply clearing its bits. Source: Bloom, 1970, https://www.cs.princeton.edu/courses/archive/spr05/cos598E/bib/p422-bloom.pdf])[All ones mean “maybe present”][
  #small[Every checked bit is 1 in both queries below. Only one key is present.]
  #v(18pt)
  #bloom-positive()
  #takeaway[A false positive causes extra work, not a wrong database answer.]
]

// 27
#lecture-slide(source: [§2.2, §3: CPU utilization, Table 3], notes: [2 minutes. Simplified whole-key, full-file filtering for a point Get after memory misses. Among candidate files selected by the read path, a negative filter avoids a data lookup; a positive triggers normal SST lookup and visibility handling. When enabled, filters are built from keys as new SSTs are created by flush or compaction. They live in the SST format and are accessed through memory or cache, so a filter access itself is not always free of I/O. More bits per key generally lower false-positive probability at a memory cost. Prefix filters may also help some seeks; whole-key filters do not remove general range-scan merging. Source: https://github.com/facebook/rocksdb/wiki/RocksDB-Bloom-Filter])[Bloom filters in the RocksDB read path][
  #small[After checking memory, Get(g) tests the filters of candidate SSTs.]
  #v(16pt)
  #bloom-ssts()
  - More bits per key use more memory and reduce false positives.
  - Whole-key filters help point lookups; scans still merge runs.
  #caption[Filters must themselves be available in memory or cache.]
]

// 28
#lecture-slide(section: true, notes: [0 minutes. Move from the storage mechanisms to the production measurements that changed RocksDB's optimization priorities.])[Resource optimization][]

// 29
#lecture-slide(talk-pages: [13], source: [Table 2, Figure 3, §3], notes: [3 minutes. Table 2 gives one typical use case per category, not fleet averages. Figure 3 separately surveys 42 ZippyDB/MyRocks deployments. Flash endurance means utilization of the endurance budget, not fraction of lifetime already worn out. The cache is an instructive exception.])[What the deployed workloads used][
  #comparison(columns: (1.5fr, .75fr, .85fr, 1fr, 1fr),
    [*Example*], [*CPU*], [*Space*], [*Flash\ endurance*], [*Read\ bandwidth*],
    [Stream processing], [11%], [48%], [16%], [1.6%],
    [Logging / queues], [46%], [45%], [7%], [1.0%],
    [Index services], [47%], [61%], [5%], [10.0%],
    [Cache], [3%], [78%], [74%], [3.5%],
  )
  #v(24pt)
  #small[Table 2 examples. The separate 42-deployment survey found most workloads space constrained.]
]

// 30
#lecture-slide(talk-pages: [12–20], source: [§3], notes: [1 minute. These objectives accumulate. Write-heavy applications may still prioritize endurance while others prioritize space.])[The bottleneck moved][
  #bottlenecks()
  #takeaway[The data structure survived. The optimization target changed.]
]

// 31
#lecture-slide(source: [§3: space amplification, Table 4], notes: [2 minutes. Static targets can leave the actual bottom level underfilled relative to upper levels. Dynamic leveling derives targets from the actual last-level size. Under 13 percent here is a measured result, not a universal bound. Random updates, 2 MB/s, DB size about 12–60 GB.])[Dynamic level sizes reduce space overhead][
  #small[Set level targets from the *actual last-level size*.]
  #v(12pt)
  #comparison(columns: (1fr, 1fr, 1fr),
    [*Keys*], [*Dynamic targets*], [*Static targets*],
    [200 million], [12.4%], [25.6%],
    [400 million], [11.8%], [12.2%],
    [600 million], [12.2%], [16.9%],
    [800 million], [12.7%], [19.7%],
    [1 billion], [12.4%], [22.4%],
  )
  #v(9pt)
  #caption[Space overhead in Table 4's random-update experiment. Lower is better.]
]

// 32
#lecture-slide(talk-pages: [15–20], source: [§3: CPU utilization, Appendix A], notes: [2 minutes. The paper could generally saturate one SSD with a suitable CPU. CPU/DRAM became cost targets even when they did not constrain throughput. Compression and multiple SSDs per CPU can change that. Parallelism is not a claim of lower total CPU work.])[CPU and DRAM became cost targets][
#small[CPU and DRAM became more expensive relative to flash.]
  #v(18pt)
  - Hosts reserve spare capacity for growth and failures, so low CPU use can be intentional.
  - Checking a filter before the index avoids searches and unnecessary data reads.
  - Batched lookups and parallel I/O overlap independent work instead of waiting in sequence.
  #takeaway[Optimize cost per request as well as peak throughput.]
]


// Added after CPU cost discussion.
// 33
#lecture-slide(source: [§3: adapting to newer technologies], talk-pages: [16–20], notes: [2 minutes. The talk compares a CPU with two 2 TB SSDs to a CPU with three. Changing that ratio can exchange unused CPU for unused flash without balancing both. Decoupled storage allows independent provisioning; it does not guarantee full utilization. Longer I/O latency motivates batching and parallelism. Transient failures and QoS also become explicit concerns.])[Disaggregation separates compute and capacity][
#small[Disaggregation puts SSDs on storage servers reached over a network.]
  #v(12pt)
  #disaggregation()
  #v(18pt)
  #small[Compute and flash can grow independently. Network delays and failures now require retries, batching, and I/O priorities.]
]

// 34
#lecture-slide(section: true, notes: [0 minutes. Follow corruption across replicas, memory, files, and storage interfaces, then consider recovery policies.])[Data integrity and recovery][]

// 35
#lecture-slide(source: [§5, Figure 4], notes: [1 minute. A checksum is a small deterministic summary of bytes, commonly a CRC for accidental corruption. Save it while data is believed correct and compare against that saved value later. Different bytes can collide, so a match is not a mathematical proof of equality. Checksums detect rather than repair corruption and are not authentication against a malicious modifier. C is a teaching notation.])[What a checksum can detect][
  #small[A checksum is a small number computed from bytes to detect accidental changes.]
  #v(22pt)
  + *Create:* for data x, compute C(x) and save it with the data or its metadata.
  + *Verify:* read or receive bytes y, then compute C(y) using the same function.
  + *Compare:* if C(y) differs from the saved C(x), reject the data as corrupted.
  #takeaway[A mismatch detects a change. It cannot reconstruct the original bytes.]
  #caption[A match can miss a checksum collision. The expected checksum must also be protected.]
]

// 36
#lecture-slide(talk-pages: [30–40], source: [§5: frequency of silent corruptions], notes: [1 minute. The RocksDB estimate came from comparing MyRocks primary/secondary indexes, including CPU/memory corruption. Forty percent had propagated. The transfer estimate came from one observed period with storage-stack bugs. These are not universal SSD error rates.])[Rare corruption matters at scale][
#small[Silent corruption means wrong bytes without an obvious I/O failure.]
  #v(22pt)
  #columns[
    #text(size: 42pt, weight: "bold", fill: red)[1 / 3 months]
    #v(18pt)
    #small[One detected RocksDB corruption per three months across about 100 petabytes (PB).]
    #v(20pt)
    #small[*40%* had already reached another replica.]
  ][
    #text(size: 42pt, weight: "bold", fill: red)[17 / PB]
    #v(18pt)
    #small[Checksum mismatches per petabyte of files transferred in one observed period.]
    #v(20pt)
    #small[Software bugs were an important cause.]
  ]
  #takeaway[Replication helps only while a correct copy remains.]
  #caption[These are production observations, not universal hardware error rates.]
]


// Added to make the talk's replica-replacement failure sequence explicit.
// 37
#lecture-slide(source: [§5: detecting corruption early], talk-pages: [30–36, 39–40], notes: [2 minutes. A single shard has replicas on different hosts. The application replicates operations using Paxos; RocksDB does not implement that protocol. After unnoticed corruption on host 1, a physical copy builds host 4 and the application retires healthy host 2. Copying 4 to 5 and retiring healthy 3 removes the last good replica. This is unchecked replacement, not a correct repair policy. Early detection instead lets the application discard the bad replica and rebuild from a validated healthy source. CPU/memory corruption can start the same chain even when later file checksums are valid.])[Unchecked copies can replace every good replica][
#small[Three hosts hold copies of the same shard. Red marks corrupted data.]
  #v(12pt)
  #replica-loss()
  #v(18pt)
  #small[Validate the source before replacing a healthy replica with its copy.]
]

// 38
#lecture-slide(talk-pages: [29, 37–43], source: [§5, Figure 4], notes: [2 minutes. Block checksums came from LevelDB. File checksums arrived in 2020. Handoff checksums require a supporting storage API, rarely exposed by local filesystems. Per-KV checksums were in progress. This diagram reports the 2021 design.])[Integrity checks at different boundaries][
#small[A checksum covers a specific set of bytes between creation and verification.]
  #v(12pt)
  #checksums()
  #caption[KV means key/value. Detection still needs a valid copy for recovery. Status shown as in 2021.]
]


// File checksums are checked during movement, in addition to per-block read checks.
// 39
#lecture-slide(source: [§5: file integrity, Figure 4], talk-pages: [37–38], notes: [2 minutes. The SST checksum is generated when the file is created, saved in its metadata entry, and carried with that identity through transfers. Verify the received contents against that saved expectation. Recomputing a new expected checksum after corruption would merely legitimize bad bytes. Reject a mismatching new replica. Backup and restore both need verification. The 2021 paper says other files, including WAL files, did not yet have this whole-file protection. A complete database copy still includes the necessary metadata and recovery state.])[Verify SSTs during copy, backup, and restore][
  #verified-transfer()
  #takeaway[Reject a mismatch before accepting the copied SST.]
  #caption[2021: whole-file checksums protect SSTs; WAL files require separate protection.]
]

// 40
#lecture-slide(talk-pages: [39–41], source: [§5: end-to-end protection], notes: [2 minutes. Block checksums compare with bytes when the checksum was generated. They cannot detect prior memory corruption. A per-KV checksum carried from an earlier boundary can catch corruption before it becomes durable.])[A checksum can protect the wrong value][
#bitflip()
  Why did verification pass?
  #pause
  #takeaway[The checksum was computed after corruption. An earlier record checksum could catch the change before flush.]
]


// The proposed per-record protection covers the paths above the file layer.
// 41
#lecture-slide(source: [§5: end-to-end protection, Figure 4], talk-pages: [41], notes: [2 minutes. This is the proposed/in-progress design in 2021. Carry a checksum with each record wherever it is copied in memory. Verify writes from the client, memtable flushes, records during compaction, and reads from memtables or block cache before returning them. Existing block checksums protect SST file data, so the per-KV checksum need not be persisted there. Integrity checks do not correct a corrupt record by themselves; recovery still needs a valid source.])[Carry record checksums through memory][
#small[Compute a checksum per key/value record and carry it with each memory copy.]
  #v(16pt)
  #comparison(columns: (.7fr, 2fr),
    [*Boundary*], [*Where to verify the record*],
    [Write], [Check the key/value checksum passed into the engine.],
    [Flush], [Check memtable records before writing SST blocks.],
    [Compaction], [Check decoded records while merging and rewriting files.],
    [Read], [Check memtable and block-cache records before returning them.],
  )
  #v(18pt)
  #small[Keep block checksums on SSTs. Record checksums cover the memory paths.]
  #caption[Proposed / in progress in the 2021 paper. A mismatch detects, but does not repair, corruption.]
]

// 42
#lecture-slide(source: [§5: handoff integrity], talk-pages: [42–43], notes: [2 minutes. Distinguish a WAL fragment's internal checksum, storage's own protection, and the checksum across their API boundary. A buffer can be corrupted while being copied, before reliable storage establishes its protection. The WAL checksum might detect this later on a read, too late to reject the acknowledged write. A handoff checksum is computed before copying and verified by the receiver before accepting the write. A suitable API is needed; local file systems rarely provided it in the paper's environment. Remote storage APIs can expose it.])[Protect the write across the storage API][
#small[H(b) is a checksum made before RocksDB passes write buffer b to storage.]
  #v(12pt)
  #handoff()
  #caption[Storage recomputes H from the received bytes b′ and rejects a mismatch before acknowledging the write. This requires a supporting API.]
]

// 43
#lecture-slide(source: [§5: severity-based error handling], notes: [2 minutes. Earlier behavior returned errors or halted writes permanently. Local recovery is preferable for transient conditions. Disk-full needs the condition to clear, not a tight retry loop. Corruption needs isolation and a validated recovery path.])[Errors need different recovery policies][
#small[The response must address the cause. Retrying cannot repair corrupted bytes.]
  #v(18pt)
  #comparison(columns: (1fr, 1.6fr),
    [*Condition*], [*Response*],
    [Transient remote I/O failure], [Retry or resume once connectivity or the service recovers.],
    [Out of space], [Pause writes, reclaim capacity, then resume safely.],
    [Confirmed corruption], [Isolate the bad data and rebuild from a validated replica or backup.],
  )
  #takeaway[Automatic retry fits a temporary failure. Corruption needs a known-good recovery source.]
]

// 44
#lecture-slide(section: true, notes: [0 minutes. Introduce the operational demands of many instances, durability choices, file deletion, upgrades, configuration, and replication.])[Operating RocksDB at scale][]

// 45
#lecture-slide(talk-pages: [22–28], source: [§4: resource management], notes: [2 minutes. Tens or hundreds of shards share a host. Controllers need global budgets and local fairness. Shared pools avoid thread explosion. Separate processes make global coordination harder, requiring conservative allocation or shared usage information.])[Many instances share one host][
#small[One data partition (shard) per instance. A host may run 100 instances.]
  #v(12pt)
  #resources()
  #v(18pt)
  #small[Share the block cache (read data) and write buffers (recent writes). Per-instance caps keep one busy shard from exhausting the host.]
]

// 46
#lecture-slide(source: [§2.2, §4: WAL treatment], notes: [1 minute. WAL records recover writes that have not yet become durable SST data. Replaying the log reconstructs memtable contents after reopening. A WAL segment can be retired only after all data it protects no longer requires it. Sync means forcing log data to persistent storage, assuming the storage stack honors that request. Source: https://github.com/facebook/rocksdb/wiki/Write-Ahead-Log-(WAL)])[What the write-ahead log protects][
  #small[The WAL is an append-only record used to recover recent writes.]
  #v(22pt)
  + *Before flush:* Put(k, 9) updates a memtable and records the write in the WAL.
  + *After a crash:* RAM is lost. Replay surviving WAL records to rebuild the memtable.
  + *After durable flush:* SSTs contain the data. Retire a WAL segment when none of its records are still needed.
  #takeaway[A write in memory needs a durable recovery source.]
]

// 47
#lecture-slide(source: [§4: WAL treatment], notes: [2 minutes. Replication alone does not prove WAL can be disabled. The upper layer must durably preserve and replay acknowledged writes, and coordinate log truncation with persistent engine progress. Buffered WAL durability depends on flush/sync policy.])[The WAL follows the durability contract][
#comparison(columns: (.75fr, 2.25fr),
    [*WAL mode*], [*What success means*],
    [Synchronous], [Sync the WAL before acknowledging a durable write.],
    [Buffered], [Return before sync. Unsynced writes may be lost in a machine crash.],
    [Disabled], [Write no RocksDB WAL. Recover using another durable source.],
  )
  #v(18pt)
  When is a replicated consensus log enough?
  #pause
  #takeaway[It must replay every required write and retain the log until RocksDB has persisted the data.]
]

// 48
#lecture-slide(source: [§4: rate-limited file deletions], notes: [2 minutes. With configurations such as XFS realtime discard, deletion can issue TRIM. SSD translation metadata updates and garbage collection can affect foreground reads. This depends on filesystem settings and firmware.])[Deleting files can stall reads][
#small[Compaction can make many old SST files obsolete at once.]
  #v(12pt)
  #delete-chain()
  #v(18pt)
  #small[TRIM tells the SSD which ranges are unused. Garbage collection (GC) reclaims flash. Spreading deletions out avoids a burst of this work.]
  #caption[This coupling depends on filesystem settings and SSD firmware.]
]

// 49
#lecture-slide(source: [§4: data format compatibility], notes: [2 minutes. Define compatibility from the reader's perspective. The paper aimed for at least one year of forward compatibility, with new-feature exceptions. This is the historical policy, not a current blanket guarantee. Unknown optional fields differ from unknown required semantics.])[Rolling upgrades constrain file formats][
#small[A rolling upgrade replaces servers gradually, so old and new code coexist.]
  #v(18pt)
  #comparison(columns: (1fr, 2fr),
    [*Operation*], [*Why the reader must handle this format*],
    [Upgrade], [New code must open files written by old code.],
    [Rollback], [Old code must open files written during the upgrade.],
    [Replica bootstrap], [A new replica may receive files from a different version.],
  )
  #v(20pt)
  #small[Example: rolling back the binary is unsafe if it cannot read yesterday's SSTs.]
  #caption[2021 policy: keep old formats readable and aim for at least one year of forward compatibility, with exceptions for new features.]
]

// 50
#lecture-slide(source: [§4: managing configurations, Table 5], notes: [1 minute. Despite standardization efforts, over 25 configurations appeared across 39 ZippyDB deployments. Default changes can increase memory or concurrency unexpectedly. Some options affect file compatibility. Tools persisted options, validated opening, and supported limited migration.])[Configuration becomes an operational interface][
#block(above: 0pt, below: 18pt)[#text(size: 47pt, weight: "bold", fill: red)[25+ configurations]]
  #block(above: 0pt, below: 0pt)[#text(size: 23pt, fill: muted)[across 39 sampled ZippyDB deployments]]
  #v(26pt)
  - Save chosen options beside the database so restarts can reproduce them.
  - Check compatibility before opening existing files with changed options.
  - Pin intended settings during upgrades: a new default may reserve more RAM.
  #caption[Examples: memtable size, cache budget, compression, and compaction policy.]
]

// 51
#lecture-slide(talk-pages: [23–28], source: [§4: replication and backup support], notes: [2 minutes. Logical copying scans keys without polluting the source cache, then bulk-loads the destination. Physical copying pins a consistent set of necessary files including metadata and recovery state. Filesystem access lets applications reuse copy tools. Copying SSTs alone is not a full replication protocol.])[Replication needs storage-engine support][
#small[A new replica needs a consistent starting copy of an existing database.]
  #v(12pt)
  #copy-files()
  #v(18pt)
  #small[*Pinning* keeps the selected files alive while compaction continues.]
  #v(12pt)
  #small[*Logical copying* instead reads key/value records and bulk-loads fresh files.]
]

// 52
#lecture-slide(section: true, notes: [0 minutes. Introduce the limits of local sequence numbers and the motivation for application-defined timestamps.])[Versions and timestamps][]

// 53
#lecture-slide(source: [§6: versions and timestamps], notes: [2 minutes. A sequence number is RocksDB's internal local ordering of writes; it is not an application timestamp or an elapsed-time measure. A user-defined timestamp is supplied by the application and may use a physical or logical clock. Enabling timestamps adds a version field; sequence numbers still exist. There is no automatic universal conversion between sequence numbers and timestamps, and equal sequence numbers on different instances are unrelated. For the same user key, the documented user-timestamp implementation requires seq1 < seq2 to imply ts1 <= ts2. Snapshot visibility and timestamp visibility are both applied on reads. These API details clarify the paper's concepts; timestamp support was partial in 2021. Sources: https://github.com/facebook/rocksdb/wiki/User-defined-Timestamp and https://github.com/facebook/rocksdb/wiki/Snapshot])[Sequence numbers and timestamps][
  #comparison(columns: (.85fr, 1.55fr, 1.7fr),
    [*Property*], [*Sequence number*], [*User timestamp*],
    [Assigned by], [RocksDB], [The application],
    [Meaning], [Write order within one RocksDB instance], [Application version time, physical or logical],
    [Read limit], [Snapshot at sequence S], [Read at timestamp T],
  )
  #takeaway[A version can carry both: sequence 101 and timestamp 30.]
  #caption[For one key, timestamps cannot decrease as sequence numbers increase.]
]

// 54
#lecture-slide(source: [§6: versions and timestamps], notes: [1 minute. Two retained versions of one user key. The application supplies timestamps 20 and 30, while RocksDB assigns sequences 100 and 101. The application takes and holds snapshot S=100 between the two writes. In the latest view, both writes pass sequence visibility, and the timestamp limit chooses the newest eligible version: T=25 returns 80, T=35 returns 81. With the earlier snapshot, sequence 101 is invisible even at T=35, so the result is 80. This demonstrates that timestamps add a visibility condition rather than replace sequence numbers. Assume simple Put operations with no deletions or merges and both versions retained. Ordinary snapshots must be taken while the desired view is current; they cannot recover discarded history. Source: https://github.com/facebook/rocksdb/wiki/User-defined-Timestamp#dbget and https://github.com/facebook/rocksdb/wiki/Snapshot])[Sequence and timestamp limits both apply][
  #small[Two versions of key k. Take snapshot S=100 before the second write.]
  #v(18pt)
  #comparison(columns: (1fr, 1fr, 1fr, 1fr),
    [*Write*], [*Sequence*], [*Timestamp*], [*Value*],
    [First], [100], [20], [80],
    [Second], [101], [30], [81],
  )
  #v(22pt)
  - Latest view, timestamp 25: return *80*.
  - Latest view, timestamp 35: return *81*.
  - Snapshot S=100, timestamp 35: return *80*.
  #caption[An active snapshot preserves its view. Timestamp reads also need retained history.]
]

// 55
#lecture-slide(source: [§6: versions and timestamps], notes: [1 minute. Illustrative independent write histories. The same sequence number on two instances does not denote the same application time. The paper's ordinary snapshots are local; this is not a claim that applications can never coordinate snapshots. A distributed protocol must choose a shared read time, ensure relevant writes are applied, and retain the necessary versions. Source: https://github.com/facebook/rocksdb/wiki/Snapshot])[Local sequence numbers are not a shared clock][
  #small[Each RocksDB instance numbers its own writes independently.]
  #v(22pt)
  #comparison(columns: (1fr, 1fr, 1.5fr),
    [*Instance*], [*Local snapshot*], [*Application time reached*],
    [Shard A], [Sequence 100], [t = 20],
    [Shard B], [Sequence 100], [t = 35],
  )
  #v(24pt)
  Equal sequence numbers can represent different application times.
  #takeaway[Reading all shards at time 25 needs a shared timestamp and a coordination protocol.]
  #caption[Illustrative histories. Timestamp support helps express the read; the application still coordinates it.]
]

// 56
#lecture-slide(source: [§6], notes: [2 minutes. Timestamp-in-key can require iterators for version queries, and filters are less helpful unless they understand the encoding/prefix. Timestamp-in-value complicates old versions and out-of-order writes. User timestamps are metadata. Transactions were another API extension used by MyRocks.])[Where should a version timestamp live?][
#small[Query: return the version of account/7 visible at time 25.]
  #v(18pt)
  #comparison(columns: (.9fr, 1.15fr, 1.95fr),
    [*Placement*], [*Example*], [*How to find the version*],
    [In the key], [`account/7@20`], [Seek among versioned keys for the latest timestamp ≤ 25.],
    [In the value], [`(20, balance=80)`], [The application must store and search a history of values.],
    [Separate metadata], [`key, ts, value`], [A timestamp-aware Get selects the visible version for the user key.],
  )
  #caption[Separate timestamp semantics let the engine filter by user key and skip files outside the requested time range.]
]

// 57
#lecture-slide(source: [§6], notes: [2 minutes. A conceptual MVCC example, not exact API syntax. Read at 25 selects the newest retained version at most 25. Applications still supply meaningful timestamps and coordinate distributed consistency. File timestamp ranges can prune irrelevant SSTables.])[A timestamp-aware point lookup][
#timestamp-versions()
  #v(18pt)
  #small[Choose the newest retained version with timestamp ≤ 25: t=20.]
  #caption[The application controls timestamp order, history retention, and coordination across shards.]
]

// 58
#lecture-slide(source: [§6, Table 6], notes: [2 minutes. Populate then measure the second phase. Baseline encodes timestamps in user keys. These are measured ratios, not guaranteed speedups. Richer semantics improve point lookup, filtering, and file pruning, but cost space, API simplicity, and portability.])[Timestamp metadata improved this benchmark][
#small[Baseline: timestamps encoded in user keys. Results are throughput ratios.]
  #v(14pt)
  #comparison(columns: (2fr, 1fr),
    [*Populate, then measure*], [*Throughput gain*],
    [Sequential fill, random reads], [1.2×],
    [Sequential fill, reads during writes], [1.9×],
    [Random fill, random reads], [1.9×],
    [Random fill, reads during writes], [2.0×],
  )
  #v(20pt)
  #small[2.0× means twice as many operations per second in this DB_bench experiment.]
  #caption[Engine-aware timestamps improve lookup and filtering, at the cost of space and API complexity.]
]

// 59
#lecture-slide(section: true, notes: [0 minutes. Bring the resource, durability, and integrity decisions together in a design exercise and recap.])[Discussion and takeaways][]

// 60
#lecture-slide(source: [Discussion based on §3–§6], notes: [2 minutes. Allow one minute for discussion. The following slide expands the answers. Expected answers: host budgets with local caps, durable replay with safe log truncation, pinned consistent file set, version compatibility, and transfer checksums. Compaction policy still depends on capacity and reads.])[Design discussion][
A host runs 100 shards, each with a RocksDB instance. A consensus log durably records writes. New replicas copy data from existing hosts.
  #v(20pt)
  + Which resources need a shared budget?
  + When is it safe to disable the RocksDB WAL?
  + What must a new replica verify before using a copied database?
  #pause
  #takeaway[Use host budgets, replayable logs, and a verified file set.]
]

// 61
#lecture-slide(source: [Discussion based on §3–§6], notes: [2 minutes. One possible design, not a unique implementation. Memory examples are budgets rather than measured allocations. Log retention must cover replay of acknowledged writes until engine progress is durable. Pinning preserves the file set; format compatibility allows it to open; checksums test copied bytes. Distributed log catch-up may still be needed after the initial copy.])[Design discussion: one possible design][
  + *Shared resources:* cap cache, memtable memory, and background I/O. Give each shard a bounded share.
  + *Recovery:* disable the RocksDB WAL only if the durable consensus log can replay lost writes. Retain it until engine state is durable.
  + *Replica copy:* pin a consistent file set, check format compatibility, and verify file checksums before using the copy.
  #takeaway[Replication provides recovery only when these conditions hold.]
]

// 62
#lecture-slide(source: [§9, Appendix B], notes: [2 minutes. Students should trace reads/writes, explain compaction tradeoffs, distinguish benchmarks from operational constraints, and justify durability/integrity boundaries. The remaining slides are optional.])[What to remember][
  - Memtables batch small writes. SSTs keep data sorted. Compaction removes obsolete versions.
  - Leveled compaction spends more writes to reduce retained space and read work.
  - Measure the limiting resource: flash endurance, capacity, CPU, or memory cost.
  - Set host-wide budgets and identify which durable log can replay lost memory state.
  - Check data before trusting a copy. Retain the versions needed for timestamped reads.
]

// 63
#lecture-slide(section: true, notes: [Optional, 0 minutes. Supporting examples, measurements, and project history for reference or further discussion.])[Appendix][]

// 64
#lecture-slide(source: [§3: adapting to newer technologies], notes: [Optional, 2 minutes. Historical framing. Device-specific latency/endurance improvements helped a minority of these workloads. Remote SSDs enabled independent provisioning. This is not a 2026 hardware-market survey.])[Appendix: hardware priorities in 2021][
#comparison(columns: (1fr, 2fr),
    [*Direction*], [*What it offers*],
    [Host-managed flash], [Open-channel, zoned namespaces (ZNS), and multi-stream SSDs expose placement or write-order controls.],
    [Remote SSDs], [Access flash over a network to scale storage capacity separately from compute.],
    [Storage-class memory], [Persistent memory between DRAM and SSDs in cost and latency. Possible roles: cache, main store, or WAL.],
  )
  #v(20pt)
  #small[The paper asks whether each feature improves the workload's limiting resource enough to justify its cost.]
]

// 65
#lecture-slide(source: [§3: main data structure revisited], notes: [Optional, 2 minutes. KV separation is the WiscKey idea cited by the paper. BlobDB was being added. A reference is cheaper to compact than a large value, but values still need garbage collection and introduce read/locality tradeoffs.])[Appendix: separating keys and large values][
#small[Example: a small key points to a 4 KB value.]
  #v(24pt)
  #columns[
    #text(size: 28pt, weight: "bold")[Values inside SSTs]
    #v(17pt)
    SST entry: key + 4 KB value
    #v(21pt)
    Every compaction copies the large value along with the key.
  ][
    #text(size: 28pt, weight: "bold")[Values in separate files]
    #v(17pt)
    SST entry: key + location
    #v(21pt)
    The value stays elsewhere. Reads follow its location to fetch it.
  ]
  #takeaway[Less compaction copying, but extra value reads and garbage collection.]
  #caption[Value garbage collection reclaims bytes that no live key references.]
]

// 66
#lecture-slide(source: [Table 3 and caption], notes: [Optional, 2 minutes. Point lookups hide run-count differences when filters are effective. Iterator seeks expose more work. These are benchmark measurements, not asymptotic complexities.])[Appendix: read costs depend on the operation][
#small[Get looks up one key. An iterator seek positions a scan at a starting key.]
  #v(14pt)
  #comparison(columns: (1fr, 1.3fr, 1.3fr, 1.3fr),
    [*Policy*], [*Get I/O\ with Bloom*], [*Get I/O\ without Bloom*], [*Iterator\ seek I/O*],
    [Leveled], [0.99], [1.70], [1.84],
    [Tiered], [1.03], [3.39], [4.80],
    [FIFO], [1.16], [528], [967],
  )
  #v(18pt)
  #small[Filters can reject files for an exact key. A seek must find the next key across runs, exposing FIFO's many-file read cost.]
  #caption[RocksDB 5.9, direct I/O, cache at 10% of compacted size. Tiered: 12 runs. FIFO: 20 filter bits/key.]
]


// Additional references from the FAST talk.
// 67
#lecture-slide(talk-pages: [6], source: [Appendix A], notes: [Optional, 2 minutes. Historical milestones as dated in the FAST talk, which includes deployments not listed in the paper's feature timeline. These are original project milestones, not release recommendations.])[Appendix: project milestones, 2012–2016][
#comparison(columns: (.45fr, 2.5fr),
    [*Year*], [*Milestone and purpose*],
    [2012], [LevelDB fork. Multiple compaction threads use more CPU cores.],
    [2013], [Open source and production use. Pluggable parts allow customization.],
    [2014], [Backup support creates restorable database copies.],
    [2015], [MongoRocks for MongoDB at Facebook. Transactions and bulk loading.],
    [2016], [MyRocks for MySQL at Parse. DeleteRange removes a key interval.],
  )
]

// 68
#lecture-slide(talk-pages: [6], source: [Appendix A], notes: [Optional, 1 minute. Complete the talk's timeline. NVM caching was an experiment. User-defined timestamp support was partial in 2020. These qualifications matter.])[Appendix: project milestones, 2017–2020][
#comparison(columns: (.45fr, 2.5fr),
    [*Year*], [*Milestone and purpose*],
    [2017], [Experiments with nonvolatile-memory (NVM) caching.],
    [2018], [Rocksandra for Cassandra at Instagram. Work on remote, disaggregated storage.],
    [2019], [MultiGet issues independent reads in parallel for a batch of keys.],
    [2020], [Partial support for timestamps supplied by the application.],
  )
  #caption[Historical status in the talk: NVM work was experimental and timestamp support was partial.]
]

// 69
#lecture-slide(source: [Figure 3 and caption], talk-pages: [13], notes: [Optional, 2 minutes. This is the original chart image embedded in the FAST presentation, extracted without redrawing or estimating its bars. The paper describes 42 ZippyDB/MyRocks deployments observed for one month. Each metric is averaged across hosts within a deployment. CPU and read bandwidth use the busiest hour, while space and flash endurance use month averages. Thus do not compare the four metrics as simultaneous instantaneous load. This is distinct from the category examples in Table 2.])[Appendix: the 42-deployment survey][
  #grid(columns: (390pt, 1fr), column-gutter: 28pt,
    image("assets/fast21-utilization.png", width: 374pt),
    [
      #text(size: 23pt, weight: "bold")[ZippyDB and MyRocks]
      #v(24pt)
      #small[One bar per deployment; averages across its hosts.]
      #v(28pt)
      #small[*CPU / read bandwidth:* busiest hour in the month.]
      #v(28pt)
      #small[*Space / endurance:* average over the month.]
      #v(28pt)
      #small[The paper identifies storage capacity as the common constraint.]
      #v(22pt)
      #text(size: 16pt, fill: muted)[Endurance is write-budget usage, not the fraction of the SSD lifetime already worn out.]
    ],
  )
]

// 70
#lecture-slide(source: [§3: write amplification], talk-pages: [9–10], notes: [Optional, 1 minute. Preserve the talk's motivating estimates without treating them as the RocksDB Table 3 benchmark. The talk characterizes engine-level write amplification as often in the hundreds, file systems as near one, and SSD internal amplification as one to three. The paper separately describes software amplification up to about 100 and SSD amplification of 1.1 to 3. These differ in framing and rounding. Layer factors multiply only when adjacent byte-count boundaries align; adding these factors would be wrong.])[Appendix: amplification at each layer][
#small[Write amplification compares output bytes with input bytes at one layer.]
  #v(14pt)
  #comparison(columns: (1fr, 1fr, 1.6fr),
    [*Layer*], [*Talk's rough scale*], [*Why bytes multiply*],
    [Storage engine], [Often hundreds×], [Rewrite a full database page for a small record update.],
    [Filesystem], [About 1×], [Pass the writes to the SSD.],
    [Inside the SSD], [About 1–3×], [Copy live pages while reclaiming flash blocks.],
  )
  #v(18pt)
  #small[Example: rewriting a 4 KB page for a 50-byte change is about 82×, before any extra SSD writes.]
  #caption[These are motivating estimates, not Table 3 results. The paper reports software amplification up to about 100× and SSD amplification of 1.1–3×.]
]
