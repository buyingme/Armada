## Unit tests for [InteractionFlow] domain type and [GameState] integration.
##
## Covers:
##   * Default field values
##   * [code]make()[/code] and [code]empty()[/code] factories
##   * Round-trip serialise / deserialise (incl. payload deep-copy)
##   * Forward compat: missing keys → defaults
##   * [code]is_actor()[/code] semantics
##   * [GameState] wires the field through serialize / deserialize
##   * [StateFilter] strips OWNER payload from non-controllers
##   * Constants enum coverage matches legacy id maps
##
## Phase I — see [code]docs/refactoring_phase_i_plan.md[/code], step I1.
extends GutTest


# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

func test_new_flow_type_is_none() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_eq(f.flow_type, Constants.InteractionFlow.NONE,
			"Default flow_type must be NONE.")


func test_new_step_id_is_none() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_eq(f.step_id, Constants.InteractionStep.NONE,
			"Default step_id must be NONE.")


func test_new_controller_player_is_minus_one() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_eq(f.controller_player, -1,
			"Default controller_player must be -1.")


func test_new_visible_to_is_all() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_eq(f.visible_to, Constants.Visibility.ALL,
			"Default visible_to must be ALL.")


func test_new_payload_is_empty() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_eq(f.payload.size(), 0, "Default payload must be empty.")


# ---------------------------------------------------------------------------
# Factories
# ---------------------------------------------------------------------------

func test_make_assigns_all_fields() -> void:
	var f: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			1,
			Constants.Visibility.OWNER,
			{"attack_id": 42})
	assert_eq(f.flow_type, Constants.InteractionFlow.ATTACK)
	assert_eq(f.step_id, Constants.InteractionStep.ATTACK_ROLL)
	assert_eq(f.controller_player, 1)
	assert_eq(f.visible_to, Constants.Visibility.OWNER)
	assert_eq(f.payload.get("attack_id", -1), 42)


func test_make_deep_copies_payload() -> void:
	var src: Dictionary = {"k": [1, 2, 3]}
	var f: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			0, Constants.Visibility.ALL, src)
	src["k"].append(4)
	assert_eq((f.payload.get("k", []) as Array).size(), 3,
			"make() must deep-copy the payload.")


func test_empty_returns_default_flow() -> void:
	var f: InteractionFlow = InteractionFlow.empty()
	assert_eq(f.flow_type, Constants.InteractionFlow.NONE)
	assert_eq(f.controller_player, -1)


# ---------------------------------------------------------------------------
# Serialisation round-trip
# ---------------------------------------------------------------------------

func test_serialize_default_yields_expected_keys() -> void:
	var data: Dictionary = InteractionFlow.new().serialize()
	for key in ["flow_type", "step_id", "controller_player",
			"visible_to", "payload"]:
		assert_true(data.has(key), "serialize() must include key %s" % key)


func test_round_trip_preserves_all_fields() -> void:
	var original: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			0,
			Constants.Visibility.OWNER,
			{"ship_index": 2, "speed": 3})
	var clone: InteractionFlow = InteractionFlow.deserialize(
			original.serialize())
	assert_true(clone.equals(original), "Round-trip must preserve all fields.")


func test_round_trip_preserves_nested_payload() -> void:
	var original: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			1,
			Constants.Visibility.OWNER,
			{"tokens": [ {"type": "evade", "state": "ready"}]})
	var clone: InteractionFlow = InteractionFlow.deserialize(
			original.serialize())
	var tokens: Array = clone.payload.get("tokens", [])
	assert_eq(tokens.size(), 1)
	assert_eq((tokens[0] as Dictionary).get("type", ""), "evade")


func test_payload_deep_copied_on_serialize() -> void:
	var f: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			0, Constants.Visibility.ALL, {"k": [1]})
	var data: Dictionary = f.serialize()
	(data["payload"]["k"] as Array).append(2)
	assert_eq((f.payload["k"] as Array).size(), 1,
			"serialize() output must not alias internal payload.")


func test_deserialize_missing_keys_uses_defaults() -> void:
	var f: InteractionFlow = InteractionFlow.deserialize({})
	assert_eq(f.flow_type, Constants.InteractionFlow.NONE)
	assert_eq(f.step_id, Constants.InteractionStep.NONE)
	assert_eq(f.controller_player, -1)
	assert_eq(f.visible_to, Constants.Visibility.ALL)
	assert_eq(f.payload.size(), 0)


func test_deserialize_handles_non_dictionary_payload() -> void:
	# Belt-and-braces: malformed input should not crash.
	var f: InteractionFlow = InteractionFlow.deserialize({"payload": "oops"})
	assert_eq(f.payload.size(), 0,
			"Non-dictionary payload must be coerced to {}.")


