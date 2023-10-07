---
layout: page
---

[
[Home](./index.html) | 
[Schedule](./schedule.html) |
[Labs](./labs.html) |
[Policy](./policy.html)
]

#  Labs

Distributed systems labs for C++ lovers. 

## Lab assignments

<!-- [Lab 1 - MapReduce](labs/lab1.html) -->

- [Lab 1 - Replicated State Machine](labs/lab1.html) (Due Oct 8 23:59pm)
- Lab 2 - Fault-tolerant Key-value Store
<!-- - (labs/lab2.html) (Due ~~Oct 23~~ Oct 30) -->
- Lab 3 - Sharded Key-value Store
<!-- - ](labs/lab3.html) (Due ~~Nov 13~~ Dec 11)  -->
- Lab 4 - Distributed Transactions

<!-- [Lab 2 - Fault-tolerant Key-value Store](labs/lab2.html)  -->

<!-- [Lab 3 - Sharded Key-value Store](labs/lab3.html) -->

<!-- All assignments are due on November 1, 23:59pm  -->

## Collaboration Policy
See [here](policy.html).

## Lab Environment

A Ubuntu 20.04 amd64 environment is recommended for the labs. 
The labs do not require a lot of CPU/memory resources, but to avoid weird errors it is better to have more than 4 cores and 8G memory.
If you do not have access to this, consider using a virtual machine (on cloud). 
We do not provide machines.  
<!-- If you use a different distribution, it is possible you run into some compilation errors  -->
<!-- such as missing include files. Usually fixing these errors does not affect the grading process.   -->

<!-- (Technically the labs can be run on a Mac, including M1/M2, with homebrew 
installed dependencies. But this is not thoroughly tested.) -->

## Lab Repository Setup

Our labs are distributed and submitted through Github. Sign up an account if you
don't yet have one. Then join the labs assignment system via this
[link](https://classroom.github.com/a/3HAMvwwX). Choose your student ID in the 
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
$ git clone git@github.com:shuai-teaching/dslabs-cpp-<YourGithubUsername>.git  
$ cd dslabs-cpp-<YourGithubUsername>
```

You will see that a directory named dslabs-cpp-\<YourGithubUsername\> has
been created under your home directory. This is the git repo for your lab
assignments throughout the semester. -->

## Setting up the upstream repo

The repo you created is currently empty. Add the upstream and sync with it. 

```bash 
$ git remote add upstream https://github.com/stonysystems/dslabs-cpp 
$ git fetch upstream 
```

Next you will checkout the branch for the lab you are going to solve. For example, for lab 1:

```bash
$ git checkout -b lab-raft-solution upstream/lab-raft-23 
$ git submodule update --init
$ git push -u origin lab-raft-solution
```

Before compile, you need to install needed software dependencies.

```
sudo apt-get update
sudo apt-get install -y \
    git \
    pkg-config \
    build-essential \
    clang \
    libapr1-dev libaprutil1-dev \
    libboost-all-dev \
    libyaml-cpp-dev \
    libjemalloc-dev \
    python3-dev \
    python3-pip \
    python3-wheel \
    python3-setuptools \
    libgoogle-perftools-dev
sudo pip3 install -r requirements.txt
```

Refer to each lab assignment for compiling commands.

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

## Acknowledgements
These labs are inspired by the C++/Go labs of MIT 6.824.