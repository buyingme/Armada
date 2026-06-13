# Current-State Architecture Maps

> Scope: repository structure, Arc42 documentation, other documentation,
> Copilot instructions, and existing project skills as observed in the current
> workspace.
>
> This document records the current state only. It intentionally does not
> propose improvements, refactors, or target architecture changes.
>
> Important current-state distinction: project guidance describes
> `RuleRegistry` as the production rule-extension architecture, but the
> implemented rules system is currently hybrid. Some rules are implemented as
> static `RuleRegistry` hooks, while substantial core rules still live in
> resolvers, command validation/execution, setup/fleet validators, and
> rule-relevant scene orchestration.
>
> Important code-derived distinction: the implementation is not a purely
> layered core-first architecture. `GameManager` is a large orchestration hub,
> `EventBus` is a first-class integration backbone, and several scene
> controllers own real runtime workflow state before publishing durable
> command or `InteractionFlow` mutations.

## 1. Domain Map

### 1.1 Primary Game Domains

| Domain | Current responsibility | Main source locations | Main state/data |
|---|---|---|---|
| Match lifecycle | Starts games, bootstraps scenarios/setup packages, advances rounds and phases, ends games, derives active player | `src/autoload/game_manager.gd`, `src/core/commands/start_round_command.gd`, `src/core/commands/advance_phase_command.gd`, `src/core/state/scoring_calculator.gd` | `GameState.current_round`, `GameState.current_phase`, `GameState.initiative_player`, `GameManager.active_player`, command history |
| Player and fleet runtime state | Represents each player's fleet, score, ships, squadrons, commands, damage, and deployment/runtime identifiers | `src/core/state/player_state.gd`, `src/core/state/ship_instance.gd`, `src/core/state/squadron_instance.gd`, `src/core/state/command_dial_stack.gd`, `src/core/state/command_token_manager.gd` | `PlayerState`, `ShipInstance`, `SquadronInstance`, `CommandDialStack`, `CommandTokenManager` |
| Setup flow | Match type, fleet selection handoff, initiative/objective setup draft, obstacle placement, deployment, review, setup-to-round transition | `docs/setup_flow.md`, `src/core/setup/`, `src/scenes/setup_flow/`, `src/scenes/game_board/setup_placement_controller.gd`, setup commands | `FleetSetupPackage`, setup state in `GameState.objectives`, setup `InteractionFlow`, normalized placement payloads |
| Fleet builder | Local roster creation, validation, catalog browsing, saved fleet library, setup-ready roster payloads | `src/core/fleet/`, `src/scenes/fleet_builder/`, `src/ui/fleet_builder/`, `saves/fleets/` | `FleetRoster`, `FleetShipEntry`, `FleetSquadronEntry`, `FleetUpgradeAssignment`, `FleetObjectiveSelection`, saved roster JSON |
| Command phase | Per-player command dial assignment, both-player submission gate, command dial stacks | `src/autoload/game_manager.gd`, `src/scenes/game_board/command_phase_controller.gd`, `src/core/commands/assign_dial_command.gd`, command dial UI | `ShipInstance.command_dial_stack`, `GameManager._command_submitted`, `GameManager._command_assigning_player` |
| Ship activation | Ship selection, dial reveal/spend, squadron command, repair, attack, maneuver, overlap/displacement, activation end | `docs/game_flow.md`, `src/scenes/game_board/ship_activation_controller.gd`, `src/ui/combat/activation_modal.gd`, `src/core/state/ship_activation_state.gd`, `src/core/state/activation_context.gd`, activation commands | `GameState.interaction_flow`, `ActivationContext`, `ShipActivationState`, selected `ShipInstance` |
| Attack and defense | Target declaration, dice roll/modify, accuracy spending, defense token choice, redirect/evade choices, damage resolution, counter/critical choice | `src/core/combat/`, `src/scenes/game_board/attack_executor.gd`, `src/scenes/game_board/attack_panel_controller.gd`, `src/scenes/game_board/target_selector.gd`, combat UI, attack/defense commands | `AttackState`, attack payloads in `InteractionFlow.payload`, `DicePool`, `CombatParticipants`, unit damage/token fields |
| Movement and geometry | Maneuver tool computation, yaw/speed, overlap detection, squadron movement, range, line of sight, hull-zone geometry | `src/core/movement/`, `src/core/geometry/`, `src/scenes/tools/`, movement/range controllers | Normalized unit positions, `ManeuverToolState`, `ShipBase`, `SquadronBase` |
| Squadrons | Squadron phase activation, ship-command squadron activation, movement, engagement, squadron attacks, keyword hooks | `src/scenes/game_board/squadron_phase_controller.gd`, `src/ui/combat/squadron_activation_modal.gd`, `src/core/combat/engagement_resolver.gd`, `src/core/combat/squadron_command_resolver.gd`, `src/core/effects/rules/squadron_keywords/` | `SquadronInstance`, `GameManager._activating_squadron`, `GameManager._squadrons_activated_this_turn`, squadron keyword data |
| Damage and repair | Damage deck, faceup/facedown damage, immediate effects, persistent effect damage, repair actions | `src/core/damage/`, `src/core/effects/rules/damage_cards/ship/`, `src/ui/commands/repair_panel.gd`, damage/repair commands | `DamageDeck`, `DamageCard`, ship damage arrays, immediate-effect payloads, repair command payloads |
| Rule hook catalogue | Static hook registration for implemented damage-card and squadron-keyword rules; hook lookup by FlowSpec step and target/command | `src/core/effects/`, `src/core/effects/rules/`, `src/autoload/rule_bootstrap.gd`, `.github/skills/rule-integration/SKILL.md` | `RuleRegistry` static hook arrays, `FlowHook`, `EffectContext`; active state read from serialized entities |
| Runtime/core rule logic | Core Armada rules that are currently implemented directly in resolvers/helpers rather than exclusively as `RuleRegistry` files | `src/core/combat/`, `src/core/damage/`, `src/core/movement/`, `src/core/setup/`, `src/core/fleet/` | Resolver-local derived values, command payloads, `GameState`, unit state, static component data |
| Command rule surface | Flow/phase gating, command-specific validation, and authoritative mutation for many game actions | `src/core/commands/`, `src/autoload/command_processor.gd`, `src/core/commands/command_applicability.gd`, `docs/game_flow.md` | Serialized command payloads, validation errors, command results, command history |
| Rule-relevant presentation flow | Local previews, selectable options, modal state, payload assembly, and UI affordances for rule-bound choices | `src/scenes/game_board/`, `src/ui/combat/`, `src/ui/commands/`, `src/core/network/ui_projector.gd` | Scene-local preview/controller state, projected `UIIntent`, `InteractionFlow.payload` |
| Game orchestration hub | Owns game bootstrap/load handoff, current state reference, active-player tracking, round/phase progression, activation trackers, command submitter strategy, command wrapper methods, network-result side effects, and many EventBus emissions | `src/autoload/game_manager.gd` | `GameManager.current_game_state`, `_submitter`, `active_player`, `_activating_ship`, `_activating_squadron`, `_command_submitted`, `_command_assigning_player`, pending setup/scenario fields |
| Signal integration backbone | Decouples game flow, UI refresh, audio, command-dial/token updates, activation lifecycle, combat events, destruction, network dice results, and handoff/selection events | `src/autoload/event_bus.gd`, emitters/listeners across `src/autoload/`, `src/scenes/`, and `src/ui/` | Godot signals; no durable game state, but many runtime reactions depend on these emissions |
| Networking and lobby | ENet host/client connection, protocol state, lobby state, game config broadcast, command-result mirroring, filtered snapshots | `src/autoload/network_manager.gd`, `src/autoload/lobby_manager.gd`, `src/core/network/`, `src/scenes/lobby/lobby_room.gd` | `NetworkManager.connection_state`, `NetworkManager.role`, peers, pending game config, `LobbyState`, `CommandSyncGate` |
| Save/load and replay | Signed save files, checkpoints, safe save points, replay command history, baseline traces | `src/autoload/save_game_manager.gd`, `src/core/state/save_game_metadata.gd`, `src/core/commands/game_replay.gd`, `src/autoload/replay_driver.gd`, `src/autoload/baseline_trace.gd`, `src/utils/integrity_signer.gd` | `GameState.serialize()`, `SaveGameMetadata`, HMAC signature, `CommandProcessor` history |
| Presentation and tools | Main menu, game board, tokens, modals, HUD, overlays, debug UI, audio controls, tooltip UI | `src/scenes/`, `src/ui/`, `src/autoload/tooltip_manager.gd`, `src/autoload/sfx_manager.gd`, `src/autoload/music_manager.gd` | Scene-local Node state, transient previews, `UIProjector.UIIntent`, tooltip registrations |
| Static content and reference data | Ships, squadrons, upgrades, objectives, obstacles, dice, maps, rules reference, sound, scale config, scenarios | `Resources/Game_Components/`, `Resources/SWM-RULES-REFERENCE-GUIDE-150/`, `Resources/SWM01-ARMADA-LEARN-TO-PLAY/`, `Resources/Sound/`, `src/models/`, `src/utils/asset_loader.gd` | JSON component data, images/audio, `ShipData`, `SquadronData`, `UpgradeData`, `ObjectiveData`, `ObstacleData`, `RuleReferenceData` |

