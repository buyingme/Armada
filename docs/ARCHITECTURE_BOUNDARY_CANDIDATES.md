# Architecture Boundary Candidates

> Scope: candidate ownership boundaries discovered from
> `docs/REALITY_GAP_REGISTER.md`, `docs/current_state_architecture_maps.md`,
> existing architecture docs, and targeted code evidence where needed.
>
> A boundary candidate is not an accepted architecture decision. This document
> does not create contracts, refactor code, or rewrite Arc42. It does not assume
> the documented architecture is correct, and it does not assume the actual
> implementation is wrong.
>
> Accepted ADRs govern any decided sub-scope. In particular, `ADR-001` is the
> normative authority for current-attack state and semantic attack mutation;
> the related candidate rows below remain open only for their broader scope.

## Summary

| Boundary | Stability | Risk | Related gaps | Recommended next step |
|---|---|---|---|---|
| Live Game State Authority | Current-attack scope accepted; broader scope mostly stable | High | RG-001, RG-003, RG-014 | follow `ADR-001`; continue remaining boundary work |
| Command Processing and Applicability | Mostly stable | High | RG-003, RG-005, RG-012, RG-013 | add tests |
| Interaction Flow and UI Projection | Current-attack scope accepted; broader scope needs owner decision | High | RG-003, RG-004, RG-014 | follow `ADR-001`; continue remaining boundary work |
| Setup Flow and Setup Package | Mostly stable | High | RG-015, RG-001, RG-004 | create context pack first |
| Rule and Validation Surfaces | Needs owner decision | High | RG-005, RG-006, RG-012, RG-013 | create contract |
| Game Component Rule Extension | Needs owner decision | High | RG-005, RG-006, RG-011, RG-013, RG-015 | create contract |
| GameManager Orchestration | Needs owner decision | High | RG-001, RG-002, RG-007 | create context pack first |
| Network Command Sync and State Filtering | Mostly stable | High | RG-002, RG-003, RG-004, RG-013 | add tests |
| Save/Load and Checkpoint Boundary | Mostly stable | High | RG-001, RG-013, RG-016 | add tests |
| Replay and Baseline Trace Boundary | Mostly stable | High | RG-003, RG-005, RG-012, RG-013 | add tests |
| Presentation Preview and Local Workflow | Unstable | Medium | RG-004, RG-005, RG-014 | tolerate temporarily |
| Static Content and Asset Loading | Stable | Medium | RG-008, RG-011, RG-016 | update docs |
| Fleet Builder to Runtime Setup Handoff | Mostly stable | Medium | RG-015, RG-011, RG-013 | create context pack first |
| EventBus Integration Boundary | Needs owner decision | Medium | RG-002, RG-007 | create contract |
| Documentation Authority Boundary | Unstable | Medium | RG-008, RG-009, RG-010, RG-011, RG-012, RG-016 | update docs |

## Candidate Details

### B-001 - Live Game State Authority

| Field | Value |
|---|---|
| Boundary name | Live Game State Authority |
| Current owner subsystem | `GameManager.current_game_state` holds the live `GameState`; durable entities live under `src/core/state/`; mutations mostly flow through `GameCommand.execute()`. |
| Intended owner subsystem if different | For the current-attack sub-scope, `ADR-001` accepts `GameState` ownership of one canonical `CurrentAttackState` and replayable-command ownership of semantic mutation. Broader live-state and `GameManager` process authority remain candidate concerns. |
| State owned by this boundary | `GameState`, including the accepted `CurrentAttackState` boundary; `PlayerState`; `ShipInstance`; `SquadronInstance`; `DamageDeck`; `GameRng`; `InteractionFlow`; setup state in `GameState.objectives`; command history references; and round/phase/initiative fields. |
| Validation owned by this boundary | Structural state validity, deserialize defaults, entity lookup consistency, and command-level mutation preconditions when concrete commands touch state. |
| Serialization responsibility | Full save/network/replay-safe serialization of mutable game state. Static rules are not serialized; active rule source state is serialized through owning entities. |
| UI responsibility | None directly. UI should read state through projections, controllers, or wrappers and should not own durable game state. |
| Network/save/load/replay impact | Highest impact. This boundary is the source for filtered network snapshots, saves, load rebuilds, and replay determinism. |
| Related reality gaps | RG-001, RG-003, RG-014 |
| Risk level | High |
| Stability rating | Current-attack scope accepted in `ADR-001`; broader scope mostly stable |
| Recommended next step | Apply `ADR-001` to current-attack work; continue broader `BC-001` governance separately. |

