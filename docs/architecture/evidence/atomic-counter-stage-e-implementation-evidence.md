# Atomic Counter Stage E — recovery and composed-return evidence

Status: **Stage E Owner ACCEPTED 2026-10-19 following independent audit PASS;
B-1 CLOSED.** Recorded under the
[Owner-accepted consolidated workbook](../implementation_workbooks/atomic-counter-choice-lifecycle-consolidated-implementation-workbook.md).
Stage D was accepted and committed as `428e2b2`. Stage F checkpoint F1 is
separately authorized; final Stage F acceptance remains pending.

## Implemented boundary

- `AttackExecutor` resumes an exact, complete pending Counter publication at
  Counter Choice after GameState JSON reconstruction. It preserves the source
  and payload instead of projecting Resolve Damage. Missing board tokens for
  a destroyed Counter-eligible defender or destroyed original Squadron are
  reconstructed as hidden, presentation-only tokens from canonical Squadron
  state. `GameBoard` permits that original's retained activation through the
  active Counter child or legitimate **J**/no-**J** terminal release without
  inventing a gameplay owner.
- Squadron Move, Move-decline, and terminal completion validate that the
  satisfied inspection belongs to their canonical Squadron consumer.
  Accepted parent **I** remains reserved for child Begin; child **J** maps to
  the original defender. A destroyed original has no legal Move and can
  complete its retained activation, consuming **J** exactly once if present.
- The same owner-derived predicates cover live and reconstructed Squadron
  Phase exhaustion and commanded-Ship automatic exhaustion. An eligible
  commanded Squadron remains a live selection or voluntary-finish decision.
  Replay and passive Network reconstruction do not submit recovered commands.
  No new continuation field, FSM, queue, or scene authority was introduced.

## Focused verification — 2026-10-19

| Check | Result |
| --- | --- |
| Counter inspection/release unit suite: accepted **I** consumer rejection; **J**/no-**J** terminal release for destroyed original in both enclosing contexts; Save 11 and filtered Network reconstruction; surviving/destroyed Counter attacker; exact-once consumption | **17/17 PASS, 490 assertions** |
| Stage E production-composition integration: pending-choice GameState JSON and full-state hash, real `GameBoard` reload and `AttackExecutor` panel Accept/Decline, passive reconnect mirror submission in both player mappings, destroyed Counter defender and destroyed original/child reload, **J** reload and release, both Squadron Phase exhaustion shapes, Ship voluntary choice versus automatic advance, replay non-synthesis | **7/7 PASS, 224 assertions** |
| Full repository suite with normal app-data and Network access | **4,510 tests: 4,509 passing, one Stage F deferred version assertion; 25,756/25,757 assertions.** The sole failure is `test_replay_driver.gd:55`, which expects Replay 12 while production emits the accepted Replay 13. No Stage E test or unrelated state/hash test failed. |
| Diff whitespace check | **PASS** |

The saved and filtered Network checks use the existing Save 11 / Network 12
schemas. The integration tests prove exact Counter source propagation and
that pending-choice reload emits no second publication. Rejected inspection
consumers leave canonical state unchanged. Canonical hashes converge for the
tested pending-choice and **J** JSON reconstruction boundaries. No fixture,
baseline, expected hash, or historical Owner evidence was modified.

## Integrated and deferred gates

The existing Replay-12 expectation in
`tests/unit/test_replay_driver.gd` remains a Stage F current-format assertion
update; production `GameReplay` emits Replay 13. It is not a Stage E state or
command divergence.

The bounded existing `--counter-only` real-ENet run reached, on both peers in
mapping 0, Counter choice sequence 11, parent completion 12, child Begin 15,
child completion 21, **J** acknowledgements 23–24, original Squadron
completion 25, and enclosing Ship advances 26–27. The saved evidence reported
Network protocol 12 and inspection consumption. The runner still timed out
because its completion predicate requires the obsolete intermediate Resolve
Damage projection (`resolve_projection_seen`) and related old UI conditions.
This is a **bounded command-path observation, not a passing real-ENet
acceptance run**. Stage F owns runner renewal, both full role mappings,
Owner-recorded Replay-13 inputs, baselines, and manual evidence. Its current
runner and historical inputs remain unchanged.

## Independent audit blocker B-1 correction — 2026-10-19

The audit found that `AdvanceActivationStepCommand` could consume a satisfied
Counter parent inspection **I** or Counter-child inspection **J** after only a
matching inspection-ID check. A pure, purpose-specific
`GameState.validate_completed_attack_ship_consumer()` now checks the canonical
inspection source and Ship attacker, exact player/index, active Ship activation
identity and phase, inactive current attack, and the ordinary Ship release
conditions. Only an ordinary Ship inspection may accompany `maneuver_step`.
Counter **I**/**J** cannot accompany `attack_step`, `maneuver_step`, or
`activation_done`, even with the exact inspection ID. The command invokes the
guard in `validate()` before activation, inspection, flow, history, sequence,
or observer follow-up mutation. Existing Squadron consumer validation is
unchanged.

Direct and genuine GameCommand JSON-roundtrip regressions cover **I**, **J**,
`attack_step`, `activation_done`, exact but unauthorized IDs, wrong Ship,
controller and stale source, plus successful ordinary Ship-to-Maneuver
consumption. Rejections compare serialized canonical state, interaction flow,
inspection, submitted payload, command history count, sequence, and observer
follow-up count before and after submission.

| B-1 verification | Result |
| --- | --- |
| New direct/JSON Ship inspection-consumer regressions | **3/3 PASS, 408 assertions** |
| Existing Stage E Counter inspection/release unit suite (normal app-data access) | **17/17 PASS, 490 assertions** |
| Existing Stage E recovery integration suite | **7/7 PASS, 224 assertions** |
| Ship activation command, controller, integration, and production-resume regressions | **6/6 (23 assertions), 14/14 (100), 23/23 (82), 98/98 (2,871) PASS** |
| Full repository suite (normal app-data and Network access) | **4,513 tests: 4,512 passing, one Stage F deferred Replay-version assertion; 26,164/26,165 assertions** |

The sole full-suite failure remains `tests/unit/test_replay_driver.gd:55`:
the current Replay 13 version is compared with the historical Replay 12 test
expectation. This is the pre-existing Stage F assertion renewal, with no B-1
or other Stage E failure. The prior focused Save-11 run in the restricted
sandbox could not write its `user://` save file; rerunning with normal app-data
access passed 17/17. No fixture, baseline, expected hash, or historical Owner
evidence changed.

The Owner accepted this Stage E implementation and evidence following the
targeted independent B-1 re-audit. Stage F checkpoint F1 is separately
authorized; fixture recording, baseline/hash promotion, and final Stage F
acceptance remain separate Owner checkpoints.
Final integrated acceptance remains unavailable until Stage F verification
and genuine Owner recording obligations are met.
