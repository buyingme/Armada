# Fleet Builder Implementation Plan

> Status: Proposed
> Last updated: 2026-05-25
> Scope: local-first fleet builder, Core Set catalog completion, JSON import/export,
> fleet validation, and setup/deployment integration for hot-seat first, with
> network/backend work deliberately deferred until the local contract is stable.

---

## 0. Product Decisions

The first useful version is a hybrid local-first tool. It stores fleets locally,
uses native JSON import/export, and shapes its data contract so backend sync,
accounts, and share links can be added later without becoming a second source of
truth.

| Decision | Baseline |
|---|---|
| MVP storage | Local fleet library in project/user data, independent from game saves. |
| Exchange format | Native JSON first. PDF, CSV, and external-builder imports are later work. |
| Point formats | Standard 400, Core Set 180, and custom agreed totals. |
| Initial catalog | Existing Core Set ships/squadrons plus Core Set upgrades, objectives, and obstacles. |
| Game integration | Full setup/deployment path, not an isolated list builder. |
| Backend/auth/share links | Deferred until fleet JSON, validation, and setup packages are stable. |
| Rule authority | Local RRG/card JSON are implementation sources. External wiki data is manual verification only. |

---

## 1. Current Discovery

### 1.1 Component Catalog State

| Area | Current state | Plan consequence |
|---|---|---|
| Ships | `Resources/Game_Components/ships/` contains 6 ship JSON files and related art. | Extend metadata in place; do not hardcode fleet-builder-only ship facts in GDScript. |
| Squadrons | `Resources/Game_Components/squadrons/` contains 5 squadron JSON files and related art. | Extend metadata in place; refresh stale docs/manifests that still describe only the earlier MVP subset. |
| Upgrades | `Resources/Game_Components/upgrades/` now exists with Core Set/Wave 0 card art and some rule notes grouped by upgrade type. `src/models/upgrade_data.gd` exists but is a field stub without `from_dict()`/loader support. | Normalize the arriving upgrade data into structured JSON by type, then add schema, parser, loader, and tests before validator/UI work depends on upgrades. |
| Objectives | `Resources/Game_Components/objectives/` now contains all 12 Core Set objective card images, source rule notes, objective token art, and one structured JSON catalog file per objective. No `ObjectiveData` model exists yet. | Keep the folder lowercase, add schema/parser/loader support for the JSON shape, and normalize source-note filename typos when convenient. |
| Obstacles | `Resources/Game_Components/obstacles/obstacles_specs.txt` exists with RRG notes for asteroid field, debris field, and station plus general obstacle rules. | Keep lowercase `obstacles/` as the canonical folder. Convert the text notes into structured JSON and art/shape metadata before deployment validation uses them. |
| Schema | `Resources/Game_Components/card_data_schema.json` currently covers ships and squadrons only. | Extend schema for metadata, upgrades, objectives, obstacles, and future catalog indexes. |
| Asset loading | `src/utils/asset_loader.gd` uses a hardcoded `ASSET_MANIFEST` and only has `load_ship_data()`, `load_squadron_data()`, and `load_json()`. | Add data-driven enumeration and typed loaders. The builder must not need a manifest edit for every card. |
| README | `Resources/Game_Components/README.md` documents flat snake_case folders but does not list upgrades, objectives, or obstacles yet. | Update it when the folders are introduced and keep lower_snake_case as binding convention. |

### 1.2 Existing Runtime/Setup Surfaces

| Surface | Current state | Plan consequence |
|---|---|---|
| Main menu | `src/scenes/main_menu/main_menu.gd` opens a scenario picker and starts `GameManager.set_next_scenario_id(...)`. | Add separate Fleet Builder and New Game setup entries without embedding validation logic in the menu script. |
| Scenario setup | `src/core/state/learning_scenario_setup.gd` loads scenario JSON and creates ship/squadron instances from `AssetLoader`. | Extract reusable setup helpers rather than copy scenario creation logic. |
| Game bootstrap | `src/autoload/game_manager.gd` bootstraps from scenario id or from loaded `GameState`. | Add a setup-package path after the package contract exists. Avoid broad bootstrap rewrites before tests describe both paths. |
| Board spawning | `src/scenes/game_board/game_board.gd` has scenario and loaded-state spawn paths. | Generalize token spawn/bind from prepared instances and normalized placements. Keep visual token code in presentation, not fleet validation. |
| Player state | `src/core/state/player_state.gd` stores runtime ships/squadrons/fleet points. | Do not use `PlayerState` as the editable roster model. Fleet-builder drafts need separate core classes. |
| Game state objectives | `src/core/state/game_state.gd` declares `objectives: Dictionary` but currently does not serialize it. | When objectives become active game state, add JSON-safe serialization/deserialization and tests in the same slice. |
| Deployment positions | `src/models/token_placement.gd` and scenario JSON use `pos_x`, `pos_y`, and `rotation_deg`. | Fleet setup and deployment packages must use the same normalized coordinate contract, never pixels. |
| Network lobby | Lobby currently selects scenario metadata before game start. | Network fleet exchange is a later slice after hot-seat setup packages are deterministic. |

### 1.3 Rules That Drive Validation

Implementation APIs must cite the specific rule text in doc comments. The
minimum fleet-builder rule set comes from `Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md`:

