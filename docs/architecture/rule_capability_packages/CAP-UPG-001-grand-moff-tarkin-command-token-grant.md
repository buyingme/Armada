# CAP-UPG-001: Grand Moff Tarkin Command Token Grant

Package ID: CAP-UPG-001
Title: Grand Moff Tarkin Command Token Grant
Status: Integrated
Component Type: upgrade
Source Component: grand_moff_tarkin
Related ADRs: ADR-003, ADR-004
Related Contracts: CON-003, CON-004
Related Context Packs: CP-001
Related Tests: Implemented tests listed in this package
Created: 2026-06-28
Last Updated: 2026-07-07
Owner: Project Owner status alignment requested

## Identity

This Rule Capability Package covers the `grand_moff_tarkin` COMMANDER upgrade
behavior that allows the owning player, at the start of each Ship Phase, to
choose one command and grant each friendly ship a matching command token.

Static source:

- `Resources/Game_Components/upgrades/commander/grand_moff_tarkin.json`

Observed metadata status:

- `rules_integration.status`: `INTEGRATED`
- `implemented_rule_ids`: `upgrade.grand_moff_tarkin.command_choice`,
  `upgrade.grand_moff_tarkin.grant_tokens`
- `pending_rule_surfaces`: none
- `rule_surfaces`: command choice enabler and token-grant observer metadata
- `runtime_state_requirements`: `ship_phase_start_choice`,
  `friendly_ship_command_tokens`

This package is the integration evidence artifact for the implemented
CAP-UPG-001 behavior slice. It records status alignment only; it does not change
production behavior.

## Purpose

The purpose of this package is to preserve the completed implementation
evidence for the Grand Moff Tarkin COMMANDER upgrade as a permanent CON-003
traceability artifact.

It identifies the behavior slice, accepted ownership constraints, affected
surfaces, implemented tests, and residual risks for the integrated behavior.

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
- Production behavior changes beyond the implemented CAP-UPG-001 slice.

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
- This status update is Project Owner-requested alignment after implementation
  evidence exists.

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

Implementation evidence:

- Upgrade assignments are serialized in fleet roster entries.
- Fleet/setup validation consumes upgrade assignment data.
- Fleet setup materializes assigned upgrades into `ShipInstance.runtime_upgrades`
  under the CON-004 runtime shape.
- `ShipInstance` serializes runtime upgrade instances and mutable
  `trigger_guards` / `rule_state`.
- `GrandMoffTarkin` reads the source runtime upgrade instance by
  `runtime_upgrade_id` and writes the once-per-Ship-Phase trigger guard there.

This package does not create an exception to ADR-004 or CON-004. If
implementation later needs an exception for Tarkin, the exception must be
justified in this Rule Capability Package before implementation proceeds.

## Surface Traceability

| Surface | Required? | Evidence | Notes |
| --- | --- | --- | --- |
| Static upgrade data | Required | `Resources/Game_Components/upgrades/commander/grand_moff_tarkin.json`; `UpgradeData`; `AssetLoader` | Source exists and metadata is aligned to implemented behavior. |
| Fleet validation | Required | `FleetValidator`; `FleetUpgradeAssignment`; `FleetShipEntry`; commander/upgrade tests identified in evidence analysis | Confirms legal commander assignment before setup. |
| Runtime state | Required | ADR-004; CON-004; `GameState`; `PlayerState`; `ShipInstance`; `GrandMoffTarkin` | Source runtime upgrade instance belongs on the owning `ShipInstance`; trigger guard and last-choice state live on that runtime upgrade. |
| Command validation | Required | `TarkinChoiceCommand`; `CommandProcessor`; `CommandApplicability`; `FlowSpec` | Submitted use/decline is legal only during the public Tarkin prompt. |
| Command execution | Required | `TarkinChoiceCommand`; `GrandMoffTarkin`; `CommandTokenManager`; `DiscardTokenCommand` | Tarkin uses a command-owned implementation path; token grant mutates friendly ships and delegates overflow. |
| RuleRegistry | Optional | `RuleRegistry`; `RuleSurface` | Tarkin shall not be implemented as a passive RuleRegistry-only observer. RuleRegistry may be used only where appropriate under ADR-003. |
| RuleSurface | Required | `RuleSurface.TARGET_COMMAND_TOKEN_GAIN`; `GrandMoffTarkin._token_gain_blocked()` | Existing command-token-gain blockers apply to granted tokens. |
| Projection | Required | `InteractionFlow`; `FlowSpec`; `UIProjector`; `ModalRouter`; `TarkinChoiceModal` | Start-of-Ship-Phase command choice is publicly projected and routed to a modal. |
| Serialization | Required | `GameState.serialize`; `PlayerState`; `ShipInstance`; `InteractionFlow`; command serialization | Choice, trigger guard, token state, and active commander source survive save/load and reconnect. |
| Replay | Required | `CommandProcessor` history; `GameReplay`; `TarkinChoiceCommand` serialization | Choice, decline, and token grant are command-history deterministic. |
| Network | Required | `NetworkManager`; remote command effects; command result ordering; reconnect path | Host/server authority, mirror ordering, remote token side effects, and reconnect projection agree. |
| Visibility | Required | `StateFilter`; `InteractionFlow.visible_to`; `UIProjector` | Tarkin prompt, use, chosen command, and token results are public. |
| Tests | Required | Tarkin command, modal, projector, flow, command applicability, save/load, replay, reconnect, network ordering, remote side-effect tests | Implemented tests prove the rule active. |

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

