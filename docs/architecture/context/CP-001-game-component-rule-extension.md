# CP-001: Game Component Rule Extension Context Pack

Status: Draft  
Related task: AT-004  
Related boundaries: BC-005A, BC-005, BC-011, BC-012  
Related gaps: RG-005, RG-006, RG-011, RG-013, RG-015

## 1. Purpose

This context pack documents how game component rules work in the current codebase and where behavior-changing content crosses from static data into runtime behavior.

It exists to support later decisions around ADR-003, CON-003, and related test strategies. It is evidence, not a decision. It does not assume the documented architecture is correct, does not assume the current hybrid implementation is wrong, and does not treat RuleRegistry as the only valid rule surface.

The practical question this pack supports is: when a new ship, squadron, upgrade, objective, obstacle, token, damage card, or rules-reference record is added, what currently makes that content visible, serializable, replayable, network-safe, and behavior-changing?

## 2. Current Static Content Pipeline

Static component content lives primarily under `Resources/Game_Components/`. The catalog uses stable lower_snake_case keys. In current loaders and models, `data_key` is the primary stable identifier and normally matches the JSON file stem.

| Folder or file | Current content | Loader or model | Static-only content | Content that may become behavior-changing |
| --- | --- | --- | --- | --- |
| `Resources/Game_Components/ships/` | Ship JSON, card art, token art, source/rules text | `AssetLoader.load_ship_data()`, `ShipData` | Name, faction, costs, hull, shields, command values, speed chart, upgrade slots, token geometry, images | Ship keywords, title groups, special rules, rule metadata |
| `Resources/Game_Components/squadrons/` | Squadron JSON, card art, token art, source/rules text | `AssetLoader.load_squadron_data()`, `SquadronData` | Name, faction, cost, hull, speed, anti-squadron dice, anti-ship dice, defense tokens, images | Keywords, keyword values, ability text, ace-specific behavior |
| `Resources/Game_Components/upgrades/` | Upgrade JSON nested by upgrade type, card art, source/rules text | `AssetLoader.load_upgrade_data()`, `UpgradeData` | Name, type, cost, restrictions, exhaust/modification flags, effect text, images | Upgrade effects, timing, persistent state requirements, command/resolver hooks |
| `Resources/Game_Components/objectives/` | Objective JSON, card art, objective-token art, source/rules text | `AssetLoader.load_objective_data()`, `ObjectiveData` | Name, category, setup text, special-rule text, scoring text, images | Setup effects, scoring rules, objective token behavior, special runtime state |
| `Resources/Game_Components/obstacles/` | Obstacle JSON, token art, shape/setup metadata | `AssetLoader.load_obstacle_data()`, `ObstacleData` | Name, type, dimensions, token image, setup constraints, shape metadata | Obstacle effects, overlap effects, deployment constraints |
| `Resources/Game_Components/rules/` | Static rules-reference JSON | `AssetLoader.load_rule_reference_data()`, `RuleReferenceData` | Display/search records, rule text, summaries, source refs | Links to implemented rule ids; not executable by itself |
| `Resources/Game_Components/damage_cards.json` | Damage card definitions | Damage card/deck loaders and runtime `DamageCard` objects | Card names, effect ids, traits, text | Faceup effects and persistent damage behavior when registered/invoked |
| Token, dice, map, tool, scenario folders | Images and static setup/display assets | `AssetLoader` manifest and path helpers | Presentation assets and static configuration | Some token/map/scenario facts can affect setup or runtime when consumed by code |

Observed JSON/model fields that carry rule-extension intent include `rules_reference_ids`, `rules_integration`, `rule_surfaces`, `runtime_state_requirements`, `implemented_rule_ids`, `implementation_status`, `keywords`, `ability_text`, `effect_text`, `setup_effects`, `special_rule_text`, and `setup_constraints`.

