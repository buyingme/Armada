## SpendDefenseTokenCommand
##
## Spends a defense token on the defending ship during the attack sequence.
## Exhaust or discard is determined by [param spend_method] in the payload.
##
## Payload:
##   "ship_index"   — index of the defending ship in the player's fleet.
##   "token_index"  — index into [member ShipInstance.defense_tokens].
##   "spend_method" — "exhaust" or "discard".
##
## Rules Reference: "Defense Tokens", DT-001/DT-002, p.5 —
## "The defender can spend one or more of its defense tokens."
class_name SpendDefenseTokenCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("spend_defense_token", func(player: int,
			pl: Dictionary) -> GameCommand:
		return SpendDefenseTokenCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "spend_defense_token", p_payload)


## Validates that spending this defense token is legal.
## Attack-step-specific validation (correct step, already spent this attack,
## etc.) is handled by [AttackExecutor] before submitting.
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
	var token_index: int = payload.get("token_index", -1)
	if token_index < 0 or token_index >= ship.defense_tokens.size():
		return "Token index out of range."
	var token: Dictionary = ship.defense_tokens[token_index]
	if token.get("state", -1) == Constants.DefenseTokenState.DISCARDED:
		return "Token already discarded."
	var method: String = payload.get("spend_method", "")
	if method != "exhaust" and method != "discard":
		return "Invalid spend method: '%s'." % method
	return ""


## Exhausts or discards the defense token on the ship.
## Returns {"token_type": int, "spend_method": String, "ship_index": int,
## "token_index": int}.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	var token_index: int = payload.get("token_index", -1)
	var method: String = payload.get("spend_method", "exhaust")
	if method == "discard":
		ship.discard_defense_token(token_index)
	else:
		ship.exhaust_defense_token(token_index)
	var token: Dictionary = ship.defense_tokens[token_index]
	return {
		"token_type": token.get("type", -1),
		"spend_method": method,
		"ship_index": payload.get("ship_index", -1),
		"token_index": token_index,
	}
