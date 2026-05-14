# Modal And Overlay Classification (Network UX)

Date: 2026-04-20
Purpose: inventory every modal-like UI flow and classify expected visibility + control ownership for network mode.

How to annotate:
- Change `Guess` values if wrong.
- Fill `Decision` as one of: `Common`, `Private`, `Conditional`.
- Fill `Controller` as one of: `Active`, `NonActive`, `Defender`, `Owner`, `Both (independent)`, `None (read-only)`.
- Add comments in `Notes` and `Open Questions`.

## A. Core Turn And Action Modals

| UI Surface | Class | File | Opened From | Current Behavior (Observed/Inferred) | Decision | Controller | Notes / Open Questions |
|---|---|---|---|---|---|---|---|
| Ship activation flow | ActivationModal | src/ui/combat/activation_modal.gd | game_board step handlers | Main step gate for Ship activation. In network currently mainly local-turn flow. | Common | Active | Should both peers see step progression? If yes, should non-controller see disabled buttons only?  both answers are yes. L4 MT follow-ups: projected Repair auto-advance stays command-driven, Squadron commands can be declined before opening the command modal, and auto-skip timers are step-bound. |
| Squadron phase flow | SquadronActivationModal | src/ui/combat/squadron_activation_modal.gd | squadron_phase_controller | Guides move/attack/skip per squadron activation. | Common | Active | When modal is shown on passive peer: read-only timeline vs disabled controls? implement as disabled controls same as ship activation modal|
| Repair command UI | RepairPanel | src/ui/commands/repair_panel.gd | _on_repair_step_entered | Command spending panel for engineering points. | Common | Active | Passive peer likely should see actions chosen in real time but not click. correct|
| Attack execution UI | AttackSimPanel | src/ui/combat/attack_sim_panel.gd | attack_executor | Mixed flow: attacker controls some steps; defender controls defense token steps. | Common | Conditional | Needs per-step controller handoff (attacker -> defender -> attacker). correct. L4 MT follow-up: CF-token rerolls republish dice results so passive mirrors show the changed die before defense. |
| Targeting list | TargetingListModal | src/ui/combat/targeting_list_modal.gd | toolbar hotkey/tool | Read-only tactical list. | Private | Both (independent) | Planning tool; each player can open independently. correct|
| Command dial assignment | CommandDialPicker | src/ui/commands/command_dial_picker.gd | command_phase_controller | Per-player dial assignment in command phase. | Private | Owner | In network this must remain private; opponent should not see selected dial content. correct|
| Command dial order viewer | CommandDialOrderModal | src/ui/commands/command_dial_order_modal.gd | card panel request | Shows hidden stack order for a ship. | Private | Owner | Must never show opponent hidden dials. correct|
| Immediate effect choice | OpponentChoiceModal | src/ui/opponent_choice_modal.gd | game_board/attack_executor choice hooks | Generic chooser for damage-card immediate effects and debug paths. | Conditional | Owner or NonActive | Controller depends on card effect chooser field. Peer should still see that a choice is pending. correct, both player see the modal only one can make the choices|
| Displacement placement | DisplacementModal | src/ui/commands/displacement_modal.gd | displacement_controller | Checklist + placement commit for displaced squadrons. | Common | Owner | For overlap: controller should be owner of displaced squadron(s), not always active player. thats not correct: correct is: the player that did not cause the overlap (this is the non active player) makes the placement according to the rules|

## B. Turn Transition / Blocking Overlays

| UI Surface | Class | File | Opened From | Current Behavior (Observed/Inferred) | Decision  | Controller | Notes / Open Questions |
|---|---|---|---|---|---|---|---|
| Handoff gate | HandoffOverlay | src/ui/handoff_overlay.gd | active-player transitions, immediate choice flow | Full-screen blocker with Ready. | Common | Active | In pure network, replace with explicit waiting state? Keep only for hot-seat parity? in network game put a small "waiting for opponents choice" below the score headline if player is in passive state|
| Your turn banner | YourTurnBanner | src/ui/hud/your_turn_banner.gd | active-player transitions | Brief transition banner. | Common | None (read-only) | Informational only; no control. if player is active put "make your choices" below the score headline|
| Quit confirmation | GameMenuModal | src/ui/save/game_menu_modal.gd | escape handling | In-game ESC menu (Resume / Save / Load / Quit). Replaced QuitConfirmationModal in Phase J3. | Private | Local player | Pure local UX; no multiplayer authority impact. OK|

