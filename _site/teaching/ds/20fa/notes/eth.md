# Smart Contract (Ethereum)

## Put code in blockchain
* a special tx type
  * a program (a class object): "smart contract"
  * a special account
    * has address
    * can hold balance
    * can receive / send 
  * initialization execution
  * have permanent storage space 
* calling a function in a smart contract 
  * by send
* a language-level virtual machine
  * avoid non-deterministic operation
    * external: trusted data sources
  * avoid computation and storage abuse: gas
  * isolation for safety 

## Application exampls
* IoT 
* paycheck systems
* insurance

## Application: token systems 
* token systems examples
  * reward points
  * new currency (coins) 
  * shares
* a ledger
  * key variable: balances
  * key function: transfer
* ERC20: a template to set up a token system quickly
  * totalSupply()
  * balanceOf(account)
  * transfer(recipient, amount)
  * transferFrom(sender, recipient, amount)
  * approve(spender, amount)
  * allowance(owner, spender)
* You can add other functions / smart contracts to "trade" tokens 
  * between the token and ETH
  * between tokens

## Application: stabilize price 
* between token and eth
  * set up a smart contract that buy a token at a price in the future 
* between token/eth and USD 
  * A and B both deposit in a smart contract 1000 eth, worth of X USD at the time
  * after a pre-defined time period, return X-worth of eth to A and the rest to B

## The DAO attack
* decentralized autonomous organization 
* a token system that allows deposit and withdraw 

```
function getBalance(address user) constant returns(uint) {
  return userBalances[user];
}

function addToBalance() {
  userBalances[msg.sender] += msg.amount;
}

function withdrawBalance() {
  amountToWithdraw = userBalances[msg.sender];
  if (!(msg.sender.call.value(amountToWithdraw)())) { throw; }
  userBalances[msg.sender] = 0;
}
```

* attack/ recursive withdraw

```
function () {
  // To be called by a vulnerable contract with a withdraw function.
  // This will double withdraw.

  vulnerableContract v;
  uint times;
  if (times == 0 && attackModeIsOn) {
    times = 1;
    v.withdraw();
   
   } else { times = 0; }
}
```

* a possible fix

```
function withdrawBalance() {
  amountToWithdraw = userBalances[msg.sender];
  userBalances[msg.sender] = 0;
  if (amountToWithdraw > 0) {
    if (!(msg.sender.send(amountToWithdraw))) { throw; }
  }
}
```