| Rule area | Source summary | First validator surface |
|---|---|---|
| Fleet points | Fleet total cannot exceed the agreed total; Standard is 400 and Core Set recommendation is 180. | `FleetValidator.validate_point_total()` |
| Faction purity | Fleet aligns with one faction and cannot include cards aligned with another faction, except dual-faction cards. | `FleetValidator.validate_faction_alignment()` |
| Objectives | Each player chooses three objectives, one per category: Assault, Defense, Navigation. | `FleetValidator.validate_objectives()` |
| Commander/flagship | A fleet must have exactly one flagship; a commander creates the flagship and a fleet cannot have more than one commander. | `FleetValidator.validate_flagship()` |
| Squadron cap | Squadron points cannot exceed one third of the agreed fleet total, rounded up. | `FleetValidator.validate_squadron_points()` |
| Unique squadrons | A fleet can contain one unique squadron with defense tokens for each 100 points of agreed fleet total. | `FleetValidator.validate_unique_squadron_limit()` |
| Unique names | A fleet cannot contain more than one card with the same unique name; unique squadron type restrictions also apply. | `FleetValidator.validate_unique_names()` |
| Upgrade slots | Each upgrade icon or icon group in a ship upgrade bar can equip one matching upgrade card. | `FleetValidator.validate_upgrade_slots()` |
| Duplicate upgrades | RRG errata: a ship cannot equip more than one copy of the same upgrade card. | `FleetValidator.validate_duplicate_ship_upgrades()` |
| Upgrade restrictions | Faction, size, ship trait/name, flagship, title, modification, and non-flotilla commander restrictions apply. | `FleetValidator.validate_upgrade_restrictions()` |
| Obstacles | Standard games with objective cards use the six obstacle tokens from a core set or fleet expansion, plus any objective-specified additions. | Setup/deployment validator, not editable roster validation. |

---

## 2. Architecture Audit

The roadmap is viable, but only if it treats fleet building as three distinct
systems: static catalog data, editable roster state, and match setup state.
Blending those systems would violate existing project boundaries and make
save/load or network setup fragile.

### 2.1 Required Boundaries

| Boundary | Compliant design | Non-compliant drift to avoid |
|---|---|---|
| Static catalog | `Resources/Game_Components/*` JSON plus `src/models/*Data.gd` resources. | Hardcoded card points, factions, slots, or restrictions in UI or validators. |
| Editable roster | New `src/core/fleet/` `RefCounted` classes such as `FleetRoster` and `FleetShipEntry`. | Reusing `PlayerState` as a mutable builder draft. |
| Fleet validation | Pure core validator returning `FleetValidationResult`. UI renders result messages and disabled states. | Scenes/UI deciding faction, point, upgrade, objective, or uniqueness legality. |
| Local library | Application service that reads/writes fleet JSON files and versions. | Mixing fleet library files with save-game state or scenario JSON. |
| Setup package | Serializable package containing two validated rosters, selected objective, obstacles, first player, and normalized deployments. | Passing loose dictionaries through menu/board code without a versioned contract. |
| Game state mutation | Bootstrap creates initial `GameState` from a setup package before gameplay; interactive setup after state creation uses commands. | Scene code directly mutating `GameState` during setup/deployment. |
| Rule hooks | Gameplay effects from upgrades, objectives, and obstacles go through `RuleRegistry` under `src/core/effects/rules/`. | Special-case card effects in validators, scenes, or board controllers. |
| Presentation | `src/scenes/fleet_builder/` and reusable `src/ui/` widgets call core services and render results. | New `if PlayMode.is_network()` or `if PlayMode.is_hot_seat()` branches in `src/scenes/` or `src/ui/`. |
| Serialization | Every mutable core setup/roster/game state has `serialize()`/`deserialize()` and JSON-safe fields. | `Vector2`, `Color`, Resource instances, pixels, or enums stored raw in JSON. |

### 2.2 Proposed New Source Areas

These folders are proposed so future slices have a stable target. If a new core
subfolder is added, update `.skills/file_organization.md` and arc42 docs in the
same slice.

| Folder | Responsibility |
|---|---|
| `src/core/fleet/` | Editable roster model, catalog queries, fleet validation, fleet JSON import/export helpers. |
| `src/core/setup/` | Setup package, roster-to-instance conversion, objective/obstacle/deployment setup validation. |
| `src/scenes/fleet_builder/` | Main fleet-builder screen and controller. |
| `src/scenes/setup_flow/` | New-game setup coordinator after the fleet-builder MVP is stable. |
| `src/ui/fleet_builder/` | Reusable catalog, roster, validation, and library widgets if the scene needs extraction. |
| `Resources/Game_Components/upgrades/` | Upgrade JSON and card art. |
| `Resources/Game_Components/objectives/` | Objective JSON and card art. |
| `Resources/Game_Components/obstacles/` | Obstacle JSON, shape metadata, and art. |

### 2.3 Required Verification By Change Type

