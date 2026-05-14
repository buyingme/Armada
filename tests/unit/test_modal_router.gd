## Tests for [ModalRouter].
##
## Verifies the Phase L1 command-executed subscriber, HUD projection path, and
## command-reaction callback bridge used by [CommandRouterAdapter].
extends GutTest


var _router: ModalRouter = null
var _panel_mgr: UIPanelManager = null
var _saved_game_state: GameState = null
var _saved_active_player: int = 0
var _saved_local_player_index: int = -1


func before_each() -> void:
	_saved_game_state = GameManager.current_game_state
	_saved_active_player = GameManager.active_player
	_saved_local_player_index = NetworkManager._local_player_index
	GameManager.current_game_state = null
	GameManager.active_player = 0
	NetworkManager._local_player_index = -1


func after_each() -> void:
	_disconnect_router_signal()
	_free_test_node(_router)
	_free_test_node(_panel_mgr)
	_router = null
	_panel_mgr = null
	GameManager.current_game_state = _saved_game_state
	GameManager.active_player = _saved_active_player
	NetworkManager._local_player_index = _saved_local_player_index


# ---------------------------------------------------------------------------
# initialize
# ---------------------------------------------------------------------------

func test_initialize_connects_command_executed_signal() -> void:
	# Arrange / Act
	_create_router(Callable())

	# Assert
	var route_callable: Callable = Callable(_router, "_on_command_executed")
	assert_true(CommandProcessor.command_executed.is_connected(route_callable),
			"ModalRouter should own the command_executed subscription.")


# ---------------------------------------------------------------------------
# route_command_result
# ---------------------------------------------------------------------------

func test_route_command_result_controller_flow_updates_hud_status() -> void:
	# Arrange
	_create_router(Callable())
	GameManager.current_game_state = _state_with_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN,
			0)

	# Act
	_router.route_command_result(null, {})

	# Assert
	assert_eq(_panel_mgr._network_status_text, "make your choices",
			"HUD status should be projected from the current UIIntent.")


func test_route_command_result_invokes_command_reaction_callback() -> void:
	# Arrange
	var callback_results: Array[Dictionary] = []
	var reaction: Callable = func(_command: GameCommand, result: Dictionary) -> void:
		callback_results.append(result.duplicate(true))
	_create_router(reaction)
	GameManager.current_game_state = _state_with_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN,
			0)

	# Act
	_router.route_command_result(null, {"handled": true})

	# Assert
	assert_eq(callback_results.size(), 1,
			"Command reaction callback should run once before projection.")
	assert_eq(callback_results[0].get("handled", false), true,
			"Callback should receive the command result dictionary.")


func _create_router(command_reaction_fn: Callable) -> void:
	_panel_mgr = UIPanelManager.new()
	_panel_mgr.name = "TestUIPanelManager"
	add_child(_panel_mgr)
	_router = ModalRouter.new()
	_router.name = "TestModalRouter"
	add_child(_router)
	_router.initialize(
			_panel_mgr,
			null,
			null,
			null,
			null,
			Callable(),
			Callable(),
			command_reaction_fn)


func _state_with_flow(flow_type: Constants.InteractionFlow,
		step_id: Constants.InteractionStep,
		controller_player: int) -> GameState:
	var state: GameState = GameState.new()
	state.interaction_flow = InteractionFlow.make(
			flow_type,
			step_id,
			controller_player)
	return state


func _disconnect_router_signal() -> void:
	if _router == null:
		return
	var route_callable: Callable = Callable(_router, "_on_command_executed")
	if CommandProcessor.command_executed.is_connected(route_callable):
		CommandProcessor.command_executed.disconnect(route_callable)


func _free_test_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
