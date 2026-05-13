# 2. Constraints

## 2.1 Technical Constraints

| Constraint | Description |
|------------|-------------|
| TC-1: Godot Engine 4.5+ | The game is built using the Godot Engine (version 4.5+) with GDScript as the primary language. |
| TC-2: GDScript | Primary development language. C# may be introduced later for performance-critical systems. |
| TC-3: GUT Testing Framework | Unit and integration tests use the GUT (Godot Unit Testing) addon. |
| TC-4: Desktop Target | Primary target platform is desktop (macOS, Windows, Linux). |
| TC-5: Git Version Control | Source code is managed with Git, hosted on GitHub. |

## 2.2 Organizational Constraints

| Constraint | Description |
|------------|-------------|
| OC-1: Solo Development | Primary development by a single developer with AI assistance. |
| OC-2: arc42 Documentation | Architecture documentation follows the arc42 template. |
| OC-3: Iterative Development | The project follows an iterative approach: requirements → architecture → implementation. |
| OC-4: Non-Commercial | This is a fan project for personal/educational use. Star Wars and Armada are trademarks of their respective owners. |

## 2.3 Conventions

| Convention | Description |
|------------|-------------|
| CV-1: GDScript Style | Follow the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html). |
| CV-2: Documentation | All public functions have doc comments (`##`). Useful docstrings are part of maintainability: they should explain contracts, invariants, rationale, source rules, and failure modes, and must not be removed merely to satisfy raw LOC targets. |
| CV-3: Signal-Based Communication | Prefer signals over direct references for cross-system communication. |
| CV-4: Resource Pattern | Game data (ships, squadrons, upgrades) is defined as Godot Resources. |
