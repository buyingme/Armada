## Focused BUG-043 regressions for Network SetSpeed acceptance/rejection and
## pre-commit maneuver-preview convergence.
extends GutTest


class AsyncSubmitter:
	extends CommandSubmitter

	var submitted: Array[GameCommand] = []

	func submit(command: GameCommand) -> Dictionary:
		submitted.append(command)
		return {"awaiting_remote": true}


class SyncSubmitter:
	extends CommandSubmitter

	var submitted: Array[GameCommand] = []

	func submit(command: GameCommand) -> Dictionary:
		submitted.append(command)
		return command.execute(GameManager.current_game_state)


class AsyncSpeedSubmitter:
	extends CommandSubmitter

	var submitted: Array[GameCommand] = []

	func submit(command: GameCommand) -> Dictionary:
		submitted.append(command)
		if command.command_type == "set_speed":
			return {"awaiting_remote": true}
		return command.execute(GameManager.current_game_state)


var _saved_state: GameState = null
var _saved_submitter: CommandSubmitter = null


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_submitter = GameManager.get_command_submitter()


func after_each() -> void:
	GameManager.current_game_state = _saved_state
	GameManager.set_command_submitter(_saved_submitter)


func test_client_acceptance_converges_preview_and_blocks_rapid_resubmit() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:1")
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var tool: ManeuverToolScene = fixture["tool"] as ManeuverToolScene
	var controller: ShipActivationController = fixture["controller"] \
			as ShipActivationController
	var submitter := AsyncSubmitter.new()
	GameManager.set_command_submitter(submitter)
	controller._connect_signals()

	tool._handle_speed_change(-1)
	assert_eq(submitter.submitted.size(), 1)
	assert_eq(ship.current_speed, 2, "Awaiting result is not canonical success")
	assert_eq(tool.get_state().get_simulated_speed(), 1,
			"Pending preview may show the requested target")
	assert_true(tool.has_pending_speed_change())

	tool._handle_speed_change(1)
	assert_eq(submitter.submitted.size(), 1,
			"Rapid follow-up must not enqueue against stale canonical speed")

	ship.set_speed(1)
	GameManager._handle_remote_command_effects(submitter.submitted[0], {})
	assert_false(tool.has_pending_speed_change())
	assert_eq(tool.get_state().get_simulated_speed(), 1,
			"Accepted canonical speed must converge the preview")

	tool._handle_speed_change(1)
	assert_eq(submitter.submitted.size(), 2)
	assert_eq(int(submitter.submitted[1].payload.get("new_speed", -1)), 2)
	ship.set_speed(2)
	GameManager._handle_remote_command_effects(submitter.submitted[1], {})
	assert_eq(tool.get_state().get_simulated_speed(), 2,
			"Accepted reversal must replace the prior preview speed")
	assert_eq(tool.get_state().get_simulated_speed(), ship.current_speed,
			"Subsequent maneuver payload source must equal canonical speed")
	GameManager.submit_execute_maneuver(
			ship, tool.get_state().get_simulated_speed(), [0, 0],
			0.5, 0.5, 0.0, -1, false,
			(fixture["activation_state"] as ShipActivationState) \
					.get_total_speed_change())
	assert_eq(submitter.submitted.size(), 3)
	assert_eq(submitter.submitted[2].command_type, "execute_maneuver")
	assert_eq(int(submitter.submitted[2].payload.get("speed", -1)), 2,
			"The real maneuver payload must use accepted canonical speed")


