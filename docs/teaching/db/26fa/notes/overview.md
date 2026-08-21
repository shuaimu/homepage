

# Course introduction

## Prerequisites

* Familiar with OS & networking
* System-level C/C++ programming experience 
* Comfortable with concurrency and threading
* Paper reading experience

## Course readings

* Lectures are based on research papers
* Check webpage for schedules
* Lectures assume you have read the assigned papers
* No textbook

## Ways to get your questions answered

* Piazza (fastest)
* Office hour
* Email (slowest) 

## "This course is so hard!"
* Some thinks this is one of the hardest courses
* Take it with caution, do not take this class if: 
  * you are "underload" and you do not have much time 
  * you expect an automatic C
  * you don't have much systems experience
* Some thinks this is an easy course
  * lectures and exams are based on the papers; the project is a substantial implementation

## How are you evaluated?
* Exams (60%)
  * Three in-class exams; we keep the two best scores (30% each)
  * You may skip one exam
  * No makeup tests
* Presentations (10%)
  * Student paper presentations; dates on the schedule, topics TBA
  * Prepare the slides and send them to me a week before class
* Project (30%)
  * Groups of 3–5
  * Implement a paper (or your own idea) in Mako; C++ or Rust
  * AI is encouraged on the project, not on exams
* Grading standard
  * A: achieve >= 90 in score, or ranking 10% 
  * A-: achieve >= 85 in score, or ranking 25% 
  * B+: score >= 80, or ranking 35% 
  * B: score >= 75, or ranking 50% 
  * B-: score >= 70, or ranking 65% 
  * C+: score >= 65, or ranking 80%
  * C: score >= 60, or ranking 95%
  * F: score < 60 and last 5%
* Other bonus 
  * reporting a technical error I made (lecture) gives you 1 point, up to 20 points
 
## Integrity policies 

* The work that you turn in must be yours.
* You must acknowledge your influences.
* You must not look at, or use, solutions from prior years or the Web, or seek assistance from the Internet.
* You must take reasonable steps to protect your work.
* You must not publish your solutions.
* If there are inexplicable discrepancies between exam and project contribution, we will over-weight the exam and interview you.

## Penalty
* Violate policy -> F, report to the department   
  * We are serious: in 19fa we caught ~20 students, and they all failed.
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
* "A distributed system is one in which the failure of a computer you didn't even know existed can render your own computer unusable." -- Leslie Lamport

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
