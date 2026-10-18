## Boundary B: declared Attack publication integers and preflight hook safety.
extends GutTest


const CmdProcessor: GDScript = preload("res://src/autoload/command_processor.gd")
const POLICY: GDScript = preload(
		"res://src/core/commands/attack_publication_payload_integers.gd")
const ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")

var _state: GameState
var _processor: Node
var _previous_state: GameState
var _saved_registry: Dictionary


func before_each() -> void:
	_previous_state = GameManager.current_game_state
	_saved_registry = GameCommand._registry.duplicate()
	RuleRegistry.clear()
	CoolantDischarge.register()
	EscortKeyword.register()
	PublishAttackFlowCommand.register()
	_state = GameState.new()
	_state.initialize()
	_state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human())
	_state.current_phase = Constants.GamePhase.SHIP
	_state.current_round = 1
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE, 0,
			Constants.Visibility.ALL, {"attack_id": "attack:0"})
	assert_not_null(ATTACK_FIXTURE.install(_state, {"attack_id": "attack:0"}))
	GameManager.current_game_state = _state
	_processor = CmdProcessor.new()
	add_child_autofree(_processor)


func after_each() -> void:
	RuleRegistry.clear()
	GameCommand._registry = _saved_registry
	GameManager.current_game_state = _previous_state


func test_complete_integer_union_json_roundtrip_and_flow_reconstruction() -> void:
	var flow_payload: Dictionary = _full_payload()
	assert_eq(POLICY.validate(flow_payload), "")
	var original: Dictionary = flow_payload.duplicate(true)
	var cmd: PublishAttackFlowCommand = _command(flow_payload)
	var decoded: Variant = JSON.parse_string(JSON.stringify(cmd.serialize()))
	var restored: GameCommand = GameCommand.deserialize(decoded as Dictionary)
	assert_not_null(restored)
	assert_eq(flow_payload, original,
			"Policy and command codec must not mutate the source payload.")
	var actual: Dictionary = restored.payload["flow_payload"] as Dictionary
	assert_eq(typeof(actual["ship_target_attacks_this_round"]), TYPE_INT)
	assert_eq(typeof(actual["counter_attacker_player"]), TYPE_INT)
	assert_eq(typeof(actual["counter_dice_pool"]["BLUE"]), TYPE_INT)
	assert_eq(typeof(actual["pending_die_removal"]["controller_player"]),
			TYPE_INT)
	assert_eq(typeof(actual["ecm_choice"]["eligible_token_indices"][0]),
			TYPE_INT)
	assert_eq(typeof(actual["choice_info"]["max_selections"]), TYPE_INT)
	assert_eq(typeof(actual["dice_results"][0]["face"]), TYPE_STRING)
	assert_eq(actual["defender_zone"], "front")
	assert_eq(actual["target_player"], ["opaque"])
	var flow: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			0, Constants.Visibility.ALL, actual)
	var reconstructed: InteractionFlow = InteractionFlow.deserialize(
			JSON.parse_string(JSON.stringify(flow.serialize())) as Dictionary)
	assert_not_null(reconstructed)
	assert_eq(CanonicalJson.hash(reconstructed.serialize()),
			CanonicalJson.hash(flow.serialize()))


func test_accepted_replay_twelve_publications_reconstruct_exact_integers() -> void:
	var path: String = "res://docs/qa/bugs/closed/BUG-074/" \
			+ "replay_20261015_065840.json"
	var raw: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(path)) as Dictionary
	assert_eq((raw["commands"] as Array).size(), 83)
	var publications: int = 0
	for raw_command: Dictionary in raw["commands"] as Array:
		if raw_command.get("type") != "publish_attack_flow":
			continue
		publications += 1
		var canonical: Dictionary = GameCommand.canonicalize_serialized(
				raw_command)
		assert_false(canonical.is_empty())
		var command: GameCommand = GameCommand.deserialize(canonical)
		assert_not_null(command)
		assert_eq(CanonicalJson.hash(command.serialize()),
				CanonicalJson.hash(canonical))
		var flow_payload: Dictionary = canonical["payload"]["flow_payload"]
		var raw_flow: Dictionary = raw_command["payload"]["flow_payload"]
		assert_eq(POLICY.validate(flow_payload), "")
		if flow_payload.has("ship_target_attacks_this_round"):
			assert_eq(typeof(raw_flow["ship_target_attacks_this_round"]),
					TYPE_FLOAT)
			assert_eq(typeof(flow_payload["ship_target_attacks_this_round"]),
					TYPE_INT)
		if flow_payload.has("accuracy_count"):
			assert_eq(typeof(flow_payload["accuracy_count"]), TYPE_INT)
			assert_eq(typeof(flow_payload["spendable_accuracy_count"]),
					TYPE_INT)
		if flow_payload.has("counter_attacker_player"):
			assert_eq(typeof(flow_payload["counter_attacker_player"]), TYPE_INT)
			assert_eq(typeof(flow_payload["counter_target_player"]), TYPE_INT)
			assert_eq(typeof(flow_payload["counter_dice_pool"]["BLUE"]),
					TYPE_INT)
	assert_eq(publications, 17)


