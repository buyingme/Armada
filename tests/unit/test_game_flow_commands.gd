## Tests for §4.6 P1 game-flow command subclasses.
##
## Covers: AdvancePhaseCommand and StartRoundCommand.
## Each command is tested for validate (happy + rejection), execute,
## and serialize/deserialize roundtrip.
extends GutTest


var _state: GameState
var _saved_registry: Dictionary = {}


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	_state = GameState.new()
	_state.initialize()
	_state.current_round = 1
	_state.current_phase = Constants.GamePhase.COMMAND
	AdvancePhaseCommand.register()
	StartRoundCommand.register()


func after_each() -> void:
	GameCommand._registry = _saved_registry


# ======================================================================
# AdvancePhaseCommand — validate
# ======================================================================

func test_advance_phase_validate_command_to_ship() -> void:
	var cmd := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.SHIP),
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept COMMAND → SHIP transition.")


func test_advance_phase_validate_ship_to_squadron() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var cmd := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.SQUADRON),
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept SHIP → SQUADRON transition.")


func test_advance_phase_validate_squadron_to_status() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var cmd := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.STATUS),
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept SQUADRON → STATUS transition.")


func test_advance_phase_validate_rejects_wrong_target() -> void:
	# COMMAND phase — can only go to SHIP, not SQUADRON.
	var cmd := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.SQUADRON),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject skipping a phase.")


func test_advance_phase_validate_rejects_from_status() -> void:
	_state.current_phase = Constants.GamePhase.STATUS
	var cmd := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.COMMAND),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject STATUS → COMMAND (use StartRoundCommand).")


func test_advance_phase_validate_rejects_missing_phase() -> void:
	var cmd := AdvancePhaseCommand.new(0, {})
	assert_ne(cmd.validate(_state), "",
			"Should reject missing next_phase.")


func test_advance_phase_validate_rejects_null_state() -> void:
	var cmd := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.SHIP),
	})
	assert_ne(cmd.validate(null), "",
			"Should reject null game state.")


# ======================================================================
# AdvancePhaseCommand — execute
# ======================================================================

func test_advance_phase_execute_sets_phase() -> void:
	var cmd := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.SHIP),
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(int(_state.current_phase), int(Constants.GamePhase.SHIP),
			"Phase should be SHIP after execution.")
	assert_eq(result["previous_phase"], int(Constants.GamePhase.COMMAND),
			"Result should report previous phase.")
	assert_eq(result["new_phase"], int(Constants.GamePhase.SHIP),
			"Result should report new phase.")


func test_advance_phase_execute_ship_to_squadron() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var cmd := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.SQUADRON),
	})
	cmd.execute(_state)
	assert_eq(int(_state.current_phase), int(Constants.GamePhase.SQUADRON),
			"Phase should be SQUADRON after execution.")


# ======================================================================
# AdvancePhaseCommand — serialize / deserialize
# ======================================================================

func test_advance_phase_serialize_roundtrip() -> void:
	var cmd := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.SHIP),
	})
	cmd.sequence = 42
	var data: Dictionary = cmd.serialize()
	assert_eq(data["type"], "advance_phase",
			"Serialized type should be advance_phase.")
	assert_eq(data["player"], 0,
			"Serialized player should be 0.")
	assert_eq(data["sequence"], 42,
			"Serialized sequence should be 42.")
	assert_eq(data["payload"]["next_phase"],
			int(Constants.GamePhase.SHIP),
			"Serialized next_phase should match.")


func test_advance_phase_deserialize() -> void:
	var data: Dictionary = {
		"type": "advance_phase",
		"player": 1,
		"sequence": 7,
		"payload": {"next_phase": int(Constants.GamePhase.SQUADRON)},
	}
	var cmd: GameCommand = GameCommand.deserialize(data)
	assert_not_null(cmd, "Deserialized command should not be null.")
	assert_is(cmd, AdvancePhaseCommand,
			"Deserialized command should be AdvancePhaseCommand.")
	assert_eq(cmd.player_index, 1,
			"Player index should be 1.")
	assert_eq(cmd.sequence, 7,
			"Sequence should be 7.")
	assert_eq(cmd.payload["next_phase"],
			int(Constants.GamePhase.SQUADRON),
			"Payload next_phase should match.")


