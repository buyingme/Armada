Status: Accepted
Purpose: Migration Assessment
Consumer: Grand Moff Tarkin
Authority:
- ADR-005
- CON-005
- TEST-003

## Purpose

This document records the initial CON-005 compliance assessment of the current
Grand Moff Tarkin implementation.

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

- normal startup/authority documents

Timing-window authority and capability documents reviewed:

- required TIM/ADR/CON/TEST/CAP set
- ADR-005
- CON-005
- TEST-003
- CAP-UPG-001

Evidence scope inspected:

- Tarkin runtime surfaces
- Tarkin command surfaces
- flow and projection surfaces
- save/load surfaces
- replay surfaces
- reconnect surfaces
- network surfaces
- modal surfaces
- Tarkin tests

## Overall Assessment

Tarkin compliance score: **6.0 / 10**

Tarkin is stronger than ECM as a local legacy implementation: it has explicit
command history, good validation, public projection, save/load, reconnect,
replay, modal, and network-ordering evidence. It is still **not CON-005
compliant** because the timing-window lifecycle is owned by `InteractionFlow`,
`AdvancePhaseCommand`, and `TarkinChoiceCommand`, not by `TimingWindowState`
plus `TimingWindowOrchestrator`.

## CON-005 Compliance Matrix

| Area | Classification | Evidence |
|---|---:|---|
| 1. TimingWindowState ownership | Non-Compliant | `GameState` owns `interaction_flow`, not `TimingWindowState`: [game_state.gd:34](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:34), [game_state.gd:150](/Users/Katharina/godot/Armada/src/core/state/game_state.gd:150). |
| 2. Lifecycle identity | Non-Compliant | No serialized timing-window lifecycle identity exists. |
| 3. Static timing-window definition ownership | Non-Compliant | Tarkin timing policy is in `AdvancePhaseCommand`, `FlowSpec`, `CommandApplicability`, and rule helper. |
| 4. RuleRegistry participant discovery | Non-Compliant | Tarkin scans runtime upgrades locally: [grand_moff_tarkin.gd:98](/Users/Katharina/godot/Armada/src/core/effects/rules/upgrades/commander/grand_moff_tarkin.gd:98). |
| 5. Opportunity derivation | Partially Compliant | Derived from authoritative runtime upgrade state, but outside orchestrator protocol: [grand_moff_tarkin.gd:15](/Users/Katharina/godot/Armada/src/core/effects/rules/upgrades/commander/grand_moff_tarkin.gd:15). |
| 6. Canonical opportunity identity | Partially Compliant | Uses `runtime_upgrade_id` and owner/source facts, but no CON-005 opportunity record. |
| 7. Controller policy | Partially Compliant | Controller is stored in `InteractionFlow`, not static timing-window policy: [advance_phase_command.gd:77](/Users/Katharina/godot/Armada/src/core/commands/advance_phase_command.gd:77). |
| 8. Explicit Use command | Fully Compliant locally | `TarkinChoiceCommand` records selected command and mutates via replayable command: [tarkin_choice_command.gd:43](/Users/Katharina/godot/Armada/src/core/commands/tarkin_choice_command.gd:43). |
| 9. Explicit Decline command | Fully Compliant locally | Decline is explicit in the same replayable command type: [tarkin_choice_command.gd:46](/Users/Katharina/godot/Armada/src/core/commands/tarkin_choice_command.gd:46). |
| 10. Replayability | Partially Compliant | Command replay works; lifecycle identity and continuation-failure replay do not exist. Test: [test_tarkin_choice_command.gd:261](/Users/Katharina/godot/Armada/tests/unit/test_tarkin_choice_command.gd:261). |
| 11. Continuation derivation | Non-Compliant | `TarkinChoiceCommand` directly enters ship selection: [tarkin_choice_command.gd:53](/Users/Katharina/godot/Armada/src/core/commands/tarkin_choice_command.gd:53), [tarkin_choice_command.gd:103](/Users/Katharina/godot/Armada/src/core/commands/tarkin_choice_command.gd:103). |
| 12. Continuation failure behavior | Non-Compliant | No separate continuation command/failure behavior exists. |
| 13. Cleanup ownership | Partially Compliant | Rule guard ownership is correct, but shared lifecycle cleanup is missing. |
| 14. Cleanup trigger coverage | Partially Compliant | Resolution replaces projection, but CON-005 failure/stale/duplicate cleanup categories are not covered. |
| 15. Projection | Partially Compliant | Projection is derived and routed correctly, but not from shared opportunity records: [ui_projector.gd:110](/Users/Katharina/godot/Armada/src/core/network/ui_projector.gd:110). |
| 16. Visibility | Fully Compliant for current scope | Tarkin is public and tests cover owner/opponent projection: [test_tarkin_choice_command.gd:71](/Users/Katharina/godot/Armada/tests/unit/test_tarkin_choice_command.gd:71). |
| 17. Save/load | Partially Compliant | Runtime upgrade state and prompt payload serialize, but no lifecycle identity. |
| 18. Replay | Partially Compliant | Choice/grant replay exists; CON-005 lifecycle replay obligations do not. |
| 19. Reconnect | Partially Compliant | Prompt projection survives serialized state, but no `TimingWindowState`: [test_tarkin_choice_command.gd:279](/Users/Katharina/godot/Armada/tests/unit/test_tarkin_choice_command.gd:279). |
| 20. Networking invariants | Partially Compliant | Ordering and side effects are tested, but stale-window identity checks are absent: [game_manager.gd:2113](/Users/Katharina/godot/Armada/src/autoload/game_manager.gd:2113). |
| 21. CAP obligations | Partially Compliant | CAP-UPG-001 is Integrated for CON-003/CON-004, but not updated for CON-005 lifecycle identity/evidence. |
| 22. TEST-003 obligations | Partially Compliant | Broad legacy evidence exists; full CON-005 protocol evidence does not. |

