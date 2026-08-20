# BUG-035 — Attack result acknowledgement does not resume gameplay and leaves stale result UI

Severity: High
Area: Completed-attack result acknowledgement / post-attack continuation
Layer: Command Flow

## Expected

After a completed attack result is acknowledged, the canonical completed-attack
inspection should either:

- release exactly one applicable authoritative continuation transaction; or
- expose the next legal derived gameplay opportunity,

according to the accepted ADR-007 / CON-007 continuation model.

The completed result UI must then leave its active interaction state and the game
must resume from canonical gameplay state.

This must work consistently for both ship and squadron attacks.

## Actual

During Hot-Seat verification, both tested attack contexts stalled after the
completed result was acknowledged:

1. a squadron attack performed as part of a ship Squadron command; and
2. a normal ship-to-ship attack.

In both cases the result acknowledgement itself appears to execute, but the
visible attack-result interaction remains and gameplay does not resume correctly.

The two reproductions show slightly different canonical states after the stall,
which is useful evidence that the defect may lie in the common release/recovery
path rather than in one attack-type-specific transaction.

### Squadron reproduction

The replay shows:

- seq 77 — `complete_attack`
- seq 78 — `acknowledge_attack_result`
- seq 79 — `complete_squadron_activation`

Thus the authoritative acknowledgement and the expected squadron continuation
transaction both executed.

Nevertheless the UI remained on the attack result and gameplay appeared stalled.

The captured state showed:

- no remaining `completed_attack_inspection`;
- inactive `CurrentAttackState`;
- completed squadron activation;
- stale attack-related `interaction_flow`.

### Ship-to-ship reproduction

The log shows:

- seq 88 — `complete_attack`
- seq 89 — `acknowledge_attack_result`

No subsequent post-acknowledgement continuation command is logged before the
stall was annotated.

The captured state shows:

- `CurrentAttackState` is inactive;
- `completed_attack_inspection` still exists;
- its required and received principal sets are equal, so the inspection is
  satisfied;
- the attacking ship remains in its active attack step with one committed
  attack;
- stale attack-related `interaction_flow` remains projected.

This indicates that the acknowledgement succeeded but the satisfied inspection
was not released/consumed into the applicable normal-ship continuation path.

Taken together, the evidence suggests a defect in the common
post-acknowledgement release / controller / projection recovery path. The exact
root cause is not yet proven.

## Reproduction

Currently reproduced manually in two Hot-Seat attack contexts.

### A. Ship-commanded squadron attack

1. Start a Hot-Seat game.
2. Activate a ship with a Squadron command.
3. Activate and move a squadron through that command.
4. Attack an enemy squadron.
5. Complete the attack.
6. Acknowledge the completed attack result.
7. Observe that the result UI remains and gameplay does not recover correctly.

Observed identifiers:

- ship activation: `ship-activation:68`
- squadron activation: `squadron-activation:70`
- attack: `attack:72`
- inspection: `completed:attack:72`

### B. Normal ship-to-ship attack

1. Start a Hot-Seat game.
2. Activate a ship and enter its Attack step.
3. Perform a normal ship-to-ship attack.
4. Complete the attack.
5. Acknowledge the completed attack result.
6. Observe that the result UI remains and gameplay stalls.

Observed identifiers:

- ship activation: `ship-activation:79`
- attack: `attack:82`
- inspection: `completed:attack:82`

Reproduction frequency: reproduced in both tested post-UX-005 attack contexts.
Further attack variants have not yet been manually verified.

## Evidence

### Squadron attack

- `annotation_20260819_081027_001.json`
- `replay_20260819_081030.json`
- `game_20260819_080625.log`

Key command evidence:

- `complete_attack` seq 77
- `acknowledge_attack_result` seq 78
- `complete_squadron_activation` seq 79

### Ship-to-ship attack

- `annotation_20260819_081703_001.json`
- `game_20260819_081532.log`

Key command evidence:

- `begin_attack` seq 82
- `resolve_damage` seq 87
- `complete_attack` seq 88
- `acknowledge_attack_result` seq 89
- no subsequent continuation transaction observed before annotation

Captured ship-attack state additionally proves that:

- inspection `completed:attack:82` is satisfied;
- `received_principal_ids == required_principal_ids`;
- `CurrentAttackState` is inactive;
- the attacking Victory II retains `attack_step_active == true`;
- `committed_attack_count == 1`;
- hull zone FRONT is already recorded as used;
- stale attack `interaction_flow` is still present.

## Resolution

Status: Repaired and automated verification complete; manual Hot-Seat
confirmation appropriate.

Root cause:
Two distinct release outcomes had correct canonical command state but missing
presentation recovery:

1. A normal ship attack with a legal second declaration is CON-007's
   derived-only outcome. The satisfied inspection correctly remains for the
   selected `BeginAttackCommand`, but no live result route invoked the existing
   canonical-state declaration recovery; the retired result flow stayed shown.
