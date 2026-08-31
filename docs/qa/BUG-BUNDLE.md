

===== FILE: docs/qa/bugs/open/BUG-020/issue-Network-replay-diverges-during-second-Command-Phase.md =====

# BUG-020 — Network replay diverges during second Command Phase

Severity: High
Area: Network Replay / Command Phase
Layer: Serialization

## Expected

An application-recorded format-5 network replay should reproduce the recorded semantic command history deterministically through the network replay harness.

During the second Command Phase, the replay should execute the recorded sequence:

25. `start_round`
26. Player 1 `assign_dials`
27. Player 0 `assign_dials`
28. `advance_phase` to Ship Phase

No additional semantic command should be synthesized that changes this recorded sequence.

## Actual

The recorded network replay passes baseline-generator preflight but fails during network replay execution.

During the second Command Phase, after sequence 26 (`assign_dials` by Player 1), the replayed host automatically executes:

`advance_phase` as sequence 27

before the recorded Player 0 `assign_dials` command at sequence 27 is replayed.

The recorded sequence 28 `advance_phase → Ship Phase` is then rejected because the game is already in Ship Phase:

`Phase 2 is not the expected next phase (3).`

The ReplayDriver subsequently times out waiting for the rejected command to execute.

The client likewise times out waiting for the same replay progression.

## Reproduction

Always with the captured replay candidate.

1. Use the recorded format-5 authoritative-host network replay.
2. Run:

   `./scripts/generate_baseline_fixtures.sh --mode network --replay <replay>`

3. Candidate preflight passes.
4. Replay executes correctly through Round 1.
5. During the second Command Phase:
   - sequence 25 `start_round` executes;
   - sequence 26 Player 1 `assign_dials` executes;
   - an automatic `advance_phase` consumes sequence 27;
   - recorded sequence 28 `advance_phase` is rejected;
   - replay times out.

## Evidence

- `replay_20260812_210900_candidate_network.json`
- network candidate-generation host log
- network candidate-generation client log
- generator console output showing:
  - replay format 5
  - successful preflight
  - host=3 / client=3 failure

Recorded replay sequence:

- 25 `start_round`
- 26 Player 1 `assign_dials`
- 27 Player 0 `assign_dials`
- 28 `advance_phase`

Observed replay execution sequence:

- 25 `start_round`
- 26 Player 1 `assign_dials`
- 27 automatic `advance_phase`
- recorded progression then rejects

The replay itself passed generator structural validation and must not be edited, reordered, renumbered, or converted to bypass the failure.

## Notes

This was discovered while generating the new format-5 network baseline candidate.

The failure occurs before the later BUG-017 attack sequence, so it is not evidence that BUG-017 has regressed.

The current evidence suggests a divergence between recorded Command Phase progression and replay-time automatic/network continuation, but the exact root cause has not yet been established.

Potential investigation areas include:

- reconstructed command-dial requirements;
- simultaneous/private network Command Phase synchronization;
- automatic Command Phase completion;
- replay deferred/generated follow-up handling;
- authoritative command-sequence ownership.

Do not assume any one of these is the root cause until analyzed.

## Resolution

Root cause:
TBD

Fix:
TBD

Verification:
The unchanged captured replay must successfully complete network candidate generation with host/client authoritative final-state equality, without synthesizing an extra semantic phase-transition command or modifying the replay file.


===== FILE: docs/qa/bugs/open/BUG-031/issue-Skipping-squadron-activation-during-Squadron-command-stalls-ship-activation.md =====

# BUG-031 — Skipping squadron activation during Squadron command stalls ship activation

Severity: High
Area: Squadron command / ship activation
Layer: Command Flow

## Expected

During a Squadron command, the player can skip an available squadron activation or end the Squadron command early. The Squadron command should then finish cleanly and the commanding ship should continue to the next activation step.

## Actual

During network play, the Nebulon-B used a Squadron command. After one squadron activation, the next squadron activation was skipped.

The game did not continue correctly. The squadron activation modal became unavailable and the ship activation stalled.

Evidence shows that complete_squadron_activation was rejected with:

Squadron still has an available action.

The UI nevertheless continued as if that command activation had completed. After the player ended the Squadron command early, the subsequent advance_activation_step command was rejected with:

Declaration-adjacent state is invalid.

The game could no longer progress.

## Reproduction

Sometimes

1. Start a network game.
2. Activate a ship with a Squadron command capable of activating multiple squadrons.
3. Activate a squadron normally.
4. During the next Squadron-command activation opportunity, use Skip.
5. End the Squadron command early if prompted.
6. Observe whether the ship activation advances normally.

Observed once in Round 3 with the Nebulon-B Escort Frigate.

## Evidence

- annotation_20260816_092548_001.json
- replay_20260816_092616.json
- host_20260816_091352.log
- client_20260816_091352.log
- game_20260816_091333.log

Relevant log sequence:

- Skip pressed for X-wing Squadron
- Command rejected [complete_squadron_activation]: Squadron still has an available action.
- UI reports Command activation 1 of 2 — ready for next.
- Player selects Done to end the Squadron command early.
- Squadron command finalizes with 1 / 2 activations used.
- Ship activation attempts to advance to REPAIR.
- Command rejected [advance_activation_step]: Declaration-adjacent state is invalid.
- No further gameplay progression occurs.

## Resolution

Root cause: TBD. Evidence indicates that the Skip path leaves authoritative squadron-activation/declaration state inconsistent while presentation proceeds as though the activation was completed.

Fix: TBD.

Verification: Reproduce and verify the Squadron-command Skip / early-end path in network play. Confirm that skipping does not leave an active squadron activation or declaration-adjacent state and that the commanding ship proceeds normally to the next activation step.
# BUG-031 — Skipping squadron activation during Squadron command stalls ship activation

Severity: High
Area: Squadron command / ship activation
Layer: Command Flow

## Expected

During a Squadron command, the player can skip an available squadron activation or end the Squadron command early. The Squadron command should then finish cleanly and the commanding ship should continue to the next activation step.

## Actual

During network play, the Nebulon-B used a Squadron command. After one squadron activation, the next squadron activation was skipped.

The game did not continue correctly. The squadron activation modal became unavailable and the ship activation stalled.

Evidence shows that complete_squadron_activation was rejected with:

Squadron still has an available action.

The UI nevertheless continued as if that command activation had completed. After the player ended the Squadron command early, the subsequent advance_activation_step command was rejected with:

Declaration-adjacent state is invalid.

The game could no longer progress.

## Reproduction

Sometimes

1. Start a network game.
2. Activate a ship with a Squadron command capable of activating multiple squadrons.
3. Activate a squadron normally.
4. During the next Squadron-command activation opportunity, use Skip.
5. End the Squadron command early if prompted.
6. Observe whether the ship activation advances normally.

Observed once in Round 3 with the Nebulon-B Escort Frigate.

## Evidence

- annotation_20260816_092548_001.json
- replay_20260816_092616.json
- host_20260816_091352.log
- client_20260816_091352.log
- game_20260816_091333.log

Relevant log sequence:

- Skip pressed for X-wing Squadron
- Command rejected [complete_squadron_activation]: Squadron still has an available action.
- UI reports Command activation 1 of 2 — ready for next.
- Player selects Done to end the Squadron command early.
- Squadron command finalizes with 1 / 2 activations used.
- Ship activation attempts to advance to REPAIR.
- Command rejected [advance_activation_step]: Declaration-adjacent state is invalid.
- No further gameplay progression occurs.

