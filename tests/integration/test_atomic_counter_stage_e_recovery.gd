## Stage E: recovered Counter decisions and enclosing owner continuations.
extends GutTest


const ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")
const GAME_BOARD_SCENE: PackedScene = preload(
		"res://src/scenes/game_board/game_board.tscn")

var _old_state: GameState
var _old_active: bool
var _old_submitter: CommandSubmitter
var _old_mode: PlayMode.Mode
var _old_role: NetworkManager.Role
var _old_local_player: int
var _old_replay_enabled: bool
var _old_processor_replay: bool


class RecordingSubmitter:
	extends CommandSubmitter

	var submitted: Array[GameCommand] = []

	func submit(command: GameCommand) -> Dictionary:
		submitted.append(command)
		return {"awaiting_remote": true}


func before_each() -> void:
	_old_state = GameManager.current_game_state
	_old_active = GameManager.is_game_active
	_old_submitter = GameManager.get_command_submitter()
	_old_mode = PlayMode.current_mode
	_old_role = NetworkManager.role
	_old_local_player = NetworkManager._local_player_index
	_old_replay_enabled = ReplayDriver.enabled
	_old_processor_replay = CommandProcessor.is_replaying
	CommandProcessor.reset()
	GameManager.set_command_submitter(LocalCommandSubmitter.new())
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	NetworkManager._local_player_index = -1


func after_each() -> void:
	CommandProcessor.reset()
	GameManager.current_game_state = _old_state
	GameManager.is_game_active = _old_active
	GameManager.set_command_submitter(_old_submitter)
	PlayMode.set_mode(_old_mode)
	NetworkManager.role = _old_role
	NetworkManager._local_player_index = _old_local_player
	ReplayDriver.enabled = _old_replay_enabled
	CommandProcessor.is_replaying = _old_processor_replay


func test_board_json_reload_preserves_pending_counter_and_real_panel_choice() \
		-> void:
	for accepted: bool in [true, false]:
		var source: GameState = _pending_counter_state()
		var source_flow: Dictionary = source.interaction_flow.serialize()
		var state: GameState = GameState.deserialize(JSON.parse_string(
				JSON.stringify(source.serialize())) as Dictionary)
		assert_not_null(state)
		if state == null:
			continue
		assert_eq(CanonicalJson.hash(state.serialize()),
				CanonicalJson.hash(source.serialize()))
		assert_eq(state.interaction_flow.serialize(), source_flow)
		assert_true(GameManager.start_new_game_from_state(
				state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 72))
		var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
		add_child_autofree(board)
		assert_false(board._active_attack_reconstruction_blocked)
		assert_eq(board._attack_executor._flow_fsm.current_step,
				AttackFlowFSM.Step.COUNTER_CHOICE)
		assert_eq(state.interaction_flow.serialize(), source_flow)
		assert_eq(CommandProcessor.get_command_count(), 0)
		var panel: AttackSimPanel = board._target_selector.get_panel()
		assert_not_null(panel)
		if panel != null:
			if accepted:
				panel.counter_attack_requested.emit()
			else:
				panel.counter_attack_skipped.emit()
		assert_eq(CommandProcessor.get_history()[0].command_type,
				CounterChoiceCommand.TYPE)
		assert_eq(CommandProcessor.get_history()[0].payload.get("attack_id"),
				"attack:71")
		board.queue_free()
		await get_tree().process_frame
		CommandProcessor.reset()


