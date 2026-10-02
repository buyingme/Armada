## BUG-069: accepted Squadron completion must leave the next canonical choice
## usable after the retiring modal callback and deferred intent finish.
extends GutTest


const BOARD: PackedScene = preload(
		"res://src/scenes/game_board/game_board.tscn")
const SCENARIO: String = LearningScenarioSetup.DEFAULT_SCENARIO_ID

var _saved_state: GameState
var _saved_active: bool
var _saved_submitter: CommandSubmitter
var _saved_mode: PlayMode.Mode
var _saved_role: NetworkManager.Role
var _saved_local: int
var _saved_player: int


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_active = GameManager.is_game_active
	_saved_submitter = GameManager.get_command_submitter()
	_saved_mode = PlayMode.current_mode
	_saved_role = NetworkManager.role
	_saved_local = NetworkManager._local_player_index
	_saved_player = GameManager.active_player
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	NetworkManager._local_player_index = -1
	GameManager.set_command_submitter(LocalCommandSubmitter.new())
	CommandProcessor.reset()


func after_each() -> void:
	CommandProcessor.reset()
	GameManager.current_game_state = _saved_state
	GameManager.is_game_active = _saved_active
	GameManager.set_command_submitter(_saved_submitter)
	GameManager.active_player = _saved_player
	PlayMode.current_mode = _saved_mode
	NetworkManager.role = _saved_role
	NetworkManager._local_player_index = _saved_local


func test_move_handoff_keeps_next_players_selection_actionable() -> void:
	var state: GameState = _start_squadron_game(1, 1)
	var board: GameBoard = _board()
	await _complete_move(board, state, 0, 0)
	await get_tree().process_frame
	_assert_next_choice(board, state, 1, 0)
	var next: SquadronInstance = state.get_squadron(1, 0)
	var token: SquadronToken = _token(board, next)
	assert_true(board._squadron_phase_controller.try_handle_squadron_click(token))
	assert_false(next.has_activation_action_state(),
			"Inspection after handoff must remain transient.")
	board._squadron_phase_controller.get_modal()._on_skip_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_history_types().has("skip_attack"),
			"The next controller's chosen intent must submit after handoff.")
	assert_eq(state.current_round, 2,
			"Terminal Skip may already have advanced through Status cleanup.")


func test_two_squadron_handoff_return_and_same_player_continuation() -> void:
	var state: GameState = _start_squadron_game(4, 2)
	var board: GameBoard = _board()
	await _complete_move(board, state, 0, 0)
	await get_tree().process_frame
	_assert_next_choice(board, state, 0, 1)
	await _complete_skip(board, state, 0, 1)
	_assert_next_choice(board, state, 1, 0)
	await _complete_attack_return(board, state, 1, 0)
	_assert_next_choice(board, state, 1, 1)
	await _complete_move(board, state, 1, 1)
	await get_tree().process_frame
	_assert_next_choice(board, state, 0, 0)
	var controller: SquadronPhaseController = board._squadron_phase_controller
	var third: SquadronInstance = state.get_squadron(0, 2)
	var fourth: SquadronInstance = state.get_squadron(0, 3)
	assert_true(controller.try_handle_squadron_click(_token(board, third)))
	assert_true(controller.try_handle_squadron_click(_token(board, fourth)))
	assert_false(third.has_activation_action_state())
	assert_false(fourth.has_activation_action_state(),
			"Candidate switching on the returned turn is transient.")
	controller.get_modal()._on_move_pressed()
	await get_tree().process_frame
	assert_true(fourth.has_activation_action_state(),
			"The returned controller can commit a new intent.")
	assert_false(third.has_activation_action_state())


func test_auto_pass_and_phase_exhaustion_follow_canonical_projection() -> void:
	var state: GameState = _start_squadron_game(3, 0)
	var board: GameBoard = _board()
	await _complete_move(board, state, 0, 0)
	await get_tree().process_frame
	_assert_next_choice(board, state, 0, 1)
	await _complete_skip(board, state, 0, 1)
	_assert_next_choice(board, state, 0, 0)
	await _complete_move(board, state, 0, 2)
	await get_tree().process_frame
	assert_ne(state.current_phase, Constants.GamePhase.SQUADRON)
	assert_false(board._squadron_phase_controller.is_modal_visible(),
			"Phase exhaustion must retire the Squadron surface.")


func test_network_handoff_keeps_observer_read_only_and_filtered_owner_actionable() \
		-> void:
	for actor: int in range(2):
		PlayMode.set_mode(PlayMode.Mode.NETWORK)
		NetworkManager.role = NetworkManager.Role.SERVER if actor == 0 \
				else NetworkManager.Role.CLIENT
		NetworkManager._local_player_index = actor
		var state: GameState = _start_squadron_game(1, 1, actor, true)
		var board: GameBoard = _board()
		await _complete_move(board, state, actor, 0)
		await get_tree().process_frame
		var next: int = 1 - actor
		assert_eq(state.squadron_phase_controller_player, next)
		assert_true(board._squadron_phase_controller.is_modal_visible())
		assert_false(board._squadron_phase_controller.get_modal()._is_interactable,
				"The retiring actor's Network surface remains read only.")
		var serialized: Dictionary = state.serialize()
		var filtered: Dictionary = StateFilter.filter_for_player(serialized, next)
		var client_state: GameState = GameState.deserialize_passive_network(filtered)
		assert_not_null(client_state)
		assert_eq(client_state.squadron_phase_controller_player, next)
		assert_eq(client_state.squadron_phase_activations_committed,
				state.squadron_phase_activations_committed)
		assert_eq(_history_types().count(
				CompleteSquadronActivationCommand.TYPE), 1)
		board.queue_free()
		await get_tree().process_frame
		PlayMode.set_mode(PlayMode.Mode.NETWORK)
		NetworkManager.role = NetworkManager.Role.CLIENT if actor == 0 \
				else NetworkManager.Role.SERVER
		NetworkManager._local_player_index = next
		GameManager.current_game_state = client_state
		GameManager.active_player = next
		GameManager.is_state_preloaded = true
		var client_board: GameBoard = _board()
		await get_tree().process_frame
		_assert_next_choice(client_board, client_state, next, 0)
		client_board.queue_free()
		await get_tree().process_frame


