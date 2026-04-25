# 4. Solution Strategy

## 4.1 Technology Decisions

| Decision | Rationale |
|----------|-----------|
| **Godot Engine 4.5** | Open-source, mature 2D/3D engine with built-in scene system, suitable for board game adaptations. |
| **GDScript** | Native Godot language with excellent editor integration, rapid prototyping, and sufficient performance for a turn-based game. |
| **GUT Framework** | Godot-native testing framework enabling unit and integration tests within the engine. |
| **Resource-based data** | Godot's Resource system for defining ship/squadron/upgrade data — serializable, editor-friendly, type-safe. |

## 4.2 Architecture Approach

### Layered Architecture

```
┌────────────────────────────────────┐
│         Presentation Layer         │  Scenes, UI, Visual Effects
├────────────────────────────────────┤
│         Application Layer          │  Game Manager, Phase Controller
├────────────────────────────────────┤
│          Domain Layer              │  Rules Engine, Game State, Models
├────────────────────────────────────┤
│        Infrastructure Layer        │  Save/Load, Data Import, Logging
└────────────────────────────────────┘
```

### Key Patterns

| Pattern | Usage |
|---------|-------|
| **Observer (Event Bus)** | Decoupled communication between game systems via a central signal bus. |
| **State Machine** | Game phase management (Command → Ship → Squadron → Status). |
| **Command Pattern** | Player actions (move, attack, use token) as serializable command objects. All game-state mutations route through `GameCommand.execute()` via the `CommandProcessor` autoload. Enables deterministic replay, undo (future), and network transport. 26 concrete command classes, 40+ wired call sites. |
| **Interaction-Flow as Domain State** (Phase I) | The current interactive UI step (which modal is open, who must act, what payload it needs) is a serializable field of `GameState` (`InteractionFlow`), not a transient client-side variable. Mutated only by `GameCommand.execute()`. Travels for free over `command_result`, replays deterministically, and is reconstructable from a single state snapshot on reconnect. Eliminates the need for a parallel UI-sync RPC channel. |
| **UI Projection** (Phase I) | A single pure function `UIProjector.project(state, local_player_index)` derives all modal/HUD/sidebar decisions from `GameState`. Hot-seat and network mode share one projection path; per-modal `if PlayMode.is_network()` branching is forbidden in presentation code. |
| **Resource Pattern** | Game data defined as Godot Resources, loaded from files. |
| **MVC-like Separation** | Models (data), Scenes (view), Scripts (controller logic) kept separate. |

## 4.3 Quality Strategy

| Quality Goal | Strategy |
|-------------|----------|
| Rules Fidelity | Test-driven development with rule-based test cases derived from the Rules Reference. |
| Testability | Pure-logic classes (no Node dependency) for core game rules; GUT tests for all layers. |
| Maintainability | Consistent code style, comprehensive documentation, modular architecture. |
| Extensibility | Data-driven design; new ships/upgrades added via Resource files without code changes. |

## 4.4 Development Approach

1. **Requirements Extraction** — Analyze Rules Reference and Learn to Play documents.
2. **Architecture Definition** — Define detailed component design and interfaces.
3. **Core Implementation** — Build rules engine and game state management with full test coverage.
4. **UI/Visual Layer** — Implement game board, ship rendering, and user interaction.
5. **Integration** — Connect all systems and validate with integration tests.
6. **Polish** — Visual effects, sound, UX improvements.

> **Note:** Detailed solution strategy will be refined during the architecture phase.
