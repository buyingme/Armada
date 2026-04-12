## SpendDialCommand
##
## Spends (removes) the revealed command dial from a ship's dial stack,
## or discards the top dial if not yet revealed (Crew Panic fallback).
##
## Payload:
##   "ship_index" — index of the ship in the player's fleet array.
##   "mode"       — (optional) "spend" (default) or "discard".
##                  "spend" calls [method CommandDialStack.spend_revealed],
##                  "discard" calls [method CommandDialStack.discard_top].
##
## Rules Reference: CM-007 — after activation, dial is discarded.
## Rules Reference: "Crew Panic" — discard that dial.
class_name SpendDialCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("spend_dial", func(player: int,
			pl: Dictionary) -> GameCommand:
		return SpendDialCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "spend_dial", p_payload)


## Validates that the dial spend is legal.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Ship not found."
	if ship.command_dial_stack == null:
		return "Ship has no command dial stack."
	var mode: String = payload.get("mode", "spend")
	match mode:
		"spend":
			var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
			if revealed.is_empty():
				return "No revealed dial to spend."
		"discard":
			if ship.command_dial_stack.get_dial_count() == 0:
				return "Dial stack is empty — nothing to discard."
		_:
			return "Invalid mode: '%s'." % mode
	return ""


## Spends or discards the top dial.
## Returns {"spent": bool, "ship_index": int, "command": int, "mode": str}.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	var mode: String = payload.get("mode", "spend")
	var dial: Dictionary = {}
	match mode:
		"spend":
			dial = ship.command_dial_stack.spend_revealed()
		"discard":
			dial = ship.command_dial_stack.discard_top()
	var ok: bool = not dial.is_empty()
	return {
		"spent": ok,
		"ship_index": payload.get("ship_index", -1),
		"command": dial.get("command", -1),
		"mode": mode,
	}
