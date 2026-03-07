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
