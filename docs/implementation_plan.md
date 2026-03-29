# Implementation Plan — Learning Scenario MVP

> **Scope:** Implement the complete Learning Scenario from the core set Learn to Play booklet.
> **Prerequisite:** All graphic assets must be provided and in place before coding begins.

## Table of Contents

- [Game Scale Definition](#game-scale-definition)
- [Graphic Assets Required](#graphic-assets-required)
- [Implementation Phases](#implementation-phases)
- [Phase 0: Scale & Assets Foundation](#phase-0-scale--assets-foundation)
- [Phase 1: Core Geometry Engine](#phase-1-core-geometry-engine)
- [Phase 2: Game Board & Token Display](#phase-2-game-board--token-display)
- [Phase 2b: Debug Token Placement](#phase-2b-debug-token-placement)
- [Phase 3: Game State Wiring](#phase-3-game-state-wiring)
- [Phase 4: Command Phase](#phase-4-command-phase)
- [Phase 4b: Turn Management & Board Perspective](#phase-4b-turn-management--board-perspective)
- [Phase L: Game Logging Tooling](#phase-l-game-logging-tooling)
- [Phase 4c: Ship Activation Trigger](#phase-4c-ship-activation-trigger)
- [Phase 4d: Keep-or-Convert Dial Choice](#phase-4d-keep-or-convert-dial-choice)
- [Phase 4e: Command Token Overflow Discard](#phase-4e-command-token-overflow-discard)
- [Phase 4f: Hover Tooltip Infrastructure](#phase-4f-hover-tooltip-infrastructure)
- [Phase 4g: Fixed Round-1 Commands](#phase-4g-fixed-round-1-commands)
- [Phase 5: Ship Movement](#phase-5-ship-movement)
- [Phase 5c: Range Overlay Tool](#phase-5c-range-overlay-tool)
- [Phase 5d: Targeting List Tool](#phase-5d-targeting-list-tool)
- [Phase 6a: Attack Simulator — Attacker Declaration](#phase-6a-attack-simulator--attacker-declaration)
- [Phase 6a-3: Attack Simulator — Same-Ship Guard, Arc Validation & Range Line](#phase-6a-3-attack-simulator--same-ship-guard-arc-validation--range-line)
- [Phase 6a-4: Hull-Zone Edge Polyline Fix (HZ-EDGE-001)](#phase-6a-4-hull-zone-edge-polyline-fix-hz-edge-001)
- [Phase 6b-1: Attack Execution — Target Selection & Visuals](#phase-6b-1-attack-execution--target-selection--visuals)
- [Phase 6b-2: Attack Execution — Dice Rolling, Concentrate Fire & Two-Hull-Zone Sequencing](#phase-6b-2-attack-execution--dice-rolling-concentrate-fire--two-hull-zone-sequencing)
- [Phase 6b-3: Attack Execution — Anti-Squadron Multi-Target Sequencing](#phase-6b-3-attack-execution--anti-squadron-multi-target-sequencing)
- [Phase 6c: Attack Steps 3–5 — Accuracy, Defense Tokens & Damage Resolution](#phase-6c-attack-steps-35--accuracy-defense-tokens--damage-resolution)
- [Phase 6: Attack Resolution](#phase-6-attack-resolution)
- [Phase 7: Squadron Phase](#phase-7-squadron-phase)
- [Phase 8: Status Phase & Game Flow](#phase-8-status-phase--game-flow)
- [Phase 9: Repair Command & Damage Cards](#phase-9-repair-command--damage-cards)
- [Phase 10: UI Polish & Network Foundation](#phase-10-ui-polish--network-foundation)
- [Dependency Graph](#dependency-graph)
- [Architecture Hooks for Future Stages](#architecture-hooks-for-future-stages)

---

## Game Scale Definition

The physical game uses these real-world measurements:

| Physical Component | Real-World Size | Notes |
|--------------------|-----------------|-------|
| Range ruler | 1 foot (305mm) | Divided into 3 range bands (close/medium/long) and 5 distance bands (1–5) |
| Play area (Learning) | 3' × 3' (914mm × 914mm) | Play area = 3 × range ruler length per side |
| Small ship base | ~43mm × 71mm | CR90, Nebulon-B |
| Medium ship base | ~63mm × 102mm | Victory-class |
| Squadron base | ~34.2mm diameter (circular) | X-wing, TIE Fighter |
| Maneuver tool segment | ~61mm per segment | 5 segments, each ~1/5 of range ruler |

### How Scale Is Determined

The user provides a PNG of the range ruler and measures its **total length in pixels**. This establishes the master scale:

```
PIXELS_PER_FOOT = range_ruler_total_length_in_pixels
PLAY_AREA_PIXELS = PIXELS_PER_FOOT * 3   (for 3' × 3')
```

All other component sizes derive from this single measurement:

| Component | Scale Formula |
|-----------|---------------|
| Play area side | `PIXELS_PER_FOOT × 3` |
| Close range band | Range ruler band 1 boundary (measured from PNG) |
| Medium range band | Range ruler band 2 boundary (measured from PNG) |
| Long range band | Range ruler band 3 boundary = full ruler |
| Distance band N | Range ruler distance band N boundary (measured from PNG) |
| Small base width | `PIXELS_PER_FOOT × (43/305)` ≈ 0.141 × ruler |
| Small base length | `PIXELS_PER_FOOT × (71/305)` ≈ 0.233 × ruler |
| Medium base width | `PIXELS_PER_FOOT × (63/305)` ≈ 0.207 × ruler |
| Medium base length | `PIXELS_PER_FOOT × (102/305)` ≈ 0.334 × ruler |
| Squadron base diameter | `PIXELS_PER_FOOT × (34.2/305)` ≈ 0.112 × ruler |
| Maneuver segment length | `PIXELS_PER_FOOT / 5` |

> **ACTION REQUIRED:** Measure the range ruler PNG (total length in pixels) and provide the pixel positions of each band boundary. See `Resources/Game_Components/scale/README.md` for the exact measurements needed.

---

## Graphic Assets Required

Assets are classified as **User-Provided PNGs** or **Procedural** (generated by code).

### User-Provided PNGs (Must Exist Before Implementation)

These assets require artistic work and cannot be generated programmatically with acceptable quality.

#### Ship Tokens (Top-Down View)

These are **play area tokens** — NOT the card images already in `ships/`. They represent the miniatures as seen from above on the game mat.

| Asset | Filename | Size Guidance | Notes |
|-------|----------|---------------|-------|
| CR90 Corvette A | `cr90_corvette_a_token.png` | Small base proportions (43:71 ratio) | Top-down silhouette, Rebel styling |
| Nebulon-B Escort | `nebulon_b_escort_frigate_token.png` | Small base proportions (43:71 ratio) | Top-down silhouette, Rebel styling |
| Victory II-class SD | `victory_ii_class_star_destroyer_token.png` | Medium base proportions (63:102 ratio) | Top-down silhouette, Imperial styling |

- Transparent background (PNG with alpha)
- Ship art only — no base, no firing arc lines (those are procedural overlays)
- Orientation: ship nose pointing **up** (toward Y-negative in Godot 2D)
- Resolution: at least 2× the expected display size for crisp rendering at zoom

#### Squadron Tokens (Two-Layer Composite)

Squadrons use **two** separate graphics: a shared circular base (`squad_base.png`, 82×82 px) and a per-squadron token artwork PNG drawn on top. The base determines game-scale sizing (range measurement, overlap detection). The token artwork is purely visual.

| Asset | Filename | Size (px) | Notes |
|-------|----------|-----------|-------|
| Shared base | `squad_base.png` | 82×82 (circle) | Scaled to game-scale diameter; defines collision/range circle |
| X-wing token | `x_wing_squadron_token.png` | 74×63 (content) | Drawn on top of base, fit within circle |
| TIE Fighter token | `tie_fighter_squadron_token.png` | 70×51 (content) | Drawn on top of base, fit within circle |

- Transparent backgrounds (PNG with alpha)
- Token artwork: no base circle — the shared base PNG provides it
- Orientation: nose pointing **up**

#### Play Area

| Asset | Filename | Size Guidance | Notes |
|-------|----------|---------------|-------|
| Space background | `space_background.png` | 3:3 aspect ratio, at least 2048×2048 | Star field, can tile or be a single large image |

Alternatively, the existing map JPGs in `Resources/Game_Components/maps/` could be cropped/adapted.

#### Range Ruler

| Asset | Filename | Size Guidance | Notes |
|-------|----------|---------------|-------|
| Range ruler (range side) | `range_ruler_range.png` | Full length, proportional | Shows close/medium/long bands with markings |
| Range ruler (distance side) | `range_ruler_distance.png` | Full length, proportional | Shows distance bands 1–5 with markings |

These serve double duty: (1) visual overlay for measurement and (2) scale calibration source.

#### Dice Faces

| Asset | Filename Pattern | Count | Notes |
|-------|-----------------|-------|-------|
| Red die faces | `die_red_<face>.png` | 4 faces | blank, hit, hit_hit, crit |
| Blue die faces | `die_blue_<face>.png` | 4 faces | blank, hit, accuracy, hit_crit |
| Black die faces | `die_black_<face>.png` | 4 faces | blank, hit, hit_hit, crit |

> **Alternative:** Dice faces can be **procedural** (colored square + icon symbols drawn in code). If you prefer this, these PNGs can be skipped. See question below.

#### Defense Token Icons

| Asset | Filename Pattern | States | Notes |
|-------|-----------------|--------|-------|
| Evade | `token_evade_ready.png` / `token_evade_exhausted.png` | Ready + exhausted PNGs provided |
| Redirect | `token_redirect_ready.png` / `token_redirect_exhausted.png` | Ready + exhausted PNGs provided |
| Brace | `token_brace_ready.png` / `token_brace_exhausted.png` | Ready + exhausted PNGs provided |
| Scatter | `token_scatter_ready.png` / `token_scatter_exhausted.png` | Ready + exhausted PNGs provided |
| Contain | `token_contain_ready.png` / `token_contain_exhausted.png` | Ready + exhausted PNGs provided |

> All 10 defense token PNGs (5 types × ready/exhausted) are already in `defense_tokens/`.

#### Command Icons

| Asset | Filename Pattern | Notes |
|-------|-----------------|-------|
| Navigate icon | `cmd_navigate.png` | Arrow/compass icon |
| Squadron icon | `cmd_squadron.png` | Fighter icon |
| Repair icon | `cmd_repair.png` | Wrench icon |
| Concentrate Fire icon | `cmd_concentrate_fire.png` | Crosshair icon |

> All 4 command token PNGs are already in `command_tokens/`.

#### Initiative Token

| Asset | Filename | Notes |
|-------|----------|-------|
| Initiative (Rebel side) | `initiative_rebel.png` | Blue with ★ icon |
| Initiative (Imperial side) | `initiative_imperial.png` | Red/grey side |

### Procedural Components (Generated by Code)

These will be drawn/composed programmatically. No PNGs needed.

| Component | Approach | Notes |
|-----------|----------|-------|
| **Ship bases** | `Polygon2D` + `Line2D` | Rectangles with firing arc lines, hull zone coloring, notch markers |
| **Squadron bases** | `Polygon2D` (circle) | Colored ring with faction tint |
| **Maneuver tool** | `Line2D` segments + joints | Interactive: click joints to set yaw |
| **Speed dial** | `Control` widget | Numeric display with +/- buttons |
| **Shield dials** | `Control` widget per hull zone | Current/max display, color-coded |
| **Activation slider** | Toggle `Control` | Blue/other color state |
| **Round counter** | `Label` widget | Number 1–6 |
| **Damage deck** | Data-driven `Control` | Card back + faceup effect text from data |
| **Firing arc overlay** | `Line2D` + shader | Semi-transparent wedges extending from hull zones |
| **Range measurement overlay** | `Line2D` + colored bands | Draggable for player measurement |
| **Engagement lines** | `Line2D` | Visual links between engaged squadrons |
| **Attack step dialog** | `Control` panels | Step-by-step UI for attack resolution |
| **Command dial picker** | `Control` widget | 4-way selector, hidden from opponent |
| **HUD** | `CanvasLayer` + `Control` | Phase, round, scores, active player |

### Summary: Minimum PNGs Needed

| Category | Count | Can Skip If Procedural? |
|----------|-------|------------------------|
| Ship tokens (top-down) | 3 | No — art needed |
| Squadron tokens (top-down) | 2 | No — art needed |
| Space background | 1 | Could use existing map JPGs |
| Range ruler (both sides) | 2 | No — also used for scale calibration |
| Dice faces | 0–24 | Yes — can be procedural |
| Defense token icons | 0–4 | Already provided (10 PNGs in `defense_tokens/`) |
| Command icons | 0–4 | Already provided (4 PNGs in `command_tokens/`) |
| Initiative token | 0–2 | Yes — can be procedural |
| **Hard minimum** | **8 PNGs** | Ship tokens + squadron tokens + background + range rulers |

---

## Implementation Phases

> **Progress Key:** ✅ Complete · 🔄 In Progress · ⏳ Not Started

### Phase 0: Scale & Assets Foundation ✅
**Status:** Complete — committed `3343768`
**Goal:** Establish the pixel-to-game-unit scale and verify all assets load correctly.
**Prerequisites:** All user-provided PNGs in place.

| Task | Status | Deliverable |
|------|--------|-------------|
| Define `GameScale` autoload | ✅ | `src/autoload/game_scale.gd` |
| Asset validation utility | ✅ | `src/utils/asset_loader.gd` |
| Scale calibration tests | ✅ | `tests/unit/test_game_scale.gd` (28 tests) |
| Asset loader tests | ✅ | `tests/unit/test_asset_loader.gd` (21 tests) |
| Update `Constants` with paths + bands | ✅ | `src/autoload/constants.gd` |

**Requirements covered:** SU-001 (scale), SU-003 (asset loading)
**Tests delivered:** 49 new (180 total, all passing)

#### Scale Centralisation Refactoring

All physical dimensions (mm values) are now centralised in
`Resources/Game_Components/scale/scale_config.json` under the
`physical_dimensions_mm` section. GDScript files no longer contain
hardcoded mm constants — `GameScale` loads everything from JSON at
startup. The refactoring removed 10 hardcoded constants from
`game_scale.gd` and 6 duplicate constants from `constants.gd`.

**Changed files:**

| File | Change |
|------|--------|
| `scale_config.json` | Added `physical_dimensions_mm` section (ruler, bases, squadron, segments, multiplier) |
| `game_scale.gd` | Replaced 10 `const` values with vars loaded from JSON; added `_load_physical_dimensions()`, `_compute_derived_values()`, `_load_base_graphics()` helpers |
| `constants.gd` | Removed 6 mm constants (`RULER_LENGTH_MM`, ship base mm values, `SQUADRON_BASE_DIAMETER_MM`) |
| 4 test files | Added `physical_dimensions_mm` block to inline config dictionaries |

**Tests:** 23 scripts, 362 tests, 780 asserts — all passing.

---

### Phase 1: Core Geometry Engine ✅
**Status:** Complete — all 274 tests passing
**Goal:** Build the mathematical foundation for positions, firing arcs, range measurement, and collisions.
**Prerequisites:** Phase 0 (scale constants)

| Task | Status | Deliverable |
|------|--------|-------------|
| `Geometry2DHelper` — point/line/polygon math | ✅ | `src/core/geometry_helper.gd` |
| `ShipBase` — base shape, hull zone polygons, firing arc rays | ✅ | `src/core/ship_base.gd` |
| `FiringArc` — point-in-arc tests, hull zone classification | ✅ | `src/core/firing_arc.gd` |
| `RangeMeasurer` — range/distance calculation | ✅ | `src/core/range_measurer.gd` |
| `SquadronBase` — circular base, overlap detection | ✅ | `src/core/squadron_base.gd` |
| `ManeuverCalculator` — segment chain math, yaw angles | ✅ | `src/core/maneuver_calculator.gd` |

**Requirements covered:** AT-040–043 (firing arcs), AT-010–014 (range/colour), AT-050–053 (measurement), GC-003 (bases), SM-001/003 (squadron base), MV-001–006/010–015 (maneuver)
**Future-proofing:** Geometry primitives (line intersection, polygon overlap) reused by Phase 6 LOS system.

**Tests delivered:** ~94 new (274 total, all passing)

---

### Phase 2: Game Board & Token Display ✅
**Status:** Complete — committed `5ec46ff`, 303 tests passing
**Goal:** Visual game board with ship/squadron tokens, pannable/zoomable camera, and Learning Scenario initial placement.
**Prerequisites:** Phase 0 (assets), Phase 1 (geometry for base shapes)

| Task | Status | Deliverable |
|------|--------|-------------|
| Play area scene | ✅ | `src/scenes/game_board/game_board.tscn` + `game_board.gd` |
| Camera2D with pan/zoom | ✅ | `src/scenes/game_board/board_camera.gd` |
| Ship token scene | ✅ | `src/scenes/tokens/ship_token.tscn` + `ship_token.gd` |
| Squadron token scene | ✅ | `src/scenes/tokens/squadron_token.tscn` + `squadron_token.gd` |
| Firing arc overlay | ✅ | `src/scenes/tokens/firing_arc_overlay.gd` (toggleable wedge display) |
| Token placement setup data | ✅ | `src/core/learning_scenario_setup.gd` + `src/models/token_placement.gd` |
| EventBus `firing_arc_toggled` signal | ✅ | `src/autoload/event_bus.gd` |
| Map background from scenario JSON | ✅ | `"map_image"` field in scenario JSON → `game_board.gd` draws texture |

**Requirements covered:** SU-001, SU-002, GC-001–004, UI-001, UI-011, SU-027
**Tests delivered:** 29 new (303 total, all passing)

---

### Phase 2b: Debug Token Placement ✅
**Goal:** Interactive token drag/rotate with deployment zone enforcement and position persistence for development and visual testing during setup.
**Prerequisites:** Phase 1 (geometry for overlap detection), Phase 2 (tokens on board)
**Duration estimate:** 2 sessions
**Completed:** 2025-03-14 · 23 scripts · 362 tests · 780 asserts

| Task | Layer | Requirements | Deliverables |
|------|-------|-------------|--------------|
| `DebugMode` autoload — global toggle + state | Autoload | DBG-001, DBG-002 | `src/autoload/debug_mode.gd` ✅ |
| `TokenMover` — mouse-follow, projection-based push-out | Core | DBG-011, DBG-020, DBG-022 | `src/core/token_mover.gd` ✅ |
| Token selection/deselection in debug mode | Application | DBG-010 | Extend `game_board.gd` click handler ✅ |
| Token rotation via trackpad gesture | Presentation | DBG-012 | Input handling in `game_board.gd` ✅ |
| Closest-legal-position collision resolution | Core | DBG-020, DBG-022 | Push-out along blocker→mouse direction; Minkowski boundary ✅ |
| Deployment zone lines (2 × thin blue horizontal) | Presentation | DBG-030, DBG-031 | `src/scenes/game_board/deployment_zone_overlay.gd` ✅ |
| Deployment zone boundary collision | Core | DBG-032 | Treat deployment line as wall in `TokenMover` ✅ |
| Save token positions to scenario JSON | Application | DBG-040, DBG-041 | `src/utils/scenario_saver.gd` + Ctrl+S shortcut ✅ |
| Debug HUD indicator | Presentation | DBG-002 | Label on `CanvasLayer` (layer 100) ✅ |
| Camera conflict prevention | Presentation | DBG-003 | Input routing: debug drag vs camera pan ✅ |

#### Collision Resolution Refactoring

The original implementation used binary-search along the **movement vector**
(current_pos → desired_pos) to find a contact point, plus a separate "jump-past"
step. This was replaced with **projection-based push-out** (DBG-020 revised, DBG-022):

- When a token at the desired (mouse) position overlaps a blocker, the resolver
  computes the nearest non-overlapping position by projecting outward from the
  **blocker's centre** along the direction toward the **mouse cursor**.
- For circle↔circle: exact Minkowski formula (no binary search).
- For ship↔ship and ship↔circle: binary search along the blocker→mouse ray.
- For circle←ship: closest-point-on-polygon + radial push.
- Among all push-out candidates, the one closest to the mouse that satisfies
  all constraints (other tokens, deployment zone, play area) is returned.
- Jump-past (former DBG-021) is subsumed: if the mouse is beyond a blocker and
  the footprint fits, the desired position is returned directly (step 2).

**Tests:** 16 token_mover tests (14 original + 3 new projection tests − 1 renamed) — 23 scripts, 365 tests, 786 asserts.

---

### Phase 2c: Debug Mode — Relaxed Deployment Zones ✅
**Goal:** Allow tokens to be dragged outside their deployment zone in debug mode (advisory-only zone boundaries). Show a toast warning when a dragged token leaves its zone. Preserve all zone validation logic for full-game enforcement later.
**Prerequisites:** Phase 2b (debug token placement, deployment zone overlay, TokenMover)
**Duration estimate:** 1 session

| Task | Layer | Requirements | Deliverables |
|------|-------|-------------|--------------|
| Add `enforce_deploy_zones` flag to `TokenMover` resolve methods | Core | DBG-032 (revised), DBG-034 | Modify `resolve_ship_position()` + `resolve_squadron_position()` ✅ |
| Skip zone clamping in push-out collection when flag is false | Core | DBG-032, DBG-034 | Modify `_collect_ship_pushouts()` + `_collect_circle_pushouts()` ✅ |
| Pass `enforce_deploy_zones = false` from `game_board.gd` in debug mode | Application | DBG-032 | Modify `_move_ship_token()` + `_move_squadron_token()` ✅ |
| Add `is_in_deploy_zone()` static helper to `DeploymentZoneOverlay` | Presentation | DBG-033 | New method: checks Y position against faction zone boundary ✅ |
| Toast warning on zone crossing during debug drag | Presentation | DBG-033 | In `_move_selected_token_to_mouse()`: detect crossing, fire `TooltipManager.show_text()` ✅ |
| Track "was in zone" state to fire toast only on crossing | Presentation | DBG-033 | `_was_in_deploy_zone: bool` flag in `game_board.gd` ✅ |
| Unit tests for relaxed zone movement + toast trigger | Test | DBG-032–034 | `tests/unit/test_relaxed_deploy_zones.gd` (16 tests) ✅ |

**Requirements covered:** DBG-032 (revised), DBG-033, DBG-034
**Tests delivered:** 16 new (949 total, 55 scripts, 1793 asserts — all passing)

---

### Phase 3: Game State Wiring ✅
**Status:** Complete — 486 tests passing (29 scripts, 1034 asserts)
**Goal:** Wire `GameState`/`PlayerState` core to visual tokens. Initialize the Learning Scenario.
**Prerequisites:** Phase 2 (visual tokens exist), existing core classes
**Duration estimate:** 2 sessions

| Task | Layer | Requirements | Deliverables |
|------|-------|-------------|--------------|
| `ShipInstance` — runtime ship state (hull, shields, tokens, dials) | Core | SU-021–026 | `src/core/ship_instance.gd` ✅ |
| `SquadronInstance` — runtime squadron state | Core | SU-024–025 | `src/core/squadron_instance.gd` ✅ |
| `DamageDeck` — shuffled 52-card deck with draw/discard | Core | SU-029, DM-007–009 | `src/core/damage_deck.gd` ✅ |
| `LearningScenarioSetup` — creates exact starting state | Core | SU-010–030 | `src/core/learning_scenario_setup.gd` ✅ |
| Wire `ShipInstance` ↔ `ShipToken` via EventBus | Application | — | Two-way sync: state changes → visual updates ✅ |
| Shield/hull/speed display on bases | Presentation | GC-010, UI-007 | Shield, hull, speed value labels on ship tokens ✅ |
| Ship card side panels (Rebel left, Imperial right) | Presentation | GC-005, UI-016, UI-017 | `src/ui/ship_card_panel.gd` — CanvasLayer panels outside board ✅ |
| Defense token column left of ship cards | Presentation | GC-011, UI-006, SU-026 | Integrated in `ship_card_panel.gd` (vertical token column) ✅ |
| Click-to-magnify on ship card entries | Presentation | UI-018 | 2.5–3× toggle zoom per entry, configurable via `scale_config.json` ✅ |
| All panel sizes from scale_config.json | Data | — | `card_panel` section in `scale_config.json`, loaded by `GameScale` ✅ |

**Requirements covered:** SU-010–030 (setup), GC-005 (ship cards), GC-010 (shield display), GC-011 (defense tokens), UI-006 (token states), UI-007 (shield values), UI-016 (card panels), UI-017 (tokens on panels not board), UI-018 (magnify toggle)
**Tests delivered:** 126 new (486 total, 29 scripts, all passing)

---

### Phase 4: Command Phase ✅
**Goal:** Implement command dial selection, command dial stack display, command tokens, picker modal, and command dial order modal.
**Prerequisites:** Phase 3 (ShipInstance with dial stacks, ship card panels)
**Duration estimate:** 3 sessions
**Completed:** 583 tests passing (33 scripts, 1187 asserts)

| Task | Layer | Requirements | Deliverables | Status |
|------|-------|-------------|--------------|--------|
| `CommandDialStack` — ordered stack of facedown dials per ship | Core | CP-001–007 | `src/core/command_dial_stack.gd` | ✅ |
| Add dial + token sizes to `scale_config.json` | Data | — | `card_panel` section: `dial_height_px`, `dial_width_px`, `dial_stack_offset_px`, `cmd_token_height_px` | ✅ |
| Command dial composite rendering (hidden/revealed/spent) | Presentation | GC-008, UI-019, UI-020 | Runtime composite: `cmd_dial_hidden.png` + `cmd_<type>.png` overlay | ✅ |
| Command dial stack in ship card panel | Presentation | UI-019, UI-020 | Extend `ship_card_panel.gd` — vertical dial stack below defense tokens, 20 px overlap offset, all hidden dials facedown | ✅ |
| Command Dial Picker modal (select + confirm) | Presentation | UI-005, UI-021, CP-005 | `src/ui/command_dial_picker.gd` — centred modal, 4 icons in cycle order, stack area, CONFIRM button | ✅ |
| Round 1 multi-dial / Rounds 2+ single-dial picker logic | Core/Pres | CP-003, CP-004 | Picker enforces correct dial count per round | ✅ |
| Command Dial Order modal (queued hidden dials in stack order) | Presentation | UI-022, UI-023 | `src/ui/command_dial_order_modal.gd` — click own stack to open, click to close | ✅ |
| Opponent dial viewing restriction | Core/Pres | UI-023, NW-005 | Click on opponent stack has no effect | ✅ |
| `CommandTokenManager` — command token management | Core | CM-004–006 | `src/core/command_token_manager.gd` — token supply, assignment, duplicate/overflow rules | ✅ |
| Command token display (right of ship card in panel) | Presentation | GC-018 | Extend `ship_card_panel.gd` — vertical token stack right of card | ✅ |
| "Both submitted" gate | Core/App | CP-008, NW-007 | Phase transition blocked until both players submit | ✅ |
| Phase transition (Command → Ship) | Application | GF-002 | GameManager state update + EventBus signals | ✅ |

**Requirements covered:** CP-001–008 (Command Phase rules), GC-008 (dial rendering), GC-018 (command tokens), UI-005 (secret picker), UI-019 (dial stack display), UI-020 (spent dial), UI-021 (picker modal), UI-022 (dial order modal), UI-023 (opponent restriction), CM-004–006 (token management)
**Tests delivered:** 97 new (583 total, 33 scripts, all passing)

---

### Phase 4b: Turn Management & Board Perspective ✅
**Goal:** Implement active player tracking, board perspective rotation, card panel swapping, player handoff overlay, sequential command phase for hot-seat, and the "End Activation" button. This is the foundational turn-management layer that all subsequent phases (Ship, Squadron, Status) depend on.
**Prerequisites:** Phase 4 (Command Phase — both-submitted gate, phase transitions)
**Duration estimate:** 2–3 sessions
**Completed:** 635 tests passing (40 scripts, 1246 asserts)

| Task | Layer | Requirements | Deliverables |
|------|-------|-------------|-------------|
| Play mode config (hot-seat / network stub) | Autoload | PM-001–004 | `src/autoload/play_mode.gd` — singleton with `PlayMode.HOT_SEAT` / `PlayMode.NETWORK` enum |
| Active player tracking in GameManager | Core/App | TF-001 | `GameManager.active_player` property, `active_player_changed` signal on EventBus |
| Sequential command phase (hot-seat) | Application | TF-002, HO-003, BP-006 | Retrofit `_begin_command_dial_flow()`: initiative player assigns first → handoff → second player assigns |
| Board camera 180° rotation on player switch | Presentation | BP-001, BP-002 | Extend `BoardCamera` with `rotate_to_player()` — smooth animated rotation around board centre |
| Card panel swap (active player → left) | Presentation | BP-003, UI-016 | `ShipCardPanel` swap logic: active player panels on left, opponent on right |
| Perspective transition animation | Presentation | BP-004 | Configurable duration (default 0.5 s) in `scale_config.json` |
| Handoff overlay (Command Phase — full) | Presentation | HO-001, HO-002, HO-003 | `src/ui/handoff_overlay.gd` — full-screen overlay with player name, phase, "Ready" button |
| "Your Turn" banner (Ship/Squadron phases) | Presentation | HO-004 | Brief banner on player switch, auto-dismiss or click-dismiss |
| Auto-pass detection | Core | TF-006, TF-009, HO-005 | Skip handoff when a player has no unactivated units |
| "End Activation" button (shared UI) | Presentation | TF-005, TF-011 | `src/ui/end_activation_button.gd` — visible during Ship/Squadron phases, emits `activation_ended` signal |
| Initiative tracking clarification | Core | IN-001–003 | Ensure `GameState.initiative_player` is distinct from slider-flip; Rebel always first |
| Network mode stub (no-op paths) | Application | PM-003, BP-005 | Conditional branches that skip perspective rotation and handoff in network mode |

**Requirements covered:** PM-001–004 (play mode), TF-001–014 (turn flow), BP-001–006 (board perspective), HO-001–005 (player handoff), IN-001–003 (initiative)
**Tests delivered:** 52 new (635 total, 40 scripts, all passing)

---

### Phase L: Game Logging Tooling ✅
**Goal:** Extend the existing `GameLogger` utility with optional file-based output, activated by a `--logging` CLI flag. Log all game flow events (phase transitions, active player changes, command dial assignments, activations, auto-pass) to a timestamped file for debugging.
**Prerequisites:** Phase 4b (turn management signals exist)
**Duration estimate:** 1 session
**Completed:** 672 tests passing (43 scripts, 1316 asserts)

| Task | Layer | Requirements | Deliverables |
|------|-------|-------------|--------------|
| `LoggingMode` autoload | Autoload | LOG-001 | `src/autoload/logging_mode.gd` — parses `--logging` CLI flag, exposes `LoggingMode.enabled` |
| Extend `GameLogger` with file output | Utils | LOG-002, LOG-003, LOG-005 | Add optional `FileAccess` sink to `GameLogger._log()`; open/flush/close lifecycle |
| Session header block | Utils | LOG-004 | Write Godot version, OS, timestamp, play mode at file start |
| Log format compliance | Utils | LOG-006, LOG-007 | Ensure file lines match `[timestamp] [LEVEL] [context] message` |
| Game lifecycle logging | Core/App | LOG-010 | Log `game_started` (factions, initiative) and `game_ended` (winner) |
| Round transition logging | Core/App | LOG-011 | Log `round_started(N)` and `round_ended(N)` |
| Phase transition logging | Core/App | LOG-012 | Log every `phase_changed` with phase name |
| Active player change logging | Core/App | LOG-013 | Log `active_player_changed` with faction and phase context |
| Command dial event logging | Core/App | LOG-014, LOG-015 | Log each ship's dial pick and per-player submission |
| Handoff event logging | Core/App | LOG-016 | Log `handoff_requested` and `handoff_accepted` |
| Activation lifecycle logging | Core/App | LOG-017, LOG-018 | Log `activation_ended` with ship/squadron name |
| Auto-pass detection logging | Core/App | LOG-019 | Log when a player is auto-passed (no unactivated units) |
| Phase state snapshot | Core/App | LOG-020 | Log game state summary at each phase boundary |
| Launch script `--logging` flag | Scripts | LOG-021, LOG-022, LOG-023 | Update `run_board.sh` and `run_game.sh` to accept `--logging` |
| Unit tests | Tests | LOG-030–032 | File toggle, format compliance, header content |
| Integration tests | Tests | LOG-033 | Phase transitions and events produce correct log sequence |

**Requirements covered:** LOG-001–023 (activation, format, events, scripts), LOG-030–033 (tests)
**Tests delivered:** 36 new (671 total, 43 scripts, all passing)

---

### Post-Phase-L Bug Fixes ✅
**Goal:** Address issues discovered during manual playtesting of the Phase 4b/L hot-seat flow.
**Completed:** 672 tests passing (43 scripts, 1316 asserts)

| Commit | Fix | Layer | Details |
|--------|-----|-------|---------|
| `581e030` | Double phase advance on dial submission | Application | `_on_command_picker_confirmed` emitted `command_dials_submitted` AND called `_check_command_phase_complete()` — synchronous signal delivery caused double advance (Command → Ship → Squadron). Removed redundant call; added defensive phase guard. +1 regression test. |
| `4c3d2dd` | Camera not rotating for player switch | Presentation | `Camera2D.ignore_rotation` defaults to `true` in Godot 4; tween animated `rotation` but viewport ignored it. Set `ignore_rotation = false` in `_ready()`. |
| `af2714b` | No initial handoff overlay at game start | Presentation | `active_player_changed` signal fired before `_connect_signals()` in `game_board._ready()`. Added manual initial call + deferred dial flow to handoff acceptance. |
| `0606e16` | Inverted mouse controls at 180° rotation | Presentation | Screen-to-world conversions in `BoardCamera` didn't account for camera rotation. Applied `.rotated(-rotation)` to all pan/zoom screen-space offsets. |
| `5db1b48` | Opponent command dial stacks viewable | Presentation | `ShipCardPanel._viewer_player` was `-1` (unset), disabling the access guard. Now set via `setup()` and updated on `active_player_changed`. |

**Requirements reinforced:** BP-001/002 (camera rotation), HO-001/003 (handoff overlay), UI-023 (opponent dial restriction), CP-001 (phase sequence)
**Tests delivered:** 1 new regression test (672 total, 43 scripts, all passing)

---

### Phase 4c: Ship Activation Trigger ✅
**Status:** Complete — committed `35f7e12`, bug fixes in `35f0f39`, `c666d52`, `36460b5`
**Goal:** Enable players to activate ships during the Ship Phase by dragging the topmost command dial to the ship token on the board. This is the minimal activation flow that enables the turn loop to reach round 2+ interactively, without implementing movement or attacks.
**Prerequisites:** Phase 4b (turn management, End Activation button), Phase 3 (ShipInstance, CommandDialStack)
**Duration estimate:** 1–2 sessions
**Completed:** 701 tests passing (44 scripts, 1358 asserts)

| Task | Layer | Requirements | Deliverables | Status |
|------|-------|-------------|-------------|--------|
| Drag source on topmost dial in ShipCardPanel | Presentation | UI-024 | Extend `ship_card_panel.gd` — topmost hidden dial becomes draggable during Ship Phase | ✅ |
| Drag preview (floating dial graphic) | Presentation | UI-024 | Semi-transparent dial follows mouse during drag | ✅ |
| Drop target on ShipToken | Presentation | UI-024 | `ship_token.gd` accepts dial drop, validates ownership + not-yet-activated | ✅ |
| Reveal dial on successful drop | Core | SP-010, SP-011 | Call `CommandDialStack.reveal_top()`, emit `command_revealed` signal | ✅ |
| Show revealed dial behind ship base on board | Presentation | UI-025 | Composite Node2D (`cmd_dial_hidden.png` background + `cmd_<type>.png` icon at 75%) positioned 1 cm aft of ship base | ✅ |
| "End Activation" marks ship activated + spends dial | Core/App | UI-026, SP-002, TF-005 | Call `CommandDialStack.spend_revealed()`, set `activated_this_round = true`, remove board dial sprite | ✅ |
| Refresh card panel dial stack display | Presentation | UI-019, UI-020 | Emit `command_dials_changed` so ShipCardPanel updates (revealed → spent) | ✅ |
| Full-scope skip: Attack + Maneuver steps | — | SP-013–015 | **Deferred to Phase 5/6.** Activation currently goes directly from Reveal Dial → End Activation. | ✅ |

> **Full-scope gaps (for seamless Phase 5/6 integration):**
>
> The following activation sub-steps are intentionally skipped in Phase 4c and must be added later:
>
> 1. **Keep-or-convert choice (SP-011):** After revealing the dial, the player should choose to keep it (spend during activation) or convert it to a command token. Phase 4c always keeps the dial. **→ Moved to Phase 4d** (drag-to-card = convert, drag-to-ship = keep).
> 2. **Attack step (SP-013, SP-014):** Up to 2 attacks from different hull zones. Deferred entirely to Phase 6.
> 3. **Execute Maneuver step (SP-015):** Mandatory movement using the maneuver tool. Deferred entirely to Phase 5.
> 4. **Navigate command resolution (CM-010–013):** Speed/yaw modification during movement. Deferred to Phase 5.
> 5. **Squadron command resolution (CM-020–022):** Activate squadrons at range after dial reveal. Deferred to Phase 7.
> 6. **Repair command resolution (CM-030–037):** Engineering points for shield/hull recovery. Deferred to Phase 9.
> 7. **Concentrate Fire (CM-040–042):** Extra die / reroll during attack. Deferred to Phase 6.
> 8. **CM-007 (unused dial discard):** If the dial is not spent during activation, it should be discarded. Phase 4c always spends/discards on End Activation. Full logic in Phase 5.
> 9. **Activation step gating:** "End Activation" should only be available after Attack + Maneuver are complete. Phase 4c allows immediate end. Phase 5 must add step-by-step gating.

**Requirements covered:** UI-024 (drag-and-drop), UI-025 (dial behind base), UI-026 (spent transition), SP-010 (activate), SP-011 (reveal top — partial), IN-001 (initiative stays with Rebel)
**Tests delivered:** 21 new (701 total, 44 scripts, all passing)

#### Post-Phase-4c Bug Fixes

Three fix commits addressed issues discovered during multi-round playtesting:

| Commit | Fix | Layer | Details |
|--------|-----|-------|---------|
| `35f0f39` | Composite dial graphic, spent dial gap, round-2 cleanup + picker context | Presentation | Revealed dial on board now uses a composite Node2D (background + icon overlay at 75%) instead of a single sprite. Spent dial in card panel displays below active stack with 12 px gap using `SIZE_SHRINK_CENTER`. Status Phase clears spent history (`clear_spent_history()`) so round-2 card panel starts fresh. Command dial picker shows existing stack commands for player context. |
| `c666d52` | Hide revealed dial from stack, center spent dial alignment | Presentation | Revealed dial no longer appears in the card panel dial stack (only visible on board token). Spent dial Control uses `SIZE_SHRINK_CENTER` to prevent VBoxContainer stretching. |
| `36460b5` | Initiative stays with first player, fix round-2 dial assignment | Core | Initiative no longer flips during Status Phase — per RRG "Initiative" p.8: "The first player retains initiative for the entire game." Rebel player (player 0) always has initiative (IN-001). `get_dials_needed()` changed from `get_dials_needed(current_round: int)` to parameterless — now returns `max(0, command_value - get_dial_count())`, making it state-aware instead of hardcoding round logic. Fixes Nebulon-B being skipped in round 2. |

---

### Phase 4d: Keep-or-Convert Dial Choice ✅
**Goal:** Extend the dial drag-and-drop activation to support both SP-011 paths: dragging the dial to the **ship token on the board** keeps it for its full command effect (existing behaviour), while dragging it to the **ship card panel entry** converts it to a matching command token. A help text guides the player during the drag.
**Prerequisites:** Phase 4c (dial drag-and-drop activation), Phase 4 (CommandTokenManager)
**Duration estimate:** 1 session

| Task | Layer | Requirements | Deliverables |
|------|-------|-------------|-------------|
| Drag help text overlay | Presentation | UI-027 | Show *"Drag to ship for full command effect · Drag to ship card for command token"* while dragging; disappears on drop/cancel |
| Drop target on ShipCardPanel entry | Presentation | UI-028, UI-024 | `ship_card_panel.gd` accepts dial drop on the owning ship's card entry |
| Convert dial to command token on card drop | Core/App | UI-028, SP-011, CM-004–006 | Call `CommandTokenManager.add_token()` with matching type; enforce duplicate/overflow rules (CM-004/CM-005) |
| Move dial to spent area on card drop | Presentation | UI-028, UI-020 | Call `CommandDialStack.spend_revealed()` immediately; update card panel display |
| Begin activation after card drop | Core/App | UI-028, SP-010 | Ship enters activated state (same as board drop), "End Activation" becomes available |
| No revealed dial on board for card drop | Presentation | UI-028 | Skip the composite dial sprite behind ship base — no board visual since dial was converted |
| Command token display update | Presentation | GC-018 | New token appears in the vertical token stack to the right of the ship card |

> **Rules Reference:** "Command Dials", p.3: "When a ship's command dial is revealed,
> the player can either resolve the command at the appropriate time during the
> ship's activation or spend the command dial to gain a command token of the
> same type." SP-011b implements the latter path.

**Requirements covered:** UI-027 (help text), UI-028 (drag-to-card converts), SP-011 (full keep-or-convert), CM-004–006 (token rules)
**Tests:** 15 (activate_ship_as_token domain tests, token overflow/duplicate rejection, activation ended after token convert, card panel hit detection, full cycle mix of board + card drops)

---

### Phase 4e: Command Token Overflow Discard ✅
**Goal:** When a dial-to-token conversion would exceed the ship's command value, temporarily add the token and prompt the player to click one of the surplus tokens to discard. For duplicates, auto-discard immediately and show a brief notification.
**Prerequisites:** Phase 4d (keep-or-convert), Phase 4 (CommandTokenManager)
**Duration estimate:** 1 session

| Task | Layer | Requirements | Deliverables |
|------|-------|-------------|-------------|
| `force_add_token()` in CommandTokenManager | Core | CM-004, CM-005 | Bypasses capacity/dup checks; returns `{overflow, duplicate}` dict |
| EventBus discard signals | Autoload | — | `token_discard_required`, `token_discarded`, `duplicate_token_discarded` |
| Refactor `activate_ship_as_token()` | Core/App | CM-004, CM-005 | Use `force_add_token()`, emit overflow/duplicate signals |
| Token discard mode in ShipCardPanel | Presentation | CM-004, UI | Clickable tokens, prompt label, colour tint; player clicks to discard |
| GameBoard discard flow wiring | Presentation | CM-004 | Delay End Activation button until discard resolved |
| Duplicate token notification | Presentation | CM-005 | Brief toast label ("Duplicate discarded") that auto-hides after 2s |
| Unit tests for `force_add_token` | Test | — | 6 tests: normal, overflow, duplicate, cmd-value-1, resolve scenarios |
| Integration tests for discard flow | Test | — | 4 tests: overflow signal, duplicate signal, manual discard resolve, no-overflow baseline |

> **Rules Reference:** "Command Tokens", p.4: "When a ship is assigned a command
> token, if it has more command tokens than its command value, it must immediately
> discard one of its command tokens." Also: "When a ship is assigned a command
> token, if it already has a copy of that command token, it must immediately
> discard that command token."

**Requirements covered:** CM-004 (overflow discard), CM-005 (duplicate auto-discard)
**Tests:** ~10 (6 unit + 4 integration)

---

### Phase 4f: Hover Tooltip Infrastructure ✅
**Goal:** Build a reusable, globally switchable tooltip system that displays contextual help text on hover (with configurable delay) and replaces all existing ad-hoc help labels (drag help, discard prompt, duplicate toast) with a single unified mechanism.
**Prerequisites:** Phase 4d (drag help label to migrate), Phase 4e (discard prompt + duplicate toast to migrate)
**Duration estimate:** 2 sessions
**Architecture:** arc42 § 8.8 · ADR-009 · Requirements: `docs/requirements/hover_tooltip_system.md`

| Task | Layer | Requirements | Deliverables |
|------|-------|-------------|---------------|
| Add `"tooltip"` section to `scale_config.json` | Data | TT-040, TT-042, TT-075 | New config block with delay, offset, max width, font, colours, toggle button size |
| `GameScale` tooltip properties | Autoload | TT-041, TT-042 | `tooltip_hover_delay_sec`, `tooltip_offset`, `tooltip_max_width_px`, `tooltip_font_size`, etc. |
| `TooltipLayout` — pure position / clamping logic | Core | TT-020, TT-021, TT-060 | `src/core/tooltip_layout.gd` (RefCounted, static `compute_position()`) |
| `TooltipLayout` unit tests | Test | TT-062 | `tests/unit/test_tooltip_layout.gd` — 5 tests: normal offset, flip H, flip V, flip both, clamp-to-zero |
| `TooltipPanel` — styled BBCode popup widget | Presentation | TT-010, TT-011, TT-030–035 | `src/ui/tooltip_panel.gd` (PanelContainer + RichTextLabel, MOUSE_FILTER_IGNORE) |
| `TooltipManager` autoload (registration, state machine, timer) | Autoload | TT-001–007, TT-012–013, TT-050–052 | `src/autoload/tooltip_manager.gd` — register/deregister, 4-state hover FSM (IDLE → WAITING → SHOWING / FORCED) |
| Global toggle button (lower-right corner) | Presentation | TT-070–075 | Icon button on TooltipLayer; toggles `tooltips_enabled`; persists to `user://settings.cfg` |
| `TooltipManager` integration tests | Test | TT-061–063 | `tests/integration/test_tooltip_manager.gd` — 11 tests: hover delay, exit, empty-callback suppression, programmatic override, auto-hide, deregister, freed-control, region-change reset, toggle disabled hover, toggle allows programmatic |
| Wire hover regions (ShipCardPanel: dial stack + card entry) | Presentation | TT-012, TT-080–086 | `register()` calls with context-sensitive callbacks: dial stack (reveal/drag/order), card entry (magnify). Two callbacks + two registrations per ship entry |
| Migrate drag help label → `show_text()` | Presentation | UI-027, TT-005, TT-053 | Remove `_create_drag_help_label()` / `_center_drag_help_label()` / `_drag_help_label` from `game_board.gd`; use `TooltipManager.show_text()` on drag start, `.hide()` on drop |
| Migrate discard prompt → `show_text()` | Presentation | TT-005, TT-053 | Remove discard prompt Label from `ship_card_panel.gd`; use `TooltipManager.show_text("Click a token to discard")` |
| Migrate duplicate toast → `show_text()` + auto-hide | Presentation | TT-005, TT-053 | Remove toast Label from `ship_card_panel.gd`; use `TooltipManager.show_text(text, Vector2.INF, 2.0)` |
| Remove dead code from `game_board.gd` + `ship_card_panel.gd` | Presentation | TT-053 | Delete superseded Label creation/cleanup methods |
| Register `TooltipManager` in `project.godot` | Config | TT-051 | Autoload entry |
| Run full test suite — verify 0 failures + expected script count | Test | — | Regression check |

> **Key design decisions:**
>
> - **Callback-based text** (Callable, not static string) — each region's tooltip
>   text is computed at show-time, reflecting current game state (TT-012).
> - **FORCED state** in the state machine — programmatic `show_text()` overrides
>   hover and ignores the toggle switch, because drag help and discard prompts
>   are essential gameplay instructions, not optional hints (TT-007, TT-073).
> - **Toggle button** in lower-right corner — players who know the game can
>   disable hover hints without losing essential instructions (TT-070–075).
> - **Layer 100 CanvasLayer** — tooltip always renders above all other UI (TT-050).
> - **Auto-deregister** via `tree_exiting` signal — prevents use-after-free on
>   scene transitions (TT-052).

**Requirements covered:** TT-001–007 (hover trigger + programmatic API), TT-010–013 (content), TT-020–022 (positioning), TT-030–035 (visual style), TT-040–042 (configuration), TT-050–053 (lifecycle + migration), TT-060–063 (testability), TT-070–075 (global toggle), TT-080–086 (contextual hover hints), UI-027 (drag help migration)
**Tests:** 17 (5 unit + 12 integration) — 759 total, 47 scripts, 1488 asserts

---

### Phase 4g: Fixed Round-1 Commands ✅
**Goal:** Allow the learning scenario to use pre-assigned command dials in round 1, skipping the command phase entirely. Configurable via `use_fixed_round1_commands` and `fixed_round1_commands` fields in the scenario JSON. When active, `LearningScenarioSetup` auto-assigns each ship's dial stack from the JSON data, and `GameManager` skips the command phase UI in round 1.
**Prerequisites:** Phase 4 (CommandDialStack, command phase flow), Phase 3 (LearningScenarioSetup, ShipInstance)
**Duration estimate:** 1 session
**Requirements:** CP-009, CP-010
**Completed:** 933 tests passing (54 scripts, 1776 asserts)

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | Add `use_fixed_round1_commands` + `fixed_round1_commands` to `learning_scenario.json` | Data | CP-009 | New JSON fields: boolean toggle + per-ship-key command arrays | ✅ |
| 2 | Parse fixed commands in `LearningScenarioSetup` | Core | CP-009 | `has_fixed_round1_commands() -> bool`, `get_fixed_round1_commands() -> Dictionary`, `_parse_command_name()` helper | ✅ |
| 3 | Auto-assign dials in `GameManager.apply_fixed_round1_commands()` | Application | CP-009, CP-010 | Assigns dials to each ship, marks both players submitted, emits `command_phase_complete`, advances to Ship Phase | ✅ |
| 4 | Log auto-assigned commands via GameLogger | Utils | CP-010 | Log entry per ship: "Auto-assigned round 1 commands: <ship> = [<commands>]" | ✅ |
| 5 | Toast notification in `game_board.gd` | Presentation | CP-010 | "Round 1 commands pre-assigned" toast via `TooltipManager.show_text()` (3s auto-hide) | ✅ |
| 6 | Unit tests — parsing + auto-assign + dial order | Test | CP-009, CP-010 | `tests/unit/test_fixed_round1_commands.gd` — 17 tests covering parsing, apply, stack order, flag, preconditions | ✅ |

**Requirements covered:** CP-009 (fixed commands config + assignment), CP-010 (skip command phase in round 1)
**Tests:** 17 new (933 total, 54 scripts, 1776 asserts)

---

### Phase 5a: Maneuver Tool Visualization & Toolbar ✅
**Goal:** Standalone maneuver tool that can be displayed on the board, attached to a ship, with interactive joints. Plus a lower-right action toolbar that houses both the tooltip toggle and the new "Display Maneuver Tool" button.
**Prerequisites:** Phase 1 (ManeuverCalculator already has `compute_tool_joints()`, `YAW = 22.5°`), Phase 3 (ShipInstance/ShipToken), Phase 4f (tooltip toggle — relocated into toolbar)
**Requirements:** `docs/requirements/maneuver_tool.md` (MT-G-001–008, MT-U-001–006, MT-D-001–002, AC-01–16)
**Duration estimate:** 2 sessions → completed in 1

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | `GameScale` loads `maneuver_tool` config | Autoload | MT-D-001, AC-09 | `_load_maneuver_tool()` + `_parse_vec2()` in `game_scale.gd` | ✅ |
| 2 | `ManeuverToolState` — joint angles, active speed, yaw validation | Core | MT-M-001–004, AC-01–03, AC-12 | `src/core/maneuver_tool_state.gd` (RefCounted) | ✅ |
| 3 | `ManeuverToolScene` — renders segments as sprites, positions via chain math | Presentation | MT-G-001–002, MT-G-004–005, AC-04 | `src/scenes/tools/maneuver_tool_scene.gd` | ✅ |
| 4 | Joint interaction — left-click = port, right-click = starboard | Presentation | MT-G-003, MT-G-006, AC-05–06 | Click areas at each joint in ManeuverToolScene._try_joint_click | ✅ |
| 5 | Ghost ship preview | Presentation | MT-G-007, AC-07 | Transparent ship token at computed final transform | ✅ |
| 6 | `ActionToolbar` — lower-right HBoxContainer | UI | MT-U-001, AC-13 | `src/ui/action_toolbar.gd`; tooltip toggle reparented from TooltipManager | ✅ |
| 7 | "Display Maneuver Tool" button + ship selection mode | UI + Pres | MT-U-002–004, AC-14 | Button in toolbar → prompt → click ship → show tool on left side | ✅ |
| 8 | Dismissal (Escape / re-press button) | Presentation | MT-U-005–006, AC-15 | _handle_maneuver_tool_escape in GameBoard | ✅ |
| 9 | Contact points on all segments | Data + Core | MT-G-008, AC-16 | `contact_left`/`contact_right` in config for root, segment, segment_end | ✅ |
| 10 | Tests | Test | AC-11 | Unit: ManeuverToolState (26) + GameScale config (7) | ✅ |

**Requirements covered:** MT-G-001–008 (graphical), MT-U-001–006 (UI flow), MT-M-001–006 (math model state), MT-D-001–002 (data), AC-01–16
**Tests:** 36 (ManeuverToolState 29 + GameScale maneuver 7) — 796 total, 49 scripts, 1541 asserts

---

### Phase 5a+: Dynamic Alignment & Speed Simulation ✅
**Goal:** Auto-switch **both** root attachment and ghost alignment based on joint bending direction (tool follows the bend; ghost appears opposite). Add +/− speed simulation buttons on the end segment to preview different speeds without modifying ship state.
**Prerequisites:** Phase 5a (maneuver tool scene, tool state, ghost preview)
**Requirements:** `docs/requirements/maneuver_tool.md` §8–§11 (MT-A-001–004, MT-S-001–006, MT-D-003a, AC-17–25)
**Duration estimate:** 1 session

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | Dynamic side: compute alignment from joint angles | Core | MT-A-001–002, AC-17–18 | `ManeuverToolState.compute_ghost_side() → String` — scans joints end→start; left bend → "left", right bend → "right" | ✅ |
| 2 | Wire dynamic side into root attachment **and** ghost | Presentation | MT-A-003–004, AC-17 | `ManeuverToolScene._compute_attachment()` and `_update_ghost()` both use computed side | ✅ |
| 3 | Load speed button positions from config | Autoload | MT-D-003a, AC-25 | `GameScale._load_maneuver_tool()` parses `speed_reduction_button`/`speed_increase_button` | ✅ |
| 4 | Speed simulation in ManeuverToolState | Core | MT-S-002–004, AC-20–22, AC-24 | `set_simulated_speed()`, `get_simulated_speed()`, joint clamping, segment count adapts; min=1, max=ship_data.max_speed | ✅ |
| 5 | Speed +/− buttons on end segment | Presentation | MT-S-001, AC-19 | `ManeuverToolScene` renders two 20 px circle buttons with centred +/− labels at config positions, left-click handling | ✅ |
| 6 | Speed label on ghost | Presentation | MT-S-005, AC-23 | Draw simulated speed number at `token_label_offsets.speed` position on ghost sprite, matching ShipToken font/scale | ✅ |
| 7 | Tests | Test | AC-17–25 | Unit: `compute_ghost_side` cases, speed sim bounds/clamping, config loading | ✅ 16 tests |

**Requirements covered:** MT-A-001–004 (dynamic alignment), MT-S-001–006 (speed simulation), MT-D-003a (config), AC-17–25
**Tests:** 16 actual (ghost side logic ×5, speed sim ×9, setup ×2, config loading ×1) — 812 cumulative (49 scripts, 1566 asserts)

---

### Phase 5b: Ship Movement Execution ✅
**Goal:** Add activation modal that guides the player through the ship activation sub-steps (Reveal → Squadron → Repair → Attack → Execute Maneuver). Implement the Navigate command and actual ship placement via the maneuver tool. Overlap handling deferred to Phase 5b-2.
**Prerequisites:** Phase 5a/5a+ (maneuver tool), Phase 4c/4d (activation trigger + keep-or-convert)
**Duration estimate:** 3 sessions
**Commits:** `aba05de` (initial), `fe2d382`–`9939cb7` (8 bug-fix follow-ups)

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | `ShipActivationState` — step tracker | Core | ACT-002, FLOW-004, AC-5b-01 | `src/core/ship_activation_state.gd` (RefCounted) — tracks current step, spent commands, Navigate resources. Steps: REVEAL, SQUADRON, REPAIR, ATTACK, MANEUVER, DONE | ✅ |
| 2 | "Show Activation Sequence" button + Activation Modal UI | Presentation | ACT-001–004, ACT-007, AC-5b-01–02, AC-5b-14 | `src/ui/show_activation_button.gd` — bottom-centre button appears after dial reveal; pressing it opens `src/ui/activation_modal.gd` — centred panel matching CommandDialPicker style (StyleBoxFlat, `#0D1B2A` bg); 5 step rows with colour-coded states; two-phase button ("Execute Maneuver ►" → "Commit Maneuver ►"); dismissible via Escape/✕; steps 2–4 auto-skip with amber badges | ✅ |
| 3 | Navigate command resolution | Core | NAV-001–008, CM-010–013, AC-5b-04–06 | `ShipActivationState.can_change_speed()`, `apply_speed_change()`, `has_yaw_bonus()`, `apply_yaw_bonus()` — dial: speed ±1 AND/OR +1 yaw; token: speed ±1; combined: speed ±2 AND/OR +1 yaw. Speed changes are **reversible** (total-change vs budget model). Token actually removed from `CommandTokenManager` on commit. | ✅ |
| 4 | Wire +/− buttons to Navigate in activation mode | Presentation | NAV-008, AC-5b-04–07 | `ManeuverToolScene` detects activation vs simulation mode; +/− writes `ShipInstance.current_speed` gated by Navigate availability; reddish overlay on token when token-only spend; simulation button disabled during activation | ✅ |
| 5 | Yaw bonus joint (any joint) | Core + Pres | NAV-002, NAV-006, EXE-005, AC-5b-04 | Yaw bonus applied on-demand when player clicks a joint beyond its base limit — `_try_apply_yaw_bonus_for()` in `ManeuverToolScene`; bonus can be moved between joints; visual "N" badge follows the bonus joint | ✅ |
| 6 | Two-phase Execute/Commit button | Presentation | EXE-001, AC-5b-08 | Embedded in activation modal step 5 row: Phase 1 "Execute Maneuver ►" opens maneuver tool; Phase 2 "Commit Maneuver ►" commits position. Modal closes during both phases. | ✅ |
| 7 | Ship snap placement | Presentation | EXE-002, EXE-003, MV-010–014, AC-5b-09 | Ship token transform set to `compute_final_transform()` result; side from `compute_ghost_side()`; instant snap | ✅ |
| 8 | Speed 0 maneuver | Core | EXE-004, MV-015, AC-5b-10 | No tool displayed; ship stays in place; maneuver counts as executed | ✅ |
| 9 | Activation flow rewiring + auto-end | Presentation | FLOW-001–003, AC-5b-11 | "Show Activation Sequence" button replaces immediate End Activation after dial reveal. After Commit, `activation_ended` emits automatically — no manual End Activation button press required. Next player's turn starts immediately. | ✅ |
| 10 | Token spend highlight | Presentation | NAV-007, AC-5b-07 | Reddish semi-transparent overlay on Navigate token in ship card panel when speed change would require the token; Navigate token removed from ship on commit | ✅ |
| 11 | Tests | Test | AC-5b-01–15 | Unit: ShipActivationState step tracking, Navigate speed/yaw logic, combined dial+token, bounds; Integration: activation flow end-to-end | ✅ |

> **Note:** Activation trigger (drag-and-drop dial to ship) and basic reveal/spend flow
> are handled by Phase 4c. Phase 4d adds the keep-or-convert choice (drag to card = token).
> Phase 5b extends with the activation modal, Navigate command, and maneuver execution.
> Overlap handling (ship–ship, ship–squadron) is deferred to Phase 5b-2.

**Requirements covered:** ACT-001–007, NAV-001–008, EXE-001–005, FLOW-001–004, AC-5b-01–15, CM-010–013, MV-010–015
**Tests:** 33 (ShipActivationState: step tracking ×8, command resolution ×3, Navigate availability ×4, speed changes ×10, yaw bonus ×5, maneuver execution ×3) — 847 cumulative (50 scripts, 1635 asserts)

---

### Phase 5c: Range Overlay Tool ✅
**Goal:** Add an "R" button to the toolbar that shows per-firing-arc range bands (close/medium/long) around a selected ship. Pre-rendered overlay PNGs (one per ship type) are displayed as a Sprite2D beneath the ship token. The range overlay is a pure visual aid — no gameplay effect.
**Prerequisites:** Phase 0 (GameScale range values), Phase 2 (ShipToken, game board), Phase 5a (ActionToolbar)
**Duration estimate:** 1 session
**Commits:** `9319404` (initial algorithmic impl), `3a79c6e` (hull-zone fix)

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | Ship JSON data: firing arc boundaries + LOS origins | Data | RO-DATA-01 | 8 boundary points and 4 LOS origins in each ship JSON; `card_data_schema.json` updated | ✅ |
| 2 | Ship JSON data: range overlay image + origin | Data | RO-DATA-03 | `range_overlay.image` (filename) and `range_overlay.origin_px` ([x,y] of ship center) per ship JSON; 3 overlay PNGs at ruler pixel scale | ✅ |
| 3 | `ShipData` parsing | Model | RO-DATA-02, RO-DATA-03 | `firing_arc_boundaries`, `line_of_sight_origins`, `range_overlay_image`, `range_overlay_origin_px` fields | ✅ |
| 4 | `RangeOverlayScene` (sprite-based) | Presentation | RO-003, RO-006 | Sprite2D loads overlay texture, scales to game-scale, centres on ship token; z-order below all tokens | ✅ |
| 5 | Delete `RangeOverlayCalculator` | Cleanup | — | Remove `src/core/range_overlay_calculator.gd` and `tests/unit/test_range_overlay_calculator.gd` | ✅ |
| 6 | "R" button in ActionToolbar | Presentation | RO-001 | Button next to "M"; emits `range_overlay_requested`; disabled during activation alongside M | ✅ |
| 7 | GameBoard wiring | Presentation | RO-002, RO-007 | Ship selection mode → show overlay; toggle/dismiss via R press or Escape | ✅ |
| 8 | Tests | Test | RO-T-01 | `test_ship_data.gd` (+4 overlay field parsing tests) | ✅ |

**Requirements covered:** RO-001–RO-007, RO-008 (keyboard shortcut), RO-DATA-01/02/03, RO-T-01
**Tests:** 862 cumulative (50 scripts, 1653 asserts)

---

### Phase 5d: Targeting List Tool ✅
**Goal:** Add a "T" button to the toolbar that opens a modal panel showing all valid attack targets (outgoing) and threats (incoming) for the active player's ships. Includes range-finding, firing-arc containment, line-of-sight/obstruction algorithms. Ghost hypothetical section when the maneuver tool ghost is visible. Pure information tool — no gameplay effect.
**Prerequisites:** Phase 0 (GameScale range values), Phase 1 (geometry primitives), Phase 2 (ShipToken, SquadronToken), Phase 3 (GameState, PlayerState), Phase 5c (firing-arc boundary data, LOS origins data)
**Duration estimate:** 2 sessions
**Requirements:** `docs/requirements/targeting_list.md` (TL-RNG-001–006, TL-ARC-001–006, TL-LOS-001–009, TL-LIST-001–007, TL-UI-001–006, TL-ALGO-001–003)

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | `RangeFinder` — point-in-arc, closest-point, range measurement | Core | TL-RNG-001–006, TL-ARC-001–006 | `src/core/range_finder.gd` — arc containment, hull-zone edge closest point (within arc), squadron base closest point, range band classification, max attack range | ✅ |
| 2 | `LineOfSightChecker` — LOS trace + obstruction | Core | TL-LOS-001–009 | `src/core/line_of_sight_checker.gd` — segment-vs-OBR intersection, LOS from targeting points, blocked-by-other-hull-zone check (LOS + range path), obstruction by intervening ships, extensible obstacle array | ✅ |
| 3 | `TargetingListBuilder` — orchestrator | Core | TL-LIST-001–005, TL-ALGO-003 | `src/core/targeting_list_builder.gd` — iterates friendly ships × hull zones × enemies, calls RangeFinder + LOSChecker, returns structured result with outgoing + incoming entries + ghost section | ✅ |
| 4 | `TargetingListModal` — UI panel | Presentation | TL-UI-001–006, TL-LIST-006–007 | `src/ui/targeting_list_modal.gd` — PanelContainer, scrollable, per-ship sections, dice summary, obstruction flags, empty states, colour coding | ✅ |
| 5 | "T" button + GameBoard wiring | Presentation | TL-UI-001, TL-UI-003–004 | Button in ActionToolbar; emits `targeting_list_requested`; open/close toggle; Escape dismissal; snapshot semantics; ghost section from maneuver tool | ✅ |
| 6 | Unit tests — RangeFinder | Test | AC-TL-15, AC-TL-18 | `tests/unit/test_range_finder.gd` — point-in-arc, closest-point-within-arc, range band, max attack range, squadron base | ✅ |
| 7 | Unit tests — LineOfSightChecker | Test | AC-TL-15, AC-TL-18 | `tests/unit/test_line_of_sight_checker.gd` — LOS traces, blocked by other HZ, obstruction by intervening ship, obstacle array | ✅ |
| 8 | Unit tests — TargetingListBuilder | Test | AC-TL-01–18 | `tests/unit/test_targeting_list_builder.gd` — integration scenarios, ghost section, empty states, dice filtering by range | ✅ |

**Requirements covered:** TL-RNG-001–006, TL-ARC-001–006, TL-LOS-001–009, TL-LIST-001–007, TL-UI-001–006, TL-ALGO-001–003, AC-TL-01–18
**Tests:** 916 cumulative (53 scripts, 1741 asserts)

---

### Phase 5e: Keyboard Shortcuts for Tools ✅
**Goal:** Allow players to press **M**, **R**, or **T** on the keyboard to activate the Maneuver Tool, Range Overlay, and Targeting List respectively — same behaviour as clicking the toolbar buttons.
**Prerequisites:** Phase 5a (ActionToolbar, Maneuver Tool), Phase 5c (Range Overlay), Phase 5d (Targeting List)
**Duration estimate:** < 1 session
**Requirements:** MT-U-007, RO-008 (new), TL-UI-003a
**Commits:** `53d86d1`

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | Handle M/R/T key events in `game_board.gd` `_unhandled_input` | Presentation | MT-U-007, RO-008, TL-UI-003a | Key press → emit `EventBus` signal (same as button); guard against disabled state | ✅ |
| 2 | Add "Tools" section to `DebugHelpPanel` | Presentation | DBG-002 | M / R / T shortcuts shown in debug-mode help panel | ✅ |
| 3 | Update requirements & docs | Docs | — | MT-U-007 in maneuver_tool.md, TL-UI-003a in targeting_list.md, RO-008 in impl plan, manual test plan | ✅ |

**Requirements covered:** MT-U-007, AC-17, RO-008, TL-UI-003a
**Tests:** 949 cumulative (55 scripts, 1793 asserts)

---

### Phase 5d-fix: Targeting List Squadron Corrections ✅
**Goal:** Fix three squadron-related bugs in the targeting list: (1) ship → squadron uses battery armament instead of anti-squadron armament for dice/range, (2) incoming threats omit enemy squadrons entirely, (3) SquadInfo lacks armament fields.
**Prerequisites:** Phase 5d (Targeting List Tool)
**Duration estimate:** < 1 session
**Requirements:** TL-RNG-007, TL-LIST-008, TL-LIST-010, AC-TL-20–23

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | Add armament fields to `SquadInfo` | Core | TL-LIST-010, AC-TL-23 | `battery_armament` and `anti_squadron_armament` on `SquadInfo`; `_collect_squad_infos()` populates from JSON | ✅ |
| 2 | Fix `_check_squadron_target` to use anti-squadron armament | Core | TL-RNG-007, AC-TL-20, AC-TL-21 | Pass `anti_squadron_armament` for dice + max-range check instead of hull zone battery | ✅ |
| 3 | Add squadron incoming threats in `_build_incoming_threats` | Core | TL-LIST-008, AC-TL-22 | Enemy squads at distance 1 with battery armament appear as threats | ✅ |
| 4 | Unit tests for all three fixes | Test | AC-TL-18, AC-TL-20–23 | New tests in `test_targeting_list_builder.gd` | ✅ |
| 5 | Update requirements & docs | Docs | — | TL-RNG-007, TL-LIST-008, TL-LIST-010 in targeting_list.md; manual test plan | ✅ |

---

### Phase 5d-2: Targeting List — Squadron Sections & Hull Zone Detail ⏳
**Goal:** Extend the targeting list with three enhancements: (1) Add friendly squadron sections showing outgoing targets (ships + squadrons at distance 1) and incoming threats (enemy ships' anti-squadron arcs + enemy squadrons at distance 1). (2) Show per-defending-hull-zone breakdown for ship → ship targets instead of collapsing to the single closest zone. (3) Update the UI modal to display squadron sections and hull zone detail lines.
**Prerequisites:** Phase 5d (Targeting List Tool), Phase 5d-fix (squadron armament)
**Duration estimate:** 1–2 sessions
**Requirements:** TL-LIST-011–014, TL-RNG-003, TL-RNG-005, AC-TL-30–37

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | Add `target_zone` field to `TargetEntry` | Core | TL-LIST-013, AC-TL-35 | Optional `Constants.HullZone` on `TargetEntry`; populated for ship → ship, empty for squadron targets | ⏳ |
| 2 | Ship → ship: emit one `TargetEntry` per reachable defending hull zone | Core | TL-LIST-013, AC-TL-34 | `_check_ship_target` returns `Array[TargetEntry]` instead of collapsing to best; each entry carries `target_zone`, its own range/dice/obstruction | ⏳ |
| 3 | `SquadTargetingResult` + `_build_squad_entry` | Core | TL-LIST-011, TL-LIST-014, AC-TL-30–32 | New inner class; `_build_squad_entry` checks distance 1 to enemy ships (battery dice) and enemy squads (anti-sq dice); 360° arc, no LOS | ⏳ |
| 4 | `_build_incoming_squad_threats` | Core | TL-LIST-012, AC-TL-33 | Enemy ships with anti-sq armament in arc at range → threat; enemy squads at distance 1 → threat | ⏳ |
| 5 | `build()` returns combined results | Core | TL-LIST-014 | Return structure includes both `Array[ShipTargetingResult]` and `Array[SquadTargetingResult]`; backward-compatible wrapper or new return type | ⏳ |
| 6 | `TargetingListModal` — squadron sections | Presentation | AC-TL-36 | New `_build_squad_section()` renders squadron outgoing + incoming after ship sections | ⏳ |
| 7 | `TargetingListModal` — hull zone detail display | Presentation | AC-TL-37 | Ship → ship lines show "FRONT → LEFT at medium range (2 red, 1 blue)" format | ⏳ |
| 8 | `game_board.gd` — collect friendly squad infos for builder | Presentation | TL-LIST-011 | Pass friendly squadrons to builder alongside enemy squads | ⏳ |
| 9 | Unit tests — squadron targeting | Test | AC-TL-18, AC-TL-30–33 | Squad → ship, squad → squad, incoming to squads, empty states | ⏳ |
| 10 | Unit tests — per-hull-zone detail | Test | AC-TL-18, AC-TL-34–35 | Ship → ship returns multiple entries with different target_zones | ⏳ |
| 11 | Update requirements & docs | Docs | — | targeting_list.md, manual test plan | ⏳ |

**Requirements covered:** TL-LIST-011–014, TL-RNG-003, TL-RNG-005, AC-TL-30–37
**Tests:** ~15–20 new tests

---

### Phase 5b-2: Overlap Handling ⏳
**Goal:** Handle ship–ship and ship–squadron overlaps during movement.
**Prerequisites:** Phase 5b (maneuver execution)
**Duration estimate:** 1 session

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | Ship–ship overlap detection | Core | OV-010–013 | Detect overlap at final position; temp speed reduction loop; facedown damage to both ships | ⏳ |
| 2 | Ship–squadron overlap handling | Core | OV-001–004 | Opponent places displaced squadrons | ⏳ |
| 3 | Maneuver tool side fallback | Core | MV-013 | If ship overlaps tool on computed side, use opposite side | ⏳ |
| 4 | Tests | Test | OV-001–013 | Overlap scenarios, displacement, damage | ⏳ |

**Tests:** ~10 (overlap detection, displacement, damage)

---

### Phase 6a: Attack Simulator — Attacker Declaration ✅
**Goal:** Add an interactive "A" button / A-key tool that lets the player select an attacking hull zone (on a friendly ship) or a friendly squadron. On selection, draw visual aids: range overlay, firing arc boundary lines extended to the map edge, and LOS targeting point marker for ships; close-range circle for squadrons. An info panel guides the player step by step. This is the first sub-phase of Phase 6 (Attack Resolution) and sets up the interactive selection infrastructure that later phases will extend.
**Prerequisites:** Phase 5a (ActionToolbar), Phase 5c (Range Overlay, firing arc data), Phase 5d (LOS origins data, Targeting List)
**Duration estimate:** 1–2 sessions
**Requirements:** `docs/requirements/attack_simulator.md` (AS-ACT-001–005, AS-PNL-001–003, AS-SEL-001–003/010–011, AS-VIS-001–004/010–011, AS-LOG-001–002, AC-AS-01–15)

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | `EventBus.attack_simulator_requested` signal | Autoload | AS-ACT-001 | New signal in `event_bus.gd` | ✅ |
| 2 | "A" button on `ActionToolbar` | Presentation | AS-ACT-001, AC-AS-01 | New button after T; styled same as M/R/T; emits signal; disabled during activation | ✅ |
| 3 | **A** key shortcut in `game_board.gd` | Presentation | AS-ACT-002 | `KEY_A` in `_handle_tool_shortcut`; toggle behaviour | ✅ |
| 4 | Attack simulator state management in `game_board.gd` | Presentation | AS-ACT-003–005, AC-AS-09/10/15 | `_attack_sim_active` flag; Escape handler; dismiss range overlay / targeting list on entry; cancel on A re-press | ✅ |
| 5 | `AttackSimPanel` — info panel (PanelContainer) | Presentation | AS-PNL-001–003, AC-AS-02/08 | Screen-space modal with standard styling; shows prompts; dismissed on cancel | ✅ |
| 6 | Hull zone click detection | Presentation | AS-SEL-001–002, AC-AS-03 | Convert click to ship local space → determine hull zone quadrant; accept any ship (friendly or enemy) | ✅ |
| 7 | Squadron click detection | Presentation | AS-SEL-010–011, AC-AS-11 | Any squadron click → select as attacker; no faction filter | ✅ |
| 8 | `AttackSimOverlay` — visual aids (Node2D) | Presentation | AS-VIS-001–004, AS-VIS-010–011, AC-AS-05–07/12 | Draws firing arc lines (white, extended to map edge), LOS marker (yellow, 6 px), close-range circle (squadron); uses `RangeOverlayScene` for ship range | ✅ |
| 9 | Logging | Utility | AS-LOG-001–002, AC-AS-14 | `GameLogger.new("AttackSim")` — activation, cancellation, selection, ignored clicks | ✅ |
| 10 | Unit tests — hull zone quadrant detection | Test | AC-AS-03 | Test that click positions map to correct hull zones | ✅ |
| 11 | Manual test plan update | Docs | — | `docs/test_plan_manual.md` Phase 6a section | ✅ |

**Requirements covered:** AS-ACT-001–005, AS-PNL-001–003, AS-SEL-001–003/010–011, AS-VIS-001–004/010–011, AS-LOG-001–002, AC-AS-01–15
**Tests:** ~8–12 new tests (hull zone detection, state management, panel lifecycle)

---

### Phase 6a-2: Attack Simulator — Target Selection & LOS Visualization ✅
**Goal:** After the attacker is selected (Phase 6a), let the player select a defending hull zone or squadron. Draw a colour-coded LOS line between attacker and target following the Rules Reference. Show the LOS trace result (clear / obstructed / blocked) in the info panel. Support deselection: re-click target to deselect it, click attacker to deselect both.
**Prerequisites:** Phase 6a (attack simulator infrastructure, overlay, panel)
**Duration estimate:** 1–2 sessions
**Requirements:** `docs/requirements/attack_simulator.md` (AS-TGT-001–003/010–012/020–022, AS-VIS-020–022, AS-PNL-010–011, AS-LOG-010, AC-AS-20–30)

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | Target selection state in `game_board.gd` | Presentation | AS-TGT-001, AS-TGT-010, AS-PNL-010 | New `_attack_sim_target_selecting` flag; store attacker token/zone/type; after attacker selected, enter target-selection mode; panel shows "Select a target." | ✅ |
| 2 | Target hull zone click handler | Presentation | AS-TGT-001–003, AC-AS-21 | `_attack_sim_handle_target_ship_click()`: determine hull zone, store target, trigger LOS computation + visuals | ✅ |
| 3 | Target squadron click handler | Presentation | AS-TGT-010–012, AC-AS-22 | `_attack_sim_handle_target_squadron_click()`: store target squadron, trigger LOS computation + visuals | ✅ |
| 4 | Target deselection (click target again) | Presentation | AS-TGT-020, AC-AS-27 | Re-click target → remove target visuals + LOS line → return to "Select a target" prompt; attacker visuals remain | ✅ |
| 5 | Both deselection (click attacker) | Presentation | AS-TGT-021, AC-AS-28 | Click attacker hull zone / squadron → remove all visuals → return to initial "Select attacker" prompt | ✅ |
| 6 | Target LOS marker in `AttackSimOverlay` | Presentation | AS-VIS-020, AC-AS-23 | `setup_target_hull_zone(los_pos)` / `setup_target_squadron(centre)` — draw yellow 6 px marker at target's LOS point | ✅ |
| 7 | LOS line + colour coding in `AttackSimOverlay` | Presentation | AS-VIS-021–022, AC-AS-24–25 | `setup_los_line(start, end, status)` — yellow (clear), orange (obstructed), red (blocked); 2.0 px width | ✅ |
| 8 | LOS computation helper | Presentation | AS-VIS-021–022, AC-AS-30 | Gather `ObstructionBody` list, compute LOS endpoints per attacker/target type, call `LineOfSightChecker`, return LOSResult | ✅ |
| 9 | `AttackSimPanel` target prompts | Presentation | AS-PNL-010–011, AC-AS-20/26 | `show_target_selected(atk_name, atk_zone, def_name, def_zone, los_text)` — display attacker→target + LOS result | ✅ |
| 10 | Logging — target events | Utility | AS-LOG-010 | Target selected, deselected, LOS result → `GameLogger("AttackSim")` | ✅ |
| 11 | Unit tests — target selection & LOS | Test | AC-AS-20–30 | Target click detection, deselection state transitions, LOS line endpoints, panel text updates | ✅ |
| 12 | Manual test plan update | Docs | — | `docs/test_plan_manual.md` Phase 6a-2 section (MT-6a-2.1–6a-2.8) | ✅ |

**Requirements covered:** AS-TGT-001–003/010–012/020–022, AS-VIS-020–022, AS-PNL-010–011, AS-LOG-010, AC-AS-20–30
**Tests:** 20 new tests (59 scripts, 1024 total, 1906 asserts)

---

### Phase 6a-3: Attack Simulator — Same-Ship Guard, Arc Validation & Range Line ✅
**Goal:** Prevent illegal target selections (same ship, not in arc) with tooltip feedback. Draw a range measurement line (closest-point-to-closest-point) colour-coded by range band alongside the existing LOS line. Add new `RangeFinder` endpoint functions that return both distance and the two world-space points used for measurement.
**Prerequisites:** Phase 6a-2 (target selection, LOS line, overlay, panel)
**Duration estimate:** 1 session
**Requirements:** `docs/requirements/attack_simulator.md` (AS-TGT-030, AS-ARC-001–002, AS-RNG-010–014, AS-LOG-020, AC-AS-40–48)

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | Same-ship guard in `_attack_sim_handle_target_ship_click` | Presentation | AS-TGT-030, AC-AS-40 | If `token == _attack_sim_atk_ship` and zone differs, reject click + show tooltip "Cannot target the same ship." | ✅ |
| 2 | Arc check — ship target | Presentation | AS-ARC-001, AC-AS-41 | Before accepting a ship hull zone target, call `RangeFinder.is_hull_zone_edge_in_arc(def_edge, atk_zone, atk_arc_pts)`; reject + tooltip "Defender is not in arc." if false | ✅ |
| 3 | Arc check — squadron target | Presentation | AS-ARC-001, AC-AS-41/42 | Before accepting a squadron target (ship attacker only), call `RangeFinder.is_squadron_in_arc()`; reject + tooltip; skip entirely for squadron attackers | ✅ |
| 4 | `RangeFinder.measure_attack_range_ship_endpoints()` | Core | AS-RNG-011, AC-AS-47 | Returns `{"distance", "atk_pt", "def_pt"}` — like `measure_attack_range_ship` but also returns the two closest points | ✅ |
| 5 | `RangeFinder.measure_attack_range_squadron_endpoints()` | Core | AS-RNG-011, AC-AS-47 | Returns `{"distance", "atk_pt", "def_pt"}` — like `measure_attack_range_squadron` but also returns endpoints | ✅ |
| 6 | `RangeFinder.measure_range_squad_to_ship()` | Core | AS-RNG-011, AC-AS-47 | Returns `{"distance", "atk_pt", "def_pt"}` — squadron base → ship hull-zone edge (no arc restriction) | ✅ |
| 7 | `RangeFinder.measure_range_squad_to_squad()` | Core | AS-RNG-011, AC-AS-47 | Returns `{"distance", "atk_pt", "def_pt"}` — squadron base → squadron base | ✅ |
| 8 | Range line drawing in `AttackSimOverlay` | Presentation | AS-RNG-010/012/013, AC-AS-43–45 | `setup_range_line(start, end, band)` — grey/blue/red/purple; 2.0 px; drawn alongside LOS line | ✅ |
| 9 | Range computation + overlay wiring in `game_board.gd` | Presentation | AS-RNG-010, AC-AS-43 | After LOS computed, compute range endpoints via new RangeFinder functions, determine band via `GameScale.get_range_band()`, call `setup_range_line()` | ✅ |
| 10 | Panel body extended with range band | Presentation | AS-RNG-014, AC-AS-46 | `show_target_selected()` updated: body shows "LOS: Clear · Range: Close" | ✅ |
| 11 | Unit tests — guard, arc, range | Test | AC-AS-40–48 | Same-ship rejection, arc rejection, endpoint functions, range line colours, panel range text | ✅ |
| 12 | Manual test plan update | Docs | — | `docs/test_plan_manual.md` Phase 6a-3 section (MT-6a-3.1–6a-3.8) | ✅ |

**Commit:** `5c2d4e2`
**Requirements covered:** AS-TGT-030, AS-ARC-001–002, AS-RNG-010–014, AS-LOG-020, AC-AS-40–48
**Tests:** 1045 (59 scripts, 1941 asserts) — 21 new tests

---

### Phase 6a-4: Hull-Zone Edge Polyline Fix (HZ-EDGE-001) ✅
**Goal:** Fix incorrect hull-zone edge geometry. The previous implementation used rectangle corners for hull-zone edges, but firing arc boundary lines do not always intersect at the template corners. FRONT and REAR edges now use 3-segment polylines wrapping around the template corners, derived from arc boundary outer points and new `corner_*` JSON fields.
**Prerequisites:** Phase 6a-3 (RangeFinder, arc validation, range measurement)
**Duration estimate:** 1 session

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | Add `corner_*` fields to ship JSON | Data | HZ-EDGE-001 | `corner_front_left/right`, `corner_rear_left/right` in all 6 ship JSON files | ✅ |
| 2 | `RangeFinder.get_hull_zone_edge_from_arcs()` | Core | HZ-EDGE-001, TL-ARC-005b | Returns polyline `Array[Vector2]` from arc boundary + corner world points | ✅ |
| 3 | `RangeFinder.closest_point_on_polyline()` | Core | HZ-EDGE-001 | Finds nearest point across all segments of a polyline | ✅ |
| 4 | `RangeFinder.is_hull_zone_edge_in_arc()` — polyline | Core | HZ-EDGE-001, TL-ARC-003 | Signature changed from `(start, end, …)` to `(polyline, …)` — iterates all segments | ✅ |
| 5 | Update `measure_attack_range_ship/squadron/_endpoints` | Core | HZ-EDGE-001, TL-RNG-001 | All measurement functions iterate polyline segments | ✅ |
| 6 | Update callers in `game_board.gd` | Presentation | HZ-EDGE-001 | `_get_ship_edge()` helper prefers arc-based edges; updated 5 call sites | ✅ |
| 7 | Update callers in `targeting_list_builder.gd` | Core | HZ-EDGE-001 | `_get_ship_edge()` helper; updated 7 `get_hull_zone_edge` + 2 `is_hull_zone_edge_in_arc` + 2 `closest_point_on_segment` calls | ✅ |
| 8 | LOS checker — deferred TODO | Core | HZ-EDGE-001 | Added TODO comment to `_los_blocked_by_other_hull_zone()` for future arc-based edge update | ✅ |
| 9 | Unit tests | Test | HZ-EDGE-001 | New tests for `get_hull_zone_edge_from_arcs`, `closest_point_on_polyline`, polyline measurement, polyline arc-check | ✅ |
| 10 | Requirements & docs update | Docs | — | TL-ARC-005b in `targeting_list.md`, this phase, manual test plan | ✅ |

**Requirements covered:** HZ-EDGE-001, TL-ARC-005b
**Tests:** 1055 (59 scripts, 1963 asserts) — 10 new tests

---

### Phase 6b-1: Attack Execution — Target Selection & Visuals ✅
**Goal:** Add an "Execute Attack ►" button in the activation modal's Attack step. Pressing it closes the modal, shows the range overlay for the activated ship, and enters a target-selection flow that reuses the attack simulator infrastructure. Visual differences from the simulator: no arc lines, no range line — only LOS markers and LOS line. After target selection, the dice pool (by colour, filtered by range) is displayed. A "Done" button completes the attack step and re-opens the activation modal at the Maneuver step. Only the activated ship's hull zones can be the attacker; only enemy units can be targets.
**Prerequisites:** Phase 6a-4 (attack sim overlay, panel, LOS, range, arc validation)

| # | Task | Layer | Requirements | Deliverables | Status |
|---|------|-------|-------------|--------------|--------|
| 1 | `DicePool` — range-filtered dice pool computation | Core | AE-PNL-002 | `src/core/dice_pool.gd` — static methods: `get_attack_pool()`, `format_pool()` | ✅ |
| 2 | `DicePool` unit tests | Tests | — | `tests/unit/test_dice_pool.gd` — 19 tests covering range filtering, formatting, edge cases | ✅ |
| 3 | `AttackSimOverlay.attack_execution_mode` | Presentation | AE-VIS-001 | Suppress arc lines + range line when mode active; LOS markers/line still drawn | ✅ |
| 4 | `AttackSimPanel` — dice count + Done button | Presentation | AE-PNL-001–003 | `show_dice_count()`, `hide_dice_count()`, `show_initial_attack_exec()`, `attack_done_pressed` signal | ✅ |
| 5 | `ActivationModal` — Execute Attack button | Presentation | AE-ACT-001 | Remove ATTACK from placeholders, add button + `attack_step_entered` signal | ✅ |
| 6 | `game_board.gd` — attack execution flow | Orchestration | AE-FLOW-001–005, AE-TGT-001 | `_on_attack_step_entered()`, `_on_attack_exec_done()`, mode flag, faction guards, Escape cancel | ✅ |
| 7 | Docs & implementation plan update | Docs | — | This section + `docs/test_plan_manual.md` Phase 6b-1 | ✅ |

**Requirements covered:** AE-ACT-001, AE-VIS-001, AE-PNL-001–003, AE-FLOW-001–005, AE-TGT-001
**Tests:** 1074 (60 scripts, 1989 asserts) — 19 new tests

---

### Phase 6b-2: Attack Execution — Dice Rolling, Concentrate Fire & Two-Hull-Zone Sequencing ✅
**Goal:** After target selection (Phase 6b-1), the player can optionally spend a Concentrate Fire dial to add a die, roll the dice pool, optionally spend a CF token to reroll one die, then confirm. The attack sequence supports two sequential hull zone attacks with the first zone marked as spent. Damage resolution is deferred (dice are rolled but damage is not applied).
**Prerequisites:** Phase 6b-1 (target selection, LOS, dice count display, DicePool, Dice class)
**Duration estimate:** 1–2 sessions

#### Requirements

**Concentrate Fire Dial** (Rules Reference: "Concentrate Fire", p.3)

| ID | Requirement | Notes |
|----|------------|-------|
| AE-CF-001 | After target selected with dice count visible, if the ship's revealed command dial is Concentrate Fire (kept as dial, not converted to token), show prompt: "Spend CF dial for +1 die?" | Check `command_dial_stack.get_revealed_dial()` command type |
| AE-CF-002 | Show clickable colour buttons only for colours present in the attacking hull zone's battery armament (or anti-squadron armament when targeting a squadron) | e.g. CR90 FRONT: [+ Red] [+ Blue] — no Black button |
| AE-CF-003 | Pressing a colour button: adds 1 die of that colour to the pool, updates the dice count display, spends the dial via `CommandDialStack.spend_revealed()`, hides the dial sprite on the ship token | Irreversible action |
| AE-CF-004 | "Skip" button to decline the extra die — CF dial remains unspent for potential later use (e.g. second hull zone attack) | |
| AE-CF-005 | CF dial prompt appears BEFORE the "Roll Dice" button; rolling is blocked until the dial decision is resolved | |

**Dice Rolling** (Rules Reference: "Attack", Step 2, p.2)

| ID | Requirement | Notes |
|----|------------|-------|
| AE-DICE-001 | "Roll Dice" button appears after the CF dial decision (or immediately if no CF dial available) | |
| AE-DICE-002 | Rolling uses `Dice.roll_pool()` with the final pool (base armament ± CF extra die), converting DicePool string keys to DiceColor enums | |
| AE-DICE-003 | Rolled dice shown as die-face PNG images (~32×32 px) in a horizontal row inside the panel; PNGs from `Resources/Game_Components/dice/` | e.g. `die_red_hit.png`, `die_blue_accuracy.png` |
| AE-DICE-004 | "Roll Dice" button hidden after rolling; dice count label replaced by actual image results | |

**Concentrate Fire Token Reroll** (Rules Reference: "Concentrate Fire", p.3)

| ID | Requirement | Notes |
|----|------------|-------|
| AE-CF-010 | After rolling, if the ship holds a Concentrate Fire command token, show: "Spend CF token to reroll 1 die?" | Check `command_tokens.has_token(CONCENTRATE_FIRE)` |
| AE-CF-011 | Player clicks a die image to select it (yellow border highlight); then presses "Reroll" button | Only one die may be selected at a time |
| AE-CF-012 | Rerolled die replaces the selected die in the results display using its new face PNG | |
| AE-CF-013 | CF token spent via `CommandTokenManager.spend_token(CONCENTRATE_FIRE)` after reroll; reroll UI removed | Irreversible |
| AE-CF-014 | "Skip" button to decline the reroll — CF token remains unspent | |

**Confirm & Damage Skip**

| ID | Requirement | Notes |
|----|------------|-------|
| AE-CONF-001 | "Confirm" button appears below dice results (after optional reroll decision) | |
| AE-CONF-002 | Pressing Confirm ends the current hull zone's attack; damage resolution is skipped for now (deferred to Phase 6) | Placeholder: log dice results, no shield/hull changes |

**Two-Hull-Zone Sequencing** (Rules Reference: "Ship Activation", p.16 — "each of its hull zones can be used to perform one attack")

| ID | Requirement | Notes |
|----|------------|-------|
| AE-2HZ-001 | After first hull zone Confirm, return to hull zone selection for a second attack from a different hull zone | Reset target state, keep range overlay |
| AE-2HZ-002 | The first hull zone's LOS marker is overlaid with a translucent red dot (6 px diameter) indicating it has already fired | Drawn by AttackSimOverlay |
| AE-2HZ-003 | The first hull zone is blocked from re-selection; clicking it shows tooltip: "This hull zone has already attacked." | |
| AE-2HZ-004 | "Skip" button available during second hull zone selection to decline the second attack | |
| AE-2HZ-005 | After second Confirm (or Skip), complete the attack step → dismiss visuals → re-open activation modal with Attack step checkmarked | |

**Skip Logic**

| ID | Requirement | Notes |
|----|------------|-------|
| AE-SKIP-001 | "Skip Attack" button visible during hull zone selection to skip the current attack opportunity | |
| AE-SKIP-002 | Skipping first hull zone → transitions to second hull zone opportunity (no red dot, no zone blocked) | |
| AE-SKIP-003 | Skipping second hull zone → completes the attack step | |
| AE-SKIP-004 | Auto-skip entire attack when no hull zone has valid targets (enemy in arc + at range) | `_attack_exec_has_any_valid_target()` |
| AE-SKIP-005 | Auto-skip second attack when no remaining unfired hull zone has valid targets | Check in `_attack_exec_prepare_next_attack()` |
| AE-SKIP-006 | "Skip Attack" button shown immediately at hull zone selection phase (not just after target/dice phase) | Shown in `_on_attack_step_entered()` |
| AE-SKIP-007 | When no valid targets, Attack step is auto-checkmarked in the activation modal (no Execute Attack button appears) | `ActivationModal.set_attack_skippable()` + `_ship_has_any_attack_target()` |

#### Implementation Tasks

| # | Task | Layer | Requirements | Deliverables | Status |
|---|------|-------|-------------|--------------|--------|
| 1 | `Dice.get_face_image_path()` — colour+face → PNG path | Core | AE-DICE-003 | Static method on existing `Dice` class | ✅ |
| 2 | `DicePool.to_engine_pool()` — string keys → DiceColor enum keys | Core | AE-DICE-002 | Static method; allows `Dice.roll_pool(DicePool.to_engine_pool(pool))` | ✅ |
| 3 | `AttackSimPanel` — CF dial UI (colour buttons + skip) | Presentation | AE-CF-001–005 | New section in panel with colour buttons, skip button, signals | ✅ |
| 4 | `AttackSimPanel` — Roll Dice button + dice image display | Presentation | AE-DICE-001–004 | HBoxContainer of TextureRect die faces, Roll button | ✅ |
| 5 | `AttackSimPanel` — CF token reroll UI (die selection + reroll) | Presentation | AE-CF-010–014 | Clickable die images with highlight, Reroll/Skip buttons | ✅ |
| 6 | `AttackSimPanel` — Confirm button + Skip Attack button | Presentation | AE-CONF-001–002, AE-SKIP-001–003 | Confirm replaces Done; Skip available during selection | ✅ |
| 7 | `AttackSimOverlay` — red dot on spent hull zone LOS marker | Presentation | AE-2HZ-002 | New `add_spent_zone_marker(position)` method | ✅ |
| 8 | `game_board.gd` — CF dial integration | Orchestration | AE-CF-001–005 | Check revealed dial, handle spending, hide dial sprite | ✅ |
| 9 | `game_board.gd` — dice rolling orchestration | Orchestration | AE-DICE-001–004 | Roll via `Dice.roll_pool()`, feed results to panel | ✅ |
| 10 | `game_board.gd` — CF token reroll | Orchestration | AE-CF-010–014 | Handle reroll request, spend token, update results | ✅ |
| 11 | `game_board.gd` — two-hull-zone sequencing | Orchestration | AE-2HZ-001–005, AE-SKIP-001–003 | Track fired zones, red dot, zone blocking, skip, complete | ✅ |
| 12 | Unit tests — `Dice.get_face_image_path()`, `DicePool.to_engine_pool()` | Tests | — | New tests in `test_dice_pool.gd` and `test_dice.gd` | ✅ |
| 13 | Docs & plan update | Docs | — | This section + `docs/test_plan_manual.md` Phase 6b-2 | ✅ |

**Requirements covered:** AE-CF-001–005, AE-CF-010–014, AE-DICE-001–004, AE-CONF-001–002, AE-2HZ-001–005, AE-SKIP-001–003
**Tests:** 60 scripts, 1105 tests, 2061 asserts (31 new tests)

---

### Phase 6b-3: Attack Execution — Anti-Squadron Multi-Target Sequencing ✅
**Goal:** After confirming an attack against a squadron, the ship can declare another enemy squadron as a defender from the same hull zone (Rules Reference: "Attack", Step 6). Each attacked squadron is marked with a translucent red dot. The loop repeats the full dice sequence (CF dial → Roll → Reroll → Confirm) per squadron until no more eligible targets remain or the player skips.
**Prerequisites:** Phase 6b-2 (dice rolling, confirm, two-hull-zone sequencing)
**Duration estimate:** 0.5 session

#### Requirements

**Anti-Squadron Loop** (Rules Reference: "Attack", Step 6, p.2)

| ID | Requirement | Notes |
|----|------------|-------|
| AE-SQ-001 | Track squadrons already attacked during the current hull zone's anti-squadron loop in `_attack_exec_attacked_squads` | Reset on hull zone change or attack done |
| AE-SQ-002 | Block re-targeting an already-attacked squadron with tooltip: "{name} has already been attacked." | Guard in `_attack_sim_handle_target_squadron_click()` |
| AE-SQ-003 | After confirming attack vs squadron, check for remaining enemy squadrons in same arc AND at attack range (not beyond) that have not been attacked | `_attack_exec_has_more_squad_targets()` |
| AE-SQ-004 | If more targets exist, reset target/dice state, show prompt "Select next squadron in arc, or Skip." — hull zone stays locked, cannot be deselected | `_attack_exec_prepare_next_squadron()` |
| AE-SQ-005 | For each subsequent squadron target, repeat the full dice sequence: CF dial (if not yet spent) → Roll → CF token reroll (if token available) → Confirm | Each repetition is a new attack per rules ("Treat each repetition of steps 2 through 6 as a new attack for the purposes of resolving card effects.") |
| AE-SQ-006 | "Skip Attack" during the squadron loop ends the loop and moves to the next hull zone (or finishes if both HZs done) — does NOT end the entire attack step | |
| AE-SQ-007 | Each confirmed squadron attack draws a translucent red 6px dot on the squadron's base centre via `AttackSimOverlay.add_spent_zone_marker()` | Visual feedback for attacked squadrons |
| AE-SQ-008 | Hull zone locked during squadron loop: clicking attacker ship shows tooltip "Hull zone is locked during anti-squadron attacks." | Prevents deselection |
| AE-SQ-009 | When no more eligible squadron targets remain after confirm, record hull zone as fired and proceed to next hull zone selection (or finish) | Same as AE-2HZ-001 flow |

#### Implementation Tasks

| # | Task | Layer | Requirements | Deliverables | Status |
|---|------|-------|-------------|--------------|--------|
| 1 | `_attack_exec_attacked_squads` state variable | Orchestration | AE-SQ-001 | New `Array[SquadronToken]` in `game_board.gd` | ✅ |
| 2 | Already-attacked guard in target click handler | Orchestration | AE-SQ-002 | Guard + tooltip in `_attack_sim_handle_target_squadron_click()` | ✅ |
| 3 | `_attack_exec_has_more_squad_targets()` — checks arc + range + not-attacked | Orchestration | AE-SQ-003 | New method checks all enemy squadrons | ✅ |
| 4 | `_attack_exec_is_squadron_at_range()` — range check helper | Orchestration | AE-SQ-003 | Uses `RangeFinder.measure_attack_range_squadron_endpoints()` | ✅ |
| 5 | Branch `_on_attack_confirm()` for squadron defender | Orchestration | AE-SQ-004, AE-SQ-007, AE-SQ-009 | Red dot on squadron + loop or proceed to next HZ | ✅ |
| 6 | `_attack_exec_prepare_next_squadron()` — reset for next target | Orchestration | AE-SQ-004, AE-SQ-005 | Resets target/dice, keeps HZ locked, shows prompt | ✅ |
| 7 | `AttackSimPanel.show_select_next_squadron()` — prompt method | Presentation | AE-SQ-004 | New method showing "Select next squadron in arc, or Skip." | ✅ |
| 8 | Hull zone lock guard during squadron loop | Orchestration | AE-SQ-008 | Guard in `_attack_sim_handle_target_ship_click()` | ✅ |
| 9 | Skip Attack during loop ends loop (not full attack step) | Orchestration | AE-SQ-006 | Updated `_on_attack_skip()` to branch for squadron loop | ✅ |
| 10 | Unit tests — `show_select_next_squadron()` | Tests | — | 2 new tests in `test_attack_sim_panel.gd` | ✅ |
| 11 | Docs & plan update | Docs | — | This section + `docs/test_plan_manual.md` Phase 6b-3 | ✅ |

**Requirements covered:** AE-SQ-001–009
**Tests:** 60 scripts, 1107 tests, 2063 asserts (2 new tests)

---

### Phase 6c: Attack Steps 3–5 — Accuracy, Defense Tokens & Damage Resolution ✅
**Goal:** Complete the attack sequence by implementing Step 3 (accuracy spending to lock defender tokens), Step 4 (defense token spending: Scatter, Evade, Brace, Redirect, Contain), and Step 5 (damage resolution: shields → hull → damage cards → ship destruction).
**Prerequisites:** Phase 6b-3 (dice rolling, confirm, two-hull-zone sequencing, anti-squadron loop)
**Duration:** 1 session

#### Requirements

**Phase 6c-1: Accuracy Spending** (Rules Reference: "Attack", Step 3, "Accuracy", p.1)

| ID | Requirement | Notes |
|----|------------|-------|
| AE-ACC-001 | After dice confirmation, count accuracy icons in the pool via `Dice.count_accuracy()` | New static method on Dice |
| AE-ACC-002 | If ≥1 accuracy and defender has defense tokens, show accuracy section in AttackSimPanel with defender's token buttons | Budget = accuracy count |
| AE-ACC-003 | Player can toggle tokens on/off up to accuracy budget; toggled tokens are "locked" | Locked indices stored in panel |
| AE-ACC-004 | "Confirm Accuracy" button proceeds to defense step; locked token indices passed to game_board | Signal: `accuracy_confirmed` |
| AE-ACC-005 | If 0 accuracies or defender has no tokens, skip directly to defense step | Auto-skip with no UI |
| AE-ACC-006 | `Dice.has_any_critical()` — new static helper to check for CRITICAL or HIT_CRITICAL faces | Used later by damage resolution |

**Phase 6c-2: Defense Token Spending** (Rules Reference: "Defense Tokens", p.5; "Evade"/"Brace"/"Redirect"/"Scatter"/"Contain")

| ID | Requirement | Notes |
|----|------------|-------|
| AE-DEF-001 | Show defense section with defender's spendable tokens (READY or EXHAUSTED, not DISCARDED, not accuracy-locked) | Token buttons with exhaust/discard options |
| AE-DEF-002 | Speed 0 defenders cannot spend any defense tokens (Rules Reference: "Defense Tokens", bullet 4) | Auto-skip with log |
| AE-DEF-003 | Each token type can be spent at most once per attack | Disable button after spending |
| AE-DEF-003a | Defense token buttons toggle selection (highlight) instead of immediately spending; player clicks "Commit Defense" to apply | Two-phase: select → commit. Visual green highlight + ✓ on selected tokens. One-per-type enforced during selection. |
| AE-DEF-003b | Selected defense tokens can be deselected before committing | Click again to toggle off; restores original modulate |
| AE-DEF-003c | Commit processes selected tokens sequentially via queue; evade/redirect pause for sub-steps | `_defense_commit_queue`, `_process_next_defense_commit()` |
| AE-DEF-003d | "Done Redirecting" button allows early exit from redirect sub-step during commit queue | `redirect_done_pressed` signal, `_on_redirect_done_early()` |
| AE-DEF-004 | READY tokens can be exhausted; EXHAUSTED tokens must be discarded | Spend method determined by state |
| AE-DEF-005 | **Scatter** — cancels all dice, sets modified damage to 0, ends defense step immediately | Most impactful token |
| AE-DEF-006 | **Evade** — defender manually selects a die: at long range remove it, at medium/close reroll it (immediate apply on click) | `_attack_exec_start_evade()` + `_on_evade_die_selected()` |
| AE-DEF-007 | **Brace** — deferred to Step 5 (Resolve Damage): halve total damage (round up); show pending indicator during Step 4 | Flag `_attack_exec_brace_used`, applied in `_attack_exec_resolve_damage()` |
| AE-DEF-008 | **Redirect** — enter redirect sub-step: player clicks adjacent hull zones to move damage 1-at-a-time up to shield capacity | `_attack_exec_start_redirect()`, per-click allocation |
| AE-DEF-009 | **Contain** — prevent the first damage card from being dealt faceup (standard critical blocked) | Flag `_attack_exec_contain_used` |
| AE-DEF-010 | "Done" button ends defense step and proceeds to damage resolution | Signal: `defense_tokens_done` |
| AE-DEF-011 | Camera rotates to defender's player before defense step | `_camera.rotate_to_player()` |
| AE-DEF-012 | Real-time damage display updated after each token spend | `update_defense_damage()` on panel |

**Phase 6c-3: Damage Resolution** (Rules Reference: "Attack", Step 5; "Damage", p.5–6)

| ID | Requirement | Notes |
|----|------------|-------|
| AE-DMG-001 | Calculate total damage from modified dice pool via `Dice.calculate_damage()` | After all defense modifications |
| AE-DMG-002 | For ship targets: shields in attacked zone absorb damage first via `reduce_shields()` | Emit `ship_shields_changed` |
| AE-DMG-003 | Remaining damage dealt as facedown damage cards from DamageDeck | One card per damage point |
| AE-DMG-004 | Standard critical effect: if pool has critical icon AND Contain not used, first card is faceup | `has_any_critical()` check |
| AE-DMG-005 | Ship destroyed when total damage ≥ hull value | `is_destroyed()` check |
| AE-DMG-006 | Destroyed ship hidden from board, `ship_destroyed` signal emitted | Visual removal |
| AE-DMG-007 | For squadron targets: damage dealt directly to hull via `suffer_damage()` | No shields on squadrons |
| AE-DMG-008 | Squadron destroyed when hull ≤ 0; hidden + signal emitted | `squadron_destroyed` |
| AE-DMG-009 | Damage info section shows final damage summary before proceeding | `show_damage_info()` on panel |
| AE-DMG-010 | After 1.2s delay, finalize attack and proceed to next hull zone or squadron loop | `_attack_exec_finalize_after_delay()` |
| AE-DMG-011 | Hull zone adjacency table in Constants for redirect targeting | `get_adjacent_hull_zones()` |
| AE-DMG-012 | Hull zone string ↔ enum conversion utilities in Constants | `hull_zone_to_string()`, `string_to_hull_zone()` |
| AE-DMG-013 | Defense token name dictionary in Constants | `DEFENSE_TOKEN_NAMES` |
| AE-DMG-014 | DamageDeck stored in game_board for card drawing during damage resolution | `_damage_deck` reference |

#### Implementation Tasks

| # | Task | Layer | Requirements | Deliverables | Status |
|---|------|-------|-------------|--------------|--------|
| 1 | `Dice.count_accuracy()` + `Dice.has_any_critical()` | Core | AE-ACC-001, AE-ACC-006 | Static methods in `src/core/dice.gd` | ✅ |
| 2 | Constants: adjacency table, zone string conversion, token names | Autoload | AE-DMG-011–013 | `get_adjacent_hull_zones()`, `hull_zone_to_string()`, `string_to_hull_zone()`, `DEFENSE_TOKEN_NAMES` | ✅ |
| 3 | Phase 6c state variables in game_board.gd | Orchestration | All | ~15 new state vars for accuracy/defense/damage tracking | ✅ |
| 4 | Store `_damage_deck` reference during scenario setup | Orchestration | AE-DMG-014 | `_damage_deck` from `setup.get_damage_deck()` | ✅ |
| 5 | State var resets in `_on_attack_exec_done()` | Orchestration | All | Clean reset of all Phase 6c state | ✅ |
| 6 | AttackSimPanel: 6 new signals + ~15 UI member vars | Presentation | AE-ACC-002–004, AE-DEF-001–012, AE-DMG-009 | Signals, containers, buttons, labels | ✅ |
| 7 | AttackSimPanel: `_build_ui()` accuracy/defense/redirect/damage sections | Presentation | AE-ACC-002, AE-DEF-001, AE-DEF-008, AE-DMG-009 | Hidden containers built in `_build_ui()` | ✅ |
| 8 | AttackSimPanel: public API methods (show/hide/update) | Presentation | All UI | `show_accuracy_section()`, `show_defense_section()`, `show_redirect_section()`, `show_damage_info()`, etc. | ✅ |
| 9 | `_create_token_button()` helper | Presentation | AE-ACC-002, AE-DEF-001 | Creates styled token Button with metadata | ✅ |
| 10 | Connect new panel signals in `_connect_attack_panel_signals()` | Orchestration | All | 4 new signal connections | ✅ |
| 11 | Refactor `_on_attack_confirm()` → start accuracy step | Orchestration | AE-ACC-001 | Now resets Phase 6c state and calls `_attack_exec_start_accuracy()` | ✅ |
| 12 | Phase 6c-1: `_attack_exec_start_accuracy()` + `_on_attack_accuracy_confirmed()` | Orchestration | AE-ACC-001–005 | Full accuracy toggling flow with budget | ✅ |
| 13 | Phase 6c-2: `_attack_exec_start_defense()` + token spending flow | Orchestration | AE-DEF-001–004, AE-DEF-011 | Camera rotation, spendable token check, speed 0 guard | ✅ |
| 14 | `_on_attack_defense_token_spent()` + `_apply_defense_token_effect()` | Orchestration | AE-DEF-003–009 | Exhaust/discard logic, dispatch to token-specific handlers | ✅ |
| 15 | Evade die-selection: `_attack_exec_start_evade()` + `_on_evade_die_selected()` + panel `show_evade_die_selection()` | Orchestration+UI | AE-DEF-006 | Manual die selection, long=remove, medium/close=reroll; `evade_die_confirmed` signal | ✅ |
| 16 | Redirect sub-step: `_attack_exec_start_redirect()` + `_on_attack_redirect_zone_selected()` | Orchestration | AE-DEF-008 | Adjacent zone buttons, per-click allocation | ✅ |
| 17 | `_on_attack_defense_done()` | Orchestration | AE-DEF-010 | Ends defense, proceeds to damage | ✅ |
| 18 | `_attack_exec_resolve_damage()` — routes to ship or squadron | Orchestration | AE-DMG-001 | Calculates final damage, dispatches | ✅ |
| 19 | `_resolve_ship_damage()` — shields → cards → crit → destroy | Orchestration | AE-DMG-002–006 | Full ship damage pipeline | ✅ |
| 20 | `_resolve_squadron_damage()` — direct hull damage | Orchestration | AE-DMG-007–008 | Squadron damage + destroy | ✅ |
| 21 | `_attack_exec_finalize_after_delay()` + `_attack_exec_finalize_attack()` | Orchestration | AE-DMG-010 | 1.2s timer, then squadron loop / two-HZ sequencing | ✅ |
| 22 | Unit tests: `test_dice_accuracy.gd` (9 tests) | Tests | AE-ACC-001, AE-ACC-006 | `Dice.count_accuracy()` + `has_any_critical()` | ✅ |
| 23 | Unit tests: `test_constants_hull_zones.gd` (12 tests) | Tests | AE-DMG-011–012 | Adjacency, string↔enum conversion | ✅ |
| 24 | Unit tests: `test_ship_damage_resolution.gd` (25 tests) | Tests | AE-DMG-001–006 | Shields, damage cards, defense tokens, brace math, destruction | ✅ |
| 25 | Unit tests: `test_attack_sim_panel_defense.gd` (24 tests) | Tests | AE-ACC-002–004, AE-DEF-001, AE-DEF-006–007, AE-DEF-008, AE-DMG-009 | Accuracy/defense/redirect/damage/evade/brace UI sections | ✅ |
| 26 | Docs & plan update | Docs | — | This section + `docs/test_plan_manual.md` Phase 6c | ✅ |

**Requirements covered:** AE-ACC-001–006, AE-DEF-001–012, AE-DMG-001–014
**Tests:** 64 scripts, 1173 tests, 2147 asserts (66 new tests across 4 new test files)

---

### Post-Phase-5d LOS Bug Fix ✅

**Bug:** `_los_blocked_by_other_hull_zone()` in `LineOfSightChecker` assigned each rectangle edge entirely to one hull zone (e.g. the full RIGHT edge → RIGHT zone). For ships whose base is taller than wide (medium/large), the LEFT and RIGHT edges span FRONT, LEFT/RIGHT, and REAR hull zones. LOS entering the RIGHT edge in the REAR third was incorrectly classified as entering the RIGHT zone, causing false "LOS Blocked" results (e.g. Nebulon-B RIGHT arc → VSD REAR).

**Fix:** After finding the first perimeter intersection, convert the entry point to the defender's local space and classify the hull zone using the 1/3-length division rule (same as `ShipToken.get_hull_zone_at()`). Added `_classify_local_point()` helper. Removed stale `TODO(HZ-EDGE-001)`.

| Task | File | Details | Status |
|------|------|---------|--------|
| Point-based hull zone classification at entry point | `src/core/line_of_sight_checker.gd` | Replace edge-based zone with `_classify_local_point()` | ✅ |
| New `_classify_local_point()` static helper | `src/core/line_of_sight_checker.gd` | 1/3-length division: FRONT/REAR by y, LEFT/RIGHT by x sign | ✅ |
| Update LOS + targeting tests for corrected behaviour | `tests/unit/test_line_of_sight_checker.gd`, `tests/unit/test_targeting_list_builder.gd` | 7 new tests, 3 updated assertions | ✅ |

**Tests:** 65 scripts, 1223 tests, 2207 asserts — 1222 passing, 1 pre-existing Nebulon-B placement failure

---

### Post-Phase-5d LOS Bug Fix v2 — Arc-Boundary Intersection ✅

**Bug:** The 1/3-length-division heuristic from the previous LOS fix still produced false "LOS Blocked" results (e.g. Nebulon-B FRONT arc → VSD LEFT arc). The heuristic splits the ship rectangle into thirds by length, but hull zones are actually separated by diagonal arc boundary lines (inner_point → outer_point) defined in each ship's JSON. The 1/3 rule does not match these real boundaries.

**Fix:** Check whether the LOS segment crosses any of the 4 arc boundary lines (front_left, front_right, rear_left, rear_right). If the LOS line crosses any boundary, it enters through a different hull zone → blocked. The rectangle+classify approach is kept as a fallback when arc data is unavailable.

| Task | File | Details | Status |
|------|------|---------|--------|
| Primary arc-boundary intersection check | `src/core/line_of_sight_checker.gd` | `_los_blocked_by_arc_boundaries()`, `_has_arc_boundary_keys()`, `_ARC_BOUNDARY_PAIRS` const | ✅ |
| `get_blocking_boundary_info()` debug helper | `src/core/line_of_sight_checker.gd` | Returns boundary name, inner/outer points, intersection point for logging | ✅ |
| Fallback preserved as `_los_blocked_by_rect_classify()` | `src/core/line_of_sight_checker.gd` | Original 1/3-length approach used when no arc data | ✅ |
| Pass arc boundary data from all call sites | `game_board.gd`, `targeting_list_builder.gd` | `def_arc_pts` parameter added to `trace_los_ship_to_ship()`, `trace_los_squad_to_ship()`, `is_range_path_blocked()` | ✅ |
| Debug logging for blocked LOS | `game_board.gd` | Log boundary name + inner/outer/intersection points when LOS is blocked | ✅ |
| Arc-boundary unit tests | `test_line_of_sight_checker.gd` | 17 new tests: arc-boundary clear/blocked, rotated defender, `get_blocking_boundary_info()`, `_has_arc_boundary_keys()` | ✅ |
| Targeting list builder test updated | `test_targeting_list_builder.gd` | `test_squad_ship_target_los_blocked_by_other_hull_zone` adjusted for diagonal boundaries | ✅ |

**Tests:** 65 scripts, 1240 tests, 2226 asserts — 1239 passing, 1 pre-existing Nebulon-B placement failure

---

### Post-Phase-6c Bug Fix — Hull Display ✅

**Problem:** `ShipInstance.current_hull` was set once at creation and never decremented
when damage cards were dealt. The ship token always showed the max hull value regardless
of damage taken. The `ship_hull_changed` signal emitted the correct computed value, but
the display in `ship_token.gd` read the stale `current_hull` field instead.

**Fix (Option A — computed display):** Added `ShipInstance.get_remaining_hull()` which
returns `ship_data.hull - get_total_damage()`. Updated `ship_token.gd` to call this
instead of reading `current_hull`. No dual bookkeeping — the damage card arrays remain
the single source of truth.

| Deliverable | File | Details | Status |
|-------------|------|---------|--------|
| `get_remaining_hull()` method | `src/core/ship_instance.gd` | Returns `ship_data.hull - get_total_damage()` | ✅ |
| Hull label uses computed value | `src/scenes/tokens/ship_token.gd` | `_on_label_layer_draw()` calls `get_remaining_hull()` | ✅ |
| Unit tests (4 new) | `tests/unit/test_ship_instance.gd` | No damage, facedown, mixed, at destruction | ✅ |

**Tests:** 65 scripts, 1244 tests, 2231 asserts — 1243 passing, 1 pre-existing Nebulon-B placement failure

---

### Post-Phase-6c Bug Fix — Critical Icons vs Squadrons ✅

**Problem:** `Dice.calculate_damage()` always counted CRITICAL faces as 1 damage and
HIT_CRITICAL faces as 2 damage, regardless of the defender type. Per rules (RRG "Dice
Icons", p.5): "**Critical:** If the attacker and defender are ships, this icon adds one
damage to the damage total." Critical icons should deal **zero** damage against
squadrons; HIT_CRITICAL should count only the hit portion (1 damage).

**Fix:** Added `Dice.calculate_damage_vs_squadron()` and
`Dice.get_face_damage_vs_squadron()` which exclude the critical damage component. Added
`_calc_attack_damage()` helper in `game_board.gd` that dispatches to the correct method
based on whether the defender is a squadron (`_attack_sim_def_squad != null`). Updated
all 5 damage calculation call sites in the attack flow.

| Deliverable | File | Details | Status |
|-------------|------|---------|--------|
| `get_face_damage_vs_squadron()` | `src/core/dice.gd` | CRITICAL → 0, HIT_CRITICAL → 1 | ✅ |
| `calculate_damage_vs_squadron()` | `src/core/dice.gd` | Sums hit-only damage | ✅ |
| `_calc_attack_damage()` helper | `src/scenes/game_board/attack_executor.gd` | Dispatches by defender type | ✅ |
| All call sites updated | `src/scenes/game_board/attack_executor.gd` | 5 call sites use `_calc_attack_damage()` | ✅ |
| Unit tests (6 new) | `tests/unit/test_dice.gd` | Crit ignored, hit-crit → 1, mixed pool, etc. | ✅ |

**Tests:** 65 scripts, 1250 tests, 2237 asserts — 1249 passing, 1 pre-existing Nebulon-B placement failure

---

### AttackExecutor Extraction Refactoring ✅

**Motivation:** `game_board.gd` had grown to 4057 lines with ~60 attack-related
functions. Before implementing Phase 7 (Squadron Phase), the attack subsystem was
extracted into a dedicated `AttackExecutor` node to improve maintainability.

**What changed:** ~2000 lines of attack simulator and attack execution code moved
from `game_board.gd` to a new `attack_executor.gd`. `GameBoard` creates the
executor as a child node and delegates via a 13-method + 3-signal interface. No
game logic was altered — pure structural refactoring.

| Deliverable | File | Details | Status |
|-------------|------|---------|--------|
| New `AttackExecutor` class (~2100 lines) | `src/scenes/game_board/attack_executor.gd` | All attack simulator + execution logic, extends Node | ✅ |
| `GameBoard` delegation wiring | `src/scenes/game_board/game_board.gd` | Reduced from 4057 → ~1890 lines, delegates via `_attack_executor` | ✅ |
| Architecture docs updated | `docs/arc42/05_building_block_view.md` | AttackExecutor added to component table | ✅ |
| Runtime view updated | `docs/arc42/06_runtime_view.md` | Attack resolution sequence diagrams filled in | ✅ |
| Manual test plan updated | `docs/test_plan_manual.md` | MT-AE.1–MT-AE.11 refactoring verification tests | ✅ |

**Interface:** `initialize()`, `set_damage_deck()`, `on_simulator_requested()`,
`start_ship_attack()`, `handle_ship_click()`, `handle_squadron_click()`,
`handle_escape()`, `dismiss()`, `is_active()`, `is_selecting()`,
`is_target_selecting()`, `is_in_exec_mode()`, `has_any_attack_target()`

**Signals:** `attack_exec_completed`, `attack_exec_cancelled`, `dismiss_other_tools_requested`

**Tests:** 65 scripts, 1250 tests, 2237 asserts — 1249 passing, 1 pre-existing Nebulon-B placement failure (unchanged)

---

### Phase 6: Attack Resolution ⏳ attack pipeline for ship-vs-ship, ship-vs-squadron, and the Concentrate Fire command.
**Prerequisites:** Phase 1 (RangeMeasurer, FiringArc), Phase 3 (ShipInstance, DamageDeck), Phase 5 (activation flow)
**Duration estimate:** 3–4 sessions

| Task | Layer | Requirements | Deliverables |
|------|-------|-------------|--------------|
| `AttackPipeline` — orchestrates 6 steps | Core | AT-001–007 | `src/core/attack_pipeline.gd` — callable, reentrant-ready |
| Step 1: Target declaration (arc + range check) | Core | AT-002, AT-040–043, AT-050–053 | Valid target enumeration |
| Step 2: Dice pool gathering and rolling | Core | AT-003, AT-010–014 | Color filtering by range, server-side RNG |
| Step 3: Attack effects (accuracy spending, Conc. Fire) | Core | AT-004, CM-040–042 | Modify pool, lock defense tokens |
| Step 4: Defense token spending | Core | AT-005, DT-001–013 | Evade/Brace/Redirect/Scatter resolution |
| Step 5: Damage resolution | Core | AT-006, AT-030–034, DM-001–009 | Shields → hull → damage cards, standard crit |
| Step 6: Additional squadron target | Core | AT-007 | Repeat steps 2–6 for next squadron |
| Attack UI — step-by-step dialog | Presentation | UI-015 | `src/ui/attack_dialog.tscn` |
| Dice roll visual feedback | Presentation | UI-008, GC-007 | Rolling animation + result display |
| Hull zone selection UI | Presentation | — | Click hull zone to select attacking/defending zone |
| Two-attack-per-activation constraint | Core | AT-060, SP-013–014 | Track hull zones used |

**Architecture hook:** `AttackPipeline` is a callable function (not monolithic flow) so it can be invoked recursively for Salvo/Counter in future stages (per Priority 1 in future_stages.md).

**Tests:** ~45 (every attack step, edge cases, defense token combinations, damage distribution)

---

### Phase 7: Squadron Phase ✅ — Effect/Hook pipeline, engagement, movement validation, keyword effects, interactive squadron activation.
**Prerequisites:** Phase 1 (geometry), Phase 3 (SquadronInstance), Phase 6 (attack pipeline for squadron attacks)
**Duration estimate:** 2–3 sessions

> **Placeholder replaced:** `_begin_squadron_phase()` previously auto-marked all
> squadrons as activated and immediately advanced to the Status Phase. Phase 7
> replaces this with an interactive alternating activation system, an Effect/Hook
> pipeline for rule-modifying effects, engagement calculations, and movement
> validation.

**Architecture:** Effect/Hook Pipeline (see `docs/arc42/08_crosscutting_concepts.md`)
- `GameEffect` base class → `EffectContext` mutable data bag → `EffectRegistry` central resolver
- Hook points: `ATTACK_CALC_DAMAGE`, `ATTACK_MODIFY_DICE_ATTACKER`, `SQUADRON_MUST_ATTACK_ENGAGED`
- Effects registered at game start via `EffectFactory.register_squadron_keywords()`
- Resolved in player-priority order (initiative player first)

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | `EffectContext` — mutable data bag for hook pipeline | Core | — | `src/core/effects/effect_context.gd` | ✅ |
| 2 | `GameEffect` — base class for all effects | Core | — | `src/core/effects/game_effect.gd` | ✅ |
| 3 | `EffectRegistry` — central resolve, priority sort | Core | — | `src/core/effects/effect_registry.gd` | ✅ |
| 4 | `EffectFactory` — keyword→effect registration | Core | — | `src/core/effects/effect_factory.gd` | ✅ |
| 5 | `BomberEffect` — crits count as damage vs ships | Core | SM-030 | `src/core/effects/keywords/bomber_effect.gd` | ✅ |
| 6 | `EscortEffect` — engaged must target Escort first | Core | SM-031 | `src/core/effects/keywords/escort_effect.gd` | ✅ |
| 7 | `SwarmEffect` — reroll worst die when friendly engaged | Core | SM-032 | `src/core/effects/keywords/swarm_effect.gd` | ✅ |
| 8 | `EngagementResolver` — distance-1 edge-to-edge checks | Core | SM-010–015 | `src/core/engagement_resolver.gd` | ✅ |
| 9 | `SquadronMover` — movement distance + overlap validation | Core | SM-001–005 | `src/core/squadron_mover.gd` | ✅ |
| 10 | `EffectRegistry` wired into `GameState.initialize()` | Core | — | Modified `src/core/game_state.gd` | ✅ |
| 11 | `ATTACK_CALC_DAMAGE` hook in `AttackExecutor._calc_attack_damage()` | Core+Pres | SM-030 | Modified `src/scenes/game_board/attack_executor.gd` | ✅ |
| 12 | `set_effect_registry()` wired from `game_board.gd` | Presentation | — | Modified `src/scenes/game_board/game_board.gd` | ✅ |
| 13 | Interactive squadron activation (2 per turn, alternating) | Core+Autoload | SQ-001–005, TF-008–012 | Modified `src/autoload/game_manager.gd` | ✅ |
| 14 | `squadron_activation_ended` signal | Autoload | — | Modified `src/autoload/event_bus.gd` | ✅ |
| 15 | `SQUADRONS_PER_ACTIVATION` constant | Autoload | SQ-003 | Modified `src/autoload/constants.gd` | ✅ |
| 16 | Unit tests — effect system, keywords, engagement, movement | Test | — | 7 test files, 75 tests | ✅ |
| 17 | Manual test plan update | Docs | — | `docs/test_plan_manual.md` Phase 7 section | ✅ |
| 18 | Architecture docs update | Docs | — | `docs/arc42/05_building_block_view.md`, `06_runtime_view.md` | ✅ |

**Requirements covered:** SQ-001–005, TF-008–012, SM-001–005, SM-010–015, SM-030–032
**Tests:** 75 new tests (71 scripts total, 1325 tests, 1324 passing, 1 pre-existing Nebulon-B failure)

---

### Phase 7b: Squadron Activation UI ✅ — Modal, move overlay, attack integration, activated visual.
**Prerequisites:** Phase 7 (engagement, movement validation, GameManager squadron logic), Phase 6a (AttackExecutor)
**Duration estimate:** 1 session
**Commit:** (pending)

> **Interactive squadron activation UI:** Replaces the placeholder squadron phase
> with a guided modal that walks the player through selecting, moving, and
> attacking with each squadron. Includes movement + armament range overlays,
> engagement-based button restrictions, and visual dimming of activated tokens.

| # | Task | Layer | Req IDs | Deliverables | Status |
|---|------|-------|---------|--------------|--------|
| 1 | Requirements doc — resolved ambiguities | Docs | SQA-001–013 | `docs/requirements/squadron_activation_ui.md` | ✅ |
| 2 | `set_activated_visual()` on SquadronToken | Presentation | SQA-013 | Modified `src/scenes/tokens/squadron_token.gd` | ✅ |
| 3 | `SquadronMoveOverlay` — movement + armament circles | Presentation | SQM-001, SQM-002 | `src/ui/squadron_move_overlay.gd` | ✅ |
| 4 | `SquadronActivationModal` — 6-state state machine | Presentation | SQA-001–012 | `src/ui/squadron_activation_modal.gd` | ✅ |
| 5 | `ShowSquadronModalButton` — re-open button | Presentation | SQA-011, SQA-013 | `src/ui/show_squadron_modal_button.gd` | ✅ |
| 6 | `start_squadron_attack()` in AttackExecutor | Presentation | SQA-ATK-001 | Modified `src/scenes/game_board/attack_executor.gd` | ✅ |
| 7 | GameBoard wiring — signals, handlers, overlays | Presentation | SQA-TM-001–004 | Modified `src/scenes/game_board/game_board.gd` | ✅ |
| 8 | Unit + integration tests | Test | — | 3 test files, 39 new tests | ✅ |

**Requirements covered:** SQA-001–013, SQM-001–007, SQA-ATK-001–006, SQA-TM-001–004
**Tests:** 39 new tests (75 scripts total, 1385 tests, 1384 passing, 1 pre-existing Nebulon-B failure)

---

### Phase 8: Status Phase & Game Flow ✅ `e780aba` (79 scripts, 1431 tests)
**Prerequisites:** Phases 4–7 (all phase logic)
**Duration estimate:** 1–2 sessions

> **Completed in three sub-phases:**
> - **8a** (`9b34f3f`): ScoringCalculator (RefCounted), elimination check via
>   `ship_destroyed`/`squadron_destroyed` signals, enhanced `game_ended(details)`
>   signal (breaking change from `winner_index: int` to `details: Dictionary`),
>   fade-out tween on destroyed tokens (0.8 s).
> - **8b** (`f280634`): VictoryScreen overlay (CanvasLayer 110) — winner banner,
>   scores, reason text, "Play Again" / "Quit" buttons.
> - **8c** (`e780aba`): Phase HUD expanded to show live scores:
>   `"Round N — Phase  |  Rebel: X  |  Imperial: Y"`.
>
> **Deferred:** UI-014 (activation sidebar) → Phase 10; UI-009 (damage deck count) → future.
> **Eliminated:** Initiative token slider colour (ST-002 visual) — not relevant for digital.

| Task | Layer | Requirements | Deliverables |
|------|-------|-------------|--------------|
| Defense token readying | Core | ST-001 | Flip all exhausted tokens to ready |
| Initiative token flip | Core | ST-002, IN-003 | Toggle initiative token side (slider colour only — initiative does NOT change hands) |
| Round advancement | Core | ST-003, GF-001–003 | Increment round, check round 6 end |
| Clear activation state | Core | ST-004 | Remove faceup dials, reset activation |
| Elimination check (continuous) | Core | GF-004, WN-001 | End game immediately when all ships destroyed |
| Scoring | Core | WN-002–004 | Fleet point totals, tie-breaker |
| Victory screen | Presentation | — | Display winner, scores, game summary |
| HUD (phase, round, scores) | Presentation | UI-003, UI-004, UI-009, UI-014 | Persistent overlay |

**Tests:** ~20 (round cycle, elimination timing, scoring, initiative flip, status phase sequence)

---

### Phase 9: Repair Command & Damage Cards ✅ `c26f18f`→`32fcb29`
**Prerequisites:** Phase 3 (DamageDeck, ShipInstance), Phase 6 (damage cards used in attacks)
**Duration estimate:** 1–2 sessions | **Actual:** 6 sub-phases across 2 sessions

| Task | Layer | Requirements | Deliverables | Status |
|------|-------|-------------|--------------|--------|
| Damage card JSON data (52 cards, 22 types) | Data | DM-005, DM-009, GC-012 | `Resources/Game_Components/damage_cards.json` | ✅ 9a `c26f18f` |
| DamageCard + DamageDeck load from JSON | Core | — | `src/core/damage_card.gd`, `damage_deck.gd` enhanced | ✅ 9a `c26f18f` |
| RepairResolver (engineering points) | Core | CM-030–037 | `src/core/repair_resolver.gd`, constants, signals | ✅ 9b `3b3e4ef` |
| Ship destruction cleanup | Core | DM-033 | `clear_all_damage_cards()`, GameManager wiring | ✅ 9c `9cdff39` |
| ImmediateEffectResolver (6 cards) | Core | DM-005 | `src/core/immediate_effect_resolver.gd` | ✅ 9d `37f4aaf` |
| Persistent damage card effects (16 cards) | Core | DM-005 | `DamageCardEffect`, `DamageCardEffectFactory`, hook wiring | ✅ 9e `7adb68c` |
| RepairPanel + activation wiring | Presentation | — | `src/ui/repair_panel.gd`, activation modal integration | ✅ 9f `32fcb29` |

**Architecture hook:** Damage card effects use the same `GameEffect`/`EffectRegistry` pipeline that future upgrade cards will use (Priority 1 in future_stages.md). 13 new hooks documented in arc42 §8.9.

**Tests:** 133 new tests (84 scripts, 1564 total, 1563 passing)

---

### Phase 10: UI Polish & Network Foundation ⏳ and lay network multiplayer groundwork.
**Prerequisites:** All prior phases
**Duration estimate:** 2–3 sessions

| Task | Layer | Requirements | Deliverables |
|------|-------|-------------|--------------|
| Card detail view (ship, squadron, damage) | Presentation | UI-002 | Full-size card overlay on click |
| Movement preview polish | Presentation | UI-010 | Smooth ghost, snap-to-valid |
| Range ruler tool (player-draggable) | Presentation | UI-012 | Measurement overlay |
| Turn order sidebar | Presentation | UI-014 | Activation status for all units |
| Fix Shield Failure card effect (multi-zone, −1 shield each) | Core | DM-010–015 | `ImmediateEffectResolver`, choice model, updated tests |
| Fix Injured Crew card effect (discard defense token) | Core | — | `ImmediateEffectResolver`, updated tests |
| Fix Comm Noise card effect (reduce speed or change dial) | Core | — | `ImmediateEffectResolver`, updated tests |
| Opponent choice UI for immediate damage cards | Presentation | DM-011 | Zone/token picker modal for opponent |
| Network message protocol | Application | NW-001–008 | Message types for all sync points |
| Server-side RNG | Core | NW-004 | Dice roll authority on server |
| State snapshot & reconnection | Application | NW-006 | Full GameState serialization for rejoin |
| Secret information hiding | Application | NW-005 | Command dials only sent to owner |
| Turn timer (optional) | Application | NW-008 | Configurable per-player timer |

**Tests:** ~20 (serialization roundtrip, network message validation, reconnection state)

---

## Dependency Graph

```
Phase 0 (Scale & Assets)
    │
    ├── Phase 1 (Geometry Engine)
    │       │
    │       ├── Phase 2 (Board & Tokens) ──┬── Phase 2b (Debug Token Placement)
    │                               └── Phase 3 (State Wiring)
    │       │                                        │
    │       │                                 Phase 4 (Command Phase)
    │       │                                        │
    │       │                                 Phase 4b (Turn Mgmt & Perspective)
    │       │                                        │
    │       │                                 Phase L (Game Logging Tooling)
    │       │                                        │
    │       │                                 Phase 4c (Ship Activation Trigger)
    │       │                                        │
    │       │                                 Phase 4d (Keep-or-Convert Dial Choice)
    │       │                                        │
    │       │                                 Phase 4e (Token Overflow Discard)
    │       │                                        │
    │       │                                 Phase 4f (Hover Tooltip Infrastructure)
    │       │                                        │
    │       ├── Phase 5 (Ship Movement) ◄────────────┘
    │       │       │
    │       │       ├── Phase 5c (Range Overlay) ────┐
    │       │       │                                │
    │       │       └── Phase 5d (Targeting List) ◄──┘
    │       │
    │       └── Phase 6 (Attack Resolution) ◄────────┘
    │               │
    │               ├── Phase 7 (Squadron Phase)
    │               │
    │               └── Phase 9 (Repair & Damage Cards)
    │
    └── Phase 8 (Status Phase & Game Flow) ◄── Phases 4b–7
                │
                └── Phase 10 (UI Polish & Network) ◄── All phases
```

## Test Budget Summary

| Phase | Estimated Tests | Actual | Cumulative |
|-------|----------------|--------|------------|
| Existing | 131 | 131 | 131 |
| Phase 0 | ~10 | **49** | **180** |
| Phase 1 | ~40 | **94** | **274** |
| Phase 2 | ~15 | **29** | **303** |
| Phase 2b | ~20 | **31** | **360** |
| Phase 3 | ~25 | **126** | **486** |
| Phase 4 | ~30 | **97** | **583** |
| Phase 4b | ~25 | **52** | **635** |
| Phase L | ~20 | **36** | **671** |
| Bug fixes | — | **1** | **672** |
| Phase 4b+ | — | **8** | **680** |
| Phase 4c | ~12 | **21** | **701** |
| Phase 4d | ~10 | **15** | **716** |
| Phase 4e | ~10 | **10** | **726** |
| Phase 4f | ~16 | **17** | **759** |
| Phase 5a | ~25 | **36** | **796** |
| Phase 5a+ | 16 | 812 | 812 |
| Phase 5b | ~25 | **35** | **847** |
| Phase 5c | ~12 | **12** | **862** |
| Phase 5d | ~50 | **54** | **916** |
| Phase 5b-2 | ~10 | — | ~922 |
| Phase 6 | ~45 | — | ~967 |
| Phase 7 | ~30 | **75** | **1325** |
| Phase 7b | ~30 | **39** | **1385** |
| Phase 8 | ~20 | **31** | **1431** |
| Phase 9 | ~15 | **133** | **1564** |
| Phase 10 | ~20 | — | ~1440 |
| **Total** | **~420 new** | | **~1440** |

---

## Architecture Hooks for Future Stages

Per `docs/requirements/future_stages.md` Priority 1, these hooks are built during MVP even though not fully used:

| Hook | Built In Phase | Used By (Future) |
|------|---------------|------------------|
| `AttackPipeline` as callable function | Phase 6 | Salvo, Counter (reentrant attacks) |
| Effect timing points in attack steps | Phase 6 | Upgrade card effects |
| Effect timing points in movement | Phase 5b | Upgrade card effects on movement |
| Geometry primitives (intersection, overlap) | Phase 1 | LOS system |
| Complete state serialization | Phase 3 + 10 | Network multiplayer, save/load |
| Ship hull zone list as configurable | Phase 1 | Huge ships (6 hull zones) |
| Keyword resolution as pluggable system | Phase 7 | Extended squadron keywords | ✅ EffectRegistry + GameEffect pipeline |
| Damage card effect pattern | Phase 9 | Upgrade card effects (same pattern) | ✅ DamageCardEffect + DamageCardEffectFactory + 13 hooks |

---

## Requirements Coverage

Every requirement from `docs/requirements/mvp_learning_scenario.md` is addressed:

| Section | Reqs | Covered In Phase(s) | Status |
|---------|------|---------------------|--------|
| Game Overview (GO-001–006) | 6 | Phase 8 | ✅ |
| Setup (SU-001–030) | 18 | Phase 0, 2, 3 | ✅ SU-001, SU-003, SU-010–030 done |
| Game Flow (GF-001–004) | 4 | Phase 8 | ✅ |
| Command Phase (CP-001–008) | 8 | Phase 4, 4b | ✅ (CP-001 hot-seat adaptation in 4b) |
| Ship Phase (SP-001–016) | 16 | Phase 4b, 4c, 4d, 5, 6 | ⏳ SP-010/011 in 4c/4d; SP-015 (maneuver) in 5b; Attack in Phase 6 |
| Squadron Phase (SQ-001–009) | 9 | Phase 4b, 7, 7b | ✅ SQ-001–005 done (Phase 7); SQ-006–009 visual activation UI in Phase 7b |
| Status Phase (ST-001–004) | 4 | Phase 4b, 4c, 8 | ✅ ST-001/002/004 placeholder in 4b; initiative clarified in 4c; elimination + scoring in 8 |
| Play Mode (PM-001–004) | 4 | Phase 4b | ✅ |
| Turn Flow (TF-001–014) | 14 | Phase 4b, 5, 7, 8 | ✅ (core flow; activation steps in 5/7) |
| Board Perspective (BP-001–006) | 6 | Phase 4b | ✅ |
| Player Handoff (HO-001–005) | 5 | Phase 4b | ✅ |
| Initiative (IN-001–003) | 3 | Phase 4b | ✅ |
| Commands (CM-001–042) | 22 | Phase 4, 4d, 5, 6, 7, 9 | ✅ CM-030–037 (Repair) done in Phase 9 |
| Attack Resolution (AT-001–063) | 28 | Phase 1, 6 | ⏳ |
| Defense Tokens (DT-001–021) | 10 | Phase 6 | ⏳ |
| Damage (DM-001–033) | 12 | Phase 6, 9 | ✅ DM-001–009 in Phase 6; DM-005 effects + DM-030–033 cleanup in Phase 9 |
| Ship Movement (MV-001–022) | 13 | Phase 1, 5 | ✅ MV-001–015 done (overlap MV-016+ in 5b-2) |
| Squadron Mechanics (SM-001–042) | 18 | Phase 1, 7, 7b | ✅ SM-001–005, SM-010–015, SM-030–032 done (Phase 7); SM-040–042 (activation UI) done (Phase 7b) |
| Overlapping (OV-001–021) | 8 | Phase 5 |
| Winning/Scoring (WN-001–004) | 4 | Phase 8 | ✅ |
| Game Components (GC-001–018) | 18 | Phase 0, 2, 3, 4, 5, 6, 7 |
| UI Requirements (UI-001–028) | 28 | Phase 2, 3, 4, 4b, 4c, 4d, 4f, 5, 6, 7, 8, 10 |
| Network (NW-001–008) | 8 | Phase 4, 4b, 10 |
| Debug Mode (DBG-001–041) | 13 | Phase 2b | ✅ |
| Game Logging (LOG-001–033) | 18 | Phase L | ✅ |
| Hover Tooltip (TT-001–086) | 31 | Phase 4f | ✅ |
