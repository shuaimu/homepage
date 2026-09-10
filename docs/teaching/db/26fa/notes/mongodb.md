
# MongoDB Replication

Paper: Zhou and Mu, *Fault-Tolerant Replication with Pull-Based Consensus in MongoDB* (NSDI 2021).

### Election competition
* Majority vote. Two candidates at once → often *neither* wins (split vote)
* Then everyone times out, increments the term, tries again — unavailability stretches
* Raft’s fix: randomized election timeout
  * why random?
  * why does the *spread* have to be relatively large?
    * if two timeouts fire within one RTT of each other, both campaign
    * the random window needs to be ≫ broadcast time, so typically one candidate starts well before the others
  * why is the timeout itself large compared to the heartbeat?
    * heartbeat ≪ election timeout, or a slow RPC looks like leader death
    * the Raft paper’s example is 150–300 ms; production is often seconds (MongoDB default 10 s)
    * tradeoff: slower failover vs fewer spurious elections
* planned failover (upgrade, step-down): do you still want to sit out a random 10 s? (leadership transfer)

### A half-isolated node that keeps incrementing its term
* Partition: S5 cannot hear the leader. It times out, `currentTerm++`, campaigns, gets no majority, times out, term++ …
* Half-isolated: can talk to *some* nodes, never a majority — so it can never win, but it *can* deliver a higher term
* When a `RequestVote` with term 10,000 reaches the leader (or the partition heals):
  * everyone adopts the high term
  * the real leader steps down
  * cluster is unavailable while they elect again
  * S5 still cannot win (log is stale) → it will do this again
* Safety is fine. Availability is not
* What do implementations do?
  * Pre-vote (Dryrun): ask “would you vote for me?” *before* incrementing `currentTerm`. If you cannot win, don’t bump the term
  * Check-quorum: leader stays leader only while it can hear a majority — a minority’s term bump cannot depose it by itself (details vary)
* Priority-based “please elect me” policies make this worse if you skip pre-vote

### Learners (and other extra replicas)
* Recall TiFlash (TiDB lecture) is a Raft learner: gets the log, not in the election, not in the commit quorum
* Why not just add another follower?
  * majority gets larger → writes wait on more nodes (including the analytic box)
  * that node can become leader — you may not want the OLAP replica taking writes
* Learner = copy of the log that cannot vote and does not count toward commit
  * leader does not wait on it at commit time
  * it cannot win an election (until you promote it)
* Other extra roles people invent:
  * witness / arbiter: votes, stores *no* data (cheap tie-break)
  * read-only geo copies, a node that is still catching up, …

### Linearizable reads: the leader cannot just serve locally
* Tempting: reads dominate, they do not change state, the leader already has the log
* Why that is wrong:
  * leader is partitioned; majority elects a new leader; new leader commits writes
  * old leader does not know; a client reads from it → stale value, *after* another client already saw the new write
  * linearizability forbids that
* Strawman that is correct: treat the read like a write. Append a no-op (or the read itself), wait until it commits, then answer
  * every read pays a majority round trip and dirties the log
* Two standard bypasses (do not log the read):

  1. Read leases
  * leader holds a lease of length T. Followers will not elect (or the new leader will not serve reads) until T has passed since the old leader’s last heartbeat
  * clocks must be close enough — the lease is a time bound
  * while the lease is valid, this node is the only one allowed to serve linearizable reads → local, no RPC
  * cost: clock assumption, and a new leader must wait out the remaining lease
  * TiDB’s “lease read”; later MongoDB work (LeaseGuard) is this problem done carefully

  2. Wait until the next write succeeds
  * do not append a dummy. Record “linearize me with the next commit” (or with some write already in flight)
  * when that write hits a majority, you have proof you were still leader, and the read sits after every write that committed before that point
  * if a write is already replicating: piggyback — no extra log entry
  * if the system is idle: wait for the next client write, or fall back to a no-op
  * still a round trip when you have to wait; still leader only

* Weak / stale reads on followers are a different product knob — not this problem