func test_counter_identity_json_round_trip_restores_all_four_integers() -> void:
	var encoded: String = JSON.stringify(_counter_flow_data())
	var decoded: Variant = JSON.parse_string(encoded)
	assert_true(decoded is Dictionary)
	for key: String in _counter_identity_keys():
		assert_eq(typeof((decoded as Dictionary)["payload"][key]), TYPE_FLOAT)

	var restored: InteractionFlow = InteractionFlow.deserialize(
			decoded as Dictionary)
	assert_not_null(restored)
	for key: String in _counter_identity_keys():
		assert_eq(typeof(restored.payload[key]), TYPE_INT,
				"%s must be canonical int after JSON reconstruction." % key)


func test_counter_identity_reconstruction_fails_closed_for_partial_payload() \
		-> void:
	var data: Dictionary = _counter_flow_data()
	(data["payload"] as Dictionary).erase(
			"counter_target_squadron_index")
	assert_null(InteractionFlow.deserialize(data))


func test_counter_identity_reconstruction_fails_closed_for_invalid_values() \
		-> void:
	var cases: Array[Dictionary] = [
		{"field": "counter_attacker_player", "value": 0.5},
		{"field": "counter_attacker_player", "value": true},
		{"field": "counter_attacker_player", "value": "1"},
		{"field": "counter_attacker_player", "value": INF},
		{"field": "counter_attacker_player", "value": 2.0},
		{"field": "counter_target_player", "value": -1.0},
		{"field": "counter_attacker_squadron_index", "value": -1.0},
		{"field": "counter_target_squadron_index", "value": 2147483648.0},
	]
	for invalid: Dictionary in cases:
		var data: Dictionary = _counter_flow_data()
		(data["payload"] as Dictionary)[invalid["field"]] = invalid["value"]
		assert_null(InteractionFlow.deserialize(data),
				"Counter identity must reject %s=%s." % [
					invalid["field"], str(invalid["value"])])


func test_counter_identity_normalizes_wherever_present() -> void:
	var data: Dictionary = _counter_flow_data()
	data["step_id"] = int(Constants.InteractionStep.ATTACK_DECLARE)
	var restored: InteractionFlow = InteractionFlow.deserialize(data)
	assert_not_null(restored)
	for key: String in _counter_identity_keys():
		assert_eq(typeof(restored.payload[key]), TYPE_INT)
	var json_data: Dictionary = JSON.parse_string(JSON.stringify(data)) \
			as Dictionary
	var json_restored: InteractionFlow = InteractionFlow.deserialize(json_data)
	assert_not_null(json_restored)
	for key: String in _counter_identity_keys():
		assert_eq(typeof(json_restored.payload[key]), TYPE_INT,
				"Present Counter identity must be restored at ATTACK_DECLARE.")
		assert_eq(json_restored.payload[key], data["payload"][key])
	var partial: Dictionary = _counter_flow_data()
	partial["step_id"] = int(Constants.InteractionStep.ATTACK_DECLARE)
	(partial["payload"] as Dictionary).erase("counter_target_player")
	assert_not_null(InteractionFlow.deserialize(
			JSON.parse_string(JSON.stringify(partial)) as Dictionary))


func _counter_flow_data() -> Dictionary:
	return InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE,
			1, Constants.Visibility.ALL, {
				"attack_id": "attack:50",
				"counter_attacker_player": 1,
				"counter_attacker_squadron_index": 0,
				"counter_target_player": 0,
				"counter_target_squadron_index": 0,
			}).serialize()


func _counter_identity_keys() -> Array[String]:
	return [
		"counter_attacker_player", "counter_attacker_squadron_index",
		"counter_target_player", "counter_target_squadron_index",
	]


