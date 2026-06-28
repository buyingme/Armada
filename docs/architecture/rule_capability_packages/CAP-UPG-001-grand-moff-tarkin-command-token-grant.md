# CAP-UPG-001: Grand Moff Tarkin Command Token Grant

Package ID: CAP-UPG-001  
Title: Grand Moff Tarkin Command Token Grant  
Status: Draft  
Component Type: upgrade  
Source Component: grand_moff_tarkin  
Related ADRs: ADR-003  
Related Contracts: CON-003  
Related Context Packs: CP-001  
Related Tests: Required tests listed in this package  
Created: 2026-06-28  
Last Updated: 2026-06-28  
Owner: Project Owner review required

## Identity

This Rule Capability Package covers the `grand_moff_tarkin` COMMANDER upgrade
behavior that allows the owning player, at the start of each Ship Phase, to
choose one command and grant each friendly ship a matching command token.

Static source:

- `Resources/Game_Components/upgrades/commander/grand_moff_tarkin.json`

Observed metadata status:

- `rules_integration.status`: `NOT_INTEGRATED`
- `pending_rule_surfaces`: `phase.ship.start.command_choice`,
  `phase.ship.start.grant_tokens`
- `rule_surfaces`: command choice enabler and token-grant observer metadata
- `runtime_state_requirements`: `ship_phase_start_choice`,
  `friendly_ship_command_tokens`

This package is a Draft architecture artifact only. It does not change upgrade
JSON, production code, metadata status, or integration status.

## Purpose

The purpose of this package is to preserve the completed evidence analysis for
the Grand Moff Tarkin COMMANDER upgrade as a permanent CON-003 traceability
artifact.

It identifies the behavior slice, required ownership decisions, affected
surfaces, required tests, and known risks before implementation work begins.

## Scope

Included behavior:

- Grand Moff Tarkin's start-of-Ship-Phase command choice.
- Granting the selected command token to friendly ships.
- Command validation, execution, projection, serialization, replay, network,
  visibility, and test obligations needed for that behavior.

Excluded behavior:

- Generalized upgrade runtime architecture.
- Other COMMANDER upgrades.
- General Dodonna damage-deck behavior.
- Metadata status advancement.
- Marking this package `Integrated`.
- Any production implementation.

The package describes one coherent upgrade behavior slice. It does not approve a
general-purpose commander or upgrade subsystem.

## Rule Description

Grand Moff Tarkin is a COMMANDER upgrade. The relevant printed behavior is:

- At the start of each Ship Phase, the owning player may choose one command.
- Each friendly ship gains a command token matching that command.

The behavior is mixed:

- The rule source is static upgrade data.
- The active commander assignment must be discoverable at runtime.
- The command choice is player input.
- The token grant mutates ship command-token state.
- The result affects command validation, replay, network snapshots, reconnect,
  and visibility.

Static metadata alone is not active behavior evidence.

## Related Architecture Documents

- `ARCHITECTURE.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/context/CP-001-game-component-rule-extension.md`
- `docs/architecture/templates/RULE_CAPABILITY_PACKAGE_TEMPLATE.md`

Authority notes:

- ADR-003 defines the accepted rule and validation surface architecture.
- CON-003 defines the Rule Capability Package contract.
- CP-001 is Baseline Evidence and does not decide future architecture.
- Codex may recommend readiness but may not mark this package `Integrated`.

## Runtime Ownership

The runtime ownership question is unresolved.

Observed evidence from CP-001 and the completed evidence analysis:

- Upgrade assignments are serialized in fleet roster entries.
- Fleet/setup validation already consumes upgrade assignment data.
- Fleet setup uses assigned upgrades for fleet-point calculation.
- No generic active runtime upgrade-state collection was observed on
  `ShipInstance`.
- `ShipInstance` serializes ship mutable state and static ship identity, but
  the completed evidence analysis did not identify serialized runtime upgrade
  assignments on `ShipInstance`.

Owner decision required:

- Choose the active runtime owner for Grand Moff Tarkin's commander assignment
  and per-Ship-Phase trigger state before implementation.

Candidate ownership paths identified by evidence, not decided here:

- Derive the commander assignment from serialized setup/roster state if that is
  accepted as sufficient runtime source state.
- Add or reuse a serialized runtime upgrade-assignment state surface on ship,
  player, or game state.
