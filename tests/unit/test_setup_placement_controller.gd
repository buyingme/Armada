## Unit tests for [SetupPlacementController].
##
## Covers the projected obstacle-placement modal state and preview drop /
## confirm flow introduced for FB14F without depending on the full game-board
## scene.
extends GutTest


const MAP_3X3: String = "map_3x3_azure_v4.jpg"
const OBSTACLE_KEYS: Array[String] = [
	"asteroid_1",
	"asteroid_2",
	"asteroid_3",
	"debris_1",
	"debris_2",
	"station",
]
const SETUP_INTERACTION_FLOW_RESOLVER_SCRIPT: GDScript = preload(
		"res://src/core/setup/setup_interaction_flow_resolver.gd")
const SETUP_PLACEMENT_CONTROLLER_SCRIPT: GDScript = preload(
		"res://src/scenes/game_board/setup_placement_controller.gd")

var _controller = null
var _board: Node2D = null
var _token_container: Node2D = null
var _saved_game_state: GameState = null
var _saved_local_player_index: int = -1
var _prompt_calls: Array[Dictionary] = []


func before_each() -> void:
	_saved_game_state = GameManager.current_game_state
	_saved_local_player_index = NetworkManager._local_player_index
	NetworkManager._local_player_index = -1
	_board = Node2D.new()
	_token_container = Node2D.new()
	_board.add_child(_token_container)
	add_child_autofree(_board)
	_controller = SETUP_PLACEMENT_CONTROLLER_SCRIPT.new()
	_controller.setup_turn_prompt_requested.connect(_on_setup_turn_prompt_requested)
	add_child_autofree(_controller)


func after_each() -> void:
	GameManager.current_game_state = _saved_game_state
	NetworkManager._local_player_index = _saved_local_player_index
	_prompt_calls.clear()
	_controller = null
	_board = null
	_token_container = null


func test_initialize_bottom_centre_modal_and_prompt_expected() -> void:
	GameManager.current_game_state = _make_setup_state(0, [])

	_controller.initialize(_board, _token_container, TokenMover.new())
	await get_tree().process_frame

	var modal: Control = _modal()
	var scroll: ScrollContainer = modal.find_child(
			"ObstacleListScroll", true, false) as ScrollContainer
	var title: Label = modal.find_child("TitleLabel", true, false) as Label

	assert_true(modal.visible,
			"Setup obstacle modal should be visible during obstacle placement.")
	assert_almost_eq(modal.anchor_left, 0.5, 0.001,
			"Obstacle modal should be anchored to the horizontal centre.")
	assert_almost_eq(modal.anchor_bottom, 1.0, 0.001,
			"Obstacle modal should be anchored to the bottom edge.")
	assert_not_null(scroll,
			"Obstacle modal should keep its obstacle list inside a scroll container.")
	assert_eq(title.text, "Alex place obstacle",
			"Obstacle modal title should use the projected controller display name.")
	assert_eq(_prompt_calls.size(), 1,
			"Initial obstacle setup should emit one hot-seat setup prompt.")
	assert_true(_board.has_node("SetupAreaOverlay"),
			"Setup controller should install the board setup overlay.")
	assert_true((_board.get_node("SetupAreaOverlay") as Node2D).visible,
			"Setup overlay should be visible during obstacle placement.")


func test_refresh_from_state_passive_peer_disables_obstacle_buttons_expected() -> void:
	NetworkManager._local_player_index = 1
	GameManager.current_game_state = _make_setup_state(0, [_placed_obstacle("asteroid_1")])

	_controller.initialize(_board, _token_container, TokenMover.new())
	await get_tree().process_frame

	var modal: Control = _modal()
	var prompt: Label = modal.find_child("PromptLabel", true, false) as Label
	var placed_button: Button = modal.find_child(
			"ObstacleButton_asteroid_1", true, false) as Button
	var remaining_button: Button = modal.find_child(
			"ObstacleButton_asteroid_2", true, false) as Button

	assert_eq(_token_container.get_child_count(), 1,
			"Passive peer should still see committed obstacle tokens.")
	assert_true(placed_button.disabled,
			"Placed obstacles should stay disabled in the obstacle modal.")
	assert_true(remaining_button.disabled,
			"Passive peers should not gain obstacle placement controls.")
	assert_true(prompt.text.contains("Waiting for Alex"),
			"Passive peer prompt should identify the active placer by display name.")


