## Boundary C: declared current-attack outcome integers after JSON decoding.
extends GutTest


const ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")
const SQUADRON_KEYS: Array[String] = [
	"requested_hull_damage", "actual_hull_damage", "post_resolution_hull",
]
const SHIP_KEYS: Array[String] = [
	"affected_zone", "final_damage", "shield_absorbed",
	"post_resolution_shields", "hull_damage",
]
const INT64_MAX: int = 9223372036854775807
const INT64_MIN: int = -9223372036854775807 - 1


func test_production_squadron_zero_ordinary_and_excess_json_roundtrips() -> void:
	for damage: int in [0, 2, 7]:
		var state: GameState = _resolved_by_command("squadron", damage)
		assert_not_null(state)
		if state == null:
			continue
		var outcome: Dictionary = state.current_attack_state.resolved_outcome
		assert_eq(outcome["requested_hull_damage"], damage)
		assert_eq(outcome["actual_hull_damage"], mini(damage, 5))
		assert_eq(outcome["post_resolution_hull"], 5 - mini(damage, 5))
		_assert_json_state_converges(state, SQUADRON_KEYS)


func test_production_ship_shield_and_hull_damage_json_roundtrips() -> void:
	for damage: int in [2, 4]:
		var state: GameState = _resolved_by_command("ship", damage)
		assert_not_null(state)
		if state != null:
			_assert_json_state_converges(state, SHIP_KEYS)


func test_all_declared_outcome_keys_have_safe_signed_64_bit_policy() -> void:
	for kind: String in ["squadron", "ship"]:
		var base: Dictionary = _resolved_fixture(kind).current_attack_state.serialize()
		var keys: Array[String] = SQUADRON_KEYS if kind == "squadron" \
				else SHIP_KEYS
		for key: String in keys:
			for native: int in [INT64_MIN, INT64_MAX]:
				_assert_outcome_value(base, key, native, true, native)
			for accepted_float: float in [
					-9223372036854775808.0,
					-9223372036854774784.0,
					9223372036854774784.0,
				]:
				_assert_outcome_value(base, key, accepted_float, true,
						int(accepted_float))
			for rejected: Variant in [
					-9223372036854777856.0,
					9223372036854775808.0,
					float(INT64_MAX), 1e20, -1e20,
					1.5, INF, -INF, NAN, true, "2", null, [], {},
				]:
				_assert_outcome_value(base, key, rejected, false, 0)


func test_absent_keys_and_unrelated_outcome_members_are_preserved() -> void:
	var original: Dictionary = _resolved_fixture(
			"squadron").current_attack_state.serialize()
	var outcome: Dictionary = original["resolved_outcome"]
	outcome.erase("requested_hull_damage")
	outcome["unrelated"] = {"text": "7", "flag": true,
		"mixed": [2.5, "value"]}
	var restored := CurrentAttackState.new()
	assert_true(restored.load_from_serialized(original))
	assert_false(restored.resolved_outcome.has("requested_hull_damage"))
	assert_eq(restored.resolved_outcome["unrelated"], outcome["unrelated"])
	var unresolved := CurrentAttackState.new()
	assert_true(unresolved.load_from_serialized(
			CurrentAttackState.new().serialize()))
	assert_true(unresolved.resolved_outcome.is_empty())


func test_malformed_outcome_rejects_atomic_attack_and_game_state_install() -> void:
	var state: GameState = _resolved_fixture("squadron")
	var before: Dictionary = state.serialize()
	var attack: CurrentAttackState = state.current_attack_state
	var attack_hash: String = CanonicalJson.hash(attack.serialize())
	var malformed: Dictionary = attack.serialize()
	malformed["resolved_outcome"]["requested_hull_damage"] = 1e20
	assert_false(attack.load_from_serialized(malformed))
	assert_eq(CanonicalJson.hash(attack.serialize()), attack_hash)
	assert_eq(state.serialize(), before)
	var game_data: Dictionary = before.duplicate(true)
	game_data["current_attack_state"]["resolved_outcome"][
			"requested_hull_damage"] = 1e20
	assert_null(GameState.deserialize(game_data))
	assert_eq(state.serialize(), before)


func test_network_filter_rejects_malformed_outcome_without_snapshot() -> void:
	for viewer: int in [0, 1]:
		for kind: String in ["squadron", "ship"]:
			var state: GameState = _resolved_fixture(kind)
			var source: Dictionary = state.serialize()
			var good: Dictionary = StateFilter.filter_for_player_checked(
					source, viewer)
			assert_true(good.get(StateFilter.KEY_OK, false))
			var keys: Array[String] = SQUADRON_KEYS if kind == "squadron" \
					else SHIP_KEYS
			for key: String in keys:
				for invalid: Variant in ["2", 1.5, INF,
						9223372036854775808.0, 1e20]:
					var malformed: Dictionary = source.duplicate(true)
					malformed["current_attack_state"]["resolved_outcome"][
							key] = invalid
					var result: Dictionary = StateFilter.filter_for_player_checked(
							malformed, viewer)
					assert_false(result.get(StateFilter.KEY_OK, true))
					assert_true((result.get(StateFilter.KEY_STATE, {}) as Dictionary)
							.is_empty())
					assert_eq(state.serialize(), source)


