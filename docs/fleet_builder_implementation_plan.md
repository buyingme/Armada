# Fleet Builder Implementation Plan

> Status: Active roadmap
> Last updated: 2026-05-31
> Scope: local-first fleet builder, Core Set catalog completion, JSON import/export,
> fleet validation, rules-reference browsing, and setup/deployment integration
> with network-ready roster, setup, and rule contracts from the first slice that
> crosses into gameplay. Backend accounts, cloud sync, and share links remain
> deferred infrastructure.

---

## 0. Product Decisions

The first useful version is a hybrid local-first tool. It stores fleets locally,
uses native JSON import/export, and shapes its data contract so backend sync,
accounts, and share links can be added later without becoming a second source of
truth.

The important separation is local fleet-library infrastructure versus gameplay
handoff, not hot-seat versus network. Fleet drafting, local snapshots, and import
or export can be built offline-first. Any contract that enters setup, gameplay,
RuleRegistry-driven effects, replay, or save/load must be network-ready from the
first implementation: deterministic serialization, explicit player ownership,
JSON-safe state, command-backed mutations after bootstrap, and no hidden
dependency on local fleet files.

| Decision | Baseline |
|---|---|
| MVP storage | Local fleet library in project/user data, independent from game saves. |
| Exchange format | Native JSON first. PDF, CSV, and external-builder imports are later work. |
| Point formats | Standard 400, Core Set 180, and custom agreed totals. |
| Initial catalog | Existing Core Set ships/squadrons plus Core Set upgrades, objectives, and obstacles. |
| Local builder mode | Fleet drafting and the local fleet library can run without accounts, backend services, or an active network session. |
| Game integration | Full setup/deployment path for hot-seat and network handoff, not an isolated list builder. |
| Network game setup | Network lobbies must consume one expanded roster payload from the host and one from the client, validate them through the same core setup package, and confirm the same package hash before match start. |
| Rules reference | Generic rules such as squadron keywords, commands, defense tokens, obstacle rules, and setup rules are cataloged once and referenced by components; component-specific card text is cataloged beside the component and linked to implementation status. |
| Backend/auth/share links | Deferred until fleet JSON, validation, and setup packages are stable. This does not defer network game setup. |
| Rule authority | Local RRG/card JSON are implementation sources. External wiki data is manual verification only. |

---

## 1. Current Discovery

### 1.1 Component Catalog State

| Area | Current state | Plan consequence |
|---|---|---|
| Ships | `Resources/Game_Components/ships/` contains the Core Set ship JSON/art set, and `ShipData` exposes fleet-builder metadata from those records. | Keep ship facts in JSON; future catalog additions should extend metadata there rather than in validators or UI. |
| Squadrons | `Resources/Game_Components/squadrons/` contains the Core Set squadrons plus later generic Imperial entries, and `SquadronData` exposes catalog/rules metadata. | Keep Core Set completeness expectations explicit in tests and docs so extra wave data does not blur MVP gates. |
| Upgrades | `Resources/Game_Components/upgrades/` contains structured Core Set upgrade JSON and art; `UpgradeData.from_dict()` and typed loader support are implemented. | Keep validator/UI work consuming structured restriction metadata; live gameplay hooks remain later `RuleRegistry` slices. |
| Objectives | `Resources/Game_Components/objectives/` contains structured Core Set objective JSON, card art, and token/source metadata; `ObjectiveData` and loader support are implemented. | Treat objective JSON as static setup/runtime metadata until individual objectives are made live through `RuleRegistry`. |
| Obstacles | `Resources/Game_Components/obstacles/` contains Core Set obstacle JSON, art, and draft shape/setup metadata alongside source notes. | Setup/deployment validators can depend on structured obstacle data; expansion and objective-specific additions remain later catalog work. |
| Generic rules | `Resources/Game_Components/rules/` exists with the initial static rules-reference catalog for implemented squadron keywords. | Add a follow-on content slice for commands, defense tokens, setup, obstacle, attack-timing, and scoring references without duplicating generic text in component JSON. |
| Schema | `Resources/Game_Components/card_data_schema.json` now covers ships, squadrons, upgrades, objectives, obstacles, and rules-reference metadata. | Future catalog additions should extend the existing schema rather than add ad hoc loader contracts. |
| Asset loading | `src/utils/asset_loader.gd` now has typed list/load helpers for upgrades, objectives, obstacles, and rules-reference records via data-driven enumeration; `ASSET_MANIFEST` remains for shared asset validation. | Keep fleet-builder catalog discovery data-driven and avoid reintroducing per-card manifest edits outside existence checks. |
| README | `Resources/Game_Components/README.md` now documents the expanded folder layout, naming rules, and rules-reference catalog. | Keep lower_snake_case conventions and update docs when new catalog areas are added. |

### 1.2 Existing Runtime/Setup Surfaces

| Surface | Current state | Plan consequence |
|---|---|---|
| Main menu | `src/scenes/main_menu/main_menu.gd` now includes a Fleet Builder entry alongside the existing scenario-driven start flows. | Add dedicated setup-flow entry points later without moving validation or setup logic into the menu script. |
| Scenario setup | `src/core/state/learning_scenario_setup.gd` still loads scenario JSON, while shared preparation helpers now support setup-package starts. | Keep scenario bootstrap separate from package-specific setup presentation rather than folding both paths together. |
| Game bootstrap | `src/autoload/game_manager.gd` bootstraps from scenario id, loaded `GameState`, or a setup package. | Preserve separate scenario and package regression coverage instead of widening one path in place. |
| Board spawning | `src/scenes/game_board/game_board.gd` reuses the loaded-state spawn path for setup-package starts. | Further setup/deployment work should continue feeding prepared instances and placements through that shared spawn path. |
| Player state | `src/core/state/player_state.gd` stores runtime ships/squadrons/fleet points. | Do not use `PlayerState` as the editable roster model. Fleet-builder drafts need separate core classes. |
| Game state objectives | `src/core/state/game_state.gd` now serializes and deserializes `objectives`, including setup-package metadata carried into runtime state. | Extend the same JSON-safe contract when objective/obstacle runtime state grows in FB15. |
| Deployment positions | `src/models/token_placement.gd`, scenario JSON, and setup-package deployment payloads all use `pos_x`, `pos_y`, and `rotation_deg`. | Keep full-footprint validation aligned with the same normalized contract in FB13B and FB14. |
| Network lobby | `NetworkManager` can now broadcast a setup-package start in addition to scenario metadata, but roster/objective selection UI is still deferred. | Build setup-flow/lobby presentation on the same package builder and hash contract; do not invent a second network payload. |

### 1.3 Rules That Drive Validation

Implementation APIs must cite the specific rule text in doc comments. The
minimum fleet-builder rule set comes from `Resources/SWM-RULES-REFERENCE-GUIDE-150/SWM-RULES-REFERENCE-GUIDE-150.md`:

| Rule area | Source summary | First validator surface |
|---|---|---|
| Fleet points | Fleet total cannot exceed the agreed total; Standard is 400 and Core Set recommendation is 180. | `FleetValidator.validate_point_total()` |
| Faction purity | Fleet aligns with one faction and cannot include cards aligned with another faction, except dual-faction cards. | `FleetValidator.validate_faction_alignment()` |
| Objectives | Each player chooses three objectives, one per category: Assault, Defense, Navigation. | `FleetValidator.validate_objectives()` |
| Play area maps | Core Set/180-point matches use 3' x 3' maps; 300- and 400-point matches use 3' x 6' maps. Map size is derived from the `map_3x3...` or `map_3x6...` filename prefix. | `FleetValidator.validate_map_selection()` |
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
systems: static catalog data, editable roster state, and match setup state. The
first two can be local/offline. Match setup is gameplay infrastructure and must
be valid for hot-seat, network, replay, and save/load from the beginning.
Blending those systems would violate existing project boundaries and make
save/load or network setup fragile.

### 2.1 Required Boundaries

