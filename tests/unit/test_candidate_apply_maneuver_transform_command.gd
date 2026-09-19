extends GutTest


const EXECUTE: GDScript = preload(
		"res://src/core/commands/candidate_execute_maneuver_command.gd")
const APPLY: GDScript = preload(
		"res://src/core/commands/candidate_apply_maneuver_transform_command.gd")

var _state: GameState
var _ship: ShipInstance


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	_ship = ShipInstance.create_from_data("candidate", _ship_data(), 1, 0)
	_ship.pos_x = 0.5
	_ship.pos_y = 0.75
	_state.get_player_state(0).ships.append(_ship)
	assert_true(_ship.establish_ship_activation("ship-activation:10"))
	assert_true(_ship.open_maneuver_opportunity("ship-activation:10"))
	var commit: GameCommand = EXECUTE.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:10",
		"speed": 1,
		"yaw_clicks": [0],
		"yaw_bonus_joint": -1,
	})
	commit.sequence = 10
	assert_false(commit.execute(_state).is_empty())


func test_applies_committed_transform_atomically_once() -> void:
	var before := Vector2(_ship.pos_x, _ship.pos_y)
	var committed: Dictionary = _ship.active_maneuver_execution_snapshot()[
			"committed_result"]
	var command: GameCommand = _command()
	assert_eq(command.validate(_state), "")
	var result: Dictionary = command.execute(_state)
	assert_false(result.is_empty())
	assert_ne(Vector2(_ship.pos_x, _ship.pos_y), before)
	assert_eq(_ship.pos_x, committed["pos_x"])
	assert_eq(_ship.pos_y, committed["pos_y"])
	var execution: Dictionary = _ship.active_maneuver_execution_snapshot()
	assert_true(bool(execution["final_transform_applied"]))
	assert_false(execution.has("committed_result"))
	assert_ne(_command().validate(_state), "")


func test_active_pre_movement_obligation_blocks_application() -> void:
	var card := DamageCard.new()
	card.physical_card_id = "damage:0"
	card.public_card_ref = "faceup:1:0"
	card.effect_id = "structural_damage"
	card.timing = "immediate"
	card.is_faceup = true
	_ship.add_faceup_damage(card)
	assert_true(_ship.establish_immediate_resolution({
		"immediate_resolution_id": "immediate:faceup:1:0",
		"public_card_ref": "faceup:1:0",
		"physical_card_id": "damage:0",
		"effect_id": "structural_damage",
		"actor_player": -1,
		"exact_once_key": "immediate:debug:debug:1:damage:0",
		"enclosing_kind": "debug",
		"debug_application_id": "debug:1",
	}))
	var before := Vector2(_ship.pos_x, _ship.pos_y)
	assert_ne(_command().validate(_state), "")
	assert_eq(_command().execute(_state), {})
	assert_eq(Vector2(_ship.pos_x, _ship.pos_y), before)


func test_destruction_before_application_suppresses_transform() -> void:
	var before := Vector2(_ship.pos_x, _ship.pos_y)
	_ship.mark_destroyed()
	assert_eq(_command().execute(_state), {})
	assert_eq(Vector2(_ship.pos_x, _ship.pos_y), before)
	assert_false(_ship.has_active_maneuver_execution())


func test_applied_out_of_play_result_is_retained_then_terminates_execution() -> void:
	# Rebuild a speed-zero execution whose actual base is outside play.
	_ship.mark_destroyed()
	_ship = ShipInstance.create_from_data("candidate", _ship_data(), 0, 0)
	_ship.pos_x = 0.001
	_ship.pos_y = 0.001
	_state.get_player_state(0).ships[0] = _ship
	assert_true(_ship.establish_ship_activation("ship-activation:10"))
	assert_true(_ship.open_maneuver_opportunity("ship-activation:10"))
	var commit: GameCommand = EXECUTE.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:10",
		"speed": 0,
		"yaw_clicks": [],
		"yaw_bonus_joint": -1,
	})
	commit.sequence = 10
	assert_false(commit.execute(_state).is_empty())
	var result: Dictionary = _command().execute(_state)
	assert_false(result.is_empty())
	assert_true(_ship.is_destroyed())
	assert_false(_ship.has_active_maneuver_execution())
	assert_almost_eq(_ship.pos_x, 0.001, 0.00001)


func test_contract_2_application_accepts_only_recorded_committed_transform() -> void:
	var mirror := GameState.new()
	mirror.initialize()
	mirror.current_phase = Constants.GamePhase.SHIP
	var mirror_ship := ShipInstance.create_from_data(
			"candidate", _ship_data(), 1, 0)
	mirror_ship.pos_x = 0.5
	mirror_ship.pos_y = 0.75
	mirror.get_player_state(0).ships.append(mirror_ship)
	assert_true(mirror_ship.establish_ship_activation("ship-activation:10"))
	assert_true(mirror_ship.open_maneuver_opportunity("ship-activation:10"))
	var commit: GameCommand = EXECUTE.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:10",
		"speed": 1,
		"yaw_clicks": [0],
		"yaw_bonus_joint": -1,
	})
	commit.sequence = 10
	assert_false(commit.execute(mirror).is_empty())
	var authority: GameCommand = _command()
	var result: Dictionary = authority.execute(_state)
	var passive: GameCommand = APPLY.new(0, authority.payload.duplicate(true))
	assert_eq(passive.project_application_result(result, 1), result)
	assert_eq(passive.execute_with_application_result(mirror, result), result)
	assert_eq(Vector2(mirror_ship.pos_x, mirror_ship.pos_y),
			Vector2(_ship.pos_x, _ship.pos_y))


func _command() -> GameCommand:
	return APPLY.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:10",
		"maneuver_execution_id": "maneuver:10",
	})


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 5
	data.max_speed = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data
