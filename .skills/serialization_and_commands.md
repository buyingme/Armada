````markdown
# Serialization & Command Patterns — Armada Project

> **Authority:** This is the single source of truth for how game state is
> serialized and how player actions flow through the command system.
> Every code-generating agent **must** follow these patterns.

---

## 1. Golden Rule — State That Changes Must Serialize

**If a class holds mutable game state, it MUST implement
`serialize() -> Dictionary` and `static deserialize(data) -> Self`.**

Before adding a field to any class in `src/core/` or `src/models/`:

1. Ask: *"Would this field need to survive a save/load cycle or replay?"*
2. If **yes** → add the field to both `serialize()` and `deserialize()`.
3. If **no** (transient UI cache, etc.) → document with `## Transient — not serialized.`

**Enforcement:** Never merge a class that stores game state without both methods.
If you are extending an existing class with a new field, update its
`serialize()` and `deserialize()` in the **same edit**.

### Classes That Must Be Serializable

| Class | Location | Status |
|-------|----------|--------|
| `GameState` | `src/core/game_state.gd` | ✅ |
| `PlayerState` | `src/core/player_state.gd` | ✅ |
| `ShipInstance` | `src/core/ship_instance.gd` | ✅ |
| `SquadronInstance` | `src/core/squadron_instance.gd` | ✅ |
| `DamageDeck` | `src/core/damage_deck.gd` | ✅ |
| `DamageCard` | `src/core/damage_card.gd` | ✅ |
| `ShipActivationState` | `src/core/ship_activation_state.gd` | ✅ |
| `CommandDialStack` | `src/core/command_dial_stack.gd` | ✅ |
| `CommandTokenManager` | `src/core/command_token_manager.gd` | ✅ |
| `GameRng` | `src/core/game_rng.gd` | ✅ |
| `InteractionFlow` (Phase I) | `src/core/state/interaction_flow.gd` | ✅ — see `docs/implementation_plan.md` §3 |
| `FleetRoster` | `src/core/fleet/fleet_roster.gd` | ✅ |
| `FleetShipEntry` | `src/core/fleet/fleet_ship_entry.gd` | ✅ |
| `FleetSquadronEntry` | `src/core/fleet/fleet_squadron_entry.gd` | ✅ |
| `FleetUpgradeAssignment` | `src/core/fleet/fleet_upgrade_assignment.gd` | ✅ |
| `FleetObjectiveSelection` | `src/core/fleet/fleet_objective_selection.gd` | ✅ |
| `FleetValidationResult` | `src/core/fleet/fleet_validation_result.gd` | ✅ |

Any **new** class added to `src/core/` or `src/models/` that holds mutable
state must be added to this table.

---

## 2. Serialization Contract

### 2.1 Method Signatures

```gdscript
## Serializes this object to a JSON-safe Dictionary.
func serialize() -> Dictionary:

## Reconstructs the object from a serialized Dictionary.
## [param data] — Dictionary produced by [method serialize].
## Static data (e.g. ShipData resource) is passed separately.
static func deserialize(data: Dictionary, ...) -> Self:
```

### 2.2 Mandatory Rules

| Rule | Rationale |
|------|-----------|
| Every mutable field appears in both `serialize()` and `deserialize()` | Round-trip integrity |
| `deserialize()` uses `.get(key, default)` — never bare `data[key]` | Forward-compatible with older saves |
| Enum values are stored as `int()`, cast back with `as Constants.EnumType` | JSON has no enum type |
| Nested serializable objects call their own `serialize()`/`deserialize()` | Recursive composition |
| Static reference data (e.g. `ShipData`) is identified by `data_key` string, not serialized inline | Keeps payloads small; the loader resolves keys to resources |
| Arrays of serializable objects map each element through `serialize()`/`deserialize()` | Preserves order and type |
| No `Vector2`, `Color`, or other Godot types in serialized dicts — use plain floats/ints | JSON portability |

### 2.3 Template — Adding a Field to an Existing Serializable Class

When adding `my_new_field: int` to `ShipInstance`:

```gdscript
# 1. Declare the field
var my_new_field: int = 0

# 2. Add to serialize()
func serialize() -> Dictionary:
    return {
        # ... existing keys ...
        "my_new_field": my_new_field,
    }

# 3. Add to deserialize() — always with a safe default
static func deserialize(data: Dictionary, ...) -> ShipInstance:
    inst.my_new_field = int(data.get("my_new_field", 0))
```

**Forgetting step 2 or 3 is a bug.** Tests must cover the round-trip.

### 2.4 Template — New Serializable Class

```gdscript
class_name MyNewState
extends RefCounted

var value_a: int = 0
var value_b: String = ""

func serialize() -> Dictionary:
    return {
        "value_a": value_a,
        "value_b": value_b,
    }

static func deserialize(data: Dictionary) -> MyNewState:
    var inst := MyNewState.new()
    inst.value_a = int(data.get("value_a", 0))
    inst.value_b = data.get("value_b", "") as String
    return inst
```

---

## 3. Normalised Position Pattern

All spatial data on game tokens uses **normalised coordinates**:

| Field | Type | Range | Meaning |
|-------|------|-------|---------|
| `pos_x` | `float` | 0.0 – 1.0 | Horizontal position (0 = left edge, 1 = right edge) |
| `pos_y` | `float` | 0.0 – 1.0 | Vertical position (0 = top edge, 1 = bottom edge) |
| `rotation_deg` | `float` | degrees | Rotation (0 = facing up / −Y, 180 = facing down / +Y) |

This pattern is used consistently in:
- **Scenario JSON** (`learning_scenario.json` → `tokens[].pos_x`, `.pos_y`, `.rotation_deg`)
- **TokenPlacement** (`src/models/token_placement.gd`)
- **ShipInstance** (`src/core/ship_instance.gd`)
- **SquadronInstance** (`src/core/squadron_instance.gd`)
- **Command payloads** (`execute_maneuver`, `move_squadron`)

### 3.1 Why Normalised?

- **Board-size independent** — the same 0.0–1.0 values work on a 3′×3′ learning
  board and a 6′×3′ standard board.
- **JSON-safe** — plain floats, no Godot types.
- **Human-readable** — `0.5, 0.5` is obviously centre.

### 3.2 Converting to Pixels

Pixel conversion always uses `play_area_size: Vector2` (width × height):

```gdscript
func get_pixel_position(play_area_size: Vector2) -> Vector2:
    return Vector2(pos_x, pos_y) * play_area_size
```

`GameScale.play_area_size_px` provides the authoritative `Vector2`.
Never use a single `float` for pixel conversion — that assumes a square board.

### 3.3 Converting from Pixels to Normalised

When saving positions back to normalised form (e.g. `ScenarioSaver`):

```gdscript
var norm_x: float = pixel_pos.x / play_area_size.x
var norm_y: float = pixel_pos.y / play_area_size.y
```

Divide X by width, Y by height — **never by a single side length**.

### 3.4 Banned Position Patterns

- ❌ Storing pixel positions in serialized data
- ❌ Using `Vector2` directly in JSON dictionaries
- ❌ Dividing by `play_area_side_px` (single float) for normalisation
- ❌ Multiplying by `play_area_side_px` (single float) for de-normalisation
- ❌ Hardcoding board pixel dimensions in commands or models

---

## 4. Command System

### 4.1 Architecture

```
UI → creates GameCommand subclass → CommandProcessor.submit()
                                        ├─ validate(game_state) → reject or continue
                                        ├─ assign sequence number
                                        ├─ execute(game_state) → result Dict
                                        ├─ record in history
                                        └─ emit command_executed signal → UI reacts
```

**Every game-state mutation flows through a command.** No direct writes to
`GameState` from UI or scene code.

### 4.2 Command Contract

Every command subclass **must** provide:

| Method | Signature | Purpose |
|--------|-----------|---------|
| `register()` | `static func register() -> void` | Registers factory in `GameCommand._registry` |
| `_init()` | `func _init(p_player, p_payload) -> void` | Calls `super._init(player, TYPE_STRING, payload)` |
| `validate()` | `func validate(game_state: GameState) -> String` | Returns `""` if legal, error message if not |
| `execute()` | `func execute(game_state: GameState) -> Dictionary` | Mutates game_state, returns result dict |

