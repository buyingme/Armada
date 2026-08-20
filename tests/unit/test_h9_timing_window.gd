## Focused TWI-002 Slice 8B-2 H9 participant and command evidence.
extends GutTest


const PROCESSOR_SCRIPT: GDScript = preload(
		"res://src/autoload/command_processor.gd")
const RULE: GDScript = preload(
		"res://src/core/effects/rules/upgrades/turbolasers/h9_turbolasers.gd")
const CF_RULE: GDScript = preload(
		"res://src/core/effects/rules/concentrate_fire_token.gd")
const USE_COMMAND: GDScript = preload(
		"res://src/core/commands/use_h9_command.gd")
const DECLINE_COMMAND: GDScript = preload(
		"res://src/core/commands/decline_h9_command.gd")
const ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")
const OPPORTUNITY: GDScript = preload(
		"res://src/core/timing_windows/timing_window_opportunity.gd")
const COMMAND_APPLICABILITY: GDScript = preload(
		"res://src/core/commands/command_applicability.gd")
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
	_state = _make_state()
	GameManager.current_game_state = _state
	_processor = PROCESSOR_SCRIPT.new()
	add_child_autofree(_processor)
	assert_true(_processor.restore_next_sequence(3))
	GameManager.set_command_submitter(ProcessorSubmitter.new(_processor))
	RULE.register()


func after_each() -> void:
	RuleRegistry.clear()
	GameCommand._registry = _saved_registry
	GameManager.current_game_state = _saved_state
	GameManager.set_command_submitter(_saved_submitter)


func test_derives_one_optional_blocker_per_runtime_h9_source() -> void:
	var opportunities: Array = _opportunities(_state)
	assert_eq(opportunities.size(), 1)
	_assert_h9_opportunity(opportunities[0] as Dictionary)

	_add_h9(_state, "h9-second", 1)
	opportunities = _opportunities(_state)
	assert_eq(opportunities.size(), 2)
	assert_ne((opportunities[0] as Dictionary).get(OPPORTUNITY.KEY_ID),
			(opportunities[1] as Dictionary).get(OPPORTUNITY.KEY_ID))


func test_ineligible_h9_source_enumerates_but_derives_no_opportunity() -> void:
	var state: GameState = _make_state({
		"dice_results": [
			_die(Constants.DiceColor.RED, Constants.DiceFace.ACCURACY),
		],
	})
	var runtime_upgrade: Dictionary = _h9_source(state)
	var card_state: Dictionary = (runtime_upgrade.get("card_state") \
			as Dictionary).duplicate(true)
	card_state["disabled"] = true
	card_state["readied"] = false
	runtime_upgrade["card_state"] = card_state

	var sources: Array = RULE.enumerate_timing_window_sources(
			state, state.timing_window_state)
	assert_eq(sources.size(), 1)
	var source: Dictionary = sources[0] as Dictionary
	var runtime_upgrade_id: String = str(runtime_upgrade.get(
			"runtime_upgrade_id", ""))
	assert_eq(source.get(OPPORTUNITY.KEY_RUNTIME_SOURCE_ID), runtime_upgrade_id)
	var derived: Variant = RULE.derive_timing_window_opportunities(
			state,
			state.timing_window_state,
			RULE.SOURCE_OWNER_KIND,
			runtime_upgrade_id)
	assert_typeof(derived, TYPE_ARRAY)
	assert_true((derived as Array).is_empty())
	assert_true(_opportunities(state).is_empty())


func test_h9_source_enumeration_orders_runtime_ids_deterministically() -> void:
	var state: GameState = _make_state({"h9_count": 0})
	var later: Dictionary = _add_h9(state, "z-source", 0)
	var earlier: Dictionary = _add_h9(state, "a-source", 1)
	var sources: Array = RULE.enumerate_timing_window_sources(
			state, state.timing_window_state)

	assert_eq(sources.size(), 2)
	assert_eq((sources[0] as Dictionary).get(
			OPPORTUNITY.KEY_RUNTIME_SOURCE_ID),
			earlier.get("runtime_upgrade_id"))
	assert_eq((sources[1] as Dictionary).get(
			OPPORTUNITY.KEY_RUNTIME_SOURCE_ID),
			later.get("runtime_upgrade_id"))