func test_declared_non_attack_steps_restore_json_integer_payloads() -> void:
	var cases: Array[Dictionary] = [
		{"flow": Constants.InteractionFlow.NONE,
			"step": Constants.InteractionStep.NONE,
			"payload": {"active_player": 0}},
		{"flow": Constants.InteractionFlow.COMMAND_PHASE,
			"step": Constants.InteractionStep.SELECT_DIALS,
			"payload": {"active_player": 0}},
		{"flow": Constants.InteractionFlow.COMMAND_PHASE,
			"step": Constants.InteractionStep.WAIT_FOR_OPPONENT_DIALS,
			"payload": {"active_player": 1}},
		{"flow": Constants.InteractionFlow.SHIP_ACTIVATION,
			"step": Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			"payload": {"active_player": 0}},
		{"flow": Constants.InteractionFlow.GAME_OVER,
			"step": Constants.InteractionStep.GAME_OVER_STEP,
			"payload": {"active_player": 1}},
		{"flow": Constants.InteractionFlow.SQUADRON_ACTIVATION,
			"step": Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT,
			"payload": {"active_player": 0, "squadron_index": 1}},
	]
	for step: int in [
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN,
			Constants.InteractionStep.REVEAL_DIAL,
			Constants.InteractionStep.SPEND_DIAL,
			Constants.InteractionStep.REPAIR_STEP,
			Constants.InteractionStep.ATTACK_STEP,
			Constants.InteractionStep.MANEUVER_STEP,
			Constants.InteractionStep.ACTIVATION_DONE]:
		cases.append({"flow": Constants.InteractionFlow.SHIP_ACTIVATION,
			"step": step, "payload": {"ship_index": 1}})
	cases.append({"flow": Constants.InteractionFlow.SHIP_ACTIVATION,
		"step": Constants.InteractionStep.SQUADRON_STEP,
		"payload": {"ship_index": 1, "squadron_index": 2}})
	for step: int in [Constants.InteractionStep.ACTION_CHOICE,
			Constants.InteractionStep.SQUAD_MOVE,
			Constants.InteractionStep.SQUAD_ATTACK]:
		cases.append({"flow": Constants.InteractionFlow.SQUADRON_ACTIVATION,
			"step": step,
			"payload": {"ship_index": 1, "squadron_index": 2}})
	cases.append({"flow": Constants.InteractionFlow.SHIP_ACTIVATION,
		"step": Constants.InteractionStep.TARKIN_COMMAND_CHOICE,
		"payload": {"owner_player": 0, "source_ship_index": 1,
			"available_commands": [0, 1]}})
	cases.append({"flow": Constants.InteractionFlow.SETUP,
		"step": Constants.InteractionStep.SETUP_OBSTACLE_PLACEMENT,
		"payload": {"first_player": 0, "controller_player": 1,
			"obstacle_count": 3}})
	for step: int in [Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT,
			Constants.InteractionStep.SETUP_SQUADRON_DEPLOYMENT]:
		cases.append({"flow": Constants.InteractionFlow.SETUP,
			"step": step,
			"payload": {"first_player": 0, "controller_player": 1,
				"deployment_pick": {"owner_player": 1,
					"component_type": "squadron",
					"roster_entry_ids": ["s1"], "required_count": 2}}})
		cases.append({"flow": Constants.InteractionFlow.SETUP,
			"step": step, "payload": {"deployment_pick": {}}})
	cases.append({"flow": Constants.InteractionFlow.SETUP,
		"step": Constants.InteractionStep.SETUP_REVIEW,
		"payload": {"first_player": 0}})
	cases.append({"flow": Constants.InteractionFlow.STATUS_CLEANUP,
		"step": Constants.InteractionStep.STATUS_CLEANUP_STEP,
		"payload": {"ecm_ready_cost_choices": [{"owner_player": 0,
			"ship_index": 1, "rule_id": "ecm"}],
			"optional_status_rules": [{"owner_player": 1,
				"ship_index": 2, "rule_id": "status"}]}})
	for case: Dictionary in cases:
		_assert_json_flow_exact(case["flow"], case["step"], case["payload"])


func test_cumulative_attack_steps_restore_declared_payload() -> void:
	var base: Dictionary = {"attack_id": "attack:1", "attacker_player": 0,
		"defender_player": 1, "attacker_ship_index": 0,
		"attacker_zone": 0, "defender_index": 0,
		"ship_target_attacks_this_round": 1,
		"dice_pool": {"red": 2}, "defender_zone": 0}
	var fsm := AttackFlowFSM.new()
	fsm.begin(null, 0, 1, base)
	_assert_json_flow_exact(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE, fsm.payload)
	assert_true(fsm.advance(null, AttackFlowFSM.Step.ROLL))
	fsm.patch_payload(null, {"pending_die_removal": {
		"controller_player": 1}})
	_assert_json_flow_exact(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL, fsm.payload)
	assert_true(fsm.advance(null, AttackFlowFSM.Step.MODIFY))
	fsm.patch_payload(null, {"dice_results": [{"color": 0, "face": 1}],
		"accuracy_count": 1, "spendable_accuracy_count": 1,
		"swarm_controller_player": 0, "swarm_die_indices": [0]})
	_assert_json_flow_exact(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY, fsm.payload)
	assert_true(fsm.advance(null, AttackFlowFSM.Step.DEFENSE_TOKENS))
	fsm.patch_payload(null, {"modified_damage": 2, "locked_tokens": [0],
		"blocked_defense_token_indices": [1], "ecm_authorized_indices": [0],
		"redirect_adjacent_zones": [1], "spent_defense_token_types": [0],
		"defense_tokens": [{"type": 0, "state": 1}],
		"ecm_choice": {"defender_player": 1,
			"defender_ship_index": 0, "eligible_token_indices": [0]}})
	_assert_json_flow_exact(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS, fsm.payload)
	assert_true(fsm.advance(null, AttackFlowFSM.Step.RESOLVE_DAMAGE))
	fsm.patch_payload(null, {"final_damage": 2})
	_assert_json_flow_exact(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE, fsm.payload)
	var before_restart: Dictionary = fsm.payload.duplicate(true)
	fsm.restart_for_next_attack(null)
	assert_eq(fsm.payload, before_restart)
	_assert_json_flow_exact(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE, fsm.payload)
	assert_true(fsm.advance(null, AttackFlowFSM.Step.ROLL))
	assert_true(fsm.advance(null, AttackFlowFSM.Step.MODIFY))
	assert_true(fsm.advance(null, AttackFlowFSM.Step.RESOLVE_DAMAGE))
	assert_true(fsm.advance(null, AttackFlowFSM.Step.COUNTER_CHOICE))
	fsm.patch_payload(null, {"counter_attacker_player": 1,
		"counter_attacker_squadron_index": 0, "counter_target_player": 0,
		"counter_target_squadron_index": 1,
		"counter_controller_player": 1,
		"counter_dice_pool": {"blue": 1}})
	_assert_json_flow_exact(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE, fsm.payload)
	fsm.restart_for_next_attack(null)
	assert_true(fsm.advance(null, AttackFlowFSM.Step.ROLL))
	assert_true(fsm.advance(null, AttackFlowFSM.Step.MODIFY))
	assert_true(fsm.advance(null, AttackFlowFSM.Step.RESOLVE_DAMAGE))
	assert_true(fsm.advance(null, AttackFlowFSM.Step.CRITICAL_CHOICE))
	fsm.patch_payload(null, {"chooser_player": 1, "pending_card_index": 0,
		"pending_ship_index": 0, "pending_ship_owner_player": 1,
		"choice_info": {"max_selections": 1, "prompt": "choose"}})
	_assert_json_flow_exact(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_CRITICAL_CHOICE, fsm.payload)


