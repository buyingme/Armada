extends GutTest


const GAME_BOARD_SCENE: PackedScene = preload(
		"res://src/scenes/game_board/game_board.tscn")
const OVERLAP: GDScript = preload(
		"res://src/core/geometry/obstacle_overlap_authority.gd")
const MANEUVER_AUTHORITY: GDScript = preload(
		"res://src/core/movement/maneuver_authority.gd")
const SCENARIO_ID := "learning_scenario"
const ACTIVATION_ID := "ship-activation:ggs-gate-1"
const START_CURSOR := 40


class RecordingSubmitter:
	extends CommandSubmitter

	var submitted: Array[GameCommand] = []
	var authoritative_submitted: Array[GameCommand] = []

	func submit(command: GameCommand) -> Dictionary:
		submitted.append(command)
		return {"recorded": true}

	func submit_authoritative(command: GameCommand) -> Dictionary:
		authoritative_submitted.append(command)
		return {"recorded": true}


var _saved_state: GameState
var _saved_active: bool
var _saved_preloaded: bool
var _saved_submitter: CommandSubmitter
var _saved_mode: PlayMode.Mode
var _saved_role: NetworkManager.Role
var _saved_local_player: int


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_active = GameManager.is_game_active
	_saved_preloaded = GameManager.is_state_preloaded
	_saved_submitter = GameManager.get_command_submitter()
	_saved_mode = PlayMode.current_mode
	_saved_role = NetworkManager.role
	_saved_local_player = NetworkManager._local_player_index
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	NetworkManager._local_player_index = -1


func after_each() -> void:
	GameManager.current_game_state = _saved_state
	GameManager.is_game_active = _saved_active
	GameManager.is_state_preloaded = _saved_preloaded
	GameManager.set_command_submitter(_saved_submitter)
	PlayMode.current_mode = _saved_mode
	NetworkManager.role = _saved_role
	NetworkManager._local_player_index = _saved_local_player