| Boundary | Compliant design | Non-compliant drift to avoid |
|---|---|---|
| Static catalog | `Resources/Game_Components/*` JSON plus `src/models/*Data.gd` resources. | Hardcoded card points, factions, slots, or restrictions in UI or validators. |
| Editable roster | New `src/core/fleet/` `RefCounted` classes such as `FleetRoster` and `FleetShipEntry`. | Reusing `PlayerState` as a mutable builder draft. |
| Fleet validation | Pure core validator returning `FleetValidationResult`. UI renders result messages and disabled states. | Scenes/UI deciding faction, point, upgrade, objective, or uniqueness legality. |
| Local library | Application service that reads/writes fleet JSON files and versions. | Mixing fleet library files with save-game state or scenario JSON. |
| Setup package | Serializable package containing two validated rosters, selected objective, obstacles, first player, and normalized deployments. The same package is the hot-seat, network, replay, and bootstrap handoff contract. | Passing loose dictionaries through menu/board code without a versioned contract. |
| Network setup contract | Match-ready packages embed full roster payloads, explicit player indices, and deterministic canonical serialization/hash data before game start. | Building a hot-seat-only setup path first and inventing a second network package later. |
| Game state mutation | Bootstrap creates initial `GameState` from a setup package before gameplay; interactive setup after state creation uses commands. | Scene code directly mutating `GameState` during setup/deployment. |
| Rule hooks | Gameplay effects from upgrades, objectives, and obstacles go through `RuleRegistry` under `src/core/effects/rules/`. | Special-case card effects in validators, scenes, or board controllers. |
| Rules reference | Static rules-reference JSON provides browsable text, source refs, tags, and implementation status. Components link to it via `rules_reference_ids`; generic rule text is not copied into each card. | Keeping separate rule text copies in squadron/card JSON or deriving UI reference text from `RuleRegistry` internals. |
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
| `src/scenes/setup_flow/` | New-game setup coordinator for hot-seat and network package confirmation once the core setup contract exists. |
| `src/ui/fleet_builder/` | Reusable catalog, roster, validation, and library widgets if the scene needs extraction. |
| `Resources/Game_Components/upgrades/` | Upgrade JSON and card art. |
| `Resources/Game_Components/objectives/` | Objective JSON and card art. |
| `Resources/Game_Components/obstacles/` | Obstacle JSON, shape metadata, and art. |
| `Resources/Game_Components/rules/` | Generic and component-specific rules-reference JSON used by search, help, validators, and implementation tracking. |

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
| FB-REQ-002 | A fleet has name, description, faction, point format, point limit, map, ships, squadrons, upgrades, and three objectives. |
| FB-REQ-003 | Supported point formats are Standard 400, Core Set 180, and custom agreed totals. |
| FB-REQ-004 | The catalog supports search/filter by faction, component type, point cost, upgrade slot/type, wave, expansion, keywords, and search tags. |
| FB-REQ-005 | The builder calculates total points, ship points, squadron points, and upgrade points continuously. |
| FB-REQ-006 | The builder validates point total, faction purity, flagship/commander, squadron cap, unique limits, objective categories, and upgrade legality. |
| FB-REQ-007 | The builder imports and exports native versioned JSON. |
| FB-REQ-008 | The local library stores multiple versions/snapshots per fleet and can restore an older version. |
| FB-REQ-009 | Two valid fleets can be passed into setup, objective selection, obstacle/deployment placement, and match start. |
| FB-REQ-010 | Setup/deployment positions serialize as normalized `pos_x`, `pos_y`, and `rotation_deg`. |
| FB-REQ-011 | Save/load after setup preserves selected objective, obstacles, deployments, fleet points, ships, squadrons, and upgrade assignments. |
| FB-REQ-012 | The fleet builder includes a Rules Reference section where users can browse generic game rules and component-specific rules from the same catalog used by validators and implementation tracking. |
| FB-REQ-013 | Network setup consumes the host and client's expanded fleet rosters through the same setup package contract used by hot-seat setup; the host validates it and both peers confirm the same package hash before match start. |
| FB-REQ-014 | Rule integration for objectives, upgrades, obstacles, squadron abilities, and setup effects is hot-seat, replay, save/load, and network safe from the slice that makes the rule live. |
| FB-REQ-015 | Fleet maps are selected from separate filename-prefixed pools: `map_3x3...` for 180-point matches and `map_3x6...` for 300- and 400-point matches. Setup uses the first player's roster map. |

### 3.2 Deferred Requirements

| Area | Deferred until | Notes |
|---|---|---|
| User accounts/auth | After local JSON and setup package are stable. | Backend should sync the same fleet JSON contract, not invent a second format. |
| Share links/codes | After backend direction is chosen. | Local export/import covers immediate sharing. |
| PDF/CSV export | After native JSON MVP. | Useful, but not needed for game start integration. |
| External builder import | After local schema stabilizes. | Add adapters rather than weakening the native schema. |
| Full non-Core catalog | After Core Set validation and setup flow are proven. | Add waves/expansions incrementally with schema tests. |
| Strict tournament rules | Later rules pack. | MVP validates core rules and custom agreed point totals. |

Network fleet setup is not a deferred requirement. The network UI can arrive in
a later presentation slice, but the roster, validation, setup package, runtime
state, and rule-effect contracts must be shaped so network consumption is always
available without refactoring the core model.

### 3.3 Requirement Additions

