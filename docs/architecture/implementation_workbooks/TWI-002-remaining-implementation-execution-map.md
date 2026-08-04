# TWI-002 Remaining Implementation Execution Map

Status: Execution Companion

Related implementation authority:
`TWI-002-timing-window-core-and-h9-pilot-implementation-workbook.md`

Assessed revision:
`28440bfaa70adea31bfb8f7d79b34fdc14dfb7ba`

This document records the repository-specific continuation point and concise
execution map for the unfinished TWI-002 work. It does not amend or supersede
TWI-002. Where the documents differ, TWI-002 and its referenced accepted
authorities prevail.

The repository is ready to continue TWI-002 from Slice 8B-1. Slices 2–7 and the Slice 8A pre-activation checkpoint are present; Concentrate Fire migration, H9, and the atomic production activation remain. TWI-003 is correctly blocked because save version 2, replay format 4, and the TWI-002 production activation are absent.

No repository files were modified and no tests were executed.

## Documents read

Startup documents:

- [AGENTS.md](/Users/Katharina/godot/Armada/AGENTS.md)
- [ARCHITECTURE.md](/Users/Katharina/godot/Armada/ARCHITECTURE.md)
- [AI_DEVELOPMENT_PRINCIPLES.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PRINCIPLES.md)
- [AI_DEVELOPMENT_PROCESS.md](/Users/Katharina/godot/Armada/docs/development/AI_DEVELOPMENT_PROCESS.md)
- [AI_STARTUP_GUARDRAILS.md](/Users/Katharina/godot/Armada/.ai/instructions/AI_STARTUP_GUARDRAILS.md)
- [DOCUMENT_AUTHORITY.md](/Users/Katharina/godot/Armada/docs/architecture/DOCUMENT_AUTHORITY.md)
- [ARCHITECTURE_ROADMAP.md](/Users/Katharina/godot/Armada/docs/architecture/ARCHITECTURE_ROADMAP.md)
- [CODEX_WORKFLOW.md](/Users/Katharina/godot/Armada/docs/architecture/CODEX_WORKFLOW.md)

Implementation authority and evidence:

- [TWI-002](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/TWI-002-timing-window-core-and-h9-pilot-implementation-workbook.md)
- [TWI-003](/Users/Katharina/godot/Armada/docs/architecture/implementation_workbooks/TWI-003-authoritative-current-attack-state-implementation-workbook.md)
- The completed TWI-002 implementation investigation in the current task context
- Current repository implementation at revision `28440bfaa70adea31bfb8f7d79b34fdc14dfb7ba`, with a clean worktree

# 1. Repository status

| TWI-002 area | Status | Repository evidence |
|---|---|---|
| TWI-001 prerequisite | Implemented | Timing-window state foundation is present. |
| Slices 2–7 | Implemented | Static definitions, orchestrator, participant indexing, command protocol, projection/routing, persistence/replay/network foundations, and corresponding tests are present. |
| Slice 8A | Implemented at its pre-activation checkpoint | Canonical `CurrentAttackState`, semantic attack commands, command-sequence identity, replay format 3, save version 1, and the inactive direct-confirmation context are present. |
| Slice 8B-1 | Not implemented | No shared Concentrate Fire participant or dedicated use/decline commands. The production route still uses the legacy procedural reroll/skip flow. |
| Slice 8B-2 pre-activation | Not implemented | No H9 rule implementation, H9 semantic commands, registration, guard behavior, or H9 tests. |
| Final production activation | Not implemented | No production `RollDiceCommand` timing-window opener; inactive direct ship confirmation remains legal; save version remains 1; replay format remains 3. |

The repository currently supports shared timing windows and canonical attack state, but normal ship attack progression does not enter the shared Attack Modify lifecycle. The only observed calls opening that lifecycle are test fixtures and tests.

The existing Concentrate Fire token choice is still driven by [attack_executor.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd), using the older `RerollAttackDieCommand` and `SkipAttackModifierCommand` paths. Squadron Swarm also uses those legacy command surfaces and must remain procedural and unchanged in this tranche.

Save version 2 and replay format 4 were documented but never activated. Repository history showed no evidence that they were implemented and later reverted.

