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
* in a 3-replica system, if (v1, 1) is accepted on replica-1, (v1, 3) is accepted on replica-2, is the value v1 chosen (committed)?   
  * no, think about the case where replica-3 has (v2, 2) accepted. 
  
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
