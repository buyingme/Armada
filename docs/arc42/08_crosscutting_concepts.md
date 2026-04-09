# 8. Crosscutting Concepts

## 8.1 Event-Driven Communication

All inter-system communication uses the **EventBus** singleton pattern:

- Systems emit signals through `EventBus` rather than holding direct references.
- This enables loose coupling and easy testing (signals can be monitored in tests).
- See `src/autoload/event_bus.gd` for the full signal catalog.

## 8.2 Data-Driven Game Content

Game content (ships, squadrons, upgrades, objectives) is defined as **Godot Resources**:

- Resources are authored as `.tres` files or loaded from structured data.
- New content can be added without code changes.
- Resources are type-safe and editor-friendly.

## 8.3 Logging

A centralized `GameLogger` utility provides:

- Severity levels: DEBUG, INFO, WARNING, ERROR
- Context tagging (which system is logging)
- Timestamps for all log entries
- See `src/utils/logger.gd`.

## 8.4 Testing Strategy

### Test Pyramid

```
        ╱  E2E  ╲           Few manual/integration scenario tests
       ╱─────────╲
      ╱Integration╲         System interactions, phase transitions
     ╱─────────────╲
    ╱   Unit Tests   ╲      Core logic, dice, rules, state
   ╱───────────────────╲
```

### Conventions

- **Unit tests:** Test individual classes/functions in isolation. Location: `tests/unit/`
- **Integration tests:** Test system interactions (e.g., full attack sequence). Location: `tests/integration/`
- **Test naming:** `test_<method>_<scenario>_<expected_result>()`
- **Fixtures:** Reusable test data in `tests/fixtures/`
- **Coverage target:** 80%+ for core logic, 60%+ for UI-adjacent code.

## 8.5 Error Handling

- Use `push_error()` / `push_warning()` for recoverable issues.
- Use assertions (`assert()`) for programmer errors in debug builds.
- Game rule violations are handled by the rules engine returning error states, never exceptions.

## 8.6 Serialization

Game state supports serialization/deserialization for:

- Save/Load functionality (via `SaveGameManager` autoload)
- Potential future network synchronization
- Test fixture generation

All serializable classes implement `serialize() -> Dictionary` and
`static deserialize(data: Dictionary)`.

Serialized classes: `GameState`, `PlayerState`, `ShipInstance`,
`SquadronInstance`, `DamageDeck`, `DamageCard`, `ShipActivationState`,
`CommandDialStack`, `CommandTokens`.

`SaveGameManager` saves to `res://saves/` (project directory) as
pretty-printed JSON. Debug keybinds: **F5** quicksave, **F8** quickload
(debug mode only). Ship/squadron template re-association after load is
the caller's responsibility via `AssetLoader` look-ups.

## 8.7 Code Organization

```
src/
├── autoload/       # Singletons (GameManager, EventBus, Constants)
├── core/           # Pure game logic (no scene dependencies)
├── models/         # Data resources (ShipData, SquadronData, etc.)
├── scenes/         # Visual scenes (.tscn + .gd controllers)
├── ui/             # Reusable UI components
└── utils/          # Utility classes (GameLogger, helpers)
```

**Key principle:** Core game logic (`src/core/`) must not depend on scene/UI code.
This enables testing without the scene tree.

## 8.8 Hover Tooltip System

> **Full requirements:** `docs/requirements/hover_tooltip_system.md`
> **ADR:** ADR-009 (§ 9)

### 8.8.1 Purpose

A single, reusable tooltip infrastructure that displays contextual help text
when the player hovers over any interactive region.  The system unifies all
transient help text — including the drag help label (UI-027), discard-mode
prompt, and future hover hints — under one consistent mechanism.

### 8.8.2 Architecture Overview

The tooltip system follows the project's three-layer separation
(Presentation → Autoload → Core → Data):