Inherited from `GameCommand` (do NOT re-implement):

| Method | Purpose |
|--------|---------|
| `serialize()` | Produces `{"type", "player", "sequence", "payload"}` |
| `deserialize()` | Dispatches to correct subclass via `_registry` |
| `describe()` | Human-readable log string |

### 4.3 Command Template

```gdscript
## ShortDescription
##
## [Brief description of what this command does.]
## Rules Reference: "[Section]", [detail], p.[N]
class_name MyNewCommand
extends GameCommand


## Registers this command type with the GameCommand factory.
static func register() -> void:
    GameCommand.register_type("my_command_type", func(player: int,
            pl: Dictionary) -> GameCommand:
        return MyNewCommand.new(player, pl))


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
    super._init(p_player, "my_command_type", p_payload)


## Payload keys: key_a (int), key_b (String), ...


## Validates the command against the current game state.
func validate(game_state: GameState) -> String:
    var base: String = super.validate(game_state)
    if base != "":
        return base
    # Phase check
    if game_state.current_phase != Constants.GamePhase.EXPECTED:
        return "Not in expected phase."
    # Entity existence
    if not payload.has("required_key"):
        return "Missing required_key."
    return ""


## Executes the command, mutating game_state.
func execute(game_state: GameState) -> Dictionary:
    # Read payload
    var key_a: int = int(payload.get("key_a", 0))
    # Mutate state
    # ...
    # Return result
    return {"key_a": key_a, "success": true}
```

### 4.4 Command Registration

Every new command **must** be registered in `CommandProcessor._ready()`:

```gdscript
func _ready() -> void:
    # ... existing registrations ...
    MyNewCommand.register()
```

Forgetting this step causes `GameCommand.deserialize()` to return `null`
for the command type, silently breaking replay.

### 4.5 Command Payload Rules

| Rule | Example |
|------|---------|
| Payloads are plain `Dictionary` — JSON-safe types only | `{"ship_index": 0, "pos_x": 0.5}` |
| Use primitives: `int`, `float`, `String`, `bool`, `Array`, `Dictionary` | Never `Vector2`, `Resource`, `Node` |
| Identify entities by index, not by reference | `"ship_index": 2`, not a ShipInstance pointer |
| Position data uses normalised `pos_x`/`pos_y`/`rotation_deg` | See §3 |
| Enum values stored as `int` | `"phase": int(Constants.GamePhase.SHIP)` |
| Validate all required keys in `validate()` | `if not payload.has("key"): return "Missing key."` |

### 4.6 State Mutation Rules

Commands are the **only** sanctioned way to mutate `GameState` during gameplay:

- ❌ Scene code writing directly to `ShipInstance.current_hull`
- ❌ UI code modifying `GameState.current_phase`
- ❌ Any code path that changes game state outside `execute()`
- ✅ `execute()` method on a `GameCommand` subclass
- ✅ `GameManager` phase transitions (these will become commands too)

If you need to change game state, **write a command**. If a command for the
action does not exist yet, create one following the template in §4.3.

### 4.7 Commands and Position Data

When a command produces a new position (movement, deployment, etc.):

1. The command payload carries `pos_x`, `pos_y`, `rotation_deg` (normalised).
2. `validate()` checks `payload.has("pos_x")` and `payload.has("pos_y")`.
3. `execute()` writes the normalised values to the model instance:
   ```gdscript
   ship.pos_x = float(payload.get("pos_x", 0.0))
   ship.pos_y = float(payload.get("pos_y", 0.0))
   ship.rotation_deg = float(payload.get("rotation_deg", 0.0))
   ```
4. The presentation layer converts to pixels using `get_pixel_position(GameScale.play_area_size_px)`.

**Never store pixel positions in command payloads.** They are board-size
dependent and would break replay on different display configurations.

### 4.8 Post-Execute Signal Contract

Commands only mutate `GameState` — they do **not** emit EventBus signals.
The **presentation-layer caller** is responsible for emitting every signal
that the UI needs after `execute()` returns.

When a command deals damage, the caller must emit **all** of:

| Signal | Purpose | Listener |
|--------|---------|----------|
| `damage_card_dealt` | Refresh ship card panel facedown/faceup indicators | `ShipCardPanel` |
| `ship_hull_changed` | Update hull label on ship token | `ShipToken` |
| `ship_damaged` | Trigger damage animation / SFX | `SfxManager` |
| `ship_destroyed` + `_fade_out_destroyed_token()` | Remove token from board | `GameBoard` |

Omitting any signal causes a presentation desync (e.g. facedown card not
visible until the panel is manually re-opened, or ship staying on the board
at 0 hull).

**Checklist after writing a command caller:**

1. Did I emit `damage_card_dealt` for each card added?
2. Did I emit `ship_hull_changed` with the new hull value?
3. Did I check `result.get("destroyed", false)` and emit `ship_destroyed`?
4. Did I call the fade-out visual for destroyed tokens?

If a command can be called from **multiple** presentation sites
(e.g. `game_board.gd` and `maneuver_tool_scene.gd`), centralise the
post-execute signal logic in **one** place (typically `game_board.gd`) and
inject it as a `Callable` into the other site — see §4.9.

### 4.9 Callable Injection for Cross-Scene Command Callers

When a child scene (e.g. `ManeuverToolScene`) needs to trigger a command
that requires signals only the parent (`GameBoard`) can emit properly
(because it owns the token references, fade-out helpers, etc.), inject
the parent's handler as a `Callable`:

```gdscript
# Parent (game_board.gd) — owns the canonical handler:
func _submit_persistent_damage(ship: ShipInstance, eff_id: String) -> void:
    # ... submit command, emit ALL signals, handle destruction ...

# Pass it when creating the child:
maneuver_tool.set_activation_mode(state, _submit_persistent_damage)

# Child (maneuver_tool_scene.gd) — stores and calls:
var _persistent_damage_handler: Callable

func _on_speed_change_hook_triggered(ship: ShipInstance, eff_id: String) -> void:
    if _persistent_damage_handler.is_valid():
        _persistent_damage_handler.call(ship, eff_id)
```

This keeps the child focused on interaction logic while the parent retains
single responsibility for damage/destruction signalling.

❌ **Never** duplicate the signal-emitting helper in multiple scenes.
❌ **Never** have a child scene emit `ship_destroyed` directly — it lacks
   the `ShipToken` reference needed for the fade-out.

### 4.10 Interaction Flow and Command Applicability Contract

`GameState.interaction_flow` is the only production source of step-by-step UI
flow state. The old `NetworkInteractionState` side channel is retired; network
peers rebuild UI from filtered `GameState` snapshots and `command_result`.

When adding or changing a gameplay command:

1. Update `CommandApplicability` for the command's coarse scope.
2. If the command is flow-step scoped, update the matching
    `FlowSpec.allowed_commands` row.
3. Keep the concrete command `validate()` phase/step checks in agreement with
    the preflight declaration.
4. Add tests for both preflight applicability and concrete validation.

Lifecycle marker commands must be legal in every phase or flow that can submit
them. For example, `complete_squadron_activation` is valid in both SHIP and
SQUADRON phases because ship Squadron-command activations and Squadron Phase
activations can both end without a movement command.

Preview state is not committed state. Selection changes, range overlays, and
candidate placements may live in UI/controller fields, but they must not spend
command budget, activation slots, tokens, RNG, or serialized state. Commit only
when a real `GameCommand` records a move, attack, reroll, choice, or explicit
lifecycle marker. Never use a zero-distance movement command as a sync marker
for "no movement happened".

Rejected command submissions must stop local scene-side effects. If
`CommandProcessor.submit()` returns a failed result, do not advance modals,
consume local budget, clear overlays as if success occurred, or emit success
signals.

Hidden dial contents must never be present in opponent-facing payloads. Add
negative tests for leakage in snapshots, command result payloads, and UI event
payload dictionaries.

---

## 5. Replay System

### 5.1 Architecture

```
CommandProcessor._history  →  serialize_history()  →  GameReplay
                                                          ├─ header (metadata)
                                                          └─ commands (Array[Dictionary])
                                                               ├─ save_to_file() → JSON
                                                               └─ load_from_file() → GameReplay
                                                                     └─ replay_commands() → re-submit
```

