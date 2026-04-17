
# VMFT - Primary-backup replication  

## Overview
* system layers
  * Physical machine, OS/hypervisor, VM, OS/VM, Systems App, App 
* replication in different layers
  * e.g., replicating GFS master   
* virtual machine basics 
  * a stream of instruction logs
  * inputs / outputs

## Approaches
* pause, replicate states, continue (migration)
  * easy to implement
  * but cost time, can be used in adding new replica
* state machine, replicate inputs 
  * efficient in performance 

## Correctness
* Input events need to be replicated at exact point of instruction  
* When can primary return?  
  * ack from F followers: tolerate F failures 
  * otherwise? 
* 

## Non-determinism
* clock
  * record
* multi-core (different from multi-thread)
  * not supported in vmft
* IO race
  * non-blocking 
  * DMA 

## Input/Output consistency
* exactly once over network? (TCP, UDP) 
* disk read 

## Network partition and "split-brain"
* perfect failure detector? no
* atomic test and set
* can lease solve the problem?
