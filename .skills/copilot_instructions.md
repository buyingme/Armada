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

0. **Apply the ambiguity safety gate** — If there is uncertainty about the requirement, scope, behaviour, affected files, data source, hot-seat/network handling, destructive impact, or implementation path, stop before editing. Ask a concise question or present concrete options with tradeoffs, and wait for explicit user approval before proceeding. This gate is a safety net against unwanted changes.
1. **Understand the requirement** — Check the Rules Reference in `Resources/` if it concerns game rules.
2. **Check existing code** — Search `src/` for related classes and patterns.
3. **Check existing tests** — See `tests/` for testing patterns used in this project.
4. **Follow the architecture** — See `.skills/architecture_patterns.md`.
5. **Check serialization impact** — See `.skills/serialization_and_commands.md`. If the change adds mutable state fields, update `serialize()`/`deserialize()` in the same edit. If it mutates game state, route through a `GameCommand`. If it involves positions, use normalised `pos_x`/`pos_y`/`rotation_deg`.
6. **Specify off-turn ownership first** — If a defender, opponent, non-active player, or off-turn controller makes a choice, update `docs/game_flow.md` and `FlowSpec` before UI/scene edits. Name the controller role, identity payload, allowed commands, transitions, projection route, and regression tests. Counter is the reference pattern.
7. **Separate preview from commit** — If the UI lets a player inspect ranges,
   select candidates, or switch selection, keep that state transient. Spend
   command budget or activation slots only when a command-backed move, attack,
   reroll, choice, or lifecycle marker is committed.

### Network Refactor Guardrail (G4.6.6+)

When a task touches networked UI flow, authority handoff, or modal visibility:

1. Read `docs/old/g4_network_plan.md` § "Ratified UX Contract", "T0", and
    "Protocol Guarantees" before coding.
2. Treat `controller_player` as the only source of interaction authority;
    never infer authority from local UI state alone.
3. Keep visibility and interactivity separate:
    - common visibility does not imply local control.
4. Enforce command-phase privacy invariants:
    - no opponent dial content in snapshots/results/events.
5. For reconnect-sensitive flows, restore interaction step before
    enabling input.

## Progress Tracking

Progress is tracked in a single consolidated document:
- `docs/implementation_plan.md` — baseline metrics, phase status, open topics, planned extensions

Archived originals (historical detail only): `docs/old/progress_summary.md`, `docs/old/open_topics.md`, `docs/old/implementation_plan.md`, `docs/old/refactoring_plan.md`, `docs/old/refactoring_phase_i_plan.md`, `docs/old/refactoring_test_strategy.md`, `docs/old/g4_network_plan.md`, `docs/old/architecture_assessment.md`, `docs/old/test_plan_manual.md`

### Status Markers

| Marker | Meaning |
|--------|--------|
| ✅ | Complete — tests passing, committed |
| 🔄 | In progress — started, not yet complete |
| ⏳ | Planned — not yet started |

### When Completing a Phase

1. Update `docs/implementation_plan.md` — §1 baseline (test counts, commit hash), §2 phase status, §4 open topics (move resolved items out, add new pending items)
2. Update `docs/arc42/11_risks_and_technical_debt.md` if technical debt changes
3. Include doc updates in the phase commit

### Manual Test Plan — What to Add After Each Phase

`docs/implementation_plan.md` §4.4 tracks open manual tests at a summary level; per-phase MT logs live in commit messages and the archived `docs/old/open_topics.md`. After completing a phase, draft new manual test entries following these rules:

- **Format:** `## Phase N — <Name>` header, then one `### MT-N.X` block per test scenario.
- **One table per scenario:** columns = Step | Action | Expected.
- **Focus on what automated tests cannot cover:** visual output, input handling, rendering, layout, interaction. Skip anything already verified by GUT.
- **Be specific:** state exact expected values (colours, counts, pixel positions, key names) rather than vague outcomes like "it looks correct".
- **Keep it short:** 3–8 scenarios per phase is the target. More is not better.
- **Include a temp-code pattern** when testing requires triggering an event or signal that has no UI yet — and explicitly note to remove it before committing.
- **Update the Regression Checklist** at the bottom of the file with the new pass criteria and test count.
- **Update the "Last updated" footer** line with the phase, commit hash and test count.

