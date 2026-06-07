## Tests for §4.6 P1 game-flow command subclasses.
##
## Covers: AdvancePhaseCommand and StartRoundCommand.
## Each command is tested for validate (happy + rejection), execute,
## and serialize/deserialize roundtrip.
extends GutTest


const CommitSetupObstacleCommandScript = preload(
		"res://src/core/commands/commit_setup_obstacle_command.gd")
const CommitSetupDeploymentCommandScript = preload(
		"res://src/core/commands/commit_setup_deployment_command.gd")
const SetupInteractionFlowResolverScript = preload(
		"res://src/core/setup/setup_interaction_flow_resolver.gd")
const OBSTACLE_KEYS: Array[String] = [
	"asteroid_1",
	"asteroid_2",
	"asteroid_3",
	"debris_1",
	"debris_2",
	"station",
]


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
	CommitSetupObstacleCommandScript.register()
	CommitSetupDeploymentCommandScript.register()


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


# ======================================================================
# Setup placement commands
# ======================================================================

func test_commit_setup_obstacle_validate_outside_board_rejected() -> void:
	_mark_setup_package_state(false)
	var cmd: GameCommand = _deserialize_setup_command(
			"commit_setup_obstacle", 1, {
		"data_key": "asteroid_1",
		"pos_x": 1.2,
		"pos_y": 0.5,
	})
	assert_ne(cmd.validate(_state), "",
			"Obstacle placement should reject positions outside the play area.")


func test_commit_setup_obstacle_execute_appends_payload_expected() -> void:
	_mark_setup_package_state(false)
	var cmd: GameCommand = _deserialize_setup_command(
			"commit_setup_obstacle", 1, {
		"data_key": "asteroid_1",
		"pos_x": 0.25,
		"pos_y": 0.4,
		"rotation_deg": 15.0,
	})
	var result: Dictionary = cmd.execute(_state)
	var obstacles: Array = _state.objectives.get(FleetSetupBootstrapper.KEY_OBSTACLES, []) as Array
	assert_eq(obstacles.size(), 1,
			"Obstacle placement should append a new setup obstacle entry.")
	assert_eq(result.get("obstacle_count", -1), 1,
			"Obstacle result should report the current obstacle count.")
	assert_almost_eq(float((obstacles[0] as Dictionary).get("pos_x", 0.0)), 0.25, 0.001,
			"Obstacle placement should persist normalized X.")
	assert_eq(int((obstacles[0] as Dictionary).get("placing_player", -1)), 1,
			"Obstacle placement should record the committing player for replay-safe mirroring.")
	assert_eq(int((obstacles[0] as Dictionary).get("placement_order", -1)), 0,
			"Obstacle placement should record the deterministic placement order.")
	assert_eq(_state.interaction_flow.step_id,
			Constants.InteractionStep.SETUP_OBSTACLE_PLACEMENT,
			"Obstacle placement should keep setup flow on obstacle placement until six are placed.")


func test_commit_setup_obstacle_validate_wrong_controller_rejected() -> void:
	_mark_setup_package_state(false)
	var cmd: GameCommand = _deserialize_setup_command(
			"commit_setup_obstacle", 0, {
		"data_key": "asteroid_1",
		"pos_x": 0.4,
		"pos_y": 0.4,
	})
	assert_ne(cmd.validate(_state), "",
			"Obstacle placement should reject the non-controller player.")


func test_commit_setup_obstacle_validate_duplicate_obstacle_rejected() -> void:
	_mark_setup_package_state(false)
	_state.objectives[FleetSetupBootstrapper.KEY_OBSTACLES] = [
		_obstacle_entry("asteroid_1", 0.25, 0.4, 1, 0),
	]
	_refresh_setup_flow()
	var cmd: GameCommand = _deserialize_setup_command(
			"commit_setup_obstacle", 0, {
		"data_key": "asteroid_1",
		"pos_x": 0.35,
		"pos_y": 0.6,
	})
	assert_ne(cmd.validate(_state), "",
			"Obstacle placement should reject a second placement of the same obstacle key.")