2. A ship-commanded squadron attack correctly queued and executed
   `CompleteSquadronActivationCommand`, including atomic inspection
   consumption. The command restored the canonical `SHIP_ACTIVATION /
   SQUADRON_STEP` projection, but `ModalRouter` only reopened that projection
   for the original `advance_activation_step` entry command. It therefore
   failed to present the same already-OPEN opportunity after a completed
   commanded squadron. Retrying the visible Squadron step submitted a second
   `AdvanceActivationStepCommand`, which correctly rejected the already-
   reached opportunity. The ship mutation and committed count were not the
   cause: remaining capacity is derived from the canonical ship, and the
   opportunity remains OPEN until the normal Squadron-to-Repair transition.

The two-human Network evidence is the same first case after the second required
acknowledgement. It is not a principal-binding, acknowledgement-delivery, or
mirror-synthesis failure.

Fix:
After a satisfied acknowledgement, `AttackPanelController` now reuses the
existing canonical-state declaration projection only for a derived normal-ship
opportunity. It selects and submits no command. The existing
`CompleteSquadronActivationCommand` restores the enclosing Ship
Squadron-step projection only after its successful atomic mutation and
inspection consumption; command-result routing clears retired attack UI after
that consumer and after the existing Attack-to-Maneuver consumer.

The router now also treats `CompleteSquadronActivationCommand` as a
presentation recovery trigger for the canonical `SQUADRON_STEP` projection.
It opens the existing command-mode squadron presentation from the live
`ShipInstance` disposition and derived capacity; it submits no activation-step
command. The final legal commanded squadron still follows the existing normal
Squadron-to-Repair command transition, which consumes the OPEN opportunity.

No timer, scene callback, or presentation path advances gameplay.

Any fix must preserve:

- ADR-007 authoritative completed-result inspection ownership;
- CON-007 context-specific continuation ownership;
- exact-once inspection consumption;
- live-authority-only continuation synthesis;
- replay and passive-mirror non-synthesis;
- no timer or presentation-owned gameplay progression.

Do not restore the retired local acknowledgement/finalization path as a
workaround.

Initial repair verification (before the terminal projection regression):
Focused checks passed:

- `tests/integration/test_current_attack_production_resume.gd`: 45/45. The
  strengthened normal-ship regression proves a satisfied derived-only
  inspection is retained, the flow returns to `ATTACK_DECLARE`, and stale
  result UI returns to legal target selection without a synthetic command.
- `tests/integration/test_current_attack_shared_protocol.gd`: 25/25, including
  authoritative/mirror/replay ordering and exact-once anti-squadron consumer
  coverage.

Repository verification at that stage: full GUT suite 238 scripts / 4,069 tests /
13,784 asserts; Phase-K architecture lint 0 violations (4 existing
allow-listed branches); and `git diff --check` clean.

Residual commanded-squadron regression:

- `test_commanded_squadron_completion_reopens_existing_opportunity` enters a
  ship Squadron opportunity, completes the first commanded squadron through
  `CompleteSquadronActivationCommand`, verifies its one-time completion and
  OPEN disposition/count, activates a second legal squadron without a second
  `squadron_step` advance, then verifies the normal single transition to
  Repair consumes the opportunity and no attack presentation remains.

Final verification:

- `tests/integration/test_current_attack_production_resume.gd`: 46/46, 877
  assertions.
- `tests/integration/test_current_attack_shared_protocol.gd`: 25/25, 1,058
  assertions; `tests/integration/test_squadron_attack_target_recovery.gd`:
  18/18, 435 assertions; `tests/unit/test_squadron_command_resolver.gd`:
  19/19, 91 assertions.
- Full GUT suite: 238 scripts / 4,070 tests / 13,816 assertions, all passing.
- Phase-K architecture lint: 0 violations (4 existing allow-listed branches).
- `git diff --check`: clean.

Regression coverage must include at minimum:

1. normal ship-to-ship attack acknowledgement;
2. ship-commanded squadron attack acknowledgement;
3. acknowledgement satisfaction occurs exactly once;
4. the correct context-specific continuation is selected or the next legal
   opportunity is derived;
5. satisfied inspection is consumed exactly once when mutation occurs;
6. stale result interaction/projection is cleared;
7. result modal closes/rebuilds correctly;
8. gameplay resumes from canonical state;
9. no duplicate continuation is submitted;
10. replay reproduces the same post-acknowledgement state;
11. Hot-Seat manual verification for both ship and squadron attacks;
12. later two-human Network verification after Hot-Seat behavior is corrected.

## Scope / Reproduction Status

BUG-035 is now confirmed in both Hot-Seat and two-human Network play.

Manual verification has reproduced the same post-attack stall for:

- Hot-Seat ship-commanded squadron-to-squadron attack;
- Hot-Seat ship-to-ship attack;
- Network ship-to-ship attack.

