# Spanner: Distributed Transactions with two-phase locking and two-phase commit (2PL+2PC)

## ACID properties
* Atomicity: all or nothing
* Consistency: data is always in a valid state
* Isolation: concurrent transactions are isolated from each other, e.g., serializability
* Durability: data is always persisted through crash recovery

## How to ensure a serializable schedule?
  * Locking-based approach
  * Strawman solution 0: global lock
  * Strawman solution 1:
    * Fine-grained locks, grab locks on all items when transaction starts
    * release all locks when transaction finishes 
    * Problem: how do you know all items when transaction starts?
  * Strawman solution 2:
    * grab lock on item X before read/write X
    * release lock on item X after read/write X

## Problem with strawman 2?
* Permits this non-serializable interleaving
```
R_1(C), R_1(S), W_1(C), R_3(C), R_3(S), Commit3, W_1(S), Commit1
```
* Look at W_1(C), if lock on C is released, then another transaction T' can read new value of C, but T' must be able to read new value of S that T has not yet written yet.
* If write lock is not held, ---> read of uncommitted value 
* So, write lock must be held till the transaction commits

## (Extra question) How about read locks, must it also be held till transaction commits?
```
R_3(C), R_1(C), R_1(S), W_1(C), W_1(S), Commit1, R_3(S), Commit3
```
* This is a non-serializable schedule
  * R_3(C) reads old value
  * R_3(S) reads new value (non-repeatable reads)
* So, read locks must also be held till commit time


## 2-phase-locking (2PL)
* a growing phase in which transaction is acquiring locks
* a shrinking phase in which locks are released
* in practice
  * growing phase is the entire transaction
  * shrinking phase is during commit
* Optimization: use read/write locks instead of exclusive locks
* More on 2PL:
  * what is a lock is unavailable?
  * deadlock possible?
  * how to cope with deadlocks?
    * grab locks in order? not always possible
    * (central) system detects deadlock cycles and aborts involved transactions
    * deadlock prevention: give every transaction a timestamp when it starts; older = smaller = higher priority
      * wound-wait: T requests a lock that U holds
        * T older than U: T *wounds* U. U aborts, releases its locks, and restarts later *with its original timestamp*. T takes the lock
        * T younger than U: T waits
        * no deadlock: a transaction only ever waits for an older one, so wait-for edges all point toward older transactions and cannot form a cycle
        * no starvation: a wounded transaction keeps its timestamp, so it only gets older and eventually wounds everyone in its way
        * cost: aborts that a detector would not have needed. In practice a transaction that is already committing is not wounded
        * Spanner uses this for reads inside read-write transactions
      * wait-die: the mirror image. Older waits; younger aborts (dies) and retries with its old timestamp

## 2-phase-commit (2PC)
* lock without 2PC  
  * coordinator --> server-a: lock a, log a=1, write a=1 to database state, unlock a
  * coordinator --> server-b: lock b, log b=1, write b=1 to database state, unlock b
* Problem (failure to commit)
  * what if transaction cannot commit (e.g. deadlocks)
* Problem (failure):
  * coordinator crashes after message to a (before message to b).
* A later transaction T2 sees a=1, but the information about b=1 is permanently lost!
* Problem (serializability violation)
  * a's message to server A arrives
    read(a = 1)
    read(b = 0)
  * b's message to server B arrives
* 2PC (Two-phase commit)
  * coordinator --> server-a: prepare-T1: server-a lock a, logs a=1,
  * coordinator --> server-b: prepare-T1: server-b lock b, logs b=1
  * coordinator --> server-a: commit-T1: write a=1 to database state, unlock a
  * coordinator --> server-b: commit-T1: write b=1 to database state, unlock b
* Now if coordinator crashes after prepare-a before prepare-b, a recovery protocol should abort T1
  * (no other transactions can read a=1 since a is still locked)
