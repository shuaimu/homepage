---
layout: page
title: 
permalink: /teaching/sf/25sp/
---
[
[Home](./index.html) | 
[Schedule](./schedule.html) 
<!-- | -->
<!-- [Policy](./policy.html) -->
]
# CSE 590-03-54561 Reliable System Programming

## Note:
* Please join the [course Piazza](https://piazza.com/stonybrook/spring2025/cse590) for class notifications and discussions.
* Solar Issues: if you have any issues signing up for the course, please contact me (shuai@cs.stonybrook.edu).

<!-- ## Announcements -->

<!-- * (Apr 15, 2019) Final exam date: May 20, 2:15pm, Humanities 1003 -->
<!-- * (Aug 22, 2020) We will use this [Zoom meeting room](https://stonybrook.zoom.us/j/97748330819?pwd=UWhITE1qcTE1T0Rwc2RXTXlKeWR3Zz09) for our lectures.  -->
<!-- * (Aug 22, 2022) First day! Please read the grading information in lecture 1's [notes](notes/overview.md). -->
<!-- * (Aug 18, 2023) Please join
[Piazza](https://piazza.com/stonybrook/fall2023/cse535) for class
notifications and discussions.
* (Aug 18, 2023) Please read the [collaboration and academic integrity
policy](policy.html); Enrollment in this class suggests you have accepted the
policy. -->


## Course introduction

Have you ever had a painful struggle with weird bugs? Did you once have a pointer that ends with "7" on Christmas Eve? Were you angry with your distributed systems labs when the system just hung? 
 
In debugging, we often rely on writing tests bit by bit to find out where is wrong, and it could be a stressful process. This is why good engineers love well-written tests before delivering the software because the tests confirm that the code works correctly, at least for the tested inputs. But still, bugs can happen. To have fewer bugs we need to test more inputs---what if you could check every possible input? Can we live in the dreamland of zero bugs?

In software verification, tests are replaced by a complete specification; the verifier provides a compile-time check that the implementation matches the specification, providing a much stronger guarantee than traditional testing. Instead of writing tests, the developer's effort towards correctness is focused on explaining why the implementation is correct, in the form of proof annotations. These techniques can help us build reliable, secure systems, with less reliance on runtime checking, which can be expensive.

This courses introduces Verus, an open-source, Rust-based verification tool designed specifically for systems software. Verus provides efficient proof automation and scales to large, complex systems. Verus is developed by a community of academic and industry contributors, it is already seeing industrial use at Microsoft and Amazon, and two of three best papers at OSDI 2024 are built on Verus.

Verus is open source at https://github.com/verus-lang/verus.

This course will briefly introduce the state-of-the art in software verification, covering the benefits and challenges of verification as an engineering methodology, especially with regards to systems software. It will then introduce Verus's basic features with a set of interactive exercises. No prior knowledge of Rust is required beyond familiarity with C-like languages. The course will then move on to verification principles, and Verus techniques necessary to verify complex systems involving non-trivial data structures, network communication, and distributed systems. 

Note: You may see on Solar that this course is using Dafny. Verus is a successor language in the Dafny community. 

## Prerequisites:
 * Familiar with some system-level programming language, such as C++ or Java
 * Pre-knowledge on these are welcome but *not* required, we will cover these topics in class: 
   * Rust
   * Distributed system (e.g., Raft)
   * Verification and other PL concepts

## Evaluation: 
 * 70% Project
   * Option A: implement a verified MultiPaxos or Raft 
   * Option B: propose your own target; you can choose works from top system venues (SOSP/OSDI/NSDI/SIGMOD, etc)
 * 30% Course participation
   * Paper presentation and discussion

## Acknowledgement
Most materials of this course are taken from:
* [Tutorial: Verifying Rust code with Verus](https://verus-lang.github.io/event-sites/2024-sosp/)
* [UMichigan EECS498 Formal Verification of Systems Software](https://glados-michigan.github.io/verification-class/2022/)