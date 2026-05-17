## Test: CommandProcessor Rule Hooks
##
## Unit tests for Phase M6 RuleRegistry preflight validators and deferred
## observer follow-up queue semantics.
extends GutTest


const CmdProcessor: GDScript = preload("res://src/autoload/command_processor.gd")
const TEST_TYPE: String = "debug_deal_damage"

var _processor: Node
var _state: GameState
var _saved_registry: Dictionary = {}
var _executed_sources: Array[String] = []
var _history_counts_during_emit: Array[int] = []
var _rejected_reasons: Array[String] = []
var _validator_calls: Array[String] = []


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	RuleRegistry.clear()
	_processor = CmdProcessor.new()
	add_child_autofree(_processor)
	_state = GameState.new()
	_state.initialize()
	GameManager.current_game_state = _state
	_set_phase_and_flow(Constants.GamePhase.SHIP,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL)
	_executed_sources.clear()
	_history_counts_during_emit.clear()
	_rejected_reasons.clear()
	_validator_calls.clear()
	_processor.command_executed.connect(_on_executed)
	_processor.command_rejected.connect(_on_rejected)
	GameCommand.register_type(TEST_TYPE, func(p: int,
			pl: Dictionary) -> GameCommand:
		return _HookCommand.new(TEST_TYPE, p, pl))


func after_each() -> void:
	RuleRegistry.clear()
	GameManager.current_game_state = null
	GameCommand._registry = _saved_registry


func test_preflight_validator_denial_rejects_before_command_validate() -> void:
	RuleRegistry.register_validator(_validator(
			"deny", "roll_dice", Callable(self, "_deny_validator")))
	var cmd := _HookCommand.new("roll_dice")
	var result: Dictionary = _processor.submit(cmd)
	assert_true(result.is_empty(),
			"Denied rule validators should reject the command.")
	assert_false(cmd.validate_called,
			"Rule validators should run before command-specific validation.")
	assert_eq(_validator_calls, ["deny"],
			"The matching validator should be called once.")
	assert_eq(_rejected_reasons[0], "blocked by test rule",
			"Validator denial reason should be propagated.")
	assert_engine_error(1,
			"CommandProcessor should warn for the rule-validator rejection.")


func test_preflight_first_validator_denial_wins() -> void:
	RuleRegistry.register_validator(_validator(
			"deny", TEST_TYPE, Callable(self, "_deny_validator"), 20))
	RuleRegistry.register_validator(_validator(
			"after", TEST_TYPE, Callable(self, "_unexpected_validator")))
	var result: Dictionary = _processor.submit(_HookCommand.new(TEST_TYPE))
	assert_true(result.is_empty(),
			"The first denying validator should reject the command.")
	assert_eq(_validator_calls, ["deny"],
			"Validators after the first denial should not run.")
	assert_engine_error(1,
			"CommandProcessor should warn for the first validator denial.")


func test_preflight_applicability_rejects_before_rule_validators() -> void:
	_set_phase_and_flow(Constants.GamePhase.SHIP,
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT)
	RuleRegistry.register_validator(FlowHook.validator("should_not_run",
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			"commit_displacement",
			Callable(self, "_unexpected_validator")))
	var cmd := _HookCommand.new("commit_displacement")
	var result: Dictionary = _processor.submit(cmd)
	assert_true(result.is_empty(),
			"Applicability rejection should return an empty result.")
	assert_eq(_validator_calls, [],
			"Rule validators should not run after applicability rejects.")
	assert_false(cmd.validate_called,
			"Command-specific validation should also be skipped.")
	assert_engine_error(1,
			"CommandProcessor should warn for the applicability rejection.")


func test_observer_followup_drains_after_command_executed_returns() -> void:
	RuleRegistry.register_observer(_observer(
			"spawn_followup", Callable(self, "_observer_followup")))
	var result: Dictionary = _processor.submit(
			_HookCommand.new(TEST_TYPE, 0, {"source": "root"}))
	assert_eq(result.get("ok", false), true,
			"Triggering command should execute successfully.")
	assert_eq(_executed_sources, ["root", "observer"],
			"Observer follow-up should execute after the triggering command.")
	assert_eq(_history_counts_during_emit, [1, 2],
			"Follow-up should not drain until each command_executed emit returns.")
	assert_eq(_processor.get_command_count(), 2,
			"Triggering command and follow-up should both be recorded.")


func test_replay_commands_do_not_synthesize_observer_followups() -> void:
	RuleRegistry.register_observer(_observer(
			"spawn_followup", Callable(self, "_observer_followup")))
	var serialized: Array[Dictionary] = [{
		"type": TEST_TYPE,
		"player": 0,
		"sequence": 0,
		"payload": {"source": "root"},
	}]
	_processor.replay_commands(serialized)
	assert_eq(_processor.get_command_count(), 1,
			"Replay should record only the serialized command.")
	assert_eq(_executed_sources, [],
			"Replay should suppress command_executed and observer follow-ups.")


