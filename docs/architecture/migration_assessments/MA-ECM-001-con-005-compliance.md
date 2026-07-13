Status: Draft
Purpose: Migration Assessment
Consumer: Electronic Countermeasures
Authority:
- ADR-005
- CON-005
- TEST-003

## Purpose

This document records the initial CON-005 compliance assessment of the current
Electronic Countermeasures implementation.

It establishes the implementation and migration baseline before adoption of the
accepted shared timing-window architecture.

This assessment:

- records current implementation compliance against CON-005;
- identifies legacy implementation patterns;
- records required migration objectives;
- does not redefine architecture;
- does not modify the applicable CAP;
- does not prescribe implementation details.

Authority remains:

- ADR-005 for timing-window architecture;
- CON-005 for implementation obligations;
- TEST-003 for verification obligations.

This document is implementation evidence only.

## Documents And Evidence Reviewed

Startup and authority documents reviewed:

- `AGENTS.md`
- `ARCHITECTURE.md`
- `docs/development/AI_DEVELOPMENT_PRINCIPLES.md`
- `docs/development/AI_DEVELOPMENT_PROCESS.md`
- `.ai/instructions/AI_STARTUP_GUARDRAILS.md`
- `docs/architecture/DOCUMENT_AUTHORITY.md`
- `docs/architecture/ARCHITECTURE_ROADMAP.md`
- `docs/architecture/CODEX_WORKFLOW.md`

Timing-window authority and capability documents reviewed:

- ADR-005
- CON-005
- TEST-003
- CAP-ECM-001

Evidence scope inspected:

- ECM runtime surfaces
- ECM command surfaces
- flow and projection surfaces
- save/load surfaces
- replay surfaces
- network and reconnect surfaces
- modal surfaces
- ECM tests

## Overall Assessment

ECM compliance score: **5.5 / 10**

ECM has strong local implementation evidence for explicit ECM commands,
runtime-upgrade state ownership, validation, replayable command serialization,
projection, save/load, reconnect projection, and network mirror side effects.
It is **not fully CON-005 compliant** because the accepted shared timing-window
architecture is not implemented for ECM: no `TimingWindowState`, no lifecycle
identity, no shared static timing-window definition owner in use, and no
`TimingWindowOrchestrator`.

## CON-005 Compliance Matrix

