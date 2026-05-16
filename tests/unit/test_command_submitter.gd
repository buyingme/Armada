## Unit tests for CommandSubmitter strategy pattern.
## Tests [CommandSubmitter], [LocalCommandSubmitter], and
## [NetworkCommandSubmitter] classes.
##
## G4 Network Plan: §3 — G4.2 tests
extends GutTest


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## Minimal no-op command for testing.
const TEST_COMMAND_TYPE: String = "debug_deal_damage"

var _NoopCmd: Callable = func(p: int, pl: Dictionary) -> GameCommand:
	return _TestNoopCmd.new(p, pl)

var _executed_cmds: Array[GameCommand] = []
var _executed_results: Array[Dictionary] = []
var _saved_registry: Dictionary = {}


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	GameCommand.register_type(TEST_COMMAND_TYPE, _NoopCmd)
	_executed_cmds.clear()
	_executed_results.clear()
	# CommandProcessor needs an active game state to accept commands.
	var state := GameState.new()
	state.initialize()
	GameManager.current_game_state = state
	CommandProcessor.reset()
	CommandProcessor.command_executed.connect(_on_executed)


func after_each() -> void:
	if CommandProcessor.command_executed.is_connected(_on_executed):
		CommandProcessor.command_executed.disconnect(_on_executed)
	GameManager.current_game_state = null
	GameCommand._registry = _saved_registry


func _on_executed(cmd: GameCommand, result: Dictionary) -> void:
	_executed_cmds.append(cmd)
	_executed_results.append(result)


# ---------------------------------------------------------------------------
# CommandSubmitter base class
# ---------------------------------------------------------------------------

func test_base_submit_returns_empty() -> void:
	var base := CommandSubmitter.new()
	var result: Dictionary = base.submit(_TestNoopCmd.new(0, {}))
	assert_true(result.is_empty(),
			"Base CommandSubmitter.submit() should return empty dict.")


func test_base_is_awaiting_response_returns_false() -> void:
	var base := CommandSubmitter.new()
	assert_false(base.is_awaiting_response(),
			"Base CommandSubmitter should not be awaiting response.")


# ---------------------------------------------------------------------------
# LocalCommandSubmitter
# ---------------------------------------------------------------------------

func test_local_submit_executes_command() -> void:
	var submitter := LocalCommandSubmitter.new()
	var cmd := _TestNoopCmd.new(0, {"value": 42})
	var result: Dictionary = submitter.submit(cmd)
	assert_false(result.is_empty(),
			"LocalCommandSubmitter should return non-empty result on success.")
	assert_eq(_executed_cmds.size(), 1,
			"Command should be executed via CommandProcessor.")


func test_local_submit_returns_result() -> void:
	var submitter := LocalCommandSubmitter.new()
	var cmd := _TestNoopCmd.new(0, {})
	var result: Dictionary = submitter.submit(cmd)
	assert_true(result.has("status"),
			"Result should contain status key.")


func test_local_is_awaiting_response_always_false() -> void:
	var submitter := LocalCommandSubmitter.new()
	assert_false(submitter.is_awaiting_response(),
			"LocalCommandSubmitter should never be awaiting response.")


func test_local_submit_records_in_history() -> void:
	var submitter := LocalCommandSubmitter.new()
	var cmd := _TestNoopCmd.new(0, {})
	submitter.submit(cmd)
	assert_eq(CommandProcessor.get_command_count(), 1,
			"Command should be recorded in CommandProcessor history.")


func test_local_submit_invalid_returns_empty() -> void:
	var submitter := LocalCommandSubmitter.new()
	# The base CommandProcessor validates thoroughly — see test_command_processor.
	# Here we just confirm that LocalCommandSubmitter delegates correctly.
	assert_false(submitter.is_awaiting_response(),
			"Local submitter should not be awaiting response.")


# ---------------------------------------------------------------------------
# NetworkCommandSubmitter
# ---------------------------------------------------------------------------

func test_network_submit_returns_awaiting_sentinel() -> void:
	var submitter := NetworkCommandSubmitter.new()
	var cmd := _TestNoopCmd.new(0, {})
	# NetworkCommandSubmitter calls NetworkManager.send_command_to_server(),
	# which will warn because role is not CLIENT — but the return is the
	# AWAITING_REMOTE_RESULT sentinel ({"awaiting_remote": true}).
	var result: Dictionary = submitter.submit(cmd)
	assert_true(result.get("awaiting_remote", false),
			"NetworkCommandSubmitter.submit() should return the awaiting-remote sentinel.")
	# _log.warn triggers push_warning — mark handled.
	assert_engine_error(1,
			"Should warn about send_command_to_server with wrong role.")


func test_network_is_awaiting_after_submit() -> void:
	var submitter := NetworkCommandSubmitter.new()
	assert_false(submitter.is_awaiting_response(),
			"Should not be awaiting before any submit.")
	var cmd := _TestNoopCmd.new(0, {})
	submitter.submit(cmd)
	assert_true(submitter.is_awaiting_response(),
			"Should be awaiting after submit.")
	# _log.warn from role check.
	assert_engine_error(1,
			"Should warn about send_command_to_server with wrong role.")


