## Unit tests for [ShipActivationController].
##
## Covers projection-driven activation step synchronization that cannot be
## represented inside [ActivationModal] alone.
extends GutTest


class RecordingSubmitter:
	extends CommandSubmitter

	var submitted_commands: Array[GameCommand] = []
	var execute_locally: bool = false
	var result_to_return: Dictionary = {"recorded": true}


	func submit(command: GameCommand) -> Dictionary:
		submitted_commands.append(command)
		if execute_locally:
			var game_state: GameState = GameManager.current_game_state
			if game_state == null or not command.validate(game_state).is_empty():
				return {}
			return command.execute(game_state)
		return result_to_return.duplicate(true)


class StubAttackExecutor:
	extends AttackExecutor

	var has_targets: bool = false


	func has_any_attack_target(_ship_token_arg: ShipToken) -> bool:
		return has_targets


var _activation_ctx: ActivationContext = null
var _attack_executor: StubAttackExecutor = null
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
	_attack_executor = null
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


func test_activation_entry_without_commands_reaches_attack_by_commands_only() -> void:
	var ship: ShipInstance = _create_ship(0)
	_start_activation_for_ship(ship)
	_attack_executor.has_targets = true
	var flow: InteractionFlow = _activation_open_flow(0, 0)
	GameManager.current_game_state.interaction_flow = flow

	_controller.sync_activation_step_from_flow(flow)
	_controller.configure_and_open_activation_modal()
	await get_tree().process_frame

	assert_eq(_submitter.submitted_commands.size(), 1,
			"Unavailable Squadron should submit one authoritative transition.")
	var repair_command: GameCommand = _submitter.submitted_commands[0]
	assert_eq(repair_command.payload.get("step_id", ""), "repair_step")
	assert_false(ship.attack_step_active,
			"Attack progress must remain inactive before attack_step is accepted.")
	assert_eq(_activation_ctx.ship_activation_state.get_current_step(),
			ShipActivationState.Step.SQUADRON,
			"The modal auto-skip timer must not advance scene state to Attack.")

	repair_command.execute(GameManager.current_game_state)
	_controller.sync_activation_step_from_flow(
			GameManager.current_game_state.interaction_flow)
	await get_tree().process_frame

	assert_eq(_submitter.submitted_commands.size(), 2,
			"Unavailable Repair should submit the existing attack-step transition.")
	var attack_command: GameCommand = _submitter.submitted_commands[1]
	assert_eq(attack_command.payload.get("step_id", ""), "attack_step")
	attack_command.execute(GameManager.current_game_state)
	_controller.sync_activation_step_from_flow(
			GameManager.current_game_state.interaction_flow)

	assert_eq(GameManager.current_game_state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_STEP)
	assert_true(ship.attack_step_active,
			"Canonical Attack projection and ShipInstance progress must agree.")
	assert_eq(_activation_ctx.ship_activation_state.get_current_step(),
			ShipActivationState.Step.ATTACK)
	await get_tree().create_timer(0.35).timeout
	assert_eq(_submitter.submitted_commands.size(), 2,
			"Cancelled scene-local auto-skip timers must not submit extra work.")


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


func test_sync_activation_step_from_flow_no_targets_waits_for_accepted_skip() \
		-> void:
	var ship: ShipInstance = _create_ship(0)
	_start_activation_for_ship(ship)
	ship.begin_attack_step()
	_submitter.execute_locally = true
	var flow: InteractionFlow = _attack_flow(0, 0)
	GameManager.current_game_state.interaction_flow = flow

	_controller.sync_activation_step_from_flow(flow)
	await get_tree().process_frame

	assert_eq(_submitter.submitted_commands.size(), 1,
			"Controller should submit one deferred no-active Skip.")
	var command: GameCommand = _submitter.submitted_commands[0]
	assert_true(command is SkipAttackCommand,
			"Deferred command should be the supported semantic Skip.")
	assert_eq(command.payload.get("reason", ""), "no_targets")
	assert_false(ship.attack_step_active,
			"Accepted Skip must consume the Attack-step opportunity.")
	assert_eq(ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_OPEN)
	_controller.sync_activation_step_from_flow(
			GameManager.current_game_state.interaction_flow)
	assert_eq(_activation_ctx.ship_activation_state.get_current_step(),
			ShipActivationState.Step.MANEUVER,
			"Presentation should project Maneuver only after accepted Skip.")


func test_sync_activation_step_from_flow_rejected_no_target_skip_preserves_attack() \
		-> void:
	var ship: ShipInstance = _create_ship(0)
	_start_activation_for_ship(ship)
	ship.begin_attack_step()
	_submitter.result_to_return = {}
	var flow: InteractionFlow = _attack_flow(0, 0)
	GameManager.current_game_state.interaction_flow = flow
	var boundary_before: Dictionary = ship.ship_activation_boundary_snapshot()
	var progress_before: Dictionary = ship.attack_progress_snapshot()

	_controller.sync_activation_step_from_flow(flow)
	await get_tree().process_frame

	assert_eq(_submitter.submitted_commands.size(), 1)
	assert_true(_submitter.submitted_commands[0] is SkipAttackCommand)
	assert_eq(ship.ship_activation_boundary_snapshot(), boundary_before)
	assert_eq(ship.attack_progress_snapshot(), progress_before)
	assert_eq(_activation_ctx.ship_activation_state.get_current_step(),
			ShipActivationState.Step.ATTACK,
			"Rejected automatic Skip must not tear down or advance presentation.")
	assert_engine_error(1,
			"Rejected automatic no-target Skip should be diagnosed once.")