## Resolution

Root cause: TBD. Evidence indicates that the Skip path leaves authoritative squadron-activation/declaration state inconsistent while presentation proceeds as though the activation was completed.

Fix: TBD.

Verification: Reproduce and verify the Squadron-command Skip / early-end path in network play. Confirm that skipping does not leave an active squadron activation or declaration-adjacent state and that the commanding ship proceeds normally to the next activation step.


===== FILE: docs/qa/bugs/open/BUG-033/issue-End-of-game-screen-does-not-appear-on-network-client.md =====

# BUG-033 — End-of-game screen does not appear on network client

Severity: High
Area: End game / network play
Layer: Networking

## Expected

When the game ends in network play, the end-of-game state must be reflected on both instances.

Both the host and the client must transition to the end-of-game presentation and display the end-of-game screen.

## Actual

The game reached its end, but the end-of-game screen did not appear on the client side.

The client therefore remained without the expected final game presentation after the game had ended.

## Reproduction

Once

1. Start and play a network game with host and client.
2. Continue the game until the normal end-of-game condition is reached.
3. Observe the end-of-game transition on both instances.
4. The expected end-of-game screen does not appear on the client.

Observed at the end of Round 6.

## Evidence

A complete evidence package from the affected network gameplay run has been retained:

- `annotation_20260816_095035_001.json`
  - Records the observed defect on the client at the end of the game.
- `replay_20260816_095010.json`
  - Preserves the authoritative command/gameplay sequence from the affected run.
- Host and client logs from the affected gameplay run.
  - Preserve runtime and networking evidence surrounding the end-of-game transition.

The annotation, replay, and host/client logs should be investigated together to determine whether the authoritative end-of-game state was reached and propagated correctly, and where the client-side transition failed.

They are part of the BUG-033 evidence and should be retained until resolution and verification are complete.

## Resolution

Root cause: TBD.

Fix: TBD.

Verification: Complete a network game and verify that both host and client enter the authoritative end-of-game state and display the end-of-game screen. Verify through the replay and host/client logs that the end-game transition is deterministic and correctly synchronized.


===== FILE: docs/qa/bugs/open/BUG-035/BUG-035-recovery-branch-coverage-audit.md =====

## 1. Executive diagnosis

BUG-035 is a mixture:

- Several earlier symptoms were projection gaps after valid semantic continuations.
- The latest token run is a canonical action-completion gap: it is not selected by Squadron command capacity.
- The duplicate `resolve_damage` is independent: a synchronous UI reaction races the processor-owned follow-up.

No architecture contradiction found.

## 2. Actual branch dimensions

- Continuation context: normal ship, anti-squadron iteration, Squadron Phase squadron, ship-commanded squadron.
- Remaining legal opportunity: authoritative targets/action legality, not nominal capacity.
- Squadron action history: move committed; attack available/begun/declined; Rogue vs non-Rogue.
- Movement legality: particularly non-Heavy engagement versus a nominal uncommitted move.
- Squadron command resources: dial, token, dial+token; capacity and terminal resource finalization.
- Inspection state: pending, satisfied, consumed/stale.
- Execution mode: live authority, Hot-Seat synchronous projection, network mirror, replay, reconstruction.
- Attack outcome: target survival/destruction insofar as it changes authoritative target or engagement legality.

## 3. Reachable branch matrix

| Context / distinction | Expected consumer and projection | Current coverage | Status |
|---|---|---|---|
| Normal ship, legal second target | No consumer; retain satisfied inspection and reproject declaration | Real-board ACK regression | Strong |
| Normal ship, no legal target | `AdvanceActivationStepCommand` to Maneuver; clear attack UI | Canonical fixture, not full presentation route | Partial |
| Anti-squadron, same-zone target remains | No consumer; reproject same-zone target choice | Protocol target-loop coverage; ACK UI test only checks dismissal | Partial |
| Anti-squadron, exhausted | `SkipAttackCommand(squadron_done)` | Protocol coverage | Partial |
| Squadron Phase, completed squadron and allocation remains | `CompleteSquadronActivationCommand`; selection modal | Real-board regression | Strong |
| Squadron Phase, allocation exhausted | Complete then established phase handoff | Real-board regression | Strong |
| Commanded squadron, completed actions and dial capacity remains | Complete; reopen existing Squadron opportunity | Direct completion/controller test | Partial |
| Commanded squadron, completed actions and dial terminal | Complete; resolver terminal path to Repair | Direct completion/controller test | Partial |
| Commanded squadron, completed actions and token terminal | Same semantic path; token finalization | Resolver unit test only | Absent end-to-end |
| Commanded squadron, attack first and legal move remains | No complete; retain inspection for `MoveSquadronCommand`, restore action choice | No ACK-path regression | Absent |
| Commanded squadron, attack first and move is prohibited by engagement | Complete should release terminal command capacity | Latest manual case only | Absent |
| Passive mirror/replay | Never synthesize; project recorded command result only | Shared protocol/replay tests | Strong generically; not token branch |

Dial and dial+token are equivalent for the acknowledgement release decision when their remaining capacity is the same; they differ at command-resource finalization. Pending/consumed/stale inspections are guarded lifecycle states, not separate recovery paths.

## 4. Latest token-only root cause

The first divergence is in [`current_attack_continuation.gd`](/Users/Katharina/godot/Armada/src/core/state/current_attack_continuation.gd:146), before `SquadronCommandResolver` capacity is consulted.

The captured squadron state is:

- `attack_action_disposition == "begun"`
- `move_action_committed == false`
- `activation_context == "ship_squadron_command"`

For commanded squadrons, [`SquadronInstance.has_remaining_move_action()`](/Users/Katharina/godot/Armada/src/core/state/squadron_instance.gd:194) therefore returns true. The processor returns no `CompleteSquadronActivationCommand`, leaving the satisfied inspection installed.

That same nominal-action condition causes [`CompleteSquadronActivationCommand`](/Users/Katharina/godot/Armada/src/core/commands/complete_squadron_activation_command.gd:56) to reject completion. But actual movement legality is separately evaluated by [`MoveSquadronCommand`](/Users/Katharina/godot/Armada/src/core/commands/move_squadron_command.gd:68) using `SquadronKeywordRuleHelper.can_move_with_heavy_rule`.

So the token is not the causal branch. It makes the defect immediately terminal once completion is possible. The missing case is: “attack performed, move uncommitted, but movement is not legally available.” Existing dial tests pre-commit movement or use a no-target Skip path, so they never enter this state.

## 5. Duplicate `resolve_damage` root cause

Confirmed independent race:

1. `CommitAccuracyCommand` writes `DEFENSE_COMPLETE` when no defense interaction exists.
2. `CommandProcessor` queues its authoritative `resolve_damage` follow-up before emitting `command_executed`.
3. [`AttackPanelController`](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_panel_controller.gd:96) synchronously calls `AttackExecutor.apply_accuracy_result`.
4. [`_attack_exec_start_defense()`](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:2234) sees no spendable defense and directly submits `resolve_damage`.
5. The processor then drains its already-queued `resolve_damage`; validation correctly rejects it because damage resolution has advanced.

The previous guard is in `_process_next_defense_commit`, which is not reached by this accuracy/no-defense auto-skip route.

Reachable in Hot-Seat and any live-authority same-process route that projects `commit_accuracy` synchronously before follow-up draining. Replay and passive mirrors cannot produce the processor follow-up and are not affected.

