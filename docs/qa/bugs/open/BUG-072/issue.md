# BUG-072 — Network ship activation stalls after completed attack

## Summary

During manual Network gameplay verification following implementation of the accepted Network attack-flow lifecycle and remote damage-presentation repair, the Victory II-class Star Destroyer's activation stalled after completing an attack.

The attack itself appeared to finish, but normal ship-activation gameplay did not continue.

This is an acceptance-blocking regression until diagnosed and resolved.

## Observed Behavior

During a Network game:

1. the Victory II-class Star Destroyer was activated;
2. it performed and completed an attack;
3. the attack presentation ended;
4. the Victory II remained the active ship;
5. the expected continuation of its activation was not presented;
6. gameplay therefore stalled.

The captured annotation states:

> BUG: the attack flow of the VS stalled during replay.

## Expected Behavior

After an attack has completely resolved, including any required inspections and acknowledgements, the active ship must continue to its next legal activation decision.

A retired attack must not leave an otherwise valid ship activation without an exposed next legal decision.

Continuation must use the existing canonical ship-activation and attack-continuation architecture. A retired attack must not be reopened merely to recover presentation.

## Preserved Evidence

The BUG-072 folder contains the complete evidence package from the failing run:

- annotation captured at the stalled state;
- host log;
- client log;
- full replay from the affected Network game.

Treat these artifacts together as the primary diagnostic evidence.

The replay is evidence from the actual failing gameplay session. Do not regenerate, modify, transform, patch, reorder, re-sign, or otherwise manufacture it during diagnosis.

## Annotation State

At the captured stalled state:

### Attack state

The canonical current attack is inactive:

- `current_attack_state.active == false`;
- `current_attack_state.attack_id == ""`;
- `current_attack_state.stage == "inactive"`.

There is therefore no obvious active canonical attack at the captured point.

### Ship activation

The Victory II remains in a live ship activation:

- `ship_activation_identity == "ship-activation:121"`;
- `committed_attack_count == 1`;
- `maneuver_opportunity_disposition == "OPEN"`;
- `squadron_command_opportunity_disposition == "CONSUMED"`;
- hull zone `0` is recorded as used for an attack.

### Interaction flow

The canonical interaction flow remains active and references the same ship activation:

- `controller_player == 1`;
- `ship_activation_identity == "ship-activation:121"`;
- `ship_index == 0`;
- `step_id == 7`.

The interaction flow is not an active ATTACK flow.

### Match context

- phase: Ship Phase;
- round: 2;
- Victory II owner: player 1.

These observations suggest that the attack itself retired while the surrounding ship activation remained live.

They do **not** establish whether the defect is in authoritative continuation, Network distribution, projection, reconstruction, or UI presentation.

## Regression Context

BUG-072 was discovered while manually validating the implementation of the Owner-accepted:

`docs/architecture/implementation_workbooks/network-attack-flow-lifecycle-and-remote-damage-presentation-repair-implementation-workbook.md`

That implementation changes or touches:

- source-scoped attack-flow publication;
- stale publication rejection;
- terminal attack-flow clearing;
- post-command follow-up ordering;
- Counter parent/child continuation;
- Network result distribution;
- inter-attack ATTACK-flow suppression;
- router-based presentation reconstruction;
- remote attack-result presentation.

Therefore BUG-072 must initially be treated as a possible regression of the current implementation until repository and runtime evidence classify it otherwise.

Do not assume causation merely because the defect was discovered during this work.

## Diagnostic Questions

Diagnosis must establish:

1. the exact authoritative command sequence leading to the stalled state;
2. the last successfully completed attack command/lifecycle transition;
3. whether canonical state at the annotation point is legal and internally consistent;
4. the semantic meaning of the captured interaction flow and `step_id == 7`;
5. whether that interaction flow is the correct next decision for `ship-activation:121`;
6. whether `controller_player == 1` is correct


The attachment establishes the root cause. BUG-072 is not a maneuver-modal wiring failure: the controlling client rejects authoritative command 139, so it never reaches the maneuver projection at command 142.

1. Chronological failing sequence

   - `137 resolve_damage` completes attack damage.
   - The live controlling client’s presentation callback patches `final_damage`.
   - `138 complete_attack` retires `attack:124` and installs its completed-result inspection.
   - `139 publish_attack_flow(final)` succeeds on authority and reaches the client.
   - Client rejects 139 with “Completed attack result acknowledgement is outstanding,” then reports “Failed to apply authoritative network command seq=139” ([attached output](/Users/Katharina/.codex/attachments/3cbf77fc-1148-491b-afc4-c7ff841e83fd/pasted-text.txt:50)).
   - Authority subsequently executes acknowledgements 140–141 and maneuver transition 142.
   - The stalled client cannot apply anything after 139 because the ordered-result queue stops at the failed sequence ([game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:2900)).