## Strengths

- Strong command-owned local behavior: `TarkinChoiceCommand` validates, records
  use/decline, grants tokens, and serializes through command history.
- Runtime upgrade ownership aligns with ADR-004/CON-004: trigger guard and last
  choice live on the source runtime upgrade: [grand_moff_tarkin.gd:65](/Users/Katharina/godot/Armada/src/core/effects/rules/upgrades/commander/grand_moff_tarkin.gd:65).
- Good tests for prompt opening, public projection, wrong-player/wrong-phase
  rejection, duplicate-use rejection, save/load, reconnect, replay, modal
  routing, and network ordering.
- Visibility is cleanly public and does not create authorization.

## Non-Compliant Obligations

Critical:

- No GameState-owned `TimingWindowState`.
- No lifecycle identity for stale-window rejection across save/load, replay,
  reconnect, or network mirror.
- No `TimingWindowOrchestrator`.
- Tarkin command owns continuation into normal ship selection.

Medium:

- Static timing-window policy is outside the shared timing-window module.
- Participant discovery is local instead of RuleRegistry candidate indexing.
- Opportunity identity is implicit, not a canonical CON-005 opportunity record.
- Cleanup/failure coverage does not satisfy CON-005 trigger categories.
- CAP-UPG-001 is not mapped to CON-005/TEST-003 obligations despite being
  Integrated for the earlier slice.

## Legacy Patterns

- Command-owned continuation: `TarkinChoiceCommand._enter_ship_activation()` performs continuation. Violates CON-005 continuation ownership. Migration objective: move completion/continuation decision to orchestrator.
- Local participant discovery: `GrandMoffTarkin._active_sources()` scans runtime upgrades. Violates RuleRegistry-only Version 1 participant discovery. Migration objective: use RuleRegistry as static candidate index.
- Implicit lifecycle ownership: `InteractionFlow` carries prompt identity/payload. Violates dedicated `TimingWindowState`. Migration objective: use serialized lifecycle state.
- Duplicated controller/timing policy: controller appears in `AdvancePhaseCommand`, `FlowSpec`, `CommandApplicability`, and command validation. Migration objective: consolidate under static definition plus orchestrator.
- Timing-window policy outside shared module: opening, command allowance, blocking, and continuation are spread across local surfaces.

## Required Migration Work

| Migration objective | Severity | Complexity | Type |
|---|---:|---:|---|
| Add shared lifecycle state for Tarkin timing window | Critical | Large | refactor |
| Route opening/re-derivation/completion through orchestrator | Critical | Large | move/refactor |
| Remove command-owned continuation from `TarkinChoiceCommand` | Critical | Medium | move |
| Add lifecycle identity validation to Tarkin timing-window commands | Critical | Medium | refactor |
| Move static Tarkin timing-window policy to shared static definition | Medium | Medium | consolidate |
| Convert source discovery to RuleRegistry candidate indexing | Medium | Medium | consolidate |
| Add canonical Tarkin opportunity record/identity | Medium | Medium | replace |
| Add CON-005 cleanup/failure/duplicate/stale evidence | Medium | Medium | verify only/refactor |
| Update CAP-UPG-001 with CON-005 and TEST-003 mapping | Medium | Small | verify only |

## Migration Difficulty

Estimated migration difficulty: **Medium-to-Large**. Tarkin is simpler than
ECM because it is a single start-of-Ship-Phase opportunity, but it still needs
the same shared lifecycle infrastructure.

## Risk If Left Unchanged

The current implementation is reliable for the existing Tarkin slice, but it
teaches future rules the wrong lifecycle pattern. The largest risks are
duplicated continuation, stale prompt commands after lifecycle changes, and
inability to coexist correctly with another start-of-Ship-Phase opportunity.

## TEST-003 Assessment

Tarkin **partially satisfies** TEST-003. It has strong
command/projection/replay/network evidence, but it lacks full protocol evidence
for `TimingWindowState`, lifecycle identity, orchestrator re-derivation, shared
continuation, duplicate opportunity fail-closed behavior, invalid registration
handling, and continuation failure.

## Migration Feasibility

**Yes, with significant refactoring.**

No CON-005 ambiguity was discovered. An implementer using CON-005 would know
the current command-owned lifecycle is invalid, but Tarkin still needs
capability-specific migration decisions recorded in the shared static
definition: lifecycle identity inputs, participant key, canonical opportunity
key, and continuation mapping.

### Comparison With ECM

Shared migration work:

- Add `TimingWindowState`, lifecycle identity, orchestrator ownership, static
  timing-window definitions, canonical opportunity records, RuleRegistry
  candidate discovery, stale-window rejection, and TEST-003 evidence.

Tarkin-specific migration work:

- Remove `TarkinChoiceCommand` continuation.
- Handle potential duplicate Tarkin candidates/opportunities deterministically.
- Update an already-Integrated CAP so its status does not imply CON-005
  compliance.

ECM-specific migration work:

- Remove GameManager-owned Status Phase continuation.
- Consolidate multiple ECM ready-cost choices and attack-time ECM paths.
- Preserve ECM-specific pending authorization and ready-cost cleanup semantics.

Shared infrastructure theme:

Both audits point to the same missing shared timing-window lifecycle, not two
independent capability-specific redesigns.

## Recommendation

**Ready for migration planning.**

No additional architecture is required and no CON-005 ambiguity was found.
