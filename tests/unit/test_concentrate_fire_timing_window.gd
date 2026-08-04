## Focused TWI-002 Slice 8B-1 Concentrate Fire participant evidence.
extends GutTest


const PROCESSOR_SCRIPT: GDScript = preload(
		"res://src/autoload/command_processor.gd")
const RULE: GDScript = preload(
		"res://src/core/effects/rules/concentrate_fire_token.gd")
const ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")
const DEFINITIONS: GDScript = preload(
		"res://src/core/timing_windows/timing_window_definitions.gd")
const OPPORTUNITY: GDScript = preload(
		"res://src/core/timing_windows/timing_window_opportunity.gd")
const COMMAND_APPLICABILITY: GDScript = preload(
		"res://src/core/commands/command_applicability.gd")
const USE_COMMAND: GDScript = preload(
		"res://src/core/commands/use_concentrate_fire_token_reroll_command.gd")
const DECLINE_COMMAND: GDScript = preload(
		"res://src/core/commands/decline_concentrate_fire_token_reroll_command.gd")
const CURRENT_ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")

var _saved_registry: Dictionary = {}
var _saved_state: GameState = null
var _state: GameState = null
var _processor: Node = null


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	_saved_state = GameManager.current_game_state
	RuleRegistry.clear()
	_state = _make_pending_state()
	GameManager.current_game_state = _state
	_processor = PROCESSOR_SCRIPT.new()
	add_child_autofree(_processor)
	assert_true(_processor.restore_next_sequence(2))
	RULE.register()


func after_each() -> void:
	RuleRegistry.clear()
	GameCommand._registry = _saved_registry
	GameManager.current_game_state = _saved_state


func test_derives_one_canonical_optional_blocker_when_legacy_choice_is_legal() -> void:
	var result: Dictionary = ORCHESTRATOR.derive_current_opportunities(_state)
	var opportunities: Array = result.get(ORCHESTRATOR.KEY_OPPORTUNITIES, [])

	assert_true(bool(result.get(ORCHESTRATOR.KEY_OK, false)))
	assert_eq(opportunities.size(), 1)
	var opportunity: Dictionary = opportunities[0] as Dictionary
	assert_eq(opportunity.get(OPPORTUNITY.KEY_CAPABILITY_ID), RULE.CAPABILITY_ID)
	assert_eq(opportunity.get(OPPORTUNITY.KEY_SOURCE_OWNER_KIND),
			RULE.SOURCE_OWNER_KIND)
	assert_eq(opportunity.get(OPPORTUNITY.KEY_SEMANTIC_KEY), RULE.SEMANTIC_KEY)
	assert_eq(opportunity.get(OPPORTUNITY.KEY_RESOLUTION_KIND),
			OPPORTUNITY.RESOLUTION_OPTIONAL)
	assert_true(bool(opportunity.get(OPPORTUNITY.KEY_BLOCKING, false)))
	assert_eq((opportunity.get(OPPORTUNITY.KEY_USE_INTENT) as Dictionary).get(
			OPPORTUNITY.INTENT_KEY_COMMAND_TYPE),
			USE_COMMAND.TYPE)
	assert_eq((opportunity.get(OPPORTUNITY.KEY_DECLINE_INTENT) as Dictionary).get(
			OPPORTUNITY.INTENT_KEY_COMMAND_TYPE),
			DECLINE_COMMAND.TYPE)