func test_complete_attack_integer_union_survives_each_reachable_step() \
		-> void:
	var union: Dictionary = {
		"attacker_player": 0, "attacker_ship_index": 0,
		"attacker_squadron_index": -1, "attacker_zone": 0,
		"controller_player": 0, "defender_index": 0,
		"defender_player": 1, "defender_ship_index": 0,
		"defender_speed": 2, "defender_squadron_index": -1,
		"defender_zone": 0, "ship_target_attacks_this_round": 1,
		"accuracy_count": 1, "spendable_accuracy_count": 1,
		"chooser_player": 1, "final_damage": 2,
		"modified_damage": 2, "redirect_remaining": 1,
		"pending_card_index": 0, "pending_ship_index": 0,
		"pending_ship_owner_player": 1,
		"swarm_controller_player": 0,
		"counter_controller_player": 1,
		"counter_attacker_player": 1,
		"counter_attacker_squadron_index": 0,
		"counter_target_player": 0,
		"counter_target_squadron_index": 0,
		"target_ship_index": 0, "target_squadron_index": -1,
		"dice_pool": {"red": 2}, "counter_dice_pool": {"blue": 1},
		"locked_tokens": [0], "blocked_defense_token_indices": [1],
		"ecm_authorized_indices": [0], "redirect_adjacent_zones": [1],
		"spent_defense_token_types": [0], "swarm_die_indices": [0],
		"dice_results": [{"color": 0, "face": 1}],
		"defense_tokens": [{"type": 0, "state": 1}],
		"pending_die_removal": {"controller_player": 0},
		"ecm_choice": {"defender_player": 1,
			"defender_ship_index": 0, "eligible_token_indices": [0]},
		"choice_info": {"max_selections": 1},
		"attack_id": "attack:union",
	}
	for step: int in [Constants.InteractionStep.ATTACK_DECLARE,
			Constants.InteractionStep.ATTACK_ROLL,
			Constants.InteractionStep.ATTACK_MODIFY,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			Constants.InteractionStep.ATTACK_CRITICAL_CHOICE,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE]:
		_assert_json_flow_exact(Constants.InteractionFlow.ATTACK,
				step as Constants.InteractionStep, union)
	_assert_json_flow_exact(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			{"defender_player": -1, "defender_zone": "front"})


func test_mixed_attack_strings_survive_and_numeric_variants_validate() -> void:
	for label: String in ["front", "arbitrary-existing-string"]:
		_assert_json_flow_exact(Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_MODIFY, {
					"defender_zone": label,
					"dice_results": [{"color": label, "face": "hit"}]})
	_assert_json_flow_exact(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY, {
				"defender_zone": 1,
				"dice_results": [{"color": 0, "face": 1}]})
	for value: Variant in [0.5, INF, -INF, NAN, true, null, [], {}]:
		for field: String in ["defender_zone", "color", "face"]:
			var payload: Dictionary = {"defender_zone": 0,
				"dice_results": [{"color": 0, "face": 1}]}
			if field == "defender_zone":
				payload[field] = value
			else:
				payload["dice_results"][0][field] = value
			assert_null(_decode_json_flow_direct(
					Constants.InteractionFlow.ATTACK,
					Constants.InteractionStep.ATTACK_MODIFY, payload))


