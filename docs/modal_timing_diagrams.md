# Modal Timing Diagrams (Network Mode)

> **Purpose:** Plain-text sequence/timing diagrams of how each modal is opened,
> advanced and closed across both peers in network play, for human review of
> producer/subscriber wiring during Phase I refactoring.
>
> Notation:
> - **`[A]`** = the *active* peer (the one whose user clicks to drive the flow).
> - **`[P]`** = the *passive* / observer peer (mirrors via authoritative
>   command stream).
> - `signal()` and `command_executed()` are emitted by autoloads
>   ([CommandProcessor], [EventBus]); subscribers run synchronously in
>   connect-order on each peer.
>
> Status legend at end of each section:
> - ✅  the path is implemented and matches manual-test evidence
> - 🟡  legacy parallel channel still exists alongside (Phase I migration target)
> - 🐞  known gap; tracked under a fix note

---

## 1. Squadron Activation Modal (`SqActModal`)

### 1.1 Phase entry — Ship → Squadron

```
[A=host] CommandProcessor.execute(advance_phase)
    └─► AdvancePhaseCommand.execute(gs)
          ├─ gs.current_phase ← SQUADRON
          └─ gs.interaction_flow ← squadron_phase / wait_for_squad_select
                                    controller = active_player (initiative)
    └─► EventBus.command_executed(advance_phase, ...)
[A] GameManager._begin_squadron_phase()
    ├─ _squadrons_activated_this_turn = 0
    ├─ _set_active_player(initiative)
    │     └─► EventBus.active_player_changed(initiative)
    └─► EventBus.phase_changed(SQUADRON)

[A] GameBoard._handle_network_active_player(initiative)
    ├─ _update_activation_modal_interactivity()
    │     └─ _is_local_squadron_modal_controller()
    │           returns (active_player == local)              ← post-fix I5b-2
    ├─ if initiative == local:
    │     └─ YourTurnBanner.show()  (waits for click)
    │           └─► EventBus.handoff_accepted
    │                 └─► SquadronPhaseController.begin_activation_flow()
    │                       └─ _squadron_modal.open_for_turn(1, 2)
    └─ else (passive on this peer):
          └─ SquadronPhaseController.begin_activation_flow()  [observer]
                └─ _squadron_modal.open_for_turn(1, 2) interactable=false

[P=client] CommandProcessor.command_executed(advance_phase) (mirror apply)
    └─► GameManager._begin_squadron_phase_client()
          └─► EventBus.active_player_changed(initiative)
    └─► GameBoard._handle_network_active_player(initiative)
          └─ same branching as above on [P]
```

**Result:** modal visible on both peers, `State.WAITING_FOR_SELECTION`.

Status: ✅

---

### 1.2 Activation N — local click on `[A]`

```
[A] User clicks squadron token
    └─► SquadronPhaseController.try_handle_squadron_click(token)
          ├─ _squadron_modal.handle_squadron_click(token)
          │     └─ _apply_squadron_selection() → State=ACTION_CHOICE
          │     └─ emits squadron_selected (legacy)
          └─ _on_squadron_selected_in_modal(token)
                └─ shows range overlay (+ engagement / has_targets)

[A] (independently) the same click ALSO calls
    GameManager.activate_squadron(instance)                  ← legacy path
    ├─ guard `_activating_squadron != null` → reject
    ├─ ActivateSquadronCommand(player, {squadron_index})
    └─► _submitter.submit(cmd)

CommandProcessor.execute(activate_squadron)
    └─ ActivateSquadronCommand.execute(gs)
          └─ gs.interaction_flow ← squadron_phase / action_choice
                                    controller = command.player_index
    └─► EventBus.command_executed(activate_squadron, result)

  Subscribers fire on BOTH peers in connect-order:

[A]+[P] SquadronPhaseController._on_command_executed_select_squadron
    ├─ command_type == "activate_squadron" ✓
    ├─ phase == SQUADRON ✓
    ├─ resolve `instance` from command.player_index + squadron_index
    ├─ if modal already showing this instance → idempotent return  ([A])
    └─ else _squadron_modal.select_squadron_remote(token, instance) ([P])
            ├─ guard not visible → false
            ├─ guard _state != WAITING_FOR_SELECTION → false       ← see 1.4 🐞
            └─ _apply_squadron_selection() → State=ACTION_CHOICE
          → caller invokes _on_squadron_selected_in_modal(token)
                └─ shows range overlay on [P]

[A]+[P] GameBoard._on_command_executed_project_ui
    └─ HUD ← "make your choices" (active==local)
       HUD ← "waiting for opponent's choice" (otherwise)
```

Status: ✅ (with caveat — see 1.4 below)

