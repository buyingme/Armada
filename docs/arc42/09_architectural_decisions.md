# 9. Architectural Decisions

## ADR Template

Each decision follows this structure:

- **ID:** ADR-NNN
- **Status:** Proposed | Accepted | Deprecated | Superseded
- **Context:** What is the issue?
- **Decision:** What was decided?
- **Consequences:** What are the trade-offs?

---

## ADR-001: Use Godot Engine 4.5

- **Status:** Accepted
- **Date:** 2026-03-07
- **Context:** Need a game engine for a 2D/3D board game adaptation. Options considered: Unity, Unreal, Godot, custom engine.
- **Decision:** Use Godot Engine 4.5+ with GDScript.
- **Consequences:**
  - (+) Open source, no licensing costs
  - (+) Excellent 2D support, suitable for board game representation
  - (+) Built-in scene/node system maps well to game objects
  - (+) Active community and good documentation
  - (-) Smaller ecosystem than Unity/Unreal
  - (-) GDScript is less performant than C#/C++, but sufficient for turn-based gameplay

---

## ADR-002: Event Bus Pattern for Inter-System Communication

- **Status:** Accepted
- **Date:** 2026-03-07
- **Context:** Game systems (combat, movement, UI) need to communicate without tight coupling.
- **Decision:** Use a central EventBus singleton with Godot signals.
- **Consequences:**
  - (+) Loose coupling between systems
  - (+) Easy to add new listeners without modifying emitters
  - (+) Signals are monitorable in tests
  - (-) Can make control flow harder to trace
  - (-) Must maintain discipline to not bypass the bus

---

## ADR-003: Separate Core Logic from Scene Tree

- **Status:** Accepted
- **Date:** 2026-03-07
- **Context:** Core game rules need to be testable without running the full Godot scene tree.
- **Decision:** Classes in `src/core/` extend `RefCounted` (not `Node`) and have no scene tree dependencies.
- **Consequences:**
  - (+) Core logic can be unit-tested without scene tree
  - (+) Clear separation of concerns
  - (-) Some convenience of Node lifecycle (e.g., `_process()`) is unavailable
  - (-) Need explicit wiring between core logic and scene objects

---

## ADR-004: GUT for Testing Framework

- **Status:** Accepted
- **Date:** 2026-03-07
- **Context:** Need a testing framework that works within the Godot ecosystem.
- **Decision:** Use GUT (Godot Unit Testing) addon.
- **Consequences:**
  - (+) Well-maintained, Godot-native solution
  - (+) Supports unit tests, integration tests, parameterized tests
  - (+) Provides assertions, spies, stubs, and doubles
  - (-) Must be installed as an addon
  - (-) Limited CI/CD documentation compared to mainstream frameworks

---

## ADR-005: Resource-Based Data Model

- **Status:** Accepted
- **Date:** 2026-03-07
- **Context:** Ship, squadron, and upgrade data needs to be defined and loaded.
- **Decision:** Use Godot's Resource system for all game data definitions.
- **Consequences:**
  - (+) Type-safe, editor-friendly
  - (+) Serializable out of the box
  - (+) Can be created programmatically or in the editor
  - (-) Resource format is Godot-specific (not portable JSON)
  - (-) For data import, may need JSON → Resource conversion layer

---

## ADR-006: 2D Top-Down Rendering

- **Status:** Accepted
- **Date:** 2026-03-07
- **Context:** The tabletop game is played on a flat surface. Need to decide between 2D and 3D rendering.
- **Decision:** Use 2D top-down rendering, faithful to the tabletop perspective.
- **Consequences:**
  - (+) Simpler to implement, faster development
  - (+) Natural match for the tabletop game's viewing angle
  - (+) Better performance, lower complexity
  - (-) Less visually cinematic than a 3D approach
  - (-) May limit future visual enhancements

---

## ADR-007: Network Multiplayer Architecture from Start