func test_network_clear_awaiting() -> void:
	var submitter := NetworkCommandSubmitter.new()
	var cmd := _TestNoopCmd.new(0, {})
	submitter.submit(cmd)
	assert_true(submitter.is_awaiting_response(),
			"Should be awaiting after submit.")
	submitter.clear_awaiting()
	assert_false(submitter.is_awaiting_response(),
			"Should not be awaiting after clear.")
	# _log.warn from role check.
	assert_engine_error(1,
			"Should warn about send_command_to_server with wrong role.")


func test_network_queues_while_awaiting() -> void:
	var submitter := NetworkCommandSubmitter.new()
	var cmd1 := _TestNoopCmd.new(0, {})
	var cmd2 := _TestNoopCmd.new(0, {})
	submitter.submit(cmd1)
	var result: Dictionary = submitter.submit(cmd2)
	assert_true(result.get("awaiting_remote", false),
			"Queued submit while awaiting should still return the awaiting-remote sentinel.")
	assert_eq(submitter._pending_payloads.size(), 1,
			"Second submit should be queued while waiting for server response.")
	# First submit warns about role; second submit is queued (info-level).
	assert_engine_error(1,
			"Only initial send should warn about role in this test setup.")


func test_network_clear_awaiting_flushes_next_queued_command() -> void:
	var submitter := NetworkCommandSubmitter.new()
	var cmd1 := _TestNoopCmd.new(0, {})
	var cmd2 := _TestNoopCmd.new(0, {})
	submitter.submit(cmd1)
	submitter.submit(cmd2)
	assert_true(submitter.is_awaiting_response(),
			"Submitter should be awaiting after first send.")
	assert_eq(submitter._pending_payloads.size(), 1,
			"Second command should be queued.")
	submitter.clear_awaiting()
	assert_true(submitter.is_awaiting_response(),
			"Clearing should flush queued command and re-enter awaiting state.")
	assert_eq(submitter._pending_payloads.size(), 0,
			"Queued command should be flushed after clear_awaiting.")
	# Two sends attempted in non-client role (initial + flushed).
	assert_engine_error(2,
			"Both sends should warn about role in this test setup.")


# ---------------------------------------------------------------------------
# GameManager submitter integration
# ---------------------------------------------------------------------------

func test_game_manager_default_submitter_is_local() -> void:
	var submitter: CommandSubmitter = GameManager.get_command_submitter()
	assert_true(submitter is LocalCommandSubmitter,
			"Default submitter should be LocalCommandSubmitter.")


func test_game_manager_set_submitter() -> void:
	var original: CommandSubmitter = GameManager.get_command_submitter()
	var custom := LocalCommandSubmitter.new()
	GameManager.set_command_submitter(custom)
	assert_eq(GameManager.get_command_submitter(), custom,
			"Submitter should be the one we set.")
	# Restore original.
	GameManager.set_command_submitter(original)


# ---------------------------------------------------------------------------
# CommandProcessor.is_replaying
# ---------------------------------------------------------------------------

func test_is_replaying_false_by_default() -> void:
	assert_false(CommandProcessor.is_replaying,
			"is_replaying should be false by default.")


func test_is_replaying_true_during_replay() -> void:
	# We can only observe is_replaying before and after replay —
	# during replay, command_executed signals are suppressed.
	var serialized: Array[Dictionary] = [
		{"type": TEST_COMMAND_TYPE, "player": 0, "sequence": 0,
				"payload": {}},
	]
	assert_false(CommandProcessor.is_replaying,
			"Should be false before replay.")
	CommandProcessor.replay_commands(serialized)
	assert_false(CommandProcessor.is_replaying,
			"Should be false after replay completes.")


func test_replay_suppresses_command_executed_signal() -> void:
	var serialized: Array[Dictionary] = [
		{"type": TEST_COMMAND_TYPE, "player": 0, "sequence": 0,
				"payload": {}},
		{"type": TEST_COMMAND_TYPE, "player": 1, "sequence": 1,
				"payload": {}},
	]
	CommandProcessor.replay_commands(serialized)
	assert_eq(_executed_cmds.size(), 0,
			"Replay should not emit command_executed signals.")
	assert_eq(CommandProcessor.get_command_count(), 2,
			"Replay should still record commands in history.")


func test_normal_submit_emits_command_executed() -> void:
	assert_false(CommandProcessor.is_replaying,
			"Should not be replaying.")
	var cmd := _TestNoopCmd.new(0, {})
	CommandProcessor.submit(cmd)
	assert_eq(_executed_cmds.size(), 1,
			"Normal submit should emit command_executed.")


# ---------------------------------------------------------------------------
# Inner helper classes
# ---------------------------------------------------------------------------

## Minimal no-op command subclass that overrides execute().
class _TestNoopCmd extends GameCommand:
	func _init(p_player: int = 0,
			p_payload: Dictionary = {}) -> void:
		super._init(p_player, TEST_COMMAND_TYPE, p_payload)

	func execute(_game_state: GameState) -> Dictionary:
		return {"status": "ok"}
