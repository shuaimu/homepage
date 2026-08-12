# GFS
## Goals (shared storage)
* capacity
  * e.g., 1000 servers, 300TB
* performance
* fault tolerance
  * map-reduce

## Approach
* filesystem-like API 
  * proprietary library (write/read/append)
  * not POSIX
* single master (metadata) 
  * (filename, offset) -> chunk 
* chunk size: 64MB. why not smaller, such as 4KB(hdd), 4MB (ssd)?
* 3-way replication 

## How GFS works
* client communicates with master to retrieve data locations 
* client buffers information locally
* client sends to data servers 

## Performance
* why single master and 64 MB sufficient?
  * workload: large files; sequential read/write
* not a good design if
  * small files (aggregate)
  * random accesses (buffer)

## Consistency
* correctness: outcome = expectation
  * concurrency
  * failures
* tradeoff
  * weak consistency: easier to implement, hard to use 
  * strong consistency: hard to implement, easy to use

## Case 1 (strawman, inconsistent with concurrency) 
```
S1: C1  C2
S2: C2  C1
```

## Case 2 (consistent with concurrency)
```
S1(P): C1 C2 C1-id C2-id      
S2   : C2 C1             S1-id-C1 S1-id-C2
```
## Case 3 (consistent but undefined)
 * a write operation breaks into many smaller write operations

## Case 4 (inconsistent with failures)
 * follower fails
 * primary fails 
 * two primary? (what about serial numbers?)
   * leases to avoid two masters 

## Case 5 (more consistency anomaly)
```
S1(P): C1 C2 C2-id C1-id C3-read
S2   : C2 C1                     S1-id-C2 C3-read S1-id-C1 C3-read
```