### B-002 - Command Processing and Applicability

| Field | Value |
|---|---|
| Boundary name | Command Processing and Applicability |
| Current owner subsystem | `CommandProcessor`, `GameCommand` subclasses, `CommandApplicability`, `FlowSpec`, and `CommandSubmitter` implementations. `GameManager` owns many public wrapper methods into this path. |
| Intended owner subsystem if different | Docs intend command processing to own all durable game-state mutation and command validation. Current implementation largely matches, except for special interaction-flow publication/writes and broad `GameManager` wrapper usage. |
| State owned by this boundary | Command sequence, command history, observer follow-up queue, replay flags, serialized command payloads, and command result dictionaries. |
| Validation owned by this boundary | Preflight through `CommandApplicability`, registered rule validators, concrete `GameCommand.validate()`, and command-specific payload checks. |
| Serialization responsibility | `GameCommand.serialize()` / `deserialize()` and `CommandProcessor.serialize_history()`; payloads must remain JSON-safe. |
| UI responsibility | UI submits intent through commands or `GameManager.submit_*` wrappers and reacts to command results/signals. UI should not bypass command validation for durable mutation. |
| Network/save/load/replay impact | Network host/client command sync, replay command history, baseline traces, and save-safe state all depend on this boundary. |
| Related reality gaps | RG-003, RG-005, RG-012, RG-013 |
| Risk level | High |
| Stability rating | Mostly stable |
| Recommended next step | add tests |

### B-003 - Interaction Flow and UI Projection

| Field | Value |
|---|---|
| Boundary name | Interaction Flow and UI Projection |
| Current owner subsystem | `GameState.interaction_flow`, `InteractionFlow`, `FlowSpec`, `UIProjector`, `StateFilter`, `ModalRouter`, and selected scene controllers. Attack flow currently includes `AttackFlowFSM` and `PublishAttackFlowCommand`. |
| Intended owner subsystem if different | For current attacks, `ADR-001` makes `InteractionFlow`, projection, scene controllers, and UI non-authoritative consumers or mirrors; replayable commands own semantic attack mutation. Ownership outside that current-attack sub-scope remains a candidate concern. |
| State owned by this boundary | Active interaction-routing and projection data: flow type, step id, controller player, visibility, JSON-safe payload, projected modal kind, projected authority, and flow-specific UI metadata. Under `ADR-001`, this boundary does not own current-attack gameplay facts. |
| Validation owned by this boundary | Flow-step command applicability, controller ownership checks, visibility/payload filtering, and modal authority decisions. |
| Serialization responsibility | `InteractionFlow.serialize()` / `deserialize()` as part of `GameState`; payloads must remain JSON-safe and filterable. |
| UI responsibility | Render projected `UIIntent`; use payload metadata for affordances; avoid independent authority decisions where projection already exists. |
| Network/save/load/replay impact | High. A single state snapshot should rebuild modal state; network mirrors depend on published flow payloads; replay depends on deterministic flow transitions. |
| Related reality gaps | RG-003, RG-004, RG-014 |
| Risk level | High |
| Stability rating | Current-attack scope accepted in `ADR-001`; broader scope needs owner decision |
| Recommended next step | Apply `ADR-001` to current-attack work; continue broader `BC-003` governance separately. |

### B-004 - Setup Flow and Setup Package

| Field | Value |
|---|---|
| Boundary name | Setup Flow and Setup Package |
| Current owner subsystem | `docs/setup_flow.md`, `src/core/setup/`, setup commands, `SetupInteractionFlowResolver`, `FleetSetupPackage`, `FleetSetupBootstrapper`, `LobbyManager`, `SetupFlowScene`, and `SetupPlacementController`. |
| Intended owner subsystem if different | The setup contract intends step-level ownership to be explicit before setup UI work. Current architecture map records setup at a higher level and does not replace the setup contract. |
| State owned by this boundary | Match type, fleet setup package, player display names, roster payloads, initiative/objective/setup-state fields, obstacle placements, deployment placements, setup review state, setup `InteractionFlow`, and normalized placement payloads. |
| Validation owned by this boundary | Fleet/setup package validation, initiative/objective authorization, obstacle placement legality, deployment legality, setup review gating, and command payload validation. |
| Serialization responsibility | `FleetSetupPackage`, setup state stored in `GameState.objectives`, setup command payloads, lobby broadcasts, and save/load state after bootstrap. |
| UI responsibility | Setup screens, setup placement modal, previews, active/waiting projection, invalid-action feedback, and passive visibility according to `docs/setup_flow.md`. |
| Network/save/load/replay impact | High. Setup determines initial authoritative `GameState`, network lobby handoff, save/load reconstruction, and deterministic replay start conditions. |
| Related reality gaps | RG-015, RG-001, RG-004 |
| Risk level | High |
| Stability rating | Mostly stable |
| Recommended next step | create context pack first |