| Change type | Required checks |
|---|---|
| Docs only | `git diff --check` |
| Data/schema | JSON/schema tests, `godot --headless --import`, targeted loader/model GUT tests |
| New `.gd` with `class_name` | `godot --headless --import`, commit `.gd.uid`, targeted GUT tests |
| Core roster/validator/library | Targeted GUT tests plus full GUT when shared loaders/state are touched |
| UI | Focused UI tests, leak/orphan clean GUT output, full GUT, `bash scripts/lint_phase_k.sh` |
| Setup/game start/replay/network | Full GUT, `bash scripts/lint_phase_k.sh`, `bash scripts/run_baseline_traces.sh --all` |
| Objective/upgrade/obstacle gameplay effects | RuleRegistry tests, save/load rebuild, replay determinism, hot-seat/network command safety |

---

## 3. Requirement Changes To Make Before Coding

`docs/requirements/fleet_builder.txt` should be rewritten into an
implementation-ready requirement set before source work starts. The rewrite
should preserve the user's goals but split MVP from later infrastructure.

### 3.1 MVP Requirements

| ID | Requirement |
|---|---|
| FB-REQ-001 | Users can create, rename, duplicate, delete, save, and load local fleets. |
| FB-REQ-002 | A fleet has name, description, faction, point format, point limit, ships, squadrons, upgrades, and three objectives. |
| FB-REQ-003 | Supported point formats are Standard 400, Core Set 180, and custom agreed totals. |
| FB-REQ-004 | The catalog supports search/filter by faction, component type, point cost, upgrade slot/type, wave, expansion, keywords, and search tags. |
| FB-REQ-005 | The builder calculates total points, ship points, squadron points, and upgrade points continuously. |
| FB-REQ-006 | The builder validates point total, faction purity, flagship/commander, squadron cap, unique limits, objective categories, and upgrade legality. |
| FB-REQ-007 | The builder imports and exports native versioned JSON. |
| FB-REQ-008 | The local library stores multiple versions/snapshots per fleet and can restore an older version. |
| FB-REQ-009 | Two valid fleets can be passed into setup, objective selection, obstacle/deployment placement, and match start. |
| FB-REQ-010 | Setup/deployment positions serialize as normalized `pos_x`, `pos_y`, and `rotation_deg`. |
| FB-REQ-011 | Save/load after setup preserves selected objective, obstacles, deployments, fleet points, ships, squadrons, and upgrade assignments. |

### 3.2 Deferred Requirements

| Area | Deferred until | Notes |
|---|---|---|
| User accounts/auth | After local JSON and setup package are stable. | Backend should sync the same fleet JSON contract, not invent a second format. |
| Share links/codes | After backend direction is chosen. | Local export/import covers immediate sharing. |
| PDF/CSV export | After native JSON MVP. | Useful, but not needed for game start integration. |
| External builder import | After local schema stabilizes. | Add adapters rather than weakening the native schema. |
| Full non-Core catalog | After Core Set validation and setup flow are proven. | Add waves/expansions incrementally with schema tests. |
| Strict tournament rules | Later rules pack. | MVP validates core rules and custom agreed point totals. |

### 3.3 Requirement Additions

- Define the fleet JSON schema and setup package schema explicitly.
- Define data-source policy for card text, errata, and local verification.
- Define whether deployment starts as warning-guided manual placement or hard
  rule enforcement. The implementation plan assumes warning-guided manual
  placement first, followed by stricter validators.
- Define how first player is chosen. The implementation plan assumes manual
  selection first, with bid/initiative automation added later.
- Define catalog completeness criteria for Core Set upgrades, objectives, and
  obstacles before UI work begins.

---

## 4. Data Contracts

These contracts are intentionally JSON-safe and versioned. Field names are the
shape future slices should implement unless a slice explicitly updates this plan
first.

### 4.1 Fleet Roster JSON

```json
{
  "format_version": 1,
  "kind": "fleet_roster",
  "fleet_id": "local-generated-id",
  "name": "Opening Salvo Rebels",
  "description": "Core Set 180 test fleet",
  "faction": "REBEL_ALLIANCE",
  "point_format": {
    "id": "CORE_SET_180",
    "limit": 180,
    "custom_label": ""
  },
  "ships": [
    {
      "entry_id": "ship-1",
      "data_key": "cr90_corvette_a",
      "upgrades": [
        {
          "assignment_id": "upgrade-1",
          "data_key": "example_upgrade_key",
          "slot_index": 0,
          "slot_type": "TURBOLASERS"
        }
      ]
    }
  ],
  "squadrons": [
    {
      "entry_id": "squadron-1",
      "data_key": "x_wing_squadron"
    }
  ],
  "objectives": {
    "ASSAULT": "opening_salvo",
    "DEFENSE": "contested_outpost",
    "NAVIGATION": "superior_positions"
  },
  "created_at": "2026-05-25T00:00:00Z",
  "updated_at": "2026-05-25T00:00:00Z",
  "source": "local",
  "future_sync": {
    "owner_id": "",
    "remote_id": "",
    "revision": 0
  }
}
```

Rules:
- Store static references as `data_key`, never embedded card data.
- Store enum-like values as schema strings in fleet files for readability; core
  models may parse them into project enums internally.
- `validation_snapshot` may be stored for UI convenience later, but it is never
  authoritative. Validators must recompute from catalog data.
- The roster contract must round-trip unknown future fields without crashing.

### 4.2 Setup Package JSON