| Area | Classification | Evidence |
|---|---:|---|
| 1. TimingWindowState ownership | Non-Compliant | `GameState` serializes `interaction_flow`, not `TimingWindowState`: [game_state.gd:151](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:151). |
| 2. Lifecycle identity | Non-Compliant | Commands validate phase/flow/runtime id, but no active lifecycle identity is serialized or checked. |
| 3. Static timing-window definition ownership | Non-Compliant | Policy is spread across `FlowSpec`, ECM helper, `CommandApplicability`, and `GameManager`: [flow_spec.gd:247](/Users/Katharina/godot/Armada/src/core/state/flow_spec.gd:247). |
| 4. RuleRegistry participant discovery | Partially Compliant | ECM registers static enablers, but status ready-cost candidates are locally scanned by ECM helper: [electronic_countermeasures.gd:26](/Users/Katharina/godot/Armada/src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd:26), [electronic_countermeasures.gd:721](/Users/Katharina/godot/Armada/src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd:721). |
| 5. Opportunity derivation | Partially Compliant | Opportunities are derived from runtime state, but not through the orchestrator protocol: [electronic_countermeasures.gd:457](/Users/Katharina/godot/Armada/src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd:457). |
| 6. Canonical opportunity identity | Partially Compliant | Uses `runtime_upgrade_id` and owner/source facts, but no CON-005 canonical opportunity record. |
| 7. Controller policy | Partially Compliant | Owner checks exist in command validation; no window-defined controller policy: [electronic_countermeasures.gd:781](/Users/Katharina/godot/Armada/src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd:781). |
| 8. Explicit Use command | Fully Compliant locally | `use_ecm` and `ready_ecm` are replayable commands: [use_ecm_command.gd:14](/Users/Katharina/godot/Armada/src/core/commands/use_ecm_command.gd:14), [ready_ecm_command.gd:15](/Users/Katharina/godot/Armada/src/core/commands/ready_ecm_command.gd:15). |
| 9. Explicit Decline command | Fully Compliant locally | `decline_ecm` and `decline_ecm_ready` exist: [decline_ecm_command.gd:14](/Users/Katharina/godot/Armada/src/core/commands/decline_ecm_command.gd:14), [decline_ecm_ready_command.gd:14](/Users/Katharina/godot/Armada/src/core/commands/decline_ecm_ready_command.gd:14). |
| 10. Replayability | Partially Compliant | Commands serialize/replay, but lifecycle identity and orchestrator continuation are missing. Tests: [test_ecm_status_ready_cost_command.gd:487](/Users/Katharina/godot/Armada/tests/unit/test_ecm_status_ready_cost_command.gd:487). |
| 11. Continuation derivation | Non-Compliant | `GameManager` synthesizes `start_round` after ECM choices: [game_manager.gd:1308](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:1308), [game_manager.gd:1984](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:1984). |
| 12. Continuation failure behavior | Non-Compliant | No CON-005 failure semantics for failed continuation; local helper simply calls `advance_phase()`. |
| 13. Cleanup ownership | Partially Compliant | Rule state cleanup is replayable through `start_round`, but lifecycle cleanup is not orchestrator-owned: [start_round_command.gd:67](/Users/Katharina/godot/Armada/src/core/commands/start_round_command.gd:67). |
| 14. Cleanup trigger coverage | Partially Compliant | Some local cleanup tests exist; CON-005 failure/identity/duplicate categories are missing. |
| 15. Projection | Partially Compliant | Projection is derived via `UIProjector`/RuleRegistry enablers, but not from shared opportunity records: [ui_projector.gd:355](/Users/Katharina/godot/Armada/src/core/network/ui_projector.gd:355). |
| 16. Visibility | Fully Compliant for current ECM scope | ECM is public; tests cover both owner/opponent projection: [test_ecm_status_ready_cost_command.gd:371](/Users/Katharina/godot/Armada/tests/unit/test_ecm_status_ready_cost_command.gd:371). |
| 17. Save/load | Partially Compliant | Runtime upgrade state and flow serialize; timing-window lifecycle identity does not: [ship_instance.gd:430](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:430). |
| 18. Replay | Partially Compliant | Command replay exists; no lifecycle identity or continuation-failure replay proof. |
| 19. Reconnect | Partially Compliant | Projection reconstructs from filtered state, but no active `TimingWindowState`: [test_ecm_status_ready_cost_command.gd:406](/Users/Katharina/godot/Armada/tests/unit/test_ecm_status_ready_cost_command.gd:406). |
| 20. Networking invariants | Partially Compliant | Ordered mirror handling exists; stale-window identity checks do not: [game_manager.gd:2113](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:2113). |
| 21. CAP obligations | Non-Compliant | CAP is Draft and stale against implementation/CON-005: [CAP-ECM-001-electronic-countermeasures.md:5](/Users/Katharina/godot/Armada/docs/architecture/rule_capability_packages/CAP-ECM-001-electronic-countermeasures.md:5), [CAP-ECM-001-electronic-countermeasures.md:1200](/Users/Katharina/godot/Armada/docs/architecture/rule_capability_packages/CAP-ECM-001-electronic-countermeasures.md:1200). |
| 22. TEST-003 obligations | Partially Compliant | Good legacy tests, but missing full protocol evidence categories required by CON-005. |

## Strengths

- ECM uses explicit replayable use/decline commands for both attack-time and
  Status Phase choices.
- Runtime upgrade mutable state is correctly on the source `ShipInstance`
  runtime upgrade, consistent with ADR-004/CON-004: [ship_instance.gd:525](/Users/Katharina/godot/Armada/src/core/state/ship_instance.gd:525).
- Command validation rejects wrong phase, wrong player, missing source, invalid
  card state, duplicate ready/decline, and missing Repair token.
- Save/load and reconnect tests prove current projection can be reconstructed
  from serialized runtime state.
- Network clients do not locally synthesize ready-cost execution in the tested
  path: [test_ecm_status_ready_cost_command.gd:309](/Users/Katharina/godot/Armada/tests/unit/test_ecm_status_ready_cost_command.gd:309).

## Non-Compliant Obligations

Critical:

- No `TimingWindowState` or lifecycle identity. Blocks full CON-005 compliance
  and stale-window rejection.
