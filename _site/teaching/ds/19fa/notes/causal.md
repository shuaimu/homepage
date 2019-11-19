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
* design #1
  * all operations have to be acknowledged by cloud
  * 
* design #2 
