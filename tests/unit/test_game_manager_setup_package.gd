## Test: GameManager Setup Package Bootstrap
##
## Unit tests for FB13 setup-package game start orchestration.
extends GutTest


var _previous_game_state: GameState = null
var _previous_is_game_active: bool = false
var _previous_active_player: int = 0
var _previous_is_state_preloaded: bool = false
var _previous_scenario_id: String = ""
var _previous_next_scenario_id: String = ""
var _previous_next_setup_package: FleetSetupPackage = null
var _previous_fixed_commands: bool = false
var _previous_mode: PlayMode.Mode = PlayMode.Mode.HOT_SEAT
var _previous_role: NetworkManager.Role = NetworkManager.Role.NONE
var _previous_submitter: CommandSubmitter = null


func before_each() -> void:
	_previous_game_state = GameManager.current_game_state
	_previous_is_game_active = GameManager.is_game_active
	_previous_active_player = GameManager.active_player
	_previous_is_state_preloaded = GameManager.is_state_preloaded
	_previous_scenario_id = GameManager._scenario_id
	_previous_next_scenario_id = GameManager._next_scenario_id
	_previous_next_setup_package = GameManager._next_setup_package
	_previous_fixed_commands = GameManager.fixed_commands_applied
	_previous_mode = PlayMode.current_mode
	_previous_role = NetworkManager.role
	_previous_submitter = GameManager.get_command_submitter()
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT
	NetworkManager.role = NetworkManager.Role.NONE
	GameManager.set_command_submitter(LocalCommandSubmitter.new())
	CommandProcessor.reset()


func after_each() -> void:
	GameManager.current_game_state = _previous_game_state
	GameManager.is_game_active = _previous_is_game_active
	GameManager.active_player = _previous_active_player
	GameManager.is_state_preloaded = _previous_is_state_preloaded
	GameManager._scenario_id = _previous_scenario_id
	GameManager._next_scenario_id = _previous_next_scenario_id
	GameManager._next_setup_package = _previous_next_setup_package
	GameManager.fixed_commands_applied = _previous_fixed_commands
	PlayMode.current_mode = _previous_mode
	NetworkManager.role = _previous_role
	GameManager.set_command_submitter(_previous_submitter)
	CommandProcessor.reset()


func test_start_new_game_from_setup_package_installs_state_expected() -> void:
	var package: FleetSetupPackage = _package_with_deployments()

	var result: Dictionary = GameManager.start_new_game_from_setup_package(
			package, {"rng_seed": 2468})
	var state: GameState = GameManager.current_game_state
	var rebel_ship: ShipInstance = state.get_ship(0, 0)

	assert_true(result.get("ok", false), "Setup package should start a game")
	assert_true(GameManager.is_game_active,
		"GameManager should mark setup-package game active")
	assert_true(GameManager.is_state_preloaded,
		"Setup-package games should use the preloaded board spawn path")
	assert_eq(GameManager.get_scenario_id(), FleetSetupPackageBuilder.DEFAULT_SCENARIO_ID,
		"Scenario id should come from the setup package")
	assert_eq(state.current_round, 0, "GameManager should wait in setup")
	assert_eq(state.current_phase, Constants.GamePhase.SETUP,
		"GameManager should keep setup-package games in SETUP")
	assert_eq(GameManager.active_player, 1,
		"Active player should start with package initiative")
	assert_eq(state.objectives.get(FleetSetupBootstrapper.KEY_SETUP_PACKAGE_HASH, ""),
		package.canonical_hash(), "Live state should carry setup package hash")
	assert_almost_eq(rebel_ship.pos_y, 0.82, 0.001,
		"Live ship state should carry deployment position")
	assert_eq((state.objectives.get(
			FleetSetupBootstrapper.KEY_DEPLOYMENTS, []) as Array).size(), 2,
		"Live state should carry setup deployment payloads")