## 6. Coverage-gap diagnosis

The green suite proves many individual contracts, but not the branch intersection exposed manually.

Most notably, `test_commanded_squadron_completion_reopens_existing_opportunity`:

- changes a dial-based ship to capacity two;
- manually commits movement;
- directly submits `CompleteSquadronActivationCommand`;
- does not execute attack → acknowledgement → processor release;
- does not use a token;
- does not exercise blocked movement.

`test_token_only_grants_one_activation` is resolver-only. The real-board damage test starts from an already `DEFENSE_COMPLETE` fixture, bypassing `commit_accuracy` result emission and its synchronous UI callback. Thus neither test exercises its claimed manual counterpart.

## 7. Convergence recommendation

Smallest coherent next repair scope:

1. Make the authoritative squadron-completion decision use the existing movement-legality rule, consistently in:
   - post-acknowledgement continuation derivation; and
   - `CompleteSquadronActivationCommand` validation/execution eligibility.

   This must not use modal state or alter command capacity. It should reuse the existing `SquadronKeywordRuleHelper`/canonical-position path, so an unavailable move is not treated as an unfinished required action.

2. Add production-path regressions for:
   - token-only commanded squadron, attack first, non-Heavy-engagement movement prohibition, ACK → exactly one completion → terminal Repair;
   - dial commanded squadron with legal remaining movement, ACK retains inspection and restores the action interaction without completing;
   - token/dial terminal finalization resource behavior;
   - replay/mirror non-synthesis of the new completion path.

3. Separately add one real Hot-Seat `commit_accuracy` → no-defense regression proving exactly one `resolve_damage`. The production change should suppress presentation-side damage submission once the processor already owns that canonical continuation. It is independent of BUG-035 recovery semantics but is small, proven, and reasonable to include in the same bounded package.

Keep the working normal-ship legality path, anti-squadron transaction, Squadron Phase completion projection, and existing commanded-capacity reconstruction unchanged.

## 8. Architecture disposition

ADR-007 and CON-007 remain sufficient:

- GameState and semantic commands remain authoritative.
- `CommandProcessor` remains the live release seam.
- UI only projects canonical state.
- No new continuation owner or generic framework is needed.
- Replay and passive mirrors remain non-synthesizing.

No Owner decision is required. No files were modified during this audit.


===== FILE: docs/qa/bugs/open/BUG-035/issue-Squadron-attack-result-modal-remains_after-acknowledgement-and-stalls-flow.md =====

# BUG-035 — Attack result acknowledgement does not resume gameplay and leaves stale result UI

Severity: High
Area: Completed-attack result acknowledgement / post-attack continuation
Layer: Command Flow

2026-08-25 status:
Implementation checkpoint: automated workbook acceptance complete; final two-human Network manual QA pending. No known automated BUG-035 gap remains. Manual acceptance deferred while prerequisite test/recovery infrastructure is repaired.

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

Status: Open — automated repairs have corrected several individual recovery branches, including the remaining anti-squadron declaration path, but manual convergence still fails at the terminal anti-squadron return to the enclosing Ship Attack opportunity.

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

### Manual Retest After Declaration-Reconstruction Repair — Terminal Anti-Squadron Return Still Stalls

A new Hot-Seat manual retest on 2026-08-21 shows that the latest BUG-035 declaration-reconstruction repair made real progress but did not achieve full manual convergence.

Evidence:

- `annotation_20260821_215806_001.json`
- `game_20260821_215440.log`

#### What now works

The previously failing remaining-target declaration path now succeeds manually.

During the Victory II anti-squadron attack sequence:

1. the first anti-squadron attack completes and is acknowledged;
2. the locked FRONT anti-squadron iteration is reconstructed;
3. a different remaining legal X-wing can be selected;
4. the declaration can be committed;
5. a second authoritative `BeginAttackCommand` executes;
6. the second anti-squadron attack resolves and is acknowledged.

Relevant command sequence:

- first anti-squadron `begin_attack` — seq 101
- first `complete_attack` — seq 106
- first `acknowledge_attack_result` — seq 107
- second anti-squadron `begin_attack` — seq 108
- second `complete_attack` — seq 113
- second `acknowledge_attack_result` — seq 114

This manually confirms that the repaired remaining-target → selection → declaration-confirm → second `BeginAttackCommand` path now works.

#### Residual failure

After the second attack is acknowledged, the anti-squadron iteration correctly detects that no further legal target remains and executes:

- `skip_attack` — seq 115

This is the accepted terminal `squadron_done` consumer for the anti-squadron iteration.

The log then records:

- anti-squadron state cleared;
- `TargetSelector` dismissed;
- `AttackExecutor` dismissed;

but no subsequent Ship Attack continuation or Maneuver transition occurs.

Gameplay stalls.

The annotation snapshot confirms:

- `completed_attack_inspection` is empty;
- `CurrentAttackState` is inactive;
- `anti_squadron_attack_zone == -1`;
- `anti_squadron_target_history` is empty;
- the Victory II remains `attack_step_active == true`;
- `committed_attack_count == 1`;
- FRONT remains recorded in `used_attack_hull_zones`;
- `maneuver_opportunity_disposition == "UNREACHED"`.

Therefore the individual attack and anti-squadron iteration have terminated, but the enclosing Ship Attack opportunity has not resumed or completed.

#### Updated failure boundary

The current residual failure is now:

second anti-squadron attack
→ completion
→ acknowledgement
→ anti-squadron target exhaustion
→ `SkipAttackCommand(reason: squadron_done)`
→ anti-squadron iteration terminates
→ MISSING: enclosing Ship Attack opportunity continuation

After `squadron_done`, the enclosing Ship Attack opportunity must be re-evaluated from authoritative gameplay state.

It must then either:

- expose another legal ship Attack declaration if one exists; or
- complete/leave the Attack opportunity through the accepted semantic path when no legal attack remains, allowing the activation to proceed to Maneuver.

In this reproduction no further legal VSD attack target was available, so the expected result was progression out of the Attack opportunity toward Maneuver.

#### Implication for automated coverage

The previous regression proved the repaired child interaction:

acknowledgement
→ remaining anti-squadron target
→ select
→ confirm
→ second `BeginAttackCommand`

That coverage was necessary but insufficient for full BUG-035 convergence.

Future regression coverage must also prove the composed parent return:

terminal anti-squadron `squadron_done`
→ enclosing Ship Attack opportunity re-evaluation
→ another legal declaration OR accepted Attack completion
→ Maneuver when no legal attack remains

A test that stops after proving exactly one `squadron_done` does not by itself prove correct continuation of the enclosing Ship Attack interaction.

Do not repair this by adding a presentation callback that directly advances the ship. The next investigation must establish the accepted owner of the post-`squadron_done` Ship Attack re-evaluation and preserve ADR-010 / CON-007 / SAI-050 decision-equivalent recovery.

### Manual Retest — Active Anti-Squadron Attack Cannot Be Skipped

A further Hot-Seat manual retest exposed an additional anti-squadron Attack
edge that requires classification before BUG-035 can be accepted.

Evidence:

- `annotation_20260822_180028_001.json`

During a Victory II-class Star Destroyer anti-squadron attack from its front
hull zone, the player cannot skip/cancel the currently active attack against an
X-wing squadron.

The captured canonical state shows:

- `CurrentAttackState.active == true`;
- `attack_id == "attack:258"`;
- the attacker is a ship;
- the defender is a squadron;
- the attack uses the front hull zone;
- `stage == "pre_roll"`;
- the attack pool contains one blue die;
- no completed-result inspection is active.

