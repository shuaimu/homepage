# Two Phase Locking with two-phase commit (2PL+2PC)
## How to ensure a serializable schedule?
  * Locking-based approach
  * Strawman solution 1:
    * Grab global lock when transaction starts
    * release global lock when transaction finishes committing
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
R_3(C), R_1(C), R_1(S), W_1(S), W_1(S), Commit1, R_3(S), Commit3
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
    * deadlock prevention 
      * wound-wait
      * wait-die 

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
