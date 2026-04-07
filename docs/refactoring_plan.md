# Refactoring Plan — Post-MVP Code Quality & Extension Readiness

> **Purpose:** Bring the codebase from "working MVP" to industry-standard
> maintainability and prepare for all planned game extensions, including
> network multiplayer.
>
> **Approach:** Bottom-up, incremental, zero-to-low risk per phase.
> Each phase is independently shippable and leaves the test suite green.
>
> **Status:** Phase B complete — A1 ✅, A2 ✅, A3 ✅, A4 partially complete, B1 ✅, B2 ✅, B3 ✅, B4 ✅.
> **Baseline:** 88 scripts, 1 669 tests, 1 669 passing.

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

This plan addresses both concerns through seven incremental phases (A–G),
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

#### C1: `DisplacementController` (10 isolated funcs, 6 vars)

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

#### C3: `CommandPhaseController` (7 isolated funcs, 4 vars)

| Moved Vars | Moved Functions |
|------------|-----------------|
| `_ships_needing_dials`, `_command_dial_picker`, `_command_dial_order_modal`, `_handoff_overlay` | `_begin_command_dial_flow`, `_advance_picker_queue`, `_on_picker_confirmed`, `_on_command_picker_requested`, `_on_command_dial_order_requested`, `_on_command_phase_complete`, `_create_command_phase_ui` |

#### C4: `DebugController` (6 isolated funcs, 5 vars)

| Moved Vars | Moved Functions |
|------------|-----------------|
| `_deploy_overlay`, `_debug_label`, `_debug_help_panel`, `_was_in_deploy_zone`, `_scenario_saver` | `_create_deploy_overlay`, `_create_debug_label`, `_update_debug_visibility`, `_check_zone_crossing_toast`, `_on_save_positions`, `_handle_debug_click` |

#### C5: `ManeuverToolController` (4 isolated funcs, 2 vars)

| Moved Vars | Moved Functions |
|------------|-----------------|
| `_maneuver_tool_selecting`, `_maneuver_tool_scene` | `_show_maneuver_tool`, `_cancel_maneuver_tool_selection`, `_handle_maneuver_tool_escape`, `_dismiss_maneuver_tool` |

**Cross-cluster:** 5 functions read `_activating_ship_token` — resolved by
passing it as a parameter or reading from `ActivationContext` (Phase F
prep: for now, pass as argument).

#### C6: `RangeToolController` (4 isolated funcs, 2 vars)

| Moved Vars | Moved Functions |
|------------|-----------------|
| `_range_overlay_selecting`, `_range_overlay_scene` | `_show_range_overlay`, `_dismiss_range_overlay`, `_cancel_range_overlay_selection`, `_handle_range_overlay_escape` |

#### C Expected Outcome

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

#### D3: Split `ShipCardPanel`

Extract construction logic into `ShipCardEntryBuilder` (RefCounted) and
damage display into `DamageCardDisplay` (Control). `ShipCardPanel` becomes
a layout coordinator (~500 lines).

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

#### E5: `SaveGameManager` Autoload

New autoload that orchestrates full game state save/load:
```gdscript
class_name SaveGameManager
extends Node

func save_game(slot: int) -> bool:
func load_game(slot: int) -> bool:
func list_saves() -> Array[Dictionary]:
```

Saves to `user://saves/<slot>.json`.

#### E6: EventBus Domain Grouping

Add `#region` blocks to `event_bus.gd` grouping the 64 signals by domain:
Game Flow, Command Phase, Ship Phase, Squadron Phase, Attack, Damage,
UI/Interaction, Debug.

---

### Phase F — Extract Backbone & ActivationContext

> **Risk: Medium** — Requires shared-state abstraction. Do after A–E.

After Phases A–E, `game_board.gd` still holds ACTIVATION, SQUADRON_PHASE,
and UI_PANELS (~1 800 lines, still above the 500-line industry target).

#### F1: Create `ActivationContext`

A lightweight RefCounted that holds the shared activation state:

```gdscript
class_name ActivationContext
extends RefCounted

signal activation_changed

var activating_ship_token: ShipToken = null
var ship_activation_state: ShipActivationState = null

func set_active(token: ShipToken, state: ShipActivationState) -> void:
    activating_ship_token = token
    ship_activation_state = state
    activation_changed.emit()

func clear() -> void:
    activating_ship_token = null
    ship_activation_state = null
    activation_changed.emit()
```

Inject `ActivationContext` into every controller that currently reads
`_activating_ship_token` or `_ship_activation_state`:
ManeuverToolController, DisplacementController, SquadronPhaseController,
and AttackExecutor.

#### F2: Extract `SquadronPhaseController`

With `ActivationContext`, the 10 cross-cluster functions that read
`_activating_ship_token` now read from the injected context instead.
12 isolated + 10 previously-cross-cluster functions (7 vars) can move.

#### F3: Extract `UIPanelManager`

Owns all 9 UI_PANELS variables. Handles creation, positioning, resizing,
and visibility. The data-driven resize dispatch from Phase B3 moves here.
13 isolated functions move cleanly.

#### F4: Extract `AttackUIManager` From `attack_executor.gd`

Separate the AttackSimPanel lifecycle (create, show, hide, connect signals,
update sections) from the attack state machine logic. Brings
`attack_executor.gd` from ~2 800 → ~1 500 lines.

#### F Expected Outcome

| Metric | Before F | After F |
|--------|----------|---------|
| `game_board.gd` lines | ~1 800 | ~500 |
| `attack_executor.gd` lines | ~2 800 | ~1 500 |
| God objects (>1 000 lines) | 2 | 1 (AE at ~1 500) |
| Controllers | 7 | 10 |

`attack_executor.gd` at ~1 500 lines is acceptable for a complex state
machine with 10+ states. Further splitting would fragment the state
transitions across files, making the flow harder to follow.

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

---

## 6. Quantified Targets

| Metric | Current | After A | After C | After F | After G | Industry Std |
|--------|---------|---------|---------|---------|---------|-------------|
| Functions >30 lines | 95 | **0** | 0 | 0 | 0 | 0 |
| Max file lines | 3 390 | 3 390 | ~1 800 | ~500 | ~500 | <500 |
| God objects (>1 000 LOC) | 4 | 4 | 2 | 1 | 1 | 0 |
| Serializable game classes | 6/11 | 6/11 | 6/11 | 6/11 | **11/11** | 11/11 |
| Scene controller unit tests | 0% | 0% | >50% | >80% | >80% | >80% |
| Player action model | Implicit | Implicit | Implicit | Implicit | **Command** | Command |
| Network-ready | No | No | No | No | **Yes** | Yes |

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
| TD-4 | Functions exceeding 30-line guideline | **Phase A** |
| TD-7 | `game_board.gd` God Object (3 390 lines) | **Phases C + F** |
| TD-8 | `attack_executor.gd` God Object (3 008 lines) | **Phases A + F4** |
| TD-9 | `ship_card_panel.gd` oversized (1 407 lines) | **Phase D3** |
| TD-10 | `attack_sim_panel.gd` monolithic `_build_ui()` | **Phase A1 + D1** |
| TD-11 | Missing serialization on ShipInstance/SquadronInstance | **Phase E** |
| TD-12 | 64 EventBus signals — spaghetti risk | **Phase E6** |
| R-6 | God-object files resist extension | **Phases C + F** |

---

*Document created: 2026-04-04. Last updated: 2026-04-04.*