`Resources/Game_Components/card_data_schema.json` defines `rules_integration`, `rule_surface`, and related component record shapes. In current runtime code these fields are parsed into models and surfaced through catalog/search UI, but they are not themselves an execution mechanism. `rules_integration.status`, `implemented_rule_ids`, `pending_rule_surfaces`, `rule_surfaces`, and `runtime_state_requirements` are schema-backed/descriptive metadata unless a command, resolver, RuleRegistry hook, setup flow, or projection path consumes them.

The component catalog README states that catalog facts belong in JSON, while live gameplay behavior belongs in rule/runtime code and needs registration or integration metadata. The rules-reference README states that rules-reference records are display/search metadata and are not executable gameplay logic.

`FleetCatalog` flattens loaded component records into catalog entries for fleet-builder search and filtering. It exposes `rules_integration_status` for ships, squadrons, upgrades, objectives, and obstacles, and `implementation_status` for rules-reference records. It also stores the typed `resource` object on each entry. This makes rule-extension metadata visible to users and tests, but does not make the referenced behavior active.

Current static content can therefore be grouped as:

- Purely static today: art paths, display names, search/source metadata, base costs, printed stats, printed rules text, static rules-reference records, token images.
- Runtime templates today: ship and squadron templates loaded by `data_key` and attached to runtime instances; upgrade/objective/obstacle records used by fleet/setup validation and UI/catalog flows.
- Behavior-changing only when connected to runtime code: damage-card effects, registered squadron keyword rules, command/defense token mechanics, attack/defense/movement resolver logic, setup commands, and any content with callable validation/resolver/command/projection paths.

## 3. Current Runtime Activation Path

Current activation is not a single pipeline. Static content becomes active through several handoffs.

### Fleet Builder

`FleetCatalog` and `AssetLoader` expose ships, squadrons, upgrades, objectives, obstacles, and rules-reference records to the fleet builder. `FleetRoster` stores the selected fleet as JSON-safe data.

Roster entries are builder/setup payloads:

- `FleetShipEntry` stores a ship `data_key` and assigned `FleetUpgradeAssignment` records.
- `FleetSquadronEntry` stores a squadron `data_key`.
- `FleetUpgradeAssignment` stores upgrade `data_key`, slot, slot index, and entry id.
- `FleetObjectiveSelection` stores selected objective keys.

At this point, upgrade assignments and objective selections are serialized roster facts. They are not, by themselves, active runtime rule objects.

### Roster Payload

`FleetRoster.serialize()` produces a JSON-safe roster payload containing ships, squadrons, objectives, map, point format, faction, and player metadata. This payload is used by setup and lobby/network code without requiring local fleet-library files.

Fleet validation uses static catalog data to check references, costs, faction, commander/flagship rules, squadron caps, uniqueness, upgrade slots, restrictions, objectives, and map selection.

### Setup Package

`FleetSetupPackage` embeds both player rosters plus setup metadata: scenario id, point format, map, first player, selected objective, obstacles, deployments, setup state, and package hash inputs.

`FleetSetupPackageBuilder` validates and builds the package. Lobby/setup flows keep the package JSON-safe so hot-seat, network, replay, and bootstrap paths can start from the same payload.

For selected objectives, `FleetSetupPackageBuilder._objective_setup_state()` creates objective-specific setup scaffolding from `ObjectiveData.setup_effects` and `ObjectiveData.runtime_state_requirements`. The generated setup state includes `objective_key`, `category`, `setup_effects`, `setup_steps`, `runtime_state_requirements`, `objective_ships`, `objective_tokens`, `set_aside_units`, and `deployment_overrides`. `objective_tokens` is initialized with `placements`, `assignments`, `removed_tokens`, and `placement_steps`. Effect kinds such as `choose_objective_ship_pair`, `assign_objective_tokens`, `place_objective_tokens`, `place_objective_tokens_alternating`, `set_aside_units`, `deployment_order_override`, and `deployment_zone_override` add more scaffold records.

### GameState, PlayerState, ShipInstance, SquadronInstance

`FleetSetupBootstrapper` converts a match-ready `FleetSetupPackage` into an initialized `GameState`.

`FleetRosterSetupHelper` performs the main roster-to-runtime conversion:

- It loads `ShipData` by ship `data_key`.
- It creates `ShipInstance` objects from `ShipData`.
- It assigns owner, roster entry id, fleet points, deployment, and initial mutable state.
- It loads `SquadronData` by squadron `data_key`.
- It creates `SquadronInstance` objects from `SquadronData`.
- It calculates ship fleet points by loading assigned `UpgradeData`.

The observed `ShipInstance` runtime state contains ship mutable state, damage cards, defense tokens, command dials, command tokens, position, activation state, owner, roster entry id, and static `ship_data` reference. The observed `SquadronInstance` runtime state contains squadron mutable state, defense tokens, position, activation, ownership, roster entry id, and static `squadron_data` reference.

No generic active runtime upgrade-state collection was observed on `ShipInstance`. Upgrade assignment data participates in roster serialization, validation, and fleet-point calculation. Behavior-changing upgrade effects would currently need an explicit runtime/state/command/resolver/projection path if they are intended to affect gameplay.

Selected objective, setup state, obstacle selections, deployment data, map, point format, and package hash are attached to `GameState.objectives` by setup bootstrap. Setup placement and deployment are then represented through setup commands, setup interaction flow payloads, and board state.

`FleetSetupBootstrapper` stores `selected_objective` and the copied setup state under `GameState.objectives`, adding `player_display_names` during bootstrap. Later setup validators and flow resolvers read and mutate this dictionary for deployment progress, remaining ship/squadron keys, current deployment pick, allowed component types, setup completion status, and setup interaction-flow payloads. This is active setup/runtime state, but it is not the same as generalized objective scoring or special-rule execution.

### Save/Load

`GameState.serialize()` writes current phase, initiative, objectives dictionary, player states, damage deck, RNG, interaction flow, and ship-target attack counts.

`PlayerState.deserialize()` rebuilds ships and squadrons using serialized entity data and template lookups by `data_key`. `ShipInstance.deserialize()` and `SquadronInstance.deserialize()` restore mutable state while reconnecting static templates.

Durable component behavior therefore requires either:

- serialized runtime entity state,
- serialized `GameState` state,
- serialized command/history state,
- deterministic static lookup by `data_key`,
- or some combination of these.

RuleRegistry itself is a static hook catalogue and is not serialized.

### Replay

`CommandProcessor.serialize_history()`, `create_replay()`, and `replay_commands()` serialize and replay command dictionaries. Rule behavior is replayable when it is driven by serialized commands plus deterministic runtime state and registered/invoked rule surfaces.

Observed tests cover command history, replay command round trips, rule ordering, damage-card save/load behavior, and some reconnection/projection paths. Coverage is not mapped as an accepted test strategy for all component categories.

### Network

Network/lobby code serializes rosters, setup packages, commands, and game state snapshots. `StateFilter` and `UIProjector` are part of the reconnect/projection path.

Network-safe component behavior currently depends on JSON-safe identifiers and deterministic static data on all peers.

`StateFilter.filter_for_player()` removes server-only or hidden information from serialized snapshots: RNG state, damage-deck draw order, opponent facedown damage card data, hidden opponent command dial commands, and owner-only `InteractionFlow.payload` data for non-controllers. `UIProjector.project()` then derives the local `UIIntent` from the filtered `GameState`. Component rules that add payload fields or durable state therefore affect reconnect and observer behavior whenever those fields are visible, hidden, or required for projection.

Behavior that exists only in local UI state, unregistered scripts, or non-serialized runtime fields is not durable across network, save/load, or replay paths.

## 4. Current Rule Surfaces

Rule behavior is currently distributed across several surfaces.

