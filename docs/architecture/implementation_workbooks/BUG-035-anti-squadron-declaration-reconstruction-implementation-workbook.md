# BUG-035: Anti-Squadron Declaration Reconstruction Implementation Workbook

Status: Accepted implementation workbook
Accepted by: Project Owner
Accepted date: 2026-08-21

Purpose: sole implementation specification for the narrow BUG-035 repair.

Scope: restore the existing declaration-confirm interaction after a completed
ship anti-squadron attack is acknowledged and a legal remaining squadron is
selected. This workbook does not change shared Attack completion, completed-
result ownership, declaration semantics, or Ship Activation ownership.

## 1. Authority, Problem, And Outcome

Binding authority, in precedence order:

- [CON-007](../contracts/CON-007-post-attack-continuation-release-contract.md);
- [CON-006](../contracts/CON-006-attack-declaration-lifecycle-contract.md);
- [ADR-001](../adr/ADR-001-authoritative-current-attack-state-and-transition-ownership.md);
- [ADR-010](../adr/ADR-010-gameplay-interaction-decision-equivalent-recovery.md); and
- accepted [Ship Activation interaction requirements](../../requirements/gameplay_interactions/ship_activation_interaction.md), especially SAI-001 and SAI-050.

BUG-035 is an implementation defect against those authorities. The accepted
diagnosis and required result are:

| Boundary | Established evidence | Defect disposition |
| --- | --- | --- |
| Canonical gameplay state | Completion retires `CurrentAttackState`; the inspection is satisfied; the active ship retains Attack-step state, locked anti-squadron zone, and target history. | Not defective. |
| Continuation / release | With an untargeted legal squadron, `CurrentAttackContinuation` returns no command. | Correct CON-007 derived-only outcome. |
| Derived declaration opportunity | Remaining legal target is derived from canonical targeting and history. | Present. |
| Target selection | A remaining squadron can be selected. | Present. |
| Declaration confirmation | The selected candidate lacks the existing confirmation interaction that submits Begin. | BUG-035. |
| Presentation reconstruction | The recovered selector/prompt is not reliably equivalent to normal declaration entry. | Repair boundary. |

Required semantic trace:

```text
completed anti-squadron Attack
→ acknowledgement / derived-only release
→ remaining-target declaration presentation
→ select legal remaining squadron
→ existing declaration Confirm
→ existing BeginAttackCommand
→ next authoritative CurrentAttackState
```

## 2. Required Behavior

After acknowledgement, where the locked zone has an eligible squadron not in
`ShipInstance` target history:

1. Retain the satisfied inspection. Do not synthesize a command merely to
   represent the next choice.
2. Reconstruct the locked-zone target decision from canonical state; exclude
   historic targets and ships.
3. A legal selected squadron uses the ordinary authoritative candidate query
   and creates the normal transient declaration candidate.
4. That candidate exposes the existing declaration-confirm control. Confirm
   uses `AttackExecutor._on_declaration_confirm()` and submits exactly one
   `BeginAttackCommand`.
5. `BeginAttackCommand` remains the authoritative declaration commitment and
   creates the next `CurrentAttackState`.
6. With no legal target, only the existing live-authority consumer,
   `SkipAttackCommand(reason: squadron_done)`, closes the iteration.

The same decision must be recoverable from equivalent live and reconstructed
canonical state. Hover, camera, and other transient working state need not be
preserved.

## 3. Concrete Evidence And Repair Seam

### Preserve the canonical/release path

`src/core/state/current_attack_continuation.gd` derives release from canonical
`ShipInstance` facts. `_derive_ship_inspection_release()` returns no command
while `_has_remaining_anti_squadron_target()` is true; it selects existing
`SkipAttackCommand(reason: squadron_done)` only when exhausted.

`src/autoload/command_processor.gd` evaluates that helper through its existing
post-success seam and synthesizes only on live authority. This is correct
CON-007 behavior and is outside production change scope.

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

