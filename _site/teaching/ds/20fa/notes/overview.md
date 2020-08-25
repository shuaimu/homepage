

# Course introduction

## Class stuff and office hour

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

* Labs 70 points
  * You must work alone on all assignments.
  * A single deadline: Nov 1
  * A bonus lab that can pump your score to 80 (B+)  
  * Late policy: 10 off per day, at most 60 (after 6 days)
* A bonus project 30 points
  * optional only if you finish at least lab3 by Oct 1  
  * you can group or you can do it individually, but the bonus points will be distributed evenly among you  
  * I will release a few candidate projects which you can choose from
  * You can also propose your own, but it has to be releated to distributed systems research and has to go through me first.
    * warning: a randomly pitched idea (e.g., let me show you what I did in my intern / past work / another class) will not be accepted. 
  * You will likely receive 0, 10, 20, 30 bonus points depending on your implementation and presentation. 
* Grading standard
  * A: achieve > 90 in score 
  * A-: achieve > 80 in score, or ranking 10% 
  * B+: score > 70, or ranking 30% 
  * B: score > 60, or ranking 50% 
  * B-: score > 50, or ranking 70% 
  * C+: score > 40, or ranking 90%
  * C: score > 20, or ranking 95%
  * F: score <= 20 and last 5%
* Other bonus 
  * reporting a technical error I made gives you 2%, up to 20%
  * reporting a non-technical error I made gives you 0.5%, up to 5%
    * including grammar errors in any written text.
    * excluding grammar errors in any verbal communication unless it is a specific and repeated error. 
  * Note: this will be added to your score after it is multiplied by the base score. 
    * e.g., if you get 80 on your labs+project, and you have 3% bonus from correcting errors, your final score will be 82.4
 
## Integrity policies 

* The work that you turn in must be yours.
* You must acknowledge your influences.
* You must not look at, or use, solutions from prior years or the Web, or seek assistance from the Internet.
* You must take reasonable steps to protect your work.
* You must not publish your solutions.
* If there are inexplicable discrepancies between exam and lab performance, we will over-weight the exam and interview you.

## Penalty
* Violate policy -> Incomplete, report to the department   
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