### 1.2 Flow Domains From `docs/game_flow.md` and `FlowSpec`

| Flow | Current steps |
|---|---|
| `NONE` | `NONE` |
| `COMMAND_PHASE` | `SELECT_DIALS`, `WAIT_FOR_OPPONENT_DIALS` |
| `SHIP_ACTIVATION` | `WAIT_FOR_SHIP_SELECT`, `ACTIVATION_MODAL_OPEN`, `REVEAL_DIAL`, `SPEND_DIAL`, `SQUADRON_STEP`, `REPAIR_STEP`, `ATTACK_STEP`, `MANEUVER_STEP`, `ACTIVATION_DONE` |
| `SQUADRON_ACTIVATION` | `WAIT_FOR_SQUAD_SELECT`, `ACTION_CHOICE`, `SQUAD_MOVE`, `SQUAD_ATTACK` |
| `ATTACK` | `ATTACK_DECLARE`, `ATTACK_ROLL`, `ATTACK_MODIFY`, `ATTACK_DEFENSE_TOKENS`, `ATTACK_RESOLVE_DAMAGE`, `ATTACK_COUNTER_CHOICE`, `ATTACK_CRITICAL_CHOICE` |
| `SQUADRON_DISPLACEMENT` | `DISPLACEMENT_PLACE` |
| `SETUP` | `SETUP_OBSTACLE_PLACEMENT`, `SETUP_SHIP_DEPLOYMENT`, `SETUP_SQUADRON_DEPLOYMENT`, `SETUP_REVIEW` |
| `STATUS_CLEANUP` | `STATUS_CLEANUP_STEP` |
| `GAME_OVER` | `GAME_OVER_STEP` |

### 1.3 Current Rule Implementation Domains