2. Relevant replay range

   Commands 137–142, with the complete attack lifecycle beginning at 124. The critical boundary is:

   `137 resolve_damage → 138 complete_attack → 139 terminal publication → 140/141 acknowledgements → 142 maneuver_step`

   The preserved replay records this range at [replay_20261011_085935.json](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-072/replay_20261011_085935.json:2071).

3. Host-side sequence

   The authority completes all commands through 142. Command 139 must have succeeded and been distributed because the live client received it. The captured `open_mirror` after 142 is the passive host presentation, which is correct because the Victory II belongs to player 1.

4. Client-side sequence

   The controlling client applies through 138, receives 139, but rejects it during strict mirror validation. Receipt/application of 140–142 on that client is not recorded; if received, they remain blocked behind 139. Reopening “Show Activation Sequence” therefore exposes only stale/passive presentation and cannot progress gameplay.

5. Annotation interpretation

   `flow_type == 2` is `SHIP_ACTIVATION`; `step_id == 7` is `MANEUVER_STEP` ([constants.gd](/Users/Katharina/godot/Armada/src/autoload/constants.gd:147)). It is the correct next live decision for `ship-activation:121`.

   `controller_player == 1` is correct: player 1 owns the Victory II. `maneuver_opportunity_disposition == "OPEN"` is also correct. The annotation has no active attack or outstanding inspection and describes a completed post-attack transition ([annotation](/Users/Katharina/godot/Armada/docs/qa/bugs/open/BUG-072/annotation_20261011_085918_001.json:535)).

6. Canonical-state classification

   Annotation/authority: **VALID AND COMPLETE**.

   Overall Network session: the client is **INVALID/DIVERGED** relative to authority because it stops at 139.

7. Host/client convergence

   **Not converged.** Authority reaches cursor 143 and maneuver state; the live client remains blocked at cursor 139.

8. Exact failing seam

   The seam is:

   `AttackExecutor.apply_damage_result`
   → `_fsm_patch_payload(final_damage)`
   → local `AttackFlowFSM` projection rewrite
   → `GameManager.build_publish_attack_flow_command`
   → client validation of authoritative terminal publication.

   It precedes `UIProjector`, `ModalRouter`, and ship-activation routing.

9. Root cause

   The transient FSM begins with an empty payload and never retains `attack_id`. Its later `final_damage` patch rewrites the client’s installed ATTACK flow from that source-less payload ([attack_executor.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:3221)).

   The central producer adds `attack_id` only to a duplicated command payload, not to the actual installed `InteractionFlow` ([game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:2053)). Consequently, when authoritative final command 139 arrives, strict validation finds that the client’s installed projection lacks matching source `attack:124` ([publish_attack_flow_command.gd](/Users/Katharina/godot/Armada/src/core/commands/publish_attack_flow_command.gd:128)).

   Preflight masks that underlying source mismatch with the generic outstanding-acknowledgement message.

10. Causal classification

   **CAUSED.** The current implementation introduced the source-scoped terminal command while incompletely implementing the accepted requirement that the producer place the source identity in the installed ATTACK projection—not merely its outgoing command copy.

11. Smallest architecture-consistent repair

   Correct the existing central publication producer so that, after rejecting any pre-existing mismatch, it places the canonical active attack ID into the actual published/installed `InteractionFlow.payload` before taking the command snapshot.

   Do not change terminal validation, stale-command rejection, result ordering, ModalRouter, ActivationModal, or continuation ownership.

12. Required regression tests

   - Producer stamps both the installed flow and serialized command with the same source.
   - Existing mismatched source still fails without mutation.
   - Live controlling-client sequence 137–142, including the `final_damage` callback, accepts 139 and advances through 142.
   - Client player 1 receives an interactive maneuver modal; host player 0 receives only the passive mirror.
   - Delayed non-final publication still rejects after retirement.
   - Ordered result cursor reaches 143 on both peers.
   - Both real-ENet role mappings converge.
   - Existing save/load/reconnect and replay-12 coverage remains passing.

13. Accepted-workbook amendment required

   **NO.** The workbook already requires the producer to place the source identity in the installed projection ([workbook](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/network-attack-flow-lifecycle-and-remote-damage-presentation-repair-implementation-workbook.md:129)). This is an implementation conformance correction.

14. New Owner architecture decision required

   **NO.** The existing producer, validators, continuation owner, and ordered Network result path are sufficient.

15. Compatibility/version consequences

   None change: Save 10, Network 11, replay 12. No adapter or migration is indicated.

16. Severity

   **Acceptance-blocking / high.** It deterministically stalls the controlling client after a successful attack.

17. Acceptance impact

   **BUG-072 blocks acceptance of the current implementation.**

The later 09:01 replay run succeeds through 142 because replay mode does not emit the live `command_executed` callbacks that trigger this local projection rewrite ([command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd:458)). That explains why the replay preserves the authoritative sequence but does not itself reproduce the live client stall.

No files were changed, no fixtures or baselines were modified, and implementation/convergence work remains stopped as requested.