### B-005 - Rule and Validation Surfaces

| Field | Value |
|---|---|
| Boundary name | Rule and Validation Surfaces |
| Current owner subsystem | Hybrid ownership: `RuleRegistry` / `RuleSurface`, combat/damage/movement/setup/fleet resolvers, command validators, `CommandApplicability`, and scene-owned preview/payload assembly. |
| Intended owner subsystem if different | Docs often present `RuleRegistry` as the production extension boundary. Actual implementation keeps many core rules in resolvers and commands. |
| State owned by this boundary | Static rule hook definitions, active rule source state on serialized entities, resolver-derived legality values, command validation payloads, and rule-derived UI metadata. |
| Validation owned by this boundary | Rule validators, blockers, modifiers, observers/enablers, resolver legality checks, command validation, setup/fleet validation, and final command-result acceptance. |
| Serialization responsibility | Active rule state serializes through ships, squadrons, damage cards, objectives/upgrades/tokens where present, and command metadata. `RuleRegistry` itself is runtime-only. |
| UI responsibility | UI may display availability and selected state from payloads; it should not become the only owner of a rule predicate. Scene previews may inspect candidates but must not commit durable state. |
| Network/save/load/replay impact | High. Rule state must derive consistently after save/load, replay, hot-seat, and network mirroring. |
| Related reality gaps | RG-005, RG-006, RG-012, RG-013 |
| Risk level | High |
| Stability rating | Needs owner decision |
| Recommended next step | create contract |

### B-005A - Game Component Rule Extension

| Field | Value |
|---|---|
| Boundary name | Game Component Rule Extension |
| Current owner subsystem | Split across static component data under `Resources/Game_Components/`, model/data loaders, fleet/setup roster payloads, serialized runtime entities, `RuleRegistry` / `RuleSurface`, resolvers, command validators, `InteractionFlow.payload`, `UIProjector`, and UI panels. |
| Intended owner subsystem if different | Not yet decided. Docs imply future/source-first rule files under `src/core/effects/rules/`, while the current implementation activates some rules through registered hooks and others through resolver/command/UI workflow paths. |
| State owned by this boundary | Static component identity and rules text; roster assignments for ships, squadrons, upgrades, objectives, obstacles, and tokens; active serialized state such as equipped upgrades, faceup damage cards, squadron keywords, objective/setup state, token state, ready/exhausted/discarded status where implemented, and command/result metadata that proves timing or activation. |
| Validation owned by this boundary | Component legality at fleet/setup time, active-state eligibility, timing-window checks, command/path coverage for illegal actions, marker-command coverage, projected availability metadata, and final mutation validation. |
| Serialization responsibility | Static definitions are referenced by stable keys. Active component rule state must serialize through owning runtime entities or setup/objective state; `RuleRegistry` remains runtime-only. Any rule choice exposed to UI must use JSON-safe payload fields so save/load, replay, and network mirrors can rebuild the same active rule state. |
| UI responsibility | UI renders component text/art and rule-derived availability. UI may show disabled/enabled controls and selected state from payload metadata, but should not be the only owner of upgrade/card/keyword predicates. |
| Network/save/load/replay impact | High. Special-rule-bearing content must behave the same after setup handoff, save/load, replay, hot-seat, and network mirroring. New ships or squadrons without special rules mostly depend on static content and setup/fleet boundaries; upgrades, objectives, obstacles, tokens, and special ship/squadron rules require this boundary plus command/projection coverage. |
| Related reality gaps | RG-005, RG-006, RG-011, RG-013, RG-015 |
| Risk level | High |
| Stability rating | Needs owner decision |
| Recommended next step | create contract |

### B-006 - GameManager Orchestration