## C. Information And Inspection Overlays

| UI Surface | Class | File | Opened From | Current Behavior (Observed/Inferred) | Decision (Guess) | Controller (Guess) | Notes / Open Questions |
|---|---|---|---|---|---|---|---|
| Card zoom | CardDetailOverlay | src/ui/ship/card_detail_overlay.gd | card panel right-click | Full-screen card inspection. | Private | Both (independent) | Should remain local and independent. correct|
| Damage summary | DamageSummaryOverlay | src/ui/ship/damage_summary_overlay.gd | attack resolution | Shows dealt/all damage cards. | Common | None (read-only) | If immediate choices follow, both peers should see summary timing consistently. correct|
| Squadron movement ring | SquadronMoveOverlay | src/ui/combat/squadron_move_overlay.gd | squadron_phase_controller | Range/move overlay while selecting/moving squadron. | Conditional | Active or Owner | During displacement this should track displaced owner controller. OK|
| Range ruler overlay | RangeOverlayScene | src/scenes/tools/range_overlay_scene.gd | range_tool_controller / target_selector | Ship range bands visual aid. | Private | Both (independent) | Planning tool; no authority implications until command submission. OK|
| Attack visual overlay | AttackSimOverlay | src/scenes/tools/attack_sim_overlay.gd | target_selector/attack flow | Arc/LOS/range lines during attack targeting. | Conditional | Active | Passive peer may see mirrored lines (read-only) in shared timeline mode. OK |
| Firing arc overlay | FiringArcOverlay | src/scenes/tokens/firing_arc_overlay.gd | ship token visuals | Arc feedback overlay tied to token presentation. | Common | None (read-only) | Usually passive visual; keep synchronized with token orientation. OK|
| Deployment zone overlay | DeploymentZoneOverlay | src/scenes/game_board/deployment_zone_overlay.gd | setup/deployment flow | Board deployment boundaries. | Common | None (read-only) | Not modal, but shared gating context in setup phase. OK|

## D. Utility / Dev Surfaces

| UI Surface | Class | File | Opened From | Current Behavior (Observed/Inferred) | Decision (Guess) | Controller (Guess) | Notes / Open Questions |
|---|---|---|---|---|---|---|---|
| Debug annotation prompt | DebugAnnotationModal | src/ui/debug/debug_annotation_modal.gd | debug tooling | Local debug note entry. | Private | Local player | No gameplay authority impact. OK|
| Chat panel | ChatPanel | src/ui/chat_panel.gd | chat toggle | In-game chat UI. | Private | Both (independent) | Independent local open/close; shared content stream. OK|
| Reopen squadron modal button | ShowSquadronModalButton | src/ui/hud/show_squadron_modal_button.gd | squadron modal dismiss/reopen | Reopens hidden squadron modal. | Conditional | Active or Owner | Should appear for whichever peer controls current squadron interaction window. OK|

## E. Missing Clarifications Needed Before Implementation

1. During ship activation, should ActivationModal be visible on both clients at all times, with disabled controls on passive peer? both
2. During attack flow, should passive peer see each sub-step live (targeting, roll, reroll, defense, redirect), or only state deltas after each command? yes
3. For defense token windows, should attacker panel remain visible but frozen while defender controls token actions? no attacker should see the same modal as defender
4. For displacement, if multiple displaced squadrons belong to both players, do you want serial ownership handoff in one shared modal timeline? no see above. passive player always places deiplaced squadrons.
5. Do you want any private fog-of-war even for public sequences (for example hide targeting helper overlays from passive peer), or fully mirrored public visuals? fully mirrored
6. Should handoff overlay remain in network mode, or should it be replaced by non-blocking status labels except where a decision is required? should be replaced see above
7. In command phase, should each player see only their own CommandDialPicker, and simultaneously see the other player in a generic "planning..." state? yes implement like this.

## F. Recommended Decision Pattern