Implemented evidence:

- `GrandMoffTarkin.record_choice()` stores the Ship Phase trigger guard on the
  source runtime upgrade instance.
- Save/load coverage preserves the Tarkin trigger guard and granted token state.

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

Implemented validation evidence:

- `TarkinChoiceCommand.validate()` rejects wrong phase, wrong player, missing or
  destroyed source runtime upgrade, duplicate use in the same Ship Phase, and
  invalid command choice.
- `CommandApplicability` and `FlowSpec` block non-Tarkin commands while the
  public Tarkin prompt is active.

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

Implemented execution evidence:

- `TarkinChoiceCommand.execute()` records use or decline and enters normal ship
  activation flow.
- `GrandMoffTarkin.grant_command_tokens()` grants to friendly, non-destroyed
  ships in deterministic `PlayerState.ships` order.
- Duplicate granted tokens auto-discard without a discard prompt.
- Non-duplicate overflow reuses the existing `DiscardTokenCommand` flow.
- `RuleSurface.TARGET_COMMAND_TOKEN_GAIN` blockers are honored.

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

Implemented projection evidence:

- `FlowSpec` defines `TARKIN_COMMAND_CHOICE` with allowed `tarkin_choice`
  command and transition to `WAIT_FOR_SHIP_SELECT`.
- `UIProjector` projects the public Tarkin prompt for both players.
- `ModalRouter` routes `Constants.ModalKind.TARKIN_COMMAND_CHOICE` to
  `TarkinChoiceModal`.
- `TarkinChoiceModal` submits the replayable `TarkinChoiceCommand` for use or
  decline.

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

Implemented serialization evidence:

- The source runtime upgrade instance, trigger guard, last-choice `rule_state`,
  active prompt payload, command history, and granted command tokens serialize
  through existing `GameState`, `PlayerState`, `ShipInstance`,
  `InteractionFlow`, and command serialization paths.
- Save/load tests cover unresolved prompt state, trigger guard persistence, and
  granted token persistence.

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

Implemented replay evidence:

- `TarkinChoiceCommand` serializes/deserializes through the `GameCommand`
  registry.
- Command-history tests cover replayable choice and explicit decline entries.
- Network command-result ordering tests protect command sequence ordering before
  the Ship Phase Tarkin prompt.

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

Implemented network evidence:

- `GameManager._handle_remote_tarkin_choice()` classifies mirrored
  `tarkin_choice` results.
- Remote token side-effect handling emits token refresh, duplicate-discard, and
  discard-required events where applicable.
- Network command-result ordering tests prove held `assign_dials` results mirror
  before `advance_phase` and before the Tarkin prompt.
- Reconnect tests prove unresolved Tarkin prompt projection survives serialized
  state reconstruction.

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

Implemented visibility evidence:

- Projection tests prove both players observe the public Tarkin prompt.
- Choice, decline, selected command, and resulting command-token state are
  public command/result data.

## Evidence Map