- Use another owner-approved state path.

This package does not choose among those options.

## Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| Static upgrade data | Required | `Resources/Game_Components/upgrades/commander/grand_moff_tarkin.json`; `UpgradeData`; `AssetLoader` | Source exists, but metadata is not active behavior. |
| Fleet validation | Required | `FleetValidator`; `FleetUpgradeAssignment`; `FleetShipEntry`; commander/upgrade tests identified in evidence analysis | Confirms legal commander assignment before setup. |
| Runtime state | Required | `GameState`; `PlayerState`; `ShipInstance`; setup package and roster evidence | Active owner unresolved. |
| Command validation | Required | `CommandProcessor`; `CommandApplicability`; command classes | A submitted choice/grant must be legal and phase-scoped. |
| Command execution | Required | Existing command-token mutation paths and `CommandTokenManager` | Token grant mutates friendly ships. |
| RuleRegistry | Optional | `RuleRegistry`; `RuleSurface` | May be used only if accepted call sites exist. Not required by ADR-003. |
| RuleSurface | Required if token-gain hooks are used | `RuleSurface.TARGET_COMMAND_TOKEN_GAIN`; existing token-gain blocker patterns | Needed to respect existing token-gain blockers if implementation uses this surface. |
| Projection | Required | `InteractionFlow`; `FlowSpec`; `UIProjector` | Start-of-Ship-Phase command choice needs a prompt or equivalent affordance. |
| Serialization | Required | `GameState.serialize`; `PlayerState`; `ShipInstance`; `InteractionFlow`; command serialization | Choice, trigger guard, token state, and active commander source must survive save/load as applicable. |
| Replay | Required | `CommandProcessor` history; `GameReplay` | Choice and token grant must be command-history deterministic. |
| Network | Required | `NetworkManager`; snapshots; reconnect path | Host/server authority and reconnect projection must agree. |
| Visibility | Required | `StateFilter`; `InteractionFlow.visible_to`; `UIProjector` | Prompt visibility and post-choice public token state must be classified. |
| Tests | Required | Required tests listed below | No existing tests prove this rule active. |

## Runtime State

Required runtime facts:

- The player who owns Grand Moff Tarkin.
- The ship or fleet assignment that proves the commander is active.
- The selected command for the Ship Phase, or an explicit declined choice if the
  optional trigger is represented by command history.
- A once-per-Ship-Phase or equivalent trigger guard.
- Resulting command-token state on each affected friendly ship.

Existing state evidence:

- `ShipInstance.command_tokens` and `CommandTokenManager` already represent
  command tokens.
- Command tokens serialize with ship state.
- `InteractionFlow.payload` is JSON-safe and serializes through `GameState`.
- Command history serializes submitted commands.

Evidence gap:

- The active runtime owner for assigned upgrades after setup is unresolved.

## Validation Surfaces

Validation is required before implementation can be considered safe.

Required validation checks:

- The submitting player owns Grand Moff Tarkin.
- The game is at the start of the Ship Phase.
- The rule has not already been used for that Ship Phase.
- The chosen command is one of the valid Armada command types.
- The command is submitted by the correct player or authority.
- Token gain respects existing token-gain blockers where applicable.
- Duplicate-token and command-value overflow behavior is handled consistently
  with existing command-token rules.

Existing validation evidence:

- Fleet validation already covers commander and upgrade assignment legality.
- Command validation and applicability are centralized through command surfaces.
- Existing token-gain and blocker patterns exist for command-token behavior.

Missing validation evidence:

- No Tarkin-specific runtime command validation exists yet.

## Execution Surfaces

Execution is required because the rule mutates ship command-token state.

Required execution behavior:

- Record or consume the selected command in an authoritative command path.
- Grant matching command tokens to friendly ships.
- Avoid granting tokens to enemy ships.
- Apply existing token capacity, duplicate, discard, or blocker behavior.
- Preserve deterministic command results for replay and network sync.

Existing execution evidence:

- `CommandTokenManager` supports token mutation and serialization.
- Existing commands mutate command-token state through command execution.
- `CommandProcessor` records command history and observer follow-ups.

Missing execution evidence:

- No Tarkin-specific command, observer, resolver, or hook implementation exists.

## Projection Surfaces

Projection is required because the owning player must be able to choose a
command at the correct timing point.

Required projection behavior:

- Present a start-of-Ship-Phase Tarkin choice to the owning player.
- Allow decline if the optional trigger is represented explicitly.
- Transition back to normal Ship Phase activation after resolution or decline.
- Show resulting command-token state consistently.

Existing projection evidence:

- `InteractionFlow` stores active flow, controller, visibility, and payload.
- `UIProjector` derives viewer-specific UI intent from serialized state.
- `StateFilter` strips owner-only interaction payloads for non-controllers.

Missing projection evidence:

- No Tarkin-specific Ship Phase start prompt or flow step exists yet.

## Serialization Impact

Serialization impact is required.

State and payloads that may need serialization:

- Active commander source state.
- Chosen command or decline command.
- Once-per-Ship-Phase trigger guard, if not fully derived from command history.
- Mutated command-token state.
- Active prompt payload, if the game is saved or reconnected during the choice.

Existing serialization evidence:

- `GameState.serialize()` serializes phase, player states, interaction flow,
  objectives/setup state, damage deck, RNG, and related gameplay state.
- `ShipInstance` serializes command-token state.
- `InteractionFlow` payloads are expected to be JSON-safe.
- Game commands serialize into command history.

Evidence gap:

- Existing evidence does not identify an accepted serialized runtime owner for
  upgrade assignments after setup.

## Replay Impact

Replay impact is required because the chosen command and resulting token grants
change gameplay state.

Required replay behavior:

- The chosen command or decline must be represented in replayable command
  history.
- Token grants must replay deterministically.
- Any observer follow-up ordering must be deterministic if RuleRegistry observer
  hooks are used.

Existing replay evidence:

- `CommandProcessor` records command history.
- `GameReplay` replays serialized commands.
- Existing tests cover command-history round trips and rule ordering for other
  rule surfaces.

Missing replay evidence:

- No replay test exists for Tarkin command choice or token grants.

## Network Impact

Network impact is required.

Required network behavior:

- The authoritative peer/server must own command acceptance.
- Remote peers must receive the same command result and token state.
- Reconnect during the command-choice prompt must reconstruct the correct UI
  state for the controlling player.
- Reconnect after token grant must reconstruct the resulting token state.
- Passive peers must not synthesize duplicate prompt or grant behavior.

Existing network evidence:

- Network code serializes rosters, setup packages, commands, and snapshots.
- Reconnect projection uses serialized state, `StateFilter`, and `UIProjector`.
- Existing tests cover network/reconnect behavior for other surfaces.

Missing network evidence:

- No Tarkin-specific network or reconnect test exists.

## Visibility Impact

Visibility impact is required.

Visibility classification requiring owner review:

- The pre-choice prompt must be classified as owner/controller-only or public.
- The chosen command must be classified before and after resolution.
- The resulting command-token state must be classified according to the accepted
  visibility model for ship command tokens.
- No private deck, facedown damage identity, or hidden random state is involved.

Existing visibility evidence:

- `InteractionFlow.visible_to` and `StateFilter` support owner-only payloads.
- `StateFilter` strips hidden command dials, hidden damage identities, RNG, and
  owner-only interaction payloads.

Missing visibility evidence:

- The exact visibility policy for the Tarkin prompt and chosen command has not
  been decided by the Project Owner.

## Evidence Map

