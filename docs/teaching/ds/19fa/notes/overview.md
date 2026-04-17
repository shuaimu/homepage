

# Course introduction

## Class stuff and office hour

* Lecturer: Shuai Mu shuai@cs.stonybrook.edu
* Office hour: W 2:00-4:00pm (appointment recommended)
* TA TBD

## Prerequisites

* Familiar with OS & networking
* System-level programming experience 
* Comfortable with concurrency and threading

## Polling of PhD and Master 

## Course readings

* Lectures are based on research papers
* Check webpage for schedules
* Lectures assume you have read the assigned papers
* No textbook

## Important website

* class schedule
* piazza 

## How are you evaluated?

* Labs 50% 
 * You must work alone on all assignments.
 * A single deadline: Dec 1
 * Late policy: 10% off per day  
* Final exam 50%
* Grading
 * A: achieve > 85% in score, or ranking top 20% 
 * B+: score > 80%, or ranking 35% 
 * B: score > 75%, or ranking 50% 
 * B-: score > 70%, or ranking 75% 
 * C: score > 60%, or ranking 90%
 * F: achieve < 30%, or ranking bottom 10% 
 * No A-, C+, C-

 
## Integrity policies 

* The work that you turn in must be yours.
* You must acknowledge your influences.
* You must not look at, or use, solutions from prior years or the Web, or seek assistance from the Internet.
* You must take reasonable steps to protect your work.
* You must not publish your solutions.
* If there are inexplicable discrepancies between exam and lab performance, we will over-weight the exam and interview you.

## Penalty
* Violate policy -> F (and report to department) 
* Attempt to negotiate on grading -> 10% off per each attempt 


## What are distributed systems?

* Machines communicate to provide some service for applications
* Multiple hosts
* A local or wide area network

## Why distributed systems?

* ease-of-use (web, NFS)
* availability/reliability (hardware/software failures)
* scalable capacity (CPU, memory, storage)
* modular functionality (authentication service)

## Downside
* A distributed system is a system in which I can’t do my work because some computer that I’ve never even heard of has failed.” -- Leslie Lamport

## Main challenges/topics in distributed systems

* Abstraction/Interface
 * different system requirements: file system/database/disk 
 * simple, flexible, implementation-friendly
* System architecture
 * data center / wide area
 * client-server / peer-to-peer
* Fault Tolerance
 * backup/replication
 * backup fail-over 
* Consistency
 * keep replicas identical
 * keep replicas non-identical
* Performance
 * throughput (parallelism/divide load)
 * latency (queuing, minimize critical path)