| Rule surface | Current implementation | Examples observed |
|---|---|---|
| Static hook rules | `RuleBootstrap` preloads rule scripts; scripts register `FlowHook` definitions in `RuleRegistry`; callers execute hooks through `RuleSurface` or direct `RuleRegistry` lookup | Ship damage-card rules under `src/core/effects/rules/damage_cards/ship/`; squadron keyword rules under `src/core/effects/rules/squadron_keywords/` |
| Combat resolvers | Core combat rules are implemented in resolver methods, with optional `RuleRegistry` blockers/modifiers where migrated | `AttackTargetResolver`, `AttackDiceResolver`, `DefenseTokenResolver`, `EngagementResolver`, `SquadronCommandResolver`, `TargetingListBuilder` |
| Damage/repair resolvers | Damage assignment, immediate effects, persistent damage, repair legality, and engineering point calculations live in damage helpers and commands | `DamageDealer`, `ImmediateEffectResolver`, `ResolveImmediateEffectCommand`, `RepairResolver`, `ResolveDamageCommand`, `PersistentEffectDamageCommand` |
| Movement/setup/fleet validators | Geometry, placement, overlap, deployment, setup obstacle, and fleet-construction legality are direct validator/resolver code | `OverlapResolver`, `ManeuverRuleResolver`, `SetupObstacleValidator`, `SetupDeploymentValidator`, `FleetValidator` |
| Command validators | Commands own payload legality and final submission safety for many actions, sometimes calling resolvers and sometimes directly checking rule conditions | `CommitDefenseCommand`, `SpendDefenseTokenCommand`, `ResolveImmediateEffectCommand`, `CommitSetupObstacleCommand`, `CommitSetupDeploymentCommand`, `MoveSquadronCommand`, `ExecuteManeuverCommand` |
| Scene/UI rule previews | Scene controllers and panels own transient previews and selected option state; durable choices are committed by commands or published through `InteractionFlow.payload` | `AttackExecutor`, `AttackPanelController`, `TargetSelector`, `SquadronPhaseController`, `SetupPlacementController`, `AttackSimPanel`, `RepairPanel`, `SquadronActivationModal` |
| Scene-owned attack workflow | `AttackExecutor` and collaborators own attack runtime sequencing, target lock handoff, attack payload patching, local FSM transitions, defense-token substeps, immediate-effect prompts, and command submissions | `AttackExecutor`, `AttackFlowFSM`, `AttackFlowExecutor`, `AttackState`, `TargetSelector`, `AttackPanelMirror`, `AttackSimPanel` |

### 1.4 Implemented RuleRegistry Catalogue

`src/autoload/rule_bootstrap.gd` currently registers these static rule files:

| Group | Registered rules |
|---|---|
| Ship damage cards | `blinded_gunners`, `capacitor_failure`, `compartment_fire`, `coolant_discharge`, `crew_panic`, `damaged_controls`, `damaged_munitions`, `depowered_armament`, `disengaged_fire_control`, `faulty_countermeasures`, `life_support_failure`, `point_defense_failure`, `power_failure`, `ruptured_engine`, `targeter_disruption`, `thrust_control_malfunction`, `thruster_fissure` |
| Squadron keywords | `heavy`, `escort`, `counter`, `swarm`, `bomber` |

The repository contains additional rule-file grouping guidance under
`src/core/effects/rules/README.md`, including directories for core rules,
ship keywords, upgrades, objectives, obstacles, and tokens. Those categories
are documented as organization targets, but they are not represented by
registered production rule scripts in the current bootstrap list.

### 1.5 Code-Derived Architecture Shape

| Axis | What the code actually implements |
|---|---|
| Primary composition model | Godot scenes/controllers are composed by `GameBoard`; global services are composed by `project.godot` autoloads |
| Mutation model | Most durable game mutations are serializable `GameCommand` executions routed through `CommandProcessor`, usually via `GameManager` wrapper methods |
| Orchestration model | `GameManager` owns lifecycle, active-player/turn state, phase advancement, activation tracking, submitter strategy, and many post-command side effects |
| Flow/UI authority model | `GameState.interaction_flow` plus `FlowSpec` and `UIProjector` drive projected modal authority, while scene controllers still own transient workflow state |
| Rule model | Hybrid: static `RuleRegistry` hooks plus resolver-owned rules plus command-owned validation plus scene-owned previews and payload assembly |
| Integration model | `EventBus` signals connect game flow, UI panels, audio, command-dial/token refresh, activation handoff, destruction, and network result handling |
| Network model | Host/server executes authoritative serialized commands; clients mirror commands/results and rebuild UI from state/projection plus remote side-effect handling |

## 2. System Map

### 2.1 Repository Topology

| Area | Current contents |
|---|---|
| `src/autoload/` | Godot singleton services registered in `project.godot`: game lifecycle, command processing, constants, play/debug/logging modes, scale, tooltip/audio managers, save/replay/baseline trace, networking/lobby/chat/server entry, rule bootstrap |
| `src/core/` | Scene-tree-independent domain code grouped by `combat`, `commands`, `damage`, `effects`, `fleet`, `geometry`, `movement`, `network`, `setup`, and `state` |
| `src/models/` | Godot `Resource` and `RefCounted` data models for ship/squadron/upgrade/objective/obstacle/rule-reference/scenario placement data |
| `src/scenes/` | Main menu, setup flow, lobby, game board composition root/controllers, token scenes, tool scenes, fleet builder scene |
| `src/ui/` | Reusable panels, modals, HUD widgets, save dialogs, setup placement modal, ship/card widgets, fleet-library widgets |
| `src/utils/` | Asset loading, JSON canonicalization, HMAC signing, logging, path configuration, scenario saving, UI style helpers, save-file store |
| `tests/` | GUT tests: unit, integration, fixtures, baseline traces, fleet fixtures, scene/UI/util tests |
| `Resources/` | Game data/assets and reference material: component JSON/images, maps, sound, rules reference, learn-to-play materials |
| `docs/arc42/` | Arc42 documentation sections 00-12 |
| `docs/` | Flow docs, setup contract, implementation/refactoring plans, requirements, modal timing/classification docs, release operations, archived old plans |
| `.github/` | Copilot instructions, workflows, contribution/PR/issue templates, discoverable `rule-integration` skill |
| `.skills/` | Project guidance documents for style, architecture, testing, file organization, UI styling, refactoring, serialization/commands, audio |
| `addons/gut/` | GUT testing addon |
| `saves/`, `replays/`, `logs/`, `build/`, `game_resources/` | Local runtime/generated/project support directories present in the workspace |

