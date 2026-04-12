## AssignDialCommand
##
## Assigns command dials to a ship during the Command Phase.
## Wraps [method CommandDialStack.assign_dials] as a serializable command.
##
## Payload:
##   "ship_index" — index of the ship in the player's fleet array.
##   "commands"   — Array of [Constants.CommandType] values to assign.
##
## Rules Reference: "Command Phase", p.3; CP-001–007.
class_name AssignDialCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("assign_dials", func(player: int,
			pl: Dictionary) -> GameCommand:
		return AssignDialCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "assign_dials", p_payload)


## Validates that the command is legal in the current game state.
## Returns "" if valid, or an error message.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.COMMAND:
		return "Not in Command Phase."
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Ship not found."
	if ship.command_dial_stack == null:
		return "Ship has no dial stack."
	var commands: Array = payload.get("commands", [])
	var needed: int = ship.command_dial_stack.get_dials_needed()
	if commands.size() != needed:
		return "Expected %d dials, got %d." % [needed, commands.size()]
	return ""


## Executes the dial assignment. Returns a result dictionary.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	var commands: Array = payload.get("commands", [])
	var ok: bool = ship.command_dial_stack.assign_dials(
			commands, game_state.current_round)
	return {"success": ok, "ship_index": payload.get("ship_index", -1)}
