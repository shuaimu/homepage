# Byzantine Paxos

## Byzantine failures: "malicious" participants
* including crashes/slowness 
* hacked/compromised servers  
* other rare failures: disk/memory/network corruption 

## How many good servers needed to tolerate f byz-failures?
* Apparently greater than f+1, i.e., has to cover normal consensus
* f+1 is not enough
  * divide the system into 3 groups
    * f byz servers
    * f good servers
    * 1 good server
  * counter-example
    * f good servers offline
    * f byz servers and 1 good server come to a decision v-1 
    * 1 good server offline, f good server online.
    * f byz servers act like never deciding anything
    * f good servers and f byz servers will decide a different value v-2
* f+x is not enough for any x <= f
* so we at least need 2f+1 good servers to tolerate f byz servers; that is 3f+1 in total

## Starting point
* in Paxos we have our quorum as majority, which is f+1 out of 2f+1 servers. 
* now we have f possible liars in each message round.
* can we enlarge the quorum size by f to outvote the byz-servers?
  * f+1 -> 2f+1, in prepare and accept

## Example
* good: S1, S2, S3, byz: S4
* S1 prepares all with ballot 1
* S1 accepts S1, S3, S4 with (1, v1), considers this value chosen.
* S1 stands down
* S2 tries to prepare S2,S3,S4
* S3 replies (1, v1), S4 replies (1, v2)
* S2 is stuck!

## Prevent lies at non-proposers
* assume proposers don't lie for now
* lies in phase1b (ack to prepare), should->lie
  * type 1: okay -> reject
  * type 2: okay (b1, v1) -> okay (no-value) 
  * type 3: okay (b1, v1) -> okay (bx, vx)
    * let the phase1b message include the previous phase2a as proof
  * type 4: reject -> okay (no-value)
  * type 5: reject -> okay (bx, vx) 
* lies in phase 2b, does it hurt?
  * type 1: okay -> reject
  * type 2: reject -> okay
  
## Prevent lies at proposers
* lies in phase1a, does it hurt?
  * no, only a number.
* lies in phase2a, a single type: (b1, v1)->(bx, vx) 
  * let phase2a include previous phase1b responses as proof.  
  * or, add another phase phase1c to send these proof before phase2a
* what about commit messages?
  * include phase2b?   
  * add another phase phase2av to broadcast accepted values. 
