
# COPS

## Background 
* System setup
  * Multiple data centers, separated by long distance links
  * Each data center has many nodes, storage state is fully replicated at each data center
* Desired performance:
  * Writes finish w/o waiting for remote sites (async. replication)
  * Reads contact local site only

## What's causal consistency?
* Systems that obey the following set of partial orders
  * 1. if op1 and op2 are in the single thread of execution and op1 is issued before op2, then op1 --> op2. (On client1, op1: creates pid1, op2: adds pid1 to album aid. All node s see the effect of op2 after op1) 
  * 2. If op2 reads the result written by op1, then op1--> op2 (On client1, op1: adds pid1 to album aid On client 2, op2: reads pid1 in album)
  * 3. if op1-->op2, op2-->op3, then op1-->op3   (On client 1, op1: adds pid1 to album aid On client 2, op2: reads pid1 in album, op3: deletes pid1. All nodes see op1--->op2--->op3, i.e. pid1 is deleted)

## COPS' approach  
* partition key-space among nodes 
* explicitly keep track explicit dependencies (partial orders) for each write
  * Site A performs a write, replicates it together with the dependencies to another site B
  * Site B waits until the write's dependencies are satisfied in B before committing the write.
  
## Client library  
* put(key,value,context); //put's dependencies are set by context, new dependency includes the new put version.  
* value = get(key,context);  //add dependencies of get to context
* example
```
Client 1:  put(x,1) ---> put(y,2)           
           ctx1:x1       store (x1) with y2, ctx=x1,y2
Client 2:                get(y)=2 --> put(x,4)                         
                         ctx2:x1,y2   store (y2) with x4, ctx2:x4,y2
Client 3:                             get(x)=4 --> put(z,5)                                      
                                      ctx3:x4,y2  store (x4,y2), ctx3:x4,y2,z5
```
* Site A replicate y2 with dependency (x1) to site B.
* Site B performs a dependency check locally to wait for x1 to commit before committing y2.

## Anomalies under causal consistency   
* -- write-write conflict  
* -- do not capture causality caused by external communication. I posted a picture, call my friend to check it out.

## Reasoning causal consistency
* example (consider the case with and without c3)
  ```
  x,y=0 initially
  c1: put(x)=1        get(y)=?
  c2:      put(y)=1
  c3:                         get(y)=1  get(x)=0
  
  ```

## Time to check to time to use
* example 1
```
Alice:               private ACL; upload photo
Bob:   read public ACL,                         read photo 
```
* example 2
```
Alice: private ACL; upload photo
Bob:                            read photo, read ACL 
```
* example 2
```
Alice: private ACL; upload photo; delete photo; public ACL
Bob:                                            read photo, read ACL 