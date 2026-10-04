## Rolls and applies one added Concentrate Fire die after resource commitment.
class_name UseConcentrateFireDialCommand
extends GameCommand


const TYPE: String = "use_concentrate_fire_dial"
const CF_RULE: GDScript = preload(
		"res://src/core/effects/rules/concentrate_fire_choice.gd")


static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int,
			pl: Dictionary) -> GameCommand:
		return UseConcentrateFireDialCommand.new(player, pl))


func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)


func application_contract_id() -> String:
	return "concentrate_fire_dial_added_die"


func project_application_result(authority_result: Dictionary,
		_viewer_player: int) -> Dictionary:
	var added: Dictionary = authority_result.get("added_result", {})
	return {"new_face": int(added.get("face", -1))}


func validate(game_state: GameState) -> String:
	var reason: String = validate_context(game_state, player_index, payload)
	if not reason.is_empty():
		return reason
	var attack: CurrentAttackState = game_state.current_attack_state
	var color: String = str(payload.get("color", "")).to_upper()
	if int(attack.dice_pool.get(color, 0)) <= 0:
		return "Concentrate Fire die color is not in the current pool."
	return ""


static func validate_context(game_state: GameState, acting_player: int,
		values: Dictionary) -> String:
	if game_state == null:
		return "No active game state."
	var attack: CurrentAttackState = game_state.current_attack_state
	var timing: TimingWindowState = game_state.timing_window_state
	var flow: InteractionFlow = game_state.interaction_flow
	if attack == null or not attack.active \
			or attack.stage != CurrentAttackState.STAGE_ATTACK_MODIFY \
			or attack.attacker_kind != CurrentAttackState.KIND_SHIP \
			or attack.cf_choice not in [CurrentAttackState.CF_CHOICE_DIAL,
				CurrentAttackState.CF_CHOICE_BOTH] \
			or attack.cf_dial_resolution != CurrentAttackState.RESOLUTION_PENDING \
			or str(values.get("attack_id", "")) != attack.attack_id \
			or acting_player != attack.attacker_player:
		return "Concentrate Fire dial effect is not pending for this attack."
	if flow == null or flow.flow_type != Constants.InteractionFlow.ATTACK \
			or flow.step_id != Constants.InteractionStep.ATTACK_MODIFY \
			or timing == null or not timing.active \
			or timing.status != TimingWindowState.STATUS_OPEN \
			or timing.timing_window_id != TimingWindowDefinitions.ATTACK_MODIFY \
			or str(values.get("timing_window_id", "")) \
				!= timing.timing_window_id \
			or str(values.get("lifecycle_id", "")) != timing.lifecycle_id \
			or attack.cf_choice_lifecycle_id != timing.lifecycle_id \
			or timing.controller_player != acting_player:
		return "Concentrate Fire dial effect has a stale timing lifecycle."
	var expected_source: String = "%d:ship:%d:concentrate_fire_choice" % [
		attack.attacker_player, attack.attacker_index]
	if str(values.get("source_owner_kind", "")) != CF_RULE.SOURCE_OWNER_KIND \
			or str(values.get("runtime_source_id", "")) != expected_source \
			or str(values.get("semantic_key", "")) != CF_RULE.DIAL_SEMANTIC_KEY:
		return "Concentrate Fire dial effect has a stale source identity."
	var ship: ShipInstance = game_state.get_ship(
			attack.attacker_player, attack.attacker_index)
	if ship == null or str(values.get("ship_activation_identity", "")) \
			!= ship.ship_activation_identity \
			or attack.cf_choice_activation_id \
				!= ship.ship_activation_identity \
			or int(values.get("round", -1)) != game_state.current_round \
			or attack.cf_choice_round != game_state.current_round \
			or ship.concentrate_fire_resolved_round \
				!= game_state.current_round:
		return "Concentrate Fire dial authorization has a stale ship or round."
	return ""


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if not validate(game_state).is_empty() \
			or application_result.size() != 1 \
			or typeof(application_result.get("new_face")) != TYPE_INT:
		return {}
	var color: String = str(payload["color"]).to_upper()
	var engine_color: int = _engine_color(color)
	var face: int = int(application_result["new_face"])
	if not Dice.DICE_FACES.has(engine_color) \
			or face not in Dice.DICE_FACES[engine_color]:
		return {}
	return _apply(game_state, color, engine_color, face)


func execute(game_state: GameState) -> Dictionary:
	if not validate(game_state).is_empty():
		return {}
	var color: String = str(payload["color"]).to_upper()
	var engine_color: int = _engine_color(color)
	var rng_before: int = game_state.rng.get_state()
	var face: int = int(Dice.roll_die(
			engine_color as Constants.DiceColor, game_state.rng))
	var result: Dictionary = _apply(game_state, color, engine_color, face)
	if result.is_empty():
		game_state.rng.set_state(rng_before)
	return result


func _apply(game_state: GameState, color: String,
		engine_color: int, face: int) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var pool: Dictionary = attack.dice_pool
	pool[color] = int(pool.get(color, 0)) + 1
	var dice: Array[Dictionary] = attack.dice_results
	var added: Dictionary = {"color": engine_color, "face": face}
	dice.append(added)
	var replacement: CurrentAttackState = attack.with_patch({
		"dice_pool": pool,
		"dice_results": dice,
		"cf_dial_resolution": CurrentAttackState.RESOLUTION_USED,
	})
	if replacement == null or not game_state.set_current_attack_state(replacement):
		return {}
	return {"attack_id": attack.attack_id, "color": color,
		"added_result": added, "dice_pool": pool, "dice_results": dice}


static func _engine_color(color: String) -> int:
	match color:
		DicePool.RED_KEY:
			return int(Constants.DiceColor.RED)
		DicePool.BLUE_KEY:
			return int(Constants.DiceColor.BLUE)
		DicePool.BLACK_KEY:
			return int(Constants.DiceColor.BLACK)
	return -1
