# BUG-035: Anti-Squadron Declaration Reconstruction And Composed-Return Convergence Implementation Workbook

Status: Accepted and updated implementation workbook
Accepted by: Project Owner
Accepted date: 2026-08-21
Accepted update date: 2026-08-22

Amendment basis: Owner-directed BUG-035 convergence re-entry, 2026-08-22

Purpose: sole branch-complete implementation specification for the remaining
BUG-035 repair. It preserves the accepted anti-squadron declaration
reconstruction repair and adds only the proven composed-return convergence
repair required by refined CON-007.

Scope: after a completed ship anti-squadron attack is acknowledged, restore a
remaining legal squadron declaration where one exists, then continue an
exhausted anti-squadron iteration through the existing enclosing Ship Attack
owner until a stable outcome. This workbook does not change shared Attack
completion, completed-result ownership, declaration semantics, or Ship
Activation ownership.

## 1. Authority, Problem, And Outcome

Binding authority, in precedence order:

- [CON-007](../contracts/CON-007-post-attack-continuation-release-contract.md);
- [CON-006](../contracts/CON-006-attack-declaration-lifecycle-contract.md);
- [ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md);
- [ADR-007](../adr/ADR-007-purpose-specific-completed-attack-result-inspection-lifecycle.md);
- [ADR-010](../adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md);
- accepted [ODR-001](../decision_workbooks/ODR-001-composed-return-convergence-principle.md);
- accepted [ODR-002](../decision_workbooks/ODR-002-CON-007-composed-return-convergence-contract-refinement-workbook.md); and
- accepted [Ship Activation interaction requirements](../../requirements/gameplay_interactions/ship_activation_interaction.md), especially SAI-001 and SAI-050.

Implementation evidence includes the BUG-035 issue history and latest manual
reproduction, the current pre-existing dirty BUG-035 working tree, and the
2026-08-22 convergence re-entry audit.

BUG-035 is an implementation defect against those authorities. The accepted
diagnosis and required result are:

| Boundary | Established evidence | Defect disposition |
| --- | --- | --- |
| Canonical gameplay state | Completion retires `CurrentAttackState`; the inspection records acknowledgement state; the active ship retains Attack-step state, locked anti-squadron zone/history, used hull zones, activation identity, and Maneuver disposition. | Sufficient; do not add state. |
| Continuation / release | With an untargeted legal squadron, `CurrentAttackContinuation` returns no command. | Correct CON-007 derived-only outcome. |
| Derived declaration opportunity | Remaining legal target is derived from canonical targeting and history. | Present. |
| Target selection | A remaining squadron can be selected. | Present. |
| Declaration reconstruction | The current `attack_executor.gd` repair rebuilds the ordinary declaration surface, allowing selection → declaration Confirm → second `BeginAttackCommand`. | Valid pre-existing candidate implementation; preserve unless concrete evidence proves it invalid. |
| Exhausted anti-squadron iteration | `SkipAttackCommand(reason: squadron_done)` ends the iteration and atomically consumes the matching inspection. | Correct child transaction; it does not complete Ship Attack. |
| Enclosing Ship Attack return | After `squadron_done`, the existing continuation evaluation stops because inspection-driven release has ended. | Remaining BUG-035 convergence defect. |

The already-working path is not reopened or redesigned:

```text
completed anti-squadron Attack
→ acknowledgement / derived-only release
→ remaining-target declaration presentation
→ select legal remaining squadron
→ existing declaration Confirm
→ existing BeginAttackCommand
→ next authoritative CurrentAttackState
```

## 2. Required Branch-Complete Behavior

### 2.1 Remaining anti-squadron target

After acknowledgement, where the locked zone has an eligible squadron not in
`ShipInstance` target history:

1. Retain the satisfied inspection and synthesize no command merely to expose
   the next choice.
2. Reconstruct the locked-zone target decision from canonical state; exclude
   historic targets and ships.
3. A selected legal squadron uses the ordinary authoritative candidate query,
   existing declaration Confirm, and exactly one accepted `BeginAttackCommand`.
4. The resulting next active `CurrentAttackState` remains the terminal proof
   for this child declaration path, but not for the whole anti-squadron matrix.