TWI-003 is blocked by its explicit Entry Gate:

- TWI-002 production activation must be present and passing.
- Save version must be exactly 2.
- Replay format must be exactly 4, with the signed version remaining an alias.

None of these conditions currently holds.

# 2. Remaining implementation inventory

## Tranche A — Slice 8B-1: Concentrate Fire shared participant

**Purpose:** Move the existing ship-attacker Concentrate Fire token reroll into the shared timing-window protocol while leaving automatic production opening disabled.

**Expected behavior:**

- A legal ship Concentrate Fire token produces one optional blocking opportunity.
- Use spends one token, rerolls exactly the selected canonical die through authoritative RNG, and records `used`.
- Decline preserves dice and token state and records `declined`.
- Rejection mutates nothing.
- The opportunity cannot reappear for the same attack after either resolution.
- Ship anti-squadron attacks receive the same participant.
- Squadron attacks do not enter the shared window; Swarm remains unchanged.
- Normal gameplay continues using the existing pre-activation route until final activation.

**Production files expected to change:**

- New direct participant under `src/core/effects/rules/`
- New `UseConcentrateFireTokenRerollCommand`
- New `DeclineConcentrateFireTokenRerollCommand`
- [rule_bootstrap.gd](/Users/Katharina/godot/Armada/src/autoload/rule_bootstrap.gd)
- [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd)
- [command_applicability.gd](/Users/Katharina/godot/Armada/src/core/commands/command_applicability.gd)
- [flow_spec.gd](/Users/Katharina/godot/Armada/src/core/state/flow_spec.gd)
- [game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd), if required for handled remote-command classification
- [current_attack_state.gd](/Users/Katharina/godot/Armada/src/core/state/current_attack_state.gd) only where the existing canonical token-resolution operations require completion

The production opener, version constants, and normal AttackExecutor flow must remain unchanged.

**Tests expected to change:**

- `test_timing_window_participants.gd`
- `test_timing_window_command_protocol.gd`
- `test_timing_window_projection.gd`
- `test_timing_window_shared_protocol.gd`
- `test_current_attack_shared_protocol.gd`
- Focused attack-command atomicity/applicability tests
- Existing ship anti-squadron and Swarm regression tests

**Cross-cutting scope:**

- Commands: add the two explicit semantic commands.
- Serialization/save-load: use existing authoritative fields; no format change.
- Replay: exercise commands under format 3; no format change.
- Networking: prove host assignment and mirror equality through the existing protocol.
- Projection/UI: use the generic opportunity projection; no special CF UI ownership.
- Compatibility: preserve save version 1, replay format 3, and inactive direct confirmation.
- Commit boundary: one isolated Slice 8B-1 commit after the Concentrate Fire Readiness Gate passes.

## Tranche B — Slice 8B-2: H9 pre-activation

**Purpose:** Add H9 as the clean vertical pilot over the shared protocol, without enabling normal production opening.

**Expected behavior:**

- Each independent H9 runtime source can derive one `change_die_to_accuracy` opportunity.
- Use changes one eligible die to an available same-color Accuracy result and records that H9 source as used for the current attack.
- Decline records the source as declined without altering dice.
- Stale selected-die information rejects without mutation.
- H9 and Concentrate Fire can resolve in either player-selected order.
- Each ship attack and anti-squadron target receives a fresh attack identity and fresh H9 guard scope.
- Confirm, completion, cancellation, replacement, and termination clear the appropriate H9 guard through accepted semantic boundaries.
- No scene callback or reconstruction repair owns cleanup.
- Squadron attacks remain outside the shared opening.

**Production files expected to change:**

- New H9 rule under `src/core/effects/rules/upgrades/`
- New `UseH9Command`
- New `DeclineH9Command`
- [rule_bootstrap.gd](/Users/Katharina/godot/Armada/src/autoload/rule_bootstrap.gd)
- [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd)
- [command_applicability.gd](/Users/Katharina/godot/Armada/src/core/commands/command_applicability.gd)
- [flow_spec.gd](/Users/Katharina/godot/Armada/src/core/state/flow_spec.gd)
- Relevant existing semantic terminal commands for H9 guard cleanup
- [game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd), if required for remote-command result handling
- Existing projection/filter files only if the generic shared representation lacks an already-required field; no H9-specific modal or continuation path

