## Unit tests for [SetupPlacementController].
##
## Covers the projected obstacle-placement modal state and preview drop /
## confirm flow introduced for FB14F without depending on the full game-board
## scene.
extends GutTest


const MAP_3X3: String = "map_3x3_azure_v4.jpg"
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


func _placed_obstacle(data_key: String) -> Dictionary:
	return {
		"data_key": data_key,
		"pos_x": 0.5,
		"pos_y": 0.5,
		"rotation_deg": 0.0,
	}


func _on_setup_turn_prompt_requested(player_index: int, player_label: String) -> void:
	_prompt_calls.append({
		"player_index": player_index,
		"player_label": player_label,
	})