### 2.2 Runtime System Blocks

| Block | Current role | Key classes/services |
|---|---|---|
| Presentation layer | Builds scenes, captures input, displays tokens/modals/HUD, renders projection results, owns transient preview state and some rule-relevant option assembly | `GameBoard`, `MainMenu`, `SetupFlowScene`, `FleetBuilderScene`, `LobbyRoom`, `ShipToken`, `SquadronToken`, `AttackExecutor`, `AttackPanelController`, `TargetSelector`, UI panels |
| Application/autoload layer | Owns process-wide orchestration and service state; contains several architectural hubs rather than only thin services | `GameManager`, `CommandProcessor`, `NetworkManager`, `LobbyManager`, `SaveGameManager`, `EventBus`, `RuleBootstrap`, `ReplayDriver`, `BaselineTrace`, `TooltipManager`, `SfxManager`, `MusicManager` |
| `GameManager` orchestration hub | Holds the active `GameState`, wraps many command submissions, tracks active player/activations/command phase submission, starts rounds/phases, handles setup/bootstrap/load handoff, emits EventBus updates, and processes remote command side effects | `GameManager`, `CommandSubmitter` implementations, phase/activation command classes |
| `CommandProcessor` command spine | Validates applicability, runs registered rule validators, calls command validation/execution, records command history, emits command results, and queues/drains observer follow-up commands | `CommandProcessor`, `GameCommand`, `CommandApplicability`, `RuleRegistry` validators/observers |
| Event signal backbone | Provides cross-system notifications for lifecycle, phase, activation, command dials/tokens, movement, damage, destruction, combat, selection, handoff, network dice, and UI refresh | `EventBus` plus listeners in autoloads, `GameBoard` controllers, UI panels, audio managers |
| Domain/core layer | Owns durable game state, command classes, command applicability, validators, combat/movement/setup/fleet helpers, geometry, projection/filtering, and the static rule hook catalogue | `GameState`, `GameCommand` subclasses, `FlowSpec`, `CommandApplicability`, `UIProjector`, `StateFilter`, `RuleRegistry`, combat/movement/setup/fleet/damage classes |
| Scene-owned workflow layer | Owns several multi-step runtime workflows that are not fully reduced to core commands, especially attack execution and setup/placement previews | `AttackExecutor`, `AttackFlowFSM`, `TargetSelector`, `ShipActivationController`, `SquadronPhaseController`, `SetupPlacementController`, `DisplacementController` |
| Static rule hook subsystem | Stores static hook definitions and executes registered callbacks when callers opt into a known rule surface | `RuleBootstrap`, `RuleRegistry`, `RuleSurface`, `FlowHook`, `EffectContext`, rule files under `src/core/effects/rules/` |
| Runtime rule resolver subsystem | Implements many current game rules directly in core helper classes and command validation/execution paths | Combat resolvers, damage resolvers, setup validators, fleet validator, movement resolvers, command classes |
| Data/model layer | Owns static data resource shapes and catalog parsing targets | `ShipData`, `SquadronData`, `UpgradeData`, `ObjectiveData`, `ObstacleData`, `RuleReferenceData`, `TokenPlacement` |
| Infrastructure/files | Reads/writes resources, saves, replays, logs, signing keys, settings | `AssetLoader`, `SaveFileStore`, `IntegritySigner`, `GameReplay`, `GameLogger`, `PathConfig` |
| External engine/runtime | Provides scene tree, rendering, input, audio, filesystem, ENet networking, Godot Resource loading, GUT tests | Godot 4.5+, GDScript, ENet, GUT |

### 2.3 Autoload Registry From `project.godot`

`project.godot` registers these singleton services:

`GameManager`, `EventBus`, `Constants`, `GameScale`, `DebugMode`, `PlayMode`,
`LoggingMode`, `BaselineTrace`, `TooltipManager`, `SfxManager`, `MusicManager`,
`SaveGameManager`, `RuleBootstrap`, `CommandProcessor`, `PlayerProfile`,
`NetworkManager`, `LobbyManager`, `ChatManager`, `ServerMain`, and
`ReplayDriver`.

### 2.4 Documentation and Guidance System

| Source | Current role |
|---|---|
| `docs/arc42/00_overview.md` | States Arc42 structure and reading order |
| `docs/arc42/03_context_and_scope.md` | Defines business/technical context: two players, Godot engine, rules engine, game data, saves, desktop OS, network |
| `docs/arc42/04_solution_strategy.md` | Records layered architecture, command pattern, interaction flow as domain state, UI projection, resource pattern |
| `docs/arc42/05_building_block_view.md` | Lists intended/implemented building blocks; some listed file paths reflect older locations while class names match current modules |
| `docs/arc42/06_runtime_view.md` | Describes round, ship activation, attack, movement, squadron phase, and rule-hook runtime flows |
| `docs/arc42/08_crosscutting_concepts.md` | Documents EventBus, data-driven content, logging, testing, serialization, replay gates, setup UI contract, tooltip system, and `RuleRegistry` hook pipeline |
| `docs/arc42/09_architectural_decisions.md` | Records ADRs: Godot/GDScript, EventBus, core scene-tree separation, GUT, resources, 2D rendering, network architecture, initial faction scope, tooltip system, modal layout, command pattern, setup contract |
| `docs/game_flow.md` | Human-readable reference for `FlowSpec`, command applicability, flow ownership, command scopes, rule/runtime ownership |
| `docs/setup_flow.md` | Accepted setup UI contract and mandatory gate for setup presentation work |
| `.github/copilot-instructions.md` | System-level Copilot rules: mandatory reading list, code constraints, rule registry, command/serialization guardrails, verification gates |
| `.skills/*.md` | Project guidance files loaded by AI agents for code style, architecture, testing, file layout, UI, refactoring, serialization/commands, audio |
| `.github/skills/rule-integration/SKILL.md` | Workspace skill for adding/reviewing/debugging rules, rule hooks, command surfaces, ownership, UI affordances, and tests |

