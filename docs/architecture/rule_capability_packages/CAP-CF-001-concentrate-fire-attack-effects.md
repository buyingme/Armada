# CAP-CF-001: Concentrate Fire Attack Effects

## Identity

Package ID: CAP-CF-001  
Status: Draft  
Component type: command dial and token  
Source: Rules Reference Concentrate Fire command  
Authority: [CON-003](../contracts/CON-003-rule-capability-contract.md), [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md), [BUG-071 Owner UX resolution](../../qa/bugs/open/BUG-071/issue.md#owner-ux-resolution--2026-10-03), [final Owner effect-presentation refinement](../../qa/bugs/open/BUG-071/issue.md#owner-ux-refinement--concentrate-fire-effect-resolution), [Owner-accepted implementation workbook](../implementation_workbooks/BUG-070-BUG-071-gather-and-concentrate-fire-implementation-workbook.md)

## Scope

Post-roll dial addition and token reroll within one CF command resolution;
atomic dial/token/both commitment (or attack-local decline), once-per-round
marker, retained effect authorization, timing-window blocking and H9
coexistence. The top-level CF Use/Decline row opens only legal Dial, Token or
Dial + Token choices after Use. Combined resources are spent together before
the dial-first, token-second effects; an unexercised reroll does not refund the
token. BUG-071 has separate acceptance from BUG-070.
After commitment, Dial presents the `Concentrate Fire Command Dial` modal
with `Select die to add.` and visual choices limited to authoritative legal
die colours/types. Token presents the established visual eligible-die
reroll interaction. Combined use proceeds Dial then Token, with no repeated
resource/effect dropdown. These are CF presentation obligations only; they
do not change command, RNG, recovery, Network or replay semantics.

## Ownership and surface traceability

| Surface | Owner and evidence |
| --- | --- |
| Registration and timing | [RuleBootstrap](../../../src/autoload/rule_bootstrap.gd), [CF choice participant](../../../src/core/effects/rules/concentrate_fire_choice.gd), [token participant](../../../src/core/effects/rules/concentrate_fire_token.gd), and [TimingWindowOrchestrator](../../../src/core/timing_windows/timing_window_orchestrator.gd). |
| Commitment | [ChooseConcentrateFireCommand](../../../src/core/commands/choose_concentrate_fire_command.gd) validates/atomically spends; [ShipInstance](../../../src/core/state/ship_instance.gd) owns the round marker; [CurrentAttackState](../../../src/core/state/current_attack_state.gd) owns bound effect authorization. |
| Effect commands and RNG | [Dial use](../../../src/core/commands/use_concentrate_fire_dial_command.gd), [dial decline](../../../src/core/commands/decline_concentrate_fire_dial_command.gd), [token use](../../../src/core/commands/use_concentrate_fire_token_reroll_command.gd), and [token decline](../../../src/core/commands/decline_concentrate_fire_token_reroll_command.gd). Dial and token use have authority result application; passive peers do not roll. |
| Projection and confirmation | [UIProjector](../../../src/core/network/ui_projector.gd), [AttackExecutor](../../../src/scenes/game_board/attack_executor.gd), and [ConfirmAttackDiceCommand](../../../src/core/commands/confirm_attack_dice_command.gd) read canonical readiness. After committed selection, project the Dial modal or Token visual reroll interaction directly, without a second CF selector. |
| Save, replay, Network | [GameState](../../../src/core/state/game_state.gd), [GameReplay](../../../src/core/commands/game_replay.gd), [NetworkManager](../../../src/autoload/network_manager.gd), and [StateFilter](../../../src/core/network/state_filter.gd). |

## Evidence map and test evidence

- Dial/token/both/neither transition and round-marker cases: [test_concentrate_fire_timing_window.gd](../../../tests/unit/test_concentrate_fire_timing_window.gd).
- BUG-071 production evidence: real production CF Use/Decline row, actionable Use,
  authoritative legal resource filtering, CF distinct from simultaneous effects,
  combined simultaneous spend, dial-before-token result sequence, no-refund
  decline, and rederived enclosing Attack Modify interaction after each result.
- Final Owner UX evidence: exact Dial modal title/instruction and
  visual legal die choices; direct Token eligible-die reroll; combined
  Dial-then-Token visual sequence; explicit decline/no refund; no redundant
  post-commit selector; preserved transient pre-commit and authoritative
  post-commit recovery. Roll Dice, reroll and Depowered Armament provide
  presentation references, not broader refactor authority.
- Real Begin/Roll/choice, added die, optional token use/decline, H9, recovery: [test_current_attack_production_resume.gd](../../../tests/integration/test_current_attack_production_resume.gd).
- ADR-012 passive result rejection and ordered recovery: [test_result_application_contract.gd](../../../tests/unit/test_result_application_contract.gd), [test_network_command_result_ordering.gd](../../../tests/unit/test_network_command_result_ordering.gd).
- Production replay JSON/factory/ReplayDriver: [test_replay_driver.gd](../../../tests/unit/test_replay_driver.gd). Two-process Network: [network_resume driver](../../../tests/acceptance/network_resume/driver.gd).
- Separate BUG-071 acceptance: [traceability map](../evidence/BUG-070-BUG-071-normative-refinement-traceability.md).

## Serialization, replay, Network and visibility impact

Save 9, replay 11 and protocol 10 are the planned workbook cutover;
application contract 2 remains. The controller alone
receives command intents; the public result is filtered per viewer. Owner
records replay and baseline renewal.

## Integration status

Draft. Final automated convergence and Owner-recorded replay renewal passed; independent implementation audit and Owner integration approval remain outstanding. This package is not Integrated.

## Review history

| Reviewer | Date | Decision |
| --- | --- | --- |
| Codex | 2026-10-03 | Recorded implementation evidence; no integration claim. |