func test_try_handle_rotate_input_preview_rotates_obstacle_expected() -> void:
	GameManager.current_game_state = _make_setup_state(0, [])

	_controller.initialize(_board, _token_container, TokenMover.new())
	await get_tree().process_frame
	(_modal().find_child("ObstacleButton_asteroid_1", true, false) as Button).pressed.emit()

	var preview: Node2D = _token_container.get_child(0) as Node2D
	var event: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
	event.factor = 1.5
	var initial_rotation: float = preview.rotation

	var handled: bool = _controller.try_handle_rotate_input(event)

	assert_true(handled,
			"Magnify rotation should be consumed by the setup preview when active.")
	assert_ne(preview.rotation, initial_rotation,
			"Obstacle preview rotation should follow the debug-equivalent rotate input.")


func test_obstacle_preview_requires_drop_then_confirm_expected() -> void:
	GameManager.current_game_state = _make_setup_state(0, [])

	_controller.initialize(_board, _token_container, TokenMover.new())
	await get_tree().process_frame
	(_modal().find_child("ObstacleButton_asteroid_1", true, false) as Button).pressed.emit()

	var confirm_button: Button = _modal().find_child(
			"ConfirmPlacementButton", true, false) as Button
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true

	assert_true(confirm_button.disabled,
			"Confirm button should stay disabled while the preview is still moving.")
	assert_true(_controller.try_handle_input(click),
			"A first board click should drop the live obstacle preview without committing.")
	await get_tree().process_frame
	assert_false(confirm_button.disabled,
			"Confirm button should enable after the preview has been dropped.")

	var preview: Node = _token_container.get_child(0)
	preview.emit_signal("token_clicked", preview)
	await get_tree().process_frame

	assert_true(confirm_button.disabled,
			"Clicking the dropped preview should resume move mode and disable confirm again.")


func test_initialize_ship_deployment_modal_lists_remaining_ship_expected() -> void:
	var ship: ShipInstance = _add_ship(0, "ship_alpha", "cr90_corvette_a")
	GameManager.current_game_state = _make_deployment_state([ship], [], [])
	_add_ship_token(ship)

	_controller.initialize(_board, _token_container, TokenMover.new())
	await get_tree().process_frame

	var modal: Control = _modal()
	var title: Label = modal.find_child("TitleLabel", true, false) as Label
	var pending_label: Label = modal.find_child("PendingLabel", true, false) as Label
	var button: Button = modal.find_child(
			"DeploymentButton_0_ship_ship_alpha", true, false) as Button

	assert_eq(title.text, "Deploy your fleet Alex",
			"Ship deployment title should use the active player's display name.")
	assert_true(pending_label.text.contains("Select a remaining unit"),
			"Ship deployment should instruct the player to choose a remaining unit.")
	assert_not_null(button,
			"Ship deployment should list the remaining ship in the setup modal.")
	assert_eq(_prompt_calls.size(), 1,
			"Ship deployment should emit a shared-screen handoff prompt.")


func test_initialize_ship_deployment_modal_hides_other_players_remaining_ships_expected() -> void:
	var rebel_ship: ShipInstance = _add_ship(0, "ship_alpha", "cr90_corvette_a")
	var imperial_ship: ShipInstance = _add_ship(1, "ship_beta", "victory_ii_class_star_destroyer")
	GameManager.current_game_state = _make_deployment_state([rebel_ship, imperial_ship], [], [])
	_add_ship_token(rebel_ship)
	_add_ship_token(imperial_ship)

	_controller.initialize(_board, _token_container, TokenMover.new())
	await get_tree().process_frame

	assert_not_null(_modal().find_child("DeploymentButton_0_ship_ship_alpha", true, false),
			"The active player's remaining ship should appear in the deployment list.")
	assert_null(_modal().find_child("DeploymentButton_1_ship_ship_beta", true, false),
			"The inactive player's remaining ship should not appear in the deployment list.")


