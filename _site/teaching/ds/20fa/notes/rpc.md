# RPC

## Overview
* basic building block to make distributed programming easier 
  * make a remote call similar to a local call 
  * e.g. `server.add(3, 5), proxy.add(3, 5)`
* As a library
  * e.g. gRPC, go-rpc, json-rpc

## Inside RPC
* function register
  * protocol file -> compile -> source code -> put in your repo 
* marshalling (serialization) and unmarshalling 
  * data structure <---> bytes
* network connections
  * hard to deal (buffer, async calls, error codes) 
  * (optional) read C10k problem 

## Challenge: failures
* network delays, message reorder/loss
* practice: set timeout (and retry) on clients

## At least once
* usually unsafe: trade, withdraw/deposit  
* safe for read-only requests
* pro: simple implementation

## At most once
* clients use a globally unique xid for each request 
* servers keep a buffer of previous results
* keep a window of outstanding requests and force ordering
  * clients use sequentially increasing xid 
  * servers block on "holes" 
* alternative: write the buffer to durable storage and never delete

## Exactly once?
* "eventually"
* theoratically not possible with asynchronous network
