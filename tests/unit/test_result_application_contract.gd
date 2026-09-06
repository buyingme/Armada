extends GutTest


var _saved_state: GameState


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	var state := GameState.new()
	state.initialize()
	GameManager.current_game_state = state
	CommandProcessor.reset()


func after_each() -> void:
	CommandProcessor.reset()
	GameManager.current_game_state = _saved_state


func _envelope(application: Dictionary = {}) -> Dictionary:
	return {
		"protocol_version": NetworkManager.PROTOCOL_VERSION,
		"application_contract": "fixture_result",
		"application_contract_version": 1,
		"viewer_player": 1,
		"application_result": application,
		"presentation_result": {},
	}


func _command(sequence: int = 0) -> FixtureResultCommand:
	var command := FixtureResultCommand.new()
	command.sequence = sequence
	return command


func test_present_empty_application_result_commits_once() -> void:
	var command := _command()
	assert_eq(CommandProcessor.submit_mirror(command, _envelope(), 1),
			{"applied": true})
	assert_eq(GameManager.current_game_state.current_round, 1)
	assert_eq(CommandProcessor.get_next_sequence(), 1)
	assert_eq(CommandProcessor.get_command_count(), 1)


func test_missing_application_result_is_not_empty_application_result() -> void:
	var envelope := _envelope()
	envelope.erase("application_result")
	assert_eq(CommandProcessor.submit_mirror(_command(), envelope, 1), {})
	assert_eq(GameManager.current_game_state.current_round, 0)
	assert_eq(CommandProcessor.get_next_sequence(), 0)
	assert_engine_error(1)


func test_wrong_binding_and_unknown_envelope_fields_fail_closed() -> void:
	for patch: Dictionary in [
		{"application_contract": "wrong"},
		{"application_contract_version": 2},
		{"viewer_player": 0},
		{"protocol_version": NetworkManager.PROTOCOL_VERSION - 1},
		{"unknown": true},
	]:
		var envelope := _envelope()
		envelope.merge(patch, true)
		assert_eq(CommandProcessor.submit_mirror(_command(), envelope, 1), {})
		assert_eq(GameManager.current_game_state.current_round, 0)
	assert_eq(CommandProcessor.get_next_sequence(), 0)
	assert_eq(CommandProcessor.get_command_count(), 0)
	assert_engine_error(5)


func test_malformed_application_result_does_not_mutate_or_record() -> void:
	assert_eq(CommandProcessor.submit_mirror(
			_command(), _envelope({"forbidden": true}), 1), {})
	assert_eq(GameManager.current_game_state.current_round, 0)
	assert_eq(CommandProcessor.get_next_sequence(), 0)
	assert_eq(CommandProcessor.get_command_count(), 0)
	assert_engine_error(1)


class FixtureResultCommand extends GameCommand:
	func _init() -> void:
		super._init(0, "debug_deal_damage", {})

	func application_contract_id() -> String:
		return "fixture_result"

	func execute(_game_state: GameState) -> Dictionary:
		return {"authority_only": true}

	func execute_with_application_result(game_state: GameState,
			application_result: Dictionary) -> Dictionary:
		if not application_result.is_empty():
			return {}
		game_state.current_round += 1
		return {"applied": true}
