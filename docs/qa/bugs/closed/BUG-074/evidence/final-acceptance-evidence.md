# BUG-074 Final Acceptance Evidence

Status: Owner accepted and resolved — BUG-074 closed
Owner manual gameplay decision: PASS — 2026-10-15

## Immutable Owner evidence

- [Successful Network Replay-12](../replay_20261015_065840.json)
- [Successful Network session log](../game_20261015_065610.log)

Reviewed SHA-256 identities:

- replay: `30e0750993d45db158fcc37b08911a485fe03d824e108c9abf94db731d3f5d92`
- log: `dd4abbe6c4b6d6ccd90ce34ee09751f102f46553decff79202fc6452e2546cbd`

The files above are Owner-controlled originals. This report does not transform,
repair, patch, re-sign, or replace them.

## Verified manual lifecycle

The format-12 replay records the destroyed-Counter acceptance path:

1. parent `attack:47` reaches authoritative damage resolution at commands
   `55–57`; the three-damage result destroys the TIE Interceptor;
2. commands `58–59` expose the parent-source Counter choice to Player 1 with
   the exact Counter 2 pool;
3. command `60` accepts Counter;
4. commands `61–63` complete the parent and satisfy exact inspection
   `completed:attack:47` through both acknowledgements;
5. authoritative command `64` explicitly begins Counter child `attack:64` and
   consumes that exact parent inspection;
6. commands `65–66` publish locked Declare and Roll for the child with the
   canonical TIE Interceptor attacker, X-wing target, and two blue dice;
7. commands `67–70` execute the ordinary applicable Roll, confirmation,
   accuracy, and damage path;
8. commands `71–74` complete the child, publish its exact terminal clear, and
   satisfy inspection `completed:attack:64` through both acknowledgements; and
9. command `75` consumes inspection J in the original X-wing Squadron
   activation, after which command `76` reaches the next stable enclosing
   Status Phase.

The replay therefore proves destroyed-attacker eligibility, accepted choice,
explicit child Begin, locked entry, ordinary child resolution, exact
acknowledgements, J release, and composed return beyond the original Squadron
activation.

## Integrity and convergence evidence

- The replay header declares format 12, Network principal binding, the Debug
  Scenario, and a contiguous 83-command history.
- Ordinary `ReplayDriver` loading executed all 83 commands and exhausted the
  history successfully, producing final state hash
  `a0098afffb023b9d3b89151ee19fe3365c7f65ab68562b5f84ed87392d7fdcea`.
- The permanent Network replay fixture independently passed real-ENet
  host/client state equality with hash
  `1d0bb7d11639c7632bb7106db0400ffbeab7858b233335c55ce7afeb18f0db53`.
- The Owner-approved broader Hot-Seat canonical-state rebaseline was promoted
  without changing its Replay-12 input or command trace. Post-promotion
  verification passed trace byte equality and final-state hash equality at
  `582100885f33fcdf4a308c6ef83e3419ce74db8f26c7b94aa13ed02434d90ac8`;
  the same run retained the Network peer-equality result above. The
  [approval record](../../../../../architecture/evidence/hot-seat-baseline-canonical-state-rebaseline-approval-record.md)
  preserves that the historical canonical drift from `87c9…` is not fully
  classified.
- The accepted workbook retains automated coverage of all eight combinations
  of surviving/destroyed attacker, Accept/Decline, and both Network mappings,
  plus focused/full convergence, Save 10, reconnect, protocol 11, and replay
  format 12 verification.

## Owner acceptance refinement

The Owner decision of 2026-10-15 supersedes the former requirement for three
additional Owner-recorded format-12 Counter histories: surviving Accept,
surviving Decline, and destroyed Decline. Those variations are recorded in the
GGS assurance backlog. The deferral does not weaken automated real-ENet
coverage, authorize GGS-001 Gate 2, or establish GGS as a replacement for
Replay-12 assurance.

The independent final closure audit passed. No BUG-074 acceptance obligation
remains open, and BUG-074 is resolved in the closed defect archive.
