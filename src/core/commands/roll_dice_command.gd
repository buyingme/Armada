## RollDiceCommand
##
## Rolls attack dice during the Ship Phase attack sequence.
## Uses [member GameState.rng] for deterministic replay support.
##
## Payload: "attack_id" — the current canonical attack identity.
##
## Rules Reference: "Attack", Step 2, p.2 — "Roll Attack Dice".
class_name RollDiceCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("roll_dice", func(player: int,
			pl: Dictionary) -> GameCommand:
		return RollDiceCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "roll_dice", p_payload)


func application_contract_id() -> String:
	return "roll_dice"


func project_application_result(authority_result: Dictionary,
		_viewer_player: int) -> Dictionary:
	return {"dice_results": authority_result.get("dice_results", []).duplicate(true)}


func execute_with_application_result(game_state: GameState,
		application_result: Dictionary) -> Dictionary:
	if application_result.size() != 1 \
			or not application_result.has("dice_results") \
			or not application_result.get("dice_results") is Array:
		return {}
	var attack: CurrentAttackState = game_state.current_attack_state
	var results: Array[Dictionary] = []
	var expected_colors: Array[int] = []
	var engine_pool: Dictionary = DicePool.to_engine_pool(attack.dice_pool)
	for color_value: Variant in engine_pool:
		for _index: int in range(int(engine_pool[color_value])):
			expected_colors.append(int(color_value))
	var raw_results: Array = application_result["dice_results"] as Array
	if raw_results.size() != expected_colors.size():
		return {}
	for index: int in range(raw_results.size()):
		var raw: Variant = raw_results[index]
		if not raw is Dictionary:
			return {}
		var die: Dictionary = raw as Dictionary
		if die.size() != 2 or not die.has("color") or not die.has("face") \
				or typeof(die.get("color")) != TYPE_INT \
				or typeof(die.get("face")) != TYPE_INT \
				or int(die["color"]) != expected_colors[index] \
				or not Dice.DICE_FACES.has(int(die["color"])) \
				or int(die["face"]) not in Dice.DICE_FACES[int(die["color"])]:
			return {}
		results.append({"color": int(die["color"]), "face": int(die["face"])})
	var replacement: CurrentAttackState = attack.with_patch({
		"dice_results": results,
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
	})
	if replacement == null or not game_state.set_current_attack_state(replacement):
		return {}
	_record_ship_target_attack(game_state, attack)
	return {"attack_id": attack.attack_id, "dice_results": results}


## Validates that rolling dice is legal.
## Attack-step-specific validation is handled by [AttackExecutor] before
## submitting; this only checks GameState-level preconditions.
## Allowed in both Ship and Squadron phases (squadron attacks roll dice too).
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
	if attack.stage != CurrentAttackState.STAGE_PRE_ROLL:
		return "Current attack is not ready to roll."
	if attack.attacker_kind == CurrentAttackState.KIND_SHIP \
			and (game_state.timing_window_state == null \
					or game_state.timing_window_state.active):
		return "Ship attack roll requires an inactive timing lifecycle."
	if not attack.obstruction_resolved:
		return "Obstruction choice is unresolved."
	if attack.cf_dial_resolution == CurrentAttackState.RESOLUTION_PENDING:
		return "Concentrate Fire dial choice is unresolved."
	if player_index != attack.attacker_player:
		return "Attack roll belongs to player %d." % attack.attacker_player
	if DicePool.get_total_count(attack.dice_pool) <= 0:
		return "Dice pool is empty."
	return ""


## Rolls the dice pool deterministically via [member GameState.rng].
## Returns {"dice_results": Array[Dictionary]} where each entry is
## {"color": DiceColor, "face": DiceFace}.
func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var engine_pool: Dictionary = DicePool.to_engine_pool(attack.dice_pool)
	var rng_state: int = game_state.rng.get_state()
	var results: Array[Dictionary] = Dice.roll_pool(
			engine_pool, game_state.rng)
	var replacement: CurrentAttackState = attack.with_patch({
		"dice_results": results,
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
	})
	if replacement == null or not game_state.set_current_attack_state(replacement):
		game_state.rng.set_state(rng_state)
		return {}
	_record_ship_target_attack(game_state, attack)
	return {"attack_id": attack.attack_id, "dice_results": results}


func _record_ship_target_attack(game_state: GameState,
		attack: CurrentAttackState) -> void:
	if game_state == null:
		return
	if attack.attacker_kind != CurrentAttackState.KIND_SHIP:
		return
	if attack.defender_kind != CurrentAttackState.KIND_SHIP:
		return
	var attacker: ShipInstance = game_state.get_ship(
			attack.attacker_player, attack.attacker_index)
	game_state.record_ship_target_attack(attacker)