func test_accepted_speed_one_to_zero_enters_unified_maneuver_path() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:zero", 1)
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var state: ShipActivationState = fixture["activation_state"] \
			as ShipActivationState
	var tool: ManeuverToolScene = fixture["tool"] as ManeuverToolScene
	var maneuver_controller: ManeuverToolController = \
			fixture["maneuver_controller"] as ManeuverToolController
	var controller: ShipActivationController = fixture["controller"] \
			as ShipActivationController
	var submitter := AsyncSpeedSubmitter.new()
	GameManager.set_command_submitter(submitter)
	controller._connect_signals()
	_advance_to_maneuver(state)

	tool._handle_speed_change(-1)
	assert_eq(ship.current_speed, 1,
			"Pending speed zero is not canonical acceptance")
	assert_eq(tool.get_state().get_simulated_speed(), 0,
			"Pending activation preview may represent target speed zero")
	controller._on_execute_maneuver()
	assert_false(state.is_maneuver_executed(),
			"A pending stale speed-one maneuver must not commit")
	assert_eq(submitter.submitted.size(), 1)

	ship.set_speed(0)
	GameManager._handle_remote_command_effects(submitter.submitted[0], {})

	assert_eq(ship.current_speed, 0)
	assert_eq(tool.get_state().get_simulated_speed(), 0,
			"Accepted canonical speed zero must converge transient state")
	assert_false(tool.has_pending_speed_change())
	assert_true(state.is_maneuver_executed(),
			"Existing speed-zero path must complete the local maneuver")
	assert_false(state.is_done(),
			"Completion waits for the authoritative Maneuver result chain")
	assert_null(maneuver_controller.get_scene(),
			"The speed-one tool must be invalidated after speed-zero completion")
	assert_eq(submitter.submitted.size(), 2)
	assert_eq(submitter.submitted[1].command_type, "execute_maneuver")
	assert_eq(int(submitter.submitted[1].payload.get("speed", -1)), 0)
	assert_true(ship.has_active_maneuver_execution(),
			"The direct test submitter commits but does not synthesize follow-ups")


func test_matching_rejection_restores_same_activation_transient_state() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:reject", 2, true)
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var state: ShipActivationState = fixture["activation_state"] \
			as ShipActivationState
	var tool: ManeuverToolScene = fixture["tool"] as ManeuverToolScene
	var controller: ShipActivationController = fixture["controller"] \
			as ShipActivationController
	var submitter := AsyncSubmitter.new()
	GameManager.set_command_submitter(submitter)
	controller._connect_signals()
	watch_signals(EventBus)

	tool._handle_speed_change(-1)
	GameManager.network_command_rejected.emit(
			submitter.submitted[0], "test rejection")

	assert_eq(ship.current_speed, 2, "Rejection must not mutate canonical speed")
	assert_eq(state.get_total_speed_change(), 0)
	assert_eq(state.get_dial_speed_budget(), 1)
	assert_eq(state.get_token_speed_budget(), 1)
	assert_eq(tool.get_state().get_simulated_speed(), 2)
	assert_false(tool.has_pending_speed_change())
	assert_signal_emitted_with_parameters(
			EventBus, "ship_speed_changed", [ship, 2])
	assert_signal_emitted_with_parameters(
			EventBus, "navigate_token_spend_preview", [ship, false])
	assert_true(controller._maneuver_preview_ready_for_commit(),
			"Matching rejection must reopen commit eligibility")


func test_stale_rejection_cannot_mutate_replacement_activation_tool() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:old")
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var old_tool: ManeuverToolScene = fixture["tool"] as ManeuverToolScene
	var maneuver_controller: ManeuverToolController = \
			fixture["maneuver_controller"] as ManeuverToolController
	var controller: ShipActivationController = fixture["controller"] \
			as ShipActivationController
	var submitter := AsyncSubmitter.new()
	GameManager.set_command_submitter(submitter)
	controller._connect_signals()
	old_tool._handle_speed_change(-1)

	ship.ship_activation_identity = "activation:bug043:new"
	var replacement_state := ShipActivationState.create(ship)
	var replacement_tool := _make_tool(ship, replacement_state)
	maneuver_controller.add_child(replacement_tool)
	maneuver_controller._scene = replacement_tool
	var network_submitter := NetworkCommandSubmitter.new()
	network_submitter._awaiting = true
	network_submitter._in_flight_count = 1
	GameManager.set_command_submitter(network_submitter)
	ship.set_speed(1)
	GameManager._handle_remote_command_effects(submitter.submitted[0], {})
	assert_eq(replacement_tool.get_state().get_simulated_speed(), 2,
			"Delayed acceptance must not refresh a replacement tool")
	ship.set_speed(2)
	GameManager.network_command_rejected.emit(
			submitter.submitted[0], "delayed rejection")

	assert_eq(replacement_state.get_total_speed_change(), 0)
	assert_eq(replacement_tool.get_state().get_simulated_speed(), 2)
	assert_false(replacement_tool.has_pending_speed_change())