func test_use_spends_one_token_rerolls_selected_die_and_then_continues() -> void:
	var attacker: ShipInstance = _state.get_ship(0, 0)
	var before_tokens: int = attacker.command_tokens.get_token_count()
	var before_rng: int = _state.rng.get_state()
	var before_dice: Array[Dictionary] = \
			_state.current_attack_state.dice_results.duplicate(true)
	var command: GameCommand = USE_COMMAND.new(
			0, _use_payload(_state, 1))
	var result: Dictionary = _processor.submit_deferred_followups(command)

	assert_false(result.is_empty())
	assert_eq(attacker.command_tokens.get_token_count(), before_tokens - 1)
	assert_false(attacker.command_tokens.has_token(
			Constants.CommandType.CONCENTRATE_FIRE))
	assert_ne(_state.rng.get_state(), before_rng)
	assert_eq(result.get("die_index"), 1)
	assert_eq(_state.current_attack_state.dice_results[0], before_dice[0],
			"The non-selected canonical die must remain unchanged.")
	assert_eq(int(_state.current_attack_state.dice_results[1].get(
			"color", -1)), int(Constants.DiceColor.BLUE))
	assert_eq(_state.current_attack_state.cf_token_resolution,
			CurrentAttackState.RESOLUTION_USED)
	assert_eq(_state.current_attack_state.stage,
			CurrentAttackState.STAGE_ATTACK_MODIFY)
	assert_eq(_processor.get_pending_observer_followup_count(), 1)
	assert_eq(_history_types(_processor.serialize_history()), [
		USE_COMMAND.TYPE,
	])
	assert_true((ORCHESTRATOR.derive_current_opportunities(
			_state).get(ORCHESTRATOR.KEY_OPPORTUNITIES) as Array).is_empty())

	_processor.drain_observer_followups()
	assert_eq(_state.current_attack_state.stage,
			CurrentAttackState.STAGE_ACCURACY)
	assert_true(_state.timing_window_state.is_inactive())
	assert_eq(_history_types(_processor.serialize_history()), [
		USE_COMMAND.TYPE,
		ConfirmAttackDiceCommand.TYPE,
	])


func test_decline_preserves_dice_and_token_and_suppresses_repeat() -> void:
	var attacker: ShipInstance = _state.get_ship(0, 0)
	var before_dice: Array[Dictionary] = _state.current_attack_state.dice_results
	var before_tokens: Dictionary = attacker.command_tokens.serialize()
	var command: GameCommand = DECLINE_COMMAND.new(
			0, _identity_payload(_state))
	var result: Dictionary = _processor.submit_deferred_followups(command)

	assert_false(result.is_empty())
	assert_eq(_state.current_attack_state.dice_results, before_dice)
	assert_eq(attacker.command_tokens.serialize(), before_tokens)
	assert_eq(_state.current_attack_state.cf_token_resolution,
			CurrentAttackState.RESOLUTION_DECLINED)
	assert_true((ORCHESTRATOR.derive_current_opportunities(
			_state).get(ORCHESTRATOR.KEY_OPPORTUNITIES) as Array).is_empty())
	assert_ne(command.validate(_state), "",
			"A resolved source must reject repeat submission.")


func test_unresolved_blocker_does_not_request_automatic_confirmation() -> void:
	var processed: Dictionary = ORCHESTRATOR.process_successful_command(
			_state,
			GameCommand.new(0, "debug_deal_damage", {}),
			{},
			ORCHESTRATOR.MODE_LIVE_AUTHORITY)

	assert_true(bool(processed.get(ORCHESTRATOR.KEY_OK, false)))
	assert_null(processed.get(ORCHESTRATOR.KEY_CONTINUATION))
	assert_eq(_state.timing_window_state.status, TimingWindowState.STATUS_OPEN)


func test_ship_anti_squadron_attack_derives_the_same_participant() -> void:
	var state: GameState = _make_pending_state(
			CurrentAttackState.KIND_SHIP,
			CurrentAttackState.KIND_SQUADRON)
	var opportunities: Array = ORCHESTRATOR.derive_current_opportunities(
			state).get(ORCHESTRATOR.KEY_OPPORTUNITIES, [])

	assert_eq(opportunities.size(), 1)
	assert_eq((opportunities[0] as Dictionary).get(
			OPPORTUNITY.KEY_SEMANTIC_KEY), RULE.SEMANTIC_KEY)


func test_squadron_attacker_never_derives_concentrate_fire_participant() -> void:
	var state: GameState = _make_pending_state(
			CurrentAttackState.KIND_SQUADRON,
			CurrentAttackState.KIND_SQUADRON)
	var opportunities: Array = ORCHESTRATOR.derive_current_opportunities(
			state).get(ORCHESTRATOR.KEY_OPPORTUNITIES, [])

	assert_true(opportunities.is_empty())


func test_ship_without_concentrate_fire_token_derives_no_opportunity() -> void:
	var attacker: ShipInstance = _state.get_ship(0, 0)
	assert_true(attacker.command_tokens.spend_token(
			Constants.CommandType.CONCENTRATE_FIRE))

	assert_true((ORCHESTRATOR.derive_current_opportunities(
			_state).get(ORCHESTRATOR.KEY_OPPORTUNITIES, []) as Array).is_empty())