For each surface above, tag one of these patterns:
- Pattern P1: Common view + single controller + disabled controls for others.
- Pattern P2: Private independent tool (local only, no replication).
- Pattern P3: Common read-only timeline (no controls for either).
- Pattern P4: Conditional owner/defender control window with explicit server-declared controller.

This map should be completed before implementing T1-T7 to avoid rework.

---

## L-Inventory — Phase L0 audit (2026-05-11)

Inventory of every direct-callback modal lifecycle decision in
`src/scenes/` and `src/ui/` that branches on `PlayMode` or otherwise
opens / closes a modal without going through
`UIProjector.project() → ModalRouter`.

Classification:
- **Lifecycle** — open / close / mirror decision. Must migrate during L1–L5.
- **Affordance** — hot-seat-only UX trigger (e.g. sequence button) that
  has no network analogue. Needs to be re-expressed as a projected
  `UIIntent.affordances` entry or explicitly suppressed.
- **Session-mode dispatcher (KEEP)** — intrinsic deployment-mode site
  (save dialog, load dialog, lobby room, network-only RPC submit).
  These are the post-L allow-list floor (target ≤ 4).
- **Pure local UX** — read-only visuals (tooltip, banner). Out of scope.

Seed: the 7 sites currently allow-listed by `scripts/lint_phase_k.sh`
plus the direct `_displacement_controller.start()` call site (no
`PlayMode` branch but a hot-seat-only lifecycle entry point). Completed
L-slice rows remain in the table for traceability.