func test_declared_field_negative_matrix_and_payload_disposition() -> void:
	var samples: Array[Dictionary] = [
		{"flow": Constants.InteractionFlow.SHIP_ACTIVATION,
			"step": Constants.InteractionStep.MANEUVER_STEP,
			"payload": {"ship_index": 0}},
		{"flow": Constants.InteractionFlow.SQUADRON_ACTIVATION,
			"step": Constants.InteractionStep.ACTION_CHOICE,
			"payload": {"squadron_index": 0}},
		{"flow": Constants.InteractionFlow.COMMAND_PHASE,
			"step": Constants.InteractionStep.SELECT_DIALS,
			"payload": {"active_player": 0}},
		{"flow": Constants.InteractionFlow.SETUP,
			"step": Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT,
			"payload": {"first_player": 0}},
		{"flow": Constants.InteractionFlow.ATTACK,
			"step": Constants.InteractionStep.ATTACK_DECLARE,
			"payload": {"attacker_player": 0}},
		{"flow": Constants.InteractionFlow.NONE,
			"step": Constants.InteractionStep.NONE,
			"payload": {"active_player": 0}},
		{"flow": Constants.InteractionFlow.GAME_OVER,
			"step": Constants.InteractionStep.GAME_OVER_STEP,
			"payload": {"active_player": 0}},
	]
	for sample: Dictionary in samples:
		var flow: InteractionFlow = _decode_json_flow_direct(
				sample["flow"], sample["step"], "malformed")
		assert_not_null(flow)
		assert_eq(flow.payload, {})
		assert_not_null(_decode_json_flow_direct(
				sample["flow"], sample["step"], {}))
		var key: String = str((sample["payload"] as Dictionary).keys()[0])
		for invalid: Variant in [0.5, -1.5, INF, -INF, NAN,
				true, "0", null, [], {}]:
			var payload: Dictionary = (sample["payload"] as Dictionary).duplicate(true)
			payload[key] = invalid
			assert_null(_decode_json_flow_direct(
					sample["flow"], sample["step"], payload))
	for invalid: Variant in [0.5, INF, true, "0", null, {}]:
		assert_null(_decode_json_flow_direct(
				Constants.InteractionFlow.STATUS_CLEANUP,
				Constants.InteractionStep.STATUS_CLEANUP_STEP,
				{"ecm_ready_cost_choices": invalid}))
	assert_null(_decode_json_flow_direct(
			Constants.InteractionFlow.STATUS_CLEANUP,
			Constants.InteractionStep.STATUS_CLEANUP_STEP,
			{"ecm_ready_cost_choices": [{"owner_player": 0.5}]}))
	assert_null(_decode_json_flow_direct(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE, "malformed"))
	assert_null(_decode_json_flow_direct(Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE, {}))
	var displacement: InteractionFlow = _decode_json_flow_direct(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE, "malformed")
	assert_not_null(displacement)
	assert_eq(displacement.payload, {})
	assert_not_null(_decode_json_flow_direct(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE, {}))
	for bad: Variant in [0.5, INF, -INF, NAN, "0", true, null]:
		assert_null(_decode_json_flow_direct(
				Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
				Constants.InteractionStep.DISPLACEMENT_PLACE, {
					"owner_player": bad, "ship_index": 0,
					"displaced_squadrons": []}))
	assert_not_null(_decode_json_flow_direct(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE, {
				"owner_player": 2147483648, "ship_index": -2147483648,
				"displaced_squadrons": []}))
	assert_null(_decode_json_flow_direct(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE, {
				"owner_player": 2147483648.0, "ship_index": 0,
				"displaced_squadrons": []}))
	assert_null(_decode_json_flow_direct(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE, {
				"owner_player": 0, "ship_index": 0,
				"displaced_squadrons": [{}]}))
	assert_null(_decode_json_flow_direct(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE, {
				"owner_player": 0, "ship_index": 0,
				"displaced_squadrons": [0]}))


