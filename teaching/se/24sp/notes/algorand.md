# Algorand

## Use byzantine consensus/agreements in block chains 
* Replace the Proof-of-works consensus protocols in Bitcoin 
* Pros
  * higher throughput
  * no forks
  * no mining
* Cons 
  * liveness
    * malicious
    * concurrent proposals
  * membership management
    * join/leave
    * Sybil attacks

## Sortition based on Verifiable Random Function (VRF)
* Sortition:
  * proposer
  * committee
* given public/private key pair (pk, sk),  VRF(sk, seed) generates a hash and a proof
  * use the hash to deterministically decide whether the user is a proposer or a committee member 
  * seed is in the previous block 
  
## BA agreements
* Vote and CountVote  
  * over threshold in the first round: final consensus
  * else: tentative consensus
    * fork: could achieve tentative consensus on two blocks, why? (network asynchrony)

## Compare to Stellar  
* a node in Stellar selects a number of servers it trusts as the consensus group, compared to VRF used in Algorand 
* BA in Stellar is ballot-based, a node first tries to find out what value is potentially chosen before