**Tests expected to change:**

- New H9 derivation and use/decline command tests
- Stale-source and same-color legality tests
- Multiple-source and both-order coexistence tests
- Shared protocol, projection, applicability, and cleanup tests
- Save/load, replay-format-3, reconnect, and network tests
- Accuracy, defense, ship anti-squadron, and Swarm regression tests

**Cross-cutting scope:**

- Commands: add only `UseH9Command` and `DeclineH9Command`.
- Serialization/save-load: use existing serialized runtime-upgrade `rule_state`; no save-version change.
- Replay: record the new commands under format 3; no format change.
- Networking: host-authoritative command assignment and identical mirror dice/guard state.
- Projection/UI: generic public opportunity, attacker-only interaction, existing tooltip mechanism.
- Compatibility: preserve all pre-activation semantics.
- Commit boundary: one Slice 8B-2 pre-activation commit after the coexistence gate passes.

## Tranche C — Atomic production activation

**Purpose:** Make the shared Attack Modify lifecycle the only normal ship-attacker post-roll route.

**Expected behavior:**

- A successful ship-attacker `RollDiceCommand` opens exactly one shared lifecycle.
- Squadron rolls do not open it.
- Ship confirmation is valid only as the matching orchestrator-derived continuation.
- Inactive direct squadron confirmation remains valid.
- Legacy ship CF token handling can no longer bypass the shared participant.
- Existing Accuracy, defense, damage, Complete, and Skip semantics continue from canonical state.

**Production files expected to change:**

- [timing_window_orchestrator.gd](/Users/Katharina/godot/Armada/src/core/timing_windows/timing_window_orchestrator.gd)
- The post-success command-processing seam in [command_processor.gd](/Users/Katharina/godot/Armada/src/autoload/command_processor.gd)
- [confirm_attack_dice_command.gd](/Users/Katharina/godot/Armada/src/core/commands/confirm_attack_dice_command.gd)
- [attack_executor.gd](/Users/Katharina/godot/Armada/src/scenes/game_board/attack_executor.gd)
- CF-specific legacy branches in `RerollAttackDieCommand`, `SkipAttackModifierCommand`, and associated submission helpers, while preserving Swarm behavior
- [save_game_metadata.gd](/Users/Katharina/godot/Armada/src/core/state/save_game_metadata.gd)
- [save_game_manager.gd](/Users/Katharina/godot/Armada/src/autoload/save_game_manager.gd)
- [game_replay.gd](/Users/Katharina/godot/Armada/src/core/commands/game_replay.gd)
- [replay_driver.gd](/Users/Katharina/godot/Armada/src/autoload/replay_driver.gd)
- Reconstruction/reconnect validation seams
- Existing projection and routing files only as needed to consume the already-established generic opportunity projection

**Cross-cutting scope:**

- Save version: atomically change 1 to 2; reject version 1 before body reconstruction.
- Replay format: atomically change 3 to 4; signed format remains the alias; reject format 3 before command deserialization/application.
- Reconnect: reject stale ship `ATTACK_MODIFY` plus inactive timing state before projection or routing.
- Networking: no mixed pre-/post-activation session behavior.
- Commit boundary: one indivisible production-activation commit.

# 3. Slice 8B-1 execution map

## Prerequisites

- Confirm Slice 8A gate remains passing.
- Reconfirm the complete production post-roll/pre-confirm inventory: CF token for ship attackers and Swarm for squadron attackers.
- Stop if another legal blocker is discovered.
- Confirm canonical `cf_token_resolution`, dice, token ownership, RNG, and current-attack identity are available.

## Implementation order

1. Add and register the direct CF participant.
2. Add and register use/decline commands.
3. Complete applicability and flow agreement.
4. Connect participant derivation to canonical ship/token/current-attack facts.
5. Exercise it through the shared test opener.
6. Verify generic projection, continuation blocking, network, replay, and save/load behavior.
7. Run the Concentrate Fire Readiness Gate.
8. Confirm no normal production opener or legacy production behavior changed.

## Required automated evidence