### 2.2 Exhausted iteration with a normal Ship Attack remaining

```text
SkipAttackCommand(reason: squadron_done)
→ anti-squadron iteration ends
→ enclosing Ship Attack re-evaluates from ShipInstance state
→ no synthetic gameplay command
→ legal normal Ship Attack declaration is recoverable
→ stable live decision
```

`squadron_done` remains child iteration termination only. It does not advance
Ship Activation, and a derived normal declaration must not be represented by a
no-op or generic continuation command.

### 2.3 Exhausted iteration with no Ship Attack remaining

```text
SkipAttackCommand(reason: squadron_done)
→ anti-squadron iteration ends
→ enclosing Ship Attack re-evaluates from ShipInstance state
→ existing AdvanceActivationStepCommand(maneuver_step) executes exactly once
→ Maneuver opportunity becomes OPEN
→ stable live decision
```

The existing `AdvanceActivationStepCommand` owns the Ship Attack-to-Maneuver
mutation. `squadron_done` must neither substitute for it nor directly advance
the ship.

## 3. Concrete Evidence And Repair Seam

### Remaining composed-return seam

`CurrentAttackContinuation._derive_ship_inspection_release()` correctly
returns no command while a legal anti-squadron target remains and selects the
existing `SkipAttackCommand(reason: squadron_done)` only when exhausted.

The residual seam begins after that accepted Skip. The command correctly ends
the anti-squadron iteration and consumes the inspection atomically. Canonical
Ship Attack state is still sufficient, but
`CurrentAttackContinuation._derive_followup()` sees an inactive attack and a
consumed inspection, ends inspection-driven release evaluation, and returns no
enclosing Ship Attack result. The applicable existing owner is therefore never
re-evaluated to a stable outcome.

The repair shall make the existing live-authority `CommandProcessor`
post-success seam perform bounded re-evaluation through the existing Ship
Attack owner. It shall select only the already-applicable
`AdvanceActivationStepCommand(maneuver_step)` when automatic mutation is
required; it shall select no command for a derived normal declaration.

### Confirmed presentation handoff

`AttackPanelController.react_to_command()` receives
`AcknowledgeAttackResultCommand` and calls
`_recover_satisfied_ship_attack_presentation()`. That calls
`AttackExecutor.resume_inactive_ship_attack_continuation()`.

For an anti-squadron continuation, `AttackExecutor` restores `ATTACK_DECLARE`,
initializes existing ship execution state, synchronizes locked zone/history,
wires the existing panel signals, enters locked-zone target selection, and
shows the next-squadron prompt in `_render_inactive_ship_continuation()`.

`TargetSelector._handle_target_squadron_click()` uses
`_resolve_authoritative_anti_squadron_candidate()`, which delegates to
`TargetingListBuilder.authoritative_attack_entry()`. For an accepted target,
`_update_los_overlay_and_panel()` is the normal declaration seam: it creates
the transient candidate and calls `AttackSimPanel.show_declaration_confirm_button()`.
The connected `declaration_confirm_pressed` signal reaches
`AttackExecutor._on_declaration_confirm()`, which submits `BeginAttackCommand`.

BUG-035 proves that this reconstructed handoff reaches selectable target state
but not the actionable Confirm-to-Begin interaction. Fresh declaration entry
through `start_ship_attack()` establishes the same selector/panel/signal and
candidate lifecycle successfully. The repair must make the reconstructed path
equivalent, not invent a second lifecycle.

The existing derived-decision presentation bridge may reconstruct a normal Ship
Attack declaration only after semantic evaluation establishes it. Presentation
must not decide legal Ship Attack continuation or submit a progression
transaction.

## 4. Authorized Scope