### 2.5 Current Rule System Blocks

| Block | Current responsibility | Current implementation scope |
|---|---|---|
| `RuleBootstrap` | Clears and repopulates the static hook catalogue at startup/test setup | Preloads the 17 ship damage-card scripts and 5 squadron-keyword scripts listed in section 1.4 |
| `RuleRegistry` | Stores static validators, modifiers, observers, blockers, and enablers keyed by FlowSpec surfaces | Static runtime-only catalogue; not serialized; only rules registered by bootstrap are present |
| `RuleSurface` | Names common hook targets and runs matching modifier/blocker/observer callbacks | Target names include dice pool, attack target, attack damage, accuracy spend, critical effect, defense token spend, repair shield, engineering value, token gain/readying, command dial reveal, squadron movement, maneuver yaw, post-maneuver, speed change, and attack modifier affordance |
| Core resolvers | Implement non-hooked and partially-hooked rules | Defense token, attack target, attack dice, damage, repair, engagement, squadron command, overlap, setup placement, deployment, fleet validation |
| Commands | Gate by phase/flow and validate/mutate payloads | Command-specific rules remain authoritative for many submissions and network/replay safety |
| UI/projectors/controllers | Display and assemble choices from projected/durable payloads plus scene-local preview state | UI panels do not own durable state, but some rule-relevant preview and option-building code remains in scene/UI classes |
| `AttackExecutor` / attack FSM | Runs the attack workflow in scene code, using core helpers for calculations while retaining sequencing, payload patching, immediate-choice prompts, defense substeps, and command submission | `AttackExecutor` owns `AttackState`, uses `AttackFlowFSM` to write `GameState.interaction_flow`, and publishes snapshots through `PublishAttackFlowCommand` in network mode |

## 3. Dependency Map

### 3.1 Layer Direction Recorded by Project Guidance

The documented dependency direction is:

```text
UI/Scenes -> Autoloads -> Core Logic -> Models/Data
```

Additional observed relationships:

```text
UI/Scenes -> Core helpers and models for display/projection/validation
UI/Scenes -> GameManager command wrapper methods and EventBus signals
Autoloads -> Core commands/state/network/setup/fleet/effects
GameManager -> CommandSubmitter -> CommandProcessor -> GameCommand
Core commands -> GameState, domain helpers, and selected rule resolvers
Core resolvers -> GameState/unit state, geometry, static data, and optional RuleSurface calls
Core network projector/filter -> GameState/InteractionFlow/FlowSpec
Core setup/fleet -> AssetLoader/static component data
EventBus signals -> listeners across autoloads/scenes/UI/audio
Models -> Constants and parsed JSON fields
Utils -> Godot filesystem/resource APIs and model constructors
Tests -> all layers under test
```

### 3.2 Main Runtime Dependency Paths

| Path | Current dependency flow |
|---|---|
| User input to mutation | Scene/UI controller creates or requests a command -> `GameManager` active `CommandSubmitter` -> `CommandProcessor.submit()` -> `CommandApplicability` and any matching `RuleRegistry` validators -> concrete command `validate()` -> command-specific resolver/helper calls where used -> command `execute(GameState)` -> history/signals/follow-ups |
| Mutation to UI | `CommandProcessor.command_executed` -> `ModalRouter` / controllers -> `UIProjector.project(GameState, local_player)` -> UI panels/HUD/overlays render `UIIntent` and payload |
| GameManager orchestration path | EventBus or scene call -> `GameManager` lifecycle/phase/activation method -> command submission through `_submitter` where durable state changes are needed -> EventBus emissions and local runtime trackers update around the command result |
| EventBus reaction path | Command, scene, or autoload emits EventBus signal -> subscribed autoloads/controllers/UI/audio react -> some listeners submit commands or update local presentation/runtime state |
| Attack workflow path | Activation controller starts attack -> `AttackExecutor`/`TargetSelector` manage target and step sequencing -> core combat/damage resolvers calculate legality/effects -> `AttackFlowFSM` patches `GameState.interaction_flow` locally -> commands persist dice/defense/damage choices -> network mode publishes attack-flow snapshots |
| Rule hook definition to runtime effect | `RuleBootstrap` preloads registered rule scripts -> rule scripts register static hooks in `RuleRegistry` -> `RuleSurface` or direct callers query validators/blockers/modifiers/observers/enablers -> callbacks derive active status from serialized entities |
| Runtime resolver rule path | Commands/scenes call combat, damage, repair, movement, setup, or fleet helpers -> helpers calculate legality/effects from `GameState`, unit instances, geometry/static data, and sometimes `RuleSurface` hooks -> result returns to command or UI payload |
| Immediate damage-card path | Damage dealing identifies immediate effects -> `ImmediateEffectResolver` builds descriptors/options or auto-resolution -> `ResolveImmediateEffectCommand` validates choice payload and mutates ship/player/damage state |
| Setup package to game state | Setup/lobby/fleet builder creates `FleetSetupPackage` -> `FleetSetupBootstrapper` builds `GameState` -> `FleetRosterSetupHelper` maps rosters to `PlayerState`/instances -> `SetupInteractionFlowResolver` sets setup flow -> setup commands commit normalized placements |
| Static asset loading | Domain/UI/fleet/setup code calls `AssetLoader` -> JSON/images under `Resources/Game_Components/` -> model resources or texture assets |
| Save/load | UI save dialogs -> `SaveGameManager` -> `GameState.serialize()` / `GameState.deserialize()` -> `SaveGameMetadata` -> `IntegritySigner` -> filesystem via `SaveFileStore` |
| Replay/baseline | `CommandProcessor` history -> `GameReplay` -> `ReplayDriver` replays commands -> `BaselineTrace` records flow/command/state-hash diagnostics |
| Network command path | Client command submitter sends serialized command -> host/server `CommandProcessor` executes -> host broadcasts command/result/state-related data -> client mirror applies authoritative command/result -> `StateFilter` removes hidden data from snapshots where used |
| Lobby setup path | `MainMenu`/`LobbyRoom` -> `NetworkManager` host/connect -> `LobbyManager.current_lobby` / `LobbyState` -> setup draft/fleet roster submission -> game config/setup package broadcast -> `GameManager.bootstrap_game()` |
| Tooltip path | UI consumers register with `TooltipManager` -> `TooltipManager` owns shared `TooltipPanel` -> `TooltipLayout` computes viewport-safe placement |