func test_network_reconnect_mirror_submits_source_bound_choice_in_both_roles() \
		-> void:
	for attacker_player: int in [0, 1]:
		for accepted: bool in [true, false]:
			var source: GameState = _pending_counter_state(
					attacker_player, false)
			var counter_player: int = 1 - attacker_player
			var filtered: Dictionary = StateFilter.filter_for_player_checked(
					source.serialize(), counter_player)
			assert_true(bool(filtered.get(StateFilter.KEY_OK, false)))
			var state: GameState = GameState.deserialize_passive_network(
					filtered.get(StateFilter.KEY_STATE, {}) as Dictionary)
			assert_not_null(state)
			if state == null:
				continue
			PlayMode.set_mode(PlayMode.Mode.NETWORK)
			NetworkManager.role = NetworkManager.Role.CLIENT
			NetworkManager._local_player_index = counter_player
			var submitter := RecordingSubmitter.new()
			GameManager.set_command_submitter(submitter)
			assert_true(GameManager.start_new_game_from_state(
					state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 72))
			var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
			add_child_autofree(board)
			var mirror: AttackPanelMirror = \
					board._panel_mgr.attack_panel_mirror
			assert_true(mirror.is_open())
			assert_eq(state.interaction_flow.step_id,
					Constants.InteractionStep.ATTACK_COUNTER_CHOICE)
			assert_true(submitter.submitted.is_empty())
			if accepted:
				mirror.get_panel().counter_attack_requested.emit()
			else:
				mirror.get_panel().counter_attack_skipped.emit()
			assert_eq(submitter.submitted.size(), 1)
			if not submitter.submitted.is_empty():
				assert_eq(submitter.submitted[0].command_type,
						CounterChoiceCommand.TYPE)
				assert_eq(submitter.submitted[0].player_index,
						counter_player)
				assert_eq(submitter.submitted[0].payload.get("attack_id"),
						"attack:71")
				assert_eq(submitter.submitted[0].validate(state), "")
			board.queue_free()
			await get_tree().process_frame
			CommandProcessor.reset()


func test_board_reload_recovers_destroyed_counter_eligible_defender() -> void:
	var source: GameState = _pending_counter_state(0, true, true)
	assert_true(source.get_squadron(1, 0).is_destroyed())
	var state: GameState = GameState.deserialize(JSON.parse_string(
			JSON.stringify(source.serialize())) as Dictionary)
	assert_not_null(state)
	if state == null:
		return
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 72))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	assert_false(board._active_attack_reconstruction_blocked)
	assert_eq(board._attack_executor._flow_fsm.current_step,
			AttackFlowFSM.Step.COUNTER_CHOICE)
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE)
	board.queue_free()
	await get_tree().process_frame


func test_board_reload_recovers_destroyed_original_during_counter_child() \
		-> void:
	await _assert_destroyed_original_child_reload(false)
	await _assert_destroyed_original_child_reload(true)


func _assert_destroyed_original_child_reload(
		destroyed_counter: bool) -> void:
	CommandProcessor.reset()
	var source: GameState = _pending_counter_state(0, false,
			destroyed_counter)
	GameManager.current_game_state = source
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = 1
	assert_true(CommandProcessor.restore_next_sequence(72))
	var context: Dictionary = GameManager.counter_choice_context_for_parent()
	context["accepted"] = true
	assert_false(CommandProcessor.submit(
			CounterChoiceCommand.new(1, context)).is_empty())
	var inspection: CompletedAttackInspection = \
			source.completed_attack_inspection
	assert_not_null(inspection)
	if inspection == null:
		return
	for player: int in [0, 1]:
		assert_false(CommandProcessor.submit(
				AcknowledgeAttackResultCommand.new(player, {
					"inspection_id": inspection.inspection_id(),
				})).is_empty())
	var child: CurrentAttackState = source.current_attack_state
	assert_true(child.active)
	assert_eq(child.attack_kind,
			SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER)
	var original: SquadronInstance = source.get_squadron(0, 0)
	original.mark_destroyed()
	var resolved: CurrentAttackState = child.with_patch({
		"stage": CurrentAttackState.STAGE_RESOLVED,
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
		"damage_stage": CurrentAttackState.DAMAGE_RESOLVED,
		"accuracy_complete": true,
		"resolved_outcome": {"target_kind": "squadron",
			"requested_hull_damage": 4, "actual_hull_damage": 4,
			"post_resolution_hull": 0, "destroyed": true},
	})
	assert_not_null(resolved)
	if resolved == null:
		return
	assert_true(source.set_current_attack_state(resolved))
	var restored: GameState = GameState.deserialize(JSON.parse_string(
			JSON.stringify(source.serialize())) as Dictionary)
	assert_not_null(restored)
	if restored == null:
		return
	assert_true(GameManager.start_new_game_from_state(
			restored, LearningScenarioSetup.DEFAULT_SCENARIO_ID,
			CommandProcessor.get_next_sequence()))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	assert_false(board._active_attack_reconstruction_blocked)
	assert_eq(CommandProcessor.get_history()[0].command_type,
			CompleteAttackCommand.TYPE)
	assert_true(restored.get_squadron(0, 0).is_destroyed())
	assert_false(restored.has_legal_remaining_squadron_move_action(
			restored.get_squadron(0, 0)))
	assert_not_null(restored.completed_attack_inspection)
	board.queue_free()
	await get_tree().process_frame
	var pending_j: GameState = GameState.deserialize(JSON.parse_string(
			JSON.stringify(restored.serialize())) as Dictionary)
	assert_not_null(pending_j)
	if pending_j == null:
		return
	assert_eq(CanonicalJson.hash(pending_j.serialize()),
			CanonicalJson.hash(restored.serialize()))
	assert_true(GameManager.start_new_game_from_state(
			pending_j, LearningScenarioSetup.DEFAULT_SCENARIO_ID,
			CommandProcessor.get_next_sequence()))
	var second_board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(second_board)
	assert_false(second_board._active_attack_reconstruction_blocked)
	var j: CompletedAttackInspection = pending_j.completed_attack_inspection
	assert_not_null(j)
	if j != null:
		for player: int in [0, 1]:
			assert_false(CommandProcessor.submit(
					AcknowledgeAttackResultCommand.new(player, {
						"inspection_id": j.inspection_id(),
					})).is_empty())
	assert_null(pending_j.completed_attack_inspection)
	assert_true(pending_j.get_squadron(0, 0).activated_this_round)
	assert_eq(_command_count(CompleteSquadronActivationCommand.TYPE), 1)
	second_board.queue_free()
	await get_tree().process_frame


