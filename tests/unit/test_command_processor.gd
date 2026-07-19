## Tests for CommandProcessor autoload.
## Validates the submit → validate → execute → record pipeline,
## rejection flow, history tracking, serialization, and replay.
extends GutTest


const CmdProcessor := preload("res://src/autoload/command_processor.gd")
const TEST_NOOP_TYPE: String = "debug_deal_damage"
const TEST_FAILING_TYPE: String = "publish_attack_flow"

var _processor: Node
var _state: GameState
var _executed_cmds: Array[GameCommand] = []
var _rejected_cmds: Array[GameCommand] = []
var _rejected_reasons: Array[String] = []
var _saved_registry: Dictionary = {}


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	_processor = CmdProcessor.new()
	add_child_autofree(_processor)
	_state = GameState.new()
	_state.initialize()
	GameManager.current_game_state = _state
	_executed_cmds.clear()
	_rejected_cmds.clear()
	_rejected_reasons.clear()
	_processor.command_executed.connect(_on_executed)
	_processor.command_rejected.connect(_on_rejected)
	# Use declared global command types so M4 applicability stays active.
	GameCommand.register_type(TEST_NOOP_TYPE, func(p: int,
			pl: Dictionary) -> GameCommand:
		return _NoopCommand.new(p, pl))
	GameCommand.register_type(TEST_FAILING_TYPE, func(p: int,
			pl: Dictionary) -> GameCommand:
		return _FailingCommand.new(p, pl))


func after_each() -> void:
	GameManager.current_game_state = null
	GameCommand._registry = _saved_registry


func _on_executed(command: GameCommand, _result: Dictionary) -> void:
	_executed_cmds.append(command)


func _on_rejected(command: GameCommand, reason: String) -> void:
	_rejected_cmds.append(command)
	_rejected_reasons.append(reason)


# ------------------------------------------------------------------
# Submit — happy path
# ------------------------------------------------------------------

func test_submit_executes_valid_command() -> void:
	var cmd := _NoopCommand.new(0, {"a": 1})
	var result: Dictionary = _processor.submit(cmd)
	assert_eq(result.get("ok", false), true,
			"Valid command should return its execution result.")
	assert_eq(_processor.get_command_count(), 1,
			"History should contain 1 command.")
	assert_eq(cmd.sequence, 0,
			"First command should have sequence 0.")
	assert_eq(_executed_cmds.size(), 1,
			"command_executed signal should fire once.")


func test_submit_increments_sequence() -> void:
	_processor.submit(_NoopCommand.new(0))
	_processor.submit(_NoopCommand.new(1))
	var history: Array[GameCommand] = _processor.get_history()
	assert_eq(history[0].sequence, 0, "First seq should be 0.")
	assert_eq(history[1].sequence, 1, "Second seq should be 1.")


# ------------------------------------------------------------------
# Submit — rejection
# ------------------------------------------------------------------

func test_submit_rejects_when_no_game_state() -> void:
	GameManager.current_game_state = null
	var cmd := _NoopCommand.new(0)
	var result: Dictionary = _processor.submit(cmd)
	assert_true(result.is_empty(),
			"Rejected command should return empty dict.")
	assert_eq(_rejected_cmds.size(), 1,
			"command_rejected should fire once.")
	assert_eq(_processor.get_command_count(), 0,
			"Rejected command should not be in history.")
	# _log.warn triggers push_warning — mark handled.
	assert_engine_error(1,
			"Should warn about rejected command.")


func test_submit_rejects_on_custom_validation_failure() -> void:
	# Register a type whose validate always fails.
	var cmd := _FailingCommand.new(0, {})
	var result: Dictionary = _processor.submit(cmd)
	assert_true(result.is_empty(),
			"Failing validation should return empty dict.")
	assert_eq(_rejected_reasons[0], "always fails",
			"Rejection reason should propagate.")
	# _log.warn triggers push_warning — mark handled.
	assert_engine_error(1,
			"Should warn about rejected command.")


