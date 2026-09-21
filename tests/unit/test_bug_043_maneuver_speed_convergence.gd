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


class ConvergedHotSeatSubmitter:
	extends CommandSubmitter

	var _next_sequence: int = 200

	func submit(command: GameCommand) -> Dictionary:
		command.sequence = _next_sequence
		_next_sequence += 1
		var committed: Dictionary = command.execute(
				GameManager.current_game_state)
		if committed.is_empty() or command.command_type != "execute_maneuver":
			return committed
		var continuation_payload: Dictionary = {
			"owner_player": int(committed["owner_player"]),
			"ship_index": int(committed["ship_index"]),
			"ship_activation_identity": committed["ship_activation_identity"],
			"maneuver_execution_id": committed["maneuver_execution_id"],
		}
		var apply := CandidateApplyManeuverTransformCommand.new(
				command.player_index, continuation_payload)
		apply.sequence = _next_sequence
		_next_sequence += 1
		if apply.execute(GameManager.current_game_state).is_empty():
			return {}
		var complete := CandidateCompleteManeuverCommand.new(
				command.player_index, continuation_payload)
		complete.sequence = _next_sequence
		_next_sequence += 1
		return committed \
				if not complete.execute(GameManager.current_game_state).is_empty() \
				else {}


var _saved_state: GameState = null
var _saved_submitter: CommandSubmitter = null


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_submitter = GameManager.get_command_submitter()


func after_each() -> void:
	GameManager.current_game_state = _saved_state
	GameManager.set_command_submitter(_saved_submitter)


func test_speed_selection_stays_transient_until_maneuver_commit() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:1")
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var tool: ManeuverToolScene = fixture["tool"] as ManeuverToolScene
	var submitter := AsyncSubmitter.new()
	GameManager.set_command_submitter(submitter)

	tool._handle_speed_change(-1)
	assert_eq(submitter.submitted.size(), 0,
			"Preview selection must not submit pre-commit set_speed")
	assert_eq(ship.current_speed, 2, "Preview must not mutate canonical speed")
	assert_eq(tool.get_state().get_simulated_speed(), 1,
			"Preview represents the selected target")
	assert_false(tool.has_pending_speed_change())

	tool._handle_speed_change(1)
	assert_eq(tool.get_state().get_simulated_speed(), 2,
			"Reversing selection restores the original preview")
	assert_eq(ship.current_speed, 2)
	assert_eq(submitter.submitted.size(), 0)


func test_speed_zero_is_committed_by_execute_maneuver_not_set_speed() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:zero", 1)
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var state: ShipActivationState = fixture["activation_state"] \
			as ShipActivationState
	var tool: ManeuverToolScene = fixture["tool"] as ManeuverToolScene
	var controller: ShipActivationController = fixture["controller"] \
			as ShipActivationController
	var submitter := SyncSubmitter.new()
	GameManager.set_command_submitter(submitter)
	_advance_to_maneuver(state)

	tool._handle_speed_change(-1)
	assert_eq(ship.current_speed, 1,
			"Speed-zero selection remains transient before commit")
	assert_eq(tool.get_state().get_simulated_speed(), 0,
			"Preview may represent target speed zero")
	controller._on_execute_maneuver()
	assert_eq(ship.current_speed, 0)
	assert_eq(submitter.submitted.size(), 1)
	assert_eq(submitter.submitted[0].command_type, "execute_maneuver")
	assert_eq(int(submitter.submitted[0].payload.get("speed", -1)), 0)
	assert_true(ship.has_active_maneuver_execution(),
			"The direct test submitter commits but does not synthesize follow-ups")


func test_token_only_speed_change_is_debited_atomically_at_commit() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:token", 2, true)
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var tool: ManeuverToolScene = fixture["tool"] as ManeuverToolScene
	# Remove the revealed Navigate dial so the selected speed change is
	# unambiguously token-funded, matching the CR90 evidence.
	assert_false(ship.command_dial_stack.spend_revealed().is_empty())

	tool._handle_speed_change(-1)
	assert_eq(ship.current_speed, 2)
	assert_true(ship.command_tokens.has_token(Constants.CommandType.NAVIGATE))
	var command := CandidateExecuteManeuverCommand.new(0, {
		"ship_index": 0,
		"ship_activation_identity": ship.ship_activation_identity,
		"speed": tool.get_state().get_simulated_speed(),
		"yaw_clicks": [0],
		"yaw_bonus_joint": -1,
	})
	var result: Dictionary = command.execute(GameManager.current_game_state)
	assert_false(result.is_empty())
	assert_true(bool(result.get("navigate_token_spent", false)))
	assert_eq(ship.current_speed, 1)
	assert_false(ship.command_tokens.has_token(Constants.CommandType.NAVIGATE),
			"Accepted speed change must remove the canonical Navigate token")


