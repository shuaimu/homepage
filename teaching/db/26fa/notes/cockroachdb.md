# MVCC and Snapshot Isolation — From Write Skew to CockroachDB

## 1. Classic Snapshot Isolation

### MVCC

- Keep multiple versions of each record, identified by timestamps.
- In the timestamp-based model below, committed versions carry their writer's **commit timestamp**, not its start timestamp.
- A read at timestamp `t` returns the newest committed version at or before `t`, provided the database has established a stable snapshot at `t`.

Example:

```text
Key   Version   Value
C     20        90
C      5       100
S     20       110
S      5       100

read(C, 10) = 100
read(C, 25) = 90
```

### Snapshot Isolation protocol

Use one increasing timestamp order for snapshot creation and commits. Snapshot creation must be coordinated with commit publication: an unfinished commit cannot later insert a version into an already established snapshot.

```text
BEGIN(T):
    T.start_ts = establish_snapshot()
    T.write_set = {}

READ(T, key):
    if key in T.write_set:
        return T.write_set[key]
    return latest_committed_version(key, <= T.start_ts)

WRITE(T, key, value):
    T.write_set[key] = value

COMMIT(T):
    atomically with snapshot creation and competing commits:
        T.commit_ts = get_timestamp()

        if any transaction committed after T.start_ts
           wrote a key in T.write_set:
            ABORT

        publish all writes at T.commit_ts
```

The atomic block includes timestamp assignment, the write-write conflict check, and publication. This is an abstract correctness requirement, not a requirement to use one global lock. A distributed implementation needs a protocol that provides equivalent snapshot visibility and atomic commit.

**Two guarantees:**

- All reads observe one consistent snapshot.
- Concurrent transactions cannot both successfully modify the same key.

**Notice:** There is no read-set validation.

### Can a write at timestamp 10 arrive after a read at 11?

Distinguish the writer's **start timestamp**, a **reserved commit timestamp**, and a **completed commit**.

If the writer starts at 9 and completes its commit at 10, a reader taking snapshot 11 must see that write, assuming no newer version at or before 11:

```text
Initially: C@1 = 100

Writer W                         Reader R
BEGIN: start_ts = 9
write C = 90
COMMIT: publish C@10 = 90
                                 BEGIN: snapshot = 11
                                 read C -> C@10 = 90
```

But merely obtaining the number 10 does not complete the commit:

```text
Writer W                         Reader R
BEGIN: start_ts = 9
reserve commit timestamp 10
  (still uncommitted)
                                 request snapshot 11
                                 read C -> can it return C@1?
later publish C@10 = 90
```

There are two implementation approaches:

- **Timestamp-defined snapshots:** If snapshot 11 is defined to include committed versions through 11, the database must resolve relevant unfinished commits and make their data available before returning reads that depend on them. If W commits at 10, R must see C@10; it may need to wait. It cannot return C@1 and later treat C@10 as part of the same snapshot.
- **Transaction-visibility snapshots:** The snapshot records which transactions were still in progress when it was taken. If W was uncommitted then, R may read C@1 and must continue to exclude W after W commits. In this approach, a timestamp or transaction-ID comparison alone does not determine visibility; the snapshot also needs transaction-status information.