| Surface | Current responsibility | Examples | Durable logic or presentation logic | Serialization impact | Network/replay impact |
| --- | --- | --- | --- | --- | --- |
| Static JSON/catalog metadata | Defines catalog records, printed text, stable keys, integration metadata, and some setup/restriction facts | `rules_integration`, `rules_reference_ids`, `keywords`, `effect_text`, `setup_effects`, upgrade restrictions | Mostly static metadata; behavior-changing only when consumed by runtime code | Serialized indirectly by stable keys, not by copying full records into game state | Requires matching static catalog on all peers and replay environments |
| `RuleRegistry` | Registers validators, modifiers, blockers, observers, and enablers keyed by flow/step/target/command | Damage-card rules, squadron keyword rules | Durable gameplay hook catalogue when invoked by command/resolver/projection paths | Not serialized; active source state lives on entities or `GameState` | Replay/network depend on deterministic bootstrap and serialized active state |
| `RuleSurface` | Shared constants and runners for rule targets and command targets | Attack damage modifiers, target blockers, defense-token blockers, observer followups | Durable execution helper for registered hooks | No state of its own | Safe only where command/resolver/projection call sites invoke it |
| Resolvers | Apply core rules and some RuleRegistry hooks during combat/movement/repair logic | `AttackDiceResolver`, `DefenseTokenResolver`, `RepairResolver`, `ManeuverRuleResolver`, and squadron/command resolvers | Durable gameplay logic | Depends on serialized state read by resolvers | Replay/network-safe when invoked through commands and deterministic state |
| Command validation/preflight | Checks command applicability, command-specific validation, and registered rule validators | `CommandProcessor.preflight()`, `CommandApplicability`, `PublishAttackFlowCommand` validators | Durable command gate | Commands are serialized in history/replay | Central to replay and network command sync |
| Setup/fleet validators | Validate roster construction and setup-package readiness using static catalog data | `FleetValidator`, `FleetSetupPackageBuilder`, setup validation results | Durable validation for setup/fleet facts; not runtime effect execution | Roster/setup package serialization carries validated facts | Network setup depends on shared validation and package hash inputs |
| `InteractionFlow` payloads | Store active flow, step, actor, prompt, visibility, and flow-specific payload. Payloads are expected to be JSON-safe plain data. `InteractionFlow.visible_to` controls whether payload contents are public or owner-only. `StateFilter` strips owner-only payloads from non-controller snapshots before network delivery or reconnect projection. | Attack payload, setup placement payload, rule-choice payloads | Durable transient interaction state when serialized in `GameState` | Serialized by `GameState.serialize()` | Reconnection and replay depend on payload shape staying stable |
| `UIProjector` | Converts `GameState` and viewer into UI intent, actions, prompts, visible payload, and affordances | Rule affordances for Counter/Swarm, setup UI intents, reconnect projection | Presentation projection plus rule affordance surface; not authoritative by itself | No durable state except projected from serialized state | Network reconnect depends on deterministic projection |
| UI/presentation previews | Render local choices, previews, modals, token/card panels, and some eligibility previews | Setup placement controller, activation modals, maneuver previews, card panels | Presentation/local workflow unless submitting commands | Usually not serialized unless command submitted | Risky when predicates live only here; not replay-authoritative |
| Runtime entity state | Stores the active source facts that rules inspect | Faceup damage cards on ships, squadron keywords via `squadron_data`, command/defense tokens, ship-target attack counts | Durable gameplay state | Serialized on `ShipInstance`, `SquadronInstance`, `GameState`, damage deck | Core input for save/load, replay, reconnect, and network sync |

Observed active RuleRegistry coverage includes ship damage-card rules and squadron keyword rules. Observed non-registry rule logic includes fleet/setup validation, command applicability, resolver-owned attack/defense/token logic, setup placement/deployment logic, and UI projection.

## 5. Component Categories