func test_accepted_explicit_token_spend_projects_canonical_removal() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:repair-spend")
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	assert_true(ship.command_tokens.add_token(Constants.CommandType.REPAIR))
	GameManager.set_command_submitter(SyncSubmitter.new())
	watch_signals(EventBus)

	var result: Dictionary = GameManager.submit_spend_token(
			ship, int(Constants.CommandType.REPAIR))

	assert_true(bool(result.get("spent", false)))
	assert_false(ship.command_tokens.has_token(Constants.CommandType.REPAIR),
			"Accepted spend must remove the canonical command token")
	assert_signal_emitted_with_parameters(
			EventBus, "command_tokens_changed", [ship])


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
	assert_eq(tool.get_state().get_simulated_speed(), 1,
			"A rejected inconsistent preview remains presentation-only")


func test_hot_seat_converged_maneuver_projects_retired_canonical_transform() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:hot-seat")
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var token: ShipToken = fixture["token"] as ShipToken
	var controller: ShipActivationController = fixture["controller"] \
			as ShipActivationController
	ship.pos_x = 0.5
	ship.pos_y = 0.5
	token.position = ship.get_pixel_position(GameScale.play_area_size_px)
	var before_canonical := Vector2(ship.pos_x, ship.pos_y)
	var before_projection: Vector2 = token.position
	GameManager.set_command_submitter(ConvergedHotSeatSubmitter.new())

	controller._on_execute_maneuver()

	assert_ne(Vector2(ship.pos_x, ship.pos_y), before_canonical,
			"A non-zero committed maneuver must change canonical position")
	assert_false(ship.has_active_maneuver_execution(),
			"The synchronous authority sequence must retire its execution")
	assert_eq(ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_CONSUMED)
	assert_ne(token.position, before_projection,
			"Hot-Seat projection must not be restored after record retirement")
	assert_almost_eq(token.position.x,
			ship.pos_x * GameScale.play_area_size_px.x, 0.001)
	assert_almost_eq(token.position.y,
			ship.pos_y * GameScale.play_area_size_px.y, 0.001)
	assert_almost_eq(token.rotation, deg_to_rad(ship.rotation_deg), 0.00001)


func test_rejected_overclick_preserves_preview_and_authority_course() -> void:
	var fixture: Dictionary = _fixture("activation:bug043:yaw-course")
	var ship: ShipInstance = fixture["ship"] as ShipInstance
	var activation_state: ShipActivationState = fixture["activation_state"] \
			as ShipActivationState
	var tool: ManeuverToolScene = fixture["tool"] as ManeuverToolScene
	ship.ship_data.navigation_chart = [[2], [1, 2], [0, 1, 2]]
	tool.get_state().set_navigation_chart(ship.ship_data.navigation_chart)
	assert_true(activation_state.apply_yaw_bonus(0))
	assert_true(tool.get_state().set_yaw_bonus_joint(0))
	assert_true(tool.get_state().click_joint_left(0))
	assert_true(tool.get_state().click_joint_left(0))
	assert_true(tool.get_state().click_joint_left(1))
	assert_true(tool.get_state().click_joint_left(1))
	var selected_clicks: Array[int] = tool.get_state().get_joint_clicks()

	assert_false(tool._try_apply_yaw_bonus_for(1, MOUSE_BUTTON_LEFT),
			"A third click cannot move the bonus by mutating a valid course.")
	assert_eq(tool.get_state().get_joint_clicks(), selected_clicks)
	assert_eq(tool.get_state().get_yaw_bonus_joint(), 0)
	assert_eq(activation_state.get_yaw_bonus_joint(), 0)
	var start_transform := Transform2D(
			deg_to_rad(ship.rotation_deg),
			ship.get_pixel_position(GameScale.play_area_size_px))
	var side: String = tool.get_state().compute_ghost_side()
	var attachment: Dictionary = \
			ManeuverToolState.compute_attachment_from_ship_transform(
					start_transform, ship.ship_data.ship_size, side)
	var preview_transform: Transform2D = tool.get_state().compute_final_transform(
			attachment["position"], attachment["rotation"], side)
	var authority: Dictionary = ManeuverAuthority.derive(
			GameManager.current_game_state, 0, 0, 2,
			selected_clicks.slice(0, 2), 0)

	assert_true(bool(authority.get("ok", false)))
	var committed_transform: Transform2D = authority["final_transform"]
	assert_almost_eq(committed_transform.origin.x,
			preview_transform.origin.x, 0.00001)
	assert_almost_eq(committed_transform.origin.y,
			preview_transform.origin.y, 0.00001)
	assert_almost_eq(committed_transform.get_rotation(),
			preview_transform.get_rotation(), 0.00001)


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
	var panel_mgr := UIPanelManager.new()
	add_child_autofree(panel_mgr)
	controller._activation_ctx = context
	controller._maneuver_tool_controller = maneuver_controller
	controller._panel_mgr = panel_mgr
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