func test_source_and_dice_legality_are_derived_from_authoritative_state() -> void:
	var no_h9: GameState = _make_state({"h9_count": 0})
	assert_true(_opportunities(no_h9).is_empty())

	var squadron: GameState = _make_state({
		"attacker_kind": CurrentAttackState.KIND_SQUADRON,
		"h9_count": 0,
	})
	assert_true(_opportunities(squadron).is_empty())

	for rejected_dice: Array in [[_die(Constants.DiceColor.RED,
			Constants.DiceFace.ACCURACY)], [_die(Constants.DiceColor.BLACK,
			Constants.DiceFace.HIT_CRITICAL)]]:
		var rejected: GameState = _make_state({"dice_results": rejected_dice})
		assert_true(_opportunities(rejected).is_empty())

	for accepted: Dictionary in [
		_die(Constants.DiceColor.RED, Constants.DiceFace.HIT),
		_die(Constants.DiceColor.RED, Constants.DiceFace.CRITICAL),
		_die(Constants.DiceColor.RED, Constants.DiceFace.HIT_HIT),
		_die(Constants.DiceColor.BLUE, Constants.DiceFace.HIT_CRITICAL),
	]:
		var legal: GameState = _make_state({"dice_results": [accepted]})
		assert_eq(_opportunities(legal).size(), 1)


func test_discarded_or_disabled_runtime_source_is_not_available() -> void:
	var runtime_upgrade: Dictionary = _h9_source(_state)
	var card_state: Dictionary = (runtime_upgrade.get("card_state") \
			as Dictionary).duplicate(true)
	card_state["discarded"] = true
	card_state["readied"] = false
	runtime_upgrade["card_state"] = card_state
	assert_true(_opportunities(_state).is_empty())

	var disabled: GameState = _make_state()
	runtime_upgrade = _h9_source(disabled)
	card_state = (runtime_upgrade.get("card_state") as Dictionary).duplicate(true)
	card_state["disabled"] = true
	card_state["readied"] = false
	runtime_upgrade["card_state"] = card_state
	assert_true(_opportunities(disabled).is_empty())


func test_use_changes_exactly_one_die_and_writes_rule_owned_guard() -> void:
	var runtime_upgrade: Dictionary = _h9_source(_state)
	var before_card_state: Dictionary = (runtime_upgrade.get("card_state") \
			as Dictionary).duplicate(true)
	var before_dice: Array[Dictionary] = _state.current_attack_state.dice_results
	var result: Dictionary = _processor.submit_deferred_followups(
			USE_COMMAND.new(0, _use_payload(_state, runtime_upgrade, 0)))

	assert_false(result.is_empty())
	assert_eq(_state.current_attack_state.dice_results[1], before_dice[1])
	assert_eq(_state.current_attack_state.dice_results[0],
			_die(Constants.DiceColor.RED, Constants.DiceFace.ACCURACY))
	assert_eq(runtime_upgrade.get("card_state"), before_card_state)
	assert_eq(RULE.resolution_guard(runtime_upgrade), {
		RULE.GUARD_ATTACK_ID: "attack:0",
		RULE.GUARD_RESOLUTION: RULE.RESOLUTION_USED,
	})
	assert_eq(_history_types(_processor.serialize_history()), [USE_COMMAND.TYPE])
	assert_eq(_processor.get_pending_observer_followup_count(), 1)