func test_commit_setup_obstacle_validate_3x6_deployment_zone_rejected() -> void:
	_mark_setup_package_state(false)
	_state.objectives[FleetSetupBootstrapper.KEY_MAP] = {
		"filename": "map_3x6_distant-planet_v4.jpg",
	}
	_refresh_setup_flow()
	var cmd: GameCommand = _deserialize_setup_command(
			"commit_setup_obstacle", 1, {
		"data_key": "asteroid_2",
		"pos_x": 0.5,
		"pos_y": 0.18,
	})
	assert_ne(cmd.validate(_state), "",
			"3x6 obstacle placement should reject footprints that overlap deployment zones.")


func test_commit_setup_obstacle_validate_distance_one_separation_rejected() -> void:
	_mark_setup_package_state(false)
	_state.objectives[FleetSetupBootstrapper.KEY_OBSTACLES] = [
		_obstacle_entry("asteroid_1", 0.5, 0.5, 1, 0),
	]
	_refresh_setup_flow()
	var cmd: GameCommand = _deserialize_setup_command(
			"commit_setup_obstacle", 0, {
		"data_key": "debris_1",
		"pos_x": 0.56,
		"pos_y": 0.5,
	})
	assert_ne(cmd.validate(_state), "",
			"Obstacle placement should reject placements within distance 1 of another obstacle.")


func test_commit_setup_deployment_validate_missing_target_rejected() -> void:
	_mark_setup_package_state(false)
	var cmd: GameCommand = _deserialize_setup_command(
			"commit_setup_deployment", 0, {
		"owner_player": 0,
		"component_type": "ship",
		"roster_entry_id": "missing",
		"pos_x": 0.5,
		"pos_y": 0.5,
	})
	assert_ne(cmd.validate(_state), "",
			"Deployment placement should reject unknown live targets.")


func test_commit_setup_deployment_execute_updates_ship_expected() -> void:
	_mark_setup_ready_with_ship()
	var ship: ShipInstance = _state.get_player_state(0).ships[0] as ShipInstance
	ship.current_speed = 2
	var cmd: GameCommand = _deserialize_setup_command(
			"commit_setup_deployment", 0, {
		"owner_player": 0,
		"component_type": "ship",
		"roster_entry_id": "ship-1",
		"pos_x": 0.62,
		"pos_y": 0.78,
		"rotation_deg": 180.0,
		"speed": 3,
	})
	var result: Dictionary = cmd.execute(_state)
	var deployments: Array = _state.objectives.get(FleetSetupBootstrapper.KEY_DEPLOYMENTS, []) as Array
	assert_almost_eq(ship.pos_x, 0.62, 0.001,
			"Deployment execute should update the live ship X position.")
	assert_eq(ship.current_speed, 3,
			"Deployment execute should update the live ship speed when provided.")
	assert_eq((result.get("deployment", {}) as Dictionary).get("roster_entry_id", ""), "ship-1",
			"Deployment result should echo the updated roster entry id.")
	assert_eq(deployments.size(), 1,
			"Deployment execute should upsert a single deployment entry for the ship.")
	assert_eq(_state.interaction_flow.step_id,
			Constants.InteractionStep.SETUP_REVIEW,
			"Completing the last deployment should advance setup flow to review.")


func test_commit_setup_obstacle_execute_sixth_obstacle_advances_to_ship_deployment_expected() -> void:
	_mark_setup_package_state(false)
	var ship: ShipInstance = ShipInstance.new()
	ship.owner_player = 0
	ship.roster_entry_id = "ship-1"
	_state.get_player_state(0).ships.append(ship)
	_state.objectives[FleetSetupBootstrapper.KEY_OBSTACLES] = _five_obstacles()
	_refresh_setup_flow()
	var cmd: GameCommand = _deserialize_setup_command(
			"commit_setup_obstacle", 1, {
		"data_key": "station",
		"pos_x": 0.65,
		"pos_y": 0.5,
	})
	cmd.execute(_state)
	assert_eq(_state.interaction_flow.step_id,
			Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT,
			"The sixth obstacle should advance setup flow to ship deployment.")


