extends GutTest

const PROCESSOR: GDScript = preload("res://src/autoload/command_processor.gd")


func test_elimination_installs_one_authoritative_result() -> void:
	var state: GameState = _state()
	(state.get_ship(1, 0) as ShipInstance).mark_destroyed()
	assert_eq(state.detected_terminal_reason(), "elimination")
	var command := CompleteMatchCommand.new(0, {})
	command.sequence = 41
	assert_eq(command.validate(state), "")
	var result: Dictionary = command.execute(state)
	assert_false(result.is_empty())
	assert_eq(result["terminal_match_result"]["result_id"],
			"match-result:41")
	assert_eq(result["terminal_match_result"]["winner_index"], 0)
	assert_eq(state.terminal_match_result,
			result["terminal_match_result"])
	assert_true(state.validate_terminal_match_result())
	assert_ne(command.validate(state), "")
	assert_true(command.execute(state).is_empty())


func test_premature_and_caller_supplied_outcome_reject_without_mutation() -> void:
	var state: GameState = _state()
	var command := CompleteMatchCommand.new(0, {})
	command.sequence = 42
	assert_ne(command.validate(state), "")
	assert_true(command.execute(state).is_empty())
	assert_true(state.terminal_match_result.is_empty())
	(state.get_ship(1, 0) as ShipInstance).mark_destroyed()
	var forged := CompleteMatchCommand.new(0, {"winner_index": 0})
	forged.sequence = 43
	assert_ne(forged.validate(state), "")
	assert_true(forged.execute(state).is_empty())
	assert_true(state.terminal_match_result.is_empty())


func test_mutual_elimination_scores_before_one_result() -> void:
	var state: GameState = _state()
	(state.get_ship(0, 0) as ShipInstance).mark_destroyed()
	(state.get_ship(1, 0) as ShipInstance).mark_destroyed()
	assert_eq(state.detected_terminal_reason(), "mutual_destruction")
	var command := CompleteMatchCommand.new(0, {})
	command.sequence = 44
	var result: Dictionary = command.execute(state)
	assert_false(result.is_empty())
	assert_eq(result["terminal_match_result"]["reason"],
			"mutual_destruction")
	assert_eq(result["terminal_match_result"]["scores"], [37, 37])


func test_final_status_proof_precedes_round_limit_result() -> void:
	var state: GameState = _state()
	state.current_phase = Constants.GamePhase.STATUS
	state.current_round = Constants.MAX_ROUNDS
	assert_eq(state.detected_terminal_reason(), "")
	assert_ne(CompleteMatchCommand.new(0, {}).validate(state), "")
	state.final_status_cleanup_round = Constants.MAX_ROUNDS
	assert_eq(state.detected_terminal_reason(), "round_6")
	var command := CompleteMatchCommand.new(0, {})
	command.sequence = 45
	var result: Dictionary = command.execute(state)
	assert_eq(result["terminal_match_result"]["reason"], "round_6")
	assert_true(state.validate_terminal_match_result())


func test_terminal_application_rejects_forged_result_before_mutation() -> void:
	var authority: GameState = _state()
	var passive: GameState = _state()
	(authority.get_ship(1, 0) as ShipInstance).mark_destroyed()
	(passive.get_ship(1, 0) as ShipInstance).mark_destroyed()
	var command := CompleteMatchCommand.new(0, {})
	command.sequence = 46
	var result: Dictionary = command.execute(authority)
	var forged: Dictionary = result.duplicate(true)
	forged["terminal_match_result"]["winner_index"] = 1
	var mirror := CompleteMatchCommand.new(0, {})
	mirror.sequence = 46
	var before: Dictionary = passive.serialize()
	assert_true(mirror.execute_with_application_result(passive, forged).is_empty())
	assert_eq(passive.serialize(), before)
	assert_eq(mirror.execute_with_application_result(passive, result), result)
	assert_eq(passive.terminal_match_result, authority.terminal_match_result)
	assert_ne(CommandProcessor.preflight(
			AdvancePhaseCommand.new(0, {}), passive), "")


func test_nonfixture_replay_keeps_one_terminal_command_and_result() -> void:
	var previous: GameState = GameManager.current_game_state
	var authority: GameState = _state()
	(authority.get_ship(1, 0) as ShipInstance).mark_destroyed()
	GameManager.current_game_state = authority
	var processor: Node = PROCESSOR.new()
	add_child_autofree(processor)
	assert_false(processor.submit(CompleteMatchCommand.new(0, {})).is_empty())
	var replay: GameReplay = processor.create_replay()
	assert_not_null(replay)
	var loaded: GameReplay = GameReplay.deserialize(
			JSON.parse_string(JSON.stringify(replay.serialize())))
	assert_not_null(loaded)
	assert_eq(loaded.commands.size(), 1)
	assert_eq((loaded.commands[0] as Dictionary)["type"], "complete_match")
	var replay_state: GameState = _state()
	(replay_state.get_ship(1, 0) as ShipInstance).mark_destroyed()
	GameManager.current_game_state = replay_state
	var replay_processor: Node = PROCESSOR.new()
	add_child_autofree(replay_processor)
	var recorded: GameCommand = GameCommand.deserialize(
			loaded.commands[0] as Dictionary)
	assert_not_null(recorded)
	assert_false(replay_processor.submit_replay(recorded).is_empty())
	assert_eq(replay_state.terminal_match_result,
			authority.terminal_match_result)
	assert_eq(replay_processor.get_history().size(), 1)
	GameManager.current_game_state = previous


func _state() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	state.current_round = 2
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	for owner: int in [0, 1]:
		var data := ShipData.new()
		data.hull = 4
		data.point_cost = 37
		var ship := ShipInstance.create_from_data(
				"terminal-test:%d" % owner, data, 1, owner)
		ship.roster_entry_id = "terminal-test:%d" % owner
		state.get_player_state(owner).ships.append(ship)
	return state