Network ship-to-squadron testing was not repeated after the ship-to-ship
reproduction because the same completed-attack inspection/release failure was
already reproduced across both play modes and both tested Hot-Seat attack
contexts.

The defect therefore should not be treated as a Hot-Seat-specific presentation
problem.

## Additional Network Reproduction — 2026-08-19

Mode: two-human Network
Context: ship-to-ship attack
Attack: Victory II-class Star Destroyer → CR90 Corvette A
Attack ID: `attack:42`
Inspection ID: `completed:attack:42`

The attack resolves normally and creates the completed-attack inspection.

Both human principals then acknowledge the result.

The game nevertheless stalls instead of releasing the completed inspection and
continuing the attacking ship's activation.

### Network Evidence

- `annotation_20260819_111334_001.json`
- `replay_20260819_111345.json`

The annotation snapshot is especially significant because the canonical
completed inspection records:

- two required HUMAN principals;
- the same two principals in `received_principal_ids`;
- therefore acknowledgement satisfaction has already been reached;
- `current_attack_state.active = false`;
- the attacking Victory remains in its active ship activation;
- `attack_step_active = true`;
- `committed_attack_count = 1`;
- `maneuver_opportunity_disposition = "UNREACHED"`.

Despite the inspection being satisfied, it remains installed and no subsequent
canonical continuation has occurred.

The replay independently confirms the sequence:

1. `complete_attack` — sequence 71
2. attacker `acknowledge_attack_result` — sequence 72
3. defender `acknowledge_attack_result` — sequence 73
4. no post-acknowledgement continuation command follows

This narrows the defect substantially.

The Network reproduction does **not** appear to be caused by a missing remote
acknowledgement or principal-binding mismatch. Both required acknowledgements
reach authoritative command history and the canonical inspection records both
principals as having acknowledged.

The failure is therefore at or after the transition:

`inspection satisfied`
→ `authoritative release evaluation`
→ `continuation selection`
→ `atomic inspection consumption + continuation mutation`

The exact failing seam remains to be established by implementation
investigation.

## Updated Initial Assessment

Evidence now supports treating BUG-035 as a shared completed-attack
continuation/release defect rather than a mode-specific UI defect.

The implementation should investigate why a satisfied
`CompletedAttackInspection` does not trigger the CON-007 / UX-005
post-success release path.

In particular, determine whether:

- acknowledgement satisfaction is detected after the final
  `AcknowledgeAttackResultCommand`;
- the CommandProcessor post-success release evaluator runs after that command;
- the correct continuation is derived for the enclosing attack context;
- a continuation is derived but rejected or discarded;
- inspection consumption and the continuation mutation fail their atomic
  validation;
- presentation remains stalled merely as a consequence of the missing
  canonical continuation.

Do not introduce presentation-side continuation, timers, callbacks, or a second
continuation authority to repair the defect.

The repair must preserve the accepted ADR-007 / CON-007 model:
canonical acknowledgement satisfaction followed by authoritative,
exact-once release and atomic inspection consumption.

### Manual Retest After First Repair — 2026-08-19

The first BUG-035 repair improved the observed failure but did not fully resolve
the ship-commanded squadron continuation.

After acknowledging the completed attack result:

- the completed inspection is consumed;
- the retired attack-result presentation is cleared;
- `CompleteSquadronActivationCommand` completes the first commanded squadron;
- control returns toward the enclosing ship activation.

However, the second squadron permitted by the ship's Squadron command cannot be
activated.

The player can only escape the stalled Squadron-command flow by skipping from
the ship activation modal, which incorrectly advances the ship beyond the
remaining Squadron-command activation opportunity.

Evidence:

- `annotation_20260819_113852_001.json`
- `game_20260819_113641.log`

Captured canonical state after the failed continuation:

- `completed_attack_inspection` is empty;
- `CurrentAttackState` is inactive;
- the first commanded squadron remains associated with
  `squadron-activation:70`;
- the commanding Nebulon retains `ship-activation:68`;
- `squadron_command_activations_committed == 1`;
- `squadron_command_opportunity_disposition == "CONSUMED"`;
- `maneuver_opportunity_disposition == "OPEN"`.

The ship's Squadron value permits a second commanded squadron activation, so
the enclosing flow should offer that remaining activation rather than require
the player to skip the Squadron step.

The log additionally shows that after the completed squadron activation the
presentation returns to the ship activation flow, but attempting to execute the
Squadron step again submits an activation-step transition which is rejected:

`Command rejected [advance_activation_step]: Squadron-command opportunity was already reached.`

This indicates that the first repair fixed stale attack-result recovery but did
not correctly reconstruct or continue the already-reached Squadron-command
opportunity.

The remaining root cause must be determined from canonical activation semantics.
In particular, investigate whether:

1. `CompleteSquadronActivationCommand` incorrectly marks the whole
   Squadron-command opportunity consumed after one squadron activation; or
