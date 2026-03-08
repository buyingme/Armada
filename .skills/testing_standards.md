# Testing Standards — Armada Project

## Framework

- **GUT** (Godot Unit Testing) v9.6.0
- Test runner: Godot editor panel or CLI (`scripts/quality_check.sh` runs all checks)
- All test files extend `GutTest`

## Test Organization

```
tests/
├── unit/                    # Unit tests — one-to-one with source files
│   ├── test_constants.gd
│   ├── test_dice.gd
│   ├── test_game_state.gd
│   └── ...
├── integration/             # Integration tests — multi-system flows
│   ├── test_game_flow.gd
│   ├── test_attack_sequence.gd
│   └── ...
└── fixtures/                # Shared test data and factories
    └── test_fixtures.gd
```

## Naming Conventions

### Test Files

- Prefix: `test_`
- Name matches the source file: `dice.gd` → `test_dice.gd`

### Test Functions

Pattern: `test_<method_or_behavior>_<scenario>_<expected_result>()`

```gdscript
# GOOD — clear what is tested, under what conditions, and what is expected
func test_get_face_damage_hit_returns_one() -> void:
func test_roll_pool_empty_returns_empty() -> void:
func test_advance_phase_from_status_starts_new_round() -> void:

# BAD — vague, no scenario, no expected result
func test_damage() -> void:
func test_it_works() -> void:
```

### Test Grouping

Group related tests within a file using comment headers:

```gdscript
# --- Roll Die ---

func test_roll_die_red_returns_valid_face() -> void:
    ...

# --- Damage Calculation ---

func test_calculate_damage_all_hits() -> void:
    ...
```

## Test Structure (AAA Pattern)

Every test follows **Arrange → Act → Assert**:

```gdscript
func test_calculate_damage_two_hits() -> void:
    # Arrange
    var results: Array[Dictionary] = [
        {"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
        {"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.HIT},
    ]

    # Act
    var damage := Dice.calculate_damage(results)

    # Assert
    assert_eq(damage, 2, "Two HITs should deal 2 total damage")
```

## Assertion Guidelines

- **Always include a description message** as the last parameter:
  ```gdscript
  assert_eq(result, 4, "Small ships should have max speed 4")
  ```
- Use the most specific assertion:
  | Need | Assertion |
  |------|-----------|
  | Equality | `assert_eq(a, b, msg)` |
  | Inequality | `assert_ne(a, b, msg)` |
  | Boolean true | `assert_true(expr, msg)` |
  | Boolean false | `assert_false(expr, msg)` |
  | Null check | `assert_null(obj, msg)` / `assert_not_null(obj, msg)` |
  | Contains | `assert_has(dict, key, msg)` |
  | Range | `assert_between(val, low, high, msg)` |
  | Signals | `assert_signal_emitted(obj, signal_name)` |  | Float (geometry) | `assert_almost_eq(a, b, delta, msg)` |

### Floating-Point Assertions

Always use `assert_almost_eq` for any value computed through floating-point math (distances, angles, pixel positions):

```gdscript
# GOOD — allows for floating-point rounding
assert_almost_eq(distance, 100.0, 0.01, "Ship-to-ship distance should be ~100 px")
assert_almost_eq(angle_deg, 45.0, 0.001, "Bearing should be 45 degrees")

# BAD — will fail intermittently due to float rounding
assert_eq(distance, 100.0, "Distance should be exactly 100")
```

For geometry tests, a tolerance of `0.01` px (sub-pixel) is appropriate. Use a tighter delta (`0.0001`) for pure angle/trig results.
## Coverage Targets

| Layer | Target | Rationale |
|-------|--------|-----------|
| `src/core/` | ≥80% | Critical game logic — must be thoroughly tested |
| `src/models/` | ≥70% | Data integrity, serialization |
| `src/autoload/` | ≥70% | Core services used everywhere |
| `src/ui/`, `src/scenes/` | ≥40% | UI-heavy code, harder to unit test |
| Integration | ≥60% | Cover key game flows end-to-end |

## Setup and Teardown

Use GUT's lifecycle hooks for consistent test state:

```gdscript
func before_each() -> void:
    # Reset state before every test
    ...

func after_each() -> void:
    # Clean up after every test
    ...

func before_all() -> void:
    # One-time setup for the test suite
    ...

func after_all() -> void:
    # One-time teardown for the test suite
    ...
```

## Test Doubles

GUT provides doubles (mocks/stubs). Use them for:
- Isolating the unit under test from dependencies
- Controlling inputs to the unit (e.g., fixed dice rolls)
- Verifying interactions (e.g., signals emitted, methods called)

```gdscript
# Example: stub a dice roll for deterministic testing
var dice_double = double(Dice).new()
stub(dice_double, "roll_die").to_return(Constants.DiceFace.HIT)
```

## Integration Test Guidelines

- Test **complete game flows** (e.g., full attack resolution, round progression)
- Connect to `EventBus` signals to verify system interactions
- **Always disconnect** signal handlers in `after_each()` to prevent leaks
- Use `TestFixtures` for consistent test data

## What to Test

| Always Test | Don't Test |
|-------------|------------|
| Game rules correctness | Godot engine internals |
| State transitions | UI layout/rendering |
| Serialization round-trips | Third-party addon behavior |
| Edge cases (0 shields, max speed) | Obvious getters/setters |
| Error handling paths | Configuration constants |

## Running Tests

```bash
# All tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs 2>&1 | tail -20

# Unit tests only
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Integration tests only
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit

# Single test file
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_dice.gd -gexit
```

## Test Count Verification (Critical)

After adding new test files, or after any fix, always confirm the GUT summary line shows the **expected script count and test count**:

```
Ran 16 test scripts
274 passed, 0 failed
```

If fewer scripts load than expected, **GUT has silently dropped a file due to a parse error**.

GUT prints no failure for dropped files — you only notice from a lower-than-expected count.

### Diagnosing GUT Silent Test Omissions

Symptom: Test total drops unexpectedly (e.g. 274 → 260 with "0 failed").

1. Narrow down which file is missing from the output (GUT lists loaded scripts).
2. The parse error is usually in the **source file**, not the test file:
   ```bash
   godot --headless res://src/core/suspect_file.gd
   ```
3. Look for `Parse Error:` in the output.
4. Most common cause: **mixed tab/space indentation** — a function body using spaces in a tab-indented file. One such line silently breaks the entire file.
5. Fix the indentation, re-run, and verify the script count returns to expected.

## Before Committing

Run the full test suite and check the tail output:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs 2>&1 | tail -20
```

Requirements before any commit:
- ✅ 0 failures
- ✅ Total test count matches expectation (no silent drops)
- ✅ No `Parse Error:` in output
- ✅ Implementation plan updated if a phase task was completed
