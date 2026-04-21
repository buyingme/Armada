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

### 5. Network UI Authority Pattern (G4.6.6+)

For multiplayer interaction windows, use this pattern:

- **Visibility state**: what both peers can see.
- **Authority state**: who can act (`controller_player`).

These must be represented separately and updated from authoritative
network state, never inferred from local modal state.

Rules:
- Common modal visibility may exist on both clients with disabled controls.
- Non-controller input handlers must fail fast and return without side effects.
- Step transitions are driven by network interaction state + command results,
  not by local UI events alone.
```

## Required Patterns

### Autoload Singletons

| Singleton | Responsibility | File |
|-----------|---------------|------|
| `GameManager` | Game lifecycle, round/phase progression | `src/autoload/game_manager.gd` |
| `EventBus` | Central signal hub | `src/autoload/event_bus.gd` |
| `Constants` | Game-wide constants, enums, utility functions | `src/autoload/constants.gd` |
| `GameScale` | Pixel-to-game-unit scale, UI sizes from `scale_config.json` | `src/autoload/game_scale.gd` |
| `DebugMode` | Debug-mode toggle, editor-only features | `src/autoload/debug_mode.gd` |
| `AssetLoader` | Loads textures and JSON from `Resources/Game_Components/` | `src/utils/asset_loader.gd` (not autoload, but global utility) |

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

### Static Utility Pattern — Pure Computation

For stateless math/geometry/helper modules, use all-static methods on a `RefCounted` class:

```gdscript
## Geometry2DHelper
##
## Pure mathematical helpers — no state, no instantiation.
class_name Geometry2DHelper
extends RefCounted

## Returns minimum distance from [p] to segment [b1]–[b2].
static func distance_point_to_segment(p: Vector2, b1: Vector2, b2: Vector2) -> float:
	var closest := closest_point_on_segment(p, b1, b2)
	return p.distance_to(closest)
```

- All methods carry the `static` keyword
- Callers use `Geometry2DHelper.method()` — never `Geometry2DHelper.new().method()`
- Tests call the methods directly; no setup/teardown needed
- Never mix static and instance methods in the same utility class

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

### Single Source of Targeting Geometry

All distance, range, and arc measurements **must** go through the canonical
static methods in `RangeFinder` (or `EngagementResolver` for engagement).
No class may re-implement edge-to-edge distance, closest-point, or
arc-containment logic locally.

#### Canonical Method Table

| Measurement | Canonical Method | File |
|---|---|---|
| Squad → Ship hull-zone edge | `RangeFinder.measure_range_squad_to_ship()` | `range_finder.gd` |
| Squad → Squad | `RangeFinder.measure_range_squad_to_squad()` | `range_finder.gd` |
| Ship → Ship | `RangeFinder.measure_range_ship_to_ship()` | `range_finder.gd` |
| Hull-zone edge polyline | `RangeFinder.get_hull_zone_edge()` / `get_hull_zone_edge_from_arcs()` | `range_finder.gd` |
| Closest point on polyline | `RangeFinder.closest_point_on_polyline()` | `range_finder.gd` |
| Closest point on circle | `RangeFinder.closest_point_on_circle()` | `range_finder.gd` |
| Max attack range band | `RangeFinder.max_attack_range_band()` | `range_finder.gd` |
| Engagement (squad ↔ squad) | `EngagementResolver.is_engaged()` / `_edge_distance()` | `engagement_resolver.gd` |

#### Banned Targeting Patterns

- ❌ Raw `pos.distance_to(other) - radius` for edge-to-edge distance
- ❌ Manual `centre_dist - ship_half - squad_radius` approximations
- ❌ Local `closest_point_on_polyline` / `closest_point_on_segment` reimplementations
- ❌ New utility classes that duplicate `RangeFinder` API (e.g. `RangeMeasurer`, `FiringArc`)

When a new measurement type is needed, **add a method to `RangeFinder`**,
not a local helper.

---

## Anti-Patterns to Avoid

| Anti-Pattern | Why | Instead |
|-------------|-----|---------|
| God object | Single class with too many responsibilities | Split into focused classes |
| Direct node paths | Brittle, breaks with scene changes | Use signals or `%` unique names |
| Global mutable state | Hard to test, race conditions | Encapsulate state in GameState |
| Inheritance for variation | Ship/squadron variants via deep hierarchies | Composition + Resources |
| String-typed enums | Error-prone, no IDE support | Use `Constants` enums |
| Duplicated signal dispatch | Same EventBus signals emitted in multiple scenes → risk of omission | Centralise in one scene, inject as `Callable` (see `.skills/serialization_and_commands.md` §4.9) |

## Dependency Direction

```
UI/Scenes → Autoloads → Core Logic → Models
   ↓            ↓           ↓          ↓
  (view)    (services)   (domain)   (data)
```

Dependencies flow **downward only**. Lower layers never import from upper layers.
