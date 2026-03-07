# GDScript Style Guide — Armada Project

## General Rules

- Follow the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- Use **tabs** for indentation (Godot default)
- Maximum line length: **100 characters** (soft limit)
- Use **static typing** for all function parameters, return types, and variable declarations
- Prefer **explicit types** over `Variant` wherever possible

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Files | `snake_case.gd` | `game_state.gd` |
| Classes | `PascalCase` | `GameState`, `ShipData` |
| Functions | `snake_case` | `calculate_damage()` |
| Variables | `snake_case` | `current_round` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_ROUNDS` |
| Enums | `PascalCase` (type), `UPPER_SNAKE_CASE` (values) | `enum ShipSize { SMALL, LARGE }` |
| Signals | `snake_case` (past tense for events) | `signal ship_destroyed` |
| Private members | `_prefixed_snake_case` | `func _calculate_internal()` |
| Node references | `snake_case` | `var health_bar: ProgressBar` |
| Export vars | `snake_case` | `@export var max_health: int` |

## Documentation Comments

Every public class, function, signal, and exported variable **must** have a doc comment using `##`:

```gdscript
## Calculates the total damage from a set of dice results.
## Returns the sum of all damage values, ignoring accuracy and blank faces.
static func calculate_damage(results: Array[Dictionary]) -> int:
```

### Class-level Documentation

Every script file must start with a doc comment block:

```gdscript
## Ship Data
##
## Resource that defines the static data for a ship type.
## Loaded from data files; instances are created from this template.
class_name ShipData
extends Resource
```

## Type Annotations

**Always** use type annotations:

```gdscript
# GOOD
var current_round: int = 0
var ships: Array[ShipData] = []
func get_damage(face: Constants.DiceFace) -> int:

# BAD
var current_round = 0
var ships = []
func get_damage(face):
```

## Signal Declarations

Signals include typed parameters when possible:

```gdscript
## Emitted when a ship takes damage.
signal ship_damaged(ship: Node, damage_amount: int, hull_zone: Constants.HullZone)
```

## Enum Usage

- Define game enums in `Constants` autoload
- Always use the fully qualified enum name: `Constants.HullZone.FRONT` (not just `FRONT`)
- Use `match` statements (not `if/elif`) for enum branching

## Error Handling

- Use `push_error()` for runtime errors that should be logged
- Use `push_warning()` for suspicious but non-fatal conditions
- Use `assert()` for programmer errors (debug-only checks)
- **Never** use bare `print()` — use the `GameLogger` utility

## Code Organization Within Files

Order within a script file:

1. Doc comment and class declaration
2. `extends` / `class_name`
3. Signals
4. Enums (if class-local)
5. Constants
6. `@export` variables
7. Public variables
8. Private variables (`_prefixed`)
9. `@onready` variables
10. Built-in callbacks (`_ready`, `_process`, etc.)
11. Public methods
12. Private methods (`_prefixed`)
13. Signal handler methods (`_on_<source>_<signal>`)

## Banned Patterns

- ❌ `print()` — use `GameLogger` instead
- ❌ Untyped function signatures
- ❌ Direct cross-system references — use `EventBus` signals
- ❌ Magic numbers — define in `Constants`
- ❌ Nested `if` deeper than 3 levels — refactor with early returns or helper functions
- ❌ Functions longer than 30 lines — split into smaller functions
