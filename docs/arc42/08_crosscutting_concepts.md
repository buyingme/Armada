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
`CommandDialStack`, `CommandTokens`, `GameCommand` (and all 26 subclasses).

`GameState` also serializes round-scoped rule counters when they affect
future legality. N7 added `ship_target_attack_counts`, keyed by
`round:owner_player:ship_index`, so Coolant Discharge can block later
ship-target declarations from save/load, replay, hot-seat, and network state
without depending on scene-local attack-executor counters.

`GameCommand.serialize()` produces `{type, player, sequence, payload}`.
`GameCommand.deserialize()` dispatches to the correct subclass via the
command type registry.  Replay files (`GameReplay`) store the full
command history as a JSON array of serialized commands.

Movement rule observers depend on command-result metadata rather than local UI
state. N12-N15 added `ExecuteManeuverCommand` fields for `did_overlap` and
`speed_delta`, and `PersistentEffectDamageCommand` can draw from
`GameState.damage_deck` during `execute()`. This keeps Ruptured Engine,
Damaged Controls, and Thruster Fissure follow-up damage deterministic across
hot-seat, replay, and network mirrors.

`SaveGameManager` saves to `res://saves/` (project directory) as
pretty-printed JSON. Debug keybinds: **F5** quicksave, **F8** quickload
(debug mode only). Ship/squadron template re-association after load is
the caller's responsibility via `AssetLoader` look-ups.

### 8.6.1 Replay Regression Gates

Phase L0.5 adds an opt-in replay regression harness for modal and
network refactoring work:

- `ReplayDriver` is an autoload activated only by `--replay <path>`.
  It loads a `GameReplay`, seeds the match, drives commands through the
  active `CommandSubmitter`, and exits non-zero on replay failure.
- `BaselineTrace` writes a diagnostic JSONL projection of
  `(seq, command_type, flow_type, step_id, controller_player)` plus a
  sibling `.state_hash` file derived from canonical `GameState.serialize()`
  JSON.
- Hot-seat replay is deterministic.  `scripts/run_baseline_traces.sh
  --hot-seat` diffs both the JSONL trace and final-state hash against
  committed fixtures in `tests/fixtures/baseline_traces/`.
- Network replay uses the real two-process ENet host/client path.  Valid
  localhost packet timing can produce different command interleavings
  across runs, so network JSONL is diagnostic only.  The automated gate
  requires host and client to finish the same run with identical
  final-state hashes.
- During replay sessions, live auto-publishing of attack-flow snapshots is
  suppressed because the replay file already contains the captured
  `PublishAttackFlowCommand` entries.  This keeps the replay file as the
  single source of commands while preserving the production command and
  network submitter paths.

For Phase L/M slices that touch modal lifecycle, replay, or network flow,
`bash scripts/run_baseline_traces.sh --all` is a required local gate in
addition to GUT and `scripts/lint_phase_k.sh`.

## 8.7 Code Organization

Refactoring metrics are used to keep responsibilities small and testable. The
30-line function cap excludes doc comments and blank lines. File-level LOC
ceilings are extraction triggers: do not delete useful docstrings or rationale
comments just to reduce raw line counts. For complex network, replay,
serialization, and modal-flow code, concise source-level rationale is preferred;
full historical narrative belongs in this architecture documentation or the
phase plan.

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

Legacy hooks are resolved via `EffectRegistry.resolve_hook(hook_name, context)`.
Migrated Phase M rules use `RuleRegistry` hook descriptors on FlowSpec
surfaces and share the same transient `EffectContext` data bag where a hook
modifies an attack, status, or repair context. Unless noted, new context fields
are passed via `EffectContext.metadata`.

#### Attack Pipeline Hooks