2. the canonical state is correct and the presentation/controller incorrectly
   attempts to re-enter an already-reached Squadron step instead of presenting
   the remaining activation inside that opportunity; or
3. both state mutation and reconstruction contribute to the defect.

Do not work around this by allowing duplicate `AdvanceActivationStepCommand`
execution or by making the UI own remaining Squadron-command capacity.

The repair must continue to use the canonical ship activation identity,
Squadron-command opportunity disposition, and committed-activation count.

### Manual Retest — Normal Ship Continuation Passes

A follow-up Hot-Seat normal ship-to-ship attack test passed after the first
BUG-035 repair.

Evidence:

- `annotation_20260819_123722_001.json`

The test confirms:

- the completed inspection is no longer left stuck;
- the derived-only second-attack opportunity is recovered correctly;
- gameplay resumes from canonical ship activation state;
- the original normal-ship BUG-035 manifestation is resolved in Hot-Seat.

This narrows the remaining defect to the ship-commanded squadron continuation
path documented above.

Current residual scope:

- Hot-Seat normal ship-to-ship continuation: PASS after first repair.
- Hot-Seat ship-commanded squadron continuation: FAIL; second allowed squadron
  activation cannot be entered correctly after the first commanded squadron
  completes.
- Network normal ship-to-ship continuation: pre-repair failure known; post-repair
  verification still pending.
- Network ship-commanded squadron continuation: not yet retested post-repair.

### Manual Retest After Second Repair — Terminal Squadron-Command Projection Still Incorrect

The commanded-squadron gameplay sequence now completes functionally, including
both permitted squadron activations.

However, after acknowledgement and completion of the second commanded squadron,
the UI incorrectly opens another Squadron activation modal showing:

`activation 3 of 2`

Evidence:

- `annotation_20260819_133359_001.json`
- `game_20260819_133130.log`

At this point canonical state already records:

- `completed_attack_inspection` empty;
- `squadron_command_activations_committed == 2`;
- `squadron_command_opportunity_disposition == "CONSUMED"`;
- `maneuver_opportunity_disposition == "OPEN"`.

Therefore no third commanded squadron activation exists.

The log confirms that after
`CompleteSquadronActivationCommand` for the second commanded squadron, the
Squadron-command presentation is reconstructed and opens:

`Opened for squadron command: activation 3 of 2.`

The player must press Done before the resolver finalizes `2 / 2 activations used`
and the ship activation proceeds to Repair.

Expected behavior is that projection/recovery recognize the canonically exhausted
Squadron-command opportunity and do not present another squadron-selection modal.
The enclosing Squadron command should transition through its accepted terminal
presentation/finalization path without offering a nonexistent third activation.

This is a residual BUG-035 presentation/reconstruction defect. Do not solve it
by changing canonical activation counts or allowing an additional activation.

### Residual Resolution — Terminal Squadron-Command Projection

Root cause: `CompleteSquadronActivationCommand` correctly restored the
enclosing `SHIP_ACTIVATION / SQUADRON_STEP` flow after each commanded squadron,
but presentation recovery opened the Squadron modal without first checking the
canonical resolver's remaining capacity. At `2 / 2`, the resolver was already
done and the opportunity was `CONSUMED`; the modal nevertheless presented a
third selection.

Repair: `ShipActivationController.open_squadron_command_from_interaction_state`
now checks the canonical resolver's `is_done()` state before opening selection.
At the terminal boundary it hides the command modal and uses the existing
Squadron-command finalization path, which spends the existing resources and
advances to Repair. Remaining-capacity recovery still opens the existing modal
without submitting another Squadron-step command.

The duplicate `resolve_damage` attempt was also traced to a synchronous
hot-seat re-entry: the authoritative `CommitDefenseCommand` post-success seam
queues and drains `resolve_damage`, then the executor's defense callback could
enter the same resolver again. The callback now exits when canonical defense is
already `DEFENSE_COMPLETE`; validation remains unchanged. This is a bounded
idempotence guard in the existing current-attack seam, not a second continuation
owner.

Because the duplicate submission has a clear local re-entry cause and is fixed
by that bounded guard, a separate bug is not recommended at this time.

The `activation 3 of 2` behavior is resolved by the focused regression
`test_commanded_squadron_completion_reopens_existing_opportunity`, which now
drives both commanded completions and verifies no visible command modal remains,
the opportunity is `CONSUMED`, the ship is at Repair, and only one normal
Repair transition is present.

### Manual Retest — False Second-Attack Opportunity

A later Hot-Seat normal ship-to-ship retest exposed a remaining BUG-035
continuation-classification defect.

After the Victory II completed and acknowledged its first ship attack, the UI
returned to attack declaration and prompted for a second attack even though no
legal target remained.

Evidence:

- `annotation_20260819_142925_001.json`
- `game_20260819_142712.log`

Canonical state at the time shows:

- the completed inspection is satisfied and remains installed;
- `CurrentAttackState` is inactive;
- `committed_attack_count == 1`;
- the FRONT hull zone is already used;
- `attack_step_active == true`;
- Maneuver remains `UNREACHED`.

The target selector subsequently proves that no legal second attack exists:

- FRONT: already used;
- RIGHT: no valid targets;
- LEFT: no valid targets;
- REAR: no valid targets.

The player must manually invoke Skip Attack before the ship can continue.

This means the first normal-ship BUG-035 repair correctly recovered a real
derived second-attack opportunity, but the continuation/recovery predicate is
still too broad: it exposes a second attack when nominal attack capacity remains
without establishing that at least one legal attack declaration actually exists.

Expected behavior:

- if at least one legal second attack exists, retain the satisfied inspection
  and expose the derived attack-declaration opportunity;
- if no legal second attack exists, do not present an empty declaration UI;
  use the accepted existing terminal attack-step continuation toward Maneuver,
  with inspection consumption according to CON-007.

The determination of whether another attack remains must reuse authoritative
gameplay target-legality logic. Do not create a presentation-local approximation
of target availability.

### Residual Resolution — False Normal Second-Attack Opportunity

Root cause: normal-ship inspection release previously classified every ship
with fewer than two committed attacks as a derived second-attack opportunity.
That nominal-capacity check ignored whether any unused hull zone still had a
legal ship target, so an empty declaration was projected when all remaining
zones were invalid.

Repair: `CurrentAttackContinuation` now reuses
`TargetingListBuilder.authoritative_ship_target_entries`, the same canonical
range, firing-arc, obstruction, target, and attack-pool candidate surface used
by `BeginAttackCommand` and live target selection. It filters only the already
canonical `used_attack_hull_zones` and ship-to-ship target kind. A legal
candidate retains the satisfied inspection for derived declaration; no legal
candidate derives the existing `AdvanceActivationStepCommand` maneuver
continuation, which atomically consumes the inspection.

Paired regressions now prove:

- a legal unused-zone target leaves history at acknowledgement only, keeps the
  satisfied inspection, and leaves the derived declaration available;
- no legal target executes exactly one Maneuver transition, consumes the
  inspection, opens Maneuver, and submits no redundant `SkipAttackCommand`.

Final verification after this repair:

- production current-attack resume: 48/48, 899 assertions;
- shared current-attack protocol: 25/25, 1,058 assertions;
- authoritative target-legality suite: 35/35, 69 assertions;
- squadron attack recovery: 18/18, 435 assertions;
- full GUT suite: 238 scripts / 4,072 tests / 13,838 assertions, all passing;
- Phase-K architecture lint: 0 violations (4 existing allow-listed branches);
- `git diff --check`: clean.

The normal-ship false second-attack behavior is resolved. Manual Hot-Seat
retest is appropriate; replay baselines were not renewed.

### Manual Retest — Squadron Phase Post-Attack Presentation Stall

A further Hot-Seat manual retest exposed another BUG-035 post-attack
presentation/recovery failure, this time in the normal Squadron Phase.

Evidence:

- `annotation_20260819_145138_001.json`
- `game_20260819_144803.log`

Scenario:

- Squadron Phase, player 1;
- first TIE Fighter squadron activation;
- the squadron is engaged and attacks;
- the attack completes normally;
- the player acknowledges the completed attack result.

The authoritative command sequence succeeds:

- `complete_attack` seq=151;
- `acknowledge_attack_result` seq=152;
- `complete_squadron_activation` seq=153.

The log then shows:

- `TargetSelector` dismissed;
- `AttackExecutor` dismissed.

However, the Squadron Phase flow does not recover presentation for the next
legal squadron activation and the UI stalls.

Captured canonical state after the stall shows:

- `completed_attack_inspection` is empty;
- `CurrentAttackState` is inactive;
- the completed TIE has
  `activation_context == "squadron_phase"`;
- its activation is complete;
- `squadron_phase_activations_committed == 1`;
- additional unactivated, non-destroyed player-1 squadrons remain available.

Therefore this is not evidence that acknowledgement or authoritative inspection
consumption failed. Canonical progression completed, but presentation was not
reprojected from the resulting canonical Squadron Phase state.

### Relationship to Earlier BUG-035 Failures

This is another instance of the broader post-completed-attack recovery problem
already exposed in:

1. ship-commanded squadron continuation;
2. normal ship second-attack continuation;
3. terminal ship-commanded squadron continuation;
4. now normal Squadron Phase continuation.

The repeated pattern is that canonical post-attack state can be correct while
individual scene/controller callback paths fail to reconstruct the presentation
required by that state.

Further repair should therefore not add another isolated Squadron Phase callback
patch without first checking the complete CON-007 context matrix.

The implementation should verify presentation recovery after completed-attack
inspection consumption for all four CON-007 contexts:

- normal ship attack;
- ship anti-squadron iteration;
- Squadron Phase squadron attack;
- ship-commanded squadron attack.