func test_passive_snapshot_rejects_malformed_outcome_without_install() -> void:
	for viewer: int in [0, 1]:
		for kind: String in ["squadron", "ship"]:
			var state: GameState = _resolved_fixture(kind)
			var filtered: Dictionary = StateFilter.filter_for_player_checked(
					state.serialize(), viewer)
			assert_true(filtered.get(StateFilter.KEY_OK, false))
			if not filtered.get(StateFilter.KEY_OK, false):
				continue
			var passive: Dictionary = filtered[StateFilter.KEY_STATE]
			assert_not_null(GameState.deserialize_passive_network(passive))
			var keys: Array[String] = SQUADRON_KEYS if kind == "squadron" \
					else SHIP_KEYS
			for key: String in keys:
				for invalid: Variant in ["2", 1.5, INF,
						9223372036854775808.0, 1e20]:
					var malformed: Dictionary = passive.duplicate(true)
					malformed["current_attack_state"]["resolved_outcome"][
							key] = invalid
					assert_null(GameState.deserialize_passive_network(malformed))
					assert_eq(filtered[StateFilter.KEY_STATE], passive)


func test_negative_snapshot_acknowledgement_aborts_reconnect_staging() -> void:
	var previous_role: NetworkManager.Role = NetworkManager.role
	var previous_attempt: Dictionary = NetworkManager._resume_attempt.duplicate(true)
	var previous_admission: bool = \
			NetworkManager._principal_command_admission_enabled
	var previous_state: GameState = GameManager.current_game_state
	var attempt_id: String = "a".repeat(64)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._resume_attempt = {
		"operation": "reconnect", "phase": "STAGING_SNAPSHOT",
		"attempt_id": attempt_id, "expected_endpoints": [0],
		"cursor": 1, "ready": {},
	}
	NetworkManager._principal_command_admission_enabled = false
	NetworkManager._acknowledge_resume_snapshot(attempt_id, false, -1)
	assert_true(NetworkManager._resume_attempt.is_empty())
	assert_true(NetworkManager._principal_command_admission_enabled)
	assert_same(GameManager.current_game_state, previous_state)
	NetworkManager.role = previous_role
	NetworkManager._resume_attempt = previous_attempt
	NetworkManager._principal_command_admission_enabled = previous_admission


func _resolved_by_command(kind: String, damage: int) -> GameState:
	var state: GameState = _new_state()
	var dice: Array[Dictionary] = []
	for index: int in range(damage):
		dice.append({"color": int(Constants.DiceColor.RED),
			"face": int(Constants.DiceFace.HIT)})
	var attack: CurrentAttackState = ATTACK_FIXTURE.install(state, {
		"stage": CurrentAttackState.STAGE_DEFENSE,
		"defender_kind": kind,
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
		"dice_results": dice,
	})
	if attack == null:
		return null
	var payload: Dictionary = {"attack_id": attack.attack_id,
		"target_type": kind, "owner_player": 1, "target_destroyed": false}
	if kind == "squadron":
		payload["squadron_index"] = 0
		payload["hull_damage"] = damage
	else:
		payload["ship_index"] = 0
		payload["hull_zone"] = "FRONT"
		payload["shield_damage"] = mini(damage, 2)
		payload["damage_cards"] = []
	var command: ResolveDamageCommand = CandidateResolveDamageCommand.new(
			0, {"attack_id": attack.attack_id}) if kind == "ship" and damage > 2 \
			else ResolveDamageCommand.new(0, payload)
	if not command.validate(state).is_empty() or command.execute(state).is_empty():
		return null
	return state


func _resolved_fixture(kind: String) -> GameState:
	var state: GameState = _new_state()
	var attack: CurrentAttackState = ATTACK_FIXTURE.install(state, {
		"stage": CurrentAttackState.STAGE_RESOLVED,
		"defender_kind": kind,
	})
	assert_not_null(attack)
	return state


func _new_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.damage_deck = DamageDeck.new()
	state.damage_deck.set_rng(state.rng)
	state.damage_deck.initialize()
	return state


func _assert_json_state_converges(state: GameState,
		keys: Array[String]) -> void:
	var before: Dictionary = state.serialize()
	var decoded: Variant = JSON.parse_string(JSON.stringify(before))
	var restored: GameState = GameState.deserialize(decoded)
	assert_not_null(restored)
	if restored == null:
		return
	var after: Dictionary = restored.serialize()
	for key: String in keys:
		assert_eq(typeof(after["current_attack_state"]["resolved_outcome"][key]),
				TYPE_INT)
		assert_eq(after["current_attack_state"]["resolved_outcome"][key],
				before["current_attack_state"]["resolved_outcome"][key])
	assert_eq(after["current_attack_state"], before["current_attack_state"])
	assert_eq(CanonicalJson.hash(after["current_attack_state"]),
			CanonicalJson.hash(before["current_attack_state"]))
	assert_eq(after, before)
	assert_eq(CanonicalJson.hash(after), CanonicalJson.hash(before))


func _assert_outcome_value(base: Dictionary, key: String, value: Variant,
		accepted: bool, expected: int) -> void:
	var candidate: Dictionary = base.duplicate(true)
	candidate["resolved_outcome"][key] = value
	var attack := CurrentAttackState.new()
	assert_eq(attack.load_from_serialized(candidate), accepted,
			"%s: %s" % [key, str(value)])
	if accepted:
		assert_eq(typeof(attack.resolved_outcome[key]), TYPE_INT)
		assert_eq(attack.resolved_outcome[key], expected)