| Category | Static data status | Runtime state status | Rule implementation status | Command/projection/test needs |
| --- | --- | --- | --- | --- |
| Ships without special rules | Supported through ship JSON, `ShipData`, `AssetLoader`, fleet catalog, roster entries, and bootstrap | Active as `ShipInstance` with mutable hull/shields/speed/position/tokens/dials/damage/activation state | Base ship facts are consumed by setup, activation, movement, attack, defense, and UI paths | Existing path needs catalog/load/bootstrap/save/load coverage; new base facts still need validation when they affect commands or projection |
| Ships with special rules | JSON supports rules metadata and reference ids; card/source text exists for some records | No generic special-ship-rule state beyond `ShipInstance` fields and damage-card state was observed | No accepted generalized ship ability path observed; damage cards are active through separate damage-card rule path | Needs explicit rule surface, active state, command validation, projection, save/load, replay, network, and focused tests for each behavior-changing rule |
| Squadrons without special rules | Supported through squadron JSON, `SquadronData`, catalog, roster entries, and bootstrap | Active as `SquadronInstance` with hull/position/activation/engagement/defense-token state | Base squadron facts are consumed by attack, movement, engagement, and UI paths | Needs load/bootstrap/save/load and command validation coverage when adding new printed base facts |
| Squadrons with keywords/special rules | JSON supports keywords, keyword values, ability text, rules references, and integration metadata | Keyword data is available through `SquadronData` referenced by `SquadronInstance`; unique ability state is not generalized | Five generic squadron keyword rules are registered by `RuleBootstrap`; named or ace-specific abilities may be static only unless implemented elsewhere | Needs hook registration plus call-site coverage, command validation, UI projection, save/load, replay, network, and tests before marking behavior active |
| Upgrades | Upgrade JSON supports type, cost, restrictions, effect text, timing, errata, rule metadata, and runtime-state requirements | Roster assignments serialize in `FleetShipEntry`; bootstrap uses upgrades for fleet points; no generic active runtime upgrade state was observed on `ShipInstance` | Fleet-building restrictions are implemented; gameplay effects are not covered by a generalized active upgrade rule path in observed code | Behavior-changing upgrades need an active state owner, serialization shape, command/resolver/projection call sites, network/replay handling, and tests |
| Objectives | Objective JSON supports category, setup text, special rules, scoring text, setup effects, tokens, and rule metadata | Objective selections live in rosters/setup package and are attached to `GameState.objectives`; setup state also lives there | Objective selection/setup-package flow exists; generalized objective scoring/special runtime behavior was not observed as a complete rule surface | Needs runtime objective state, scoring/update commands, projection, save/load, replay, network, and setup-flow tests before broad objective behavior work |
| Obstacles | Obstacle JSON supports type, token image, setup constraints, and shape metadata | Obstacle selections/placements flow through setup package, `GameState.objectives`, setup commands, and board tokens | Setup placement support exists; generalized obstacle gameplay effects are not established as a complete rule path | Needs shape/effect ownership, command/resolver integration, projection, serialization, replay/network, and tests for behavior-changing obstacle effects |
| Tokens | Token images exist for command/defense tokens; token concepts also appear in ship/squadron static data | Command tokens, command dials, and defense tokens are active on ship/squadron state; some counts/states serialize with entities | Core command/defense-token behavior exists in command managers, resolvers, commands, and UI | New token types or token-changing rules need state serialization, command validation, projection, replay/network, and token UI tests |
| Damage cards | `damage_cards.json` and damage art define card facts; damage cards also have effect ids and text | Damage cards are active as serialized faceup/facedown card state on `ShipInstance`; deck state serializes in `GameState` | Seventeen ship damage-card rule scripts are registered; many inspect faceup damage state and hook commands/resolvers/observers | New damage effects need registered/invoked hooks, command/resolver coverage, save/load, replay/order, network/reconnect, and tests |
| Rules reference records | Static rules-reference JSON supports display/search metadata and implemented-rule-id links | No runtime state | Not executable by itself; can point to implemented rule ids | Needs catalog/UI tests for display; gameplay tests only when an implemented behavior path exists |

Damage-card coverage is split by effect type. `damage_cards.json` currently defines 22 `effect_id` values. `RuleBootstrap` registers 17 ship damage-card rule scripts under `src/core/effects/rules/damage_cards/ship/`. Six immediate effects are handled by `ResolveImmediateEffectCommand`: `structural_damage`, `projector_misaligned`, `life_support_failure`, `injured_crew`, `shield_failure`, and `comm_noise`; `life_support_failure` also has a persistent registered rule. Some static effect ids therefore become active through command-owned immediate resolution rather than one rule script per card, and some may be passive/no-op unless referenced by another path.