```
┌─────────────────────────────────────────────────────────────┐
│  Consumers (any scene / UI widget)                          │
│  register(control, callback)  ·  show_text()  ·  hide()    │
└──────────────────────┬──────────────────────────────────────┘
                       │ calls API
┌──────────────────────▼──────────────────────────────────────┐
│  TooltipManager (Autoload singleton, extends Node)          │
│  Owns: Timer, CanvasLayer, TooltipPanel, ToggleButton       │
│  Reads: GameScale.tooltip_* properties                      │
│  Manages: registration table, hover detection, display,     │
│           global on/off toggle, persistence                 │
└──────────────────────┬──────────────────────────────────────┘
                       │ delegates pure logic
┌──────────────────────▼──────────────────────────────────────┐
│  TooltipLayout (RefCounted, scene-tree independent)         │
│  Pure functions: viewport clamping, offset calculation      │
└─────────────────────────────────────────────────────────────┘
```

### 8.8.3 Components

#### `TooltipLayout` — Pure Logic (`src/core/tooltip_layout.gd`)

- Extends `RefCounted` (scene-tree independent, fully unit-testable).
- Single static method `compute_position()` takes cursor position, tooltip
  size, viewport size, and offset — returns the clamped top-left position.
- Flips the tooltip horizontally/vertically when the cursor is near a
  viewport edge; final clamp prevents negative coordinates.

#### `TooltipPanel` — Visual Widget (`src/ui/tooltip_panel.gd`)

- Extends `PanelContainer` with `mouse_filter = MOUSE_FILTER_IGNORE`.
- Contains a `MarginContainer → RichTextLabel` for BBCode text, multi-line,
  and inline `[img]` tags.
- Styled from `GameScale` tooltip properties (font 18 px, white text 90 %
  alpha, dark shadow, semi-transparent background `Color(0.05, 0.05, 0.1, 0.85)`,
  corner radius 4 px).
- Maximum width 320 px (configurable).

#### `TooltipManager` — Autoload Singleton (`src/autoload/tooltip_manager.gd`)

- **Registration table:** `Dictionary { Control → Callable }`.
  On `register()`, connects `mouse_entered` / `mouse_exited` signals.
  Auto-deregisters via `tree_exiting` when the Control is freed.

- **Hover state machine:**

```
          mouse_entered
  IDLE ──────────────────► WAITING
   ▲                         │ timer fires
   │ mouse_exited             ▼
   ├──────────────────── SHOWING
   │                         │
   │  programmatic show()    │
   ▼                         │
  FORCED ◄───────── (also from any state)
   │  hide()
   └──────► IDLE
```

  | State | Behaviour |
  |-------|-----------|
  | IDLE | No tooltip visible. Timer stopped. |
  | WAITING | Timer running — delay from `GameScale.tooltip_hover_delay_sec`. |
  | SHOWING | Tooltip visible, follows cursor via `_process()`. Mouse exit → IDLE. |
  | FORCED | Programmatic `show_text()`. Hide only via `hide()`. Hover events ignored. |

- **Public API:**

  ```gdscript
  func register(control: Control, callback: Callable) -> void
  func deregister(control: Control) -> void
  func show_text(text: String, fixed_position: Vector2 = Vector2.INF,
          auto_hide_sec: float = 0.0) -> void
  func hide() -> void
  func is_visible() -> bool
  ```

- **CanvasLayer** — `"TooltipLayer"`, layer **100** (above all other UI):

  | Layer | Name | Value |
  |-------|------|-------|
  | Card Panels | CardPanelLayer | 50 |
  | Command Phase UI | CommandPhaseUILayer | 60 |
  | Turn Management | TurnManagementLayer | 80 |
  | Phase HUD | PhaseHUDLayer | 90 |
  | **Tooltip** | **TooltipLayer** | **100** |

- **`_process()` loop** — active only when tooltip is visible; updates
  position via `TooltipLayout.compute_position()`. Disabled on IDLE.

### 8.8.4 Global Toggle (TT-070 – TT-075)

- A small icon-only **toggle button** (~28 × 28 px) sits in the **lower-right
  corner** of the screen, on the same `TooltipLayer` CanvasLayer.
- **Enabled state:** bright icon (question-mark / speech-bubble glyph).
  **Disabled state:** dimmed / struck-through variant.
- Clicking the button toggles `TooltipManager.tooltips_enabled`.
- When disabled, **hover tooltips are suppressed** (callbacks are not invoked,
  panel stays hidden). **Programmatic `show_text()` calls are still honoured**
  because they convey essential gameplay instructions (drag help, discard prompt).
- The enabled/disabled preference is **persisted** to `user://settings.cfg`
  so it survives application restarts.
