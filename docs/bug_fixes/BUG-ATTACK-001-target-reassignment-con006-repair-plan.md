# BUG-ATTACK-001 Repair Plan

Status: Accepted
Related Bug: BUG-ATTACK-001
Authority:
- CON-006
- MA-ATTACK-001
- Contract-Driven Defect Analysis

Purpose

This document defines the implementation repair required to stabilize the
current attack declaration implementation. It is an engineering planning
artifact, not an architectural authority.

After successful implementation, verification, and commit, this document
may be archived or deleted.

# Implementation Execution Plan

No repository files were modified. This plan targets the current dirty worktree assessed by MA-ATTACK-001, not repository HEAD.

## Startup documents read

- [AGENTS.md](/Users/Katharina/godot/Armada/AGENTS.md)
- [ARCHITECTURE.md](/Users/Katharina/godot/Armada/ARCHITECTURE.md)
- [AI_DEVELOPMENT_PRINCIPLES.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PRINCIPLES.md)
- [AI_DEVELOPMENT_PROCESS.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PROCESS.md)
- [AI_STARTUP_GUARDRAILS.md](/Users/Katharina/godot/Armada/.ai/instructions/AI_STARTUP_GUARDRAILS.md)
- [DOCUMENT_AUTHORITY.md](/Users/Katharina/godot/Armada/docs/architecture/DOCUMENT_AUTHORITY.md)
- [ARCHITECTURE_ROADMAP.md](/Users/Katharina/godot/Armada/docs/architecture/ARCHITECTURE_ROADMAP.md)
- [CODEX_WORKFLOW.md](/Users/Katharina/godot/Armada/docs/architecture/CODEX_WORKFLOW.md)

## Authority documents read

- [ADR-001](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md)
- [ADR-003](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md)
- [ADR-004](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md)
- [ADR-005](/Users/Katharina/godot/Armada/docs/architecture/adr/ADR-005-timing-window-ownership-and-continuation.md)
- [CON-001](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-001-current-attack-state-and-semantic-transition-contract.md)
- [CON-003](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-003-rule-capability-contract.md)
- [CON-004](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-004-upgrade-runtime-contract.md)
- [CON-005](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-005-timing-window-implementation-contract.md)
- [CON-006](/Users/Katharina/godot/Armada/docs/architecture/contracts/CON-006-attack-declaration-lifecycle-contract.md)
- [DR-001](/Users/Katharina/godot/Armada/docs/architecture/decision_workbooks/DR-001-CON-006-owner-decisions.md)
- [TEST-003](/Users/Katharina/godot/Armada/docs/architecture/tests/TEST-003-interactive-rule-timing-window-verification.md)
- [MA-ATTACK-001](/Users/Katharina/godot/Armada/docs/architecture/migration_assessments/MA-ATTACK-001-con-006-compliance.md)
- The completed contract-driven defect analysis in this task conversation.

The superseded CAP-ATTACK-001 draft was checked only to confirm its non-authoritative status and was not used as implementation authority.

## Repository evidence used

The plan is grounded in:

- Immediate `target_locked` emission after preview in [target_selector.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd:1179).
- Automatic Begin and active `Skip(flow_replaced) → Begin` choreography in [attack_executor.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd:795).
- Shared mutable declaration state in [attack_state.gd](/Users/Katharina/godot/Armada/src/core/combat/attack_state.gd:1).
- The later, dice-stage Confirm already present in [attack_sim_panel.gd](/Users/Katharina/godot/Armada/src/ui/combat/attack_sim_panel.gd:55).
- Authoritative Begin revalidation and `CurrentAttackState` construction in [begin_attack_command.gd](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd:14).
- Legacy `flow_replaced` support in [skip_attack_command.gd](/Users/Katharina/godot/Armada/src/core/commands/skip_attack_command.gd:18).
- Client pending-command gating in [network_command_submitter.gd](/Users/Katharina/godot/Armada/src/core/commands/network_command_submitter.gd:41).
- Server-side rejection without a response to the client in [network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd:587).
- Legacy sequence assertions in [test_squadron_attack_target_recovery.gd](/Users/Katharina/godot/Armada/tests/integration/test_squadron_attack_target_recovery.gd:280) and [test_current_attack_shared_protocol.gd](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd:345).
- MA-ATTACK-001’s accepted distinction between the target-reassignment defect and broader CON-006 migration gaps.