func test_select_ship_deployment_enables_speed_selector_expected() -> void:
	var ship: ShipInstance = _add_ship(0, "ship_alpha", "cr90_corvette_a")
	GameManager.current_game_state = _make_deployment_state([ship], [], [])
	_add_ship_token(ship)

	_controller.initialize(_board, _token_container, TokenMover.new())
	await get_tree().process_frame
	(_modal().find_child("DeploymentButton_0_ship_ship_alpha", true, false) as Button).pressed.emit()
	await get_tree().process_frame

	var speed_button: Button = _modal().find_child("SpeedButton_1", true, false) as Button
	var confirm_button: Button = _modal().find_child(
			"ConfirmPlacementButton", true, false) as Button
	var pending_label: Label = _modal().find_child("PendingLabel", true, false) as Label

	assert_true((
			_modal().find_child("SpeedSelectorRow", true, false) as HBoxContainer).visible,
			"Selecting a ship should reveal the setup speed selector.")
	assert_false(speed_button.disabled,
			"Legal ship speeds should be selectable in the deployment modal.")
	assert_false(confirm_button.disabled,
			"Selected ships with a legal setup speed should be confirmable.")
	assert_true(pending_label.text.contains("Selected ship"),
			"Deployment modal should acknowledge the currently selected ship.")


func test_passive_peer_hides_undeployed_tokens_during_deployment_expected() -> void:
	NetworkManager._local_player_index = 1
	var ship: ShipInstance = _add_ship(0, "ship_alpha", "cr90_corvette_a")
	GameManager.current_game_state = _make_deployment_state([ship], [], [])
	var token: ShipToken = _add_ship_token(ship)

	_controller.initialize(_board, _token_container, TokenMover.new())
	await get_tree().process_frame

	var prompt: Label = _modal().find_child("PromptLabel", true, false) as Label
	assert_false(token.visible,
			"Passive peers should not see undeployed setup tokens during deployment.")
	assert_true(prompt.text.contains("Waiting for Alex"),
			"Passive deployment prompt should identify the active deployment player.")


func test_squadron_pick_pending_text_tracks_partial_batch_expected() -> void:
	var rebel_ship: ShipInstance = _add_ship(0, "ship_alpha", "cr90_corvette_a")
	var imperial_ship: ShipInstance = _add_ship(1, "ship_beta", "victory_ii_class_star_destroyer")
	var first_squadron: SquadronInstance = _add_squadron(0, "sq_alpha", "x_wing_squadron")
	var second_squadron: SquadronInstance = _add_squadron(0, "sq_beta", "x_wing_squadron")
	GameManager.current_game_state = _make_deployment_state(
			[rebel_ship, imperial_ship],
			[first_squadron, second_squadron],
			[
				_deployment(0, "ship", "ship_alpha", 0.48, 0.88),
				_deployment(1, "ship", "ship_beta", 0.48, 0.12),
				_deployment(0, "squadron", "sq_alpha", 0.45, 0.82),
			])
	_add_squadron_token(first_squadron)
	_add_squadron_token(second_squadron)

	_controller.initialize(_board, _token_container, TokenMover.new())
	await get_tree().process_frame

	var pending_label: Label = _modal().find_child("PendingLabel", true, false) as Label
	assert_true(pending_label.text.contains("1/2 committed"),
			"Partial squadron picks should show progress toward the required batch size.")


func test_squadron_deployment_modal_hides_other_players_remaining_squadrons_expected() -> void:
	var rebel_ship: ShipInstance = _add_ship(0, "ship_alpha", "cr90_corvette_a")
	var imperial_ship: ShipInstance = _add_ship(1, "ship_beta", "victory_ii_class_star_destroyer")
	var rebel_squadron: SquadronInstance = _add_squadron(0, "sq_alpha", "x_wing_squadron")
	var imperial_squadron: SquadronInstance = _add_squadron(1, "sq_beta", "tie_fighter_squadron")
	GameManager.current_game_state = _make_deployment_state(
			[rebel_ship, imperial_ship],
			[rebel_squadron, imperial_squadron],
			[
				_deployment(0, "ship", "ship_alpha", 0.48, 0.88),
				_deployment(1, "ship", "ship_beta", 0.48, 0.12),
			])
	_add_squadron_token(rebel_squadron)
	_add_squadron_token(imperial_squadron)

	_controller.initialize(_board, _token_container, TokenMover.new())
	await get_tree().process_frame

	assert_not_null(_modal().find_child("DeploymentButton_0_squadron_sq_alpha", true, false),
			"The active player's remaining squadron should appear in the deployment list.")
	assert_null(_modal().find_child("DeploymentButton_1_squadron_sq_beta", true, false),
			"The inactive player's remaining squadron should not appear in the deployment list.")


