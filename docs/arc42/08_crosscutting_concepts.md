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

- Save/Load functionality
- Potential future network synchronization
- Test fixture generation

All serializable classes implement `serialize() -> Dictionary` and `static deserialize(data: Dictionary)`.

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
                       ┌───────────────┐     ┌────────┴────────┐
                       │ EffectContext │     │ BomberEffect    │
                       │ (mutable bag) │     │ EscortEffect    │
                       └───────────────┘     │ SwarmEffect     │
                                             └─────────────────┘
```

### 8.9.3 Hook Points

| Hook Name | Where Resolved | Purpose |
|-----------|---------------|---------|
| `ATTACK_CALC_DAMAGE` | `AttackExecutor._calc_attack_damage()` | Modify final damage total (Bomber) |
| `ATTACK_MODIFY_DICE_ATTACKER` | (future) attack step 3 | Modify dice pool (Swarm reroll) |
| `SQUADRON_MUST_ATTACK_ENGAGED` | (future) target selection | Force targeting Escort squadrons |

### 8.9.4 Resolution Order

1. All effects registered for the current hook are collected
2. Effects are sorted by `player_priority` (initiative player = 0, other = 1)
3. Each effect's `should_trigger(context)` is checked
4. If true, `resolve(context)` mutates the shared `EffectContext`
5. After all effects resolve, the caller reads the mutated context

### 8.9.5 Adding New Effects

To add a new keyword or upgrade effect:

1. Create a new class extending `GameEffect` in `src/core/effects/`
2. Override `get_hooks()` → return the hook StringNames to listen on
3. Override `should_trigger(context)` → return true when the effect applies
4. Override `resolve(context)` → mutate the context data bag
5. Register in `EffectFactory` (for keywords) or at game start (for upgrades)

### 8.9.6 Design Decisions

- **RefCounted, not Node:** Effects are pure logic, no scene tree dependency
- **Mutable context:** Single object passed by reference avoids allocations
- **Priority sort:** Ensures initiative player's effects resolve first (RRG "Effects and Timing")
- **Optional flag:** `is_optional` on GameEffect supports future player-choice effects