func test_submit_mirror_suppresses_observer_followups_but_emits() -> void:
	RuleRegistry.register_observer(_observer(
			"spawn_followup", Callable(self, "_observer_followup")))
	_processor.submit_mirror(_HookCommand.new(TEST_TYPE, 0, {"source": "root"}))
	assert_eq(_processor.get_command_count(), 1,
			"Mirrored commands should not synthesize observer follow-ups.")
	assert_eq(_executed_sources, ["root"],
			"Mirrored commands should still emit command_executed for UI refresh.")


func test_observer_cannot_submit_synchronously_while_collecting() -> void:
	RuleRegistry.register_observer(_observer(
			"sync_submit", Callable(self, "_observer_sync_submit")))
	_processor.submit(_HookCommand.new(TEST_TYPE, 0, {"source": "root"}))
	assert_eq(_processor.get_command_count(), 1,
			"Synchronous observer submits should not enter history.")
	assert_true(_rejected_reasons[0].contains(
			"Observer hooks must return follow-up commands"),
			"Synchronous observer submits should be rejected explicitly.")
	assert_engine_error(1,
			"CommandProcessor should warn for the synchronous observer submit.")


func test_rule_files_do_not_submit_commands_synchronously() -> void:
	var offenders: Array[String] = _rule_submit_offenders(
			"res://src/core/effects/rules")
	assert_eq(offenders, [],
			"Rule files should return observer follow-ups instead of submitting.")


func _on_executed(command: GameCommand, _result: Dictionary) -> void:
	_executed_sources.append(str(command.payload.get("source", "")))
	_history_counts_during_emit.append(_processor.get_command_count())


func _on_rejected(_command: GameCommand, reason: String) -> void:
	_rejected_reasons.append(reason)


func _set_phase_and_flow(phase: Constants.GamePhase,
		flow: Constants.InteractionFlow,
		step: Constants.InteractionStep) -> void:
	_state.current_phase = phase
	_state.interaction_flow = InteractionFlow.make(flow, step, -1)


func _validator(rule_id: String,
		command_type: String,
		callback: Callable,
		priority: int = 0) -> FlowHook:
	return FlowHook.validator(rule_id,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			command_type,
			callback,
			priority)


func _observer(rule_id: String, callback: Callable) -> FlowHook:
	return FlowHook.observer(rule_id,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			TEST_TYPE,
			callback)


func _deny_validator(_game_state: GameState,
		_command: GameCommand) -> Dictionary:
	_validator_calls.append("deny")
	return {"allowed": false, "reason": "blocked by test rule"}


func _unexpected_validator(_game_state: GameState,
		_command: GameCommand) -> Dictionary:
	_validator_calls.append("unexpected")
	return {"allowed": true, "reason": ""}


func _observer_followup(_game_state: GameState,
		command: GameCommand,
		_result: Dictionary) -> Array[GameCommand]:
	var followups: Array[GameCommand] = []
	if str(command.payload.get("source", "")) != "root":
		return followups
	followups.append(_HookCommand.new(TEST_TYPE, command.player_index,
			{"source": "observer"}))
	return followups


func _observer_sync_submit(_game_state: GameState,
		_command: GameCommand,
		_result: Dictionary) -> Array[GameCommand]:
	_processor.submit(_HookCommand.new(TEST_TYPE, 0, {"source": "sync"}))
	var followups: Array[GameCommand] = []
	return followups


func _rule_submit_offenders(root_path: String) -> Array[String]:
	var offenders: Array[String] = []
	_scan_rule_dir(root_path, offenders)
	return offenders


func _scan_rule_dir(path: String, offenders: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		_scan_rule_entry(path, file_name, dir.current_is_dir(), offenders)
		file_name = dir.get_next()
	dir.list_dir_end()


func _scan_rule_entry(path: String,
		file_name: String,
		is_dir: bool,
		offenders: Array[String]) -> void:
	if file_name.begins_with("."):
		return
	var child_path: String = path + "/" + file_name
	if is_dir:
		_scan_rule_dir(child_path, offenders)
	elif file_name.ends_with(".gd"):
		_scan_rule_file(child_path, offenders)


func _scan_rule_file(path: String, offenders: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text: String = file.get_as_text()
	if text.contains("CommandProcessor.submit") \
			or text.contains("GameManager.submit_"):
		offenders.append(path)


class _HookCommand extends GameCommand:
	var validate_called: bool = false

	func _init(p_type: String = TEST_TYPE,
			p_player: int = 0,
			p_payload: Dictionary = {}) -> void:
		super._init(p_player, p_type, p_payload)

	func validate(game_state: GameState) -> String:
		validate_called = true
		return super.validate(game_state)

	func execute(_game_state: GameState) -> Dictionary:
		return {"ok": true, "source": payload.get("source", "")}