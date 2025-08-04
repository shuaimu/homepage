---
layout: page
---

# Lab 4: Distributed Transactions
In the previous lab, you implemented the sharding of the KV store. In this lab, your task is to implement a versioned KV store and cross-shard transactions with optimistic concurrency control (OCC).

Get the latest lab software.
```
$ git checkout -b lab-transaction-solution
$ git fetch --all
$ git merge upstream/lab-transaction-23 
```

## Maintaining versions in the KV store

Your KV store internally should maintain a version along with each key. Whenever the key is updated, the version is automatically updated too. The versions need to be monotonically increasing, but they do not have to be incremental. Versions across different keys do not need to be comparable.  

## Cross-shard Distributed Transactions

Your ShardKvClient should support the following methods -
* `TxBegin` method to initiate a transaction and return a unique tx_id.
* `TxGet(tx_id, key)` to retrieve the current version of a key's value from the ShardKVServer leader.
* `TxPut(tx_id, key, value)` to update the value of the key.
* `TxCommit(tx_id)` to atomically commit the transaction using 2PL and 2PC. The ShardKvClient will act as the transaction coordinator for 2PC. Only the servers responsible for the shards associated with the keys accessed during a transaction need to participate in the 2PC.
* `TxAbort(tx_id)` to abort the transaction and discard associated side effects.

Here describes the variant of OCC and 2PC process we would like you to implement:
* During transaction execution (everything between TxBegin and TxCommit), writes are buffered at the client, not sent to the server. 
* Following TxCommit is a 2PC, coordinated by the client, i.e. the client serves the coordinator role of the 2PC.  
* In 2PC prepare phase, the server uses locks to protect the atomicity/isolation. The server acquires both read and write locks. The lock strategy we require is simple. First, the locks do not need to distinguish between read locks and write locks. Namely, two reads can conflict with each other. Second, The locks either succeed or fail on acquisition attempts. Namely you don’t have to maintain a queue and block the lock requests.
* If during the Prepare phase, the transaction observes any version updates to the read keys, then Prepare should be rejected, leading to the abortion of the transaction. After the Prepare phase, any concurrent normal operations (Get/Put) or transaction operations (TxGet/TxPut) attempting to access the locked keys should be aborted.
* The commit/abort request releases all the locks and installs the write-set into the KV store. 
* Any transaction operation (TxGet/TxPut) or normal operation (Get/Put) is allowed to access keys if they are not locked. 

## Basic test cases (Atomicity and Isolation)
```
$ python3 waf configure build --enable-raft-test
$ build/deptran_server -f config/transaction_lab_test.yml
TEST 1: Transaction commit perists all changes
TEST 1 Passed
TEST 2: Transaction abort discards all changes
TEST 2 Passed
TEST 3: Transaction Isolation on Single Server Shard: concurrent transaction aborts. (W before R)
TEST 3 Passed
TEST 4: Transaction Isolation on Single Server Shard: concurrent transaction aborts. (W before R)
TEST 4 Passed
TEST 5: Transaction Isolation on Single Server Shard: concurrent transaction commit. (R before W)
TEST 5 Passed
TEST 6: Transaction Isolation on Single Server Shard: concurrent transaction commit. (W before W)
TEST 6 Passed
TEST 7: Transaction Isolation on Cross Server Shard: concurrent transaction aborts. (W before R)
TEST 7 Passed
TEST 8: Transaction Isolation on Cross Server Shard: concurrent transaction aborts. (W before R)
TEST 8 Passed
TEST 9: Transaction Isolation on Cross Server Shard: concurrent transaction commit. (R before W)
TEST 9 Passed
TEST 10: Transaction Isolation on Cross Server Shard: concurrent transaction commit. (W before W)
TEST 10 Passed
TEST 11: Transaction Concurrency - multiple concurrent commits, only one should succeed
TEST 11 Passed
TEST 12: Transaction Concurrency - multiple concurrent commits, zero or one should succeed
TEST 12 Passed
ALL TESTS PASSED
```

