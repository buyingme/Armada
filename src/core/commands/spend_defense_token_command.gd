## SpendDefenseTokenCommand
##
## Spends a defense token on the canonical defender during the attack sequence.
## Exhaust or discard is determined by [param spend_method] in the payload.
##
## Payload:
##   "defender_kind"  — canonical participant kind (ship or squadron).
##   "defender_index" — index of the defender in the matching fleet list.
##   "token_index"    — index into the defender's defense-token list.
##   "spend_method"   — "exhaust" or "discard".
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
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return "No current attack."
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if attack.stage != CurrentAttackState.STAGE_DEFENSE \
			or attack.defense_stage != CurrentAttackState.DEFENSE_RESOLVING:
		return "Defense-token resolution is not active."
	if player_index != attack.defender_player \
			or not _payload_matches_defender(attack):
		return "Defense-token spend does not match the current defender."
	var defender: RefCounted = _defender(game_state, attack)
	if defender == null:
		return "Defender not found."
	var tokens: Array[Dictionary] = _defense_tokens(defender)
	var token_index: int = payload.get("token_index", -1)
	if token_index < 0 or token_index >= tokens.size():
		return "Token index out of range."
	if not attack.committed_defense_tokens.has(token_index):
		return "Defense token was not committed."
	if token_index != _next_unresolved_token(attack):
		return "Defense tokens must resolve in committed order."
	var token: Dictionary = tokens[token_index]
	if typeof(payload.get("expected_token_type")) != TYPE_INT \
			or int(payload.get("expected_token_type")) \
					!= int(token.get("type", -1)):
		return "Stale defense-token reference."
	for effect: Dictionary in attack.resolved_defense_effects:
		if int(effect.get("token_index", -1)) == token_index:
			return "Defense token effect already resolved."
	if token.get("state", -1) == Constants.DefenseTokenState.DISCARDED:
		return "Token already discarded."
	if defender is ShipInstance \
			and (defender as ShipInstance).current_speed == 0:
		return "A speed-0 defender cannot spend defense tokens."
	var method: String = payload.get("spend_method", "")
	if method != "exhaust" and method != "discard":
		return "Invalid spend method: '%s'." % method
	if defender is ShipInstance:
		var ecm_error: String = ECM_SCRIPT.validate_authorized_token_spend(
				game_state, defender as ShipInstance,
				attack.defender_index, token_index)
		if ecm_error != "":
			return ecm_error
	var spent_types: Dictionary = {}
	for effect: Dictionary in attack.resolved_defense_effects:
		spent_types[int(effect.get("token_type", -1))] = true
	var resolver := DefenseTokenResolver.new()
	var locked_for_generic_check: Array[int] = attack.accuracy_locked_tokens
	if locked_for_generic_check.has(token_index):
		# ECM authorization above is the sole accepted exception to Accuracy.
		locked_for_generic_check = []
	if not resolver.is_token_spendable(token_index, token, spent_types,
			locked_for_generic_check, defender, attack.defender_zone):
		return "Defense token is not spendable in the current attack."
	var required_method: String = resolver.resolve_spend_method(method, token)
	if method != required_method:
		return "Exhausted defense tokens must be discarded."
	return ""


