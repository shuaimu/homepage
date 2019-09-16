
# VMFT - Primary-backup replication  

## Overview
* virtual machines layers 
* replication in different layers
* e.g., replicating GFS master   

## Approaches
* pause, replicate states, continue
 * easy to implement
* state machine, replicate inputs 
 * efficient in performance 

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
* failure detector
* atomic compare and swap
* can lease solve the problem?