* Now if coordinator crashes after commit-a before commit-b, a recovery protocol should send commit-T1 to b.
* How does the recovery protocol work? Two options:
  * Option 1:
	* Coordinator can unilaterially determine the commit status of a transaction
	* e.g. Coordinator receives prepare-ok(T1) from server-a, but times out on server-b,
	  * Coordinator can abort T1 (even if server-b has successfully prepared T1). 
	* Coordinator durably logs its decision (e.g. to a Paxos RSM).
	* Recovery protocol reads from coordinator's log to decide to commit or abort.
  * Option 2:
	* Coordinator can *not* unilaterially determine the commit status of a transaction
	* If both server-a and server-b successfully prepared T1, then T1 must commit
      * participants log must be durable against failure (e.g. log replicated via Paxos RSM)
	* Recovery protocol must read all participating server's log to decide commit or abort.

## TrueTime and read-only transactions
* TrueTime: `TT.now()` returns an interval `[earliest, latest]` guaranteed to contain true time
  * the interval is a few ms wide; `TT.after(t)` / `TT.before(t)` are shorthand for comparing against it
* Writers (read-write transactions) pay for it. The coordinator leader picks the commit timestamp `s` by three rules
  * `s ≥` every participant's prepare timestamp (each participant picked one above anything it assigned before, and logged it with its prepare record)
  * `s > TT.now().latest`, read when the coordinator received the commit request. So `s` is above any time at which the client could have been told "go"
  * `s >` any timestamp this leader assigned earlier, so a leader's timestamps are monotonic
    * across leaders of one group this holds too: leader leases are disjoint in time, and a new leader must not assign below the old lease
  * then *commit wait*: do not apply, release locks, or reply until `TT.after(s)`
    * so when anyone learns of a commit, true time is already past `s`. A transaction that starts afterwards gets a bigger `s` (external consistency)
  * non-coordinator participants' prepare timestamps obey rules 2 and 3 as well; the coordinator skips its own prepare
