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
`CommandDialStack`, `CommandTokens`, `GameCommand` (and all 26 subclasses),
`FleetSetupPackage` and `SetupValidationResult` for pre-game roster/setup
handoff, and the fleet-builder roster payload classes (`FleetRoster`, `FleetShipEntry`,
`FleetSquadronEntry`, `FleetUpgradeAssignment`, `FleetObjectiveSelection`,
`FleetValidationResult`).

`FleetSetupPackage.canonical_hash()` uses `CanonicalJson` sorted-key JSON so
hot-seat, network, replay, and future setup flows can compare embedded roster
payloads without depending on local fleet-library files or volatile timestamps.
`FleetSetupPackageBuilder` maps local fleet ids or host/client roster ownership
into player-indexed packages without storing transport-specific peer ids in core
setup JSON.
`FleetRosterSetupHelper` is the package-to-runtime seam for fleet starts: it
loads static ship, squadron, and upgrade data from the catalog, creates
`PlayerState`, `ShipInstance`, and `SquadronInstance` objects, and rejects
missing catalog records before bootstrap. Runtime ship and squadron instances
serialize `roster_entry_id` plus roster-derived `fleet_points`, so deployment
mapping and save/load do not depend on local fleet-library files.
`FleetSetupBootstrapper` is the setup-package-to-`GameState` seam: it consumes
that runtime conversion, installs initiative, seeded RNG, shared damage deck,
and objective/setup payload into `GameState.objectives`. `GameManager` then
marks package starts as preloaded so `GameBoard` can reuse the existing
loaded-state token spawn and binding path.
`ScoringCalculator` reads those runtime fleet-point values for destroyed
entities, falling back to static card costs for older saves and scenario-only
instances.
`FleetRoster.serialize()` orders ships, squadrons, and ship upgrade assignments
by stable `entry_id` before hashing so equivalent builder actions produce the
same setup-ready payload shape.

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

## 8.7.1 Setup UI Contract Gate

Setup-phase UI work has an additional architecture gate. The authoritative
human-facing contract is `docs/setup_flow.md`. It must describe the affected
setup step before implementation begins, including controller ownership,
hot-seat and network visibility, required information on screen, actions,
serialized state/command payloads, validation, transitions, and tests.

If the relevant section of `docs/setup_flow.md` is missing, marked `Draft`, or
ambiguous, presentation work under `src/scenes/`, `src/ui/`, or setup-specific
autoload wiring must not be edited. The correct action is to update the
contract and get explicit owner approval before implementing UI. This gate
protects setup usability from implicit design decisions hidden in code.

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

## 8.9 RuleRegistry Hook Pipeline

### 8.9.1 Purpose

A pluggable pipeline for rule-modifying behavior: squadron keywords, upgrade
cards, damage cards, objectives, obstacles, tokens, and rule-derived UI
affordances. `RuleRegistry` stores static hook definitions; active rule status
comes from serialized game entities and command/flow context.

As of Phase N24, this is the only production rule-extension architecture. The
legacy runtime effect system (`EffectRegistry`, `GameEffect`,
`DamageCardEffect`, runtime rebuild factories, and old hook-string dispatch)
is retired and guarded from production reintroduction by the Phase K/N lint
gate.

### 8.9.2 Architecture Overview

```
┌──────────────┐     ┌──────────────┐     ┌───────────────┐
│ RuleBootstrap│────▶│ RuleRegistry │────▶│  FlowHook     │
│ (registers)  │     │ (catalogue)  │     │  descriptors  │
└──────────────┘     └──────┬───────┘     └───────────────┘
                            │
                            │ RuleSurface runners
                            ▼
                    ┌───────────────┐
                    │ EffectContext │
                    │ (mutable bag) │
                    └──────┬────────┘
                           │
                           ▼
              Serialized entities and command metadata
```

### 8.9.3 Rule Surfaces

Rule files register `FlowHook` descriptors on `RuleSurface` target names.
Callers pass typed objects plus JSON-safe metadata through `EffectContext`; rule
callbacks may validate, block, modify, enable UI affordances, or return
follow-up commands. The registry never stores active card/keyword instances.