func test_sync_activation_step_from_flow_attack_targets_does_not_submit() -> void:
	var ship: ShipInstance = _create_ship(0)
	_start_activation_for_ship(ship)
	_attack_executor.has_targets = true
	var flow: InteractionFlow = _attack_flow(0, 0)
	GameManager.current_game_state.interaction_flow = flow

	_controller.sync_activation_step_from_flow(flow)
	await get_tree().process_frame

	assert_eq(_submitter.submitted_commands.size(), 0,
			"Controller should not auto-advance Attack when targets exist.")
	assert_eq(_activation_ctx.ship_activation_state.get_current_step(),
			ShipActivationState.Step.ATTACK,
			"Local activation state should remain at ATTACK when targets exist.")


func test_command_range_overlay_retires_from_accepted_step_on_each_peer() -> void:
	var ship: ShipInstance = _create_ship(0)
	_start_activation_for_ship(ship)
	_attack_executor.has_targets = true
	var overlay_parent: Node2D = Node2D.new()
	add_child_autofree(overlay_parent)
	var squadron_controller: SquadronPhaseController = \
			SquadronPhaseController.new()
	add_child_autofree(squadron_controller)
	squadron_controller.initialize(
			overlay_parent, Callable(), Callable(), Callable(), Callable())
	_controller._squadron_phase_controller = squadron_controller
	_controller._has_squadron_resources = func(_token: Variant) -> bool:
		return true

	squadron_controller.open_for_command(null, _ship_token)
	assert_not_null(squadron_controller._squad_cmd_range_overlay,
			"Command range overlay should open for the local command tool.")
	_controller.sync_activation_step_from_flow(InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.SQUADRON_STEP,
			0, Constants.Visibility.ALL, {"ship_index": 0}))
	assert_not_null(squadron_controller._squad_cmd_range_overlay,
			"The canonical Squadron step should retain its local overlay.")

	_controller.sync_activation_step_from_flow(_attack_flow(0, 0))
	assert_null(squadron_controller._squad_cmd_range_overlay,
			"Accepted local completion should dismiss the host overlay.")

	# A passive network peer executes the same one-way projection cleanup.
	NetworkManager._local_player_index = 1
	squadron_controller.open_for_command(null, _ship_token)
	assert_not_null(squadron_controller._squad_cmd_range_overlay,
			"A later command may open a fresh local overlay.")
	_controller.sync_activation_step_from_flow(_attack_flow(0, 0))
	assert_null(squadron_controller._squad_cmd_range_overlay,
			"Mirrored accepted completion should dismiss the client overlay too.")


func test_pending_network_overlap_does_not_refresh_from_precommand_state() -> void:
	var moving: ShipInstance = _create_ship(0)
	_start_activation_for_ship(moving)
	var other: ShipInstance = _create_ship(1)
	GameManager.current_game_state.player_states[1].ships.append(other)
	var other_token: ShipToken = ShipToken.new()
	other_token.bind_instance(other)
	add_child_autofree(other_token)
	var damage_deck: DamageDeck = DamageDeck.new()
	damage_deck.initialize()
	_controller._damage_deck = damage_deck
	_controller._get_ship_tokens = func() -> Array[ShipToken]:
		return [_ship_token, other_token]
	_controller._is_pending_remote_result = func(result: Dictionary) -> bool:
		return bool(result.get("awaiting_remote", false))
	_submitter.result_to_return = {"awaiting_remote": true}
	var overlap: OverlapResolver.ShipShipResult = \
			OverlapResolver.ShipShipResult.new()
	overlap.overlapped_ship_index = 0
	overlap.stayed_in_place = true
	watch_signals(EventBus)

	_controller._apply_overlap_damage(overlap)

	assert_eq(moving.get_total_damage(), 0)
	assert_eq(other.get_total_damage(), 0)
	assert_signal_not_emitted(EventBus, "damage_card_dealt",
			"Pending client submission must not refresh from stale canonical damage.")
	assert_signal_not_emitted(EventBus, "ship_hull_changed",
			"Pending client submission must wait for the accepted mirror result.")


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
	assert_true(ship.establish_ship_activation(
			"ship-activation:controller"))
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
	_attack_executor = StubAttackExecutor.new()
	add_child_autofree(_attack_executor)
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


func _activation_open_flow(
		controller_player: int, ship_index: int) -> InteractionFlow:
	return InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN,
			controller_player,
			Constants.Visibility.ALL,
			{"ship_index": ship_index})


func _attack_flow(controller_player: int, ship_index: int) -> InteractionFlow:
	return InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ATTACK_STEP,
			controller_player,
			Constants.Visibility.ALL,
			{"ship_index": ship_index})


func _initialize_controller() -> void:
	_controller.initialize(
			_activation_ctx,
			_panel_mgr,
			_attack_executor,
			null,
			null,
			null,
			null,
			null,
			Callable(),
			Callable(self , "_has_no_repair_resources"),
			Callable(self , "_has_no_squadron_resources"),
			Callable(self , "_is_not_squadron_token_only"),
			Callable(),
			Callable(),
			Callable(self , "_local_squadron_controller"),
			Callable(self , "_empty_ship_tokens"),
			Callable(self , "_empty_squadron_tokens"),
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