# Execution plan

The objectives below are traceability items, not implementation order.

## 1. Scope

This stabilization includes:

- Ship and squadron gameplay declaration entry.
- One transient declaration candidate.
- First preview, preview replacement, deselection, and illegal-selection preservation.
- A distinct declaration Confirm interaction.
- Exactly one Begin submission from Confirm.
- Pending and rejected Begin behavior, including network-client rejection recovery.
- Removing pre-confirm replacement through active `Skip(flow_replaced)`.
- Replay and network verification that Preview A → Preview B yields one eventual Begin for B and no replacement Skip.
- Presentation cleanup only after an authoritative accepted result.
- Regression verification of declaration Skip with and without a preview.
- Updating obsolete implementation comments and tests associated with the removed replacement choreography.

It does not include:

- Full migration of enclosing ship or squadron activation progress.
- The separate MA finding that no-active Skip does not yet commit all required enclosing authoritative progress.
- Ship-preview/Begin parity migration through `TargetingListBuilder`.
- Active attack replacement, cancellation, completion, or cleanup.
- Second-attack, anti-squadron loop, fired-zone, or already-targeted ownership migration.
- Post-Begin dice, accuracy, defense, damage, Counter, rule, upgrade, or timing-window behavior.
- General save/load or reconnect infrastructure cleanup.
- Production integration of the currently direct-boundary reconnect filter test.
- Any broader CON-006 compliance claim.

Declaration Skip is included as a stabilization regression path: it must remain available, one-shot, and unrelated to preview replacement. Its broader authoritative-effect gap remains outside this defect correction.

## 2. Implementation objectives

| Objective | Why required | Applicable obligations | Repository behavior replaced |
|---|---|---|---|
| Establish one transient candidate owner | Target A currently remains visible through shared state while replacement B is separately pending. | CON-006-AUTH-002/004; LIFE-002/004/012; PREV-001–004; REPLACE-001–004 | Shared target state plus `AttackExecutor` replacement cache |
| Make target selection preview-only | Selection currently crosses the semantic boundary immediately. | LIFE-001–003; PREV-001–004; REPLACE-002/003 | `target_locked` immediately causing Begin |
| Add explicit declaration Confirm | The visible existing Confirm belongs to the later dice stage. | CONFIRM-001–006; LIFE-005/007/008 | Automatic Begin on legal target selection |
| Preserve authoritative Begin ownership | Confirm must submit the existing authoritative command, not create scene authority. | BEGIN-001/004/011; CON-001-STATE-001/007; CON-001-LIFE-001–005 | Scene sequencing selecting when authority is created |
| Remove replacement Skip choreography | Preview replacement must not be represented as active cancellation and fresh attack creation. | LIFE-012; REPLACE-002/003; REPLAY-001/002; NET-003 | `Begin → Skip(flow_replaced) → Begin` |
| Retain candidate during pending/rejection | The player must not lose B or submit duplicates while Begin is unresolved. | LIFE-005/007/008; CONFIRM-005/006; BEGIN-011; FLOW-008/009 | Path-specific rejection recovery and early panel teardown |
| Return network rejection to the submitter | A rejected client Begin currently leaves the network submitter awaiting indefinitely. | BEGIN-011; FLOW-009; NET-004/008 | Server silently dropping rejected commands |
| Keep preview outside durability and distribution | Preview churn must not become history, canonical state, or a semantic network message. | SER-002–004; REPLAY-001–006; NET-001–005; RECONNECT-001/002 | Replay-visible replacement and any temptation to mirror preview |
| Preserve declaration Skip as an independent terminal choice | Removing replacement Skip must not remove the user’s explicit declaration Skip. | LIFE-006–008; SKIP-002/003/007; REPLACE-002 | Skip overloaded as both user choice and replacement machinery |

