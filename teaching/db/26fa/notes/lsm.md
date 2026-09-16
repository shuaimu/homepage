
# LSM-Tree

Paper: O'Neil, Cheng, Gawlick, and O'Neil, *The Log-Structured Merge-Tree (LSM-Tree)* (Acta Informatica 1996).

## The job

* A table that is mostly *appended to*, plus an index on it
* Paper's running example: TPC-A at 1000 transactions per second
  * each txn writes a 50-byte History row (account, teller, amount, time)
  * people occasionally ask: recent History rows for this account?
* Without an index on `(account, time)`: scan the whole History table
* With a B-tree index: every txn does *another* random leaf I/O
  * Account-table updates already need ~50 disk arms
  * the History index doubles that
* We want: inserts cheap
  * finds possible (not a full scan), but they can be rarer than inserts
  * History / logs / audit trails are the intended workload
  * if your workload is find-heavy, a B-tree is already the right answer
* 1995 hardware, not SSDs
  * scarce resource is the *disk arm* (seek + rotation), not flash wear

## Why a B-tree insert is expensive

* A B-tree keeps keys sorted in page-sized nodes on disk
* To insert a random key:
  1. Walk down the tree to the leaf (directory nodes may be cached)
  2. Read that leaf page
  3. Put the new entry in
  4. Write the leaf page back
* Two costs hide in that random I/O:
  * seek + rotation (~15–20 ms) dwarf the actual transfer of 4 KB (~1–2 ms)
  * you paid that for *one* new entry
* Strawman we will keep coming back to:
  * if we could (a) write sequentially, and (b) put many new entries on a page per trip to disk, inserts would get cheap

## Strawman 1: keep the index in memory

* Inserts become pointer wiggles
* Finds are fast
* RAM in 1995 is ~100× the $ per MB of disk
  * History index is gigabytes
  * you cannot buy that much memory for an index that is mostly cold

## Strawman 2: append every insert to a disk log

```
  disk:  [k=9][k=3][k=47][k=3][k=12] ...   // arrival order
```

* Writes are sequential — one arm, no seeks. That is cheap
* Finds: scan the log
  * the query that motivated the index is now a sequential scan of everything
  * useless

## Strawman 3: buffer in memory, dump a sorted run

* Combine 1 and 2
* Keep a small sorted index C0 in RAM (the piece we could afford)
* Insert always goes into C0. No disk I/O
* When C0 hits a size limit: write its contents out as one *sorted* file (a "run") and empty C0

```
  memory C0:  3, 9, 12, 47          // sorted, small

  disk:       run1: 1, 4, 8, 20     // previous flush, sorted
              run2: 3, 9, 12, 47    // this flush, sorted
```

* Writes are sequential (dump a sorted array)
* Finds: search C0, then each run
* Problem: after a day you have thousands of runs
  * a find checks all of them
  * inserts stayed cheap; finds died

## Strawman 4: merge the runs (one pass)

* When there are too many runs: read two of them and write one bigger sorted run
* Same algorithm as merging two sorted lists:

```
  run A:  1, 4, 8, 20
  run B:  3, 9, 12, 47
  ---------------- merge, left to right, once ----------------
  run C:  1, 3, 4, 8, 9, 12, 20, 47
```

* I/O is sequential on both sides
* After the merge, a find checks *one* file instead of two
* Throw away A and B
* This is the "merge" in "log-structured merge"
  * "Log-structured" is from Rosenblum and Ousterhout's Log-Structured File System
  * always write new sequential blocks, never overwrite in place
* We now have the idea
  * the paper's contribution is a specific data structure that does this with two (then K) *trees*, not a pile of files
  * the paper moves data with a "rolling" cursor a little at a time
  * we ignore that and always merge in one full pass, as above

## A two-layer (component) LSM-tree

* Two trees

```
   C1 tree                         C0 tree
   (big, on disk)                  (small, all in memory)

        / \                             / \
       ...                               ...
```

