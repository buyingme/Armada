## Tests for StartDisplacementCommand and CommitDisplacementCommand.
##
## Phase I6b-4a — domain plumbing only (the commands are not yet wired
## into the displacement runtime).  These tests cover validate/execute/
## serialize round-trip + interaction-flow mutation.
extends GutTest


var _state: GameState


func _make_ship_data() -> ShipData:
	var data := ShipData.new()
	data.hull = 5
	data.max_speed = 2
	data.command_value = 2
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = ["brace"]
	data.navigation_chart = [[1], [1, 1]]
	return data


func _make_squadron_data() -> SquadronData:
	var sd := SquadronData.new()
	sd.squadron_name = "Test Squadron"
	sd.hull = 3
	sd.speed = 3
	return sd


func _add_ship(player: int) -> int:
	var ship: ShipInstance = ShipInstance.create_from_data(
			"test_ship", _make_ship_data(), 2, player)
	var ps: PlayerState = _state.get_player_state(player)
	ps.ships.append(ship)
	return ps.ships.size() - 1


func _add_squadron(player: int) -> int:
	var sq: SquadronInstance = SquadronInstance.create_from_data(
			"test_sq", _make_squadron_data(), player)
	var ps: PlayerState = _state.get_player_state(player)
	ps.squadrons.append(sq)
	return ps.squadrons.size() - 1


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	StartDisplacementCommand.register()
	CommitDisplacementCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("start_displacement")
	GameCommand._registry.erase("commit_displacement")


# ---------------------------------------------------------------------------
# StartDisplacementCommand
# ---------------------------------------------------------------------------

func test_start_validate_accepts_legal_displacement() -> void:
	var ship_idx: int = _add_ship(0)
	var sq_idx: int = _add_squadron(1)
	var cmd := StartDisplacementCommand.new(0, {
		"ship_index": ship_idx,
		"controller_player": 1,
		"displaced_squadrons": [ {"owner": 1, "squadron_index": sq_idx}],
	})
	assert_eq(cmd.validate(_state), "",
			"Legal displacement should validate.")


