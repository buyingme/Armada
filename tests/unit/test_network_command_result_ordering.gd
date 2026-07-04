## Test: network command result ordering
##
## Focused regressions for client-side application of authoritative server
## command results in server sequence order.
extends GutTest


var _saved_play_mode: PlayMode.Mode
var _saved_role: NetworkManager.Role
var _saved_local_player_index: int = -1
var _saved_state: GameState = null
var _saved_active: bool = false
var _saved_submitter: CommandSubmitter = null
var _saved_registry: Dictionary = {}


func before_each() -> void:
	_saved_play_mode = PlayMode.current_mode
	_saved_role = NetworkManager.role
	_saved_local_player_index = NetworkManager._local_player_index
	_saved_state = GameManager.current_game_state
	_saved_active = GameManager.is_game_active
	_saved_submitter = GameManager.get_command_submitter()
	_saved_registry = GameCommand._registry.duplicate()
	GameCommand._registry.clear()
	AssignDialCommand.register()
	AdvancePhaseCommand.register()
	TarkinChoiceCommand.register()
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1


func after_each() -> void:
	PlayMode.current_mode = _saved_play_mode
	NetworkManager.role = _saved_role
	NetworkManager._local_player_index = _saved_local_player_index
	GameManager.current_game_state = _saved_state
	GameManager.is_game_active = _saved_active
	GameManager.set_command_submitter(_saved_submitter)
	GameCommand._registry = _saved_registry
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()


func test_network_result_ordering_buffers_later_sequence_until_gap_filled() -> void:
	var state: GameState = _install_client_state(false)
	var assign: AssignDialCommand = _assign_cmd(
			0, 0, Constants.CommandType.NAVIGATE, 0)
	var advance: AdvancePhaseCommand = _advance_cmd(1)

	GameManager._on_network_command_result(
			advance.serialize(), _advance_result())

	assert_eq(state.current_phase, Constants.GamePhase.COMMAND,
			"Client must not mirror later advance_phase before sequence 0.")
	assert_eq(CommandProcessor.get_command_count(), 0,
			"Buffered later command should not enter local history yet.")
	assert_eq(GameManager._pending_network_results.size(), 1,
			"Out-of-order advance should be buffered.")

	GameManager._on_network_command_result(
			assign.serialize(), _assign_result(0))

	assert_eq(CommandProcessor.get_command_count(), 2,
			"Missing earlier result should flush assign_dials then advance_phase.")
	assert_eq(CommandProcessor.get_history()[0].command_type, "assign_dials",
			"Earlier assign_dials should mirror first.")
	assert_eq(CommandProcessor.get_history()[1].command_type, "advance_phase",
			"Buffered advance_phase should mirror second.")
	assert_eq(state.current_phase, Constants.GamePhase.SHIP,
			"Client should enter Ship Phase only after earlier result applies.")


func test_network_result_ordering_does_not_enter_ship_before_missing_dial() -> void:
	var state: GameState = _install_client_state(false)
	var first: AssignDialCommand = _assign_cmd(
			1, 0, Constants.CommandType.NAVIGATE, 0)
	var missing: AssignDialCommand = _assign_cmd(
			1, 1, Constants.CommandType.REPAIR, 1)
	var advance: AdvancePhaseCommand = _advance_cmd(2)

	GameManager._on_network_command_result(
			first.serialize(), _assign_result(0))
	GameManager._on_network_command_result(
			advance.serialize(), _advance_result())

	assert_eq(state.current_phase, Constants.GamePhase.COMMAND,
			"Client must stay in Command Phase while sequence 1 is missing.")
	assert_eq(_ship(state, 1, 1).command_dial_stack.get_dial_count(), 0,
			"Second Imperial ship should still be missing its dial.")

	GameManager._on_network_command_result(
			missing.serialize(), _assign_result(1))

	assert_eq(state.current_phase, Constants.GamePhase.SHIP,
			"Client should enter Ship Phase after the missing dial applies.")
	assert_eq(_ship(state, 1, 1).command_dial_stack.get_dial_count(), 1,
			"Missing dial should be applied before phase advancement.")


