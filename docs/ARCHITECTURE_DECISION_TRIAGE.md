# Architecture Decision Triage

> Scope: triages major boundary candidates from
> `ARCHITECTURE_BOUNDARY_CANDIDATES.md` against the observed implementation in
> `current_state_architecture_maps.md`, the discrepancies in
> `REALITY_GAP_REGISTER.md`, and existing architecture documentation.
>
> This document does not refactor code, create contracts, or rewrite Arc42. It
> does not assume the documented architecture is correct, and it does not assume
> the current implementation is wrong. Statuses below are triage states, not
> accepted architecture decisions.
>
> Accepted ADRs govern decided sub-scopes. `ADR-001` is the normative authority
> for current-attack state and semantic attack mutation; broader concerns under
> the related boundary candidates remain in triage.

## Summary

| Boundary | Decision status | Risk | Codex risk | Recommended next step |
|---|---|---|---|---|
| Live Game State Authority | Current-attack scope accepted; broader scope remains | High | Medium | follow `ADR-001`; continue remaining boundary work |
| Command Processing and Applicability | Needs tests first | High | High | add tests |
| Interaction Flow and UI Projection | Current-attack scope accepted; broader scope needs owner decision | High | High | follow `ADR-001`; continue remaining boundary work |
| Setup Flow and Setup Package | Needs context pack first | High | Medium | create context pack first |
| Rule and Validation Surfaces | Needs owner decision | High | High | create contract |
| Game Component Rule Extension | Ready for contract | High | High | create contract |
| GameManager Orchestration | Needs context pack first | High | High | create context pack first |
| Network Command Sync and State Filtering | Needs tests first | High | High | add tests |
| Save/Load and Checkpoint Boundary | Needs tests first | High | Medium | add tests |
| Replay and Baseline Trace Boundary | Needs tests first | High | High | add tests |
| Presentation Preview and Local Workflow | Tolerate temporarily | Medium | High | tolerate temporarily |
| Static Content and Asset Loading | Update docs first | Medium | Low | update docs |
| Fleet Builder to Runtime Setup Handoff | Needs context pack first | Medium | Medium | create context pack first |
| EventBus Integration Boundary | Needs owner decision | Medium | Medium | create contract |
| Documentation Authority Boundary | Update docs first | Medium | High | update docs |

## Boundary Triage

### Live Game State Authority

| Field | Value |
|---|---|
| Boundary name | Live Game State Authority |
| Related reality gaps | RG-001, RG-003, RG-014 |
| Current implementation summary | `GameManager.current_game_state` holds the live `GameState`; durable state lives mainly under `src/core/state`; most durable mutations are command-mediated. The current-state map records `GameState` as the serialized source for saves, network snapshots, and replay-related state. |
| Intended/documented architecture summary | `ADR-001` makes `GameState` the owner of one canonical `CurrentAttackState` and replayable commands the owner of semantic attack mutation. Broader domain/core state and `GameManager` process authority remain under this boundary. |
| Main discrepancy | Current scene-owned attack state and local attack-flow writes are migration gaps against `ADR-001`, not unresolved architecture. Broader `GameManager` process authority remains open. |
| Risk level | High |
| Codex risk | Medium: Codex may add mutable state in runtime services or scene controllers instead of serialized state. |
| Network/save/load/replay impact | Highest. This boundary is the source for save/load payloads, filtered snapshots, replay determinism, and active rule-state reconstruction. |
| Recommended next step | follow `ADR-001`; continue remaining boundary work |
| Reasoning | Current-attack ownership and mutation are settled. Any further work under this broad boundary must preserve `ADR-001` while addressing only the remaining live-state concerns. |

### Command Processing and Applicability

| Field | Value |
|---|---|
| Boundary name | Command Processing and Applicability |
| Related reality gaps | RG-003, RG-005, RG-012, RG-013 |
| Current implementation summary | User input usually becomes a `GameCommand` submitted through `GameManager` wrappers and `CommandSubmitter` implementations into `CommandProcessor`. `CommandProcessor` runs command applicability, registered rule validators, command validation, execution, history, signals, and observer follow-ups. |
| Intended/documented architecture summary | Docs intend all durable game-state mutations to route through serialized commands, with command applicability, `FlowSpec`, and concrete validation aligned. |
| Main discrepancy | The command spine exists, but some flow publication/writes and rule-derived UI paths sit outside pure command ownership. Test visibility for command/applicability invariants is not captured in the current architecture docs. |
| Risk level | High |
| Codex risk | High: Codex can add commands without all command-scope, marker-command, projection, replay, and network coverage. |
| Network/save/load/replay impact | High. Serialized command shape and validation determine replay, network mirroring, and deterministic state transitions. |
| Recommended next step | add tests |
| Reasoning | This boundary is mostly stable, but contract work without a visible test map would encode assumptions that may not be protected. |

