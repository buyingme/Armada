# BUG-035: Anti-Squadron Declaration Reconstruction And Composed-Return Convergence Implementation Workbook

Status: Accepted and updated implementation workbook
Accepted by: Project Owner
Accepted date: 2026-08-21
Accepted update date: 2026-08-22
Accepted second update date: 2026-08-22

Amendment basis: Owner-directed BUG-035 convergence re-entry and accepted
ship-commanded Squadron terminal route-coverage finding, 2026-08-22

Purpose: sole branch-complete implementation specification for the remaining
BUG-035 repair. It preserves the accepted anti-squadron declaration
reconstruction repair, the implemented Ship Attack composed-return repair, and
adds only the newly proven ship-commanded Squadron terminal convergence slice
required by refined CON-007.

Scope: after a completed ship anti-squadron attack is acknowledged, restore a
remaining legal squadron declaration where one exists, then continue an
exhausted anti-squadron iteration through the existing enclosing Ship Attack
owner until a stable outcome. Also, after a terminal ship-commanded Squadron
Attack, return from the completed squadron activation through existing
Squadron Command and Ship Activation ownership without making presentation
machinery semantic authority. This workbook does not change shared Attack
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
| Ship-commanded Squadron terminal return | `CompleteSquadronActivationCommand` correctly completes the child and restores a Squadron-step projection, but terminal command completion is then inferred by `InteractionFlow` → `ModalRouter` → `ShipActivationController` → scene-local `SquadronCommandResolver`. | Proven CON-007 route gap. Presentation reconstruction may use those facilities; semantic terminal progression may not depend on them. |

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

### 2.4 Ship-commanded Squadron Attack composed return

The child and parent return chain is purpose-specific and bounded:

```text
Squadron Attack completes
→ enclosing Squadron Activation re-evaluates
→ CompleteSquadronActivationCommand when that activation is terminal
→ enclosing Squadron Command re-evaluates canonical remaining capacity and eligibility
→ live command remains: recoverable commanded-squadron decision
→ terminal command: existing authoritative Ship Activation transition
→ enclosing Ship Activation determines its next applicable step
→ stable outcome
```

`CompleteSquadronActivationCommand` remains the existing child completion
transaction. It does not itself advance directly to Repair. Squadron Command
canonically determines only whether its opportunity remains live or is
terminal; it does not mutate Ship Activation or hard-code a successor step.
When terminal, the existing Ship Activation
`AdvanceActivationStepCommand(repair_step)`, validated from the active
`ShipInstance` identity and purpose-specific opportunity facts, performs the
parent mutation and owns the next applicable step.

Presentation reconstruction may use `InteractionFlow`, `ModalRouter`,
controllers, tokens, overlays, and `SquadronCommandResolver` geometry/caches
to expose a stable decision. Those facilities SHALL NOT establish whether
Squadron Command is live or terminal, consume it, finalize resources, or
advance its parent. The current terminal controller/modal route violates this
boundary and is the sole newly authorized repair slice.

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

### Commanded-Squadron terminal seam

The route-coverage audit established that the existing authoritative facts are
sufficient without new state: the commanding `ShipInstance` owns the active
activation identity, Squadron-command opportunity disposition, and committed
activation count; `SquadronCommandResolver.authoritative_capacity(ship)`
derives capacity from those existing game facts. `ActivateSquadronCommand`,
`BeginAttackCommand`, and `CompleteSquadronActivationCommand` already validate
the same commanded-Squadron boundary.

`CompleteSquadronActivationCommand` is the existing terminal child mutation.
`AdvanceActivationStepCommand` is the existing authoritative Ship Activation
transition: its `repair_step` branch consumes the already-open
Squadron-command opportunity and validates that no commanded squadron
activation remains active. The present controller path chooses that existing
transaction only after a scene-local resolver reports terminal state. That is
the defect, not an absence of a command or canonical owner.

`CommandProcessor` remains the sole live-authority post-success
release/convergence seam. Following an accepted ship-commanded
`CompleteSquadronActivationCommand`, its existing deferred post-success path
SHALL invoke one bounded GameManager evaluator. That evaluator SHALL read only
canonical `GameState`/`ShipInstance` facts and existing authoritative
capacity/range queries, and return either no transaction while a legal
commanded-squadron decision remains or the fully identified existing
`AdvanceActivationStepCommand(repair_step)` when Squadron Command is terminal.
`CommandProcessor` alone SHALL enqueue that returned existing transaction
through its established live-authority submission path.

