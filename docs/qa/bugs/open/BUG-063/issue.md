# BUG-063 — Network Speed-0 Maneuver Rejected as Invalid Yaw Bonus Joint

## Status

Open

## Summary

In Network play, a ship can enter the normal Maneuver interaction, establish a legal
speed-0 Maneuver preview, and press **Commit Maneuver**, but the authority rejects the
resulting `execute_maneuver` command with:

`Invalid yaw bonus joint.`

The Maneuver therefore does not enter authoritative command history and the ship's
activation remains stuck at the Maneuver interaction.

This is a production-path defect discovered during manual verification of the speed-0
Maneuver path.

## Observed Behavior

During the affected Network activation:

1. The ship reaches its normal Maneuver opportunity.
2. The Maneuver UI permits the speed preview to be reduced to speed 0.
3. The speed-0 Maneuver tool is displayed.
4. The player presses **Commit Maneuver**.
5. The client-side interaction reports:
   - Navigate token spent;
   - Maneuver executed;
   - Maneuver commitment accepted / consequences authority-driven.
6. Authority rejects `execute_maneuver` with:
   - `Invalid yaw bonus joint.`
7. The authoritative Maneuver lifecycle does not begin/continue.
8. Reopening the activation interaction does not allow the activation to converge normally.

The corresponding replay contains no accepted `execute_maneuver` for the affected
speed-0 attempt.

## Expected Behavior

A legal speed-0 Maneuver must use a command representation accepted by the existing
authoritative Maneuver contract.

After commitment:

- `execute_maneuver` must be accepted when the selected speed-0 Maneuver is legal;
- the Maneuver must continue through the normal authoritative Maneuver lifecycle;
- the activation must converge normally after Maneuver completion;
- speed 0 must not require a separate UI-only lifecycle or weakened authoritative
  validation.

If authority rejects a Maneuver command, rejection must not leave canonical or client
gameplay state partially mutated.

## Reproduction

### Mode

Network

### Steps

1. Start a Network match with a ship capable of reaching a legal speed-0 Maneuver.
2. Activate the ship normally.
3. Progress through the activation to the Maneuver opportunity.
4. Use the available Navigate effect/resources to establish a legal speed-0 Maneuver
   preview.
5. Press **Commit Maneuver**.
6. Observe the Network/CommandProcessor log.
7. Attempt to continue the activation.

### Result

Authority rejects the submitted `execute_maneuver` command with:

`Invalid yaw bonus joint.`

The activation does not progress through the normal Maneuver completion path.

## Evidence

Manual Network test performed 2026-09-27.

### Log

`game_20260927_101313.log`

Relevant sequence:

- speed change validates to target speed 0;
- speed-0 Maneuver preview is established;
- Commit Maneuver is pressed;
- `Execute maneuver requested`;
- Navigate token is reported spent;
- `Maneuver executed`;
- `Maneuver commitment accepted; consequences are authority-driven`;
- `CommandProcessor` rejects `execute_maneuver`:
  `Invalid yaw bonus joint.`;
- NetworkManager reports that the command was rejected by validation.

### Replay

`replay_20260927_101524.json`

The replay reaches the affected ship's Maneuver opportunity after `skip_attack`, but
contains no subsequent accepted `execute_maneuver` for the speed-0 attempt.

For comparison, an earlier successful Maneuver in the same replay records the normal
authoritative chain:

`execute_maneuver`
→ `apply_maneuver_transform`
→ displacement handling
→ `complete_maneuver`
→ activation completion
→ `end_activation`.

## Initial Classification

The observed UI stall is a consequence of an authoritative command rejection rather
than evidence of a purely presentation-level failure.

The exact root cause is **not yet established**.

Investigation should determine whether the defect is in one or more of:

- speed-0 `execute_maneuver` command construction;
- representation of `yaw_bonus_joint` for a speed-0 Maneuver;
- authoritative `execute_maneuver` validation;
- an adapter/normalization boundary between UI/controller representation and the
  authoritative command contract.

Do not weaken authoritative validation or introduce a special UI-only speed-0 execution
path merely to make the command pass.

## Additional Verification Concern

The log reports that the Navigate token was spent and that the Maneuver was executed
before the authority rejection is reported.

This evidence alone does **not** establish that canonical gameplay state was mutated
before authoritative acceptance; these messages may describe transient/controller-side
state.

Investigation must verify that rejection leaves no canonical or passive-client gameplay
state partially mutated or divergent.

