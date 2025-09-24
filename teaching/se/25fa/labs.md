---
layout: page
---

[
[Home](./index.html) | 
[Schedule](./schedule.html) |
[Policy](./policy.html)
]

#  Labs

## Lab assignments

Lab assignments will be announced here as the semester progresses.

<!-- [Lab 1 - MapReduce](labs/lab1.html) -->

<!-- [Lab 2 - Replicated State Machine](labs/lab2.html) -->

<!-- [Lab 3 - Fault-tolerant Key-value Store](labs/lab3.html)  -->

<!-- [Lab 4 - Sharded Key-value Store (Optional)](labs/lab4.html) -->

<!-- All assignments are due on November 1, 23:59pm  -->

## Acknowledgements
Lab assignments will be based on established software engineering curricula.

## Collaboration Policy
See [here](policy.html)

## Lab Environment

A modern development environment is recommended for the labs. Students may use their preferred IDE/editor and development tools.

## Lab Repository Setup

Lab repository setup information will be provided at the beginning of the semester.

<!-- Our labs are distributed and submitted through Github. Sign up an account if you
don't yet have one. Then join the labs assignment system via this
[link](https://classroom.github.com/a/vpPm2u0J). Choose your student ID in the 
next page. If you don't see your ID there, contact the TAs. 
Then follow the hints on the next page for initial setup of your private labs repo.
(Github sometimes fails this step. Retry after a few minutes if it happens.)

You will submit labs by pushing to your private repo (as many times as you want)
and we will collect labs for grading after the lab deadline directly from
Github. Below are the steps for setting up the lab environment on your
laptop. If you are not familiar with the git version control system, follow the
resources [here](https://try.github.io) to get started. 

Clone your repo by typing the following in a terminal:

```bash 
$ git clone https://github.com/shuai-teaching/ds20fall-labs-<YourGithubUsername>.git 
$ cd ds20fall-labs-<YourGithubUsername>
```

You will see that a directory named ds20fall-labs-\<YourGithubUsername\> has
been created under your home directory. This is the git repo for your lab
assignments throughout the semester. -->

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

Detailed submission procedures will be provided with each lab assignment.

<!-- Make sure you carefully read the collaboration policy, then in the root directory of the lab (the same folder as the Makefile), type these: 

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