### Speculative apply and rollback
* Raft textbook: append to the log, wait for commit, *then* apply to the state machine
  * applied prefix = committed prefix
  * failover only truncates an uncommitted *log* tail; state is always a prefix of committed history
* Production KVs often apply before commit (speculative)
  * why: weak / read-your-writes without waiting for a majority; hide apply latency on the leader; leftover of primary-backup (“ack after local apply”)
  * linearizable clients still wait for commit
* Cost: failover may throw away log entries you already applied
  * truncating the log is not enough — those writes are already in the state machine
  * you need rollback of state, not just of the log
* How do you roll state back?
  * undo log: one compensating op per speculative entry
  * or MVCC / timestamped versions: revert to a snapshot timestamp, then optionally replay forward to the last common log entry
  * or speculate only on the leader — still a problem when that leader is deposed
* Invariant: a linearizable read must not see a speculative write; a committed write must survive rollback
* This paper: every replica speculates (weak-consistency product); rollback via timestamp revert, not an undo log

### A few more you will hit
* catching up a far-behind replica: snapshot, or clone + replay?
* membership change without two leaders of two configs? (Raft §6 — we are not redoing that today)

## What MongoDB is (for this lecture)

History of one product’s replication, not a green-field Raft KV.

### Single node
* 10gen / MongoDB (~2007–2009): a document store on one machine
  * BSON documents in collections (JSON-ish rows)
  * crash the box, the database is down
* That is the product people adopted. Replication is bolted on later — unlike Spanner / TiDB, which started as replicated systems

### Primary-backup (replica set, pre-consensus)
* From 1.0: replica set = one primary, some secondaries, a logical copy of the DB
* Data plane is pull, not the usual push-from-primary
  * a secondary fetches the oplog from some other node (often not the primary)
  * this predates Raft in the codebase; it is why they will refuse vanilla `AppendEntries`
* Failover is *not* consensus:
  * either a human appoints the new primary, or
  * they assume a semi-synchronous network: if you have not heard in 30 s, the node is dead
* What that cannot do:
  * a partition looks like death → two primaries (split brain)
  * a slow network looks like death → spurious failover
  * no majority commit, no Leader Completeness — “the primary said so” is the durability story
* Weaker consistency knobs already exist here (ack after primary apply, after one extra copy, …). Those knobs never went away — they will force speculative apply and primary catchup later
* Sharding, when it comes, is many replica sets. Today is one set

### Then Raft (from 2015)
* Demand: linearizability + survive any minority, in an asynchronous network (arbitrary delay/loss; no perfect failure detector)
* No drop-in protocol: Paxos / Raft push from the leader; they needed to keep pull
* Remodel the replica set as a Raft group
  * same elections (terms, majority, up-to-date log)
  * same commit-on-majority
  * data sync still pull, between *any* two replicas
* Autonomous failover; election timeout drops from “30 s means dead” to ~10 s
* This paper (NSDI 2021) is that protocol: Raft safety with the old pull data plane

## Why pull, not vanilla Raft?

MongoDB: any replica can fetch from any other replica.
* Topology control. Users (esp. multi-DC / cloud) want to pick the path.
  * Intra-DC traffic is cheap/fast; cross-DC is billed and bandwidth-limited
* Backward compatibility. MongoDB had pull-based replication long before Raft. Keep the programming model, put consensus underneath

Takeaway: the paper is not “a better Raft.” It is “Raft’s safety, with the data plane of an old pull-based primary-backup system.”

## Split AppendEntries into two RPCs

Raft `AppendEntries` does three jobs at once: ship entries, learn matchIndex, heartbeat.

MongoDB splits that:

| Job | Who initiates | RPC |
|-----|---------------|-----|
| fetch new entries | secondary (any → any) | `PullEntries` |
| report log position so the primary can commit | secondary, forwarded hop-by-hop toward the primary | `UpdatePosition` |
| liveness, commit-point gossip, sync-source selection | everyone ↔ everyone | `Heartbeat` |

Elections still use `RequestVote` (same as Raft).