If canonical mutation before authoritative acceptance is demonstrated, record and
classify that separately if it represents a distinct defect.

## Architecture / Requirement Context

Speed-0 Maneuver is part of the normal Maneuver interaction and authoritative Maneuver
lifecycle.

The repair must preserve:

- authoritative command validation;
- canonical Maneuver ownership;
- normal Maneuver commitment/consequence/completion semantics;
- Network command admission;
- replay-authoritative command history;
- controller-independent gameplay behavior.

No new speed-0-specific gameplay authority, alternate Maneuver lifecycle, generic
continuation mechanism, or UI-owned canonical state is authorized by this issue.

## Scope

### In Scope

- reproduce the speed-0 rejection;
- identify the exact command-construction / representation / validation seam;
- repair the minimum responsible production seam;
- verify successful legal speed-0 Maneuver execution in Network play;
- verify rejected Maneuvers cannot partially mutate canonical state;
- add focused regression coverage appropriate to the responsible seam.

### Out of Scope

- redesigning the Maneuver lifecycle;
- weakening legal-Maneuver validation;
- introducing a special speed-0 UI execution path;
- unrelated BUG-058 recovery/projection architecture changes;
- unrelated Maneuver UX changes.

## Acceptance Criteria

1. A legal speed-0 Maneuver can be committed successfully in Network play.
2. Authority accepts the corresponding valid `execute_maneuver` command.
3. The Maneuver progresses through the existing authoritative Maneuver lifecycle.
4. The activation converges normally after Maneuver completion.
5. Speed-0 command representation and authoritative validation agree on the applicable
   yaw-bonus semantics.
6. Invalid Maneuver commands remain rejected.
7. Rejection does not partially mutate canonical gameplay state.
8. Network peers remain converged.
9. Replay records the accepted speed-0 Maneuver through the normal authoritative command
   path.
10. Focused regression coverage protects the responsible production seam.
11. Existing non-speed-0 Maneuver behavior remains unchanged.

## Verification

At minimum:

- focused automated regression for the identified production seam;
- Network verification of legal speed-0 Maneuver commitment;
- verification of rejection atomicity;
- verification that the accepted speed-0 Maneuver appears in authoritative command
  history/replay;
- relevant existing Maneuver regression tests.

Manual replay fixture policy remains unchanged: Codex must not generate, synthesize,
reconstruct, patch, transform, relabel, or promote accepted replay fixtures. If accepted
fixture renewal is required, stop for Owner manual replay capture.