func test_commit_setup_deployment_execute_ship_then_squadron_flow_expected() -> void:
	_mark_setup_package_state(false)
	var ship: ShipInstance = ShipInstance.new()
	ship.owner_player = 0
	ship.roster_entry_id = "ship-1"
	var squadron: SquadronInstance = SquadronInstance.new()
	squadron.owner_player = 0
	squadron.roster_entry_id = "sq-1"
	_state.get_player_state(0).ships.append(ship)
	_state.get_player_state(0).squadrons.append(squadron)
	_state.objectives[FleetSetupBootstrapper.KEY_OBSTACLES] = _six_obstacles()
	_refresh_setup_flow()
	var cmd: GameCommand = _deserialize_setup_command(
			"commit_setup_deployment", 0, {
		"owner_player": 0,
		"component_type": "ship",
		"roster_entry_id": "ship-1",
		"pos_x": 0.5,
		"pos_y": 0.75,
		"rotation_deg": 180.0,
		"speed": 2,
	})
	cmd.execute(_state)
	assert_eq(_state.interaction_flow.step_id,
			Constants.InteractionStep.SETUP_SQUADRON_DEPLOYMENT,
			"After ships are deployed, setup flow should advance to squadron deployment.")


func _mark_setup_package_state(is_complete: bool) -> void:
	_state.current_phase = Constants.GamePhase.SETUP
	_state.current_round = 0
	var setup_state: Dictionary = {}
	if is_complete:
		setup_state["status"] = StartRoundCommand.SETUP_STATUS_COMPLETE
	_state.objectives = {
		FleetSetupBootstrapper.KEY_SETUP_PACKAGE_HASH: "hash",
		FleetSetupBootstrapper.KEY_SETUP_STATE: {
			"player_display_names": ["Alex", "Blake"],
			"status": setup_state.get("status", ""),
		},
		FleetSetupBootstrapper.KEY_MAP: {
			"filename": "map_3x3_azure_v4.jpg",
		},
		FleetSetupBootstrapper.KEY_OBSTACLES: [],
		FleetSetupBootstrapper.KEY_DEPLOYMENTS: [],
	}
	_refresh_setup_flow()


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
	_refresh_setup_flow()


func _refresh_setup_flow() -> void:
	SetupInteractionFlowResolverScript.apply_to_state(_state)


func _five_obstacles() -> Array[Dictionary]:
	var obstacles: Array[Dictionary] = []
	for index: int in range(StartRoundCommand.STANDARD_OBSTACLE_COUNT - 1):
		obstacles.append(_obstacle_entry(
				OBSTACLE_KEYS[index],
				0.12 + float(index) * 0.16,
				0.16 if index % 2 == 0 else 0.84,
				1 if index % 2 == 0 else 0,
				index))
	return obstacles


func _obstacle_entry(data_key: String,
		pos_x: float,
		pos_y: float,
		placing_player: int,
		placement_order: int,
		rotation_deg: float = 0.0) -> Dictionary:
	return {
		"data_key": data_key,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"rotation_deg": rotation_deg,
		"placing_player": placing_player,
		"placement_order": placement_order,
	}


func _six_obstacles() -> Array[Dictionary]:
	var obstacles: Array[Dictionary] = []
	for index: int in range(StartRoundCommand.STANDARD_OBSTACLE_COUNT):
		obstacles.append(_obstacle_entry(
				OBSTACLE_KEYS[index],
				0.12 + float(index % 3) * 0.28,
				0.16 if index < 3 else 0.84,
				1 if index % 2 == 0 else 0,
				index))
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


func _deserialize_setup_command(command_type: String,
		player_index: int, payload: Dictionary) -> GameCommand:
	return GameCommand.deserialize({
		"type": command_type,
		"player": player_index,
		"sequence": - 1,
		"payload": payload,
	})
