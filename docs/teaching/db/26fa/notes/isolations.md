

# Locking-based isolations levels
* serializable
  * 2PL (long-duration read/write locks) 
* repeatable read
  * long w/r locks, short predicate read locks 
  * could have phantom read
    * r1[P]...w2[y in P]...c2...r1[P]...c1 
* read committed
  * long w locks, short r locks
  * could have non-repeatable (fuzzy) read
    * r1[x]...w2[x]...c2...r1[x]...c1
* read uncommitted
  * long write locks, no read locks. 
  * could have dirty read
    * w1[x]...r2[x]...(a1 and c2 in any order)

# ANSI 
* English version
  * read committed cannot have dirty read
  * repeatable read cannot have dirty/fuzzy read
  * serializability cannot have any of: dirty/fuzzy/phantom read 
* Simply forbidding dirty/fuzzy/phantom read does not give you serializability, or, "anomaly serializable != serializable"
  * H1: r1[x=50]w1[x=10]r2[x=10]r2[y=50]c2 r1[y=50]w1[y=90]c1
  * H2: r1[x=50]r2[x=50]w2[x=10]r2[y=50]w2[y=90]c2r1[y=90]c1
  * H3: r1[P] w2[insert y to P] r2[z] w2[z] c2 r1[z] c10

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
r1[C] r1[S] w1[C=90] r3[C] r3[S] w1[S=110]

T3 reads old value of C and S (due to T3.sts < T1.cts)
```


## Does snapshot isolation implement serializability? No
* read skew, not possible with si
  * r1[x]...w2[x]...w2[y]...c2...r1[y]...(c1 or a1)
* write skew, possible with si
  * r1[x]...r2[y]...w1[y]...w2[x]...(c1 and c2 occur) 
* stronger than read committed
* stronger than "anomaly serializable".
* revisit the long fork example: read skew
```
T1: r1[A=0] r1[B=0] w1[A=1]
T2:                         r2[A=1] r2[B=0]
T3: r3[A=0] r3[B=0] w3[B=1]
T4:                         r4[A=0] r4[B=1]
T5:                                         r5[A=1] r5[B=1]
```
  
# Serialization Graph 
* How to check if a schedule is serializable?
  * Check if Serialization graph is cycle-free

* Examples:
```
Serializable? r1[C] r1[S] r2[C] w2[C] c2 w1[C] w1[S] c1
No
Serializable? r1[C] r1[S] r3[C] r3[S] c3 w1[C] w1[S] c1
equivalent to r3[C] r3[S] c3 r1[C] r1[S] w1[C] w1[S] c1
Serializable? r1[C] r1[S] w1[C] r3[C] r3[S] c3 w1[S] c1
no.
```
# Serialization graph for weaker isolation levels
* Read uncommitted 
  * disallows cycles consisting only of ww edges
    * ww implies commit-start order because of long write locks.
* Read committed/repeatable read
  * disallow cycles consisting of ww or wr edges
* Snapshot isolation, disallows:
  * wr or ww without commit-start
  * cycles consisting of only commit-start, wr, ww edges
    * wr or ww implies commit-start
  * cycles containing a single rw edge
    * rw imples either commit-start or concurrent 
    
