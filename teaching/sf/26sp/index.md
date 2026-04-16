---
layout: page
title: 
permalink: /teaching/sf/26sp/
---
[
[Home](./index.html) | 
[Schedule](./schedule.html) |
[Labs](./labs.html) 
<!-- | -->
<!-- [Policy](./policy.html) -->
]
# CSE 590-04(49474) Reliable System Programming (Rust/Verus)

Time: MW 2:00-3:20pm (Jan 26 - May 20)

Location: NCS 115

Lecturer: Shuai Mu, Zihao Zhang

## Note:
<!-- * Please join the [course Piazza](https://piazza.com/stonybrook/spring2025/cse590) for class notifications and discussions. -->
* Joing [Piazza](https://piazza.com/stonybrook/spring2026/cse590) for class notifications and discussions.
* Solar note: This course is named as Dafny in Solar for some historical reasons. Verus is a successor project of Dafny. If you have any issues signing up for the course, please contact me (shuai@cs.stonybrook.edu).

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

Systems software is notoriously difficult to develop correctly. We often have to investigate into bugs that are very hard to find root causes of. In debugging, we often rely on writing tests bit by bit to find out where is wrong, and it could be a stressful process. This is why good engineers love well-written tests before delivering the software because the tests confirm that the code works correctly, at least for the tested inputs. But still, bugs can happen. To have fewer bugs we need to test more inputs---what if you could check every possible input? Can we live in the dreamland of zero bugs?

<!-- Studies consistently show that a significant proportion of vulnerabilities in operating systems, databases, and other low-level software stem from memory-related defects—use-after-free, double-free, buffer overflows, and null pointer dereferences. These bugs not only cause crashes and unpredictable behavior, but also serve as entry points for security exploits. What makes memory bugs particularly insidious is their non-local nature: the symptom often manifests far from the root cause, turning debugging into a time-consuming and frustrating endeavor. -->
One philosophy to reduce debugging efforts is to catch bugs before the software ever runs—that is, to verify correctness at compile time. Rust takes a significant step in this direction through its ownership system and type safety guarantees. The compiler enforces memory safety without garbage collection, preventing entire classes of bugs such as use-after-free, double-free, data races, and null pointer dereferences. By tracking ownership and lifetimes statically, Rust catches many errors before the code even runs. This compile-time safety means that if your Rust code compiles, you have strong guarantees about memory safety and thread safety, dramatically reducing the debugging burden compared to languages like C or C++.

However, Rust's guarantees focus primarily on memory and concurrency safety—it does not verify that your program computes the correct result. This is where software verification comes in. It takes the compile-time philosophy further: tests are replaced by a complete specification; the verifier provides a compile-time check that the implementation matches the specification, providing a much stronger guarantee than traditional testing. Instead of writing tests, the developer's effort towards correctness is focused on explaining why the implementation is correct, in the form of proof annotations. These techniques can help us build reliable, secure systems, with less reliance on runtime checking, which can be expensive.

This courses teaches Rust basics and then introduces Verus, an open-source, Rust-based verification tool designed specifically for systems software. Verus provides efficient proof automation and scales to large, complex systems. Verus is developed by a community of academic and industry contributors, it is already seeing industrial use at Microsoft and Amazon, and two of three best papers at OSDI 2024 are built on Verus.

Verus is open source at https://github.com/verus-lang/verus.

This course will briefly introduce the state-of-the art in software verification, covering the benefits and challenges of verification as an engineering methodology, especially with regards to systems software. We will spend significant time going through Rust basics, including ownership, borrowing, data types, error handling, traits, generics, lifetimes, and concurrency. No prior knowledge of Rust is required beyond familiarity with C-like languages. The course will then introduce Verus's basic features with a set of interactive exercises, and move on to verification principles, and Verus techniques necessary to verify complex systems involving non-trivial data structures, network communication, and distributed systems. 

Note: You may see on Solar that this course is using Dafny. Verus is a successor language in the Dafny community. 

## Prerequisites:
 * You have learned some non-GC languages, such as C or C++.
 * Pre-knowledge on these are welcome but *not* required, we will cover these topics in class: 
   * Rust
   * Distributed system (e.g., Raft, Paxos)
   * Verification and other PL concepts

## Evaluation: 
We will have two homework assignments, each worth 50% of the final grade. One is using Rust to implement a Raft. The other one is using Rust+Verus to implement a Paxos. We will provide a framework for you to fill in the missing functions. The framework is provided with the grading script so you can test your implementation before submitting. To have an idea of what is the flavor of the assignment and framework, you can refer to the assignment in my other course [CSE 523 Database Systems](http://mpaxos.com/teaching/db/25fa/labs.html) (it is C++, but the flavor is the same).

## Acknowledgement
Most materials of this course are taken from:
* [Tutorial: Verifying Rust code with Verus](https://verus-lang.github.io/event-sites/2024-sosp/)
* [UMichigan EECS498 Formal Verification of Systems Software](https://glados-michigan.github.io/verification-class/2022/)