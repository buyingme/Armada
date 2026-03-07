# Architecture Patterns — Armada Project

## Core Principles

### 1. Separation of Concerns

```
Presentation (Scenes/UI) ←→ Application (Managers) ←→ Domain (Core Logic) ←→ Data (Models)
```

- **Domain logic** (`src/core/`) must NOT depend on scene tree, UI, or Godot nodes
- **Presentation** depends on domain, never the reverse
- **Communication** between layers uses the EventBus or direct method calls downward only

### 2. Scene-Tree Independence for Core Logic

Classes in `src/core/` extend `RefCounted`, not `Node`:

```gdscript
# GOOD — testable without scene tree
class_name GameState
extends RefCounted

# BAD — requires scene tree to test
class_name GameState
extends Node
```

### 3. Event-Driven Communication

All cross-system communication goes through `EventBus`:

```gdscript
# GOOD — decoupled
EventBus.ship_damaged.emit(ship, damage, zone)

# BAD — tight coupling
get_node("/root/UI/HUD").update_damage(ship, damage)
```

### 4. Data-Driven Design

Game content is defined as Resources, not hardcoded:

```gdscript
# GOOD — data-driven
var ship_data: ShipData = load("res://data/ships/cr90_corvette.tres")

# BAD — hardcoded
var hull := 4
var shields := {"front": 2, "left": 1}
```

## Required Patterns

### Autoload Singletons

| Singleton | Responsibility | File |
|-----------|---------------|------|
| `GameManager` | Game lifecycle, round/phase progression | `src/autoload/game_manager.gd` |
| `EventBus` | Central signal hub | `src/autoload/event_bus.gd` |
| `Constants` | Game-wide constants, enums, utility functions | `src/autoload/constants.gd` |

### State Pattern — Game Phases

Game phase transitions follow a strict state machine:

```
SETUP → COMMAND → SHIP → SQUADRON → STATUS → COMMAND → ... (for 6 rounds)
```

Each phase should have clear entry/exit logic managed by `GameManager`.

### Command Pattern — Player Actions

Player actions (future implementation) should be modeled as command objects:

```gdscript
class_name MoveShipCommand
extends RefCounted

var ship: Node
var movement_path: Array

func execute() -> void: ...
func undo() -> void: ...
```

This enables:
- Action validation before execution
- Undo/redo support
- Action logging and replay
- Network synchronization (future)

### Resource Pattern — Game Data

All static game data uses Godot Resources:

```gdscript
class_name ShipData
extends Resource

@export var ship_name: String
@export var hull: int
@export var shields: Dictionary
```

### Observer Pattern — EventBus

The EventBus pattern decouples systems:

```gdscript
# Publisher (does not know about subscribers)
EventBus.ship_destroyed.emit(ship)

# Subscriber (connects during _ready)
func _ready() -> void:
    EventBus.ship_destroyed.connect(_on_ship_destroyed)

func _on_ship_destroyed(ship: Node) -> void:
    update_score(ship)
```

## Anti-Patterns to Avoid

| Anti-Pattern | Why | Instead |
|-------------|-----|---------|
| God object | Single class with too many responsibilities | Split into focused classes |
| Direct node paths | Brittle, breaks with scene changes | Use signals or `%` unique names |
| Global mutable state | Hard to test, race conditions | Encapsulate state in GameState |
| Inheritance for variation | Ship/squadron variants via deep hierarchies | Composition + Resources |
| String-typed enums | Error-prone, no IDE support | Use `Constants` enums |

## Dependency Direction

```
UI/Scenes → Autoloads → Core Logic → Models
   ↓            ↓           ↓          ↓
  (view)    (services)   (domain)   (data)
```

Dependencies flow **downward only**. Lower layers never import from upper layers.