# ======================================================================
# StartRoundCommand — validate
# ======================================================================

func test_start_round_validate_ok_from_status() -> void:
	_state.current_phase = Constants.GamePhase.STATUS
	_state.current_round = 1
	var cmd := StartRoundCommand.new(0, {})
	assert_eq(cmd.validate(_state), "",
			"Should accept starting round 2 from STATUS phase.")


func test_start_round_validate_ok_from_setup() -> void:
	_state.current_phase = Constants.GamePhase.SETUP
	_state.current_round = 0
	var cmd := StartRoundCommand.new(0, {})
	assert_eq(cmd.validate(_state), "",
			"Should accept starting round 1 from SETUP phase (game start).")


func test_start_round_validate_rejects_incomplete_setup_package() -> void:
	_mark_setup_package_state(false)
	var cmd := StartRoundCommand.new(0, {})
	assert_ne(cmd.validate(_state), "",
			"Setup-package starts should wait for full placement data.")


func test_start_round_validate_accepts_complete_setup_package() -> void:
	_mark_setup_package_state(true)
	var cmd := StartRoundCommand.new(0, {})
	assert_eq(cmd.validate(_state), "",
			"Completed setup-package state should allow round one to start.")


func test_start_round_validate_rejects_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var cmd := StartRoundCommand.new(0, {})
	assert_ne(cmd.validate(_state), "",
			"Should reject starting round from non-STATUS phase.")


func test_start_round_validate_rejects_max_rounds() -> void:
	_state.current_phase = Constants.GamePhase.STATUS
	_state.current_round = Constants.MAX_ROUNDS
	var cmd := StartRoundCommand.new(0, {})
	assert_ne(cmd.validate(_state), "",
			"Should reject starting round beyond MAX_ROUNDS.")


func test_start_round_validate_rejects_null_state() -> void:
	var cmd := StartRoundCommand.new(0, {})
	assert_ne(cmd.validate(null), "",
			"Should reject null game state.")


# ======================================================================
# StartRoundCommand — execute
# ======================================================================

func test_start_round_execute_increments_round() -> void:
	_state.current_phase = Constants.GamePhase.STATUS
	_state.current_round = 2
	var cmd := StartRoundCommand.new(0, {})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(_state.current_round, 3,
			"Round should be incremented to 3.")
	assert_eq(int(_state.current_phase), int(Constants.GamePhase.COMMAND),
			"Phase should be reset to COMMAND.")
	assert_eq(result["new_round"], 3,
			"Result should report new round.")
	assert_eq(result["new_phase"], int(Constants.GamePhase.COMMAND),
			"Result should report COMMAND phase.")


func test_start_round_execute_from_round_1() -> void:
	_state.current_phase = Constants.GamePhase.STATUS
	_state.current_round = 1
	var cmd := StartRoundCommand.new(0, {})
	cmd.execute(_state)
	assert_eq(_state.current_round, 2,
			"Round should be incremented to 2.")
	assert_eq(int(_state.current_phase), int(Constants.GamePhase.COMMAND),
			"Phase should be COMMAND.")


# ======================================================================
# StartRoundCommand — serialize / deserialize
# ======================================================================

func test_start_round_serialize_roundtrip() -> void:
	var cmd := StartRoundCommand.new(1, {})
	cmd.sequence = 99
	var data: Dictionary = cmd.serialize()
	assert_eq(data["type"], "start_round",
			"Serialized type should be start_round.")
	assert_eq(data["player"], 1,
			"Serialized player should be 1.")
	assert_eq(data["sequence"], 99,
			"Serialized sequence should be 99.")