func test_decline_changes_no_dice_and_suppresses_every_repeat_path() -> void:
	var runtime_upgrade: Dictionary = _h9_source(_state)
	var before_dice: Array[Dictionary] = _state.current_attack_state.dice_results
	var payload: Dictionary = _identity_payload(_state, runtime_upgrade)
	assert_false(_processor.submit_deferred_followups(
			DECLINE_COMMAND.new(0, payload)).is_empty())

	assert_eq(_state.current_attack_state.dice_results, before_dice)
	assert_eq(RULE.resolution_guard(runtime_upgrade), {
		RULE.GUARD_ATTACK_ID: "attack:0",
		RULE.GUARD_RESOLUTION: RULE.RESOLUTION_DECLINED,
	})
	assert_true(_opportunities(_state).is_empty())
	assert_ne(DECLINE_COMMAND.new(0, payload).validate(_state), "")
	assert_ne(USE_COMMAND.new(0,
			_use_payload(_state, runtime_upgrade, 0)).validate(_state), "")


func test_multiple_h9_sources_resolve_independently_before_continuation() -> void:
	var attack: CurrentAttackState = _state.current_attack_state
	assert_true(_state.set_current_attack_state(attack.with_patch({
		"dice_results": [attack.dice_results[0],
				_die(Constants.DiceColor.BLUE, Constants.DiceFace.HIT)],
	})))
	var first: Dictionary = _h9_source(_state)
	var second: Dictionary = _add_h9(_state, "h9-second", 1)
	assert_eq(_opportunities(_state).size(), 2)

	assert_false(_processor.submit_deferred_followups(USE_COMMAND.new(
			0, _use_payload(_state, first, 0))).is_empty())
	assert_eq(_opportunities(_state).size(), 1)
	assert_eq(_processor.get_pending_observer_followup_count(), 0)

	assert_false(_processor.submit_deferred_followups(DECLINE_COMMAND.new(
			0, _identity_payload(_state, second))).is_empty())
	assert_true(_opportunities(_state).is_empty())
	assert_eq(_processor.get_pending_observer_followup_count(), 1)


func test_stale_illegal_and_wrong_owner_intents_reject_without_mutation() -> void:
	var runtime_upgrade: Dictionary = _h9_source(_state)
	var cases: Array[Dictionary] = []
	var stale_lifecycle: Dictionary = _use_payload(_state, runtime_upgrade, 0)
	stale_lifecycle[ORCHESTRATOR.COMMAND_KEY_LIFECYCLE_ID] = "attack_modify:1"
	cases.append(stale_lifecycle)
	var stale_attack: Dictionary = _use_payload(_state, runtime_upgrade, 0)
	stale_attack[RULE.PAYLOAD_ATTACK_ID] = "attack:99"
	cases.append(stale_attack)
	var stale_source: Dictionary = _use_payload(_state, runtime_upgrade, 0)
	stale_source[RULE.PAYLOAD_RUNTIME_UPGRADE_ID] = "missing"
	stale_source[OPPORTUNITY.KEY_RUNTIME_SOURCE_ID] = "missing"
	cases.append(stale_source)
	var stale_die: Dictionary = _use_payload(_state, runtime_upgrade, 0)
	stale_die["expected_face"] = int(Constants.DiceFace.CRITICAL)
	cases.append(stale_die)
	var wrong_target: Dictionary = _use_payload(_state, runtime_upgrade, 0)
	wrong_target[RULE.PAYLOAD_TARGET_FACE] = int(Constants.DiceFace.HIT)
	cases.append(wrong_target)
	var invalid_index: Dictionary = _use_payload(_state, runtime_upgrade, 0)
	invalid_index["die_index"] = 99
	cases.append(invalid_index)

	for payload: Dictionary in cases:
		var before: Dictionary = _state.serialize()
		var command: GameCommand = USE_COMMAND.new(0, payload)
		assert_eq(_processor.submit(command), {})
		assert_eq(_state.serialize(), before)
		assert_eq(command.sequence, -1)

	var before_wrong_player: Dictionary = _state.serialize()
	assert_eq(_processor.submit(USE_COMMAND.new(
			1, _use_payload(_state, runtime_upgrade, 0))), {})
	assert_eq(_state.serialize(), before_wrong_player)
	assert_engine_error(cases.size() + 1)


