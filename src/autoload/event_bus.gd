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

## Emitted when a ship changes speed.
signal ship_speed_changed(ship: Node, new_speed: int)

## Emitted when a ship completes movement.
signal ship_moved(ship: Node)


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
