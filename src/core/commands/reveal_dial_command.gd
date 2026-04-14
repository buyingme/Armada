## RevealDialCommand
##
## Reveals or unreveals the top command dial on a ship's dial stack.
## Used during the Ship Phase two-click activation flow:
##   Click 1 → reveal (preview the dial face-up on the card panel)
##   Click 2 → activate (ActivateShipCommand picks up the already-revealed
##              dial and starts the activation)
##
## Also used to unreveal when the player changes their mind (clicks a
## different ship) or cancels a dial drag.
##
## Payload:
##   [code]ship_index[/code] — int — index in the player's fleet
##   [code]action[/code]     — String — "reveal" or "unreveal"
##
## Rules Reference: "Ship Phase", SP-010 — reveal top facedown dial.
class_name RevealDialCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("reveal_dial", func(
			player: int, pl: Dictionary) -> GameCommand:
		return RevealDialCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "reveal_dial", p_payload)


## Validates that the reveal/unreveal is legal.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
	if not payload.has("ship_index"):
		return "Missing ship_index."
	var action: String = payload.get("action", "")
	if action != "reveal" and action != "unreveal":
		return "Invalid action '%s' — must be 'reveal' or 'unreveal'." \
				% action
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Ship not found."
	if ship.command_dial_stack == null:
		return "Ship has no dial stack."
	match action:
		"reveal":
			if ship.command_dial_stack.get_hidden_count() == 0:
				return "No hidden dials to reveal."
			var top: Dictionary = ship.command_dial_stack \
					.get_revealed_dial()
			if not top.is_empty():
				return "Top dial is already revealed."
		"unreveal":
			var top: Dictionary = ship.command_dial_stack \
					.get_revealed_dial()
			if top.is_empty():
				return "No revealed dial to unreveal."
	return ""


## Reveals or unreveals the top dial.
## Returns {"command": int, "action": String, "ship_index": int}.
## "command" is the CommandType of the affected dial, or -1 on failure.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	var action: String = payload.get("action", "")
	var dial: Dictionary = {}
	match action:
		"reveal":
			dial = ship.command_dial_stack.reveal_top()
		"unreveal":
			dial = ship.command_dial_stack.unreveal_top()
	return {
		"command": int(dial.get("command", -1)),
		"action": action,
		"ship_index": payload.get("ship_index", -1),
	}