func test_submitted_publication_converges_with_flow_json_reconstruction() -> void:
	var flow_payload: Dictionary = _base_payload()
	flow_payload["ship_target_attacks_this_round"] = 0.0
	var command: PublishAttackFlowCommand = _command(flow_payload)
	assert_false(_processor.submit(command).is_empty())
	assert_eq(typeof(command.payload["flow_payload"]
			["ship_target_attacks_this_round"]), TYPE_INT)
	var flow: InteractionFlow = _state.interaction_flow
	assert_eq(typeof(flow.payload["ship_target_attacks_this_round"]),
			TYPE_INT)
	var restored: InteractionFlow = InteractionFlow.deserialize(
			JSON.parse_string(JSON.stringify(flow.serialize())) as Dictionary)
	assert_not_null(restored)
	assert_eq(CanonicalJson.hash(restored.serialize()),
			CanonicalJson.hash(flow.serialize()))


func test_counter_identity_required_only_at_counter_choice() -> void:
	var ordinary: Dictionary = _base_payload()
	ordinary["counter_attacker_player"] = 0.0
	var ordinary_command: PublishAttackFlowCommand = _command(ordinary)
	assert_eq(ordinary_command.validate(_state), "")
	assert_eq(typeof(ordinary_command.payload["flow_payload"]
			["counter_attacker_player"]), TYPE_INT)
	var counter_command: PublishAttackFlowCommand = _command(ordinary)
	counter_command.payload["step_id"] = int(
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE)
	assert_ne(counter_command.validate(_state), "")


func test_codec_rejects_malformed_declared_fields_but_preserves_mixed_strings() -> void:
	var valid: Dictionary = _base_payload()
	valid["defender_zone"] = "front"
	valid["dice_results"] = [{"color": "red", "face": "hit"}]
	valid["target_player"] = []
	var accepted: GameCommand = GameCommand.deserialize(
			JSON.parse_string(JSON.stringify(_command(valid).serialize()))
			as Dictionary)
	assert_not_null(accepted)
	assert_eq(accepted.payload["flow_payload"]["defender_zone"], "front")
	assert_eq(accepted.payload["flow_payload"]["target_player"], [])
	for bad: Variant in ["0", true, 0.5, -1, 2147483648]:
		var malformed: Dictionary = valid.duplicate(true)
		malformed["attacker_player"] = bad
		assert_null(GameCommand.deserialize(JSON.parse_string(
				JSON.stringify(_command(malformed).serialize()))
				as Dictionary))
	var nested: Dictionary = valid.duplicate(true)
	nested["ecm_choice"] = {"eligible_token_indices": ["0"]}
	assert_null(GameCommand.deserialize(JSON.parse_string(
			JSON.stringify(_command(nested).serialize())) as Dictionary))


func test_declared_malformed_values_reject_before_hooks() -> void:
	var bad_values: Array[Variant] = [[], "0", true, 0.5, INF, NAN,
			2147483648, -1]
	for bad: Variant in bad_values:
		var flow_payload: Dictionary = _base_payload()
		flow_payload["attacker_player"] = bad
		_assert_early_rejection(_command(flow_payload),
				typeof(bad) == TYPE_FLOAT and is_nan(float(bad)))
	for patch: Dictionary in [
			{"dice_pool": {"RED": "2"}},
			{"counter_dice_pool": {"BLUE": false}},
			{"locked_tokens": [0.5]},
			{"ecm_choice": {"defender_player": []}},
			{"ecm_choice": {"eligible_token_indices": ["0"]}},
			{"pending_die_removal": {"controller_player": INF}},
			{"choice_info": {"max_selections": -1}},
			{"defense_tokens": [{"type": "0"}]},
			{"dice_results": [{"color": true}]},
			{"defender_zone": false},
			{"ecm_choice": []},
	]:
		var flow_payload: Dictionary = _base_payload()
		flow_payload.merge(patch, true)
		_assert_early_rejection(_command(flow_payload))
	for bad_container: Variant in [null, [], "bad", 0]:
		_assert_early_rejection(_command(bad_container))
	assert_engine_error(23)


func test_valid_native_and_integral_json_numbers_reach_hooks_unchanged() -> void:
	var native: PublishAttackFlowCommand = _command(_base_payload())
	var native_before: Dictionary = native.payload.duplicate(true)
	assert_eq(_processor.preflight(native, _state), "")
	assert_eq(native.payload, native_before)
	var json_payload: Dictionary = JSON.parse_string(
			JSON.stringify(_base_payload())) as Dictionary
	assert_eq(typeof(json_payload["attacker_player"]), TYPE_FLOAT)
	var json_cmd: PublishAttackFlowCommand = _command(json_payload)
	assert_eq(_processor.preflight(json_cmd, _state), "")
	assert_eq(typeof(json_cmd.payload["flow_payload"]["attacker_player"]),
			TYPE_FLOAT, "Preflight must not canonicalize the submitted payload.")
	assert_eq(json_cmd.validate(_state), "")
	assert_eq(typeof(json_cmd.payload["flow_payload"]["attacker_player"]),
			TYPE_INT, "Full command validation installs canonical integers.")