For each context, distinguish:

- another derived gameplay opportunity remains;
- the context is terminal and must advance through its accepted semantic
  transaction.

Presentation must be derived/reprojected from canonical state after the
authoritative mutation rather than depend on a particular UI callback having
initiated that mutation.

No UI/controller path may become a second gameplay authority.

### Expected Squadron Phase Behavior

After acknowledgement and successful
`CompleteSquadronActivationCommand` in Squadron Phase:

- the completed attack UI is dismissed;
- the completed squadron remains canonically activated;
- if further legal Squadron Phase activations remain, the normal Squadron Phase
  selection/presentation is restored;
- if the player's Squadron Phase allocation is exhausted, the existing
  authoritative phase/player continuation occurs;
- no duplicate activation or continuation command is synthesized merely to
  restore presentation;
- no manual workaround is required.

### Cross-Context Recovery Trace and Repair (2026-08-19)

The four CON-007 contexts were traced from acknowledgement through the
processor-owned consumer and post-command projection.

| Context | Canonical consumer/result | Recovery conclusion |
| --- | --- | --- |
| Normal ship | Derived declaration when authoritative target legality finds a remaining target; otherwise `AdvanceActivationStepCommand` to Maneuver | Uses the existing inactive-ship attack projection. The prior false second-attack defect was a target-legality classification defect, not the Squadron Phase mechanism. |
| Ship anti-squadron | Derived same-zone declaration while an authoritative target remains; otherwise accepted `SkipAttackCommand(squadron_done)` | Existing target-legality/iteration transaction already owns the terminal path. No production change was required. |
| Squadron Phase squadron | `CompleteSquadronActivationCommand` consumes the inspection and writes `SQUADRON_ACTIVATION / WAIT_FOR_SQUAD_SELECT` | Confirmed defect: direct processor follow-up bypassed the local Squadron Phase callback that normally reopened the modal, and terminal phase routing was wrapper-dependent. |
| Ship-commanded squadron | `CompleteSquadronActivationCommand` restores `SHIP_ACTIVATION / SQUADRON_STEP` | Existing ShipActivationController recovery remains correct: it uses the canonical resolver, reopens only while capacity remains, and uses the established terminal path otherwise. |

Repair:

- ModalRouter now reprojects the existing Squadron Phase selector only when
  `UIProjector` exposes canonical `SQUADRON_ACTIVATION / WAIT_FOR_SQUAD_SELECT`.
  The controller submits no command and owns no capacity decision.
- GameManager now applies its existing Squadron Phase progress projection from
  accepted local `complete_squadron_activation` / declaration-skip command
  results, rather than only from the UI wrapper that happened to submit them.
  This preserves the existing live-authority terminal phase advance while
  passive network mirrors retain their established mirror path.

This confirms a common presentation recoverability gap for Squadron Phase and
the earlier commanded-squadron issue: a processor-owned continuation could
reach valid canonical state without invoking the callback that happened to own
the preceding local interaction. The normal-ship legality defect is separate;
anti-squadron did not reproduce a recovery failure.

Regression coverage now includes production-board acknowledgement chains for
Squadron Phase with (a) a remaining activation and (b) terminal phase
exhaustion, alongside the already-covered normal ship, anti-squadron, and
ship-commanded remaining/terminal cases. It asserts canonical inspection
consumption, exact command ordering, modal recovery/suppression, and no stale
attack execution state.

Manual verification remains required before closing BUG-035. Recommended
Hot-Seat matrix: normal ship with and without a real second target;
anti-squadron with another target and with the iteration exhausted; Squadron
Phase first and final squadron attacks; commanded-squadron first and final
activations. Confirm that no attack result or impossible selector remains and
that each accepted terminal command appears once.

Verification for this convergence repair:

- focused production-resume suite: 50/50 tests, 935 assertions;
- integration suite: 245/245 tests, 3,085 assertions;
- full repository suite: 4,074/4,074 tests, 13,874 assertions;
- `lint_phase_k.sh`: 0 violations;
- `git diff --check`: clean.

Replay baselines were not renewed. BUG-035 remains open pending the manual
Hot-Seat matrix above (and Network mirror confirmation where applicable).

### Manual Retest — Token-Only Squadron Command Still Stalls

A further Hot-Seat manual retest exposed another BUG-035 regression in the
ship-commanded squadron path.

This reproduction uses a Squadron command **token**, not a Squadron command
dial.

Because the token permits only one commanded squadron activation, the first
completed squadron is also the terminal activation for the Squadron command.

Evidence:

- `annotation_20260819_152519_001.json`
- `game_20260819_152026.log`

The squadron attack itself completes normally:

- `begin_attack` seq=166
- `resolve_damage` seq=170
- `complete_attack` seq=171
- `acknowledge_attack_result` seq=172

However, no subsequent `CompleteSquadronActivationCommand` is observed before
the stall.