| # | Hook Name | Call Site | Purpose | Cards Using It |
|---|-----------|----------|---------|----------------|
| 0 | `ATTACK_CALC_DAMAGE` | `AttackDiceResolver.calc_damage()` legacy fallback | Legacy damage-total modifiers | No current production keyword after N10; compatibility fallback only. |
| 0a | `attack_damage` RuleRegistry modifier | `AttackDiceResolver.calc_damage()` on `ATTACK / ATTACK_RESOLVE_DAMAGE` | Modify final damage total from serialized attacker/defender state | Bomber (squadron crit icons count against ships). |
| 1 | `ATTACK_VALIDATE_TARGET` | Target selection in attack flow legacy fallback | Legacy target blockers | No current production damage card after N7; compatibility fallback only. |
| 1a | `attack_target` RuleRegistry blocker | `AttackDiceResolver` and `publish_attack_flow` validation on `ATTACK / ATTACK_DECLARE` | Block illegal target declarations from serialized state | Depowered Armament (no long range), Disengaged Fire Control (no obstructed), Coolant Discharge (one ship-targeting attack per round). |
| 2 | `ATTACK_GATHER_DICE` | After assembling dice pool, before roll | Legacy pre-roll dice-pool effects | Remaining non-migrated effects only |
| 2a | `dice_pool` RuleRegistry modifier | `AttackDiceResolver.apply_gather_hook()` after legacy gather-dice hooks | Expose/apply pre-roll dice-pool choices | Damaged Munitions (attacker chooses −1 die vs ship), Point-Defense Failure (attacker chooses −1 die vs squadron) |
| 3 | `ATTACK_SPEND_ACCURACY` | Accuracy-spending legacy fallback | Block accuracy spending | No current production damage card after N8; compatibility fallback only. |
| 3a | `accuracy_spend` RuleRegistry blocker | Attack defense-step payload and command validation | Block accuracy spending from serialized attacker state | Blinded Gunners (cannot spend accuracy icons). |
| 4 | `ATTACK_RESOLVE_CRITICAL` | Critical-resolution legacy fallback | Block critical effects | No current production damage card after N9; compatibility fallback only. |
| 4a | `critical_effect` RuleRegistry blocker | `DefenseTokenResolver.determine_first_card_faceup()` on `ATTACK / ATTACK_RESOLVE_DAMAGE` | Block critical effects from serialized attacker state | Targeter Disruption (cannot resolve critical effects). |
| 5 | `DEFENSE_VALIDATE_TOKEN` | Retired production bridge after N2 | Former legacy defense-token hook | No current production cards use this bridge. |
| 5a | `defense_token_spend` RuleRegistry blocker | `DefenseTokenResolver` while building spendable-token/UI eligibility | Block specific defense-token buttons from authoritative state | Faulty Countermeasures (no exhausted tokens), Capacitor Failure (no Redirect if the defending hull zone has 0 shields) |

**Context fields:**
- Hook 1: `metadata.target_is_ship` (bool), `metadata.is_obstructed` (bool), `metadata.ship_attacks_this_round` (int). Sets `cancelled` for remaining legacy target effects.
- Hook 0a: `attacker`, `defender`, `dice_results`, and `damage_total`. Bomber recalculates critical icons as damage only when a Bomber squadron attacks a ship.
- Hook 1a: `attacker`, `defender`, `range_band`, obstruction metadata, serialized ship-target attack counts, and attack-flow payload identity. Blocks long range, obstructed attacks, or extra ship-targeting attacks according to the active faceup damage card.
- Hook 2: `dice_pool` (existing legacy surface). Remaining effects remove entries.
- Hook 2a: `attacker`, `defender`, and `dice_pool`. The modifier reads the
  attacker's `faceup_damage`, exposes pending die-choice metadata, and then
  removes the selected die when the target predicate matches the card text.
- Hook 3/3a: Legacy effects set `cancelled`; RuleRegistry blockers publish zero spendable accuracies and reject locked-token submissions.
- Hook 4/4a: Legacy effects set `critical_allowed = false`; RuleRegistry blockers force the first damage card facedown when the attacking ship has faceup Targeter Disruption.
- Hook 5: `metadata.token_type` (Constants.DefenseToken), `metadata.token_state` (Constants.DefenseTokenState), `defending_zone` (existing). Sets `cancelled`.

#### Movement Pipeline Hooks

