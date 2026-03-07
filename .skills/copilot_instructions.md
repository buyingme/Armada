# AI Code Generation Instructions — Armada Project

## Context

This document provides instructions for AI assistants (GitHub Copilot, etc.) generating code for the Star Wars: Armada Digital Edition project.

**Always read and follow all documents in `.skills/` before generating code.**

## Project Summary

- **Engine:** Godot 4.5+ with GDScript
- **Type:** Turn-based tactical board game (digital adaptation of Star Wars: Armada)
- **Architecture:** Layered (Presentation → Application → Domain → Data)
- **Testing:** GUT framework, high coverage required
- **Documentation:** arc42 style

## Before Writing Code

1. **Understand the requirement** — Check the Rules Reference in `Resources/` if it concerns game rules.
2. **Check existing code** — Search `src/` for related classes and patterns.
3. **Check existing tests** — See `tests/` for testing patterns used in this project.
4. **Follow the architecture** — See `.skills/architecture_patterns.md`.

## When Writing GDScript

### Always Do

- Use **static typing** for ALL parameters, return types, and variables
- Add `## Doc comments` for every public class, method, signal, and export
- Use `Constants` enums — never raw strings or magic numbers for game concepts
- Use the `GameLogger` utility — never `print()`
- Follow the file ordering convention in `.skills/gdscript_style.md`
- Keep functions under 30 lines
- Use early returns to avoid deep nesting

### Code Template — New Class (RefCounted)

```gdscript
## [ClassName]
##
## [Brief description of what this class does.]
## [Additional context about usage and relationships.]
class_name [ClassName]
extends RefCounted


## [Description of the method.]
func method_name(param: Type) -> ReturnType:
    pass
```

### Code Template — New Scene Script

```gdscript
## [SceneName]
##
## [Brief description of this scene's purpose.]
extends [BaseType]


## Called when the node enters the scene tree.
func _ready() -> void:
    _connect_signals()
    _initialize()


## Connects EventBus and local signals.
func _connect_signals() -> void:
    EventBus.some_signal.connect(_on_some_signal)


## Initializes the scene state.
func _initialize() -> void:
    pass


## Handles the some_signal event.
func _on_some_signal() -> void:
    pass
```

### Code Template — New Resource

```gdscript
## [ResourceName]
##
## [Brief description of what data this resource holds.]
class_name [ResourceName]
extends Resource


@export var name: String = ""
@export var value: int = 0
```

## When Writing Tests

### Always Do

- Follow AAA pattern (Arrange → Act → Assert)
- Include descriptive assertion messages
- Name tests: `test_<method>_<scenario>_<expected>()`
- Group related tests with `# --- Section ---` comments
- Clean up in `after_each()`
- Use `TestFixtures` for reusable test data

### Test Template

```gdscript
## Test: [ClassName]
##
## Unit tests for [ClassName] — [brief description].
extends GutTest


func before_each() -> void:
    pass


func after_each() -> void:
    pass


# --- [Method/Feature Group] ---

func test_method_name_scenario_expected_result() -> void:
    # Arrange
    var input := ...

    # Act
    var result := ClassUnderTest.method(input)

    # Assert
    assert_eq(result, expected, "Description of what should happen")
```

## Game Rules Implementation

When implementing game rules:

1. **Cite the source** — Reference the Rules Reference section in comments:
   ```gdscript
   ## Resolves attack dice modification step.
   ## Rules Reference: "Attack", Step 3, Page 2
   func resolve_attack_effects(pool: Array[Dictionary]) -> Array[Dictionary]:
   ```

2. **One rule, one function** — Each distinct rule should be a testable function.

3. **Test against the rules** — Write tests that validate specific rule interactions from the Rules Reference.

## Communication Patterns

### Between Systems

```gdscript
# Use EventBus — never direct references between systems
EventBus.ship_destroyed.emit(ship)
```

### Within a System

```gdscript
# Direct method calls are fine within the same system
var damage := _calculate_total_damage(dice_results)
```

## Common Mistakes to Avoid

| Mistake | Correction |
|---------|-----------|
| Using `Node` for logic classes | Use `RefCounted` in `src/core/` |
| Forgetting type annotations | Add types to ALL declarations |
| Using `print()` for debugging | Use `GameLogger.debug()` |
| Hardcoding game values | Use `Constants` |
| Cross-system direct references | Use `EventBus` signals |
| Writing tests without assertion messages | Always add description parameter |
| Functions >30 lines | Split into smaller functions |
| Missing doc comments | Add `##` to all public API |