---

### 1.3 Move squadron N

```
[A] User drags + clicks → SquadronPhaseController._on_squadron_move_commit
    └─► GameManager.submit_move_squadron(instance, norm_x, norm_y)
          └─► CommandProcessor.execute(move_squadron)
                └─ MoveSquadronCommand.execute(gs)
                      (squadron position update; no interaction_flow change)
                └─► EventBus.command_executed(move_squadron, result)

[A] SquadronPhaseController._on_squadron_activation_done(instance)
    ├─ _squadron_activation_count += 1
    ├─ if count < 2: _squadron_modal.open_for_turn(next, 2)
    └─ else: hide_ui()

[A] GameManager._on_squadron_activation_ended(sq)             ← legacy
    ├─ sq.activated_this_round = true
    └─ if !network_client:
          _activating_squadron = null
          _squadrons_activated_this_turn += 1
          if reached limit → _advance_squadron_phase_turn()

[P] CommandProcessor.command_executed(move_squadron)
    ├─ GameManager._handle_remote_move_squadron(cmd)          ← legacy mirror
    │     ├─ sq.activated_this_round = true
    │     ├─ _activating_squadron = null
    │     └─ _finish_remote_squadron_activation()
    │           └─ counter++, if limit reached → advance turn
    └─ SquadronPhaseController._on_command_executed_advance_after_move ← I5b-1
          ├─ guard player_index == local → skip (active peer)
          ├─ guard phase == SQUADRON ✓
          ├─ _squadron_activation_count += 1
          └─ if count < 2:
                _squadron_modal.open_for_turn(next, 2)
                _squadron_modal.set_interactable(_modal_interactable)
            else: skip (turn handoff path will reset)
```

Status: ✅ post-fix I5b-1 (was 🐞: passive peer's modal stayed in
`ACTION_CHOICE`, blocking the next `select_squadron_remote`).

---

### 1.4 Turn handoff (player 0 → player 1, mid-phase)

```
[A=last-mover] GameManager._advance_squadron_phase_turn  (host only)
    ├─ _squadrons_activated_this_turn = 0
    └─ _set_active_player(1 - active)
          └─► EventBus.active_player_changed(other)

both peers → GameBoard._handle_network_active_player(other)
    ├─ _update_activation_modal_interactivity()
    │     └─ active==local? recompute set_interactable
    └─ if other == local: YourTurnBanner.show + handoff click → begin_activation_flow
       else (now-passive peer): begin_activation_flow [observer]
             └─ _squadron_modal.open_for_turn(1, 2)  resets State + count
```

> ⚠ No `interaction_state` broadcast happens on this transition in the
> legacy path — the only authoritative event is `active_player_changed`.
> Phase I6 will replace this with an interaction-flow update from a
> `set_active_player_command` or equivalent.

Status: ✅ but produced by `active_player_changed` (legacy).

---

### 1.5 Phase exit (both players exhausted)

```
[host] GameManager._advance_squadron_phase_turn
    └─ both lack unactivated → advance_phase()
          └─► CommandProcessor.execute(advance_phase, next=...)
                └─ AdvancePhaseCommand mirrors interaction_flow
                └─► EventBus.command_executed
[A]+[P] SquadronPhaseController.hide_ui() (via the active_player_changed
        + phase change paths)
```

Status: ✅

---

### 1.6 Authoritative producers per side-effect (post-I5b)

| Side effect | Producer |
|---|---|
| Open modal at phase start | `EventBus.handoff_accepted` (active peer); `_handle_network_active_player` observer branch (passive peer) |
| Modal reaches `ACTION_CHOICE` | `command_executed(activate_squadron)` → `select_squadron_remote` |
| Range overlay on **both** peers | `_on_squadron_selected_in_modal` invoked from the controller's `command_executed` handler |
| Modal back to `WAITING_FOR_SELECTION` between activations | **[A]:** `_on_squadron_activation_done` (modal `move_commit`)<br>**[P]:** `command_executed(move_squadron)` → `_on_command_executed_advance_after_move` (I5b-1) |
| Range/move overlay removed between activations | **[A]:** `_on_squadron_move_commit` / `_on_squadron_activation_done`<br>**[P]:** same `_on_command_executed_advance_after_move` (I5b-3) |
| Range/move overlay removed on turn handoff | `begin_activation_flow` (now drops overlay before `open_for_turn`) — I5b-3 |
| Modal reset on turn handoff | `EventBus.active_player_changed` → `begin_activation_flow` |
| Interactivity gate | `_is_local_squadron_modal_controller()` = `(active_player == local)` — no longer reads stale `_interaction_controller_player` (I5b-2) |
| HUD "make your choices" / "waiting…" | `command_executed` → `UIProjector.project` |
| Modal hide at phase end | `command_executed(advance_phase)` → controller / phase listener |