func test_declared_structured_fields_reject_malformed_values() -> void:
	var attack_flow: Constants.InteractionFlow = Constants.InteractionFlow.ATTACK
	var attack_step: Constants.InteractionStep = \
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS
	for key: String in ["locked_tokens", "blocked_defense_token_indices",
			"ecm_authorized_indices", "redirect_adjacent_zones",
			"spent_defense_token_types", "swarm_die_indices"]:
		assert_null(_decode_json_flow_direct(attack_flow, attack_step,
				_payload_with(key, [0.5])), key)
		assert_null(_decode_json_flow_direct(attack_flow, attack_step,
				_payload_with(key, {})), key)
	for key: String in ["dice_pool", "counter_dice_pool"]:
		assert_null(_decode_json_flow_direct(attack_flow, attack_step,
				_payload_with(key, {"red": INF})), key)
		assert_null(_decode_json_flow_direct(attack_flow, attack_step,
				_payload_with(key, [])), key)
	for key: String in ["dice_results", "defense_tokens"]:
		assert_null(_decode_json_flow_direct(attack_flow, attack_step,
				_payload_with(key, [0])), key)
		assert_null(_decode_json_flow_direct(attack_flow, attack_step,
				_payload_with(key, {})), key)
	for key: String in ["ecm_choice", "pending_die_removal",
			"choice_info"]:
		assert_null(_decode_json_flow_direct(attack_flow, attack_step,
				_payload_with(key, [])), key)
		assert_not_null(_decode_json_flow_direct(attack_flow, attack_step,
				_payload_with(key, {})), key)
	assert_null(_decode_json_flow_direct(attack_flow, attack_step,
			{"ecm_choice": {"defender_player": 2}}))
	assert_null(_decode_json_flow_direct(attack_flow, attack_step,
			{"ecm_choice": {"eligible_token_indices": [NAN]}}))
	assert_null(_decode_json_flow_direct(attack_flow, attack_step,
			{"choice_info": {"max_selections": -1}}))
	assert_null(_decode_json_flow_direct(attack_flow, attack_step,
			{"pending_die_removal": {"controller_player": "1"}}))
	assert_null(_decode_json_flow_direct(attack_flow, attack_step,
			{"attacker_player": 2}))
	assert_null(_decode_json_flow_direct(attack_flow, attack_step,
			{"attacker_ship_index": 2147483648}))
	assert_null(_decode_json_flow_direct(attack_flow, attack_step,
			{"dice_pool": {"red": 9007199254740992.0}}))
	assert_null(_decode_json_flow_direct(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.TARKIN_COMMAND_CHOICE,
			{"available_commands": [0.5]}))
	for step: int in [Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT,
			Constants.InteractionStep.SETUP_SQUADRON_DEPLOYMENT]:
		assert_null(_decode_json_flow_direct(Constants.InteractionFlow.SETUP,
				step as Constants.InteractionStep, {"deployment_pick": []}))
		assert_null(_decode_json_flow_direct(Constants.InteractionFlow.SETUP,
				step as Constants.InteractionStep,
				{"deployment_pick": {"owner_player": 2}}))
		assert_not_null(_decode_json_flow_direct(Constants.InteractionFlow.SETUP,
				step as Constants.InteractionStep,
				{"deployment_pick": {"component_type": "squadron",
					"roster_entry_ids": ["s1"]}}))
	var with_unknown: Dictionary = {"ship_index": 1,
		"unknown_number": 7.0, "unknown_label": "keep"}
	var restored: InteractionFlow = _decode_json_flow_direct(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP, with_unknown)
	assert_not_null(restored)
	assert_eq(typeof(restored.payload["ship_index"]), TYPE_INT)
	assert_eq(typeof(restored.payload["unknown_number"]), TYPE_FLOAT)
	assert_eq(restored.payload["unknown_label"], "keep")


func _payload_with(key: String, value: Variant) -> Dictionary:
	var result: Dictionary = {}
	result[key] = value
	return result


func test_game_state_json_reconstruction_converges_flow_and_digest() -> void:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	_attach_authority_damage_deck(state)
	var cases: Array[Dictionary] = [
		{"flow": Constants.InteractionFlow.SHIP_ACTIVATION,
			"step": Constants.InteractionStep.MANEUVER_STEP,
			"payload": {"ship_index": 0, "route": "maneuver"}},
		{"flow": Constants.InteractionFlow.SETUP,
			"step": Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT,
			"payload": {"first_player": 0, "controller_player": 0,
				"deployment_pick": {"owner_player": 0,
					"required_count": 2,
					"component_type": "squadron",
					"roster_entry_ids": ["s1"]}}},
		{"flow": Constants.InteractionFlow.STATUS_CLEANUP,
			"step": Constants.InteractionStep.STATUS_CLEANUP_STEP,
			"payload": {"ecm_ready_cost_choices": [{
				"owner_player": 0, "ship_index": 0}]}},
		{"flow": Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			"step": Constants.InteractionStep.DISPLACEMENT_PLACE,
			"payload": {"owner_player": 0, "ship_index": 0,
				"displaced_squadrons": [{
					"owner": 1, "squadron_index": 0}]}},
	]
	for case: Dictionary in cases:
		state.interaction_flow = InteractionFlow.make(case["flow"],
				case["step"], 0, Constants.Visibility.ALL,
				case["payload"])
		var live: Dictionary = state.serialize()
		var parsed: Dictionary = JSON.parse_string(
				JSON.stringify(live)) as Dictionary
		var restored: GameState = GameState.deserialize(parsed)
		assert_not_null(restored, str(case["step"]))
		if restored == null:
			continue
		assert_eq(restored.interaction_flow.serialize(),
				state.interaction_flow.serialize())
		assert_eq(CanonicalJson.hash(
				restored.interaction_flow.serialize()),
				CanonicalJson.hash(state.interaction_flow.serialize()))
		var live_intent: UIProjector.UIIntent = UIProjector.project(state, 0)
		var recovered_intent: UIProjector.UIIntent = UIProjector.project(
				restored, 0)
		assert_eq(recovered_intent.modal_kind, live_intent.modal_kind)
		assert_eq(recovered_intent.is_interactive,
				live_intent.is_interactive)
		assert_eq(recovered_intent.payload, live_intent.payload)
		var restored_data: Dictionary = restored.serialize()
		var other_live: Dictionary = live.duplicate(true)
		var other_restored: Dictionary = restored_data.duplicate(true)
		other_live.erase("interaction_flow")
		other_restored.erase("interaction_flow")
		assert_eq(other_restored, other_live,
				"Non-flow state must be stable before a whole-state hash claim.")
		if other_restored == other_live:
			assert_eq(CanonicalJson.hash(restored_data),
					CanonicalJson.hash(live))


