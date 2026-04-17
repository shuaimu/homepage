

## Optimistic concurrency control (OCC)
```
T1:
Begin_tx
v<-R(C)  # remember read version c#=1
v'<-R(S) # remember read version s#=1
write v-10 to C (in T1's write-buffer)
write v'+10 to S (in T1's write-buffer)
Commit_tx
Lock(C)
Lock(S)
validate C# still 1
validate S# still 1
write (C=90), version 2
write (S=110), version 2
unlock(C)
unlock(S)
```
* Note: OCC has no deadlock problem

# Snapshot isolation

## Overview
* A transaction
  * reads a "snapshot" of database image
  * can commit only if there are no write-write conflict
* protocol:
```
 begin_tx : T is assigned a start timestamp T.sts
 Read: T reads the biggest version i such that i < = T.sts
 Write: buffers writes, T.wset += {C}
 commit_tx: T is assigned a commit timestamp T.cts
            checks for all T' such that T'.cts \in [T.sts, T.cts] whether T'.wset and T.wset overlaps
            write item with version T.cts
```

## Recall our earlier bad interleaving: 
```
T1: Read(C) Read(S) Write(C, 90)                Write(S, 110)
T3:                              Read(C) Read(S)

T3 reads old value of C and S (due to T3.sts < T1.cts)
```


## Does snapshot isolation implement serializability? No
* The write-skew problem
```
R_1(A), R_2(B), W_1(B), W_2(A), C_1(A), C_2(B)
```
* non-serializable interleaving but, possible under SI
