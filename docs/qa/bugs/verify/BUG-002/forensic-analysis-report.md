Status:  accepted


## 1. Startup and authority documents read

Startup documents read before the audit:

- [AGENTS.md](/Users/Katharina/godot/Armada/AGENTS.md)
- [ARCHITECTURE.md](/Users/Katharina/godot/Armada/ARCHITECTURE.md)
- [AI_DEVELOPMENT_PRINCIPLES.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PRINCIPLES.md)
- [AI_DEVELOPMENT_PROCESS.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PROCESS.md)
- [AI_STARTUP_GUARDRAILS.md](/Users/Katharina/godot/Armada/.ai/instructions/AI_STARTUP_GUARDRAILS.md)
- [DOCUMENT_AUTHORITY.md](/Users/Katharina/godot/Armada/docs/architecture/DOCUMENT_AUTHORITY.md)
- [ARCHITECTURE_ROADMAP.md](/Users/Katharina/godot/Armada/docs/architecture/ARCHITECTURE_ROADMAP.md)
- [CODEX_WORKFLOW.md](/Users/Katharina/godot/Armada/docs/architecture/CODEX_WORKFLOW.md)

Authority documents read:

- [SWM Rules Reference Guide 1.5.0](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:79)
- [ADR-001](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md:90)
- [ADR-003](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md)
- [ADR-005](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md:86)
- [CON-001](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md:124)
- [CON-003](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-003-rule-capability-contract.md)
- [CON-005](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-005-timing-window-implementation-contract.md:300)
- [CON-006](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-006-attack-declaration-lifecycle-contract.md:208)
- [TEST-003](/Users/Katharina/godot/Armada/docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md)

Defect evidence read:

- [BUG-002 issue](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-002/issue_attack-sequence-early-termination.md:1)
- [Nebulon-B annotation](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-002/annotation_20260727_195551_001.json:2)
- [Victory II annotation](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-002/annotation_20260727_195741_001.json:2)

ADR-004/CON-004 were not needed to determine this defect: both snapshots contain no active timing window, runtime upgrade state, or faceup damage-card state affecting the reported continuation.

## 2. Authoritative rules

- A ship may normally perform two attacks during its activation and may not attack from the same hull zone more than once during that activation. The Ship Activation entry phrases this as “up to two attacks from different hull zones.” [Attack rule](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:126), [Ship Activation](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:1101).
- A ship declares the defender and attacking hull zone. The target must be in that hull zone’s firing arc and at attack range; normal line-of-sight restrictions apply. [Declare Target](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:94), [firing-arc measurement](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:674).
- Against a squadron, the ship uses its single anti-squadron armament regardless of the attacking hull zone. [Armament](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:81).
- After resolving one squadron, Step 6 permits the attacker to declare another enemy squadron and repeat Steps 2–6. The new target must remain in range and arc of the same attacking hull zone and must have normal line of sight. Each enemy squadron may be targeted only once during that attack. [Step 6](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:122).
- Step 6 is optional: the rule says the attacker “can” declare another target. Therefore one anti-squadron attack is complete when the attacker reaches Step 6 and either declines to declare another eligible squadron or no eligible squadron remains.
- The repeated squadron resolutions belong to the same normal ship attack opportunity. They are treated as new attacks only for resolving card effects. [Card-effect qualification](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:124).
- A second normal attack is a separate attack opportunity and must use a different hull zone. It may target the same surviving squadron because a ship may attack the same target with different attacks. [Same-target rule](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:128).
- Friendly ships and squadrons cannot be attacked. A declaration with no usable dice is cancelled. [Target restrictions](/Users/Katharina/godot/Armada/Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md:99).

Thus BUG-002’s phrase “against every eligible squadron” is accurate only as an available continuation, not a mandatory requirement. The defect is that the player cannot choose further eligible targets.

## 3. Incident reconstruction