### 3.3 Command and Flow Dependencies

| Component | Depends on | Used by |
|---|---|---|
| `GameCommand` subclasses | `GameState`, `Constants`, command payloads, selected domain helpers/resolvers | `CommandProcessor`, submitters, replay/network deserialization |
| `CommandProcessor` | `GameManager.current_game_state`, `CommandApplicability`, `RuleRegistry`, `GameCommand` registry | `GameManager`, submitters, UI routers, replay |
| `GameManager` | `GameState`, `CommandSubmitter`, command classes, `EventBus`, `NetworkManager`, setup package helpers, scoring | Scenes/controllers, UI panels through wrapper methods, network/lobby/save/replay paths |
| `EventBus` | Godot signal system and typed signal declarations | Autoloads, scene controllers, UI panels, audio managers, debug/replay/network handlers |
| `CommandApplicability` | `FlowSpec`, `Constants.CommandScope`, phase/flow metadata | `CommandProcessor.preflight()` |
| `FlowSpec` | `Constants.InteractionFlow`, `Constants.InteractionStep`, controller roles, modal kinds | `UIProjector`, commands that construct flows, command applicability tests/tooling |
| `InteractionFlow` | JSON-safe payloads, controller/visibility enums | `GameState`, `UIProjector`, `StateFilter`, commands |
| `UIProjector` | `GameState`, `InteractionFlow`, `FlowSpec`, setup display names, some rule-derived affordance metadata | `ModalRouter`, scene controllers, tests |
| `StateFilter` | serialized `GameState`, command dial/damage deck conventions | `NetworkManager` snapshot/state filtering paths |

### 3.4 Rule Dependency Paths by Surface

| Surface | Current dependencies | Current consumers |
|---|---|---|
| Registered hook validators | `RuleRegistry.validators_for(flow, step, command_type)` and hook callbacks reading active serialized state | `CommandProcessor` preflight and rule-aware command paths |
| Registered hook blockers | `RuleSurface.block_result()` / `is_blocked()` or direct `RuleRegistry.blockers_for()` | Attack target checks, defense token spending, repair eligibility, accuracy/critical checks, UI availability payloads |
| Registered hook modifiers | `RuleSurface.apply_modifiers()` / `apply_modifier_by_rule()` | Dice pool changes, attack damage, engineering value, yaw modification, token readying |
| Registered hook observers/enablers | `RuleSurface.collect_observer_followups()` or direct enabler lookup | Persistent damage follow-ups, command dial reveal affordances, Counter/Swarm and other optional attack affordances |
| Resolver-owned rules | Direct method calls using `GameState`, `ShipInstance`, `SquadronInstance`, geometry helpers, dice, and static data | Attack, defense, damage, repair, setup, fleet, movement, engagement |
| Command-owned rules | `CommandApplicability` plus concrete `validate()` / `execute()` logic | All command submissions, replay, network mirroring |
| Scene-owned previews | Scene/UI controller state plus resolver outputs and projected payloads | Local interaction previews and modal option state before command submission |
| Scene-owned attack workflow | `AttackExecutor` uses `AttackState`, `AttackFlowFSM`, `AttackFlowExecutor`, combat/damage resolvers, `GameManager` command wrappers, and `InteractionFlow.payload` | Attack sequence, attack-panel UI, defender mirror flow, immediate-effect choice handling, Counter/Swarm/CF/defense-token substeps |

### 3.5 Static Content Dependencies

| Consumer | Data source |
|---|---|
| `AssetLoader` | `Resources/Game_Components/ships`, `squadrons`, `upgrades`, `objectives`, `obstacles`, `rules`, `maps`, `scenarios`, `scale`, image folders |
| `GameScale` | `Resources/Game_Components/scale/scale_config.json` |
| Scenario/bootstrap code | `Resources/Game_Components/scenarios/*.json` |
| Fleet catalog/builder | Component JSON plus card/rules/art assets in `Resources/Game_Components/` |
| Rules/card effects | `Resources/SWM-RULES-REFERENCE-GUIDE-150/`, component rules text/JSON, registered rule scripts, active serialized entities, resolver/command implementations |
| Main menu/audio | `Resources/Game_Components/screen_art/`, `Resources/Sound/` |

### 3.6 Test and Tooling Dependencies