func test_black_die_and_non_icon_face_fail_command_validation() -> void:
	var black: GameState = _make_state({
		"dice_results": [_die(Constants.DiceColor.BLACK,
				Constants.DiceFace.HIT)],
	})
	var black_source: Dictionary = _h9_source(black)
	var black_payload: Dictionary = _identity_payload(black, black_source)
	black_payload.merge({
		"die_index": 0,
		"expected_color": int(Constants.DiceColor.BLACK),
		"expected_face": int(Constants.DiceFace.HIT),
		"target_face": int(Constants.DiceFace.ACCURACY),
	})
	assert_ne(USE_COMMAND.new(0, black_payload).validate(black), "")

	var blank: GameState = _make_state({
		"dice_results": [_die(Constants.DiceColor.RED,
				Constants.DiceFace.BLANK)],
	})
	var blank_source: Dictionary = _h9_source(blank)
	var blank_payload: Dictionary = _identity_payload(blank, blank_source)
	blank_payload.merge({
		"die_index": 0,
		"expected_color": int(Constants.DiceColor.RED),
		"expected_face": int(Constants.DiceFace.BLANK),
		"target_face": int(Constants.DiceFace.ACCURACY),
	})
	assert_ne(USE_COMMAND.new(0, blank_payload).validate(blank), "")


func test_expected_source_rejects_after_another_modifier_changes_the_die() -> void:
	var runtime_upgrade: Dictionary = _h9_source(_state)
	var stale_command: GameCommand = USE_COMMAND.new(
			0, _use_payload(_state, runtime_upgrade, 0))
	var attack: CurrentAttackState = _state.current_attack_state
	assert_true(_state.set_current_attack_state(attack.with_patch({
		"dice_results": [
			_die(Constants.DiceColor.RED, Constants.DiceFace.CRITICAL),
			attack.dice_results[1],
		],
	})))
	assert_ne(stale_command.validate(_state), "")


func test_confirm_cleans_guard_and_generated_accuracy_drives_defense() -> void:
	var runtime_upgrade: Dictionary = _h9_source(_state)
	assert_false(_processor.submit_deferred_followups(USE_COMMAND.new(
			0, _use_payload(_state, runtime_upgrade, 0))).is_empty())
	assert_false(RULE.resolution_guard(runtime_upgrade).is_empty())
	_processor.drain_observer_followups()

	assert_true(RULE.resolution_guard(runtime_upgrade).is_empty())
	assert_true(_state.timing_window_state.is_inactive())
	assert_eq(_state.current_attack_state.stage,
			CurrentAttackState.STAGE_ACCURACY)
	assert_false(_processor.submit(CommitAccuracyCommand.new(0, {
		"attack_id": _state.current_attack_state.attack_id,
		"locked_tokens": [0],
	})).is_empty())
	assert_eq(_state.current_attack_state.accuracy_locked_tokens, [0])
	assert_eq(_state.current_attack_state.stage, CurrentAttackState.STAGE_DEFENSE)