* C0
  * entirely in RAM
  * any in-memory search tree (AVL, 2-3, …)
  * nodes are *not* disk-page sized — C0 never goes to disk as a tree
  * every insert / delete-note lands here first. Zero I/O
* C1
  * on disk, B-tree *shaped*: page-sized nodes, separators in directory pages, a leaf level in key order
  * leaves packed 100% full (a B-tree is typically ~70% full — wasted space, extra arms)
  * leaves grouped into multi-page blocks (~256 KB in the paper)
    * sequential I/O for merge and for long range scans
  * point finds walk *single pages* down the directory
    * you do not pull a 256 KB block to look up one key
  * hot directory pages sit in the buffer pool like any B-tree
* Search: look in C0, then in C1
  * unique keys: stop when you hit
  * recent inserts are still in C0 — C0 is also a cache for "what just happened"
* Durability of C0
  * the ordinary transactional log already recorded the History row
  * after a crash, replay that log and rebuild C0
  * C1 is on disk

### Merge, one pass

* C0 cannot grow forever
* When it hits a size threshold:
  1. Freeze this C0. New inserts go into a fresh empty C0 (so the system keeps taking writes)
  2. Merge the frozen C0 with C1, left to right, once — the same two-list merge as strawman 4
  3. Write the result as a *new* C1 (sequential blocks, new disk addresses). Do not overwrite the old C1
  4. Point the directory at the new C1. Drop the frozen C0 and the old C1

```
  frozen C0:   3, 4, 7, 20
  old C1:      1, 2, 5, 6, 8, 9, 16, 18
  -------------------------------- merge once ----------------
  new C1:      1, 2, 3, 4, 5, 6, 7, 8, 9, 16, 18, 20
```

* A page is 4 KB: one C1 leaf, and the unit of a point-find I/O
* A multi-page block is many consecutive pages (~256 KB)
* Writes during the merge go to the new C0
  * they are not in this pass
  * they will be in the next merge, when *that* C0 fills
* Finds look in (live C0, then frozen C0 if it is still around, then C1), newest first

### Two batching effects (this is why it beats a B-tree)

* `COSTP` = cost of one *random* page I/O (you pay a seek)
* `COSTπ` = cost of one page I/O *inside* a multi-page sequential block (seek amortized)
* 1995 SCSI numbers in the paper:
  * random ~16 ms/page
  * 64-page sequential ~1.5 ms/page
  * so `COSTπ / COSTP ≈ 1/10`
  * hardware, not a tree-size ratio
* B-tree insert:

```
COSTB ≈ COSTP * (De + 1)
```

* `De` ≈ 2 directory misses + 1 dirty leaf write. About three random I/Os
* LSM insert: the insert only touches C0 in RAM
  * disk cost shows up in the merge
  * per C1 leaf you sequentially read it and sequentially write it (`2 * COSTπ`)
  * those two I/Os are shared by the `M` new C0 keys that land in that leaf:

```
COSTLSM ≈ 2 * COSTπ / M
```

* `M` is a key count, not the size ratio `r = |C1| / |C0|`
  * a packed leaf holds `P = 250` keys
  * if C0 is 1/25 of C1 (`r = 25`), about `250 / 25 = 10` keys on that leaf came from C0, so `M ≈ 10`
  * paper: `M = P × |C0| / (|C0|+|C1|)`
  * when C0 is much smaller than C1, that is `≈ P / r`
* Same number, other angle — a full one-pass merge reads *every* old C1 page and writes *every* new C1 page, then divide by `|C0|` inserts:

```
  I/Os per insert = (2r + 1) / P ≈ 2 / M
```

* With `r = 25`, `P = 250`, `M = 10`: `(50+1)/250 = 0.204` and `2/10 = 0.2`
  * rolling step vs full pass are the same cost, just leaf-by-leaf vs all-pages-at-once
* Cost vs B-tree:

```
COSTLSM / COSTB ≈ (2/(De+1)) × (COSTπ/COSTP) × (1/M)
                 ≈     0.67     ×      1/10        ×   1/10
```