| File | Authorized boundary | Permitted change |
| --- | --- | --- |
| `src/scenes/game_board/attack_executor.gd` | Existing inactive ship declaration reconstruction | Preserve the current pre-existing panel/signal repair. Do not redesign it unless new concrete evidence invalidates it. |
| `src/core/state/current_attack_continuation.gd` | Existing post-success release derivation | Add only the bounded post-`squadron_done` Ship Attack re-evaluation needed for Sections 2.2 and 2.3, using existing canonical facts and transactions. |
| Existing derived-decision presentation bridge, only if proved necessary | Projection of the Section 2.2 normal declaration | Reconstruct the canonical derived choice without semantic mutation or command submission. Do not pre-authorize unrelated controllers or target-selection code. |
| `tests/integration/test_current_attack_production_resume.gd` and directly applicable existing BUG-035 tests | Stable-outcome regression coverage | Extend assertions and add only focused branch fixtures needed by Sections 2 and 5. |

`src/autoload/command_processor.gd` is not pre-authorized. It may be changed
only if implementation evidence proves that the existing post-success seam
cannot invoke the bounded evaluation through `CurrentAttackContinuation`.

Not authorized: `GameState`, command classes, Ship Activation state/commands,
`CurrentAttackState`, contracts, ADRs, requirements, generic continuation
infrastructure, or unrelated presentation/controller code. A material
production-file expansion beyond this table is a stop.

The current dirty BUG-035 changes are pre-existing candidate implementation
work, not a baseline to reset. Implementation shall distinguish preserved valid
changes, newly authorized changes, and unrelated/pre-existing evidence files;
it shall not revert, stash, rewrite, or otherwise disturb them merely to make a
clean baseline.

## 5. Stable-Outcome Regression Acceptance

Extend the real-GameBoard Hot-Seat coverage in
`test_current_attack_production_resume.gd`, adjacent to the current
post-acknowledgement anti-squadron tests. Reuse
`_satisfied_inactive_anti_state(true)`, `GameManager.start_new_game_from_state`,
board token helpers, and `AcknowledgeAttackResultCommand` where applicable.

The existing remaining-target real-GameBoard regression SHALL retain its proof
of history exclusion, ordinary declaration Confirm, and exactly one second
`BeginAttackCommand`. It shall be paired with or extended through the
appropriate stable outcome after that attack resolves: either another
recoverable legal decision or the required enclosing automatic transition.

Intermediate assertions remain required evidence but are never sufficient as a
terminal assertion: inspection consumption, consumer execution, modal closure,
selector dismissal, and iteration clearing do not independently prove refined
CON-007 convergence.

The remaining-target portion SHALL:

1. install first-completed anti-squadron state with a locked FRONT zone,
   history, pending inspection, and a distinct remaining target;
2. acknowledge through the real command path;
3. prove the inspection remains satisfied, `CurrentAttackState` inactive, and
   no `SkipAttackCommand` is synthesized;
4. reject the historic target and accept the distinct remaining squadron;
5. assert a complete transient declaration candidate for that squadron and an
   enabled **declaration** Confirm (not result acknowledgement or dice Confirm);
6. emit that control's production signal/path and prove exactly one accepted
   `BeginAttackCommand`;
7. prove the next active `CurrentAttackState` has the ship attacker, locked
   FRONT zone, selected remaining squadron, and authoritative range/pool; and
8. prove the earlier inspection was consumed only by accepted Begin and that
   no unrelated continuation command was introduced.

The exhausted-iteration regression shall retain exactly-one `squadron_done` and
atomic inspection-consumption assertions, then prove both distinct post-child
outcomes:

1. exhausted iteration with a legal normal Ship Attack: no synthetic command,
   recovered legal normal declaration, and a controller-actionable stable
   decision;
2. exhausted iteration with no legal Ship Attack: one existing Maneuver-step
   transition, Maneuver `OPEN`, and no further immediate required transition.

Focused tests shall also prove exact-once behavior: no duplicate Skip,
`AdvanceActivationStepCommand`, Begin, or inspection consumption.

## 6. Invariants And Prohibited Fixes

Do not:

- add a continuation owner, descriptor, queue, FSM, generic framework, or a
  synthetic command merely to reopen UI;
- make controller, modal, callback, scene, or panel state authoritative;
- duplicate legality outside `TargetingListBuilder` / `BeginAttackCommand`;
- bypass Begin, directly mutate `CurrentAttackState` from UI, or make
  acknowledgement advance Ship Activation;
