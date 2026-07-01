# CAP-UPG-001: Grand Moff Tarkin Command Token Grant

Package ID: CAP-UPG-001
Title: Grand Moff Tarkin Command Token Grant
Status: Draft
Component Type: upgrade
Source Component: grand_moff_tarkin
Related ADRs: ADR-003, ADR-004
Related Contracts: CON-003, CON-004
Related Context Packs: CP-001
Related Tests: Required tests listed in this package
Created: 2026-06-28
Last Updated: 2026-07-01
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

It identifies the behavior slice, accepted ownership constraints, affected
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

## Accepted Implementation Decisions

The Project Owner has accepted these Tarkin-specific implementation decisions
before implementation begins:

- The source of the Tarkin rule is the runtime upgrade instance on the ship
  carrying Grand Moff Tarkin.
- The rule exists only while that runtime upgrade instance exists in play.
- If the source ship is destroyed before the Start of Ship Phase trigger
  resolves, the Tarkin ability is unavailable.
- If the ability has already resolved, granted command tokens remain.
- Tarkin uses a command-owned implementation path.
- Tarkin shall not be implemented as a passive RuleRegistry-only observer.
- Declining to use Tarkin shall be represented by an explicit replayable
  command-history entry.
- The use of Tarkin and the chosen command are public.
- Both players may observe the Tarkin prompt.
- After the controlling player makes the choice, the non-controlling player
  should be able to acknowledge or read the chosen command before play
  continues where applicable.
- Tarkin shall use the existing command-token gain path.
- Existing `RuleSurface.TARGET_COMMAND_TOKEN_GAIN` blockers shall apply.
- Duplicate granted command tokens shall use the existing automatic
  duplicate-discard behavior and shall not create a discard prompt.
- Non-duplicate command-token overflow shall reuse the existing
  `DiscardTokenCommand` flow.
- If several ships require overflow resolution, they shall be processed
  deterministically in `PlayerState.ships` order.
- The once-per-Ship-Phase trigger guard belongs to the runtime upgrade instance
  by default.

## Related Architecture Documents

- `ARCHITECTURE.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/adr/ADR-003-rule-and-validation-surfaces.md`
- `docs/architecture/adr/ADR-004-upgrade-runtime-ownership.md`
- `docs/architecture/contracts/CON-003-rule-capability-contract.md`
- `docs/architecture/contracts/CON-004-upgrade-runtime-contract.md`
- `docs/architecture/context/CP-001-game-component-rule-extension.md`
- `docs/architecture/templates/RULE_CAPABILITY_PACKAGE_TEMPLATE.md`

Authority notes:

- ADR-003 defines the accepted rule and validation surface architecture.
- ADR-004 defines the accepted runtime ownership model for active upgrade
  instances and mutable upgrade state.
- CON-003 defines the Rule Capability Package contract.
- CON-004 defines the implementation contract for runtime upgrade instances.
- CP-001 is Baseline Evidence and does not decide future architecture.
- Codex may recommend readiness but may not mark this package `Integrated`.

## Runtime Ownership

Runtime ownership is governed by accepted ADR-004 and CON-004.

For this package, Grand Moff Tarkin uses the default ownership model:
the source runtime upgrade instance belongs on the owning ShipInstance and
references static upgrade data by data_key.

The Tarkin rule exists only while that source runtime upgrade instance exists in
play. If the source ship is destroyed before the Start of Ship Phase trigger
resolves, the ability is unavailable. If the ability has already resolved,
granted command tokens remain.

This package does not create an exception to ADR-004 or CON-004.
If implementation later needs an exception, it must be justified in this
Rule Capability Package before implementation proceeds.

Evidence from CP-001 and the completed evidence analysis:

- Upgrade assignments are serialized in fleet roster entries.
- Fleet/setup validation already consumes upgrade assignment data.
- Fleet setup uses assigned upgrades for fleet-point calculation.
- No generic active runtime upgrade-state collection was observed on
  `ShipInstance` before ADR-004 and CON-004.
- `ShipInstance` serializes ship mutable state and static ship identity, but
  the completed evidence analysis predated the accepted runtime upgrade
  instance contract.

This package does not create an exception to ADR-004 or CON-004. If
implementation later needs an exception for Tarkin, the exception must be
justified in this Rule Capability Package before implementation proceeds.

## Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| Static upgrade data | Required | `Resources/Game_Components/upgrades/commander/grand_moff_tarkin.json`; `UpgradeData`; `AssetLoader` | Source exists, but metadata is not active behavior. |
| Fleet validation | Required | `FleetValidator`; `FleetUpgradeAssignment`; `FleetShipEntry`; commander/upgrade tests identified in evidence analysis | Confirms legal commander assignment before setup. |
| Runtime state | Required | ADR-004; CON-004; `GameState`; `PlayerState`; `ShipInstance`; setup package and roster evidence | Source runtime upgrade instance belongs on the owning `ShipInstance` by default. |
| Command validation | Required | `CommandProcessor`; `CommandApplicability`; command classes | A submitted choice/grant must be legal and phase-scoped. |
| Command execution | Required | Existing command-token mutation paths and `CommandTokenManager` | Tarkin uses a command-owned implementation path; token grant mutates friendly ships. |
| RuleRegistry | Optional | `RuleRegistry`; `RuleSurface` | Tarkin shall not be implemented as a passive RuleRegistry-only observer. RuleRegistry may be used only where appropriate under ADR-003. |
| RuleSurface | Required | `RuleSurface.TARGET_COMMAND_TOKEN_GAIN`; existing token-gain blocker patterns | Existing command-token-gain blockers shall apply. |
| Projection | Required | `InteractionFlow`; `FlowSpec`; `UIProjector` | Start-of-Ship-Phase command choice needs a prompt or equivalent affordance. |
| Serialization | Required | `GameState.serialize`; `PlayerState`; `ShipInstance`; `InteractionFlow`; command serialization | Choice, trigger guard, token state, and active commander source must survive save/load as applicable. |
| Replay | Required | `CommandProcessor` history; `GameReplay` | Choice and token grant must be command-history deterministic. |
| Network | Required | `NetworkManager`; snapshots; reconnect path | Host/server authority and reconnect projection must agree. |
| Visibility | Required | `StateFilter`; `InteractionFlow.visible_to`; `UIProjector` | Tarkin prompt, use, and chosen command are public. |
| Tests | Required | Required tests listed below | No existing tests prove this rule active. |

## Runtime State

Required runtime facts:

- The player who owns Grand Moff Tarkin.
- The ship or fleet assignment that proves the commander is active.
- The source runtime upgrade instance on the ship carrying Grand Moff Tarkin.
- The selected command for the Ship Phase, or an explicit declined choice
  represented by command history.
- A once-per-Ship-Phase trigger guard on the runtime upgrade instance.
- Resulting command-token state on each affected friendly ship.

Existing state evidence:

- ADR-004 and CON-004 define the runtime upgrade instance ownership model.
- `ShipInstance.command_tokens` and `CommandTokenManager` already represent
  command tokens.
- Command tokens serialize with ship state.
- `InteractionFlow.payload` is JSON-safe and serializes through `GameState`.
- Command history serializes submitted commands.

Implementation gap:

- No Tarkin-specific runtime upgrade instance materialization or trigger guard
  implementation exists yet.

## Validation Surfaces

Validation is required before implementation can be considered safe.

Required validation checks:

- The submitting player owns Grand Moff Tarkin.
- The source runtime upgrade instance exists in play.
- The game is at the start of the Ship Phase.
- The rule has not already been used for that Ship Phase.
- The chosen command is one of the valid Armada command types.
- The command is submitted by the correct player or authority.
- Token gain respects existing `RuleSurface.TARGET_COMMAND_TOKEN_GAIN` blockers.
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
- Record an explicit command-history entry when the owning player declines.
- Grant matching command tokens to friendly ships.
- Avoid granting tokens to enemy ships.
- Apply existing token-gain blocker behavior.
- Automatically discard duplicate granted command tokens without creating a
  discard prompt.
- Reuse `DiscardTokenCommand` for non-duplicate command-token overflow.
- Resolve multi-ship overflow deterministically in `PlayerState.ships` order.
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

- Present a public start-of-Ship-Phase Tarkin choice controlled by the owning
  player.
- Allow decline through an explicit replayable command.
- Allow both players to observe the Tarkin prompt.
- After the controlling player chooses, allow the non-controlling player to
  acknowledge or read the chosen command before play continues where applicable.
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
- Chosen command or explicit decline command.
- Once-per-Ship-Phase trigger guard on the runtime upgrade instance.
- Mutated command-token state.
- Active prompt payload, if the game is saved or reconnected during the choice.

Existing serialization evidence:

- `GameState.serialize()` serializes phase, player states, interaction flow,
  objectives/setup state, damage deck, RNG, and related gameplay state.
- `ShipInstance` serializes command-token state.
- `InteractionFlow` payloads are expected to be JSON-safe.
- Game commands serialize into command history.

Implementation gap:

- No Tarkin-specific serialized runtime upgrade instance or trigger guard
  implementation exists yet.

## Replay Impact

Replay impact is required because the chosen command and resulting token grants
change gameplay state.

Required replay behavior:

- The chosen command or explicit decline must be represented in replayable command
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

Accepted visibility classification:

- The use of Tarkin is public.
- The chosen command is public.
- Both players may observe the Tarkin prompt.
- After the controlling player makes the choice, the non-controlling player
  should be able to acknowledge or read the chosen command before play continues
  where applicable.
- The resulting command-token state remains public according to the accepted
  visibility model for ship command tokens.
- No private deck, facedown damage identity, or hidden random state is involved.

Existing visibility evidence:

- `InteractionFlow.visible_to` and `StateFilter` support owner-only payloads.
- `StateFilter` strips hidden command dials, hidden damage identities, RNG, and
  owner-only interaction payloads.

Missing visibility evidence:

- No Tarkin-specific visibility test exists yet.

## Evidence Map

| Evidence Type | Evidence | What It Proves |
| --- | --- | --- |
| Static source | `Resources/Game_Components/upgrades/commander/grand_moff_tarkin.json` | Tarkin exists as COMMANDER upgrade static data with NOT_INTEGRATED metadata. |
| Static model/loading | `UpgradeData`; `AssetLoader.load_upgrade_data()`; `AssetLoader.list_upgrade_keys()` | Upgrade records are typed and loadable. |
| Fleet assignment | `FleetUpgradeAssignment`; `FleetShipEntry`; `FleetRoster` | Upgrade assignments are represented in roster/setup payloads. |
| Fleet validation | `FleetValidator`; commander-related fleet tests identified in evidence analysis | Commander legality is currently a fleet/build concern. |
| Runtime setup | `FleetRosterSetupHelper`; `FleetSetupPackage`; `FleetSetupBootstrapper` | Setup converts roster data to runtime game state and uses upgrades for fleet points. |
| Runtime ownership | ADR-004; CON-004 | Active equipped upgrades become runtime upgrade instances on the owning `ShipInstance` by default; mutable upgrade state belongs to that instance by default. |
| Command tokens | `ShipInstance.command_tokens`; `CommandTokenManager` | Command-token state exists and serializes. |
| Command processing | `CommandProcessor`; `CommandApplicability`; `GameCommand` | Commands provide validation, execution, history, and replay surfaces. |
| Token-gain rule interaction | `RuleSurface.TARGET_COMMAND_TOKEN_GAIN`; existing token-gain blocker patterns | Tarkin token gain may need to respect existing blockers. |
| Projection | `InteractionFlow`; `FlowSpec`; `UIProjector` | Prompt and viewer-specific UI intent can be serialized/projected. |
| Visibility | `StateFilter`; `InteractionFlow.visible_to` | Owner-only payloads and hidden information are filtered by viewer. |
| Serialization | `GameState.serialize()`; `PlayerState`; `ShipInstance`; command serialization | Durable state and command history are available surfaces. |
| Replay | `CommandProcessor.serialize_history()`; `GameReplay` | Replay depends on serialized commands and deterministic state. |
| Network/reconnect | `NetworkManager`; snapshot/reconnect projection path | Live sync and reconnect require serialized state and filtered projection. |
| Architecture authority | ADR-003; ADR-004; CON-003; CON-004; CP-001 | Rule behavior requires capability-backed surface evidence before integration; active upgrade runtime ownership is decided. |

## Required Tests

Required before this package can advance beyond Draft/Identified:

- Static/catalog test confirming Tarkin's static upgrade record remains loadable
  and metadata remains a status claim, not active behavior proof.
- Fleet/setup test proving the accepted runtime ownership model can
  identify the Tarkin owner after setup and after save/load.
- Command registration and applicability tests for any new command used by the
  rule.
- Validation tests rejecting missing commander, wrong player, wrong phase,
  duplicate use in the same Ship Phase, and invalid command choice.
- Validation tests rejecting use when the source runtime upgrade instance is no
  longer in play before the trigger resolves.
- Execution tests granting the selected command token to friendly ships only.
- Execution tests proving granted tokens remain if the Tarkin ability has
  already resolved and the source ship is later destroyed.
- Execution tests proving duplicate granted command tokens are automatically
  discarded without a discard prompt.
- Execution tests proving non-duplicate command-token overflow uses the
  existing `DiscardTokenCommand` flow.
- Execution tests proving multi-ship overflow resolution is deterministic in
  `PlayerState.ships` order.
- Rule interaction tests proving command-token-gain blockers are respected.
- Projection tests for the start-of-Ship-Phase choice prompt and normal flow
  continuation after resolution or decline.
- Serialization/save-load tests for active source state, trigger guard,
  command-token results, and active prompt payload if applicable.
- Replay tests proving deterministic command choice, explicit decline, and token
  grant.
- Network/reconnect tests for reconnect during prompt and after token grant.
- Visibility tests proving the prompt, use, and chosen command are public.
- Metadata/status regression test if metadata is later advanced from
  `NOT_INTEGRATED`.