- Button size, screen-edge padding, and icon resource path are loaded from
  `scale_config.json → "tooltip"`.

### 8.8.5 Configuration (`scale_config.json → "tooltip"`)

All visual and behavioural parameters are data-driven:

```json
"tooltip": {
    "_comment": "Hover tooltip display parameters (TT-040).",
    "hover_delay_sec": 0.2,
    "offset_x": 12,
    "offset_y": 16,
    "max_width_px": 320,
    "font_size": 18,
    "corner_radius": 4,
    "padding_h": 8,
    "padding_v": 6,
    "bg_color": [0.05, 0.05, 0.1, 0.85],
    "text_color": [1.0, 1.0, 1.0, 0.9],
    "shadow_color": [0.0, 0.0, 0.0, 0.8],
    "shadow_offset_x": 1,
    "shadow_offset_y": 1,
    "toggle_button_size": 28,
    "toggle_button_edge_padding": 12
}
```

`GameScale` exposes these as typed properties (`tooltip_hover_delay_sec`,
`tooltip_offset`, `tooltip_max_width_px`, etc.). Sensible defaults are used
when the section is absent (backward-compatible).

### 8.8.6 Migration Plan

| Current Implementation | Migrated To |
|------------------------|-------------|
| `game_board.gd` → `_create_drag_help_label()` (UI-027) | `TooltipManager.show_text(text, fixed_pos)` on drag start; `TooltipManager.hide()` on drop/cancel. |
| `ship_card_panel.gd` → discard-mode prompt Label | `TooltipManager.show_text("Click a token to discard")` on enter; `.hide()` on exit. |
| `ship_card_panel.gd` → duplicate toast Label | `TooltipManager.show_text(text, Vector2.INF, 2.0)` with auto-hide. |

After migration, the dedicated Label creation/cleanup methods are deleted.

### 8.8.7 Sequence Diagrams

**Hover flow:**

```
Player          Control           TooltipManager       Timer       TooltipPanel
  │ hover ──────►│                      │                │               │
  │              │ mouse_entered ──────►│                │               │
  │              │                      │ start(delay) ─►│               │
  │              │                      │◄── timeout ────│               │
  │              │                      │ callback()     │               │
  │              │◄─── return text ─────│                │               │
  │              │                      │ set_content() ─────────────────►│
  │              │                      │ state=SHOWING  │               │
  │ move ───────►│                      │ update pos ────────────────────►│
  │ leave ──────►│                      │                │               │
  │              │ mouse_exited ───────►│                │               │
  │              │                      │ hide panel     │               │
  │              │                      │ state=IDLE     │               │
```

**Programmatic (drag help) flow:**

```
GameBoard            TooltipManager       TooltipPanel
  │ drag start          │                      │
  │ show_text("…") ────►│ state=FORCED         │
  │                      │ set_content() ──────►│
  │ drag end             │                      │
  │ hide() ─────────────►│ state=IDLE           │
  │                      │ hide panel           │
```

### 8.8.8 File Layout

```
src/
├── autoload/
│   ├── tooltip_manager.gd          # NEW — autoload singleton
│   └── game_scale.gd               # MODIFY — add tooltip_* properties
├── core/
│   └── tooltip_layout.gd           # NEW — pure position logic (RefCounted)
└── ui/
    └── tooltip_panel.gd            # NEW — visual panel widget

tests/
├── unit/
│   └── test_tooltip_layout.gd      # NEW — clamping / offset tests
└── integration/
    └── test_tooltip_manager.gd     # NEW — register/hover/show/hide tests

Resources/Game_Components/scale/
    └── scale_config.json           # MODIFY — add "tooltip" section
```

Autoload registration in `project.godot`:
```ini
[autoload]
TooltipManager="*res://src/autoload/tooltip_manager.gd"
```

### 8.8.9 Testing Strategy

**Unit tests** (`test_tooltip_layout.gd`):

| Test | Scenario |
|------|----------|
| `test_compute_position_places_right_below_cursor()` | Normal offset applied |
| `test_compute_position_flips_horizontal_at_right_edge()` | Placed left of cursor |
| `test_compute_position_flips_vertical_at_bottom_edge()` | Placed above cursor |
| `test_compute_position_flips_both_at_corner()` | Bottom-right corner flip |
| `test_compute_position_clamps_to_zero()` | Negative position clamped |