* Read-only transaction: no locks, no 2PC, never blocks a writer. Pick a timestamp, then read at it
  * pick `s_read = TT.now().latest` (one Paxos group: the leader's last committed timestamp works too and is smaller)
  * why it sees every earlier commit: a transaction that committed before this read started had true time pass its `s` first (commit wait), and `TT.now().latest ≥` true time, so `s < s_read`. No clock agreement between machines needed; each trusts only its own interval
  * why it is a stable snapshot: a replica serves the read only once its safe time `t_safe ≥ s_read`
    * `t_safe = min(` last Paxos write applied, smallest prepare timestamp of any prepared-but-uncommitted transaction minus one `)`
    * leaders hand out timestamps monotonically, so nothing can still commit at or below `t_safe`
  * cost: `TT.now().latest` is a little ahead of true time and `t_safe` a little behind it, so the read may wait briefly for `t_safe` to catch up. Any sufficiently caught-up replica can serve it, not just the leader
  * snapshot read: the same with a client-supplied timestamp

## Serializability: the correctness condition

Review from the [serializability notes](serializability.html), to connect the schedules above to a precise correctness test.

* A **serial schedule** runs one transaction at a time, with no interleaving.
* A **serializable schedule** may interleave transactions, but has the same effect on the database and the same results for each transaction as some serial execution.
  * Matching the final database state alone is insufficient: a read-only transaction might have observed an impossible intermediate state.
  * The equivalent serial order need not be the order in which transactions started.
* Running example: initially `C = 100`, `S = 100`.
  * `T1`: transfer $10 from checking (`C`) to savings (`S`).
  * `T2`: withdraw $20 from checking.
  * `T3`: read `C + S`.
  * With only `T1` and `T2`, either serial order ends at `C = 70`, `S = 110`.
  * With only `T1` and `T3`, either serial order makes `T3` return `200`.

## Conflict serializability and the serialization graph

* A schedule orders operations while preserving each transaction's own operation order. Below, `R_i(X)` and `W_i(X)` mean a read and a write of `X` by `Ti`; all transactions commit.
* Two operations **conflict** if they belong to different transactions, access the same item, and at least one is a write.
  * Read/write, write/read, and write/write conflict; read/read does not.
* Two schedules are **conflict equivalent** if they contain the same operations and preserve the order of every conflicting pair.
  * Swapping adjacent non-conflicting operations preserves conflict equivalence.
* Construct the **serialization graph** (also called the precedence graph):
  * One vertex per transaction.
  * Add `Ti → Tj` when an operation of `Ti` comes before a conflicting operation of `Tj`.
  * The edge means that any conflict-equivalent serial schedule must put `Ti` before `Tj`.
* A schedule is **conflict serializable if and only if this graph is acyclic**.
  * If acyclic, a topological ordering gives an equivalent serial order.
  * A cycle imposes contradictory ordering constraints.
  * This is a test for conflict serializability, a sufficient condition for serializability; it does not characterize every possible serializable schedule.

### Example 1: lost update

```text
R_1(C), R_1(S), R_2(C), W_2(C), Commit2, W_1(C), W_1(S), Commit1
```

* `R_1(C)` before `W_2(C)` gives `T1 → T2`.
* `R_2(C)` before `W_1(C)` gives `T2 → T1`.
* The graph has a cycle. Both transactions read `C = 100`; `T2` writes `80`, then `T1` overwrites it with `90`.
* Final state: `C = 90`, `S = 110`. The withdrawal is lost, unlike either serial order.

### Example 2: interleaved, but serializable

```text
R_1(C), R_1(S), R_3(C), R_3(S), Commit3, W_1(C), W_1(S), Commit1
```

* The only edge is `T3 → T1`: `T3` reads both items before `T1` writes them.
* The early reads of `T1` do not conflict with the reads of `T3`.
* Equivalent serial order: `T3`, then `T1`, even though `T1` started first.
* `T3` sees `100 + 100 = 200`.

### Example 3: the mixed snapshot from strawman 2

```text
R_1(C), R_1(S), W_1(C), R_3(C), R_3(S), Commit3, W_1(S), Commit1
```

* `W_1(C)` before `R_3(C)` gives `T1 → T3`.
* `R_3(S)` before `W_1(S)` gives `T3 → T1`.
* The cycle explains the anomaly: `T3` sees `90 + 100 = 190`, although either serial order would return `200`.
* The final database state is correct for the transfer; the read result is not.

## Why 2PL prevents these cycles

* A transaction's **lock point** is when it acquires its final lock.
* Suppose a conflict gives `Ti → Tj`. Their locks on that item are incompatible, so `Ti` must release its lock before `Tj` acquires its lock.
* Under 2PL, `Ti`'s lock point precedes that release; `Tj`'s lock point is at or after that acquisition.
* Every edge therefore points forward in lock-point order. A cycle is impossible.
* Basic 2PL forbids acquiring locks after releasing one; it does not require holding every lock until commit. Holding all read and write locks until commit/abort is the stronger **rigorous (strong strict) 2PL** used by the practical scheme above. It also prevents other transactions from reading or overwriting uncommitted writes. See [CMU's 2PL notes](https://15445.courses.cs.cmu.edu/spring2024/slides/17-twophaselocking.pdf).
* Do not confuse the serialization graph with the **wait-for graph** used for deadlock detection: the former records ordering of executed conflicting operations; the latter records transactions currently waiting for locks. 2PL prevents cycles in the former, but can still deadlock.

## From serializability to Spanner's external consistency

* **Strict serializability** adds a real-time requirement: if `T1` finishes committing before `T2` begins, the equivalent serial order must put `T1` before `T2`. Ordinary serializability alone does not impose that requirement.
* Spanner's 2PL controls conflicting read-write transactions; 2PC coordinates their commit decision across groups. Atomic commit alone does not ensure serializability.
* TrueTime and commit wait make Spanner's timestamp order respect that real-time requirement. Read-only transactions join this order by reading a consistent snapshot at their chosen timestamp. See the [Spanner paper, Section 4](https://research.google.com/archive/spanner-osdi2012.pdf).
* The graph examples above use a single-version model. For Spanner's multiversion reads, account for the version being read: a read that physically executes later can still read a version logically before a concurrent writer.
* An explicitly requested historical snapshot intentionally observes an earlier state; it is not a promise to include every commit completed before the read request.