func test_mixed_deployment_modal_shows_active_players_ship_and_squadrons_expected() -> void:
	var first_ship: ShipInstance = _add_ship(0, "ship_alpha", "cr90_corvette_a")
	var second_ship: ShipInstance = _add_ship(0, "ship_beta", "cr90_corvette_a")
	var enemy_ship: ShipInstance = _add_ship(1, "ship_gamma", "victory_ii_class_star_destroyer")
	var first_squadron: SquadronInstance = _add_squadron(0, "sq_alpha", "x_wing_squadron")
	var second_squadron: SquadronInstance = _add_squadron(0, "sq_beta", "x_wing_squadron")
	GameManager.current_game_state = _make_deployment_state(
			[first_ship, second_ship, enemy_ship],
			[first_squadron, second_squadron],
			[
				_deployment(0, "ship", "ship_alpha", 0.48, 0.88),
				_deployment(1, "ship", "ship_gamma", 0.48, 0.12),
			])
	_add_ship_token(second_ship)
	_add_squadron_token(first_squadron)
	_add_squadron_token(second_squadron)

	_controller.initialize(_board, _token_container, TokenMover.new())
	await get_tree().process_frame

	var prompt: Label = _modal().find_child("PromptLabel", true, false) as Label
	assert_not_null(_modal().find_child("DeploymentButton_0_ship_ship_beta", true, false),
			"Mixed deployment should still list the active player's remaining ship.")
	assert_not_null(_modal().find_child("DeploymentButton_0_squadron_sq_alpha", true, false),
			"Mixed deployment should also list the active player's eligible squadron pick.")
	assert_true(prompt.text.contains("ship or eligible squadron pick"),
			"Mixed deployment prompt should explain that both ships and squadrons are legal picks.")


func test_refresh_from_state_removes_committed_deployment_button_expected() -> void:
	var first_ship: ShipInstance = _add_ship(0, "ship_alpha", "cr90_corvette_a")
	var second_ship: ShipInstance = _add_ship(0, "ship_beta", "cr90_corvette_a")
	GameManager.current_game_state = _make_deployment_state([first_ship, second_ship], [], [])
	_add_ship_token(first_ship)
	_add_ship_token(second_ship)

	_controller.initialize(_board, _token_container, TokenMover.new())
	await get_tree().process_frame
	assert_not_null(_modal().find_child("DeploymentButton_0_ship_ship_alpha", true, false),
			"The deployment button should exist before the ship is committed.")

	GameManager.current_game_state.objectives[FleetSetupBootstrapper.KEY_DEPLOYMENTS] = [
		_deployment(0, "ship", "ship_alpha", 0.48, 0.88),
	]
	SETUP_INTERACTION_FLOW_RESOLVER_SCRIPT.apply_to_state(GameManager.current_game_state)
	_controller.refresh_from_state()
	await get_tree().process_frame

	assert_null(_modal().find_child("DeploymentButton_0_ship_ship_alpha", true, false),
			"Committed deployment buttons should be removed from the setup modal after refresh.")
	assert_not_null(_modal().find_child("DeploymentButton_0_ship_ship_beta", true, false),
			"Remaining deployable ships should stay listed after a different ship is committed.")


func test_try_handle_ship_click_committed_token_rejected_expected() -> void:
	var ship: ShipInstance = _add_ship(0, "ship_alpha", "cr90_corvette_a")
	GameManager.current_game_state = _make_deployment_state(
			[ship],
			[],
			[_deployment(0, "ship", "ship_alpha", 0.48, 0.88)])
	var token: ShipToken = _add_ship_token(ship)

	_controller.initialize(_board, _token_container, TokenMover.new())
	await get_tree().process_frame

	assert_false(_controller.try_handle_ship_click(token),
			"Committed ships should stay visible but must not be selectable for redeployment.")


func _modal() -> Control:
	return _controller.get_node("SetupPlacementLayer/SetupPlacementModal") as Control


func _make_setup_state(controller_player: int,
		obstacles: Array[Dictionary]) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SETUP
	state.current_round = 0
	state.initiative_player = controller_player if obstacles.size() % 2 == 1 \
			else 1 - controller_player
	state.objectives = {
		FleetSetupBootstrapper.KEY_SETUP_PACKAGE_HASH: "hash",
		FleetSetupBootstrapper.KEY_SETUP_STATE: {
			"player_display_names": ["Alex", "Blake"],
		},
		FleetSetupBootstrapper.KEY_OBSTACLES: obstacles,
		FleetSetupBootstrapper.KEY_DEPLOYMENTS: [],
		FleetSetupBootstrapper.KEY_MAP: {"filename": MAP_3X3},
	}
	SETUP_INTERACTION_FLOW_RESOLVER_SCRIPT.apply_to_state(state)
	return state