| # | File:Line | Symbol / context | Modal target | Classification | L slice | Notes |
|--:|---|---|---|---|---|---|
| 1 | [ship_activation_controller.gd](../src/scenes/game_board/ship_activation_controller.gd) | Token-convert activation sequence button now flows through `UIIntent.affordances["activation_sequence_button"]`; former `elif not PlayMode.is_network()` branch removed | Sequence button affordance | **Affordance (L3 complete)** | — | L3 makes the sequence button a projected non-mutating UI affordance. |
| 2 | [ship_activation_controller.gd](../src/scenes/game_board/ship_activation_controller.gd) | `submit_activation_step` submits `advance_activation_step` in both modes; former `submit_network_activation_step` guard removed | Activation step projection | **Lifecycle (L2 complete)** | — | L2 makes hot-seat produce command-executed projection events for activation sub-step reopens. L4 MT follow-ups keep projected no-repair `REPAIR_STEP` skips on the command path, hide stale past-step buttons during refresh, expose Squadron command decline from the activation modal, and bind auto-skip timers to their original step. |
| 3 | [ship_activation_controller.gd](../src/scenes/game_board/ship_activation_controller.gd) | `_finalize_maneuver_execute` now only submits `start_displacement`; former `if not PlayMode.is_network(): _displacement_controller.start(...)` branch removed | Displacement modal | **Lifecycle (L4 complete)** | — | L4 closes the 2026-05-11 displacement defect class by making hot-seat and network open from the projected `SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE` flow. RRG "Overlapping" p.8: controller is always the opponent of the maneuvering ship's owner. |
| 4 | [game_board.gd](../src/scenes/game_board/game_board.gd) | `_on_active_player_changed` now applies `UIProjector.project_turn_transition()`; former `if PlayMode.is_network(): _handle_network_active_player(...)` branch removed | Handoff overlay vs. "waiting" overlay | **Lifecycle (L5 complete)** | — | Shared-screen handoff, active-player banner, passive waiting status, command-dial startup, and Squadron observer startup are now projected as `UIIntent` fields. |
| 5 | [attack_panel_controller.gd](../src/scenes/game_board/attack_panel_controller.gd) | `react_to_command` handles `resolve_immediate_effect` in both modes | Immediate-choice modal cleanup | **Lifecycle (L2 complete)** | — | `apply_remote_immediate_choice()` is idempotent when no pending choice exists, so hot-seat and network now share the same command-executed cleanup path. |
| 6 | [modal_router.gd](../src/scenes/game_board/modal_router.gd) | `_drive_displacement_modal` opens from projected displacement intent in hot-seat and network; commit resume remains network-only to avoid double-advancing hot-seat camera return | Displacement modal projection path | **Lifecycle (L4 complete)** | — | L4 makes `DisplacementController.start()` a `ModalRouter` effect of the authoritative interaction flow. |
| 7 | [lobby_room.gd:368](../src/scenes/lobby/lobby_room.gd#L368) | `_on_start_game_pressed` early-return `if not PlayMode.is_network()` | (none — lobby flow guard) | **Session-mode dispatcher (KEEP)** | — | Lobby is network-only by definition. Allow-list stays. |
| 8 | [game_menu_modal.gd:403](../src/ui/save/game_menu_modal.gd#L403) | Save button gating `if PlayMode.is_network()` | Save dialog disable | **Session-mode dispatcher (KEEP)** | — | Network mode disables manual save (engine save is host-only). Allow-list stays. |
| 9 | [save_game_dialog.gd:272](../src/ui/save/save_game_dialog.gd#L272) | Save flow `if PlayMode.is_network()` | Save dialog content | **Session-mode dispatcher (KEEP)** | — | Same as #8 — disables save UI in network mode. Allow-list stays. |
| 10 | [load_game_dialog.gd](../src/ui/save/load_game_dialog.gd) | `_is_network_session()` centralises the load dialog's deployment-mode query | Load dialog content/action gating | **Session-mode dispatcher (KEEP, L6 tightened)** | — | Filters which save files appear and decides whether host-side network loads broadcast through `LobbyManager`; lint counts this as one surface after L6. |
| 11 | [load_game_dialog.gd](../src/ui/save/load_game_dialog.gd) | Former second load action `PlayMode.is_network()` branch removed in L6 | Load dialog action gating | **Session-mode dispatcher (L6 complete)** | — | Retained for traceability; no separate lint hit remains. |
| 12 | [ship_activation_controller.gd](../src/scenes/game_board/ship_activation_controller.gd) | `_finalize_maneuver_execute` — `GameManager.submit_start_displacement(...)` is the only displacement producer path | Displacement modal producer | **Lifecycle producer (L4 complete)** | — | Producer now publishes the command/flow only. Modal origin is exclusively `ModalRouter`. |

### L-Inventory summary

| Category | Count | L slice(s) |
|---|---:|---|
| Lifecycle (must migrate)            | 0 | complete |
| Affordance (re-express as `UIIntent.affordances`) | 0 | complete |
| Session-mode dispatcher (KEEP — post-L allow-list floor) | 4 | — |
| Producer-side lifecycle co-anchor | 0 | complete |

### Direct-callback modal-open sites without `PlayMode` branches

These are modal opens that the lint can't currently see (no `PlayMode`
check) but which still bypass projection in hot-seat. They migrate
alongside the corresponding lifecycle slice.

| File:Line | Symbol | Modal | L slice |
|---|---|---|---|
| [ship_activation_controller.gd `configure_and_open_activation_modal`](../src/scenes/game_board/ship_activation_controller.gd) | Projection helper called through `open_modal_from_interaction_state()`; direct activation-entry callbacks removed in L2 | Activation modal | complete |
| [ship_activation_controller.gd `_show_activation_sequence_button`](../src/scenes/game_board/ship_activation_controller.gd) | Projection affordance helper; normal activation-flow show/hide now routes through `apply_activation_sequence_affordance()` | Sequence button | complete |
| [squadron_phase_controller.gd squadron command modal open](../src/scenes/game_board/squadron_phase_controller.gd) | Command-mode modal opens through `ModalRouter -> ShipActivationController.open_squadron_command_from_interaction_state()` on `advance_activation_step("squadron_step")` | Squadron modal | complete |
| [displacement_controller.gd `start()`](../src/scenes/game_board/displacement_controller.gd) | Projection helper called only by [modal_router.gd](../src/scenes/game_board/modal_router.gd) for `SQUADRON_DISPLACEMENT / DISPLACEMENT_PLACE` | Displacement modal | complete |

### Post-L allow-list floor (target ≤ 4)

After L5, only these intrinsic deployment-mode sites remain:
1. `game_menu_modal.gd:403` — save button disable.
2. `save_game_dialog.gd:272` — save dialog content.
3. `load_game_dialog.gd` — load dialog content + action via `_is_network_session()`.
4. `lobby_room.gd:368` — lobby-only flow.

That is 4 surface concerns and 4 lint hits after L6, meeting the post-L
allow-list floor.
