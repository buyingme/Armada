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


const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")


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
## Allowed in both Ship and Squadron phases (defense tokens apply to all attacks).
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
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
	var ecm_error: String = ECM_SCRIPT.validate_authorized_token_spend(
			game_state, ship, int(payload.get("ship_index", -1)), token_index)
	if ecm_error != "":
		return ecm_error
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
	var ecm_runtime_upgrade_id: String = ECM_SCRIPT.consume_authorization_for_spend(
			game_state, ship, token_index)
	var token: Dictionary = ship.defense_tokens[token_index]
	_record_spent_token_type(game_state, int(token.get("type", -1)))
	return {
		"token_type": token.get("type", -1),
		"spend_method": method,
		"ship_index": payload.get("ship_index", -1),
		"token_index": token_index,
		"ecm_runtime_upgrade_id": ecm_runtime_upgrade_id,
		"ecm_authorized": not ecm_runtime_upgrade_id.is_empty(),
	}


func _record_spent_token_type(game_state: GameState,
		token_type: int) -> void:
	if game_state == null or game_state.interaction_flow == null:
		return
	if game_state.interaction_flow.flow_type != Constants.InteractionFlow.ATTACK \
			or game_state.interaction_flow.step_id \
					!= Constants.InteractionStep.ATTACK_DEFENSE_TOKENS:
		return
	var spent: Array = game_state.interaction_flow.payload.get(
			"spent_defense_token_types", []) as Array
	if not spent.has(token_type):
		spent.append(token_type)
	game_state.interaction_flow.payload["spent_defense_token_types"] = spent