TEST-003 is not yet accepted, so the Project Owner determines whether test
coverage is sufficient for any non-Integrated status advancement.

## Risks

| Risk Area | Impact | Evidence / Rationale | Mitigation or Outstanding Work |
| --- | --- | --- | --- |
| Runtime ownership | Medium | ADR-004 and CON-004 define default ownership, but no Tarkin runtime instance implementation exists yet. | Implement and test the accepted runtime upgrade instance path. |
| Phase timing | Medium | Existing flow moves into Ship Phase activation; no Tarkin prompt was observed. | Define command/flow timing before implementation. |
| Token overflow/duplicates | Medium | Tarkin may grant tokens to multiple ships at once. | Use accepted duplicate auto-discard, `DiscardTokenCommand` overflow handling, and `PlayerState.ships` order; tests must cover each case. |
| Rule interactions | Medium | Existing token-gain blockers apply. | Validate against `TARGET_COMMAND_TOKEN_GAIN`. |
| Replay | Medium | Choice and grant must be command-history deterministic. | Add replay tests. |
| Network/reconnect | Medium | Prompt and grant affect live peer state and reconnect projection. | Add network/reconnect tests. |
| Trigger guard | Medium | The rule applies at the start of each Ship Phase and must not be applied more than once for the same timing window. | Store and test the guard on the runtime upgrade instance. |
| Visibility | Low | Prompt, use, chosen command, and resulting token state are public. | Add visibility tests for the accepted public behavior. |
| Metadata drift | Medium | Static JSON currently says `NOT_INTEGRATED`. | Do not update metadata until package evidence and owner approval support it. |

## Open Questions

- How should the start-of-Ship-Phase prompt be inserted into the existing flow?
- What test threshold is sufficient while TEST-003 does not exist?

## Evidence Gaps

- No Tarkin-specific runtime command, resolver, RuleRegistry hook, or execution
  path.
- No Tarkin-specific start-of-Ship-Phase interaction flow or projection path.
- No Tarkin-specific serialization/save-load test.
- No Tarkin-specific replay test.
- No Tarkin-specific network/reconnect test.
- No Tarkin-specific visibility test.

## Owner Decisions Required

Before implementation, the Project Owner must decide or explicitly delegate:

- Minimum sufficient tests before any status advancement.

## Integration Status

Current Status: Draft

Evidence summary:

- Static upgrade data exists and is loadable.
- Fleet/build assignment and validation surfaces exist.
- Command-token state, serialization, command history, replay, network snapshot,
  reconnect projection, and visibility filtering surfaces exist.
- ADR-004 and CON-004 define active upgrade runtime ownership.
- Project Owner decisions for source lifetime, command-owned implementation,
  decline recording, public visibility, token-gain blockers, duplicate/overflow
  handling, and runtime-instance trigger guard are recorded.
- No active Tarkin runtime behavior exists in the evidence collected.

Outstanding work:

- Remaining owner decisions listed above.
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
| Codex | 2026-07-01 | Owner decisions recorded | Recorded accepted Tarkin-specific implementation decisions. Draft status retained. |

## Summary of Evidence Captured

1. Grand Moff Tarkin is the smallest safe COMMANDER upgrade candidate compared
   with General Dodonna because it uses existing command-token state and avoids
   private damage-deck mutation.
2. Existing implementation surfaces support static upgrade loading, fleet
   validation, command-token mutation, command history, serialization, replay,
   network snapshots, reconnect projection, and visibility filtering.
3. Static metadata and rule-surface declarations are descriptive only and do not
   make the rule active.
4. Runtime upgrade ownership after setup is defined by accepted ADR-004 and
   CON-004.
5. Project Owner decisions now define Tarkin-specific source lifetime,
   command-owned implementation, decline recording, visibility, token-gain
   blockers, duplicate/overflow handling, and trigger-guard ownership.

## Remaining Evidence Gaps

1. Tarkin-specific command/flow/projection surface.
2. Tarkin-specific serialization, replay, network, reconnect, and visibility
   evidence.
3. Test sufficiency criteria while TEST-003 remains unavailable.

## Owner Decisions Required Before Implementation

1. Decide minimum test coverage required before status advancement.

## Recommended Implementation Task for VS Code

Implement the CAP-UPG-001 Grand Moff Tarkin command-token grant as a narrow
behavior slice: use the ADR-004/CON-004 runtime upgrade instance path,
command/flow handling,
projection, serialization, replay, network/reconnect, visibility filtering, and
focused tests required by this Draft package. Do not update upgrade JSON
integration status or mark the package `Integrated` until owner review approves
the evidence.