func _make_deployment_state(ships: Array[ShipInstance],
		squadrons: Array[SquadronInstance],
		deployments: Array[Dictionary]) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SETUP
	state.current_round = 0
	state.initiative_player = 0
	for ship: ShipInstance in ships:
		state.get_player_state(ship.owner_player).ships.append(ship)
	for squadron: SquadronInstance in squadrons:
		state.get_player_state(squadron.owner_player).squadrons.append(squadron)
	state.objectives = {
		FleetSetupBootstrapper.KEY_SETUP_PACKAGE_HASH: "hash",
		FleetSetupBootstrapper.KEY_SETUP_STATE: {
			"player_display_names": ["Alex", "Blake"],
		},
		FleetSetupBootstrapper.KEY_OBSTACLES: _six_obstacles(),
		FleetSetupBootstrapper.KEY_DEPLOYMENTS: deployments,
		FleetSetupBootstrapper.KEY_MAP: {"filename": MAP_3X3},
	}
	SETUP_INTERACTION_FLOW_RESOLVER_SCRIPT.apply_to_state(state)
	return state


func _placed_obstacle(data_key: String) -> Dictionary:
	return {
		"data_key": data_key,
		"pos_x": 0.5,
		"pos_y": 0.5,
		"rotation_deg": 0.0,
	}


func _deployment(owner_player: int,
		component_type: String,
		roster_entry_id: String,
		pos_x: float,
		pos_y: float) -> Dictionary:
	return {
		"owner_player": owner_player,
		"component_type": component_type,
		"roster_entry_id": roster_entry_id,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"rotation_deg": 0.0,
	}


func _six_obstacles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for obstacle_key: String in OBSTACLE_KEYS:
		result.append(_placed_obstacle(obstacle_key))
	return result


func _add_ship(owner_player: int,
		roster_entry_id: String,
		data_key: String) -> ShipInstance:
	var ship: ShipInstance = ShipInstance.new()
	ship.owner_player = owner_player
	ship.roster_entry_id = roster_entry_id
	ship.data_key = data_key
	ship.ship_data = AssetLoader.load_ship_data(data_key)
	ship.current_speed = FleetRosterSetupHelper.DEFAULT_DEPLOYMENT_SPEED
	ship.pos_x = 0.5
	ship.pos_y = 0.5
	return ship


func _add_squadron(owner_player: int,
		roster_entry_id: String,
		data_key: String) -> SquadronInstance:
	var squadron: SquadronInstance = SquadronInstance.new()
	squadron.owner_player = owner_player
	squadron.roster_entry_id = roster_entry_id
	squadron.data_key = data_key
	squadron.squadron_data = AssetLoader.load_squadron_data(data_key)
	squadron.pos_x = 0.5
	squadron.pos_y = 0.5
	return squadron


func _add_ship_token(ship: ShipInstance) -> ShipToken:
	var token: ShipToken = ShipToken.new()
	token.setup(TokenPlacement.new(
			ship.data_key,
			true,
			state_faction(ship.owner_player),
			ship.pos_x,
			ship.pos_y,
			deg_to_rad(ship.rotation_deg),
			ship.ship_data.ship_size))
	token.bind_instance(ship)
	_token_container.add_child(token)
	return token


func _add_squadron_token(squadron: SquadronInstance) -> SquadronToken:
	var token: SquadronToken = SquadronToken.new()
	token.setup(TokenPlacement.new(
			squadron.data_key,
			false,
			state_faction(squadron.owner_player),
			squadron.pos_x,
			squadron.pos_y,
			deg_to_rad(squadron.rotation_deg)))
	token.bind_instance(squadron)
	_token_container.add_child(token)
	return token


func state_faction(player_index: int) -> Constants.Faction:
	if player_index == 1:
		return Constants.Faction.GALACTIC_EMPIRE
	return Constants.Faction.REBEL_ALLIANCE


func _on_setup_turn_prompt_requested(player_index: int, player_label: String) -> void:
	_prompt_calls.append({
		"player_index": player_index,
		"player_label": player_label,
	})
