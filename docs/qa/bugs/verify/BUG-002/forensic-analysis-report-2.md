# Forensic conclusion

The August 1 incidents do not contain `SHIP_ACTIVATION / ATTACK_STEP` at capture time. Both serialize:

- `flow_type: 2` = `SHIP_ACTIVATION`
- `step_id: 7` = `MANEUVER_STEP`
- `ATTACK_STEP` is enum value `10`

This mapping is defined in [constants.gd](/Users/Katharina/godot/Armada/src/autoload/constants.gd:147).

The earliest incorrect production boundary is the activation modal’s scene-local auto-skip from Repair into Attack. That path does not submit `AdvanceActivationStepCommand("attack_step")`, so `ShipInstance.begin_attack_step()` is never called. The later `MANEUVER_STEP` snapshots are the downstream result.

No files were modified.

## 1. Documents and annotations read

Startup documents read and retained in context, as required by AGENTS.md:

- [AGENTS.md](/Users/Katharina/godot/Armada/AGENTS.md)
- [ARCHITECTURE.md](/Users/Katharina/godot/Armada/ARCHITECTURE.md)
- [AI_DEVELOPMENT_PRINCIPLES.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PRINCIPLES.md)
- [AI_DEVELOPMENT_PROCESS.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PROCESS.md)
- [AI_STARTUP_GUARDRAILS.md](/Users/Katharina/godot/Armada/.ai/instructions/AI_STARTUP_GUARDRAILS.md)
- [DOCUMENT_AUTHORITY.md](/Users/Katharina/godot/Armada/docs/architecture/DOCUMENT_AUTHORITY.md)
- [ARCHITECTURE_ROADMAP.md](/Users/Katharina/godot/Armada/docs/architecture/ARCHITECTURE_ROADMAP.md)
- [CODEX_WORKFLOW.md](/Users/Katharina/godot/Armada/docs/architecture/CODEX_WORKFLOW.md)

Authority and supporting evidence read:

- [BUG-002 issue](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-002/issue_attack-sequence-early-termination.md)
- [Accepted BUG-002 forensic analysis](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-002/forensic-analysis-report.md)
- [ADR-001](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md)
- [CON-001](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md)
- [CON-006](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-006-attack-declaration-lifecycle-contract.md)
- [Rules Reference](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:90)
- Current uncommitted BUG-002 implementation diff

Only these annotations were used as fresh incident evidence:

- [annotation_20260801_075338_001.json](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-002/annotation_20260801_075338_001.json:1)
- [annotation_20260801_075833_003.json](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-002/annotation_20260801_075833_003.json:1)

The July 27 annotations were not used to explain the post-repair failures.

## 2. August 1 incident reconstruction

| Evidence | Victory II Step 6 incident | Nebulon-B second-attack incident |
|---|---|---|
| Round/phase | Round 2, Ship Phase | Round 3, Ship Phase |
| Flow identity | Controller `1`, owner-local ship index `0` | Controller `0`, owner-local ship index `1` |
| Acting ship | Victory II-class Star Destroyer | Nebulon-B Escort Frigate |
| Activation status | `activated_this_round == false` | `activated_this_round == false` |
| `CurrentAttackState` | Fully inactive | Fully inactive |
| `attack_step_active` | `false` | `false` |
| `committed_attack_count` | `0` | `0` |
| `used_attack_hull_zones` | `[]` | `[]` |
| `anti_squadron_attack_zone` | `-1` | `-1` |
| `anti_squadron_target_history` | `[]` | `[]` |
| Reported expected continuation | Another eligible X-Wing in the same-zone Step 6 iteration | Second normal attack against the Victory II from another hull zone |
| Actual state | No continuation available | No second declaration available |
| Captured flow | `SHIP_ACTIVATION / MANEUVER_STEP` | `SHIP_ACTIVATION / MANEUVER_STEP` |

The VSD fields appear at [lines 667–734](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-002/annotation_20260801_075338_001.json:667). The Nebulon-B fields appear at [lines 540–599](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-002/annotation_20260801_075833_003.json:540). Both flow snapshots contain `step_id: 7` at line 469.

Both ships also satisfy the modal’s unavailable-command auto-skip conditions:

- The Victory II has no Squadron command resource. Although it has a Repair token, it is fully healthy, so `_has_repair_resources()` returns false.
- The Nebulon-B has a Navigate dial and no command tokens, so it has neither Squadron nor Repair resources.

The resource checks are defined in [game_board.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/game_board.gd:1145).

## 3. Attack-step entry timeline

### Command-backed path

1. Ship activation establishes an activation context containing the selected `ShipInstance`.
2. Completing or skipping Repair calls `_on_repair_done()`.
3. The controller submits `AdvanceActivationStepCommand("attack_step")` for that ship.
4. `GameManager` derives the owner-local index from `ship.owner_player`.
5. The command resolves that same ship, invokes `begin_attack_step()`, then publishes `SHIP_ACTIVATION / ATTACK_STEP`.
6. Projection updates the scene-local `ShipActivationState`.

