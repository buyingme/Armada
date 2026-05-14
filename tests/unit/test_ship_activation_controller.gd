## Unit tests for [ShipActivationController].
##
## Covers projection-driven activation step synchronization that cannot be
## represented inside [ActivationModal] alone.
extends GutTest


class RecordingSubmitter:
	extends CommandSubmitter

	var submitted_commands: Array[GameCommand] = []


	func submit(command: GameCommand) -> Dictionary:
		submitted_commands.append(command)
		return {"recorded": true}


var _activation_ctx: ActivationContext = null
var _controller: ShipActivationController = null
var _panel_mgr: UIPanelManager = null
var _ship_token: ShipToken = null
var _submitter: RecordingSubmitter = null
var _saved_active_player: int = 0
var _saved_game_state: GameState = null
var _saved_local_player_index: int = -1
var _saved_submitter: CommandSubmitter = null


func before_each() -> void:
	_saved_active_player = GameManager.active_player
	_saved_game_state = GameManager.current_game_state
	_saved_local_player_index = NetworkManager._local_player_index
	_saved_submitter = GameManager.get_command_submitter()
	_submitter = RecordingSubmitter.new()
	GameManager.set_command_submitter(_submitter)
	GameManager.active_player = 0
	NetworkManager._local_player_index = -1


func after_each() -> void:
	GameManager.set_command_submitter(_saved_submitter)
	GameManager.current_game_state = _saved_game_state
	GameManager.active_player = _saved_active_player
	NetworkManager._local_player_index = _saved_local_player_index
	_activation_ctx = null
	_controller = null
	_panel_mgr = null
	_ship_token = null
	_submitter = null


func test_sync_activation_step_from_flow_unavailable_repair_submits_attack_step() -> void:
	var ship: ShipInstance = _create_ship(0)
	_start_activation_for_ship(ship)
	var flow: InteractionFlow = _repair_flow(0, 0)

	_controller.sync_activation_step_from_flow(flow)
	await get_tree().process_frame

	assert_eq(_submitter.submitted_commands.size(), 1,
			"Controller should submit one deferred advance from Repair to Attack.")
	var command: GameCommand = _submitter.submitted_commands[0]
	assert_true(command is AdvanceActivationStepCommand,
			"Deferred command should be an AdvanceActivationStepCommand.")
	assert_eq(command.payload.get("step_id", ""), "attack_step",
			"Unavailable projected Repair step should advance to attack_step.")
	assert_eq(_activation_ctx.ship_activation_state.get_current_step(),
			ShipActivationState.Step.ATTACK,
			"Local activation state should advance to ATTACK after deferred repair skip.")


func test_sync_activation_step_from_flow_passive_peer_does_not_submit() -> void:
	NetworkManager._local_player_index = 1
	var ship: ShipInstance = _create_ship(0)
	_start_activation_for_ship(ship)
	var flow: InteractionFlow = _repair_flow(0, 0)

	_controller.sync_activation_step_from_flow(flow)
	await get_tree().process_frame

	assert_eq(_submitter.submitted_commands.size(), 0,
			"Passive peer should not submit the projected Repair auto-advance.")
	assert_eq(_activation_ctx.ship_activation_state.get_current_step(),
			ShipActivationState.Step.REPAIR,
			"Passive peer should mirror the authoritative Repair step.")


func _create_ship(owner_player: int) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = 4
	data.max_speed = 4
	data.navigation_chart = [[2], [1, 2], [0, 1, 2], [0, 1, 1, 2]]
	data.command_value = 1
	data.shields = {"front": 2, "left": 1, "right": 1, "rear": 1}
	data.defense_tokens = []
	return ShipInstance.create_from_data("test_ship", data, 1, owner_player)


func _start_activation_for_ship(ship: ShipInstance) -> void:
	GameManager.current_game_state = _game_state_with_ship(ship)
	_ship_token = ShipToken.new()
	_ship_token.bind_instance(ship)
	add_child_autofree(_ship_token)
	_activation_ctx = ActivationContext.new()
	_activation_ctx.set_active(_ship_token, ShipActivationState.create(ship))
	_panel_mgr = UIPanelManager.new()
	_panel_mgr.activation_modal = ActivationModal.new()
	_panel_mgr.add_child(_panel_mgr.activation_modal)
	add_child_autofree(_panel_mgr)
	_controller = ShipActivationController.new()
	add_child_autofree(_controller)
	_initialize_controller()


func _game_state_with_ship(ship: ShipInstance) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	state.player_states[ship.owner_player].ships.append(ship)
	state.interaction_flow = _repair_flow(ship.owner_player, 0)
	return state


func _repair_flow(controller_player: int, ship_index: int) -> InteractionFlow:
	return InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.REPAIR_STEP,
			controller_player,
			Constants.Visibility.ALL,
			{"ship_index": ship_index})


func _initialize_controller() -> void:
	_controller.initialize(
			_activation_ctx,
			_panel_mgr,
			null,
			null,
			null,
			null,
			null,
			null,
			Callable(),
			Callable(self, "_has_no_repair_resources"),
			Callable(self, "_has_no_squadron_resources"),
			Callable(self, "_is_not_squadron_token_only"),
			Callable(),
			Callable(),
			Callable(self, "_local_squadron_controller"),
			Callable(self, "_empty_ship_tokens"),
			Callable(self, "_empty_squadron_tokens"),
			Callable())


func _has_no_repair_resources(_ship_token_arg: Variant) -> bool:
	return false


func _has_no_squadron_resources(_ship_token_arg: Variant) -> bool:
	return false


func _is_not_squadron_token_only(_ship_token_arg: Variant) -> bool:
	return false


func _local_squadron_controller() -> bool:
	return true


func _empty_ship_tokens() -> Array[ShipToken]:
	return []


func _empty_squadron_tokens() -> Array[SquadronToken]:
	return []