func test_start_round_deserialize() -> void:
	var data: Dictionary = {
		"type": "start_round",
		"player": 0,
		"sequence": 5,
		"payload": {},
	}
	var cmd: GameCommand = GameCommand.deserialize(data)
	assert_not_null(cmd, "Deserialized command should not be null.")
	assert_is(cmd, StartRoundCommand,
			"Deserialized command should be StartRoundCommand.")
	assert_eq(cmd.player_index, 0,
			"Player index should be 0.")
	assert_eq(cmd.sequence, 5,
			"Sequence should be 5.")


# ======================================================================
# StartRoundCommand — setup package completion
# ======================================================================

func test_start_round_validate_ready_setup_package_expected() -> void:
	_mark_setup_ready_with_ship()
	var cmd := StartRoundCommand.new(0, {})
	assert_eq(cmd.validate(_state), "",
			"Start round should accept placed obstacles and deployments.")


func test_start_round_validate_missing_obstacles_rejected() -> void:
	_mark_setup_package_state(false)
	var cmd := StartRoundCommand.new(0, {})
	assert_ne(cmd.validate(_state), "",
			"Start round should reject missing obstacle placements.")


func test_start_round_validate_missing_unit_deployment_rejected() -> void:
	_mark_setup_ready_with_ship()
	_state.objectives[FleetSetupBootstrapper.KEY_DEPLOYMENTS] = []
	var cmd := StartRoundCommand.new(0, {})
	assert_ne(cmd.validate(_state), "",
			"Start round should reject missing unit deployments.")


func test_start_round_execute_marks_setup_complete_expected() -> void:
	_mark_setup_ready_with_ship()
	var cmd := StartRoundCommand.new(1, {})
	var result: Dictionary = cmd.execute(_state)
	var setup_state: Dictionary = _state.objectives.get(
			FleetSetupBootstrapper.KEY_SETUP_STATE, {}) as Dictionary
	assert_eq(result.get("new_round", -1), 1,
			"Start round result should report round one.")
	assert_eq(setup_state.get("status", ""),
			StartRoundCommand.SETUP_STATUS_COMPLETE,
			"Setup state should record completion status.")
	assert_eq(setup_state.get("completed_by_player", -1), 1,
			"Setup state should record the command player.")


func _mark_setup_package_state(is_complete: bool) -> void:
	_state.current_phase = Constants.GamePhase.SETUP
	_state.current_round = 0
	var setup_state: Dictionary = {}
	if is_complete:
		setup_state["status"] = StartRoundCommand.SETUP_STATUS_COMPLETE
	_state.objectives = {
		FleetSetupBootstrapper.KEY_SETUP_PACKAGE_HASH: "hash",
		FleetSetupBootstrapper.KEY_SETUP_STATE: setup_state,
		FleetSetupBootstrapper.KEY_OBSTACLES: [],
		FleetSetupBootstrapper.KEY_DEPLOYMENTS: [],
	}


func _mark_setup_ready_with_ship() -> void:
	_mark_setup_package_state(false)
	var ship: ShipInstance = ShipInstance.new()
	ship.owner_player = 0
	ship.roster_entry_id = "ship-1"
	_state.get_player_state(0).ships.append(ship)
	_state.objectives[FleetSetupBootstrapper.KEY_OBSTACLES] = _six_obstacles()
	_state.objectives[FleetSetupBootstrapper.KEY_DEPLOYMENTS] = [
		_deployment(0, "ship", "ship-1"),
	]


func _six_obstacles() -> Array[Dictionary]:
	var obstacles: Array[Dictionary] = []
	for index: int in range(StartRoundCommand.STANDARD_OBSTACLE_COUNT):
		obstacles.append({
			"data_key": "obstacle_%d" % index,
			"pos_x": 0.1 + float(index) * 0.1,
			"pos_y": 0.5,
			"rotation_deg": 0.0,
		})
	return obstacles


func _deployment(owner_player: int,
		component_type: String, roster_entry_id: String) -> Dictionary:
	return {
		"owner_player": owner_player,
		"component_type": component_type,
		"roster_entry_id": roster_entry_id,
		"pos_x": 0.5,
		"pos_y": 0.5,
		"rotation_deg": 0.0,
	}