func test_terminal_attack_commands_clean_matching_guard_idempotently() -> void:
	for reason: String in ["cancelled", "flow_replaced", "flow_terminated"]:
		var state: GameState = _make_state()
		var runtime_upgrade: Dictionary = _h9_source(state)
		assert_true(RULE.write_resolution_guard(
				runtime_upgrade, "attack:0", RULE.RESOLUTION_USED))
		GameManager.current_game_state = state
		var processor: Node = PROCESSOR_SCRIPT.new()
		add_child_autofree(processor)
		assert_true(processor.restore_next_sequence(3))
		var result: Dictionary = processor.submit(SkipAttackCommand.new(0, {
			"attack_id": "attack:0",
			"reason": reason,
			ORCHESTRATOR.COMMAND_KEY_LIFECYCLE_ID:
					state.timing_window_state.lifecycle_id,
		}))
		assert_false(result.is_empty())
		assert_true(RULE.resolution_guard(runtime_upgrade).is_empty())
		assert_true(RULE.clear_attack_guards(state, "attack:0").is_empty())

	var complete_state: GameState = _make_state({
		"stage": CurrentAttackState.STAGE_RESOLVED,
		"open_window": false,
	})
	var complete_source: Dictionary = _h9_source(complete_state)
	assert_true(RULE.write_resolution_guard(
			complete_source, "attack:0", RULE.RESOLUTION_DECLINED))
	GameManager.current_game_state = complete_state
	var complete_processor: Node = PROCESSOR_SCRIPT.new()
	add_child_autofree(complete_processor)
	var complete_result: Dictionary = complete_processor.submit(
			CompleteAttackCommand.new(0, {"attack_id": "attack:0"}))
	assert_false(complete_result.is_empty())
	assert_true(RULE.resolution_guard(complete_source).is_empty())


func test_anti_squadron_target_and_next_attack_receive_fresh_h9_opportunity() -> void:
	var state: GameState = _make_state({
		"defender_kind": CurrentAttackState.KIND_SQUADRON,
	})
	GameManager.current_game_state = state
	var processor: Node = PROCESSOR_SCRIPT.new()
	add_child_autofree(processor)
	assert_true(processor.restore_next_sequence(3))
	var source: Dictionary = _h9_source(state)
	assert_false(processor.submit_deferred_followups(USE_COMMAND.new(
			0, _use_payload(state, source, 0))).is_empty())
	processor.drain_observer_followups()
	assert_true(RULE.resolution_guard(source).is_empty())

	assert_not_null(CURRENT_ATTACK_FIXTURE.install(state, {
		"attack_id": "attack:5",
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
		"attacker_kind": CurrentAttackState.KIND_SHIP,
		"defender_kind": CurrentAttackState.KIND_SQUADRON,
		"dice_results": [_die(Constants.DiceColor.BLUE,
				Constants.DiceFace.HIT)],
	}))
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY, 0)
	assert_true(bool(ORCHESTRATOR.open_window(
			state, TimingWindowDefinitions.ATTACK_MODIFY, 6,
			_context(state)).get(ORCHESTRATOR.KEY_OK, false)))
	assert_eq(_opportunities(state).size(), 1)


func test_projection_is_public_and_controller_receives_one_choice_per_eligible_die() -> void:
	var owner: Dictionary = UIProjector.project(_state, 0).timing_window
	var observer: Dictionary = UIProjector.project(_state, 1).timing_window
	var owner_h9: Dictionary = _projected_h9(owner)
	var observer_h9: Dictionary = _projected_h9(observer)

	assert_false(owner_h9.is_empty())
	assert_false(observer_h9.is_empty())
	assert_eq((owner_h9.get("use_choices", []) as Array).size(), 1)
	assert_false(owner_h9.has("use_intent"))
	assert_true(owner_h9.has("decline_intent"))
	assert_false(observer_h9.has("use_choices"))
	assert_false(observer_h9.has("decline_intent"))


