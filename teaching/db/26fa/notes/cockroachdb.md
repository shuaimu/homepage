
# MVCC (CockroachDB)

Paper: Taft et al., *CockroachDB: The Resilient Geo-Distributed SQL Database* (SIGMOD 2020).

Last time ([notes](isolations.html)): snapshot isolation stops read skew but lets write skew through; the safe level, serializable, meant 2PL with read locks. Today: serializable transactions over multi-version data, sharded and replicated across regions, with ordinary NTP clocks: no read locks, no commit wait.

## The job

* Global OLTP: users in Europe, Australia, and "a fast growing user base in the US"
  * GDPR: European users' data must stay in the EU
  * data near the users who touch it most
  * survive "a full regional failure"
  * SQL with serializable transactions, "to avoid data anomalies and to simplify application development"
* No special hardware: "a standard clock synchronization mechanism such as NTP is sufficient"
  * no TrueTime; runs in any cloud, or on-prem
* Spanner (Oct 19, [notes](spanner.html)) got strict serializability: serializable from 2PL (read and write locks) plus 2PC, real-time order from commit wait on TrueTime
* Today's question: can we get serializable from versions, with no read locks and no special clocks?

## The machine we have

* One sorted key-value (KV) map; rows and index entries are KV pairs (TiDB, Aug 31, [notes](tidb.html))
* The map is cut into *Ranges*: contiguous key ranges of about 64 MiB. TiDB's Regions under another name
* Each Range is one Raft group (Sep 2, [notes](raft.html)): 3 replicas by default, spread across failure domains (here: regions)
* *Leaseholder*: one replica, usually the Raft leader, holding a time-based *lease* on the Range
  * proposes every write of the Range
  * so it can serve up-to-date reads with no Raft round (read leases again, Sep 9, [notes](mongodb.html))
