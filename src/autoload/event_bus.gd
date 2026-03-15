## Event Bus
##
## Central event bus for decoupled communication between game systems.
## Uses Godot signals to implement the observer pattern.
## All game-wide events should be defined and emitted through this singleton.
extends Node


# --- Game Flow Events ---

## Emitted when a new game starts.
signal game_started()

## Emitted when the game ends. [param winner_index] indicates the winning player.
signal game_ended(winner_index: int)

## Emitted when a new round begins. [param round_number] is the current round (1-based).
signal round_started(round_number: int)

## Emitted when a round ends.
signal round_ended(round_number: int)

## Emitted when the game phase changes.
signal phase_changed(new_phase: Constants.GamePhase)


# --- Ship Events ---

## Emitted when a ship is activated.
signal ship_activated(ship: Node)

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

## Emitted when a ship's defense token state changes.
signal ship_defense_token_changed(ship_instance: RefCounted)

## Emitted when a ship completes movement.
signal ship_moved(ship: Node)

## Emitted when a squadron's hull points change.
signal squadron_hull_changed(squadron_instance: RefCounted, new_hull: int)


# --- Squadron Events ---

## Emitted when a squadron is activated.
signal squadron_activated(squadron: Node)

## Emitted when a squadron is destroyed.
signal squadron_destroyed(squadron: Node)

## Emitted when a squadron moves.
signal squadron_moved(squadron: Node)


# --- Combat Events ---

## Emitted when an attack is declared.
signal attack_declared(attacker: Node, defender: Node)

## Emitted when dice are rolled for an attack.
signal dice_rolled(attacker: Node, dice_results: Array)

## Emitted when a defense token is spent.
signal defense_token_spent(ship: Node, token_type: Constants.DefenseToken)

## Emitted when damage is resolved.
signal damage_resolved(target: Node, total_damage: int)


# --- UI Events ---

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


# --- Command Phase Events ---

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


# --- Turn Management Events (Phase 4b) ---

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