| Surface | Typical Call Sites | Purpose | Current Rules |
|---|---|---|---|
| `attack_damage` | `AttackDiceResolver.calc_damage()` | Modify final damage total from serialized attacker/defender state | Bomber |
| `attack_target` | Attack declaration validation and target filtering | Block illegal target declarations | Depowered Armament, Disengaged Fire Control, Coolant Discharge, Escort |
| `dice_pool` | `AttackDiceResolver.apply_gather_hook()` | Expose/apply pre-roll dice-pool choices | Damaged Munitions, Point-Defense Failure |
| `attack_dice_attacker` | Attack modification step | Attacker-side dice affordances/results | Swarm |
| `accuracy_spend` | Defense-step payload and command validation | Block accuracy spending | Blinded Gunners |
| `critical_effect` | Damage resolution | Block critical effects | Targeter Disruption |
| `defense_token_spend` | Defense-token eligibility/projection | Block specific defense-token buttons | Faulty Countermeasures, Capacitor Failure |
| `squadron_attack` | Squadron activation attack validation/projection | Enforce keyword attack rules | Heavy, Counter, Escort |
| `maneuver_yaw` | Maneuver yaw calculation | Modify yaw values from faceup damage state | Thrust Control Malfunction |
| `after_maneuver` | Maneuver observer follow-ups | Add post-move damage follow-up commands | Damaged Controls, Ruptured Engine |
| `speed_change` | Speed-change observer follow-ups | Add speed-change damage follow-up commands | Thruster Fissure |
| `command_dial_reveal` | Pre-reveal projection and activation command paths | Offer/validate rule choices before reveal | Crew Panic |
| `engineering_value` | Repair point calculation | Modify engineering value | Power Failure |
| `defense_token_readying` | Status-phase cleanup | Block token readying | Compartment Fire |
| `repair_shield` | Repair action eligibility | Block shield operations | Capacitor Failure |
| `command_token_gain` | Dial/token conversion and token gain helpers | Block command-token gain | Life Support Failure |

### 8.9.4 Immediate vs Persistent Damage Card Effects

Damage cards fall into three categories:

| Timing | Behaviour | Active Source | Examples |
|---|---|---|---|
| **Immediate** | Resolved inline when dealt faceup, then flipped facedown | Damage deck result and command payload | Structural Damage, Projector Misaligned, Shield Failure, Comm Noise, Injured Crew |
| **Persistent** | Faceup card stays on the ship and RuleRegistry callbacks read `ShipInstance.faceup_damage` | Serialized faceup damage | Faulty Countermeasures, Capacitor Failure, Compartment Fire, Damaged Munitions, Point-Defense Failure, Power Failure, Depowered Armament, Disengaged Fire Control, Coolant Discharge, Blinded Gunners, Targeter Disruption, movement damage cards |
| **Hybrid** | Immediate action plus persistent restriction | Immediate command/resolver plus serialized faceup damage | Life Support Failure, Crew Panic |

### 8.9.5 Resolution Order

1. `RuleBootstrap` registers static hook descriptors at startup/test setup.
2. The caller invokes the relevant `RuleSurface` runner with current state and context.
3. Matching hooks are sorted by priority and deterministic registration order.
4. Each callback reads serialized active state and mutates `EffectContext` or returns follow-up commands.
5. The command/projection caller consumes the accepted result or payload metadata.

### 8.9.6 Adding New Rules

New rules, damage-card effects, keywords, upgrades, objectives, obstacles, and
rule-derived UI affordances go through `RuleRegistry` rule files under
`src/core/effects/rules/`. A rule file registers static `FlowHook` descriptors,
reads active state from serialized entities such as `ShipInstance.faceup_damage`,
and returns validation, blocking, modification, enablement, or observer results
without storing mutable active state in the registry.

### 8.9.7 Design Decisions

- **RefCounted, not Node:** rules are pure logic, no scene tree dependency
- **Serialized active state:** save/load, replay, hot-seat, and network all derive active status from the same state
- **Priority sort:** deterministic ordering supports timing conflicts and initiative-sensitive effects
- **Metadata dict:** hook-specific fields use `EffectContext.metadata` to keep the class stable across phases
- **No runtime effect rebuild:** save/load restores serialized entities only; rule files re-evaluate active status from that state on demand

### 8.9.8 RuleRegistry Integration Pattern

`RuleSurface` is the shared vocabulary and callback runner for common target
surfaces. It keeps surface names such as attack target blocking, attack damage
modification, critical-effect blocking, engineering value modification,
command-token gain blocking, maneuver yaw modification, and post-maneuver
observer follow-ups in one pure core helper while `RuleRegistry` remains the
only hook catalogue. The Phase N23 static guard prevents production code from
reintroducing retired runtime effect classes or legacy hook-string dispatch.

The M7 Faulty Countermeasures bug established an additional crosscutting rule:
player-choice rules must cover every command surface, not only the final state
mutation. If a panel submits a marker command before a mutation command, both
must be validated by the same rule. Any disabled/blocked choice metadata must
be published through `GameState.interaction_flow.payload`, and UI panels must
render that metadata without re-implementing card text.

The N23/N24 Squadron command follow-ups add two related command-flow rules.
First, lifecycle markers must be legal wherever their producers can emit them:
`complete_squadron_activation` is phase-scoped for both SHIP and SQUADRON and
is also listed on the ship-activation Squadron step so no-move activations can
synchronize hot-seat, replay, and network peers. Second, preview is not commit:
clicking a squadron to inspect ranges or switching selection is presentation
state only. Squadron command activation budget is consumed when a real move or
attack begins, and no-move completion uses the explicit lifecycle marker rather
than a dummy zero-distance movement command.

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