* Each node stores its replicas in RocksDB (Sep 21, [slides](../slides/DB26fa-RocksDB.pdf))
* New today
  * *Gateway*: the node the SQL client connects to. It *coordinates* the client's transactions: drives them, commits or aborts them
  * Transactions are *conversational*: one statement at a time, each answered before the next. Read and write sets are not known up front (unlike Mako's one-shot transactions, Oct 21, [notes](mako.html))
  * No timestamp oracle, no TrueTime. Each node has its own NTP-synchronized clock

```
client ──SQL──> gateway = coordinator
                  │ KV ops, one at a time
        ┌─────────┴──────────┐
     R1 (holds C)          R2 (holds S)         each Range: one Raft group, replicas in 3 regions
     leaseholder n1        leaseholder n4
     followers n2, n3      followers n5, n6
```

## Running example

```
C = 100 (checking), S = 100 (savings), both written at ts 5.  C in Range R1, S in Range R2
bank rule: one account may go negative, but C + S ≥ 0

T1  withdraw 150 from C     read C, S; if C + S ≥ 150: C -= 150
T2  withdraw 150 from S     read C, S; if C + S ≥ 150: S -= 150
T3  transfer 10, C to S     read C, S; C -= 10; S += 10
T4  report                  read C + S
```

* In any serial order of T1 and T2, the second sees C + S = 50 and refuses
* C and S are Oct 19's accounts; T3 and T4 are Oct 19's T1 and T3, renamed
* Every trace starts from this state

## Strawman 1: Spanner's locks and commit wait

* Oct 19: 2PL with read and write locks held to commit, 2PC across groups, commit wait on TrueTime
* Read locks: transfer T3 read-locks C and S, so T1's write of C waits out T3's whole run (or, if T1 is older, wounds T3). With replicas on three continents, runs are long
* Commit wait is cheap only when the clock bound is tight
  * TrueTime: a few ms, with GPS and atomic clocks
  * NTP: the bound you can trust is far looser (CockroachDB's default: 500 ms). Every commit would wait about that long
* Keep: Raft per Range, a timestamp per transaction, old versions so reads need no locks

## Strawman 2: snapshot isolation over versions

* *MVCC* (multi-version concurrency control): never overwrite. Keep old versions, each stamped with a timestamp; a read at t sees the newest version ≤ t
* Snapshot isolation (SI), as defined in the Nov 11 reading (Berenson et al.): read the snapshot at the start ts, write at a later commit ts, abort if someone committed a write to a key I wrote since my start (*first-committer-wins*)

```
T1 start 10:  r1[C] = 100, r1[S] = 100
T2 start 11:  r2[C] = 100, r2[S] = 100
T1:           w1[C] = −50, c1 at 12          writes {C}
T2:           w2[S] = −50, c2 at 13          writes {S}: no overlap with T1 → commits
C + S = −100
```

* Nov 11's write skew. Each transaction reads at one moment and writes at another, and nothing re-checks the reads
* The paper: "application developers should not have to worry about write skew anomalies"
* Want: SI's lock-free reads, without the gap between reading and writing

## Idea: read and write at one timestamp

* Each transaction gets one timestamp `ts`. A read returns the newest version ≤ ts; a write creates a version at ts
* The paper: "each transaction performs its reads and writes at its commit timestamp. This results in a total ordering of all transactions in the system, representing a serializable execution."
* Why that would be enough: Oct 19's serialization graph. If every edge goes from a lower ts to a higher ts, there is no cycle, and ts order is a serial order
  * wr: U writes a version, T reads it (U → T)
  * ww: T writes a newer version over U's (U → T)
  * rw: T reads a version, U writes the next one (T → U). The paper's "rw-antidependencies"

```
after T3 commits at ts 10:
key  ts   value
C    10   90
C    5    100
S    10   110
S    5    100
read C at 7 → 100      read C at 12 → 90
```

* Old versions are garbage-collected after a while
* Problems left
  1. Writes on two Ranges must appear at once
  2. Ops arrive in real-time order, not ts order: a write can arrive after a read at a higher ts
  3. Who hands out ts without an oracle? For now, perfect clocks: ts = the gateway's clock at BEGIN
  4. Commit latency. Last

## Atomicity: write intents and a transaction record

* Failing case: T3 at ts 10 writes C@10 = 90 on R1, then S@10 = 110 on R2
  * T4 at ts 15 runs in between: 90 + 100 = 190 (Oct 19's Example 3)
  * and T3 could still abort after C is written
* Strawman: buffer writes at the gateway, run 2PC at COMMIT (Spanner). Two replicated rounds after the last statement; conflicts found only at the end
* Fix: write provisional versions in place, *write intents*
  * "An intent is a regular MVCC KV pair, except that it is preceded by metadata indicating that what follows is an intent."
  * replicated through Raft like any write
  * one writer per key: intents act as write locks
* The metadata points to the *transaction record*: one key per transaction, in the Range of its first write. Status PENDING, STAGING, COMMITTED, or ABORTED (STAGING comes near the end)

```
R1:  C@10 = 90     intent → T3's record          T3's record (on R1): PENDING
     C@5  = 100
R2:  S@10 = 110    intent → T3's record
     S@5  = 100
```

* Commit = one write to one key, one Raft round: "The transaction record serves to atomically change the visibility of all the intents at once"
* A reader meets an intent
  * above my ts: my future, ignore it (perfect clocks; refined later)
  * at or below my ts: read the record
    * COMMITTED: the value counts at the record's commit ts (pushes, below, can raise it above the intent's ts). At or below my ts: use it; above: my future
    * ABORTED: skip it, and clean it up
    * PENDING: wait
  * dead coordinator: it heartbeats its record; a waiter that finds the record expired marks it ABORTED

```
T4  (ts 15) reads C: intent C@10 ≤ 15 → T3's record PENDING → wait
T4' (ts 8)  reads C, S: intents at 10 are its future → C@5 + S@5 = 200
T3 commits: record COMMITTED
T4: C = 90; reads S: intent S@10 → COMMITTED → 110.  C + S = 200
```

* Cost: a reader above a pending writer waits out the writer's remaining life
* Bridges
  * Percolator, the commit protocol TiDB uses (named Aug 31, not covered there): one lock is the *primary*, the others point to it, commit rewrites the primary. Same trick; here the record is its own key, and no oracle hands out timestamps
  * Oct 19's 2PC recovery, Option 1: the decision is one durable record. Here it sits in the data, and any reader settles the outcome by reading it

## Problem: a write arrives after a read

```
     T1 (ts 10)                          T2 (ts 11)
1.   r1[C] = 100, r1[S] = 100
2.                                       r2[C] = 100, r2[S] = 100
3.   w1[C]: intent C@10 = −50
4.   commit at 10
5.                                       w2[S]: intent S@11 = −50
6.                                       commit at 11
C + S = −100
```

* In ts order T1 (10) comes first, so T2 should have read C = −50
* T2 read C before T1's version existed: an rw edge T2 → T1, from 11 to 10. It points backward

## Fix 1: push the writer above earlier reads

* Strawman: read locks. Strawman 1's cost
* Strawman: reject the late write and abort T1 (basic timestamp ordering). Conversational transactions run long, so many writes are late; any reader, even report T4, can cost a writer a restart
* Fix: each leaseholder remembers, per key, the highest ts it was read at: the *timestamp cache*. A write at or below it is *pushed*: its transaction's ts moves above it
  * "A write to a key at timestamp t_a cannot be performed if there's already been a read on the same key at a higher timestamp t_b >= t_a. CRDB forces the writing transaction to advance its commit timestamp past t_b."
  * a transaction's own reads do not push it
  * nobody waits, nobody aborts
* Why one in-memory table per leaseholder is enough
  * the leaseholder serves every read at timestamps where writes can still land
  * it may be coarse, e.g. one max per key span: that only over-pushes
  * lost when the lease moves? The new leaseholder writes only at timestamps inside its own lease, above every read the old one served (leases, later). Nothing to hand over
* Same for a write that meets a committed version above its ts: pushed above it
* Replay; the right column is what the timestamp caches hold:

```
     T1 (ts 10)                          T2 (ts 11)                      highest read
1.   r1[C], r1[S] at 10                                                  C 10 (T1)   S 10 (T1)
2.                                       r2[C], r2[S] at 11              C 11 (T2)   S 11 (T2)
3.   w1[C]: C read at 11 ≥ 10
       → push T1 to 12; intent C@12 = −50
4.   commit at 12 (its reads were at 10)
5.                                       w2[S]: S's 11 is T2's own
                                           → no push; intent S@11 = −50
6.                                       commit at 11
C + S = −100 again
```

* Now ts order is T2 (11), T1 (12). T1 should have read S = −50, but read 100 at 10: the rw edge T1 → T2 points backward
* The push moved T1's writes, not its reads. T1 reads at 10 and writes at 12: Strawman 2 again
* The paper now splits ts in two: a *commit timestamp* that pushes move, and a *read timestamp*. They agree until a push
* An intent laid before a push stays at the old ts until it is resolved. Hence the reader rule takes the ts from the record: T3 lays C@10, is pushed to 13, lays S@13, commits at 13. A reader at 11 that trusted C@10 would read 90 + 100 = 190

## Fix 2: read refresh

* Strawman: abort on every push. Then a report that read C at a higher ts restarts every transfer, even when nothing it read changed
* "Advancing a transaction's read timestamp from t_a to t_b > t_a is possible if we can prove that none of the data that the transaction read at t_a has been updated in the interval (t_a, t_b]. If the data has changed, the transaction needs to be restarted."

```
refresh(T, t_new):                                    // at the coordinator
  for each key or span k that T read:
    if another txn wrote a version or intent of k in (T.ts, t_new]:  return FAIL → restart T
  record T's reads at t_new                           // in the timestamp caches (implied, not stated)
  T.ts ← t_new
```

* One round of RPCs to the Ranges read; no consensus
* Replay, third time:

```
     T1 (ts 10)                          T2 (ts 11)                      highest read
1.   r1[C], r1[S] at 10                                                  C 10 (T1)   S 10 (T1)
2.                                       r2[C], r2[S] at 11              C 11 (T2)   S 11 (T2)
3.   w1[C]: C read at 11 → push to 12; intent C@12 = −50
     refresh {C, S} over (10, 12]:
       nothing new → T1 at 12                                            C 12 (T1)   S 12 (T1)
4.   commit at 12
5.                                       w2[S]: S read at 12 by T1
                                           → push T2 to 13
                                         refresh {C, S} over (11, 13]:
                                           C@12 → FAIL → restart
6.                                       retry at 14: C = −50, S = 100
                                           50 < 150 → refuse
C = −50, S = 100: one withdrawal, as in a serial order
```

* Why record the reads at t_new: otherwise S's highest read stays 11 (T2's own), T2 is not pushed, and commits S@11 under reads T1 now claims at 12. −100 again
* Bridge: Mako's Validate (Oct 21) re-checks the read set at every commit. Here only after a push: a transaction never pushed has every later writer pushed above its reads, and every version above its ts stays its future
* Restarts: "If no results from the transaction have been delivered to the client, CRDB retries the transaction internally." Otherwise the client must retry. Postgres applications do not expect that
* The paper's summary: "pessimistic write locks, but otherwise it is an optimistic protocol"
* Costs: restarts under contention; the read set kept at the coordinator "up to a memory budget"; false positives, which the paper admits

## Write-write conflicts

* The paper's rules
  * an uncommitted intent with a lower ts: wait
  * a committed value with a higher ts: push past it, then refresh
* Lost update (Oct 19's Example 1, with a withdrawal of 150):

```
T3 (ts 20): reads C = 100, S = 100                    highest read: C 20, S 20
T1 (ts 21): reads C = 100, S = 100                    highest read: C 21, S 21
            w1[C] = −50 (21 is its own read); commits at 21
T3: w3[C] = 90: C read at 21 by T1 → push to 22 (the committed C@21 would push it too)
    refresh {C, S} over (20, 22]: C@21 → FAIL → restart
retry at 23: C = −50 → −60, S = 100 → 110.  C + S = 50
```

* Without the refresh, T3 commits C = 90, S = 110: the books say 200 after the bank paid out 150. No first-committer-wins rule needed; push plus refresh catch it
* Waits can form a cycle (T3 writes C then S, another transfer writes S then C). "CRDB employs a distributed deadlock-detection algorithm to abort one transaction from a cycle of waiters." Oct 19's wound-wait prevented deadlocks; here they are detected

## Why it is serializable

* Serial order = commit-ts order. Each edge points forward
  * wr: T reads U's version only once U committed, at a commit ts ≤ T's; a pending intent below makes T wait
  * ww: T's version lands above every committed version, or T waits on the intent
  * rw, read first: the writer is pushed above the read
  * rw, write first, above my ts: my future. It turns backward only if my ts later moves past it, and then the refresh finds exactly that version
* Versus SI, in Nov 11's graph terms: SI orders wr and ww edges, but an rw edge between concurrent transactions can point backward, and two of them close write skew's cycle. Here no rw edge points backward
* Read skew is gone too: all reads are at one ts
* Phantoms: the read set holds scanned spans, so an insert into a scanned span within (old ts, new ts] fails the refresh, and a later insert below the scan's ts is pushed (Nov 11's H3)
* The paper: "This process is equivalent to detecting the rw-antidependencies that PostgreSQL tracks for its implementation of SSI"
  * not the same test: Postgres's SSI (serializable snapshot isolation) runs SI and aborts on two consecutive rw edges; CockroachDB aborts on one rw edge a push would turn backward
* What the argument used: one leaseholder per Range sees every read at a ts where writes can still land (leases; skew comes later). What it never used: clocks

## Clocks: who hands out timestamps?

* Any ts assignment stays serializable: pushes and refreshes fix the order. The paper: "even under severe clock skew that violates maximum clock offset bounds, CRDB provides serializable isolation"
* So clocks are for real time: a transaction that starts after another finished should see it
* Strawman: a timestamp oracle (TiDB's PD, Aug 31). One round trip to one place per transaction, across continents
* Strawman: TrueTime. Special hardware
* Strawman: each node's NTP clock as is. It learns nothing from messages
  * a clock that steps back (an NTP correction, a restart) hands out a ts below one it already gave: a client's second transaction can get a lower ts than its first, and miss its own write
  * a lease handed from n1 to n2, whose clock is behind, cannot start until n2's clock catches up
* Strawman: a Lamport clock per shard, as in Mako (Oct 21). Mako reads the newest version and picks ts afterwards; we pick the read ts at BEGIN, and a quiet node's counter lags far behind, so its transactions read old data
* Fix: a *hybrid-logical clock* (HLC): a Lamport clock riding on the physical clock. It never goes backward, and every message carries it
* Update rules (from the HLC paper; CockroachDB's paper gives none):

```
timestamp (l, c): l = largest physical time seen, c = counter; compare l, then c.  pt = this node's wall clock
local event or send:   l' = max(l, pt);       c' = c + 1 if l' = l, else 0
receive (lm, cm):      l' = max(l, lm, pt);   c' = 1 + largest counter among (l, c), (lm, cm) whose l is l'
                                              (0 if only pt reaches l')

node A, pt = 100:  event               (100, 0)
node A, pt = 100:  send to B           (100, 1)    the message carries (100, 1)
node B, pt = 90:   receive             (100, 2)    B was at (90, 0): its wall clock is behind, its HLC is not
node B, pt = 101:  event               (101, 0)
```

* What CockroachDB uses
  * causality: messages carry HLC timestamps, so a node that heard of an event gets a later ts. The lease handoff message carries n1's time, so n2 starts at once
  * strict monotonicity per node, kept across restarts by "waiting out the maximum clock offset upon process startup"
* *max_offset*: the configured bound on clock offset between nodes, "a conservative value of 500 ms"
* Limit: an HLC sees only causality that travels in the system's own messages

## Problem: a stale read across gateways

```
max_offset = 500. Gateway A's clock runs 200 ms fast; gateway B's is right
true 1000  T5 via A: deposit 100 into S, commits at ts 1200; client told "done"
           the client phones a teller (no message from A to B)
true 1050  T4 via B: report, ts 1050
           reads C@5 = 100; S: newest ≤ 1050 is S@5 = 100        → 200: the deposit is missing
```

* *Stale read*: a transaction misses a write by a transaction that finished before it began. The HLC cannot help: the phone call is outside the system
* Strawman: Spanner's commit wait. A cannot know how far off its own clock is, so T5 waits a full 500 ms. Every writer, every commit

## Idea: uncertainty intervals

* A transaction gets "a provisional commit timestamp commit_ts from the transaction coordinator's local HLC and an uncertainty interval of [commit_ts, commit_ts + max_offset]"
* A reader at ts, with *limit* = start ts + max_offset, sorts what it finds
  * version ≤ ts: past
  * version in (ts, limit]: *uncertain*. It may have finished before T began, so treat it as past: push ts above it (with a refresh), keep limit fixed
  * version above limit: future, ignore it
* Intents in (ts, limit] are uncertain too: read the record, wait if PENDING. A writer's client hears "committed" before its intents are cleaned up (CockroachDB's design; the paper's rule ignores every intent above ts, which is safe only with perfect clocks)

```
T4: ts 1050, window up to 1550
reads C: C@5 = 100
reads S: S@1200 ∈ (1050, 1550] → uncertain → refresh {C} over (1050, 1201]: unchanged → ts 1201
         S@1200 = 200.  report 300
```

* Why it suffices: an HLC's physical part is some node's earlier clock reading, never above the fastest clock, which is within max_offset of T's gateway. So a transaction that finished before T began has ts ≤ T's start + max_offset: in T's past or window, never its future
* Why limit stays fixed: moving it adds nothing needed, and on a hot key T could be pushed forever

```
                    Spanner (Oct 19)                         CockroachDB
clock               TrueTime: GPS + atomic clocks            HLC over NTP
uncertainty         a few ms                                 max_offset, 500 ms by default
who pays            every read-write commit: commit wait     a reader that finds a value in its window:
                                                             a refresh, or a restart
reads in r/w txns   read locks (2PL)                         no locks; refresh when pushed
guarantee           strict serializability                   serializable, no stale reads
```

## What we got: no stale reads, not strictly serializable

* "Under normal conditions, CRDB satisfies single-key linearizability for reads and writes." *Single-key linearizability*: the transactions touching one key are ordered consistently with real time. "Under single-key linearizability, stale read anomalies are not possible."
* *Strict serializability* (Oct 19): serializable, and if T1 finished before T2 began, T1 comes first
* "CRDB does not support strict serializability because there is no guarantee that the ordering of transactions touching disjoint key sets will match their ordering in real time."

```
max_offset = 500. Gateway A's clock runs 150 ms fast; B and G are right; no message from A reaches B or G
true 1000  T4 via G: report, ts 1000, window up to 1500
true 1400  T6 via A: deposit 100 into C, commits at ts 1550; client 1 phones client 2
true 1450  T5 via B: deposit 100 into S, commits at ts 1450
true 1500  T4 reads S: S@1450 ∈ (1000, 1500] → uncertain → ts 1451 (nothing read yet) → S = 200
true 1550  T4 reads C: C@1550 > 1500 → future → C = 100
T4 reports 300: T5's deposit but not T6's, though T6 finished before T5 began
ts order T5 (1450) < T4 (1451) < T6 (1550): serializable. Real time puts T6 before T5
```

* Each key alone is fine: T4 began before T6 finished, so either order on C is allowed
* The anomaly needs a reader that started before T6 finished: a later reader has T6 in its past or window
* The paper: "In practice, this is not a problem for applications unless there is an external low-latency communication channel between clients"

## When clocks drift past the bound

* Rerun the stale read with A 600 ms fast: S@1600 is above 1550, the future; T4 reports 200. A stale read
* Serializability holds anyway
  * Raft has no clock: its order for one Range "will remain linearizable regardless of clock skew"
  * the danger is leases: they are time-based, so under skew two nodes can both believe they hold one
  * two safeguards: a lease covers a ts interval, and leases never overlap, so an incoming leaseholder cannot write under an outgoing one's reads; each Raft command carries the lease sequence number it was proposed under, so an outgoing leaseholder's late write is rejected on apply
* A node whose offset "exceeds the configured maximum offset by more than 80%" against a majority shuts itself down (CockroachDB's docs: 80% of max_offset, 400 ms by default). The offset is measured periodically, so a skew can do damage before it is caught

```
                            serializable   no stale reads   strict serializable
clocks within max_offset    yes            yes              no (disjoint keys)
clocks beyond it            yes            no               no
```

* In one line: clock skew can cost stale reads, never serializability

## Problem: one consensus round per write

* W = one Raft round. Replicas sit in three regions, so W is a cross-region round trip
* Assume the leaseholders are near the gateway, so a hop to them is about 0 (placement, optional part, is how you get that)
* T3 as the client sends it:

```
statement         at the leaseholder                        client waits
BEGIN             ts 10 from the gateway's clock            -
SELECT C, S       read C, S at 10: 100, 100                 0
UPDATE C          intent C@10 → Raft                        W
UPDATE S          intent S@10 → Raft                        W
COMMIT            record T3: COMMITTED → Raft               W
                                                            3W.  k writes: k + 1 rounds in a row
```

* Why does an UPDATE wait for Raft? Only so that COMMIT never makes a lost intent visible. That check can wait until COMMIT

## Idea: write pipelining

* The leaseholder evaluates the write, proposes it to Raft, and answers at once; replication goes on in the background
* The coordinator tracks *in-flight* writes: proposed, not yet known to be replicated
  * an op on a key with an in-flight write waits for it: a *pipeline stall*
  * ops on other keys go ahead: "multiple operations on different keys can be “pipelined”"
  * COMMIT waits for every in-flight write

```
statement         leaseholder                                    in flight    client waits
UPDATE C          intent C@10, answer; Raft runs on              {C}          ~0
UPDATE S          intent S@10, answer; Raft runs on              {C, S}       ~0
COMMIT            wait until C, S replicated (overlapped)                     ~W
                  then record COMMITTED → Raft                                W
                                                                              2W, for any k
```

* Who sees an unreplicated intent? Nobody else: the leaseholder holds a per-key in-memory *latch* from evaluation through replication, so another transaction's request on C waits until C's intent is durable
  * contrast Mako (Oct 21): others read unreplicated writes, so a failure cascades rollbacks. Here only T3 runs ahead of its own replication
* Still "at least two sequential rounds of consensus"

## Problem: the commit still waits for the writes

* Strawman: replicate COMMITTED at the same time as the last intents

```
R1   record T3: COMMITTED → Raft    replicated; client told "committed"
R2   intent S@10 → Raft             n4 dies before a quorum: S@10 is lost
after failover, T4 (ts 15):         C: intent → COMMITTED → 90;  S: S@5 = 100.  190: the 10 vanished
```

* 2PC's answer (Oct 19): every part durable first (prepare), then the decision. Two rounds again
* Oct 19's Option 2: "If both server-a and server-b successfully prepared T1, then T1 must commit"
  * the decision need not be a separately replicated bit; it can be a fact about durable state
  * the replicated intents already are the prepare records

## Idea: parallel commits

* New status *STAGING*: it "makes the true status of the transaction conditional on whether all of its writes have been replicated"
  * *implicitly committed* ⇔ the record is STAGING and every write it lists is replicated at a ts ≤ the record's ts
  * the record lists the in-flight writes, so anyone can check

```
COMMIT, at the coordinator:
  replicate record STAGING{ts 10, writes C, S} on R1     ┐
  check intent C replicated (R1), intent S (R2)           ├ all at once
  all three durable → reply "committed"                   ┘
  later, off the client's path: record ← COMMITTED; resolve intents into plain versions
```

* Why still write COMMITTED: under STAGING every reader would have to check every write

```
time →              0            W            2W           3W
naive               [ C ────────][ S ────────][ COMMITTED ─]    3W
pipelining          [ C ────────]
                    [ S ────────][ COMMITTED ─]                 2W
parallel commits    [ C ────────]
                    [ S ────────]
                    [ STAGING{C,S}]                             1W
```

```
                           consensus rounds on the commit path        other waits
Spanner (Oct 19)           2: prepare, then commit                    commit wait
Percolator/TiDB (Aug 31)   2: lock all keys, then the primary          trips to the timestamp oracle
Mako (Oct 21)              1: 2PC among leaders, then replicate       the watermark; a failure rolls back
CockroachDB                1: last writes and STAGING together        none at commit (readers pay: uncertainty)
```

## Recovery: the coordinator dies while STAGING

```
T3 at ts 10; record on R1; in flight: C (R1), S (R2)
STAGING{C, S} at 10, intents C@10 and S@10, all three replicating

case 1: all three replicated → client acked → coordinator dies before COMMITTED
        T4 (ts 15) meets S@10 → record STAGING → checks C and S: both replicated
        → writes COMMITTED; reads 90 + 110 = 200
case 2: coordinator dies before S@10 is replicated (client never acked)
        T4 meets C@10 → STAGING, heartbeat expired → asks R2 for S@10: not there
        in the same step, R2 records a read of S at 10 → a late S is pushed above 10, the record's ts, and no longer counts
        → writes ABORTED; reads 100 + 100 = 200
```

* Why prevent the write, not just note it missing: S could land a moment later, and T3 would become committed after T4 decided ABORTED
* The paper: "the reader attempts to abort the transaction by preventing one of its writes from being replicated. If all writes are already replicated, the transaction is in fact committed, and is updated to reflect that." How it prevents the write is not in the paper; our reading: the timestamp cache again
* A reader can never abort a transaction whose client heard "committed": the coordinator replies only after all writes and STAGING are durable
* Bridge: Oct 19's Option 2 recovery reads every participant's log. Here it is done lazily, by whichever transaction is blocked
* Cost: recovery touches every Range the transaction wrote; only after a coordinator crash

## What it costs, what it assumes

* Got
  * reads: no consensus, no locks (a WAN trip only to a far leaseholder)
  * a transaction: 1 W at commit however many keys it writes (plus a W for each pipeline stall)
  * serializable always; no stale reads while clocks stay within max_offset; not strictly serializable
* Costs
  * restarts under contention, and clients that must retry
  * refreshes and their false positives
  * uncertainty restarts inside a 500 ms window
  * readers blocked behind PENDING writers
* Assumes clocks within max_offset, for freshness only
* Versus Spanner: no read locks, no commit wait. The price: serializable, not strict
* The core lecture ends here. The next three sections are optional: run on if time is left, otherwise leave them for reading

## Why not offer snapshot isolation too?

* The paper (section 7.2): SERIALIZABLE is the default also because "in our implementation the performance advantage of the weaker isolation level was small"
* "we initially expected that offering just snapshot isolation by removing the check for write skews would be simple. However, this proved not to be the case."
  * "The only safe mechanism to enforce strong consistency under snapshot isolation is pessimistic locking, via the explicit locking modifiers FOR SHARE and FOR UPDATE on queries."
  * mixing levels would need locks "for any row updates, even for SERIALIZABLE transactions"
* So SNAPSHOT became "an alias to SERIALIZABLE"

## Follower reads: closed timestamps

* Problem: R1's leaseholder is in another region, though a nearby replica exists. Every read crosses regions
* A follower may lag the log, and the leaseholder may still accept writes at the read's ts
* *Closed timestamp*: "the timestamp below which no further writes will be accepted", sent to followers with a Raft log index; a later write below it is pushed above it (our reading)

```
R1 leaseholder n1 → followers: "closed ts 1000 at log index 57"
far follower n3, applied through index 60:
  read C AS OF SYSTEM TIME 990     990 ≤ 1000 and 60 ≥ 57 → served locally, no WAN trip
  read C at 1100                   above the closed ts → forwarded to the leaseholder
```

* "closed timestamps typically trail current time by ~2 seconds": the read is stale on purpose, so the client opts in with `AS OF SYSTEM TIME`
* Bridges: Spanner's `t_safe` (Oct 19) and Mako's watermark (Oct 21), timestamps below which a replica's state is final

## Placement, SQL, evaluation

* Placement policies (the paper's menu; its Figure 1 customer would use them to keep EU data in the EU)

```
policy                         reads    writes                       a whole region fails
geo-partitioned replicas       local    local                        that region's data unavailable
geo-partitioned leaseholders   local    cross-region                 survives
duplicated indexes             local    cross-region, more writes    survives
```

* Geo-partitioned replicas: all of a partition's replicas in its home region. Geo-partitioned leaseholders: only the leaseholder there, the other replicas elsewhere. Duplicated indexes: a copy of a rarely updated index in each region, each with a local leaseholder
* SQL
  * a Cascades-style optimizer: Nov 2's search over subplans ([slides](../slides/DB26fa-QueryOpt.pdf)), run top-down with rewrite rules
  * distributed execution, for read-only queries: plan pieces go to the nodes holding the ranges, as in Spanner SQL (Nov 4, [slides](../slides/DB26fa-SpannerSQL.pdf))
  * online schema changes as in F1: at most two schema versions live at once
* Parallel commits: "improves throughput by up to 72% and reduces p50 latency by up to 47%" (p50: the median) over committing after the writes, on writes that touch secondary indexes in other Ranges
* TPC-C: 1,245,462 tpmC (new-order transactions per minute) at 100,000 warehouses
* Against Spanner on YCSB (key-value benchmarks): higher throughput on most workloads. On workload A, update-heavy with skewed keys, it "does not scale well": Spanner pulls ahead at 15 servers

## Where the idea went

* CockroachDB 20.1 added `SELECT ... FOR UPDATE`: read locking for contended workloads, where refresh restarts hurt
* Weaker levels came back: READ COMMITTED, built on pessimistic locks. The paper had argued a weaker level could be made safe only with locks
* Multi-region SQL: a GLOBAL table's writes commit at a future timestamp and wait it out, so any replica serves fresh reads. Commit wait, back for read-mostly data
* TiDB 5.0 (2021): async commit. The primary lock lists the secondaries, and the transaction counts as committed once every lock is written. Parallel commits in Percolator's shape
* Postgres SSI (Ports and Grittner, VLDB 2012): the other road from MVCC to serializable. Keep SI, abort on dangerous rw-edge pairs
* Oct 19, Nov 11, and today form one arc: locks and commit wait for strict serializability; what weaker levels let through; timestamps plus refresh to get serializable back without read locks

## Questions to review

* Replay T1 and T2 under snapshot isolation. Why does first-committer-wins not fire?
* Why does reading and writing at one timestamp make ts order a candidate serial order? For wr, ww, and rw edges, which mechanism keeps each pointing forward?
* With perfect clocks, T3's intent C@10 is PENDING, and readers at ts 15 and ts 8 read C. What does each do? Why can't the first just read C@5?
* A write at ts 11 reaches a key already read at ts 12. Give three responses (abort, lock, push) and the cost of each. Which does CockroachDB use? Why may the timestamp cache be approximate, and in which direction?
* Replay the write-skew race with pushes but no refresh, then with a refresh that does not record its reads at the new timestamp. Where does each go wrong?
* Replay the lost update. What makes T3 restart? Why is no first-committer-wins rule needed?
* Mako's Validate checks the read set at every commit; CockroachDB only after a push. Why is a transaction that was never pushed safe without a check?
* When can CockroachDB retry a transaction by itself, and when must the client?
* Node B's wall clock reads 90, its HLC is (80, 4), and it receives a message stamped (100, 1). What is B's HLC afterwards? What does a plain NTP clock lack, and what does a Lamport clock lack?
* max_offset = 500. Gateway A is 300 ms fast and B is exact. T5 via A commits its deposit at true time 1000; T4 via B starts at true time 1100 and reads C, then S. What are T5's ts and T4's window, and what does T4 report? Redo with A 700 ms fast. Which guarantee is lost, and which is kept?
* Why does the upper end of the uncertainty window stay fixed when ts moves up?
* Give a history CockroachDB allows and Spanner does not. Why must the reader have started before the first writer finished?
* T3 gains a third UPDATE on a third Range. How many consensus rounds does the client wait for with no pipelining, with pipelining, and with parallel commits? What keeps other transactions from seeing an unreplicated intent?
* Why can't COMMITTED replicate together with the last intents? What does STAGING change? A reader finds T3's record STAGING with S's write missing: why must it prevent the write rather than note its absence, and why can it never abort a transaction whose client heard "committed"?
* Map the transaction record to Percolator's primary lock, and plain commit and parallel commits to Oct 19's two 2PC recovery options
* (Optional part) What did CockroachDB do with SNAPSHOT, and why was offering it harder than removing the write-skew check?
* (Optional part) A follower serves an `AS OF SYSTEM TIME` read. What must it know, and why must the client opt in?