```json
{
  "format_version": 1,
  "kind": "fleet_setup_package",
  "scenario_id": "standard_3x6",
  "point_format": {
    "id": "STANDARD_400",
    "limit": 400
  },
  "first_player": 0,
  "players": [
    {
      "player_index": 0,
      "roster": { "fleet_id": "fleet-a" },
      "faction": "REBEL_ALLIANCE"
    },
    {
      "player_index": 1,
      "roster": { "fleet_id": "fleet-b" },
      "faction": "GALACTIC_EMPIRE"
    }
  ],
  "selected_objective": {
    "data_key": "opening_salvo",
    "owner_player": 1,
    "chosen_by_player": 0
  },
  "obstacles": [
    {
      "data_key": "asteroid_field_1",
      "pos_x": 0.45,
      "pos_y": 0.50,
      "rotation_deg": 17.0
    }
  ],
  "deployments": [
    {
      "owner_player": 0,
      "component_type": "ship",
      "roster_entry_id": "ship-1",
      "pos_x": 0.50,
      "pos_y": 0.82,
      "rotation_deg": 0.0
    }
  ]
}
```

Rules:
- The setup package can reference full embedded rosters or local `fleet_id`s.
  For network and replay, use a fully expanded package before game start.
- All placements use normalized coordinates.
- Setup package validation must run before it is converted to `GameState`.
- If setup is interactive after `GameState` exists, each commit must be a
  `GameCommand`; otherwise package-to-state conversion happens during bootstrap
  before gameplay begins.

### 4.3 Static Catalog Metadata

All card/component JSON should support these optional fields before search/filter
UI is built:

| Field | Applies to | Purpose |
|---|---|---|
| `data_key` | all | Stable file/catalog id if explicit id is needed. |
| `display_name` or existing card name field | all | UI display. |
| `wave` | all cards | Filter and catalog grouping. |
| `expansion` | all cards/obstacles | Source/product grouping. |
| `source` | all | Local verification note, e.g. Core Set, RRG, errata. |
| `card_image` | cards | Relative image filename in the same folder. |
| `search_tags` | all | Search/filter tags, lower_snake_case strings. |
| `is_unique` | cards | Unique-name validator input. |
| `unique_group` | squadrons/titles | Unique squadron type or name restriction group. |
| `errata_version` | cards | Future errata tracking. |

### 4.4 Objective Card JSON

Objective JSON is static catalog data, not executable rule code. It records the
card identity, rule text summaries, setup effects, rule hook surfaces, token
requirements, and runtime state needed by later setup/gameplay slices. Concrete
gameplay behavior still belongs in `RuleRegistry` rule files once an objective
is made live.

Example shape:

```json
{
  "data_key": "obj_nav_superior_positions",
  "kind": "objective_card",
  "objective_name": "Superior Positions",
  "category": "NAVIGATION",
  "wave": 0,
  "expansion": "core_set",
  "available_through": ["star_wars_armada_core_set"],
  "card_image": "obj_nav_superior_positions_card.png",
  "victory_token_points": 15,
  "task_force_recommended": true,
  "setup_text": "The first player must deploy all ships and squadrons before the second player.",
  "special_rule_text": "After a ship or squadron attacks the rear hull zone of another ship, if the defender suffered at least 1 damage, the attacker's owner gains 1 victory token.",
  "end_of_round_text": "",
  "end_of_game_text": "",
  "timing_notes": [],
  "errata": [],
  "clarifications": [],
  "setup_effects": [
    {
      "kind": "deployment_order_override",
      "controller": "FIRST_PLAYER",
      "rule": "first_player_deploys_all_ships_and_squadrons_before_second_player"
    }
  ],
  "rule_surfaces": [
    {
      "kind": "OBSERVER",
      "surface": "attack.after_performed",
      "timing": "after_attack_performed",
      "summary": "Award 1 victory token after a ship or squadron attack damages a ship's rear hull zone."
    }
  ],
  "objective_tokens": {
    "uses_tokens": false,
    "count": 0,
    "count_formula": "none",
    "placement": []
  },
  "runtime_state_requirements": [
    "deployment_order_override",
    "victory_tokens_by_player"
  ],
  "search_tags": ["navigation", "rear_hull_zone", "deployment", "victory_tokens"],
  "source_refs": [
    "Resources/Game_Components/objectives/obj_nav_superior_positions_rules.txt",
    "RRG 1.5.0 Objective Cards, p.11"
  ]
}
```

The first Core Set extraction includes:

| Category | JSON files |
|---|---|
| Assault | `obj_ass_advanced_gunnery.json`, `obj_ass_most_wanted.json`, `obj_ass_opening_salvo.json`, `obj_ass_precision_strike.json` |
| Defense | `obj_def_contested_outpost.json`, `obj_def_fire_lanes.json`, `obj_def_fleet_ambush.json`, `obj_def_hyperspace_assault.json` |
| Navigation | `obj_nav_dangerous_territory.json`, `obj_nav_intel_sweep.json`, `obj_nav_minefields.json`, `obj_nav_superior_positions.json` |

`ObjectiveData.from_dict()` should parse these fields directly and keep
`setup_effects`, `rule_surfaces`, `objective_tokens`, `errata`, and
`clarifications` as JSON-safe arrays/dictionaries until individual objectives
are implemented through typed rule classes.

---

## 5. Implementation Slices

Each slice should be small enough to finish with targeted tests and a clear exit
condition. Code-bearing slices must not be committed until the relevant manual
test gate is passed.