- **Status:** Accepted
- **Date:** 2026-03-07
- **Context:** The game needs multiplayer support. Building networking later often requires major refactors.
- **Decision:** Design the architecture with network multiplayer in mind from day one. Use authoritative server model with client-server separation.
- **Consequences:**
  - (+) Avoids costly refactoring later
  - (+) Cleaner state management (everything must be serializable)
  - (+) Enables both local and remote play with same code paths
  - (-) More upfront architecture complexity
  - (-) Slower initial development for single-player scenarios

---

## ADR-008: Initial Scope — Rebels and Empire

- **Status:** Accepted
- **Date:** 2026-03-07
- **Context:** The game has 4 factions. Need to scope the initial implementation.
- **Decision:** Start with Rebel Alliance and Galactic Empire (core box factions). Republic and Separatists added later.
- **Consequences:**
  - (+) Smaller scope, faster iteration
  - (+) Core box has the most established rules and reference material
  - (-) Must ensure architecture supports easy faction addition later

---

## ADR-009: Centralised Hover Tooltip System

- **Status:** Proposed
- **Date:** 2026-03-18
- **Context:** Multiple UI locations need contextual help text (hover hints on ship cards, dial stacks, defense tokens; drag help label; discard-mode prompt; duplicate toast). These were implemented as separate, ad-hoc Labels with duplicated styling code.
- **Decision:** Introduce a single `TooltipManager` autoload singleton that owns a shared `TooltipPanel` on a dedicated `CanvasLayer` (layer 100). Interactive regions register via `register(control, callback)` for hover tooltips; non-hover help text uses `show_text()` / `hide()`. A global toggle button in the lower-right corner lets players disable optional hover hints while preserving essential gameplay instructions. All styling and behavioural parameters are loaded from `scale_config.json`.
- **Consequences:**
  - (+) One consistent tooltip style across the entire application
  - (+) Context-sensitive text via callbacks; no stale strings
  - (+) Configurable and data-driven (delay, offset, colours, toggle)
  - (+) Core layout logic (`TooltipLayout` RefCounted) is unit-testable without scene tree
  - (+) Existing drag help, discard prompt, and duplicate toast are migrated, removing duplicated code
  - (-) New autoload singleton adds to the global namespace
  - (-) Migration of existing help text requires careful regression testing
  - (-) Toggle state persistence adds a dependency on `user://settings.cfg`

---

## ADR-010: Two-Phase Modal Button for Ship Activation

- **Status:** Accepted
- **Date:** 2026-07-12
- **Context:** Phase 5b needed a way to let the player (a) open the maneuver tool from the activation modal and (b) commit the result back. A single-press "Execute Maneuver" button at the bottom of the viewport felt disconnected from the modal. The player also had to manually press "End Activation" after each ship.
- **Decision:** Embed a two-phase button inside the Activation Modal panel. Phase 1 ("Execute Maneuver ►") closes the modal and attaches the maneuver tool to the ship. Phase 2 ("Commit Maneuver ►") commits the final position and auto-ends the activation. No separate "End Activation" button is needed.
- **Consequences:**
  - (+) Single UI location for the entire activation flow — no wandering buttons
  - (+) Auto-end reduces clicks per activation by 1
  - (+) Modal can be dismissed and reopened freely (state preserved)
  - (+) Consistent centred-panel style with CommandDialPicker
  - (-) Two label states on one button require clear visual feedback
  - (-) Dismissibility means the player must know to reopen the modal to commit

---

## ADR-012: Command Pattern for All Game-State Mutations

