# Phase M — Flow Authority and Rule Registry

> Archived: 2026-05-19 after M15 closeout.
> Source plan: [docs/refactoring_phase_lm_plan.md](../refactoring_phase_lm_plan.md).

Phase M promoted interaction flow into a machine-readable rule surface:
`FlowSpec` defines valid `(flow, step)` pairs, controller roles, modal metadata,
allowed commands, transitions, and rule citations; `RuleRegistry` provides the
open-ended hook catalogue for game rules, card effects, keywords, upgrades,
objectives, and rule-derived UI affordances.

## Completed Scope

| Slice | Result |
|---|---|
| M0-M0.7 | Authored and validated the natural-language flow model, runtime registry boundary, and command-scope taxonomy. |
| M1-M2.5 | Implemented `FlowSpec`, controller roles, projection integration, and producer-safe controller resolution. |
| M3-M4 | Added command applicability declarations and the `CommandProcessor` preflight gate. |
| M5-M6 | Added `FlowHook`, `RuleRegistry`, `RuleBootstrap`, validator preflight, modifiers, and deferred observer follow-ups. |
| M7-M12 | Migrated six representative ship damage-card rules into RuleRegistry hooks: Faulty Countermeasures, Compartment Fire, Damaged Munitions, Point-Defense Failure, Crew Panic, and Capacitor Failure. |
| M13 | Added replay/network determinism coverage for hook order and observer follow-ups. |
| M14 | Added the headless FlowSpec/RuleRegistry coverage dump tool. |
| M15 | Promoted RuleRegistry guidance into project instructions and architecture skills; cleaned implementation-plan open topics. |

## Closing Baseline

- Full GUT: 163 scripts / 3 096 tests / 6 209 asserts / 0 failures.
- Phase K lint: 0 violations / 4 allow-listed branches.
- Baseline traces: hot-seat trace/state pass and real ENet host/client state equality pass.
- Diff check: `git diff --check` clean, including the new archive file.
- Successor: resume G4.7 Spectator Mode, then G4.8 Reconnection runtime, G4.9 Turn Timers, and Phase 10c.

## Lasting Rules

- FlowSpec owns which steps exist and who controls them.
- RuleRegistry owns static hook definitions and deterministic ordering.
- Active rule state comes from serialized GameState entities or documented transient bridges rebuilt from serialized state.
- New rules go through `src/core/effects/rules/` and `RuleBootstrap` unless the user explicitly approves a temporary legacy bridge.