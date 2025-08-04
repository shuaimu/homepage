---
layout: page
title: 
permalink: /teaching/se/24sp/
---

[
[Home](./index.html)]
<!-- [Schedule](./schedule.html)  -->
<!-- | [Policy](./policy.html) -->
<!-- ] -->
# CSE 416 Software Engineering (Spring 2024, Section 2)

## Important message to read before you enroll


This section will be an *experimental track* of 416 which does *not* use a web-app project as the class project. We will still discuss important software engineering skills such as documentation, collaboration, code review, testing, etc. But we won't use a web project (e.g., MERN/Spring/Django-like projects) as the object of the study. Instead, we are going to build a prototype blockchain system. This project will use some systems-level programming languages, such as C++ or Rust.


It is important to note that we need you to be familiar with systems programming as a pre-prerequisite to take this class. You need to be comfortable with hacking low-level details (pointers, segfaults) to have the expected experience of this class. A good example is your OS class. This class is likely as hard (or as easy) as that. I recommend you not to take this class as a chance to get familiar with systems programming because then your workload will be overwhelming and you are likely to receive a failing grade. Attached below are a few questions you can test yourself on how well you are familiar with systems programming if you are uncertain.


FAQ:


Q: What type of blockchain project are we going to build? \
A: We haven’t fully decided, but it will probably be a file sharing blockchain, such as IPFS. You can read more about IPFS with the following two articles to get an idea about how it works.
[paper1](http://mpaxos.com/teaching/ds/23fa/readings/filecoin.pdf)
[paper2](http://mpaxos.com/teaching/ds/23fa/readings/ipfs.pdf)


Q: Are we going to work in teams?\
A: If we end up with a normal attendance (10-20), you will likely loosely work with someone else to get some tasks done, and/or with them on a sub-project for a longer time, but you won’t have a “team” in a traditional sense that each team has a separate project the entire semester.


Q: How will I be graded?\
A: Your grade will be based on your performance throughout the semester. It will be similar to a performance review process in a company (read [How Google does Performance Reviews](https://worklogixblog.files.wordpress.com/2018/08/b3318-google.pdf) ). It won’t be the same as the traditional rating process of classes you’ve taken here (exams or task lists). This may be another reason you won’t like this class, so take it with caution.







If you have any more questions, feel free to ask via [Piazza](https://piazza.com/stonybrook/spring2024/cse41602)




-Shuai


Attachment (Systems programming self-test)

```
Q1: What does OS rely on in order to schedule a busy-looping thread to the background from time to time?

Q2: What is the main advantage of using a green thread (also known as a fiber, or stackful coroutine) than an OS thread?

Q3: If you have a pointer that ends with 0x7, is that pointer valid?

Q4: How many times can an OS do context switching per second?

Q5: Why is select/epoll usually faster than synchronous send/recv?

Q6: If one thread writes 1 to a variable x, and after that,  another thread without protection of locks reads x, does it always return 1?



Answers:
Q1: Time interrupts.

Q2: Avoid OS context switch.

Q3: No.

Q4: ~10-100K.

Q5: Reduce context switches; reduce the number of threads.

Q6: No.


Results analysis
>=4 correct, take this class, you are fine.
>=2 but <4 correct, not recommended, but with extra work you may be fine.
< 2 correct, strongly not recommended.
```

<!-- ## Announcements -->

<!-- * (Apr 15, 2019) Final exam date: May 20, 2:15pm, Humanities 1003 -->
<!-- * (Jan 24, 2022) We are switching to -->
<!-- [Piazza](https://piazza.com/stonybrook/spring2022/cse41603) for class -->
<!-- notifications and discussions.  -->
<!-- * (Jan 17, 2022) Please read the [collaboration and academic integrity
policy](policy.html); Enrollment in this class suggests you have accepted the
policy. -->

<!-- ## Course information -->
<!-- Please refer to the department's    -->

<!-- ## Course information

Introduces the basic concepts and modern tools and techniques of software engineering. Emphasizes the development of reliable and maintainable software via system requirements and specifications, software design methodologies including object-oriented design, implementation, integration, and testing; software project management; life-cycle documentation; software maintenance; and consideration of human factor issues.

This course focuses on finishing a project: 
* The topic of the project is given with some basic features required.
* You can choose your toolchain, use the architecture you prefer, and add the features you desire. 
* You will work with a team of 3-5 students.  

## Grading

* Participation - 25%
* Mid-term exam - 25%
* Final - 50%


## Prerequisites:
 * CSE 316; and CSE major; and U4 standing. -->

<!-- ## Acedemic Integrity
You are welcome to use existing public libraries in your work. You may also look at code for
public domain software such as Github. Consistent with the policies and normal
academic practice, you are obligated to cite any source that gave you code or an
idea. You may not claim others' work as yours. Any violation will lead to an F in the grade, and be reported to the university.    -->

<!-- ## Useful Books
The following books may help provide background help. None of them are required.
They are listed in rough order of usefulness.
 * Principles of Computer System Design. Jerome Saltzer and M. Frans Kaashoek,
   Morgan Kaufmann.
 * Distributed Systems: Principles and Paradigms, Andrew Tanenbaum and Maarten
   van Steen, Prentice Hall. -->

<!-- ## Acknowledgement
The topics and many materials of this class are from the distributed systems
class taught at [MIT](https://pdos.csail.mit.edu/6.824/) and
[NYU](http://www.news.cs.nyu.edu/~jinyang/fa16-ds/index.html). -->
