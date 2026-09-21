extends GutTest


const COMMAND: GDScript = preload(
		"res://src/core/commands/candidate_execute_maneuver_command.gd")
const AUTHORITY: GDScript = preload(
		"res://src/core/movement/maneuver_authority.gd")

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


func test_intent_only_commit_derives_geometry_and_exact_result() -> void:
	var command: GameCommand = _command(10, 1, [0], -1)
	assert_eq(command.validate(_state), "")
	var result: Dictionary = command.execute(_state)
	assert_eq(result.keys(), [
		"owner_player", "ship_index", "ship_activation_identity",
		"maneuver_execution_id", "speed", "yaw_clicks",
		"yaw_bonus_joint", "navigate_dial_spent",
		"navigate_token_spent", "navigate_speed_changed", "pos_x",
		"pos_y", "rotation_deg", "maneuver_opportunity_disposition",
	])
	assert_eq(result["maneuver_execution_id"], "maneuver:10")
	assert_false(bool(result["navigate_dial_spent"]))
	assert_false(bool(result["navigate_token_spent"]))
	assert_ne(float(result["pos_y"]), 0.75)
	assert_eq(Vector2(_ship.pos_x, _ship.pos_y), Vector2(0.5, 0.75),
			"Commitment must preserve the canonical board transform.")
	assert_true(_ship.has_active_maneuver_execution())
	assert_false(bool(_ship.active_maneuver_execution_snapshot()[
			"final_transform_applied"]))
	assert_eq(_ship.active_maneuver_execution_snapshot()["committed_result"][
			"pos_y"], result["pos_y"])
	assert_eq(_ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_OPEN)


func test_speed_change_atomically_spends_minimum_dial_source() -> void:
	_reveal_navigate_dial()
	var command: GameCommand = _command(11, 2, [0, 0], -1)
	var result: Dictionary = command.execute(_state)
	assert_true(bool(result["navigate_dial_spent"]))
	assert_false(bool(result["navigate_token_spent"]))
	assert_eq(_ship.current_speed, 2)
	assert_true(_ship.command_dial_stack.get_revealed_dial().is_empty())
	assert_eq(_ship.command_dial_stack.get_spent_history().size(), 1)


func test_replayed_reveal_convert_then_speed_change_matches_live_state() -> void:
	var live: GameState = _navigate_conversion_state()
	var replay: GameState = _navigate_conversion_state()
	var recorded: Array[GameCommand] = [
		AssignDialCommand.new(0, {
			"ship_index": 0,
			"commands": [int(Constants.CommandType.NAVIGATE)],
		}),
		RevealDialCommand.new(0, {"ship_index": 0, "action": "reveal"}),
		ConvertDialToTokenCommand.new(0, {"ship_index": 0}),
	]
	recorded[0].sequence = 1
	recorded[1].sequence = 5
	recorded[2].sequence = 6
	for command: GameCommand in recorded:
		assert_false(command.execute(live).is_empty())
		var reconstructed: GameCommand = GameCommand.deserialize(
				command.serialize())
		assert_not_null(reconstructed)
		assert_false(reconstructed.execute(replay).is_empty())
	assert_true(live.get_ship(0, 0).open_maneuver_opportunity(
			"ship-activation:6"))
	assert_true(replay.get_ship(0, 0).open_maneuver_opportunity(
			"ship-activation:6"))

	var live_execute := CandidateExecuteManeuverCommand.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:6",
		"speed": 3,
		"yaw_clicks": [0, 0, 0],
		"yaw_bonus_joint": -1,
	})
	live_execute.sequence = 10
	var replay_execute: GameCommand = GameCommand.deserialize(
			live_execute.serialize())
	var live_result: Dictionary = live_execute.execute(live)
	var replay_result: Dictionary = replay_execute.execute(replay)
	assert_false(live_result.is_empty())
	assert_eq(replay_result, live_result)
	assert_true(bool(replay_result.get("navigate_token_spent", false)))
	assert_false(replay.get_ship(0, 0).command_tokens.has_token(
			Constants.CommandType.NAVIGATE))
	assert_eq(replay.serialize(), live.serialize(),
			"Live and replay canonical state must converge across conversion.")


func test_speed_zero_uses_same_commitment_identity_and_path() -> void:
	_reveal_navigate_dial()
	var command: GameCommand = _command(12, 0, [], -1)
	var before := Vector2(_ship.pos_x, _ship.pos_y)
	var result: Dictionary = command.execute(_state)
	assert_eq(result["maneuver_execution_id"], "maneuver:12")
	assert_eq(_ship.current_speed, 0)
	assert_eq(Vector2(_ship.pos_x, _ship.pos_y), before)
	assert_true(_ship.has_active_maneuver_execution())