| Evidence Type | Evidence | What It Proves |
| --- | --- | --- |
| Static source | `Resources/Game_Components/upgrades/commander/grand_moff_tarkin.json` | Tarkin exists as COMMANDER upgrade static data with INTEGRATED metadata. |
| Static model/loading | `UpgradeData`; `AssetLoader.load_upgrade_data()`; `AssetLoader.list_upgrade_keys()` | Upgrade records are typed and loadable. |
| Fleet assignment | `FleetUpgradeAssignment`; `FleetShipEntry`; `FleetRoster` | Upgrade assignments are represented in roster/setup payloads. |
| Fleet validation | `FleetValidator`; commander-related fleet tests identified in evidence analysis | Commander legality is currently a fleet/build concern. |
| Runtime setup | `FleetRosterSetupHelper`; `FleetSetupPackage`; `FleetSetupBootstrapper` | Setup converts roster data to runtime game state and uses upgrades for fleet points. |
| Runtime ownership | ADR-004; CON-004; `ShipInstance.runtime_upgrades`; `GrandMoffTarkin` | Active equipped upgrades become runtime upgrade instances on the owning `ShipInstance`; Tarkin reads and writes the source runtime upgrade instance. |
| Command tokens | `ShipInstance.command_tokens`; `CommandTokenManager` | Command-token state exists and serializes. |
| Command processing | `TarkinChoiceCommand`; `CommandProcessor`; `CommandApplicability`; `GameCommand` | Commands provide validation, execution, history, and replay surfaces for choice and decline. |
| Token-gain rule interaction | `RuleSurface.TARGET_COMMAND_TOKEN_GAIN`; `GrandMoffTarkin._token_gain_blocked()` | Tarkin token gain respects existing blockers. |
| Duplicate token handling | `CommandTokenManager.force_add_token()`; `GrandMoffTarkin._grant_command_token_to_ship()` | Duplicate granted command tokens auto-discard and do not create a discard prompt. |
| Overflow handling | `TarkinChoiceCommand` result payload; existing `DiscardTokenCommand` flow | Non-duplicate overflow reuses existing discard flow. |
| Deterministic order | `GrandMoffTarkin.grant_command_tokens()` | Multi-ship grant/overflow processing follows `PlayerState.ships` order. |
| Projection | `InteractionFlow`; `FlowSpec`; `UIProjector`; `ModalRouter`; `TarkinChoiceModal` | Prompt and viewer-specific UI intent serialize/project publicly and route to the modal. |
| Visibility | `StateFilter`; `InteractionFlow.visible_to`; `UIProjector` | Prompt, use, chosen command, and token results are public. |
| Serialization | `GameState.serialize()`; `PlayerState`; `ShipInstance`; command serialization | Runtime upgrade state, trigger guard, prompt payload, token state, and command history survive save/load. |
| Replay | `TarkinChoiceCommand`; `CommandProcessor.serialize_history()`; `GameReplay` | Choice, decline, and grants are replayable command history. |
| Network/reconnect | `NetworkManager`; `GameManager._handle_remote_tarkin_choice()`; command result ordering; snapshot/reconnect projection path | Live sync, side effects, reconnect, and mirrored ordering are implemented and tested. |
| Architecture authority | ADR-003; ADR-004; CON-003; CON-004; CP-001 | Rule behavior requires capability-backed surface evidence before integration; active upgrade runtime ownership is decided. |

## Test Evidence

Implemented automated coverage includes:

- Static/catalog loading coverage for Tarkin upgrade data through the component
  catalog and typed upgrade loader.
- Fleet/setup and runtime upgrade tests proving the accepted runtime ownership
  model can identify the Tarkin source after setup and save/load.
- `TarkinChoiceCommand` registration, serialization, validation, execution, and
  explicit decline coverage.
- `CommandApplicability` and `FlowSpec` coverage proving an unresolved
  `TARKIN_COMMAND_CHOICE` prompt cannot be bypassed by unrelated gameplay
  commands.
- Validation tests rejecting missing commander/source, wrong player, wrong
  phase, destroyed source, duplicate use in the same Ship Phase, and invalid
  command choice.
- Execution tests granting the selected command token to friendly ships only.
- Execution tests proving granted tokens remain if the Tarkin source ship is
  destroyed after resolution.
- Execution tests proving duplicate granted command tokens are automatically
  discarded without a discard prompt.
- Execution tests proving non-duplicate command-token overflow uses the
  existing `DiscardTokenCommand` flow.
- Execution tests proving multi-ship grant/overflow resolution follows
  `PlayerState.ships` order.
- Rule interaction tests proving `RuleSurface.TARGET_COMMAND_TOKEN_GAIN`
  blockers are respected.
- Projection and modal tests for the public start-of-Ship-Phase choice prompt,
  modal routing, choice submission, and normal flow continuation after
  resolution or decline.
- Serialization/save-load tests for active source state, trigger guard,
  command-token results, and unresolved prompt payload.
- Replay/command-history tests proving deterministic command choice, explicit
  decline, and token grant.
- Network/reconnect tests for command-result ordering, reconnect during prompt,
  remote command side-effect classification, token refresh, duplicate-discard,
  overflow-discard, and declined-choice no-op side effects.
- Visibility tests proving both players observe the prompt, use, and chosen
  command.

## Risks