func test_host_synchronous_acceptance_uses_committed_canonical_speed() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:host")
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var tool: ManeuverToolScene = fixture["tool"] as ManeuverToolScene
	var submitter := SyncSubmitter.new()
	GameManager.set_command_submitter(submitter)

	tool._handle_speed_change(-1)

	assert_eq(submitter.submitted.size(), 1)
	assert_eq(ship.current_speed, 1)
	assert_eq(tool.get_state().get_simulated_speed(), 1)
	assert_false(tool.has_pending_speed_change())


func test_host_synchronous_speed_zero_enters_unified_maneuver_path() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:host-zero", 1)
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var state: ShipActivationState = fixture["activation_state"] \
			as ShipActivationState
	var tool: ManeuverToolScene = fixture["tool"] as ManeuverToolScene
	var maneuver_controller: ManeuverToolController = \
			fixture["maneuver_controller"] as ManeuverToolController
	var controller: ShipActivationController = fixture["controller"] \
			as ShipActivationController
	var submitter := SyncSubmitter.new()
	GameManager.set_command_submitter(submitter)
	controller._connect_signals()
	_advance_to_maneuver(state)

	tool._handle_speed_change(-1)

	assert_eq(ship.current_speed, 0)
	assert_eq(tool.get_state().get_simulated_speed(), 0)
	assert_true(state.is_maneuver_executed())
	assert_false(state.is_done())
	assert_null(maneuver_controller.get_scene())
	assert_eq(submitter.submitted.size(), 2)
	assert_eq(submitter.submitted[0].command_type, "set_speed")
	assert_eq(submitter.submitted[1].command_type, "execute_maneuver")
	assert_eq(int(submitter.submitted[1].payload.get("speed", -1)), 0)
	assert_true(ship.has_active_maneuver_execution())


func test_passive_matching_preview_refreshes_without_originating_command() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:passive")
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var tool: ManeuverToolScene = fixture["tool"] as ManeuverToolScene
	var controller: ShipActivationController = fixture["controller"] \
			as ShipActivationController
	var submitter := AsyncSubmitter.new()
	GameManager.set_command_submitter(submitter)
	controller._connect_signals()
	ship.set_speed(1)

	EventBus.ship_speed_changed.emit(ship, ship.current_speed)

	assert_eq(tool.get_state().get_simulated_speed(), 1)
	assert_eq(submitter.submitted.size(), 0,
			"Passive convergence must not originate a SetSpeed command")


func test_passive_speed_zero_invalidates_tool_without_originating_terminal_command() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:passive-zero", 1)
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var tool: ManeuverToolScene = fixture["tool"] as ManeuverToolScene
	var maneuver_controller: ManeuverToolController = \
			fixture["maneuver_controller"] as ManeuverToolController
	var controller: ShipActivationController = fixture["controller"] \
			as ShipActivationController
	var submitter := NetworkCommandSubmitter.new()
	GameManager.set_command_submitter(submitter)
	controller._connect_signals()
	ship.set_speed(0)

	EventBus.ship_speed_changed.emit(ship, ship.current_speed)

	assert_eq(tool.get_state().get_simulated_speed(), 0)
	assert_null(maneuver_controller.get_scene(),
			"Passive speed-zero preview should be invalidated")
	assert_false(submitter.is_awaiting_response(),
			"Passive convergence must not originate terminal commands")


