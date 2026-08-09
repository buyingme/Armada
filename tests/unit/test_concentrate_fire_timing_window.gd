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


class ProcessorSubmitter:
	extends CommandSubmitter

	var processor: Node = null

	func _init(p_processor: Node) -> void:
		processor = p_processor

	func submit(command: GameCommand) -> Dictionary:
		return processor.submit_deferred_followups(command)


var _saved_registry: Dictionary = {}
var _saved_state: GameState = null
var _saved_submitter: CommandSubmitter = null
var _state: GameState = null
var _processor: Node = null


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	_saved_state = GameManager.current_game_state
	_saved_submitter = GameManager.get_command_submitter()
	RuleRegistry.clear()
	_state = _make_pending_state()
	GameManager.current_game_state = _state
	_processor = PROCESSOR_SCRIPT.new()
	add_child_autofree(_processor)
	assert_true(_processor.restore_next_sequence(2))
	GameManager.set_command_submitter(ProcessorSubmitter.new(_processor))
	RULE.register()


func after_each() -> void:
	RuleRegistry.clear()
	GameCommand._registry = _saved_registry
	GameManager.current_game_state = _saved_state
	GameManager.set_command_submitter(_saved_submitter)


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


func test_resolved_source_enumerates_but_derives_no_opportunity() -> void:
	var attack: CurrentAttackState = _state.current_attack_state
	assert_true(_state.set_current_attack_state(attack.with_patch({
		"cf_token_resolution": CurrentAttackState.RESOLUTION_DECLINED,
	})))
	var sources: Array = RULE.enumerate_timing_window_sources(
			_state, _state.timing_window_state)
	assert_eq(sources.size(), 1)
	var source: Dictionary = sources[0] as Dictionary
	var runtime_source_id: String = str(source.get(
			OPPORTUNITY.KEY_RUNTIME_SOURCE_ID, ""))
	assert_false(runtime_source_id.is_empty())
	var derived: Variant = RULE.derive_timing_window_opportunities(
			_state,
			_state.timing_window_state,
			RULE.SOURCE_OWNER_KIND,
			runtime_source_id)
	assert_typeof(derived, TYPE_ARRAY)
	assert_true((derived as Array).is_empty())
	assert_true((ORCHESTRATOR.derive_current_opportunities(
			_state).get(ORCHESTRATOR.KEY_OPPORTUNITIES, []) as Array).is_empty())


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

	var sources: Array = RULE.enumerate_timing_window_sources(
			_state, _state.timing_window_state)
	assert_eq(sources.size(), 1)
	var runtime_source_id: String = str((sources[0] as Dictionary).get(
			OPPORTUNITY.KEY_RUNTIME_SOURCE_ID, ""))
	var derived: Variant = RULE.derive_timing_window_opportunities(
			_state,
			_state.timing_window_state,
			RULE.SOURCE_OWNER_KIND,
			runtime_source_id)
	assert_typeof(derived, TYPE_ARRAY)
	assert_true((derived as Array).is_empty())
	assert_true((ORCHESTRATOR.derive_current_opportunities(
			_state).get(ORCHESTRATOR.KEY_OPPORTUNITIES, []) as Array).is_empty())


func test_normal_roll_opens_production_window_only_for_ship_attacker() -> void:
	var ship_state: GameState = _make_roll_state(CurrentAttackState.KIND_SHIP)
	GameManager.current_game_state = ship_state
	var ship_processor: Node = PROCESSOR_SCRIPT.new()
	add_child_autofree(ship_processor)
	assert_false(ship_processor.submit(RollDiceCommand.new(0, {
		"attack_id": ship_state.current_attack_state.attack_id,
	})).is_empty())
	assert_true(ship_state.timing_window_state.active)
	assert_eq(ship_state.timing_window_state.lifecycle_id, "attack_modify:0")

	var squadron_state: GameState = _make_roll_state(
			CurrentAttackState.KIND_SQUADRON)
	GameManager.current_game_state = squadron_state
	var squadron_processor: Node = PROCESSOR_SCRIPT.new()
	add_child_autofree(squadron_processor)
	assert_false(squadron_processor.submit(RollDiceCommand.new(0, {
		"attack_id": squadron_state.current_attack_state.attack_id,
	})).is_empty())
	assert_false(squadron_state.timing_window_state.active)