func test_normal_roll_does_not_open_production_window_for_ship_or_squadron() -> void:
	for attacker_kind: String in [
		CurrentAttackState.KIND_SHIP,
		CurrentAttackState.KIND_SQUADRON,
	]:
		var state: GameState = _make_roll_state(attacker_kind)
		GameManager.current_game_state = state
		var processor: Node = PROCESSOR_SCRIPT.new()
		add_child_autofree(processor)
		var result: Dictionary = processor.submit(RollDiceCommand.new(0, {
			"attack_id": state.current_attack_state.attack_id,
		}))
		assert_false(result.is_empty())
		assert_false(state.timing_window_state.active,
				"Slice 8B-1 must not connect the production opener.")


func test_projection_is_public_but_only_attacker_receives_command_intents() -> void:
	var owner: Dictionary = UIProjector.project(_state, 0).timing_window
	var observer: Dictionary = UIProjector.project(_state, 1).timing_window
	var owner_opportunities: Array = owner.get("opportunities", [])
	var observer_opportunities: Array = observer.get("opportunities", [])

	assert_eq(owner_opportunities.size(), 1)
	assert_eq(observer_opportunities.size(), 1)
	assert_true(bool(owner.get("is_interactive", false)))
	assert_false(bool(observer.get("is_interactive", true)))
	assert_true((owner_opportunities[0] as Dictionary).has("use_intent"))
	assert_true((owner_opportunities[0] as Dictionary).has("decline_intent"))
	assert_false((observer_opportunities[0] as Dictionary).has("use_intent"))
	assert_false((observer_opportunities[0] as Dictionary).has("decline_intent"))


func test_shared_commands_have_attack_modify_applicability_only() -> void:
	for command_type: String in [
		USE_COMMAND.TYPE,
		DECLINE_COMMAND.TYPE,
	]:
		assert_true(COMMAND_APPLICABILITY.is_flow_step_allowed(
				command_type,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_MODIFY))
		assert_false(COMMAND_APPLICABILITY.is_flow_step_allowed(
				command_type,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_ROLL))


func test_legacy_concentrate_fire_commands_cannot_bypass_active_shared_window() -> void:
	var use_payload: Dictionary = _use_payload(_state, 0)
	use_payload["source_rule_id"] = \
			RerollAttackDieCommand.SOURCE_CONCENTRATE_FIRE_TOKEN
	var legacy_use := RerollAttackDieCommand.new(0, use_payload)
	var legacy_decline := SkipAttackModifierCommand.new(0, {
		"attack_id": _state.current_attack_state.attack_id,
		"source_rule_id":
				RerollAttackDieCommand.SOURCE_CONCENTRATE_FIRE_TOKEN,
	})

	assert_ne(legacy_use.validate(_state), "")
	assert_ne(legacy_decline.validate(_state), "")
	assert_eq(_state.current_attack_state.cf_token_resolution,
			CurrentAttackState.RESOLUTION_PENDING)


func test_stale_shared_intent_rejects_without_mutation_or_sequence_advance() -> void:
	var before_state: Dictionary = _state.serialize()
	var before_rng: int = _state.rng.get_state()
	var command: GameCommand = USE_COMMAND.new(0, _use_payload(_state, 0))
	command.payload[ORCHESTRATOR.COMMAND_KEY_LIFECYCLE_ID] = \
			"attack_modify:stale"

	assert_eq(_processor.submit(command), {})
	assert_eq(_state.serialize(), before_state)
	assert_eq(_state.rng.get_state(), before_rng)
	assert_eq(_processor.get_next_sequence(), 2)
	assert_eq(command.sequence, -1)
	assert_engine_error(1)


func test_use_payload_round_trips_json_numeric_fields_canonically() -> void:
	var command: GameCommand = USE_COMMAND.new(
			0, _use_payload(_state, 0))
	command.sequence = 2
	var json_data: Dictionary = JSON.parse_string(JSON.stringify(
			command.serialize())) as Dictionary
	var restored: GameCommand = GameCommand.deserialize(json_data)

	assert_not_null(restored)
	assert_typeof(restored.payload["die_index"], TYPE_INT)
	assert_typeof(restored.payload["expected_color"], TYPE_INT)
	assert_typeof(restored.payload["expected_face"], TYPE_INT)


