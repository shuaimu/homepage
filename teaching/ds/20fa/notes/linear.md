# Distributed consistency

## Distributed consistency  
* usually describes behaviors of multiple copies of data
  * example, replicated chunks/log entries (GFS, Raft), CPU caches
* challenges
  * concurrency
  * failures
* systems
  * abstract data types 
  * key-value store (memory, registers)
* not defined by states, but by operations, example
  ```
  initially x=0, y=0
  c1: put(x, 1) put(y, 1)
  c2: get(y)=? get(x)=?
  ```  

## Consistency as a "contract" 
* clients' expectation
  * knowing the system's behavior without examining the system design
* what would a good contract?
  * stronger, hard to implement, easy to use 
  * weaker, easy to implement, hard to use  

## Linearizability
* definition
  * equivalent sequential order, one-copy data 
  * the order matches the global completion-to-issuing (C2I) order 
    * why not C2C or I2I? 
* linearizability is the strongest consistency in practice?
* linearizability is a "local" property
  * putting different linearizable systems together? still linearizable
  * proof strategy: order and C2I 

## Sequential consistency 
* definition
  * order
  * per-client C2I
* usage: closer to today's multi-core memory system
* example (consider the case with and without c3)
  ```
  x,y=0 initially
  c1: put(x)=1        get(y)=?
  c2:      put(y)=1
  c3:                         get(y)=1  get(x)=0
  
  ```
