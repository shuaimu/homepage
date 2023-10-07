* Why testing is hard?
  * Imagine a "simple" program
    * take input at once
    * generate output at once
    * enumerate all input?
      * too much
      * instead, code coverage
    * the program still have many conditions/branches
      * if  
        * 2^N possibilities
      * loop (including goto)
  * Real world program is more complex
    * Input/output is dynamic/non-stop
    * System can be more complex 
      * multi-threading
      * multple components (disks, multiple nodes) 
  * Phase1: select env/interface
  * Phase2: select test case
    * criteria
      * coverage
        * each statement
        * each branch
        * each data structure initialized and used
      * fault seeding
      * input domain
        * each physical input
        * each interface control
        * random
        * typical
  * Phase 3: run test and evaluate 
    * evaluate the test
      * formal methods
      * embedded code
    * regression testing
      * rerun the tests again after patch!
  * Phase 4: measure test progress
    * structural completeness
    * functional completeness
      * think of more ways it could fail
* How Google tests
  * Why do we test? for quality software
    * but who should be more responsible for quality? 
      * developer or tester?
    * So testers in Google help develpers to test, not test for them!
    * Organization structure 
      * Eng Prod
      * product team
      * testers belong to both eng prod and product team
      * testers "oversee" the tesing progress
      * two different testers
        * software engineer in testing
        * test engineer
          * think of more ways it could fail
    * Code structure
      * canary channel
      * dev channel
      * test channel
      * beta/release channel
    * Do you need a tester in the beginning?
      * no
      * but it does not mean you should not write tests!
* The Boeing 737 case
  * overview
    * the new/bigger engine changed the aerodynamics
    * pull up the nose / risk of stall
    * Problem found in a test flight
    * MCAS -> automatically push down the nose
      * danger! push down the nose - crash
      * worse 1: pilots do not know
      * worse 2: not in the checklist
      * worse 3: very hard to turn off
      * worse 4: if not turned down in 10s, no more chance
      * worse 5: rely on one sensor 
  * lessons
    * patch exisiting systems is better?
    * regression test is necessary 
    * autopilot should only be conditionally trusted and can be turned off anytime
* The Google App Engine case
  * overview
  * lessons
    * the implementation is correct but the worklflow is problematic