## 3. File impact analysis

### Expected production changes

| File | Purpose | Size |
|---|---|---:|
| [target_selector.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/target_selector.gd) | Own the current transient candidate and replace all preview-derived output coherently; stop emitting automatic attack entry; remove active-replacement requests. | Large |
| [attack_executor.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd) | Coordinate explicit declaration Confirm/Skip, one-command pending state, accepted/rejected result handling, and removal of replacement caches and Skip→Begin sequencing. | Large |
| [attack_state.gd](/Users/Katharina/godot/Armada/src/core/combat/attack_state.gd) | Clarify and constrain its declaration-time role so it is not documented or used as a competing mutable candidate owner; preserve its post-Begin scene projection responsibilities. | Small |
| [attack_flow_fsm.gd](/Users/Katharina/godot/Armada/src/core/combat/attack_flow_fsm.gd) | Correct declaration comments and assumptions that currently equate declaration entry with a locked target. No post-Begin transition redesign. | Small |
| [attack_sim_panel.gd](/Users/Katharina/godot/Armada/src/ui/combat/attack_sim_panel.gd) | Present a declaration Confirm distinct from later dice confirmation; expose pending, rejection, preview replacement, deselection, and Skip states. | Medium |
| [attack_panel_controller.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_panel_controller.gd) | Route accepted/rejected declaration outcomes without treating a pending or inactive declaration as loss of presentation ownership. | Medium |
| [game_board.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/game_board.gd) | Wire authoritative rejection/result notification into the existing attack presentation composition. | Small |
| [skip_attack_command.gd](/Users/Katharina/godot/Armada/src/core/commands/skip_attack_command.gd) | Remove the obsolete `flow_replaced` replacement reason after all callers are removed, while leaving ordinary active cancellation and no-active declaration Skip semantics otherwise unchanged. | Small |
| [network_command_submitter.gd](/Users/Katharina/godot/Armada/src/core/commands/network_command_submitter.gd) | Release the one-command awaiting gate on authoritative rejection as well as acceptance. | Medium |
| [network_manager.gd](/Users/Katharina/godot/Armada/src/autoload/network_manager.gd) | Return a rejected submission outcome to the submitting client without recording or broadcasting it as an accepted semantic command. | Medium |
| [game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd) | Deliver accepted/rejected network outcomes to the declaration coordinator while preserving accepted-command ordering. | Medium |

### Expected test changes

- [test_squadron_attack_target_recovery.gd](/Users/Katharina/godot/Armada/tests/integration/test_squadron_attack_target_recovery.gd) — large replacement of legacy active-replacement expectations.
- [test_current_attack_shared_protocol.gd](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_shared_protocol.gd) — replace Begin→Skip→Begin equivalence with preview-local and one-Begin equivalence.
- [test_current_attack_production_resume.gd](/Users/Katharina/godot/Armada/tests/integration/test_current_attack_production_resume.gd) — declaration presentation, pending, acceptance, and rejection lifecycle.
- [test_attack_sim_panel.gd](/Users/Katharina/godot/Armada/tests/unit/test_attack_sim_panel.gd) — distinct declaration and dice confirmation states.
- [test_attack_state.gd](/Users/Katharina/godot/Armada/tests/unit/test_attack_state.gd) — transient reset and stale-target removal.
- [test_attack_commands.gd](/Users/Katharina/godot/Armada/tests/unit/test_attack_commands.gd) — retirement of `flow_replaced` while preserving supported Skip behavior.
- [test_command_submitter.gd](/Users/Katharina/godot/Armada/tests/unit/test_command_submitter.gd) — rejection clears awaiting and queued work proceeds.
- [test_network_manager.gd](/Users/Katharina/godot/Armada/tests/unit/test_network_manager.gd) — rejected submission response semantics.
- [test_network_command_result_ordering.gd](/Users/Katharina/godot/Armada/tests/unit/test_network_command_result_ordering.gd) — rejection does not enter accepted command order or block the next valid command.
- [test_modal_router.gd](/Users/Katharina/godot/Armada/tests/unit/test_modal_router.gd) — declaration presentation is retained while pending and after rejection.
- [test_attack_panel_mirror.gd](/Users/Katharina/godot/Armada/tests/unit/test_attack_panel_mirror.gd) — passive peers receive no preview authority and still project accepted Begin.
- [test_reconnection_mid_attack.gd](/Users/Katharina/godot/Armada/tests/integration/test_reconnection_mid_attack.gd) — reconnect before Begin restores no candidate or attack.
- [test_save_load_round_trip.gd](/Users/Katharina/godot/Armada/tests/unit/test_save_load_round_trip.gd) — local preview does not alter serialized authoritative state.