func test_squadron_exhaustion_recovers_both_zero_progress_shapes_once() -> void:
	for initialized: bool in [false, true]:
		var state: GameState = _pending_counter_state()
		assert_true(state.set_current_attack_state(CurrentAttackState.inactive()))
		for player: int in [0, 1]:
			var squadron: SquadronInstance = state.get_squadron(player, 0)
			squadron.reset_activation_action_state()
			squadron.activated_this_round = true
		state.clear_squadron_phase_progress()
		if initialized:
			assert_true(state.initialize_squadron_phase_progress(0))
		state.interaction_flow = InteractionFlow.make(
				Constants.InteractionFlow.SQUADRON_ACTIVATION,
				Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT,
				0, Constants.Visibility.ALL, {})
		var restored: GameState = GameState.deserialize(JSON.parse_string(
				JSON.stringify(state.serialize())) as Dictionary)
		assert_not_null(restored)
		if restored == null:
			continue
		GameManager.current_game_state = restored
		GameManager.is_game_active = true
		var advance: GameCommand = GameManager \
				.derive_squadron_phase_exhaustion_transition(restored)
		assert_not_null(advance)
		if advance != null:
			assert_false(GameManager \
					.release_reconstructed_completed_attack_inspection().is_empty())
			assert_eq(restored.current_phase, Constants.GamePhase.COMMAND)
			assert_eq(CommandProcessor.get_history()[0].command_type,
					"advance_phase")
			assert_eq(CommandProcessor.get_history().size(), 3)
			assert_null(GameManager \
					.derive_squadron_phase_exhaustion_transition(restored))
			assert_true(GameManager \
					.release_reconstructed_completed_attack_inspection().is_empty())
		CommandProcessor.reset()