This differs from the previously repaired post-Attack anti-squadron
continuation cases. The captured attack has already entered an active
`CurrentAttackState`; it is not a completed child attack returning to the
anti-squadron iteration.

The observation therefore raises a narrower Attack-lifecycle question:

> After an anti-squadron attack declaration has been committed and
> `CurrentAttackState` is active but dice have not yet been rolled, is the player
> permitted to cancel/skip that individual attack?

This must not be inferred from the presence or absence of a UI Skip action.

Before any implementation change, the current behavior must be checked against
the accepted Attack declaration/commitment semantics, especially CON-006 and
the accepted Ship Activation Attack requirements.

The investigation must distinguish:

1. declining/skipping an Attack opportunity before declaration commitment;
2. declining further anti-squadron attacks between completed individual attacks;
3. cancelling an already committed individual anti-squadron attack while its
   `CurrentAttackState` is active at `pre_roll`.

Possible dispositions after investigation:

- if accepted authority already requires cancellation at this point, treat this
  as a remaining BUG-035-adjacent Attack-lifecycle implementation edge;
- if accepted authority forbids cancellation after declaration commitment,
  classify the observed behavior as expected and consider only whether
  presentation should communicate that commitment more clearly;
- if accepted authority does not define the case, stop for an Owner decision
  rather than inventing cancellation semantics.

No repair is authorized from this observation alone.

BUG-035 remains open pending this classification and completion of the remaining
manual QA.

continuation in the implementation workbook


===== FILE: docs/qa/bugs/open/BUG-036/issue.md =====

### Additional Command-Flow Anomaly Observed

The same manual run also logged a rejected second `resolve_damage` attempt after
each of the two commanded-squadron attacks.

In both cases:

1. one authoritative `resolve_damage` command executes successfully and applies
   damage;
2. a second `resolve_damage` attempt immediately follows;
3. `CommandProcessor` rejects the second attempt with
   `Defense resolution is not complete`;
4. `complete_attack` then executes normally.

This did not produce an observed double-damage mutation because validation
rejected the duplicate attempt.

The repeated pattern should be investigated for duplicate command submission or
auto-skip-defense routing. Do not assume it shares BUG-035's
post-acknowledgement root cause.


===== FILE: docs/qa/bugs/open/BUG-037/issue-Squadron-Attack-Cannot-Be-Declined-Before-Entering-Attack-Interaction.md =====

# BUG-037 — Squadron Attack Cannot Be Declined Before Entering Attack Interaction

Severity: Low
Area: Squadron Phase / Squadron Activation
Layer: Command Flow

## Expected

During a Squadron Phase Squadron Activation, when the squadron's Attack action
is still available and the player is permitted to decline that action, the
player should be able to decline Attack without first entering the Attack
interaction.

Declining Attack should use the existing authoritative Squadron Activation
semantics and result in the canonical Attack-action disposition becoming
`declined`.

The player should not need to begin Attack target-selection/presentation merely
to expose the choice to decline the Attack action.

## Actual

During Hot-Seat Squadron Phase testing, an activated X-wing squadron could not
directly decline its available Attack action from the initial Squadron
Activation interaction.

The player first had to enter the Attack interaction.

Once the Attack interaction had been entered, the existing decline/skip action
became available and worked correctly. After using it, canonical state recorded:

`attack_action_disposition == "declined"`

and the Squadron Activation completed normally.

Thus the authoritative decline behavior appears to exist and work, but the
decline choice is not exposed at the expected interaction level.

## Reproduction

1. Enter the Squadron Phase.
2. Activate an eligible squadron.
3. Reach the Squadron Activation state with the Attack action available.
4. Before entering the Attack interaction, attempt to decline the Attack action.

Result:

There is no direct way to decline Attack from the initial Squadron Activation
interaction.

5. Enter the Attack interaction.
6. Use the available decline/skip action.

Result:

The Attack action can now be declined and canonical state records the Attack
action as `declined`.

Frequency: Once

## Evidence

- `annotation_20260822_180414_002.json`
- `annotation_20260822_180522_003.json`

The first annotation captures the Squadron Activation before the workaround.
The activated X-wing is in Squadron Phase and its Attack action remains
available, but the player cannot directly decline that action.

The second annotation captures the state after entering the Attack interaction
and using the available decline action. Canonical state then records:

- the squadron remains associated with its Squadron Phase activation;
- `attack_action_disposition == "declined"`;
- `activated_this_round == true`;
- no active `CurrentAttackState` remains.

The before/after evidence therefore suggests that the underlying authoritative
decline semantics work correctly. The observed defect is that the choice is
only exposed after entering the nested Attack interaction.

## Initial Assessment

This currently appears to be a Squadron Activation interaction/command-flow
issue rather than an Attack rules or canonical-state defect.

The implementation should determine whether the Squadron Activation interaction
already derives the legal Attack-decline decision but fails to project it, or
whether the decline choice is currently derived only after entering the Attack
interaction.

Any repair should reuse the existing authoritative Attack-action disposition and
decline command/path.

Do not introduce:

- presentation-local gameplay state;
- a second decline mutation path;
- a UI-only disposition;
- direct controller mutation of Squadron Activation state.

The authoritative result of declining Attack should remain the existing
canonical `attack_action_disposition == "declined"` state.

## Relationship to BUG-035

This issue was discovered during BUG-035 Hot-Seat manual QA but is currently
classified separately.

BUG-035 concerns completed-Attack inspection/release and composed-return
convergence.

BUG-037 occurs before an Attack is committed: no active Attack needs to complete
or return through the BUG-035 post-Attack continuation path.

The fact that the existing decline action works after entering the Attack
interaction further suggests that BUG-037 is an interaction-entry/choice
exposure issue rather than another completed-Attack convergence failure.

BUG-037 should therefore not block BUG-035 unless later investigation shows a
shared authoritative defect.

## Resolution

Root cause:

Fix:

Verification:

- Activate a squadron during Squadron Phase with Attack available.
- Verify that Attack can be declined without first entering Attack
  target-selection/presentation.
- Verify that declining records the canonical Attack-action disposition as
  `declined`.
- Verify that no `CurrentAttackState` is created merely to decline Attack.
- Verify that entering and performing a legal Attack remains unchanged.
- Verify that choosing Attack and then following its normal commitment path
  remains unchanged.
- Verify that Squadron Activation converges to the same authoritative outcome
  regardless of whether Attack is declined through the direct interaction or
  through any still-supported equivalent path.
- Verify Hot-Seat behavior.
- Verify Network behavior when BUG-037 is eventually scheduled for
  implementation.


===== FILE: docs/qa/bugs/verify/BUG-008/issue-Range-overlay-remains-visible-on-client-after-host-fleet-command-completes.md =====

# BUG-008 — Range overlay remains visible on client after host fleet command completes

Severity: Low–Medium
Area: Network / Range Overlay
Layer: Presentation / Projection

## Expected

When a fleet command or related interaction that displays the range overlay is
completed, the range overlay should be dismissed on all clients where it was
shown.

The client presentation should reflect that the interaction requiring the
range overlay has ended.

## Actual

During network play, after the fleet command is executed by the host, the range
overlay remains visible on the other player's client.

In the observed case, the Imperial client continued displaying the range
overlay after the host had completed the fleet-command interaction.

Gameplay otherwise appeared to continue.

## Reproduction