func test_start_validate_rejects_non_ship_phase() -> void:
	_add_ship(0)
	_add_squadron(1)
	_state.current_phase = Constants.GamePhase.SQUADRON
	var cmd := StartDisplacementCommand.new(0, {
		"ship_index": 0,
		"controller_player": 1,
		"displaced_squadrons": [ {"owner": 1, "squadron_index": 0}],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Ship Phase.")


func test_start_validate_rejects_missing_ship() -> void:
	_add_squadron(1)
	var cmd := StartDisplacementCommand.new(0, {
		"ship_index": 99,
		"controller_player": 1,
		"displaced_squadrons": [ {"owner": 1, "squadron_index": 0}],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject missing maneuvering ship.")


func test_start_validate_rejects_missing_squadron() -> void:
	_add_ship(0)
	var cmd := StartDisplacementCommand.new(0, {
		"ship_index": 0,
		"controller_player": 1,
		"displaced_squadrons": [ {"owner": 1, "squadron_index": 99}],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject missing displaced squadron.")


func test_start_validate_rejects_invalid_controller() -> void:
	_add_ship(0)
	_add_squadron(1)
	var cmd := StartDisplacementCommand.new(0, {
		"ship_index": 0,
		"controller_player": 5,
		"displaced_squadrons": [ {"owner": 1, "squadron_index": 0}],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject controller_player outside [0,1].")


func test_start_validate_rejects_empty_squadron_list() -> void:
	_add_ship(0)
	var cmd := StartDisplacementCommand.new(0, {
		"ship_index": 0,
		"controller_player": 1,
		"displaced_squadrons": [],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject empty displaced_squadrons list.")


func test_start_validate_rejects_double_open() -> void:
	_add_ship(0)
	_add_squadron(1)
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE,
			1, Constants.Visibility.ALL, {})
	var cmd := StartDisplacementCommand.new(0, {
		"ship_index": 0,
		"controller_player": 1,
		"displaced_squadrons": [ {"owner": 1, "squadron_index": 0}],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject opening when displacement already active.")


func test_start_execute_sets_interaction_flow() -> void:
	_add_ship(0)
	_add_squadron(1)
	var cmd := StartDisplacementCommand.new(0, {
		"ship_index": 0,
		"controller_player": 1,
		"displaced_squadrons": [ {"owner": 1, "squadron_index": 0}],
	})
	cmd.execute(_state)
	var f: InteractionFlow = _state.interaction_flow
	assert_eq(f.flow_type,
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			"flow_type should be SQUADRON_DISPLACEMENT.")
	assert_eq(f.step_id,
			Constants.InteractionStep.DISPLACEMENT_PLACE,
			"step_id should be DISPLACEMENT_PLACE.")
	assert_eq(f.controller_player, 1,
			"controller_player should match payload (set by producer to" +
			" the opposing — non-moving — player per RRG p.8).")
	assert_true(f.payload.has("ship_index"),
			"Payload should carry ship_index.")
	assert_true(f.payload.has("displaced_squadrons"),
			"Payload should carry displaced_squadrons.")


func test_start_execute_payload_is_independent_copy() -> void:
	_add_ship(0)
	_add_squadron(1)
	var list: Array = [ {"owner": 1, "squadron_index": 0}]
	var cmd := StartDisplacementCommand.new(0, {
		"ship_index": 0,
		"controller_player": 1,
		"displaced_squadrons": list,
	})
	cmd.execute(_state)
	# Mutate the original command payload list — the flow snapshot
	# inside GameState must not change.
	(list[0] as Dictionary)["squadron_index"] = 999
	var stored_list: Array = (
			_state.interaction_flow.payload["displaced_squadrons"] as Array)
	assert_eq(int((stored_list[0] as Dictionary).get("squadron_index", -1)),
			0,
			"Stored payload must be a deep copy isolated from caller.")


func test_start_serialize_deserialize_roundtrip() -> void:
	var cmd := StartDisplacementCommand.new(0, {
		"ship_index": 2,
		"controller_player": 1,
		"displaced_squadrons": [
			{"owner": 1, "squadron_index": 0},
			{"owner": 1, "squadron_index": 1},
		],
	})
	cmd.sequence = 41
	var data: Dictionary = cmd.serialize()
	var copy: GameCommand = GameCommand.deserialize(data)
	assert_not_null(copy, "Deserialized command should not be null.")
	assert_eq(copy.command_type, "start_displacement",
			"Type should round-trip.")
	assert_eq(copy.player_index, 0,
			"Player index should round-trip.")
	assert_eq(copy.sequence, 41,
			"Sequence should round-trip.")
	assert_eq(int(copy.payload.get("controller_player", -1)), 1,
			"controller_player should round-trip.")
	var roundtrip_list: Array = (
			copy.payload.get("displaced_squadrons", []) as Array)
	assert_eq(roundtrip_list.size(), 2,
			"displaced_squadrons should round-trip with all entries.")


# ---------------------------------------------------------------------------
# CommitDisplacementCommand
# ---------------------------------------------------------------------------

func _open_displacement_flow(controller: int) -> void:
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE,
			controller, Constants.Visibility.ALL,
			{"ship_index": 0, "displaced_squadrons": [
					{"owner": 1, "squadron_index": 0}]})


func test_commit_validate_accepts_legal_placement() -> void:
	_add_squadron(1)
	_open_displacement_flow(1)
	var cmd := CommitDisplacementCommand.new(1, {
		"placements": [
			{"owner": 1, "squadron_index": 0,
				"pos_x": 0.5, "pos_y": 0.5},
		],
	})
	assert_eq(cmd.validate(_state), "",
			"Legal commit should validate.")


func test_commit_validate_rejects_no_active_flow() -> void:
	_add_squadron(1)
	var cmd := CommitDisplacementCommand.new(1, {
		"placements": [
			{"owner": 1, "squadron_index": 0,
				"pos_x": 0.5, "pos_y": 0.5},
		],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject commit when no displacement flow is active.")


func test_commit_validate_rejects_wrong_controller() -> void:
	_add_squadron(1)
	_open_displacement_flow(1)
	var cmd := CommitDisplacementCommand.new(0, {
		"placements": [
			{"owner": 1, "squadron_index": 0,
				"pos_x": 0.5, "pos_y": 0.5},
		],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject commit from non-controller peer.")


func test_commit_validate_rejects_out_of_range_position() -> void:
	_add_squadron(1)
	_open_displacement_flow(1)
	var cmd := CommitDisplacementCommand.new(1, {
		"placements": [
			{"owner": 1, "squadron_index": 0,
				"pos_x": 1.7, "pos_y": 0.5},
		],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject placement with denormalised position.")


func test_commit_execute_applies_positions_and_clears_flow() -> void:
	var sq_idx: int = _add_squadron(1)
	_open_displacement_flow(1)
	var cmd := CommitDisplacementCommand.new(1, {
		"placements": [
			{"owner": 1, "squadron_index": sq_idx,
				"pos_x": 0.25, "pos_y": 0.75},
		],
	})
	cmd.execute(_state)
	var sq: SquadronInstance = _state.get_squadron(1, sq_idx)
	assert_almost_eq(sq.pos_x, 0.25, 0.0001,
			"Squadron pos_x should be applied from payload.")
	assert_almost_eq(sq.pos_y, 0.75, 0.0001,
			"Squadron pos_y should be applied from payload.")
	assert_eq(_state.interaction_flow.flow_type,
			Constants.InteractionFlow.NONE,
			"flow_type should be cleared to NONE after commit.")


func test_commit_serialize_deserialize_roundtrip() -> void:
	var cmd := CommitDisplacementCommand.new(1, {
		"placements": [
			{"owner": 1, "squadron_index": 0,
				"pos_x": 0.1, "pos_y": 0.9},
			{"owner": 1, "squadron_index": 1,
				"pos_x": 0.4, "pos_y": 0.6},
		],
	})
	cmd.sequence = 88
	var data: Dictionary = cmd.serialize()
	var copy: GameCommand = GameCommand.deserialize(data)
	assert_not_null(copy, "Deserialized command should not be null.")
	assert_eq(copy.command_type, "commit_displacement",
			"Type should round-trip.")
	assert_eq(copy.sequence, 88, "Sequence should round-trip.")
	var roundtrip_list: Array = (
			copy.payload.get("placements", []) as Array)
	assert_eq(roundtrip_list.size(), 2,
			"placements should round-trip with all entries.")
