
# Raft

## A linearizable replicated log
* Raft picks one server to be leader
* clients send Append/Get RPCs to leader
* leader sends each client command to all replicas
  * each follower appends to log
  * goal is to have identical logs
  * log entry is "committed" if a majority put it in their logs -- won't be forgotten
     majority -> can proceed despite minority of failed servers
  * servers execute entry once the leader says it's committed

## Will the Raft logs always be exactly the same replicas?
* no: some replicas may lag
* no: we'll see that they can have different entries!
* if a server has executed a command in a given entry number:
  * no other server will execute a different command for that entry
  * i.e. the servers will agree on the command for each entry
  * State Machine Safety (Figure 3)

## Two parts
* electing a new leader
* ensuring identical logs after failures

## Leader election 
* Raft numbers the sequence of leaders
  * new leader -> new term
  * a term has at most one leader; might have no leader
  * the numbering helps servers follow latest leader, not superseded leader
* when does Raft start a leader election?
  * other servers don't hear from current leader for a while
  * they increment local currentTerm, become candidates, start election
* how to ensure at most one leader in a term?
  * (Figure 2 RequestVote RPC and Rules for Servers)
  * leader must get votes from a majority of servers
  * each server can cast only one vote per term
     votes for first server that asks (within Figure 2 rules)
  * at most one server can get majority of votes for a given term
    -> at most one leader even if network partition
    -> election can succeed even if some servers have failed
* how does a server know that election succeeded?
  * winner gets yes votes from majority
  * others see the AppendEntries heart-beats from winner
* an election may not succeed
  * none gets majority 
  * even # of live servers, two candidates each get half
  * less than a majority of servers are reachable
* what happens after a failed election?
  * another timeout, increment currentTerm, become candidate
  * higher term takes precedence, candidates for older terms quit
* how does Raft reduce chances of election failure due to split vote?
  * each server delays a random amount of time before starting candidacy
  * why is the random delay useful?
* what if the old leader isn't aware a new one is elected?
  * a new leader elected means a majority of servers have incremented currentTerm
  * so the old leader (w/ old term) can't get majority for AppendEntries
  * so the old leader won't commit or execute any new log entries
  * thus no split brain despite partition
  * but a minority may accept old server's AppendEntries so logs may diverge at the end of the old term

## Log synchronization after failures

* how can logs disagree?
  * a log might be short -- missing entries at end of the term
    leader of term 3 crashes before sending all AppendEntries
```
    S1: 3
    S2: 3 3
    S3: 3 3
```
  * logs might have different commands in same entry!
    after a series of leader crashes, e.g.
```
        10 11 12 13  <- log entry #
    S1:  3
    S2:  3  3  4
    S3:  3  3  5
```
  * new leader will force its log on followers; example:
    * S3 is chosen as new leader for term 6
    * S3 sends a new command, entry 13, term 6
    *   AppendEntries, previous entry 12, previous term 5
    * S2 replies false (AppendEntries step 2)
    * S3 decrements nextIndex[S2] to 12
    * S3 sends AppendEntries, prev entry 11, prev term 3
    * S2 deletes entry 12 (AppendEntries step 3)
    * similar story for S1, but have to go back one farther

* the result of roll-back:
  * each live follower deletes tail of log that differs from leader
  * thus live followers' logs are prefixes of leader's log
  * and live followers that keep up will have logs identical to leader's
    except they may be missing the few most recent entries

## New leader must be "up to date" 
* could new leader roll back *executed* entries from end of previous term?
  * i.e. could an executed entry be missing from the new leader's log?
  * this would be a disaster -- violates State Machine Safety
  * solution: Raft won't elect a leader that might not have an executed entry
* could we choose leader with longest log?
```
  example:
    S1: 5 6 7
    S2: 5 8
    S3: 5 8
```
  * first, could this scenario happen? how?
    * S1 leader in term 6; crash+reboot; leader in term 7; crash and stay down
      both times it crashed after only appending to its own log
    * S2 leader in term 8, only S2+S3 alive, then crash
  * who should be next leader?
    * S1 has longest log, but entry 8 could have been executed !!!
    * so new leader can only be one of S2 or S3
    * i.e. the rule cannot be simply choosing the "longest log"
* end of 5.4.1 explains "at least as up to date" voting rule
  * compare last entry -- higher term wins
  * if equal terms, longer log wins
  * so only S2 or S3 can be leader, will force S1 to discard 6,7
    * ok since no majority -> not executed -> no client reply
* the point:
  * "at least as up to date" rule ensures new leader's log contains
    * all potentially executed entries
  * so new leader won't roll back any executed operation

## More 
* why "log[N].term==currentTerm" in figure 2's Rules for Servers?
  * why can't we execute any entry that's on a majority?
    * how could such an entry be discarded?
```
  figure 8 describes an example
  S1: 1 2     1 2 4
  S2: 1 2     1 2
  S3: 1   --> 1 2
  S4: 1       1
  S5: 1       1 3
```
    * S1 was leader in term 2, sends out two copies of 2
    * S5 leader in term 3
    * S1 in term 4, sends one more copy of 2 (b/c S3 rejected op 4)
    * what if S5 now becomes leader?
      * S5 can get a majority (w/o S1)
      * S5 will roll back 2 and replace it with 3
    * so "present on a majority" != "committed"
* so an entry becomes committed if:
  * it reached a majority in the term it was initially sent out, or
  * if a subsequent log entry becomes committed.
     * *could* have committed if S1 hadn't lost term=4 leadership
* this is a consequence of:
  * the "more up to date" voting rule favoring higher term, and
  * the leader imposing its log on followers
* an important aside: 
  * can leader execute read-only operations locally?
    * without sending to followers in AppendEntries and waiting for commit?
    * very tempting, since r/o ops may dominate, and don't change state
  * why might that be a bad idea?
  * how could we make the idea work?

