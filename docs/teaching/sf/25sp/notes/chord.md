# P2P and DHT 

## Peer-to-peer
* Practical distributed systems in early 2000s
  * eMule 2000, BitTorrent 2001
* BitTorrent
  * tracker servers exchange info "who has the file"
  * client contact tracker to contact the file owners 
  * after finish, the client report to tracker as an owner
  * centralized bottleneck: some servers are more important than others.
  
## Consistent hashing
* deterministic hashing function 
  * uniform distribution 
  * choose m-bit in results so that the collision rate is low 
  * each key is hashed to m bits
  * each server (ip, port) is also hashed to m bits 
* a ring connects 0 and 2^m-1
  * a key (its hash) is stored on the succeeding server
  * if every node has the membership info, then it can route the request to the right node with one hop 
* on membership change
  * if a node joins, it takes over some keys from its immediate successor 
  * if a node leaves, it gives all its keys to its immediate successor.
* what about failures? 
  * use replicas: for a key who hash is k, use k + F, k + 2F as extra replicas (F is a constant) 
* if everyone has the membership, this is it
  * Dynamo is implemented like this
  * reasonable for a moderate sized system with closed membership 
    * what about a million nodes? 
    * what about more open network?

## Chord, a scalable lookup service   
* no node stores the full membership 
* the minimum: a node only stores its predecessor and successor 
  * with N nodes, search O(N) times. 
* Idea: store multiple "fingers" on the ring, look up similar a binary search 
  * how can we distribute the fingers? 
* store m fingers, divided by increasing index of 2 
  * e.g.,  m=3, every node (node 0, 1, 3) store three fingers
    * node 0: 1, 2, 4
    * node 1: 2, 3, 5 
    * node 3: 4, 5, 7 
  * every finger has the successor and interval (range to next finger)
* search rule for k 
  * if find a match (the immediate successor is the one), return
  * else, find the interval that includes k, forward the search to that successor, and repeat 
* each forward will halve the search range, hence seach time is O(logN)
  * search node: n, i-th finger node: f, succ node: p
  * distance between n and f >= 2^(i-1)
  * distance between f and p <= 2^(i-1)
  * f to p is at most half of n to p 
* membership change (join), base version
  * init finger table
    * delegate to exisiting nodes
    * quicker to ask a neighbor  
  * update fingers of other nodes
  * transfer keys 
* dynamic stablization
  * a new node joins: notify immediate successor   
  * exisiting node calibrates: ask the immediate successor about its predecessor
