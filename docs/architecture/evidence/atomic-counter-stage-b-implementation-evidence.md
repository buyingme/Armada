# Atomic Counter Stage B — command admission implementation evidence

Status: **Stage B Owner ACCEPTED 2026-10-18; independent audit PASS; B-1
CLOSED.** Recorded 2026-10-18 under the
[Owner-accepted consolidated workbook](../implementation_workbooks/atomic-counter-choice-lifecycle-consolidated-implementation-workbook.md).
The Owner accepted Stage A and authorized Stage B on 2026-10-18. At that
implementation checkpoint, Stages C–F were unauthorized.

## Implemented boundary

- Reused the preserved Boundary B `AttackPublicationPayloadIntegers` policy,
  command JSON copy, pure publication preflight, and narrow Escort
  `target_player` correction. The preflight remains before publication rule
  hooks and does not mutate the submitted payload.
- Added the accepted pure installed-Counter guard at preflight and command
  validation. No direct or JSON publication may duplicate, downgrade, replace,
  or finally clear an installed Counter-choice projection. A new Counter
  publication must match the active resolved parent, Squadron owners,
  disposition, source, controller, exact BLUE pool, and native canonical
  requested damage. Only accepted predecessor routes are admitted.
- Added a pure `counter_choice` safe-shape, source, undecided-parent, and
  complete-installed-flow guard before the registered Counter rule hook.
  Command validation repeats the guard and checks phase, controller, exact
  participants, and rule legality. Genuine JSON decoding restores nested
  `counter_dice_pool` integers. Choice execution and continuation remain
  Stage D work.
- Removed three synthetic-test collisions with the real publication command
  type: the command-processor failing stub, rule-order observer follow-up, and
  timing-window opening fixture now use existing declared command names. The
  timing fixture uses an ordinary remotely recognized marker in the Network
  test. Production publication validation was not relaxed.

## Verification

Focused suites run on 2026-10-18:

| Suite | Result |
| --- | --- |
| New Stage B direct/JSON complete-publication, exact flow/full-state hash, owner-backed enclosing predecessor, decided parent and inspection protection, malformed choice, hook-safety, and atomic-rejection tests | **6/6 PASS, 351 assertions** |
| Preserved Boundary B integer and Escort tests, adapted to inspect immutable Replay-12 commands through the codec rather than load an obsolete replay header | **8/8 PASS, 452 assertions** |
| Publication command and Counter marker validation | **15/15 PASS (36 assertions); 9/9 PASS (21)** |
| Counter executor and Coolant Discharge rules | **11/11 PASS (70); 11/11 PASS (42)** |
| Synthetic command processor, rule-order replay, and timing-window Network/shared protocol | **9/9 PASS (26); 3/3 PASS (12); 7/7 PASS (84)** |
| Stage A exact state/reconstruction regression | **4/4 PASS, 141 assertions** |

Total focused evidence: **83/83 PASS, 1,235 assertions**. Registered Counter,
Escort, and Coolant Discharge hooks were active for malformed direct and JSON
cases. A probe validator confirms wrong-container and malformed declared
integer or choice inputs are rejected before hook invocation. Rejected
submissions retain canonical state and flow digests, history, sequence,
observer follow-up count, and the submitted payload.

The full suite with normal user-data access reached **4,485 tests: 4,469
passing, 16 failing**. The 19 previously diagnosed synthetic-publication
failures no longer occur. Fifteen failures are the known obsolete
`test_counter_inspection_release.gd` two-publication/inspection assertions,
assigned to Stages D/E; the remaining `test_replay_driver.gd` assertion still
expects historical Replay 12, assigned to Stage F. The first sandboxed
full-suite run had unrelated user-data write failures and is not convergence
evidence. This full-suite run preceded the final focused enclosing-predecessor
and decided-inspection specimens; those additions passed the focused Stage B
run above. Full-suite convergence remains mandatory at the integrated gate.

## Limits and next gate

Stage C must install the accepted atomic ordered publication producer and
trusted Network origin. Stage D must commit source-bound decisions and update
the real UI submitters. Stage E owns board reload/recovery; Stage F owns
Owner-recorded Replay-13 inputs, current runners, baselines, full-suite and
real-ENet convergence. This Stage B evidence does not authorize those stages
or promote any fixture, trace, or hash. Save 11 / Network 12 / Replay 13
constants remain as Stage A accepted; historical files and expected hashes
were not changed.

## B-1 predecessor-consistency audit correction — 2026-10-18

The targeted Stage B audit found that the initial predecessor gate checked an
installed Attack flow's step and `attack_id`, but not its agreement with the
canonical parent and retained Squadron activation. `PublishAttackFlowCommand`
now checks the **installed** flow independently of the candidate Counter
payload before admission. It requires the resolved parent, completed defense
and damage facts, active original Squadron action, matching phase controller
or commanding Ship, and the correct route controller. For the three Attack
steps it compares every present retained participant, dice, locked-token, and
final-damage field with canonical owners. For the Squadron Phase and Ship
Command routes it compares present source, participant, and activation identity
fields.
The candidate remains subject to the separate complete Counter policy. The
check is pure and adds no state owner or new route.

Direct and genuine JSON command tests now exercise all five accepted routes
positively and reject same-source wrong source, controller, participant,
phase, defense fact, and projection specimens. Rejection checks unchanged
canonical state and flow, command history, sequence, observer follow-up
queue, and submitted payload. The focused Stage B matrix is **85/85 PASS,
2,140 assertions** across the ten suites listed above. The enlarged Stage B
test alone is **8/8 PASS, 1,256 assertions**. A direct GUT run exited zero;
one shell-wrapper invocation printed the passing GUT summary but exited on a
broken pipe while echoing its large captured output. The final full-suite run
with normal user-data access is **4,489 tests: 4,473 passing, 16 failing;
24,713/24,782 assertions**. The same fifteen Counter inspection/child-release
tests remain assigned to Stages D/E, and the one Replay-version expectation
remains assigned to Stage F. No new B-1 failure appeared. The targeted
independent re-audit subsequently passed, as recorded below.

## Owner implementation acceptance — 2026-10-18

The Owner accepted Stage B after independent audit PASS and closed B-1.
The accepted Stage A/B implementation and evidence are isolated in commit
`e7f48fe`. Stage C is separately authorized under the consolidated workbook;
Stages D–F remain unauthorized. This checkpoint does not accept the deferred
full-suite failures or authorize fixture, baseline, hash, or historical
evidence changes.
