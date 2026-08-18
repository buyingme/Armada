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


class LoadedEntityPanelCapture:
	extends UIPanelManager

	var card_ships: Array[ShipInstance] = []

	func add_ship_to_card_panel(ship: ShipInstance) -> void:
		card_ships.append(ship)


class LoadedEntityBoardCapture:
	extends GameBoard

	var spawned_ships: Array[ShipInstance] = []
	var spawned_squadrons: Array[SquadronInstance] = []

	func _ready() -> void:
		pass

	func setup_capture() -> void:
		_token_container = Node2D.new()
		add_child(_token_container)
		_panel_mgr = LoadedEntityPanelCapture.new()
		add_child(_panel_mgr)

	func _spawn_ship_token(_placement: TokenPlacement) -> ShipToken:
		var token: ShipToken = ShipToken.new()
		_token_container.add_child(token)
		return token

	func _spawn_squadron_token(_placement: TokenPlacement) -> SquadronToken:
		var token: SquadronToken = SquadronToken.new()
		_token_container.add_child(token)
		return token

	func capture_spawned_instances() -> void:
		for child: Node in _token_container.get_children():
			if child is ShipToken:
				spawned_ships.append((child as ShipToken).get_ship_instance())
			elif child is SquadronToken:
				spawned_squadrons.append(
						(child as SquadronToken).get_squadron_instance())


class DestroyedShipProjectionBoard:
	extends GameBoard

	func _ready() -> void:
		pass

	func setup_capture(instance: ShipInstance) -> ShipToken:
		_token_container = Node2D.new()
		add_child(_token_container)
		var token: ShipToken = ShipToken.new()
		token.bind_instance(instance)
		_token_container.add_child(token)
		_connect_board_damage_and_remote_signals()
		return token


class LiveSpatialBoard:
	extends GameBoard

	func _ready() -> void:
		pass

	func setup_capture() -> void:
		_token_container = Node2D.new()
		add_child(_token_container)

	func add_squadron(instance: SquadronInstance,
			at: Vector2) -> SquadronToken:
		var token := SquadronToken.new()
		token.position = at
		token._radius_px = GameScale.squadron_base_diameter_px * 0.5
		token.bind_instance(instance)
		_token_container.add_child(token)
		return token

	func add_ship(instance: ShipInstance, at: Vector2) -> ShipToken:
		var token := ShipToken.new()
		token.position = at
		token._half_w = 35.0
		token._half_l = 60.0
		token.bind_instance(instance)
		_token_container.add_child(token)
		return token


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
var _previous_replay_enabled: bool = false
var _previous_replay_seed: int = 0
var _previous_replay_connect_target: String = ""


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
	_previous_replay_enabled = ReplayDriver.enabled
	_previous_replay_seed = ReplayDriver.pending_replay_seed
	_previous_replay_connect_target = ReplayDriver._connect_target
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
	ReplayDriver.enabled = _previous_replay_enabled
	ReplayDriver.pending_replay_seed = _previous_replay_seed
	ReplayDriver._connect_target = _previous_replay_connect_target
	CommandProcessor.reset()


func test_bootstrap_or_load_board_state_spawns_network_pending_scenario() -> void:
	PlayMode.current_mode = PlayMode.Mode.NETWORK
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._receive_game_config(12345, LobbyState.SCENARIO_DEBUG_ID,
			MatchPlayerControlBinding.create_two_human().serialize())
	var board: ScenarioCaptureBoard = ScenarioCaptureBoard.new()
	autofree(board)

	board._bootstrap_or_load_board_state()

	assert_eq(board.spawned_scenario_id, LobbyState.SCENARIO_DEBUG_ID,
			"Network board spawn should use the scenario from pending game config.")
	assert_eq(GameManager.current_game_state.rng.initial_seed, 12345,
			"Normal network bootstrap should retain the host-selected seed.")