Observed during network play.

1. Start a network game.
2. Reach a situation in which a fleet command displays the range overlay.
3. Execute/complete the fleet command on the host.
4. Observe the other player's client.

Result:

- the host completes the fleet-command interaction;
- the range overlay remains visible on the client.

## Evidence

- `annotation_20260804_221320_002.json`

Annotation:

`I relize another bug. after fleet command has been executed by the host, the
range overlay will not vanish on the client (in this case imperial) screen.`

The captured state is in Round 3 Ship Phase after gameplay has continued,
supporting the interpretation that this is primarily stale client presentation
rather than an obvious canonical game-flow stall.

## Initial Assessment

Root cause is unknown.

This should be treated as a presentation/projection lifecycle defect unless
investigation produces evidence of an underlying canonical-state problem.

Likely investigation areas include:

- network handling of fleet-command completion;
- range-overlay dismissal events;
- host versus mirrored-client presentation cleanup;
- whether accepted command/result projection dismisses the overlay locally but
  fails to perform equivalent cleanup on the remote client;
- lifecycle cleanup when the interaction that requested the range overlay ends.

### Architecture Constraint

The range overlay is presentation/tool state and must not become canonical
gameplay state merely to repair this synchronization defect.

In particular, the repair must not introduce concepts such as
`range_overlay_visible`, equivalent UI visibility state, or range-tool
lifecycle state into `GameState` or another authoritative gameplay owner solely
for network synchronization.

Range measurement is a player-side tool. Its presentation does not require
semantic command representation or deterministic replication merely because
Hot-Seat and Network presentation differ.

The preferred repair direction is therefore:

authoritative gameplay transition
→ accepted/mirrored result
→ derived presentation lifecycle
→ local overlay cleanup

The client should derive that the interaction requiring the overlay has ended
and dismiss its local presentation accordingly.

If investigation shows that an existing canonical gameplay fact required to
derive this cleanup is missing, stop and report that architectural finding
rather than introducing new authoritative presentation state as part of the
bug fix.

## Resolution

Root cause:
TBD

Fix:
TBD

## Verification

After repair, verify:

- overlay appears correctly when required on the host;
- overlay appears correctly when required on the client;
- completing the interaction dismisses it on the host;
- completing the interaction dismisses it on the client;
- dismissal occurs after authoritative/mirrored completion rather than through
  optimistic canonical mutation;
- subsequent range-overlay interactions can still be opened normally;
- Hot-Seat behavior remains unchanged;
- replay/reconnect does not leave a stale overlay visible.

## Implementation Update — 2026-08-14

Confirmed root cause:

The ship-command range overlay was opened locally by
`SquadronPhaseController.open_for_command()` and dismissed by the local
`squadron_command_done` callback. A passive network peer did not execute that
local callback. Although its accepted mirrored `InteractionFlow` left
`SQUADRON_STEP`, `ShipActivationController.sync_activation_step_from_flow()`
did not retire the peer's transient command overlay.

Implemented fix:

When an accepted/mirrored ship-activation projection is no longer at
`SQUADRON_STEP`, each peer asks its local `SquadronPhaseController` to dismiss
the command range overlay. A later command can create a fresh overlay normally.

Architecture Constraint compliance:

The repair derives cleanup from the existing accepted `InteractionFlow` step
and mutates only the local overlay node. No `range_overlay_visible`, canonical
tool lifecycle, semantic command, network field, or serialized UI state was
introduced. `InteractionFlow` remains projection/routing state, not gameplay
or activation authority.

Regression evidence:

`test_command_range_overlay_retires_from_accepted_step_on_each_peer` proves
overlay creation, retention during the Squadron step, Hot-Seat dismissal,
passive network-client dismissal, and subsequent reuse.

Verification:

- focused `test_ship_activation_controller.gd`: 8/8 passed;
- full repository suite: 4,048/4,048 passed (13,507 assertions);
- architecture lint and `git diff --check`: passed.

Status: repaired by automated evidence; ready for Project Owner/manual Network
verification.


===== FILE: docs/qa/bugs/verify/BUG-009/issue-Destroyed-ship-is-not-removed-immediately-on-defender-client.md =====

# BUG-009 — Destroyed ship is not removed immediately on defender client

Severity: Medium
Area: Network / Ship Destruction
Layer: Presentation / Projection

## Expected

When a ship is destroyed by an accepted attack:

1. canonical game state must mark the ship destroyed;
2. all peers must receive the authoritative result;
3. the destroyed ship must be removed or otherwise shown as destroyed on both
   attacker and defender screens without requiring another gameplay event or
   manual refresh.

The defender's local presentation must derive from the same accepted canonical
state as the attacker.

## Actual

The CR90 Corvette A reached destruction during an attack.

On the attacker's screen, the CR90 was correctly shown as destroyed.

On the defender's screen, the CR90 was not shown as destroyed immediately.

The first observation therefore appeared to show a ship surviving at zero hull,
but a follow-up observation established that destruction had occurred
canonically and was already visible to the attacker.

The defect is therefore a stale defender/client presentation rather than an
obvious failure of canonical destruction.

## Reproduction

Observed during network play.

1. Attack the CR90 until the attack destroys it.
2. Observe the attacker screen.
3. Observe the defender screen immediately after the accepted destruction.

Result:

- attacker: CR90 is shown destroyed;
- defender: CR90 remains visible / does not immediately reflect destruction.

## Evidence

- `annotation_20260804_221638_001.json`
- `annotation_20260804_221817_002.json`

### First observation

The first annotation states:

`Another bug the CR90 was not destroyed at 0 hull.`

The captured state already contains:

- `destroyed = true` for the CR90;
- lethal accumulated damage;
- no active `CurrentAttackState`.

This means the canonical snapshot itself does not support the interpretation
that destruction failed.

### Follow-up observation

The second annotation clarifies:

`on the attacker screen the CR90 was actually destroyed. only on defender
screen this is not showing up right away.`

This narrows the issue to presentation/projection synchronization on the
defender side.

## Initial Assessment

The evidence strongly suggests a remote/client presentation refresh defect.

Likely investigation areas include:

- mirrored attack/damage result handling;
- destruction notification propagation;
- ship-scene removal or visibility refresh on the defending client;
- whether local attack resolution emits a destruction/ship-refresh signal that
  the mirrored client path does not emit;
- ordering between canonical damage installation and presentation refresh;
- whether destruction is projected only after a later unrelated board refresh.

The canonical `destroyed` state must remain authoritative.

Do not repair this by introducing separate client-owned destruction state or UI
state into `GameState`.

### Architecture Constraint

Ship destruction is canonical gameplay state.

The repair should therefore follow:

authoritative damage/destruction command
→ accepted/mirrored canonical state
→ derived ship presentation refresh/removal

The defender client must not independently infer, predict, or authoritatively
mark destruction.

Likewise, presentation state such as `ship_visible`, `destroyed_marker_visible`,
or equivalent UI flags should not become new canonical gameplay fields solely
to fix this refresh issue.

If investigation shows that the canonical destruction result itself is not
being distributed correctly, stop and report that separately rather than
masking the problem with local UI mutation.

## Relationship to BUG-019

BUG-009 and BUG-019 may share a presentation-refresh seam.

BUG-009:
- accepted ship destruction is not reflected immediately on the defender client.

BUG-019:
- ship damage display does not refresh immediately after collision damage.

Both suggest that some remote damage/destruction paths may fail to trigger the
same presentation refresh used by local paths.

