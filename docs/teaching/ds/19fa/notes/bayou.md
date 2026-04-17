# Eventual and causal consistency

## Weaker than linearizability 
* linearizability
  * ordering
  * C2I (global)
* pros and cons
  * easy to use
  * hard to implement, low performance, not available during network partitions.
* e.g. eventual consistency (generally):
  * accept write at any replica immediately
  * respond to read at any replica immediately
* anomalies
  * stale read
  * diverging write
  * loss of causality
* desired properties: 
  * eventual convergence of state 
  * preserving causality 
  
## A cloud album as an example
* mobile phones and cloud, album and photos 
  * operations: add album, upload photo to album, delete photo, get photo
* design #1: all operations have to be acknowledged by cloud
  * strong consistency, no anomalies
  * potentially bad user experience, long latency, freezes when connections are bad
* design #2: each device acts as a storage server 
  * a device caches photos/albums and modifies its local copy; read from local copy. 
  * data is available despite periodic connectivity to cloud and other nodes.
  * consistency issues if two devices have conflicting operations.
  
## Straw man 1: merge storage 
* write-write conflict, e.g., add two photos to the same album the same time
* automatic conflict resolution
  * idea update functions: have update be a function, not a new value.
* e.g. add photo pid to album w/ aid.
  * read current state of storage, decide best change
* function must be deterministic
  * otherwise nodes will get different answers
* Challenge:
```
A: add pid1 to album w/ aid 
B: add pid2 to album w/ aid
```
  * X syncs w/ A, then B  Y syncs w/ B, then A  Will X show pid1 in front of pid2, and Y show pid2 in front of pid1?  
  * If update function is commutative (e.g. album is an *unordered* set of photos), then it dos not matter.

## Goal: eventual state convergence 
* Idea: ordered update log
  * Ordered list of updates at each node
  * Storage state is result of applying updates in order
  * Syncing == ensure all nodes have same updates in log
* How can nodes agree on update order?
  * Update ID: <time T, node ID>
  * Assigned by node that creates the update 
  * Ordering updates a and b: 
    * a < b if a.T < b.T or (a.T = b.T and a.ID < b.ID)
* Example: 
```
<10,A>: add pid1 to album aid 
<20,B>: add pid2 to album aid 
```
  * What's the final ordered list in aid? 
    * the result of executing update functions in timestamp order
    * [..pid1, pid2] (not [..pid2, pid1])
* What's the status before any syncs?  i.e. content of each node's storage state  
  * A: pid1 at 3rd position for album aid
  * B: pid2 at 3rd position for album aid
  * This is what A/B user will see before syncing. 
* Now A and B sync with each other 
  * Both now know the full set of updates 
  * Can each just run the new update function against its storage state?
    * A: pid1 at 3rd position, pid2 at 4th position    
    * B: pid2 at 3rd position, pid1 at 3rd position  
  * That's not the right answer!
* Roll back and replay  
  * Naive way: Re-run all update functions, starting from empty storage state  
  * Since A and B have same ordered set of updates
    * they will arrive at same final state  
  * We will optimize this in a bit
* Displayed photo positions are "tentative"
  * B's user saw a photo pid2 at 3rd position, then it's changed to 4th position  
  * You never know if there's some other photo from nodes you haven't yet synced
    * That will change the pid1's position yet again
* Will update order be consistent with wall-clock time?
  * Maybe A went first (in wall-clock time) with timestamp <10,A>  
  * Node clocks are not perfectly synchronized  
  * So B could then generates <9,B>  
  * B's meeting gets priority, even though A asked first
* Will update order be consistent with causality?  
  * What if A adds a photo pid1,     
    * then B sees it, 
    * then B deletes pid1  
  * Perhaps    
    * <10,A> add    
    * <9,B> delete -- B's clock is slow  
  * Now delete will be ordered before add!    
    * Unlikely to work    
    * Differs from wall-clock time case b/c system *knew* B had seen the add
      
# Lamport logical clocks  
* Want to timestamp events s.t.    
  * node observes E1, then generates E2, TS(E2) > TS(E1)  
* Thus other nodes will order E1 and E2 the same way.  
* Each node keeps a clock T   
  * increments T as real time passes, one second per second    
  * T = max(T, T'+1) if sees T' from another node  
* Note properties:    
  * E1 then E2 on same node => TS(E1) < TS(E2)    
  * BUT it's a partial order    
  * TS(E1) < TS(E2) does not imply E1 came before E2
* Logical clock solves add/delete causality example  
  * When B sees <10,A>,    
    * B will set its clock to 11, so    
    * B will generate <11,B> for its delete
* Irritating that there could always be a long-delayed update with lower TS  
  * That can cause the results of my update to change  
  * Would be nice if updates were eventually "stable"    
    * => no changes in update order up to that point    
    * => results can never again change -- e.g. you know for sure pid1 is at position 3.    
    * => no need to re-run update function
* How about a fully decentralized "commit" scheme?  
  * You want to know if update <10,A> is stable  
  * Have sync always send in log order -- "prefix property"  
  * If you have seen updates w/ TS > 10 from *every* node    
    * Then you'll never again see one < <10,A>    
    * So <10,A> is stable  
  * Why doesn't Bayou do something like this? (Bayou commits updates through designated primary replica)
* How to sync?  
  * A sending to B  
  * Need a quick way for B to tell A what to send  
  * A has:    
    * <-,10,X>    
    * <-,20,Y>    
    * <-,30,X>    
    * <-,40,X>  
  * B has:    
    * <-,10,X>    
    * <-,20,Y>    
    * <-,30,X>  
  * At start of sync, B tells A "X 30, Y 20"    
    * Sync prefix property means B has all X updates before 30, all Y before 20  
  * A sends all X's updates after <-,30,X>, all Y's updates after <-,20,X>, &c  
  * This is a version vector -- it summarize log content   
    * It's the "F" vector in Figure 4    
    * A's F: [X:40,Y:20]    
    * B's F: [X:30,Y:20]
* How did all this work out?  
  * Replicas, write any copy, and sync are good ideas    
    * Now used by both user apps *and* multi-site storage systems  
  * Requirement for p2p interaction is debatable
    * clients (phones, ipads) can just (sporadically) contact the servers  
  * Bayou introduced some very influential design ideas    
    * Update functions    
    * Ordered update log     
    * Allowed general purpose conflict resolution  
  * Bayou made good use of existing ideas    
    * Logical clock