### FB0 - Requirements And Source Inventory

| Field | Plan |
|---|---|
| Goal | Turn `docs/requirements/fleet_builder.txt` into implementation-ready MVP/deferred requirements. |
| Scope | Requirements rewrite, Core Set card inventory checklist, data-source policy, first-player/deployment assumptions, non-goals. |
| Primary files | `docs/requirements/fleet_builder.txt`, this plan, possibly `docs/arc42/01_introduction_and_goals.md`. |
| Acceptance | Requirements contain MVP/deferred split, JSON/import-export requirement, point formats, objective/deployment integration, and backend/auth deferral. |
| Verification | `git diff --check`. |

### FB1 - Component Folder And Schema Contract

| Field | Plan |
|---|---|
| Goal | Make the static catalog structure explicit before loader/model code changes. |
| Scope | Add or normalize `upgrades/`, `objectives/`, and `obstacles/`; update `Resources/Game_Components/README.md`; extend `card_data_schema.json` definitions for metadata, upgrades, objectives, and obstacles. Objective schema must cover `setup_effects`, `rule_surfaces`, `objective_tokens`, `runtime_state_requirements`, `victory_token_points`, `task_force_recommended`, `errata`, and `clarifications`. |
| Primary files | `Resources/Game_Components/README.md`, `Resources/Game_Components/card_data_schema.json`, `Resources/Game_Components/obstacles/`. |
| Acceptance | Schema can express Core Set upgrade/objective/obstacle records; README lists the new folders; objective schema validates all 12 Core Set objective JSON files; no PascalCase or space-containing folder names. |
| Tests | Add schema-validation tests or a small Godot test helper that loads sample JSON and reports schema/required-field failures. |
| Verification | `godot --headless --import`, targeted schema/loader tests, `git diff --check`. |

### FB2 - Static Data Models And Loaders

| Field | Plan |
|---|---|
| Goal | Give the catalog typed loading support without hardcoded per-card manifests. |
| Scope | Complete `UpgradeData.from_dict()`, add `ObjectiveData` and `ObstacleData`, add typed `AssetLoader` load/list helpers, and add data-driven enumeration with `DirAccess`. |
| Primary files | `src/models/upgrade_data.gd`, new `src/models/objective_data.gd`, new `src/models/obstacle_data.gd`, `src/utils/asset_loader.gd`. |
| Acceptance | Tests can list and load ships, squadrons, upgrades, objectives, and obstacles by key; missing/invalid JSON produces clear failures without crashing. |
| Tests | Model parsing tests, loader enumeration tests, invalid/missing asset tests. |
| Verification | `godot --headless --import`, targeted GUT, full GUT if `AssetLoader` behavior changes broadly, `bash scripts/lint_phase_k.sh`. |

### FB3 - Core Set Data Ingestion

| Field | Plan |
|---|---|
| Goal | Convert the prepared upgrade/objective/obstacle information into validated catalog JSON. |
| Scope | Add Core Set upgrade JSON/art references, objective JSON/art references, obstacle JSON/shape metadata, and metadata for existing Core Set ships/squadrons. |
| Primary files | `Resources/Game_Components/upgrades/`, `Resources/Game_Components/objectives/`, `Resources/Game_Components/obstacles/`, existing ship/squadron JSON. |
| Acceptance | All Core Set cards/components needed for 180-point fleets are loadable; all 12 Core Set objective JSON files exist and declare 4 Assault, 4 Defense, and 4 Navigation cards; every objective points to card art and a source note; each upgrade JSON declares faction/slot/category/restriction fields needed by validators. |
| Tests | Catalog completeness tests for expected Core Set keys; parser tests for representative upgrade/objective/obstacle restrictions; objective category-count tests. |
| Verification | `godot --headless --import`, targeted data tests, `git diff --check`. |

### FB4 - Serializable Fleet Roster Model

| Field | Plan |
|---|---|
| Goal | Add editable fleet-builder state separate from runtime `PlayerState`. |
| Scope | Create `FleetRoster`, `FleetShipEntry`, `FleetSquadronEntry`, `FleetUpgradeAssignment`, `FleetObjectiveSelection`, and `FleetValidationResult` in `src/core/fleet/`. |
| Primary files | New `src/core/fleet/*.gd`, tests under `tests/unit/core/fleet/`. |
| Acceptance | Roster create/add/remove/update APIs are typed, documented, JSON-safe, and round-trip through `serialize()`/`deserialize()`. |
| Tests | Empty roster, populated roster, upgrade assignment, objective selection, unknown future fields/defaults, duplicate entry ids. |
| Verification | `godot --headless --import`, targeted GUT, full GUT if shared state classes are touched, `bash scripts/lint_phase_k.sh`. |

### FB5 - Fleet Catalog Queries

| Field | Plan |
|---|---|
| Goal | Provide search/filter primitives for UI and validators. |
| Scope | Add `FleetCatalog` query helper over `AssetLoader` lists with filters for faction, component type, point cost range, upgrade slot/type, wave, expansion, keyword, and text tags. |
| Primary files | New `src/core/fleet/fleet_catalog.gd`, loader/model tests. |
| Acceptance | Queries are deterministic, sorted consistently, and return catalog keys plus typed data resources without UI dependencies. |
| Tests | Filter combinations, empty results, case-insensitive text search, stable sort, missing metadata defaults. |
| Verification | Targeted GUT, `bash scripts/lint_phase_k.sh`. |

