# Codex Architecture Workflow

This workflow defines how future Codex sessions should operate during the
architecture migration period.

It is not an architecture decision and does not replace ADRs, contracts, or
tests.

## Identifier System

Use these IDs in architecture-sensitive work:

| Prefix | Meaning |
| --- | --- |
| `RG-xxx` | Reality Gap |
| `BC-xxx` | Boundary Candidate |
| `AT-xxx` | Architecture Task |
| `ADR-xxx` | Architecture Decision |
| `CP-xxx` | Context Pack |
| `CON-xxx` | Contract |
| `TEST-xxx` | Test Strategy |

All new architecture docs should reference applicable IDs. If a change touches
an unresolved boundary, reference its `BC-xxx` and related `RG-xxx` IDs in the
work summary.

## Workflow for Architecture-Sensitive Changes

For every architecture-sensitive change:

1. Identify affected architecture areas and boundary candidates.
2. Check `docs/architecture/ARCHITECTURE_ROADMAP.md`.
3. Identify related architecture tasks.
4. Check accepted ADRs for the topic.
5. Check contracts for behavioral invariants.
6. Check context packs for current implementation evidence.
7. Check `docs/REALITY_GAP_REGISTER.md`.
8. Decide whether the work is safe, needs owner decision, needs tests, or needs
   a new architecture task.

Architecture-sensitive changes include:

- Changes to `GameState`, command execution, command applicability, or
  serialized payloads.
- Changes to `InteractionFlow`, `FlowSpec`, `UIProjector`, modal authority, or
  attack/setup flow state.
- Changes affecting save/load, replay, network sync, filtered state snapshots,
  deterministic RNG, or command history.
- New rule behavior, upgrades, objectives, obstacles, tokens, ship rules, or
  squadron special rules.
- New responsibilities in `GameManager`, `EventBus`, autoload services, or
  scene controllers that affect durable state.

## Decision Outcomes

After checking the roadmap and authority rules, classify the work:

| Outcome | Codex behavior |
| --- | --- |
| Safe | Proceed using accepted ADRs/contracts and existing local patterns. |
| Needs owner decision | Stop before implementation and ask for direction. |
| Needs tests | Add or propose focused tests before changing behavior. |
| Needs context pack | Gather current implementation and documentation evidence first. |
| Needs architecture task | Add a proposed `AT-xxx` only when requested, or report the need. |
| Tolerate temporarily | Keep changes local; do not spread the tolerated pattern. |

## When Code Conflicts With Documentation

1. Check whether the conflict is listed in `REALITY_GAP_REGISTER.md`.
2. Check whether an accepted ADR or contract resolves it.
3. If resolved, follow the accepted ADR or contract.
4. If unresolved, do not assume either side is correct.
5. For non-architecture feature work, preserve current local behavior without
   expanding the conflicting pattern.
6. For architecture-sensitive work, stop and request owner guidance.

## When Multiple Documents Disagree

Use this authority order for the affected topic:

1. Accepted contract.
2. Accepted ADR.
3. Architecture roadmap status and task dependencies.
4. Current-state architecture map for observed implementation.
5. Reality gap register and boundary candidates for unresolved discrepancies.
6. Arc42 and historical docs for intended or historical architecture.
7. Existing Copilot instructions and skills, unless superseded above.

If the authority order still does not produce a clear answer, ask the owner.

## When a Feature Touches an Unresolved Area

- If the feature touches `BC-001`, `BC-003`, `BC-005`, `BC-005A`, `BC-006`,
  `BC-007`, `BC-008`, or `BC-009`, check the related `AT-xxx` task first.
- Do not add new direct durable state mutation paths while `AT-001` and
  `AT-002` are unresolved.
- Do not add new behavior-changing rules without checking `AT-003` and
  `AT-004`.
- Do not add new `GameManager` responsibility categories without checking
  `AT-006`.
- Do not rely on stale Arc42 paths, counts, or component names when current code
  evidence disagrees.

## Safe Defaults

- Prefer narrowly scoped feature work in stable or well-contained areas.
- Keep UI previews transient unless a contract says otherwise.
- Keep serialized payloads JSON-safe.
- Prefer existing command, setup, save/load, replay, and network patterns over
  inventing new patterns.
- When in doubt, document the uncertainty and ask before implementing.