**MT scenario template:**

```markdown
### MT-N.X — Short description of what is being tested

| Step | Action | Expected |
|------|--------|----------|
| 1 | [Concrete thing to do] | [Concrete thing to see/measure] |
| 2 | ... | ... |

**Pass criteria:** [One-sentence summary of what "pass" means.]
```

### When Starting a Phase

1. Change phase header from `⏳` to `🔄`
2. Confirm all prerequisites phases are `✅`

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
| Hardcoding named scalars/enums in game logic | Use `Constants` for game-wide values (`MAX_ROUNDS`, hull zone names, dice colours) |
| Hardcoding card properties in GDScript (faction, ship size, cost, stats) | Read from card JSON via `AssetLoader.load_ship_data()` / `load_squadron_data()` — these come from `ships/<key>.json`, `squadrons/<key>.json` |
| Hardcoding scenario placement data in GDScript (positions, rotations, token list) | Create `scenarios/<name>.json` and load via `AssetLoader.load_json("scenarios/", file)` |
| Adding mutable state field without updating `serialize()`/`deserialize()` | Update both methods in the same edit — see `.skills/serialization_and_commands.md` §2 |
| Mutating GameState outside a GameCommand `execute()` | Write a command — see `.skills/serialization_and_commands.md` §4.6 |
| Spending command resources during selection preview | Keep previews local/transient; spend only on committed move/attack/reroll/choice/marker commands |
| Adding a marker command without preflight parity | Update `CommandApplicability`, `FlowSpec.allowed_commands`, command `validate()`, and tests together |
| Storing pixel positions in command payloads or serialized state | Use normalised `pos_x`/`pos_y`/`rotation_deg` (0.0–1.0) — see `.skills/serialization_and_commands.md` §3 |
| Using `Vector2`/`Color` in serialized dictionaries | Use separate float keys (`pos_x`, `pos_y`) for JSON safety |
| Using `play_area_side_px` (float) in `get_pixel_position()` | Use `play_area_size_px` (Vector2) for rectangular board support |
| Cross-system direct references | Use `EventBus` signals |
| Writing tests without assertion messages | Always add description parameter |
| Functions >30 lines | Split into smaller functions |
| Missing doc comments | Add `##` to all public API |
| File LOC pressure | Extract behaviour; do not delete useful docstrings to satisfy raw line counts |
| Using `if/elif` chains on enum values | Use `match` statements |

## GDScript Gotchas Learned in Development

These are subtle bugs actually encountered in this project:

| Gotcha | Symptom | Fix |
|--------|---------|-----|
| Mixing tabs and spaces in one file | GUT silently drops the entire test file — fewer tests with 0 failures | Use only tabs; audit every inserted block for 8-space indentation |
| Wrong sign in boolean condition | Arc membership tests accept wrong quadrant | Re-derive from first principles on paper before coding; `lx - ly >= -tol` ≠ `lx - ly <= tol` |
| Calling `.distance_to()` on wrong object | Geometry distance function returns 0 for all inputs | Verify both args are independent points; don't pass a point that is already on the segment as the reference |
| Forgetting `static` on utility class method | `Method not found in base 'RefCounted'` at runtime | All methods in a static utility class must carry the `static` keyword |
| `match` arm body indented at wrong level | Parse error or wrong arm executes | Each arm body must be exactly one tab deeper than the arm label |
| GUT `-gexit` required in 9.5.0 | Headless process never terminates without it — tests run but the shell hangs | Always use `-gexit 2>&1 \| tail -20`; output IS visible through the pipe |
| Lifecycle command legal in one phase but produced in another | Host preflight rejects the command and passive network UI stalls | Make marker commands legal on every producer phase/FlowSpec row; test both applicability and command validation |
| Selection preview consumes command budget | Merely clicking a different token spends a Squadron command activation | Keep selection/range checks transient; commit budget only when movement or attack starts, and clear preview on Back |
| Multi-line `git commit -m` in terminal tool | Zsh garbles multi-line quoted strings passed via the terminal tool — produces `cmdand dquote>` artifacts, duplicated fragments, or truncated messages | **Never** use `git commit -m` with multi-line messages. Always write the message to a temp file first, then commit with `-F`. See the Git Commit section below |