The GameManager evaluator is a purpose-specific canonical query invoked only
from that processor-owned seam. It is not an independent continuation owner,
callback-driven semantic progression path, or owner of Squadron Command or
Ship Activation semantics. It SHALL not use `InteractionFlow`, `ModalRouter`,
scene tokens, `ShipActivationState`, controller state, or
`SquadronCommandResolver` instance caches as semantic inputs.

The repair MUST leave `CurrentAttackContinuation` responsible only for its
previously accepted anti-squadron post-`squadron_done` convergence work and
completed-attack release through `CompleteSquadronActivationCommand`; it has
no role in the newly added commanded-Squadron terminal evaluation.

## 4. Authorized Scope

| File | Authorized boundary | Permitted change |
| --- | --- | --- |
| `src/scenes/game_board/attack_executor.gd` | Existing inactive ship declaration reconstruction | Preserve the current pre-existing panel/signal repair. Do not redesign it unless new concrete evidence invalidates it. |
| `src/core/state/current_attack_continuation.gd` | Existing post-success release derivation | Add only the bounded post-`squadron_done` Ship Attack re-evaluation needed for Sections 2.2 and 2.3, using existing canonical facts and transactions. |
| Existing derived-decision presentation bridge, only if proved necessary | Projection of the Section 2.2 normal declaration | Reconstruct the canonical derived choice without semantic mutation or command submission. Do not pre-authorize unrelated controllers or target-selection code. |
| `src/autoload/command_processor.gd` | Sole CON-007 live-authority post-success seam | Add only the bounded ship-commanded completion hook in its existing deferred post-success path: invoke the GameManager canonical evaluator after an accepted ship-commanded `CompleteSquadronActivationCommand`, and enqueue only its returned existing `AdvanceActivationStepCommand(repair_step)`. No generic continuation, parent-policy, or additional progression semantics are authorized. |
| `src/autoload/game_manager.gd` | Bounded canonical query used by the processor-owned seam | Add only a purpose-specific evaluator invoked from the authorized `CommandProcessor` hook. It derives live-versus-terminal Squadron Command status from existing canonical facts and returns no transaction or the existing fully identified Ship Activation transition; it neither submits nor enqueues a command and remains independent of all presentation inputs. |
| `src/scenes/game_board/ship_activation_controller.gd` | Existing command-mode Squadron projection | Remove or neutralize only the terminal semantic submission/finalization branch that currently follows `InteractionFlow`/modal/controller-local resolver state. Retain derived modal, overlay, and recoverable-choice projection; do not move semantic progression into another controller. |
| `tests/integration/test_current_attack_production_resume.gd` and directly applicable existing BUG-035 tests | Stable-outcome regression coverage | Extend assertions and add only focused branch fixtures needed by Sections 2 and 5. |

Not authorized: `GameState`, `ShipInstance`, command classes, Ship Activation
state/commands, `CurrentAttackState`, contracts, ADRs, requirements, generic
continuation infrastructure, or unrelated presentation/controller code.
`CurrentAttackContinuation` is not authorized except for the previously
accepted narrow BUG-035 convergence changes already specified in this
workbook. `CommandProcessor` is not authorized except for the exact bounded
post-success hook listed in this table. A material production-file expansion
beyond this table is a stop.

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

### Commanded-Squadron terminal regression

Add real production-path coverage adjacent to the existing commanded-Squadron
completed-attack fixtures. The terminal proof is canonical owner state and an
accepted existing semantic transition, never modal closure, resolver
completion, controller callback execution, or Repair-panel visibility.

The capacity-remains branch SHALL prove:

```text
Attack completes
→ completed-result acknowledgement
→ CompleteSquadronActivationCommand exactly once
→ canonical Squadron Command re-evaluation
→ another eligible commanded-squadron decision is recoverable
→ no synthetic parent-progression command
→ stable live decision
```

The capacity-terminal branch SHALL prove:

```text
Attack completes
→ completed-result acknowledgement
→ CompleteSquadronActivationCommand exactly once
→ canonical Squadron Command terminal result
→ existing authoritative Ship Activation transition
  AdvanceActivationStepCommand(repair_step) exactly once
→ Ship Activation re-evaluates its next applicable step
→ stable authoritative outcome
```

Both branches SHALL assert the active ship identity, opportunity disposition,
committed count, authoritative capacity, commanded-squadron activation state,
and command history needed to establish the result. The terminal branch SHALL
prove that the existing Ship Activation transition is accepted from canonical
state and that no immediate further semantic transition is required. It SHALL
not assert Repair as a controller-selected destination.