* The last `1/10` is `1/M` with `M = 10`
  * the middle `1/10` is sequential vs random
  * neither is `r = 25`
* What this does *not* include:
  * C0 disk I/O (there is none)
  * a separate memtable log (use the History WAL)
  * C1 directory I/O
* Larger C0 (smaller `r`) → larger `M` → cheaper inserts, more RAM
* Tiny C0 → `M` near 0 → you still rewrite all of C1
  * that is why a later section adds C2

### Finds (immediate)

* Exact-match or range, needed *now*: search C0, then C1
  * two directories — some extra CPU
  * with only two components, usually not extra I/O beyond what a B-tree find would do on C1 (C0 is RAM)
* Optimizations the paper lists:
  * unique keys: stop at the first hit
  * "I only want rows from the last τ seconds": if you refuse to merge entries younger than τ out of C0, the find never goes to disk
  * UNDO-log indexes for short transactions sit almost entirely in C0
* Immediate finds are the operation LSM does *not* try to make cheaper than a B-tree
  * if they dominate, do not use this structure

## Deletes, updates, and dropping old data

* If the key is in C0, delete it there
* If not, insert a delete-note (a tombstone) into C0, keyed the same way
  * the next merge sees the note and the live entry together
  * they *annihilate* and both disappear
* Finds must honor delete-notes
  * the note sits in an *earlier* component than the live entry
  * so you see it first and know not to return the row
* Update of an indexed value = delete-note + insert of the new key
  * the paper says this is unusual
* Predicate delete: "drop everything with timestamp older than 20 days"
  * do not probe the index
  * when you next merge the *largest* component, drop those keys as you rewrite it
  * that is how the 20-day History window stays bounded without a B-tree-style random delete per expired row

## Why two components are not enough

* `COSTLSM ≈ 2 COSTπ / M`
  * `M` is larger when C0 is larger compared to C1
* If C0 is huge, RAM cost dominates
* If C0 is tiny, each merge still rewrites all of C1 for almost no new keys
* The cost-optimal two-component C0 is often still a lot of RAM
* So add a disk-resident stepping stone:

```
  CK (largest, disk)  ...  C2 (disk)  C1 (disk)  C0 (RAM)
         ^ merge ^            ^ merge ^    ^ merge ^
```

* When `Ci-1` fills, freeze it and merge it into `Ci` in one pass
* An entry is born in C0 and walks out to CK through K merges
* Components grow geometrically
  * Theorem 3.1: to minimize merge I/O given a fixed RAM budget `S0` and a fixed largest component `SK`, pick one ratio `r`

```
S_i = r * S_{i-1}
```

* Sizes are `S0, r S0, r² S0, …, r^K S0`
* Intuition:
  * each merge "pays" sequential I/O proportional to how much bigger the destination is than the source
  * equal ratios spread that tax evenly
* More components:
  * smaller C0 (less RAM)
  * more sequential I/O layers
  * a find may do one extra page I/O per disk component
  * the paper is explicit: this is an insert-mostly structure
* TPC History numbers (Example 3.3), inserts only, 20 days, 1000 entries/s:
  * B-tree: ~$50k of disk arms + ~$6k to cache the directory ≈ $56k
  * two-component LSM: 9.2 GB packed on disk ($9.2k) + 20 MB of C0 ($2k) ≈ $11k
    * disk full *and* sequential arms full
  * pump the insert rate 10× (Example 3.4):
    * B-tree arms blow up
    * a third component starts to win
    * two-component C0 would have to grow (or you spread C1 across idle capacity) to keep `M` sane
* The paper's temperature picture (cold / warm / hot data):
  * a B-tree History index is *warm* — you buy arms, not capacity
  * LSM's sequential batched inserts push that temperature toward *cold* (capacity-limited)
  * memory buffering in a B-tree only helps once data is *hot*
  * LSM is a way to stay off that slope for mergeable operations (insert, delete)
