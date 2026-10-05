
# Masstree

Paper: Mao, Kohler, and Morris, [*Cache Craftiness for Fast Multicore Key-Value Storage*](../readings/masstree.pdf) (EuroSys 2012).

## Around 2010: the database fits in memory

* Cheaper, larger RAM lets more databases fit in memory. Systems such as [H-Store](https://hstore.cs.brown.edu/papers/hstore-endofera.pdf)/VoltDB, Redis, and memcached explore this opportunity
* Without disk reads, CPU work, cache misses, and synchronization become the bottlenecks
* Masstree (2012): an ordered index in shared memory, accessed by many cores. Last lecture's B-link tree assumed atomic, private page reads; that assumption is gone

## In memory does not mean equally fast

* The CPU still has a hierarchy between its execution units and DRAM (illustrative modern x86 sizes and latencies; hardware-dependent)
  * L1 data: ~48 KB per core, close to the core — ~1 ns
  * L2: ~1–2 MB per core, usually private — ~5 ns
  * L3: ~32 MB shared among cores on a chip or chiplet — ~15 ns
  * DRAM: much larger, off chip — ~100 ns, ~300 CPU cycles
* Fetching from memory to cache: cache line, 64 bytes.
  * Cache misses means CPU is empty waiting for that 300 cycles.


## The job

* One server, many cores; all keys and values fit in DRAM
* `get(k)`, `put(k, v)`, `remove(k)`, `iterate(k, n)`
  * arbitrary-length binary keys and values
* many keys with long common prefixes
  * e.g., reverse-domain URLs: `edu.harvard.seas.www/...`
  * db table names, like "user_tbl/alice"
* Two problems to solve:
  1. a single lookup spends too long waiting for memory
  2. many lookups interfere with each other, even when they only want to read

## Strawman 1: a hash table

* Good point lookups. Compute a hash, go almost directly to the bucket
* But a hash destroys key order. Finding the next 100 keys after k now needs another index or a scan
* We asked for range queries. Keep an ordered index
* Remember this choice at evaluation time: a faster hash table does not implement the same interface

## Strawman 2: the B-tree we already have, in RAM

* It works, with suitable synchronization. But the cost model changed
* On disk: minimize page I/Os. A large node amortizes seek time over many keys
* In memory: minimize *dependent cache misses*
  * CPU asks for a cache line, waits for DRAM, then learns the next address
  * a pointer chase cannot fetch the next node until it has examined this one
  * hot upper nodes may be cached; lower levels of a large tree usually are not

```
  read root → choose child → read child → choose child → read leaf
               next address unknown until the previous read finishes
```

* A useful cost model:
  * lookup time ≈ memory latency * tree height * work within node
  * A disk-sized B-tree node goes too far the other way: too many cache lines within a node
  * multicore throughput also depends on memory bandwidth and cache-line ownership transfers
* Let us reduce the node size to make fewer trips to memory per node? 
  * A balanced binary tree on roughly 1 million keys has about 20 levels
* What should an *in-memory* B-tree node look like?

## Fewer trips, more work per trip

* Put several separators and child pointers together
  * wider fanout → fewer levels
  * comparisons within a fetched node are much cheaper than another DRAM round trip
* Put the bytes needed for routing *in the node*
  * an array of pointers to separately allocated strings adds another pointer chase per comparison
  * start by storing a short piece of each key directly
* A node can span several cache lines. Fetch those lines together
  * as soon as we know the node's address, issue software prefetches for its lines
  * the addresses within one node are known, so their fetches can overlap
  * the next child address is still unknown. Prefetching does not remove the dependency between levels
* Why not make the node enormous?
  * more bandwidth, more cache pollution, more comparisons, and limited outstanding memory requests
  * a wider node only helps if the time saved by fewer levels exceeds these costs
* The paper's tuning point: width 15, with a target of about four 64-byte cache lines of node data
  * 15 key slots; an interior node can have 16 children
  * metadata and key suffix storage also consume space
  * an empirical compromise on their hardware, not a universal best node size
* So far: a small, wide B+ tree, with inline key pieces and prefetching

## Long keys spoil the plan

* Suppose keys share a 64-byte prefix and differ near the end
* Ordinary string comparisons keep checking that same prefix
  * at the root, at the next level, several times inside each node
  * storing only the first few bytes inline does not help distinguish these keys
  * following pointers to the rest of the string brings back the memory stalls
* A byte-at-a-time trie avoids repeated prefix comparisons
  * consume one byte, follow an edge, consume the next byte
  * but a long prefix becomes a long chain of nodes
  * an array of 256 child pointers per byte can waste a lot of memory
* We want the trie's habit of consuming a prefix once, with the B-tree's compact, balanced search among alternatives

## Consume eight bytes at a time

* Slice the key into 8-byte pieces
* At each trie position, use a B+ tree to index the next slice
  * the B+ tree stores only slices that actually occur; no enormous array of all possible 64-bit values
  * if keys agree on this slice, descend to another B+ tree for the next slice
* That is Masstree: a trie whose nodes are B+ trees
  * *layer*: which 8-byte slice we are examining
  * *level*: how far down one of those B+ trees we are
  * a layer can contain many B+ trees, one per prefix. A single B+ tree can have several levels
* The leaves are called **border nodes**: their entries can lead to values or to the next layer

### Build one by hand

* Insert `user0001/alice`
  * layer 0 indexes `user0001`; store the remaining `/alice` as a suffix alongside its value
  * no reason to allocate another tree for one key
* Insert `user0001/bob`
  * same first slice, different suffix. Now we need a second layer
  * replace the suffix/value entry by a pointer to a new B+ tree holding both suffixes
* Insert `user0002/alice`: different first slice; another entry in layer 0

```
  layer 0: B+ tree on bytes 0..7
      ... → border node
              user0001 ─────────────────────────────┐
              user0002 → suffix /alice, value C     │
                                                    │
                                                    v
  layer 1, prefix user0001:       B+ tree on bytes 8..15
                                     /alice → value A
                                     /bob   → value B
```

* `get(user0001/bob)`:
  1. search the layer-0 tree for `user0001`
  2. entry says next layer; consume eight bytes
  3. search that tree for `/bob`, find B
* If the suffixes share another full slice, repeat. Create layers only when needed
* If only one long key occupies a slice, keep its unmatched suffix and compare it at the end
  * avoids a chain of mostly empty trees just to represent one key
* Keys in a layer-h tree all share the same first `8h` bytes
* For keys sharing a long prefix of length P, followed by short distinguishing suffixes:
  * ordinary full-string B-tree comparisons can cost O(P log N)
  * Masstree consumes the prefix once along the path: O(P + log N) comparison work
  * it still traverses the prefix layers. A 64-byte shared prefix does not disappear for free
  * general worst case for maximum key length L remains O(L log N); the shape depends on the keys

### Why eight bytes?

* A slice fits in a machine word: one integer comparison instead of a string-comparison loop
* Need integer order to match byte-string order

```
  bytes of "ABCDEFGH":        41 42 43 44 45 46 47 48
  little-endian integer load:  0x4847464544434241
  comparison representation:  0x4142434445464748
```
* Byte-swap on little-endian machines; compare as an *unsigned* integer


## Multi-thread safety: the assumption from last time breaks

* Node read/write is no longer atomic.
* Writer inserting 20 into a sorted array might move 30 and 40 before installing 20
* Reader can observe keys from one moment, child pointers or values from another
  * a right link repairs a stale *position*, not an inconsistent node
* First repair: give each node a version and a dirty marker

```
  writer, holding node lock:        reader:
    mark node dirty                  v1 ← stable version of node
    change keys / pointers           read the needed fields
    increment version                v2 ← node version
    clear dirty                      accept only if unchanged and clean
```

* Dirty marker detects an update in progress; version detects one that finished between the two reads
* The reader may have observed nonsense. It must validate before accepting the result
  * including a "not found" result
* Conservative scheme: record versions for the whole path, validate all of them before returning, restart on any change
  * correct with the required ordering and memory-lifetime rules, but lots of unnecessary retries
* Can we make common writes safe to observe, so they do not force a retry at all?

## Update a value: publish one pointer

* Suppose a put changes an existing value
* If it fits in an atomically writable slot: replace that slot in one aligned write
* For a larger value, especially multiple columns:
  1. lock the border node against other writers
  2. allocate and initialize a replacement value object, copying unchanged columns
  3. atomically publish its pointer in the existing slot
  4. unlock
* A reader sees either the old object or the new one, never half the column updates
* The node's key layout did not change. No node-version increment is needed for this update
* But do **not** immediately free the old object
  * a reader may already hold its pointer
  * an atomic pointer replacement solves publication, not reclamation

## Insert a key: stop moving the old keys

* A conventional leaf keeps physical slots in sorted order
* Inserting in the middle means shifting keys and values. Too many writes to publish atomically
* What actually needs to be sorted? The *order in which we search*, not the physical slots
* Leave entries where they are. Store a separate permutation describing their sorted order

```
  physical slot:       0     1     2     3
  key:                30    10    40    --
  logical order:      [1, 0, 2]             count = 3

  insert 20:
    fill slot 3:      30    10    40    20
    publish order:    [1, 3, 0, 2]          count = 4
```

* Reader loads the permutation once, then uses that saved order to examine the slots
  * old permutation: does not inspect slot 3
  * new permutation: sees the initialized key/value in slot 3
  * no intermediate order is visible
* Fifteen slots make this fit in one 64-bit word:
  * 4 bits for the count, 15 × 4 bits for slot indexes
  * unused indexes identify available slots
* Writer locks the node, fills an unused slot, then publishes the new permutation in one aligned write
  * initialization must become visible before the permutation; fences enforce this order
  * no key movement, no dirty interval, no version increment for this ordinary insert
* The lock bit and the dirty bits are deliberately different
  * lock: another *writer* must wait
  * dirty: a *reader* cannot trust the layout
  * a locked node can still be perfectly safe to read
* This is the **permuter**. A concurrency optimization comes from changing the data layout
* Two exceptions are still waiting for us: a full node must split, and a previously removed slot cannot always be reused this way

## Delete: the slot-reuse trap

* To remove an entry, publish a permutation that omits its slot
* Leave the old slot contents intact: a reader may still be using an old permutation
* Why not immediately treat that slot as an ordinary free slot?

```
  reader get(10)                      writer
  old permutation says 10 is slot 1
                                      remove 10 from permutation
                                      reuse slot 1 for key 99, value V99
  read value from slot 1
  return V99 for key 10                wrong
```

* Returning the old value for 10 could be legal: the get overlapped the remove
* Returning 99's value for 10 is never legal
* Therefore reusing a removed slot must use the dirty/version protocol and change `vinsert`
  * the old reader detects the change and retries
  * "inserts never cause retries" was only true for the simple case using an unused slot
* No merging, but empty nodes can be unlinked; empty ancestors can be removed too
  * deletion marks 
* Unlinked does not mean safe to free

## Reclamation: who might still hold a pointer?

* This applies to replaced values, removed nodes, and old suffix storage
* A writer cannot inspect another core's registers to see whether it still has a pointer
* Epoch-based reclamation:
  * threads announce progress through read-side epochs
  * removed objects are retired first
  * free them only after every reader that could have seen them has passed the relevant epoch
* A reader can finish using an old value while later readers see the replacement
* This is the RCU-like part of the design. Masstree does **not** copy the whole tree or every node on each write
  * values may be replaced by copying; tree nodes are often changed in place
  * atomic publication, version validation, and delayed freeing solve different problems
* Readers take no tree locks, but may spin on a dirty node or retry
  * no read locks is not a guarantee of bounded completion time

## What does a scan promise?

* Search for the first key ≥ k, enumerate entries in permutation order, and walk border-node links
* At a next-layer entry, traverse that subtree in order, then resume the enclosing layer
  * every suffix below one prefix sorts together
  * layer traversal makes this more involved than walking one flat leaf list
* Individual observations need the same validation and memory-lifetime rules as point lookups
* The paper explicitly does **not** make `getrange` atomic with respect to concurrent inserts and updates
  * a scan can combine observations from different times
  * a transactionally consistent snapshot needs another mechanism
* Ordered access, atomic updates to one key, and transactions across multiple keys are separate promises

## Did the design choices matter?

* Read the experiments as tests of the mechanisms, not a current database ranking
  * 2012 hardware/software; up to 16 cores, small keys/values, large memory-resident datasets
* Factor analysis (Figure 8, Section 6.2): start with a concurrent binary tree, add changes cumulatively
  * allocator and huge pages also matter: tree traversal is not the only source of memory overhead
  * integer comparison, wider nodes, prefetching, then the permuter and trie layers
  * generated inside the server: **no network or logging** in this figure
* Does the tree still matter in a complete server? Section 6.3 turns network and logging on
  * 140-million-key workload, 16 cores: about 8.03 M gets/s and 5.78 M puts/s
  * 1.90× get and 1.53× put throughput of the optimized binary-tree baseline
  * do not mix these absolute numbers with Figure 8's in-process experiment
* Sharing versus partitioning (Figure 11): the tradeoff we predicted
  * uniform reads: static per-core trees are 1.5× faster, largely from local DRAM access
  * one partition gets 40% of requests: the shared tree is 3.5× faster
  * evidence about this static-partition experiment, not proof that sharing always wins
* Cost of order (Section 6.4): a favorable hash-table baseline gets 2.5× the throughput on its tested workload
  * it cannot answer range queries. The extra interface has a real cost


## A split really changes the search path

* Full border node: allocate a right sibling and move the higher keys into it
* Now old entries disappear from one node and appear in another. One permutation store cannot publish the whole change
* Use the version protocol for structural changes
  * `locked`: writer exclusion
  * `inserting`, `splitting`: dirty markers
  * `vinsert`, `vsplit`: counters for completed changes of the two kinds
  * also root, border, and deleted flags
* Why two counters?
  * an interior insertion adds a separator/child; a reader can search that same node again
  * a split may move responsibility for the key to a different node; rereading the old node may never find it
* Interior inserts still rearrange entries. The permuter above is for *border* nodes

### Writers go up

* Descend without locks, like a reader. Lock the target border node, then recheck that it is still the right node
* To split n:
  1. allocate n'; mark n and n' splitting before moving entries
  2. distribute entries, with the higher keys in n'; link border siblings
  3. lock n's parent; check that it is still the parent (it may itself have split)
  4. mark the parent inserting and add n'
  5. finish version changes and unlock
* If the parent is full: mark it splitting and propagate upward
  * transfer the protection upward before releasing the lower nodes
  * create a new root if necessary
* Splits use at most three node locks at once: the splitting node, its new sibling, and its parent
* As in Lehman-Yao, structural writers acquire existing-node locks upward; they do not lock the root on every insert
* The split markings matter as much as the locks. Locks coordinate writers; markings explain the change to readers

### Readers need an overlap between parent and child

* Tempting algorithm: read parent, validate parent, then read child's version and contents
* Still wrong. Each node can look consistent while the *path* is stale

```
  reader wants a key under X          writer splits interior node B
  read A; choose child B
  validate A: unchanged
                                      move child X from B to new B'
                                      add B' to A; finish split
  read B's new version and contents
  validate B: unchanged
  search below B                      wrong subtree: X is under B'
```

* Fix: snapshot the child's stable version **before** validating the parent

```
  vA ← stableversion(A)
  B  ← choose_child(A, key)
  vB ← stableversion(B)                // take this before releasing A logically
  validate A against vA               // ignore a change in the lock bit alone
  if valid:
      continue in B, carrying vB      // do not replace it with a fresh snapshot
```

* **Hand-over-hand validation**, in place of hand-over-hand locking
* Why the split cannot fall through the gap:
  * writer marks B splitting *before* changing A, and carries the split protection upward
  * if reader captured B before the split, its saved vB exposes the split when it next validates B
  * if reader waits through B's split to obtain a stable vB, the change to A is already detectable
  * if reader follows the new pointer to B', the moved children were installed before that pointer was published
* Version changed during an interior-node search?
  * only insertion changed: retry at that node
  * split counter changed: restart at the root of this B+ tree layer
* This replaces remembering and revalidating the entire path

### At the border, recover to the right

* Border nodes have sibling links. Interior nodes in Masstree do not
* Each border node owns a half-open slice range `[lowkey, highkey)`
  * its low boundary stays fixed for its lifetime
  * splitting moves higher keys right; the next node's low boundary tells us whether to move there
* If border-node validation fails: obtain a stable version, check the next sibling's low boundary, move right as needed, and try the lookup again
* This is last lecture's repair idea, with version checking added because nodes are no longer atomic pages
* A deleted node forces a restart
* A saved layer-root pointer can also become stale after a root split
  * the root flag and parent pointer let traversal find the new root
  * "restart at root" means the current root, not blindly trusting an old pointer