- No `TimingWindowOrchestrator`. Lifecycle opening, re-derivation,
  continuation, exact-one continuation, and shared cleanup remain local.
- Continuation is GameManager-owned for Status Phase ECM, not
  orchestrator-owned.

Medium:

- Static timing-window policy is distributed instead of owned by the shared
  timing-window module.
- Participant discovery and opportunity derivation are ECM-local rather than
  RuleRegistry-candidate plus orchestrator-derived.
- Cleanup trigger coverage does not cover all CON-005 failure, duplicate,
  stale identity, and reconstruction cases.
- CAP-ECM-001 is stale and lacks CON-005/TEST-003 evidence mapping.

Low:

- Current ECM visibility is acceptable because the Project Owner accepted
  public visibility, but the evidence should be recorded in CAP-ECM-001 before
  any status advancement.

## Legacy Patterns

- GameManager-owned continuation: `GameManager._maybe_start_round_after_status_ready_cost()` calls `advance_phase()` after local recheck. Violates CON-005 orchestrator/continuation ownership. Migration: move continuation decision to TimingWindowOrchestrator.
- Local participant discovery: `_status_ready_cost_sources()` scans ships/runtime upgrades directly. Violates RuleRegistry-only candidate discovery for Version 1. Migration: consolidate candidate discovery through RuleRegistry static participant indexing.
- Implicit lifecycle ownership: `InteractionFlow` represents the window-like status prompt. Violates dedicated `TimingWindowState` ownership. Migration: replace implicit lifecycle with serialized GameState-owned timing-window lifecycle state.
- Duplicated controller/eligibility logic: owner checks, FlowSpec, CommandApplicability, projection payloads, and ECM helper all contribute. Migration: centralize lifecycle/control policy through static definition plus orchestrator.
- Local cleanup path: ECM helper clears rule guards directly from `StartRoundCommand`/local helper. Partially acceptable for rule-owned state, but missing orchestrator lifecycle cleanup. Migration: preserve rule-owned cleanup command path while adding shared lifecycle cleanup.

## Required Migration Work

| Migration objective | Severity | Complexity | Type |
|---|---:|---:|---|
| Add shared GameState-owned timing-window lifecycle state for ECM windows | Critical | Large | refactor |
| Route ECM lifecycle opening, re-derivation, completion, and continuation through TimingWindowOrchestrator | Critical | Large | move/refactor |
| Replace GameManager-owned `start_round` synthesis with orchestrator-owned continuation | Critical | Medium | move |
| Add lifecycle identity validation to ECM timing-window commands | Critical | Medium | refactor |
| Move static timing-window policy into the shared timing-window module mapping | Medium | Medium | consolidate |
| Convert ECM participant discovery to RuleRegistry candidate indexing plus runtime derivation | Medium | Medium | consolidate |
| Add canonical opportunity records/identity for attack-time and status ready-cost ECM | Medium | Medium | replace |
| Expand cleanup coverage for all CON-005 cleanup triggers | Medium | Medium | verify/refactor |
| Update CAP-ECM-001 to reflect actual implementation and CON-005/TEST-003 evidence | Medium | Small | verify only |
| Add missing TEST-003 evidence for duplicate identity, invalid registration, stale lifecycle identity, continuation failure, replay/network stale-window behavior | Medium | Medium/Large | verify only/refactor |

## Migration Difficulty

Estimated migration difficulty: **Significant refactoring**.

## Risk If Left Unchanged

The current ECM code is serviceable as a local implementation, but it will not
scale safely to 100+ timing-window rules. The main risks are duplicated
continuation logic, stale-window commands crossing save/load/replay/network/
reconnect boundaries, inconsistent participant discovery, and future rules
copying ECM-local orchestration instead of the accepted lifecycle protocol.

## TEST-003 Assessment

ECM does **not** fully satisfy TEST-003. It partially satisfies the command,
projection, save/load, replay-serialization, reconnect projection, and network
side-effect categories, but it lacks full timing-window protocol evidence for
lifecycle identity, orchestrator re-derivation, static definition ownership,
duplicate opportunity fail-closed behavior, invalid registration handling,
continuation failure, and complete cleanup trigger categories.

## Migration Feasibility

**Yes, with significant refactoring.**

## Recommendation

**Ready for migration planning.**

No additional architecture is required and no CON-005 ambiguity was found.