---

## Mandatory Manual Test Gate

**Before every commit, you MUST prompt the user for manual testing.**

This is a hard gate — no commit may happen without user approval.

### Large-File Edits — Incremental Only

**Never rewrite a file > 300 lines in a single edit.**  AI token budgets
can be exhausted mid-write, crashing the session and leaving the file
truncated.

Follow the **incremental delegation pattern** from
`.skills/refactoring_guidelines.md` §8:

1. Create extracted helper files first (separate edits).
2. Add helper member vars + init (tiny edit).
3. Delegate one method group at a time (small edits, < 50 lines each).
4. Run tests after each step.
5. Delete dead code last.

LOC ceilings are a signal to extract responsibilities, not an instruction to
strip documentation. Preserve docstrings that explain why/contract/invariant/
failure modes, especially in network, replay, serialization, and modal-flow
code. Move broad phase-history narrative to `docs/`, but keep concise rationale
near the code it protects.

### Workflow

1. **Run the automated test suite** and report the results (pass count, script count, failures).
2. **Run the replay baseline gate when applicable.** For Phase L/M work, modal lifecycle changes, replay/trace changes, command-submission changes, or network-flow changes, run `bash scripts/run_baseline_traces.sh --all`. It verifies the committed hot-seat trace/hash and network host/client final-state-hash equality. Do not add committed network command/hash fixtures until the network command pump is deterministic across separate runs.
3. **Provide manual test steps** — specific actions the user should perform in the running game to verify the change visually/interactively. Be concrete: which scene to run, what to click, what should appear on screen.
4. **Wait for user approval** — ask explicitly: *"Please run the manual tests above and confirm the results. Should I commit?"*
5. **Only commit after the user confirms.** If the user reports a problem, fix it and repeat from step 1.

### What Manual Test Steps Should Cover

- Visual correctness (layout, colours, text, sizing)
- Interaction correctness (clicks, drags, keyboard input)
- State transitions visible in the UI (panels opening/closing, tokens changing)
- Anything GUT cannot verify (rendering, audio, animation timing)

### When to Skip (Rare)

- Docs-only changes (no code touched)
- Test-only additions where no source code was modified
- Skill/config file updates (like this one)

Even in these cases, state explicitly: *"This is a docs/test-only change — no manual test needed. Should I commit?"*

---

## Git Commits

The terminal tool struggles with multi-line quoted strings. Commits **must** follow this pattern:

### Procedure

1. **Write message to a temp file** using `printf` (not heredoc — heredocs can also have issues with the terminal tool):
   ```bash
   printf 'feat(core): implement targeting list tool (Phase 5d)\n\nShort body line 1.\nShort body line 2.\nTests: 916 (53 scripts, 1741 asserts).' > /tmp/commit_msg.txt
   ```
2. **Stage and commit** in the same command:
   ```bash
   git add -A && git commit -F /tmp/commit_msg.txt
   ```
3. **Verify** with `git log --oneline -1`.

### Rules

- **Never** use `git commit -m "..."` with multi-line messages.
- **Never** use heredoc (`<< 'EOF'`) — it can also get garbled.
- Use `printf` with `\n` for newlines — it's the most reliable method.
- Keep commit messages concise: one subject line + 2-4 body lines max.
- Follow Conventional Commits: `feat|fix|test|docs|refactor(scope): subject`
- Include test count in the body: `Tests: NNN (SS scripts, AAA asserts).`
- For single-line messages, `git commit -m "feat(scope): subject"` is fine.