No new test file is required; the existing focused integration suites are the natural home for the new evidence.

### Considered but expected to remain unchanged

- [begin_attack_command.gd](/Users/Katharina/godot/Armada/src/core/commands/begin_attack_command.gd): continues to revalidate authoritative target facts and create canonical attack state.
- [current_attack_state.gd](/Users/Katharina/godot/Armada/src/core/state/current_attack_state.gd): remains the accepted post-Begin state representation.
- [targeting_list_builder.gd](/Users/Katharina/godot/Armada/src/core/combat/targeting_list_builder.gd) and [attack_target_resolver.gd](/Users/Katharina/godot/Armada/src/core/combat/attack_target_resolver.gd): broader Preview/Begin parity work is outside this stabilization.
- [command_applicability.gd](/Users/Katharina/godot/Armada/src/core/commands/command_applicability.gd), [flow_spec.gd](/Users/Katharina/godot/Armada/src/core/state/flow_spec.gd), and [game_state.gd](/Users/Katharina/godot/Armada/src/core/state/game_state.gd): their accepted MA gaps require the broader declaration/enclosing-progress migration.
- [save_game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd): save-point policy remains unchanged.
- [ui_projector.gd](/Users/Katharina/godot/Armada/src/core/network/ui_projector.gd), [state_filter.gd](/Users/Katharina/godot/Armada/src/core/network/state_filter.gd), and [modal_router.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/modal_router.gd): existing projection remains authoritative-result-driven.
- Ship/squadron activation state, controllers, and modal-local progress: broader enclosing-progress migration remains out of scope.
- Roll, dice confirmation, defense, damage, completion, active cancellation, Counter, upgrade, rule, and timing-window implementation.
- Architecture, Contract, ADR, TEST, CAP, Migration Assessment, and implementation-workbook documents.

## 4. Behavioral changes

- Selecting legal target A produces Preview A only. No Begin, Skip, canonical attack, history entry, timing state, or semantic network message occurs.
- Selecting legal target B while A is previewed atomically replaces the entire local preview with B. A can no longer drive Confirm or presentation.
- Re-selecting the current target clears only the target preview and disables declaration Confirm.
- An illegal selection preserves an existing legal preview.
- Declaration Confirm is visibly and semantically distinct from later dice confirmation.
- One declaration Confirm submits one Begin built from stable candidate identity. Repeated input while pending produces no additional submission.
- Accepted Begin clears the transient candidate only after the authoritative result is processed and continues through the existing post-Begin attack pipeline.
- Rejected Begin leaves canonical attack state inactive, preserves or re-derives the candidate, restores interaction, and submits no fallback Skip.
- A client-side rejected Begin receives an authoritative rejection outcome and leaves the network gate usable.
- Declaration Skip remains available with or without a preview and submits at most one Skip. It is never used for target replacement.
- Preview remains controller-local. Passive peers project only accepted authoritative state.
- No active completion, active cancellation, second-attack, or post-Begin behavior changes.

## 5. Legacy behavior removal

The stabilization removes:

