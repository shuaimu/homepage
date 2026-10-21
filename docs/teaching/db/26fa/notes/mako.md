
# Speculative 2PC (Mako)
Paper: *Mako: Speculative Distributed Transactions with Geo-Replication* (OSDI 2025)

## Setting
* sharded key-value store, serializable transactions
* each shard is a Paxos group: leader + followers in other datacenters
* shard leaders are (usually) in the same datacenter
  * leader to leader: LAN, fast
  * leader to follower: WAN, tens of ms
* one-shot transactions: client sends the whole transaction to a shard leader
* running example: shard A holds `Alice.bal`, shard B holds `Bob.bal`, shard C holds `Charlie.bal`
```
T1: Alice transfers 100 to Bob
  if Alice.bal > 100:
    Alice.bal -= 100        (shard A)
    Bob.bal += 100          (shard B)
```

## What is slow in Spanner?
* every 2PC step (prepare, commit) is replicated via Paxos before the next step
  * A and B each replicate their YES before answering; each replicates COMMIT before applying
* T1 holds its locks across two WAN round trips. the next transaction on Alice or Bob waits
* can we hide it with more concurrent transactions? no
  * more concurrent transactions --> more conflicts --> more aborts/waits
  * throughput is limited by contention, not by the number of in-flight requests

## Idea: run 2PC first, replicate later
* execute + 2PC among leaders only (LAN). no replication inside
* once 2PC passes, writes are visible to the next transaction. keep going
* replicate in the background
* reply to the client only after replication finishes
* a transaction that passed 2PC but is not replicated yet: *certified* (speculative)

## Problem: a leader fails before replication
* T1 runs 2PC: A votes YES, B votes YES, coordinator sends COMMIT. A applies it. then A's leader dies
* its memory is gone: data, locks, and its part of every 2PC
* B: did A commit? abort? nobody knows. 2PC is not fault-tolerant
  * Spanner avoids this by replicating the vote before casting it. we just gave that up
* the client has not been answered yet, so we are allowed to roll T1 back on B. fine, if it stopped there. it does not
```
A: Alice.bal 100 -> 0        T1
B: Bob.bal     0 -> 100      T1
B: Bob.bal   100 -> 0        T2: Bob spends the 100 (read T1's write)
```
* T2 read T1's write before T1 was replicated. that was the point: don't wait
* T1 rolls back --> Bob never received 100 --> T2 spent money that never existed --> T2 rolls back
* and whatever read T2's writes, and so on. cascading rollback
* same problem on followers: T1's B half may be replicated while its A half is lost. replaying half of T1 is wrong

## Strawmen
* track exact dependencies ("T2 read from T1"): precise, but a record per read at millions of reads/s. too slow
* on failure, freeze the whole system, find what is lost, roll back it and its dependents: one dead server halts all shards

## What do we actually need on failure?
* not "who read from whom"
* just a *cut*: keep a set of transactions such that
  * every kept transaction is replicated on all shards it wrote
  * everything a kept transaction read from is also kept
* roll back everything above the cut. nothing below can be affected
* so we need a cheap per-transaction summary that is *monotone*: T2 reads from T1 ==> summary(T2) >= summary(T1)
  * then "keep everything with summary <= W" is a valid cut, for any W
* simplest summary: a timestamp

## Version = timestamp
* each shard has a logical clock (Lamport style: bump on every use, jump forward on seeing a larger timestamp)
* a transaction's timestamp: fresh clock from every shard it writes, max with the timestamps of everything it read
* invariant: T2 reads from T1 ==> ts(T2) >= ts(T1) (and transitively)
* on one shard, a later writer gets a larger timestamp than an earlier writer
```
T1  W(Alice) W(Bob)     reads {}          ts 1
T2  R(Bob) W(Bob)       reads Bob: ts 1   ts 2
T3  W(Charlie)          reads {}          ts 1
```

## Execution and certification (= OCC + 2PC among leaders)
* coordinator = the shard leader that received the transaction
* execute: read newest *certified* version, record (key, version) in ReadSet. buffer writes in WriteSet
* certify, 4 rounds among involved leaders:
  1. Lock: lock WriteSet keys. already locked --> abort
  2. GetClock: each written shard bumps its clock and returns it. ts = max(fresh clocks, ReadSet timestamps)
  3. Validate: every ReadSet key still at the version we read, and unlocked? else abort
  4. Install: write WriteSet with version ts. keep old versions (may need to roll back)
* step 2 is where the invariant comes from: T1's timestamp sits in T2's ReadSet
* Validate/Install = prepare/commit. now CERTIFIED. no WAN traffic so far

## Replication and the watermark
* each shard appends (writes on this shard, ts) to a log, replicated with Paxos in the background
  * actually one log per core, no coordination between logs or shards
* shard watermark w_i = timestamp of the last replicated transaction, min over shard i's logs
  * meaning: every transaction with ts <= w_i is durable on shard i
