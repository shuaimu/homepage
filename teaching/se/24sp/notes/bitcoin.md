# Bitcoin (Proof-of-work)

## A chain of blocks as a public ledger 
 * each block has a header and a body
 * the body has entries of transfers
 * asymmetric encryption scheme (public/private keys) to prevent forging 
 * (hash of) public key as address, private key to sign

## Proof-of-work for consensus
 * each block header contains the hash value of previous block
 * target: a number (256 bit for bitcoin) with the beginning n bits are zero.
   * lower than or equal to
   * max (easier to computer): 32 bits as 0
     * 2^224-1 : 0x00000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
   * min (harder to computer): all bits as 0  
     * can be possibly extended to more than 256 bits, so really no minimum target
 * each block also has a 4-byte random number (nonce), a participant (miner) can enumerate the nonce to meet the difficulty requirement. 
 * on average generating each block will take 2^n tries. If the network has "hashing power" as H, and the expected time to generate next block is t. Then: t*H = 2^n. 
 * if the desired time to generate the next block is T, then the difficulty should be set as n=log_2(T*H)
 * difficulty: max_target / current_target
   * min: 1
   * max: no max difficulty (greater than 2^224) 
   * current difficulty: 12,720,005,267,390 ~= 12.7T ~= 2^44
     * target = max_target / difficulty ~= 2^(224-44) = 2^180 
 * difficulty/target is adjusted every 2016 blocks (approximately 2 weeks given the 10 minutes period)

## Timestamp
 * accepted as valid if 
   * lower than now + 2 hours 
   * greater than the median timestamp of previous 11 blocks 

## Incentives and mining
 * block reward initially 50 bitcoin for each block, plus transaction fees
 * block reward halves every 210,000 blocks (~4 years), 0 after 64 iterations
   * currently at 12.5 (2019)
 * total amount: ~21 million, over 75% and below 87.5% have been mined (why?)
   * 210000 * (50 + 25 + 12.5 + ...)

## Merkle tree
 * leaf nodes has data
 * non-leaf nodes has hash of children nodes
 * the merkle root hash (32 bytes) is in the block chain header 
 * this enables fast verification of the chain 
   * no need to compute hash for all transaction content.

## Forking
 * if two miners both generate (different) next blocks, then the chain "forks". Other clients may accept either chain.
 * eventually, the longer chain wins, that is, a client will replace its own chain with a new chain if the new chain is longer.
 * 51% attack: if one controls most of the hash powers, she can always rewrite a chain, causing issues such as double spending. 
 * to avoid frequent forking, the expected time to generate a block should not be too small. 4 minutes in bitcoin. To achieve this, the difficulty is adjusted every 2016 blocks (~2 weeks). 