func test_rejected_repeat_roll_cannot_open_or_replace_production_window() -> void:
	var state: GameState = _make_roll_state(CurrentAttackState.KIND_SHIP)
	GameManager.current_game_state = state
	var processor: Node = PROCESSOR_SCRIPT.new()
	add_child_autofree(processor)
	assert_false(processor.submit(RollDiceCommand.new(0, {
		"attack_id": state.current_attack_state.attack_id,
	})).is_empty())
	var before: Dictionary = state.serialize()
	var lifecycle_id: String = state.timing_window_state.lifecycle_id

	assert_eq(processor.submit(RollDiceCommand.new(0, {
		"attack_id": state.current_attack_state.attack_id,
	})), {})
	assert_eq(state.serialize(), before)
	assert_eq(state.timing_window_state.lifecycle_id, lifecycle_id)
	assert_eq(processor.get_next_sequence(), 1)
	assert_engine_error(1)


func test_projection_is_public_but_only_attacker_receives_command_intents() -> void:
	var owner: Dictionary = UIProjector.project(_state, 0).timing_window
	var observer: Dictionary = UIProjector.project(_state, 1).timing_window
	var owner_opportunities: Array = owner.get("opportunities", [])
	var observer_opportunities: Array = observer.get("opportunities", [])
	var owner_opportunity: Dictionary = owner_opportunities[0] as Dictionary

	assert_eq(owner_opportunities.size(), 1)
	assert_eq(observer_opportunities.size(), 1)
	assert_true(bool(owner.get("is_interactive", false)))
	assert_false(bool(observer.get("is_interactive", true)))
	assert_false(owner_opportunity.has("use_intent"))
	assert_eq((owner_opportunity.get("use_choices", []) as Array).size(),
			_state.current_attack_state.dice_results.size())
	for die_index: int in range(
			_state.current_attack_state.dice_results.size()):
		var choice: Dictionary = (owner_opportunity.get(
				"use_choices", []) as Array)[die_index] as Dictionary
		var payload: Dictionary = ((choice.get("intent") as Dictionary).get(
				"payload") as Dictionary)
		var selected: Dictionary = _state.current_attack_state.dice_results[
				die_index]
		assert_eq(payload.get("die_index"), die_index)
		assert_eq(payload.get("expected_color"), selected.get("color"))
		assert_eq(payload.get("expected_face"), selected.get("face"))
	assert_true(owner_opportunity.has("decline_intent"))
	assert_false((observer_opportunities[0] as Dictionary).has("use_intent"))
	assert_false((observer_opportunities[0] as Dictionary).has("use_choices"))
	assert_false((observer_opportunities[0] as Dictionary).has("decline_intent"))