func test_rejects_caller_geometry_and_overlap_fields_without_mutation() -> void:
	var command: GameCommand = _command(13, 1, [0], -1)
	command.payload["pos_x"] = 0.1
	command.payload["did_overlap"] = true
	var before: Dictionary = _snapshot()
	assert_ne(command.validate(_state), "")
	assert_eq(command.execute(_state), {})
	assert_eq(_snapshot(), before)


func test_aggregate_conflict_rejects_without_spending_or_mutation() -> void:
	_reveal_navigate_dial()
	assert_true(_ship.command_tokens.add_token(
			Constants.CommandType.NAVIGATE))
	var command: GameCommand = _command(14, 3, [0, 0, 0], -1)
	var before: Dictionary = _snapshot()
	var conflicting := ShipInstance.create_from_data(
			"conflict", _ship_data(), 1, 1)
	_state.get_player_state(1).ships.append(conflicting)
	assert_true(conflicting.establish_ship_activation("ship-activation:other"))
	assert_true(conflicting.open_maneuver_opportunity("ship-activation:other"))
	assert_true(conflicting.commit_maneuver_execution(
			"ship-activation:other", "maneuver:other", false,
			_committed_result([0], -1, 0.5, 0.5, 0.0),
			{"kind": "none"}))
	assert_eq(command.execute(_state), {})
	assert_eq(_snapshot(), before)


func test_collision_identity_and_key_are_committed_from_attempted_result() -> void:
	var first: Dictionary = AUTHORITY.derive(
			_state, 0, 0, 1, [0], -1)
	var other := ShipInstance.create_from_data(
			"other", _ship_data(), 0, 1)
	var attempted: Transform2D = first["attempted_transform"]
	other.pos_x = attempted.origin.x / GameScale.play_area_size_px.x
	other.pos_y = attempted.origin.y / GameScale.play_area_size_px.y
	_state.get_player_state(1).ships.append(other)
	var result: Dictionary = _command(15, 1, [0], -1).execute(_state)
	assert_false(result.is_empty())
	assert_eq(_ship.active_maneuver_execution_snapshot()["ship_collision"], {
		"kind": "closest_ship",
		"target_owner_player": 1,
		"target_ship_index": 0,
		"exact_once_key":
				"collision:ship-activation:10:maneuver:15:1:0",
		"damage_resolved": false,
	})


func test_contract_2_application_rederives_and_applies_exact_result() -> void:
	var authority: GameCommand = _command(16, 1, [0], -1)
	var result: Dictionary = authority.execute(_state)
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
	var command: GameCommand = COMMAND.new(0, authority.payload.duplicate(true))
	command.sequence = 16
	assert_eq(command.project_application_result(result, 1), result)
	assert_eq(command.execute_with_application_result(mirror, result), result)
	assert_eq(mirror_ship.active_maneuver_execution_snapshot(),
			_ship.active_maneuver_execution_snapshot())
	var bad: Dictionary = result.duplicate(true)
	bad["pos_x"] = float(bad["pos_x"]) + 0.1
	assert_eq(COMMAND.new(0, authority.payload)
			.execute_with_application_result(mirror, bad), {})


func _command(command_sequence: int, speed: int, yaw_clicks: Array,
		yaw_bonus_joint: int) -> GameCommand:
	var command: GameCommand = COMMAND.new(0, {
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:10",
		"speed": speed,
		"yaw_clicks": yaw_clicks,
		"yaw_bonus_joint": yaw_bonus_joint,
	})
	command.sequence = command_sequence
	return command


func _navigate_conversion_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	state.rng = GameRng.new(20260920)
	var data: ShipData = _ship_data()
	data.command_value = 1
	var ship := ShipInstance.create_from_data("candidate", data, 2, 0)
	ship.pos_x = 0.5
	ship.pos_y = 0.75
	state.get_player_state(0).ships.append(ship)
	return state


func _reveal_navigate_dial() -> void:
	assert_true(_ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1))
	assert_false(_ship.command_dial_stack.reveal_top().is_empty())


func _committed_result(yaw_clicks: Array, yaw_bonus_joint: int,
		pos_x: float, pos_y: float, rotation_deg: float) -> Dictionary:
	return {
		"yaw_clicks": yaw_clicks,
		"yaw_bonus_joint": yaw_bonus_joint,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"rotation_deg": rotation_deg,
	}


func _snapshot() -> Dictionary:
	return {
		"speed": _ship.current_speed,
		"pos_x": _ship.pos_x,
		"pos_y": _ship.pos_y,
		"rotation_deg": _ship.rotation_deg,
		"boundary": _ship.ship_activation_boundary_snapshot(),
		"dials": _ship.command_dial_stack.serialize(),
		"tokens": _ship.command_tokens.serialize(),
	}


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 5
	data.max_speed = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data
