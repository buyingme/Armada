## Test: Squadron Keyword Live Rules
##
## Verifies Phase N18-N21 production rule predicates and command surfaces for
## Heavy, Escort, Counter, and Swarm.
extends GutTest


func before_each() -> void:
	RuleRegistry.clear()
	HeavyKeyword.register()
	EscortKeyword.register()
	CounterKeyword.register()
	SwarmKeyword.register()


func after_each() -> void:
	RuleRegistry.clear()


func test_move_squadron_validate_heavy_engager_allows_move() -> void:
	var state: GameState = _state_with_engagement([""], ["Heavy"])
	var command := MoveSquadronCommand.new(0, {
		"squadron_index": 0, "pos_x": 0.6, "pos_y": 0.5,
	})
	assert_eq(command.validate(state), "",
			"Heavy enemies should not prevent squadron movement.")


func test_move_squadron_validate_non_heavy_engager_blocks_move() -> void:
	var state: GameState = _state_with_engagement([""], [""])
	var command := MoveSquadronCommand.new(0, {
		"squadron_index": 0, "pos_x": 0.6, "pos_y": 0.5,
	})
	assert_ne(command.validate(state), "",
			"Non-Heavy enemies should still prevent squadron movement.")


func test_move_squadron_validate_obstructed_non_heavy_allows_move() -> void:
	var state: GameState = _state_with_engagement([""], [""])
	_add_obstructing_ship_pixels(state, _midpoint(
			SquadronKeywordRuleHelper.position_from_state(
					state.get_squadron(0, 0)),
			SquadronKeywordRuleHelper.position_from_state(
					state.get_squadron(1, 0))))
	var command := MoveSquadronCommand.new(0, {
		"squadron_index": 0, "pos_x": 0.6, "pos_y": 0.5,
	})
	assert_eq(command.validate(state), "",
			"Obstructed non-Heavy enemies should not prevent movement.")


func test_escort_blocker_rejects_non_escort_target() -> void:
	var context: EffectContext = _escort_context(
			SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD, [])
	var result: Dictionary = EscortKeyword.new().block_attack_target(context)
	assert_true(bool(result.get("blocked", false)),
			"Escort should block attacks against non-Escort squadrons.")


func test_escort_blocker_allows_counter_attack() -> void:
	var context: EffectContext = _escort_context(
			SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER, [])
	var result: Dictionary = EscortKeyword.new().block_attack_target(context)
	assert_false(bool(result.get("blocked", false)),
			"Counter attacks should ignore Escort targeting restrictions.")


func test_counter_affordance_projects_for_controller() -> void:
	var flow: InteractionFlow = _counter_flow(true, 1)
	var payload: Dictionary = CounterKeyword.new().project_counter_affordance(
			GameState.new(), flow, 1)
	assert_true(payload.has(
			SquadronKeywordRuleHelper.AFFORDANCE_COUNTER_ATTACK),
			"Counter affordance should project to the defender.")


func test_counter_choice_validator_accepts_controller() -> void:
	var state: GameState = _state_with_counter_roll({"BLUE": 2})
	state.interaction_flow = _counter_choice_flow(true, 1)
	var command := CounterChoiceCommand.new(1, _counter_choice_payload(true))
	var result: Dictionary = CounterKeyword.new().validate_counter_choice(
			state, command)
	assert_true(bool(result.get("allowed", false)),
			"Counter choice validator should allow the owning controller.")


func test_counter_choice_validator_rejects_original_attacker() -> void:
	var state: GameState = _state_with_counter_roll({"BLUE": 2})
	state.interaction_flow = _counter_choice_flow(true, 1)
	var command := CounterChoiceCommand.new(0, _counter_choice_payload(true))
	var result: Dictionary = CounterKeyword.new().validate_counter_choice(
			state, command)
	assert_false(bool(result.get("allowed", true)),
			"Counter choice validator should reject the triggering attacker.")


func test_counter_trigger_available_after_zero_damage_attack() -> void:
	var attacker: SquadronInstance = _make_squadron([], 0)
	var defender: SquadronInstance = _make_squadron(["Counter"], 1)
	defender.squadron_data.keywords = [ {
		"name": SquadronKeywordRuleHelper.KEYWORD_COUNTER,
		"value": 2,
	}]
	assert_true(CounterKeyword.is_counter_trigger_available(
			SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
			attacker, defender),
			"Counter should trigger after the attack, independent of damage.")


func test_counter_trigger_rejects_counter_attack() -> void:
	var attacker: SquadronInstance = _make_squadron([], 0)
	var defender: SquadronInstance = _make_squadron(["Counter"], 1)
	defender.squadron_data.keywords = [ {
		"name": SquadronKeywordRuleHelper.KEYWORD_COUNTER,
		"value": 2,
	}]
	assert_false(CounterKeyword.is_counter_trigger_available(
			SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER,
			attacker, defender),
			"Counter attacks should not recursively trigger Counter.")