| Evidence | Nebulon-B incident | Victory II incident |
|---|---|---|
| Acting controller and ship | Flow controller `0`, ship index `1`; that owner-local ship is the Nebulon-B Escort Frigate. | Flow controller `1`, ship index `0`; that owner-local ship is the Victory II-class Star Destroyer. |
| Enclosing state | Round 3, Ship Phase, `SHIP_ACTIVATION / ATTACK_STEP`; ship not yet marked activated. | Round 3, Ship Phase, `SHIP_ACTIVATION / ATTACK_STEP`; ship not yet marked activated. |
| Completed attack evidence | Annotation says the first TIE attack was confirmed; snapshot has inactive current attack and one destroyed TIE. | Annotation says one X-wing was attacked; snapshot has inactive current attack and an X-wing with reduced hull. |
| `CurrentAttackState` | Fully inactive, with no participant or hull-zone identity. | Fully inactive, with no participant or hull-zone identity. |
| Timing window | Inactive, with no lifecycle or continuation context. | Inactive, with no lifecycle or continuation context. |
| Interaction flow | Still the enclosing ship Attack step. | Still the enclosing ship Attack step. |
| Visible attack history | `ship_target_attack_counts` contains `2:0:1 = 1`, which belongs to round 2, not this round-3 incident. No Step 6 target history is serialized. | The same old round-2 entry remains. No current VSD attack count, fired-zone history, or Step 6 target history is serialized. |
| Expected next state | Same-zone Step 6 target declaration if another eligible TIE is chosen; after that anti-squadron attack ends, a second declaration from another hull zone if retained. | Same-zone Step 6 target declaration if another eligible X-wing is chosen; afterward, a different-zone second declaration if retained. |
| Reported actual state | No further TIE or second-hull-zone declaration can be initiated. | No further X-wing or second-hull-zone declaration can be initiated. |

The annotations establish that an individual attack ended, no timing window remained, the enclosing activation was still at its Attack step, and both continuation affordances were unavailable.

They do not prove the exact command history, network/hot-seat mode, which hull zone was used, the geometry of every alleged next target, whether the damaged/destroyed squadron result came exclusively from the immediately preceding attack, or the value of the non-serialized `GameManager.active_player`. Controller and ship identity are derived from the canonical flow payload.

## 4. Expected and actual lifecycle

| Stage | Rules-consistent lifecycle | Current failure lifecycle |
|---|---|---|
| First declaration | Choose hull zone and squadron; accepted Begin creates the individual attack. | Same. |
| First target resolution | Resolve Steps 2–5. | Same. |
| Step 6 | Preserve same attacking hull zone and prior-target history; offer another eligible squadron. | Individual state is completed while these facts exist only in scene-local state. |
| End of anti-squadron attack | Occurs only after Step 6 is declined or exhausted. | Loss/teardown of the local continuation context can make the first target appear to end the entire attack session. |
| Second normal attack | If retained, return to hull-zone selection excluding the first hull zone. | Used-zone and normal-attack count are unavailable authoritatively; the second declaration is lost. |
| Attack-step exit | Move to Maneuver only after the player declines/exhausts remaining legal attack opportunities. | The lifecycle is stranded at, or prematurely exits from, the enclosing Attack step. |

## 5. Production control-flow trace

A. Ship attack entry starts in `AttackExecutor.start_ship_attack()`. It initializes scene-local `AttackState`, starts the derived attack FSM, and opens hull-zone selection. [Entry path](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:781).

B. `TargetSelector` owns the transient declaration candidate. It blocks target changes while a current attack is active and builds the stable candidate after target selection. [Selection guard](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:621), [candidate construction](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:1183).

C. Explicit Confirm submits `BeginAttackCommand`. [Confirm path](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:1231).

D. `BeginAttackCommand` validates targeting and creates `CurrentAttackState`, but its execution does not mutate an enclosing attack counter, used-hull-zone record, or Step 6 target history. [Begin execution](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:43). This is inconsistent with CON-006’s accepted bindings for hull-zone usage, attack-step progress, and applicable target history. [CON-006 authority matrix](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-006-attack-declaration-lifecycle-contract.md:620).

E. Resolution commands advance the individual `CurrentAttackState`. After successful damage resolution, `CurrentAttackContinuation` derives `CompleteAttackCommand` when no Counter or immediate-effect decision remains. [Continuation derivation](/Users/Katharina/godot/Armada/src/core/state/current_attack_continuation.gd:42).

