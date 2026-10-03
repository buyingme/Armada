# CAP-DMG-010: Point-Defense Failure Gather Removal

## Identity

Package ID: CAP-DMG-010  
Status: Draft  
Component type: damage card  
Source: `point_defense_failure` in [damage_cards.json](../../../Resources/Game_Components/damage_cards.json)  
Authority: [CON-003](../contracts/CON-003-rule-capability-contract.md), [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md), [accepted workbook](../implementation_workbooks/BUG-070-BUG-071-gather-and-concentrate-fire-implementation-workbook.md)

## Scope

The mandatory die removal when the damaged ship attacks a squadron, including final-die removal. BUG-070 owns the cancellation evidence. Damaged Munitions and obstruction have separate packages.

## Ownership and surface traceability

| Surface | Owner and evidence |
| --- | --- |
| Rule source and registration | [Point-Defense Failure rule](../../../src/core/effects/rules/damage_cards/ship/point_defense_failure.gd) and [RuleBootstrap](../../../src/autoload/rule_bootstrap.gd) |
| Readiness and validation | [AttackGatherReadiness](../../../src/core/commands/attack_gather_readiness.gd) derives the next mandatory source; [ResolveAttackPoolChoiceCommand](../../../src/core/commands/resolve_attack_pool_choice_command.gd) validates and invokes the registered modifier. |
| State and execution | [CurrentAttackState](../../../src/core/state/current_attack_state.gd) stores resolved choice and temporary empty pool; the choice command commits one removal. [RollDiceCommand](../../../src/core/commands/roll_dice_command.gd) and [SkipAttackCommand](../../../src/core/commands/skip_attack_command.gd) own completed positive and final-empty outcomes. |
| Projection | [AttackExecutor](../../../src/scenes/game_board/attack_executor.gd) derives the next choice and recovery from canonical state. |
| Save, replay, Network | CurrentAttack and command history carry the result through [GameState](../../../src/core/state/game_state.gd), [GameReplay](../../../src/core/commands/game_replay.gd), and [StateFilter](../../../src/core/network/state_filter.gd); no separate card state is serialized. |

## Evidence map and test evidence

- Production Begin, final-die removal, card-before-obstruction, raw cancellation recovery and rejection guards: [test_current_attack_production_resume.gd](../../../tests/integration/test_current_attack_production_resume.gd).
- Real two-process Network attacker-role and passive-peer convergence: [network_resume driver](../../../tests/acceptance/network_resume/driver.gd) and [assertions](../../../tests/acceptance/network_resume/assertions.gd).
- Separate BUG-070 acceptance and Owner rule origin: [traceability map](../evidence/BUG-070-BUG-071-normative-refinement-traceability.md).

## Serialization, replay, Network and visibility impact

The accepted save 9, replay 11 and protocol 10 cutover applies. The rule source is public; hidden information continues through StateFilter. Replay fixture and baseline renewal remains Owner-recorded.

## Integration status

Draft. Implementation evidence is present; Owner-recorded replay renewal, final convergence review and Owner integration approval remain outstanding. This package is not Integrated.

## Review history

| Reviewer | Date | Decision |
| --- | --- | --- |
| Codex | 2026-10-03 | Recorded implementation evidence; no integration claim. |
