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
| Ship activation flow | ActivationModal | src/ui/combat/activation_modal.gd | game_board step handlers | Main step gate for Ship activation. In network currently mainly local-turn flow. | Common | Active | Should both peers see step progression? If yes, should non-controller see disabled buttons only?  both answers are yes|
| Squadron phase flow | SquadronActivationModal | src/ui/combat/squadron_activation_modal.gd | squadron_phase_controller | Guides move/attack/skip per squadron activation. | Common | Active | When modal is shown on passive peer: read-only timeline vs disabled controls? implement as disabled controls same as ship activation modal|
| Repair command UI | RepairPanel | src/ui/commands/repair_panel.gd | _on_repair_step_entered | Command spending panel for engineering points. | Common | Active | Passive peer likely should see actions chosen in real time but not click. correct|
| Attack execution UI | AttackSimPanel | src/ui/combat/attack_sim_panel.gd | attack_executor | Mixed flow: attacker controls some steps; defender controls defense token steps. | Common | Conditional | Needs per-step controller handoff (attacker -> defender -> attacker). correct|
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
| Quit confirmation | QuitConfirmationModal | src/ui/quit_confirmation_modal.gd | escape handling | Local quit confirmation. | Private | Local player | Pure local UX; no multiplayer authority impact. OK|

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