Keep the issues separate for traceability, but investigate them together when
the Presentation / Projection batch is implemented.

## Resolution

Root cause:
TBD

Fix:
TBD

## Verification

After repair, verify:

- lethal attack marks the ship destroyed canonically;
- attacker presentation updates immediately;
- defender presentation updates immediately;
- destroyed ship is removed/hidden consistently on both peers;
- no duplicate destruction processing occurs;
- non-lethal damage still refreshes correctly;
- destruction caused by attack, collision, critical effect, and other damage
  transactions all use the correct projection path;
- Hot-Seat behavior remains correct;
- replay/reconnect reconstruct destroyed ships correctly;
- BUG-019 regression remains green.

## Implementation Update — 2026-08-14

Confirmed root cause:

Mirrored `ResolveDamageCommand` correctly installed canonical damage and
destruction, but remote presentation attempted to send a `ShipInstance`
through the token-typed `ship_destroyed` event. `GameBoard` had no canonical
instance destruction-refresh route, so the defender's board token remained.
The card/sidebar/score refreshes were likewise tied to the local token event.

Exact production failure path:

lethal attack accepted on authority -> mirror executes and marks defender
`ShipInstance` destroyed -> remote handler has the canonical instance but no
usable board-token refresh -> defender presentation stays active until an
unrelated rebuild.

Implemented fix:

- Accepted/mirrored hull projection now drives board-token retirement by
  resolving the local token from the canonical `ShipInstance`.
- Ship card, activation sidebar, and phase HUD re-read canonical state at the
  same projection boundary.
- Loaded destroyed ships are not recreated as board pieces.
- A transient token-node marker makes the local and mirrored fade routes
  idempotent; it is never consulted for gameplay authorization.

Architecture Constraint compliance:

Destruction remains command-owned canonical `ShipInstance` state. The repair
does not predict destruction, add client-owned visibility/destruction state,
or submit a semantic transition from presentation.

Regression evidence:

- `test_remote_lethal_hull_projection_removes_destroyed_ship_token` proves the
  defender-side token is retired from canonical destruction.
- `test_accepted_lethal_damage_projection_ghosts_without_magnification`
  proves immediate card projection.
- BUG-019 mirrored collision refresh and pending-result regressions also pass.

Verification:

- focused board/card/damage suites: 8/8, 25/25, and 29/29 passed;
- full repository suite: 4,048/4,048 passed (13,507 assertions);
- architecture lint and `git diff --check`: passed.

Status: repaired by automated evidence; ready for Project Owner/manual
attacker/defender Network verification.


===== FILE: docs/qa/bugs/verify/BUG-011/issue-network-replay-rng-bootstrap-repair-plan.md =====

# BUG-011 — Network Replay RNG Bootstrap Repair Plan

Status: Accepted
Accepted by: Project Owner
Accepted date: 2026-08-05

Classification: Networking / Serialization / Replay

Confirmed root cause: `NETWORK REPLAY RNG BOOTSTRAP DEFECT`

Authority:

- ADR-001
- ADR-003
- ADR-005
- CON-001
- TWI-002

Supporting implementation evidence:

- TWI-002 Remaining Implementation Execution Map
- Replay Baseline Workflow
- Accepted network replay RNG bootstrap investigation report
- Current replay, lobby, network configuration, game bootstrap, RNG, and
  baseline-verification implementation

This document is a bounded implementation repair specification. It is not an
ADR, Contract, Migration Assessment, implementation workbook, or replacement
for TWI-002. It does not authorize implementation before Owner acceptance.

## 1. Status And Purpose

The purpose of this plan is to define the smallest repair that makes a format-3
network replay reconstruct the match RNG from its recorded replay header.

The repair covers only the bootstrap transaction that selects the replay seed,
distributes it to both network peers, and constructs both peers' initial
`GameState.rng`. Its boundary ends before normal game initialization and replay
command execution continue.

The existing network replay fixture is evidence for this repair. The fixture is
not to be edited, converted, or regenerated to make the repair pass.

## 2. Confirmed Root Cause

The confirmed root cause is:

> NETWORK REPLAY RNG BOOTSTRAP DEFECT

The authoritative recording path writes the match RNG seed from
`GameState.rng.initial_seed` into the format-3 replay header. `GameReplay`
loads that exact recorded value, and `ReplayDriver` stores it in
`pending_replay_seed`.

Network replay then enters the ordinary lobby start path. That path currently:

1. generates a new time-derived seed in `LobbyManager.request_start_game()`;
2. distributes the new seed through the existing network game configuration;
3. causes `GameManager.bootstrap_game()` on both peers to construct the match
   from the distributed lobby seed; and
4. ignores `ReplayDriver.pending_replay_seed` because the replay is running in
   network mode.

The new lobby seed therefore replaces the replay-header seed before canonical
game initialization. Setup-time RNG consumption and later command-time RNG
consumption then proceed from a different sequence than the recorded match.
`RollDiceCommand` correctly generates canonical dice from `GameState.rng`, and
`CommitAccuracyCommand` correctly validates against canonical
`CurrentAttackState.dice_results`; neither command is the source of the defect.

The current format-3 network replay demonstrates the resulting failure. Its
recorded sequence 77 projects one Accuracy result and sequence 80 legally locks
one defense token. Replay execution regenerates different canonical dice, so
sequence 80 is rejected with `Too many Accuracy lock targets.` The subsequent
`ReplayDriver` timeout is a downstream consequence of the rejected command.

## 3. Scope

This repair includes only:

- format-3 network replay bootstrap;
- the exact replay-header RNG seed already accepted by `GameReplay`;
- replay bootstrap coordination by `ReplayDriver`;
- host selection of the seed used for the replay lobby start;
- propagation of that seed to host and client through the existing network
  game-configuration path;
- validation that both peers received the accepted replay seed;
- construction of both peers' initial `GameState.rng` from that seed;
- deterministic consumption or clearing of replay-bootstrap seed state;
- focused failure behavior before game initialization or replay command
  execution can proceed; and
- focused automated and manual regression evidence.

The repair is complete at the first boundary where both peers have installed
the replay-header seed as the initial state of their authoritative runtime RNG.
Normal setup, damage-deck initialization, command execution, dice generation,
projection, and replay exhaustion then continue through their existing paths.

## 4. Explicit Exclusions

The repair does not include:

- dice-command changes;
- Accuracy validation changes;
- `CurrentAttackState` changes;
- replay command or replay payload changes;
- replay format changes or conversion;
- trace format changes;
- baseline generator or verifier redesign;
- editing or regenerating the existing failing replay;
- normal non-replay network game seed-generation changes;
- save/load network bootstrap or BUG-001;
- timing-window, Concentrate Fire, H9, or other TWI-002 semantic changes;
- production activation, save-version, or replay-version advancement;
- BUG-010 or targeting behavior;
- network-session, transport, RPC, ordering, retry, or lobby redesign;
- a new RNG owner, replay owner, network protocol, compatibility layer, feature
  flag, or temporary bridge; and
- general replay cleanup unrelated to the confirmed bootstrap boundary.

## 5. Accepted Ownership

| Responsibility | Accepted owner or boundary |
| --- | --- |
| Recorded seed value used to reconstruct a replay | The accepted `GameReplay` header |
| Replay startup coordination and one-shot bootstrap seed state | `ReplayDriver`; it does not own gameplay RNG |
| Selection of the seed supplied at host lobby start | Existing lobby bootstrap, using fresh generation for live games and the accepted header value for network replay |
| Distribution of the host-selected seed | Existing `NetworkManager` game-configuration path |
| Authoritative runtime RNG and its evolving state | `GameState.rng` |
| Deterministic gameplay RNG consumption | Existing commands and deterministic setup/resolver paths reading `GameState.rng` |