func test_filtered_and_passive_reconstruction_restores_owner_route() \
		-> void:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	_attach_authority_damage_deck(state)
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			0, Constants.Visibility.OWNER, {"ship_index": 0,
				"route": "maneuver"})
	var authority: Dictionary = state.serialize()
	var owner_result: Dictionary = StateFilter.filter_for_player_checked(
			authority, 0)
	assert_true(bool(owner_result.get(StateFilter.KEY_OK, false)))
	if not bool(owner_result.get(StateFilter.KEY_OK, false)):
		return
	var owner_data: Dictionary = owner_result[StateFilter.KEY_STATE]
	var passive: GameState = GameState.deserialize_passive_network(
			owner_data)
	assert_not_null(passive)
	if passive == null:
		return
	assert_eq(typeof(passive.interaction_flow.payload["ship_index"]), TYPE_INT)
	assert_eq(passive.interaction_flow.serialize(),
			state.interaction_flow.serialize())
	var hidden_result: Dictionary = StateFilter.filter_for_player_checked(
			authority, 1)
	assert_true(bool(hidden_result.get(StateFilter.KEY_OK, false)))
	if bool(hidden_result.get(StateFilter.KEY_OK, false)):
		assert_eq(hidden_result[StateFilter.KEY_STATE] \
				["interaction_flow"]["payload"], {})


func _assert_json_flow_exact(flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep, payload: Dictionary) -> void:
	var live: InteractionFlow = InteractionFlow.make(
			flow_id, step_id, 0, Constants.Visibility.ALL, payload)
	var parsed: Dictionary = JSON.parse_string(
			JSON.stringify(live.serialize())) as Dictionary
	var restored: InteractionFlow = InteractionFlow.deserialize(parsed)
	assert_not_null(restored, "flow=%s step=%s" % [flow_id, step_id])
	if restored == null:
		return
	assert_eq(restored.serialize(), live.serialize())
	assert_eq(CanonicalJson.hash(restored.serialize()),
			CanonicalJson.hash(live.serialize()))


func _decode_json_flow_direct(flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep, payload: Variant) -> InteractionFlow:
	return InteractionFlow.deserialize({
		"flow_type": int(flow_id), "step_id": int(step_id),
		"controller_player": 0, "visible_to": int(Constants.Visibility.ALL),
		"payload": payload,
	})


# ---------------------------------------------------------------------------
# is_actor()
# ---------------------------------------------------------------------------

func test_is_actor_true_for_controller() -> void:
	var f: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			1)
	assert_true(f.is_actor(1), "Player 1 is the controller — should act.")


func test_is_actor_false_for_other_player() -> void:
	var f: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			1)
	assert_false(f.is_actor(0))


func test_is_actor_false_for_minus_one_default() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_false(f.is_actor(0))
	assert_false(f.is_actor(1))


# ---------------------------------------------------------------------------
# equals()
# ---------------------------------------------------------------------------

func test_equals_returns_false_for_null() -> void:
	var f: InteractionFlow = InteractionFlow.new()
	assert_false(f.equals(null))


func test_equals_detects_payload_difference() -> void:
	var a: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			0, Constants.Visibility.ALL, {"x": 1})
	var b: InteractionFlow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			0, Constants.Visibility.ALL, {"x": 2})
	assert_false(a.equals(b))


# ---------------------------------------------------------------------------
# GameState integration
# ---------------------------------------------------------------------------

func test_game_state_initialize_creates_default_flow() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	state.install_match_player_control_binding(MatchPlayerControlBinding.create_hot_seat_human())
	assert_not_null(state.interaction_flow,
			"GameState.initialize() must create an InteractionFlow.")
	assert_eq(state.interaction_flow.flow_type,
			Constants.InteractionFlow.NONE)


func test_game_state_round_trip_preserves_flow() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	state.install_match_player_control_binding(MatchPlayerControlBinding.create_hot_seat_human())
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.REVEAL_DIAL,
			0,
			Constants.Visibility.OWNER,
			{"ship_index": 1})
	var clone: GameState = GameState.deserialize(state.serialize())
	assert_true(clone.interaction_flow.equals(state.interaction_flow),
			"GameState round-trip must preserve interaction_flow.")