- Define the fleet JSON schema and setup package schema explicitly.
- Define canonical serialization/hash rules for match-ready setup packages.
- Define data-source policy for card text, errata, and local verification.
- Define how the network lobby maps host/client peers to setup package
  `player_index` values without storing transport-specific peer ids in core
  setup JSON.
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
  "map": {
    "filename": "map_3x3_distant_planet_v3.jpg",
    "grid": "3x3",
    "label": "3x3 Distant Planet"
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
- Map size is derived from the selected filename prefix. The `grid` and `label`
  fields are convenience metadata and must stay consistent with `filename`.
- Local fleet ids are storage conveniences. A match-ready setup package must be
  able to embed the full roster payload so network peers and replays do not need
  access to another machine's local fleet library.
- Roster serialization used for setup-package hashing must be deterministic:
  stable array ordering, stable dictionary keys where practical, and no volatile
  local-only timestamps in the canonical hash payload.

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
  "map": {
    "filename": "map_3x6_distant-planet_v4.jpg",
    "grid": "3x6",
    "label": "3x6 Distant Planet"
  },
  "first_player": 0,
  "players": [
    {
      "player_index": 0,
      "roster": {
        "format_version": 1,
        "kind": "fleet_roster",
        "fleet_id": "fleet-a",
        "name": "Opening Salvo Rebels",
        "faction": "REBEL_ALLIANCE",
        "point_format": {
          "id": "STANDARD_400",
          "limit": 400
        },
        "ships": [
          {
            "entry_id": "rebel-ship-1",
            "data_key": "cr90_corvette_a",
            "upgrades": []
          }
        ],
        "squadrons": [
          {
            "entry_id": "rebel-squadron-1",
            "data_key": "x_wing_squadron"
          }
        ],
        "objectives": {
          "ASSAULT": "obj_ass_advanced_gunnery",
          "DEFENSE": "obj_def_contested_outpost",
          "NAVIGATION": "obj_nav_superior_positions"
        }
      },
      "faction": "REBEL_ALLIANCE"
    },
    {
      "player_index": 1,
      "roster": {
        "format_version": 1,
        "kind": "fleet_roster",
        "fleet_id": "fleet-b",
        "name": "Victory At Kuat",
        "faction": "GALACTIC_EMPIRE",
        "point_format": {
          "id": "STANDARD_400",
          "limit": 400
        },
        "ships": [
          {
            "entry_id": "imperial-ship-1",
            "data_key": "victory_ii_class_star_destroyer",
            "upgrades": []
          }
        ],
        "squadrons": [
          {
            "entry_id": "imperial-squadron-1",
            "data_key": "tie_fighter_squadron"
          }
        ],
        "objectives": {
          "ASSAULT": "obj_ass_opening_salvo",
          "DEFENSE": "obj_def_fleet_ambush",
          "NAVIGATION": "obj_nav_minefields"
        }
      },
      "faction": "GALACTIC_EMPIRE"
    }
  ],
  "selected_objective": {
    "data_key": "obj_ass_opening_salvo",
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
      "roster_entry_id": "rebel-ship-1",
      "pos_x": 0.50,
      "pos_y": 0.82,
      "rotation_deg": 0.0
    }
  ]
}
```

Rules:
- Local setup drafts can reference `fleet_id`s while the user is choosing
  fleets. A match-ready package always embeds full rosters before validation,
  network exchange, replay capture, or game start.
- All placements use normalized coordinates.
- Setup package validation must run before it is converted to `GameState`.
- The setup package map is copied from the first player's embedded roster and is
  included in the canonical package hash because play-area size affects setup,
  deployment, and movement geometry.
- Network setup maps peers to `player_index` outside the core package. Core
  setup JSON stores player indices and owner fields, not transport-specific peer
  ids.
- Host and client must be able to compute or receive the same canonical package
  hash before bootstrap. The hash payload excludes local library metadata and
  timestamps that do not affect gameplay.
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
| `rules_reference_ids` | cards/components with rules | Links to generic or component-specific rules-reference records. Generic rules such as squadron keywords are referenced here instead of being duplicated per card. |
| `rules_integration` | cards/components with live gameplay rules | Tracks `status`, implemented `RuleRegistry` rule ids, pending surfaces, and notes. Status values are `NOT_INTEGRATED`, `PARTIAL`, and `INTEGRATED`. |

### 4.4 Rules Reference Catalog

The fleet builder needs a user-facing Rules Reference view, and the codebase
needs one source of truth for generic rule text. The plan is to add static
rules-reference JSON under `Resources/Game_Components/rules/` and have cards,
validators, UI help, and `RuleRegistry` implementation tracking point to those
records.

Generic examples include squadron keywords, command rules, defense-token rules,
obstacle rules, setup/deployment rules, attack timing, and scoring rules.
Component-specific examples include a named upgrade, objective, title, ace
ability, or damage card effect.

Example shape:

```json
{
  "data_key": "squadron_keyword.bomber",
  "kind": "rules_reference",
  "scope": "GENERIC",
  "display_name": "Bomber",
  "category": "SQUADRON_KEYWORD",
  "rules_text": "While attacking a ship, each of your critical icons adds 1 damage to the damage total and you can resolve a critical effect.",
  "summary": "Critical icons count as damage and can resolve critical effects during ship attacks.",
  "search_tags": ["squadron", "keyword", "bomber", "critical"],
  "source_refs": ["RRG 1.5.0 Squadron Keywords"],
  "implemented_rule_ids": ["squadron_keyword.bomber"],
  "implementation_status": "INTEGRATED"
}
```

Component JSON uses `rules_reference_ids` to link to these records:

```json
{
  "data_key": "x_wing_squadron",
  "rules_reference_ids": [
    "squadron_keyword.bomber",
    "squadron_keyword.escort"
  ],
  "rules_integration": {
    "status": "INTEGRATED",
    "implemented_rule_ids": [
      "squadron_keyword.bomber",
      "squadron_keyword.escort"
    ],
    "pending_rule_surfaces": [],
    "notes": "Generic squadron keyword rules are implemented through RuleRegistry."
  }
}
```

Rules:
- Generic rule text is authored once in `Resources/Game_Components/rules/` and
  referenced by cards/components through `rules_reference_ids`.
- Existing duplicate fields such as `keyword_reminder_text` are transitional
  compatibility data. The fleet-builder UI should prefer the rules-reference
  catalog once loaders exist.
- `RuleRegistry` remains the gameplay implementation authority. Rules-reference
  records expose implementation status and matching rule ids, but they are not
  executable code.
- When a component-specific rule is implemented later, the rule slice updates
  that component's `rules_integration` from `NOT_INTEGRATED` or `PARTIAL` to
  `INTEGRATED` and records the exact `RuleRegistry` ids.

### 4.5 Objective Card JSON

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
  "rules_reference_ids": ["objective.obj_nav_superior_positions"],
  "rules_integration": {
    "status": "NOT_INTEGRATED",
    "implemented_rule_ids": [],
    "pending_rule_surfaces": ["attack.after_performed"],
    "notes": "Static catalog metadata only; gameplay rule integration is deferred to RuleRegistry."
  },
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
`rules_reference_ids`, `rules_integration`, `setup_effects`, `rule_surfaces`,
`objective_tokens`, `errata`, and `clarifications` as JSON-safe arrays/
dictionaries until individual objectives are implemented through typed rule
classes.

### 4.6 Codebase Readiness And Risk Assessment

The codebase is now through FB13A: requirements, catalog contracts, typed
loaders, editable roster state, local library/import-export UI, setup-package
building, runtime conversion/bootstrap, and first-pass rectangular runtime
support are in place. The remaining fleet-builder risk has shifted from
catalog/bootstrap creation to full-footprint geometry hardening, setup-flow
presentation layering, placement validators, save/load expansion, and live
`RuleRegistry` effects.

Current strengths:
- Typed catalog models and loader enumeration exist for ships, squadrons,
  upgrades, objectives, obstacles, and rules-reference records.
- The local fleet-builder scene and library workflows exist, so later slices
  can build on established roster/catalog/validator APIs instead of inventing
  new ones.
- Setup-package building, canonical hashing, runtime conversion, bootstrap, and
  network setup-package broadcast paths exist for hot-seat and network starts.
- `GameState.objectives` now serializes, and setup-package map/objective
  metadata already survives into runtime bootstrap.
- Existing rectangular play-area tests already cover board width/height
  handling across `GameScale`, overlays, camera, and setup-package starts.
- `RuleRegistry`, `FlowSpec`, `CommandApplicability`, `UIProjector`, and the
  command processor provide the correct architecture for later objective,
  obstacle, upgrade, and named squadron ability rules.

Current weaknesses:
- `AssetLoader` still carries a hardcoded validation manifest for shared asset
  existence. Keep fleet-builder discovery on the data-driven list/load helpers
  and avoid reintroducing per-card manifest edits.
- `TokenMover` and setup deployment application still operate on token centers
  rather than full base footprints, so FB14 would inherit false-positive legal
  placements without FB13B.
- `src/scenes/setup_flow/` still does not exist. First-player selection,
  objective choice, and package confirmation need a thin presentation slice
  before placement UI grows around them.
- The static rules-reference catalog currently covers the implemented squadron
  keywords only; commands, defense tokens, setup, obstacle, attack-timing, and
  scoring records remain content work.
- Setup/deployment validators for obstacle placement, deployment zones, and
  full-base bounds do not exist yet.
- `GameBoard` still owns too much setup translation and token registration
  detail. Adding fleet setup directly there would increase coupling and make
  network/replay regressions harder to isolate.
- Several large files are already beyond normal refactoring thresholds,
  including `game_manager.gd`, `game_board.gd`, `attack_executor.gd`, and
  `save_game_manager.gd`. New fleet-builder behavior should go into focused
  helpers instead of growing those files further.

Slice risk assessment:

| Slice | Risk | Main reason |
|---|---|---|
| FB0 | Low | Docs and requirements only. |
| FB1 | Medium | Schema and folder contracts affect every later loader and catalog test. |
| FB2 | Medium-high | Loader enumeration and new models touch shared asset-loading behavior. |
| FB2.5 | Medium | Refactoring existing setup paths is sensitive, but it reduces later network/bootstrap risk. |
| FB3 | Medium | Large catalog ingestion can create schema drift or stale rule-status markers. |
| FB4 | Medium | Roster serialization must stay distinct from runtime `PlayerState`. |
| FB5 | Medium | Catalog queries must stay deterministic and UI-independent. |
| FB6 | Medium | Validator messages become a shared UI/import/setup contract. |
| FB7 | High | Upgrade slot and restriction legality has many card-data edge cases. |
| FB8 | Medium | Local file persistence can be kept isolated from save-game state. |
| FB9 | High | UI can easily accumulate validation or PlayMode logic if core APIs are incomplete. |
| FB10 | Medium | Library UI is moderate risk if it remains a thin wrapper over tested services. |
| FB11 | High | Setup package hashing, embedded rosters, objective choice, and host/client identity must align. |
| FB12 | High | Roster-to-instance conversion crosses catalog, setup, runtime state, and board placement. |
| FB13 | Critical | Game bootstrap affects hot-seat, network, loaded state, board spawning, RNG, and traces. |
| FB13A | High | Rectangular runtime support touches movement, camera, overlays, and board-start regressions. |
| FB13B | High | Full-footprint clamping must align runtime drag/push-out behavior with later setup validators and bootstrap. |
| FB13C | Medium-high | Setup-flow UI must stay thin over validated package builders and not absorb placement logic before FB14. |
| FB14 | High | Deployment/obstacle placement must choose package mutation or command-backed mutation cleanly. |
| FB15 | High-critical | New runtime state must serialize, filter, replay, save/load, and network-mirror correctly. |
| FB16 | Critical | Live objective, obstacle, upgrade, and named ability rules touch command legality and UI eligibility. |
| FB17 | High | Network UX must not invent a second setup contract or bypass validation. |
| FB18 | Medium-high | Backend sync is manageable only after the local JSON contract is stable. |

Action advice for high and critical items:
- FB7: implement upgrade legality in pure validator APIs first. Cover slot,
  duplicate, title, modification, commander, faction, size, ship-name, and
  missing-metadata cases before any UI depends on the results.
- FB9: build the scene only after roster, catalog, and validator APIs are
  stable enough for the UI to be a renderer/controller. Use mocked services in
  UI tests and keep all legality decisions in core.
- FB11: define canonical package hashing before lobby UI work. Match-ready
  packages must embed both expanded rosters, explicit player indices, selected
  objective ownership, setup state, and no local-only timestamps or file ids in
  the hash payload.
- FB12: extract roster-to-instance conversion into a core setup helper that
  preserves owner player, data key, roster entry id, fleet points, and placement
  identity. It must depend only on the embedded setup package and static
  catalog, never a local fleet library.
- FB13: add a dedicated setup-package bootstrap entry point instead of widening
  scenario-only paths in place. Keep scenario bootstrap tests green, add
  setup-package bootstrap tests, and require baseline traces once network or
  replay state is affected.
- FB13B: replace center-only play-area clamping with footprint-aware ship and
  squadron bounds shared by drag and push-out logic. Add rectangular edge,
  corner, and rotated-base regressions before placement validators depend on
  the same contract.
- FB13C: build a thin `src/scenes/setup_flow/` coordinator for roster
  selection, first-player selection, objective choice, package summary/hash
  confirmation, and validation rendering. Keep obstacle and deployment
  placement out of this slice so FB14 stays about placement semantics.
- FB14: decide whether placement edits mutate the pre-bootstrap setup package
  or use `GameCommand`s after `GameState` exists. Do not let scene code mutate
  authoritative setup or runtime state directly.
- FB15: add serialization for selected objective, obstacle placements/state,
  objective tokens, objective ships, victory tokens, set-aside units, and
  upgrade assignments in the same slice that introduces them. Update
  `StateFilter` for any player-specific visibility.
- FB16: treat every live card/objective/obstacle/named ability rule as a
  `RuleRegistry` integration slice. Cover marker commands, mutation commands,
  `FlowSpec`, projected UI eligibility, save/load rebuild, replay determinism,
  and network mirror behavior before marking catalog status `INTEGRATED`.
- FB17: build network setup presentation only on top of the same setup package
  and validators already proven by hot-seat and core tests. Package-hash
  mismatch, invalid remote roster, and resume/rejoin states must be explicit UI
  states, not hidden lobby assumptions.

---

## 5. Implementation Slices

Each slice should be small enough to finish with targeted tests and a clear exit
condition. Code-bearing slices must not be committed until the relevant manual
test gate is passed.

Status note:
- `Complete` means the code and listed automated/manual gates are finished.
- `In progress` means a slice has started and some scoped code or validation has landed, but the slice still has remaining planned work.
- `Implemented` means code and automated checks landed, but at least one listed manual gate still remains.
- `Planned` means the slice has not started.

### FB0 - Requirements And Source Inventory

| Field | Plan |
|---|---|
| Goal | Turn `docs/requirements/fleet_builder.txt` into implementation-ready MVP/deferred requirements. |
| Scope | Requirements rewrite, Core Set card inventory checklist, data-source policy, network-ready setup contract, first-player/deployment assumptions, non-goals. |
| Primary files | `docs/requirements/fleet_builder.txt`, this plan, possibly `docs/arc42/01_introduction_and_goals.md`. |
| Acceptance | Requirements contain MVP/deferred split, JSON/import-export requirement, point formats, objective/deployment integration, network setup consumption from host/client fleets, rule-integration network safety, and backend/auth deferral. |
| Verification | `git diff --check`. |
| Status | Complete as of 2026-05-26 in `docs/requirements/fleet_builder.txt`; continue with FB1 before source implementation. |

### FB1 - Component Folder And Schema Contract

| Field | Plan |
|---|---|
| Goal | Make the static catalog structure explicit before loader/model code changes. |
| Scope | Add or normalize `upgrades/`, `objectives/`, `obstacles/`, and `rules/`; update `Resources/Game_Components/README.md`; extend `card_data_schema.json` definitions for metadata, upgrades, objectives, obstacles, rules-reference records, `rules_reference_ids`, and `rules_integration`. Objective schema must cover `setup_effects`, `rule_surfaces`, `objective_tokens`, `runtime_state_requirements`, `victory_token_points`, `task_force_recommended`, `errata`, and `clarifications`. |
| Primary files | `Resources/Game_Components/README.md`, `Resources/Game_Components/card_data_schema.json`, `Resources/Game_Components/obstacles/`, `Resources/Game_Components/rules/`. |
| Acceptance | Schema can express Core Set upgrade/objective/obstacle records and generic rules-reference records; README lists the new folders; objective schema validates all 12 Core Set objective JSON files; every objective/upgrade with pending gameplay text has `rules_integration.status = "NOT_INTEGRATED"`; generic squadron keyword records map to existing `RuleRegistry` rule ids; no PascalCase or space-containing folder names. |
| Tests | Add schema-validation tests or a small Godot test helper that loads sample JSON and reports schema/required-field failures. |
| Verification | `godot --headless --import`, targeted schema/loader tests, `git diff --check`. |
| Status | Complete as of 2026-05-26: component README refreshed, schema expanded, rules-reference folder added, implemented squadron keyword reference records added, and schema contract GUT coverage added. |

### FB2 - Static Data Models And Loaders

| Field | Plan |
|---|---|
| Goal | Give the catalog typed loading support without hardcoded per-card manifests. |
| Scope | Complete `UpgradeData.from_dict()`, add `ObjectiveData`, `ObstacleData`, and `RuleReferenceData`, add typed `AssetLoader` load/list helpers, and add data-driven enumeration with `DirAccess`. |
| Primary files | `src/models/upgrade_data.gd`, new `src/models/objective_data.gd`, new `src/models/obstacle_data.gd`, new `src/models/rule_reference_data.gd`, `src/utils/asset_loader.gd`. |
| Acceptance | Tests can list and load ships, squadrons, upgrades, objectives, obstacles, and rules-reference records by key; card/component loaders expose `rules_reference_ids` and `rules_integration`; missing/invalid JSON produces clear failures without crashing. |
| Tests | Model parsing tests, loader enumeration tests, invalid/missing asset tests, rules-reference resolution tests. |
| Verification | `godot --headless --import`, targeted GUT, full GUT if `AssetLoader` behavior changes broadly, `bash scripts/lint_phase_k.sh`. |
| Status | Complete as of 2026-05-26: `UpgradeData.from_dict()` added, objective/obstacle/rules-reference data resources added, `AssetLoader` can enumerate and load catalog records by key without per-card manifest entries, and focused parser/loader GUT coverage added. |

### FB2.5 - Setup Contract Extraction And Canonical Hash

| Field | Plan |
|---|---|
| Goal | Reduce setup, bootstrap, and network risk before any fleet-builder scene or game-start integration depends on new roster data. |
| Scope | Add a shared canonical JSON/hash helper for deterministic setup payloads; define a setup-package shell that can hash embedded roster payloads even before the full setup UI exists; extract testable scenario/setup preparation from `GameBoard` into core setup helpers while keeping visual token spawning in presentation; preserve the current scenario start path. |
| Primary files | New `src/core/setup/*` helpers, possible `src/utils/canonical_json.gd`, focused extraction points in `src/scenes/game_board/game_board.gd`, tests under `tests/unit/core/setup/` or the existing unit layout. |
| Acceptance | Learning scenario bootstrap still behaves the same; setup preparation can be tested without a scene tree; equivalent setup payloads hash identically across repeated runs; the setup package shell has no dependency on local fleet-library files; existing loaded-state spawning remains intact. |
| Tests | Canonical hash stability, setup-package shell round trip, scenario preparation parity, missing data rejection, loaded-state spawn regression if touched. |
| Verification | `godot --headless --import` if new scripts are added, targeted GUT, full GUT and `bash scripts/lint_phase_k.sh` if board or game-manager code changes, `git diff --check`. |
| Status | Complete as of 2026-05-26: `CanonicalJson` added and shared by baseline traces, `FleetSetupPackage` added with embedded-roster hashing and basic validation, Learning Scenario preparation extracted from `GameBoard` into `LearningScenarioPreparer`, and focused GUT coverage added. |

### FB3 - Core Set Data Ingestion

| Field | Plan |
|---|---|
| Goal | Convert the prepared upgrade/objective/obstacle information into validated catalog JSON. |
| Scope | Add Core Set upgrade JSON/art references, objective JSON/art references, obstacle JSON/shape metadata, rules-reference ids, rules-integration markers, and metadata for existing Core Set ships/squadrons. Add initial generic rules-reference records for squadron keywords that already have `RuleRegistry` implementations. |
| Primary files | `Resources/Game_Components/upgrades/`, `Resources/Game_Components/objectives/`, `Resources/Game_Components/obstacles/`, `Resources/Game_Components/rules/`, existing ship/squadron JSON. |
| Acceptance | All Core Set cards/components needed for 180-point fleets are loadable; all 12 Core Set objective JSON files exist and declare 4 Assault, 4 Defense, and 4 Navigation cards; every objective points to card art and a source note; each upgrade JSON declares faction/slot/category/restriction fields needed by validators; objectives/upgrades are marked `NOT_INTEGRATED`; generic keyword-only squadron records resolve to integrated keyword rule ids; unique ace abilities without rule files are marked `PARTIAL`. |
| Tests | Catalog completeness tests for expected Core Set keys; parser tests for representative upgrade/objective/obstacle restrictions; objective category-count tests; rules-reference id resolution tests. |
| Verification | `godot --headless --import`, targeted data tests, `git diff --check`. |
| Status | Complete as of 2026-05-27: Core Set obstacle JSON records added for three asteroids, two debris fields, and the station; loader and catalog contract tests now cover obstacle discovery, parsing, setup constraints, draft shape metadata, and `NOT_INTEGRATED` rule status. |

### FB4 - Serializable Fleet Roster Model

| Field | Plan |
|---|---|
| Goal | Add editable fleet-builder state separate from runtime `PlayerState`. |
| Scope | Create `FleetRoster`, `FleetShipEntry`, `FleetSquadronEntry`, `FleetUpgradeAssignment`, `FleetObjectiveSelection`, and `FleetValidationResult` in `src/core/fleet/`. |
| Primary files | New `src/core/fleet/*.gd`, tests under `tests/unit/core/fleet/`. |
| Acceptance | Roster create/add/remove/update APIs are typed, documented, JSON-safe, deterministic when canonicalized for setup hashing, and round-trip through `serialize()`/`deserialize()`. |
| Tests | Empty roster, populated roster, upgrade assignment, objective selection, unknown future fields/defaults, duplicate entry ids, canonical serialization stability. |
| Verification | `godot --headless --import`, targeted GUT, full GUT if shared state classes are touched, `bash scripts/lint_phase_k.sh`. |
| Status | Complete as of 2026-05-27: added `src/core/fleet/` roster payload classes with typed add/remove/update APIs, deterministic entry ordering, JSON-safe round trips, objective selection, upgrade assignment, and structured validation-result payload tests. |

### FB5 - Fleet Catalog Queries

| Field | Plan |
|---|---|
| Goal | Provide search/filter primitives for UI and validators. |
| Scope | Add `FleetCatalog` query helper over `AssetLoader` lists with filters for faction, component type, point cost range, upgrade slot/type, wave, expansion, keyword, rules-reference category, implementation status, and text tags. |
| Primary files | New `src/core/fleet/fleet_catalog.gd`, loader/model tests. |
| Acceptance | Queries are deterministic, sorted consistently, and return catalog keys plus typed data resources without UI dependencies; component results can resolve linked generic/component-specific rules for display. |
| Tests | Filter combinations, empty results, case-insensitive text search, stable sort, missing metadata defaults, rules-reference lookup by component and by generic rule category. |
| Verification | Targeted GUT, `bash scripts/lint_phase_k.sh`. |
| Status | Complete as of 2026-05-27: added `FleetCatalog` with deterministic component queries over `AssetLoader` lists, metadata filters (faction/type/points/upgrade type/wave/expansion/keyword/rules category/status/text/tag), and linked rules-reference lookups for component and category views. |

### FB6 - Fleet Validator Baseline Rules

| Field | Plan |
|---|---|
| Goal | Enforce construction rules that do not require detailed upgrade restrictions yet. |
| Scope | Add `FleetValidator` APIs for point total, faction alignment, commander/flagship count, squadron one-third cap, unique names, unique squadron limit, and three objective categories. |
| Primary files | New `src/core/fleet/fleet_validator.gd`, `fleet_validation_result.gd`, tests. |
| Acceptance | Validator returns structured JSON-safe errors/warnings with rule ids, affected roster entry ids, source references, severity, and deterministic ordering for UI, import/export, and network setup rejection. |
| Tests | Legal 180/400/custom fleets, over-limit fleets, mixed faction, zero/two commanders, excessive squadron points, duplicate unique names, invalid objective sets. |
| Verification | Targeted GUT, full GUT if validator touches shared models, `bash scripts/lint_phase_k.sh`. |
| Status | Complete as of 2026-05-27 and extended on 2026-05-30: added `FleetValidator` baseline rules for point limit, faction alignment, commander/flagship count, one-third squadron cap, unique upgrade/squadron limits, objective-category validation, and filename-driven map size validation with deterministic `FleetValidationResult` issue payloads. |

### FB7 - Upgrade Assignment Validation

| Field | Plan |
|---|---|
| Goal | Validate upgrade slots and restriction traits using static catalog data. |
| Scope | Add slot matching, multi-icon groups if present in data, duplicate upgrade per ship, one title, one modification, faction/size/ship-name/ship-icon/title/flagship restrictions, and flotilla commander restriction once flotilla metadata exists. |
| Primary files | `src/core/fleet/fleet_validator.gd`, `UpgradeData`, upgrade JSON. |
| Acceptance | Illegal upgrades are blocked by validator and exposed as structured `FleetValidationResult` entries; UI later can render the same entries. |
| Tests | Matching/mismatched slot, duplicate same upgrade on one ship, commander on non-flotilla, title mismatch, modification limit, faction and size restrictions. |
| Verification | Targeted GUT, full GUT, `bash scripts/lint_phase_k.sh`. |
| Status | Complete as of 2026-05-27: `FleetValidator` now enforces upgrade slot matching/index occupancy, duplicate-upgrade-per-ship rejection, per-ship TITLE and Modification singleton limits, and metadata-driven size/ship-class/ship-data-key restrictions with deterministic `FleetValidationResult` rule ids. |

### FB8 - Fleet JSON Import/Export And Local Library

| Field | Plan |
|---|---|
| Goal | Persist local fleets independently from game saves. |
| Scope | Add `FleetLibraryManager` or equivalent application service for save/list/load/delete/duplicate/version/restore; add import/export helpers for the versioned fleet JSON contract. |
| Primary files | New service under `src/autoload/` only if singleton behavior is needed, otherwise `src/core/fleet/` plus a thin scene controller; tests under unit/integration. |
| Acceptance | Library can save multiple fleets, create version snapshots, restore older versions, reject invalid JSON with readable errors, preserve unknown future fields where practical, and export rosters in the same shape consumed by match-ready setup packages. |
| Tests | Save/load/delete/list, version restore, invalid JSON, format migration/defaults, import/export round trip. |
| Verification | Targeted GUT, full GUT if adding autoload, `bash scripts/lint_phase_k.sh`. |
| Status | Complete as of 2026-05-27: added `FleetLibraryManager` under `src/core/fleet/` with file-backed save/list/load/delete/duplicate/version/restore APIs plus import/export helpers for the FB8 JSON contract, readable parse/schema errors, and unknown-field preservation through import/export round trips. |

### FB9 - Fleet Builder Scene MVP

| Field | Plan |
|---|---|
| Goal | Add an integrated UI for building and validating a fleet. |
| Scope | Add menu entry, fleet header, point/status strip, catalog/search/filter panel, selected ships with upgrade slots, squadron list, objective selectors, validation panel, and a Rules Reference section/tab. |
| Primary files | `src/scenes/fleet_builder/fleet_builder.tscn`, `src/scenes/fleet_builder/fleet_builder.gd`, extracted `src/ui/fleet_builder/*` widgets as needed, `src/scenes/main_menu/main_menu.gd`. |
| Acceptance | User can create a local draft, add/remove ships/squadrons/upgrades/objectives, see live point totals and validation errors, browse generic rules, open a component's specific rules from the catalog/roster, and return to main menu. |
| Architecture gate | UI only calls catalog/roster/validator/library APIs. It does not implement fleet rules and adds no PlayMode branches. |
| Tests | UI construction, search/filter interaction, add/remove flows, validation rendering, rules-reference browsing/navigation, no orphan/leak warnings. |
| Verification | Focused UI GUT, full GUT, `bash scripts/lint_phase_k.sh`, manual create/edit invalid/legal fleet and rules-reference browsing pass. |
| Status | Complete as of 2026-05-31: added the local fleet-builder scene, menu entry, core-backed draft mutation and option helpers, live point/validation rendering, catalog search with grouped upgrade-type filtering, one component-add action, roster objective editing with selected-objective inspection, map selection below objectives with point-format filtering, a Standard reference tab for selected component card rules plus validation, filtered rules-reference browsing, and a Card Art tab for the selected component. The manual UI pass for create/edit invalid/legal fleets and rules-reference browsing is complete. |

### FB10 - Library, Import, Export, And Version UI

| Field | Plan |
|---|---|
| Goal | Make local fleet management usable from the scene. |
| Scope | Add open/save-as/duplicate/delete/version restore/import/export controls and confirmation/error states. |
| Primary files | Fleet builder scene/widgets, `FleetLibraryManager`. |
| Acceptance | User can manage multiple fleets, export JSON, import JSON, and restore an older local version from UI. |
| Tests | Button flows with mocked library, invalid import display, version restore rendering, no orphan/leak warnings. |
| Verification | Focused UI GUT, full GUT, `bash scripts/lint_phase_k.sh`, manual import/export/version pass. |
| Status | Complete as of 2026-05-31: added a reusable `FleetLibraryPanel` under the Fleet Data → Fleets tab with extracted action/view/list helpers, save/open/save-as/duplicate/delete confirmation, version restore, and import/export JSON controls; scene load/restore/import actions replace the active draft roster and rebuild local entry counters. The manual import/export/version pass is complete. |

### FB11 - Setup Package Model, Objective Choice Flow, And Network Contract

| Field | Plan |
|---|---|
| Goal | Bridge two validated rosters into a deterministic pre-game setup package usable by hot-seat, network, replay, and bootstrap paths. |
| Scope | Add `FleetSetupPackage`, `SetupValidationResult`, first-player selection, objective choice from second player's objectives, package serialization, canonical package hashing, match-ready expansion from local fleet ids to full roster payloads, host/client player-index mapping rules, and setup-state scaffolding derived from `ObjectiveData.setup_effects`. |
| Primary files | New `src/core/setup/*.gd`; setup flow scene/controller skeleton remains deferred to FB13C and FB14. |
| Acceptance | Two valid fleets produce a match-ready setup package; invalid rosters cannot start setup; selected objective records owner/chosen-by player; the first player's roster map is copied into the package; objective setup requirements such as objective ships, objective token placements, set-aside units, and deployment-order overrides are represented as JSON-safe setup state; a package containing one host roster and one client roster can be validated and hashed identically on both peers before game start. |
| Tests | Package round trip, invalid fleet rejection, objective choice ownership, first-player persistence, representative objective setup-state extraction, local-id expansion to embedded rosters, host/client package equality, canonical hash stability. |
| Verification | `godot --headless --import`, targeted GUT, full GUT, `bash scripts/lint_phase_k.sh`, `bash scripts/run_baseline_traces.sh --all` once the package can bootstrap or mirror network state. |
| Status | Implemented as of 2026-05-30: extended `FleetSetupPackage` with JSON-safe setup state and first-player map payload, added `SetupValidationResult`, and added `FleetSetupPackageBuilder` for validated two-roster packages, local fleet-id expansion, objective ownership/chosen-by metadata, objective setup-effect scaffolding, and host/client roster-to-player mapping without peer ids in core JSON. Setup-flow presentation and placement UI remain in FB13C-FB14. |

### FB12 - Roster To Runtime Instance Conversion

| Field | Plan |
|---|---|
| Goal | Convert setup-package roster entries into `ShipInstance` and `SquadronInstance` arrays using the same static data loading rules as scenarios. |
| Scope | Add `FleetRosterSetupHelper` or `RosterInstanceFactory`; extract common instance creation from `LearningScenarioSetup`/board code if needed; carry upgrade assignments into runtime state once runtime upgrade state exists. |
| Primary files | `src/core/setup/fleet_roster_setup_helper.gd`, `src/core/state/*` if runtime upgrade assignments must serialize, `src/scenes/game_board/game_board.gd` extraction points. |
| Acceptance | Runtime instances preserve owner player, data key, initial speed policy, fleet points, and roster entry identity for deployment mapping; the conversion depends only on the embedded setup package and static catalog, not a local fleet library. |
| Tests | Rebel/Imperial roster conversion, duplicate ship instances, squadron conversion, missing data rejection, host/client conversion equality from the same package, save/load of any new runtime fields. |
| Verification | Targeted GUT, full GUT, `bash scripts/lint_phase_k.sh`. |
| Status | Implemented as of 2026-05-30: added `FleetRosterSetupHelper` to convert embedded setup-package rosters into runtime `PlayerState`, `ShipInstance`, and `SquadronInstance` data without local library access; `ShipInstance` and `SquadronInstance` now serialize roster entry identity and roster-derived fleet points, and scoring consumes runtime ship/squadron points with static-data fallback. Deployment positions are consumed by FB13 bootstrap. |

### FB13 - Game Bootstrap From Setup Package

| Field | Plan |
|---|---|
| Goal | Start hot-seat and network matches from the same setup package without duplicating scenario spawn logic. |
| Scope | Add a setup-package entry point in `GameManager`, let lobby/start flows provide a package for hot-seat or network, generalize board spawn/bind to accept prepared instances plus placements, keep scenario start path intact. |
| Primary files | `src/autoload/game_manager.gd`, `src/scenes/game_board/game_board.gd`, setup helpers. |
| Acceptance | Existing scenario starts still pass; a setup package starts a board with correct player states, damage deck, RNG, first-player roster map, ships, and squadrons in hot-seat and network modes; host/client final state hashes match after network start. |
| Tests | Scenario path regression, setup-package bootstrap, network setup-package bootstrap, loaded-state spawn regression, token binding assertions. |
| Verification | Full GUT, `bash scripts/lint_phase_k.sh`, `bash scripts/run_baseline_traces.sh --all`, manual hot-seat and two-process network start-from-fleet pass. |
| Status | Implemented as of 2026-05-30: added `FleetSetupBootstrapper` as the core package-to-`GameState` helper, added `GameManager` setup-package start/next-bootstrap entry points, added network pending setup-package config, reused the loaded-state board spawn path for package starts, preserved deployment positions in runtime instances, serialized `GameState.objectives`, carries the first-player roster map through state for board loading, and added a `standard_3x6` map-only scenario shell for package-start fallback map loading. |

### FB13A - Rectangular Play-Area Runtime Support

| Field | Plan |
|---|---|
| Goal | Make the runtime geometry, camera, overlays, and token movement honor rectangular 3x3 and 3x6 play areas instead of assuming a square board. |
| Scope | Replace remaining `play_area_side_px` movement/clamp/deployment call paths with `play_area_size_px`, keep `play_area_side_px` only as a legacy height alias where unavoidable, update board drag/move helpers, deployment-zone overlay geometry, and debug/setup overlays so x bounds use board width and y bounds use board height. |
| Primary files | `src/core/movement/token_mover.gd`, `src/scenes/game_board/game_board.gd`, `src/scenes/game_board/squadron_phase_controller.gd`, `src/scenes/game_board/deployment_zone_overlay.gd`, `src/scenes/game_board/board_camera.gd`, targeted overlays/controllers still extending by square side. |
| Acceptance | A 3x3 map clamps/moves exactly within a 3x3 board; a 3x6 map clamps/moves exactly within a 3x6 board; board camera frames the full rectangle; deployment/drag helpers use width for x bounds and height for y bounds; no runtime path silently crops interaction to a square on 3x6 maps. |
| Tests | `GameScale` rectangular sizing, `TokenMover` width/height clamping, deployment-zone overlay geometry, board camera framing, and targeted board/runtime regressions for 3x6 map payload starts. |
| Verification | Targeted GUT for geometry/runtime files, full GUT, `bash scripts/lint_phase_k.sh`, manual 3x3 and 3x6 board interaction pass before FB14 placement UI. |
| Status | Implemented, manual gate still pending as of 2026-05-31: runtime geometry now routes token movement, board drag helpers, deployment-zone geometry, attack-simulator arc clipping, and firing-arc debug extents through rectangular play-area sizing; 3x3 maps use the full play area as setup area while still keeping distance-3 deployment-zone boundaries, and 3x6 maps keep the standard height-based deployment bounds. Focused/full GUT and `bash scripts/lint_phase_k.sh` pass. The dedicated manual rectangular-map pass is not yet available end to end, so FB13A remains short of complete until that path can be exercised. |

### FB13B - Rectangular Play-Area And Base-Footprint Hardening

| Field | Plan |
|---|---|
| Goal | Prove that selected 3x3 and 3x6 maps, runtime movement, camera/overlay geometry, and setup placement validation agree on the same rectangular play area before deployment/obstacle placement builds on them. |
| Implementation audit | `GameScale.configure_play_area_for_map_filename()` already maps `map_3x3...` to `Vector2(2160, 2160)` and `map_3x6...` to `Vector2(4320, 2160)`; board drag helpers, squadron movement, camera framing/clamping, deployment-zone overlay drawing, firing-arc debug extents, and attack-simulator clipping mostly consume `GameScale.play_area_size_px`. The remaining gap is base-footprint containment: `TokenMover._clamp_to_play_area()` clamps token centers to `[0,width] x [0,height]`, and push-out candidates reuse that center clamp, so ships and squadrons can end with part of their base outside the selected map. Tests currently verify rectangular width usage but not full footprint containment. |
| Scope | Harden all runtime/setup geometry to use `GameScale.play_area_size_px` width and height, not square `play_area_side_px`; keep `play_area_side_px` only as a legacy height alias for older square APIs/tests. Add footprint-aware clamping for ships and squadrons, including push-out candidates. Distinguish play area, setup area, and deployment-zone bands in validators so map legality, setup legality, and deployment legality are explicit. |
| Primary files | `src/core/movement/token_mover.gd`, setup/deployment validators introduced in FB14, `src/autoload/game_scale.gd`, `src/scenes/game_board/game_board.gd`, `src/scenes/game_board/squadron_phase_controller.gd`, `src/scenes/game_board/deployment_zone_overlay.gd`, `src/scenes/game_board/board_camera.gd`, attack/firing overlays, related tests. |
| Ship-base containment details | Compute ship drag bounds from the rotated base extents: `extent_x = abs(half_w * cos(rot)) + abs(half_l * sin(rot))` and `extent_y = abs(half_w * sin(rot)) + abs(half_l * cos(rot))`; clamp center X to `[extent_x, play_area_size.x - extent_x]` and center Y to `[extent_y, play_area_size.y - extent_y]`. If a base is larger than an axis, use the axis center and report/validate the placement as illegal rather than silently placing outside. Squadron bounds use radius on both axes. Push-out candidates must be re-clamped with the same footprint rules before overlap validation. |
| Setup/placement validation details | FB14 validators must reject normalized ship/squadron placements whose full footprint crosses the selected map boundary after converting with `play_area_size_px`; positions serialize as `pos_x = pixel_x / play_area_size.x`, `pos_y = pixel_y / play_area_size.y`, and `rotation_deg`, never pixels. 3x3 maps use the full 3x3 play area; 3x6 maps preserve the 6x3 play area, the standard setup region, and distance-band deployment zones. |
| Acceptance | Ships and squadrons cannot be dragged, pushed out, bootstrapped, or validated as deployed with any part of their footprint outside the selected map; rotated ship extents are respected for drag clamping; x bounds use board width and y bounds use board height; 3x3 maps use the full 3x3 play area; 3x6 maps preserve the intended 6x3 play area and setup/deployment regions; camera and overlays frame/draw the full rectangle. |
| Tests | `TokenMover` footprint clamping for ships, rotated ships, and squadrons on all edges/corners; push-out candidate clamping near edges; `GameScale` map filename sizing; deployment-zone overlay geometry; board camera framing; setup-package/bootstrap regression for both 3x3 and 3x6 selected maps; placement-validator tests for full-base boundary rejection and normalized coordinate conversion. |
| Verification | Targeted geometry/setup GUT, full GUT, `bash scripts/lint_phase_k.sh`, `bash scripts/run_baseline_traces.sh --all`, manual 3x3/3x6 drag/rotate/pan/zoom and start-from-fleet pass. |
| Status | In progress as of 2026-05-31: `TokenMover` now uses footprint-aware play-area clamps for direct ship/squadron movement and for ship push-out candidate collection, with focused `test_token_mover.gd` FB13B regressions added for squadron radius clamping, direct ship footprint clamping, rotated ship extents, and edge push-out candidates. `FleetRosterSetupHelper` now rejects setup-package ship/squadron deployments whose full base footprint crosses the selected map boundary before runtime bootstrap, with focused setup-helper and bootstrap regressions. Focused GUT, full GUT, `bash scripts/lint_phase_k.sh`, and `bash scripts/run_baseline_traces.sh --all` pass. Remaining FB13B work is to carry the same full-footprint contract into FB14 placement validators and any later interactive placement seams. |

### FB13C - Setup Flow Selection And Package Confirmation

| Field | Plan |
|---|---|
| Goal | Add the thin presentation layer for selecting two rosters, choosing first player and objective, and confirming a validated setup package before placement begins. |
| Scope | Add `src/scenes/setup_flow/` coordinator/widgets for choosing local rosters, invoking `FleetSetupPackageBuilder`, surfacing `SetupValidationResult`, selecting first player and the second player's objective, previewing package hash/map summary, and handing the validated package to later placement/start flows. Keep obstacle and deployment placement out of this slice. |
| Primary files | New `src/scenes/setup_flow/*`, minimal additions in `src/scenes/main_menu/main_menu.gd` or lobby entry points, existing core setup classes. |
| Acceptance | Hot-seat setup can choose two local rosters, choose first player/objective, reject invalid rosters, display deterministic package summary/hash, and hand off a validated package without local-library coupling. Network/lobby reuse remains on the same builder contract. |
| Tests | Focused setup-flow UI/controller tests with mocked library/builder, invalid roster display, objective ownership rendering, package-summary rendering, no orphan/leak warnings. |
| Verification | Focused UI GUT, full GUT, `bash scripts/lint_phase_k.sh`, manual local setup selection and package-confirmation pass. |
| Status | In progress as of 2026-06-01: local setup-package confirmation has a thin `src/scenes/setup_flow/` screen over `FleetLibraryManager` and `FleetSetupPackageBuilder`, with roster selection, RRG-compliant initiative chooser resolution from fleet points or tie-breaker, selectable first player, objective selection from the second player's roster, deterministic package summary/hash, and a `GameManager.set_next_setup_package()` handoff. Legacy fleet records without serialized map payloads now default their map from point format during roster deserialization, so older saved fleets can still build setup packages. Focused roster/setup-flow/package-builder GUT, full GUT, `bash scripts/lint_phase_k.sh`, and `bash scripts/run_baseline_traces.sh --all` pass. Obstacle and deployment placement remain FB14 scope; manual local setup selection/package-confirmation pass is pending. |

### FB13D - Dynamic Player Identity Projection

| Field | Plan |
|---|---|
| Goal | Remove the remaining presentation assumptions that player 0 is always Rebel and player 1 is always Imperial, so setup-package starts display the correct active player, faction, and perspective in hot-seat and network play. |
| Problem statement | FB13C can now build a package where the lower-point Imperial fleet is first player. The core state already preserves this correctly (`GameState.player_states`, `initiative_player`, and active-player logging show `Player 0: Imperial, Player 1: Rebel`), but hot-seat handoff/turn banners and nearby card-panel perspective comments still use static player-index-to-faction labels. This makes the UI tell the wrong player that it is their turn and would make FB14 manual placement hard to trust. |
| Scope | Add a small player-identity projection surface that resolves display name, faction name, faction enum, and active/initiative markers from `GameState.player_states` for any player index. Route `HandoffOverlay`, `YourTurnBanner`, and the board turn-transition path through that projected identity instead of local `PLAYER_NAMES` arrays. Update card-panel side/perspective logic so the active player's panel is placed by the active player's actual faction, not by a player-index shortcut. Keep all hot-seat and network turn-transition rendering on the existing `UIProjector.project_turn_transition()` path; do not add `PlayMode.is_network()` or `PlayMode.is_hot_seat()` branches under `src/scenes/` or `src/ui/`. |
| Out of scope | Actual setup placement, obstacle placement, deployment commands, objective setup-step routing, lobby fleet exchange UX, and save/load expansion for objective runtime state remain FB14-FB17 work. This slice may document hardcoded deployment-zone or camera comments discovered during the audit, but only fixes identity surfaces that affect turn ownership and player-facing labels. |
| Primary files | `src/core/network/ui_projector.gd` or a focused identity formatter under `src/core/state/`, `src/scenes/game_board/game_board.gd`, `src/ui/handoff_overlay.gd`, `src/ui/hud/your_turn_banner.gd`, `src/ui/ship/ship_card_panel.gd` only if side/perspective API changes are needed, and focused tests in `tests/unit/test_ui_projector.gd`, `tests/unit/test_handoff_overlay.gd`, `tests/unit/test_your_turn_banner.gd`, plus any board/panel regression tests already covering perspective. |
| Acceptance | A setup-package hot-seat start with `Player 0 = Galactic Empire`, `Player 1 = Rebel Alliance`, and `initiative_player = 0` shows the Imperial player in the Command Phase handoff and later turn banner; the opposite mapping still works for legacy scenario starts; network peers stay pinned to their local perspective while seeing correct active-player/waiting labels; card panels continue to put the active viewer's cards on the expected side even when player index and faction order differ; no scenario, save-load, replay, or baseline trace behavior regresses. |
| Tests | Unit tests for identity projection from `GameState.player_states`; updated handoff/banner tests that pass explicit projected labels instead of asserting `0 == Rebel`; projector tests for shared-screen and network transitions with Imperial player 0/Rebel player 1; card-panel/perspective regression for active player 0 with Imperial faction; setup-package bootstrap regression asserting the projected first-player label follows the package's player-state faction. |
| Verification | Focused GUT for projector/banner/handoff/perspective tests, full GUT, `bash scripts/lint_phase_k.sh`, `bash scripts/run_baseline_traces.sh --all`, and a manual hot-seat start from two fleets where Imperial has fewer points and receives first-player banners. If network setup-package UI is still unavailable, run the existing two-process baseline traces and record network manual setup as pending. |
| Status | Complete as of 2026-05-31: `UIProjector` now projects controller and perspective player labels/factions from `GameState.player_states`; `GameBoard` passes those projected identities into hot-seat/network turn prompts and card-panel side selection; `HandoffOverlay`, `YourTurnBanner`, the damage-card choice handoff, phase-HUD score labels, victory labels, and end-game music no longer depend on fixed `0 = Rebel, 1 = Imperial` arrays when live state is available. Focused projector/banner/handoff/card-panel/HUD/victory GUT coverage includes Imperial player 0 and Rebel player 1 mappings. Manual hot-seat setup-package identity testing passed with Imperial as first player. |

### FB14 - Deployment And Obstacle Placement Flow

| Field | Plan |
|---|---|
| Goal | Let setup choose/place obstacles and deploy fleet components using normalized positions. |
| Scope | Add obstacle placement state, deployment placement state, warning-guided manual placement UI first, and validators for normalized bounds/deployment zones/obstacle overlap constraints. Validators must validate full ship/squadron footprints, not just token centers, and serialize normalized positions using `x / play_area_size.x` and `y / play_area_size.y`. The validators must account for 3x3 maps using the full play area as setup area while ships still deploy within distance 1-3 of their player edge, and 3x6 maps using the standard 3x4 setup area plus distance 1-3 deployment zones from the RRG. If placement remains pre-bootstrap, it updates the setup package; if placement occurs after `GameState` exists, it uses commands so network peers and replays receive the same mutations. |
| Primary files | `src/core/setup/*deployment*.gd`, `src/core/setup/*obstacle*.gd`, existing `src/scenes/setup_flow/*` widgets/controllers, `src/models/token_placement.gd` reuse. |
| Acceptance | User can place Core Set obstacles and deploy ships/squadrons, then serialize a setup package with normalized placements that hot-seat and network start paths can consume identically. |
| Tests | Placement serialization, bounds validation, obstacle set completeness, deployment-zone warnings/errors, no pixel values in payloads, host/client placement package equality. |
| Verification | Focused setup UI tests, full GUT, `bash scripts/lint_phase_k.sh`, `bash scripts/run_baseline_traces.sh --all`, manual deployment pass. |
| Status | In progress as of 2026-06-01: setup-package starts now remain in `SETUP` instead of immediately entering Command Phase, and round one is gated behind command-backed setup validation in `StartRoundCommand`. Live `GameState.objectives` carries the serialized deployment payload beside obstacles/setup state so after-bootstrap placement completion can validate that six obstacles and every fleet component have normalized placements before `GameManager.complete_setup_and_start_round()` submits round one. Interactive placement UI and full obstacle/deployment validators remain in this slice. |

### FB15 - GameState Persistence For Objectives, Obstacles, And Upgrades

| Field | Plan |
|---|---|
| Goal | Preserve setup-derived state through save/load, replay, and network snapshots. |
| Scope | Add serialized fields for selected objective, obstacle placements/state, objective tokens, objective ships, victory tokens, set-aside units, station/obstacle overrides, deployment modifiers, and runtime upgrade assignments/exhaustion where gameplay uses them. Update `StateFilter` if player-specific visibility is needed. |
| Primary files | `src/core/state/game_state.gd`, `src/core/state/player_state.gd`, ship/squadron instance state if upgrades attach there, `StateFilter`, tests. |
| Acceptance | Save/load after deployment reconstructs objective, objective-specific runtime state, obstacles, fleet points, upgrade assignments, and token positions identically. |
| Tests | Serialize/deserialize round trips, save/load integration, representative objective-state round trips, replay determinism for setup package start. |
| Verification | Full GUT, `bash scripts/lint_phase_k.sh`, `bash scripts/run_baseline_traces.sh --all`, manual save/load after setup pass. |

### FB16 - Gameplay Rule Hooks For Objectives, Obstacles, And Upgrades

| Field | Plan |
|---|---|
| Goal | Implement only the active gameplay effects needed by the Core Set catalog through `RuleRegistry`. |
| Scope | Add rule files under `src/core/effects/rules/` for selected objectives, obstacle effects, named squadron abilities, and any upgrades promoted from passive validation to gameplay behavior. Update the corresponding catalog `rules_integration` markers in the same slice. |
| Primary files | `src/core/effects/rules/*`, `RuleBootstrap`, commands/validators touched by those rules. |
| Acceptance | Rule effects are source-first, active status is derived from serialized state, UI affordances are projected from core/application metadata, and catalog implementation status agrees with the registered `RuleRegistry` ids. |
| Tests | Direct command validation, UI eligibility projection, save/load rebuild, replay determinism, network mirror safety for each rule surface. |
| Verification | Full GUT, `bash scripts/lint_phase_k.sh`, `bash scripts/run_baseline_traces.sh --all`, manual rule-specific passes. |

### FB17 - Network Setup UX And Resumability

| Field | Plan |
|---|---|
| Goal | Build network presentation and recovery behavior over the setup-package contract already introduced in FB11-FB13. |
| Scope | Add lobby controls for selecting a local fleet, sending the expanded roster payload, showing validation failures, confirming the setup package hash, and resuming/rejoining setup if the lobby supports it. |
| Primary files | `src/autoload/lobby_manager.gd`, `src/scenes/lobby/lobby_room.gd`, setup package serialization, state filtering if needed. |
| Acceptance | Network UI consumes the same core package and validators as hot-seat setup; host and client agree on the same setup package and final state hash after game start; existing scenario network starts remain intact. |
| Tests | Lobby serialization, invalid remote package rejection, host/client setup equality, package-hash mismatch display, reconnection snapshot if setup can be resumed. |
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
11. Generic rule text and source references are read from the rules-reference
  catalog. Component JSON links by `rules_reference_ids`; it must not become
  a second source of truth for generic keyword/command/obstacle rule text.
12. Gameplay effects from objectives, obstacles, and upgrades use
    `RuleRegistry`, not scene branches or ad hoc resolver special cases.
13. When a rule is implemented, the corresponding rules-reference record and
  component `rules_integration` marker are updated in the same slice.
14. No setup package, roster conversion, or rule hook may be hot-seat-only. The
   first code slice for each contract must include a network/replay-safe test
   seam, even if the final network UI arrives later.
15. Any setup/game-start/network/replay slice runs baseline traces.

---

## 7. Manual Test Matrix

These are the human acceptance passes to run before committing the relevant
code-bearing slices.

| Milestone | Manual pass |
|---|---|
| Data/catalog | Open catalog UI or diagnostic output and confirm Core Set ships, squadrons, upgrades, objectives, and obstacles appear with expected points/categories. |
| Rules reference | Browse generic rules by category, open linked component-specific rules from a card entry, and confirm implemented/pending markers are visible without implying pending card effects are live. |
| Roster/validation | Build legal and illegal 180, 400, and custom fleets; confirm errors match the violated rules. |
| Import/export | Export a fleet JSON, import it as a new fleet, compare points/objectives/upgrades, and restore an older version. |
| UI MVP | Create a fleet from scratch, filter/search components, add upgrades, choose objectives, save, reload, duplicate, and delete. |
| Rectangular maps | Start 3x3 and 3x6 maps from selected fleets; drag/rotate ships and move squadrons against every board edge; confirm the full base footprint stays inside the visible map and camera/overlays cover the full rectangle. |
| Setup package | Select two valid fleets, choose first player/objective, confirm invalid fleets cannot advance, and confirm the package embeds both rosters without local-library dependencies. |
| Dynamic player identity | Start from two fleets where player index and faction order differ from the legacy Rebel-first scenario mapping; confirm hot-seat handoff overlays, turn banners, card-panel perspective, and network/passive status text name the correct active player. |
| Deployment | Place obstacles and deploy units; confirm normalized positions survive leaving/reopening setup. |
| Start match | Start hot-seat and network matches from two fleets and verify correct ships/squadrons, factions, points, objective, obstacle placements, and matching host/client state hashes. |
| Save/load | Save immediately after deployment/start, load, and verify objective/obstacles/deployments/upgrades survive. |
| Network setup | Host and client choose/confirm fleets, compare the setup package hash, start game, and verify matching state hashes plus expected local visibility. |

---

## 8. Open Questions And Useful Context

1. The per-type `Resources/Game_Components/upgrades/` layout is now in use.
  Revisit it only if tooling or loader ergonomics become a real problem; do
  not reopen FB1 schema work without a concrete migration reason.
2. Add a follow-on Rules Reference content slice beyond squadron keywords:
  commands, defense tokens, attack timing, setup, obstacles, and scoring still
  need static catalog records.
3. FB13C/FB13D now cover local setup-package confirmation and dynamic player
  identity. FB14 should own setup-step routing, obstacle placement, and fleet
  deployment UI.
4. First-player choice now follows RRG setup step 3: the lower-point player
  chooses first player, and tied fleets use the tie-breaker to pick the chooser.
  Remaining work is setup placement, not initiative-choice ownership.
5. Deployment begins as warning-guided manual placement with normalized
  positions; strict hard enforcement can harden in later setup validators.
6. `FleetLibraryManager` currently stores fleets under `PathConfig.SAVES_DIR + "/fleets"`.
  Keep setup packages independent from that local library path.
7. Pick a future backend direction before FB18: self-hosted API, hosted service,
  file-sync provider, or no cloud for now.

---

## 9. Suggested Next Slice

FB0-FB13D are code-complete for requirements, component-contract,
typed-loading, setup-hash, Core Set catalog, editable roster model,
catalog-query, validator foundation, local library/import-export UI,
setup-package contract, runtime instance conversion, setup-package bootstrap,
rectangular runtime support, and full-footprint runtime/setup placement
hardening, local setup-package confirmation, point-total-derived first player,
objective choice, legacy missing-map fallback, package handoff to the board,
and dynamic player identity projection for turn prompts and card-panel
perspective.

1. Start FB14, carrying the full-footprint boundary contract into
  obstacle/deployment validators and using normalized positions derived from
  `play_area_size_px`.
2. Add setup-step routing that consumes `FleetSetupPackage.setup_state` instead
  of jumping from package confirmation directly to Command Phase.
3. Keep obstacle placement, deployment placement, and setup-step completion
  command-backed if they occur after `GameState` exists.
4. Run the full setup/game-start verification gate, including baseline traces,
  before treating FB14 placement UI as ready for manual deployment testing.

This keeps FB14 focused on setup placement semantics now that package
confirmation and player identity are stable enough for manual placement passes.
