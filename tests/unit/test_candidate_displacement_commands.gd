extends GutTest


const START: GDScript = preload(
		"res://src/core/commands/candidate_start_displacement_command.gd")
const COMMIT: GDScript = preload(
		"res://src/core/commands/candidate_commit_displacement_command.gd")
const PROCESSOR_SCRIPT: GDScript = preload(
		"res://src/autoload/command_processor.gd")


class ProcessorSubmitter:
	extends CommandSubmitter

	var processor: Node = null


	func _init(p_processor: Node) -> void:
		processor = p_processor


	func submit(command: GameCommand) -> Dictionary:
		return processor.submit(command)


var _state: GameState
var _ship: ShipInstance
var _squadron: SquadronInstance
var _identity: Dictionary = {"owner": 1, "squadron_index": 0}
var _saved_state: GameState = null
var _saved_submitter: CommandSubmitter = null


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_submitter = GameManager.get_command_submitter()
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	_ship = ShipInstance.create_from_data("moving", _ship_data(), 0, 0)
	_ship.pos_x = 0.5
	_ship.pos_y = 0.5
	_state.get_player_state(0).ships.append(_ship)
	_squadron = SquadronInstance.create_from_data(
			"affected", _squadron_data(), 1)
	_squadron.pos_x = 0.5
	_squadron.pos_y = 0.5
	_state.get_player_state(1).squadrons.append(_squadron)
	assert_true(_ship.establish_ship_activation("ship-activation:50"))
	assert_true(_ship.open_maneuver_opportunity("ship-activation:50"))
	assert_true(_ship.commit_maneuver_execution(
			"ship-activation:50", "maneuver:50", false, {
		"yaw_clicks": [], "yaw_bonus_joint": -1,
		"pos_x": 0.5, "pos_y": 0.5, "rotation_deg": 0.0,
	}, {"kind": "none"}))
	assert_false(_ship.apply_maneuver_final_transform(
			"ship-activation:50", "maneuver:50").is_empty())
	GameManager.current_game_state = _state


func after_each() -> void:
	GameManager.current_game_state = _saved_state
	GameManager.set_command_submitter(_saved_submitter)


func test_start_rederives_complete_set_and_nonmoving_controller() -> void:
	var command: GameCommand = START.new(0, _start_payload())
	assert_eq(command.validate(_state), "")
	assert_eq(command.execute(_state), {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:50",
		"maneuver_execution_id": "maneuver:50",
		"displaced_squadrons": [_identity],
		"controller_player": 1,
	})
	assert_eq(_state.interaction_flow.controller_player, 1)
	assert_eq(_state.interaction_flow.payload["maneuver_execution_id"],
			"maneuver:50")
	var stale: Dictionary = _start_payload()
	stale["displaced_squadrons"] = []
	assert_ne(START.new(0, stale).validate(_state), "")


func test_commit_rejects_manufactured_exclusion_then_applies_complete_batch() -> void:
	assert_false(START.new(0, _start_payload()).execute(_state).is_empty())
	var excluded := COMMIT.new(1, _commit_payload([], [_identity]))
	assert_ne(excluded.validate(_state), "")
	assert_eq(excluded.rejection_projection(), {
		"required_placeable_count": 1,
		"submitted_placeable_count": 0,
		"required_direct_touch_count": 1,
		"submitted_direct_touch_count": 0,
	})
	var point: Vector2 = _direct_point()
	var placement: Dictionary = {
		"owner": 1,
		"squadron_index": 0,
		"pos_x": point.x / GameScale.play_area_size_px.x,
		"pos_y": point.y / GameScale.play_area_size_px.y,
	}
	var accepted := COMMIT.new(1, _commit_payload([placement], []))
	assert_eq(accepted.validate(_state), "")
	var result: Dictionary = accepted.execute(_state)
	assert_eq(result["destroyed_squadrons"], [])
	assert_almost_eq(_squadron.pos_x, float(placement["pos_x"]), 0.00001)
	assert_eq(_state.interaction_flow.flow_type,
			Constants.InteractionFlow.NONE)