### Interaction Flow and UI Projection

| Field | Value |
|---|---|
| Boundary name | Interaction Flow and UI Projection |
| Related reality gaps | RG-003, RG-004, RG-014 |
| Current implementation summary | `GameState.interaction_flow`, `FlowSpec`, `UIProjector`, `StateFilter`, `ModalRouter`, and scene controllers collaborate to drive modal authority. Attack flow currently includes `AttackFlowFSM` and `PublishAttackFlowCommand`, with scene-owned writes recorded in the current-state map. |
| Intended/documented architecture summary | For current attacks, `ADR-001` makes `InteractionFlow`, `FlowSpec`, `UIProjector`, scene controllers, modal routers, and UI derived and non-authoritative; replayable commands own semantic attack mutation. |
| Main discrepancy | Current scene-owned attack workflow and flow publication remain migration gaps against `ADR-001`. Ownership of non-attack interaction and projection surfaces remains broader unresolved scope. |
| Risk level | High |
| Codex risk | High: Codex may spread direct flow writes, local modal authority, or UI-driven step inference. |
| Network/save/load/replay impact | High. Reconnect, network mirrors, save/load UI reconstruction, and replay determinism depend on clear flow ownership. |
| Recommended next step | follow `ADR-001`; continue remaining boundary work |
| Reasoning | Direct scene ownership of current-attack facts is no longer an open option. Further triage must address only non-attack flow and projection concerns without reopening `ADR-001`. |

### Setup Flow and Setup Package

| Field | Value |
|---|---|
| Boundary name | Setup Flow and Setup Package |
| Related reality gaps | RG-015, RG-001, RG-004 |
| Current implementation summary | Setup spans `docs/setup_flow.md`, core setup helpers, setup commands, `FleetSetupPackage`, `SetupInteractionFlowResolver`, lobby/setup scenes, and setup placement controllers. Durable placement uses normalized command payloads; previews remain transient. |
| Intended/documented architecture summary | `docs/setup_flow.md` is accepted as the mandatory setup UI contract and requires trigger, controller, visibility, state, validation, transitions, and tests per step. |
| Main discrepancy | The boundary candidate is architecture-level; the setup contract is step-level. The two are complementary but not yet packaged as a concise implementation context. |
| Risk level | High |
| Codex risk | Medium: Codex may implement setup UI from broad architecture notes without checking the step contract. |
| Network/save/load/replay impact | High. Setup produces initial runtime `GameState`, network lobby handoff payloads, and replay/save baseline state. |
| Recommended next step | create context pack first |
| Reasoning | The setup contract already exists. A context pack should assemble the concrete files, state keys, commands, and tests before any new setup contract or implementation work. |

### Rule and Validation Surfaces

| Field | Value |
|---|---|
| Boundary name | Rule and Validation Surfaces |
| Related reality gaps | RG-005, RG-006, RG-012, RG-013 |
| Current implementation summary | Rule behavior is hybrid: `RuleRegistry` hooks, resolver-owned rules, command validation/execution, setup/fleet validators, and scene-owned previews/payload assembly all participate. |
| Intended/documented architecture summary | Docs often state that `RuleRegistry` is the production rule-extension architecture, with active state read from serialized entities and UI rendering from payload metadata. |
| Main discrepancy | The documented rule-extension architecture is narrower than the actual rule behavior surface. Existing rules live in several places. |
| Risk level | High |
| Codex risk | High: Codex may implement only one surface and leave command, marker, projection, save/load, replay, or network paths inconsistent. |
| Network/save/load/replay impact | High. Rule predicates must derive from serialized active state and be deterministic across all modes. |
| Recommended next step | create contract |
| Reasoning | The boundary is not ready for feature work without a decision on whether resolver/command-owned rule logic remains first-class or `RuleRegistry` becomes the sole extension path. |

### Game Component Rule Extension

