## Slice 8A evidence for the canonical current-attack value boundary.
extends GutTest


const CurrentAttackFixture: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")


func test_inactive_state_has_one_canonical_json_safe_shape() -> void:
	var state := CurrentAttackState.new()
	assert_true(state.is_inactive())
	assert_true(state.is_valid())
	var restored := CurrentAttackState.new()
	assert_true(restored.load_from_serialized(
			JSON.parse_string(JSON.stringify(state.serialize()))))
	assert_eq(restored.serialize(), state.serialize(),
			"Inactive state must round-trip through JSON.")


func test_active_state_round_trips_without_aliasing_input() -> void:
	var values: Dictionary = _active_values()
	var state := CurrentAttackState.new()
	assert_true(state.configure_active("attack:17", values))
	values["dice_pool"]["RED"] = 99
	assert_eq(state.dice_pool, {"RED": 2},
			"Runtime input must not remain aliased to authoritative state.")
	var restored := CurrentAttackState.new()
	assert_true(restored.load_from_serialized(
			JSON.parse_string(JSON.stringify(state.serialize()))))
	assert_eq(restored.serialize(), state.serialize())


func test_composite_getters_cannot_mutate_authoritative_state() -> void:
	var state := CurrentAttackState.new()
	assert_true(state.configure_active("attack:18", _active_values()))
	var pool: Dictionary = state.dice_pool
	pool["RED"] = 0
	var serialized: Dictionary = state.serialize()
	serialized["dice_pool"]["RED"] = 0
	assert_eq(state.dice_pool, {"RED": 2})


func test_patch_returns_valid_replacement_without_mutating_original() -> void:
	var state := CurrentAttackState.new()
	assert_true(state.configure_active("attack:19", _active_values()))
	var replacement: CurrentAttackState = state.with_patch({
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
		"dice_results": _one_red_hit(),
	})
	assert_not_null(replacement)
	assert_eq(state.stage, CurrentAttackState.STAGE_PRE_ROLL)
	assert_true(state.dice_results.is_empty())
	assert_eq(replacement.stage, CurrentAttackState.STAGE_ATTACK_MODIFY)


func test_invalid_identity_controller_and_json_shape_reject() -> void:
	var state := CurrentAttackState.new()
	assert_false(state.configure_active("synthetic-id", _active_values()))
	var invalid_player: Dictionary = _active_values()
	invalid_player["attacker_player"] = 7
	assert_false(state.configure_active("attack:20", invalid_player))
	var serialized: Dictionary = _serialized_active("attack:20")
	serialized["projection"] = {"modal": true}
	assert_false(state.load_from_serialized(serialized),
			"Open-ended presentation data must not enter canonical state.")


func test_non_finite_and_semantically_invalid_state_reject() -> void:
	var state := CurrentAttackState.new()
	var non_finite: Dictionary = _serialized_active("attack:21")
	non_finite["attacker_index"] = INF
	assert_false(state.load_from_serialized(non_finite))
	var invalid_stage: Dictionary = _serialized_active("attack:21")
	invalid_stage["stage"] = CurrentAttackState.STAGE_ATTACK_MODIFY
	assert_false(state.load_from_serialized(invalid_stage),
			"Attack Modify cannot exist without canonical dice.")
	var empty_pool: Dictionary = _serialized_active("attack:21")
	empty_pool["dice_pool"] = {}
	assert_false(state.load_from_serialized(empty_pool),
			"An active attack must retain a non-empty committed dice pool.")
	var duplicate_effects: Dictionary = _serialized_active("attack:21")
	duplicate_effects["stage"] = CurrentAttackState.STAGE_DEFENSE
	duplicate_effects["dice_results"] = _one_red_hit()
	duplicate_effects["accuracy_complete"] = true
	duplicate_effects["defense_stage"] = CurrentAttackState.DEFENSE_RESOLVING
	duplicate_effects["committed_defense_tokens"] = [0]
	duplicate_effects["resolved_defense_effects"] = [
		{"token_index": 0, "token_type": int(Constants.DefenseToken.EVADE)},
		{"token_index": 0, "token_type": int(Constants.DefenseToken.EVADE)},
	]
	assert_false(state.load_from_serialized(duplicate_effects),
			"One defense-token reference cannot resolve twice.")
	var unowned_damage_stage: Dictionary = _serialized_active("attack:21")
	unowned_damage_stage["stage"] = CurrentAttackState.STAGE_DAMAGE
	unowned_damage_stage["dice_results"] = _one_red_hit()
	unowned_damage_stage["accuracy_complete"] = true
	assert_false(state.load_from_serialized(unowned_damage_stage),
			"No accepted command owns a persistable STAGE_DAMAGE transition.")