**Integration tests** (`test_tooltip_manager.gd`):

| Test | Scenario |
|------|----------|
| `test_register_and_hover_shows_tooltip_after_delay()` | Hover → delay → visible |
| `test_hover_exit_hides_tooltip()` | Mouse exit → hidden |
| `test_callback_empty_string_suppresses_tooltip()` | Empty text → suppressed |
| `test_programmatic_show_overrides_hover()` | Forced overrides hover |
| `test_programmatic_hide_returns_to_idle()` | hide() → IDLE |
| `test_auto_hide_hides_after_timeout()` | Auto-hide timer works |
| `test_deregister_cleans_up_signals()` | No stale connections |
| `test_control_freed_auto_deregisters()` | No use-after-free |
| `test_delay_resets_on_region_change()` | Timer restarts |
| `test_toggle_disabled_suppresses_hover()` | Hover suppressed when off |
| `test_toggle_disabled_allows_programmatic()` | show_text() still works when off |

### 8.8.10 Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Tooltip flickers on rapid region crossings | UX annoyance | TT-003 restarts timer; 200 ms is responsive yet stable |
| `RichTextLabel` mis-sizes on first frame | 1-frame position glitch | Defer position via `resized` signal (existing pattern) |
| Many registrations in large scenes | Performance | O(1) dictionary lookup; signals are lightweight |
| Migration breaks drag/discard behaviour | Regression | Migrate one piece at a time with integration tests |
| Toggle button obscures game content | Visual clutter | Small 28 px icon, lower-right corner, configurable padding |

### 8.8.11 Implementation Order

| Step | Description | Depends on |
|------|-------------|------------|
| 1 | Add `"tooltip"` section to `scale_config.json` + `GameScale` properties | — |
| 2 | Create `TooltipLayout` + unit tests | — |
| 3 | Create `TooltipPanel` | Step 1 |
| 4 | Create `TooltipManager` (with toggle button + persistence) + integration tests | Steps 1–3 |
| 5 | Register `TooltipManager` in `project.godot` | Step 4 |
| 6 | Wire up initial hover regions (ShipCardPanel, dial stack) | Step 5 |
| 7 | Migrate drag help label → `show_text()` | Step 5 |
| 8 | Migrate discard prompt → `show_text()` | Step 5 |
| 9 | Migrate duplicate toast → `show_text()` + `auto_hide_sec` | Step 5 |
| 10 | Remove dead code (old Label creation/cleanup methods) | Steps 7–9 |
| 11 | Run full test suite, verify script count + 0 failures | Step 10 |

## 8.9 Effect/Hook Pipeline

### 8.9.1 Purpose

A pluggable pipeline for rule-modifying effects (squadron keywords, upgrade cards,
damage card effects, objective modifiers). Effects register for named "hook points"
and are resolved in priority order at runtime. This replaces hard-coded keyword
checks with an extensible architecture.

### 8.9.2 Architecture Overview

```
┌────────────────┐     ┌───────────────┐     ┌───────────────┐
│  EffectFactory │────▶│ EffectRegistry│────▶│  GameEffect   │
│  (registers)   │     │  (resolves)   │     │  (base class) │
└────────────────┘     └───────┬───────┘     └───────────────┘
                               │                      ▲
                               │ resolve_hook()       │ extends
                               ▼                      │
                       ┌───────────────┐     ┌────────┴────────────────┐
                       │ EffectContext │     │ BomberEffect            │
                       │ (mutable bag) │     │ EscortEffect            │
                       └───────────────┘     │ SwarmEffect             │
                                             │ StructuralDamageEffect  │
                                             │ BlindedGunnersEffect    │
                                             │ … (22 damage card types)│
                                             └─────────────────────────┘
```

### 8.9.3 Hook Points

All hooks are resolved via `EffectRegistry.resolve_hook(hook_name, context)`.
Context fields are read/written through the shared `EffectContext` data bag.
Unless noted, new context fields are passed via `EffectContext.metadata`.

#### Attack Pipeline Hooks

