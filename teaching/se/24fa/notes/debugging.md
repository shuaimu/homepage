* Common techniques in debugging? 
  * debugger (e.g., GDB)
  * logging
* Organization/culture
  * who is responsible for incidents?
    * SWE and SRE (site reliability engineer)
  * on call
  * don't blame
* Flow
  * receive alert
    * what is the severity?
  * evaluate (triage)
    * should i create an incident?
    * escalate severity?
    * local or global?
    * inactionable?
  * isolate error (initial investigation)
    * monitoring tools
      * spike in error and latency?
      * QPS
    * dependency change
  * Mitigate
    * rollback code / configuration
    * assign to a different datacenter
  * Validate health
  * Fix (background) 
* Common issues in isolating the error 
  * capacity problems
  * code changes
  * configuration chances
  * dependency
    * 2018 oct, youtube crashed because of logging library changed
  * underlying infrasturcture
  * external traffic 
* Example 1
  * 500 
  * check monitor tools, more alert coming in 
  * local or global? route the traffic
  * look for cause (code change)
  * roll back
  * validate
  * (send a issue to developer)
* Example 2:
  * alert SLO drops from 99.9% to 90%
  * intial investigation
    * when starting? caused by timeouts? 
    * dig into server logs
  * At the same time, another on-caller changes the configuration
    * intend to increase quota, but accidentally decreases
    * pushed globally (bad act!) without communication (bad act!)
    * more errors in the app
  * Finally, they connect and mitigate the issues together
* Debug / finding root cause
  * horse vs zebra
  * horses are more common, but in a large system, expect zebras
  * the python eq example 
* Uncommon issues (zebras)
  * int32 (4 billion) vs int64
    * 63,000 search queries per second
  * hash collision
  * (concurrency) bugs that only happens at a large scale
  * hanging program eats memory
  * 10,000 shared libraries, minutes to start the program
* Things to do when get stuck
  * read the doc more
    * the python equal example
  * add more log
  * take a break
  * clean the code
  * delete it!