---

## 2. Ship Activation Modal (`ActivationModal`)  ⏳

> *Phase I5c — diagram to be added when the activation-modal sub-step is
> migrated off the legacy `NetworkInteractionState` channel.*

---

## 3. Attack Panel & Defense-Token Modal  ⏳

> *Phase I6 — diagrams to be added when the attack-flow FSM (already
> publishing in `gs.interaction_flow.payload`) drives UI projection.*

---

## Fix log

| ID | Fix | Files | Commit |
|---|---|---|---|
| I5b-1 | Passive peer modal reset after `move_squadron` | `src/scenes/game_board/squadron_phase_controller.gd` | `735de7f` |
| I5b-2 | Squadron-modal interactivity gate uses `active_player == local` (was stale `_interaction_controller_player`) | `src/scenes/game_board/game_board.gd` | `735de7f` |
| I5b-3 | Drop lingering range/move overlay on observer between activations and on turn handoff | `src/scenes/game_board/squadron_phase_controller.gd` | `735de7f` |
| I5b-4 | Client `_handle_remote_start_round` uses `_set_active_player` so `active_player_changed` fires → Command Phase round 2+ opens dial panel on client | `src/autoload/game_manager.gd` | `735de7f` |
| I5b-5 | Close [CommandDialPicker] on `command_phase_complete` so the speculative round-1 picker (opened by I5b-4 right before the host broadcasts fixed-dial mirrors) cannot be confirmed during Ship Phase. Server was rejecting these as "Not in Command Phase." | `src/scenes/game_board/command_phase_controller.gd` | `735de7f` |
| I6a | `game_board.gd` no longer subscribes to `EventBus.interaction_state_changed`; HUD status, activation-step sync and modal lifecycle all read from `GameState.interaction_flow` after `CommandProcessor.command_executed`. Adds 4 missing ship-activation sub-step ids to `Constants.InteractionStep` (SQUADRON_STEP, REPAIR_STEP, ATTACK_STEP, ACTIVATION_DONE) so the I2 mirror is complete. Mirror open call moved into `_on_remote_ship_activated` so passive peer reliably opens activation modal. Legacy parallel-channel producer + RPC stay alive (deleted in I6c). | `src/scenes/game_board/game_board.gd`, `src/autoload/constants.gd` | `e288fa9` (MT-PHI.06a passed 2026-04-28) |
| I6b | `UIProjector.UIIntent` extended with `flow_type`, `step_id`, `modal_kind` (new `Constants.ModalKind` enum) and deep-copied `payload`. All attack sub-steps (DECLARE/ROLL/MODIFY/DEFENSE_TOKENS/RESOLVE_DAMAGE/CRITICAL_CHOICE) project to dedicated modal kinds. Pure data extension; no UI behavior change yet. Defender mirror wiring in I6b slice 2. | `src/core/network/ui_projector.gd`, `src/autoload/constants.gd`, `tests/unit/test_ui_projector.gd` | `1900e24` slice 1 / `7f329bf` slice 2 |
| I6c | Deleted the legacy parallel-channel surface in full: `NetworkInteractionState` class + `EventBus.interaction_state_changed` signal + `NetworkManager.broadcast_interaction_state` / `_receive_interaction_state` / `interaction_state_received` / `_latest_interaction_state` / `get_latest_interaction_state` + `GameManager._publish_interaction_state_for_command` / `_broadcast_interaction_step` / `_on_interaction_state_received` / `_apply_interaction_state_if_ready` / `_flush_pending_interaction_states` and the `_last_applied_command_seq` / `_last_interaction_version` / `_pending_interaction_by_version` ordering buffer. Deleted `tests/unit/test_network_interaction_state.gd` and `tests/unit/test_game_manager_interaction_state.gd`. `interaction_flow` is now the sole authoritative interaction-state surface; UI flow lifecycle is driven exclusively by `CommandProcessor.command_executed` → `UIProjector.project()`. 130 / 2 701 / 5 039. | `src/core/network/network_interaction_state.gd` (DEL), `src/autoload/event_bus.gd`, `src/autoload/network_manager.gd`, `src/autoload/game_manager.gd`, `src/scenes/game_board/game_board.gd`, `src/core/network/ui_projector.gd`, `tests/unit/test_network_interaction_state.gd` (DEL), `tests/unit/test_game_manager_interaction_state.gd` (DEL), `tests/unit/test_phase_i2_invariant.gd` | MT-PHI.06c passed 2026-04-28 |