| # | Hook Name | Call Site | Purpose | Cards Using It |
|---|-----------|----------|---------|----------------|
| 0 | `ATTACK_CALC_DAMAGE` | `AttackExecutor._calc_attack_damage()` | Modify final damage total | Bomber (keyword) |
| 1 | `ATTACK_VALIDATE_TARGET` | Target selection in attack flow | Block illegal targets | Coolant Discharge (1 ship/round), Depowered Armament (no long range), Disengaged Fire Control (no obstructed) |
| 2 | `ATTACK_GATHER_DICE` | After assembling dice pool, before roll | Remove dice from pool | Damaged Munitions (−1 die vs ship), Point-Defense Failure (−1 die vs squadron) |
| 3 | `ATTACK_SPEND_ACCURACY` | During accuracy-spending sub-step | Block accuracy spending | Blinded Gunners (cannot spend accuracy icons) |
| 4 | `ATTACK_RESOLVE_CRITICAL` | Before resolving standard critical effect | Block critical effects | Targeter Disruption (cannot resolve critical effects) |
| 5 | `DEFENSE_VALIDATE_TOKEN` | When checking if a defense token can be spent | Block specific token spending | Faulty Countermeasures (no exhausted tokens), Capacitor Failure (no Redirect if zone shields = 0) |

**Context fields:**
- Hook 1: `metadata.target_is_ship` (bool), `metadata.is_obstructed` (bool), `metadata.ship_attacks_this_round` (int). Sets `cancelled`.
- Hook 2: `dice_pool` (existing). Effect removes entries.
- Hook 3: Sets `cancelled` to block accuracy spending.
- Hook 4: Sets `critical_allowed = false` (existing field).
- Hook 5: `metadata.token_type` (Constants.DefenseToken), `metadata.token_state` (Constants.DefenseTokenState), `defending_zone` (existing). Sets `cancelled`.

#### Movement Pipeline Hooks

| # | Hook Name | Call Site | Purpose | Cards Using It |
|---|-----------|----------|---------|----------------|
| 6 | `MANEUVER_DETERMINE_YAWS` | ManeuverTool yaw calculation | Reduce yaw at joints | Thrust Control Malfunction (last adjustable joint −1 yaw) |
| 7 | `AFTER_MANEUVER_EXECUTE` | After maneuver is committed | Post-move triggers | Ruptured Engine (suffer 1 dmg if speed > 1), Damaged Controls (+1 facedown on overlap) |
| 8 | `ON_SPEED_CHANGE` | When speed dial value changes | Speed-change triggers | Thruster Fissure (suffer 1 dmg on any speed change) |

**Context fields:**
- Hook 6: `metadata.yaw_values` (Array[int], mutated). `metadata.ship_speed` (int).
- Hook 7: `metadata.ship_speed` (int), `metadata.did_overlap` (bool).
- Hook 8: `metadata.old_speed` (int), `metadata.new_speed` (int).

#### Command & Status Phase Hooks

| # | Hook Name | Call Site | Purpose | Cards Using It |
|---|-----------|----------|---------|----------------|
| 9 | `BEFORE_REVEAL_DIAL` | Start of ship activation, before dial reveal | Pre-reveal penalties | Crew Panic (suffer 1 dmg or discard dial) |
| 10 | `CALC_ENGINEERING_VALUE` | RepairResolver.get_engineering_points() | Modify engineering value | Power Failure (halve, rounded down; stackable) |
| 11 | `STATUS_READY_TOKENS` | GameManager._begin_status_phase() | Block token readying | Compartment Fire (cannot ready defense tokens) |

**Context fields:**
- Hook 9: `metadata.dial_discarded` (bool, set if player chooses to discard).
- Hook 10: `metadata.engineering_value` (int, mutated by each Power Failure).
- Hook 11: Sets `cancelled` to block token readying for this ship.

#### Repair & Token Hooks

| # | Hook Name | Call Site | Purpose | Cards Using It |
|---|-----------|----------|---------|----------------|
| 12 | `REPAIR_VALIDATE_SHIELD` | RepairResolver.recover_shields() / move_shields() | Block shield ops on empty zones | Capacitor Failure (cannot recover/move shields to zone with 0 shields) |
| 13 | `ON_COMMAND_TOKEN_GAIN` | GameManager command token logic | Block token gain | Life Support Failure (cannot have command tokens) |

