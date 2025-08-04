* Motivation, why code review?
  * better code quality
  * consistent code style
  * find bug early
  * (gatekeeping) set boundary for the code
  * avoid accident
  * improve readability and maintainability
  * help knowledge transfer (education)
* Some common things to catch in review
  * don't repeat yourself
  * coding conventions
  * comments vs function naming
  * avoid hacks / magic numbers / strings in the code
  * fail fast and accurately
  * avoid over reuse
* Form/Style
  * Fagan-style
  * Email
  * Tool
    * Google/Gerrit
    * VMWare/ReviewBoard
    * Microsoft/CodeReview
    * Facebook/Phabricator
    * Flow:
      * Create a change
      * Preview
      * Assign reviewers
      * Comment/feedback
      * Fix/iterate
      * Approve
  * From Fagan to modern
    * early
    * asynchronous
    * lightweight/small-size
    * defect finding to problem solving? 
* Google's flow
  * preivew / static analysis (hooks, auto test, check)
  * find reviewer
    * ownership / tree structure
    * round-robin to reduce review load
      * sometimes outside your team
      * you don't get a promote for reviewing code!
  * review frequency and size
    * 3 (median), 7 (80%) a week
      * 2.6 hours median (3.2 average)
      * lower than other companies
    * median latency for review (4 hours)
      * compare to 15-20 hours
    * why? review size is small
      * 10%: single line change
      * median: 24 lines
        * AMD 44 lines
        * Lucent 263 lines
        * similar to OSS projects
      * 35%: single file
      * 90%: within 10 files
    * number of reviewer
      * most change only has 1 reviewer (75%)
      * for other OSS, commonly two
      * Microsoft: 4
  * Code review breakdowns
    * distance - delays
    * social interaction
    * review subject
    * context
    * customization by team
  * Discussion
    * lightweight, and why?
      * review quality, and latency
    * reviewer comments vs author's tenure
      * less questions in the reviews
    * developers will review more files as they stay longer in google