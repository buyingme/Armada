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