## 6. Known Risks

- Static JSON can be mistaken for active gameplay behavior.
- `rules_integration` or `implementation_status` can imply behavior is live even when no rule is registered or invoked.
- RuleRegistry hooks can exist without command/resolver/projection call-site coverage.
- Resolver-owned behavior can be missed by rule documentation or rule-file searches.
- Command predicates or eligibility checks can exist only in UI/presentation code.
- Behavior-changing state can be omitted from `GameState`, `ShipInstance`, `SquadronInstance`, command history, or setup-package serialization.
- Upgrade assignments can be preserved in rosters while not existing as active runtime upgrade state after bootstrap.
- Objective, obstacle, and setup behavior can be split between setup package, setup commands, board scenes, and UI projection.
- Replay and network behavior can diverge if peers or replay environments do not share the same static catalog version.
- Arc42 or older docs can imply `.tres`/Resource-based content where current code uses JSON plus `AssetLoader`.
- Current tests cover many rule and serialization paths, but there is no accepted coverage map for every component category and rule surface.
- Schema-backed rule-extension metadata can be mistaken for runtime enforcement; current schema/model/catalog support proves the metadata is present and loadable, not that behavior is active.

## 7. Codex Guardrails

- Do not add behavior-changing component content as static JSON only.
- Do not add rule predicates only in UI or preview code.
- Do not assume a rule file is active unless it is registered and a command/resolver/projection path invokes the relevant hook.
- Do not assume RuleRegistry is the only valid current rule surface.
- Do not mark `rules_integration.status` or `implementation_status` as integrated without tests that exercise active behavior.
- Treat `rule_surfaces`, `runtime_state_requirements`, and `pending_rule_surfaces` as descriptive evidence unless a runtime caller consumes them.
- For behavior-changing component work, identify affected static data, runtime state, command validation, resolver logic, RuleRegistry hooks, `InteractionFlow` payloads, `UIProjector`, UI presentation, save/load, replay, and network paths.
- For setup-affecting component work, check `docs/setup_flow.md`, setup commands, setup-package serialization, and setup projection.
- Preserve local current patterns while the related ADR/contract is unresolved, unless the roadmap or an accepted decision says otherwise.
- When code and architecture docs conflict in this area and no accepted ADR/contract resolves the conflict, stop before implementation and ask for owner guidance.

## 8. Evidence Map