The host and client must begin replay reconstruction with identical
`GameState.rng` initial seed and state. Neither peer, projection, scene, UI, nor
replay command payload becomes an alternative RNG authority.

Normal live network games continue to use the existing fresh, host-selected
lobby seed. The replay-header seed is authoritative only for reconstruction of
the replay that carries it.

## 6. Intended Transaction

### 6.1 Normal Network Game

For a network game with no active replay:

1. `LobbyManager` generates the existing fresh time-derived seed.
2. The host distributes that seed through the existing game configuration.
3. Both peers construct `GameState.rng` from the distributed seed.
4. No replay-bootstrap state participates.

This behavior remains unchanged.

### 6.2 Network Replay

For a network replay:

1. `GameReplay` accepts the replay and exposes its exact header seed before the
   lobby start is requested.
2. `ReplayDriver` establishes that value as the pending one-shot replay
   bootstrap input on each peer.
3. The host lobby start selects that accepted replay seed. It does not generate,
   substitute, or fall back to a fresh seed.
4. The host distributes the selected seed to both peers through the existing
   game-configuration path before scene transition and game initialization.
5. Each peer verifies that the received configuration contains the same valid
   seed as its accepted replay header. Missing, zero/fallback, or mismatched
   replay bootstrap input fails closed.
6. Each peer constructs its initial `GameState.rng` from the accepted seed
   before any setup-time RNG consumer or replay command can run.
7. Each peer consumes or clears its pending replay-bootstrap seed state exactly
   once after successful installation.
8. Existing initialization and command execution continue without another RNG
   construction, randomization, or reset.

The transaction is successful only when both peers enter normal initialization
from the same accepted seed. A peer may not continue independently with a
fallback seed.

## 7. Likely Repository Change Surface

The smallest likely production surface is:

| File or seam | Bounded responsibility in this repair |
| --- | --- |
| `src/autoload/replay_driver.gd` | Coordinate the accepted replay-header seed as one-shot network replay bootstrap input and expose deterministic success/failure state. |
| `src/autoload/lobby_manager.gd` | Select the accepted replay seed for a network replay host start while preserving fresh seed generation for every normal network start. |
| `src/autoload/game_manager.gd` | At the existing bootstrap boundary, reject missing/mismatched replay configuration, construct `GameState.rng` from the accepted network replay seed, and consume bootstrap state before initialization continues. |

Existing supporting seams expected to remain structurally unchanged:

- `src/autoload/network_manager.gd` already distributes one supplied seed to
  host and client through the accepted game-configuration path;
- `src/core/commands/game_replay.gd` already owns the format-3 replay header and
  exact seed decoding;
- `src/core/state/game_rng.gd` already constructs deterministic equal streams
  from equal non-zero seeds;
- `RollDiceCommand`, `CommitAccuracyCommand`, `CurrentAttackState`, and all
  dice/Accuracy calculation paths remain unchanged; and
- both baseline scripts and the network replay fixture remain unchanged.

Focused evidence is expected in the existing replay, lobby/bootstrap, network,
and RNG test layers. Exact test-file placement may follow existing repository
conventions, but the likely homes are:

- `tests/unit/test_replay_driver.gd`;
- the existing focused `LobbyManager` scenario/bootstrap tests;
- `tests/unit/test_network_manager.gd` for unchanged configuration propagation;
- the existing game-board/game bootstrap test surface;
- `tests/integration/test_network_transport.gd`; and
- the authoritative network baseline gate using the unchanged
  `tests/fixtures/baseline_traces/replay_network.json`.

Implementation stops if this behavior cannot be expressed through these
existing owners and the existing game-configuration path.

## 8. Atomicity And Failure Behavior

- The accepted seed selection, network distribution, peer validation, and
  initial `GameState.rng` construction form one bootstrap transaction.
- Host and client must receive and accept the same replay-header seed.
- No peer may begin normal game initialization with a missing, random,
  time-derived, mismatched, or otherwise substituted seed during network
  replay.
- Invalid or missing replay seed data must fail before replay command execution.
- A host/client seed mismatch must fail before either peer can be treated as a
  successfully bootstrapped replay participant.
- No replay command may execute before RNG bootstrap succeeds.
- Failed bootstrap must not consume replay commands or produce an accepted
  partial replay result.
- Pending replay-bootstrap state is consumed exactly once on success and cannot
  affect a later game start.
- Normal live-network start behavior must be identical to the pre-repair
  behavior.

## 9. Automated Verification

Focused automated evidence must prove all of the following:

- a valid network replay selects the exact header seed;
- the host places that exact value into the existing network game
  configuration;
- the client receives the identical value;
- both peers construct `GameState.rng` with the same `initial_seed` and initial
  state before setup proceeds;
- deterministic setup-time RNG consumption, including damage-deck
  initialization, remains identical on both peers;
- subsequent deterministic dice generation remains identical for the same
  command sequence;
- the existing format-3 `replay_network.json` reaches sequence 80 unchanged and
  accepts its one-token `commit_accuracy` command;
- the existing replay exhausts successfully;
- host and client final canonical state hashes match;
- hot-seat replay bootstrap and the committed hot-seat trace/hash gate remain
  unchanged;
- a normal fresh network game still selects a fresh lobby seed and never
  consumes replay-bootstrap state;
- missing, zero/fallback, or mismatched replay seed state fails closed before
  command execution;
- successful bootstrap consumes pending replay seed state exactly once; and
- all relevant replay, RNG, lobby/bootstrap, network, and baseline regressions
  pass.

No test may make the replay pass by replacing recorded dice, bypassing command
validation, editing replay sequence 80, or introducing a test-only bootstrap
authority.

## 10. Minimal Manual Verification

1. Run the existing format-3 network replay through
   `scripts/generate_baseline_fixtures.sh --mode network` without editing or
   rerecording it.
2. Confirm that both peers report replay exhaustion and that sequence 80
   `commit_accuracy` is accepted.
3. Confirm that the generator reports host/client final-state peer equality and
   requires no replay promotion or fixture modification.

## 11. Stop Conditions

Stop implementation and return to the Owner if any of the following is found:

- the repair requires a new authoritative RNG, replay, lobby, or network owner;
- the repair requires a new network protocol, RPC payload, transport path, or
  compatibility mode;
- the repair requires a replay-format or replay-payload change;
- the repair requires changes to dice generation, Accuracy semantics,
  `CurrentAttackState`, or any recorded replay command;
- the repair conflicts with TWI-002 or changes any TWI-002 semantic checkpoint;
- normal live-network fresh-seed behavior cannot be preserved;
- the replay seed cannot be delivered through the existing network
  game-configuration path;
- either peer must begin initialization before the seed is validated;
- the existing failing replay cannot remain byte-for-byte unchanged; or
- the defect proves to depend on BUG-001, BUG-010, targeting, save/load
  bootstrap, or another excluded behavior.

## 12. Binary Completion Criteria

The repair is complete only when every statement below is true:

- [ ] The previously failing format-3 network replay succeeds unchanged.
- [ ] Sequence 80 `commit_accuracy` is accepted.
- [ ] Host and client both initialize `GameState.rng` from the recorded replay
      header seed.