| # | Hook Name | Call Site | Purpose | Cards Using It |
|---|-----------|----------|---------|----------------|
| 6 | `MANEUVER_DETERMINE_YAWS` | `ManeuverRuleResolver.apply_yaw_modifiers()` compatibility fallback | Reduce yaw at joints | Thrust Control Malfunction (legacy behaviour preserved until N12). |
| 6a | `maneuver_yaw` RuleRegistry modifier | `ManeuverRuleResolver.apply_yaw_modifiers()` on `SHIP_ACTIVATION / MANEUVER_STEP` | Modify maneuver yaw values from serialized ship state | Reserved for Thrust Control Malfunction migration in N12. |
| 7 | `AFTER_MANEUVER_EXECUTE` | `ManeuverRuleResolver.resolve_after_maneuver_effect_id()` compatibility fallback | Post-move triggers | Ruptured Engine (suffer 1 dmg if speed > 1), Damaged Controls (+1 facedown on overlap). |
| 8 | `ON_SPEED_CHANGE` | `ManeuverRuleResolver.resolve_speed_change_effect_id()` compatibility fallback | Speed-change triggers | Thruster Fissure (suffer 1 dmg on any speed change). |

**Context fields:**
- Hook 6: `metadata.yaw_values` (Array[int], mutated). `metadata.ship_speed` (int).
- Hook 7: `metadata.ship_speed` (int), `metadata.did_overlap` (bool).
- Hook 8: `metadata.old_speed` (int), `metadata.new_speed` (int).

#### Command & Status Phase Hooks

| # | Hook Name | Call Site | Purpose | Cards Using It |
|---|-----------|----------|---------|----------------|
| 9 | `command_dial_reveal` RuleRegistry enabler | `UIProjector.affordances` during `SHIP_ACTIVATION / WAIT_FOR_SHIP_SELECT` | Pre-reveal choice affordance | Crew Panic (suffer 1 dmg or discard dial) |
| 10 | `CALC_ENGINEERING_VALUE` | RepairResolver legacy fallback | Legacy engineering value modifier | No current production card after N3. |
| 10a | `engineering_value` RuleRegistry modifier | RepairResolver engineering point calculation | Modify engineering value from serialized damage state | Power Failure (halve, rounded down; stackable) |
| 11 | `defense_token_readying` RuleRegistry modifier | StatusPhaseCleanupCommand ship cleanup | Block token readying | Compartment Fire (cannot ready defense tokens) |

**Context fields:**
- Hook 9: `UIIntent.affordances.crew_panic_choices` contains JSON-safe
  `owner_player`, `ship_index`, and modal `choice_info`; active state comes
  from `ShipInstance.faceup_damage`.
- Hook 10/10a: `metadata.engineering_value` (int, mutated by each Power Failure through RuleRegistry after N3).
- Hook 11: `metadata.ship` (ShipInstance). Sets `cancelled` to block token readying for this ship.

#### Repair & Token Hooks

| # | Hook Name | Call Site | Purpose | Cards Using It |
|---|-----------|----------|---------|----------------|
| 12 | `REPAIR_VALIDATE_SHIELD` | RepairResolver.recover_shields() / move_shields() | Legacy shield-operation blockers | Remaining non-migrated repair effects only |
| 12a | `repair_shield` RuleRegistry blocker | `RepairResolver` repair action eligibility | Block shield ops on empty zones | Capacitor Failure (cannot recover/move shields to zone with 0 shields) |
| 13 | `ON_COMMAND_TOKEN_GAIN` | Retired production bridge after N4 | Former legacy token-gain blocker | No current production cards use this bridge. |
| 13a | `command_token_gain` RuleRegistry blocker | Convert-dial/token helper paths during ship activation | Block command-token gain from serialized damage state | Life Support Failure (cannot have/gain command tokens) |

**Context fields:**
- Hook 12: `metadata.target_zone` (String), `metadata.target_zone_shields` (int). Sets `cancelled`.
- Hook 13a: `metadata.ship` (ShipInstance). Blocks token acquisition; immediate token discard remains in the immediate-effect command/resolver.

### 8.9.4 Immediate vs Persistent Damage Card Effects

Damage cards fall into two categories:

| Timing | Behaviour | Hook Needed? | Cards |
|--------|-----------|-------------|-------|
| **Immediate** | Resolved inline when dealt faceup, then flipped facedown | No hook — resolved by `DamageDeck`/`AttackExecutor` at deal time | Structural Damage (×8), Projector Misaligned (×2), Shield Failure (×2), Comm Noise (×2), Injured Crew (×4) |
| **Persistent** | Registered in `EffectRegistry` while faceup; unregistered on discard/flip | Yes — uses one or more legacy hooks above | Damaged Controls, Ruptured Engine, Thrust Control Malfunction, Thruster Fissure |
| **RuleRegistry-migrated persistent** | Static rule hook reads active `faceup_damage` state instead of registering a legacy runtime effect | No legacy bridge after migration unless noted | Faulty Countermeasures, Capacitor Failure, Compartment Fire, Crew Panic, Damaged Munitions, Point-Defense Failure, Power Failure, Depowered Armament, Disengaged Fire Control, Coolant Discharge, Blinded Gunners, Targeter Disruption |
| **Hybrid** | Immediate action + persistent restriction; stays faceup | Immediate command/resolver plus RuleRegistry persistent restriction | Life Support Failure (discard all tokens immediately; cannot gain tokens while faceup) |

### 8.9.5 Resolution Order

1. All effects registered for the current hook are collected
2. Effects are sorted by `player_priority` (initiative player = 0, other = 1)
3. Each effect's `should_trigger(context)` is checked
4. If true, `resolve(context)` mutates the shared `EffectContext`
5. After all effects resolve, the caller reads the mutated context

### 8.9.6 Adding New Rules

New rules, damage-card effects, keywords, upgrades, objectives, obstacles, and
rule-derived UI affordances go through `RuleRegistry` rule files under
`src/core/effects/rules/`. A rule file registers static `FlowHook` descriptors,
reads active state from serialized game entities such as `ShipInstance.faceup_damage`,
and returns validation, blocking, modification, enablement, or observer results
without storing mutable active state in the registry.

The older `GameEffect` / `EffectRegistry` pattern remains only for Phase N
legacy bridges until their source rules migrate. New production work should not
add `GameEffect` subclasses unless a temporary legacy bridge is explicitly
approved and documented.

### 8.9.7 Design Decisions

- **RefCounted, not Node:** Effects are pure logic, no scene tree dependency
- **Mutable context:** Single object passed by reference avoids allocations
- **Priority sort:** Ensures initiative player's effects resolve first (RRG "Effects and Timing")
- **Optional flag:** `is_optional` on GameEffect supports future player-choice effects
- **Metadata dict:** New hook-specific fields use `EffectContext.metadata` to keep the class stable across phases

### 8.9.8 RuleRegistry Integration Pattern

Phase M adds `RuleRegistry` as the static catalogue for rule hooks while
`EffectRegistry` remains the transient runtime bridge for legacy effects. A
rule file declares which hooks exist, but active rule status is derived from
serialized game entities (`GameState`, ships, squadrons, faceup damage cards,
upgrades, objectives) or from a documented `EffectRegistry` bridge rebuilt from
those entities after load.

Phase N adds `RuleSurface` as the shared vocabulary and callback runner for
common target surfaces. It keeps surface names such as attack target blocking,
attack damage modification, critical-effect blocking, engineering value
modification, command-token gain blocking, maneuver yaw modification, and
post-maneuver observer follow-ups in one pure core helper while
`RuleRegistry` remains the only hook catalogue. N11 routes remaining movement
compatibility through `ManeuverRuleResolver` so scene/tool code no longer owns
legacy movement hook predicates during the N12-N15 migration.

The M7 Faulty Countermeasures bug established an additional crosscutting rule:
player-choice rules must cover every command surface, not only the final state
mutation. If a panel submits a marker command before a mutation command, both
must be validated by the same rule. Any disabled/blocked choice metadata must
be published through `GameState.interaction_flow.payload`, and UI panels must
render that metadata without re-implementing card text.

The source-first grouping proposal for future rule files is documented in
[src/core/effects/rules/README.md](../../src/core/effects/rules/README.md):
core rules by subsystem, damage cards by deck/type, squadron and ship keywords,
upgrades by slot, objectives by category, obstacles, and special tokens. This
keeps rules findable by the game component a contributor sees on the table.

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

