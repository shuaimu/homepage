

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

* Snapshot isolation
  * read skew, not possible with si
    * r1[x]...w2[x]...w2[y]...c2...r1[y]...(c1 or a1)
  * write skew, possible with si
    * r1[x]...r2[y]...w1[y]...w2[x]...(c1 and c2 occur) 
  * stronger than read committed
  * stronger than "anomaly serializable".
  * revisit the long fork example: read skew
  ```
  T1: R(A)=0, R(B)=0, W(A)=1 
  T2:                        R(A)=1, R(B)=0
  T3: R(A)=0, R(B)=0, W(B)=1 
  T4:                        R(A)=0, R(B)=1
  T5:                                       R(A)=1, R(B)=1
  ```
  
# Graph 
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
    