| Field | Value |
|---|---|
| Boundary name | Game Component Rule Extension |
| Related reality gaps | RG-005, RG-006, RG-011, RG-013, RG-015 |
| Current implementation summary | Special-rule-bearing content is split across static JSON/component data, fleet/setup roster payloads, serialized runtime entities, `RuleRegistry`/`RuleSurface`, resolvers, commands, `InteractionFlow.payload`, `UIProjector`, and UI panels. |
| Intended/documented architecture summary | Docs suggest source-first rule files and `RuleRegistry` hooks for new rules, but active support is currently proven mainly for registered damage-card rules and some squadron keywords. |
| Main discrepancy | New ships/squadrons without special rules fit the static content path, but upgrades, objectives, obstacles, tokens, and special ship/squadron rules do not yet have a single accepted expansion boundary. |
| Risk level | High |
| Codex risk | High: Codex may treat behavior-changing content as static data or add a hook without active-state serialization, command validation, projection, or tests. |
| Network/save/load/replay impact | High. Expansion rules must remain deterministic after setup handoff, save/load, replay, hot-seat, and network mirroring. |
| Recommended next step | create contract |
| Reasoning | This is the most important boundary for product extensibility. It is sufficiently identified and should become an explicit contract before adding broad new special-rule content. |

### GameManager Orchestration

| Field | Value |
|---|---|
| Boundary name | GameManager Orchestration |
| Related reality gaps | RG-001, RG-002, RG-007 |
| Current implementation summary | `GameManager` is a broad orchestration hub: current state reference, active player, activation trackers, command wrappers, setup/load handoff, submitter strategy, EventBus emissions, and network result side effects. |
| Intended/documented architecture summary | Docs describe `GameManager` more narrowly as lifecycle/round/phase management and warn against growing it beyond prior ceilings. |
| Main discrepancy | Actual responsibility is broader than documented responsibility. It may be accepted application architecture or accumulated legacy. |
| Risk level | High |
| Codex risk | High: Codex may add new behavior to `GameManager` because it is convenient and already central. |
| Network/save/load/replay impact | High. `GameManager` selects submitter strategy, handles remote side effects, starts loaded games, and coordinates mode-sensitive behavior. |
| Recommended next step | create context pack first |
| Reasoning | Do not contract this boundary until its real call families and responsibilities are indexed. Owner decision is needed after a focused context pack. |

### Network Command Sync and State Filtering

| Field | Value |
|---|---|
| Boundary name | Network Command Sync and State Filtering |
| Related reality gaps | RG-002, RG-003, RG-004, RG-013 |
| Current implementation summary | Network behavior uses submitters, host/client command execution, `NetworkManager`, `LobbyManager`, `CommandSyncGate`, `StateFilter`, `UIProjector`, and `GameManager` remote command side-effect handling. |
| Intended/documented architecture summary | Docs intend authoritative serialized command sync, filtered snapshots, and projection-driven UI authority. |
| Main discrepancy | Implementation is mostly aligned but still depends on side-effect mirroring and attack-flow snapshots; test coverage visibility is not mapped. |
| Risk level | High |
| Codex risk | High: Codex may add UI/network branches, unfiltered payloads, or local-only side effects. |
| Network/save/load/replay impact | High by definition; also affects save/load and replay consistency when command/state hashes must match. |
| Recommended next step | add tests |
| Reasoning | Boundary behavior is known enough to protect with tests before changing contracts or adding feature work in network-sensitive flows. |

### Save/Load and Checkpoint Boundary

| Field | Value |
|---|---|
| Boundary name | Save/Load and Checkpoint Boundary |
| Related reality gaps | RG-001, RG-013, RG-016 |
| Current implementation summary | `SaveGameManager`, `SaveGameMetadata`, `GameState.serialize()`/`deserialize()`, signing, file storage, dialogs, and `GameManager.start_new_game_from_state()` own save/load and checkpoints. |
| Intended/documented architecture summary | Mutable durable state must serialize/deserialize; saves are signed and mode-aware; runtime process state is reconstructed or transient. |
| Main discrepancy | The boundary appears aligned, but architecture docs do not map invariant test coverage or which historical docs remain authoritative. |
| Risk level | High |
| Codex risk | Medium: Codex may add new mutable state without serialization or load rehydration coverage. |
| Network/save/load/replay impact | High. This is the save/load boundary and interacts with network host/client behavior and replay-safe state. |
| Recommended next step | add tests |
| Reasoning | Feature work can proceed only when new state has round-trip and load/install coverage. The next architecture step is test visibility, not a new contract. |

### Replay and Baseline Trace Boundary