func test_stale_preview_guard_runs_before_maneuver_commit_effects() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:guard")
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var state: ShipActivationState = fixture["activation_state"] \
			as ShipActivationState
	var tool: ManeuverToolScene = fixture["tool"] as ManeuverToolScene
	var token: ShipToken = fixture["token"] as ShipToken
	var controller: ShipActivationController = fixture["controller"] \
			as ShipActivationController
	tool.get_state().set_simulated_speed(1)
	var before_position: Vector2 = token.position
	var before_history: int = CommandProcessor.get_command_count()

	controller._on_execute_maneuver()

	assert_eq(token.position, before_position, "Token must not snap")
	assert_false(state.is_maneuver_executed(),
			"Maneuver state must not commit")
	assert_eq(ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_OPEN,
			"Canonical maneuver opportunity must remain open")
	assert_eq(CommandProcessor.get_command_count(), before_history,
			"No authoritative maneuver or side-effect command may submit")
	assert_eq(tool.get_state().get_simulated_speed(), 2,
			"Matching transient preview should re-derive from canonical speed")


func test_reconstructed_live_tool_derives_canonical_speed_and_identity() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:rebuild")
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var maneuver_controller: ManeuverToolController = \
			fixture["maneuver_controller"] as ManeuverToolController
	var controller: ShipActivationController = fixture["controller"] \
			as ShipActivationController
	ship.set_speed(1)
	var replacement_state := ShipActivationState.create(ship)
	var replacement_tool := _make_tool(ship, replacement_state)
	maneuver_controller.add_child(replacement_tool)
	maneuver_controller._scene = replacement_tool
	controller._activation_ctx.ship_activation_state = replacement_state

	assert_eq(replacement_tool.get_state().get_simulated_speed(), 1)
	assert_eq(replacement_tool.get_activation_ship(), ship)
	assert_eq(replacement_tool.get_activation_identity(),
			ship.ship_activation_identity)
	assert_true(controller._maneuver_preview_ready_for_commit(),
			"A reconstructed matching tool must be eligible from canonical state")


func _fixture(activation_identity: String, initial_speed: int = 2,
		has_navigate_token: bool = false) -> Dictionary:
	var data := ShipData.new()
	data.hull = 8
	data.max_speed = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 3, "left": 3, "right": 3, "rear": 2}
	var ship := ShipInstance.create_from_data(
			"bug043_ship", data, initial_speed, 0)
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE, Constants.CommandType.REPAIR], 1)
	ship.command_dial_stack.reveal_top()
	if has_navigate_token:
		assert_true(ship.command_tokens.add_token(
				Constants.CommandType.NAVIGATE))
	assert_true(ship.establish_ship_activation(activation_identity))
	assert_true(ship.open_maneuver_opportunity(activation_identity))
	var player_zero := PlayerState.new()
	player_zero.player_index = 0
	player_zero.ships.append(ship)
	var player_one := PlayerState.new()
	player_one.player_index = 1
	var game_state := GameState.new()
	game_state.current_phase = Constants.GamePhase.SHIP
	game_state.player_states = [player_zero, player_one]
	GameManager.current_game_state = game_state

	var activation_state := ShipActivationState.create(ship)
	var tool := _make_tool(ship, activation_state)
	var maneuver_controller := ManeuverToolController.new()
	add_child_autofree(maneuver_controller)
	maneuver_controller.add_child(tool)
	maneuver_controller._scene = tool
	var token := ShipToken.new()
	add_child_autofree(token)
	var context := ActivationContext.new()
	context.set_active(token, activation_state)
	var controller := ShipActivationController.new()
	add_child_autofree(controller)
	controller._activation_ctx = context
	controller._maneuver_tool_controller = maneuver_controller
	controller._dismiss_maneuver_tool_with_preview = func() -> void:
		maneuver_controller.dismiss(ship)
	return {
		"ship": ship,
		"activation_state": activation_state,
		"tool": tool,
		"maneuver_controller": maneuver_controller,
		"token": token,
		"controller": controller,
	}


func _make_tool(ship: ShipInstance,
		activation_state: ShipActivationState) -> ManeuverToolScene:
	var tool := ManeuverToolScene.new()
	tool._state = ManeuverToolState.new()
	tool._state.setup(ship.current_speed,
			ship.ship_data.navigation_chart,
			ship.ship_data.ship_size, ship.ship_data.max_speed)
	tool.set_activation_mode(activation_state)
	return tool


func _advance_to_maneuver(state: ShipActivationState) -> void:
	while not state.is_at_step(ShipActivationState.Step.MANEUVER):
		state.advance_step()
