## EndActivationCommand
##
## Ends a ship's activation during the Ship Phase.
## Spends the revealed command dial (if still revealed) and marks the
## ship as activated this round.
##
## Payload:
##   "ship_index" — index of the ship in the player's fleet array.
##
## Rules Reference: "Ship Phase", CM-007 — after activation, dial is discarded.
## SP-001 — each ship activates once per round.
class_name EndActivationCommand
extends GameCommand


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("end_activation", func(player: int,
			pl: Dictionary) -> GameCommand:
		return EndActivationCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "end_activation", p_payload)


## Validates that ending activation is legal.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Ship not found."
	if ship.activated_this_round:
		return "Ship already activated."
	return ""


## Spends the revealed dial, marks ship activated.
## Returns {"spent_command": int} or {"spent_command": -1} if no dial.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	var revealed: Dictionary = \
			ship.command_dial_stack.get_revealed_dial()
	var spent_command: int = -1
	if not revealed.is_empty():
		var spent: Dictionary = \
				ship.command_dial_stack.spend_revealed()
		if not spent.is_empty():
			spent_command = int(spent.get("command", -1))
	ship.activated_this_round = true
	var next_active_player: int = Constants.PLAYER_COUNT - 1 - player_index
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			game_state,
			{"active_player": next_active_player},
			Constants.Visibility.ALL)
	return {"spent_command": spent_command,
			"ship_index": payload.get("ship_index", -1)}