Principle: decouple the data path from the commit path. Data can flow on a chain. Commit still needs a majority at the primary.

### PullEntries

* Syncing server = the puller. Sync source = who it pulls from (need not be the primary)
* Request carries the last local log index
* Source returns entries at/after that index, or empty if it is behind
  * if logs are equal, wait ~5 s for new data (avoid busy loop)
* On reply, concatenate only if the first received entry matches the last local entry
* If they don’t line up and the received log is *newer*: walk the source’s log back to the last common entry, truncate the local tail, then append
  * same idea as Raft log rollback, but the *follower* drives it
  * extra work because of speculative apply (opening question)

### UpdatePosition

* After a successful pull, the secondary tells its sync source its last log position
* Each hop forwards toward the primary (batch: keep the highest position per server; at most one in-flight)
* Primary keeps a volatile `lastPosition[]` map (Raft’s `matchIndex`)
* Commit rule (same *shape* as Raft Figure 2):
  * some entry `e` with `e.term == currentTerm`
  * a majority of `lastPosition[i] ≥ e`
  * then `lastCommitted ← e` (and everything before it)
* `lastCommitted` rides back on heartbeats and `PullEntries` replies

## The change is *not* a rename

`PullEntries` does not check that the sync source’s term ≥ the puller’s term.

In Raft, after you vote in term 3 you refuse `AppendEntries` from a term-2 leader. In MongoDB you can still *pull* that term-2 entry, because the pull does not carry “I am the current leader of term T.”

That is the whole protocol hazard.

### Figure 2 (why “on a majority” is not “committed”)

Five servers. Entry at index 1 is term 1 everywhere. Then:

```
              (a) start          (b) Raft            (c) MongoDB pull     (d) A sees term 3    (e) later
A  term 2     1  2               1  2                1  2                 1  2  (steps down)   1  3
B  term 2     1                  1  2  ← from A      1  2                 1  2                 1  3
C  term 3     1                  1     (rejects A)   1  2  ← from A       1  2  → UpdatePos    1  3
D  term 3     1                  1     (rejects A)   1  2  ← from A       1  2  → UpdatePos    1  3
E  term 3     1  3               1  3                1  3                 1  3                 1  3
```

* (a) A won term 2 (votes A/B/C), wrote a local entry. E won term 3 (votes C/D/E), wrote a *different* entry at the same index
* (b) Raft: only B will accept A’s `AppendEntries`. C/D/E already have a higher term
* (c) MongoDB: if A is the sync source, B/C/D will all take A’s term-2 entry — it is “newer” than what they have
* If A now used Raft’s naive rule (“I created this entry and it is on a majority → commit”), the term-2 entry would be committed
* Then E’s term-3 entry can overwrite it → committed entry lost

Same bug Raft already warns about as “counting replicas, not replies.” Here it shows up because pull does not refuse a stale primary.

### The fix: put the puller’s term on UpdatePosition

* `UpdatePosition` carries the syncing server’s current term
* Recipient adopts a higher term. A stale primary steps down before advancing `lastCommitted`
* In the picture: C/D send `UpdatePosition` with term 3 → A steps down. Term-2 entry is on a majority, but not committed. Later it can be rolled back (e)

Invariant they are restoring: Raft’s Leader Completeness.

To commit an entry in term *T*, the primary of *T* needs `UpdatePosition` with term T from a majority.  
A later primary of term *U > T* also needs a majority of votes. The two majorities share a voter:

* that voter sent `UpdatePosition` in *T* *before* voting → by log matching, the new leader already has the committed entry, or
* that voter voted first, then sent `UpdatePosition` with a term *> T* → the old primary stepped down and did not commit

Either way, a committed entry is on every later leader.

### A useful quirk, not a bug

A newly elected primary (or candidate) may keep pulling old-term entries after voting for itself, *until it appends its first new-term entry*.

Vanilla Raft would not do this: the new leader’s log is already “the” log. MongoDB uses the quirk for primary catchup (preserve uncommitted writes after failover).
