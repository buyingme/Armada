# Atomic Counter Stage C — ordered publication implementation evidence

Status: **Stage C Owner ACCEPTED 2026-10-19 after independent audit PASS.**
Recorded 2026-10-19 under the [Owner-accepted consolidated workbook](../implementation_workbooks/atomic-counter-choice-lifecycle-consolidated-implementation-workbook.md).
Stage D is separately authorized; Stages E/F remain unauthorized.

## Implemented boundary

- `CurrentAttackContinuation` derives one detached, complete Counter-choice
  publication from the resolved parent Attack, canonical Squadron owners, and
  the installed same-source predecessor. It uses canonical
  `resolved_outcome.requested_hull_damage` for `final_damage`, including zero
  and values above remaining hull. Accepted `resolve_damage` selects that
  publication instead of parent completion; reconstruction can derive a lost
  publication once from the same owners.
- `AttackExecutor` no longer advances or publishes an intermediate local
  Counter-eligible damage flow, patches `final_damage`, or submits the obsolete
  two-publication Counter choice from its damage callback. Its post-command
  Counter work is presentation only. The accepted publication restores the
  transient local FSM projection without changing canonical state.
- Live Network ingress and the host player submitter reject player-originated
  Counter-step publications. The host authoritative follow-up route remains
  available after accepted damage and broadcast. Recorded replay retains
  ordinary deterministic command validation. Stage B publication and hook
  validation remains unchanged.

## Verification — 2026-10-18 to 2026-10-19

| Check | Result |
| --- | --- |
| Stage C focused unit: zero/positive/excess requested damage, accepted command order and observable boundaries, exact JSON full-state hash, lost-publication reconstruction, malformed canonical damage, direct/JSON host player-route rejection | **4/4 PASS, 103 assertions** |
| Existing Counter executor, Stage B admission, Boundary B integer, Network manager and transport focused suites, including decoded live peer ingress rejection before processing | **90/90 PASS, 1,917 related-suite assertions** (Owner-corrected audit aggregate; suite tests 11/11, 8/8, 8/8, 49/49, and 14/14 respectively) |
| Full suite with normal user-data and ENet access | **4,494 tests: 4,478 passing, 16 failing; 24,823/24,892 assertions** |
| Real ENet Counter scenario prefix, both host/client role mappings | Host and client each applied `resolve_damage` sequence 9 before exactly one complete `publish_attack_flow` sequence 10. Both saw the actionable Counter projection; neither recorded an intermediate Resolve Damage publication. |
| Diff whitespace check | **PASS** |

The 16 full-suite failures match the pre-Stage-C deferred set: fifteen
`test_counter_inspection_release.gd` assertions require Stage D/E decision,
child, inspection, and return semantics; the Replay version assertion in
`test_replay_driver.gd` requires Stage F current-format fixture renewal. The
first sandboxed full-suite invocation had extra file-write and ENet failures;
the result above is from the normal-access rerun.

The existing full Counter ENet scenario timed out **after** the Stage C
boundary, following accepted choice, parent completion, inspection
acknowledgment, and child Begin. Its legacy child-flow callback attempted two
publications rejected by the accepted installed-Counter guard. These are
Stage D/E child and retirement obligations, not additional damage-boundary
publications. The acceptance runner's full scenario remains pending; the
Stage C ordering evidence comes from retained temporary host/client logs for
both mappings. Mapping 0 came from the original `--counter-only` runner attempt.
Mapping 1 came from a **separate bounded rerun** of the existing
`counter_release` driver with `--mapping=1` and independent host/client
processes, using a different temporary diagnostic directory. Its sequence
9/10 result is not attributed to the original runner directory. No runner,
fixture, baseline, expected hash, or historical Owner evidence was changed.

## Remaining gates

Stage C independent audit and Owner acceptance are complete. Stage D now
owns source-bound single-use choice and child transition; Stage E owns
reconstruction, board reload, inspection release, and composed return. Stage F
requires genuine Owner-recorded current-format replay inputs, baseline and
runner convergence, full-suite convergence, and full real-ENet acceptance.
This record does not authorize Stage E/F or any fixture/hash promotion.