| Field | Value |
|---|---|
| Boundary name | Replay and Baseline Trace Boundary |
| Related reality gaps | RG-003, RG-005, RG-012, RG-013 |
| Current implementation summary | Replay uses command history, `GameReplay`, `ReplayDriver`, `BaselineTrace`, command serialization, deterministic RNG/deck state, and baseline trace scripts. |
| Intended/documented architecture summary | Docs intend deterministic replay through serialized commands and command-mediated mutations. |
| Main discrepancy | Local flow writes, observer follow-ups, hybrid rule paths, and stale command inventory counts make replay assumptions easy to overstate. |
| Risk level | High |
| Codex risk | High: Codex may add non-command side effects or rule paths that replay does not reproduce. |
| Network/save/load/replay impact | High. Replay and baseline traces are the verification mechanism for command/state determinism and network parity. |
| Recommended next step | add tests |
| Reasoning | Before adding rule-heavy or flow-heavy features, baseline/replay coverage should prove the affected path is deterministic. |

### Presentation Preview and Local Workflow

| Field | Value |
|---|---|
| Boundary name | Presentation Preview and Local Workflow |
| Related reality gaps | RG-004, RG-005, RG-014 |
| Current implementation summary | Scene controllers and panels own previews, selections, overlays, attack workflow state, setup placement previews, and tool state. Some rule-relevant option assembly lives here. |
| Intended/documented architecture summary | Docs intend previews to remain transient and durable decisions to flow through commands/projection. UI should render rule metadata rather than own rule predicates. |
| Main discrepancy | Some current workflows, especially attack, are not fully reduced to core commands/projection and still write or assemble authoritative payloads in scene code. |
| Risk level | Medium |
| Codex risk | High: Codex may add rule logic or durable authority to UI because nearby code already has workflow logic. |
| Network/save/load/replay impact | Medium to high. Preview state should be reconstructable or disposable, but attack-flow payloads affect network projection. |
| Recommended next step | tolerate temporarily |
| Reasoning | Refactoring this before every feature would block progress. It should be constrained, not expanded, until owner decisions exist for flow and rules. |

### Static Content and Asset Loading

| Field | Value |
|---|---|
| Boundary name | Static Content and Asset Loading |
| Related reality gaps | RG-008, RG-011, RG-016 |
| Current implementation summary | Static content is JSON/assets under `Resources/Game_Components/`, loaded by `AssetLoader` into model resources or dictionaries. Static keys are referenced by runtime state. |
| Intended/documented architecture summary | Arc42 still describes Godot Resources/.tres in places and has stale file/class inventories. |
| Main discrepancy | Docs are stale for the current JSON-backed asset/content pipeline. Behavior-changing content now explicitly crosses into Game Component Rule Extension. |
| Risk level | Medium |
| Codex risk | Low for ordinary static data, higher if content has behavior. |
| Network/save/load/replay impact | Medium. Stable keys are required for save/load/replay; behavior-changing content has high impact through B-005A. |
| Recommended next step | update docs |
| Reasoning | This boundary is safe for non-behavioral content when the current JSON path is followed. Arc42/docs should be updated before using them as implementation guidance. |

### Fleet Builder to Runtime Setup Handoff

| Field | Value |
|---|---|
| Boundary name | Fleet Builder to Runtime Setup Handoff |
| Related reality gaps | RG-015, RG-011, RG-013 |
| Current implementation summary | Fleet builder and setup package helpers produce serialized roster/setup payloads, validate fleets, map rosters to runtime `PlayerState`/instances, and pass setup state through lobby/setup into game bootstrap. |
| Intended/documented architecture summary | Fleet/lobby selection should produce setup-ready serialized packages before runtime game state starts. Setup UI remains governed by `docs/setup_flow.md`. |
| Main discrepancy | The handoff is broadly aligned, but upgrade assignments and special-rule activation now need explicit linkage to B-005A after setup handoff. |
| Risk level | Medium |
| Codex risk | Medium: Codex may add roster fields that do not become runtime serialized active state or rule sources. |
| Network/save/load/replay impact | Medium to high. Initial runtime state, network lobby start, and save/replay baseline depend on deterministic handoff. |
| Recommended next step | create context pack first |
| Reasoning | The next useful step is a compact inventory of package fields, roster fields, runtime mapping, and validation tests before changing contracts. |

### EventBus Integration Boundary