## Exhausts or discards the defense token on the ship.
## Returns {"token_type": int, "spend_method": String, "ship_index": int,
## "token_index": int}.
func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return _execute_legacy_direct_call(game_state)
	var defender: RefCounted = _defender(game_state, attack)
	var tokens: Array[Dictionary] = _defense_tokens(defender)
	var token_index: int = payload.get("token_index", -1)
	var method: String = payload.get("spend_method", "exhaust")
	var token: Dictionary = tokens[token_index]
	var token_type: int = int(token.get("type", -1))
	var effects: Array[Dictionary] = attack.resolved_defense_effects
	if token_type not in [Constants.DefenseToken.EVADE,
			Constants.DefenseToken.REDIRECT]:
		effects.append({"token_index": token_index, "token_type": token_type})
	var defense_stage: String = CurrentAttackState.DEFENSE_RESOLVING
	if _all_committed_effects_resolved(
			attack.committed_defense_tokens, effects):
		defense_stage = CurrentAttackState.DEFENSE_COMPLETE
	var replacement: CurrentAttackState = attack.with_patch({
		"resolved_defense_effects": effects,
		"defense_stage": defense_stage,
	})
	if replacement == null or not game_state.set_current_attack_state(replacement):
		return {}
	if method == "discard":
		defender.call("discard_defense_token", token_index)
	else:
		defender.call("exhaust_defense_token", token_index)
	var ecm_runtime_upgrade_id: String = ""
	if defender is ShipInstance:
		ecm_runtime_upgrade_id = ECM_SCRIPT.consume_authorization_for_spend(
				game_state, defender as ShipInstance, token_index)
	return {
		"attack_id": attack.attack_id,
		"token_type": token.get("type", -1),
		"spend_method": method,
		"defender_kind": attack.defender_kind,
		"defender_index": attack.defender_index,
		"ship_index": attack.defender_index \
				if attack.defender_kind == CurrentAttackState.KIND_SHIP else -1,
		"token_index": token_index,
		"ecm_runtime_upgrade_id": ecm_runtime_upgrade_id,
		"ecm_authorized": not ecm_runtime_upgrade_id.is_empty(),
	}


## Keeps direct unit-level execute calls null-safe. CommandProcessor always
## validates first, so this path cannot bypass current-attack authority.
func _execute_legacy_direct_call(game_state: GameState) -> Dictionary:
	var kind: String = str(payload.get(
			"defender_kind", CurrentAttackState.KIND_SHIP))
	var index: int = int(payload.get(
			"defender_index", payload.get("ship_index", -1)))
	var defender: RefCounted = game_state.get_ship(player_index, index) \
			if kind == CurrentAttackState.KIND_SHIP \
			else game_state.get_squadron(player_index, index)
	var tokens: Array[Dictionary] = _defense_tokens(defender)
	var token_index: int = int(payload.get("token_index", -1))
	if defender == null or token_index < 0 or token_index >= tokens.size():
		return {}
	var method: String = str(payload.get("spend_method", "exhaust"))
	defender.call("discard_defense_token" if method == "discard" \
			else "exhaust_defense_token", token_index)
	return {
		"token_type": int(tokens[token_index].get("type", -1)),
		"spend_method": method,
		"defender_kind": kind,
		"defender_index": index,
		"ship_index": index if kind == CurrentAttackState.KIND_SHIP else -1,
		"token_index": token_index,
	}


func _payload_matches_defender(attack: CurrentAttackState) -> bool:
	var kind: String = str(payload.get(
			"defender_kind", CurrentAttackState.KIND_SHIP))
	var index: int = int(payload.get(
			"defender_index", payload.get("ship_index", -1)))
	return kind == attack.defender_kind and index == attack.defender_index


func _defender(game_state: GameState,
		attack: CurrentAttackState) -> RefCounted:
	if attack.defender_kind == CurrentAttackState.KIND_SHIP:
		return game_state.get_ship(attack.defender_player, attack.defender_index)
	return game_state.get_squadron(
			attack.defender_player, attack.defender_index)


func _defense_tokens(defender: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if defender != null:
		result.assign(defender.get("defense_tokens") as Array)
	return result


func _all_committed_effects_resolved(committed: Array[int],
		effects: Array[Dictionary]) -> bool:
	var resolved: Dictionary = {}
	for effect: Dictionary in effects:
		resolved[int(effect.get("token_index", -1))] = true
	for token_index: int in committed:
		if not resolved.has(token_index):
			return false
	return true


func _next_unresolved_token(attack: CurrentAttackState) -> int:
	var resolved: Dictionary = {}
	for effect: Dictionary in attack.resolved_defense_effects:
		resolved[int(effect.get("token_index", -1))] = true
	for token_index: int in attack.committed_defense_tokens:
		if not resolved.has(token_index):
			return token_index
	return -1
