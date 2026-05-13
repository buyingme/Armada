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
8. **`.skills/serialization_and_commands.md`** — Serialization contract, command system, normalised positions, replay safety, banned patterns

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

Doc comments are part of maintainability. Prefer comments that explain why the
code exists, caller contracts, invariants, source rules, and failure modes. Do
not remove useful docstrings merely to satisfy raw file LOC targets; the
30-line function limit excludes doc comments and blank lines. If documentation
pushes a file over a ceiling, preserve the rationale and extract behaviour or
record a focused follow-up.

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
- ❌ Mutable game-state field without `serialize()`/`deserialize()` — see `.skills/serialization_and_commands.md` §1
- ❌ Mutating `GameState` outside a `GameCommand.execute()` — see `.skills/serialization_and_commands.md` §4.6
- ❌ Pixel values in command payloads or serialized state — use normalised `pos_x`/`pos_y`/`rotation_deg`
- ❌ `Vector2`/`Color`/Godot types in serialized dictionaries — use plain floats/ints
- ❌ `play_area_side_px` (float) in `get_pixel_position()` — use `play_area_size_px` (Vector2)
- ❌ (Phase I) New `NetworkInteractionState` producer call sites or `broadcast_interaction_state(` calls — UI flow state lives in `GameState.interaction_flow`, mutated only by `GameCommand.execute()`. See `docs/implementation_plan.md` §3.
- ❌ (Phase I) `if PlayMode.is_network():` branches inside `src/scenes/` or `src/ui/` for modal/authority decisions — use `UIProjector.project(state, local_player_index)`.
- ❌ (Phase I) Subscribing to `EventBus.interaction_state_changed` (signal removed in Phase I6) — subscribe to `EventBus.command_executed` and call `UIProjector.project()`.
- ❌ (Phase I) Inferring activation/attack sub-step from local UI events — always read `state.interaction_flow.step_id`.
- ❌ (Phase K) Any new `if PlayMode.is_network()` / `if PlayMode.is_hot_seat()` in `src/scenes/` or `src/ui/` — `UIProjector.project()` is the only PlayMode-aware code path outside `src/autoload/`. Run `scripts/lint_phase_k.sh` (added in slice K7) before every commit. See `docs/refactoring_phase_k_plan.md`.
- ❌ (Phase K) Growing [game_board.gd](src/scenes/game_board/game_board.gd), [attack_executor.gd](src/scenes/game_board/attack_executor.gd), [game_manager.gd](src/autoload/game_manager.gd), or [save_game_manager.gd](src/autoload/save_game_manager.gd) past their Phase K LOC ceilings (2 000 / 1 500 / 1 500 / 700). New behaviour goes into a focused controller / RefCounted helper. Do not meet LOC ceilings by deleting useful docstrings or rationale comments; file LOC is a refactoring trigger, not a documentation-cutting target.

### 8. Game Rules Must Be Cited

When implementing game mechanics, always reference the source rule:

```gdscript
## Determines if a defense token can be spent.
## Rules Reference: "Defense Tokens", bullet 4, p.5
## "If the defender's speed is '‘0,' he cannot spend any defense tokens."
func can_spend_defense_token(defender_speed: int) -> bool:
    return defender_speed > 0
```

### 9. Verify Test Count and Lint After Every Change