- consume the inspection for a derived remaining target or weaken the exactly
  one exhausted-iteration `squadron_done` consumer;
- redesign shared Attack Flow, introduce caller-specific completion
  architecture, or broaden into Squadron Phase / unrelated Attack work.

## 7. Verification Matrix

### Required automated coverage

Each row must end in either a recoverable live legal decision or authoritative
gameplay with no further immediate required transition.

| Context / branch | Current evidence disposition | Required amendment verification |
| --- | --- | --- |
| Normal ship: legal next declaration | Convergence-complete evidence | Preserve focused recovery assertion; do not rewrite unnecessarily. |
| Normal ship: no declaration | Convergence-complete canonical evidence | Preserve Maneuver `OPEN` and exact-once transition assertion. |
| Ship anti-squadron: legal same-zone target | Valid intermediate evidence | Preserve declaration reconstruction proof and connect it to the applicable stable outcome. |
| Ship anti-squadron: exhausted, normal Ship Attack remains | Must be extended | Add the Section 2.2 recovered-normal-declaration stable assertion. |
| Ship anti-squadron: exhausted, no Ship Attack remains | Must be extended | Add the Section 2.3 exact-once Maneuver `OPEN` stable assertion. |
| Squadron Phase: remaining action / allocation remains | Valid intermediate evidence | Verify the existing owner exposes the live next action or allocation decision. |
| Squadron Phase: terminal allocation/handoff | Convergence-complete evidence | Preserve accepted terminal phase/handoff assertion. |
| Ship-commanded Squadron: remaining action / capacity remains | Valid intermediate evidence | Verify the existing Squadron Command owner exposes the recoverable live choice. |
| Ship-commanded Squadron: terminal command return | Valid intermediate evidence | Verify the existing commanding-ship path reaches its next applicable owner-derived stable state. |

Existing tests that already prove the refined terminal result shall be retained,
not rewritten. Tests that stop at a consumer command, modal state, or child
completion shall be extended only to the nearest required stable outcome.

### Distribution and reconstruction coverage

For every mutating leg:

- only live authority may derive and submit an automatic existing transaction;
- passive network mirrors do not synthesize continuation;
- replay applies accepted recorded commands only;
- save/load and reconnect install canonical state before the same bounded
  canonical re-derivation; and
- derived decisions are not persisted or transmitted as continuation
  descriptors.

Regression coverage shall preserve atomic inspection consumption with the
selected mutating consumer, rejected duplicate/stale behavior, and no
presentation-owned semantic progression.

### Required existing suites

- `tests/integration/test_current_attack_production_resume.gd`
- `tests/integration/test_current_attack_shared_protocol.gd`
- `tests/integration/test_squadron_attack_target_recovery.gd`

Run the full GUT suite, Phase-K architecture lint, and `git diff --check`.
Manual QA remains useful for Hot-Seat remaining-target → second Begin, exhausted
target → one `squadron_done`, and Network confirmation after automated checks.

## 8. Stop Gates And Completion

Stop implementation and request direction rather than improvising if:

1. canonical Ship Attack state is insufficient after `squadron_done`;
2. the existing Ship Attack-to-Maneuver transaction cannot validate from that
   canonical state;
3. a new gameplay command, state owner, or continuation fact is required;
4. a generic continuation mechanism, queue, FSM, or controller is required;
5. accepted CON-007 ownership cannot be preserved; or
6. a material production-file expansion beyond Section 4 is required.

No stop gate is currently triggered.

Completion requires the preserved remaining-target regression, both exhausted
iteration branches, the four-context stable-outcome review, applicable
live/mirror/replay/reconstruction checks, the required suites, applicable
architecture or documentation lint, and `git diff --check` to pass. Manual QA
must cover both terminal anti-squadron branches and confirm no stale attack
presentation remains after their stable outcome.

```text
acknowledge_attack_result → [no synthetic command] → BeginAttackCommand
acknowledge_attack_result → SkipAttackCommand(squadron_done) → derived normal declaration
acknowledge_attack_result → SkipAttackCommand(squadron_done) → AdvanceActivationStepCommand(maneuver_step)
```
