## Test: GameBoard Scenario Bootstrap
##
## Unit tests for the scenario id handoff between game bootstrap and
## scenario-token spawning.
extends GutTest


class ScenarioCaptureBoard:
	extends GameBoard

	var spawned_scenario_id: String = ""
	var loaded_state_spawned: bool = false

	func _spawn_learning_scenario_tokens(scenario_id: String) -> void:
		spawned_scenario_id = scenario_id

	func _spawn_tokens_from_loaded_state() -> void:
		loaded_state_spawned = true


class SetupPromptBoard:
	extends GameBoard

	var applied_perspective_player: int = -1

	func _ready() -> void:
		pass

	func setup_prompt_dependencies() -> void:
		_panel_mgr = UIPanelManager.new()
		_panel_mgr.name = "UIPanelManager"
		add_child(_panel_mgr)
		_panel_mgr.handoff_overlay = HandoffOverlay.new()
		_panel_mgr.handoff_overlay.name = "HandoffOverlay"
		_panel_mgr.add_child(_panel_mgr.handoff_overlay)

	func _apply_turn_perspective(player_index: int, _player_faction: int) -> void:
		applied_perspective_player = player_index


var _previous_game_state: GameState = null
var _previous_is_game_active: bool = false
var _previous_active_player: int = 0
var _previous_is_state_preloaded: bool = false
var _previous_scenario_id: String = ""
var _previous_next_scenario_id: String = ""
var _previous_next_setup_package: FleetSetupPackage = null
var _previous_play_mode: PlayMode.Mode = PlayMode.Mode.HOT_SEAT
var _previous_network_role: NetworkManager.Role = NetworkManager.Role.NONE
var _previous_local_player_index: int = -1
var _previous_pending_config: Dictionary = {}
var _previous_submitter: CommandSubmitter = null


func before_each() -> void:
	_previous_game_state = GameManager.current_game_state
	_previous_is_game_active = GameManager.is_game_active
	_previous_active_player = GameManager.active_player
	_previous_is_state_preloaded = GameManager.is_state_preloaded
	_previous_scenario_id = GameManager._scenario_id
	_previous_next_scenario_id = GameManager._next_scenario_id
	_previous_next_setup_package = GameManager._next_setup_package
	_previous_play_mode = PlayMode.current_mode
	_previous_network_role = NetworkManager.role
	_previous_local_player_index = NetworkManager._local_player_index
	_previous_pending_config = NetworkManager._pending_game_config.duplicate(true)
	_previous_submitter = GameManager.get_command_submitter()
	GameManager.is_state_preloaded = false
	GameManager._next_scenario_id = ""
	GameManager._next_setup_package = null
	NetworkManager._local_player_index = -1


func after_each() -> void:
	GameManager.current_game_state = _previous_game_state
	GameManager.is_game_active = _previous_is_game_active
	GameManager.active_player = _previous_active_player
	GameManager.is_state_preloaded = _previous_is_state_preloaded
	GameManager._scenario_id = _previous_scenario_id
	GameManager._next_scenario_id = _previous_next_scenario_id
	GameManager._next_setup_package = _previous_next_setup_package
	PlayMode.current_mode = _previous_play_mode
	NetworkManager.role = _previous_network_role
	NetworkManager._local_player_index = _previous_local_player_index
	NetworkManager._pending_game_config = _previous_pending_config.duplicate(true)
	GameManager.set_command_submitter(_previous_submitter)
	CommandProcessor.reset()


func test_bootstrap_or_load_board_state_spawns_network_pending_scenario() -> void:
	PlayMode.current_mode = PlayMode.Mode.NETWORK
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._receive_game_config(12345, LobbyState.SCENARIO_DEBUG_ID)
	var board: ScenarioCaptureBoard = ScenarioCaptureBoard.new()
	autofree(board)

	board._bootstrap_or_load_board_state()

	assert_eq(board.spawned_scenario_id, LobbyState.SCENARIO_DEBUG_ID,
			"Network board spawn should use the scenario from pending game config.")