- [ ] Neither peer uses a generated or fallback seed during network replay.
- [ ] Host/client final canonical state hashes match.
- [ ] Replay execution exhausts without a command timeout.
- [ ] Hot-seat replay behavior remains unchanged.
- [ ] Normal network games retain the existing fresh lobby-seed behavior.
- [ ] Invalid, missing, or mismatched replay-bootstrap seed state fails closed
      before command execution.
- [ ] Pending replay-bootstrap state is consumed exactly once.
- [ ] No replay, trace, save, or compatibility version changes.
- [ ] No dice, Accuracy, CurrentAttackState, timing-window, TWI-002, BUG-001,
      BUG-010, targeting, generator, or verifier behavior changes.
- [ ] All focused and relevant regression evidence passes.
- [ ] No new owner, protocol, compatibility layer, feature flag, or temporary
      bridge is present.


===== FILE: docs/qa/bugs/verify/BUG-030/issue-CR90-shield-damage-does-not-refresh-on-owning-host.md =====

# BUG-030 — CR90 shield damage does not refresh on owning host

Severity: Medium
Area: Ship Damage / Network Presentation
Layer: Presentation / Projection

## Expected

When a ship suffers shield damage, the updated shield values must be presented
consistently on all relevant peers after the authoritative damage result has
been accepted.

In particular, the player owning the damaged ship must immediately see the
updated shield values on their own host presentation.

Hot-Seat, network host, and network client presentation should all derive the
displayed shield state from the accepted canonical ShipInstance state.

## Actual

During network play, shield damage to the Rebel CR90 was displayed correctly
on the Imperial player's client but was not displayed correctly on the Rebel
player's host.

The two peers therefore presented different shield state for the same
canonically damaged ship.

## Reproduction

Observed once during network play.

1. Rebel player is the network host and owns the CR90 Corvette A.
2. Imperial player is the network client.
3. The CR90 suffers damage affecting its shields.
4. Observe the CR90 shield presentation on both peers.

Result:

- Imperial/client presentation shows the shield damage correctly.
- Rebel/host presentation does not show the corresponding shield damage.
- Canonical game state contains the reduced shield values.

## Evidence

- `annotation_20260815_151129_001.json`

Annotation:

`I realize another UI BUG. toe damage on the CR-90 Shields are not displayed
on the rebel player (host). They are displayed on the imperial players screen
(client) correctly.`

The captured canonical state shows the Rebel CR90 with:

- `current_hull = 4`
- `FRONT = 2`
- `LEFT = 0`
- `REAR = 1`
- `RIGHT = 0`
- `destroyed = false`

The game is in Round 3 Ship Phase.

This is strong evidence that the observed problem is not simply missing
canonical damage mutation: the canonical ShipInstance already contains the
reduced shield values while the owning host presentation is reported as stale.

## Initial Assessment

This appears to be a presentation/projection defect rather than a damage-rule
or canonical-state defect.

The asymmetric result is particularly relevant:

- the passive Imperial/client presentation receives and displays the changed
  shield state correctly;
- the Rebel/network-host presentation remains stale;
- canonical state already contains the reduced shields.

Investigation should therefore compare the accepted local/host damage-result
projection path with the mirrored network-client projection path.

Likely investigation areas include:

- accepted ship-damage result handling on the authoritative host;
- shield/hull refresh events emitted after local accepted damage commands;
- mirrored-result refresh handling that may already work correctly;
- ship-card and/or board-token shield presentation refresh;
- whether the local authoritative route incorrectly assumes that canonical
  mutation automatically refreshes presentation.

The repair should project already-accepted canonical ShipInstance state into
the local presentation. It should not introduce duplicate damage mutation,
network-specific canonical state, or presentation-owned shield state.

## Relationship to Earlier Presentation Bugs

BUG-030 may be related to the accepted-result presentation/projection gaps
previously found in BUG-019 and BUG-027.

Those repairs should be inspected for an established projection pattern before
introducing another refresh mechanism.

Do not merge BUG-030 with an earlier issue unless investigation proves that
the same remaining root cause and repair actually cover this case.

## Architecture Constraint

`ShipInstance` remains authoritative for shield and hull state.

The fix must not:

- mutate shield values from presentation code;
- introduce a second shield-state owner;
- synchronize presentation-only state through GameState;
- duplicate damage resolution;
- weaken command authority.

The desired flow is:

accepted authoritative damage
→ canonical ShipInstance mutation
→ accepted-result projection
→ local host and remote client presentation refresh

Both peers should ultimately render the same accepted canonical state.

## Resolution

Root cause:

The captured asymmetry was specifically the defender-owned Redirect shield
path, not a general failure of canonical damage resolution. The accepted
`SelectRedirectZoneCommand` correctly reduced the host-owned defender's
canonical shields. The server's accepted-result handler then skipped ordinary
host-local commands because their semantic mutation had already executed
inline. That assumption was incorrect for presentation: the inline Redirect
path intentionally performs no UI work, while the mirrored client result calls
`_handle_remote_select_redirect_zone()` and emits
`EventBus.ship_shields_changed`. The client refreshed; the defender-host did
not.

Exact failing path:

`SelectRedirectZoneCommand.execute()` mutates the host defender's
`ShipInstance` → accepted result is broadcast →
`GameManager._on_network_command_result()` sees a host-local player index and
skips result projection → no local shield refresh signal → host card/token
presentation remains stale. The client takes the mirrored handler and refreshes
correctly.

Fix:

The existing server accepted-result gate now routes
`select_redirect_zone` through the existing remote-effect projector even when
the defender is the local host. That projector only resolves the already
canonical ship reference and emits `ship_shields_changed` with the accepted
result value. It performs no shield mutation.

The repair is deliberately command-specific rather than a new refresh layer.
`ShipInstance` remains the shield owner; `SelectRedirectZoneCommand` remains the
only mutation; the event remains a one-way board/card presentation refresh. No
network state, replay entry, prediction, compatibility bridge, or serialized
field was added.

## Verification

After repair, verify:

- shield damage immediately refreshes on the damaged ship owner's network-host
  presentation;
- the remote client continues to display the same damage correctly;
- hull damage refreshes consistently as well;
- damage to ships owned by either host or client behaves equivalently;
- ship-card and board-token presentation agree with canonical ShipInstance
  state;
- rejected or pending commands do not optimistically change displayed damage;
- Hot-Seat behavior remains correct;
- replay/save/reconnect reconstruction displays canonical shield state;
- existing BUG-019 and BUG-027 regression behavior remains intact.

Implemented regression evidence models the production host boundary after the
command-owned shield mutation and proves:

- the accepted host-local Redirect result emits exactly one shield refresh for
  the canonical defender instance;
- projection does not reduce shields again and creates no command/replay
  history;
- a rejected result does not optimistically emit another refresh;
- existing client mirrored-result, Repair, collision/damage, board-token, and
  ship-card refresh suites remain green.

Verification on 2026-08-15:

- `test_network_command_result_ordering.gd`: 9/9 passed;
- `test_attack_commands.gd`: 64/64 passed;
- `test_current_attack_shared_protocol.gd`: 25/25 passed;
- full suite: 237 scripts, 4064/4064 tests, 13645 assertions passed;
- Phase-K architecture lint: 0 violations, with 4 existing allow-listed
  branches;
- `git diff --check`: passed.

Status: repaired and moved to verification; Project Owner manual Network
verification with the Rebel host as Redirecting defender remains required.