F. `CommandProcessor` queues that continuation before emitting the triggering command result and drains it afterward. [Command ordering](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:225). `CompleteAttackCommand` then correctly retires the individual current attack. [Completion](/Users/Katharina/godot/Armada/src/core/commands/complete_attack_command.gd:31).

G. The decision about what follows is still made from scene-local `AttackState`:

- `attacked_squads` controls Step 6 target eligibility;
- `fired_zones` controls hull-zone reuse;
- `current_attack` controls whether a second normal attack remains.

These are local token references/counters, not canonical serialized facts. [Local fields](/Users/Katharina/godot/Armada/src/core/combat/attack_state.gd:82).

H. After completion, `_finalize_completed_attack()` branches from those local fields to the Step 6 loop, second hull-zone selection, or complete teardown. [Branch point](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:3793). Step 6 appends the target locally and checks for more targets; finishing the loop increments the local attack count. [Step 6 finalization](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:3838), [loop end](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:3881).

In network projection, an inactive canonical attack combined with a non-declaration attack flow can cause `sync_mirror_from_flow()` to call `deactivate_primary_presentation()`, which clears all of those local facts. [Projection reaction](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_panel_controller.gd:186), [teardown](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:875).

## 6. First incorrect boundary

The first incorrect authoritative transition occurs at accepted `BeginAttackCommand`: it creates the individual `CurrentAttackState` but does not commit the enclosing ship attack opportunity, attacking hull-zone usage, or applicable target-iteration history to the accepted existing owners.

The first rules-visible divergence occurs at the subsequent `CompleteAttackCommand` handoff. Completion correctly removes the individual current attack, but the repository cannot derive the next legal enclosing state from authoritative data. It instead depends on `AttackState.attacked_squads`, `fired_zones`, and `current_attack`.

Consequently:

- anti-squadron target iteration is a downstream casualty;
- used-zone and remaining-attack calculations are downstream casualties;
- executor teardown/projection is a concrete trigger that can erase the only surviving continuation context;
- geometry, firing-arc calculation, timing-window behavior, and initial target legality are not supported as root causes.

CON-006 itself ends at accepted Begin or declaration Skip and explicitly excludes post-Begin completion and additional-target iteration. [Scope boundary](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-006-attack-declaration-lifecycle-contract.md:228). Its Begin coordination obligations nevertheless identify why the later completion boundary lacks authoritative enclosing progress.

## 7. Root cause and confidence

Root cause: an incomplete semantic cutover across the individual-attack completion/enclosing-attack progression boundary.

The new canonical individual attack is completed replayably, but the durable facts required to continue the enclosing ship Attack step remain solely in legacy scene-local state. Completion therefore leaves canonical state unable to determine whether the next state is:

- another squadron target in the same anti-squadron attack;
- a second normal attack declaration from another hull zone; or
- the Maneuver step.

This violates the accepted ownership and derivation boundaries in CON-001, particularly:

- semantic mutation through commands: [CON-001-CMD-001/002](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md:303);
- scenes may not own durable progression or completion: [responsibility table](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md:549);
- post-command routing must derive from resulting authoritative state: [CON-001-BOUND-009](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md:595).

Confidence is high for the repository root cause. Confidence is lower that the retained annotations specifically traversed the network teardown branch because they do not record play mode or command history. That limitation does not affect the demonstrated authoritative progression gap.

## 8. Whether both symptoms share one root cause

Yes.

They use different local fields but cross the same broken boundary:

- additional squadron continuation depends on `defender_squadron` and `attacked_squads`;
- the second normal attack depends on `fired_zones` and `current_attack`;
- all are evaluated after the individual canonical attack has already been retired;
- all are cleared together by executor reset/primary-presentation deactivation.

There is no evidence of two independent target-legality failures.

## 9. Relationship to the declaration stabilization

BUG-002 is a behavioral regression introduced by the `7bc978a` CON-006 semantic cutover, acting on a pre-existing ownership gap.

Before `7bc978a`, the implementation moved directly from damage finalization into the scene-local Step 6/second-attack branches. The same scene-local ownership was architecturally incomplete, but the uninterrupted local execution path preserved the behavior.