2026-09-27T10:14:40] [INFO] [ManeuverTool] Activation speed preview -1 → 0
[2026-09-27T10:14:40] [INFO] [ActivationModal] [OFFSETS] _deferred:before: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:14:40] [INFO] [ActivationModal] [OFFSETS] _deferred:after: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:14:44] [INFO] [ShipActivationState] Speed change validated: +1 → target 1 (total_change=-1, dial_budget=0, token_budget=1)
[2026-09-27T10:14:44] [INFO] [ManeuverTool] === Maneuver Tool Chain (speed 2, scale 1.0992) ===
[2026-09-27T10:14:44] [INFO] [ManeuverTool]   [0] root  entry_px=(18.0, 118.0)  exit_px=(18.0, 18.0)
[2026-09-27T10:14:44] [INFO] [ManeuverTool]        entry_world=(1173.0, 412.7)  rot=-180.00°
[2026-09-27T10:14:44] [INFO] [ManeuverTool]        exit_world=(1173.0, 522.6)
[2026-09-27T10:14:44] [INFO] [ManeuverTool]        contact_L_world=(1192.8, 433.6)  contact_R_world=(1154.4, 433.6)
[2026-09-27T10:14:44] [INFO] [ManeuverTool]   [1] segment_end  entry_px=(21.0, 149.0)  exit_px=(0.0, 0.0)
[2026-09-27T10:14:44] [INFO] [ManeuverTool]        entry_world=(1173.0, 522.6)  rot=-180.00°
[2026-09-27T10:14:44] [INFO] [ManeuverTool]        (no exit — end segment)
[2026-09-27T10:14:44] [INFO] [ManeuverTool]        contact_L_world=(1192.8, 576.5)  contact_R_world=(1154.4, 576.5)
[2026-09-27T10:14:44] [INFO] [ManeuverTool]   Joint 0  world=(1173.0, 522.6)
[2026-09-27T10:14:44] [INFO] [ManeuverTool] === End Chain ===
[2026-09-27T10:14:44] [INFO] [ManeuverTool] Activation speed preview +1 → 1
[2026-09-27T10:14:44] [INFO] [ActivationModal] [OFFSETS] _deferred:before: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:14:44] [INFO] [ActivationModal] [OFFSETS] _deferred:after: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:14:44] [INFO] [ManeuverTool] === Maneuver Tool Chain (speed 2, scale 1.0992) ===
[2026-09-27T10:14:44] [INFO] [ManeuverTool]   [0] root  entry_px=(18.0, 118.0)  exit_px=(18.0, 18.0)
[2026-09-27T10:14:44] [INFO] [ManeuverTool]        entry_world=(1173.0, 412.7)  rot=-180.00°
[2026-09-27T10:14:44] [INFO] [ManeuverTool]        exit_world=(1173.0, 522.6)
[2026-09-27T10:14:44] [INFO] [ManeuverTool]        contact_L_world=(1192.8, 433.6)  contact_R_world=(1154.4, 433.6)
[2026-09-27T10:14:44] [INFO] [ManeuverTool]   [1] segment_end  entry_px=(21.0, 149.0)  exit_px=(0.0, 0.0)
[2026-09-27T10:14:44] [INFO] [ManeuverTool]        entry_world=(1173.0, 522.6)  rot=157.50°
[2026-09-27T10:14:44] [INFO] [ManeuverTool]        (no exit — end segment)
[2026-09-27T10:14:44] [INFO] [ManeuverTool]        contact_L_world=(1211.9, 564.8)  contact_R_world=(1176.4, 579.5)
[2026-09-27T10:14:44] [INFO] [ManeuverTool]   Joint 0  world=(1173.0, 522.6)
[2026-09-27T10:14:44] [INFO] [ManeuverTool] === End Chain ===
[2026-09-27T10:14:44] [INFO] [ManeuverTool] Joint 0 clicked left → -1
[2026-09-27T10:14:44] [INFO] [ActivationModal] [OFFSETS] _deferred:before: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:14:44] [INFO] [ActivationModal] [OFFSETS] _deferred:after: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:14:45] [INFO] [ShipActivationState] Yaw bonus applied to joint 0.
[2026-09-27T10:14:45] [INFO] [ManeuverTool] === Maneuver Tool Chain (speed 2, scale 1.0992) ===
[2026-09-27T10:14:45] [INFO] [ManeuverTool]   [0] root  entry_px=(18.0, 118.0)  exit_px=(18.0, 18.0)
[2026-09-27T10:14:45] [INFO] [ManeuverTool]        entry_world=(1173.0, 412.7)  rot=-180.00°
[2026-09-27T10:14:45] [INFO] [ManeuverTool]        exit_world=(1173.0, 522.6)
[2026-09-27T10:14:45] [INFO] [ManeuverTool]        contact_L_world=(1192.8, 433.6)  contact_R_world=(1154.4, 433.6)
[2026-09-27T10:14:45] [INFO] [ManeuverTool]   [1] segment_end  entry_px=(21.0, 149.0)  exit_px=(0.0, 0.0)
[2026-09-27T10:14:45] [INFO] [ManeuverTool]        entry_world=(1173.0, 522.6)  rot=135.00°
[2026-09-27T10:14:45] [INFO] [ManeuverTool]        (no exit — end segment)
[2026-09-27T10:14:45] [INFO] [ManeuverTool]        contact_L_world=(1225.1, 546.7)  contact_R_world=(1197.9, 573.9)
[2026-09-27T10:14:45] [INFO] [ManeuverTool]   Joint 0  world=(1173.0, 522.6)
[2026-09-27T10:14:45] [INFO] [ManeuverTool] === End Chain ===
[2026-09-27T10:14:45] [INFO] [ManeuverTool] Joint 0 clicked left → -2
[2026-09-27T10:14:45] [INFO] [ActivationModal] [OFFSETS] _deferred:before: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:14:45] [INFO] [ActivationModal] [OFFSETS] _deferred:after: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:14:47] [INFO] [ShipActivationState] Speed change validated: -1 → target 0 (total_change=-2, dial_budget=0, token_budget=0)
[2026-09-27T10:14:47] [INFO] [ManeuverTool] === Maneuver Tool Chain (speed 2, scale 1.0992) ===
[2026-09-27T10:14:47] [INFO] [ManeuverTool]   [0] segment_end  entry_px=(21.0, 149.0)  exit_px=(0.0, 0.0)
[2026-09-27T10:14:47] [INFO] [ManeuverTool]        entry_world=(1173.0, 412.7)  rot=-180.00°
[2026-09-27T10:14:47] [INFO] [ManeuverTool]        (no exit — end segment)
[2026-09-27T10:14:47] [INFO] [ManeuverTool]        contact_L_world=(1192.8, 466.6)  contact_R_world=(1154.4, 466.6)
[2026-09-27T10:14:47] [INFO] [ManeuverTool] === End Chain ===
[2026-09-27T10:14:47] [INFO] [ManeuverTool] Activation speed preview -1 → 0
[2026-09-27T10:14:47] [INFO] [ActivationModal] [OFFSETS] _deferred:before: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:14:47] [INFO] [ActivationModal] [OFFSETS] _deferred:after: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:14:50] [INFO] [ActivationModal] Commit maneuver pressed — snapping ship.
[2026-09-27T10:14:50] [INFO] [ShipActivation] Execute maneuver requested.
[2026-09-27T10:14:50] [INFO] [ShipActivationState] Navigate token spent on speed change.
[2026-09-27T10:14:50] [INFO] [ShipActivationState] Maneuver executed.
[2026-09-27T10:14:50] [INFO] [TooltipManager] hide_tooltip() — was IDLE, now IDLE.
[2026-09-27T10:14:50] [INFO] [ManeuverToolController] Maneuver tool dismissed.
[2026-09-27T10:14:50] [INFO] [ShipActivation] Maneuver commitment accepted; consequences are authority-driven.
[2026-09-27T10:14:50] [INFO] [ActivationModal] [OFFSETS] _deferred:before: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:14:50] [INFO] [ActivationModal] [OFFSETS] _deferred:after: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
WARNING: [2026-09-27T10:14:50] [WARN] [CommandProcessor] Command rejected [execute_maneuver]: Invalid yaw bonus joint.
     at: push_warning (core/variant/variant_utility.cpp:1034)
     GDScript backtrace (most recent call first):
         [0] _log (res://src/utils/logger.gd:128)
         [1] warn (res://src/utils/logger.gd:105)
         [2] _reject_command (res://src/autoload/command_processor.gd:978)
         [3] _submit (res://src/autoload/command_processor.gd:343)
         [4] submit_deferred_followups (res://src/autoload/command_processor.gd:220)
         [5] _submit_command_to_server (res://src/autoload/network_manager.gd:1643)
[2026-09-27T10:14:50] [INFO] [NetworkManager] Command [execute_maneuver] from peer 1141248356 rejected by validation.
[2026-09-27T10:14:59] [INFO] [ActivationModal] Activation modal closed.
[2026-09-27T10:14:59] [INFO] [ShipActivation] Activation modal dismissed by player.
[2026-09-27T10:15:01] [INFO] [ShowActBtn] Show Activation Sequence pressed.
[2026-09-27T10:15:01] [INFO] [ShipActivation] Activation sequence requested.
[2026-09-27T10:15:01] [INFO] [ActivationModal] [OFFSETS] open_mirror:before_build: L=-184.0 R=214.0 T=-40.0 B=-40.0 sz=(398,400) pos=(795,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:01] [INFO] [ActivationModal] [OFFSETS] _build_ui:after_clear: L=-184.0 R=214.0 T=-40.0 B=-40.0 sz=(398,400) pos=(795,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:01] [INFO] [ActivationModal] [OFFSETS] _build_ui:after_size_y_zero: L=-184.0 R=214.0 T=-440.0 B=-408.0 sz=(398,32) pos=(795,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:01] [INFO] [ActivationModal] [OFFSETS] _build_ui:after_repin_vert: L=-184.0 R=214.0 T=-40.0 B=-40.0 sz=(398,32) pos=(795,1008) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:01] [INFO] [ActivationModal] [OFFSETS] open_mirror:after_build: L=-184.0 R=214.0 T=-40.0 B=-40.0 sz=(398,32) pos=(795,1008) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:01] [INFO] [ActivationModal] [OFFSETS] open_mirror:after_step_display: L=-184.0 R=214.0 T=-40.0 B=-40.0 sz=(398,32) pos=(795,1008) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:01] [INFO] [ActivationModal] Activation modal opened (mirror — no auto-skip).
[2026-09-27T10:15:01] [INFO] [ActivationModal] [OFFSETS] _deferred:before: L=-184.0 R=214.0 T=-40.0 B=-40.0 sz=(398,400) pos=(795,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:01] [INFO] [ActivationModal] [OFFSETS] _deferred:after: L=-184.0 R=214.0 T=-40.0 B=-40.0 sz=(398,400) pos=(795,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:05] [INFO] [ActivationModal] Activation modal closed.
[2026-09-27T10:15:05] [INFO] [ShipActivation] Activation modal dismissed by player.
[2026-09-27T10:15:07] [INFO] [ShowActBtn] Show Activation Sequence pressed.
[2026-09-27T10:15:07] [INFO] [ShipActivation] Activation sequence requested.
[2026-09-27T10:15:07] [INFO] [ActivationModal] [OFFSETS] open:before_build: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640)anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:07] [INFO] [ActivationModal] [OFFSETS] _build_ui:after_clear: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:07] [INFO] [ActivationModal] [OFFSETS] _build_ui:after_size_y_zero: L=-185.5 R=215.5 T=-440.0 B=-408.0 sz=(401,32) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:07] [INFO] [ActivationModal] [OFFSETS] _build_ui:after_repin_vert: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,32) pos=(793,1008) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:07] [INFO] [ActivationModal] [OFFSETS] open:after_build: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,32) pos=(793,1008) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:07] [INFO] [ActivationModal] [OFFSETS] open:after_step_display: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,32) pos=(793,1008) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:07] [INFO] [ActivationModal] [OFFSETS] open:after_visible+deferred_queued: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:07] [INFO] [ActivationModal] Activation modal opened.
[2026-09-27T10:15:07] [INFO] [ActivationModal] [OFFSETS] _deferred:before: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:07] [INFO] [ActivationModal] [OFFSETS] _deferred:after: L=-185.5 R=215.5 T=-40.0 B=-40.0 sz=(401,400) pos=(793,640) anchors=(0.50,1.00,0.50,1.00)
[2026-09-27T10:15:09] [INFO] [ActivationModal] Commit maneuver pressed — snapping ship.
[2026-09-27T10:15:09] [INFO] [ShipActivation] Execute maneuver requested.
[2026-09-27T10:15:12] [INFO] [TooltipManager] Region entered — WAITING (delay=0.45s).
[2026-09-27T10:15:13] [INFO] [TooltipManager] Hover exit — was WAITING, now IDLE.
[2026-09-27T10:15:13] [INFO] [ActivationModal] Activation modal closed.
[2026-09-27T10:15:13] [INFO] [ShipActivation] Activation modal dismissed by player.
[2026-09-27T10:15:16] [INFO] [LobbyManager] Leaving lobby 'Like's Game'.
[2026-09-27T10:15:16] [INFO] [NetworkManager] Disconnecting (was IN_GAME).
[2026-09-27T10:15:16] [INFO] [NetworkManager] State: IN_GAME → DISCONNECTED
[2026-09-27T10:15:16] [INFO] [NetworkManager] Peer disconnected: 1141248356
[2026-09-27T10:15:16] [INFO] [LobbyManager] Player (peer 1141248356) removed from lobby.
[2026-09-27T10:15:18] [INFO] [ActivationModal] Activation modal closed.
[2026-09-27T10:15:18] [INFO] [ShipActivation] Activation modal dismissed by player.
[2026-09-27T10:15:20] [INFO] [GameManager] Auto-saved replay: res://replays/replay_20260927_101520.json (22 commands).
[2026-09-27T10:15:20] [INFO] [LobbyManager] Leaving lobby 'Like's Game'.
[2026-09-27T10:15:20] [INFO] [NetworkManager] Disconnecting (was IN_GAME).
[2026-09-27T10:15:20] [INFO] [NetworkManager] State: IN_GAME → DISCONNECTED
[2026-09-27T10:15:23] [INFO] [GameManager] Auto-saved replay: res://replays/replay_20260927_101523.json (22 commands).
[2026-09-27T10:15:23] [INFO] [LoggingMode] Session ended — closing log file.
[2026-09-27T10:15:24] [INFO] [GameManager] Auto-saved replay: res://replays/replay_20260927_101524.json (22 commands).
[2026-09-27T10:15:24] [INFO] [LoggingMode] Session ended — closing log file.

Shutting down all instances...