### FB6 - Fleet Validator Baseline Rules

| Field | Plan |
|---|---|
| Goal | Enforce construction rules that do not require detailed upgrade restrictions yet. |
| Scope | Add `FleetValidator` APIs for point total, faction alignment, commander/flagship count, squadron one-third cap, unique names, unique squadron limit, and three objective categories. |
| Primary files | New `src/core/fleet/fleet_validator.gd`, `fleet_validation_result.gd`, tests. |
| Acceptance | Validator returns structured errors/warnings with rule ids, affected roster entry ids, source references, and severity. |
| Tests | Legal 180/400/custom fleets, over-limit fleets, mixed faction, zero/two commanders, excessive squadron points, duplicate unique names, invalid objective sets. |
| Verification | Targeted GUT, full GUT if validator touches shared models, `bash scripts/lint_phase_k.sh`. |

### FB7 - Upgrade Assignment Validation

| Field | Plan |
|---|---|
| Goal | Validate upgrade slots and restriction traits using static catalog data. |
| Scope | Add slot matching, multi-icon groups if present in data, duplicate upgrade per ship, one title, one modification, faction/size/ship-name/ship-icon/title/flagship restrictions, and flotilla commander restriction once flotilla metadata exists. |
| Primary files | `src/core/fleet/fleet_validator.gd`, `UpgradeData`, upgrade JSON. |
| Acceptance | Illegal upgrades are blocked by validator and exposed as structured `FleetValidationResult` entries; UI later can render the same entries. |
| Tests | Matching/mismatched slot, duplicate same upgrade on one ship, commander on non-flotilla, title mismatch, modification limit, faction and size restrictions. |
| Verification | Targeted GUT, full GUT, `bash scripts/lint_phase_k.sh`. |

### FB8 - Fleet JSON Import/Export And Local Library

| Field | Plan |
|---|---|
| Goal | Persist local fleets independently from game saves. |
| Scope | Add `FleetLibraryManager` or equivalent application service for save/list/load/delete/duplicate/version/restore; add import/export helpers for the versioned fleet JSON contract. |
| Primary files | New service under `src/autoload/` only if singleton behavior is needed, otherwise `src/core/fleet/` plus a thin scene controller; tests under unit/integration. |
| Acceptance | Library can save multiple fleets, create version snapshots, restore older versions, reject invalid JSON with readable errors, and preserve unknown future fields where practical. |
| Tests | Save/load/delete/list, version restore, invalid JSON, format migration/defaults, import/export round trip. |
| Verification | Targeted GUT, full GUT if adding autoload, `bash scripts/lint_phase_k.sh`. |

### FB9 - Fleet Builder Scene MVP

| Field | Plan |
|---|---|
| Goal | Add an integrated UI for building and validating a fleet. |
| Scope | Add menu entry, fleet header, point/status strip, catalog/search/filter panel, selected ships with upgrade slots, squadron list, objective selectors, and validation panel. |
| Primary files | `src/scenes/fleet_builder/fleet_builder.tscn`, `src/scenes/fleet_builder/fleet_builder.gd`, extracted `src/ui/fleet_builder/*` widgets as needed, `src/scenes/main_menu/main_menu.gd`. |
| Acceptance | User can create a local draft, add/remove ships/squadrons/upgrades/objectives, see live point totals and validation errors, and return to main menu. |
| Architecture gate | UI only calls catalog/roster/validator/library APIs. It does not implement fleet rules and adds no PlayMode branches. |
| Tests | UI construction, search/filter interaction, add/remove flows, validation rendering, no orphan/leak warnings. |
| Verification | Focused UI GUT, full GUT, `bash scripts/lint_phase_k.sh`, manual create/edit invalid/legal fleet pass. |

### FB10 - Library, Import, Export, And Version UI

| Field | Plan |
|---|---|
| Goal | Make local fleet management usable from the scene. |
| Scope | Add open/save-as/duplicate/delete/version restore/import/export controls and confirmation/error states. |
| Primary files | Fleet builder scene/widgets, `FleetLibraryManager`. |
| Acceptance | User can manage multiple fleets, export JSON, import JSON, and restore an older local version from UI. |
| Tests | Button flows with mocked library, invalid import display, version restore rendering, no orphan/leak warnings. |
| Verification | Focused UI GUT, full GUT, `bash scripts/lint_phase_k.sh`, manual import/export/version pass. |

### FB11 - Setup Package Model And Objective Choice Flow

| Field | Plan |
|---|---|
| Goal | Bridge two validated rosters into a deterministic pre-game setup package. |
| Scope | Add `FleetSetupPackage`, `SetupValidationResult`, first-player selection, objective choice from second player's objectives, package serialization, and setup-state scaffolding derived from `ObjectiveData.setup_effects`. |
| Primary files | New `src/core/setup/*.gd`, setup flow scene/controller skeleton. |
| Acceptance | Two valid fleets produce a setup package; invalid rosters cannot start setup; selected objective records owner/chosen-by player; objective setup requirements such as objective ships, objective token placements, set-aside units, and deployment-order overrides are represented as JSON-safe setup state. |
| Tests | Package round trip, invalid fleet rejection, objective choice ownership, first-player persistence, representative objective setup-state extraction. |
| Verification | `godot --headless --import`, targeted GUT, full GUT, `bash scripts/lint_phase_k.sh`. |

