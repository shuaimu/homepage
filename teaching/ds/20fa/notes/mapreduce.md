# MapReduce

## Google Infrastructure
* GFS : Storage
* MapReduce: Computation
* Chubby: Coordination 

## Why Distributed? (in 2003)
* Storage 
 * HDD 1TB
 * Google > 100 billion pages, about 1PB 
 * need > 1000 machines 
* Computation
 * 100 MB/s, ~100 day to process 1PB  

## The world before MapReduce
* Systems community
 * Distributed = Multi-thread 
 * Distributed shared memory
* HPC community
 * MPI
* Fault tolerance?

## What about doing it in the hard way?
* send-recv
* coordination 
* debug
* optimize 
* fault tolerance

## MapReduce
* Programming framework/model 
* input/output on GFS
* no persistence 
* online tasks
* as a service (process) or as a library?
* auto parallelism, load balance, fault tolerance. 

## Concept
* input->map->reduce->output
* input: a set of kv pairs
* map (UDF): kv pair -> a set of kv pairs 
* reduce (UDF): a set of kv pairs -> kv pair 

## Example: word count
* input k: doc-name, v: doc-content
* map: k: each word, v: 1  
* reduce: k: each word, v: word count 

## More examples:
* grep
* reversed links
* sorting (requires extra)

## Distributed implementation
* Input (in GFS) ---> (M) Map jobs ---> (R) Reduce jobs ---> Output (in GFS) 
* Map workers and Reduce workers communicate in network (RPC)
  * why not using external storage same as input/output? 
* A master that assigns jobs to workers 
* UDF partition
* Linked as library
  * C++
  * debug locally
  * bootstrap time?

## Load balancing and pipelining example
* M=3, R=2 
* flow 
```
  W1: m1-----m1 m3------m3
  W2: m2--------------------m2
  W3: ..........1.1.......1.3..1.2 r1---r1
  W4: ...........2.1.......2.3...2.2 r2---r2
```

## Fault tolerance 
* Failure types: networks, server crashes, disk corruption, "gray" failures
* Master(seldom)
* Workers
 * Map: relaunch
 * Reduce: relaunch, atomic GFS functions
* Slow worker = failed worker

## Performance opt
* What is the "scarce" resource?
  * network
* Optimization to reduce network traffic
  * Combine: local reduce (commutative/associative)
  * Locality read