## 8.12 Command Pattern & Replay System

### 8.12.1 Purpose

Every game-state mutation must route through a `GameCommand.execute()` call
(§4.6 mutation rule).  This ensures:

- **Replay safety:** the full game can be reconstructed from the command history.
- **Multiplayer readiness:** commands are serializable and can be transmitted
  over the network to an authoritative host.
- **Determinism:** combined with `GameRng` (seeded RNG), identical command
  sequences produce identical game states.

### 8.12.2 Architecture Overview

```
Presentation Layer          Application Layer           Domain Layer
┌─────────────────┐   submit()   ┌──────────────────┐   execute()   ┌──────────────┐
│  GameBoard      │─────────────▶│ CommandProcessor  │─────────────▶│ GameCommand   │
│  AttackExecutor │              │ (autoload)        │              │ (RefCounted)  │
│  ShipCardPanel  │              │                   │              │               │
│  ManeuverTool   │   result     │ validate → seq →  │   result     │ mutates       │
│  ...            │◀─────────────│ execute → record  │◀─────────────│ GameState     │
└─────────────────┘              └──────────────────┘              └──────────────┘
                                        │
                                        │ command_executed signal
                                        ▼
                                 ┌──────────────────┐
                                 │ GameReplay        │
                                 │ (record/playback) │
                                 └──────────────────┘
```

### 8.12.3 Command Lifecycle

1. **Presentation layer** gathers parameters (ship index, dice pool, card data, etc.)
2. Calls a `GameManager.submit_*()` convenience method
3. `GameManager` builds a `GameCommand` subclass with a serializable payload
4. `CommandProcessor.submit()`:
   - Calls `command.validate(game_state)` — returns error string or `""`
   - Assigns monotonically increasing sequence number
   - Calls `command.execute(game_state)` — mutates state, returns result dict
   - Appends to history array
   - Emits `command_executed(command, result)` signal
5. Presentation layer receives result and emits `EventBus` signals for UI updates

### 8.12.4 Command Tiers (26 classes)

| Tier | Commands | Domain |
|------|----------|--------|
| 1 | AssignDial, ActivateShip, EndActivation, ConvertDialToToken, ActivateSquadron, SpendToken, SpendDial | Core actions |
| 2 | RollDice, SpendDefenseToken, SelectRedirectZone, SkipAttack | Attack pipeline |
| 3 | MoveSquadron, ExecuteManeuver | Movement |
| 4 | AdvancePhase, StartRound | Game flow |
| 5 | StatusPhaseCleanup, DestroyUnit | Status phase |
| 6 | ResolveDamage | Damage resolution |
| 7 | RepairAction | Repair actions |
| 8 | ResolveImmediateEffect | Immediate damage card effects |
| 9 | SetSpeed, OverlapDamage, PersistentEffectDamage | Movement side-effects |
| 10 | DiscardToken, RevealDial | UI state |
| 11 | DebugDealDamage | Debug-only |

### 8.12.5 Deterministic RNG

`GameRng` wraps Godot's `RandomNumberGenerator` with a captured initial seed.
All random operations (dice rolls via `Dice`, deck shuffles via `DamageDeck`)
use `GameRng` instead of global `randi()`.  The seed is stored in the replay
header, enabling deterministic playback.

### 8.12.6 Replay System

`GameReplay` captures:
- **Header:** scenario ID, RNG seed, factions, initiative player
- **Commands:** ordered array of serialized `GameCommand` dictionaries

File format: JSON v1, saved to `res://replays/`.  Debug keybind: **Shift+R**
saves a replay; auto-save on game exit and game over.

Playback: `CommandProcessor.replay_commands()` deserializes and re-submits
each command in order, reconstructing the full game state.

### 8.12.7 §4.6 Mutation Rule

> All mutations of `GameState`-owned data must route through a
> `GameCommand.execute()` call.

This rule is enforced by code review (no automated linter yet).
34 violations were identified across 8 files and resolved in 7 priority
phases (P1–P7), producing 13 new command classes.  One debug-only
violation was resolved with `DebugDealDamageCommand`.