func test_network_replay_bootstrap_installs_exact_rng_and_consumes_seed() -> void:
	const REPLAY_SEED: int = 30671017
	PlayMode.current_mode = PlayMode.Mode.NETWORK
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._receive_game_config(
			REPLAY_SEED, LobbyState.SCENARIO_DEBUG_ID,
			MatchPlayerControlBinding.create_two_human().serialize())
	ReplayDriver.enabled = true
	ReplayDriver._connect_target = "127.0.0.1:7350"
	ReplayDriver.pending_replay_seed = REPLAY_SEED
	ReplayDriver.pending_replay_binding = \
			MatchPlayerControlBinding.create_two_human().serialize()

	GameManager.bootstrap_game(LobbyState.SCENARIO_LEARNING_ID)

	assert_not_null(GameManager.current_game_state,
			"Valid replay bootstrap should install a GameState.")
	assert_not_null(GameManager.current_game_state.rng,
			"Valid replay bootstrap should install authoritative RNG.")
	assert_eq(GameManager.current_game_state.rng.initial_seed, REPLAY_SEED,
			"GameState RNG must use the exact distributed replay seed.")
	assert_eq(GameManager.current_game_state.rng.serialize(),
			GameRng.new(REPLAY_SEED).serialize(),
			"Installed RNG must begin at the exact recorded initial state.")
	assert_eq(ReplayDriver.pending_replay_seed, 0,
			"Successful GameState installation should consume seed once.")


func test_network_replay_bootstrap_rejects_invalid_received_seed_config() -> void:
	const REPLAY_SEED: int = 30671017
	ReplayDriver.enabled = true
	ReplayDriver._connect_target = "127.0.0.1:7350"
	ReplayDriver.pending_replay_seed = REPLAY_SEED

	for invalid_config: Dictionary in [
		{},
		{"rng_seed": 0},
		{"rng_seed": REPLAY_SEED + 1},
	]:
		var validation: Dictionary = (
				GameManager._validate_network_replay_rng_config(invalid_config))
		assert_false(bool(validation.get("ok", true)),
				"Missing, zero, and mismatched peer seed must fail closed.")
	assert_eq(ReplayDriver.pending_replay_seed, REPLAY_SEED,
			"Rejected peer configuration must not consume accepted seed.")


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


func test_bug_006_destroyed_save_records_are_not_active_board_tokens() -> void:
	for filename: String in [
		"NEWLearningScenario_HotSeat_R3_Ship.json",
		"NEW_LearningScenario_Network_R3_Ship.json",
	]:
		var state: GameState = _load_bug_006_state(filename)
		assert_not_null(state, "%s should deserialize." % filename)
		if state == null:
			continue
		var expected_alive_squadrons: int = 0
		var expected_destroyed_squadrons: int = 0
		for player: PlayerState in state.player_states:
			for squadron: SquadronInstance in player.squadrons:
				if squadron.is_destroyed():
					expected_destroyed_squadrons += 1
				else:
					expected_alive_squadrons += 1
		var board: LoadedEntityBoardCapture = LoadedEntityBoardCapture.new()
		add_child_autofree(board)
		board.setup_capture()
		for player: PlayerState in state.player_states:
			board._spawn_loaded_tokens_for_player(player)
		board.capture_spawned_instances()

		assert_gt(expected_destroyed_squadrons, 0,
				"BUG-006 evidence must contain a destroyed squadron.")
		assert_eq(board.spawned_squadrons.size(), expected_alive_squadrons,
				"Only surviving squadrons should reconstruct as board pieces.")
		for squadron: SquadronInstance in board.spawned_squadrons:
			assert_false(squadron.is_destroyed(),
					"Active/selectable token projection must exclude destroyed records.")
		assert_eq(_destroyed_squadron_count(state.serialize()),
				expected_destroyed_squadrons,
				"Canonical serialization must retain destroyed squadron records.")