| Evidence Type | Evidence | What It Proves |
| --- | --- | --- |
| Static source | `Resources/Game_Components/upgrades/commander/grand_moff_tarkin.json` | Tarkin exists as COMMANDER upgrade static data with NOT_INTEGRATED metadata. |
| Static model/loading | `UpgradeData`; `AssetLoader.load_upgrade_data()`; `AssetLoader.list_upgrade_keys()` | Upgrade records are typed and loadable. |
| Fleet assignment | `FleetUpgradeAssignment`; `FleetShipEntry`; `FleetRoster` | Upgrade assignments are represented in roster/setup payloads. |
| Fleet validation | `FleetValidator`; commander-related fleet tests identified in evidence analysis | Commander legality is currently a fleet/build concern. |
| Runtime setup | `FleetRosterSetupHelper`; `FleetSetupPackage`; `FleetSetupBootstrapper` | Setup converts roster data to runtime game state and uses upgrades for fleet points. |
| Runtime state gap | CP-001 Section 3 and completed evidence analysis | No generic active runtime upgrade-state collection was observed on `ShipInstance`. |
| Command tokens | `ShipInstance.command_tokens`; `CommandTokenManager` | Command-token state exists and serializes. |
| Command processing | `CommandProcessor`; `CommandApplicability`; `GameCommand` | Commands provide validation, execution, history, and replay surfaces. |
| Token-gain rule interaction | `RuleSurface.TARGET_COMMAND_TOKEN_GAIN`; existing token-gain blocker patterns | Tarkin token gain may need to respect existing blockers. |
| Projection | `InteractionFlow`; `FlowSpec`; `UIProjector` | Prompt and viewer-specific UI intent can be serialized/projected. |
| Visibility | `StateFilter`; `InteractionFlow.visible_to` | Owner-only payloads and hidden information are filtered by viewer. |
| Serialization | `GameState.serialize()`; `PlayerState`; `ShipInstance`; command serialization | Durable state and command history are available surfaces. |
| Replay | `CommandProcessor.serialize_history()`; `GameReplay` | Replay depends on serialized commands and deterministic state. |
| Network/reconnect | `NetworkManager`; snapshot/reconnect projection path | Live sync and reconnect require serialized state and filtered projection. |
| Architecture authority | ADR-003; CON-003; CP-001 | Rule behavior requires capability-backed surface evidence before integration. |

## Required Tests

Required before this package can advance beyond Draft/Identified:

- Static/catalog test confirming Tarkin's static upgrade record remains loadable
  and metadata remains a status claim, not active behavior proof.
- Fleet/setup test proving the selected active runtime ownership path can
  identify the Tarkin owner after setup and after save/load.
- Command registration and applicability tests for any new command used by the
  rule.
- Validation tests rejecting missing commander, wrong player, wrong phase,
  duplicate use in the same Ship Phase, and invalid command choice.
- Execution tests granting the selected command token to friendly ships only.
- Execution tests for duplicate-token and command-value overflow behavior.
- Rule interaction tests proving command-token-gain blockers are respected.
- Projection tests for the start-of-Ship-Phase choice prompt and normal flow
  continuation after resolution or decline.
- Serialization/save-load tests for active source state, trigger guard,
  command-token results, and active prompt payload if applicable.
- Replay tests proving deterministic command choice and token grant.
- Network/reconnect tests for reconnect during prompt and after token grant.
- Visibility tests for owner-only pre-choice payload, if used, and public
  post-resolution token state.
- Metadata/status regression test if metadata is later advanced from
  `NOT_INTEGRATED`.

TEST-003 is not yet accepted, so the Project Owner determines whether test
coverage is sufficient for any non-Integrated status advancement.

## Risks

| Risk Area | Impact | Evidence / Rationale | Mitigation or Outstanding Work |
| --- | --- | --- | --- |
| Runtime ownership | High | No generic active runtime upgrade state was observed on `ShipInstance`. | Owner must choose active state owner before implementation. |
| Phase timing | Medium | Existing flow moves into Ship Phase activation; no Tarkin prompt was observed. | Define command/flow timing before implementation. |
| Token overflow/duplicates | Medium | Tarkin may grant tokens to multiple ships at once. | Tests must cover duplicate and overflow behavior. |
| Rule interactions | Medium | Existing token-gain blockers may apply. | Validate against `TARGET_COMMAND_TOKEN_GAIN` or owner-approved equivalent. |
| Replay | Medium | Choice and grant must be command-history deterministic. | Add replay tests. |
| Network/reconnect | Medium | Prompt and grant affect live peer state and reconnect projection. | Add network/reconnect tests. |
| Trigger guard | Medium | The rule applies at the start of each Ship Phase and must not be applied more than once for the same timing window. | Decide and test durable guard or command-history-derived guard. |
| Visibility | Low to medium | Prompt, chosen command, and resulting token state require explicit classification. | Owner must decide prompt/chosen-command/token visibility. |
| Metadata drift | Medium | Static JSON currently says `NOT_INTEGRATED`. | Do not update metadata until package evidence and owner approval support it. |

## Open Questions

- Where should active runtime upgrade assignment state live for Tarkin?
- Should the rule be implemented as a direct command, RuleRegistry observer, or
  another owner-approved command/resolver path?
- How should the start-of-Ship-Phase prompt be inserted into the existing flow?
- Should declining Tarkin's optional trigger be recorded as a command?
- How should duplicate-token and overflow choices be handled when several ships
  receive tokens at once?
