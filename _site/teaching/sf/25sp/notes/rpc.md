# RPC

## Overview
* What is wrong with handweaving the network code?
  * abstraction
  * error/failure handling
  * performance 
* basic building block to make distributed programming easier 
  * make a remote call similar to a local call 
  * e.g. `server.add(3, 5), proxy.add(3, 5)`
* As a library
  * e.g. gRPC, go-rpc, json-rpc

## Inside RPC
* function register
  * protocol file -> compile -> source code (client/server) -> put in your repo 
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
* no liveness guarantee with asynchronous network
* two generals problem

## RPC performnace 
* highly concurrent code, how? 
* two classic approaches: threads vs event 
* threads
  * pro: easy to understand/maintain, automatic stack management 
  * con: cost (C10K), pre-emptive thread scheduling
* event
  * pro: fast, no pre-emptive thread sheduling, no "thread safe" (with data partitioning).   
  * con: harder to read/write, stack ripping (function scope, automatic variables, control structures, debugging stack), harder to "evolve"
* a sweet spot: userspace thread (fiber, stackful coroutine)
  * create stack in userspace
  * switch between them on users' call  
  * use very similar to threads but with a much lower cost
* stackless coroutine
  * started as syntax sugar, "glue" callback into calling function   
    * async/await
    * major difference: nested yield? 
  * compiler support for stack variables 