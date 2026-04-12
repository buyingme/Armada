## SpendTokenCommand
##
## Spends (removes) a command token from a ship.
## Used during the token-overflow discard flow or when a player
## voluntarily spends a command token during activation.
##
## Payload:
##   "ship_index" — index of the ship in the player's fleet array.
##   "token_type" — [Constants.CommandType] int value of the token.
##
## Rules Reference: "Command Tokens", p.4 — spending / discarding tokens.
## CM-004–006.
class_name SpendTokenCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("spend_token", func(player: int,
			pl: Dictionary) -> GameCommand:
		return SpendTokenCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "spend_token", p_payload)


## Validates that the token spend is legal.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
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
	return ""


## Spends the specified command token.
## Returns {"spent": bool}.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	var token_type: int = payload.get("token_type", -1)
	var ok: bool = ship.command_tokens.spend_token(
			token_type as Constants.CommandType)
	return {"spent": ok,
			"ship_index": payload.get("ship_index", -1),
			"token_type": token_type}