func test_generic_panel_collects_h9_die_before_emitting_exact_intent() -> void:
	var projected: Dictionary = UIProjector.project(_state, 0).timing_window
	var opportunities: Array = projected.get("opportunities", []) as Array
	var projected_h9: Dictionary = _projected_h9(projected)
	var use_choices: Array = projected_h9.get("use_choices", []) as Array
	var expected_intent: Dictionary = (use_choices[0] as Dictionary).get(
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
	assert_string_contains(panel.get_body_text(), "Select an eligible die",
			"Parameterized H9 selection should present its transient prompt.")
	assert_signal_not_emitted(panel, "timing_window_use_requested")
	assert_true(_processor.serialize_history().is_empty())
	assert_true(use_button.disabled)
	assert_eq(panel._dice_textures[0].mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq(panel._dice_textures[1].mouse_filter,
			Control.MOUSE_FILTER_IGNORE)
	var original_die: TextureRect = panel._dice_textures[0]
	panel.show_dice_results(_state.current_attack_state.dice_results)
	assert_ne(panel._dice_textures[0], original_die,
			"Canonical projection should rebuild H9 dice.")
	assert_eq(panel._dice_textures[0].mouse_filter,
			Control.MOUSE_FILTER_STOP,
			"H9 parameter collection must survive canonical refresh.")
	assert_eq(panel._dice_textures[1].mouse_filter,
			Control.MOUSE_FILTER_IGNORE)

	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	panel._on_die_clicked(click, panel._dice_textures[1])
	assert_signal_not_emitted(panel, "timing_window_use_requested")
	assert_true(_processor.serialize_history().is_empty())
	panel._dice_textures[0].gui_input.emit(click)
	assert_signal_emitted(panel, "timing_window_use_requested")
	assert_eq(get_signal_parameters(
			panel, "timing_window_use_requested"), [expected_intent])
	assert_eq(_history_types(_processor.serialize_history()), [USE_COMMAND.TYPE])
	assert_eq(_state.current_attack_state.dice_results[0],
			_die(Constants.DiceColor.RED, Constants.DiceFace.ACCURACY))
	assert_eq(RULE.resolution_guard(_h9_source(_state)).get(
			RULE.GUARD_RESOLUTION), RULE.RESOLUTION_USED)
	assert_true(panel._timing_window_die_intents.is_empty())
	assert_eq(panel._dice_textures[0].mouse_filter,
			Control.MOUSE_FILTER_IGNORE)
	panel.hide_timing_window_opportunities()
	assert_false(panel.get_body_text().contains("Select an eligible die"),
			"Accepted H9 completion must retire its parameter prompt even after "
			+ "the local die intent has already been consumed.")
	panel._set_prompt("Defense", "Spend defense tokens.")
	panel.hide_timing_window_opportunities()
	assert_eq(panel.get_body_text(), "Spend defense tokens.",
			"Attack Modify cleanup must not overwrite a later-stage prompt.")
	panel.show_dice_results(_state.current_attack_state.dice_results)
	assert_eq(panel._dice_textures[0].mouse_filter,
			Control.MOUSE_FILTER_IGNORE,
			"Accepted H9 input must not be restored after refresh.")
	await get_tree().process_frame


func test_generic_panel_h9_decline_submits_without_parameter_mode() -> void:
	var projected: Dictionary = UIProjector.project(_state, 0).timing_window
	var opportunities: Array = projected.get("opportunities", []) as Array
	var projected_h9: Dictionary = _projected_h9(projected)
	var expected_intent: Dictionary = projected_h9.get(
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
	assert_eq(RULE.resolution_guard(_h9_source(_state)).get(
			RULE.GUARD_RESOLUTION), RULE.RESOLUTION_DECLINED)
	assert_true(panel._timing_window_die_intents.is_empty())


func test_commands_are_attack_modify_only_and_round_trip_integer_payloads() -> void:
	for command_type: String in [USE_COMMAND.TYPE, DECLINE_COMMAND.TYPE]:
		assert_true(COMMAND_APPLICABILITY.is_flow_step_allowed(
				command_type, Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_MODIFY))
		assert_false(COMMAND_APPLICABILITY.is_flow_step_allowed(
				command_type, Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_ROLL))
	var command: GameCommand = USE_COMMAND.new(
			0, _use_payload(_state, _h9_source(_state), 0))
	command.sequence = 3
	var restored: GameCommand = GameCommand.deserialize(
			JSON.parse_string(JSON.stringify(command.serialize())) as Dictionary)
	assert_not_null(restored)
	for field: String in ["die_index", "expected_color", "expected_face",
			"target_face"]:
		assert_typeof(restored.payload[field], TYPE_INT)


func test_roll_dice_activates_ship_window_and_compatibility_boundary() -> void:
	var state: GameState = _make_state({
		"stage": CurrentAttackState.STAGE_PRE_ROLL,
		"open_window": false,
	})
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL, 0)
	GameManager.current_game_state = state
	var processor: Node = PROCESSOR_SCRIPT.new()
	add_child_autofree(processor)
	assert_false(processor.submit(RollDiceCommand.new(
			0, {"attack_id": "attack:0"})).is_empty())
	assert_true(state.timing_window_state.active)
	assert_eq(state.timing_window_state.lifecycle_id, "attack_modify:0")
	var opportunities: Array = _opportunities(state)
	assert_eq(opportunities.size(), 1)
	_assert_h9_opportunity(opportunities[0] as Dictionary)
	var projected: Dictionary = UIProjector.project(state, 0).timing_window
	assert_eq(projected.get("timing_window_id"),
			TimingWindowDefinitions.ATTACK_MODIFY)
	assert_true(bool(projected.get("is_interactive", false)))
	assert_false(_projected_h9(projected).is_empty())
	assert_eq(SaveGameMetadata.CURRENT_VERSION, 5)
	assert_eq(GameReplay.FORMAT_VERSION, 7)
	assert_eq(GameReplay.SIGNED_FORMAT_VERSION, GameReplay.FORMAT_VERSION)
	assert_ne(ConfirmAttackDiceCommand.new(0, {"attack_id": "attack:0"}) \
			.validate(state), "")


func _make_state(options: Dictionary = {}) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.rng = GameRng.new(7419)
	var attacker_kind: String = str(options.get(
			"attacker_kind", CurrentAttackState.KIND_SHIP))
	var defender_kind: String = str(options.get(
			"defender_kind", CurrentAttackState.KIND_SHIP))
	var stage: String = str(options.get(
			"stage", CurrentAttackState.STAGE_ATTACK_MODIFY))
	if attacker_kind == CurrentAttackState.KIND_SQUADRON:
		state.current_phase = Constants.GamePhase.SQUADRON
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0,
			Constants.Visibility.ALL,
			{"attacker_player": 0})
	assert_not_null(CURRENT_ATTACK_FIXTURE.install(state, {
		"attack_id": "attack:0",
		"stage": stage,
		"attacker_kind": attacker_kind,
		"defender_kind": defender_kind,
		"dice_results": options.get("dice_results", [
			_die(Constants.DiceColor.RED, Constants.DiceFace.HIT),
			_die(Constants.DiceColor.BLACK, Constants.DiceFace.HIT),
		]),
	}))
	if attacker_kind == CurrentAttackState.KIND_SHIP:
		var ship: ShipInstance = state.get_ship(0, 0)
		ship.roster_entry_id = "attacker-0"
		ship.begin_attack_step()
		for index: int in range(int(options.get("h9_count", 1))):
			_add_h9(state, "h9-%d" % index, index)
	if bool(options.get("open_window", true)) \
			and stage == CurrentAttackState.STAGE_ATTACK_MODIFY:
		assert_true(bool(ORCHESTRATOR.open_window(
				state, TimingWindowDefinitions.ATTACK_MODIFY, 2,
				_context(state)).get(ORCHESTRATOR.KEY_OK, false)))
	return state


func _add_h9(state: GameState,
		assignment_id: String,
		slot_index: int) -> Dictionary:
	return state.get_ship(0, 0).add_runtime_upgrade(
			RULE.DATA_KEY, assignment_id, "TURBOLASERS", slot_index)


func _h9_source(state: GameState) -> Dictionary:
	for runtime_upgrade: Dictionary in state.get_ship(0, 0).runtime_upgrades:
		if str(runtime_upgrade.get("data_key", "")) == RULE.DATA_KEY:
			return runtime_upgrade
	return {}


func _context(state: GameState) -> Dictionary:
	return {
		TimingWindowState.CONTINUATION_KEY_ID: ConfirmAttackDiceCommand.TYPE,
		TimingWindowState.CONTINUATION_KEY_RESUME_POINT: "attack_after_modify",
		TimingWindowState.CONTINUATION_KEY_SOURCE_ID:
				state.current_attack_state.attack_id,
		TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE: "current_attack",
		TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER: 0,
	}


func _identity_payload(state: GameState,
		runtime_upgrade: Dictionary) -> Dictionary:
	var runtime_upgrade_id: String = str(runtime_upgrade.get(
			"runtime_upgrade_id", ""))
	return {
		ORCHESTRATOR.COMMAND_KEY_TIMING_WINDOW_ID:
				state.timing_window_state.timing_window_id,
		ORCHESTRATOR.COMMAND_KEY_LIFECYCLE_ID:
				state.timing_window_state.lifecycle_id,
		OPPORTUNITY.KEY_SOURCE_OWNER_KIND: RULE.SOURCE_OWNER_KIND,
		OPPORTUNITY.KEY_RUNTIME_SOURCE_ID: runtime_upgrade_id,
		OPPORTUNITY.KEY_SEMANTIC_KEY: RULE.SEMANTIC_KEY,
		RULE.PAYLOAD_ATTACK_ID: state.current_attack_state.attack_id,
		RULE.PAYLOAD_RUNTIME_UPGRADE_ID: runtime_upgrade_id,
	}


func _use_payload(state: GameState,
		runtime_upgrade: Dictionary,
		die_index: int) -> Dictionary:
	var payload: Dictionary = _identity_payload(state, runtime_upgrade)
	var selected: Dictionary = state.current_attack_state.dice_results[die_index]
	payload.merge({
		"die_index": die_index,
		"expected_color": int(selected.get("color", -1)),
		"expected_face": int(selected.get("face", -1)),
		RULE.PAYLOAD_TARGET_FACE: int(Constants.DiceFace.ACCURACY),
	})
	return payload


func _opportunities(state: GameState) -> Array:
	var result: Dictionary = ORCHESTRATOR.derive_current_opportunities(state)
	assert_true(bool(result.get(ORCHESTRATOR.KEY_OK, false)))
	return result.get(ORCHESTRATOR.KEY_OPPORTUNITIES, []) as Array


func _assert_h9_opportunity(opportunity: Dictionary) -> void:
	assert_eq(opportunity.get(OPPORTUNITY.KEY_CAPABILITY_ID), RULE.CAPABILITY_ID)
	assert_eq(opportunity.get(OPPORTUNITY.KEY_SOURCE_OWNER_KIND),
			RULE.SOURCE_OWNER_KIND)
	assert_eq(opportunity.get(OPPORTUNITY.KEY_SEMANTIC_KEY), RULE.SEMANTIC_KEY)
	assert_eq(opportunity.get(OPPORTUNITY.KEY_RESOLUTION_KIND),
			OPPORTUNITY.RESOLUTION_OPTIONAL)
	assert_true(bool(opportunity.get(OPPORTUNITY.KEY_BLOCKING, false)))
	assert_eq((opportunity.get(OPPORTUNITY.KEY_USE_INTENT) as Dictionary).get(
			OPPORTUNITY.INTENT_KEY_COMMAND_TYPE), USE_COMMAND.TYPE)
	assert_eq((opportunity.get(OPPORTUNITY.KEY_DECLINE_INTENT) as Dictionary).get(
			OPPORTUNITY.INTENT_KEY_COMMAND_TYPE), DECLINE_COMMAND.TYPE)


func _projected_h9(timing_projection: Dictionary) -> Dictionary:
	for opportunity: Dictionary in timing_projection.get("opportunities", []):
		if str(opportunity.get("capability_id", "")) == RULE.CAPABILITY_ID:
			return opportunity
	return {}


func _history_types(commands: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for command: Dictionary in commands:
		result.append(str(command.get("type", "")))
	return result


func _die(color: Constants.DiceColor,
		face: Constants.DiceFace) -> Dictionary:
	return {"color": int(color), "face": int(face)}