### FB12 - Roster To Runtime Instance Conversion

| Field | Plan |
|---|---|
| Goal | Convert fleet roster entries into `ShipInstance` and `SquadronInstance` arrays using the same static data loading rules as scenarios. |
| Scope | Add `FleetRosterSetupHelper` or `RosterInstanceFactory`; extract common instance creation from `LearningScenarioSetup`/board code if needed; carry upgrade assignments into runtime state once runtime upgrade state exists. |
| Primary files | `src/core/setup/fleet_roster_setup_helper.gd`, `src/core/state/*` if runtime upgrade assignments must serialize, `src/scenes/game_board/game_board.gd` extraction points. |
| Acceptance | Runtime instances preserve owner player, data key, initial speed policy, fleet points, and roster entry identity for deployment mapping. |
| Tests | Rebel/Imperial roster conversion, duplicate ship instances, squadron conversion, missing data rejection, save/load of any new runtime fields. |
| Verification | Targeted GUT, full GUT, `bash scripts/lint_phase_k.sh`. |

### FB13 - Game Bootstrap From Setup Package

| Field | Plan |
|---|---|
| Goal | Start a hot-seat match from two rosters without duplicating scenario spawn logic. |
| Scope | Add a setup-package entry point in `GameManager`, generalize board spawn/bind to accept prepared instances plus placements, keep scenario start path intact. |
| Primary files | `src/autoload/game_manager.gd`, `src/scenes/game_board/game_board.gd`, setup helpers. |
| Acceptance | Existing scenario starts still pass; a setup package starts a board with correct player states, damage deck, RNG, map, ships, and squadrons. |
| Tests | Scenario path regression, setup-package bootstrap, loaded-state spawn regression, token binding assertions. |
| Verification | Full GUT, `bash scripts/lint_phase_k.sh`, `bash scripts/run_baseline_traces.sh --all`, manual start-from-fleet pass. |

### FB14 - Deployment And Obstacle Placement Flow

| Field | Plan |
|---|---|
| Goal | Let setup choose/place obstacles and deploy fleet components using normalized positions. |
| Scope | Add obstacle placement state, deployment placement state, warning-guided manual placement UI first, and validators for normalized bounds/deployment zones/obstacle overlap constraints. |
| Primary files | `src/core/setup/*deployment*.gd`, `src/core/setup/*obstacle*.gd`, setup flow scene/widgets, `src/models/token_placement.gd` reuse. |
| Acceptance | User can place Core Set obstacles and deploy ships/squadrons, then serialize a setup package with normalized placements. |
| Tests | Placement serialization, bounds validation, obstacle set completeness, deployment-zone warnings/errors, no pixel values in payloads. |
| Verification | Focused setup UI tests, full GUT, `bash scripts/lint_phase_k.sh`, `bash scripts/run_baseline_traces.sh --all`, manual deployment pass. |

### FB15 - GameState Persistence For Objectives, Obstacles, And Upgrades

| Field | Plan |
|---|---|
| Goal | Preserve setup-derived state through save/load, replay, and later network snapshots. |
| Scope | Add serialized fields for selected objective, obstacle placements/state, objective tokens, objective ships, victory tokens, set-aside units, station/obstacle overrides, deployment modifiers, and runtime upgrade assignments/exhaustion where gameplay uses them. Update `StateFilter` if player-specific visibility is needed. |
| Primary files | `src/core/state/game_state.gd`, `src/core/state/player_state.gd`, ship/squadron instance state if upgrades attach there, `StateFilter`, tests. |
| Acceptance | Save/load after deployment reconstructs objective, objective-specific runtime state, obstacles, fleet points, upgrade assignments, and token positions identically. |
| Tests | Serialize/deserialize round trips, save/load integration, representative objective-state round trips, replay determinism for setup package start. |
| Verification | Full GUT, `bash scripts/lint_phase_k.sh`, `bash scripts/run_baseline_traces.sh --all`, manual save/load after setup pass. |

### FB16 - Gameplay Rule Hooks For Objectives, Obstacles, And Upgrades

| Field | Plan |
|---|---|
| Goal | Implement only the active gameplay effects needed by the Core Set catalog through `RuleRegistry`. |
| Scope | Add rule files under `src/core/effects/rules/` for selected objectives, obstacle effects, and any upgrades promoted from passive validation to gameplay behavior. |
| Primary files | `src/core/effects/rules/*`, `RuleBootstrap`, commands/validators touched by those rules. |
| Acceptance | Rule effects are source-first, active status is derived from serialized state, and UI affordances are projected from core/application metadata. |
| Tests | Direct command validation, UI eligibility projection, save/load rebuild, replay determinism, network mirror safety for each rule surface. |
| Verification | Full GUT, `bash scripts/lint_phase_k.sh`, `bash scripts/run_baseline_traces.sh --all`, manual rule-specific passes. |

### FB17 - Network Fleet Setup Exchange

