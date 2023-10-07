
# Fast Paxos

## Paxos review
* Round structure
* Discover the possibly chosen value of previous rounds?
  * no value accepted before
  * a single round or multiple round accepted before
    * choose the higher round
    * is there a single value or multiple accepted in this round?
* Trick, intersect
  * What if increasing the prepare quorum size?
  * What if increasing the accept quorum size?
* The high performance model
  * there is a leader
  * client to leader
  * leader send to follwers, and followers ack
  * leader reply to client
  * 2 RTT in total
* Question: can we reduce RTT?
  * client directly send to every one?

## Fastpath Quorum
* problem
  * multiple values can be accepted in a round
* quorum size: a majority?
  * how to recover in the next round? 
  * compare number is no longer possible
* quorum size: all?
  * if see differeent values, then values chosen
  * unless see the overlap between N and M, which is M, no need to accept this value
* what is the right size? between M and N?
* problem, the intersection of M and Qf does not intersect with another QF
  * Make the intesect!
  * Qf+M-N+Qf-N>0 2Qf+M>2N
    * N-E+N-F-N+N-E-N>0, N>2E+F
  * 2M>N
    * N-F+N-F>N, N>2F
  * 4Qf>=3N,    
* 