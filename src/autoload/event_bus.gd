## Event Bus
##
## Central event bus for decoupled communication between game systems.
## Uses Godot signals to implement the observer pattern.
## All game-wide events should be defined and emitted through this singleton.
extends Node


#region Game Flow Events

## Emitted when a new game starts.
signal game_started()

## Emitted when the game ends.
## [param details] — Dictionary with keys: "winner_index" (int), "reason"
## (String: "elimination"/"round_6"/"mutual_destruction"), "scores" (Array[int]),
## "round" (int).
signal game_ended(details: Dictionary)

## Emitted when a new round begins. [param round_number] is the current round (1-based).
signal round_started(round_number: int)

## Emitted when a round ends.
signal round_ended(round_number: int)

## Emitted when the game phase changes.
signal phase_changed(new_phase: Constants.GamePhase)

#endregion


#region Ship Events

## Emitted when a ship is activated.
signal ship_activated(ship: Node)

## Emitted on all peers when the opponent activates a ship in network mode.
## Passive peer listens to set up [ActivationContext] and open the modal as
## a read-only observer.  Not emitted for the local player's own activations.
## G4.6.6 T1a C7.
signal ship_activated_remotely(ship: ShipInstance)

## Emitted when a ship finishes activation.
signal ship_activation_finished(ship: Node)

## Emitted when a ship takes damage.
signal ship_damaged(ship: Node, damage_amount: int, hull_zone: Constants.HullZone)

## Emitted when a ship is destroyed.
signal ship_destroyed(ship: Node)

## Emitted when a ship reveals a command dial.
signal command_revealed(ship: Node, command: Constants.CommandType)

## Emitted when a ship's shields change in a hull zone.
signal ship_shields_changed(ship_instance: RefCounted, zone: String, new_value: int)

## Emitted when a ship's hull points change (damage taken or repaired).
signal ship_hull_changed(ship_instance: RefCounted, new_hull: int)

## Emitted when a ship changes speed.
signal ship_speed_changed(ship_instance: RefCounted, new_speed: int)

## Emitted when the Navigate token spend preview changes during maneuver.
## [param ship_instance] — the ship being activated.
## [param would_spend] — true if the current speed change requires the token.
## Requirements: NAV-007, AC-5b-07.
signal navigate_token_spend_preview(ship_instance: RefCounted, would_spend: bool)

## Emitted when a ship's defense token state changes.
signal ship_defense_token_changed(ship_instance: RefCounted)

## Emitted when a ship completes movement.
signal ship_moved(ship: Node)

## Emitted when a remote maneuver command repositions a ship on the client.
## GameBoard listens to snap the visual ShipToken to the updated position.
## G4.6.5 BF-2.
signal ship_repositioned_remotely(ship_instance: RefCounted)

## Emitted when a squadron's hull points change.
signal squadron_hull_changed(squadron_instance: RefCounted, new_hull: int)

#endregion


#region Squadron Events

## Emitted when a squadron is activated.
signal squadron_activated(squadron: Node)

## Emitted when a squadron finishes its activation (moved and/or attacked).
## GameManager listens to advance the squadron phase turn.
## Requirements: SQ-006, TF-011.
signal squadron_activation_ended(squadron_instance: RefCounted)

## Emitted when a squadron is destroyed.
signal squadron_destroyed(squadron: Node)

## Emitted when a squadron moves.
signal squadron_moved(squadron: Node)

## Emitted when a remote move_squadron command repositions a squadron
## on the client.  G4.6.5 BF-2.
signal squadron_repositioned_remotely(squadron_instance: RefCounted)

#endregion


#region Combat Events

## Emitted when an attack is declared.
signal attack_declared(attacker: Node, defender: Node)

## Emitted when dice are rolled for an attack.
signal dice_rolled(attacker: Node, dice_results: Array)

## Emitted when a network broadcast delivers a dice roll result
## for the local player's attack.  G4.6.5 — async dice resolution.
signal network_dice_result(result: Dictionary)

## Emitted when a new [NetworkInteractionState] has been applied locally.
## Consumed by UI controllers (modals, sidebar, score header) to update
## visibility and permission gates.
## [param state] — the fully applied [NetworkInteractionState] object.
## G4.6.6 T1a C3.
signal interaction_state_changed(state: NetworkInteractionState)