| Risk Area | Impact | Evidence / Rationale | Mitigation or Outstanding Work |
| --- | --- | --- | --- |
| Runtime ownership | Low | ADR-004 and CON-004 define default ownership, and implementation uses the source runtime upgrade instance. | Continue testing runtime upgrade serialization and source lookup. |
| Phase timing | Low | Tarkin prompt is inserted before normal Ship Phase activation and cannot be bypassed by unrelated commands. | Preserve `FlowSpec`, `CommandApplicability`, and prompt-gating tests. |
| Token overflow/duplicates | Low | Duplicate auto-discard, `DiscardTokenCommand` overflow handling, and `PlayerState.ships` order are implemented and tested. | Preserve token-grant regression tests. |
| Rule interactions | Low | Existing token-gain blockers apply through `RuleSurface.TARGET_COMMAND_TOKEN_GAIN`. | Preserve blocker tests. |
| Replay | Low | Choice and grant are command-history deterministic through `TarkinChoiceCommand`. | Preserve command serialization/replay coverage. |
| Network/reconnect | Low | Prompt, remote side effects, command ordering, and reconnect projection are implemented and tested. | Preserve network ordering and remote side-effect tests. |
| Trigger guard | Low | The once-per-Ship-Phase guard is stored on the runtime upgrade instance. | Preserve duplicate-use and save/load guard tests. |
| Visibility | Low | Prompt, use, chosen command, and resulting token state are public. | Preserve public projection tests. |
| Metadata drift | Low | Static JSON and CAP status are aligned to implemented behavior. | Keep metadata/status changes tied to capability evidence. |

## Open Questions

None currently recorded for CAP-UPG-001.

## Evidence Gaps

None currently recorded for the implemented CAP-UPG-001 behavior slice.

## Owner Decisions Required

None currently recorded.

## Integration Status

Current Status: Integrated

Evidence summary:

- Static upgrade data exists, is loadable, and is aligned to `INTEGRATED`
  metadata.
- Fleet/build assignment and validation surfaces exist.
- Runtime upgrade instances materialize on `ShipInstance` and preserve the
  source runtime upgrade identity.
- `TarkinChoiceCommand` implements replayable use and decline.
- `GrandMoffTarkin` implements source lookup, trigger guard, command-token
  grant, duplicate auto-discard, overflow reporting, token-gain blocker checks,
  and deterministic friendly-ship order.
- `FlowSpec`, `UIProjector`, `ModalRouter`, and `TarkinChoiceModal` implement
  public flow/projection/modal behavior.
- Serialization, command history, replay, network result ordering, remote token
  side effects, reconnect projection, and visibility coverage exist.
- ADR-004 and CON-004 define active upgrade runtime ownership.
- Project Owner decisions for source lifetime, command-owned implementation,
  decline recording, public visibility, token-gain blockers, duplicate/overflow
  handling, and runtime-instance trigger guard are recorded.

Outstanding work:

- None currently recorded for the integrated CAP-UPG-001 behavior slice.

Approval state:

- Owner approval: status alignment requested by Project Owner.
- Reviewers required: Project Owner.
- Review date: 2026-07-07.

Status constraints:

- This package is `Integrated` for the implemented CAP-UPG-001 behavior slice.
- Future Tarkin behavior changes must preserve CAP-UPG-001 evidence or update
  this package before claiming continued integration.

## Review History

| Reviewer | Date | Decision | Notes |
| --- | --- | --- | --- |
| Codex | 2026-06-28 | Draft prepared | Created from completed Evidence Analysis. No integration approval claimed. |
| Codex | 2026-07-01 | Owner decisions recorded | Recorded accepted Tarkin-specific implementation decisions. Draft status retained. |
| Codex | 2026-07-07 | Integrated status aligned | Recorded implemented production evidence and aligned CAP/JSON status at Project Owner request. |

## Summary of Evidence Captured

1. Grand Moff Tarkin is the smallest safe COMMANDER upgrade candidate compared
   with General Dodonna because it uses existing command-token state and avoids
   private damage-deck mutation.
2. Existing implementation surfaces support static upgrade loading, fleet
   validation, command-token mutation, command history, serialization, replay,
   network snapshots, reconnect projection, and visibility filtering.
3. Implemented command, flow, projection, serialization, replay, network,
   reconnect, visibility, duplicate/overflow, blocker, and deterministic-order
   evidence makes the CAP-UPG-001 rule active.
4. Runtime upgrade ownership after setup is defined by accepted ADR-004 and
   CON-004.
5. Project Owner decisions now define Tarkin-specific source lifetime,
   command-owned implementation, decline recording, visibility, token-gain
   blockers, duplicate/overflow handling, and trigger-guard ownership.

## Remaining Evidence Gaps

None currently recorded for the integrated CAP-UPG-001 behavior slice.

## Owner Decisions Required

None currently recorded.

## Future Implementation Guidance

No implementation task remains for the integrated CAP-UPG-001 behavior slice.
Future Tarkin changes should be scoped as follow-up implementation tasks with
fresh evidence and tests.