| Field | Plan |
|---|---|
| Goal | Let network games exchange and confirm fleet setup deterministically before game start. |
| Scope | Extend lobby state with selected fleet metadata, expanded setup package exchange, host-authoritative validation, and start-game handoff. |
| Primary files | `src/autoload/lobby_manager.gd`, `src/scenes/lobby/lobby_room.gd`, setup package serialization, state filtering if needed. |
| Acceptance | Host and client agree on the same setup package and final state hash after game start. Existing scenario network starts remain intact. |
| Tests | Lobby serialization, invalid remote package rejection, host/client setup equality, reconnection snapshot if setup can be resumed. |
| Verification | Full GUT, `bash scripts/lint_phase_k.sh`, `bash scripts/run_baseline_traces.sh --all`, manual two-process setup pass. |

### FB18 - Backend Sync And Share Links

| Field | Plan |
|---|---|
| Goal | Add optional online features over the stable local fleet contract. |
| Scope | Choose backend direction, auth, remote library sync, public/private share links, conflict policy, and import from shared code/link. |
| Primary files | New backend/client integration docs and services. |
| Acceptance | Remote sync never bypasses local validation and stores the same versioned fleet JSON contract. |
| Tests | Contract tests, sync conflict tests, offline/online transition tests. |
| Verification | Depends on backend choice; keep local library tests as the non-network baseline. |

---

## 6. Cross-Slice Engineering Gates

These gates apply whenever the corresponding slice creates or changes code.

1. Static typing everywhere: all parameters, return types, and variables in new
   GDScript must be typed.
2. Public APIs need doc comments with rule references where they validate or
   implement Armada rules.
3. New core classes extend `RefCounted`; new model classes extend `Resource`;
   scene/UI scripts extend `Node`/`Control` only in presentation layers.
4. New mutable state in core/models must serialize and deserialize in the same
   slice, with round-trip tests.
5. Static catalog facts stay in JSON/data resources. No hardcoded card point
   costs, factions, ship sizes, slots, or card restrictions in GDScript.
6. UI renders `FleetValidationResult` and catalog data; it does not own rules.
7. No new PlayMode branches under `src/scenes/` or `src/ui/`.
8. Runtime game-state mutation after bootstrap goes through `GameCommand`.
9. Setup/deployment positions use normalized floats and `rotation_deg`, never
   pixels or `Vector2` in serialized payloads.
10. New `.gd` files with `class_name` require `godot --headless --import` and
    committed `.gd.uid` sidecars.
11. Gameplay effects from objectives, obstacles, and upgrades use
    `RuleRegistry`, not scene branches or ad hoc resolver special cases.
12. Any setup/game-start/network/replay slice runs baseline traces.

---

## 7. Manual Test Matrix

These are the human acceptance passes to run before committing the relevant
code-bearing slices.

| Milestone | Manual pass |
|---|---|
| Data/catalog | Open catalog UI or diagnostic output and confirm Core Set ships, squadrons, upgrades, objectives, and obstacles appear with expected points/categories. |
| Roster/validation | Build legal and illegal 180, 400, and custom fleets; confirm errors match the violated rules. |
| Import/export | Export a fleet JSON, import it as a new fleet, compare points/objectives/upgrades, and restore an older version. |
| UI MVP | Create a fleet from scratch, filter/search components, add upgrades, choose objectives, save, reload, duplicate, and delete. |
| Setup package | Select two valid fleets, choose first player/objective, and confirm invalid fleets cannot advance. |
| Deployment | Place obstacles and deploy units; confirm normalized positions survive leaving/reopening setup. |
| Start match | Start a hot-seat match from two fleets and verify correct ships/squadrons, factions, points, objective, and obstacle placements. |
| Save/load | Save immediately after deployment/start, load, and verify objective/obstacles/deployments/upgrades survive. |
| Network future | Host and client choose/confirm fleets, start game, and verify matching state hashes plus expected local visibility. |

---

## 8. Open Questions And Useful Context

1. Upgrade files are arriving under `Resources/Game_Components/upgrades/`.
  Confirm whether the current per-type subfolders are the desired long-term
  layout before FB1 locks the schema and loader behavior.
2. Confirm the exact Core Set upgrade card list to treat as the
   MVP completeness checklist.
3. Confirm whether first-player selection should be manual for MVP or derived
   from fleet bid immediately.
4. Confirm whether deployment should begin as warning-guided manual placement or
   strict hard enforcement from the first setup slice.
5. Confirm whether local fleet files should live beside saves, under a new
   `fleets/` folder, or in Godot user data only.
6. Pick a future backend direction before FB18: self-hosted API, hosted service,
   file-sync provider, or no cloud for now.

---

## 9. Suggested Next Slice

Start with FB0 and FB1 together as a docs/data-contract batch:

1. Rewrite `docs/requirements/fleet_builder.txt` into the MVP/deferred structure.
2. Update `Resources/Game_Components/README.md` for `upgrades/`, `objectives/`,
   and `obstacles/`.
3. Extend `card_data_schema.json` with the minimum fields needed by the Core Set
  data already being prepared, including the objective JSON fields in Section 4.4.
4. Add `ObjectiveData.from_dict()` and loader tests for the 12 objective JSON
  files before wiring fleet-builder objective selectors.
5. Convert `obstacles/obstacles_specs.txt` into draft obstacle JSON records or
   keep it as a source note while adding the JSON schema.

This gives later code slices a stable contract, keeps the architecture clean,
and avoids building UI or validators against moving data shapes.
