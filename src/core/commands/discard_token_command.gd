## DiscardTokenCommand
##
## Discards a command token from a ship during the token-overflow flow.
## When a dial-to-token conversion causes the ship to exceed its command
## value, the player must choose one token to discard.  This command wraps
## that mutation for replay and network determinism.
##
## Payload:
##   [code]ship_index[/code]  — int — index in the player's fleet
##   [code]token_type[/code]  — int — [Constants.CommandType] value to discard
##
## Rules Reference: "Command Tokens", p.4 — "If a ship ever has more
## command tokens than its command value, it must immediately discard
## tokens down to its command value."  CM-004.
class_name DiscardTokenCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("discard_token", func(
			player: int, pl: Dictionary) -> GameCommand:
		return DiscardTokenCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "discard_token", p_payload)


## Validates that the discard is legal.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if not payload.has("ship_index"):
		return "Missing ship_index."
	if not payload.has("token_type"):
		return "Missing token_type."
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Ship not found."
	if ship.command_tokens == null:
		return "Ship has no command token manager."
	var token_type: int = payload.get("token_type", -1)
	if not ship.command_tokens.has_token(
			token_type as Constants.CommandType):
		return "Ship does not have that token."
	if ship.command_tokens.get_token_count() \
			<= ship.command_tokens.max_tokens:
		return "Ship is not in overflow — no discard needed."
	return ""


## Removes the specified command token.
## Returns {"discarded": bool, "ship_index": int, "token_type": int}.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	var token_type: int = payload.get("token_type", -1)
	var ok: bool = ship.command_tokens.remove_token(
			token_type as Constants.CommandType)
	return {
		"discarded": ok,
		"ship_index": payload.get("ship_index", -1),
		"token_type": token_type,
	}