| Field | Value |
|---|---|
| Boundary name | EventBus Integration Boundary |
| Related reality gaps | RG-002, RG-007 |
| Current implementation summary | `EventBus` is a runtime signal backbone with distributed emitters/listeners across autoloads, scenes, UI, audio, debug, replay, and network handlers. It does not own durable state. |
| Intended/documented architecture summary | Some docs describe EventBus as the exclusive inter-system communication path. Current implementation also uses direct `GameManager` wrappers, submitters, and projection paths. |
| Main discrepancy | EventBus exclusivity is not true in current code, but EventBus remains a major integration mechanism. |
| Risk level | Medium |
| Codex risk | Medium: Codex may overuse signals for command-like request/response flows or bypass signals where existing subscribers expect them. |
| Network/save/load/replay impact | Medium. Signals are not serialized, but side effects must mirror command results consistently. |
| Recommended next step | create contract |
| Reasoning | A small communication-boundary contract can clarify when to use EventBus, direct wrappers, command submitters, and projection without forcing refactoring. |

### Documentation Authority Boundary

| Field | Value |
|---|---|
| Boundary name | Documentation Authority Boundary |
| Related reality gaps | RG-008, RG-009, RG-010, RG-011, RG-012, RG-016 |
| Current implementation summary | Current architecture knowledge is split across current-state maps, gap register, boundary candidates, Arc42, flow/setup docs, phase plans, Copilot instructions, and skills. Some docs are current contracts; others are historical or stale. |
| Intended/documented architecture summary | Arc42 and skills describe intended architecture; setup/game flow docs contain specific contracts/reference; phase plans contain historical migration context. |
| Main discrepancy | Authority level is not consistently marked, so Codex can follow stale Arc42 paths, counts, or behavior descriptions. |
| Risk level | Medium |
| Codex risk | High: Codex may treat stale docs as current implementation truth. |
| Network/save/load/replay impact | Indirect but important; stale docs can misdirect high-risk changes. |
| Recommended next step | update docs |
| Reasoning | Marking authority/status is lower risk than code changes and will reduce future agent error. |

## Top 5 Architecture Decisions Owner Must Make

1. Is the accepted long-term architecture a strict layered model, the current autoload/scene/command hybrid, or an explicit hybrid with named exceptions?
2. Outside the current-attack scope governed by `ADR-001`, which direct `InteractionFlow` mutation paths are accepted, temporary, or prohibited?
3. Should future special-rule work use `RuleRegistry` as the only extension path, or should resolver/command-owned rule surfaces remain first-class?
4. What is the accepted responsibility boundary for `GameManager`: lifecycle facade or broad application orchestration hub?
5. What is the authoritative expansion path for upgrades, objectives, obstacles, tokens, and special ship/squadron rules from static component data to active serialized rule state?

## Top 5 Areas Where Codex Must Be Constrained

1. Follow `ADR-001` for current-attack authority and do not add new direct `GameState.interaction_flow` writers outside established non-attack flow surfaces.
2. Do not add rule predicates only in UI/presentation code; commands/resolvers/projection payloads must own legality.
3. Do not add new `GameManager` responsibility categories without owner direction or an existing matching wrapper family.
4. Do not treat static component JSON as sufficient for behavior-changing content; special rules need active state, validation, projection, and tests.
5. Do not follow stale Arc42 paths, component names, command counts, or runtime descriptions without checking current code and current-state docs.

## Top 5 Areas Safe For Feature Work

1. Static non-behavioral content additions that use existing `Resources/Game_Components/` JSON and existing loader patterns.
2. Fleet builder UI/library changes that stay within existing roster fields and validation paths.
3. Tooltip/audio/visual presentation changes that do not change command, rule, flow, network, save/load, or replay behavior.
4. Setup UI changes only when the affected `docs/setup_flow.md` step is already accepted and the change stays within that step.
5. Command or resolver bug fixes that preserve existing command surface, include focused tests, and do not introduce new flow owners or rule-extension patterns.

## Top 5 Areas Not To Touch Without A Contract

1. Game Component Rule Extension for upgrades, objectives, obstacles, tokens, and special ship/squadron rules.
2. Interaction Flow and UI Projection ownership outside the current-attack scope already governed by `ADR-001`.
3. Rule and Validation Surfaces when adding or migrating rules across hooks, commands, resolvers, payloads, and UI affordances.
4. GameManager Orchestration responsibility boundaries and new command-wrapper families.
5. EventBus vs direct-call communication rules for cross-system workflows.
