# BUG-038: Voluntary Anti-Squadron Child-Finish Implementation Workbook

Status: Accepted; Implementation-ready, requirements fixed; not an authorization to
implement beyond this workbook

Accepted by: Project Owner
Accepted date: 2026-08-23

Purpose: repair only the BUG-038 routing that maps a voluntary, non-exhausted
anti-squadron child finish onto the ordinary whole-Ship-Attack declaration
Skip. No production code or tests are changed by this workbook.

## 1. Authority, Classification, And Fixed Semantics

Classification: **Bounded Architecture**. The accepted requirements distinguish
the affected child and parent semantics, the accepted contracts retain their
owners, and the current code seam is contained.

Binding authority, in precedence order:

- [CON-007](../contracts/CON-007-post-attack-continuation-release-contract.md),
  especially BOUNDARY-004/005, RELEASE-004, SEAM-001–005, XO-001–004, and
  DIST-001–005;
- [CON-006](../contracts/CON-006-attack-declaration-lifecycle-contract.md),
  especially the Ship declaration-Skip matrix and SKIP-001–011;
- accepted Ship Activation owner decision
  [D-SA-050–052](../../requirements/gameplay_interactions/ship_activation_interaction_owner_decisions.md);
- [ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md)
  and [ADR-007](../adr/ADR-007-purpose-specific-completed-attack-result-inspection-lifecycle.md);
- the completed BUG-038 requirements/semantics audit supplied with this task;
  and
- current implementation evidence in `SkipAttackCommand`,
  `CurrentAttackContinuation`, `GameManager`, `AttackExecutor`, and
  `AttackPanelController`.

The following requirements are fixed:

1. Abandoning an uncommitted individual candidate, voluntarily ending a
   non-exhausted anti-squadron sequence, and voluntarily ending the enclosing
   remaining Ship Attack opportunity are different semantics.
2. BUG-038 is the second semantic only. It closes the current anti-squadron
   child iteration, retains committed attack count and used hull-zone history,
   and re-evaluates the enclosing Ship Attack opportunity.
3. Ordinary ship-context `SkipAttackCommand(reason: voluntary)` is case 3. It
   remains the whole-Ship-Attack voluntary finish and is not changed.
4. `SkipAttackCommand(reason: squadron_done)` is exhausted child termination.
   Its no-remaining-target guard and semantics are not broadened.
5. Child completion does not itself complete Ship Attack. The existing
   `CommandProcessor` live-authority seam re-evaluates the applicable existing
   Ship Attack owner to a stable outcome.

## 2. Evidence And Root Implementation Seam

The voluntary control is exposed by
`AttackExecutor._on_attack_skip()` while the recovered inactive Step 6
anti-squadron declaration is target-selecting and the locked zone still has an
untargeted legal squadron. The current BUG-035 working-tree routing checks
whether targets remain, but routes the non-exhausted case to:

```text
AttackExecutor._on_attack_skip()
→ GameManager.submit_skip_attack(player, "voluntary")
→ GameManager._declaration_identity_for_player()
→ SkipAttackCommand(declaration_context: ship_attack, reason: voluntary)
→ _execute_ship_declaration_skip()
→ ShipInstance.open_maneuver_opportunity() + end_attack_step()
→ Maneuver OPEN
```

That is correctly the existing whole-Ship-Attack Skip transaction under
CON-006, but is too broad for BUG-038. It explains the observed state:
inactive `CurrentAttackState`, only one committed/used hull zone, inactive
Ship Attack step, and Maneuver `OPEN`.

The existing exhausted path is different:

```text
SkipAttackCommand(reason: squadron_done)
→ ShipInstance.end_anti_squadron_attack()
→ atomically consume matching satisfied inspection
→ CurrentAttackContinuation._derive_post_squadron_done_ship_return()
→ no command for a legal remaining Ship Attack, otherwise existing
  AdvanceActivationStepCommand(maneuver_step)
```

`ShipInstance` remains the canonical owner of child iteration facts and Ship
Attack facts. `SkipAttackCommand` is the existing authoritative transaction
family that commits an anti-squadron iteration close. `CurrentAttackContinuation`
in the `CommandProcessor` post-success seam is the sole live-authority
evaluator that may then select the already-existing parent transition.

## 3. Selected Transaction Strategy

No existing transaction can express voluntary *non-exhausted* child-only
termination without semantic overloading:

- ordinary `reason: voluntary` with `declaration_context: ship_attack` commits
  the parent Ship Attack opportunity and calls `end_attack_step()`;
- `reason: squadron_done` is intentionally invalid while a legal untargeted
  squadron remains; and
- `AdvanceActivationStepCommand(maneuver_step)` is the parent transition, not
  a child close.

The smallest necessary purpose-specific change is a **new, explicitly named
child-termination reason/payload variant on the existing
`SkipAttackCommand`**, for example `anti_squadron_voluntary_done`. This is not
a new command class, owner, state field, generic continuation mechanism, or
Ship-level declaration Skip variant. The final literal must be selected once
and used consistently by command validation, execution, routing, and tests.

Its required transaction is:

