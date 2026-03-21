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