func test_bootstrap_or_load_board_state_spawns_pending_setup_package() -> void:
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT
	NetworkManager.role = NetworkManager.Role.NONE
	GameManager.set_command_submitter(LocalCommandSubmitter.new())
	GameManager.set_next_setup_package(_setup_package())
	var board: ScenarioCaptureBoard = ScenarioCaptureBoard.new()
	autofree(board)

	board._bootstrap_or_load_board_state()

	assert_true(board.loaded_state_spawned,
		"Setup-package bootstrap should reuse loaded-state token spawning.")
	assert_eq(board.spawned_scenario_id, "",
		"Setup-package bootstrap should not spawn scenario JSON tokens.")
	assert_eq(GameManager.get_scenario_id(), FleetSetupPackageBuilder.DEFAULT_SCENARIO_ID,
		"Setup-package bootstrap should install the package scenario id.")


func test_setup_turn_prompt_ship_deployment_shows_deploy_handoff_expected() -> void:
	GameManager.current_game_state = _setup_prompt_state(
			Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT, 0)
	var board: SetupPromptBoard = SetupPromptBoard.new()
	add_child_autofree(board)
	board.setup_prompt_dependencies()
	await get_tree().process_frame

	board._on_setup_turn_prompt_requested(0, "Alex")

	assert_eq(board.applied_perspective_player, 0,
			"Setup prompt should apply the active setup player's perspective.")
	assert_eq(_handoff_phase_label(board), "Deploy your fleet",
			"Ship deployment prompt should use the deployment handoff phase text.")


func test_setup_turn_prompt_obstacle_placement_keeps_setup_handoff_expected() -> void:
	GameManager.current_game_state = _setup_prompt_state(
			Constants.InteractionStep.SETUP_OBSTACLE_PLACEMENT, 1)
	var board: SetupPromptBoard = SetupPromptBoard.new()
	add_child_autofree(board)
	board.setup_prompt_dependencies()
	await get_tree().process_frame

	board._on_setup_turn_prompt_requested(1, "Bianca")

	assert_eq(board.applied_perspective_player, 1,
			"Setup obstacle prompt should apply the active setup player's perspective.")
	assert_eq(_handoff_phase_label(board), "Setup",
			"Obstacle placement prompt should keep the generic setup phase text.")


func _setup_package() -> FleetSetupPackage:
	return FleetSetupPackage.deserialize({
		"format_version": 1,
		"kind": FleetSetupPackage.KIND,
		"scenario_id": FleetSetupPackageBuilder.DEFAULT_SCENARIO_ID,
		"point_format": {"id": "STANDARD_400", "limit": 400},
		"map": FleetBuilderOptions.map_payload("map_3x6_distant-planet_v4.jpg"),
		"first_player": 0,
		"players": [
			_player_entry(0, "REBEL_ALLIANCE", _roster(
					"rebel-fleet", "REBEL_ALLIANCE", "cr90_corvette_a")),
			_player_entry(1, "GALACTIC_EMPIRE", _roster("imperial-fleet",
					"GALACTIC_EMPIRE", "victory_ii_class_star_destroyer")),
		],
		"selected_objective": {},
		"obstacles": [],
		"deployments": [],
		"setup_state": {},
	})


func _setup_prompt_state(
		step_id: Constants.InteractionStep,
		controller_player: int) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SETUP
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SETUP,
			step_id,
			controller_player,
			Constants.Visibility.ALL,
			{})
	return state


func _handoff_phase_label(board: SetupPromptBoard) -> String:
	var label: Label = board._panel_mgr.handoff_overlay.find_child(
			"PhaseLabel", true, false) as Label
	if label == null:
		return ""
	return label.text


func _player_entry(player_index: int, faction: String, roster: Dictionary) -> Dictionary:
	return {
		"player_index": player_index,
		"display_name": _display_name_for_player(player_index),
		"faction": faction,
		"roster": roster,
	}


func _display_name_for_player(player_index: int) -> String:
	if player_index == 0:
		return "Player One"
	return "Player Two"


func _roster(fleet_id: String, faction: String, ship_key: String) -> Dictionary:
	return {
		"format_version": 1,
		"kind": FleetRoster.KIND,
		"fleet_id": fleet_id,
		"name": fleet_id,
		"faction": faction,
		"point_format": {"id": "STANDARD_400", "limit": 400},
		"map": FleetBuilderOptions.map_payload("map_3x6_distant-planet_v4.jpg"),
		"ships": [{"entry_id": "%s-ship" % fleet_id, "data_key": ship_key,
			"upgrades": []}],
		"squadrons": [],
		"objectives": {},
	}
