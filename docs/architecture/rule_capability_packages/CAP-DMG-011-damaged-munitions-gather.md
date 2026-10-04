# CAP-DMG-011: Damaged Munitions Gather Removal

## Identity

Package ID: CAP-DMG-011  
Status: Draft  
Component type: damage card  
Source: `damaged_munitions` in [damage_cards.json](../../../Resources/Game_Components/damage_cards.json)  
Authority: [CON-003](../contracts/CON-003-rule-capability-contract.md), [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md), [accepted workbook](../implementation_workbooks/BUG-070-BUG-071-gather-and-concentrate-fire-implementation-workbook.md)

## Scope

The mandatory die removal when the damaged ship attacks a ship. The gather, final-empty and cancellation boundary is shared with CAP-DMG-010; the card predicates remain separate.

## Ownership and surface traceability

| Surface | Owner and evidence |
| --- | --- |
| Rule source and registration | [Damaged Munitions rule](../../../src/core/effects/rules/damage_cards/ship/damaged_munitions.gd) and [RuleBootstrap](../../../src/autoload/rule_bootstrap.gd) |
| Readiness and command | [AttackGatherReadiness](../../../src/core/commands/attack_gather_readiness.gd) identifies applicable source and order; [ResolveAttackPoolChoiceCommand](../../../src/core/commands/resolve_attack_pool_choice_command.gd) validates one selected die and invokes the modifier. |
| Canonical state and continuation | [CurrentAttackState](../../../src/core/state/current_attack_state.gd), [RollDiceCommand](../../../src/core/commands/roll_dice_command.gd), [SkipAttackCommand](../../../src/core/commands/skip_attack_command.gd), and [CurrentAttackContinuation](../../../src/core/state/current_attack_continuation.gd). |
| Projection | [AttackExecutor](../../../src/scenes/game_board/attack_executor.gd) reads the authoritative next obligation. |
| Save, replay, Network | CurrentAttack resolved choices and the semantic command use [GameState](../../../src/core/state/game_state.gd), [GameReplay](../../../src/core/commands/game_replay.gd), and [StateFilter](../../../src/core/network/state_filter.gd). No parallel UI authority is persisted. |

## Evidence map and test evidence

- Rule modifier and card predicates: [damage-card tests](../../../tests/unit/test_rule_damaged_munitions.gd) and [gather command tests](../../../tests/unit/test_attack_commands.gd).
- Shared production cancellation and recovery boundary: [test_current_attack_production_resume.gd](../../../tests/integration/test_current_attack_production_resume.gd).
- Separate BUG-070 acceptance: [traceability map](../evidence/BUG-070-BUG-071-normative-refinement-traceability.md).

## Serialization, replay, Network and visibility impact

The shared save 9, replay 11 and protocol 10 cutover applies. Card identity is public; StateFilter retains existing visibility. Owner records any required replay and baseline renewal.

## Integration status

Draft. The production Begin → mandatory choice → Roll path and shared final-empty cancellation boundary are covered; final automated convergence is recorded in the traceability map. Independent implementation audit and Owner integration approval remain outstanding. This package is not Integrated.

## Review history

| Reviewer | Date | Decision |
| --- | --- | --- |
| Codex | 2026-10-03 | Recorded implementation traceability; no integration claim. |