func test_recovered_flow_and_contract_2_result_apply_same_complete_batch() -> void:
	var authority_start: GameCommand = START.new(0, _start_payload())
	var start_result: Dictionary = authority_start.execute(_state)
	var recovered: GameState = _mirror_state()
	recovered.interaction_flow = InteractionFlow.deserialize(
			_state.interaction_flow.serialize())
	var point: Vector2 = _direct_point_for(recovered.get_ship(0, 0))
	var placement: Dictionary = {
		"owner": 1, "squadron_index": 0,
		"pos_x": point.x / GameScale.play_area_size_px.x,
		"pos_y": point.y / GameScale.play_area_size_px.y,
	}
	var authority_commit := COMMIT.new(1, _commit_payload([placement], []))
	var commit_result: Dictionary = authority_commit.execute(_state)
	assert_false(commit_result.is_empty())
	var mirror_start: GameCommand = START.new(0, _start_payload())
	# The recovered flow already represents the accepted opener; a duplicate
	# opener remains unavailable while the exact commit is legal.
	assert_ne(mirror_start.validate(recovered), "")
	var mirror_commit: GameCommand = COMMIT.new(
			1, authority_commit.payload.duplicate(true))
	assert_eq(mirror_commit.execute_with_application_result(
			recovered, commit_result), commit_result)
	assert_almost_eq(recovered.get_squadron(1, 0).pos_x,
			float(placement["pos_x"]), 0.00001)
	assert_eq(start_result["controller_player"], 1)


func test_game_manager_commit_preserves_identity_and_completes_maneuver() -> void:
	assert_false(START.new(0, _start_payload()).execute(_state).is_empty())
	var processor: Node = PROCESSOR_SCRIPT.new()
	add_child_autofree(processor)
	GameManager.set_command_submitter(ProcessorSubmitter.new(processor))
	var point: Vector2 = _direct_point()
	var placement: Dictionary = {
		"owner": 1,
		"squadron_index": 0,
		"pos_x": point.x / GameScale.play_area_size_px.x,
		"pos_y": point.y / GameScale.play_area_size_px.y,
	}

	var result: Dictionary = GameManager.submit_commit_displacement([placement])

	assert_false(result.is_empty())
	var history: Array[GameCommand] = processor.get_history()
	assert_eq(history.size(), 2,
			"Accepted displacement should derive exactly complete_maneuver.")
	assert_eq(history[0].command_type, "commit_displacement")
	assert_eq(history[0].payload, _commit_payload([placement], []),
			"The UI submission boundary must preserve every Maneuver identity.")
	assert_eq(history[1].command_type, "complete_maneuver")
	assert_false(_ship.has_active_maneuver_execution(),
			"Purpose-specific return must retire the execution record.")
	assert_eq(_ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_CONSUMED)


func _start_payload() -> Dictionary:
	return {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:50",
		"maneuver_execution_id": "maneuver:50",
		"displaced_squadrons": [_identity.duplicate(true)],
	}


func _commit_payload(placements: Array, excluded: Array) -> Dictionary:
	return {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:50",
		"maneuver_execution_id": "maneuver:50",
		"placements": placements,
		"excluded_squadrons": excluded,
	}


func _direct_point() -> Vector2:
	return _direct_point_for(_ship)


func _direct_point_for(ship: ShipInstance) -> Vector2:
	var base := ShipBase.new(ship.ship_data.ship_size,
			Transform2D(0.0, ship.get_pixel_position(
					GameScale.play_area_size_px)))
	return base.ship_transform * Vector2(0.0,
			-base.half_length_px
			- GameScale.squadron_base_diameter_px * 0.5 - 1.0)


func _mirror_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	var ship := ShipInstance.create_from_data("moving", _ship_data(), 0, 0)
	ship.pos_x = _ship.pos_x
	ship.pos_y = _ship.pos_y
	assert_true(ship.restore_ship_activation_boundary(
			_ship.ship_activation_boundary_snapshot()))
	state.get_player_state(0).ships.append(ship)
	var squadron := SquadronInstance.create_from_data(
			"affected", _squadron_data(), 1)
	squadron.pos_x = _squadron.pos_x
	squadron.pos_y = _squadron.pos_y
	state.get_player_state(1).squadrons.append(squadron)
	return state


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 5
	data.max_speed = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data


func _squadron_data() -> SquadronData:
	var data := SquadronData.new()
	data.hull = 3
	return data