After editing source or test files, always run the full suite **and** the Phase K lint, and confirm both the script count and the pass count, plus zero lint violations:

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
bash scripts/lint_phase_k.sh
```

For Phase L/M work or any change touching modal lifecycle, replay,
`GameReplay`, `ReplayDriver`, `BaselineTrace`, command submission, or
network flow, also run:

```bash
bash scripts/run_baseline_traces.sh --all
```

This gate diffs the committed hot-seat trace/hash and verifies that a real
two-process network replay ends with matching host/client state hashes. Do
not add committed network command-trace or network state-hash fixtures until
the network command pump is deterministic across separate runs.

GUT **silently drops test files that contain parse errors** — you see fewer tests with 0 failures. If the count drops unexpectedly, find the parse error before committing. The most common cause is mixed tab/space indentation.

`scripts/lint_phase_k.sh` must exit `0` and report `0 violations`. New `if PlayMode.is_network()` / `is_hot_seat()` branches in `src/scenes/` or `src/ui/` are forbidden — route through `UIProjector.project()` instead. Never silence the lint by bumping the allow-list count without explicit approval.

### 10. Generate `.uid` Files for New Scripts

Godot 4.5+ requires a `.gd.uid` sidecar for every script that declares `class_name`. After creating any new `.gd` file with `class_name`, run:

```bash
godot --headless --import
```

Then **commit the resulting `.gd.uid`** alongside the `.gd`. Without it, other scripts referencing the type will fail with *"Could not find type … in the current scope"*.

### 11. Update Progress Tracking Per Phase

When completing a phase task or full phase:
- Update `docs/implementation_plan.md` — refresh §1 baseline (test counts, commit hash), update phase status in §2, move resolved items out of §4 and add new pending items
- Update `docs/arc42/11_risks_and_technical_debt.md` if technical debt changes
- Include doc updates in the phase commit
- See `.skills/copilot_instructions.md` for the exact update procedure and the MT scenario template
- Archived originals in `docs/old/` for historical reference (per-slice narratives, MT logs, fix follow-ups)

## Code Generation Workflow

When asked to implement a feature or fix a bug:

1. **Search first** — Check `src/` for existing related code. Check `Resources/` rules docs for game rules.
2. **Plan the change** — Identify which layer(s) are affected (Domain? Presentation? Both?)
3. **Check refactoring constraints** — Read `.skills/refactoring_guidelines.md`. Ensure the change does not introduce functions > 30 lines, does not add responsibilities to god objects, and follows extraction patterns if applicable.
4. **Check serialization impact** — Read `.skills/serialization_and_commands.md`. If the change adds mutable state, add `serialize()`/`deserialize()`. If it mutates game state, route through a `GameCommand`. If it involves positions, use normalised coordinates.
5. **Write the core logic** — `src/core/` with `RefCounted`, no scene tree dependency
6. **Write the tests first or alongside** — Never submit untested logic
7. **Wire up the presentation** — `src/scenes/` connects to core via EventBus
8. **Verify** — Run tests **and** the Phase K lint and confirm: 0 failures, expected script count, no parse errors, lint exit 0:
   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
   bash scripts/lint_phase_k.sh
   ```
   The lint must report `0 violations` (allow-listed branches are fine). If it fails, fix before continuing — never silence it by editing the allow-list count without explicit approval.
9. **Replay baseline gate** — For Phase L/M, modal lifecycle, replay, command-submission, or network-flow changes, run `bash scripts/run_baseline_traces.sh --all` and require it to pass.
10. **Manual test gate** — Prompt the user with concrete manual test steps (what to run, click, observe). **Wait for explicit user approval before committing.** See `.skills/copilot_instructions.md` § "Mandatory Manual Test Gate".
11. **Update progress** — Update `docs/implementation_plan.md` (§1 baseline, §2 phase status, §4 open topics) and include in commit

## Architecture Quick Reference

```
src/
├── autoload/    → Singletons (GameManager, EventBus, Constants)  [extends Node]
├── core/        → Pure game logic — NO files at root, use sub-folders  [extends RefCounted]
│   ├── combat/      → Attack resolution, defense tokens, dice modification
│   ├── commands/    → GameCommand subclasses, submitters, replay
│   ├── damage/      → Damage cards, damage dealing, repair
│   ├── effects/     → Upgrade / ability effects (keywords/ sub-folder)
│   ├── geometry/    → Ship bases, range finding, line of sight, layout math
│   ├── movement/    → Maneuver tool, overlap resolution, squadron movement
│   └── state/       → GameState, activation context, dial/token mgmt, RNG
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