func _make_pending_state(
		attacker_kind: String = CurrentAttackState.KIND_SHIP,
		defender_kind: String = CurrentAttackState.KIND_SHIP) -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP \
			if attacker_kind == CurrentAttackState.KIND_SHIP \
			else Constants.GamePhase.SQUADRON
	state.rng = GameRng.new(8811)
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0,
			Constants.Visibility.ALL,
			{"attacker_player": 0})
	assert_not_null(CURRENT_ATTACK_FIXTURE.install(state, {
		"attack_id": "attack:0",
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
		"attacker_kind": attacker_kind,
		"defender_kind": defender_kind,
		"cf_token_resolution": CurrentAttackState.RESOLUTION_PENDING \
				if attacker_kind == CurrentAttackState.KIND_SHIP \
				else CurrentAttackState.RESOLUTION_UNAVAILABLE,
		"dice_results": [{
			"color": int(Constants.DiceColor.RED),
			"face": int(Constants.DiceFace.HIT),
		}, {
			"color": int(Constants.DiceColor.BLUE),
			"face": int(Constants.DiceFace.ACCURACY),
		}],
	}))
	if attacker_kind == CurrentAttackState.KIND_SHIP:
		assert_true(state.get_ship(0, 0).command_tokens.add_token(
				Constants.CommandType.CONCENTRATE_FIRE))
	assert_true(bool(ORCHESTRATOR.open_window(
			state,
			DEFINITIONS.ATTACK_MODIFY,
			1,
			_context(state)).get(ORCHESTRATOR.KEY_OK, false)))
	return state


func _make_roll_state(attacker_kind: String) -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP \
			if attacker_kind == CurrentAttackState.KIND_SHIP \
			else Constants.GamePhase.SQUADRON
	state.rng = GameRng.new(8812)
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			0)
	assert_not_null(CURRENT_ATTACK_FIXTURE.install(state, {
		"attack_id": "attack:0",
		"stage": CurrentAttackState.STAGE_PRE_ROLL,
		"attacker_kind": attacker_kind,
		"defender_kind": CurrentAttackState.KIND_SQUADRON,
		"cf_token_resolution": CurrentAttackState.RESOLUTION_PENDING \
				if attacker_kind == CurrentAttackState.KIND_SHIP \
				else CurrentAttackState.RESOLUTION_UNAVAILABLE,
	}))
	if attacker_kind == CurrentAttackState.KIND_SHIP:
		assert_true(state.get_ship(0, 0).command_tokens.add_token(
				Constants.CommandType.CONCENTRATE_FIRE))
	return state


func _context(state: GameState) -> Dictionary:
	return {
		TimingWindowState.CONTINUATION_KEY_ID: ConfirmAttackDiceCommand.TYPE,
		TimingWindowState.CONTINUATION_KEY_RESUME_POINT: "attack_after_modify",
		TimingWindowState.CONTINUATION_KEY_SOURCE_ID:
				state.current_attack_state.attack_id,
		TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE: "current_attack",
		TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER: 0,
	}


func _identity_payload(state: GameState) -> Dictionary:
	var attack: CurrentAttackState = state.current_attack_state
	var ship_id: String = RULE.attacking_ship_identity(attack)
	return {
		ORCHESTRATOR.COMMAND_KEY_TIMING_WINDOW_ID:
				state.timing_window_state.timing_window_id,
		ORCHESTRATOR.COMMAND_KEY_LIFECYCLE_ID:
				state.timing_window_state.lifecycle_id,
		OPPORTUNITY.KEY_SOURCE_OWNER_KIND: RULE.SOURCE_OWNER_KIND,
		OPPORTUNITY.KEY_RUNTIME_SOURCE_ID:
				RULE.token_source_identity(ship_id),
		OPPORTUNITY.KEY_SEMANTIC_KEY: RULE.SEMANTIC_KEY,
		RULE.PAYLOAD_ATTACK_ID: attack.attack_id,
		RULE.PAYLOAD_ATTACKING_SHIP_ID: ship_id,
	}


func _use_payload(state: GameState, die_index: int) -> Dictionary:
	var payload: Dictionary = _identity_payload(state)
	var selected: Dictionary = state.current_attack_state.dice_results[die_index]
	payload["die_index"] = die_index
	payload["expected_color"] = int(selected.get("color", -1))
	payload["expected_face"] = int(selected.get("face", -1))
	return payload


func _history_types(commands: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for command: Dictionary in commands:
		result.append(str(command.get("type", "")))
	return result