| Concern | Current evidence | Files/classes | Related RG/BC/AT IDs |
| --- | --- | --- | --- |
| Static catalog location and key policy | Component README describes `Resources/Game_Components/`, stable lower_snake_case keys, and `data_key`/file-stem matching | `Resources/Game_Components/README.md` | RG-011, BC-011, AT-004 |
| Static rules-reference records are not executable | Rules README states rules-reference JSON is for display/search and live effects belong in runtime code | `Resources/Game_Components/rules/README.md`, `RuleReferenceData` | RG-005, RG-006, BC-005A, AT-004 |
| JSON loaders and typed static models | `AssetLoader` loads ships, squadrons, upgrades, objectives, obstacles, and rules-reference JSON into model resources | `AssetLoader`, `ShipData`, `SquadronData`, `UpgradeData`, `ObjectiveData`, `ObstacleData`, `RuleReferenceData` | RG-011, BC-011, AT-004 |
| Fleet-builder roster payload | Rosters serialize selected ships, squadrons, objectives, map, point format, faction, and upgrade assignments | `FleetRoster`, `FleetShipEntry`, `FleetSquadronEntry`, `FleetUpgradeAssignment`, `FleetObjectiveSelection` | RG-015, BC-012, AT-004 |
| Fleet/setup validation uses static catalog | Validator checks catalog references, costs, restrictions, uniqueness, objectives, maps, and upgrade slots | `FleetValidator`, `FleetUpgradeSlotResolver`, `FleetSetupPackageBuilder` | RG-013, RG-015, BC-012, AT-004 |
| Setup package handoff | Setup package embeds rosters and setup metadata; bootstrap converts it to initialized `GameState` | `FleetSetupPackage`, `FleetSetupBootstrapper`, `FleetRosterSetupHelper` | RG-015, BC-012, AT-004 |
| Ship runtime activation | Ship JSON becomes `ShipInstance` via `ShipData`; mutable ship state serializes separately from template data | `ShipInstance`, `PlayerState`, `GameState` | RG-005, RG-013, BC-005A, BC-012, AT-004 |
| Squadron runtime activation | Squadron JSON becomes `SquadronInstance` via `SquadronData`; keyword data remains available through the static template reference | `SquadronInstance`, `SquadronData`, `PlayerState` | RG-005, RG-006, BC-005A, AT-004 |
| Upgrade runtime gap | Upgrade assignments serialize in roster entries and affect fleet points, but no generic active upgrade-state collection was observed on `ShipInstance` | `FleetUpgradeAssignment`, `FleetShipEntry`, `FleetRosterSetupHelper`, `ShipInstance` | RG-005, RG-013, RG-015, BC-005A, BC-012, AT-004 |
| Objective and obstacle setup state | Selected objective, obstacles, setup state, deployments, map, and package hash are attached to `GameState.objectives` | `FleetSetupPackage`, `FleetSetupBootstrapper`, setup commands, setup flow code | RG-015, BC-005A, BC-012, AT-004 |
| Objective setup scaffolding | Selected objective setup creates structured setup state from objective JSON, including setup steps, objective ship selections, objective token assignment/placement scaffolds, set-aside units, deployment overrides, and runtime-state requirement metadata | `FleetSetupPackageBuilder._objective_setup_state()`, `ObjectiveData`, objective JSON records | RG-015, BC-005A, BC-012, AT-004 |
| RuleRegistry active scope | Bootstrap registers damage-card and squadron keyword rule scripts; registry stores hook catalogue, not active serialized state | `RuleBootstrap`, `RuleRegistry`, `src/core/effects/rules/` | RG-005, RG-006, BC-005, BC-005A, AT-004 |
| Damage card behavior split | Static damage-card records define effect ids; persistent effects are mostly registered through damage-card rule scripts, while immediate effects are resolved through `ResolveImmediateEffectCommand` and related UI/executor paths | `damage_cards.json`, `RuleBootstrap`, `src/core/effects/rules/damage_cards/ship/`, `ResolveImmediateEffectCommand`, `AttackExecutor` | RG-005, RG-006, RG-013, BC-005, BC-005A, AT-004 |
| RuleSurface execution helper | Shared targets and runners apply modifiers, blockers, observers, and enablers where call sites invoke them | `RuleSurface`, `AttackDiceResolver`, `DefenseTokenResolver`, `CommandProcessor` | RG-005, RG-006, BC-005, AT-004 |
| Resolver-owned rules | Attack/defense resolvers include both core logic and RuleRegistry hook application | `AttackDiceResolver`, `DefenseTokenResolver` | RG-005, BC-005, AT-004 |
| Command validation surface | CommandProcessor runs command applicability, command validation, rule validators, and observer followups | `CommandProcessor`, `CommandApplicability`, `GameCommand` subclasses | RG-005, RG-013, BC-005, AT-004 |
| Interaction/projection surface | `InteractionFlow` serializes active flow payload; `UIProjector` projects viewer-specific intent and rule affordances | `InteractionFlow`, `UIProjector`, setup/attack UI controllers | RG-005, RG-013, RG-015, BC-005, BC-012, AT-004 |
| Visibility and hidden information | Serialized snapshots are filtered per viewer before projection; owner-only interaction payloads are stripped from non-controller views, and hidden deck/dial/damage information is removed | `StateFilter`, `InteractionFlow.visible_to`, `UIProjector`, `test_reconnection_mid_attack.gd` | RG-013, BC-005, BC-007, BC-012, AT-004 |
| Save/load durability | `GameState.serialize()` includes objectives, player states, damage deck, RNG, interaction flow, and ship-target attack counts | `GameState`, `PlayerState`, `ShipInstance`, `SquadronInstance`, `DamageDeck` | RG-013, BC-005A, BC-012, AT-004 |
| Replay durability | Command history and `GameReplay` replay serialized commands; rule behavior depends on commands plus deterministic active state | `CommandProcessor`, `GameReplay`, replay tests | RG-013, BC-005, BC-005A, AT-004 |
| Network/reconnect durability | Lobby/network code serializes rosters, setup packages, commands, and state snapshots; projection reconstructs visible intent | `LobbyManager`, `NetworkManager`, `StateFilter`, `UIProjector` | RG-013, RG-015, BC-005A, BC-012, AT-004 |
| Existing test evidence | Static catalog/schema tests cover component records and typed loading; fleet/setup tests cover roster/package/bootstrap flows; command tests cover validation/history; rule tests cover registry/surface hooks, squadron keywords, and damage-card behavior; save/load tests cover serialized state; replay tests cover command replay/order; network/reconnect tests cover filtering and projection paths. Coverage is not yet mapped as an accepted per-boundary test strategy | `test_component_catalog_schema_contract.gd`, `test_fleet_builder_catalog_data_models.gd`, `test_fleet_catalog.gd`, `test_fleet_roster.gd`, `test_fleet_setup_package_builder.gd`, `test_fleet_roster_setup_helper.gd`, `test_rule_bootstrap.gd`, `test_rule_surface.gd`, `test_squadron_keyword_live_rules.gd`, `test_resolve_immediate_effect_command.gd`, `test_save_load_round_trip.gd`, `test_game_replay.gd`, `test_rule_order_replay.gd`, `test_network_manager.gd`, `test_reconnection_mid_attack.gd` | RG-013, BC-005, BC-005A, BC-012, AT-004 |