func test_bug_007_destroyed_records_do_not_enter_live_spatial_occupancy() \
		-> void:
	GameScale._load_scale_config()
	var state := GameState.new()
	state.initialize()
	state.install_match_player_control_binding(MatchPlayerControlBinding.create_hot_seat_human())
	var squadron_data: SquadronData = AssetLoader.load_squadron_data(
			"tie_fighter_squadron")
	var moving: SquadronInstance = SquadronInstance.create_from_data(
			"tie_fighter_squadron", squadron_data, 1)
	var living_blocker: SquadronInstance = SquadronInstance.create_from_data(
			"tie_fighter_squadron", squadron_data, 1)
	var destroyed_blocker: SquadronInstance = SquadronInstance.create_from_data(
			"tie_fighter_squadron", squadron_data, 1)
	destroyed_blocker.mark_destroyed()
	state.get_player_state(1).squadrons.append_array([
			moving, living_blocker, destroyed_blocker])

	var ship_data: ShipData = AssetLoader.load_ship_data("cr90_corvette_a")
	var living_ship: ShipInstance = ShipInstance.create_from_data(
			"cr90_corvette_a", ship_data, 2, 0)
	var destroyed_ship: ShipInstance = ShipInstance.create_from_data(
			"cr90_corvette_a", ship_data, 2, 0)
	destroyed_ship.mark_destroyed()
	state.get_player_state(0).ships.append_array([living_ship, destroyed_ship])

	var board := LiveSpatialBoard.new()
	add_child_autofree(board)
	board.setup_capture()
	var moving_token: SquadronToken = board.add_squadron(
			moving, Vector2(400.0, 400.0))
	board.add_squadron(living_blocker, Vector2(500.0, 400.0))
	board.add_squadron(destroyed_blocker, Vector2(600.0, 400.0))
	board.add_ship(living_ship, Vector2(500.0, 600.0))
	board.add_ship(destroyed_ship, Vector2(700.0, 600.0))

	var squadron_occupancy: Array = board._build_other_squad_circles(
			moving_token)
	var ship_occupancy: Array = board._build_other_ship_rects(moving_token)
	assert_eq(squadron_occupancy.size(), 1,
			"Only the living squadron may block live placement.")
	assert_eq((squadron_occupancy[0] as Dictionary)["position"],
			Vector2(500.0, 400.0))
	assert_eq(ship_occupancy.size(), 1,
			"Destroyed ships follow the same removed-from-play geometry rule.")
	assert_eq((ship_occupancy[0] as Dictionary)["position"],
			Vector2(500.0, 600.0))
	assert_true(destroyed_blocker.is_destroyed())
	assert_eq(_destroyed_squadron_count(state.serialize()), 1,
			"The filtered squadron remains in canonical serialized history.")
	var restored: GameState = GameState.deserialize(state.serialize())
	assert_not_null(restored)
	if restored != null:
		assert_true(restored.get_squadron(1, 2).is_destroyed(),
				"Save/load must retain destruction without restoring occupancy.")


func test_remote_lethal_hull_projection_removes_destroyed_ship_token() -> void:
	var data: ShipData = ShipData.new()
	data.hull = 1
	data.max_speed = 1
	data.command_value = 1
	data.navigation_chart = [[0]]
	data.shields = {"front": 0, "left": 0, "right": 0, "rear": 0}
	data.defense_tokens = []
	var instance: ShipInstance = ShipInstance.create_from_data(
			"remote_destroyed", data, 0, 1)
	instance.mark_destroyed()
	var board: DestroyedShipProjectionBoard = \
			DestroyedShipProjectionBoard.new()
	add_child_autofree(board)
	var token: ShipToken = board.setup_capture(instance)

	EventBus.ship_hull_changed.emit(instance, 0)
	await get_tree().create_timer(0.85).timeout

	assert_false(token.visible,
			"Defender peer should retire a canonically destroyed ship token "
			+ "without prediction or duplicate semantic destruction.")


func _load_bug_006_state(filename: String) -> GameState:
	for workflow: String in ["open", "in_progress", "verify", "closed"]:
		var path: String = "res://docs/qa/bugs/%s/BUG-006/%s" % [
				workflow, filename]
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var body: Dictionary = (parsed as Dictionary).get("state", {})
			var state: GameState = GameState.new()
			state.initialize()
			state.install_match_player_control_binding(MatchPlayerControlBinding.create_hot_seat_human())
			state.player_states.clear()
			for player: Variant in body.get("player_states", []):
				if player is Dictionary:
					state.player_states.append(PlayerState.deserialize(player))
			return state
	return null


func _destroyed_squadron_count(serialized_state: Dictionary) -> int:
	var count: int = 0
	for player: Variant in serialized_state.get("player_states", []):
		if not player is Dictionary:
			continue
		for squadron: Variant in (player as Dictionary).get("squadrons", []):
			if squadron is Dictionary \
					and bool((squadron as Dictionary).get("destroyed", false)):
				count += 1
	return count


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
	state.install_match_player_control_binding(MatchPlayerControlBinding.create_hot_seat_human())
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