func test_escort_ignores_unknown_target_player_for_direct_and_json_commands() -> void:
	var baseline: Dictionary = _squadron_payload()
	var expected: Dictionary = EscortKeyword.new().validate_attack_flow_publish(
			_state, _command(baseline))
	for unknown: Variant in [[], "bogus", true, {"bad": "value"}]:
		var flow_payload: Dictionary = baseline.duplicate(true)
		flow_payload["target_player"] = unknown
		for json_path: bool in [false, true]:
			var cmd: GameCommand = _command(flow_payload)
			if json_path:
				cmd = GameCommand.deserialize(JSON.parse_string(
						JSON.stringify(cmd.serialize())) as Dictionary)
			assert_not_null(cmd)
			var before: Dictionary = cmd.payload.duplicate(true)
			assert_eq(_processor.preflight(cmd, _state), "")
			assert_eq(cmd.payload, before)
			assert_eq(EscortKeyword.new().validate_attack_flow_publish(
					_state, cmd), expected)
			assert_eq(cmd.payload["flow_payload"]["target_player"], unknown)
			cmd.payload["source_attack_id"] = "attack:1"
			var state_before: Dictionary = _state.serialize()
			var digest_before: String = CanonicalJson.hash(state_before)
			var sequence_before: int = _processor.get_next_sequence()
			var history_before: int = _processor.get_command_count()
			var followups_before: int = \
					_processor.get_pending_observer_followup_count()
			assert_true(_processor.submit(cmd).is_empty())
			assert_eq(_state.serialize(), state_before)
			assert_eq(CanonicalJson.hash(_state.serialize()), digest_before)
			assert_eq(_processor.get_next_sequence(), sequence_before)
			assert_eq(_processor.get_command_count(), history_before)
			assert_eq(_processor.get_pending_observer_followup_count(),
					followups_before)
	assert_engine_error(8)


func _assert_early_rejection(command: PublishAttackFlowCommand,
		has_nan: bool = false) -> void:
	var command_before: Dictionary = command.payload.duplicate(true)
	var state_before: Dictionary = _state.serialize()
	var digest_before: String = CanonicalJson.hash(state_before)
	var sequence_before: int = _processor.get_next_sequence()
	var history_before: int = _processor.get_command_count()
	var followups_before: int = _processor.get_pending_observer_followup_count()
	assert_ne(_processor.preflight(command, _state), "")
	if has_nan:
		assert_true(is_nan(float((command.payload["flow_payload"] as Dictionary)
				.get("attacker_player"))))
	else:
		assert_eq(command.payload, command_before)
	assert_true(_processor.submit(command).is_empty())
	assert_eq(_state.serialize(), state_before)
	assert_eq(CanonicalJson.hash(_state.serialize()), digest_before)
	assert_eq(_processor.get_next_sequence(), sequence_before)
	assert_eq(_processor.get_command_count(), history_before)
	assert_eq(_processor.get_pending_observer_followup_count(),
			followups_before)
	if has_nan:
		assert_true(is_nan(float((command.payload["flow_payload"] as Dictionary)
				.get("attacker_player"))))
	else:
		assert_eq(command.payload, command_before)


func _command(flow_payload: Variant) -> PublishAttackFlowCommand:
	return PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_DECLARE),
		"controller_player": 0,
		"flow_payload": flow_payload,
		"final": false,
		"source_attack_id": "attack:0",
	})


func _base_payload() -> Dictionary:
	return {"attack_id": "attack:0", "attacker_kind": "ship",
		"attacker_player": 0, "attacker_ship_index": 0,
		"target_kind": "ship", "target_ship_index": 0}


func _squadron_payload() -> Dictionary:
	return {"attack_id": "attack:0", "attacker_kind": "squadron",
		"attacker_player": 0, "attacker_squadron_index": 0,
		"target_kind": "squadron", "defender_player": 1,
		"target_squadron_index": 0}


func _full_payload() -> Dictionary:
	var result: Dictionary = _base_payload()
	for key: String in POLICY.DIRECT_FIELDS:
		result[key] = 0
	result["defender_zone"] = "front"
	result["dice_pool"] = {"RED": 1}
	result["counter_dice_pool"] = {"BLUE": 2}
	for key: String in POLICY.INTEGER_ARRAYS:
		result[key] = [0]
	result["dice_results"] = [{"color": 1, "face": "hit"}]
	result["defense_tokens"] = [{"type": 1, "state": 0}]
	result["pending_die_removal"] = {"controller_player": 0}
	result["ecm_choice"] = {"defender_player": 1,
		"defender_ship_index": 0, "eligible_token_indices": [0]}
	result["choice_info"] = {"max_selections": 1}
	result["target_player"] = ["opaque"]
	return result