| Tooling area | Current dependency |
|---|---|
| GUT tests | `addons/gut/`, `tests/unit`, `tests/integration`, `tests/fixtures` |
| CI | `.github/workflows/tests.yml`, `.github/workflows/server_build.yml` |
| Phase/lint gates | `scripts/lint_phase_k.sh`, `scripts/run_baseline_traces.sh`, `scripts/dump_flow_coverage.gd` |
| Project guidance | `.github/copilot-instructions.md`, `.skills/*.md`, `.github/skills/rule-integration/SKILL.md` |

## 4. State Ownership Map

### 4.1 Authoritative Durable Game State

| State | Owner | Mutated by | Persistence/sync status |
|---|---|---|---|
| Entire live game state | `GameManager.current_game_state` | Installed by `GameManager` start/load/bootstrap methods; fields mutated by `GameCommand.execute()` during gameplay | Serialized by `GameState.serialize()` for saves/network/replay-related snapshots |
| Round/phase/initiative | `GameState` | `StartRoundCommand`, `AdvancePhaseCommand`, status/game lifecycle methods through command path | Serialized in `GameState` |
| Player fleets/scores | `PlayerState` inside `GameState.player_states` | Setup bootstrap and gameplay commands | Serialized in `PlayerState` |
| Ships | `ShipInstance` inside owning `PlayerState` | Commands for dials/tokens/movement/damage/repair/destruction/effects | Serialized by `ShipInstance`; static template resolved via `data_key` |
| Squadrons | `SquadronInstance` inside owning `PlayerState` | Commands for activation/movement/damage/destruction | Serialized by `SquadronInstance`; static template resolved via `data_key` |
| Damage deck | `GameState.damage_deck` | Scenario/setup bootstrap, damage/repair/effect commands | Serialized by `DamageDeck`; `StateFilter` hides draw pile from clients |
| RNG | `GameState.rng` | Game bootstrap and deterministic command execution | Serialized by `GameRng`; `StateFilter` removes from client snapshots |
| Active interaction flow | `GameState.interaction_flow` | Command execution: setup commands, activation/attack/displacement/status/game-over flow commands, attack-flow publishing | Serialized by `InteractionFlow`; projected by `UIProjector`; payload filtered by `StateFilter` |
| Ship target attack counters | `GameState.ship_target_attack_counts` | Attack/dice flow commands | Serialized in `GameState`; used by rule logic such as Coolant Discharge |
| Setup-package state | `GameState.objectives` using setup package keys | `FleetSetupBootstrapper`, setup commands, `SetupInteractionFlowResolver` | Serialized as part of `GameState.objectives` |
| Active rule source state | Serialized entities: faceup damage cards, squadron keyword data, upgrades/objectives/obstacles/tokens where present, command/result metadata | Gameplay commands and setup/bootstrap paths | Serialized through owning state objects; `RuleRegistry` is not serialized |
| Fleet rosters | `FleetRoster` and related classes | Fleet builder core helpers and UI-facing draft helper | Serialized for saved fleets and setup package payloads |
| Save metadata | `SaveGameMetadata` | `SaveGameManager` metadata builder/load path | Serialized in save header |
| Command history | `CommandProcessor._history` | `CommandProcessor._execute_and_record()` | Serialized through `CommandProcessor.serialize_history()` and `GameReplay` |

### 4.2 Process/Service State

| State | Owner | Nature |
|---|---|---|
| GameManager command/orchestration state | `GameManager._submitter`, `active_player`, `_activating_ship`, `_activating_squadron`, `_squadrons_activated_this_turn`, `_command_submitted`, `_command_assigning_player`, `_next_scenario_id`, `_next_setup_package`, `_next_setup_match_type` | Runtime authority/lifecycle state around the durable `GameState`; includes command submitter strategy, activation/command-phase trackers, and pending menu/lobby/setup handoff state |
| Command sequence and observer queue | `CommandProcessor._next_sequence`, `_observer_followups`, replay flags | Runtime command processing state |
| Event subscriptions and signal-driven reactions | `EventBus` signal connections distributed across autoloads, scenes, UI panels, and audio managers | Runtime integration wiring; not serialized; reactions can update local state or submit commands |
| Static rule catalogue | `RuleRegistry`, bootstrapped by `RuleBootstrap` | Runtime-only static definitions; stores registered hook descriptors, not active rule state; not serialized |
| Network connection/session | `NetworkManager.connection_state`, `role`, `peers`, ENet peer, heartbeat state, pending config, sync gate | Runtime transport/session state; not part of `GameState` |
| Lobby state | `LobbyManager.current_lobby` / `LobbyState` | Pre-game network/lobby setup state; serialized for lobby broadcasts |
| Save checkpoint cache/signing key | `SaveGameManager._checkpoints`, `_signing_key`, command count at last save | Runtime/file-backed save service state |
| Player profile | `PlayerProfile` | Local client profile/settings state |
| Play/debug/logging modes | `PlayMode`, `DebugMode`, `LoggingMode` | Runtime mode flags/settings |
| Tooltip/audio managers | `TooltipManager`, `SfxManager`, `MusicManager` | Runtime UI/audio service state |
| Baseline/replay driver state | `BaselineTrace`, `ReplayDriver` | Runtime diagnostics/replay automation state |

### 4.3 Rule State Ownership

