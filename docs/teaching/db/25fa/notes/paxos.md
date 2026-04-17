# Paxos

## Single-instance consensus
* different problem abstraction from Raft 
* same environment---asynchrony 
  * node/network failure/slowness
* "equivalent" to multi-instance consensus
* proposer/acceptor/learner: logical roles; each server/replica has all

## Preliminaries
* starting point
  * different replicas have different ids; can generate distinguished numbers
  * a value is attached with a number to distinguish
* goal
  * The system eventually "chooses" a value; or, a value gets chosen
  * Chosen (by definition) if it is "accepted" by a majority of servers 

## Thinking
* a server has to accept the first value it sees. 
  * otherwise the system will never choose any value
  * consequence: each server may accept different values 
* a server has to accept multiple values
  * otherwise "split"
  * consequences multiple values can be chosen
* if two values get chosen, they must be the same value
  * otherwise unsafe
* equivalent to: if a value with number n is chosen, any value with greater number m (m>n) chosen must be the same value
* further: if value-n is chosen, any value-m accepted must be the same value
* further: if value-n is chosen, any value-m proposed must be the same value
* if value-n is chosen, before value-m is proposed, the system replies value-n to the value-m proposer. 
* if value-n is *possibly* chosen, before value-m is proposed, the system
  * replies value-n to the value-m proposer, 
  * or, the system promises not to accept/choose value-n anymore.

## Protocol
* prepare phase:
  * pick number n, send prepare messages (phase-1a) to all
  * on receiving a prepare request, each replica updates its highest seen ballot, reply (phase-1b) with the highest number value it has ever accepted. 
  * collect replies (phase-1b) until get at least a majority, pick the value with the greatest number to propose, if no value in replies, pick any value
* accept phase:
  * use the value picked, send accept messages to all
  * on receiving an accept message, check highest seen number, accept and reply 
  * a majority of replies -> chosen (commit)
* commit phase:
  * broadcast commit messages notifying the chosen value

## Questions
* can a server accept different values?
  * yes
* does the majority of phase-1 (prepare) and phase-2 (accept) have to be the same?
  * no
* can each server only keep 1 ballot number instead of 2? 
  * no 
* in phase-2, can we use the original ballot number as the accept number?
  * no
* in a 3-replica system, if (v1, b1) is accepted on server s1, (v1, b3) is accepted on s2, is the value v1 considered chosen (committed)?   
  * no, think about the case where:
    * s1, s2 prepared b1; s1 accepted (v1, b1) 
    * s2, s3 prepared b2; s2 accepted (v2, b2) 
    * s1, s3 prepared b3; s3 accepted (v1, b3)
    * s1, s2 prepared b4; s1, s2 accepted (v2, b4)
  
## Multi-Paxos
* each log entry maps to a Paxos instance
* batch prepare request
  * normally 1 roundtrip to commit a value on the leader, same as Raft
* log entry has more content than Raft
  * highest seen ballot, accepted value ballot, value 
* unlike Raft, log entry could be modified 
  * otherwise what could happen?
* reconfiguration
  * add view information into each log entry. 

## Compare Multi-Paxos and Raft
* similarities: 
  * log structure
  * performance (w.r.t. 1 message roundtrip to commit)
* differences: 
  * currentTerm is not highest seen ballot 
  * term in each log entry is not the same as accepted ballot 
  * Raft has two extra rules 

## Paxos->Raft
* change phase-1: move comparison from proposer to acceptor. 
  * proposer send its accepted ballot to others to request a "vote"
* "super-prepare/accept"
  * each super-prepare prepares all instances
  * each super-accept accepts all instances 
  * "super-reject", if any instances refuses to prepare/accept, then reject
* global ballot number? 
  * a single highest seen ballot for all instances 
  * a single highest accepted ballot number for all instances
    * what about the ballot numbers in each log entry?  
    * if we keep them, "sometimes", they are the same as the highest accepted ballot number
      * sometimes = when highest seen ballot = highest accepted ballot. 
    * if the proposing server always use the ballot in a new log entry:
      * for a recipient, the last log entry log ballot is always the same as the global highest accepted ballot.  
      * so we can remove the global highest accepted ballot.
  * revisit Raft rules
    * "up-to-date" rule in leader election
    * "cannot count" rule in failure recovery 
* shrink the super-prepare/accept message size.
  * prepare
    * send a digest of all previously accepted entries
    * this digest is accepted ballot + log length (index).  
  * accept
    * prefix of the committed logs are the same. 
    * inductively, a ballot at the same index is the same => all previous are the same
    * send a "delta": what is different between the leader/follower?
    * should guarantee no "holes".
  
