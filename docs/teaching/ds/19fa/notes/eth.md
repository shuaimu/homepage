# Smart Contract (Ethereum)

## Put code in blockchain
* a special tx type
  * a program (a class object): "smart contract"
  * a special account
    * has address
    * can hold balance
    * can receive / initiate transfer
  * initialization execution
  * have permanent storage space 
  * function triggered by transfer
* problem
  * avoid non-deterministic operation
    * external: trusted data sources
  * avoid computation and storage abuse: gas
  * isolation for safety 

## Application: Token systems 
* token systems examples
  * reward points
  * new currency (coins) 
  * shares
* a ledger
  * key variable: balances
  * key function: transfer
* ERC20: a template to set up a token system quickly

## Application: stabilize price 
* A and B both deposit in a smart contract 1000 eth, worth of X USD at the time
* after a pre-defined time period, return X-worth of eth to A and the rest to B