Coverage SHALL include live authority, passive mirror, replay, and
save/load-or-reconnect reconstruction for every mutating terminal leg. Only
live authority may derive/submit the existing transaction; mirrors and replay
apply the ordered accepted command stream without synthesis; reconstruction
must re-derive from installed canonical state rather than controller or modal
state.

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
- permit `InteractionFlow`, `ModalRouter`, a controller callback, scene token,
  `ShipActivationState`, or `SquadronCommandResolver` instance state to decide
  commanded-Squadron terminality or submit its parent progression; or
- make Squadron Activation advance directly to Repair, make Squadron Command
  hard-code a Ship Activation successor, or bypass the existing Ship
  Activation transition.

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
| Squadron Phase: remaining action / allocation remains | Convergence-complete evidence | Preserve the existing owner live-action/allocation assertion; do not reopen without contrary evidence. |
| Squadron Phase: terminal allocation/handoff | Convergence-complete evidence | Preserve accepted terminal phase/handoff assertion. |
| Ship-commanded Squadron: remaining action / capacity remains | Convergence-complete canonical/recoverable evidence | Preserve the recoverable live choice assertion; no parent-progression command may be synthesized. |
| Ship-commanded Squadron: terminal command return | Incomplete: route audit proved controller/modal-dependent semantic bypass | Add the Section 5 commanded-Squadron terminal stable-outcome regression and remove the bypass before declaring this context convergence-complete. |

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

For the commanded-Squadron terminal leg specifically, presentation recovery
must consume the canonical result after the live-authority transaction; it may
not become the source of that transaction. A passive mirror must not rely on a
local controller or modal to complete the command opportunity.

Regression coverage shall preserve atomic inspection consumption with the
selected mutating consumer, rejected duplicate/stale behavior, and no
presentation-owned semantic progression.

### Required existing suites

- `tests/integration/test_current_attack_production_resume.gd`
- `tests/integration/test_current_attack_shared_protocol.gd`
- `tests/integration/test_squadron_attack_target_recovery.gd`

Run the full GUT suite, Phase-K architecture lint, and `git diff --check`.
Manual QA remains useful for Hot-Seat remaining-target → second Begin, exhausted
target → one `squadron_done`, commanded-Squadron remaining-capacity recovery,
commanded-Squadron terminal return without modal-driven progression, and Network
confirmation after automated checks.

## 8. Stop Gates And Completion

Stop implementation and request direction rather than improvising if:

1. canonical Ship Attack state is insufficient after `squadron_done`;
2. the existing Ship Attack-to-Maneuver transaction cannot validate from that
   canonical state;
3. a new gameplay command, state owner, or continuation fact is required;
4. a generic continuation mechanism, queue, FSM, or controller is required;
5. accepted CON-007 ownership cannot be preserved; or
6. a material production-file expansion beyond Section 4 is required.

For the commanded-Squadron slice, also stop if:

7. Squadron Command terminal/live status cannot be derived from the existing
   canonical commanding-ship and squadron facts;
8. the existing Ship Activation
   `AdvanceActivationStepCommand(repair_step)` cannot validate from that
   terminal canonical state;
9. Ship Activation cannot determine its next applicable step without
   controller transient state; or
10. repair would transfer purpose-specific Squadron Command or Ship Activation
    semantics into `CurrentAttackContinuation` or `CommandProcessor`.

The processor-owned invocation path and authorized file scope above resolve the
two pre-amendment audit gates. No stop gate is currently triggered on the
available route-coverage evidence; implementation SHALL stop if that evidence
is contradicted at the authorized seam.

Completion requires the preserved remaining-target regression, both exhausted
iteration branches, the commanded-Squadron capacity-remains and terminal
stable-outcome branches, the four-context stable-outcome review, applicable
live/mirror/replay/reconstruction checks, the required suites, applicable
architecture or documentation lint, and `git diff --check` to pass. Manual QA
must cover both terminal anti-squadron branches, both commanded-Squadron
branches, and confirm no stale attack presentation remains after their stable
outcome.

```text
acknowledge_attack_result → [no synthetic command] → BeginAttackCommand
acknowledge_attack_result → SkipAttackCommand(squadron_done) → derived normal declaration
acknowledge_attack_result → SkipAttackCommand(squadron_done) → AdvanceActivationStepCommand(maneuver_step)
acknowledge_attack_result → CompleteSquadronActivationCommand → derived commanded-squadron decision
acknowledge_attack_result → CompleteSquadronActivationCommand → existing Ship Activation transition
```