func test_counter_roll_validator_allows_locked_counter_pool() -> void:
	var state: GameState = _state_with_counter_roll({"BLUE": 2})
	var command := RollDiceCommand.new(1, _counter_roll_payload({"blue": 2}))
	var result: Dictionary = CounterKeyword.new().validate_counter_roll(
			state, command)
	assert_true(bool(result.get("allowed", false)),
			"Counter 2 should allow exactly two blue dice.")


func test_counter_roll_validator_rejects_normal_interceptor_pool() -> void:
	var state: GameState = _state_with_counter_roll({"BLUE": 2})
	var command := RollDiceCommand.new(1, _counter_roll_payload({"BLUE": 4}))
	var result: Dictionary = CounterKeyword.new().validate_counter_roll(
			state, command)
	assert_false(bool(result.get("allowed", true)),
			"Counter should reject the Interceptor's normal four-blue pool.")
	assert_eq(str(result.get("reason", "")), CounterKeyword.REJECTION_REASON,
			"Counter rejection should explain the locked dice-pool rule.")


func test_swarm_reroll_command_updates_flow_payload() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SQUADRON
	state.rng = GameRng.new(7)
	state.interaction_flow = _modify_flow(_one_blue_critical())
	var command := RerollAttackDieCommand.new(0, {
		"die_index": 0,
		"dice_results": _one_blue_critical(),
		"source_rule_id": SwarmKeyword.RULE_ID,
	})
	var result: Dictionary = command.execute(state)
	assert_eq((result.get("dice_results", []) as Array).size(), 1,
			"Reroll should preserve the dice-result count.")
	assert_eq((state.interaction_flow.payload.get("dice_results", []) as Array).size(), 1,
			"Reroll should update interaction-flow dice results.")


func test_swarm_reroll_validate_unobstructed_partner_allows() -> void:
	var state: GameState = _state_with_swarm_partner(false)
	var command := RerollAttackDieCommand.new(1, {
		"die_index": 0,
		"dice_results": _one_blue_critical(),
		"source_rule_id": SwarmKeyword.RULE_ID,
	})
	assert_eq(command.validate(state), "",
			"Unobstructed friendly engagement should allow Swarm reroll.")


func test_swarm_reroll_validate_obstructed_partner_rejects() -> void:
	var state: GameState = _state_with_swarm_partner(true)
	var command := RerollAttackDieCommand.new(1, {
		"die_index": 0,
		"dice_results": _one_blue_critical(),
		"source_rule_id": SwarmKeyword.RULE_ID,
	})
	assert_eq(command.validate(state), "Swarm reroll is not eligible.",
			"Obstructed friendly engagement should reject Swarm reroll.")


func _state_with_engagement(p0_keywords: Array[String],
		p1_keywords: Array[String]) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SQUADRON
	_add_squadron(state, 0, p0_keywords, 0.50, 0.50)
	_add_squadron(state, 1, p1_keywords, 0.55, 0.50)
	return state


func _add_squadron(state: GameState,
		player: int,
		keywords: Array[String],
		pos_x: float,
		pos_y: float) -> SquadronInstance:
	var squadron: SquadronInstance = _make_squadron(keywords, player)
	squadron.pos_x = pos_x
	squadron.pos_y = pos_y
	state.get_player_state(player).squadrons.append(squadron)
	return squadron


func _state_with_swarm_partner(obstructed: bool) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SQUADRON
	var attacker_pos: Vector2 = Vector2.ZERO
	var target_pos: Vector2 = _close_vector()
	var friendly_pos: Vector2 = target_pos + _close_vector()
	_add_squadron_pixels(state, 1, ["Swarm"], attacker_pos)
	_add_squadron_pixels(state, 1, [""], friendly_pos)
	_add_squadron_pixels(state, 0, [""], target_pos)
	if obstructed:
		_add_obstructing_ship_pixels(state, _midpoint(target_pos, friendly_pos))
	state.interaction_flow = _swarm_modify_flow()
	return state


func _state_with_counter_roll(dice_pool: Dictionary) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SQUADRON
	_add_counter_squadron(state, 1, 2)
	_add_squadron(state, 0, [], 0.55, 0.50)
	state.interaction_flow = _counter_roll_flow(dice_pool)
	return state


func _add_squadron_pixels(state: GameState,
		player: int,
		keywords: Array[String],
		position: Vector2) -> SquadronInstance:
	var squadron: SquadronInstance = _make_squadron(keywords, player)
	var play_area_size: Vector2 = _play_area_size()
	squadron.pos_x = position.x / play_area_size.x
	squadron.pos_y = position.y / play_area_size.y
	state.get_player_state(player).squadrons.append(squadron)
	return squadron


func _add_obstructing_ship_pixels(state: GameState, position: Vector2) -> void:
	var data: ShipData = ShipData.new()
	data.ship_name = "Blocker"
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 5
	var ship: ShipInstance = ShipInstance.new()
	ship.ship_data = data
	var play_area_size: Vector2 = _play_area_size()
	ship.pos_x = position.x / play_area_size.x
	ship.pos_y = position.y / play_area_size.y
	state.get_player_state(0).ships.append(ship)