- Automatic Begin from `TargetSelector.target_locked`.
- The `target_locked` declaration meaning and associated comments.
- `active_target_replacement_requested`.
- `AttackExecutor`’s pending replacement candidate, replacement attack ID, Skip-submission flags, Begin-expectation flags, and related recovery branches.
- `TargetSelector` replacement commit/recovery entry points.
- `SkipAttackCommand` reason `flow_replaced`.
- Replay-visible `Begin → Skip(flow_replaced) → Begin`.
- Tests that treat active cancellation and fresh Begin as target reassignment.
- Comments describing legal target selection as target lock or immediate dice-sequence entry.
- Comments that describe the shared scene `AttackState` as the declaration candidate’s competing owner.

No compatibility bridge or dual replacement path remains after cutover.

## 6. Test impact

### Tests requiring updates

The files listed in the file impact section must be updated to reflect preview-only selection, explicit Confirm, pending/rejection behavior, and one accepted Begin.

### Tests expected to remain unchanged

- `CurrentAttackState` serialization and invariant tests.
- Existing authoritative target legality and rule tests.
- Roll, dice modification, accuracy, defense, damage, Counter, completion, and active-cancellation tests.
- Timing-window and TEST-003 participating-rule tests.
- Save-manager safe-point tests.
- Replay format and baseline trace format tests.
- Existing accepted-Begin reconstruction tests that begin from active canonical attack state.

### New automated verification required

- Preview A → B → C leaves canonical serialization, flow, timing state, and command history unchanged.
- Replacement across supported attacker/defender kinds clears every A-derived target fact.
- Old A cannot be submitted after B replaces it.
- Same-target deselection removes Confirm availability.
- Illegal selection preserves the current legal preview.
- Confirm submits exactly one Begin for the final candidate.
- Rapid or repeated Confirm, Skip, and replacement attempts while pending submit nothing further.
- Local Begin rejection preserves candidate and interaction.
- Network Begin rejection returns to the submitter, clears awaiting, and permits a later valid command.
- Preview churn produces no network semantic messages.
- Replay contains one Begin for the final target and no replacement Skip.
- Save/reconnect before Begin contains no preview or active attack.
- Accepted Begin continues through the existing post-Begin pipeline without a second Begin.
- Ordinary declaration preview and replacement create no timing-window state.

## 7. Manual verification plan

- Ship declaration:
  - Enter attack declaration.
  - Select attacker hull zone and target.
  - Confirm no attack begins until declaration Confirm.

- Squadron declaration:
  - Enter from Squadron Phase and squadron-command context where available.
  - Select a target.
  - Confirm the same preview/Confirm behavior.

- Preview A → Preview B:
  - Select A, then legal B.
  - Verify identity, hull zone, LOS, obstruction, range, and dice preview all show B.
  - Verify no visible fact from A remains.
  - Verify no attack command has occurred.

- Confirm:
  - Confirm B once.
  - Verify one authoritative Begin and continuation into the existing attack sequence.
  - Try repeated Confirm while pending and verify no duplicate.

- Rejected Begin:
  - Make the candidate stale or otherwise rejectable.
  - Verify no active attack, no Skip/fallback, B remains or is deterministically refreshed, and interaction is restored.

- Declaration Skip:
  - Skip once with no preview and once with a preview.
  - Verify no Begin and no `flow_replaced` behavior.
  - Verify the accepted Skip uses the existing declaration exit path.

- Networking:
  - Perform A → B on the controller peer and verify no semantic command reaches the host.
  - Confirm B and verify exactly one Begin is accepted and mirrored.
  - Reject one client Begin and verify the client is no longer stuck awaiting.
  - Verify the passive peer sees only authoritative post-Begin state.

No tests are executed as part of this planning task.

## 8. Risks

