
# B-link Tree

Paper: Lehman and Yao, *Efficient Locking for Concurrent Operations on B-Trees* (ACM TODS 1981).

## The job

* A B+ tree index on disk. Many processes search and insert at once
* Wanted:
  * correct: a search finds the key if it is there
  * searches never wait. Reads dominate; an index that blocks readers on every insert is useless
  * inserts hold few locks, briefly. A lock held across a 20 ms disk I/O stalls everyone behind it
  * no deadlock
* Storage model (Section 2). Keep it in mind; the whole trick depends on it
  * disk is pages; a page is a node
  * `A ← get(x)` reads a whole page into a process's *private* memory; `put(A, x)` writes it back
  * each `get` / `put` is atomic: you see a page as it was before a write or after it, never half
  * `lock(x)` is exclusive. You must hold it to `put` x. It does *not* stop anyone from `get`-ing x
  * a process has a few page buffers of its own. No shared memory between processes

## B+ tree, 1979 edition

* The paper says B\*-tree (Wedekind's variant). It is what we now call a B+ tree
* Every root-to-leaf path has the same length
* Keys and record pointers live in the leaves. Nonleaf nodes hold separator keys and child pointers
* A node is one page: up to `2k` entries, at least `k` (except the root)
* Fanout in the hundreds, so three or four levels cover millions of keys

```
  nonleaf:  [ P0 | 20 | P1 | 40 | P2 ]      P1 covers the keys in (20, 40]
  leaf:     [ 21 | 25 | 33 | 38 ]           each key + a pointer to its record
```

* Search: start at the root. In each node find the slot whose range holds v, follow it. At the leaf, look for v
* Insert: search to the leaf. If it has room, put v in. Otherwise split
  * make two half-full nodes out of one
  * push a separator and a pointer to the new node into the parent
  * the parent may be full too; splits can cascade up to the root
* *Safe* node: has room (fewer than `2k` entries). *Unsafe* node: full, an insert here will split it
* The sequential code is a few dozen lines. Now run it from two processes

## The race (paper's Figure 5)

* Parent `x` says: keys in (8, 20] are in leaf `y`. `y = [10 12 15 18]` is full (`k = 2`)
* Process S searches for 15. Process I inserts 9

```
  search(15)                          insert(9)
  1. read x; 15 is in y
  2.                                  read x; 9 is in y
  3.                                  read y = [10 12 15 18]     full
  4.                                  split: y = [9 10 12], y' = [15 18]
  5.                                  write y', write y
  6.                                  add (12 → y') to x
  7. read y = [9 10 12]
  8. 15 not found                     wrong: 15 is in the tree
```

* Nothing was torn: every page S read was a consistent node
* The bug is about *position*: S holds a pointer it got from `x` *before* `y` changed. By the time it reads `y`, the key it wants has moved to a node S has no way to reach
* Every concurrency scheme for B-trees is an answer to this one race

## Strawman 1: one lock on the whole tree

* Correct, trivially
* Zero concurrency. Every operation does a few disk I/Os at ~20 ms each; all of them serialize
* The multiprogramming the database exists for is gone

## Strawman 2: lock the path (Samadi 1976)

* An insert can only change nodes on its root-to-leaf path. So: exclusive-lock the path, top down, then work
* Readers must lock too, or they hit the race above
* The root is on every path. Every insert locks the root; everyone queues behind it
* You hold locks across disk I/O all the way down

## Strawman 3: lock coupling (Bayer and Schkolnick 1977)

* Observation: a split stops at the nearest *safe* ancestor. Below a safe node, the damage is contained
* Reader: hold the parent's lock while acquiring the child's, then release the parent. Never hold a pointer that nobody is protecting ("crabbing")
* Inserter: same descent with write locks; when you pass a safe node, release everything above it — a split cannot climb past it
  * refinement: lock the upper levels with a writer-exclusion lock (blocks writers, not readers). Take exclusive locks only where you actually write, mostly near the leaves
  * or be optimistic: descend with read locks assuming the leaf is safe; if not, start over with write locks
* Deadlock-free: everybody locks top down
* What it costs:
  * every search locks and unlocks a node per level. Every search touches the root's lock
  * a writer sits on a subtree while it does disk I/O; readers under it wait
  * the number of locks held depends on where the nearest safe node is; a cascade near the root holds the root
* Two properties we would rather have: searches read without any lock, and an inserter holds a constant number of locks. The paper's Section 1 says exactly this

## Look at the race again

* S's pointer to `y` was not *wrong*. `y` still exists and still holds a subset of the keys it had
* What changed: some keys moved *right*, into a new node `y'`, and S has no path to `y'`
* So do not stop I from splitting. Instead, let S notice and recover:
  1. **Detect.** A node should say what range it covers. Store its upper bound in the node: the *high key*. If v is larger than the high key, the node split after we read its parent
     * the bound has to live *in the node*: it changes exactly when the node's contents change, in the same atomic `put`. A bound remembered from the parent is stale in the same way the pointer is
  2. **Recover.** From `y` there should be a path to `y'` that does not go through the parent. Give every node a pointer to its right sibling: the *link*. Splits always move keys to the right, so the moved keys are always one link away
* That is the B-link tree: a B+ tree plus one key and one pointer per node

```
  y  = [ 9 | 10 | 12 || high 12 | link → y' ]
  y' = [ 15 | 18     || high 20 | link → z  ]
```

* Now step 7 above reads `y`, sees 15 > 12, follows the link, and finds 15 in `y'`
* The split node and its right twin, joined by the link, behave like one big node until the parent gets its pointer
  * so the parent's pointer can be added *later*, in a separate step
  * a node with a left twin but no parent pointer is a *valid* tree. It is reachable
  * rule: the link to a new node exists before the pointer from its parent. Link first, parent second
* Every node on a level is now in a linked list. Rightmost node: null link, high key +∞
  * a leaf-level scan (range query) walks the links and never goes back up
* Price: one key and one pointer per node; an extra page read on the rare occasion you follow a link. Splits are rare

## Search: no locks

```
  search(v):
    current ← root; A ← get(current)
    while current is not a leaf:
        current ← scannode(v, A)         // a child pointer, or the link if v > high key
        A ← get(current)
    while scannode(v, A) is the link of A:   // at the leaf level: keep moving right
        current ← link; A ← get(current)
    return v ∈ A
```

* `scannode(v, A)`: if v > high key of A, return the link. Else return the child pointer whose range holds v
* This is the sequential search plus one comparison per node. It never locks. It may read a page another process has locked; the lock is only against other *writers*
* Why it is right:
  * every page it reads is a consistent node (`get` is atomic)
  * the only thing that can be wrong is *where* it is. Because keys only move right and every move leaves a link, it can be too far left, never too far right. Too far left is repaired by following links
  * nothing ever moves keys to the left (see Delete below). That is the invariant the whole design rests on

## Insert

### Descend, then lock, then go up

* Descend exactly like a search — no locks — remembering the rightmost node visited at each level (a stack)
* At the leaf: `lock` it, then `get` it *again*. The copy from the descent is unlocked and may be stale
* `move_right`: while v > high key, lock the right neighbor, unlock the current node, step right. Left-to-right, hand over hand
* Now we hold the leaf where v belongs, and the lock on it
* If v is already there: unlock, done
* If the leaf is safe: insert, `put`, unlock. One lock, held for one page write
* If the leaf is unsafe: split

### The split, in the right order

```
  u ← allocate a new page
  A, B ← split A plus the new entry;  link(B) ← link(A);  link(A) ← u
  y ← max key in A                     // A's new high key, and the separator for the parent
  put(B, u)                            // first
  put(A, current)                      // second
```

* `put(B, u)` first: nothing in the tree points at `u` yet, so this write changes nothing anyone can see. `B` is the parentless right twin, which we said is legal
* `put(A, current)` second: one atomic page write that both shrinks `A` and links `B` in. Lemma 2: the two writes are one change to the tree
* Other order: rewrite `A` first and a reader following its link lands on an unwritten page
* As far as correctness goes, the split is finished here. The parent does not know yet; searches for the moved keys pay one extra link. Fixing the parent is a performance matter, and we can do it separately

### Go up

```
  oldnode ← current
  (v, w) ← (y, u)                      // what goes into the parent: separator y, pointer to B
  current ← pop(stack); lock(current); A ← get(current)
  move_right                           // the parent may have split since we passed it
  unlock(oldnode)
  repeat from "if A is safe"
```

* The parent we remembered may have split too. Its right twins are reachable by links, so `move_right` at that level finds the correct place
* We keep the child locked until the parent is locked, then drop it. The pair `(y, u)` describes the child as it is; and it keeps the locking order simple (below)
* The parent gets `(12 → y')` inserted next to its existing pointer to `y`: `[ .. 8 | y | 12 | y' | 20 | .. ]`
* If the parent is safe: insert, `put`, unlock. Done. Otherwise split it the same way and go up again
* The paper does not spell out the root split (pop an empty stack): allocate a new root and switch the root pointer. An implementation needs a place to keep that pointer (Postgres: a metapage)

### How many locks?

* Usually one: the node being written
* Going up: the child plus the parent, briefly
* Worst case three: the child, the parent, and the parent's right neighbor while moving right. Then the parent is unlocked
* Constant, independent of tree height and of where the nearest safe node is. Compare crabbing, which holds a path
* Note what is *not* locked: anything on the way down. We lock only what we write, and we lock going *up*. That is only possible because a half-propagated split is a valid tree

### Deadlock

* Order the nodes: lower level before higher level; within a level, left before right
* An inserter locks in that order: leaf, then right along the leaf level, then the parent, then right along the parent level, and so on. Once it holds a node it never locks one below it or to its left
* The order is stable: a split creates a node to the *right* of an existing one, never to the left
* Fixed global lock order → no cycle → no deadlock. Searches take no locks at all

## Why it is correct (Section 6, in words)

* Three facts do the work:
  1. Every disk write is a whole page, on a locked node, atomic. So the tree on disk is a valid tree at every instant (Theorem 2)
  2. Keys only move right, and a new node is linked before it is pointed to. So any pointer you hold is either right or too far left, and links repair too far left (Theorem 3)
  3. Inserters re-read a node after locking it. The decision to insert into it is made on current contents, not on the copy from the descent
* Reader vs. inserter, node `n`
  * reader read `n` after the change: it sees a valid tree and proceeds normally
  * reader read `n` before the change, `n` a leaf: same result as if the reader had run first (it will not see the new key, which is fine)
  * reader read `n` before the change, `n` nonleaf: it may follow a pointer that is now one node too far left. One link fixes it
* Inserter vs. inserter
  * descending: it is a reader
  * going up: the remembered parent may have split, move right
  * both want the same node: the second waits for the lock, re-reads, and is then in the "after the change" case
* Livelock, not deadlock: a very slow process could keep chasing links created by faster ones. The paper argues it is negligible (splits are rare, a level has finitely many nodes) and suggests age-based priority if it ever matters

## Delete

* Lock the leaf, remove the entry, `put`, unlock. One lock
* Allow underflow: a leaf may end up with fewer than `k` entries. No merging, no borrowing from a neighbor
* Nonleaf keys are only upper bounds; they are never removed
* Why refuse to merge? A merge moves keys *left* and deletes a node. Both break fact 2 above: a reader could be too far right, or hold a pointer to a page that is gone. Half-empty leaves are the price; fix them with an offline reorganization (or a whole-tree lock) when it gets bad
* Assumption behind the price: inserts outnumber deletes

## What we got

* Searches: the sequential algorithm plus one comparison per node, zero locks
* Inserts: at most three locks, held only while writing; nothing locked on the way down
* Data structure: one extra key and one extra pointer per node. The sequential code barely changes
* The general recipe (their Section 9): do not prevent other processes from invalidating your position. Make the invalidation *detectable* and *recoverable* with a small addition to the data structure
* What made it work: `get` and `put` are atomic, and every process reads into its own private copy. Nobody can observe a node half-written. Hold on to that; it is the assumption that breaks next

## Where the idea went

* Postgres's B-tree (`nbtree`) is a Lehman-Yao tree: high keys, right links, split right and fix the parent afterwards
  * but pages sit in a *shared* buffer pool, not a private copy per process. A writer could change the bytes while a reader looks at them. So readers do take a short shared lock on the page while examining it. The paper's "no read locks" needs the private-copy model
  * it also deletes pages for real: left links, "half-dead" pages, and reclamation delayed until no scan can still be on the page
* Masstree (next class): in memory, one process, many cores. There are no pages and no atomic `get`
  * a reader can see a node mid-update. Replacement: a version number in each node. Snapshot the version, read, check the version again, retry if it changed
  * same shape as today: readers do not lock; writers lock only what they modify; a split leaves a trail the reader can follow. Hand-over-hand *validation* instead of hand-over-hand locking