Replay depends on **deterministic execution**: same seed + same command
sequence = identical game state. This is why:

- `GameRng` is seeded and serialized (see `game_rng.gd`).
- Commands carry all information needed to reproduce the action.
- No randomness occurs outside `GameRng`.
- No side channel data (pixel positions, UI state) leaks into game logic.

### 5.1.1 Phase L0.5 Replay Baseline Gate

`scripts/run_baseline_traces.sh --all` is the local replay gate for
Phase L/M and any replay, modal-lifecycle, command-submission, or network-flow
change.

- Hot-seat is deterministic: `BaselineTrace` JSONL and the final-state hash
    must match committed fixtures under `tests/fixtures/baseline_traces/`.
- Network uses a real two-process ENet host/client replay.  Per-command JSONL
    and full final-state hashes are not stable across separate process runs
    because packet timing can choose different valid command interleavings.  The
    gate therefore checks the stable invariant available today: host and client
    must end the same run with identical canonical `GameState.serialize()` hashes.
- Do not create committed network command-trace or network state-hash fixtures
    until the network command pump is deterministic across separate runs.
- During `ReplayDriver` sessions, live auto `submit_publish_attack_flow()`
    calls are suppressed because the replay file already contains the captured
    `PublishAttackFlowCommand` entries; the replay file is the single command
    source for the harness.

### 5.2 Replay-Safe Checklist

When adding a new feature, verify:

| Check | Question |
|-------|----------|
| Command exists | Does the feature mutate state? → Must go through a command |
| Payload is complete | Does the command payload contain everything needed to replay the action without UI? |
| No hidden state | Does `execute()` read anything beyond `game_state` + `payload`? It must not |
| RNG usage | Does the feature use randomness? → Must use `game_state.rng`, never `randf()`/`randi()` |
| Position format | Does the command carry positions? → Must be `pos_x`/`pos_y`/`rotation_deg` (normalised) |

---

## 6. Scenario Data

Scenarios define initial board state in JSON:

```json
{
    "scenario_name": "Learning Scenario",
    "map_image": "map_3x3_distant_planet_v3.jpg",
    "tokens": [
        {
            "key": "victory_ii_class_star_destroyer",
            "type": "ship",
            "pos_x": 0.489,
            "pos_y": 0.123,
            "rotation_deg": 180.0
        }
    ]
}
```

### 6.1 Scenario JSON Rules

| Rule | Detail |
|------|--------|
| Positions are normalised (`pos_x`, `pos_y`: 0.0–1.0) | Board-size independent |
| Rotation is in degrees (`rotation_deg`) | 0 = up, 180 = down |
| Tokens identified by `key` (matches `data_key` in ship/squadron JSON) | Never by display name |
| `type` is `"ship"` or `"squadron"` | Used to dispatch to correct loader |
| No pixel values in scenario files | Pixels are presentation-layer only |

### 6.2 Loading Flow

```
scenario JSON → AssetLoader.load_json()
    → parse tokens[] → TokenPlacement objects
        → ShipInstance / SquadronInstance (pos_x, pos_y, rotation_deg copied)
            → ShipToken / SquadronToken (get_pixel_position(GameScale.play_area_size_px))
```

---

## 7. Testing Serialization

### 7.1 Round-Trip Tests Are Mandatory

Every serializable class **must** have a round-trip test:

```gdscript
func test_serialize_deserialize_round_trip() -> void:
    # Arrange
    var original := MyClass.new()
    original.field_a = 42
    original.field_b = "hello"

    # Act
    var data: Dictionary = original.serialize()
    var restored := MyClass.deserialize(data)

    # Assert
    assert_eq(restored.field_a, 42, "field_a survives round-trip")
    assert_eq(restored.field_b, "hello", "field_b survives round-trip")
```

### 7.2 Command Tests Are Mandatory

Every command **must** have tests covering:

| Test | Pattern |
|------|---------|
| Validation passes for valid input | `assert_eq(cmd.validate(state), "")` |
| Validation rejects invalid input | `assert_ne(cmd.validate(state), "")` |
| Execute produces correct result | `var result := cmd.execute(state); assert_eq(...)` |
| Execute mutates state correctly | Check model fields after execute |
| Serialize/deserialize round-trip | `GameCommand.deserialize(cmd.serialize())` preserves type + payload |
| Position written to model (for movement commands) | `assert_eq(instance.pos_x, expected)` after execute |

### 7.3 Position Tests Must Use Asymmetric Board Size

To catch square-board assumptions, always test `get_pixel_position()` with
a non-square `Vector2`:

```gdscript
# GOOD — catches width==height bugs
var px: Vector2 = instance.get_pixel_position(Vector2(1000.0, 800.0))
assert_eq(px.x, 500.0, "X uses width")   # 0.5 * 1000
assert_eq(px.y, 200.0, "Y uses height")  # 0.25 * 800

# BAD — passes even if X and Y are swapped
var px: Vector2 = instance.get_pixel_position(Vector2(1000.0, 1000.0))
```

---

## 8. Banned Patterns — Serialization & Commands

These will be flagged during code review. Never generate code that does any
of these:

| Banned Pattern | Why | Correct Alternative |
|---------------|-----|---------------------|
| ❌ Mutable game-state field without `serialize()`/`deserialize()` | Breaks save/load and replay | Add to both methods in the same edit |
| ❌ `data["key"]` without `.get()` default in `deserialize()` | Crashes on older save files | `data.get("key", default)` |
| ❌ `Vector2` / `Color` in serialized dictionaries | Not JSON-safe | Use separate float keys (`pos_x`, `pos_y`) |
| ❌ Pixel values in command payloads or serialized state | Board-size dependent, breaks replay portability | Use normalised 0.0–1.0 coordinates |
| ❌ Entity references (Node, Resource, RefCounted) in payloads | Not serializable | Use index (`ship_index`) or key (`data_key`) |
| ❌ Mutating `GameState` outside a `GameCommand.execute()` | Breaks replay determinism | Write a command |
| ❌ Using `randf()` / `randi()` for game logic | Non-deterministic, breaks replay | Use `game_state.rng` |
| ❌ `play_area_side_px` (float) in `get_pixel_position()` | Assumes square board | Use `play_area_size_px` (Vector2) |
| ❌ Command without `register()` call in `CommandProcessor._ready()` | Breaks deserialization and replay | Add registration in `_ready()` |
| ❌ Command without `validate()` checking required payload keys | Silent failures on bad data | Check every required key with `payload.has()` |
| ❌ New serializable class without round-trip test | No proof the contract works | Write the test alongside the class |

---

## 9. Quick Reference — Data Flow

```
          ┌─────────────────────────────────────────────────┐
          │                 JSON / Save File                 │
          │  (normalised pos_x/pos_y, rotation_deg, ints)   │
          └────────────────┬──────────────┬─────────────────┘
                 load ↓                    ↑ save
          ┌────────────────┴──────────────┴─────────────────┐
          │            Domain Model (RefCounted)             │
          │  ShipInstance, SquadronInstance, GameState, etc.  │
          │  Fields: pos_x, pos_y, rotation_deg (normalised) │
          │  serialize() ↔ deserialize()                     │
          └────────────────┬──────────────┬─────────────────┘
           execute() ↑     │              │ get_pixel_position()
          ┌──────────┴─────┘              ↓
          │    GameCommand                Presentation Layer
          │    (payload: Dictionary)      (pixels via
          │    pos_x/pos_y normalised     GameScale.
          │    entity refs by index       play_area_size_px)
          └──────────────────────────────────────────────────
                      ↕
          ┌──────────────────────────────────────────────────┐
          │              CommandProcessor                     │
          │  validate → sequence → execute → record → emit   │
          └──────────────────────────────────────────────────┘
                      ↕
          ┌──────────────────────────────────────────────────┐
          │              GameReplay                           │
          │  header + Array[Dictionary] of serialized cmds   │
          │  save_to_file() / load_from_file() → JSON        │
          └──────────────────────────────────────────────────┘
```

---

*This file is referenced by `.github/copilot-instructions.md` and
`.skills/copilot_instructions.md`. Update this file when serialization
patterns change.*

````