The exact local transient condition—candidate installation, panel confirmation
mode, or signal ownership—shall be isolated by the regression below before
editing production code. This is an implementation proof gate, not an
architecture stop: canonical state and release are already proven correct.

## 4. Authorized Scope

| File | Authorized boundary | Permitted change |
| --- | --- | --- |
| `src/scenes/game_board/attack_executor.gd` | `resume_inactive_ship_attack_continuation()` and `_render_inactive_ship_continuation()` | Establish the existing selector/panel/signal declaration lifecycle fully for reconstructed anti-squadron continuation. No semantic command or canonical mutation. |
| `src/scenes/game_board/target_selector.gd` | `_handle_target_squadron_click()`, `_update_los_overlay_and_panel()`, and directly adjacent transient helpers—only if the regression proves a reconstructed selector fails to install/present its normal candidate | Preserve `authoritative_attack_entry`; repair only transient candidate/Confirm presentation. |
| `tests/integration/test_current_attack_production_resume.gd` | Existing post-acknowledgement anti-squadron area | Add the required real-GameBoard regression. |

Not authorized: `current_attack_continuation.gd`, `command_processor.gd`,
`GameState`, command classes, `modal_router.gd`, `attack_panel_controller.gd`,
Ship Activation state/commands, `CurrentAttackState`, contracts, ADRs, or
requirements. If the regression shows a necessary change outside the listed
production boundaries, stop and report before widening scope.

## 5. Required Regression Test

Add one real-GameBoard Hot-Seat test to
`test_current_attack_production_resume.gd`, adjacent to the current
post-acknowledgement anti-squadron tests. Reuse
`_satisfied_inactive_anti_state(true)`, `GameManager.start_new_game_from_state`,
board token helpers, and `AcknowledgeAttackResultCommand`.

The test SHALL:

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

This is a semantic regression: panel visibility alone is insufficient. The
test must fail on the observed select-without-confirm behavior and pass only
when the second authoritative attack exists.

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

- Section 5 Hot-Seat production regression.
- Equivalent-state reopen without the original acknowledgement callback:
  reconstructed board state reaches legal selection and Begin.
- Existing/strengthened assertions: historic target excluded, locked zone
  retained, ships excluded, exhausted iteration yields exactly one
  `SkipAttackCommand(reason: squadron_done)`.
- Network: authority alone synthesizes an exhausted consumer; mirrors do not.
  The derived remaining declaration is actionable from ordered canonical state.
- Save/load or reconnect: install canonical state before reconstructing the
  remaining target opportunity; no persisted continuation descriptor.
- Replay: apply recorded acknowledgement/Begin/Skip commands in order with no
  local synthesis.

### Required existing suites

- `tests/integration/test_current_attack_production_resume.gd`
- `tests/integration/test_current_attack_shared_protocol.gd`
- `tests/integration/test_squadron_attack_target_recovery.gd`

Run the full GUT suite, Phase-K architecture lint, and `git diff --check`.
Manual QA remains useful for Hot-Seat remaining-target → second Begin, exhausted
target → one `squadron_done`, and Network confirmation after automated checks.

## 8. Stop Gates And Completion

Stop and report rather than extending this workbook if concrete evidence shows:

1. CON-007 conflicts with CON-006 or ADR-010, or cannot distinguish remaining
   derived choice from exhausted `squadron_done` consumption;
2. canonical state cannot represent locked zone/history and the remaining
   opportunity;
3. a new gameplay command, owner, continuation state, or presentation-owned
   mutation is required;
4. the failure occurs before terminal completion, acknowledgement, or release;
   or
5. the handoff cannot be repaired without shared-Attack redesign or Squadron
   Phase scope.

No stop gate is currently triggered.

Completion requires the new regression to fail before the production change and
pass after it, all listed suites and broader checks green, and exactly these
semantic traces:

```text
acknowledge_attack_result → [no synthetic command] → BeginAttackCommand
acknowledge_attack_result → SkipAttackCommand(squadron_done)  # exhaustion only
```