| Risk | Level | Detection | Mitigation |
|---|---:|---|---|
| Removing shared target writes leaves stale A in a secondary field or widget | High | A→B→C tests compare all target-derived output and Confirm identity | Treat candidate replacement and presentation refresh as one semantic update; clear all legacy replacement caches |
| Declaration Confirm is confused with later dice Confirm | High | Panel signal tests plus a complete declaration→roll→dice-confirm attack | Keep their lifecycle, wording, enablement, and submission effects distinct |
| Post-Begin attack progression regresses when automatic Begin is removed | High | Full attack smoke tests through accepted Begin, roll, and completion | Preserve existing post-Begin command and scene behavior; cut only the pre-Begin boundary |
| Rejected network commands affect accepted command sequencing | High | Host/client rejection followed by a valid command; history/cursor assertions | Rejection releases pending state without becoming accepted history or a mirrored semantic mutation |
| Ship and squadron declaration paths diverge | Medium | Run identical preview, replacement, Confirm, rejection, and Skip assertions for both | Use the existing shared selector/executor declaration protocol |
| Removal of `flow_replaced` breaks unrelated active cancellation | Medium | Active cancellation and timing-window cleanup regression suites | Remove only the obsolete replacement reason; retain accepted active cancellation reasons and behavior |
| Projection closes the primary panel during pending or rejection | Medium | Modal/controller tests and network manual verification | Route cleanup only after an accepted authoritative result |
| Replay still encodes legacy replacement | Medium | Exact history comparison across local, host, client mirror, and replay | Remove every producer and replace legacy sequence assertions |
| Dirty worktree causes overlap with existing attack changes | Medium | Review scoped diff and status before and after implementation | Preserve existing changes and restrict edits to the accepted file set |
| Preview state leaks into serialization or reconnect | Low | State hash/serialization comparisons before and after preview | Keep candidate, rejection feedback, and pending state entirely transient |
| Obsolete comments continue to describe immediate target lock | Low | Targeted repository search after implementation | Update only implementation comments made false by this cutover |

## 9. Out-of-scope items

No work shall be performed on:

- Full TWI-ATTACK-001 or any implementation workbook.
- Accepted architecture documents.
- Complete CON-006 migration.
- Authoritative enclosing ship/squadron progress.
- No-active Skip’s broader context-specific authoritative effects.
- Ship Preview/Begin resolver parity.
- Hull-zone-use, action-history, already-targeted, or attack-count ownership.
- Active attack completion, cancellation, or replacement.
- Attack resolution after accepted Begin.
- Timing-window, rule, upgrade, or CAP implementation.
- Unrelated UI, networking, replay, save/load, or reconnect cleanup.
- The open network save/load session-bootstrap defect.
- Unrelated tests or baseline changes.

## 10. Completion criteria

Implementation is complete and ready for Owner manual testing when:

- Legal target selection never creates `CurrentAttackState` or submits Begin.
- Preview A → B fully replaces A without authoritative mutation or history.
- Deselect and illegal-selection behavior preserve the required transient state.
- Declaration Confirm is distinct from dice confirmation.
- One Confirm produces at most one Begin for the final candidate.
- Pending interaction blocks duplicate Confirm, Skip, and replacement submission.
- Local and network rejection restore a usable declaration interaction without fallback mutation.
- The network awaiting gate clears after both acceptance and rejection.
- Target replacement produces no Skip and no `flow_replaced` history.
- Declaration Skip remains independently usable and is never used for replacement.
- Local, host, client mirror, and replay agree on the single accepted Begin.
- Preview and pending state remain absent from serialization and reconnect authority.
- Existing post-Begin attack, active cancellation, completion, rule, upgrade, and timing-window regression suites remain unchanged in behavior.
- The targeted automated tests and full relevant regression suite pass.
- Final diff contains only the planned stabilization files and test updates.
- No compatibility layer, second candidate owner, architecture change, or unrelated migration work has been introduced.

# Expected implementation size

**Medium-to-large, but bounded.**

Expected impact is approximately 11 production scripts and 12–13 existing test scripts. Most changes are concentrated in `TargetSelector`, `AttackExecutor`, the attack panel, and network rejection handling. No new architecture surface, runtime subsystem, canonical state class, or documentation artifact is expected.

# Recommendation


No blocking architectural ambiguity was found for this target-reassignment stabilization. The plan deliberately does not claim to resolve the broader CON-006 gaps documented by MA-ATTACK-001.