func test_exact_obstacle_order_boundary_roundtrips_and_replays_first_command() \
		-> void:
	var initial_state: GameState = _pre_maneuver_state()
	assert_true(GameManager.start_new_game_from_state(
			initial_state, SCENARIO_ID, START_CURSOR))

	var execute := CandidateExecuteManeuverCommand.new(0, {
		"ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"speed": 0,
		"yaw_clicks": [],
		"yaw_bonus_joint": -1,
	})
	assert_false(CommandProcessor.submit(execute).is_empty())
	assert_eq(_history_types(), [
		"execute_maneuver", "apply_maneuver_transform",
	], "Production continuation must stop at the player ordering choice.")

	var source: GameState = GameManager.current_game_state
	var source_ship: ShipInstance = source.get_ship(0, 0)
	var recorded_cursor: int = CommandProcessor.get_next_sequence()
	assert_eq(recorded_cursor, START_CURSOR + 2)
	_assert_exact_boundary(source, source_ship)
	var source_signature: Dictionary = _decision_signature(source)
	var source_deck: Dictionary = source.damage_deck.serialize()
	var source_rng: Dictionary = source.rng.serialize()
	var source_state: Dictionary = source.serialize()

	var parsed_state: Variant = JSON.parse_string(JSON.stringify(source_state))
	assert_true(parsed_state is Dictionary)
	assert_eq(typeof(source_rng["state"]), TYPE_INT)
	assert_eq(typeof((parsed_state as Dictionary)["rng"]["state"]),
			TYPE_FLOAT,
			"Godot JSON parsing exposes the precision-loss seam explicitly.")
	var reconstructed: GameState = GameState.deserialize(
			parsed_state as Dictionary)
	assert_not_null(reconstructed)
	if reconstructed == null:
		return
	var reconstructed_ship: ShipInstance = reconstructed.get_ship(0, 0)
	_assert_exact_boundary(reconstructed, reconstructed_ship)
	assert_eq(reconstructed_ship.ship_activation_identity,
			source_ship.ship_activation_identity)
	assert_eq(reconstructed_ship.active_maneuver_execution_snapshot().get(
			"maneuver_execution_id"), source_ship \
			.active_maneuver_execution_snapshot().get("maneuver_execution_id"))
	assert_eq(reconstructed.damage_deck.serialize(), source_deck)
	assert_eq(reconstructed.rng.initial_seed, source_rng["initial_seed"])
	assert_eq(reconstructed.rng.get_state(), source_rng["state"],
			"Canonical JSON roundtrip must preserve the exact RNG state.")
	assert_eq(_decision_signature(reconstructed), source_signature)

	assert_true(GameManager.start_new_game_from_state(
			reconstructed, SCENARIO_ID, recorded_cursor))
	assert_true(CommandProcessor.get_history().is_empty())
	assert_eq(CommandProcessor.get_next_sequence(), recorded_cursor)
	var installed: GameState = GameManager.current_game_state
	var installed_signature: Dictionary = _decision_signature(installed)
	assert_eq(installed_signature, source_signature)

	var recording_submitter := RecordingSubmitter.new()
	GameManager.set_command_submitter(recording_submitter)
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var controller: ShipActivationController = \
			board._ship_activation_controller
	controller._close_maneuver_consequence_modal()
	board._command_router_adapter.reconstruct_presentation()
	assert_eq(_action_signature(controller._pending_maneuver_action),
			installed_signature)
	assert_not_null(controller._maneuver_consequence_modal)
	if controller._maneuver_consequence_modal != null:
		assert_true(controller._maneuver_consequence_modal.visible)
		assert_eq(controller._maneuver_consequence_modal._choice_info.get(
				"chooser"), "owner")
		assert_eq(_option_ids(controller._maneuver_consequence_modal \
				._choice_info), [
			"obstacle:0|obstacle:1",
			"obstacle:1|obstacle:0",
		])
	assert_true(recording_submitter.submitted.is_empty())
	assert_true(recording_submitter.authoritative_submitted.is_empty())
	assert_true(CommandProcessor.get_history().is_empty())
	assert_eq(CommandProcessor.get_next_sequence(), recorded_cursor)
	await get_tree().process_frame
	board.free()

	var payload: Dictionary = (installed_signature["payload"] as Dictionary) \
			.duplicate(true)
	var selected := CandidateCommitManeuverObstacleOrderCommand.new(
			int(installed_signature["player_index"]), payload)
	selected.sequence = recorded_cursor
	assert_eq(selected.validate(installed), "")
	var parsed_command: Variant = JSON.parse_string(
			JSON.stringify(selected.serialize()))
	assert_true(parsed_command is Dictionary)
	var replayed: GameCommand = GameCommand.deserialize(
			parsed_command as Dictionary)
	assert_not_null(replayed)
	if replayed == null:
		return
	assert_false(CommandProcessor.submit_replay(replayed).is_empty())
	assert_eq(CommandProcessor.get_history().size(), 1)
	assert_eq(CommandProcessor.get_history()[0].command_type,
			"commit_maneuver_obstacle_order")
	assert_eq(CommandProcessor.get_history()[0].sequence, recorded_cursor)
	assert_eq(CommandProcessor.get_next_sequence(), recorded_cursor + 1)


func _pre_maneuver_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.ship_phase_selection_controller = 0
	state.rng = GameRng.new(1007001)
	state.damage_deck = DamageDeck.new()
	state.damage_deck.set_rng(state.rng)
	state.damage_deck.initialize_for_save7()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	var data: ShipData = AssetLoader.load_ship_data("cr90_corvette_a")
	var ship := ShipInstance.create_from_data(
			"cr90_corvette_a", data, 1, 0)
	ship.roster_entry_id = "ggs-gate-1:ship"
	ship.pos_x = 0.5
	ship.pos_y = 0.5
	ship.current_speed = 0
	state.get_player_state(0).ships.append(ship)
	assert_true(ship.establish_ship_activation(ACTIVATION_ID))
	assert_true(ship.open_maneuver_opportunity(ACTIVATION_ID))
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP, 0,
			Constants.Visibility.ALL, {
				"ship_index": 0,
				"ship_activation_identity": ACTIVATION_ID,
			})
	state.objectives["obstacles"] = [
		_obstacle("obstacle:0", "debris_1", 0, ship),
		_obstacle("obstacle:1", "station", 1, ship),
	]
	return state


