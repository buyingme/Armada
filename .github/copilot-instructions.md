# GitHub Copilot Instructions — Star Wars: Armada Digital Edition

> **This file is automatically loaded by GitHub Copilot as system-level context.**
> It ensures every AI-generated code contribution meets project standards.

## Project Identity

- **Project:** Star Wars: Armada — Digital board game adaptation
- **Engine:** Godot 4.5+ with GDScript (no C#, no GDExtension)
- **Architecture:** Layered (Presentation → Application → Domain → Data)
- **Testing:** GUT framework (v9.6.0), high coverage mandatory
- **Documentation:** arc42 style in `docs/arc42/`

## Mandatory Reading Before Any Code Generation

You **must** read and follow these documents (in `.skills/`):

1. **`.skills/gdscript_style.md`** — Naming, typing, doc comments, banned patterns
2. **`.skills/architecture_patterns.md`** — Layer rules, EventBus, RefCounted core logic
3. **`.skills/testing_standards.md`** — Test naming, AAA pattern, coverage targets
4. **`.skills/file_organization.md`** — Where files go, new file checklist
5. **`.skills/copilot_instructions.md`** — Detailed templates and rules

## Non-Negotiable Rules

These rules apply to **every** code change. No exceptions.

### 1. Static Typing Everywhere

```gdscript
# REQUIRED — every parameter, return type, and variable
func calculate_damage(results: Array[Dictionary]) -> int:
    var total: int = 0
```

### 2. Doc Comments on All Public API

```gdscript
## Resolves the attack dice modification step.
## Rules Reference: "Attack", Step 3, Page 2
func resolve_attack_effects(pool: Array[Dictionary]) -> Array[Dictionary]:
```

### 3. Tests Are Mandatory

- Every new class in `src/core/` or `src/models/` **must** have a corresponding test file
- Every new public method **must** have at least one test
- Tests follow AAA pattern with descriptive assertion messages
- Test naming: `test_<method>_<scenario>_<expected>()`

### 4. Core Logic Is Scene-Tree Independent

```gdscript
# Classes in src/core/ extend RefCounted, NOT Node
class_name AttackResolver
extends RefCounted
```

### 5. EventBus for Cross-System Communication

```gdscript
# REQUIRED — never use direct node references between systems
EventBus.ship_damaged.emit(ship, damage, zone)
```

### 6. Constants for All Game Values

```gdscript
# REQUIRED — no magic numbers or string literals for game concepts
var zone: Constants.HullZone = Constants.HullZone.FRONT
if round > Constants.MAX_ROUNDS:
```

### 7. No Banned Patterns

- ❌ `print()` — use `GameLogger` utility
- ❌ Untyped function signatures
- ❌ Functions longer than 30 lines
- ❌ Nesting deeper than 3 levels
- ❌ Direct cross-system node references
- ❌ Hardcoded game values
- ❌ Mixing tabs and spaces in the same file
- ❌ `if/elif` chains on enum values — use `match`

### 8. Game Rules Must Be Cited

When implementing game mechanics, always reference the source rule:

```gdscript
## Determines if a defense token can be spent.
## Rules Reference: "Defense Tokens", bullet 4, p.5
## "If the defender's speed is '‘0,' he cannot spend any defense tokens."
func can_spend_defense_token(defender_speed: int) -> bool:
    return defender_speed > 0
```

### 9. Verify Test Count After Every Change

After editing source or test files, always run the full suite and confirm both the script count and the pass count:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs 2>&1 | tail -20
```

GUT **silently drops test files that contain parse errors** — you see fewer tests with 0 failures. If the count drops unexpectedly, find the parse error before committing. The most common cause is mixed tab/space indentation.

### 10. Update Progress Tracking Per Phase

When completing a phase task or full phase:
- Update `docs/implementation_plan.md` status markers (🔄 → ✅, add commit hash and test count)
- Include `docs/implementation_plan.md` in the phase commit
- See `.skills/copilot_instructions.md` for the exact update procedure

## Code Generation Workflow

When asked to implement a feature or fix a bug:

1. **Search first** — Check `src/` for existing related code. Check `Resources/` rules docs for game rules.
2. **Plan the change** — Identify which layer(s) are affected (Domain? Presentation? Both?)
3. **Write the core logic** — `src/core/` with `RefCounted`, no scene tree dependency
4. **Write the tests first or alongside** — Never submit untested logic
5. **Wire up the presentation** — `src/scenes/` connects to core via EventBus
6. **Verify** — Run tests and confirm: 0 failures, expected script count, no parse errors:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs 2>&1 | tail -20
   ```
7. **Update progress** — Mark completed tasks in `docs/implementation_plan.md` and include in commit

## Architecture Quick Reference

```
src/
├── autoload/    → Singletons (GameManager, EventBus, Constants)  [extends Node]
├── core/        → Pure game logic (GameState, Dice, AttackResolver)  [extends RefCounted]
├── models/      → Data resources (ShipData, SquadronData)  [extends Resource]
├── scenes/      → Visual scenes + controllers  [extends Node/Control]
├── ui/          → Reusable UI widgets  [extends Control]
└── utils/       → Helpers (GameLogger)  [extends RefCounted]
```

**Dependency flow:** UI/Scenes → Autoloads → Core → Models (downward only, never upward)

## Key Enums (from Constants autoload)

`Faction`, `ShipSize`, `HullZone`, `DiceColor`, `DiceFace`, `DefenseToken`, `DefenseTokenState`, `CommandType`, `GamePhase`

## Game Data

- Ship card data + art: `Resources/Game_Components/ships/`
- Squadron card data + art: `Resources/Game_Components/squadrons/`
- Schema: `Resources/Game_Components/card_data_schema.json`
- Asset structure: `Resources/Game_Components/README.md`
- Rules Reference: `Resources/SWM-RULES-REFERENCE-GUIDE-150/`
- Learn to Play: `Resources/SWM01-ARMADA-LEARN-TO-PLAY/`

## Commit Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):
```
feat(core): implement dice rolling system
test(dice): add unit tests for damage calculation
fix(combat): correct critical hit detection on black dice
docs(arc42): complete building block view level 2
```
