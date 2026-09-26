# BUG-049 — Network Attack Stalls When Defender Is at Speed 0

## Status

Open

## Summary

In Network mode, attacking a ship whose current speed is 0 can stall during the Defense step.

Owner manual testing reproduced the defect while a CR90 Corvette A attacked a Victory II-class Star Destroyer at speed 0.

The attack progresses normally through dice rolling and Accuracy. The game recognizes that the defender is at speed 0 and therefore cannot spend defense tokens. It then attempts to submit `commit_defense`, but that command is rejected because the submitting host principal is not authorized for the command.

The attack remains active in the Defense stage and gameplay cannot progress.

## Environment

- Mode: Network
- Scenario: Debug Scenario
- Round: 3
- Attacker: CR90 Corvette A, Player 0
- Defender: Victory II-class Star Destroyer, Player 1
- Defender canonical speed: 0
- Replay: `replay_20260926_062036.json`
- Annotation: `annotation_20260926_062023_001.json`
- Log: `game_20260926_061139.log`
- Replay format: 10

## Evidence

The annotation records:

> Another bug. attacking the vsd at speed 0 leads to stall ui. The game does not progress further. The test has been done in network mode.

At the captured state:

- the current attack remains active;
- Accuracy is complete;
- Defense remains pending;
- Damage remains pending;
- the attack stage is `defense`;
- the defender's canonical speed is 0.

The runtime log records the relevant transition:

`AttackExecutor` recognizes:

`Defender speed 0 — cannot spend defense tokens.`

Immediately afterward:

`NetworkHostCommandSubmitter` rejects `commit_defense` because the host principal is not authorized for that command.

The UI then reports:

`Defense commit command rejected — controls remain enabled.`