The pseudocode above uses the first abstraction. The second approach can also implement SI, but its read rule must consult the saved visibility information. In either case, the snapshot is stable. SI reads committed data as of the snapshot, not whatever happens to be physically present when each read arrives. See [Berenson et al., section 4](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/02/tr-95-51.pdf) and [PostgreSQL's snapshot visibility rules](https://www.postgresql.org/docs/18/transaction-iso.html#XACT-REPEATABLE-READ).

## 2. Read Skew: Prevented by SI

Initial balances:

```text
C = 100, S = 100
Invariant: C + S = 200
```

T1 reports the total. T2 transfers $10 from C to S.

Without transaction-wide snapshots:

```text
T1: read C = 100
T2: write C = 90
T2: write S = 110
T2: COMMIT
T1: read S = 110
T1: report 210    <-- read skew
```

Under SI:

```text
T1: BEGIN @10
T1: read C@10 = 100
T2: COMMIT transfer @12
T1: read S@10 = 100
T1: report 200
```

Both records are read from the same logical database snapshot.

**Conclusion:** SI prevents read skew without locking the read records.

## 3. Write Skew: Allowed by SI

Initial state:

```text
C = 100, S = 100
Invariant: C + S >= 0
```

Two transactions independently attempt to withdraw $150, provided the current total is sufficient.

```text
T1 (start @10)             T2 (start @11)
-------------------        -------------------
read C=100, S=100
                           read C=100, S=100
write C=-50
                           write S=-50
COMMIT @12
                           COMMIT @13
```

Both succeed because:

```text
W(T1) = {C}
W(T2) = {S}

W(T1) ∩ W(T2) = ∅
```

Final state:

```text
C = -50
S = -50
Total = -100   <-- invariant violated
```

Serialization graph:

```text
T1 --rw--> T2  (T1 read old S)
T2 --rw--> T1  (T2 read old C)
```

The cycle proves the history is not serializable.

**Question:** How can we prevent this without adding long-lived read locks?

## 4. CockroachDB: Use One Serialization Timestamp

Classic SI above uses a fixed start snapshot and a separate, later commit timestamp. We now change the model: a transaction starts with a **provisional serialization timestamp** that it tries to use for both reads and writes. This timestamp is not evidence that it has already committed.

Start with a stronger rule:

- Assign each transaction a timestamp `t`.
- Read MVCC versions as of `t`.
- Write provisional MVCC versions at `t`.
- Arrange that every committed transaction is valid at its final timestamp.

If all conflicting operations respect that timestamp order, the transactions can be serialized in that order.

**Problem: operations arrive out of timestamp order.**

```text
T1 @10                      T2 @11
                            read C = 100
write C = -50 @10
```

T2 has already read C at timestamp 11. We cannot subsequently insert C's version at timestamp 10: doing so would invalidate T2's completed read.

Here T1's `@10` is its proposed serialization timestamp, not a completed SI commit at 10. The following patches enforce timestamp order while allowing that proposed timestamp to change.

## 5. Patch 1: Timestamp Cache

Each range leaseholder tracks the highest protected read timestamp for keys or key spans.

```text
Key    Highest read timestamp
C      11
S      11
```

A write cannot be placed at a timestamp at or below a conflicting protected read.

Instead, **push the writer's timestamp forward**.

```text
WRITE(T, key, value):
    if conflicting_read_ts(key) >= T.write_ts:
        T.write_ts = next_ts_after(conflicting_read_ts(key))

    create provisional version at T.write_ts
```

Writes also have to respect newer committed versions and conflicting write intents.

### Replay write skew with only Patch 1

```text
T1 @10                        T2 @11
------------------------      ------------------------
read C,S @10
                              read C,S @11
write C@10
  -> pushed to 12
commit C=-50 @12
                              write S@11
                              commit S=-50 @11
```

**Still wrong!**

T1 read S at timestamp 10, but committed at timestamp 12. It failed to observe T2's write to S at timestamp 11.

We have recreated SI's fundamental problem: **reads and writes are effectively at different timestamps**.

## 6. Patch 2: Read Refresh

Distinguish two transaction timestamps:

- `read_ts`: Timestamp of the previously read snapshot.
- `write_ts`: Proposed serialization timestamp, which may advance.

Initially:

```text
read_ts = write_ts
```

When the write timestamp advances, validate earlier reads.

```text
REFRESH(T):
    if T.read_ts == T.write_ts:
        return OK

    for each span in T.read_spans:
        if a conflicting version was written
           in (T.read_ts, T.write_ts]:
            return RETRY

    protect the reads at the new timestamp
    T.read_ts = T.write_ts
    return OK
```

This checks previously read keys and scanned ranges, including potential phantoms.

It is not necessary to rerun application logic if all the reads remain valid.

### Replay write skew with both patches

```text
T1 @10                        T2 @11
------------------------      ------------------------
read C,S @10
                              read C,S @11
write C@10
  -> pushed to 12

refresh {C,S} (10,12]
  -> succeeds
protect reads @12

commit C=-50 @12
                              write S@11
                                -> pushed to 13

                              refresh {C,S} (11,13]
                                -> C changed @12
                                -> FAIL; RETRY
```

On retry, T2 reads:

```text
C = -50
S = 100
Total = 50
```

It refuses the $150 withdrawal.

**The invariant is preserved.**

If T2's write had committed before T1 refreshed, T1's refresh would fail instead.

The important property is that **the two invalidating transactions cannot both commit**.

## 7. Why Is It Serializable?

Consider serialization graph dependencies.

**Write-read (wr):** If T reads a committed version from U, U must be ordered before T.

**Write-write (ww):** Conflicting writers are coordinated through intents and timestamp ordering. A late writer must advance past newer conflicting versions.

**Read-write (rw):** Two situations:

1. A write arrives after an earlier protected read: the timestamp cache pushes the writer forward.
2. A transaction advances its own timestamp past a write that invalidates an earlier read: read refresh fails.

Therefore, the protocol prevents committed dependency edges from pointing backward relative to the final serialization timestamp order.

All edges point forward, so the serialization graph is acyclic.

**That is the fundamental correctness argument.**
