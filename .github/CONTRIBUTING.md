# Contributing to Star Wars: Armada Digital Edition

## Development Workflow

### Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, tested code. Always deployable. |
| `develop` | Integration branch for features in progress. |
| `feature/<name>` | Individual feature development. |
| `bugfix/<name>` | Bug fix branches. |
| `docs/<name>` | Documentation-only changes. |
| `test/<name>` | Test additions or improvements. |

### Branch Naming Convention

```
feature/ship-movement-system
feature/combat-resolver
bugfix/dice-blank-face-count
docs/arc42-runtime-view
test/integration-attack-sequence
```

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

**Types:**

| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `test` | Adding or updating tests |
| `docs` | Documentation changes |
| `refactor` | Code restructuring without behavior change |
| `style` | Formatting, whitespace (no logic change) |
| `chore` | Build, tooling, dependency updates |

**Examples:**

```
feat(core): implement dice rolling system
test(dice): add unit tests for damage calculation
fix(combat): correct critical hit detection on black dice
docs(arc42): complete building block view level 2
refactor(models): extract ship stats into ShipData resource
```

### Pull Request Process

1. Create a feature branch from `develop`.
2. Make changes following the coding standards (see `.skills/` documents).
3. Write or update tests — **all new code must have tests**.
4. Ensure all tests pass locally: run GUT from the Godot editor or CLI.
5. Update documentation if architecture or interfaces change.
6. Create a PR with the template below filled in.
7. Self-review using the PR checklist.

### Definition of Done

A feature/fix is considered done when:

- [ ] Code is implemented and follows the GDScript style guide
- [ ] All doc comments (`##`) are present for public API and explain useful contracts, invariants, rationale, rules, or failure modes
- [ ] Unit tests pass (≥80% coverage for core logic)
- [ ] Integration tests pass for affected systems
- [ ] No new warnings or errors in the Godot console
- [ ] arc42 documentation updated if architecture changed
- [ ] PR template checklist completed

---

## Running Tests

### In Godot Editor

1. Open the project in Godot 4.5+.
2. Navigate to `GUT` panel at the bottom.
3. Click "Run All" or select specific test directories.

### From Command Line

```bash
# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Run only unit tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# Run only integration tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit
```

---

## Code Review Checklist

- [ ] Code follows GDScript style guide
- [ ] Functions have useful doc comments; raw LOC pressure was handled by extraction, not by deleting rationale
- [ ] No hardcoded values (use Constants)
- [ ] Signals used for cross-system communication (via EventBus)
- [ ] Core logic doesn't depend on scene tree
- [ ] Tests cover happy path and edge cases
- [ ] No `print()` statements (use GameLogger instead)