# ------------------------------------------------------------------
# History & reset
# ------------------------------------------------------------------

func test_get_history_returns_ordered_commands() -> void:
	_processor.submit(_NoopCommand.new(0, {"i": 1}))
	_processor.submit(_NoopCommand.new(1, {"i": 2}))
	_processor.submit(_NoopCommand.new(0, {"i": 3}))
	var history: Array[GameCommand] = _processor.get_history()
	assert_eq(history.size(), 3, "History should have 3 entries.")
	assert_eq(history[0].payload.get("i", 0), 1,
			"First command payload should be i=1.")
	assert_eq(history[2].payload.get("i", 0), 3,
			"Third command payload should be i=3.")


func test_reset_clears_history_and_sequence() -> void:
	_processor.submit(_NoopCommand.new(0))
	_processor.submit(_NoopCommand.new(0))
	_processor.reset()
	assert_eq(_processor.get_command_count(), 0,
			"History should be empty after reset.")
	_processor.submit(_NoopCommand.new(0))
	assert_eq(_processor.get_history()[0].sequence, 0,
			"Sequence should restart from 0 after reset.")


# ------------------------------------------------------------------
# Serialization
# ------------------------------------------------------------------

func test_serialize_history_roundtrip() -> void:
	_processor.submit(_NoopCommand.new(0, {"x": 10}))
	_processor.submit(_NoopCommand.new(1, {"y": 20}))
	var serialized: Array[Dictionary] = \
			_processor.serialize_history()
	assert_eq(serialized.size(), 2,
			"Serialized history should have 2 entries.")
	assert_eq(serialized[0]["type"], TEST_NOOP_TYPE,
			"First entry type should match.")
	assert_eq(serialized[1]["player"], 1,
			"Second entry player should be 1.")
	assert_eq(serialized[0]["sequence"], 0,
			"First entry sequence should be 0.")


# ------------------------------------------------------------------
# Replay
# ------------------------------------------------------------------

func test_replay_commands_populates_history() -> void:
	var serialized: Array[Dictionary] = [
		{"type": TEST_NOOP_TYPE, "player": 0, "sequence": 0,
				"payload": {"k": 1}},
		{"type": TEST_NOOP_TYPE, "player": 1, "sequence": 1,
				"payload": {"k": 2}},
	]
	_processor.replay_commands(serialized)
	assert_eq(_processor.get_command_count(), 2,
			"Replay should add 2 commands to history.")
	assert_eq(_executed_cmds.size(), 0,
			"Replay should suppress command_executed signals.")


func test_replay_skips_unknown_types() -> void:
	var serialized: Array[Dictionary] = [
		{"type": "_unknown_xyz", "player": 0, "sequence": 0,
				"payload": {}},
		{"type": TEST_NOOP_TYPE, "player": 0, "sequence": 1,
				"payload": {}},
	]
	_processor.replay_commands(serialized)
	assert_eq(_processor.get_command_count(), 0,
			"A replay sequence gap should fail closed before mutation.")
	# Unknown-type warning, skip warning, and sequence rejection warning.
	assert_engine_error(3,
			"Unknown replay data should fail with deterministic diagnostics.")


# ------------------------------------------------------------------
# Helpers: test command subclasses
# ------------------------------------------------------------------

## Noop command that overrides execute to avoid base-class push_warning.
class _NoopCommand extends GameCommand:
	func _init(p_player: int = 0,
			p_payload: Dictionary = {}) -> void:
		super._init(p_player, TEST_NOOP_TYPE, p_payload)

	func execute(_game_state: GameState) -> Dictionary:
		return {"ok": true}


## Command that always fails validation.
class _FailingCommand extends GameCommand:
	func _init(p_player: int = 0,
			p_payload: Dictionary = {}) -> void:
		super._init(p_player, TEST_FAILING_TYPE, p_payload)

	func validate(_game_state: GameState) -> String:
		return "always fails"