| State/decision type | Current owner | Persistence |
|---|---|---|
| Static rule definitions | `RuleRegistry` hook arrays populated by `RuleBootstrap` | Runtime-only; rebuilt from scripts |
| Active damage-card rules | `ShipInstance.faceup_damage` / damage card data; read by rule scripts, resolvers, commands, and projectors | Serialized with ships |
| Active squadron keyword rules | `SquadronInstance` static data / keyword metadata resolved from squadron data | Serialized by squadron instance identity and static data key |
| Core attack/defense/movement legality | Resolver methods and command validators using current `GameState`, unit state, geometry, dice, and rule hooks where present | Derived at runtime; committed effects persist only through command mutations |
| Immediate damage-card choices/effects | `ImmediateEffectResolver` descriptors and `ResolveImmediateEffectCommand` validation/execution | Choices are transient until command execution; resulting state is serialized |
| Rule-derived UI eligibility | `InteractionFlow.payload`, `UIProjector.UIIntent`, and scene/UI local option state | Payload is serialized when stored in `InteractionFlow`; scene-local preview state is not |
| Observer follow-up queue | `CommandProcessor._observer_followups` and `RuleSurface.collect_observer_followups()` consumers | Runtime-only command processing state |

### 4.4 Presentation and Preview State

| State | Owner | Persistence |
|---|---|---|
| Board token nodes and camera | `GameBoard`, `BoardCamera`, token scene instances | Scene runtime; rebuilt from `GameState`/scenario/setup data |
| Modal lifecycle and HUD rendering | `ModalRouter`, `UIPanelManager`, UI panels/controllers | Derived from `UIProjector.UIIntent` and scene state |
| Activation UI context | `ActivationContext`, `ShipActivationController`, activation modal | Runtime controller state; durable steps live in `GameState.interaction_flow` and commands |
| Attack execution workflow | `AttackExecutor`, `AttackFlowFSM`, `AttackFlowExecutor`, `AttackState`, `AttackPanelController`, `TargetSelector`, attack panels | Scene-owned runtime workflow state; writes/patches `GameState.interaction_flow`, submits commands for durable mutations, and publishes snapshots in network mode |
| Setup drag previews | `SetupPlacementController`, `SetupPlacementModal`, setup overlays/tokens | Transient preview state; durable placements committed through setup commands with normalized payloads |
| Squadron move previews | `SquadronPhaseController`, `SquadronMoveOverlay`, `SquadronActivationModal` | Transient preview state; durable position/lifecycle through commands |
| Maneuver/range/targeting tools | `ToolOverlayController`, `ManeuverToolController`, `RangeToolController`, targeting controllers, tool scenes | Transient visual state; durable maneuver through `ExecuteManeuverCommand` |
| Debug selection/overlays | `DebugMode`, `DebugController`, debug UI | Runtime/debug state; scenario export via `ScenarioSaver` when invoked |
| Fleet builder selection/editor view | `FleetBuilderScene`, `FleetLibraryPanel`, presenter/view/action helpers | UI state around persistent `FleetRoster`/fleet-library files |

### 4.5 Static Data Ownership

| Data | Owner/source | Runtime representation |
|---|---|---|
| Ship/squadron/upgrade/objective/obstacle definitions | JSON and assets under `Resources/Game_Components/` | Loaded through `AssetLoader` into model resources or dictionaries |
| Rules reference and card rules text | `Resources/SWM-RULES-REFERENCE-GUIDE-150/`, component rules text/JSON | Used by docs, rule citations, fleet/catalog UI, rule implementations |
| Registered rule scripts | `src/core/effects/rules/` plus `RuleBootstrap.RULE_SCRIPTS` | Loaded as GDScript scripts and registered into `RuleRegistry` |
| Visual/audio assets | `Resources/Game_Components/*`, `Resources/Sound/` | Loaded as Godot textures/audio streams |
| Scale config | `Resources/Game_Components/scale/scale_config.json` | Loaded into `GameScale` |
| Scenario data | `Resources/Game_Components/scenarios/*.json` | Loaded into setup/bootstrap/token placement paths |

### 4.6 Current Ownership Rules Captured by Docs/Skills

| Rule | Current source |
|---|---|
| Core game logic is scene-tree independent and extends `RefCounted` | `.github/copilot-instructions.md`, `.skills/architecture_patterns.md`, Arc42 ADR-003 |
| Cross-system communication uses `EventBus` rather than direct scene references | `.github/copilot-instructions.md`, `.skills/architecture_patterns.md`, Arc42 ADR-002 |
| Mutable game state must serialize/deserialize | `.skills/serialization_and_commands.md`, Arc42 §8.6 |
| `GameState` mutation routes through `GameCommand.execute()` | `.github/copilot-instructions.md`, `.skills/serialization_and_commands.md`, ADR-012 |
| Active UI step is `GameState.interaction_flow` | `.skills/architecture_patterns.md`, `docs/game_flow.md`, `FlowSpec` |
| Presentation renders projected UI intent; mode/authority decisions come from projection | `.skills/architecture_patterns.md`, `src/core/network/ui_projector.gd`, `src/scenes/game_board/modal_router.gd` |
| Static rule definitions live in `RuleRegistry`; active rule status comes from serialized entities | `.github/copilot-instructions.md`, `.github/skills/rule-integration/SKILL.md`, `docs/game_flow.md`, Arc42 §8 |
| Implemented rules currently also live in resolvers, command validators/executors, setup/fleet validators, and scene-local preview/orchestration paths | Observed implementation under `src/core/combat/`, `src/core/damage/`, `src/core/movement/`, `src/core/setup/`, `src/core/fleet/`, `src/core/commands/`, `src/scenes/game_board/`, `src/ui/combat/` |
| The code architecture is autoload-centered and scene-orchestrated in addition to being command-mediated | `project.godot`, `src/autoload/game_manager.gd`, `src/autoload/command_processor.gd`, `src/autoload/event_bus.gd`, `src/scenes/game_board/attack_executor.gd` |
| Setup UI is contract-gated by `docs/setup_flow.md` | `.github/copilot-instructions.md`, `docs/setup_flow.md`, ADR-013 |
| Positions in serialized state and command payloads use normalized coordinates | `.skills/serialization_and_commands.md`, setup/movement command payloads |
