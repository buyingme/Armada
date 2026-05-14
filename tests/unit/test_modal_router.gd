## Tests for [ModalRouter].
##
## Verifies the Phase L1 command-executed subscriber, HUD projection path, and
## command-reaction callback bridge used by [CommandRouterAdapter].
extends GutTest


class StubShipActivationController:
	extends ShipActivationController

	var close_calls: int = 0
	var affordance_values: Array[bool] = []
	var interactivity_calls: int = 0
	var modal_open: bool = false
	var open_calls: int = 0
	var squadron_command_open_calls: int = 0
	var sync_calls: int = 0


	func sync_activation_step_from_flow(_flow: InteractionFlow) -> void:
		sync_calls += 1


	func open_modal_from_interaction_state() -> void:
		open_calls += 1
		modal_open = true


	func close_modal_from_interaction_state() -> void:
		close_calls += 1
		modal_open = false


	func update_activation_modal_interactivity() -> void:
		interactivity_calls += 1


	func apply_activation_sequence_affordance(is_available: bool) -> void:
		affordance_values.append(is_available)


	func open_squadron_command_from_interaction_state() -> void:
		squadron_command_open_calls += 1
		modal_open = false


	func is_command_squadron_modal_active() -> bool:
		return false


	func ensure_activation_modal_hidden_for_squadron_command() -> void:
		modal_open = false


	func is_activation_modal_open() -> bool:
		return modal_open


class StubDisplacementController:
	extends DisplacementController

	var displaced_count: int = 0
	var start_calls: int = 0


	func start(displaced: Array[SquadronToken], _ship_base: ShipBase) -> void:
		start_calls += 1
		displaced_count = displaced.size()


var _router: ModalRouter = null
var _panel_mgr: UIPanelManager = null
var _ship_activation_controller: StubShipActivationController = null
var _displacement_controller: StubDisplacementController = null
var _ship_token: ShipToken = null
var _squadron_token: SquadronToken = null
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
	_free_test_node(_ship_activation_controller)
	_free_test_node(_displacement_controller)
	_free_test_node(_ship_token)
	_free_test_node(_squadron_token)
	_free_test_node(_panel_mgr)
	_router = null
	_panel_mgr = null
	_ship_activation_controller = null
	_displacement_controller = null
	_ship_token = null
	_squadron_token = null
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


func test_route_command_result_activation_substep_opens_closed_modal() -> void:
	# Arrange
	var controller: StubShipActivationController = _create_activation_controller(false)
	_create_router(Callable(), controller)
	GameManager.current_game_state = _state_with_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ATTACK_STEP,
			0)
	var command: AdvanceActivationStepCommand = AdvanceActivationStepCommand.new(
			0, {"ship_index": 0, "step_id": "attack_step"})

	# Act
	_router.route_command_result(command, {})

	# Assert
	assert_eq(controller.sync_calls, 1,
			"Router should sync the activation step from the projected flow.")
	assert_eq(controller.open_calls, 1,
			"Closed activation modal should open from projected sub-steps.")


func test_route_command_result_activation_substep_keeps_open_modal() -> void:
	# Arrange
	var controller: StubShipActivationController = _create_activation_controller(true)
	_create_router(Callable(), controller)
	GameManager.current_game_state = _state_with_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.REPAIR_STEP,
			0)
	var command: AdvanceActivationStepCommand = AdvanceActivationStepCommand.new(
			0, {"ship_index": 0, "step_id": "repair_step"})

	# Act
	_router.route_command_result(command, {})

	# Assert
	assert_eq(controller.open_calls, 0,
			"Already-open activation modal should not be reopened.")
	assert_eq(controller.interactivity_calls, 1,
			"Router should still refresh modal interactivity.")


func test_route_command_result_wait_for_ship_select_closes_modal() -> void:
	# Arrange
	var controller: StubShipActivationController = _create_activation_controller(true)
	_create_router(Callable(), controller)
	GameManager.current_game_state = _state_with_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			0)

	# Act
	_router.route_command_result(null, {})

	# Assert
	assert_eq(controller.close_calls, 1,
			"WAIT_FOR_SHIP_SELECT should close the activation modal.")
	assert_eq(controller.affordance_values, [false],
			"WAIT_FOR_SHIP_SELECT should clear the sequence-button affordance.")


func test_route_command_result_squadron_step_opens_command_modal() -> void:
	# Arrange
	var controller: StubShipActivationController = _create_activation_controller(true)
	_create_router(Callable(), controller)
	GameManager.current_game_state = _state_with_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.SQUADRON_STEP,
			0)
	var command: AdvanceActivationStepCommand = AdvanceActivationStepCommand.new(
			0, {"ship_index": 0, "step_id": "squadron_step"})

	# Act
	_router.route_command_result(command, {})

	# Assert
	assert_eq(controller.squadron_command_open_calls, 1,
			"Projected squadron_step should open the command-mode squadron modal.")
	assert_eq(controller.open_calls, 0,
			"SQUADRON_STEP should not reopen the ship activation modal.")
	assert_eq(controller.affordance_values, [true],
			"SQUADRON_STEP should forward the activation-sequence affordance.")


