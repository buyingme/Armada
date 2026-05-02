# Refactoring Guidelines — Armada Project

> **Master plan:** `docs/implementation_plan.md` (archived detail: `docs/old/refactoring_plan.md`, `docs/old/progress_summary.md`, `docs/old/open_topics.md`)
> These rules apply to ALL generated code — not just explicit refactoring tasks.

## Purpose

This skill file ensures that every code change moves the codebase toward the
quantified targets in the refactoring plan, or at minimum does not regress them.
Code generation must respect these constraints even when the user's request is
not explicitly about refactoring.

---

## 1. Function Size — Hard Limit

**Every function must be ≤ 30 lines** (excluding doc comments and blank lines).

When adding code to an existing function would push it over 30 lines:
1. Extract the new logic into a well-named private helper.
2. Keep the original function as the coordinator that calls helpers.
3. Each helper must have a single responsibility and a descriptive name.

```gdscript
# GOOD — coordinator + helpers
func _resolve_attack_step() -> void:
    var pool := _build_dice_pool()
    _apply_attack_modifiers(pool)
    _resolve_damage(pool)

# BAD — everything inline in one 80-line function
func _resolve_attack_step() -> void:
    # ... 80 lines of mixed logic ...
```

---

## 2. `_build_ui()` Splitting Pattern

**Never write a monolithic `_build_ui()` method.**

Split UI construction into `_build_<section>()` helpers, each returning the
container it created. The parent method assembles returned containers:

```gdscript
func _build_ui() -> void:
    var header := _build_header_section()
    var dice := _build_dice_section()
    var actions := _build_action_buttons()
    main_container.add_child(header)
    main_container.add_child(dice)
    main_container.add_child(actions)

func _build_header_section() -> VBoxContainer:
    var container := VBoxContainer.new()
    # ... build header widgets ...
    return container
```

Each `_build_<section>()` must:
- Return the container it creates (not add directly to parent).
- Be ≤ 30 lines.
- Store member references (`_some_label = label`) if the widget needs updating later.
- Set all required properties (`.text`, `.custom_minimum_size`, `.disabled`, signal connections).

**Common bug:** creating a `Button.new()` but forgetting to set `.text`, `.disabled`, or
`.pressed.connect()`. Always set all four: text, minimum size, initial state, signal connection.

---

## 3. Extracted Controller Pattern

When extracting a cluster of functions from a god object into a new controller:

```gdscript
## ManeuverToolController
##
## Manages the maneuver tool lifecycle for ship activation.
## Extracted from game_board.gd (MANEUVER cluster, Phase C1).
class_name ManeuverToolController
extends Node

var _game_board: Node  # injected, not looked up

## Initializes with required dependencies.
## Called by the parent after add_child().
func initialize(game_board: Node) -> void:
    _game_board = game_board
    _connect_signals()
```

Rules:
- **Extends `Node`** (needs scene tree for signals/process).
- **`initialize()` injection** — dependencies passed explicitly, not via `get_node()` or autoload lookups.
- **Signals back to parent** — controller emits signals; parent connects. No direct upward calls.
- **Self-contained signal connections** — controller connects its own EventBus signals in `_connect_signals()`.
- **Private state** — all member vars are `_prefixed`.
- **Doc comment cites origin** — `## Extracted from game_board.gd (CLUSTER, Phase XX).`
- **Corresponding test file** — `tests/unit/test_<controller_name>.gd` created alongside.

---

## 4. EventBus Signal Organization

Group EventBus signals with `#region` blocks by domain:

```gdscript
#region Game Flow
signal round_started(round_number: int)
signal phase_changed(phase: Constants.GamePhase)
#endregion

#region Attack
signal attack_started(attacker: Node, defender: Node)
signal attack_completed(result: Dictionary)
#endregion
```

When adding a new signal, place it in the correct region. Do not append to the
end of the file without grouping.

---

## 5. Serialization Requirement

> **Full specification:** `.skills/serialization_and_commands.md`
>
> This section is a summary. The canonical rules, templates, banned patterns,
> and command contract live in that document.

**Every `RefCounted` class that holds mutable game state must implement
`serialize() -> Dictionary` and `static deserialize(data: Dictionary) -> Self`.**

When creating a new class, ask: *"Does this hold game state that would need
saving/loading?"* If yes, add `serialize()`/`deserialize()` from the start
and write a round-trip test.

When adding a field to an existing serializable class, update both
`serialize()` and `deserialize()` **in the same edit**. Use `.get(key, default)`
in `deserialize()` for forward compatibility.

See `.skills/serialization_and_commands.md` §1–§2 for the full contract,
class inventory, and templates.

---

## 6. Dependency Injection Rules

### Prefer `initialize()` over constructor for Node-derived classes

Nodes are created via `.new()` or scene instantiation, so constructor
parameters are not practical:

```gdscript
# GOOD — explicit dependency injection
func initialize(context: ActivationContext, attack_exec: Node) -> void:
    _context = context
    _attack_executor = attack_exec

# BAD — reaching through the tree
func _ready() -> void:
    _context = get_node("/root/GameBoard")._activation_context
```

### Prefer Callable injection for cross-cutting operations

When a controller needs to call back into its parent, inject a `Callable`
rather than a typed reference to the parent class:

```gdscript
# GOOD — decoupled callback
var _on_activation_complete: Callable

func initialize(on_complete: Callable) -> void:
    _on_activation_complete = on_complete

# BAD — circular dependency
var _game_board: GameBoard  # controller knows about its parent's type
```

---

## 7. God Object Prevention

### Size thresholds

| Lines | Status | Action |
|-------|--------|--------|
| ≤ 500 | Green | No action needed |
| 501–1000 | Yellow | Plan extraction at next opportunity |
| > 1000 | Red | Must be addressed — file an extraction task |

### When adding code to a large file

Before adding code to any file > 500 lines:
1. Check if the new code belongs in an existing or new extracted controller.
2. If it must go in the large file temporarily, add a `# TODO(refactor): extract to <ControllerName>` comment.
3. Never add a new responsibility cluster to an already-oversized file.

### New files start small

When creating a new class, aim for < 200 lines. If it grows past 300 during
implementation, split before committing.

---

## 8. Single Source of Targeting Geometry

See `.skills/architecture_patterns.md` § "Single Source of Targeting Geometry"
for the canonical method table.

**Enforcement rule:** When reviewing or generating code that computes
distance, range, arc containment, or engagement, verify it delegates to
`RangeFinder` or `EngagementResolver`. If it performs raw `distance_to()`
minus radius arithmetic, flag it as non-compliant and rewrite to use the
canonical API.

**Checklist for new range/distance code:**

1. Does `RangeFinder` already have a method for this measurement? → Use it.
2. Would the measurement benefit other callers? → Add to `RangeFinder`.
3. Is it truly one-off math? → Still use `RangeFinder` primitives
   (`closest_point_on_polyline`, `closest_point_on_circle`) and compose.

---

## 9. Refactoring-Safe Patterns

### Never rewrite a large file in one shot

When extracting helpers from a file > 500 lines, **never replace the entire
file in a single edit**.  AI token budgets can be exhausted mid-write, leaving
the file truncated or the session crashed.

**Incremental delegation pattern (mandatory for files > 300 lines):**

1. **Create extracted helper files first** — `ShipCardEntryBuilder.gd`,
   `DamageCardDisplay.gd`, etc. — and ensure they compile in isolation.
2. **Add helper instances** to the coordinator — add member vars and initialise
   them (2–5 line edit).
3. **Delegate one method group at a time** — replace 1–3 methods per edit,
   calling the new helper instead of the local implementation.
4. **Run tests after each step** — confirm script count and pass count.
5. **Delete dead code last** — only after all delegations are wired and green.

Each step is a small, targeted edit (< 50 lines changed) that leaves the file
compilable and testable.  This avoids the risk of a single monolithic rewrite
exhausting the AI context window.

```gdscript
# Step 1 — add helper (tiny edit)
var _builder: ShipCardEntryBuilder

func setup(...) -> void:
    _builder = ShipCardEntryBuilder.new(_tex_cache)

# Step 2 — delegate one method (small edit)
func _build_left_column(instance, gap) -> Dictionary:
    var result := _builder.build_left_column(instance, gap)
    result["dial_container"].gui_input.connect(
        _on_dial_container_gui_input.bind(_entries.size()))
    return result

# Step 3 — after all delegations green, delete the old local methods
```

### Preserve public API during extraction

When extracting code from a god object:
1. The original public methods remain as **thin wrappers** that delegate to the new controller.
2. External callers and signals are NOT updated in the extraction commit.
3. A follow-up commit removes the wrapper and updates callers.

This two-step approach keeps each commit green and testable.

### One file per commit

Refactoring commits touch **one source file** (+ its test file). Never refactor
multiple source files in the same commit — it makes bisecting failures easier.

### Test count must not drop

After every refactoring change:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```
If the script count or test count drops, **stop and find the parse error**
before continuing. The most common cause is mixed tabs/spaces.

---

## 10. Quantified Targets (from Refactoring Plan)

These are the project-wide goals. Every code change should move toward them:

| Metric | Current | Target | Phase |
|--------|---------|--------|-------|
| Functions > 30 lines | 95 | **0** | A |
| Max file lines | 3,390 | **< 500** | C + F |
| God objects (> 1,000 LOC) | 4 | **0–1** | C + F |
| Serializable game classes | 6/11 | **11/11** | E |
| EventBus signal regions | 0 | **8** | E6 |
| Controller unit test coverage | 0% | **> 80%** | C + F |

---

## 11. Refactoring Phase Reference

When working on a specific refactoring phase, consult `docs/implementation_plan.md`
for completed phases and remaining work.
Archived detail: `docs/old/refactoring_plan.md`.

| Phase | Focus | Risk |
|-------|-------|------|
| **A** | Shrink all functions to ≤ 30 lines | None |
| **B** | Narrow interfaces (parameter objects, dispatch tables) | Low |
| **C** | Extract 6 isolated controller clusters from god objects | Low–Med |
| **D** | UI builder helpers (reusable across 12+ UI files) | Low |
| **E** | Serialization + EventBus cleanup | Low |
| **F** | Extract backbone (ActivationContext, SquadronPhaseController, UIPanelManager) | Medium |
| **G** | Command pattern for multiplayer | Medium |

Always work phases in order. Never start phase N+1 until N is committed and green.

---

*This file is referenced by `.github/copilot-instructions.md` rule "Follow `.skills/` documents".*