func test_complete_setup_and_start_round_enters_command_expected() -> void:
	var package: FleetSetupPackage = _package_with_completed_placements()
	GameManager.start_new_game_from_setup_package(package, {"rng_seed": 2468})

	var result: Dictionary = GameManager.complete_setup_and_start_round()
	var setup_state: Dictionary = GameManager.current_game_state.objectives.get(
			FleetSetupBootstrapper.KEY_SETUP_STATE, {}) as Dictionary

	assert_eq(result.get("new_round", -1), 1,
		"Complete setup should accept fully placed setup payloads")
	assert_eq(GameManager.current_game_state.current_round, 1,
		"Completing setup should start round one")
	assert_eq(GameManager.current_game_state.current_phase, Constants.GamePhase.COMMAND,
		"Completing setup should enter the Command Phase")
	assert_eq(setup_state.get("status", ""),
			StartRoundCommand.SETUP_STATUS_COMPLETE,
		"Setup state should record completion before round one")


func test_start_new_game_from_setup_package_client_mode_waits_expected() -> void:
	var package: FleetSetupPackage = _package_with_deployments()

	var result: Dictionary = GameManager.start_new_game_from_setup_package(
			package, {"rng_seed": 2468, "client_mode": true})
	var state: GameState = GameManager.current_game_state

	assert_true(result.get("ok", false), "Client package bootstrap should pass")
	assert_eq(state.current_round, 0,
		"Client mode should wait for the server StartRoundCommand")
	assert_eq(state.current_phase, Constants.GamePhase.SETUP,
		"Client mode should remain in SETUP until the server command arrives")
	assert_true(GameManager.is_state_preloaded,
		"Client package bootstrap should still use loaded-state board spawn")


func _package_with_deployments() -> FleetSetupPackage:
	return FleetSetupPackage.deserialize({
		"format_version": 1,
		"kind": FleetSetupPackage.KIND,
		"scenario_id": FleetSetupPackageBuilder.DEFAULT_SCENARIO_ID,
		"point_format": {"id": "STANDARD_400", "limit": 400},
		"map": FleetBuilderOptions.map_payload("map_3x6_distant-planet_v4.jpg"),
		"first_player": 1,
		"players": [
			_player_entry(0, "REBEL_ALLIANCE", _rebel_roster()),
			_player_entry(1, "GALACTIC_EMPIRE", _imperial_roster()),
		],
		"selected_objective": {"data_key": "obj_ass_opening_salvo"},
		"obstacles": [],
		"deployments": _deployments(),
		"setup_state": {},
	})


func _package_with_completed_placements() -> FleetSetupPackage:
	var package: FleetSetupPackage = _package_with_deployments()
	package.obstacles = _six_obstacles()
	return package


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


func _deployments() -> Array[Dictionary]:
	var deployments: Array[Dictionary] = []
	deployments.append(_deployment("rebel-ship-1", 0, 0.52, 0.82, 0.0))
	deployments.append(_deployment("imperial-ship-1", 1, 0.48, 0.18, 180.0))
	return deployments


func _deployment(entry_id: String, owner_player: int,
		pos_x: float, pos_y: float, rotation_deg: float) -> Dictionary:
	return {
		"owner_player": owner_player,
		"component_type": "ship",
		"roster_entry_id": entry_id,
		"speed": 2,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"rotation_deg": rotation_deg,
	}


func _player_entry(player_index: int, faction: String, roster: Dictionary) -> Dictionary:
	return {"player_index": player_index, "faction": faction, "roster": roster}


func _rebel_roster() -> Dictionary:
	return _roster("rebel-fleet", "REBEL_ALLIANCE", [
		_ship_entry("rebel-ship-1", "cr90_corvette_a"),
	])


func _imperial_roster() -> Dictionary:
	return _roster("imperial-fleet", "GALACTIC_EMPIRE", [
		_ship_entry("imperial-ship-1", "victory_ii_class_star_destroyer"),
	])


func _roster(fleet_id: String, faction: String,
		ships: Array[Dictionary]) -> Dictionary:
	return {
		"format_version": 1,
		"kind": FleetRoster.KIND,
		"fleet_id": fleet_id,
		"name": fleet_id,
		"faction": faction,
		"point_format": {"id": "STANDARD_400", "limit": 400},
		"map": FleetBuilderOptions.map_payload("map_3x6_distant-planet_v4.jpg"),
		"ships": ships,
		"squadrons": [],
		"objectives": {},
	}


func _ship_entry(entry_id: String, data_key: String) -> Dictionary:
	return {"entry_id": entry_id, "data_key": data_key, "upgrades": []}
