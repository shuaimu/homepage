---
layout: page
---
# Lab 1: Replicated State Machine (Rust Raft)

* * *


## Policy
In short:
* Do this lab on your own.
* Do not share or discuss your code with others.
* Do not use AI.

## Lab Environment

A modern Linux environment is needed for the labs. The lab is written and tested under Debian 13 amd64. Other distributions may need some modifications. (Note that we do not provide customer support for various distros; only report if you encounter issues under Debian 13.) The labs do not require a lot of CPU/memory resources, but to avoid weird errors it is better to have more than 8 cores and 16G memory. If you do not have access to this, consider using a virtual machine (on cloud). We do not provide machines. The labs may work on other architectures, but it is not tested. From past we know the labs do not work under:
- Mac OS.
- Windows.

The following environments are known to *partially* work, i.e., you may be able to pass tests locally but not on the grading server:
- Virtual machines under Mac, like UTM.
- Arm-based Linux distributions.
- WSL1 on Windows.
- Machines/VMs with limited cores (e.g., 2 cores).

<!-- If you use a different distribution, it is possible you run into some compilation errors  -->
<!-- such as missing include files. Usually fixing these errors does not affect the grading process.   -->

<!-- (Technically the labs can be run on a Mac, including M1/M2, with homebrew 
installed dependencies. But this is not thoroughly tested.) -->

## Lab Repository Setup

Our labs are distributed and submitted through Github. Sign up an account if you
don't yet have one. Then join the labs assignment system via this
[link](https://classroom.github.com/a/fAuzLAuQ). Choose your student ID in the 
next page. If you don't see your ID there, stop (don't click skip) and contact the lecturer. 
Then follow the hints on the next page for initial setup of your private labs repo.
(Github sometimes fails this step. Retry after a few minutes if it happens.)

