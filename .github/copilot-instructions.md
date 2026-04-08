# GitHub Copilot Instructions — Star Wars: Armada Digital Edition

> **This file is automatically loaded by GitHub Copilot as system-level context.**
> It ensures every AI-generated code contribution meets project standards.

## Project Identity

- **Project:** Star Wars: Armada — Digital board game adaptation
- **Engine:** Godot 4.5+ with GDScript (no C#, no GDExtension)
- **Architecture:** Layered (Presentation → Application → Domain → Data)
- **Testing:** GUT framework (v9.5.0), high coverage mandatory
- **Documentation:** arc42 style in `docs/arc42/`

## Mandatory Reading Before Any Code Generation

You **must** read and follow these documents (in `.skills/`):

1. **`.skills/gdscript_style.md`** — Naming, typing, doc comments, banned patterns
2. **`.skills/architecture_patterns.md`** — Layer rules, EventBus, RefCounted core logic
3. **`.skills/testing_standards.md`** — Test naming, AAA pattern, coverage targets
4. **`.skills/file_organization.md`** — Where files go, new file checklist
5. **`.skills/copilot_instructions.md`** — Detailed templates and rules
6. **`.skills/ui_styling.md`** — Modal panel styles, colours, positioning, dismissibility, **§10 anchor panel reset pattern**
7. **`.skills/refactoring_guidelines.md`** — Function size limits, extraction patterns, serialization, god-object prevention, quantified targets

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
- ❌ Hardcoded named game values (scalars, enums) in logic — use `Constants`
- ❌ Hardcoded card properties (faction, ship size, cost, stats) in GDScript — read from `ships/<key>.json` or `squadrons/<key>.json` via `AssetLoader.load_ship_data()` / `load_squadron_data()`
- ❌ Hardcoded scenario placement data (positions, rotations, token list) — write a `scenarios/<name>.json` and load via `AssetLoader.load_json()`
- ❌ Mixing tabs and spaces in the same file
- ❌ `if/elif` chains on enum values — use `match`
- ❌ Rewriting a file > 300 lines in a single edit — use incremental delegation (see `.skills/refactoring_guidelines.md` §8)

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
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

GUT **silently drops test files that contain parse errors** — you see fewer tests with 0 failures. If the count drops unexpectedly, find the parse error before committing. The most common cause is mixed tab/space indentation.

### 10. Generate `.uid` Files for New Scripts

Godot 4.5+ requires a `.gd.uid` sidecar for every script that declares `class_name`. After creating any new `.gd` file with `class_name`, run:

```bash
godot --headless --import
```

Then **commit the resulting `.gd.uid`** alongside the `.gd`. Without it, other scripts referencing the type will fail with *"Could not find type … in the current scope"*.

### 11. Update Progress Tracking Per Phase

When completing a phase task or full phase:
- Update `docs/implementation_plan.md` status markers (🔄 → ✅, add commit hash and test count)
- Update `docs/test_plan_manual.md` — add or update the section for the completed phase
- Include both docs files in the phase commit
- See `.skills/copilot_instructions.md` for the exact update procedure and the MT scenario template

## Code Generation Workflow

When asked to implement a feature or fix a bug:

1. **Search first** — Check `src/` for existing related code. Check `Resources/` rules docs for game rules.
2. **Plan the change** — Identify which layer(s) are affected (Domain? Presentation? Both?)
3. **Check refactoring constraints** — Read `.skills/refactoring_guidelines.md`. Ensure the change does not introduce functions > 30 lines, does not add responsibilities to god objects, and follows extraction patterns if applicable.
4. **Write the core logic** — `src/core/` with `RefCounted`, no scene tree dependency
5. **Write the tests first or alongside** — Never submit untested logic
6. **Wire up the presentation** — `src/scenes/` connects to core via EventBus
7. **Verify** — Run tests and confirm: 0 failures, expected script count, no parse errors:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
   ```
8. **Manual test gate** — Prompt the user with concrete manual test steps (what to run, click, observe). **Wait for explicit user approval before committing.** See `.skills/copilot_instructions.md` § "Mandatory Manual Test Gate".
9. **Update progress** — Mark completed tasks in `docs/implementation_plan.md` and include in commit
10. **Update manual test plan** — Add phase section to `docs/test_plan_manual.md` (visual/interaction checks only — skip anything GUT already covers)

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

### How to Commit (Terminal Tool)

The terminal tool garbles multi-line quoted strings. **Always** use a temp file:

```bash
# 1. Write message with printf (\n for newlines)
printf 'feat(scope): subject line\n\nBody line 1.\nBody line 2.\nTests: NNN (SS scripts, AAA asserts).' > /tmp/commit_msg.txt

# 2. Stage + commit
git add -A && git commit -F /tmp/commit_msg.txt

# 3. Verify
git log --oneline -1
```

**Never** use `git commit -m` with multi-line messages. **Never** use heredocs.
Single-line messages with `git commit -m "..."` are fine.