- **Status:** Accepted
- **Date:** 2026-04-12
- **Context:** The game requires multiplayer support (ADR-007) and replay functionality. Without a single mutation pathway, game state changes are scattered across 40+ call sites in presentation-layer code, making them impossible to serialize, replay, or transmit over the network. 34 violations of the mutation rule (§4.6) were identified across 8 files.
- **Decision:** Introduce `GameCommand` (RefCounted base class) with `validate()`, `execute()`, and `serialize()`/`deserialize()`. All game-state mutations route through `CommandProcessor.submit()`, which validates, assigns a sequence number, executes, records in history, and emits `command_executed`. Presentation-layer code pre-computes parameters (dice pools, damage card data, positions) and submits commands; it never directly mutates `GameState`-owned objects. 26 concrete command classes cover all mutation paths. A deterministic `GameRng` and `GameReplay` complete the replay pipeline.
- **Consequences:**
  - (+) Full game history is serializable — enables replay, save/load, and network transport
  - (+) Deterministic replay with seeded RNG — identical command sequences produce identical states
  - (+) Clear separation: presentation gathers intent, command applies mutation
  - (+) Validation layer catches illegal actions before state is modified
  - (+) Incremental adoption — commands added in 7 priority phases (P1–P7) without breaking existing gameplay
  - (-) More boilerplate per mutation (command class + submit method + test)
  - (-) Presentation must pre-compute all parameters before submitting (e.g., pre-draw damage cards)
  - (-) EventBus signals emitted by callers after `execute()` returns, not inside the command — requires discipline

---

## ADR-011: Deferred Layout Reset for Reusable Anchor-Based Panels

- **Status:** Accepted
- **Date:** 2026-03-29
- **Context:** Modal panels (AttackSimPanel, ActivationModal) are positioned at bottom-centre via `PRESET_CENTER_BOTTOM` and reused across multiple ship activations. On reuse, three interacting Godot layout behaviours caused panels to either retain stale heights (648 px vs expected 120 px), drift off-screen (offsets accumulating ~388 px per cycle), or fail to shrink because hidden children still contribute to min-size during synchronous `add_child()`. The deferred layout pass that corrects hidden-child inflation fires only on first visibility — not on reuse.
- **Decision:** Adopt a mandatory four-step reset pattern: (1) `remove_child()` before `queue_free()` in clear methods, (2) `size.y = 0` to clear stale height (**not** `size = Vector2.ZERO` — zeroing width causes horizontal drift when content exceeds `custom_minimum_size.x`), (3) immediate vertical offset re-pin to canonical values (`-40.0`), (4) `call_deferred("_deferred_layout_reset")` after setting `visible = true` to force a next-frame layout correction. Document as `.skills/ui_styling.md` § 10.
- **Consequences:**
  - (+) Panels reliably reset to correct size on every reuse
  - (+) Bottom-centre positioning is maintained regardless of activation history
  - (+) Pattern is self-contained — no changes needed to callers or game board
  - (+) Documented as a reusable pattern for all future anchor-based modals
  - (-) One-frame visual flash: panel appears at inflated size for one frame before deferred correction
  - (-) Developers must remember to call `_request_deferred_layout()` in every `show_*()` method
  - (-) Pattern relies on understanding Godot's anchor/offset bidirectional recalculation — documented to mitigate

---

## ADR-013: Contract-First Setup UI

- **Status:** Accepted
- **Date:** 2026-06-02
- **Context:** Setup-phase work spans lobby, hot-seat, network, initiative,
  objective choice, obstacle placement, and deployment. Recent implementation
  drift showed that technically working UI can still violate the intended player
  workflow when the screen order and ownership rules are not contracted first.
- **Decision:** All setup-phase UI implementation is gated by
  `docs/setup_flow.md`. The affected section must be complete and accepted
  before editing setup UI or presentation wiring. The contract must specify
  trigger, controller, visibility, required on-screen information, actions,
  serialized state/command payloads, validation, transitions, and tests.
- **Consequences:**
  - (+) The user/designer is explicitly involved before setup UI decisions are
    encoded in code.
  - (+) Hot-seat and network ownership are described before implementation,
    reducing rework and mode-specific regressions.
  - (+) Tests and manual checks are derived from a stable user-facing contract.
  - (-) Small setup UI changes may require a documentation update before code.
  - (-) Draft contract sections intentionally block implementation until the
    missing design decisions are resolved.
