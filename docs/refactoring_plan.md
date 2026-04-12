# Refactoring Plan — Post-MVP Code Quality & Extension Readiness

> **Purpose:** Bring the codebase from "working MVP" to industry-standard
> maintainability and prepare for all planned game extensions, including
> network multiplayer.
>
> **Approach:** Bottom-up, incremental, zero-to-low risk per phase.
> Each phase is independently shippable and leaves the test suite green.
>
> **Status:** F5d complete — A1 ✅, A2 ✅, A3 ✅, A4 ✅, B1–B4 ✅, C1 ✅, C2 ✅, C3 ✅, C4 ✅, C5 ✅, C6 ✅, C7 ✅, D1 ✅, D2 ✅, D3 ✅, E1–E6 ✅, F1 ✅, F2 ✅ (C7), F3 ✅, F4a ✅, F4b ✅, F4c ✅, F4d ✅, H1–H6 ✅, F5a ✅, F5b ✅, F5c ✅, F5d ✅.
> **Baseline:** 100 scripts, 2 032 tests, 3 552 asserts — all passing.

---

## Table of Contents

- [1. Motivation](#1-motivation)
- [2. Codebase Analysis Summary](#2-codebase-analysis-summary)
- [3. Planned Game Extensions](#3-planned-game-extensions)
- [4. Refactoring Phases](#4-refactoring-phases)
  - [Phase A — Shrink Functions](#phase-a--shrink-functions)
  - [Phase B — Narrow Interfaces & Inject Dependencies](#phase-b--narrow-interfaces--inject-dependencies)
  - [Phase C — Extract Isolated Clusters](#phase-c--extract-isolated-clusters)
  - [Phase D — UI Builder Cleanup](#phase-d--ui-builder-cleanup)
  - [Phase E — Serialization & EventBus Cleanup](#phase-e--serialization--eventbus-cleanup)
  - [Phase F — Extract Backbone & ActivationContext](#phase-f--extract-backbone--activationcontext)
  - [Phase G — Command Pattern (Multiplayer Foundation)](#phase-g--command-pattern-multiplayer-foundation)
  - [Phase H — Targeting Geometry Centralisation](#phase-h--targeting-geometry-centralisation)
  - [Phase F5 — AttackExecutor Orchestration Split](#phase-f5--attackexecutor-orchestration-split)
- [5. Extension Feasibility Matrix](#5-extension-feasibility-matrix)
- [6. Quantified Targets](#6-quantified-targets)
- [7. Risk Assessment](#7-risk-assessment)
- [8. Technical Debt Resolution Map](#8-technical-debt-resolution-map)

---

## 1. Motivation

The Learning Scenario MVP is complete and fully playable. Before adding new
features, the codebase needs structural improvement for two reasons:

1. **Maintainability:** Two "God Object" files (`game_board.gd` at 3 390
   lines, `attack_executor.gd` at 3 008 lines) make changes slow and
   error-prone. 95 functions violate the project's 30-line limit.

2. **Extensibility:** Seven game extensions are planned, culminating in
   network multiplayer. The current architecture lacks the serialization
   coverage, action model, and state/presentation separation that
   multiplayer demands.

This plan addresses both concerns through nine incremental phases (A–H, F5),
ordered from zero risk to medium risk, where each phase is independently
valuable and shippable.

---

## 2. Codebase Analysis Summary

### 2.1 Scale

| Metric | Value |
|--------|-------|
| Source files | 94 (30 491 lines) |
| Test files | 88 (21 641 lines) |
| Test/source ratio | 0.71 |
| EventBus signals | 64 |
| `.tscn` scene files | 4 (nearly all UI is procedural GDScript) |
| Autoload singletons | 10 |

### 2.2 God Objects

| File | Lines | Functions | Member Vars | EventBus Connections |
|------|-------|-----------|-------------|---------------------|
| `game_board.gd` | 3 390 | 157 | 54 | 60 |
| `attack_executor.gd` | 3 008 | 96 | 57 | 38 |
| `attack_sim_panel.gd` | 1 455 | ~55 | — | — |
| `ship_card_panel.gd` | 1 407 | ~60 | — | 31 |

### 2.3 Oversized Functions

95 functions exceed the project's 30-line limit. The worst offenders:

| Lines | File | Function |
|-------|------|----------|
| 218 | `attack_sim_panel.gd` | `_build_ui()` |
| 115 | `attack_executor.gd` | `_resolve_ship_damage()` |
| 90 | `activation_modal.gd` | `_update_step_display()` |
| 86 | `damage_summary_overlay.gd` | `_build_content()` |
| 82 | `squadron_activation_modal.gd` | `_build_ui()` |
| 82 | `activation_modal.gd` | `_build_ui()` |
| 73 | `victory_screen.gd` | `_build_ui()` |
| 73 | `opponent_choice_modal.gd` | `_build_ui()` |
| 72 | `ship_card_panel.gd` | `add_ship_entry()` |
| 62 | `game_board.gd` | `_create_turn_management_ui()` |

### 2.4 Coupling Analysis — `game_board.gd`

The 54 member variables cluster into 9 responsibility groups:

| Cluster | Vars | Isolated Funcs | Cross-Cluster Funcs | Isolation Score |
|---------|------|----------------|---------------------|-----------------|
| DISPLACEMENT | 6 | 10 | 2 | **High** |
| DIAL_DRAG | 3 | 8 | 2 | **High** |
| COMMAND_PHASE | 4 | 7 | 3 | **High** |
| DEBUG | 5 | 6 | 2 | **High** |
| MANEUVER_TOOL | 2 | 4 | 5 | Medium |
| RANGE_TOOL | 2 | 4 | 2 | **High** |
| SQUADRON_PHASE | 7 | 12 | 10 | Low |
| ACTIVATION | 5 | 11 | 20+ | **Cross-cutting** |
| UI_PANELS | 9 | 13 | 5 | Medium |

**Key finding:** `_activating_ship_token` and `_ship_activation_state`
(ACTIVATION cluster) are referenced by 20+ functions across every other
cluster. This is the cross-cutting concern that makes naïve file splitting
high-risk.

**SHARED variables** (`_log`, `_token_container`, `_camera`,
`_attack_executor`, `_action_toolbar`, etc.) are used pervasively but are
read-only references — safe to pass via `initialize()`.

### 2.5 Coupling Analysis — `attack_executor.gd`

| Category | Functions |
|----------|-----------|
| SIM-only | 28 |
| EXEC-only | 8 |
| Cross-cluster (SIM + EXEC) | **40** |
| SHARED-only | 20 |

**Key finding:** 40 of 96 functions touch both SIM and EXEC state. This is
not accidental — the attack flow transitions from SIM (select
attacker/target) to EXEC (roll dice, resolve damage) while sharing the
panel, overlays, and selected-token references. It is a **single state
machine**, not two systems glued together.

**Conclusion:** Splitting `attack_executor.gd` into SIM vs EXEC files
would require 40 functions to take parameters instead of reading member
vars — a massive, error-prone change with low payoff. The correct fix is
shrinking functions (Phase A) and extracting the UI management layer
(Phase F).

The `_board` reference (typed as `Node2D` to avoid circular dependency) is
only used for 3 calls: `get_ship_tokens()` and `get_squadron_tokens()` —
a narrow 2-method interface, easy to replace with Callables (Phase B).

### 2.6 Serialization Gap

| Class | `serialize()` | `deserialize()` |
|-------|:---:|:---:|
| GameState | ✅ | ✅ |
| PlayerState | ✅ | ✅ |
| CommandDialStack | ✅ | ✅ |
| CommandTokenManager | ✅ | ✅ |
| ShipData | — | ✅ (`from_dict`) |
| SquadronData | — | ✅ (`from_dict`) |
| ShipInstance | ❌ | ❌ |
| SquadronInstance | ❌ | ❌ |
| DamageDeck | ❌ | ❌ |
| DamageCard | ❌ | ❌ |
| ShipActivationState | ❌ | ❌ |

### 2.7 Test Coverage for Scene Controllers

| File | Direct Unit Tests |
|------|:-:|
| `game_board.gd` | **None** |
| `attack_executor.gd` | 1 file (static constant only) |

All game board behaviour is verified through integration tests and
EventBus signals. No function-level unit tests exist for either God Object.

---

## 3. Planned Game Extensions

Ordered by expected implementation sequence:

| # | Extension | Category |
|---|-----------|----------|
| 1 | Saved games (save/load mid-game) | Infrastructure |
| 2 | Squadron card graphics & expanded cards | Content |
| 3 | Fleet builder | Feature |
| 4 | Upgrade cards | Feature + Architecture |
| 5 | Terrain features (obstacles) | Feature |
| 6 | Objective system | Feature |
| 7 | Network multiplayer | Architecture |

Detailed requirements for each are in `docs/requirements/future_stages.md`.

---

## 4. Refactoring Phases

### Phase A — Shrink Functions

> **Risk: None** — No interfaces change. No files move. Same public API.

Bring all 95 oversized functions under the 30-line limit by extracting
private helper methods within the same file.

#### A1: UI `_build_ui()` Methods (13 files) ✅

Each monolithic `_build_ui()` becomes a sequence of `_build_<section>()`
calls. Pure construction code with no branching logic.

**Completed:** `attack_sim_panel.gd` ✅, `activation_modal.gd` ✅,
`squadron_activation_modal.gd` ✅, `ship_card_panel.gd` ✅ (8 funcs),
`repair_panel.gd` ✅, `displacement_modal.gd` ✅,
`damage_summary_overlay.gd` ✅, `opponent_choice_modal.gd` ✅,
`victory_screen.gd` ✅, `command_dial_picker.gd` ✅ (2 funcs),
`targeting_list_modal.gd` ✅ (4 funcs),
`command_dial_order_modal.gd` ✅,
`tooltip_panel.gd` ✅, `defense_token_display.gd` ✅,
`quit_confirmation_modal.gd` ✅, `debug_help_panel.gd` ✅.

**Skipped (no oversized):** `action_toolbar.gd`.

#### A2: `attack_executor.gd` Oversized Functions (~25 functions) ✅

All 21 original + 5 newly-discovered oversized functions split into ~50
helpers. 0 functions >30 code lines remain (145 total functions).

#### A3: `game_board.gd` Oversized Functions (~6 functions) ✅

| Function | Lines | Action |
|----------|-------|--------|
| `_create_turn_management_ui()` | 62 | Extract per-widget creation helpers |
| `_create_ship_card_panels()` | 49 | Extract panel configuration |
| `_on_execute_maneuver()` | 40 | Extract overlap check, displacement trigger |
| `_spawn_learning_scenario_tokens()` | 39 | Extract per-faction spawn |
| `_create_drag_preview()` | 37 | Extract style/layout helpers |
| `_on_squadron_step_entered()` | 33 | Extract guard checks |

#### A4: Other Files (29 functions across 13 files) ✅

**Completed:** All 29 oversized functions across 13 files split into
focused helpers (≤ 30 body lines each).

| File | Functions Split | Helpers Extracted |
|------|----------------|-------------------|
| `ship_card_panel.gd` | 8 | 17 |
| `game_manager.gd` | 3 | 3 |
| `overlap_resolver.gd` | 1 | 4 |
| `token_mover.gd` | 2 | 6 |
| `damage_card_effect.gd` | 3 | 3 |
| `main_menu.gd` | 2 | 5 |
| `maneuver_tool_scene.gd` | 5 | 9 |
| `targeting_list_builder.gd` | 7 | ~20 |
| `game_scale.gd` | 1 | 1 |
| `music_manager.gd` | 1 | 1 |
| `immediate_effect_resolver.gd` | 1 | 1 |
| `maneuver_tool_state.gd` | 1 | 2 |
| `range_finder.gd` | 2 | 4 |
| `repair_resolver.gd` | 1 | 1 |
| `firing_arc_overlay.gd` | 1 | 2 |
| `ship_token.gd` | 1 | 2 |

**Skipped (no oversized):** `action_toolbar.gd`.

#### A Verification

After each file edit:
```bash
godot --headless -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```
Confirm: 0 failures, same script/test count, no parse errors.

---

### Phase B — Narrow Interfaces & Inject Dependencies

> **Risk: Low** — Small, targeted changes at module boundaries.

Make coupling explicit and injectable to prepare for extraction.

#### B1: Replace `_board` Reference With Callables ✅

`attack_executor.gd` holds `_board: Node2D` and calls only
`_board.get_ship_tokens()` (1 site) and `_board.get_squadron_tokens()`
(2 sites).

Replace with:
```gdscript
var _get_ship_tokens: Callable
var _get_squadron_tokens: Callable

func initialize(get_ships: Callable, get_squads: Callable,
        token_container: Node2D, camera: BoardCamera) -> void:
    _get_ship_tokens = get_ships
    _get_squadron_tokens = get_squads
```

**Impact:** 3 call sites in `attack_executor.gd`, 1 in `game_board.gd`.
Eliminates the circular `Node2D` type-dodge and makes AttackExecutor
testable in isolation.

#### B2: Group EventBus Connections With `#region` ✅

Add `#region` / `#endregion` comments to `game_board.gd`'s `_ready()` and
signal-connection sections, labelling each cluster. Zero code change —
documentation only.

#### B3: Extract `_on_viewport_resized()` Into Data-Driven Dispatch ✅

Replace the 12-line `if widget != null: widget.method(vp_size)` chain
with a registered-widget list. This breaks no interfaces but makes the
future `UIPanelManager` extraction (Phase F) trivial.

#### B4: Document Shared-Var Contract ✅

For each of the 11 SHARED variables in `game_board.gd`, add a doc comment
specifying: who creates it, who reads it, who writes it, and whether it
could be passed to an extracted controller. Planning work for Phase C.

---

### Phase C — Extract Isolated Clusters

> **Risk: Low–Medium** — Moves code between files. Same behaviour.
> Follows the proven `AttackExecutor` extraction pattern.

Extract the 6 best-isolated variable clusters from `game_board.gd` into
dedicated controller nodes. Each controller:

- Extends `Node`, is created in `_ready()`, added as a child.
- Receives shared references via `initialize()`.
- Communicates back via signals.
- Owns its cluster's member variables (moved, not copied).

#### C1: `DisplacementController` (10 isolated funcs, 6 vars) ✅

| Moved Vars | Moved Functions |
|------------|-----------------|
| `_displacement_queue`, `_displacement_index`, `_displacement_moving`, `_displacement_modal`, `_displacement_modal_layer`, `_displacement_ship_base` | `_start_squadron_displacement`, `_select_displacement_squadron`, `_move_displaced_squadron_to_mouse`, `_lock_displacement_position`, `_on_displacement_row_unchecked`, `_finish_displacement`, `_on_displacement_camera_ready`, `_build_displacement_other_squads`, `_create_displacement_modal`, `_remove_displacement_modal` |

**Glue in game_board:** 2 cross-cluster functions call
`_start_squadron_displacement()` passing `_activating_ship_token` — these
become signal emissions or direct calls to the controller.

#### C2: `DialDragController` (8 isolated funcs, 3 vars)

| Moved Vars | Moved Functions |
|------------|-----------------|
| `_drag_active`, `_drag_ship_instance`, `_drag_preview` | `_on_dial_drag_started`, `_create_drag_preview`, `_input` (drag portion), `_process` (drag portion), `_handle_drag_release`, `_is_valid_drop_target`, `_cancel_drag`, `_clean_up_drag` |

**Signals emitted:** `ship_activated(token)`, `token_converted(ship)` —
game_board connects these to set `_activating_ship_token`.

#### C3: `CommandPhaseController` (7 isolated funcs, 3 vars) ✅

| Moved Vars | Moved Functions |
|------------|-----------------|
| `_ships_needing_dials`, `_command_dial_picker`, `_command_dial_order_modal` | `_begin_command_dial_flow`, `_advance_picker_queue`, `_on_picker_confirmed`, `_on_command_picker_requested`, `_on_command_dial_order_requested`, `_on_command_phase_complete`, `_create_command_phase_ui` |

> `_handoff_overlay` stays in game_board — shared by AttackExecutor and
> `_on_active_player_changed`. **194 lines extracted.**
> `game_board.gd`: 3 527 → 3 419 lines (−108).
> Tests: 88 scripts, 1 669 tests, 2 932 asserts — all passing.

#### C4: `DebugController` (6 isolated funcs, 5 vars) ✅

| Moved Vars | Moved Functions |
|------------|------------------|
| `_deploy_overlay`, `_debug_label`, `_debug_help_panel`, `_was_in_deploy_zone`, `_scenario_saver` | `_create_deploy_overlay`, `_create_debug_label`, `_update_debug_visibility`, `_check_zone_crossing_toast`, `_on_save_positions`, `_handle_debug_click` |

> Also moved `_on_debug_mode_changed` (1-line delegate). **180 lines extracted.**
> `game_board.gd`: 3 419 → 3 314 lines (−105).
> Tests: 88 scripts, 1 669 tests, 2 932 asserts — all passing.

#### C5: `ManeuverToolController` (4 isolated funcs, 2 vars) ✅

| Moved Vars | Moved Functions |
|------------|------------------|
| `_maneuver_tool_selecting`, `_maneuver_tool_scene` | `_show_maneuver_tool`, `_cancel_maneuver_tool_selection`, `_handle_maneuver_tool_escape`, `_dismiss_maneuver_tool` |

> **123 lines extracted.** Cross-cluster refs to `_maneuver_tool_scene` in
> `_on_execute_maneuver`, `_resolve_maneuver_overlaps_ex`,
> `_on_range_overlay_requested`, and `_collect_ghost_info` resolved via
> `get_scene()` getter. `_dismiss_maneuver_tool` replaced by
> `_dismiss_maneuver_tool_with_preview()` wrapper that passes
> `_ship_activation_state` ship.
> `game_board.gd`: 3 315 → 3 274 lines (−41).
> Tests: 88 scripts, 1 669 tests, 2 932 asserts — all passing.

#### C6: `RangeToolController` (4 isolated funcs, 2 vars) ✅

| Moved Vars | Moved Functions |
|------------|-----------------|
| `_range_overlay_selecting`, `_range_overlay_scene` | `_show_range_overlay`, `_dismiss_range_overlay`, `_cancel_range_overlay_selection`, `_handle_range_overlay_escape` |

> **106 lines extracted.** `_on_range_overlay_requested` stays in game_board
> for toggle logic (delegates to controller). Separate `_squad_cmd_range_overlay`
> (different lifecycle) untouched.
> `game_board.gd`: 3 275 → 3 227 lines (−48).
> Tests: 88 scripts, 1 669 tests, 2 932 asserts — all passing.

#### C7: `SquadronPhaseController` (21 funcs, 7 vars) ✅

| Moved Vars | Moved Functions |
|------------|-----------------|
| `_squadron_modal`, `_show_squadron_modal_button`, `_squadron_move_overlay`, `_squad_cmd_range_overlay`, `_squadron_move_original_pos`, `_squadron_move_max_dist`, `_squadron_activation_count` | `_begin_squadron_activation_flow`, `_on_squadron_selected_in_modal`, `_on_squadron_move_requested`, `_on_squadron_move_commit`, `_on_squadron_attack_requested`, `_on_squadron_activation_done`, `_on_squadron_modal_closed`, `_on_show_squadron_modal_requested`, `_handle_squadron_move_input`, `_commit_squadron_placement`, `_move_squadron_during_activation`, `_remove_squadron_overlay`, `_find_squadron_token_for_instance`, `_build_all_squadron_positions`, `_squadron_has_valid_targets`, `_any_enemy_squadron_in_range`, `_any_enemy_ship_in_range`, `_hide_squadron_phase_ui`, `_show_squad_cmd_range_overlay`, `_dismiss_squad_cmd_range_overlay`, `_build_ship_bases` |

**Cross-cluster refs (2/21):**
- `_on_squadron_modal_closed` reads `_show_activation_button`, `_ship_activation_state` → inject Callable for "show activation button" behaviour
- `_on_squadron_attack_requested` reads `_attack_executor` → inject Callable for `start_squadron_attack()`

**Shared helpers injected at init:**
- `_token_container: Node2D`, `get_squadron_tokens: Callable`, `get_ship_tokens: Callable`, `move_squadron_token: Callable`

> **~540 lines extracted.** 19/21 isolated functions + 2 cross-cluster
> functions moved. Cross-cluster refs to `_attack_executor` and
> `_show_activation_button` resolved via injected Callables.
> Three post-extraction bug fixes: inline lambda extraction (`f2098d2`),
> `get_global_mouse_position()` on Node base (`30ae6c8`), and
> `_ready()` init order (`8ca3bf9`).
> `game_board.gd`: 3 227 → 2 799 lines (−428).
> Tests: 88 scripts, 1 669 tests, 2 932 asserts — all passing.

#### C Actual Outcome

| Metric | Before C | Planned (C1–C6) | After C6 | After C7 |
|--------|----------|-----------------|----------|----------|
| `game_board.gd` lines | 3 390 | ~1 800 | 3 227 | **2 799** |
| Extracted controllers | 1 (AE) | 7 | 7 | **8** |
| Largest controller | 3 008 (AE) | ~300 | 385 | **543** (Squadron) |
| Total lines extracted | — | ~1 590 | 1 291 | **~1 730** |

**Not extracted (stays in game_board — deferred to Phase F):**
- ACTIVATION (cross-cutting backbone — needs `ActivationContext`)
- UI_PANELS (widget creation entangled with ACTIVATION/SQUADRON ownership)

#### C Expected Outcome (original plan)

| Metric | Before | After |
|--------|--------|-------|
| `game_board.gd` lines | 3 390 | ~1 800 |
| Extracted controllers | 1 (AttackExecutor) | 7 |
| Largest controller | 3 008 (AE) | ~300 (Displacement) |

**Not extracted (stays in game_board):**
- ACTIVATION (cross-cutting backbone — 11 isolated + 20 cross-cluster)
- SQUADRON_PHASE (12 isolated but 10 cross-cluster — too entangled)
- UI_PANELS (13 isolated but layout code depends on activation state)

---

### Phase D — UI Builder Cleanup

> **Risk: Low** — Purely internal to UI classes.

#### D1: Section Builder Methods

For each UI file whose `_build_ui()` was split in Phase A, verify that the
extracted `_build_<section>()` methods follow a consistent pattern:
```gdscript
func _build_dice_section() -> VBoxContainer:
    var section: VBoxContainer = VBoxContainer.new()
    # ... build widgets ...
    return section
```

#### D2: `UIStyleHelper` Utility

Extract repeated style patterns (panel `StyleBoxFlat`, button theme
overrides, label font sizes) into `src/utils/ui_style_helper.gd`:
```gdscript
class_name UIStyleHelper
extends RefCounted

static func create_modal_panel_style() -> StyleBoxFlat:
static func apply_button_theme(button: Button, colour: Color) -> void:
static func create_section_label(text: String, size: int) -> Label:
```

Reduces duplication across 12+ UI files.

#### D3: Split `ShipCardPanel` ✅

Extracted construction logic into `ShipCardEntryBuilder` (RefCounted, 460 lines)
and damage display into `DamageCardDisplay` (RefCounted, 196 lines).
`ShipCardPanel` reduced from 1 438 to 877 lines — a layout coordinator that
delegates building and populating to the two helpers.

---

### Phase E — Serialization & EventBus Cleanup

> **Risk: Low** — Additive. No existing behaviour changes.

#### E1: `ShipInstance.serialize()` / `ShipInstance.deserialize()`

Serialize: position, rotation, hull points, shield values per zone,
defense token states, command dial stack, command tokens, speed, activated
flag, damage cards (face-up/face-down), effect states.

#### E2: `SquadronInstance.serialize()` / `SquadronInstance.deserialize()`

Serialize: position, hull points, activated flag, engaged-with list,
defense tokens (if unique squadron).

#### E3: `DamageDeck` and `DamageCard` Serialization

Serialize deck order, discard pile, dealt cards, face-up states.

#### E4: `ShipActivationState` Serialization

Serialize current step, completed steps, pending actions.

#### E5: `SaveGameManager` Autoload ✅

New autoload that orchestrates full game state save/load:
```gdscript
class_name SaveGameManager
extends Node

func save_game(game_state: GameState, file_name: String = "quicksave") -> bool:
func load_game(file_name: String = "quicksave") -> GameState:
func list_saves() -> Array[String]:
func delete_save(file_name: String) -> bool:
```

Saves to `res://saves/<name>.json` (project directory for easy debugging).
Debug keybinds: **F5** quicksave, **F8** quickload (debug mode only).

#### E6: EventBus Domain Grouping ✅

Added 12 `#region`/`#endregion` blocks to `event_bus.gd` grouping signals:
Game Flow, Ship, Squadron, Combat, UI, Command Phase, Turn Management,
Repair Command, Damage Card, Token Discard, Dial Drag, Maneuver Tool,
Activation / Maneuver Execution.

---

### Phase F — Extract Backbone & ActivationContext

> **Risk: Medium** — Requires shared-state abstraction. Do after A–E.
> **Status: Complete** — F1 ✅ (`ad61b51`), F2 ✅ (done in C7),
> F3 ✅ (`8334d06`), F4a ✅, F4b ✅, F4c ✅, F4d ✅, F5a ✅, F5b ✅, F5c ✅, F5d ✅.

After Phases A–E, `game_board.gd` still held ACTIVATION, SQUADRON_PHASE,
and UI_PANELS (~1 800 lines, still above the 500-line industry target).

#### F1: Create `ActivationContext` ✅

Created `src/core/activation_context.gd` (60 lines, RefCounted) holding
shared activation state with `last_maneuver_overlapped` flag:

- Properties: `activating_ship_token`, `ship_activation_state`,
  `last_maneuver_overlapped`
- Methods: `set_active(token, state)`, `clear()`, `is_active()`
- Signal: `activation_changed`
- Injected into ManeuverToolController, DisplacementController,
  SquadronPhaseController, AttackExecutor
- 101 references in `game_board.gd` replaced to use context
- Tests: 9 tests in `tests/unit/test_activation_context.gd`
- Commit: `ad61b51`

#### F2: Extract `SquadronPhaseController` ✅

Completed in Phase C7. All squadron-phase logic already lives in
`src/scenes/game_board/squadron_phase_controller.gd`.

#### F3: Extract `UIPanelManager` ✅

Created `src/scenes/game_board/ui_panel_manager.gd` (435 lines) owning
all UI panel lifecycle:

- **15 public panel properties** moved from `game_board.gd`
- **All `_create_*` panel functions** (card panels, overlays, modals,
  sidebars, toolbars, banners, HUD labels)
- **Resize infrastructure:** `_resizable_widgets` array,
  `register_resizable()`, `on_viewport_resized()`
- **Isolated callbacks:** card detail, damage overview/summary, quit
  confirm, victory screen, phase HUD update, score changes
- **Signal connections:** viewport resize, EventBus.game_ended,
  ship/squadron_destroyed, damage_summary_requested
- `PHASE_NAMES` constant moved here
- `game_board.gd` reduced from 2 789 → 2 207 lines (−582)
- Tests: 8 tests in `tests/unit/test_ui_panel_manager.gd`
- Commit: `8334d06`

#### F4: Incremental AttackExecutor Decomposition

> **Revised plan:** Instead of extracting the *UI layer* (which is
> hopelessly interleaved with `_attack_sim_panel`), extract the *pure
> computation layers* — geometry, dice, defense, damage — as RefCounted
> classes with zero panel references. The remaining AttackExecutor becomes
> a thinner orchestrator: "call resolver for geometry → call dice resolver
> for computation → update panel with result."

##### Context Data Pattern — `CombatParticipants`

All four extraction targets (F4a–F4d) need to know *who is attacking whom*.
Currently this is 10 member variables on AttackExecutor (`_attack_sim_atk_ship`,
`_attack_sim_atk_zone`, `_attack_sim_atk_squad`, `_attack_sim_def_ship`,
`_attack_sim_def_zone`, `_attack_sim_def_squad`, plus 4 display-name strings).

**Solution:** A lightweight, immutable-by-convention data class
`CombatParticipants extends RefCounted` in `src/core/`:

```gdscript
class_name CombatParticipants
extends RefCounted

## Attacker
var atk_ship: ShipToken          ## null when attacker is squadron
var atk_zone: int = -1           ## Constants.HullZone; -1 for squadrons
var atk_squad: SquadronToken     ## null when attacker is ship

## Defender
var def_ship: ShipToken          ## null when target is squadron
var def_zone: int = -1           ## Constants.HullZone; -1 for squadrons
var def_squad: SquadronToken     ## null when target is ship

## Convenience queries
func atk_is_ship() -> bool
func atk_is_squadron() -> bool
func def_is_ship() -> bool
func def_is_squadron() -> bool
func get_atk_faction() -> int
func get_def_faction() -> int

## Factory
static func create(atk_ship, atk_zone, atk_squad,
                   def_ship, def_zone, def_squad) -> CombatParticipants
```

**Why this pattern:**
- **Single constructor call** replaces 6 parameters on every resolver method.
- **Immutable by convention** — created once per attacker/target selection,
  never mutated. When attacker or target changes, a new instance is created.
- **Follows existing project pattern** — same shape as `ActivationContext`
  and `EffectContext` (RefCounted data bag), but read-only by design.
- **Display names stay in AE** — they are UI concerns, not geometry.
- **Shared across all resolvers** — same object is passed to
  `AttackTargetResolver`, `AttackDiceResolver`, `DefenseTokenResolver`,
  and `DamageDealer`.
- **Testable** — unit tests create `CombatParticipants` with mock tokens
  directly, no AttackExecutor needed.

AttackExecutor creates a `CombatParticipants` whenever `_attack_sim_atk_*`
or `_attack_sim_def_*` are set (in attacker/target selection handlers)
and stores it as `_participants: CombatParticipants`. All resolver calls
receive this object.

##### F4a: Extract `AttackTargetResolver` (~370 lines) ✅

> **Risk: Low** — zero `_attack_sim_panel` references.

A `RefCounted` class in `src/core/` owning all pure geometry queries.
Covers all four combatant combinations:
- Ship → Ship (all arcs)
- Ship → Squadron
- Squadron → Ship
- Squadron → Squadron

**Functions that move (26, ~370 body lines):**

| Group | Functions | Lines |
|-------|-----------|-------|
| Edge geometry | `_get_ship_edge` | 8 |
| Arc-in-arc checks | `_attack_sim_is_ship_target_in_arc`, `_attack_sim_is_squadron_target_in_arc` | 30 |
| LOS endpoints + tracing | `_attack_sim_compute_los_endpoints`, `_adjust_los_for_squadrons`, `_attack_sim_trace_los`, `_trace_los_to_ship_target`, `_trace_los_to_squad_target` | 90 |
| Obstruction body list | `_build_obstruction_bodies` | 14 |
| LOS determination | `_determine_los_status` | 30 |
| Range measurement | `_attack_sim_compute_range_endpoints`, `_measure_range_from_ship`, `_attack_exec_is_squadron_at_range` | 66 |
| Zone-has-target queries | `_attack_exec_zone_has_targets`, `_zone_has_enemy_ship_target`, `_zone_has_enemy_squad_target`, `has_any_attack_target`, `_attack_exec_has_any_valid_target`, `_attack_exec_has_more_squad_targets` | ~115 |

**Constructor injection:**
```gdscript
class_name AttackTargetResolver extends RefCounted

func _init(ship_tokens_fn: Callable, squadron_tokens_fn: Callable,
           obstruction_bodies_fn: Callable) -> void
```

`_build_obstruction_bodies` needs scene-tree access — solved by passing a
`Callable` that returns `Array[Node2D]` (same pattern as `_get_ship_tokens`).

**Public API (all methods take explicit params via `CombatParticipants`):**
- `get_ship_edge(token, zone) -> Array[Vector2]`
- `is_ship_target_in_arc(parts) -> bool`
- `is_squadron_target_in_arc(parts) -> bool`
- `compute_los(parts) -> Dictionary` — returns `{endpoints, result, obstructed}`
- `compute_range(parts) -> Dictionary` — returns `{distance, atk_pt, def_pt, range_band}`
- `zone_has_targets(ship, zone) -> bool`
- `has_any_valid_target(ship, fired_zones) -> bool`
- `has_more_squad_targets(ship, zone, attacked, faction) -> bool`

**What stays in AE:** The orchestration wrappers that call into the
resolver and then update the panel/overlay (`_attack_sim_compute_and_show_los`,
`_update_los_overlay_and_panel`, `_validate_target_ship_click`,
`_validate_target_squadron_click`). These become 5–10 line functions:
call resolver → update panel with result.

**Tests:** ~20 tests covering all 4 combatant combos × arc/LOS/range.

##### F4b: Extract `AttackDiceResolver` (~200 lines) ✅

> **Risk: Low** — zero `_attack_sim_panel` references in computation.
> **Completed:** 259 lines extracted, 10 AE functions delegated, 41 tests.

**Functions that move (10, ~200 body lines):**

| Group | Functions | Lines |
|-------|-----------|-------|
| Armament resolution | `_resolve_attacker_armament`, `_compute_attack_pool_dict`, `_compute_attack_dice_text` | 31 |
| Pool manipulation | `_apply_gather_dice_hook` (core), `_get_cf_dial_colours`, obstruction die removal (pure) | 44 |
| CF detection | `_attack_exec_has_cf_dial`, `_attack_exec_has_cf_token` | 18 |
| Damage calculation | `_calc_attack_damage` | 30 |
| Attack-blocked check | `_is_attack_blocked_by_damage` (core logic only) | 24 |

**Public API:**
- `resolve_armament(parts) -> Dictionary` — dice pool for the combatant pair
- `compute_pool(armament, range_band) -> Dictionary`
- `apply_gather_hook(pool, registry, parts) -> Dictionary`
- `is_blocked_by_damage(registry, parts, obstructed) -> bool`
- `get_cf_dial_colours(pool) -> Array[String]`
- `has_cf_dial(ship_token) -> bool`
- `has_cf_token(ship_token) -> bool`
- `remove_obstruction_die(pool, colour) -> Dictionary`
- `calc_damage(results, parts, registry) -> int`

**What stays in AE:** Signal handlers (`_on_attack_roll_dice`,
`_on_attack_cf_dial_colour`, `_on_obstruction_die_selected`) — they
call resolver for computation, then update the panel.

**Tests:** ~15 tests for pool assembly, CF logic, damage formula.

##### F4c: Extract `DefenseTokenResolver` (~300 lines) — *after F4a+F4b* ✅

> **Risk: Medium** — defense flow is a mini state machine.

Extracted pure computation of defense token effects into
`src/core/defense_token_resolver.gd` (341 lines, 15 public methods).
AE reduced from 2 930 → 2 853 lines (−77 net). 60 new tests.
UI side effects (panel updates, EventBus emissions) remain in AE.

##### F4d: Extract `DamageDealer` (220 lines) — ✅

> **Risk: Medium** — async immediate-effect flow adds complexity.

Extracted damage resolution computation (final damage, shield absorption,
hull tracking, destruction checks, damage summaries, card dealing decisions,
chooser player index) into `DamageDealer` (RefCounted, 220 lines).
The immediate-effect choice modal stays in AE (needs scene tree).

AE wiring: 7 delegation sites. AE reduced from 2 853 → 2 852 lines
(−1 net — most damage functions are orchestration with EventBus calls;
the extracted logic is the pure-computation subset).

**Tests:** 49 new tests. Full suite: 97 scripts, 1 963 tests, 3 372 asserts.

##### F4 Expected Outcome

| Step | New class | Lines moved | AE lines after | Risk |
|------|-----------|-------------|----------------|------|
| F4a | `AttackTargetResolver` | ~370 | ~2 915 | **Low** |
| F4b | `AttackDiceResolver` | ~200 | ~2 715 | **Low** |
| F4c | `DefenseTokenResolver` | 341 | 2 853 | Medium ✅ |
| F4d | `DamageDealer` | 220 | 2 852 | Medium ✅ |
| **Total** | **4 classes** | **~1 131** | **2 852** | |

Plus `CombatParticipants` data class (~50 lines, shared by all four).

After F4a+F4b (the safe first batch), AE drops to ~2 715 — still large
but the extracted logic is the densest and hardest to test in isolation.
After the full F4, AE at ~2 215 lines is predominantly orchestration
(panel wiring, signal handlers, state transitions) which is inherently
node-bound.

#### F Expected Outcome (Actual + Projected)

| Metric | Before F | After F1–F3 | After F4a–b | After F4c | After F4d | After F5 |
|--------|----------|-------------|-------------|-----------|----------|----------|
| `game_board.gd` lines | ~2 800 | 2 207 | 2 207 | 2 207 | 2 207 | 2 130 |
| `attack_executor.gd` lines | ~3 285 | 3 285 | 2 930 | 2 853 | 2 852 | 1 883 |
| God objects (>1 000 lines) | 2 | 2 | 2 | 2 | 2 | 2 |
| Controllers / managers | 7 | 9 | 11 | 12 | 13 | 16 |
| Testable RefCounted classes | — | +2 | +4 | +5 | +6 | +7 |

#### Phase F Summary

Phase F is **complete**. Across 15 sub-steps (F1–F3, F4a–d, F5a–d) the
two god objects were decomposed into focused, testable components:

| Class | Type | Lines | Location | Created In |
|-------|------|-------|----------|------------|
| `ActivationContext` | RefCounted | 60 | `src/core/` | F1 |
| `SquadronPhaseController` | Node | ~310 | `src/scenes/game_board/` | C7/F2 |
| `UIPanelManager` | Node | 435 | `src/scenes/game_board/` | F3 |
| `CombatParticipants` | RefCounted | 50 | `src/core/` | F4a |
| `AttackTargetResolver` | RefCounted | ~370 | `src/core/` | F4a |
| `AttackDiceResolver` | RefCounted | 259 | `src/core/` | F4b |
| `DefenseTokenResolver` | RefCounted | 341 | `src/core/` | F4c |
| `DamageDealer` | RefCounted | 220 | `src/core/` | F4d |
| `AttackState` | RefCounted | 237 | `src/core/` | F5a |
| `TargetingListController` | Node | 184 | `src/scenes/game_board/` | F5c |
| `TargetSelector` | Node | 959 | `src/scenes/game_board/` | F5d |

**Net impact:**
- `game_board.gd`: 3 390 → 2 130 lines (−1 260, −37%)
- `attack_executor.gd`: 3 285 → 1 883 lines (−1 402, −43%)
- 11 new classes, 7 testable RefCounted resolvers
- Test suite: 100 scripts, 2 032 tests, 3 552 asserts — 0 failures
- All manual tests (MT-F5b.01–03, MT-F5c.01–02, MT-F5d.01–03) passed

#### Post-F5 Hotfixes ✅

1. **Escape removal** (`61be60e`): Removed `handle_escape()` from
   AttackExecutor, TargetSelector, and TargetingListController. Escape
   routing was redundant (other UI elements serve the same purpose) and
   caused an infinite loop with dice-phase guards.
2. **Dice-phase guard fix**: Changed target click guards in TargetSelector
   from `dice_pool.size() > 0` (pool computed) to `dice_results.size() > 0`
   (dice actually rolled). Before rolling, players can freely change targets.
   Added `_state.reset_dice()` in `_deselect_target()` to clear stale pools.

---

### Phase G — Command Pattern (Multiplayer Foundation)

> **Risk: Medium** — Fundamental architectural addition. Do when multiplayer
> is on the active roadmap.

Network multiplayer requires three capabilities the codebase currently lacks:

1. **Serializable player actions** — every game-changing action must be a
   Command object that can be transmitted over the network.
2. **Deterministic replay** — given the same sequence of Commands and the
   same RNG seed, two clients must produce identical game states.
3. **Authority model** — one instance (host or server) is the source of
   truth; clients submit commands and receive authoritative state updates.

#### G1: Define `GameCommand` Base Class

```gdscript
class_name GameCommand
extends RefCounted

var player_index: int
var command_type: String
var payload: Dictionary

func execute(game_state: GameState) -> Dictionary:
    # Subclasses override; return result dict
    return {}

func serialize() -> Dictionary:
    return {"type": command_type, "player": player_index,
            "payload": payload}

static func deserialize(data: Dictionary) -> GameCommand:
    # Factory method dispatching on data["type"]
    return null
```

#### G2: Implement Concrete Commands

| Command | Replaces |
|---------|----------|
| `AssignDialCommand` | Direct `CommandDialStack.push()` call |
| `ActivateShipCommand` | `GameManager.activate_ship()` |
| `ConvertDialToTokenCommand` | `GameManager.activate_ship_as_token()` |
| `SelectAttackTargetCommand` | Click handler in AttackExecutor |
| `RollDiceCommand` | `_on_attack_roll_dice()` |
| `SpendDefenseTokenCommand` | `_on_attack_defense_token_spent()` |
| `SelectRedirectZoneCommand` | `_on_attack_redirect_zone_selected()` |
| `MoveSquadronCommand` | `_commit_squadron_placement()` |
| `SkipAttackCommand` | `_on_attack_skip()` |
| `EndActivationCommand` | `_complete_ship_activation()` |
| `RepairCommand` | Repair panel actions |
| `SpendTokenCommand` | Token discard/spend |

#### G3: `CommandProcessor` Autoload

```gdscript
class_name CommandProcessor
extends Node

signal command_executed(command: GameCommand)
signal command_rejected(command: GameCommand, reason: String)

func submit(command: GameCommand) -> void:
    # Validate → execute → emit
    var result: Dictionary = command.execute(GameManager.game_state)
    command_executed.emit(command)
```

All signal handlers in game_board controllers and attack_executor create
Commands and submit them to `CommandProcessor` instead of directly
modifying state.

#### G4: Network Transport Layer

```gdscript
class_name NetworkManager
extends Node

func _ready() -> void:
    CommandProcessor.command_executed.connect(_on_command_executed)

func _on_command_executed(command: GameCommand) -> void:
    # Serialize and send to all peers
    var data: Dictionary = command.serialize()
    rpc("_receive_command", data)

@rpc("any_peer", "reliable")
func _receive_command(data: Dictionary) -> void:
    var command: GameCommand = GameCommand.deserialize(data)
    CommandProcessor.submit(command)
```

Uses Godot's built-in `MultiplayerPeer` API (ENet or WebSocket).

#### G5: Deterministic RNG

Replace all `randi()` / `randf()` calls (currently in `Dice.roll()` and
`DamageDeck.shuffle()`) with a seeded `RandomNumberGenerator` instance
owned by `GameState`. The seed is agreed upon at game start and included
in saved games.

#### G6: `GameReplay`

A sequence of serialized Commands that can reproduce an entire game:
```gdscript
class_name GameReplay
extends RefCounted

var commands: Array[Dictionary] = []

func record(command: GameCommand) -> void:
    commands.append(command.serialize())

func save(path: String) -> void:
func load(path: String) -> void:
func replay(speed: float = 1.0) -> void:
```

Enables: saved game resume, spectator mode, post-game review, and
automated regression testing of full game sequences.

---

### Phase H — Targeting Geometry Centralisation

> **Risk: Low** — Replaces inline geometry approximations with calls to
> existing canonical `RangeFinder` API. No new public APIs except a
> widened factory signature in H4.
> **Status: Complete** — H1–H6 ✅. Manual tests passed 2026-04-11.

The playtest audit (Bug I) revealed 6 non-compliant locations where range
and distance calculations reimplemented `RangeFinder` logic locally, plus
2 dead-code files (`RangeMeasurer`, `FiringArc`) that were never called.

#### H1: Add Skills Rules — § Single Source of Targeting Geometry ✅

Added to `.skills/architecture_patterns.md`:
- Canonical method table (8 entries covering all measurement types)
- Banned targeting patterns (raw `distance_to() - radius`, manual
  `centre_dist - ship_half - squad_radius`, local reimplementations)

Added to `.skills/refactoring_guidelines.md`:
- New § 8 "Single Source of Targeting Geometry" with enforcement rule
  and checklist for new range/distance code

#### H2: Remove Dead Code — `range_measurer.gd` & `firing_arc.gd` ✅

Deleted:
- `src/core/range_measurer.gd` (94 lines, class `RangeMeasurer`)
- `src/core/firing_arc.gd` (101 lines, class `FiringArc`)
- Both `.gd.uid` sidecar files
- `tests/unit/test_range_measurer.gd` (11 tests)
- `tests/unit/test_firing_arc.gd` (11 tests)
- Updated doc comments in `geometry_helper.gd` and `ship_base.gd`

Zero call sites existed in `src/` — confirmed via grep.

#### H3: Fix `_any_enemy_squadron_in_range()` ✅

**File:** `squadron_phase_controller.gd` lines 520–537
**Finding:** Inline `pos.distance_to(other) - radius * 2.0` for
squad-to-squad engagement range.
**Fix:** Replaced with `RangeFinder.measure_range_squad_to_squad()`.

#### H4: Fix `is_squadron_in_range()` ✅

**File:** `squadron_command_resolver.gd` lines 125–138
**Finding (HIGH):** Circle approximation `centre_dist - ship_half - squad_radius`
for squadron command range — same Bug I class of error.
**Fix:**
- Widened `create()` factory: `create(ship, pos)` → `create(ship, pos, rot, half_w, half_l)`
- Added `_ship_rotation`, `_ship_half_width`, `_ship_half_length` members
- Replaced body with loop over 4 hull zones using
  `RangeFinder.get_hull_zone_edge()` + `measure_range_squad_to_ship()`
- Removed obsolete `_get_ship_half_length()` helper
- Updated 1 call site in `game_board.gd`
- Updated 18 call sites in `test_squadron_command_resolver.gd`
  (added `_create_resolver()` test helper with default small-ship dims)
- Fixed 2 boundary tests to use `half_w` (RIGHT edge) instead of `half_l`

#### H5: Fix 3 `targeting_list_builder.gd` Distance Helpers ✅

**File:** `targeting_list_builder.gd`
**Findings (3 × LOW):**
1. `_measure_squad_to_ship_distance()` — manual `closest_point_on_polyline`
   + subtract → `RangeFinder.measure_range_squad_to_ship()` per zone
2. `_check_squad_vs_ship_zone()` — same pattern → delegated, preserved
   `cp` (now `def_pt`) for downstream `is_range_path_blocked()` call
3. `_measure_squad_to_squad_distance()` — manual `centre_dist - r_a - r_b`
   → `RangeFinder.measure_range_squad_to_squad()["distance"]`

#### H6: Align `engagement_resolver.gd` `_edge_distance()` ✅

**File:** `engagement_resolver.gd` lines 170–174
**Finding (LOW):** Parallel circle-to-circle implementation.
**Fix:** Body delegates to `RangeFinder.measure_range_squad_to_squad()`.

#### H Bonus: Fix overlapping-circle edge case in `RangeFinder`

`measure_range_squad_to_squad()` previously returned a positive distance
when circles overlapped (the closest-point-on-circle edges crossed over).
Added overlap guard: when `centre_dist <= atk_radius + def_radius`,
return `{"distance": 0.0, ...}`. Fixes 1 failing test in
`test_targeting_list_builder.gd`.

#### H Summary

| Step | Risk | Files | Lines Δ |
|------|------|-------|---------|
| H1 | None | 2 skills docs | +40 |
| H2 | None | −4 src, −4 test, 2 doc | −195 |
| H3 | Low | 1 src | ~5 |
| H4 | Low-Med | 2 src, 1 test | ~40 src, ~36 test |
| H5 | Low | 1 src | ~25 |
| H6 | Very Low | 1 src | ~3 |
| Bonus | Low | 1 src | +8 |
| **Total** | **Low** | | **~−80 net** |

**After Phase H:** all 6 non-compliant targeting locations fixed,
2 dead files removed, skills rules codified, `RangeFinder` overlap edge
case corrected.

**Test suite:** 99 scripts, 1 994 tests, 3 428 asserts — 0 failures.
(−2 scripts, −22 tests vs. pre-H baseline due to deleted dead-code tests.)

**Manual tests:** MT-H.01, MT-H.02, MT-H.03 — all passed 2026-04-11.

---

### Phase F5 — AttackExecutor Orchestration Split

> **Risk: Medium** — Significant structural change following the proven
> ActivationContext (F1) + C7 extraction pattern. Planned after Phase H.
> **Status: F5a–F5d complete** — AttackState, TargetingListController,
> TargetSelector extracted and wired.

AE is 2 933 lines / 138 functions / 62 member vars. F4a–d extracted the
pure computation (AttackTargetResolver, AttackDiceResolver,
DefenseTokenResolver, DamageDealer). What remains is orchestration: panel
wiring, signal handlers, state transitions — but it clusters into three
distinct responsibilities.

#### AE Section Analysis

| Section | Lines | Responsibility |
|---------|-------|----------------|
| Constants + State + Init | ~317 | Shared state & setup |
| Public Interface | ~274 | Entry points from game_board |
| Internal Helpers | ~92 | Utility methods |
| Attacker Selection (6a) | ~173 | Pick attacker ship/squadron |
| Target Selection (6a-2) | ~419 | Pick target, LOS/range preview |
| Orchestration (6b-2) | ~425 | Attack sequence flow |
| Accuracy (6c-1) | ~75 | Accuracy spending |
| Defense Tokens (6c-2) | ~451 | Defense token flow |
| Damage (6c-3) | ~302 | Damage resolution |
| Immediate Effects (10a) | ~396 | Damage card choice modals |

#### F5a: Create `AttackState` (~120 lines) ✅

New `src/core/attack_state.gd` (RefCounted, 237 lines) holding 37
attack-flow member variables grouped into 7 sections (execution mode,
attacker/defender identity, attack tracking, dice, CF, accuracy/defense,
deferred damage). Provides 4 query helpers (`is_exec_active`,
`is_squad_attack`, `has_attacker`, `has_defender`) and 6 lifecycle methods
(`clear_attacker`, `clear_defender`, `reset_dice`, `reset_deferred_damage`,
`reset_for_next_attack`, `clear_all`). 38 unit tests in
`test_attack_state.gd` — same ActivationContext (F1) pattern.

#### F5b: Migrate AE Members to `AttackState` ✅

Replaced 40 member variables in AE with reads/writes to
`_state: AttackState` (453 rename operations across attack_executor.gd).
Removed 147 lines of declarations and doc comments. Rewrote 6 reset
methods to delegate to `_state` lifecycle:
- `_reset_exec_state()` → `_state.clear_all()`
- `_reset_deferred_damage_state()` → `_state.reset_deferred_damage()`
- `_attack_sim_clear_attacker_state()` → `_state.clear_attacker()`
- `_attack_sim_clear_target_state()` → `_state.clear_defender()`
- `_attack_exec_reset_dice_ui()` → `_state.reset_dice()` + UI hide
- `_reset_for_next_attack()` → `_state.reset_for_next_attack()` + UI
Also updated 18 references in `test_defense_token_ordering.gd`.
AE reduced from 2 938 → 2 594 lines (−344).
Manual tests MT-F5b.01–03 passed 2026-04-11. Game log clean (0 errors, 0 warnings).

#### F5c: Extract `TargetingListController` (~200 lines) — ✅ Complete

New `src/scenes/game_board/targeting_list_controller.gd` (184 lines, extends Node).
Owns targeting list modal lifecycle + `TargetingListBuilder` integration.

**Steps performed:**
1. Created `targeting_list_controller.gd` with public API:
   - `initialize()` — receives callables + controller/manager refs
   - `on_targeting_list_requested()` — toggle handler (replaces `_on_targeting_list_requested`)
   - `dismiss()` — close modal (replaces `_dismiss_targeting_list`)
   - `handle_escape()` — Escape key consumption (replaces `_handle_targeting_list_escape`)
2. Moved private helpers: `_show_targeting_list`, `_collect_ship_infos`, `_collect_squad_infos`, `_collect_ghost_info`
3. Wired in `game_board.gd`: new member + factory + signal delegation
4. Removed 7 methods (~105 lines) from game_board.gd

game_board.gd reduced from 2 221 → 2 116 lines (−105).
Baseline: 100 scripts, 2 032 tests, 3 552 asserts — 0 failures.
Manual tests MT-F5c.01–02 passed 2026-04-11. Game log clean (0 errors, 0 warnings).

#### F5d: Extract `TargetSelector` (~636 lines) — Option B ✅

New `src/scenes/game_board/target_selector.gd` (959 lines, extends Node).
Owns the entire attacker/target selection pipeline shared by both the
free-form attack simulator and the real attack execution.

**Implementation completed:**
1. Created `target_selector.gd` with 43 methods (16 public, 27 private).
2. Moved all selection, validation, LOS/range, and visual-aid code from AE.
3. Divergence via `target_locked(range_band, dice_text)` signal — AE
   connects and begins the dice sequence in exec mode.
4. AE slimmed from 2 594 → 1 883 lines (−711).
5. game_board.gd updated: new `_target_selector` member + factory +
   click/sim/escape routing through TS.
6. Null-safe `_get_panel()` / `_get_overlay()` helpers on AE for tests
   that create AE without TS.
7. UID generated, 100 scripts / 2 032 tests / 3 552 asserts — 0 failures.

New `src/scenes/game_board/target_selector.gd` (extends Node).
Owns the entire attacker/target selection pipeline shared by both the
free-form attack simulator and the real attack execution:

**Scope (methods moving from AE → TargetSelector):**

*SIM-ONLY entry points (56 lines):*
- `on_simulator_requested()` — toolbar/keyboard toggle
- `_activate_attack_sim()` — creates panel, enters selection mode
- `_attack_sim_handle_squadron_click()` — squadron-as-attacker (sim only)

*Shared selection + validation + visuals (~580 lines):*
- `_ensure_attack_sim_panel()` — lazy-create AttackSimPanel
- `handle_ship_click()` / `handle_squadron_click()` — click routing
- `handle_escape()` — Escape key consumption
- `dismiss()` — teardown UI
- `is_active()`, `is_selecting()`, `is_target_selecting()`, `is_in_exec_mode()`
- `_attack_sim_clear_attacker_state()` / `_attack_sim_clear_target_state()`
- `_build_current_participants()`
- `_attack_sim_handle_ship_click()` — attacker ship click (with exec guards)
- `_select_attacker_ship_zone()` — stores attacker, transitions to target mode
- `_attack_sim_show_hull_zone_visuals()` — range overlay + arc overlay
- `_clear_attack_sim_overlays()`
- `_attack_sim_show_squadron_visuals()` — close-range circle
- `_attack_sim_handle_target_ship_click()` — target ship click
- `_validate_target_ship_click()` — comprehensive target validation
- `_reject_target()`
- `_is_squad_attacker_engaged_fresh()`, `_build_squadron_positions()`
- `_get_attacker_faction()`
- `_attack_sim_handle_target_squadron_click()` — target squadron click
- `_validate_target_squadron_click()`
- `_reject_already_attacked_squad()`
- `_attack_sim_deselect_target()` / `_attack_sim_deselect_both()`
- `_attack_sim_compute_and_show_los()` — LOS + range computation
- `_update_los_overlay_and_panel()` — visual update; **divergence hook**
- `_build_obstruction_bodies()`
- `_compute_attack_dice_text()` — dice preview text

**Divergence mechanism:** TargetSelector emits a signal
`target_locked(range_band: int)` when a valid target is selected.
In exec mode, AE connects to this signal and begins the dice sequence.
In sim mode, nothing connects — the panel just shows the preview info.

**Member variables moving to TargetSelector:**
- `_attack_sim_selecting`, `_attack_sim_target_selecting` (selection flags)
- `_attack_sim_panel`, `_attack_sim_overlay`, `_attack_sim_range_overlay` (UI)
- `_target_resolver` (LOS/range)

**Shared refs (injected via initialize):**
- `_state: AttackState` (passed by reference)
- `_get_ship_tokens`, `_get_squad_tokens` (callables)
- `_token_container`, `_camera` (node refs)

**AE keeps:** dice → defense → damage → finalize (~1760 lines), plus
`start_ship_attack`, `start_squadron_attack`, exec state management,
and the signal connection to `target_locked`.

#### F5 Expected Outcome

| Step | New class | AE lines after | Risk |
|------|-----------|----------------|------|
| F5a | `AttackState` | 2 933 (no change) | Low |
| F5b | — (internal refactor) | ~2 594 | Medium |
| F5c | `TargetingListController` | ~2 116 (GB) | Low-Med |
| F5d | `TargetSelector` | ~1 883 (AE) | Medium |

---

## 5. Extension Feasibility Matrix

| Extension | Required Phases | Earliest Start |
|-----------|----------------|----------------|
| Saved games | **E** (serialization) | After Phase E |
| Squadron cards/graphics | None (content only) | Anytime |
| Fleet builder | None (new scene + data) | Anytime |
| Upgrade cards | A (readable code) | After Phase A |
| Terrain features | C (smaller game_board) | After Phase C |
| Objective system | C + E (extensible setup, serialization) | After Phase E |
| Network multiplayer | **A + B + C + E + F + G** | After Phase G |

**Six of seven extensions** are accessible after Phases A–E (the safe
investment). Only network multiplayer requires the full A–G pipeline.
Phase H is an independent code-quality improvement applicable at any time.
Phase F5 further reduces AE size, easing future work.

---

## 6. Quantified Targets

| Metric | Current | After A | After C | After F1–3 | After F4a–d | After H | After F5 | After G | Industry Std |
|--------|---------|---------|---------|------------|-------------|---------|---------|---------|-------------|
| Functions >30 lines | 95 | **0** | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Max file lines | 3 390 | 3 390 | ~2 800 | 3 285 (AE) | 2 852 | 2 933 (AE) | ~2 130 | ~500 | <500 |
| God objects (>1 000 LOC) | 4 | 4 | 2 | 2 | 2 | 2 | 2 | 1 | 0 |
| Serializable game classes | 6/11 | 6/11 | 6/11 | **11/11** | 11/11 | 11/11 | 11/11 | 11/11 | 11/11 |
| Testable RefCounted resolvers | 0 | 0 | 0 | 2 | 6 | 6 | 7 | 7+ | — |
| Dead targeting code | 2 files | 2 | 2 | 2 | 2 | **0** | 0 | 0 | 0 |
| Non-compliant range checks | 6 | 6 | 6 | 6 | 6 | **0** | 0 | 0 | 0 |
| Player action model | Implicit | Implicit | Implicit | Implicit | Implicit | Implicit | Implicit | **Command** | Command |
| Network-ready | No | No | No | No | No | No | No | **Yes** | Yes |

---

## 7. Risk Assessment

| Phase | Risk | Rationale |
|-------|------|-----------|
| **A** | **None** | Function-local extraction. Identical public API. |
| **B** | **Low** | 4 call-site changes (B1). Rest is comments/docs. |
| **C** | **Low–Med** | Proven pattern (AttackExecutor was extracted the same way). Only well-isolated clusters. |
| **D** | **Low** | Internal to UI classes. |
| **E** | **Low** | Additive serialization methods + new autoload. |
| **F** | **Medium** | Introduces shared ActivationContext. Requires updating 20+ functions to read from context instead of member vars. |
| **G** | **Medium** | Fundamental architectural change. All state-modifying code paths must route through CommandProcessor. |
| **H** | **Low** | Replaces inline geometry with existing `RangeFinder` API. One factory widening (H4). |
| **F5** | **Medium** | AE orchestration split. Follows proven F1/C7 extraction pattern but touches many signal handlers. |

**Mitigation strategy for all phases:**
1. Work one file at a time.
2. Run full test suite after each file.
3. Commit after each sub-step (C1, C2, etc.).
4. If test count drops, stop and find the parse error before continuing.

---

## 8. Technical Debt Resolution Map

Cross-reference with `docs/arc42/11_risks_and_technical_debt.md`:

| TD ID | Description | Resolved By |
|-------|-------------|-------------|
| TD-4 | Functions exceeding 30-line guideline | **Phase A** ✅ |
| TD-7 | `game_board.gd` God Object (3 390 → 2 207 lines) | **Phases C + F** ✅ (partial — F4 deferred) |
| TD-8 | `attack_executor.gd` God Object (3 285 → 1 883 lines) | **Phase A** ✅ (functions shrunk). **F4a–d** ✅ (computation extraction). **F5a–d** ✅ (orchestration split: AttackState + TargetingListController + TargetSelector). |
| TD-9 | `ship_card_panel.gd` oversized (1 407 lines) | **Phase D3** ✅ (877 lines) |
| TD-10 | `attack_sim_panel.gd` monolithic `_build_ui()` | **Phase A1 + D1** ✅ |
| TD-11 | Missing serialization on ShipInstance/SquadronInstance | **Phase E** ✅ |
| TD-12 | 64 EventBus signals — spaghetti risk | **Phase E6** ✅ |
| R-6 | God-object files resist extension | **Phases A–F** ✅ (GB −37%, AE −43%). |
| TD-13 | Non-compliant targeting geometry (6 locations) | **Phase H** ✅ |
| TD-14 | Dead-code targeting files (`RangeMeasurer`, `FiringArc`) | **Phase H2** ✅ |

---

*Document created: 2026-04-04. Last updated: 2026-04-12.*