func test_network_tarkin_command_phase_mirrors_all_imperial_dials_expected() -> void:
	var state: GameState = _install_client_state(true)
	var rebel: AssignDialCommand = _assign_cmd(
			0, 0, Constants.CommandType.SQUADRON, 0)
	var imperial_first: AssignDialCommand = _assign_cmd(
			1, 0, Constants.CommandType.NAVIGATE, 1)
	var imperial_second: AssignDialCommand = _assign_cmd(
			1, 1, Constants.CommandType.REPAIR, 2)
	var advance: AdvancePhaseCommand = _advance_cmd(3)

	GameManager._on_network_command_result(
			rebel.serialize(), _assign_result(0))
	GameManager._on_network_command_result(
			imperial_first.serialize(), _assign_result(0))
	GameManager._on_network_command_result(
			advance.serialize(), _advance_result())

	assert_eq(state.current_phase, Constants.GamePhase.COMMAND,
			"Tarkin prompt must not appear before all earlier dials mirror.")
	assert_eq(_ship(state, 1, 1).command_dial_stack.get_dial_count(), 0,
			"Second Imperial dial should still be pending before sequence 2.")

	GameManager._on_network_command_result(
			imperial_second.serialize(), _assign_result(1))

	assert_eq(state.current_phase, Constants.GamePhase.SHIP,
			"Client should enter Ship Phase after all dial results mirror.")
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.TARKIN_COMMAND_CHOICE,
			"Tarkin prompt should appear after ordered Command Phase results.")
	assert_eq(_ship(state, 1, 0).command_dial_stack.get_dial_count(), 1,
			"First Imperial ship should have its mirrored command dial.")
	assert_eq(_ship(state, 1, 1).command_dial_stack.get_dial_count(), 1,
			"Second Imperial ship should have its mirrored command dial.")


func _install_client_state(with_tarkin: bool) -> GameState:
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	var state: GameState = _make_command_phase_state(with_tarkin)
	GameManager.current_game_state = state
	GameManager.is_game_active = true
	GameManager._command_submitted = [false, false]
	GameManager._command_assigning_player = -1
	GameManager._activating_ship = null
	GameManager._activating_squadron = null
	GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	return state


func _make_command_phase_state(with_tarkin: bool) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.COMMAND
	state.initiative_player = 0
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.COMMAND_PHASE,
			Constants.InteractionStep.SELECT_DIALS,
			1)
	state.get_player_state(0).ships.append(
			_make_ship(0, "rebel-ship-1", false))
	state.get_player_state(1).ships.append(
			_make_ship(1, "imperial-ship-1", with_tarkin))
	state.get_player_state(1).ships.append(
			_make_ship(1, "imperial-ship-2", false))
	return state


func _make_ship(owner: int,
		roster_entry_id: String,
		with_tarkin: bool) -> ShipInstance:
	var ship_data: ShipData = AssetLoader.load_ship_data(
			"victory_ii_class_star_destroyer")
	var ship: ShipInstance = ShipInstance.create_from_data(
			"victory_ii_class_star_destroyer", ship_data, 2, owner)
	ship.roster_entry_id = roster_entry_id
	ship.command_dial_stack = CommandDialStack.create(1)
	ship.command_tokens = CommandTokenManager.create(1)
	if with_tarkin:
		ship.add_runtime_upgrade("grand_moff_tarkin", "imperial-cmd",
				"COMMANDER", 0)
	return ship


func _assign_cmd(player: int,
		ship_index: int,
		command: int,
		sequence: int) -> AssignDialCommand:
	var cmd := AssignDialCommand.new(player, {
		"ship_index": ship_index,
		"commands": [int(command)],
	})
	cmd.sequence = sequence
	return cmd


func _advance_cmd(sequence: int) -> AdvancePhaseCommand:
	var cmd := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.SHIP),
	})
	cmd.sequence = sequence
	return cmd


func _assign_result(ship_index: int) -> Dictionary:
	return {"success": true, "ship_index": ship_index}


func _advance_result() -> Dictionary:
	return {
		"previous_phase": int(Constants.GamePhase.COMMAND),
		"new_phase": int(Constants.GamePhase.SHIP),
	}


func _ship(state: GameState, player: int, ship_index: int) -> ShipInstance:
	return state.get_ship(player, ship_index)
