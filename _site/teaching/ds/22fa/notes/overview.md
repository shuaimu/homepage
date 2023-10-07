

# Course introduction

## Class stuff and office hour

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

## Important website

* class schedule
* piazza 

## "This course is so hard!"
* Some thinks this is one of the hardest courses
* Take it with caution, do not take this class if: 
  * you are "underload" and you do not have much time 
  * you expect an automatic C
  * you don't have much systems experience
* Some thinks this is an easy course
  * grading is objective based on labs, you have an preview

## How are you evaluated?
* No exam, graded by 4 lab assignments 
  * 25 points each lab
  * You must work alone on all assignments
  * You have about 3 weeks for each lab
  * Late policy: 5 percent off per day, at most 40 percent (so you can still get 60 percent of the credit if you submit very late)
* An extra 25-point bonus project
    * You need to get at least 70% of the first three labs to do the bonus project, i.e., this project is not supposed to be used as a "plan B" to increase your score. You should only do it if you like to do it. 
    * This project is graded subjectively. It is possible you do not get any points if you do not do a good job. 
    * A few candidate projects will be released, which you can choose from
* Grading standard
  * A: achieve >= 90 in score, or ranking 10% 
  * A-: achieve >= 85 in score, or ranking 20% 
  * B+: score >= 80, or ranking 30% 
  * B: score >= 75, or ranking 50% 
  * B-: score >= 70, or ranking 70% 
  * C+: score >= 65, or ranking 80%
  * C: score >= 60, or ranking 90%
  * F: score < 60 and last 10%
* Other bonus 
  * we will have a few voluntary presentation sessions discussion papers. You can volunteer a 20-minute presentation.  
    * I will release the papers you can choose from
    * To make sure the discussion goes on well, you need to prepare the slides and send it to me a week ago than the class. 
    * If your presentation quality meets expectation, you get 5 points; if it exceeds expection, you get extra 5 points.     
  * reporting a technical error I made (lecture/lab) gives you 2 points, up to 20 points
  * from time to time I would ask a "bonus question" in class; each 2 points.
* An alternative to lab assignments
  * an alternative to all above is to work on a more complex distributed systems project (expect at least twice the workload---usually much more---of the lab assignment). This is invitation-only. Consult the lecturer for more information.  
 
## Integrity policies 

* The work that you turn in must be yours.
* You must acknowledge your influences.
* You must not look at, or use, solutions from prior years or the Web, or seek assistance from the Internet.
* You must take reasonable steps to protect your work.
* You must not publish your solutions.
* If there are inexplicable discrepancies between exam and lab performance, we will over-weight the exam and interview you.

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
