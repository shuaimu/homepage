# Blockchain based Distributed Storage Networks (Filecoin) 

## Strawman: put all file datas into the blockchain
* files are too large for everyone to validate
* no incentives for nodes to store and share files
  * storage 
  * transmission 

## Off-chain storage
* How to prove each storage server actually store the data?  
  * the verifier cannot store the entire file
* possible attacks
  * not storing the file, generating proofs dynamically 
  * sybil attack: pretend to store more copies than actually does 
  * outsourcing to external storage 
* zero knowledge proof  
  * trusted party 
    * pk - prove key
    * vk - verification key
  * untrusted storage server 
    * given a variable x, generate a proof π
  * anyone with (pk, vk) can verify (x, π)
    * put the (pk, vk) onto the blockchain 
* avoid sybil attack 
  * seal: multiple rounds of encryption (AES)
* avoid outsourcing attack
  * require the verification to finish within a timeout  

## Filecoin
* blockchain to store metadata
* blockchain can work as a trusted party (market)
  * bid: Alice -> market 
  * ask: Bob -> market 
  * deal: Bob -> Alice -> k (within a time bound)

## Put procedure 
* client: add bid order to L (ledger) 
* network: match order, find ask
* client: sign deal, send deal (bid, ask), piece (with pk,vk,aes) to miner (storage server)
* miner: receive deal, piece, store the piece, sign

## Get procedure
* on-chain: too much overhead 
  * what if the client lies?   
    * piece by piece
* off-chain: micropayment
  * signed by client
  * miner will send grouped micropayments to L after the data transfer is over