```text
validated voluntary child-finish Skip
→ validate active ship Attack step, locked anti-squadron zone, stable ship
  identity, matching satisfied completed-result inspection, and controller
  authorization through `command.player_index` plus the existing canonical
  inspection/controller/ownership validation
→ do not require target exhaustion
→ atomically end_anti_squadron_attack() and consume that inspection
→ retain attack_step_active, committed_attack_count, and used hull zones
→ command-processor bounded re-evaluation of Ship Attack
   ├─ remaining legal declaration: no synthetic command; recover declaration
   └─ none: existing AdvanceActivationStepCommand(maneuver_step), once
```

Validation must bind the inspection attacker/defender to the active ship and
anti-squadron child context, as `squadron_done` already does. It must also
reject stale/duplicate/wrong-player/wrong-ship child-finish requests without
mutation. It deliberately differs only in the target-exhaustion predicate:
the new voluntary child reason requires no such predicate, while
`squadron_done` retains `_has_remaining_squadron_target()` rejection.

The existing post-`squadron_done` Ship return helper should be generalized
only as a *private shared evaluation of two explicit child-termination
reasons*, not as a generic continuation facility. It re-derives legal normal
or different-unused-zone declarations with `TargetingListBuilder`; it returns
no command for a live declaration and selects the existing Maneuver transition
only when none exists.

## 4. Authorized Scope

| File | Authorized bounded change |
| --- | --- |
| `src/core/commands/skip_attack_command.gd` | Add the explicit voluntary non-exhausted anti-squadron child-finish variant, validation, atomic child close/inspection consumption, rollback, and result identity. Keep `squadron_done` and Ship declaration Skip branches semantically unchanged. |
| `src/core/state/current_attack_continuation.gd` | Recognize the new explicit child termination alongside `squadron_done` and use the existing bounded Ship Attack re-evaluation. No new owner or generic continuation abstraction. |
| `src/autoload/game_manager.gd` | Decorate and submit the child-finish variant with stable `ship_index` and satisfied inspection identity; do not derive Ship declaration identity for it. Preserve normal voluntary declaration-Skip submission. |
| `src/scenes/game_board/attack_executor.gd` | At the recovered locked-zone, target-selecting, non-exhausted child decision, submit only the new child-finish variant. Preserve the existing exhausted `squadron_done` branch and ordinary whole-Ship voluntary route elsewhere. Adjust existing pending-result/rejection presentation bookkeeping only as required for that result. |
| `src/scenes/game_board/attack_panel_controller.gd` | Treat the new child-finish result like the existing child-close presentation handoff: wait for processor re-evaluation, then re-derive a remaining Ship Attack declaration only when canonical state proves one. No presentation-side legality or command submission. |
| `tests/unit/test_attack_commands.gd` | Add focused command atomicity/validation/serialization/exact-once coverage for the new variant; retain existing `squadron_done` tests unchanged. |
| `tests/integration/test_current_attack_production_resume.gd` | Replace the BUG-035-era broad-Ship-Skip expectation with BUG-038 stable-outcome coverage below, using the existing real-board recovered fixtures where possible. |

Not authorized: changes to `ShipInstance`, `GameState`, `CurrentAttackState`,
`AdvanceActivationStepCommand`, ordinary Ship declaration Skip semantics,
`squadron_done` semantics, contracts, requirements, ADRs, save schema,
network protocol shape beyond the normal serialized command payload, or a
generic continuation/interaction-state mechanism. Preserve the pre-existing
dirty BUG-035 candidate edits except for the narrow routing correction this
workbook expressly requires.

## 5. Required Regressions And Stable Outcomes

Use authoritative command history plus canonical state; do not infer outcomes
from panel visibility alone. Each child-finish regression must assert no second
`BeginAttackCommand` before the chosen outcome, exactly one accepted new
child-finish Skip, exactly one `ShipInstance.end_anti_squadron_attack()`
mutation (via canonical result/history instrumentation already used by tests),
and exactly one consumption of the matching completed-result inspection.

| Case | Required authoritative assertions and stable outcome |
| --- | --- |
| A. Voluntary non-exhausted finish; legal enclosing Ship Attack remains | Start after a completed anti-squadron child, acknowledged/satisfied inspection, locked zone, and an untargeted legal squadron plus a legal different unused hull-zone Ship Attack. Submit/select the new child-finish reason before a second Begin. Assert child zone/history are cleared once; `attack_step_active` stays true; committed count and used zone remain unchanged; `squadron_done` count is zero; ordinary ship `voluntary` Skip count is zero; `advance_activation_step(maneuver_step)` count is zero; inspection is consumed once; and canonical recovery exposes a legal Ship declaration. Confirm a recoverable legal Ship Attack from a different unused hull zone can then be declared by the ordinary Begin path. |
| B. Voluntary non-exhausted finish; no legal enclosing Ship Attack remains | Same child precondition with an untargeted legal squadron, but arrange no legal remaining Ship declaration after child close. Assert exactly one new child-finish Skip and exactly one existing `AdvanceActivationStepCommand(maneuver_step)`; no ordinary Ship-level `voluntary` Skip and no `squadron_done`; child closure once; inactive `CurrentAttackState`; inspection consumed once; Attack step ends only through the existing Maneuver transaction; Maneuver disposition is `OPEN`; interaction flow is Maneuver; and no stale attack presentation remains. |
| C. Exhausted anti-squadron termination | Preserve the current `squadron_done` fixture and assertions. With no legal untargeted squadron, it accepts exactly once, closes only the child, consumes the matching inspection atomically, and re-evaluates Ship Attack. With a remaining Ship declaration it emits no Maneuver command and that declaration is recoverable; with none it emits exactly one Maneuver transition. A forged `squadron_done` while a target remains remains rejected and leaves all canonical state/inspection unchanged. |
| D. Choose another anti-squadron target | From the same non-exhausted recovered choice, select the other legal squadron and confirm. Assert the existing second `BeginAttackCommand` path remains unchanged: one accepted Begin, active `CurrentAttackState` for that target, no child-finish Skip of either reason, no ordinary Ship voluntary Skip, no premature Maneuver transition, and target history retains correct locked-zone semantics. |