```
shard A, two logs       replicated | pending
log-0:  1 3 4 | 8 9      w_A = min(4, 6) = 4
log-1:  2 5 6 | 7        (6 might be unreplicated in log-0, so not 6)
```
* system watermark W = min over all shards of w_i, gossiped between shards
* commit rule: ts <= W --> COMMITTED, reply to client
  * own writes durable on every shard (ts <= w_i for all i)
  * everything it read from has a smaller ts, so also <= W, so also durable
* followers replay a log entry only when its ts <= W. otherwise wait
  * T1's A half lost --> w_A stays 0 --> W stays 0 --> B's follower never replays T1's B half, nor T2

## Failure: epochs
* why epochs: every shard must separate "before the failure" from "after"
  * Otherwise, the system pauses for long
* every shard *closes* the old epoch
  * healthy shard: finish or abort its in-flight old-epoch transactions, then move on
  * new leader of the failed shard: recover from followers what was replicated, fill holes with no-ops
  * new-epoch transactions do not read old-epoch versions until the old epoch is decided
* Rollback safety: roll back the whole old epoch on every shard
  * key: an old-epoch transaction read only from the old epoch or earlier; it does not depend on any new-epoch transactions
  * Simple solution: Should we rollback the entire epoch?
```
old epoch:  T1 (A, B)   T2 (B)   T3: Charlie.bal -= 100 (C)   ... thousands more
A fails --> roll back T1, T2, T3, and everything else in the old epoch
```
* too much: transactions that were fully replicated before the failure die too. and T3 had nothing to do with A

## Failure: cut the old epoch at the watermark
* we already have a cut, the watermark. finalize it for the old epoch
  * new leader of the failed shard: final w_i = min over its recovered logs, as usual
  * healthy shard: append an INF marker to each log and replicate it. final w_i = INF (it lost nothing)
* finalized watermark FW = min over shards of the final w_i
* rule: old-epoch transaction with ts <= FW commits. otherwise roll back on leaders, never replay on followers
```
A failed before T1 reached its followers.  w_A = 0, w_B = INF, w_C = INF.  FW = 0
T1  ts 1   roll back, even though its B half is durable on B
T2  ts 2   roll back
T3  ts 1   roll back.  Charlie had nothing to do with A
had A replicated up to ts 7 before dying: FW = 7, everything with ts <= 7 survives
```
* why not re-apply T1 from B's copy of its write? B's copy may depend on other lost transactions. we don't know, that was the deal
* bounded: the set above FW is fixed once FW is. no cascade into the new epoch
* healthy shards keep running new-epoch transactions that avoid the dead shard

## Why correct
* atomicity: all writes of a transaction carry the same ts, and the decision is "ts <= FW?", so every shard decides the same
  * a transaction stuck mid-2PC has a timestamp above its log's last entry, so above FW: rolled back everywhere
* rollback safety: T2 read from T1, T1 rolled back ==> ts(T2) >= ts(T1) > FW ==> T2 rolled back
* never undo a reply: replied ==> ts <= W <= FW

## Problem with one timestamp: too many rollbacks
* the watermark saved the replicated prefix, but T3 still died for nothing. in a big system most transactions are unrelated to the failed shard
* same thing without failures: W = min over *all* shards. one slow shard holds W back, so every shard's transactions wait to commit
* the timestamp is too coarse: it says "after", not "after *on which shard*"

## Fix: vector clock
* one entry per shard: vc = [v_A, v_B, v_C]
* same rule, per entry: fresh clock from every shard it writes, element-wise max with the vcs of everything it read
* same invariant, per entry: T2 reads from T1 ==> vc(T2) >= vc(T1) in every entry
* watermark becomes a vector W = [w_A, w_B, w_C]; commit rule: vc <= W in every entry
* unrelated transactions are *incomparable* and do not wait for each other
```
T1  W(Alice) W(Bob)     fresh (1,1,-)   vc [1,1,0]
T2  R(Bob) W(Bob)       fresh (-,2,-)   vc [1,2,0]     >= [1,1,0]
T3  W(Charlie)          fresh (-,-,1)   vc [0,0,1]     incomparable with both

A failed.  FVW = [0, INF, INF]
T3 [0,0,1] <= FVW   keep.  Charlie is fine
T1 [1,1,0]          roll back
T2 [1,2,0]          roll back
```
* straggler: a slow shard holds back only its own entry. transactions that do not touch it commit as before
* correctness argument is unchanged: replace <= on numbers with <= on every entry
* cost: n entries per version. with many shards, merge entries (max of a group of shards). still monotone, so still correct; the fully merged case is the single timestamp above

## Trade-offs
* throughput: no lock held across the WAN. 8.6x over geo-replicated baselines
* latency: still one WAN replication before the client hears back
* rollback is still coarse: a healthy-shard transaction with a large entry for the failed shard dies even if what it read happened to be durable
* speculative state is visible only inside the system. clients only ever see COMMITTED results