func test_route_command_result_displacement_opens_in_hot_seat() -> void:
	# Arrange
	var displacement: StubDisplacementController = _create_displacement_controller()
	var ship: ShipInstance = _create_ship(0)
	var squadron: SquadronInstance = _create_squadron(1)
	_create_tokens(ship, squadron)
	_create_router(Callable(), null, displacement,
			Callable(self , "_find_test_ship_token"),
			Callable(self , "_find_test_squadron_token"))
	GameManager.current_game_state = _state_with_displacement_flow(ship, squadron)
	var command: StartDisplacementCommand = _start_displacement_command()

	# Act
	_router.route_command_result(command, {})

	# Assert
	assert_eq(displacement.start_calls, 1,
			"Hot-seat should open displacement through ModalRouter projection.")
	assert_eq(displacement.displaced_count, 1,
			"Projected displacement should resolve the listed squadron token.")


func test_route_command_result_displacement_network_non_controller_skips() -> void:
	# Arrange
	NetworkManager._local_player_index = 0
	var displacement: StubDisplacementController = _create_displacement_controller()
	var ship: ShipInstance = _create_ship(0)
	var squadron: SquadronInstance = _create_squadron(1)
	_create_tokens(ship, squadron)
	_create_router(Callable(), null, displacement,
			Callable(self , "_find_test_ship_token"),
			Callable(self , "_find_test_squadron_token"))
	GameManager.current_game_state = _state_with_displacement_flow(ship, squadron)
	var command: StartDisplacementCommand = _start_displacement_command()

	# Act
	_router.route_command_result(command, {})

	# Assert
	assert_eq(displacement.start_calls, 0,
			"Network non-controller should not open the displacement modal.")


func _create_router(command_reaction_fn: Callable,
		ship_activation_controller: ShipActivationController = null,
		displacement_controller: DisplacementController = null,
		find_ship_token_fn: Callable = Callable(),
		find_squadron_token_fn: Callable = Callable()) -> void:
	_panel_mgr = UIPanelManager.new()
	_panel_mgr.name = "TestUIPanelManager"
	add_child(_panel_mgr)
	_router = ModalRouter.new()
	_router.name = "TestModalRouter"
	add_child(_router)
	_router.initialize(
			_panel_mgr,
			null,
			ship_activation_controller,
			displacement_controller,
			null,
			find_ship_token_fn,
			find_squadron_token_fn,
			command_reaction_fn)


func _create_activation_controller(
		modal_open: bool) -> StubShipActivationController:
	_ship_activation_controller = StubShipActivationController.new()
	_ship_activation_controller.name = "StubShipActivationController"
	_ship_activation_controller.modal_open = modal_open
	add_child(_ship_activation_controller)
	return _ship_activation_controller


func _create_displacement_controller() -> StubDisplacementController:
	_displacement_controller = StubDisplacementController.new()
	_displacement_controller.name = "StubDisplacementController"
	add_child(_displacement_controller)
	return _displacement_controller


func _create_ship(owner_player: int) -> ShipInstance:
	var ship: ShipInstance = ShipInstance.new()
	ship.owner_player = owner_player
	return ship


func _create_squadron(owner_player: int) -> SquadronInstance:
	var squadron: SquadronInstance = SquadronInstance.new()
	squadron.owner_player = owner_player
	return squadron


func _create_tokens(ship: ShipInstance, squadron: SquadronInstance) -> void:
	_ship_token = ShipToken.new()
	_ship_token.name = "TestShipToken"
	_ship_token.bind_instance(ship)
	add_child(_ship_token)
	_squadron_token = SquadronToken.new()
	_squadron_token.name = "TestSquadronToken"
	_squadron_token.bind_instance(squadron)
	add_child(_squadron_token)


func _state_with_flow(flow_type: Constants.InteractionFlow,
		step_id: Constants.InteractionStep,
		controller_player: int) -> GameState:
	var state: GameState = GameState.new()
	state.interaction_flow = InteractionFlow.make(
			flow_type,
			step_id,
			controller_player)
	return state


func _state_with_displacement_flow(ship: ShipInstance,
		squadron: SquadronInstance) -> GameState:
	var state: GameState = _state_with_flow(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE,
			1)
	var player_zero: PlayerState = PlayerState.new()
	player_zero.player_index = 0
	player_zero.ships.append(ship)
	var player_one: PlayerState = PlayerState.new()
	player_one.player_index = 1
	player_one.squadrons.append(squadron)
	state.player_states = [player_zero, player_one]
	state.interaction_flow.payload = _displacement_payload()
	return state


func _start_displacement_command() -> StartDisplacementCommand:
	return StartDisplacementCommand.new(0, {
			"ship_index": 0,
			"controller_player": 1,
			"displaced_squadrons": _displacement_entries(),
	})


func _displacement_payload() -> Dictionary:
	return {
			"ship_index": 0,
			"displaced_squadrons": _displacement_entries(),
	}


func _displacement_entries() -> Array[Dictionary]:
	return [ {"owner": 1, "squadron_index": 0}]


func _find_test_ship_token(ship: ShipInstance) -> ShipToken:
	if _ship_token != null and _ship_token.get_ship_instance() == ship:
		return _ship_token
	return null


func _find_test_squadron_token(squadron: SquadronInstance) -> SquadronToken:
	if _squadron_token != null \
			and _squadron_token.get_squadron_instance() == squadron:
		return _squadron_token
	return null


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