Add direct command-origin assertions for the new variant: `command.player_index`
matches the authoritative controller through the existing canonical
inspection/controller/ownership validation; `reason`, `ship_index`, and the
matching `completed_attack_inspection_id` are present; and it has no
`declaration_context: ship_attack`. The payload deliberately carries no
controller field. The whole-Ship voluntary case still carries
`reason: voluntary` and `declaration_context: ship_attack`.
Duplicate, stale, reordered, wrong-player, wrong-ship, and wrong-inspection
submissions must reject without consuming the inspection or closing either
child or parent. A second application after success must not re-close the
iteration or enqueue a second Maneuver transition.

## 6. Replay, Mirror, Save/Load, And Reconnect

The new variant is a normal persisted, replayable, exactly-once authoritative
command. Its serialized payload is limited to existing identity forms (reason,
ship index, and completed-inspection id); no continuation descriptor or new
canonical field is permitted.

- Live authority alone originates the child-finish command and the bounded
  follow-up evaluation in `CommandProcessor`.
- Replay applies recorded child-finish and any recorded Maneuver transition in
  history order; it must not synthesize either follow-up.
- Passive network mirrors apply ordered commands and project their results;
  they never derive or submit child closure, Ship continuation, or Maneuver.
- Save/load and reconnect restore the canonical ship progress and inspection
  before projection. A satisfied unconsumed inspection may be evaluated only
  through the existing authoritative seam. After the child command is already
  recorded/applied, recovery derives the remaining declaration from canonical
  state and never repeats its mutation.

`tests/integration/test_current_attack_production_resume.gd` SHALL add focused
distribution/reconstruction coverage for the new
`anti_squadron_voluntary_done` reason, using the authorized recovered fixtures
where possible:

- **Case A — enclosing Ship Attack remains:** live authority originates exactly
  one child-finish command; passive mirrors synthesize neither it nor a
  follow-up; replay applies recorded history only; and save/load or reconnect
  re-derives the same live, recoverable enclosing Ship Attack declaration from
  canonical state.
- **Case B — no enclosing Ship Attack remains:** host/live authority originates
  exactly one child-finish command and the existing Maneuver follow-up exactly
  once; passive mirrors synthesize neither command; replay applies the
  recorded transitions only; and save/load/reconnect converges from canonical
  state to Maneuver `OPEN`.

Existing exhausted-iteration (`squadron_done`) distribution tests are
supporting evidence only. They SHALL NOT substitute for coverage of the new
`anti_squadron_voluntary_done` reason.

## 7. Implementation Stop Gates

Stop and request Owner guidance rather than improvise if evidence requires any
of the following:

- changing the accepted three-way gameplay distinction;
- accepting `squadron_done` while a target remains or otherwise broadening it;
- changing ordinary Ship-context voluntary Skip or its Maneuver result;
- new canonical state, serialized continuation data, a new owner, or an
  interaction hierarchy model;
- a generic continuation command, queue, descriptor, FSM, controller, or
  generic interaction state; or
- a material production/test-file expansion beyond Section 4 or any unrelated
  BUG-035 reconstruction/convergence rewrite.

Current stop-gate status: **clear for the bounded strategy above**. The
accepted semantic finding and existing canonical owners support it; no Owner
decision is needed. Any failure of the proposed explicit child variant to fit
the existing `SkipAttackCommand` atomic/identity model re-opens the stop gate,
rather than authorizing an alternate architecture.

## 8. Verification Before Handoff

This workbook was verified by reading the applicable accepted requirements and
contracts, the existing BUG-035 workbook as scope-preservation evidence, and
the current command, continuation, submission, projection, state-owner, and
focused test seams. No production code, tests, or commits were created.

Implementation verification must run the focused unit and integration suites
named in Section 4, the existing replay/mirror/reconstruction coverage for
the continuation seam, repository formatting/static checks customarily used
for these GDScript files, and `git diff --check`. Manual Hot-Seat verification
must execute both Case A and Case B with a real recovered anti-squadron child
decision.