| Field | Value |
|---|---|
| Boundary name | GameManager Orchestration |
| Current owner subsystem | `src/autoload/game_manager.gd` as process-level orchestration hub, with command wrappers, active-player tracking, phase/round flow, setup/load handoff, activation trackers, network result effects, and EventBus emissions. |
| Intended owner subsystem if different | Docs describe `GameManager` more narrowly as lifecycle/round/phase progression, while actual implementation uses it as a broad application service hub. |
| State owned by this boundary | Current state reference, active player, activating ship/squadron, squadron activation counters, command submitted flags, command assigning player, command submitter strategy, pending scenario/setup package fields, and preloaded-state flags. |
| Validation owned by this boundary | Mostly orchestration gating and delegation. Concrete game validation belongs to commands/resolvers; current code also contains some lifecycle and network/client suppressions. |
| Serialization responsibility | Runtime orchestration state is mostly not serialized directly. It installs, consumes, or delegates serialization through `GameState`, save/load, replay, and setup package flows. |
| UI responsibility | Provides wrapper methods and emits signals consumed by UI/controllers. It does not render UI, but many UI paths depend on it. |
| Network/save/load/replay impact | High. It selects submitter strategy, processes remote command side effects, starts games from loaded state, and coordinates replay/autosave interactions. |
| Related reality gaps | RG-001, RG-002, RG-007 |
| Risk level | High |
| Stability rating | Needs owner decision |
| Recommended next step | create context pack first |

### B-007 - Network Command Sync and State Filtering

| Field | Value |
|---|---|
| Boundary name | Network Command Sync and State Filtering |
| Current owner subsystem | `NetworkManager`, `LobbyManager`, `NetworkCommandSubmitter`, `NetworkHostCommandSubmitter`, `CommandSyncGate`, `StateFilter`, `UIProjector`, and `GameManager` remote command handlers. |
| Intended owner subsystem if different | Docs intend authoritative serialized commands and filtered state/projection to drive network behavior. Actual implementation also relies on `GameManager` side-effect mirroring and attack-flow snapshots. |
| State owned by this boundary | Network role/connection state, peers, pending config, sync gate state, lobby state, filtered snapshots, remote command result handling, and local-player identity. |
| Validation owned by this boundary | Transport/session gates, server/host authority, client suppression of host-driven commands, command result application, and state filtering privacy rules. |
| Serialization responsibility | Serialized commands, command results, filtered `GameState` snapshots, lobby state, and setup packages crossing network boundaries. |
| UI responsibility | Network UI should render projected active/waiting states and lobby state. Presentation should not independently decide authority when projection/filtering owns it. |
| Network/save/load/replay impact | High by definition. Also affects network save/load and replay comparability where command/state hashes must match. |
| Related reality gaps | RG-002, RG-003, RG-004, RG-013 |
| Risk level | High |
| Stability rating | Mostly stable |
| Recommended next step | add tests |

### B-008 - Save/Load and Checkpoint Boundary

| Field | Value |
|---|---|
| Boundary name | Save/Load and Checkpoint Boundary |
| Current owner subsystem | `SaveGameManager`, `SaveGameMetadata`, `GameState.serialize()` / `deserialize()`, `IntegritySigner`, `SaveFileStore`, save/load dialogs, and `GameManager.start_new_game_from_state()`. |
| Intended owner subsystem if different | Docs intend all mutable durable state to serialize/deserialize. Current implementation follows this broadly, with runtime/process state reconstructed or left transient. |
| State owned by this boundary | Save metadata, signed payloads, per-mode checkpoints, dirty/checkpoint state, serialized `GameState`, command count at save, and mode-specific save availability. |
| Validation owned by this boundary | Save metadata validation, HMAC/signature checks, version checks, safe-save gating, network client refusal, and load context gating. |
| Serialization responsibility | Entire durable game payload plus metadata. Runtime services are reconstructed from serialized game state and surrounding mode/session context. |
| UI responsibility | Save/load dialogs, disabled rows/tooltips, overwrite confirmation, save notification display, and context-aware visibility. |
| Network/save/load/replay impact | High. It is central to save/load and intersects network host/client behavior and replay-safe state assumptions. |
| Related reality gaps | RG-001, RG-013, RG-016 |
| Risk level | High |
| Stability rating | Mostly stable |
| Recommended next step | add tests |