Captured canonical state shows:

- the completed inspection remains installed but is satisfied;
- `CurrentAttackState` is inactive;
- the commanded squadron retains
  `activation_context == "ship_squadron_command"`;
- `squadron_command_activations_committed == 1`;
- `squadron_command_opportunity_disposition == "OPEN"`;
- the commanding Nebulon retains its active ship activation identity.

This differs from the previously repaired dial-based commanded-squadron path,
where `CompleteSquadronActivationCommand` executes after acknowledgement and
the remaining/terminal Squadron-command presentation is then reconstructed.

The token-only path therefore exposes a missing terminal consumer/recovery
variant: after acknowledgement of the only allowed commanded squadron attack,
the authoritative squadron-completion transaction is not triggered.

The repair must not special-case “token” in presentation code. It should derive
the correct post-attack consumer from the canonical squadron activation context
and canonical remaining Squadron-command capacity.

### Regression Matrix Gap

BUG-035 verification must now distinguish not only continuation contexts but
also the state variants that select different branches within those contexts.

At minimum the ship-commanded squadron matrix must cover:

1. dial-based command, capacity remains after first activation;
2. dial-based command, final activation exhausted;
3. token-based command, first activation is terminal;
4. completion after attack;
5. completion without attack where applicable.

For every variant verify:

- correct authoritative consumer command executes;
- completed inspection is consumed exactly once when required;
- canonical committed count/disposition are correct;
- no extra Squadron-step advance is synthesized;
- no stale or impossible presentation remains;
- the ship resumes its accepted next activation state.

Do not add another UI-only workaround for the token branch.

### Additional Observation — duplicate resolve_damage

The duplicate rejected `resolve_damage` attempt also reappeared in this run:

1. one `resolve_damage` executes successfully;
2. damage is applied;
3. a second `resolve_damage` attempt is rejected with
   `Defense resolution is not complete`;
4. `complete_attack` then succeeds.

This means the previous synchronous re-entry repair did not cover all relevant
attack paths. The remaining duplicate-submission source should be included in
the next convergence investigation rather than assumed resolved.

### Recovery Branch Coverage Audit

A read-only production/control-flow and regression-coverage audit was completed
after repeated green-suite/manual-test divergence.

See:

`BUG-035-recovery-branch-coverage-audit.md`

The audit identifies the remaining commanded-squadron branch gap, the independent
duplicate `resolve_damage` race, and the branch-complete convergence scope for the
next repair.

### Convergence Repair — Legal Remaining Move and No-Defense Damage Race

Implemented from the recovery-branch coverage audit; the audit remains the
historical diagnostic record.

Root cause and repair:

- Commanded-squadron post-acknowledgement release and
  `CompleteSquadronActivationCommand` both treated an uncommitted move as an
  available action without first determining whether the move was legal.  A
  squadron engaged by a non-Heavy squadron therefore retained a satisfied
  inspection indefinitely, including the terminal token command case.
- `GameState` now exposes the shared canonical predicate for a legal remaining
  squadron move.  It delegates to `SquadronKeywordRuleHelper` using canonical
  squadron positions and obstruction bodies.  The continuation release and
  completion validation/execution use the same canonical activation-complete
  predicate.  This is independent of dial/token source: an attack-first
  squadron with a legal move retains its inspection and action interaction;
  one whose move is prohibited is completed once through the existing
  CON-007 consumer.
- In the independent Hot-Seat no-defense path, `commit_accuracy` already lets
  `CommandProcessor` queue `resolve_damage`.  `AttackExecutor` now observes
  that canonical defense is complete and only clears the defense presentation,
  rather than synchronously submitting a second resolve command.

Regression evidence added to the production-resume suite:

- token-only commanded attack, blocked by the canonical non-Heavy engagement
  rule: one completion, inspection consumed, command token finalized, and the
  Squadron step retired;
- dial commanded attack with a legal Heavy-engagement move: no premature
  completion, satisfied inspection retained, and action-choice projection
  restored;
- passive Network mirror and replay: no synthesized completion;
- a live Hot-Seat accuracy/no-defense sequence: one `commit_accuracy`, one
  `resolve_damage`, and one `complete_attack`.

Verification:

- `test_current_attack_production_resume.gd`: 54/54 tests, 1,041 assertions;
- current-attack shared-protocol, squadron target-recovery, concrete-command,
  and resolve-damage suites: passed;
- clean full GUT suite: 4,078/4,078 tests, 13,967 assertions;
- `bash scripts/lint_phase_k.sh`: 0 violations;
- `git diff --check`: clean.

No replay baseline was renewed. BUG-035 remains open pending the required
manual Hot-Seat retest, especially token-only non-Heavy engagement and dial
Heavy-engagement commanded-squadron sequences, plus the no-defense accuracy
path.

### Manual Retest — Anti-Squadron Remaining-Target Projection Incorrect

A Hot-Seat anti-squadron retest exposed another BUG-035 regression.

