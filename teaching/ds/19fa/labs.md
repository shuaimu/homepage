---
layout: page
---

[Home](.) &nbsp; &nbsp; &nbsp;
[Schedule](./schedule.html) &nbsp; &nbsp; &nbsp;
[Labs](./labs.html) &nbsp; &nbsp; &nbsp;
[Policy](./policy.html)

#  Distributed systems labs (Fall 2019)

## Lab assignments

[Lab 1 - MapReduce](labs/lab1.html)

[Lab 2 - Replicated State Machine](labs/lab2.html)

[Lab 3 - Fault-tolerant Key-value Store](labs/lab3.html) 

[Lab 4 - Sharded Key-value Store](labs/lab4.html)

All assignments are due on December 1, 6pm. 

## Acknowledgements
These labs are developed by Robert Morris (MIT 6.824).

## Collaboration Policy
See [here](policy.html)

## Lab Environment

A modern linux environment (e.g., Ubuntu 18.04) is recommended for the labs. 
If you do not have access to this, consider using a virtual machine.

## Lab Repository Setup

Our labs are distributed and submitted through Github. Sign up an account if you
don't yet have one. Then join the labs assignment system via this
[link](https://classroom.github.com/a/eWAbhlr2). Choose your student ID in the 
next page. If you don't see your ID there, contact me via email. Then 
follow the hints on the next page for initial setup of your private labs repo.
(Github sometimes fails this step. Retry after a few minutes if it happens.)

You will submit labs by pushing to your private repo (as many times as you want)
and we will collect labs for grading after the lab deadline directly from
Github. Below are the steps for setting up the lab environment on your
laptop. If you are not familiar with the git version control system, follow the
resources [here](https://try.github.io) to get started. 

Clone your repo by typing the following in a terminal:

```bash 
$ git clone https://github.com/shuai-teaching/ds19fall-labs-<YourGithubUsername>.git 
$ cd ds19fall-labs-<YourGithubUsername>
```

You will see that a directory named ds19fall-labs-\<YourGithubUsername\> has
been created under your home directory. This is the git repo for your lab
assignments throughout the semester.

<!-- ## Setting up the upstream repo -->

<!-- The lab skeleton code are kept in the repo golabs-2016 managed by the course -->
<!-- staff. Therefore, the first thing you need to do is to set up your own lab repo -->
<!-- to track the changes made in the golabs-2016 repo. In the git world, golabs-2016 -->
<!-- would be your "upstream" repo from which changes should ``flow'' into your own -->
<!-- lab repo. Type git remote add to add the upstream repo, and git remote -v to -->
<!-- check that golabs-2016 is indeed an upstream for your own lab repo. -->

<!-- ```bash -->
<!-- $ git remote add upstream https://github.com/shuai-teaching/ds19spring-labs.git -->
<!-- $ git remote -v -->
<!-- origin	git@github.com:nyu-ds/golabs-2016.git (fetch) -->
<!-- origin	git@github.com:nyu-ds/golabs-2016.git (push) -->
<!-- upstream	https://github.com/nyu-ds/golabs-2016.git (fetch) -->
<!-- upstream	https://github.com/nyu-ds/golabs-2016.git (push) -->
<!-- ``` -->

<!-- Immediately, you should check if the upstream ds19spring-labs repo has additional -->
<!-- changes not present in your repo. You can check for and merge in those changes -->
<!-- by typing: -->

<!-- ```bash -->
<!-- $ git fetch upstream -->
<!-- $ git merge upstream/master -->
<!-- ``` -->

<!-- You should perform the above two steps periodically to ensure that you've got -->
<!-- the latest lab code. We will also remind you to fetch upstream on Piazza if we -->
<!-- make changes/bug-fixes to the labs. -->

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
To handin your files, simply commit and push them to github.com

```bash
$ git commit -am "saving all my changes and handing in"
$ git push origin 
```

We will fetch your lab files from Github.com at the specified deadline and
grade them.