func _start_squadron_game(p0_count: int, p1_count: int,
		first_controller: int = 0, network: bool = false) -> GameState:
	var state := GameState.new()
	state.initialize()
	state.damage_deck = DamageDeck.new()
	state.damage_deck.set_rng(state.rng)
	state.damage_deck.initialize()
	var binding: MatchPlayerControlBinding = \
			MatchPlayerControlBinding.create_two_human() if network \
			else MatchPlayerControlBinding.create_hot_seat_human()
	assert_true(state.install_match_player_control_binding(binding))
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SQUADRON
	state.initiative_player = 0
	state.get_player_state(0).faction = Constants.Faction.REBEL_ALLIANCE
	state.get_player_state(1).faction = Constants.Faction.GALACTIC_EMPIRE
	for player: int in range(2):
		var count: int = p0_count if player == 0 else p1_count
		for index: int in range(count):
			var key: String = "x_wing_squadron" \
					if player == 0 else "tie_fighter_squadron"
			var squadron := SquadronInstance.create_from_data(
					key, AssetLoader.load_squadron_data(key), player)
			squadron.roster_entry_id = "bug069:%d:%d" % [player, index]
			squadron.pos_x = 0.15 + index * 0.08 if player == 0 \
					else 0.75 + index * 0.06
			squadron.pos_y = 0.25 if player == 0 else 0.75
			state.get_player_state(player).squadrons.append(squadron)
	assert_true(state.initialize_squadron_phase_progress(first_controller))
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SQUADRON_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT, first_controller)
	assert_true(GameManager.start_new_game_from_state(state, SCENARIO, 40))
	if network:
		GameManager.set_command_submitter(LocalCommandSubmitter.new(
				state.principal_id_for_player(first_controller)))
	return state


func _board() -> GameBoard:
	var board: GameBoard = BOARD.instantiate() as GameBoard
	add_child_autofree(board)
	board._command_router_adapter.reconstruct_presentation()
	return board


func _complete_move(board: GameBoard, state: GameState,
		player: int, index: int) -> void:
	var instance: SquadronInstance = state.get_squadron(player, index)
	var token: SquadronToken = _token(board, instance)
	assert_true(board._squadron_phase_controller.try_handle_squadron_click(token))
	var modal: SquadronActivationModal = \
			board._squadron_phase_controller.get_modal()
	modal._on_move_pressed()
	await get_tree().process_frame
	assert_true(instance.has_activation_action_state())
	assert_false(GameManager.submit_move_squadron(instance,
			instance.pos_x + 0.01, instance.pos_y).is_empty())
	var completed_before: int = _history_types().count(
			CompleteSquadronActivationCommand.TYPE)
	board._squadron_phase_controller._complete_accepted_move(
			instance, token, false)
	assert_eq(_history_types().count(
			CompleteSquadronActivationCommand.TYPE), completed_before + 1)
	if state.current_phase == Constants.GamePhase.SQUADRON:
		assert_true(instance.activated_this_round)


func _complete_skip(board: GameBoard, state: GameState,
		player: int, index: int) -> void:
	var instance: SquadronInstance = state.get_squadron(player, index)
	var controller: SquadronPhaseController = board._squadron_phase_controller
	assert_true(controller.try_handle_squadron_click(_token(board, instance)))
	controller.get_modal()._on_skip_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(instance.activated_this_round)


func _complete_attack_return(board: GameBoard, state: GameState,
		player: int, index: int) -> void:
	# The focused seam begins with an accepted, exhausted Attack action; attack
	# legality and damage are verified by their existing production-path tests.
	var instance: SquadronInstance = state.get_squadron(player, index)
	var controller: SquadronPhaseController = board._squadron_phase_controller
	assert_true(controller.try_handle_squadron_click(_token(board, instance)))
	assert_false(GameManager.activate_squadron(instance).is_empty())
	assert_true(instance.commit_attack_action_begun(
			instance.activation_id, false))
	controller.get_modal().notify_attack_completed()
	await get_tree().process_frame
	assert_true(instance.activated_this_round)


func _assert_next_choice(board: GameBoard, state: GameState,
		player: int, count: int) -> void:
	var modal: SquadronActivationModal = \
			board._squadron_phase_controller.get_modal()
	assert_eq(state.current_phase, Constants.GamePhase.SQUADRON)
	assert_eq(state.squadron_phase_controller_player, player)
	assert_eq(state.squadron_phase_activations_committed, count)
	assert_true(modal.visible,
			"Accepted result must remain visible after the old callback returns.")
	assert_eq(modal.get_state(),
			SquadronActivationModal.State.WAITING_FOR_SELECTION)
	assert_true(modal._is_interactable)


func _token(board: GameBoard,
		instance: SquadronInstance) -> SquadronToken:
	for token: SquadronToken in board.get_squadron_tokens():
		if token.get_squadron_instance() == instance:
			return token
	return null


func _history_types() -> Array[String]:
	var types: Array[String] = []
	for command: GameCommand in CommandProcessor.get_history():
		types.append(command.command_type)
	return types
