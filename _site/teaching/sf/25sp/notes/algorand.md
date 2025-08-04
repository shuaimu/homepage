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

## Choose a small committee 
* Option 1: controlled 
* Option 2: random 
  * leader with the most balance? 
    * centralized
  * random one leader, safety?
    * how? use last block as seed to rand.   
    * attack: liveness, fork
    * fairness?
  * random one leader using their weight?
    * how? a binomial distribution  
    * better, but lead to a dictator 
  * random a committee using their weight?
  * Does everyone scan all accounts?
    * how much time does it take? (against the goal of saving power) 
    * can we ask proxies to do it? (but again, verifiy would take a lot of work) 
    * can we ask each account to test for themselves? 
      * how can we verify?

## Sortition based on Verifiable Random Function (VRF)
* Sortition:
  * proposer
  * committee
* given public/private key pair (pk, sk),  VRF(sk, content/seed) generates a hash (random to everyone, crypto safe) and a proof
  * use the hash to deterministically decide whether the user is a proposer or a committee member 
  * seed is in the previous block 
  
## BA agreements
* Vote and CountVote  
  * over threshold in the first round: final consensus
  * else: tentative consensus
    * fork: could achieve tentative consensus on two blocks, why? (network asynchrony)
* The system can fork (tentative consensus) 
  * with a malicous committee member
    * but will converge in the next block (why?)
  * with network asynchrony   
* How can we avoid/address forks?
  * we cannot in a fully asynchronous setup 
  * have a stronger assumption on the network, cannot be async forever 

## Compare to Stellar  
* a node in Stellar selects a number of servers it trusts as the consensus group, compared to VRF used in Algorand 
* BA in Stellar is ballot-based, a node first tries to find out what value is potentially chosen before