- Exact opportunity presence and absence.
- Use, decline, repeat suppression, stale intent, and atomic rejection.
- Exactly one token spent and one selected die rerolled.
- No confirmation while the opportunity remains.
- Ship anti-squadron inclusion.
- Squadron exclusion and unchanged Swarm traces.
- Format-3 replay, save/load, reconnect, host/client identity, and projection agreement.
- Full repository gates prescribed by TWI-002.

## Completion criteria

- Every Concentrate Fire Readiness Gate item passes.
- No new production opening call exists.
- Save remains version 1 and replay remains format 3.
- The inactive direct-confirmation context remains unchanged.
- No duplicate token mutation or scene authority has been introduced.

# 4. Slice 8B-2 execution map

## Prerequisites

- Slice 8B-1 is committed and its readiness gate passes.
- The post-roll blocker inventory remains complete.
- H9’s runtime upgrade source and `rule_state` serialization are confirmed.
- The shared test opener can exercise H9 without production activation.

## Implementation order

1. Add H9 participant derivation under the existing upgrade-rule hierarchy.
2. Add and register use/decline commands.
3. Add applicability and flow agreement.
4. Add per-runtime-source, per-current-attack guard behavior.
5. Add accepted cleanup through existing semantic boundaries.
6. Verify H9 alone.
7. Verify H9 and CF in both orders.
8. Verify anti-squadron target and second-attack identity separation.
9. Verify persistence, replay, networking, reconnect, projection, Accuracy, and defense.
10. Run the Production Coexistence and H9 Pre-Activation Gate.
11. Confirm automatic production opening is still absent.

## Required automated evidence

- Source/opportunity identity and duplicate suppression.
- Use/decline legality and mutation.
- Expected source color/face stale rejection.
- Same-color Accuracy-result validation.
- Independent handling of multiple H9 sources.
- H9/CF order independence without blocker bypass.
- Cleanup on confirm, complete, cancellation, replacement, and termination.
- Save/load and reconnect before choice, after resolution, and during downstream stages.
- Format-3 replay and host/client command/state equivalence.
- No squadron shared opening; Swarm unchanged.

## Completion criteria

- Every pre-activation coexistence gate item passes.
- No H9-specific UI continuation or authoritative cache exists.
- H9 guards remain runtime-upgrade-owned and dice remain current-attack-owned.
- Save remains version 1; replay remains format 3.
- Normal production remains on the pre-activation route.

# 5. Final production activation

The following must be delivered atomically:

1. Enable the single post-success opening hook after a successful ship-attacker `RollDiceCommand`.
2. Derive the new lifecycle from canonical current-attack identity and static timing definition.
3. Keep squadron-attacker rolls outside the shared opener.
4. Remove inactive direct ship confirmation.
5. Preserve inactive direct squadron confirmation.
6. Retire the production CF procedural bypass while preserving Swarm.
7. Require the orchestrator-derived matching continuation as the sole normal shared confirmation.
8. Advance save version to 2 and reject every version-1 artifact before reconstruction.
9. Advance replay format to 4 and reject format 3 before command deserialization or application.
10. Reject stale reconnect state containing ship `ATTACK_MODIFY` with inactive timing before projection/routing.
11. Preserve accepted version-2 save/load, format-4 replay, fresh reconnect, networking, projection, Accuracy, defense, damage, Skip, and Complete behavior.

Required manual verification:

- Ship anti-ship attack with CF use and decline.
- Ship anti-ship attack with H9 use and decline.
- H9 and CF in both orders.
- Ship anti-squadron attack through the same shared choices.
- Squadron attack and Swarm unchanged.
- No confirmation while a blocker remains.
- Save/load and reconnect during an active shared window.
- Host/client projection and authoritative dice agreement.
- Version-1 save, format-3 replay, and stale reconnect rejection.
- Version-2 save and format-4 replay success.
- Downstream Accuracy, defense, damage, completion, and next-attack progression.

# 6. Dependency graph