**Context fields:**
- Hook 12: `metadata.target_zone` (String), `metadata.target_zone_shields` (int). Sets `cancelled`.
- Hook 13: Sets `cancelled` to block token acquisition.

### 8.9.4 Immediate vs Persistent Damage Card Effects

Damage cards fall into two categories:

| Timing | Behaviour | Hook Needed? | Cards |
|--------|-----------|-------------|-------|
| **Immediate** | Resolved inline when dealt faceup, then flipped facedown | No hook — resolved by `DamageDeck`/`AttackExecutor` at deal time | Structural Damage (×8), Projector Misaligned (×2), Shield Failure (×2), Comm Noise (×2), Injured Crew (×4) |
| **Persistent** | Registered in `EffectRegistry` while faceup; unregistered on discard/flip | Yes — uses one or more hooks above | Blinded Gunners, Capacitor Failure, Compartment Fire, Coolant Discharge, Crew Panic, Damaged Controls, Damaged Munitions, Depowered Armament, Disengaged FC, Faulty Countermeasures, Point-Defense Failure, Power Failure, Ruptured Engine, Targeter Disruption, Thrust Control Malfunction, Thruster Fissure |
| **Hybrid** | Immediate action + persistent restriction; stays faceup | Yes | Life Support Failure (discard all tokens immediately; cannot gain tokens while faceup) |

### 8.9.5 Resolution Order

1. All effects registered for the current hook are collected
2. Effects are sorted by `player_priority` (initiative player = 0, other = 1)
3. Each effect's `should_trigger(context)` is checked
4. If true, `resolve(context)` mutates the shared `EffectContext`
5. After all effects resolve, the caller reads the mutated context

### 8.9.6 Adding New Effects

To add a new keyword, upgrade, or damage card effect:

1. Create a new class extending `GameEffect` in `src/core/effects/`
   - Keywords: `src/core/effects/keywords/`
   - Damage cards: `src/core/effects/damage_cards/`
2. Set `source_type` to the appropriate `EffectSource` enum value
3. Override `get_hooks()` → return the hook StringNames to listen on
4. Override `should_trigger(context)` → return true when the effect applies
5. Override `resolve(context)` → mutate the context data bag
6. Register in `EffectFactory` (for keywords) or when the card enters play (for damage/upgrades)
7. Unregister when the card leaves play (discarded, flipped facedown, ship destroyed)

### 8.9.7 Design Decisions

- **RefCounted, not Node:** Effects are pure logic, no scene tree dependency
- **Mutable context:** Single object passed by reference avoids allocations
- **Priority sort:** Ensures initiative player's effects resolve first (RRG "Effects and Timing")
- **Optional flag:** `is_optional` on GameEffect supports future player-choice effects
- **Metadata dict:** New hook-specific fields use `EffectContext.metadata` to keep the class stable across phases

## 8.10 Reusable Anchor-Based Panel Layout

### 8.10.1 Problem

Several modal panels (`AttackSimPanel`, `ActivationModal`,
`SquadronActivationModal`) are positioned via Godot's
`PRESET_CENTER_BOTTOM` anchor preset, grow upward
(`GROW_DIRECTION_BEGIN`), and are **reused** across multiple game phases
rather than re-created.  This reuse exposes three interrelated Godot
layout behaviours that combine to cause panels to appear at the wrong
size or drift off-screen:

| Behaviour | Root Cause | Visible Symptom |
|-----------|-----------|-----------------|
| **Stale cached size** | `PanelContainer.size` retains its previous height after children are removed | Panel appears at old (large) size on reopen |
| **Vertical offset drift** | Setting `size.y = 0` on an anchor-based control triggers vertical offset recalculation | Panel drifts upward by ~388 px per reopen cycle (mitigated by re-pinning `offset_top/bottom`) |
| **Horizontal drift** | Setting `size = Vector2.ZERO` (full vector) resets width; when content inflates beyond `custom_minimum_size.x`, Godot preserves the left edge and grows rightward | Panel centre shifts left by ~20 px per reopen cycle |
| **Hidden-child inflation** | Children with `visible = false` contribute to min-size during synchronous `add_child()`; only excluded in the deferred layout pass | Panel inflates to ~648 px (all sections) instead of ~120 px (visible only) |