After the first anti-squadron attack is completed and acknowledged, the
authoritative anti-squadron iteration remains active and the target selector
reopens. However, the selector does not correctly present the remaining legal
anti-squadron target set.

Evidence:

- `annotation_20260819_160624_001.json`
- `game_20260819_160354.log`

Captured canonical state shows:

- the completed inspection is satisfied and remains installed;
- `CurrentAttackState` is inactive;
- the attacking Victory II remains in its attack step;
- `anti_squadron_attack_zone == FRONT`;
- `anti_squadron_target_history` already contains the first attacked X-wing;
- `committed_attack_count == 1`.

The post-acknowledgement selector is restored, but manual interaction shows that:

- the already-attacked X-wing can still be selected and only rejected later
  with `already attacked this activation`;
- ship targets are correctly rejected because the attack is still inside the
  anti-squadron loop;
- hull-zone changes are correctly rejected because the anti-squadron hull zone
  is locked.

Thus the authoritative anti-squadron continuation survives, but projection of
the next legal target choice is incomplete.

Expected behavior:

- after acknowledgement, if another legal squadron target remains for the locked
  hull zone, the selector should expose only valid remaining anti-squadron
  targets;
- previously attacked targets must not be offered as valid choices;
- ship targets must remain excluded;
- hull-zone selection remains locked to the accepted anti-squadron zone;
- if no legal squadron target remains, the existing
  `SkipAttackCommand(squadron_done)` terminal continuation should occur
  according to CON-007.

The repair must reuse authoritative anti-squadron target legality/history rather
than adding presentation-local filtering rules.

### Anti-Squadron Recovery Repair

Root cause and repair:

- The restored selector used transient attacked-token state for the Step 6
  history guard.  That left a recovery path able to offer a historical target
  before the later authoritative command validation rejected it.
- Anti-squadron target selection now resolves each remaining squadron through
  `TargetingListBuilder.authoritative_attack_entry`, using the canonical locked
  hull zone, range/arc/LOS, live occupancy, target kind, and
  `anti_squadron_target_history`.  This is the same legality surface used by
  `BeginAttackCommand`; no presentation-local geometry rule was added.
- When the authoritative iteration is exhausted, the existing
  `SkipAttackCommand(squadron_done)` remains the sole semantic consumer.  The
  accepted terminal command now also tears down the stale Hot-Seat selector;
  `end_anti_squadron_attack()` remains owned by that command.

Regression evidence:

- remaining-target production resume: acknowledgement restores the locked
  selector, rejects the historical target, accepts a distinct legal squadron,
  excludes ships, and submits no display-only command;
- exhausted-target production resume: one `skip_attack` closes the iteration,
  consumes the inspection, and does not reopen an empty selector;
- replay and passive Network mirror cases preserve inspection state and
  synthesize no anti-squadron continuation.

Verification:

- production-resume suite: 57/57 tests, 1,105 assertions;
- current-attack shared protocol: 25/25 tests, 1,058 assertions;
- squadron target-recovery suite: passed;
- full GUT suite: 4,081/4,081 tests, 14,031 assertions;
- `bash scripts/lint_phase_k.sh`: 0 violations;
- `git diff --check`: clean.

Manual Hot-Seat anti-squadron retest is now appropriate for both a remaining
legal target and an exhausted final target. BUG-035 remains open until those
manual scenarios confirm the repaired projection; replay baselines were not
renewed.

### Manual Retest — Remaining Anti-Squadron Attack Cannot Be Committed

A further Hot-Seat anti-squadron retest after the latest recovery repair still fails manual convergence.

Evidence:

- `annotation_20260819_204003_001.json`
- `game_20260819_203728.log`

After the first anti-squadron attack, the authoritative anti-squadron iteration remains active and a remaining X-wing can be selected.

The log confirms that target selection succeeds for the remaining X-wing, including clear LOS, medium range, and a one-blue-die attack pool.

However, the expected interaction/modal required to commit the selected attack is not presented. The player therefore cannot proceed with the otherwise selectable target.

Captured canonical state shows:

- completed inspection `completed:attack:87` remains installed and satisfied;
- `CurrentAttackState` is inactive;
- the attacking Victory II remains in its attack step;
- `anti_squadron_attack_zone == FRONT`;
- the previous target remains recorded in `anti_squadron_target_history`;
- `committed_attack_count == 1`.

This indicates that the latest anti-squadron recovery repair has not yet achieved manual convergence. Target recovery and target selection are present, but the presentation required to commit the next legal attack is missing.

No further BUG-035 repair is attempted at this point.

BUG-035 remains open. Further implementation work is deliberately deferred while the broader active-gameplay interaction/UI behavior is specified under the remaining `BC-003 / AT-002` architecture scope. This specification work should establish the intended hierarchical relationship between canonical gameplay state, available interaction/decision state, and presentation state before additional local recovery paths are added.