func test_game_state_deserialize_missing_flow_uses_default() -> void:
	var source := GameState.new()
	source.initialize()
	source.install_match_player_control_binding(MatchPlayerControlBinding.create_hot_seat_human())
	source.current_round = 1
	var data: Dictionary = source.serialize()
	data.erase("interaction_flow")
	var clone: GameState = GameState.deserialize(data)
	assert_not_null(clone)
	assert_not_null(clone.interaction_flow)
	assert_eq(clone.interaction_flow.flow_type,
			Constants.InteractionFlow.NONE)


# ---------------------------------------------------------------------------
# StateFilter integration
# ---------------------------------------------------------------------------

func _attach_authority_damage_deck(state: GameState) -> void:
	var deck := DamageDeck.new()
	deck.set_rng(state.rng)
	deck.initialize()
	state.damage_deck = deck

func test_state_filter_strips_owner_payload_from_non_controller() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	state.install_match_player_control_binding(MatchPlayerControlBinding.create_hot_seat_human())
	_attach_authority_damage_deck(state)
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.COMMAND_PHASE,
			Constants.InteractionStep.SELECT_DIALS,
			1,
			Constants.Visibility.OWNER,
			{"secret_canary": "hidden_data"})
	var filtered: Dictionary = StateFilter.filter_for_player(
			state.serialize(), 0) # Player 0 is NOT the controller
	var flow_data: Dictionary = filtered.get("interaction_flow", {})
	var payload: Dictionary = flow_data.get("payload", {})
	assert_false(payload.has("secret_canary"),
			"OWNER payload must be stripped from non-controller view.")
	# Public fields still present
	assert_eq(int(flow_data.get("flow_type", -1)),
			int(Constants.InteractionFlow.COMMAND_PHASE))
	assert_eq(int(flow_data.get("controller_player", -1)), 1)


func test_state_filter_keeps_owner_payload_for_controller() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	state.install_match_player_control_binding(MatchPlayerControlBinding.create_hot_seat_human())
	_attach_authority_damage_deck(state)
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.COMMAND_PHASE,
			Constants.InteractionStep.SELECT_DIALS,
			1,
			Constants.Visibility.OWNER,
			{"secret_canary": "hidden_data"})
	var filtered: Dictionary = StateFilter.filter_for_player(
			state.serialize(), 1) # Player 1 IS the controller
	var payload: Dictionary = (filtered["interaction_flow"]
			as Dictionary)["payload"]
	assert_eq(payload.get("secret_canary", ""), "hidden_data",
			"Controller must still see their own OWNER payload.")


func test_state_filter_keeps_all_visibility_payload() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	state.install_match_player_control_binding(MatchPlayerControlBinding.create_hot_seat_human())
	_attach_authority_damage_deck(state)
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.COMMAND_PHASE,
			Constants.InteractionStep.SELECT_DIALS,
			-1,
			Constants.Visibility.ALL,
			{"public_data": 42})
	var filtered_p0: Dictionary = StateFilter.filter_for_player(
			state.serialize(), 0)
	var filtered_p1: Dictionary = StateFilter.filter_for_player(
			state.serialize(), 1)
	for filtered in [filtered_p0, filtered_p1]:
		var p: Dictionary = (filtered["interaction_flow"]
				as Dictionary).get("payload", {})
		assert_eq(p.get("public_data", -1), 42,
				"ALL payload must always pass through filter.")


# ---------------------------------------------------------------------------
# Legacy maps (used by I2 invariant test)
# ---------------------------------------------------------------------------

func test_legacy_flow_type_map_is_complete() -> void:
	var values: Array = Constants.LEGACY_FLOW_TYPE_MAP.values()
	# Every InteractionFlow value (except duplicates) should be reachable.
	var expected: Array = [
		Constants.InteractionFlow.NONE,
		Constants.InteractionFlow.COMMAND_PHASE,
		Constants.InteractionFlow.SHIP_ACTIVATION,
		Constants.InteractionFlow.SQUADRON_ACTIVATION,
		Constants.InteractionFlow.ATTACK,
		Constants.InteractionFlow.STATUS_CLEANUP,
		Constants.InteractionFlow.GAME_OVER,
	]
	for v in expected:
		assert_true(values.has(v),
				"LEGACY_FLOW_TYPE_MAP missing flow %d" % v)


func test_legacy_step_id_map_round_trip() -> void:
	# Each step value in the map must round-trip through the enum.
	for key in Constants.LEGACY_STEP_ID_MAP.keys():
		var step_value: int = int(Constants.LEGACY_STEP_ID_MAP[key])
		assert_true(step_value >= 0,
				"Step id %s must map to non-negative enum int." % key)