func test_commanded_ship_recovery_preserves_choice_then_advances_once() -> void:
	var state: GameState = _pending_counter_state()
	assert_true(state.set_current_attack_state(CurrentAttackState.inactive()))
	state.clear_squadron_phase_progress()
	state.current_phase = Constants.GamePhase.SHIP
	var original: SquadronInstance = state.get_squadron(0, 0)
	original.reset_activation_action_state()
	original.pos_x = 0.50
	original.pos_y = 0.55
	var ship := ShipInstance.create_from_data(
			"cr90_corvette_a",
			AssetLoader.load_ship_data("cr90_corvette_a"), 2, 0)
	ship.roster_entry_id = "stage-e-command-ship"
	ship.pos_x = 0.50
	ship.pos_y = 0.55
	assert_true(ship.command_dial_stack.assign_dials(
			[Constants.CommandType.SQUADRON], 1))
	assert_false(ship.command_dial_stack.reveal_top().is_empty())
	ship.command_tokens.add_token(Constants.CommandType.SQUADRON)
	assert_true(ship.establish_ship_activation("ship-activation:stage-e"))
	assert_true(ship.open_squadron_command_opportunity(
			ship.ship_activation_identity))
	assert_true(ship.commit_squadron_command_activation(
			ship.ship_activation_identity))
	state.get_player_state(0).ships.append(ship)
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.SQUADRON_STEP,
			0, Constants.Visibility.ALL, {"ship_index": 0})
	assert_null(GameManager \
			.derive_reconstructed_commanded_squadron_terminal_transition(state),
			"An eligible Squadron remains a voluntary selection or finish choice.")
	original.activated_this_round = true
	var restored: GameState = GameState.deserialize(JSON.parse_string(
			JSON.stringify(state.serialize())) as Dictionary)
	assert_not_null(restored)
	if restored == null:
		return
	GameManager.current_game_state = restored
	GameManager.is_game_active = true
	var advance: GameCommand = GameManager \
			.derive_reconstructed_commanded_squadron_terminal_transition(restored)
	assert_not_null(advance)
	if advance == null:
		return
	assert_eq(advance.validate(restored), "")
	assert_false(GameManager \
			.release_reconstructed_completed_attack_inspection().is_empty())
	assert_eq(CommandProcessor.get_history()[0].command_type,
			"advance_activation_step")
	assert_null(GameManager \
			.derive_reconstructed_commanded_squadron_terminal_transition(restored))
	assert_true(GameManager \
			.release_reconstructed_completed_attack_inspection().is_empty())


func test_replay_reconstruction_never_synthesizes_exhaustion() -> void:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SQUADRON
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	assert_true(state.initialize_squadron_phase_progress(0))
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SQUADRON_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT,
			0, Constants.Visibility.ALL, {})
	assert_not_null(GameManager.derive_squadron_phase_exhaustion_transition(
			state))
	GameManager.current_game_state = state
	GameManager.is_game_active = true
	ReplayDriver.enabled = true
	assert_true(GameManager \
			.release_reconstructed_completed_attack_inspection().is_empty())
	assert_eq(CommandProcessor.get_command_count(), 0)
	ReplayDriver.enabled = false
	CommandProcessor.is_replaying = true
	assert_true(GameManager \
			.release_reconstructed_completed_attack_inspection().is_empty())
	assert_eq(CommandProcessor.get_command_count(), 0)


func _pending_counter_state(attacker_player: int = 0,
		hotseat: bool = true,
		destroyed_counter: bool = false) -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SQUADRON
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human() if hotseat else \
			MatchPlayerControlBinding.create_two_human()))
	var deck := DamageDeck.new()
	deck.set_rng(state.rng)
	deck.initialize()
	state.damage_deck = deck
	var counter_player: int = 1 - attacker_player
	var counter := SquadronInstance.create_from_data(
			"tie_interceptor_squadron",
			AssetLoader.load_squadron_data("tie_interceptor_squadron"),
			counter_player)
	counter.roster_entry_id = "stage-e-counter"
	counter.pos_x = 0.51
	counter.pos_y = 0.50
	if destroyed_counter:
		counter.mark_destroyed()
	state.get_player_state(counter_player).squadrons.append(counter)
	assert_not_null(ATTACK_FIXTURE.install(state, {
		"attack_id": "attack:71", "attacker_kind": "squadron",
		"defender_kind": "squadron", "attacker_player": attacker_player,
		"defender_player": counter_player,
		"stage": CurrentAttackState.STAGE_RESOLVED,
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
		"resolved_outcome": {"target_kind": "squadron",
			"requested_hull_damage": 1, "actual_hull_damage": 1,
			"post_resolution_hull": 2, "destroyed": false},
	}))
	var original: SquadronInstance = state.get_squadron(attacker_player, 0)
	original.roster_entry_id = "stage-e-original"
	original.pos_x = 0.50
	original.pos_y = 0.50
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			attacker_player, Constants.Visibility.ALL,
			{"attack_id": "attack:71"})
	var publication: GameCommand = CurrentAttackContinuation \
			.derive_reconstructed_resolved_attack(state)
	assert_not_null(publication)
	if publication != null:
		assert_eq(publication.validate(state), "")
		assert_false(publication.execute(state).is_empty())
	return state


func _command_count(command_type: String) -> int:
	var count: int = 0
	for command: GameCommand in CommandProcessor.get_history():
		if command.command_type == command_type:
			count += 1
	return count