```text
TWI-001 prerequisite
    ✓
Slices 2–7 shared core
    ✓
Slice 8A pre-activation
    ✓
Production post-roll choice inventory reconfirmed
    ↓
Slice 8B-1 — Concentrate Fire shared participant
    ↓
Concentrate Fire Readiness Gate
    ↓
Slice 8B-2 — H9 pre-activation
    ↓
Production Coexistence and H9 Pre-Activation Gate
    ↓
Atomic production activation
    ├── ship RollDice opening hook
    ├── inactive direct ship confirmation removed
    ├── legacy ship CF bypass retired
    ├── save version 2 activated
    ├── replay format 4 activated
    └── stale reconnect state rejected
    ↓
Full automated and manual activation evidence
    ↓
TWI-002 acceptance gate
    ↓
TWI-003 Entry Gate
```

Any failed gate, newly discovered production blocker, duplicate authority, missing TEST-003 category, squadron shared opening, or inability to perform the compatibility cutover atomically is a stop condition.

# 7. Risk assessment

Planning estimates:

| Tranche | Architectural risk | Implementation risk | Regression risk | Complexity | GPT-5.6 success probability |
|---|---|---|---|---|---:|
| Slice 8B-1 | Low–medium: duplicate CF ownership is the principal hazard | Medium | High around CF, anti-squadron, and Swarm coexistence | Medium–high | 82% |
| Slice 8B-2 | Medium: guard ownership and cleanup cross several accepted command boundaries | High | High around ordering, stale intents, downstream combat, and persistence | High | 76% |
| Production activation | Medium–high: all accepted owners remain fixed, but the cutover cannot be split safely | High | Very high across live combat, compatibility, replay, networking, and reconnect | High | 70% |

These probabilities assume serial execution, no parallel changes to shared command or attack files, and enforcement of every intermediate gate.

# 8. Recommended implementation order

Do not run these prompts in parallel.

| Prompt | Exact scope | Why this boundary is appropriate |
|---|---|---|
| 1. Implement Slice 8B-1 only | “Treat TWI-002 as sole authority. Reconfirm the Section 15.5.1 inventory, implement only Slice 8B-1, keep production opening disabled, run the Concentrate Fire Readiness Gate, and stop before H9.” | Isolates the existing production choice before H9. It avoids version, opener, H9, and direct-confirmation conflicts. |
| 2. Verify the CF Readiness Gate | “Read-only verification of every Section 15.5.3 criterion. Confirm no production opener, version transition, H9 work, or Swarm behavior change.” | Prevents an incomplete second participant from contaminating H9 evidence. It creates no merge conflict because it is read-only. |
| 3. Implement Slice 8B-2 pre-activation only | “Treat TWI-002 as sole authority. Implement H9 rule, use/decline commands, guard lifecycle, coexistence, cleanup, projection, and persistence evidence. Keep production opening disabled and retain save 1/replay 3.” | Keeps H9 semantics separate from the compatibility cutover and permits deterministic failure diagnosis. |
| 4. Verify the Pre-Activation Gate | “Read-only verification of the Production Coexistence and H9 Pre-Activation Gate, including H9/CF ordering, cleanup, anti-squadron, persistence, replay, network, reconnect, Accuracy/defense, and Swarm.” | Ensures all semantic participants are complete before the irreversible compatibility boundary. |
| 5. Perform the atomic production activation | “Implement only TWI-002’s atomic production-activation checkpoint: enable ship post-roll opening, remove inactive direct ship confirmation, retire the ship CF bypass, activate save 2/replay 4 rejection boundaries, and enforce stale reconnect rejection. Preserve squadron/Swarm behavior.” | All mutually dependent changes land together. This avoids an invalid intermediate repository state and contains conflicts to the known activation seams. |
| 6. Verify TWI-002 completion | “Read-only verification of TWI-002’s full-tranche acceptance matrix, compatibility boundaries, command-sequence oracles, and manual-test readiness.” | Separates acceptance from implementation and catches only workbook-defined failures. |
| 7. Re-run the TWI-003 Entry Gate | “Verify TWI-003 Entry Gate only. Confirm TWI-002 activation, save version 2, replay format 4, signed alias, clean baseline, and protected tests before authorizing TWI-003 Slice 1.” | Prevents TWI-003 work from beginning until its explicit dependency is factually satisfied. |

Recommended commit sequence is therefore exactly three implementation commits: Slice 8B-1, Slice 8B-2 pre-activation, and the atomic production activation. Verification prompts should not create commits.