## 9. Open Questions For Owner

- Should future behavior-changing component rules use RuleRegistry as the primary surface, or should the current hybrid resolver/command/registry model be formalized?
- Where should active upgrade state live after setup: on `ShipInstance`, in a separate component-state collection, in `GameState`, or somewhere else?
- Which upgrade assignment facts need to survive beyond fleet points and roster payloads?
- What makes a static component rule "integrated": registered hook, command path, projection path, save/load support, replay support, network support, tests, or a defined subset?
- How should ship-specific and squadron-specific named abilities differ from generic keyword rules?
- How should objective special rules, scoring, setup effects, and objective tokens become active runtime behavior?
- How should obstacle setup constraints and obstacle gameplay effects be owned and serialized?
- How should catalog versioning affect saves, replays, and network peers when `data_key` lookups resolve static data at load time?
- Which rule surfaces should be considered authoritative for command rejection versus UI affordance display?
- Which tests are required before component content can be marked integrated?
- Should damage-card integration status distinguish persistent registered hooks, immediate command-owned effects, passive/no-op effects, and effects implemented through other resolver paths?
- Should `rules_integration`, `rule_surfaces`, and `runtime_state_requirements` remain descriptive metadata, or become checked contract fields?
- Does ADR-003 need to decide all component categories at once, or can it define a minimal accepted path for the next behavior-changing category first?

## 10. Next Recommended Steps

Recommended next step: continue with ADR-003 Rule and Validation Surface Decision using this context pack as evidence.

Useful follow-up work before or alongside ADR-003:

- Draft a focused test strategy for behavior-changing component rules, covering command validation, projection, save/load, replay, and network.
- Create a narrow contract draft only after the owner decides the authoritative rule/validation surfaces for at least one component category.
- Create CP-004 Fleet Builder to Runtime Handoff Context Pack if upgrade, objective, or obstacle behavior is the next feature area.
- Update stale static-content documentation after the owner decides whether the current JSON/AssetLoader pipeline is accepted architecture or current implementation only.

This context pack does not accept a future architecture. It records the current evidence needed to make the next decision safely.