[2026-09-26T06:19:13] [INFO] [AttackExecutor] Attack confirmed: 5 damage. Starting Step 3 (accuracy).
[2026-09-26T06:19:13] [INFO] [CommandProcessor] Executed [publish_attack_flow] seq=150 player=0.
[2026-09-26T06:19:13] [INFO] [AttackExecutor] No accuracy icons or canonical defender — skipping accuracy step.
[2026-09-26T06:19:13] [INFO] [CommandProcessor] Executed [commit_accuracy] seq=151 player=0.
[2026-09-26T06:19:13] [INFO] [AttackExecutor] Accuracy confirmed: locked tokens [].
[2026-09-26T06:19:13] [INFO] [AttackExecutor] Defender speed 0 — cannot spend defense tokens.
WARNING: [2026-09-26T06:19:13] [WARN] [NetworkHostCommandSubmitter] Host principal is not authorized for command [commit_defense].
     at: push_warning (core/variant/variant_utility.cpp:1034)
     GDScript backtrace (most recent call first):
         [0] _log (res://src/utils/logger.gd:128)
         [1] warn (res://src/utils/logger.gd:105)
         [2] submit (res://src/core/commands/network_host_command_submitter.gd:27)
         [3] submit_commit_defense (res://src/autoload/game_manager.gd:1737)
         [4] _submit_commit_defense (res://src/scenes/game_board/attack_executor.gd:2982)
         [5] _attack_exec_start_defense (res://src/scenes/game_board/attack_executor.gd:2276)
         [6] apply_accuracy_result (res://src/scenes/game_board/attack_executor.gd:2253)
         [7] react_to_command (res://src/scenes/game_board/attack_panel_controller.gd:118)
         [8] _route_to_controllers (res://src/scenes/game_board/command_router_adapter.gd:147)
         [9] _route_to_command_reactions (res://src/scenes/game_board/modal_router.gd:146)
         [10] route_command_result (res://src/scenes/game_board/modal_router.gd:80)
         [11] _on_command_executed (res://src/scenes/game_board/modal_router.gd:114)
         [12] _submit (res://src/autoload/command_processor.gd:360)
         [13] submit_deferred_followups (res://src/autoload/command_processor.gd:220)
         [14] submit (res://src/core/commands/network_host_command_submitter.gd:30)
         [15] submit_commit_accuracy (res://src/autoload/game_manager.gd:1744)
         [16] _commit_accuracy_selection (res://src/scenes/game_board/attack_executor.gd:2229)
         [17] _attack_exec_start_accuracy (res://src/scenes/game_board/attack_executor.gd:2157)
         [18] apply_attack_confirm_result (res://src/scenes/game_board/attack_executor.gd:2137)
         [19] apply_remote_attack_confirm (res://src/scenes/game_board/attack_executor.gd:3473)
         [20] react_to_command (res://src/scenes/game_board/attack_panel_controller.gd:172)
         [21] _route_to_controllers (res://src/scenes/game_board/command_router_adapter.gd:147)
         [22] _route_to_command_reactions (res://src/scenes/game_board/modal_router.gd:146)
         [23] route_command_result (res://src/scenes/game_board/modal_router.gd:80)
         [24] _on_command_executed (res://src/scenes/game_board/modal_router.gd:114)
         [25] _submit (res://src/autoload/command_processor.gd:360)
         [26] submit_deferred_followups (res://src/autoload/command_processor.gd:220)
         [27] _submit_observer_followup_from_server (res://src/autoload/network_manager.gd:1878)
         [28] _submit_followup (res://src/autoload/command_processor.gd:961)
         [29] drain_observer_followups (res://src/autoload/command_processor.gd:294)
         [30] _drain_server_observer_followups (res://src/autoload/network_manager.gd:1887)
         [31] handle_host_command (res://src/autoload/network_manager.gd:2029)
         [32] submit (res://src/core/commands/network_host_command_submitter.gd:35)
         [33] submit_publish_attack_flow (res://src/autoload/game_manager.gd:1982)
         [34] _fsm_advance (res://src/scenes/game_board/attack_executor.gd:197)
         [35] _apply_dice_roll_result (res://src/scenes/game_board/attack_executor.gd:1935)
         [36] apply_roll_result (res://src/scenes/game_board/attack_executor.gd:3446)
         [37] react_to_command (res://src/scenes/game_board/attack_panel_controller.gd:163)
         [38] _route_to_controllers (res://src/scenes/game_board/command_router_adapter.gd:147)
         [39] _route_to_command_reactions (res://src/scenes/game_board/modal_router.gd:146)
         [40] route_command_result (res://src/scenes/game_board/modal_router.gd:80)
         [41] _on_command_executed (res://src/scenes/game_board/modal_router.gd:114)
         [42] _submit (res://src/autoload/command_processor.gd:360)
         [43] submit_deferred_followups (res://src/autoload/command_processor.gd:220)
         [44] submit (res://src/core/commands/network_host_command_submitter.gd:30)
         [45] submit_roll_dice (res://src/autoload/game_manager.gd:1517)
         [46] _on_attack_roll_dice (res://src/scenes/game_board/attack_executor.gd:1915)
         [47] _on_roll_pressed (res://src/ui/combat/attack_sim_panel.gd:1389)
WARNING: [2026-09-26T06:19:13] [WARN] [AttackExecutor] Defense commit command rejected — controls remain enabled.
     at: push_warning (core/variant/variant_utility.cpp:1034)
     GDScript backtrace (most recent call first):
         [0] _log (res://src/utils/logger.gd:128)
         [1] warn (res://src/utils/logger.gd:105)
         [2] _submit_commit_defense (res://src/scenes/game_board/attack_executor.gd:2984)
         [3] _attack_exec_start_defense (res://src/scenes/game_board/attack_executor.gd:2276)
         [4] apply_accuracy_result (res://src/scenes/game_board/attack_executor.gd:2253)
         [5] react_to_command (res://src/scenes/game_board/attack_panel_controller.gd:118)
         [6] _route_to_controllers (res://src/scenes/game_board/command_router_adapter.gd:147)
         [7] _route_to_command_reactions (res://src/scenes/game_board/modal_router.gd:146)
         [8] route_command_result (res://src/scenes/game_board/modal_router.gd:80)
         [9] _on_command_executed (res://src/scenes/game_board/modal_router.gd:114)
         [10] _submit (res://src/autoload/command_processor.gd:360)
         [11] submit_deferred_followups (res://src/autoload/command_processor.gd:220)
         [12] submit (res://src/core/commands/network_host_command_submitter.gd:30)
         [13] submit_commit_accuracy (res://src/autoload/game_manager.gd:1744)
         [14] _commit_accuracy_selection (res://src/scenes/game_board/attack_executor.gd:2229)
         [15] _attack_exec_start_accuracy (res://src/scenes/game_board/attack_executor.gd:2157)
         [16] apply_attack_confirm_result (res://src/scenes/game_board/attack_executor.gd:2137)
         [17] apply_remote_attack_confirm (res://src/scenes/game_board/attack_executor.gd:3473)
         [18] react_to_command (res://src/scenes/game_board/attack_panel_controller.gd:172)
         [19] _route_to_controllers (res://src/scenes/game_board/command_router_adapter.gd:147)
         [20] _route_to_command_reactions (res://src/scenes/game_board/modal_router.gd:146)
         [21] route_command_result (res://src/scenes/game_board/modal_router.gd:80)
         [22] _on_command_executed (res://src/scenes/game_board/modal_router.gd:114)
         [23] _submit (res://src/autoload/command_processor.gd:360)
         [24] submit_deferred_followups (res://src/autoload/command_processor.gd:220)
         [25] _submit_observer_followup_from_server (res://src/autoload/network_manager.gd:1878)
         [26] _submit_followup (res://src/autoload/command_processor.gd:961)
         [27] drain_observer_followups (res://src/autoload/command_processor.gd:294)
         [28] _drain_server_observer_followups (res://src/autoload/network_manager.gd:1887)
         [29] handle_host_command (res://src/autoload/network_manager.gd:2029)
         [30] submit (res://src/core/commands/network_host_command_submitter.gd:35)
         [31] submit_publish_attack_flow (res://src/autoload/game_manager.gd:1982)
         [32] _fsm_advance (res://src/scenes/game_board/attack_executor.gd:197)
         [33] _apply_dice_roll_result (res://src/scenes/game_board/attack_executor.gd:1935)
         [34] apply_roll_result (res://src/scenes/game_board/attack_executor.gd:3446)
         [35] react_to_command (res://src/scenes/game_board/attack_panel_controller.gd:163)
         [36] _route_to_controllers (res://src/scenes/game_board/command_router_adapter.gd:147)
         [37] _route_to_command_reactions (res://src/scenes/game_board/modal_router.gd:146)
         [38] route_command_result (res://src/scenes/game_board/modal_router.gd:80)
         [39] _on_command_executed (res://src/scenes/game_board/modal_router.gd:114)
         [40] _submit (res://src/autoload/command_processor.gd:360)
         [41] submit_deferred_followups (res://src/autoload/command_processor.gd:220)
         [42] submit (res://src/core/commands/network_host_command_submitter.gd:30)
         [43] submit_roll_dice (res://src/autoload/game_manager.gd:1517)
         [44] _on_attack_roll_dice (res://src/scenes/game_board/attack_executor.gd:1915)
         [45] _on_roll_pressed (res://src/ui/combat/attack_sim_panel.gd:1389)
[2026-09-26T06:19:13] [INFO] [CommandProcessor] Executed [publish_attack_flow] seq=152 player=0.
[2026-09-26T06:19:13] [INFO] [CommandProcessor] Executed [publish_attack_flow] seq=146 player=0.
[2026-09-26T06:19:13] [INFO] [AttackExecutor] Dice rolled: 3 dice, 5 damage.
[2026-09-26T06:19:13] [INFO] [TargetSelector] Target selector dismissed.
[2026-09-26T06:19:13] [INFO] [AttackExecutor] Attack executor dismissed.
[2026-09-26T06:19:13] [INFO] [CommandProcessor] Executed [roll_dice] seq=147 player=0.
[2026-09-26T06:19:13] [INFO] [TargetSelector] Target selector dismissed.
[2026-09-26T06:19:13] [INFO] [AttackExecutor] Attack executor dismissed.
[2026-09-26T06:19:13] [INFO] [TargetSelector] Target selector dismissed.
[2026-09-26T06:19:13] [INFO] [AttackExecutor] Attack executor dismissed.
[2026-09-26T06:19:13] [INFO] [CommandProcessor] Executed [publish_attack_flow] seq=148 player=0.
[2026-09-26T06:19:13] [INFO] [TargetSelector] Target selector dismissed.
[2026-09-26T06:19:13] [INFO] [AttackExecutor] Attack executor dismissed.
[2026-09-26T06:19:13] [INFO] [CommandProcessor] Executed [confirm_attack_dice] seq=149 player=0.


## Steps to Reproduce

1. Start a Network game using the Debug Scenario.
2. Reduce or otherwise establish the defending VSD at canonical speed 0.
3. Activate the opposing CR90.
4. Declare a normal ship attack against the speed-0 VSD.
5. Roll and confirm the attack dice.
6. Complete the Accuracy step.
7. Allow the attack flow to enter Defense.
8. Observe the automatic handling of the speed-0 defender.

## Expected Result

When a defending ship at speed 0 cannot spend defense tokens, the attack must continue through the existing authoritative Defense lifecycle without requiring an unavailable player interaction.

Any automatic no-defense continuation must use the correct authoritative command ownership and Network submission path.

After Defense is resolved, the attack proceeds normally to damage resolution and subsequent attack completion.

Hot-Seat and Network must preserve equivalent gameplay semantics.

## Actual Result

The game correctly determines that the speed-0 defender cannot spend defense tokens.

However, the subsequent `commit_defense` submission is rejected because the submitting host principal is not authorized for the command.

The attack remains active in the Defense stage and the UI/gameplay stalls.

## Evidence Files

- `replay_20260926_062036.json`
- `annotation_20260926_062023_001.json`
- `game_20260926_061139.log`

These files are genuine Owner manual-test evidence and must not be transformed into replay fixtures.

## Impact

Blocking gameplay defect.

A legal Network ship attack against a speed-0 defender can become impossible to complete.

The defect also demonstrates a Network authority/continuation seam that is not currently protected sufficiently by automated acceptance coverage.

## Preliminary Classification

Network attack continuation / command-authority defect.

The evidence proves that the automatic speed-0 Defense path attempts a `commit_defense` submission from a principal that is not authorized to submit it.

The deeper production root cause has not yet been diagnosed and should not be inferred from this issue record.

## Acceptance Criteria

- A Network attack against a speed-0 ship progresses through Defense without stalling.
- The inability to spend defense tokens is handled through the existing authoritative attack lifecycle.
- Any automatic Defense continuation is submitted/applied by the correct authority.
- No authority checks are weakened to make the path pass.
- No Network-only parallel attack or Defense lifecycle is introduced.
- The same gameplay situation remains semantically equivalent in Hot-Seat.
- Attack completion and composed return continue normally afterward.
- Focused regression coverage reproduces the speed-0 defender case and proves the previous unauthorized-submission path cannot recur.
- Real Network verification covers the repaired path.

## Relationship to Existing Work

Potentially related to the existing attack authority and Network continuation architecture, including:

- ADR-001 — authoritative CurrentAttack ownership
- CON-001 — CurrentAttack semantic transition / Network / replay contract
- CON-007 — post-attack continuation and composed return
- BUG-043 stabilization/manual acceptance work

The exact ownership of this defect should be established during diagnosis rather than assumed from the symptom.

## Notes

This defect was discovered during broader post-BUG-043 manual acceptance testing.

It should be preserved and repaired together with BUG-048 as a bounded stabilization batch before further final acceptance/replay evidence work proceeds.