The deferred layout pass that corrects hidden-child inflation fires
automatically the **first** time a panel becomes visible, but is
**not re-scheduled on panel reuse** — the second and subsequent attacks
retain the inflated size permanently.

### 8.10.2 Solution Pattern

A four-step reset sequence applied in `_build_ui()` and every `show_*()`
method:

```
_clear_content()          ← remove_child() before queue_free()
size.y = 0                ← zero stale cached HEIGHT only (not width!)
offset_top/bottom = -40   ← re-pin canonical vertical offsets
_request_deferred_layout()← call_deferred forces re-layout next frame
```

> **Critical:** Use `size.y = 0`, **not** `size = Vector2.ZERO`.  Zeroing
> the full vector resets horizontal width; when content children inflate
> the panel beyond `custom_minimum_size.x`, Godot preserves the left edge
> and grows rightward, causing the panel centre to shift left by ~20 px
> per reopen cycle.

> Full pattern with code examples: `.skills/ui_styling.md` § 10.

### 8.10.3 Affected Components

- `src/ui/attack_sim_panel.gd` — attack execution / simulator panel
- `src/ui/activation_modal.gd` — ship activation step tracker
- `src/ui/squadron_activation_modal.gd` — squadron activation flow

### 8.10.4 Key Insight

Godot's anchor/offset system is **bidirectional**: changing `size`
recalculates offsets, and changing offsets recalculates size.  When
resetting a reused panel, only the **vertical** component of `size`
should be zeroed (`size.y = 0`), followed by re-pinning vertical
offsets (`offset_top/bottom = -40`) within the same frame.  Zeroing
the full vector (`size = Vector2.ZERO`) also resets horizontal width,
causing horizontal drift when content exceeds `custom_minimum_size.x`.
A deferred layout reset on the next frame handles the hidden-child
inflation that cannot be resolved synchronously.

## 8.11 Overlap & Displacement Pattern

### 8.11.1 Context

After a ship commits its maneuver, the game must check for overlaps with other ships and squadrons. This involves two distinct resolution paths, both handled by `OverlapResolver` (RefCounted, scene-tree independent).

### 8.11.2 Ship–Ship Overlap Resolution

```
ManeuverToolScene.commit_maneuver()
    └─ OverlapResolver.check_ship_ship_overlap(moving_ship, all_ships)
        └─ For speed N down to 0:
            compute_final_transform(speed=trial)
            if no overlap → return {reduced_speed, [ship_a, ship_b]}
        └─ Both ships take 1 facedown damage card
        └─ Collision info emitted via EventBus.collision_detected
        └─ ActivationModal shows amber collision label
```

- **Pure core logic**: `OverlapResolver` only computes overlap geometry and returns results — no Node dependencies.
- **Presentation layer** (`game_board.gd`) interprets the result and drives UI (collision label, damage card draw).
- Speed reduction is temporary (for position computation only); `ShipInstance.current_speed` is not permanently changed.

### 8.11.3 Ship–Squadron Overlap Resolution (Displacement)

```
After maneuver commit:
    OverlapResolver.find_overlapped_squadrons(ship, all_squadrons)
        └─ Returns list of overlapped squadrons

    Camera flips 180° to opposing player's perspective
    DisplacementModal opens (checklist of displaced squadrons)
        └─ For each squadron:
              OverlapResolver.snap_to_ship_edge(squadron_pos, ship) → initial position
              Mouse-follow mode for fine placement
              OverlapResolver.validate_squadron_placement(pos, ship) → Boolean
              Left-click → lock position (✓ in checklist)
        └─ "Commit Placement ►" enabled when all checked
        └─ Camera flips back to active player
```

- **Displacement is an opponent action**: the opposing player places the squadrons, not the active player.
- **Snap-to-edge** provides a valid starting position; the player can adjust within the ship's footprint boundary.
- The `DisplacementModal` follows the same panel styling conventions as other modals (§8.10).

### 8.11.4 End-of-Activation Flow

After maneuver commit (with or without overlap), the activation modal stays open showing all 5 steps checked. An "End Activation ►" button appears at the bottom. The player must deliberately press it to emit `activation_ended`. This prevents accidental activation ending and gives the player a moment to review the collision result.
