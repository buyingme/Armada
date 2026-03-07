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