### B-009 - Replay and Baseline Trace Boundary

| Field | Value |
|---|---|
| Boundary name | Replay and Baseline Trace Boundary |
| Current owner subsystem | `CommandProcessor` history, `GameReplay`, `ReplayDriver`, `BaselineTrace`, command serialization, deterministic RNG/deck state, and baseline trace scripts. |
| Intended owner subsystem if different | Docs intend replay determinism through serialized commands and command-mediated mutations. Actual implementation mostly matches, with attention needed around local flow writes and observer follow-ups. |
| State owned by this boundary | Command history, replay headers, serialized command array, replay driver runtime state, baseline trace state/hash diagnostics, and deterministic RNG/deck state through `GameState`. |
| Validation owned by this boundary | Command deserialize/execute validity, deterministic replay order, observer follow-up determinism, and baseline host/client state hash comparison. |
| Serialization responsibility | `GameReplay.serialize()` / `deserialize()`, command history serialization, and replay-safe command payloads. |
| UI responsibility | Minimal. UI may expose replay/debug operations, but replay correctness should not depend on UI events. |
| Network/save/load/replay impact | High for replay and baseline verification; also validates network determinism indirectly through trace/hash checks. |
| Related reality gaps | RG-003, RG-005, RG-012, RG-013 |
| Risk level | High |
| Stability rating | Mostly stable |
| Recommended next step | add tests |

### B-010 - Presentation Preview and Local Workflow

| Field | Value |
|---|---|
| Boundary name | Presentation Preview and Local Workflow |
| Current owner subsystem | `GameBoard` controllers, `AttackExecutor`, `TargetSelector`, `AttackPanelController`, `SetupPlacementController`, `SquadronPhaseController`, `ManeuverToolController`, tool scenes, and UI panels. |
| Intended owner subsystem if different | Docs intend preview to remain presentation state and durable decisions to flow through commands/projection. Actual implementation also has some rule-relevant payload assembly and attack-flow writes in presentation-owned workflows. |
| State owned by this boundary | Drag previews, target highlights, selected options before commit, local modal state, local attack workflow state, tool overlays, camera state, and transient UI caches. |
| Validation owned by this boundary | Preview eligibility hints and client-side feedback. Final legality should belong to commands/resolvers/rules before durable mutation. |
| Serialization responsibility | None for transient previews. When a preview becomes durable, its data must become JSON-safe command payload or `InteractionFlow.payload`. |
| UI responsibility | Primary rendering and input ownership for previews, modals, overlays, HUD controls, and local feedback. |
| Network/save/load/replay impact | Medium to high. Preview state should not be required for reconnect/save/replay, but current attack-flow behavior makes some workflow state visible to network projection. |
| Related reality gaps | RG-004, RG-005, RG-014 |
| Risk level | Medium |
| Stability rating | Unstable |
| Recommended next step | tolerate temporarily |

### B-011 - Static Content and Asset Loading

| Field | Value |
|---|---|
| Boundary name | Static Content and Asset Loading |
| Current owner subsystem | `Resources/Game_Components/`, `Resources/SWM-RULES-REFERENCE-GUIDE-150/`, `AssetLoader`, model resources/dictionaries, `GameScale`, scenario JSON, and visual/audio resource folders. |
| Intended owner subsystem if different | Arc42 still describes content as Godot Resources/.tres in places. Actual implementation uses JSON/assets loaded through `AssetLoader` into runtime model objects or dictionaries. Behavior-changing content crosses into B-005A rather than remaining only static content. |
| State owned by this boundary | Static ship/squadron/upgrade/objective/obstacle data, rules text/reference data, maps, scenarios, scale config, images, and audio. |
| Validation owned by this boundary | Asset lookup, missing catalog record rejection, schema assumptions in loaders/builders, and data-key consistency. |
| Serialization responsibility | Static data is referenced by stable keys, not serialized inline into game state except where setup package embeds roster payloads. |
| UI responsibility | Provides card art, component text, fleet catalog data, rules reference display, map/scenario assets, and audio/visual resources. |
| Network/save/load/replay impact | Medium for static data; high when the static component carries active special rules. Save/load/replay depend on stable keys resolving to the same static data. Network setup packages avoid local fleet-library dependencies by embedding roster payloads. |
| Related reality gaps | RG-008, RG-011, RG-016 |
| Risk level | Medium |
| Stability rating | Stable |
| Recommended next step | update docs |

