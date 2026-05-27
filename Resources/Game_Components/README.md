# Game Components

Static game component data lives here. Folders and files use lower_snake_case so
Godot imports, loaders, and fleet-builder catalog queries can derive stable keys
from file names.

Each component folder co-locates static JSON, card art, token art, and source
notes for that component type. Upgrade cards may use one lower_snake_case
subfolder per upgrade type because the Core Set already groups upgrades that
way.

## Folder Structure

```text
Game_Components/
├── ships/                  Ship card JSON, card art, ship token art, rule notes
├── squadrons/              Squadron JSON, card art, token art, shared base art, rule notes
├── upgrades/               Upgrade JSON, card art, and rule notes grouped by upgrade type
├── objectives/             Objective JSON, card art, objective token art, rule notes
├── obstacles/              Obstacle JSON, token art, and source notes
├── rules/                  Generic rules-reference JSON records
├── dice/                   Attack dice face PNGs
├── defense_tokens/         Defense token PNGs
├── command_tokens/         Command dial/token PNGs
├── maps/                   Play area background JPGs
├── tools/                  Range ruler and maneuver tool PNGs
├── scale/                  Scale calibration JSON
├── scenarios/              Scenario setup JSON
├── damage_deck/            Damage card art
├── damage_cards.json       Damage card static data
├── wave_expansion_set_content_information.txt
└── card_data_schema.json   Static component catalog schema
```

## Current Fleet-Builder Inventory

| Category | Folder | Current FB1 status | Follow-up |
|---|---|---|---|
| Ships | `ships/` | 6 Core Set ship JSON records with card art and partial token art. | FB2 typed loader refresh. |
| Squadrons | `squadrons/` | 7 squadron JSON records: Core Set squadrons plus Wave 1 generic Imperial squadrons. | FB3 completeness tests distinguish Core Set gate from extra Wave 1 content. |
| Upgrades | `upgrades/` | 18 Core Set upgrade JSON records under per-type subfolders, with card art and rule notes. | FB2 `UpgradeData.from_dict()` and loader enumeration. |
| Objectives | `objectives/` | 12 Core Set objective JSON records: 4 Assault, 4 Defense, 4 Navigation. | FB2 `ObjectiveData` and loader enumeration. |
| Obstacles | `obstacles/` | 6 Core Set obstacle JSON records with token images, source refs, and draft shape metadata. | Future setup/deployment slices replace placeholder shape metadata with measured polygons. |
| Rules reference | `rules/` | 5 generic squadron keyword rules-reference JSON records for implemented keyword rules. | FB3 broadens generic and component-specific rules. |
| Schema | `card_data_schema.json` | Schema describes ships, squadrons, upgrades, objectives, obstacles, and rules-reference records. | Future slices tighten validators as setup packages and roster models mature. |

## Naming Convention

- Folders and files use lower_snake_case.
- Do not use spaces, hyphens, or PascalCase in new component files.
- JSON `data_key` values match the file stem unless a future migration records a
  compatibility alias.
- Static catalog facts belong in JSON, not GDScript constants or UI code.

## Per-Folder Patterns

| Folder | Pattern | Example |
|---|---|---|
| `ships/` | `<ship_key>.json`, `<ship_key>_card.png`, `<ship_key>_token.png` | `cr90_corvette_a.json` |
| `squadrons/` | `<squadron_key>.json`, `<squadron_key>_card.png`, `<squadron_key>_token.png` | `x_wing_squadron.json` |
| `upgrades/<upgrade_type>/` | `<upgrade_key>.json`, `w<index>_<upgrade_key>_card.png`, `w<index>_<upgrade_key>_rules.txt` | `commander/general_dodonna.json` |
| `objectives/` | `obj_<category>_<objective_key>.json`, matching `_card.png` and `_rules.txt` | `obj_ass_opening_salvo.json` |
| `obstacles/` | `<obstacle_key>_token.png`, future `<obstacle_key>.json` | `asteroid_1_token.png` |
| `rules/` | `<rules_reference_key>.json` using lower_snake_case for file names | `squadron_keyword_bomber.json` |

## Fleet-Builder Metadata

Static component JSON may include these shared fields:

| Field | Purpose |
|---|---|
| `data_key` | Stable catalog id. |
| `kind` | Record type such as `ship_card`, `squadron_card`, `upgrade_card`, `objective_card`, `obstacle_component`, or `rules_reference`. |
| `wave` | Numeric wave. Core Set content is Wave 0. |
| `expansion` | Source product or expansion key. |
| `available_through` | Products that contain the component. |
| `card_image` / `token_image` | Local image filenames in the component folder. |
| `search_tags` | Lower_snake_case tags for catalog filtering. |
| `source_refs` | Local source files or rules references used to verify the record. |
| `rules_reference_ids` | Links to generic or component-specific records in the rules-reference catalog. |
| `rules_integration` | Implementation status and matching `RuleRegistry` rule ids. |

`rules_integration.status` values are:

| Status | Meaning |
|---|---|
| `NOT_INTEGRATED` | Static catalog data exists, but gameplay behavior is not live. |
| `PARTIAL` | Some linked generic rules are live, but named/component-specific behavior is pending. |
| `INTEGRATED` | All relevant gameplay behavior is implemented through registered rule ids. |

## Rules Reference Policy

Generic rule text should be authored once under `rules/` and referenced by
components through `rules_reference_ids`. Existing duplicated reminder text, such
as squadron keyword text in squadron JSON, is transitional compatibility data.

Rules-reference records expose display text, source refs, tags, implementation
status, and matching `RuleRegistry` ids. They are not executable gameplay code.
Live gameplay behavior belongs in `src/core/effects/rules/` and is registered by
`RuleBootstrap`.

## Validation

- Component JSON must parse as JSON.
- Fleet-builder component records should match the appropriate definition in
  `card_data_schema.json`.
- New objective, upgrade, and obstacle records with pending gameplay text must include
  `rules_integration.status = "NOT_INTEGRATED"` until their rule slices are
  implemented.
- Generic keyword-only squadrons can be `INTEGRATED` only when their keyword ids
  map to registered `RuleRegistry` rules.
- Unique ace abilities or card-specific rules remain `PARTIAL` or
  `NOT_INTEGRATED` until their named behavior is live.

See `docs/fleet_builder_implementation_plan.md` for the implementation slices
that turn this static catalog contract into loaders, validators, setup packages,
and UI.
