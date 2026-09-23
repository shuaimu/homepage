# Coverage of the original FAST 2021 presentation

Audit date: September 20, 2026.

Source: [Siying Dong's official presentation on USENIX](https://www.usenix.org/conference/fast21/presentation/dong),
[48-page slide PDF](https://www.usenix.org/sites/default/files/conference/protected-files/fast21_slides_dong.pdf).
The downloaded PDF's SHA-256 is
`d0ece2700caf400efe08ea82ba60a9f7c6e34dbbe239dc6daac97b794994c2ba`.

All original PDF pages were inspected, including diagram-only pages and repeated
reveal frames. This audit covers the posted slides, not additional spoken
material in the video. Lecture numbers below are logical slide numbers printed
in the footer and match handout pages. The presentation PDF has 73 pages because
three slides have an initial question state followed by an answer reveal.

## Result

The revised lecture covers every substantive topic, example, and conclusion in
the original slides, across 62 core slides and seven appendix content slides,
preceded by an appendix divider. Repeated frames are consolidated; the original
section dividers and closing branding add no technical
content and are not copied. Data integrity and recovery precedes operations
in the selected teaching order.

The earlier 40-slide version covered the paper broadly, but several points that
the talk treats in detail appeared only as brief mentions. The revision adds:

- **33:** CPU/SSD provisioning imbalance and disaggregated storage.
- **37:** The original host 1 → 4 → 5 corruption-spreading sequence, including
  retirement of healthy hosts 2 and 3.
- **39:** Persisting an SST's expected checksum at creation, rejecting bad file
  copies, and verifying both backup and restore.
- **41:** Per-record verification at write, flush, compaction, and read boundaries.
- **42:** The gap between WAL checksums and reliable storage, and receiver-side
  verification of a caller-supplied handoff checksum.
- **67–68:** Every milestone in the talk's 2012–2020 timeline.
- **69:** The original utilization chart, including its measurement definitions.
- **70:** The talk's amplification estimates, distinguished from the paper's
  numbers and the compaction-policy benchmark.

Slides 4, 37, and 45 also make the hardware goals and the multi-host,
multi-instance replication setting explicit. The instructor notes explain why early detection
permits recovery from a healthy replica, while checksum detection alone cannot
reconstruct a correct value.

The opening now also includes LevelDB's 2011 origins and Facebook's 2012 fork
on slides 2–3. These use the original Google and Facebook announcements linked
in the speaker notes and README, supplementing the talk's project timeline.

The later sections also include explicit definitions and examples for WAL recovery
(slide 46), checksum creation and verification (35), independent shard sequence
numbers (55), and a worked design discussion (61). These teaching additions
expand the explanations while preserving the original talk coverage.
Slides 53–54 additionally define who assigns sequence numbers and user timestamps,
what each orders, and how both limits constrain a read. The two-version example
and per-key timestamp-ordering rule are checked against the RocksDB timestamp
and snapshot documentation linked in the speaker notes. They explain the concepts
without attributing later API availability to the 2021 paper.

## Complete page mapping

| Original PDF pages | Content or purpose | Revised lecture slides | Audit finding and resolution |
| --- | --- | --- | --- |
| 1 | Paper identity, authors, conference | 1 | Covered. |
| 2–3 | Agenda and design-goal divider | 4, 30, 36–42 | The three subject areas are retained in the selected teaching order. |
| 4–5 | Embedded persistent KV library; SSD/multicore throughput; versatility; single-node scope | 4, 32 | Hardware and library/application boundary are now explicit. |
| 6 | Project timeline, 2012–2020 | 3, 67–68 | Added all nine years, deployment names, features, and experimental/partial-status qualifications. |
| 7–8 | Resource-optimization section; initial write-cost objective | 13–15, 30 | Covered; dividers consolidated. |
| 9–10 | Amplification at engine, filesystem, and SSD layers; emphasis reveal | 13–15, 20, 70 | Added the three estimates; identify them as the talk's motivating comparison. |
| 11 | LSM as the chosen data structure | 5–19 | Covered in greater mechanical detail. |
| 12 | Capacity as the common limiting resource | 29–31, 69 | Covered, with survey context. |
| 13 | Four utilization plots for ZippyDB/MyRocks | 29, 69 | Previously only summarized. Added the exact source chart and paper's measurement definitions. |
| 14 | LSM space efficiency with suitable optimization | 17–20, 31 | Covered through compaction tradeoffs and dynamic level targets. |
| 15 | Growing importance of CPU efficiency | 32 | Covered. |
| 16–19 | Two-versus-three local SSD example; residual imbalance; remote storage | 33 | Added the local capacity comparison and separate provisioning diagram. |
| 20 | Resource-priority recap | 29–33, 62 | All four stages now appear: write cost, capacity, CPU cost, disaggregation. |
| 21 | Integrity section divider | 36–42 | Section content retained. |
| 22 | Application-level Paxos replication across hosts | 37, 45–47 | Application ownership and multi-host placement are explicit; notes distinguish logical replication from file copy. |
| 23–28 | Replica bootstrap, many instances/shards per host, multiple replication groups, backup and restore | 37, 39, 45–47, 51, 60 | Distributed shard placement, shared host budgets, file movement, and both backup directions are covered. Duplicate/emphasis frames consolidated. |
| 29 | Generate block checksums on writes and verify on reads | 38, 40–41 | Covered; differentiated from file and memory checks. |
| 30–32 | Detect early; rebuild from a good replica; no good source means loss | 36–37, 43 | Explicit healthy-source recovery in notes and failure sequence on slide 37. |
| 33–36 | Unchecked 1→4→5 file copying replaces healthy replicas 2 and 3 | 37 | Added all steps as three side-by-side states. |
| 37–38 | Reject corrupt SST copies; verify checksums during backup and restore | 39 | Added saved-checksum provenance and both transfer directions. |
| 39–40 | CPU/memory faults can silently spread despite replication | 36–37, 40–41 | Connected the bit-flip example to replica replacement and earlier memory protection. |
| 41 | Per-KV checks on writes, reads, memtables, cache, flush, and compaction; block checks on SSTs | 38, 41 | Added each boundary and retained the 2021 in-progress qualification. |
| 42–43 | Copying the WAL buffer can cross a protection gap; handoff checksum closes it | 42 | Added before/after buffer flow and verification before acceptance. |
| 44 | Integrity recap | 36–43, 62 | Early detection, file checks, CPU/memory faults, per-KV and handoff protection all covered. |
| 45 | Paper-only topics: production data, hardware, operations, recovery, KV interface | 20, 29, 31–33, 43–66, 69 | Already covered more broadly than the talk; backup detail strengthened. |
| 46–48 | Thanks, questions, branding | 60–62 | No additional technical material; not reproduced. |

## Qualifications preserved

- The timeline dates and production deployments follow the **talk**. Its 2017
  NVM work is an experiment, and timestamp support in 2020 is partial. The names
  MongoRocks/MongoDB, MyRocks/MySQL, and Rocksandra/Cassandra are identified.
- Original pages 9–10 describe engine amplification as often hundreds, filesystem
  amplification as near one, and device amplification as one to three. Paper §3
  instead says software amplification can reach about 100 and SSD amplification
  was observed at 1.1–3. Slide 70 states this difference; neither set is substituted
  for the RocksDB 5.9 Table 3 measurements on slide 20.
- The 42-deployment chart is distinct from Table 2's four category examples.
  CPU/read-bandwidth values use the highest hour, while space/endurance use the
  month average. All are averaged across hosts within each deployment.
- File checksums use an expectation established when the SST was created. The
  2021 whole-file protection did not cover WAL files; the handoff discussion
  addresses a separate write boundary.
- Per-KV protection was proposed/in progress in 2021. A handoff check depends on
  receiver/API support; it is not guaranteed by an ordinary filesystem write.

## Teaching route and artifacts

The core route is slides **1–62**, with suggested notes totaling **92 minutes**.
For the 80-minute class, omit the prior-lecture review on slides **5–11**
(7 minutes) and the discussion activities on **21** and **60–61** (7 minutes),
leaving two minutes for transitions. The HDD in-place update,
SSD block-copy example, and LSM motivation are on **13–15**, after the
"Why do we need LSM on SSD?" divider on **12**.
Each compaction policy has its own example on **17–19**, after the divider on **16**.
The application-policy discussion on **21** lists the suggested policy and reason
beside each application, with all answers visible immediately.
The Bloomfilter divider and five introductory slides are on **22–27**.
Title pages also introduce resource optimization (**28**), data integrity and
recovery (**34**), operations (**44**), versions and timestamps (**52**), and
discussion and takeaways (**59**).
Appendix slides **64–70**, after the divider on **63**, remain in both PDFs and add about
12 minutes if all are presented. The detailed 2012–2020 timeline, full survey figure, and rough
amplification estimates are therefore available for completeness without making
every appendix page mandatory in the core route.

The regenerated lecture and handout retain the selected textbook styling and
three question/answer reveals. All new conceptual figures are editable
CeTZ. The utilization chart is an attributed source image, not reconstructed
data; extraction provenance is in [assets/README.md](assets/README.md).