func test_game_state_installs_a_clone_and_rejects_missing_entities() -> void:
	var game_state: GameState = _game_state()
	var installed: CurrentAttackState = CurrentAttackFixture.install(game_state, {
		"attack_id": "attack:22",
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
	})
	assert_not_null(installed)
	var public_copy: CurrentAttackState = game_state.current_attack_state
	assert_true(public_copy.configure_active("attack:23", _active_values()))
	assert_eq(game_state.current_attack_state.attack_id, "attack:22",
			"Replacing a public copy must not replace GameState authority.")
	var missing_reference := CurrentAttackState.new()
	var values: Dictionary = _active_values()
	values["attacker_index"] = 99
	assert_true(missing_reference.configure_active("attack:24", values))
	assert_false(game_state.set_current_attack_state(missing_reference))


func test_game_state_rejects_invalid_cross_owner_attack_references() -> void:
	var game_state: GameState = _game_state()
	var installed: CurrentAttackState = CurrentAttackFixture.install(game_state, {
		"attack_id": "attack:25",
		"stage": CurrentAttackState.STAGE_DEFENSE,
	})
	assert_not_null(installed)
	var base: Dictionary = game_state.serialize()

	var invalid_lock: Dictionary = base.duplicate(true)
	invalid_lock["current_attack_state"]["accuracy_locked_tokens"] = [999]
	assert_null(GameState.deserialize(invalid_lock),
			"Accuracy locks must reference the canonical defender token list.")

	var invalid_effect: Dictionary = base.duplicate(true)
	invalid_effect["current_attack_state"]["defense_stage"] = \
			CurrentAttackState.DEFENSE_RESOLVING
	invalid_effect["current_attack_state"]["committed_defense_tokens"] = [0]
	var actual_type: int = int(game_state.get_ship(1, 0).defense_tokens[0].get(
			"type", -1))
	invalid_effect["current_attack_state"]["resolved_defense_effects"] = [{
		"token_index": 0,
		"token_type": (actual_type + 1) % (int(Constants.DefenseToken.SALVO) + 1),
	}]
	assert_null(GameState.deserialize(invalid_effect),
			"Resolved effects must match the referenced authoritative token.")

	var invalid_evade: Dictionary = base.duplicate(true)
	invalid_evade["current_attack_state"]["defense_stage"] = \
			CurrentAttackState.DEFENSE_RESOLVING
	invalid_evade["current_attack_state"]["pending_evade"] = {
		"die_index": 0,
		"expected_color": int(Constants.DiceColor.BLUE),
		"expected_face": int(Constants.DiceFace.HIT),
	}
	assert_null(GameState.deserialize(invalid_evade),
			"Pending Evade must match the canonical die source record.")


func test_missing_legacy_state_reconstructs_only_without_active_attack_flow() -> void:
	var game_state: GameState = _game_state()
	var legacy: Dictionary = game_state.serialize()
	legacy.erase("current_attack_state")
	var restored: GameState = GameState.deserialize(legacy)
	assert_not_null(restored)
	assert_true(restored.current_attack_state.is_inactive())
	legacy["interaction_flow"] = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY, 0).serialize()
	assert_null(GameState.deserialize(legacy),
			"Legacy attack flow cannot reconstruct missing attack authority.")


func _game_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	return state


func _active_values() -> Dictionary:
	return {
		"attacker_player": 0,
		"attacker_kind": CurrentAttackState.KIND_SHIP,
		"attacker_index": 0,
		"attacker_zone": int(Constants.HullZone.FRONT),
		"defender_player": 1,
		"defender_kind": CurrentAttackState.KIND_SHIP,
		"defender_index": 0,
		"defender_zone": int(Constants.HullZone.FRONT),
		"attack_kind": "standard",
		"range_band": Constants.RANGE_BAND_CLOSE,
		"obstructed": false,
		"obstruction_resolved": true,
		"dice_pool": {"RED": 2},
		"cf_dial_resolution": CurrentAttackState.RESOLUTION_UNAVAILABLE,
		"cf_token_resolution": CurrentAttackState.RESOLUTION_UNAVAILABLE,
	}


func _serialized_active(attack_id: String) -> Dictionary:
	var state := CurrentAttackState.new()
	assert_true(state.configure_active(attack_id, _active_values()))
	return state.serialize()


func _one_red_hit() -> Array[Dictionary]:
	return [{"color": int(Constants.DiceColor.RED),
		"face": int(Constants.DiceFace.HIT)}]