## Emitted when a defense token is spent.
signal defense_token_spent(ship: Node, token_type: Constants.DefenseToken)

## Emitted when damage is resolved.
signal damage_resolved(target: Node, total_damage: int)

#endregion


#region UI Events

## Emitted when a game element is selected by the player.
signal element_selected(element: Node)

## Emitted when selection is cleared.
signal selection_cleared()

## Emitted when the player requests to view details of an element.
signal detail_view_requested(element: Node)

## Emitted when the player toggles the firing arc overlay for a ship token.
## [param token] is the ShipToken node whose arcs should be toggled.
## Rules Reference: UI-011 — player may show/hide firing arcs on a ship.
signal firing_arc_toggled(token: Node)

#endregion


#region Command Phase Events

## Emitted when a ship's command dial stack changes (dial assigned, revealed, or spent).
## [param ship_instance] — the ShipInstance whose dials changed.
signal command_dials_changed(ship_instance: RefCounted)

## Emitted when a ship's command tokens change (token added or spent).
## [param ship_instance] — the ShipInstance whose tokens changed.
signal command_tokens_changed(ship_instance: RefCounted)

## Emitted when a player submits all command dial assignments for the round.
## [param player_index] — the player who submitted (0 or 1).
signal command_dials_submitted(player_index: int)

## Emitted when both players have submitted their dials and the Command Phase
## can transition to the Ship Phase.
## Rules Reference: CP-008 — both players must submit before proceeding.
signal command_phase_complete()

## Emitted to request the command dial picker for a specific ship.
## [param ship_instance] — the ship to assign dials to.
## [param current_round] — the current round number.
signal command_picker_requested(ship_instance: RefCounted, current_round: int)

## Emitted when the command dial picker is confirmed (dials assigned).
## [param ship_instance] — the ship whose dials were assigned.
## [param commands] — array of Constants.CommandType values assigned.
signal command_picker_confirmed(ship_instance: RefCounted, commands: Array)

## Emitted to request the command dial order modal for a specific ship.
## [param ship_instance] — the ship to inspect.
signal command_dial_order_requested(ship_instance: RefCounted)

#endregion


#region Turn Management Events

## Emitted when the active player changes.
## [param player_index] — the new active player (0 or 1).
## Requirements: TF-001 — only the active player can interact.
signal active_player_changed(player_index: int)

## Emitted when the active player presses "End Activation" during
## Ship or Squadron Phase.
## Requirements: TF-005, TF-011.
signal activation_ended()

## Emitted when a handoff overlay or "Your Turn" banner is dismissed
## and the new active player is ready to proceed.
## Requirements: HO-002, HO-004.
signal handoff_accepted()

## Emitted when the board perspective should switch to a given player.
## [param player_index] — the player whose perspective to show.
## Requirements: BP-001, BP-002.
signal perspective_change_requested(player_index: int)

## Emitted when the board perspective rotation animation finishes.
signal perspective_change_complete()

#endregion


#region Repair Command Events

## Emitted when shields are moved between zones via the repair command.
## [param ship_instance] — the ship whose shields changed.
## [param from_zone] — source hull zone String key.
## [param to_zone] — destination hull zone String key.
## Rules Reference: CM-033.
signal repair_shields_moved(ship_instance: RefCounted, from_zone: String, to_zone: String)

## Emitted when a shield is recovered on a zone via the repair command.
## [param ship_instance] — the ship.
## [param zone] — the hull zone String key.
## Rules Reference: CM-034.
signal repair_shields_recovered(ship_instance: RefCounted, zone: String)

## Emitted when a damage card is discarded via the repair command.
## [param ship_instance] — the ship.
## [param card] — the DamageCard that was discarded.
## Rules Reference: CM-035.
signal repair_card_discarded(ship_instance: RefCounted, card: RefCounted)

## Emitted when the repair command resolution is complete.
## [param ship_instance] — the ship.
## [param points_spent] — total engineering points spent.
## Rules Reference: CM-037.
signal repair_command_resolved(ship_instance: RefCounted, points_spent: int)

#endregion


#region Damage Card Events

## Emitted when a damage card flips between faceup and facedown.
## [param ship_instance] — the ship carrying the card.
## [param card] — the DamageCard that flipped.
## [param is_faceup] — true if the card is now faceup, false if facedown.
## Rules Reference: "Damage Cards" — immediate effects flip facedown.
signal damage_card_flipped(ship_instance: RefCounted, card: RefCounted,
		is_faceup: bool)

