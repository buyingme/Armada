extends GutTest


const EXECUTE: GDScript = preload(
		"res://src/core/commands/candidate_execute_maneuver_command.gd")
const APPLY: GDScript = preload(
		"res://src/core/commands/candidate_apply_maneuver_transform_command.gd")
const COMPLETE: GDScript = preload(
		"res://src/core/commands/candidate_complete_maneuver_command.gd")
const EVALUATOR: GDScript = preload(
		"res://src/core/movement/maneuver_execution_evaluator.gd")


func test_completion_requires_applied_transform_and_retires_exact_execution() -> void:
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	var ship := ShipInstance.create_from_data("candidate", _ship_data(), 0, 0)
	ship.pos_x = 0.5
	ship.pos_y = 0.5
	state.get_player_state(0).ships.append(ship)
	assert_true(ship.establish_ship_activation("ship-activation:18"))
	assert_true(ship.open_maneuver_opportunity("ship-activation:18"))
	var execute: GameCommand = EXECUTE.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:18",
		"speed": 0,
		"yaw_clicks": [],
		"yaw_bonus_joint": -1,
	})
	execute.sequence = 18
	assert_false(execute.execute(state).is_empty())
	var payload: Dictionary = {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:18",
		"maneuver_execution_id": "maneuver:18",
	}
	var complete: GameCommand = COMPLETE.new(0, payload)
	assert_ne(complete.validate(state), "")
	assert_eq(EVALUATOR.next_action(state, 0, 0)["command_type"],
			"apply_maneuver_transform")
	assert_false(APPLY.new(0, payload).execute(state).is_empty())
	assert_eq(EVALUATOR.next_action(state, 0, 0)["command_type"],
			"complete_maneuver")
	assert_eq(complete.validate(state), "")
	assert_eq(complete.execute(state), {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:18",
		"maneuver_execution_id": "maneuver:18",
		"maneuver_opportunity_disposition": "CONSUMED",
		"maneuver_execution_retired": true,
	})
	assert_false(ship.has_active_maneuver_execution())
	assert_eq(ship.maneuver_opportunity_disposition, "CONSUMED")
	assert_ne(COMPLETE.new(0, payload).validate(state), "")


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 5
	data.max_speed = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data