<!-- The guidelines for this part will be released after the class enrollment list is finalized (Sep 2). Before that you can view the lab content in its original repo [here](https://github.com/stonysystems/dslabs-cpp). -->

You will submit labs by pushing to your private repo (as many times as you want)
and we will collect labs for grading after the lab deadline directly from
Github. Below are the steps for setting up the lab environment on your
laptop. If you are not familiar with the git version control system, follow the
resources [here](https://try.github.io) to get started. 

Clone your repo by typing the following in a terminal:

``` 
$ git clone git@github.com:shuai-teaching/raftlab26-<YourGithubUsername>.git  
$ cd raftlab26-<YourGithubUsername>
```

You will see that a directory named raftlab26-\<YourGithubUsername\> has
been created under your home directory. 

## Setting up the upstream repo

The repo you created is currently empty. Add the upstream and sync with it. 

```bash 
$ git remote add upstream https://github.com/stonysystems/dslabs
$ git fetch upstream 
```

Next you will checkout the branch for the lab you are going to solve. For example, for lab 1:

```bash
$ git checkout -b lab-raft-solution upstream/lab-raft-26 
$ git submodule update --init
$ git push -u origin lab-raft-solution
```

Before compile, you need to install needed software dependencies.

```bash
bash apt_packages.sh
```

## Submit

Commit your code to the `lab-raft-solution` branch, with a message starting with "submit" (lower case).

<!-- Immediately, you should check if the upstream ds20spring-labs repo has additional -->
<!-- changes not present in your repo. You can check for and merge in those changes -->
<!-- by typing: -->

<!-- ```bash -->
<!-- $ git fetch upstream -->
<!-- $ git merge upstream/master -->
<!-- ``` -->

<!-- You should perform the above two steps periodically to ensure that you've got -->
<!-- the latest lab code. We will also remind you to fetch upstream on Piazza if we -->
<!-- make changes/bug-fixes to the labs. -->
<!-- 
## Saving changes while you are working on Labs
As you modify the skeleton files to complete the labs, you should frequently
save your work to protect against laptop failures and other unforeseen troubles.
You save the changes by first "committing" them to your local lab repo and then
"pushing" those changes to the repo stored on github.com

```bash
$ git commit -am "saving my changes"
$ git push origin
```

Note that whenever you add a new file, you need to manually tell git to "track
it". Otherwise, the file will not be committed by ```git commit```. Make git
track a new file by typing:

```bash
$ git add <my-new-file>
```

After you've pushed your changes with ```git push```, they are safely stored on
github.com. Even if your laptop catches on fire in the future, those pushed
changes can still be retrieved. However, you must remember that ```git commit```
by itself does not save your changes on github.com (it only saves your changes
locally). So, don't forget to run ```git push origin```. 

To see if your local repo is up-to-date with your origin repo on github.com and
vice versa, type

```bash
$ git status
```

## Handin Procedure

Make sure you carefully read the collaboration policy, then in the root directory of the lab (the same folder as the Makefile), type these: 

```
$ echo "I acknowledge that I have read, understand, and agree to the class policies." > agreement.txt
```

Check if the file has the correct sha256 hash. If you have a different hash, check if you have any typos.

```
$ sha256sum agreement.txt
fcd5da3cb6241e2aa6116564c454ac8a9e3769924a5434a864d62cd73473d80a  agreement.txt
```

Then add this file to git.
```
$ git add agreement.txt
```

When grading your lab submission, we will first look for this file and check 
its hash. If we don't find this file or it has a wrong hash, you will receive a 
0 for the labs! 

To handin your files, simply commit and push them to github.com

```bash
$ git commit -am "saving all my changes and handing in"
$ git push origin 
```

We will fetch your lab files from Github at the specified deadline and
grade them. -->
<!-- 
## Acknowledgements
These labs are inspired by the C++/Go labs of MIT 6.824. -->

## Introduction

This is the first in a series of labs in which you'll build a fault-tolerant key/value storage system. In this lab you'll implement Raft, a replicated state machine protocol. In the next lab you'll build a key/value service on top of Raft.
<!-- Then you will "shard" your service over multiple replicated state machines for higher performance. -->

A replicated service achieves fault tolerance by storing complete copies of its state (i.e., data) on multiple replica servers. Replication allows the service to continue operating even if some of its servers experience failures (crashes or a broken or flaky network). The challenge is that failures may cause the replicas to hold differing copies of the data.

Raft manages a service's state replicas, and in particular it helps the service sort out what the correct state is after failures. Raft implements a replicated state machine. It organizes client requests into a sequence, called the log, and ensures that all the replicas agree on the contents of the log. Each replica executes the client requests in the log in the order they appear in the log, applying those requests to the replica's local copy of the service's state. Since all the live replicas see the same log contents, they all execute the same requests in the same order, and thus continue to have identical service state. If a server fails but later recovers, Raft takes care of bringing its log up to date. Raft will continue to operate as long as at least a majority of the servers are alive and can talk to each other. If there is no such majority, Raft will make no progress, but will pick up where it left off as soon as a majority can communicate again.

In this lab you'll implement Raft as Rust methods in `RaftServer`, wired into the existing framework via FFI. A set of Raft instances talk to each other with RPC to maintain replicated logs. Your Raft interface will support an indefinite sequence of numbered commands, also called log entries. The entries are numbered with _index numbers_. The log entry with a given index will eventually be committed. At that point, your Raft should send the log entry to the larger service for it to execute.

Your Raft instances are only allowed to interact using RPC. For example, different Raft instances are not allowed to share variables. Your code should not use files at all.

## Objective

In this lab you'll implement most of the Raft design described in the extended paper. You will not implement: saving persistent state, cluster membership changes (Section 6), log compaction / snapshotting (Section 7).

Some general tips:
*   Start early. Although the amount of code isn't large, getting it to work correctly will be challenging.
*   Read and understand the [extended Raft paper](../readings/raft.pdf) and the Raft lecture notes before you start. Your implementation should follow the paper's description closely, particularly Figure 2, since that's what the tests expect.

<!-- This lab is divided into two parts. -->
<!-- You must submit each part on the corresponding due date. This lab does not involve a lot of code, but concurrency makes it challenging to debug; start each part early. -->

## Getting Started

First make sure you are working on the right branch, and create your working branch as `lab-raft-solution`.
```bash
$ git checkout -b lab-raft-solution origin/raft-lab-26
$ git submodule update --init
$ git push -u origin lab-raft-solution
```

We supply you with Rust skeleton code in `src/protocol/rust_raft` and the same lab tests used by C++.

To get up and running, execute the following commands:

```
$ cd your_labs_directory
$ cmake -S . -B build-rust -DBUILD_RAFT_LAB_TESTS=ON -DUSE_RUST_RAFT=ON
$ cmake --build build-rust --target labtest -j$(nproc)
$ ./build-rust/labtest -f config/raft_lab_test.yml
TEST 1: Initial election
TEST 1 Failed: ...
TESTS FAILED
```

Note: the framework runtime naming in this codebase now uses `fiber` terminology on the C++ side (older materials may say `coroutine`).

## The Code

Most of the Raft implementation work for Rust mode should be in:
* `src/protocol/rust_raft/server.rs`

You will also interact with the bridge/infrastructure files:
* `src/protocol/rust_raft/lib.rs` (FFI exports used by C++)
* `src/protocol/rust_raft/wrappers.rs` (safe wrappers for RPC/log/app callbacks)
* `src/protocol/rust_raft/ffi.rs` (raw extern bindings)
* `src/protocol/raft/server_rust.cc` (C++ adapter calling Rust)
* `src/protocol/raft/rust_ffi_wrapper.h` / `rust_ffi_wrapper.cc` (FFI types)

For the lab, you should generally implement protocol logic in `server.rs` and avoid changing wrapper/FFI glue unless instructed.

## RPCs

In Rust mode, outgoing RPCs are sent via the `Commo` wrapper in `wrappers.rs` (for example `broadcast_vote` and `send_append_entries`).

Incoming RPC handlers are Rust methods called from `lib.rs` FFI exports:
* `on_request_vote(...)`
* `on_append_entries(...)`

RPC replies are carried by wrapper reply objects:
* `VoteReply`
* `AppendEntriesReply`

These reply objects are RAII-style wrappers. Set response fields correctly before returning from handlers.

### Server logic

Struct `RaftServer` (`server.rs`) is your starting point for writing most of the protocol logic.

Some useful member fields:
* `site_id`, `partition_id`: local identity/partition.
* `commo`: RPC send helper wrapper.
* `logs`: log storage wrapper.
* `app_callback`: callback to apply committed commands.
* `current_term`, `commit_index`, `last_log_index`, `execute_index`.
* `is_leader`, `vote_for`, `next_index`, `match_index`.

## Required Functionality

There are a few specific functionalities in `RaftServer` you need to implement in order to pass all tests.

`pub fn start(&mut self, cmd: Command, index: &mut u64, term: &mut u64, slot_id: slotid_t, ballot: ballot_t) -> bool`
* Implement this method.
* If server is not the leader, return `false`.
* Else, start agreement on `cmd` in a new log entry, set `index` and `term` with the server's current index and term, and return `true`.

`pub fn get_state(&self) -> (bool, u64)`
* Implement this method.
* Return `(is_leader, term)` for the server.

`app_callback.apply(...)`
* The state machine apply callback exposed through `AppCallback`.
* Each server must pass each committed command to the callback exactly once, in the correct order, as soon as each command is committed on each server.

Your first implementation may not be clean enough that you can easily reason about its correctness. Give yourself enough time to rewrite your implementation so that you can easily reason about its correctness. Subsequent labs will build on this lab, so it is important to do a good job on your implementation.

You are recommended to do this lab following these two steps:

### Part 1A

Implement leader election and heartbeats (`AppendEntries` RPCs with no log entries). The goal for Part 1A is for a single leader to be elected, for the leader to remain the leader if there are no failures, and for a new leader to take over if the old leader fails or if packets to/from the old leader are lost.

* Add any state you need to `RaftServer` (do not use any static/global state to share data between server instances).
* Implement vote request handling in `on_request_vote(...)`.
* In `setup(...)`, start background fibers/tasks for election timeout and heartbeat behavior.
* Make sure the election timeouts in different peers don't always fire at the same time, or else all peers will vote only for themselves and no one will become the leader.
* The tester requires that the leader send heartbeat RPCs no more than ten times per second.
* The tester requires your Raft to elect a new leader within five seconds of the failure of the old leader (if a majority of peers can still communicate). Remember that leader election may require multiple rounds in case of split votes.
* Pick election timeout values that are large enough to avoid unstable leadership but small enough to satisfy test liveness.
* If your code has trouble passing tests, read Figure 2 in the paper again; the logic for leader election is spread over multiple parts of the figure.
* A good way to debug your code is to log every send/receive decision path for vote and append RPCs. `Log_info`/`log::info!` and `Log_debug`/`log::debug!` are both useful in this codebase.

### Part 1B

We want Raft to keep a consistent, replicated log of operations. A call to `start()` at the leader starts the process of adding a new operation to the log; the leader sends the new operation to other servers in `AppendEntries` RPCs.

Implement leader and follower code to append new log entries. This will involve implementing `start()`, fleshing out `on_append_entries(...)`, and advancing commit state on the leader and followers.

* You will need to implement the election restriction (section 5.4.1 in the paper).
* One way to fail tests is to hold un-needed elections even though the current leader is alive and can talk to peers. Bugs in timer management, or not sending heartbeats promptly after becoming leader, can cause this.
* You may need to write code that waits for events to occur. Do not write continuously spinning loops without sleep/yield, since that can slow your implementation enough to fail tests.
* Keep log consistency behavior correct: reject mismatched prev-log requests, overwrite/truncate conflicting suffixes, and advance commit index safely.
* Apply committed entries in order exactly once.

The tests for upcoming labs may fail your code if it runs too slowly. Try to write efficient code.

## Compile and Test

Configure and compile (Rust Raft mode):
```
$ cmake -S . -B build-rust -DBUILD_RAFT_LAB_TESTS=ON -DUSE_RUST_RAFT=ON
$ cmake --build build-rust --target labtest -j$(nproc)
```

Test:
```
$ ./build-rust/labtest -f config/raft_lab_test.yml
TEST 1: Initial election
TEST 1 Passed
TEST 2: Re-election after network failure
TEST 2 Passed
TEST 3: Basic agreement
TEST 3 Passed
TEST 4: Agreement despite follower disconnection
TEST 4 Passed
TEST 5: No agreement if too many followers disconnect
TEST 5 Passed
TEST 6: Rejoin of disconnected leader
TEST 6 Passed
TEST 7: Concurrently started agreements
TEST 7 Passed
TEST 8: Leader backs up quickly over incorrect follower logs
TEST 8 Passed
TEST 9: RPC counts aren't too high
TEST 9 Passed
TEST 10: Unreliable agreement
TEST 10 Passed
TEST 11: Figure 8
TEST 11 Passed
ALL TESTS PASSED
Total RPC count: 6609
```

The source for the tests is in `test/labtest.cc` and `test/labtestconf.cc`.

## Submit

Commit your code to the `lab-raft-solution` branch, with a message starting with "submit" (lower case).

## DO NOT

Make sure you do not do any of the following; otherwise you will fail the labs, even if the code may pass the testing scripts.

* Change/create files other than the files allowed for this lab.
* Use shared variables between Raft instances.
* Use file/network/IPC interfaces other than the provided RPC interface.
* Break the FFI bridge contracts in `lib.rs` / `rust_ffi_wrapper.*` unless the assignment explicitly asks for interface changes.