func _add_counter_squadron(state: GameState,
		player: int,
		counter_value: int) -> SquadronInstance:
	var squadron: SquadronInstance = _make_squadron([], player)
	squadron.squadron_data.keywords = [ {
		"name": SquadronKeywordRuleHelper.KEYWORD_COUNTER,
		"value": counter_value,
	}]
	state.get_player_state(player).squadrons.append(squadron)
	return squadron


func _swarm_modify_flow() -> InteractionFlow:
	return InteractionFlow.make(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			1, Constants.Visibility.ALL, {
				"attacker_kind": "squadron",
				"target_kind": "squadron",
				"attacker_player": 1,
				"attacker_squadron_index": 0,
				"defender_player": 0,
				"target_squadron_index": 0,
				"dice_results": _one_blue_critical(),
			})


func _close_vector() -> Vector2:
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var center_distance: float = GameScale.distance_bands_px[0] \
			+2.0 * radius - 1.0
	return Vector2(center_distance, 0.0)


func _midpoint(pos_a: Vector2, pos_b: Vector2) -> Vector2:
	return pos_a.lerp(pos_b, 0.5)


func _play_area_size() -> Vector2:
	if GameScale.play_area_size_px.x > 0.0 and GameScale.play_area_size_px.y > 0.0:
		return GameScale.play_area_size_px
	return Vector2(1000.0, 1000.0)


func _escort_context(attack_kind: String,
		target_keywords: Array[String]) -> EffectContext:
	var attacker: SquadronInstance = _make_squadron([], 0)
	var escort: SquadronInstance = _make_squadron(["Escort"], 1)
	var target: SquadronInstance = _make_squadron(target_keywords, 1)
	var context: EffectContext = EffectContext.new()
	context.attacker = attacker
	context.defender = target
	context.metadata = {
		SquadronKeywordRuleHelper.PAYLOAD_ATTACKER_POS: Vector2.ZERO,
		SquadronKeywordRuleHelper.PAYLOAD_TARGET_POS: Vector2(60.0, 0.0),
		SquadronKeywordRuleHelper.PAYLOAD_ALL_SQUADRONS: [
			{"instance": attacker, "position": Vector2.ZERO},
			{"instance": escort, "position": Vector2(50.0, 0.0)},
			{"instance": target, "position": Vector2(60.0, 0.0)},
		],
		SquadronKeywordRuleHelper.PAYLOAD_ATTACK_KIND: attack_kind,
	}
	return context


func _counter_flow(available: bool,
		controller_player: int) -> InteractionFlow:
	return InteractionFlow.make(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE,
			controller_player, Constants.Visibility.ALL, {
				CounterKeyword.PAYLOAD_AVAILABLE: available,
				CounterKeyword.PAYLOAD_CONTROLLER_PLAYER: controller_player,
				CounterKeyword.PAYLOAD_DICE_POOL: {"BLUE": 2},
			})


func _counter_choice_flow(available: bool,
		controller_player: int) -> InteractionFlow:
	var flow: InteractionFlow = _counter_flow(available, controller_player)
	flow.payload.merge({
		"counter_attacker_player": 1,
		"counter_attacker_squadron_index": 0,
		"counter_target_player": 0,
		"counter_target_squadron_index": 0,
	}, true)
	return flow


func _counter_choice_payload(accepted: bool) -> Dictionary:
	return {
		"accepted": accepted,
		CounterKeyword.PAYLOAD_DICE_POOL: {"BLUE": 2},
		"counter_attacker_player": 1,
		"counter_attacker_squadron_index": 0,
		"counter_target_player": 0,
		"counter_target_squadron_index": 0,
	}


func _counter_roll_flow(dice_pool: Dictionary) -> InteractionFlow:
	return InteractionFlow.make(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			1, Constants.Visibility.ALL, _counter_roll_payload(dice_pool))


func _counter_roll_payload(dice_pool: Dictionary) -> Dictionary:
	return {
		"attacker_kind": "squadron",
		"target_kind": "squadron",
		"attacker_player": 1,
		"attacker_squadron_index": 0,
		"defender_player": 0,
		"target_squadron_index": 0,
		"dice_pool": dice_pool,
		SquadronKeywordRuleHelper.PAYLOAD_ATTACK_KIND:
				SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER,
	}


func _modify_flow(dice_results: Array[Dictionary]) -> InteractionFlow:
	return InteractionFlow.make(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0, Constants.Visibility.ALL, {"dice_results": dice_results})


func _one_blue_critical() -> Array[Dictionary]:
	return [ {"color": Constants.DiceColor.BLUE,
			"face": Constants.DiceFace.CRITICAL}]


func _make_squadron(keywords: Array[String],
		owner: int) -> SquadronInstance:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "Test Squadron"
	data.hull = 3
	data.speed = 3
	data.keywords = _keyword_data(keywords)
	return SquadronInstance.create_from_data("test_squadron", data, owner)


func _keyword_data(keywords: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for keyword_name: String in keywords:
		if keyword_name != "":
			result.append({"name": keyword_name})
	return result
