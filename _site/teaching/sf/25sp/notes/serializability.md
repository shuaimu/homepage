# Serializable transactions

# Transactions groups a set of read/write operations together
* e.g.
```
begin_tx
v <-- read(checking)
v' <-- read(saving)
write(checking, v-10)
write(saving,v'+10)
commit_tx 
```
* Transactions Properties: ACID
  * Atomicity, Consistency, Isolation, Durability
* Two goals: 
  * 1. handle failure (A, D). A machine crash and later re-starts.
    * can be achieved by write-ahead-logging 
  * 2. handle concurrency (I): serializability

# Concurrency control 
```
T1:
transfer $10 from checking to saving

T2:
withdaw $20 from checking

T3:
read the sum of checking, saving

Bad interleaving
T1: Read(C)=100,             Read(S)              Write(C, 90), Write(S, 110)
T2:              Read(C)=100          Write(C, 80)
```
* What's the expected outcome?
  * Isolation: T1 happens either before or after T2 (sometimes called before-after atomicity)
* Ideal isolation semantics: serializability
* Definition: execution of a set of transactions is equivalent to some serial order
  * Two executions are *equivalent* if they have the same effect on database and produce the same output
  * typically, people mean strict serializability, i.e. the equivalent serial order cannot re-order commit-to-begin_tx ordering.

# (Conflict) serializability
* An execution schedule is an ordering of read/write/commit/abort operations (executed by the local system)
* e.g. 
```
R_1(C), R_2(C), R_1(S), W_2(C), Commit2, W_1(C), W_1(S), Commit1
```
* Two schedules are equivalent if they:
  * contain the same operations
  * order conflicting operations the same way:
* A pair of operations conflict if they access the same data item and one is a write.
* Examples:
```
Serializable? R_1(C), R_1(S), R_2(C), W_2(C), Commit2, W_1(C), W_1(S), Commit1
No
Serialiazable? R_1(C), R_1(S), R_3(C), R_3(S), Commit3, W_1(C), W_1(S), Commit1
equivalent to R_3(C), R_3(S), Commit3, R_1(C), R_1(S), W_1(C), W_1(S), Commit1
Serialiazable? R_1(C), R_1(S), W_1(C), R_3(C), R_3(S), Commit3, W_1(S), Commit1
no.
```
* How to check if a schedule is serializable?
  * Check if Serialization graph is cycle-free

