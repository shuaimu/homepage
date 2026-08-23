
# Course introduction

## This is not "Theory of Database"

* Same course number (CSE 532), different course
* Systems course on database design and implementation
* Papers from production systems (Spanner, TiDB, MongoDB, CockroachDB, Postgres, RocksDB, ...)
* No labs this year

## Prerequisites

* Official: data structures and algorithms; a prior database course; system-level programming
* You will read a systems / database paper for almost every lecture
* Concurrency experience helps (transactions, replication)

## Course readings

* Lectures are based on research papers
* Check the webpage for the schedule
* Lectures assume you have read the assigned papers
* No textbook
* Today: [How to Read a Paper](../readings/paper-reading.pdf)

## Ways to get your questions answered

* Piazza (fastest) — join today: https://piazza.com/stonybrook/fall2026/cse532
* Office hour: MW 1–2pm, NCS 351 (book a GCal slot if you want a locked-in time)
* Email (slowest)

## "This course is so hard!"

* Paper-heavy: exams are on the papers
* Take it with caution, do not take this class if:
  * you are "underload" and you do not have much time to read
  * you expect an automatic C
  * you have no database or systems background
* Some think this is an easy course
  * no labs
  * lectures and exams are based on the papers
  * the project is a workshop / poster / demo

## How are you evaluated?

* Exams (60%)
  * Three in-class exams: Sep 28, Oct 28, Dec 2
  * We keep the two best scores (30% each)
  * You may skip one exam
  * No makeup tests (a miss is a zero; the drop covers it if you take the other two)
* Presentations (10%)
  * Required student paper presentations (not voluntary)
  * Dates on the schedule; topics TBA
  * Prepare the slides and send them to me a week before class
* Project (30%)
  * Teams of about 3
  * Any database-related project
  * Deliverable: workshop paper, poster, or demo
  * Evaluation is subjective: motivation, completeness, quality of the artifact
  * AI is encouraged on the project, not on exams
  * Lightning talks Oct 14; poster session Dec 7
* Grading standard
  * A: achieve >= 90 in score, or ranking 10%
  * A-: achieve >= 85 in score, or ranking 25%
  * B+: score >= 80, or ranking 35%
  * B: score >= 75, or ranking 50%
  * B-: score >= 70, or ranking 65%
  * C+: score >= 65, or ranking 80%
  * C: score >= 60, or ranking 95%
  * F: score < 60 and last 5%
* Other bonus
  * reporting a technical error I made (lecture) gives you 1 point, up to 20 points

## Integrity policies

* The work that you turn in must be yours
  * Project: your team's work; do not copy another team
  * Exams: work alone
* You must acknowledge your influences (papers, code, people)
  * Material from lecture does not require citation
* Exams: no collaboration and no AI
  * Do not post exam questions on the Web
* AI is allowed on the project; you still have to understand what you submit
* Do not publish exam solutions or another team's project
* If there are inexplicable discrepancies between exam and project contribution, we will over-weight the exam and interview you

## Penalty

* Violate policy -> F, report to the department
  * We are serious: in 19fa we caught ~20 students, and they all failed.
* If you find a grading error, tell us
  * Do not negotiate for extra points or extra work

## What are database systems?

* Shared, persistent data for applications
* A data model and a query interface (usually SQL)
* Concurrent access with correctness (transactions)
* Survive failures (recovery / durability)

## Why database systems?

* Applications should not reinvent storage, concurrency, and recovery
* Declarative queries: say what you want; the optimizer picks a plan
* Scale: many cores, many machines, geo-distributed / cloud

## Main challenges / topics this semester

* Architecture — Postgres, TiDB
* Replication and consensus — Raft, MongoDB
* Indexes and storage — LSM-tree, RocksDB, B+ trees, Masstree
* Transactions — serializability, Spanner
* SQL and query optimization — Selinger, Spanner SQL
* Weaker isolation and consistency — ANSI/SI, CockroachDB / MVCC