## Emitted each time a damage card is dealt to a ship (faceup or facedown).
## Used by the UI to show a toast notification.
## [param ship_instance] — the ShipInstance receiving the card.
## [param card] — the DamageCard that was dealt.
## [param is_faceup] — true if dealt faceup (critical), false if facedown.
## Rules Reference: DM-005, DM-006.
signal damage_card_dealt(ship_instance: RefCounted, card: RefCounted,
		is_faceup: bool)

## Emitted after all damage cards for a single attack have been dealt.
## Used by [DamageSummaryOverlay] to show a full-screen card spread.
## [param ship_instance] — the ShipInstance that received damage.
## [param faceup_cards] — Array of DamageCard dealt faceup.
## [param facedown_count] — number of facedown cards dealt.
## [param ship_name] — display name of the damaged ship.
## Rules Reference: DM-005, DM-006.
signal damage_summary_requested(ship_instance: RefCounted,
		faceup_cards: Array, facedown_count: int, ship_name: String)

## Emitted when the player dismisses the [DamageSummaryOverlay].
## AttackExecutor listens to this to resolve deferred immediate effects.
## Rules Reference: DM-005 — player sees faceup card before effect resolves.
signal damage_summary_dismissed()

#endregion


#region Token Discard Events

## Emitted when a force-added command token causes overflow (tokens > command
## value) and the player must choose one token to discard.
## [param ship_instance] — the ship that must discard a token.
## Rules Reference: "Command Tokens", p.4 — "if it has more command tokens
## than its command value, it must immediately discard one of its command tokens."
signal token_discard_required(ship_instance: RefCounted)

## Emitted after the player (or auto-logic) discards a token to resolve
## an overflow or duplicate situation.
## [param ship_instance] — the ship whose token was discarded.
## [param discarded_type] — Constants.CommandType value of the discarded token.
signal token_discarded(ship_instance: RefCounted, discarded_type: int)

## Emitted when a duplicate token is automatically discarded, so the UI can
## show a brief notification to the player.
## [param ship_instance] — the ship that had the duplicate.
## [param token_type] — Constants.CommandType value of the discarded duplicate.
signal duplicate_token_discarded(ship_instance: RefCounted, token_type: int)

#endregion


#region Dial Drag Events

## Emitted when the player starts dragging a command dial from the card panel.
## [param ship_instance] — the ship whose topmost dial is being dragged.
## Requirements: UI-024.
signal dial_drag_started(ship_instance: RefCounted)

## Emitted when a dial drag is cancelled (released on invalid target).
signal dial_drag_cancelled()

#endregion


#region Maneuver Tool Events

## Emitted when the player presses the "Display Maneuver Tool" button.
## Requirements: MT-U-002.
signal maneuver_tool_requested()

## Emitted when the maneuver tool should be dismissed.
## Requirements: MT-U-006.
signal maneuver_tool_dismissed()

## Emitted when the player presses the "Range Overlay" button.
## Requirements: RO-002.
signal range_overlay_requested()

## Emitted when the range overlay should be dismissed.
## Requirements: RO-006.
signal range_overlay_dismissed()

## Emitted when the player presses the "Targeting List" button.
## Requirements: TL-UI-001.
signal targeting_list_requested()

## Emitted when the player presses the "Attack Simulator" button.
## Requirements: AS-ACT-001, AS-ACT-002.
signal attack_simulator_requested()

#endregion


#region Activation / Maneuver Execution Events

## Emitted when the player presses "Show Activation Sequence".
## Requirements: ACT-007.
signal activation_sequence_requested()

## Emitted when the Execute Maneuver step becomes active in the modal.
## Requirements: FLOW-003, AC-5b-03.
signal maneuver_step_entered()

## Emitted when the player presses "Execute Maneuver" to commit the move.
## Requirements: EXE-001, AC-5b-08.
signal execute_maneuver_requested()

## Emitted after the ship has been placed at its final position.
## [param ship_node] — the ShipToken that was moved.
## Requirements: EXE-002, AC-5b-09, AC-5b-13.
signal maneuver_executed(ship_node: Node)

#endregion