`7bc978a` introduced:

- canonical `CurrentAttackState`;
- automatic post-damage `CompleteAttackCommand`;
- completion-result routing and canonical-active-attack-based presentation teardown;

while retaining the old local `attacked_squads`, `fired_zones`, and `current_attack` as the sole source for enclosing continuation.

Therefore the stabilization did not merely reveal an unrelated defect. It changed the completion lifecycle in a way that made the existing local-only progression state losable. Reverting CON-006 Preview/Confirm behavior is neither required nor indicated.

## 10. Smallest coherent repair boundary

The smallest coherent repair is one progression-ownership cutover spanning accepted Begin and the post-Complete handoff:

- Keep `CompleteAttackCommand` retiring one resolved individual attack.
- Keep CON-006 Preview, replacement, explicit Confirm, command validation, and canonical attack creation unchanged.
- At accepted Begin, ensure the existing accepted enclosing owners record the committed normal attack opportunity, attacking hull zone, and applicable target history exactly once.
- After individual completion, derive whether Step 6 continues, whether a different-zone second attack remains, or whether the Attack step ends from those authoritative owners.
- Do not let presentation teardown, an inactive `CurrentAttackState`, or scene-local cache loss decide that progression.
- A Step 6 repetition must not consume a second normal ship attack; the second normal attack must exclude the first attacking hull zone but may select the same surviving target where otherwise legal.

CON-006 already identifies the owners: activation-local `ShipInstance` state together with the canonical enclosing ship activation. No new architectural owner is required.

Likely affected production boundaries are:

- [begin_attack_command.gd](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd)
- [current_attack_continuation.gd](/Users/Katharina/godot/Armada/src/core/state/current_attack_continuation.gd)
- [attack_executor.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd)
- [attack_panel_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_panel_controller.gd)
- [ship_instance.gd](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd)
- [ship_activation_state.gd](/Users/Katharina/godot/Armada/src/core/state/ship_activation_state.gd)
- potentially the existing Skip path where the player declines further Step 6 targets or the remaining normal attack.

## 11. Required automated and manual verification

Existing tests cover individual attack completion and transient Preview replacement, but not the production boundary under review. In particular, [the A→B→C test](/Users/Katharina/godot/Armada/tests/integration/test_squadron_attack_target_recovery.gd:345) stops after the first accepted Begin, while [AttackState tests](/Users/Katharina/godot/Armada/tests/unit/test_attack_state.gd:275) only verify local reset behavior.

Required automated regressions:

1. One hull zone resolves two or more eligible squadron targets sequentially.
2. Step 6 target history rejects the same squadron twice within that attack.
3. Declining/exhausting Step 6 retains a second normal attack where available.
4. The second attack accepts a legal ship target from another hull zone.
5. The second attack accepts another legal anti-squadron attack.
6. A surviving squadron may be targeted in both different-hull-zone attacks.
7. The same attacking hull zone cannot be reused.
8. A ship cannot exceed two normal attacks.
9. Existing friendly, arc, range, LOS, and no-dice restrictions remain enforced.
10. Canonical state and command order produce the same continuation in hot-seat, host, client mirror, replay, save/load, and reconnect.
11. Executor/panel teardown cannot consume a legal continuation.
12. Existing CON-006 Preview A→B, deselection, explicit Confirm, rejected Begin, and declaration Skip remain unchanged.

Owner manual scenarios should repeat the Nebulon-B and Victory II cases in hot-seat and network play, covering multiple same-zone squadron targets, optional Step 6 decline, second-zone ship target, second-zone squadron targets, same surviving squadron from both zones, illegal same-zone reuse, and transition to Maneuver only after remaining attacks are declined or exhausted.

No tests were run because this was a read-only forensic audit.

## 12. Recommendation

**Ready for repair planning.**

The accepted architecture already resolves ownership. No new Owner decision is required, but the repair crosses canonical progression, replay, network projection, and live executor lifecycle boundaries, so it should be bounded and reviewed before implementation.

No files were modified; `git diff --stat` and `git status --short` were empty.