### B-012 - Fleet Builder to Runtime Setup Handoff

| Field | Value |
|---|---|
| Boundary name | Fleet Builder to Runtime Setup Handoff |
| Current owner subsystem | `src/core/fleet/`, fleet builder UI, `FleetSetupPackageBuilder`, `FleetRosterSetupHelper`, `FleetSetupBootstrapper`, `LobbyManager`, and setup flow. |
| Intended owner subsystem if different | Current docs intend fleet/lobby selection to produce setup-ready serialized packages before runtime game state starts. Current implementation appears aligned, but ownership spans fleet, setup, lobby, and game bootstrap. |
| State owned by this boundary | Saved fleet rosters, fleet validation results, embedded roster payloads, display names, player indices, point format, selected objectives, setup package canonical hash, equipped upgrade assignments, squadron/ship component keys, and runtime mapping to `PlayerState`/instances. |
| Validation owned by this boundary | Fleet construction legality, point format matching, faction/name constraints, roster embedding validity, upgrade-slot/restriction legality, objective legality, catalog record existence, and setup package validation. Runtime special-rule activation belongs to B-005A after handoff. |
| Serialization responsibility | Fleet roster JSON, fleet setup package serialization/canonical hash, lobby broadcast payloads, and runtime `GameState` initialized from package. |
| UI responsibility | Fleet builder screens, fleet library panel, setup-flow fleet selection, lobby status/ready controls, and validation rendering. |
| Network/save/load/replay impact | Medium to high. It determines deterministic runtime state and network lobby start conditions; after bootstrap, save/load/replay depend on resulting `GameState`. |
| Related reality gaps | RG-015, RG-011, RG-013 |
| Risk level | Medium |
| Stability rating | Mostly stable |
| Recommended next step | create context pack first |

### B-013 - EventBus Integration Boundary

| Field | Value |
|---|---|
| Boundary name | EventBus Integration Boundary |
| Current owner subsystem | `EventBus` signal catalog plus distributed emitters/listeners across autoloads, scenes, UI panels, audio managers, debug/replay/network handlers. |
| Intended owner subsystem if different | Docs sometimes make EventBus exclusive for cross-system communication. Actual implementation uses EventBus mainly as a signal backbone beside direct `GameManager` wrappers and command/projection paths. |
| State owned by this boundary | No durable game state. It owns signal declarations and runtime subscription topology; listeners may update local state or submit commands. |
| Validation owned by this boundary | None directly beyond typed signal contracts. Validation belongs to command/resolver/projector paths after reactions occur. |
| Serialization responsibility | None. Event subscriptions are runtime-only and rebuilt by scene/autoload lifecycle. |
| UI responsibility | UI refresh, handoff, modal triggers, audio/tooltip reactions, and board updates often depend on EventBus emissions. |
| Network/save/load/replay impact | Medium. EventBus side effects must mirror command results consistently but are not themselves replay/save data. |
| Related reality gaps | RG-002, RG-007 |
| Risk level | Medium |
| Stability rating | Needs owner decision |
| Recommended next step | create contract |

### B-014 - Documentation Authority Boundary

| Field | Value |
|---|---|
| Boundary name | Documentation Authority Boundary |
| Current owner subsystem | `docs/current_state_architecture_maps.md`, `docs/REALITY_GAP_REGISTER.md`, Arc42 docs, flow/setup docs, phase plans, Copilot instructions, and skills. |
| Intended owner subsystem if different | Arc42 and skills contain intended architecture rules; current-state maps record observed implementation; phase docs contain historical and migration context. Authority is not uniformly marked. |
| State owned by this boundary | Documentation status, architectural claims, contracts, current-state descriptions, reality gaps, phase history, and contributor guidance. |
| Validation owned by this boundary | Human/process validation only: deciding which docs are current contracts, historical notes, or decision candidates. |
| Serialization responsibility | Not applicable to game runtime. Documentation itself is versioned as repository text. |
| UI responsibility | None. It affects Codex/contributor behavior rather than product UI. |
| Network/save/load/replay impact | Indirect but important. Stale docs can misdirect changes in network, save/load, replay, rules, and command processing. |
| Related reality gaps | RG-008, RG-009, RG-010, RG-011, RG-012, RG-016 |
| Risk level | Medium |
| Stability rating | Unstable |
| Recommended next step | update docs |