func _assert_exact_boundary(state: GameState, ship: ShipInstance) -> void:
	assert_not_null(ship)
	if ship == null:
		return
	assert_eq(PlayMode.current_mode, PlayMode.Mode.HOT_SEAT)
	assert_null(state.passive_damage_ledger)
	assert_true(state.has_valid_match_player_control_binding())
	assert_eq(state.current_phase, Constants.GamePhase.SHIP)
	assert_eq(state.interaction_flow.flow_type,
			Constants.InteractionFlow.SHIP_ACTIVATION)
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.MANEUVER_STEP)
	assert_true(state.validate_ship_activation_identity_aggregate())
	assert_eq(state.get_active_ship_activation(), ship)
	assert_eq(_active_activation_count(state), 1)
	assert_true(ship.has_active_maneuver_execution())
	var execution: Dictionary = ship.active_maneuver_execution_snapshot()
	assert_eq(execution.get("ship_activation_identity"), ACTIVATION_ID)
	assert_eq(execution.get("maneuver_execution_id"),
			"maneuver:%d" % START_CURSOR)
	assert_true(bool(execution.get("final_transform_applied", false)))
	assert_eq(execution.get("ship_collision", {}).get("kind"), "none")
	assert_true((execution.get("obstacle_resolution_order", []) as Array) \
			.is_empty())
	assert_true(MANEUVER_AUTHORITY \
			.derive_affected_squadrons_from_canonical(state, 0, 0).is_empty())
	assert_true(ship.faceup_damage.is_empty(),
			"No Damaged Controls obligation may outrank obstacle ordering.")
	assert_true(ship.pending_obstacle_pre_effect_snapshot().is_empty())
	assert_false(ship.has_active_obstacle_resolution())
	assert_false(ship.has_active_immediate_resolution())
	assert_true(ship.asteroid_completion_outstanding_snapshot().is_empty())
	assert_null(state.faceup_damage_inspection)
	var overlaps: Array[Dictionary] = OVERLAP.unresolved_overlaps(
			state, 0, 0, str(execution["maneuver_execution_id"]))
	assert_eq(overlaps, [
		{
			"obstacle_id": "obstacle:0",
			"data_key": "debris_1",
			"obstacle_type": "debris",
			"placement_order": 0,
			"last_maneuver_execution_id": "",
		},
		{
			"obstacle_id": "obstacle:1",
			"data_key": "station",
			"obstacle_type": "station",
			"placement_order": 1,
			"last_maneuver_execution_id": "",
		},
	])
	var signature: Dictionary = _decision_signature(state)
	assert_eq(signature.get("kind"), "decision")
	assert_eq(signature.get("command_type"),
			"commit_maneuver_obstacle_order")
	assert_eq(signature.get("player_index"), 0)
	assert_eq(signature.get("payload", {}).get("ship_activation_identity"),
			ACTIVATION_ID)
	assert_eq(signature.get("payload", {}).get("maneuver_execution_id"),
			"maneuver:%d" % START_CURSOR)
	assert_eq(signature.get("payload", {}).get("obstacle_ids"),
			["obstacle:0", "obstacle:1"])


func _decision_signature(state: GameState) -> Dictionary:
	return _action_signature(ManeuverExecutionEvaluator.next_action(
			state, 0, 0))


func _action_signature(action: Dictionary) -> Dictionary:
	var obstacles: Array[Dictionary] = []
	for raw: Variant in action.get("obstacles", []):
		if raw is Dictionary:
			var obstacle: Dictionary = raw as Dictionary
			obstacles.append({
				"obstacle_id": obstacle.get("obstacle_id"),
				"data_key": obstacle.get("data_key"),
				"obstacle_type": obstacle.get("obstacle_type"),
				"placement_order": obstacle.get("placement_order"),
			})
	return {
		"kind": action.get("kind"),
		"command_type": action.get("command_type"),
		"player_index": action.get("player_index"),
		"payload": (action.get("payload", {}) as Dictionary).duplicate(true),
		"obstacles": obstacles,
	}


func _active_activation_count(state: GameState) -> int:
	var count: int = 0
	for player: PlayerState in state.player_states:
		for ship: ShipInstance in player.ships:
			if ship.has_active_ship_activation():
				count += 1
	return count


func _history_types() -> Array[String]:
	var types: Array[String] = []
	for command: GameCommand in CommandProcessor.get_history():
		types.append(command.command_type)
	return types


func _option_ids(choice_info: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for raw: Variant in choice_info.get("options", []):
		if raw is Dictionary:
			ids.append(str((raw as Dictionary).get("id", "")))
	return ids


func _obstacle(id: String, key: String, order: int,
		ship: ShipInstance) -> Dictionary:
	return {
		"obstacle_id": id,
		"data_key": key,
		"pos_x": ship.pos_x,
		"pos_y": ship.pos_y,
		"rotation_deg": 0.0,
		"placing_player": 0,
		"placement_order": order,
		"last_maneuver_execution_id": "",
	}