Evidence:

- Controller submission: [ship_activation_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/ship_activation_controller.gd:1132)
- Owner-local identity construction: [game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:1578)
- Atomic progress/flow mutation: [advance_activation_step_command.gd](/Users/Katharina/godot/Armada/src/core/commands/advance_activation_step_command.gd:63)
- Owner-local lookup: [game_state.gd](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:110)

No command-backed production path publishes `SHIP_ACTIVATION / ATTACK_STEP` without calling `begin_attack_step()`.

### Broken auto-skip path

1. `ActivationModal.open()` advances its scene-local activation state from Reveal.
2. With Squadron and Repair unavailable, the modal timers call `ShipActivationState.skip_step()` twice.
3. The local state reaches Attack without emitting a controller signal or submitting an activation-step command.
4. Because targets exist, the auto-skip chain stops and exposes Execute Attack.
5. Pressing Execute Attack calls `AttackExecutor.start_ship_attack()` directly.
6. The executor publishes the derived `ATTACK / ATTACK_DECLARE` flow, but the authoritative `ShipInstance` remains inactive.
7. Confirm submits `BeginAttackCommand`.
8. Begin accepts the declaration but does not commit ship progress because `_tracked_attacker_ship()` returns null when `attack_step_active` is false.
9. `CompleteAttackCommand` retires the individual attack but likewise finds no tracked ship and produces no continuation.
10. The executor sees no authoritative Step 6 or second-attack availability, finishes the Attack step, and submits `AdvanceActivationStepCommand("maneuver_step")`.
11. That command publishes the captured `SHIP_ACTIVATION / MANEUVER_STEP` state.

The bypass is in [activation_modal.gd](/Users/Katharina/godot/Armada/src/ui/combat/activation_modal.gd:949). Its transition at line 1025 changes only `ShipActivationState`.

The downstream finish is in [attack_executor.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:4052).

## 4. Identity propagation

| Boundary | Identity behavior | Finding |
|---|---|---|
| Activation selection | Context receives the selected token and `ShipInstance` | Same object is retained locally |
| `GameManager.submit_advance_activation_step` | Uses `ship.owner_player` and `GameState.find_ship_index(ship)` | Owner-local identity |
| `AdvanceActivationStepCommand` | Resolves `get_ship(player_index, ship_index)` | Correct canonical ship when submitted |
| Published activation flow | Controller is command player; payload contains that owner-local index | Matches both annotations |
| Begin | Requires command player to equal `attacker_player`; resolves owner-local attacker index | No global-index conversion |
| Complete | Resolves the ship from the active attack’s owner-local attacker identity | Same canonical identity, but filters it out when inactive |
| Final Maneuver command | Uses the activation-context ship’s owner and owner-local index | Explains the correct controller/index in both annotations |

`GameManager.active_player` is not serialized in the annotations, so its runtime value cannot be reconstructed. It is not used to resolve the ship for either Advance or Begin. There is no evidence of owner-local/global-index confusion or of the wrong `ShipInstance` being initialized.

## 5. Complete mutation inventory

| Mutation surface | Effect |
|---|---|
| Field initialization/new instance | `false`, `0`, `[]`, `-1`, `[]` |
| `begin_attack_step()` | Activates progress and initializes all four progress collections/counters |
| `commit_attack()` | Commits a normal attack count and used zone, or appends a Step 6 target |
| `end_anti_squadron_attack()` | Clears only Step 6 zone/history |
| `end_attack_step()` | Sets active false and clears Step 6 state; retains committed count and used zones |
| `restore_attack_progress()` | Restores all five fields after failed atomic Begin installation |
| `reset_activation()` | Clears all five fields at the round/status reset boundary |
| `deserialize()` | Reconstructs all five serialized values, defaulting absent fields |
| `AdvanceActivationStepCommand("attack_step")` | Calls `begin_attack_step()` |
| Advance to Maneuver/Done | Calls `end_attack_step()` |
| Accepted standard ship Begin | Calls `commit_attack()` only if the tracker is already active |
| Complete | May close an exhausted Step 6 iteration; otherwise derives continuation without resetting the tracker |
| `SkipAttackCommand("squadron_done")` | Ends Step 6 while preserving normal attack count and used hull zone |

The field implementation is centralized in [ship_instance.gd](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:338).

For both August incidents, the data was never initialized. It was not initialized on another ship, written and reset, overwritten by completion, or lost through serialization. The final Maneuver command called `end_attack_step()` on already-default state.

## 6. First incorrect boundary

The first incorrect boundary is:

> The controller-side activation modal advances its scene-local `ShipActivationState` from Repair to Attack through `_auto_skip_current_if_gen()` without submitting the existing authoritative Attack-step transition.

At that moment:

- presentation says the player is at Attack;
- the authoritative `ShipInstance` still says no Attack step is active;
- no authoritative declaration opportunity exists;
- the player can nevertheless enter declaration UI.

The snapshots do not prove a state where canonical flow says `ATTACK_STEP` while the ship is inactive. They prove the downstream result after that missing transition: `MANEUVER_STEP` with no committed progress.

Hot-seat, host, and controlling-client presentations can all traverse the bypass because the auto-skip happens on the controlling peer. Passive clients use `open_mirror()` and do not auto-skip. Replay cannot recover the missing transition because no `AdvanceActivationStepCommand("attack_step")` was recorded. Reconstruction restores whatever serialized progress exists and does not call `begin_attack_step()`.

## 7. Permissive Begin

Permissive Begin is a second defect, not the earliest root cause.

[BeginAttackCommand](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:97) currently behaves as follows:

- `_tracked_attacker_ship()` returns null if `attack_step_active` is false.
- `_validate_ship_attack_progress()` treats that null as success.
- execution installs `CurrentAttackState` without committing attack count, hull-zone usage, or Step 6 history.

This violates:

- CON-006-BEGIN-001/002: Begin must validate the enclosing step, declaration opportunity, attack availability, hull-zone history, and stable authoritative owners.
- CON-006-BEGIN-004: possession of projection or flow state cannot authorize Begin.
- CON-006-BEGIN-006/007: accepted Begin must atomically commit applicable opportunity and existing-owner mutations.
- CON-006-DET-005: invalid authoritative state must fail closed.
- CON-001-LIFE-005 and CON-001-VAL-004: authority cannot be derived from scene, modal, projection, or UI state.

Failing Begin closed would expose the missing Attack-step transition immediately, but rejection alone would not restore valid gameplay. The entry transition must also be repaired.

## 8. Minimal coherent correction

The smallest coherent correction is bounded to two behaviors:

1. Every production route that reaches a playable ship Attack step—including the zero-resource Squadron/Repair auto-skip route—must complete the existing authoritative `AdvanceActivationStepCommand("attack_step")` transition for the correct owner-local ship before declaration presentation can begin.

2. A standard ship `BeginAttackCommand` must fail closed unless the referenced ship has the matching active authoritative Attack-step opportunity. Flow, modal state, or an `ATTACK_DECLARE` projection cannot substitute for that owner.

This uses the existing command and owners. It requires no new architecture, command, owner, compatibility layer, or scene-generated progress. Once initialized, the current BUG-002 Begin/Complete/Step 6/second-attack implementation can operate from the existing serialized `ShipInstance` fields.

Hot-seat, host, client, replay, save/load, and reconnect must therefore consume the same accepted command or serialized authoritative state; none should synthesize progress from the modal.

## 9. Missing automated production-path evidence

The passing tests separate the relevant boundaries:

- [test_activation_modal.gd](/Users/Katharina/godot/Armada/tests/unit/test_activation_modal.gd:256) proves only that scene-local auto-skip reaches Attack.
- [test_ship_activation_controller.gd](/Users/Katharina/godot/Armada/tests/unit/test_ship_activation_controller.gd:65) begins from a synthetic `REPAIR_STEP` and uses a recording submitter that does not execute the command.
- [test_advance_activation_step_command.gd](/Users/Katharina/godot/Armada/tests/unit/test_advance_activation_step_command.gd:71) executes the command directly.
- [test_current_attack_shared_protocol.gd](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:126) manually calls `ship.begin_attack_step()`.
- Production-resume fixtures likewise construct progress directly.

The missing high-value test is an end-to-end production activation beginning at `ACTIVATION_MODAL_OPEN` with:

- no Squadron resources;
- no usable Repair resources;
- at least one legal attack target.

It must traverse the real modal auto-skip and command processor, then prove before Preview/Begin that:

- an accepted `AdvanceActivationStepCommand("attack_step")` exists;
- flow controller and ship index match the selected ship;
- that exact `ShipInstance` has `attack_step_active == true`;
- Begin commits the first attack;
- Complete exposes Step 6 or a second normal attack rather than advancing to Maneuver.

That uncovered seam explains how 3,889 tests could pass.

## 10. Recommendation

**Ready for bounded implementation.**

Confidence is high. Both August incidents have the resource profile required for the same scene-only auto-skip route, both end with the exact downstream `MANEUVER_STEP`/zero-progress state produced by that route, and no production mutation can otherwise erase a committed count and used hull zone at this boundary.

The annotations do not contain command history, play mode, or `GameManager.active_player`, but those omissions do not block the bounded correction because the same bypass exists for every controlling presentation mode and the owner-local identities in both snapshots are consistent.