func test_live_panel_collects_cf_die_before_submitting_complete_use() -> void:
	var projected: Dictionary = UIProjector.project(_state, 0).timing_window
	var opportunities: Array = projected.get("opportunities", []) as Array
	var opportunity: Dictionary = opportunities[0] as Dictionary
	var use_choices: Array = opportunity.get("use_choices", []) as Array
	var expected_intent: Dictionary = (use_choices[1] as Dictionary).get(
			"intent", {}) as Dictionary
	var panel := AttackSimPanel.new()
	var adapter := CommandRouterAdapter.new()
	add_child_autofree(panel)
	add_child_autofree(adapter)
	watch_signals(panel)
	panel.timing_window_use_requested.connect(
			adapter.submit_timing_window_intent)
	panel.show_timing_window_opportunities(opportunities, true)
	panel.show_dice_results(_state.current_attack_state.dice_results)

	var use_button: Button = panel.find_child(
			"TimingUseButton_0", true, false) as Button
	assert_not_null(use_button)
	use_button.pressed.emit()
	assert_signal_not_emitted(panel, "timing_window_use_requested")
	assert_true(_processor.serialize_history().is_empty())
	assert_true(use_button.disabled)
	assert_eq(panel._dice_textures[0].mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(panel._dice_textures[1].mouse_filter, Control.MOUSE_FILTER_STOP)
	var original_die: TextureRect = panel._dice_textures[0]
	panel.show_dice_results(_state.current_attack_state.dice_results)
	assert_ne(panel._dice_textures[0], original_die,
			"Canonical projection should rebuild Concentrate Fire dice.")
	assert_eq(panel._dice_textures[0].mouse_filter,
			Control.MOUSE_FILTER_STOP,
			"Concentrate Fire parameter collection must survive refresh.")
	assert_eq(panel._dice_textures[1].mouse_filter, Control.MOUSE_FILTER_STOP)

	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	panel._dice_textures[1].gui_input.emit(click)
	assert_signal_emitted(panel, "timing_window_use_requested")
	assert_eq(get_signal_parameters(
			panel, "timing_window_use_requested"), [expected_intent])
	assert_eq(_history_types(_processor.serialize_history()), [USE_COMMAND.TYPE])
	assert_eq(_state.current_attack_state.cf_token_resolution,
			CurrentAttackState.RESOLUTION_USED)
	assert_true(panel._timing_window_die_intents.is_empty())
	assert_eq(panel._dice_textures[1].mouse_filter,
			Control.MOUSE_FILTER_IGNORE)
	panel.show_dice_results(_state.current_attack_state.dice_results)
	assert_eq(panel._dice_textures[1].mouse_filter,
			Control.MOUSE_FILTER_IGNORE,
			"Accepted Concentrate Fire input must stay dismissed after refresh.")
	panel._on_die_clicked(click, panel._dice_textures[0])
	assert_eq(_history_types(_processor.serialize_history()), [USE_COMMAND.TYPE],
			"A committed parameter choice cannot submit another command.")


func test_live_panel_cf_decline_submits_immediately_without_parameter_mode() -> void:
	var projected: Dictionary = UIProjector.project(_state, 0).timing_window
	var opportunities: Array = projected.get("opportunities", []) as Array
	var opportunity: Dictionary = opportunities[0] as Dictionary
	var expected_intent: Dictionary = opportunity.get(
			"decline_intent", {}) as Dictionary
	var panel := AttackSimPanel.new()
	var adapter := CommandRouterAdapter.new()
	add_child_autofree(panel)
	add_child_autofree(adapter)
	watch_signals(panel)
	panel.timing_window_decline_requested.connect(
			adapter.submit_timing_window_intent)
	panel.show_timing_window_opportunities(opportunities, true)
	panel.show_dice_results(_state.current_attack_state.dice_results)

	var decline_button: Button = panel.find_child(
			"TimingDeclineButton_0", true, false) as Button
	assert_not_null(decline_button)
	decline_button.pressed.emit()
	assert_signal_emitted(panel, "timing_window_decline_requested")
	assert_eq(get_signal_parameters(
			panel, "timing_window_decline_requested"), [expected_intent])
	assert_eq(_history_types(_processor.serialize_history()), [
		DECLINE_COMMAND.TYPE,
	])
	assert_eq(_state.current_attack_state.cf_token_resolution,
			CurrentAttackState.RESOLUTION_DECLINED)
	assert_true(panel._timing_window_die_intents.is_empty())


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
	use_payload["source_rule_id"] = "concentrate_fire_token"
	var legacy_use := RerollAttackDieCommand.new(0, use_payload)
	var legacy_decline := SkipAttackModifierCommand.new(0, {
		"attack_id": _state.current_attack_state.attack_id,
		"source_rule_id": "concentrate_fire_token",
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
