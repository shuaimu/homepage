# Lab 2: Verified Replicated State Machine (Verus MultiPaxos)

## Introduction

In this lab you'll work with a **verified** MultiPaxos (RSL) implementation in [Verus](https://github.com/verus-lang/verus) (verified Rust), ported from Microsoft's [IronFleet](https://github.com/microsoft/Ironclad/tree/main/ironfleet) (Dafny).

A replicated state machine ensures that all replicas agree on the same sequence of operations, even in the presence of failures. MultiPaxos achieves this through a ballot-based voting protocol. The fundamental safety property is:

> **If two quorums each decide a value for the same operation, those values must be identical.**

Proving this property requires a sophisticated induction argument that tracks how values propagate across different ballots. In this lab, you will both **prove** this safety property and **implement** the protocol actions, all within Verus's verification framework.


## Objective

In this lab you'll complete three parts:

- **Part 1 — Protocol Safety Proof:** Complete 10 core proof lemmas establishing the safety of MultiPaxos.
- **Part 2 — Implementation + Refinement:** Implement 21 protocol action functions and prove each refines its specification. Build the system, run it with 3 servers and 32 clients, and report throughput/latency.
- **Part 3 — Performance Optimization (Bonus):** Optimize the verified implementation to achieve > 20K req/s while maintaining full verification.

Your task: **replace every `admit()` with actual proofs and implementations** so that `verus src/main.rs` reports 0 errors, and the system runs end-to-end.

Some general tips:

- Start early. Although the amount of code isn't large, getting Verus proofs to go through will be challenging.
- Read and understand the protocol specs in `src/protocol/RSL/` before you start. Your proofs should follow the spec closely, since that's what the verifier expects.

## Getting Started

We supply you with Rust skeleton code. All functions you need to complete have `admit()` as their body.

Go to [this link](https://classroom.github.com/a/60d1B7fa) to join the lab assignment. 

Similarly to lab 1, git clone your repo (except this time we already copied the code for you so you don't need to do that). You can stay on the main branch. For submit, commit your code with a message starting with "submit" (lower case).

To verify your work:

```bash
verus src/main.rs 2>&1 | tail -1
# Target: "verification results:: XXX verified, 0 errors"
```

To build and run:

```bash
scons --verus-path="$VERUS_PATH" --no-verify
```

## The Code

The codebase is organized into layers:

```
src/
  services/RSL/           # Entry point (paxos_main), application state machine (counter)
  protocol/RSL/           # Abstract spec: acceptor, proposer, learner, executor, election
    common_proof/         # Safety proof lemmas  <-- Part 1 edits here
    refinement_proof/     # Refinement proofs (provided)
  implementation/RSL/     # Concrete Rust implementation  <-- Part 2 edits here
  common/                 # IO framework, collections, logic
  verus_extra/            # Verus helper libraries
csharp/                   # .NET IO framework (server/client), calls Rust via FFI
```

Most of the work for this lab should be in:

- `src/protocol/RSL/common_proof/` (Part 1: proof lemmas)
- `src/implementation/RSL/acceptorimpl.rs` (Part 2: acceptor)
- `src/implementation/RSL/electionimpl.rs` (Part 2: election)
- `src/implementation/RSL/proposerimpl.rs` (Part 2: proposer)

You will also interact with the protocol spec files:

- `src/protocol/RSL/acceptor.rs` (spec for acceptor actions)
- `src/protocol/RSL/election.rs` (spec for election actions)
- `src/protocol/RSL/proposer.rs` (spec for proposer actions)

For the lab, you should implement proof and protocol logic in the files listed above. Do not modify the provided helper functions, spec definitions, or IO/FFI infrastructure.

### Refinement

Each implementation function has an `ensures` clause referencing a spec function:

```rust
pub fn CAcceptorProcess1a(&mut self, inp: CPacket) -> (sent: OutboundPackets)
    requires old(self).valid(), inp.valid(), inp.msg is CMessage1a
    ensures  self.valid(), sent.valid(),
             LAcceptorProcess1a(old(self)@, self@, inp@, sent@)  // <-- refines spec
{
    admit(); // TODO: replace
}
```

The spec defines **what** the function should do. You implement **how** in Rust with concrete types. Verus verifies the `@` (view/abstraction) of your output matches the spec.

### Available Helper Lemmas

These are provided (already proved) and available to call in your proofs:

**Behavior & Constants:**
- `lemma_ConstantsAllConsistent(b, c, i)` — constants consistent at step i
- `lemma_ReplicaConstantsAllConsistent(b, c, i, idx)` — per-replica consistency
- `lemma_AssumptionsMakeValidTransition(b, c, i)` — step i->i+1 is valid

**Packet Tracking:**
- `lemma_PacketStaysInSentPackets(b, c, i, j, p)` — once sent, always sent
- `lemma_PacketSetStaysInSentPackets(b, c, i, j, s)` — same for sets
- `lemma_ExtractSentPacketsFromIos(ios)` — connects IOs to sent packets

**Action Identification:**
- `lemma_ActionThatSends2aIsMaybeNominateValueAndSend2a(s, s', p)` -> (idx, ios)
- `lemma_ActionThatSends1bIsProcess1a(s, s', p)` -> (idx, ios)
- `lemma_ActionThatSends2bIsProcess2a(s, s', p)` -> (idx, ios)
- `lemma_ActionThatChangesReplicaIsThatReplicasAction(b, c, i, idx)` -> ios

**Message Properties:**
- `lemma_1bMessageImplicationsForCAcceptor(b, c, i, opn, p)` — 1b reflects acceptor state
- `lemma_2bMessageImplicationsForCAcceptor(b, c, i, p)` — 2b reflects acceptor state
- `lemma_VoteWithOpnImplies2aSent(b, c, i, idx, opn)` — vote exists -> 2a was sent
- `lemma_2aMessageHasValidBallot(b, c, i, p)` — ballot has valid seqno/proposer_id

**Quorum:**
- `lemma_GetIndicesFromNodes(nodes, config)` -> index set
- `lemma_GetIndicesFromPackets(packets, config)` -> index set

**Learner State:**
- `lemma_GetSent2bMessageFromLearnerState(b, c, i, idx, opn, sender)` — extracts a sent 2b
- `lemma_Received2bMessageSendersAlwaysValidReplicas(b, c, i, idx, opn)` — senders are valid

## Required Functionality

### Part 1: Protocol Safety Proof

Complete 10 proof lemmas in `src/protocol/RSL/common_proof/` that establish the safety of MultiPaxos. The top-level safety theorem (`lemma_ChosenQuorumsMatchValue`) depends on all others:

```
lemma_ChosenQuorumsMatchValue                          [chosen.rs]
|
+-- lemma_ChosenQuorumAnd2aFromLaterBallotMatchValues  [chosen.rs]
|   |   "If value v is chosen at ballot b, any 2a at higher ballot b'
|   |    has value v" (cross-ballot induction — THE HEART OF PAXOS)
|   |
|   +-- lemma_2aMessageHas1bQuorumPermittingIt         [message2a.rs]
|   +-- lemma_QuorumIndexOverlap                       [quorum.rs]
|   +-- lemma_1bMessageWithoutOpnImplicationsFor2b     [message1b.rs]
|   +-- lemma_1bMessageWithOpnImplies2aSent            [message1b.rs]
|   +-- lemma_Vote1bMessageIsFromEarlierBallot         [message1b.rs]
|   +-- (recursive call with smaller ballot)
|
+-- lemma_2aMessagesFromSameBallotAndOperationMatch    [message2a.rs]
|       (calls lemma_2aMessagesFromSameBallotAndOperationMatchWLOG)
|
+-- lemma_2bMessageHasCorresponding2aMessage           [message2b.rs]
```

Files to modify (all in `src/protocol/RSL/common_proof/`):

| File | Lemmas |
|------|--------|
| `message2b.rs` | `lemma_2bMessageHasCorresponding2aMessage` |
| `message1b.rs` | `lemma_Vote1bMessageIsFromEarlierBallot`, `lemma_1bMessageWithoutOpnImplicationsFor2b`, `lemma_1bMessageWithOpnImplies2aSent` |
| `quorum.rs` | `lemma_QuorumIndexOverlap` |
| `message2a.rs` | `lemma_2aMessagesFromSameBallotAndOperationMatch`, `lemma_2aMessagesFromSameBallotAndOperationMatchWLOG`, `lemma_2aMessageHas1bQuorumPermittingIt` |
| `chosen.rs` | `lemma_ChosenQuorumAnd2aFromLaterBallotMatchValues`, `lemma_ChosenQuorumsMatchValue` |

You are recommended to do the lemmas in this order:

| # | Lemma | Key Technique |
|---|-------|---------------|
| 1 | `lemma_2bMessageHasCorresponding2aMessage` | Induction on behavior prefix `i`. Base: sentPackets empty. Inductive: packet old -> recurse; new -> `lemma_ActionThatSends2bIsProcess2a`. |
| 2 | `lemma_Vote1bMessageIsFromEarlierBallot` | Similar induction. Use `lemma_VotePrecedesMaxBal`. |
| 3 | `lemma_QuorumIndexOverlap` | Pigeonhole on finite sets. Use `lemma_BoundedIntSetFinite` + `lemma_SetOfElementsOfRangeNoBiggerThanRange`. |
| 4 | `lemma_1bMessageWithOpnImplies2aSent` | Induction. When 1b newly sent, acceptor has vote -> `lemma_VoteWithOpnImplies2aSent`. |
| 5 | `lemma_1bMessageWithoutOpnImplicationsFor2b` | 4 cases: both old / 1b old + 2b new / 1b new + 2b old / both new (contradiction). |
| 6 | `lemma_2aMessagesFromSameBallotAndOperationMatch` | Delegates to WLOG (Without Loss Of Generality) helper. |
| 7 | `lemma_2aMessagesFromSameBallotAndOperationMatchWLOG` | Induction: both old -> recurse; one new -> trace to proposer, show uniqueness. |
| 8 | `lemma_2aMessageHas1bQuorumPermittingIt` | Induction: trace 2a to send step, extract proposer's `received_1b_packets` as quorum. |
| 9 | `lemma_ChosenQuorumAnd2aFromLaterBallotMatchValues` | Core induction. Uses all above. `decreases (ballot.seqno, ballot.proposer_id)`. |
| 10 | `lemma_ChosenQuorumsMatchValue` | Case-split on `q1.bal` vs `q2.bal`, call sub-lemmas. |

**Core proof intuition:**

- **Case b1 == b2:** Both quorums voted at the same ballot. By `lemma_2aMessagesFromSameBallotAndOperationMatch`, a proposer sends only one value per (ballot, opn). Values match.
- **Case b1 < b2 (WLOG):** The proposer at b2 collected a 1b quorum Q_1b. Q_1b and Q1 overlap (pigeonhole). The overlap replica voted at b1 and sent 1b to b2. The 1b must report the vote (contradiction otherwise). The proposer at b2 picks highest-ballot vote b_max where b <= b_max < b2. If b_max == b, value matches directly. If b_max > b, **recurse** with b_max (terminates since b_max < b2).

### Part 2: Implementation + Refinement

Implement 21 protocol action functions in `src/implementation/RSL/` and prove each refines its specification.

**`acceptorimpl.rs` — Acceptor:**

| Function | Refines | Description |
|----------|---------|-------------|
| `CAcceptorTruncateLog` | `LAcceptorTruncateLog` | Remove old votes below truncation point |
| `CAcceptorProcessHeartbeat` | `LAcceptorProcessHeartbeat` | Update last_checkpointed_operation |
| `CAcceptorProcess1a` | `LAcceptorProcess1a` | Compare ballot, send 1b with votes |
| `CAcceptorProcess2a` | `LAcceptorProcess2a` | Update votes, send 2b broadcast |

Given helpers (don't modify): `CAcceptorInit`, `CRemoveVotesBeforeLogTruncationPoint`, `CAddVoteAndRemoveOldOnes`, `CIsLogTruncationPointValid`

**`electionimpl.rs` — Election:**

| Function | Refines | Description |
|----------|---------|-------------|
| `CElectionStateReflectReceivedRequest` | `ElectionStateReflectReceivedRequest` | Track client request in epoch |
| `CElectionStateCheckForViewTimeout` | `ElectionStateCheckForViewTimeout` | Timeout + suspicion logic |
| `CElectionStateCheckForQuorumOfViewSuspicions` | `ElectionStateCheckForQuorumOfViewSuspicions` | Quorum check + view advance |
| `CElectionStateProcessHeartbeat` | `ElectionStateProcessHeartbeat` | Reset suspicion or suspect view |

Given helpers (don't modify): `CElectionStateInit`, `CComputeSuccessorView`, `CBoundRequestSequence`, `CRequestsMatch`, `CRequestSatisfiedBy`, `FindEarlierRequests`, `BoundCRequestHeaders`, `CRemoveAllSatisfiedRequestsInSequence`, `CRemoveExecutedRequestBatch`, `CElectionStateReflectExecutedRequestBatch`

**`proposerimpl.rs` — Proposer:**

| Function | Refines | Description |
|----------|---------|-------------|
| `CIsAfterLogTruncationPoint` | `LIsAfterLogTruncationPoint` | Check opn is after log truncation (HashSet loop) |
| `CSetOfMessage1b` | `LSetOfMessage1b` | Check all packets in set are 1b (HashSet loop) |
| `CSetOfMessage1bAboutBallot` | `LSetOfMessage1bAboutBallot` | Check all 1b packets match ballot (HashSet loop) |
| `CAllAcceptorsHadNoProposal` | `LAllAcceptorsHadNoProposal` | Check no votes for opn in 1b set (HashSet + votes) |
| `CExistsAcceptorHasProposalLargeThanOpn` | `LExistsAcceptorHasProposalLargeThanOpn` | Check existence of proposal > opn (HashSet loop) |
| `Cmax_balInS` | `Lmax_balInS` | Check ballot is max in 1b set (HashSet + votes + ballot) |
| `CProposerProcessRequest` | `LProposerProcessRequest` | Handle client request (HashMap get/insert + multi-branch) |
| `CProposerProcess1b` | `LProposerProcess1b` | Add 1b packet to received set |
| `CProposerMaybeEnterNewViewAndSend1a` | `LProposerMaybeEnterNewViewAndSend1a` | Start new ballot, broadcast 1a |
| `CProposerMaybeEnterPhase2` | `LProposerMaybeEnterPhase2` | Check 1b quorum, enter phase 2 |
| `CProposerMaybeNominateValueAndSend2a` | `LProposerMaybeNominateValueAndSend2a` | Decide whether to nominate |
| `CProposerNominateNewValueAndSend2a` | `LProposerNominateNewValueAndSend2a` | Pick new value from queue, send 2a |
| `CProposerNominateOldValueAndSend2a` | `LProposerNominateOldValueAndSend2a` | Highest-ballot value from 1b votes, send 2a |

Given helpers (don't modify): `CProposerInit`, `CProposerCanNominateUsingOperationNumber`, `CExistVotesHasProposalLargeThanOpn`, `CProposerProcessHeartbeat`, `CProposerCheckForViewTimeout`, `CProposerCheckForQuorumOfViewSuspicions`, `CProposerResetViewTimerDueToExecution`

You are recommended to implement in this order:

| # | Function | Notes |
|---|----------|-------|
| 1 | `CAcceptorTruncateLog` | Call `CRemoveVotesBeforeLogTruncationPoint`, update field |
| 2 | `CAcceptorProcessHeartbeat` | Update checkpoint array |
| 3 | `CAcceptorProcess1a` | Compare ballots, construct 1b |
| 4 | `CAcceptorProcess2a` | Update votes, construct 2b broadcast |
| 5 | `CSetOfMessage1b` | HashSet loop: check all elements are 1b |
| 6 | `CSetOfMessage1bAboutBallot` | HashSet loop: check all 1b match ballot |
| 7 | `CIsAfterLogTruncationPoint` | HashSet loop: check log truncation point |
| 8 | `CAllAcceptorsHadNoProposal` | HashSet loop + votes HashMap lookup |
| 9 | `CExistsAcceptorHasProposalLargeThanOpn` | HashSet loop: existence check |
| 10 | `Cmax_balInS` | HashSet loop + votes + ballot comparison |
| 11 | `CProposerProcessRequest` | HashMap get/insert, multi-branch logic |
| 12 | `CProposerProcess1b` | Add packet to received set |
| 13 | `CElectionStateReflectReceivedRequest` | Track request |
| 14 | `CElectionStateCheckForViewTimeout` | Timeout + suspicion logic |
| 15 | `CElectionStateCheckForQuorumOfViewSuspicions` | Quorum check + view advance |
| 16 | `CElectionStateProcessHeartbeat` | Longest election function |
| 17 | `CProposerMaybeEnterNewViewAndSend1a` | Start new ballot |
| 18 | `CProposerMaybeEnterPhase2` | Check 1b quorum |
| 19 | `CProposerMaybeNominateValueAndSend2a` | Nomination dispatcher |
| 20 | `CProposerNominateNewValueAndSend2a` | New value from queue |
| 21 | `CProposerNominateOldValueAndSend2a` | Highest-ballot from votes (HashSet iteration + loop invariants) |

Key implementation patterns:

- **Direct field mapping:** `self.max_bal = bal_1a;` maps to `s'.max_bal == inp.msg->bal_1a` in spec.
- **Broadcast construction:** Use `CBroadcast::BuildBroadcastToEveryone(...)` (already verified).
- **HashSet iteration:** Convert with `hashset_to_vec(...)`, iterate with `while` loop + invariants.
- **Assert refinement:** End each function with `assert(LAcceptorProcess1a(old(self)@, self@, inp@, sent@));`. Break into conjuncts if Verus can't prove it automatically.

### Part 3 (Bonus): Performance Optimization

Baseline: ~5K req/s. Target: > 20K req/s. All code must remain fully verified (0 admits, 0 assumes, no new `external_body` on logic functions).

Main bottlenecks and strategies:

| Bottleneck | Strategy |
|-----------|----------|
| `CAddVoteAndRemoveOldOnes` creates new HashMap every call | In-place HashMap mutation |
| `CRemoveVotesBeforeLogTruncationPoint` same pattern | In-place mutation |
| `CElectionStateReflectExecutedRequestBatch` recursive Vec rebuild | Loop-based single-pass filtering |
| `truncate_vec_crequest` / `concat_vec_crequest` element-by-element clone | `Vec::split_off` / `Vec::append` |

| Throughput | Bonus |
|-----------|-------|
| > 10K req/s | +5% |
| > 20K req/s | +10% |

## Compile and Test

Prerequisites:

- Verus (0.2026.02.04.175a879)
- rustc 1.80.1
- .NET 6.0 SDK
- scons (`pip install scons`)
- Python 3

Build:

```bash
# Verify + compile
scons --verus-path="$VERUS_PATH"

# Compile only (skip verification)
scons --verus-path="$VERUS_PATH" --no-verify
```

Run:

```bash
# Generate certificates (one-time)
dotnet bin/CreateIronServiceCerts.dll outputdir=certs name=MyCounter type=IronRSL \
    addr1=127.0.0.1 port1=4001 addr2=127.0.0.1 port2=4002 addr3=127.0.0.1 port3=4003

# Start 3 servers (separate terminals or background)
dotnet bin/IronRSLServerUDP.dll certs/MyCounter.IronRSL.service.txt certs/MyCounter.IronRSL.server1.private.txt &
dotnet bin/IronRSLServerUDP.dll certs/MyCounter.IronRSL.service.txt certs/MyCounter.IronRSL.server2.private.txt &
dotnet bin/IronRSLServerUDP.dll certs/MyCounter.IronRSL.service.txt certs/MyCounter.IronRSL.server3.private.txt &

# Wait for leader election (~15s), then run benchmark
sleep 15
dotnet bin/IronRSLClientUDP.dll ip1=127.0.0.1 ip2=127.0.0.1 ip3=127.0.0.1 nthreads=32 duration=30
```

Verify no admits or assumes remain:

```bash
# No admits in proof layer
grep -rn 'admit()' src/protocol/RSL/common_proof/ | wc -l          # Target: 0

# No admits in implementation
grep -rn 'admit()' src/implementation/RSL/acceptorimpl.rs \
    src/implementation/RSL/electionimpl.rs \
    src/implementation/RSL/proposerimpl.rs | wc -l                  # Target: 0

# No assumes anywhere
grep -rn '^\s*assume(' src/protocol/RSL/ src/implementation/RSL/ | wc -l  # Target: 0
```

## Submit

Commit your code to the repository. Include in your report:

- Verification output (`XXX verified, 0 errors`)
- Throughput and latency numbers from the 32-client, 30-second run

## Grading

| Criteria | Weight |
|----------|--------|
| **Part 1: Protocol Proof** — 10 lemmas, each verified = 4.5% | **45%** |
| **Part 2: Implementation + Run** — 21 functions, each verified = ~2%; build + benchmark = 3% | **45%** |
| **Part 3: Optimization (Bonus)** — > 10K = +5%, > 20K = +10% | **up to +10%** |

## DO NOT

Make sure you do not do any of the following; otherwise you will fail the labs, even if the code may pass verification.

- Modify provided helper functions, spec definitions, or IO/FFI infrastructure.
- Add `assume()` or keep `admit()` in any submitted code.
- Add new `external_body` annotations on logic functions (existing ones for IO/clone/hash are fine).