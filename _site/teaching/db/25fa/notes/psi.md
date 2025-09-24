# Parallel Snapshot Isolation

## Design
* each data item has a preferred site
* use per site timestamp <site, seqno>
  * vector timestamp <seqno1, seqno2, ...>
  * each site maintains a vector timestamp indicating remote sites GotVTS
* Tx protocol
  * get a startVTS, which has the highest seqno for each site
  * read local version that is "visible".
    * data with version <site, seqno>: seqno < startVTS[site] 
  * write buffered at local write-set
  * commit, use 2PC:
    * prepare phase, send to all preferred sites of objects in the write-set
      * if modified (has newer version), reply no 
      * if being locked, reply no
      * otherwise, lock the data and reply yes
    * commit phase
      * assign a sequence number, apply changes locally
      * then propagate changes in the background
  * fast commit:
    * if all preferred sites are local, then no geo coordination needed 
  * on propagation
    * the preferred site can release locks 
    * wait until GotVTS >= startVTS, and GotVTS[site] = seq-1
    
## Anomalies analysis
  * not possible for either SI or PSI
    * dirty read: non-committed value
    * non-repeatable read: read different values for the same object
    * lost updates: concurrent writes become "lost"
  * possible for both SI and PSI
    * short fork
    ```
    T1: Read(A)=0, Read(B)=0, Write(A)=1 
    T2: Read(A)=0, Read(B)=0, Write(B)=1 
    T3:                                  Read(A)=1, Read(B)=1
    ```
  * not possible for SI, but possible for PSI
    * long fork
    ```
    T1: R(A)=0, R(B)=0, W(A)=1 
    T2:                    R(A)=1, R(B)=0
    T3: R(A)=0, R(B)=0, W(B)=1 
    T4:                    R(A)=0, R(B)=1
    T5:                                  R(A)=1, R(B)=1
    ```