- Should token-gain blockers apply through `RuleSurface.TARGET_COMMAND_TOKEN_GAIN`
  or another owner-approved surface?
- What is the exact visibility policy for the prompt and chosen command before
  resolution?
- What test threshold is sufficient while TEST-003 does not exist?

## Evidence Gaps

- No accepted active runtime owner for upgrade assignments after setup.
- No Tarkin-specific runtime command, resolver, RuleRegistry hook, or execution
  path.
- No Tarkin-specific start-of-Ship-Phase interaction flow or projection path.
- No Tarkin-specific serialization/save-load test.
- No Tarkin-specific replay test.
- No Tarkin-specific network/reconnect test.
- No Tarkin-specific visibility test.
- No owner decision on optional decline representation.

## Owner Decisions Required

Before implementation, the Project Owner must decide or explicitly delegate:

- Active runtime owner for Tarkin's commander assignment and per-Ship-Phase
  trigger state.
- Whether implementation should use a command-only path, RuleRegistry observer
  path, or another accepted path.
- How the start-of-Ship-Phase choice is represented in `InteractionFlow` or an
  equivalent projection surface.
- Whether decline is represented explicitly in command history.
- How multi-ship duplicate/overflow token behavior should be resolved.
- Whether existing command-token-gain blockers apply to Tarkin grants and which
  surface owns that interaction.
- Visibility policy for the prompt and chosen command.
- Minimum sufficient tests before any status advancement.

## Integration Status

Current Status: Draft

Evidence summary:

- Static upgrade data exists and is loadable.
- Fleet/build assignment and validation surfaces exist.
- Command-token state, serialization, command history, replay, network snapshot,
  reconnect projection, and visibility filtering surfaces exist.
- No active Tarkin runtime behavior exists in the evidence collected.
- Runtime ownership for upgrades remains unresolved.

Outstanding work:

- Owner decisions listed above.
- Runtime ownership selection.
- Implementation.
- Tests across validation, execution, projection, serialization, replay, network,
  and visibility.
- Metadata/status alignment after evidence exists.
- Owner review.

Approval state:

- Owner approval: not requested.
- Reviewers required: Project Owner; implementation owners for state, commands,
  projection, serialization, replay, network, and visibility.
- Review date: Not applicable.

Status constraints:

- This package must remain Draft until the Project Owner advances it.
- This package must not be marked `Integrated` by Codex.
- Existing upgrade JSON must remain `NOT_INTEGRATED` unless separately updated
  under owner-approved work.

## Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-06-28 | Draft prepared | Created from completed Evidence Analysis. No integration approval claimed. |

## Summary of Evidence Captured

1. Grand Moff Tarkin is the smallest safe COMMANDER upgrade candidate compared
   with General Dodonna because it uses existing command-token state and avoids
   private damage-deck mutation.
2. Existing implementation surfaces support static upgrade loading, fleet
   validation, command-token mutation, command history, serialization, replay,
   network snapshots, reconnect projection, and visibility filtering.
3. Static metadata and rule-surface declarations are descriptive only and do not
   make the rule active.
4. Runtime upgrade ownership after setup remains unresolved and must be decided
   before implementation.

## Remaining Evidence Gaps

1. Active runtime owner for Tarkin's upgrade assignment and trigger state.
2. Tarkin-specific command/flow/projection surface.
3. Tarkin-specific serialization, replay, network, reconnect, and visibility
   evidence.
4. Test sufficiency criteria while TEST-003 remains unavailable.

## Owner Decisions Required Before Implementation

1. Choose the runtime ownership model for active upgrade assignments.
2. Choose the implementation surface for Tarkin's start-of-Ship-Phase choice and
   token grant.
3. Decide prompt, decline, duplicate-token, overflow, blocker, and visibility
   behavior.
4. Decide minimum test coverage required before status advancement.

## Recommended Implementation Task for VS Code

Implement the CAP-UPG-001 Grand Moff Tarkin command-token grant as a narrow
behavior slice: add the owner-approved runtime state path, command/flow handling,
projection, serialization, replay, network/reconnect, visibility filtering, and
focused tests required by this Draft package. Do not update upgrade JSON
integration status or mark the package `Integrated` until owner review approves
the evidence.
