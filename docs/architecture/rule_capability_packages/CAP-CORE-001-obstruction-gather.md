# CAP-CORE-001: Obstruction Gather Removal

## Identity

Package ID: CAP-CORE-001  
Status: Draft  
Component type: core attack rule  
Source: Rules Reference obstruction rule and [CON-001](../contracts/CON-001-current-attack-state-and-semantic-transition-contract.md)  
Authority: [CON-003](../contracts/CON-003-rule-capability-contract.md), [accepted workbook](../implementation_workbooks/BUG-070-BUG-071-gather-and-concentrate-fire-implementation-workbook.md)

## Scope

One mandatory obstruction die removal after applicable card removals, including explicit no-die resolution if a prior mandatory effect emptied the pool. BUG-070 final-empty cancellation is shared with CAP-DMG-010 and CAP-DMG-011.

## Ownership and surface traceability

| Surface | Owner and evidence |
| --- | --- |
| Rule applicability | [TargetingListBuilder](../../../src/core/combat/targeting_list_builder.gd) supplies authoritative obstruction at Begin; [AttackGatherReadiness](../../../src/core/commands/attack_gather_readiness.gd) orders its resolution after applicable cards. RuleRegistry is not applicable to obstruction itself: it uses the core attack command path. |
| Command and state | [ResolveAttackPoolChoiceCommand](../../../src/core/commands/resolve_attack_pool_choice_command.gd) validates/removes or records no-die resolution; [CurrentAttackState](../../../src/core/state/current_attack_state.gd) stores obstruction status. [RollDiceCommand](../../../src/core/commands/roll_dice_command.gd) and [SkipAttackCommand](../../../src/core/commands/skip_attack_command.gd) own completion. |
| Projection | [AttackExecutor](../../../src/scenes/game_board/attack_executor.gd) reads canonical readiness; no UI state authorizes the choice. |
| Save, replay, Network | [GameState](../../../src/core/state/game_state.gd), [GameReplay](../../../src/core/commands/game_replay.gd), and [StateFilter](../../../src/core/network/state_filter.gd) carry the same canonical choice and outcome. |

## Evidence map and test evidence

- Actual obstructed Begin and final-die cancellation in Squadron Phase and commanded squadron, plus card-before-obstruction no-die resolution: [test_current_attack_production_resume.gd](../../../tests/integration/test_current_attack_production_resume.gd).
- Command guards and serialized-state invariants: [test_attack_commands.gd](../../../tests/unit/test_attack_commands.gd), [test_current_attack_state.gd](../../../tests/unit/test_current_attack_state.gd).
- Separate BUG-070 acceptance: [traceability map](../evidence/BUG-070-BUG-071-normative-refinement-traceability.md).

## Serialization, replay, Network and visibility impact

The shared save 9, replay 11 and protocol 10 cutover applies. Obstruction and choice are public in the attack state. Owner records any required replay and baseline renewal.

## Integration status

Draft. Final automated convergence and Owner-recorded replay renewal passed; the traceability map distinguishes the Owner's manual final-Gather cancellation evidence from canonical replay coverage. Independent implementation audit and Owner integration approval remain outstanding. This package is not Integrated.

## Review history

| Reviewer | Date | Decision |
| --- | --- | --- |
| Codex | 2026-10-03 | Recorded implementation evidence; no integration claim. |
