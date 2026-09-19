extends GutTest


const AUTHORITY: GDScript = preload(
		"res://src/core/movement/maneuver_authority.gd")


var _state: GameState
var _moving: ShipInstance


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	_moving = _add_ship(0, Vector2(0.5, 0.75), 1)
	assert_true(_moving.establish_ship_activation("ship-activation:1"))
	assert_true(_moving.open_maneuver_opportunity("ship-activation:1"))


func test_speed_zero_is_a_full_authority_result_without_translation() -> void:
	_reveal_navigate_dial(_moving)
	var result: Dictionary = AUTHORITY.derive(
			_state, 0, 0, 0, [], -1)
	assert_true(bool(result.get("ok", false)))
	assert_almost_eq(float(result["pos_x"]), 0.5, 0.00001)
	assert_almost_eq(float(result["pos_y"]), 0.75, 0.00001)
	assert_almost_eq(float(result["rotation_deg"]), 0.0, 0.00001)
	assert_eq(int(result["temporary_final_speed"]), 0)
	assert_eq(result["ship_collision"], {"kind": "none"})


func test_course_validation_rejects_bad_shape_and_unfunded_yaw() -> void:
	assert_ne(AUTHORITY.validate_course_intent(
			_state, 0, 0, 1, [], -1), "")
	assert_ne(AUTHORITY.validate_course_intent(
			_state, 0, 0, 1, [2], -1), "")
	assert_ne(AUTHORITY.validate_course_intent(
			_state, 0, 0, 1, [2], 0), "")


func test_navigate_source_derivation_prefers_revealed_dial() -> void:
	_reveal_navigate_dial(_moving)
	var sources: Dictionary = AUTHORITY.derive_navigate_sources(
			_moving, 2, -1)
	assert_true(bool(sources["ok"]))
	assert_true(bool(sources["navigate_dial_spent"]))
	assert_false(bool(sources["navigate_token_spent"]))
	assert_true(bool(sources["navigate_speed_changed"]))


func test_two_speed_change_requires_dial_and_token() -> void:
	_reveal_navigate_dial(_moving)
	assert_true(_moving.command_tokens.add_token(
			Constants.CommandType.NAVIGATE))
	var sources: Dictionary = AUTHORITY.derive_navigate_sources(
			_moving, 3, -1)
	assert_true(bool(sources["ok"]))
	assert_true(bool(sources["navigate_dial_spent"]))
	assert_true(bool(sources["navigate_token_spent"]))


func test_unchanged_speed_and_course_spends_no_navigate_source() -> void:
	_reveal_navigate_dial(_moving)
	assert_true(_moving.command_tokens.add_token(
			Constants.CommandType.NAVIGATE))
	var sources: Dictionary = AUTHORITY.derive_navigate_sources(
			_moving, 1, -1)
	assert_true(bool(sources["ok"]))
	assert_false(bool(sources["navigate_dial_spent"]))
	assert_false(bool(sources["navigate_token_spent"]))
	assert_false(bool(sources["navigate_speed_changed"]))


func test_collision_records_closest_attempted_ship_and_reduces_only_result() -> void:
	var unobstructed: Dictionary = AUTHORITY.derive(
			_state, 0, 0, 1, [0], -1)
	assert_true(bool(unobstructed["ok"]))
	var attempted: Transform2D = unobstructed["attempted_transform"]
	_add_ship(1, attempted.origin / GameScale.play_area_size_px, 0)
	var collided: Dictionary = AUTHORITY.derive(
			_state, 0, 0, 1, [0], -1)
	assert_true(bool(collided["ok"]))
	assert_eq(collided["ship_collision"], {
		"kind": "closest_ship",
		"target_owner_player": 1,
		"target_ship_index": 0,
	})
	assert_lt(int(collided["temporary_final_speed"]), 1)
	assert_eq(_moving.current_speed, 1,
			"Pure temporary reduction cannot mutate canonical speed.")


func test_actual_final_play_area_check_ignores_superseded_attempt() -> void:
	_moving.pos_y = 0.08
	var result: Dictionary = AUTHORITY.derive(
			_state, 0, 0, 1, [0], -1)
	assert_true(bool(result["ok"]))
	assert_true(bool(result["outside_play_area"]))


func test_affected_squadron_identities_are_stable_owner_index_values() -> void:
	_reveal_navigate_dial(_moving)
	var result: Dictionary = AUTHORITY.derive(
			_state, 0, 0, 0, [], -1)
	var final_transform: Transform2D = result["final_transform"]
	_add_squadron(1, final_transform.origin / GameScale.play_area_size_px)
	result = AUTHORITY.derive(_state, 0, 0, 0, [], -1)
	assert_eq(result["affected_squadrons"], [
		{"owner": 1, "squadron_index": 0},
	])


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 5
	data.max_speed = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data


func _add_ship(owner: int, position: Vector2, speed: int) -> ShipInstance:
	var ship := ShipInstance.create_from_data(
			"authority_ship", _ship_data(), speed, owner)
	ship.pos_x = position.x
	ship.pos_y = position.y
	_state.get_player_state(owner).ships.append(ship)
	return ship


func _add_squadron(owner: int, position: Vector2) -> SquadronInstance:
	var data := SquadronData.new()
	data.hull = 3
	var squadron := SquadronInstance.create_from_data(
			"authority_squadron", data, owner)
	squadron.pos_x = position.x
	squadron.pos_y = position.y
	_state.get_player_state(owner).squadrons.append(squadron)
	return squadron


func _reveal_navigate_dial(ship: ShipInstance) -> void:
	assert_true(ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1))
	assert_false(ship.command_dial_stack.reveal_top().is_empty())
