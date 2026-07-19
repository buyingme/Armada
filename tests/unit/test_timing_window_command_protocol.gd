## Focused Slice 5 command-stream protocol tests with deterministic fixtures.
extends GutTest


const PROCESSOR_SCRIPT: GDScript = preload(
		"res://src/autoload/command_processor.gd")
const COMMANDS: GDScript = preload(
		"res://tests/fixtures/timing_window_command_fixtures.gd")
const PARTICIPANT: GDScript = preload(
		"res://tests/fixtures/timing_window_participant_fixture.gd")
const ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")

var _processor: Node = null
var _state: GameState = null
var _saved_registry: Dictionary = {}
var _history_types: Array[String] = []


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	RuleRegistry.clear()
	_history_types.clear()
	_state = _make_state(["source-a"])
	GameManager.current_game_state = _state
	_processor = PROCESSOR_SCRIPT.new()
	add_child_autofree(_processor)
	COMMANDS.register()
	assert_true(COMMANDS.register_participant(),
			"Fixture participant should register for protocol tests.")
	_processor.command_executed.connect(_record_history_type)


func after_each() -> void:
	RuleRegistry.clear()
	GameManager.current_game_state = null
	GameCommand._registry = _saved_registry


func test_open_use_and_continuation_execute_in_authoritative_order() -> void:
	assert_false(_processor.submit(COMMANDS.make_open()).is_empty(),
			"Fixture opening command should enter the normal command path.")
	var use: GameCommand = COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, _state, "source-a")
	assert_false(_processor.submit(use).is_empty(),
			"Fixture use command should resolve one opportunity.")

	assert_eq(_history_types, [
		COMMANDS.OPEN_TYPE,
		COMMANDS.USE_TYPE,
		COMMANDS.CONTINUATION_TYPE,
	], "Opening, use, and continuation should have one stable command order.")
	assert_true(bool(_state.objectives.get(COMMANDS.COMPLETED_KEY, false)),
			"Continuation should perform its authoritative fixture mutation.")
	assert_true(_state.timing_window_state.is_inactive(),
			"Successful continuation should close shared lifecycle state.")


func test_decline_is_explicit_serializable_and_replayable() -> void:
	_processor.submit(COMMANDS.make_open())
	var decline: GameCommand = COMMANDS.make_resolution(
			COMMANDS.DECLINE_TYPE, _state, "source-a")
	var serialized: Dictionary = decline.serialize()
	var restored: GameCommand = GameCommand.deserialize(serialized)

	assert_not_null(restored,
			"Explicit decline should deserialize through command registration.")
	assert_eq(restored.command_type, COMMANDS.DECLINE_TYPE,
			"Decline command type should survive serialization.")
	_processor.submit(decline)
	assert_eq(_history_types[1], COMMANDS.DECLINE_TYPE,
			"Decline should be recorded as its own authoritative command.")


func test_one_command_resolves_one_source_and_remaining_blocker_prevents_continue() -> void:
	_state.objectives[PARTICIPANT.SOURCES_KEY] = ["source-a", "source-b"]
	_processor.submit(COMMANDS.make_open())
	_processor.submit(COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, _state, "source-a"))

	assert_eq(_history_types, [COMMANDS.OPEN_TYPE, COMMANDS.USE_TYPE],
			"A remaining blocker should prevent continuation from entering history.")
	assert_eq(_state.timing_window_state.status, TimingWindowState.STATUS_OPEN,
			"Lifecycle should stay open while source-b remains unresolved.")
	assert_false(bool((_state.objectives.get(
			PARTICIPANT.RESOLVED_KEY) as Dictionary).get("source-b", false)),
			"Resolving source-a must not choose or mutate source-b.")


func test_wrong_player_flow_lifecycle_source_and_repeat_reject_without_mutation() -> void:
	_processor.submit(COMMANDS.make_open())
	var wrong_player: GameCommand = COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, _state, "source-a", 1)
	assert_eq(_processor.submit(wrong_player), {},
			"Wrong controller should reject.")
	var stale: GameCommand = COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, _state, "source-a")
	stale.payload["lifecycle_id"] = "attack_modify:stale"
	assert_eq(_processor.submit(stale), {},
			"Stale lifecycle identity should reject.")
	var missing: GameCommand = COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, _state, "missing")
	assert_eq(_processor.submit(missing), {},
			"Missing runtime source should reject.")
	var wrong_flow: GameCommand = COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, _state, "source-a")
	_state.interaction_flow.step_id = Constants.InteractionStep.ATTACK_ROLL
	assert_eq(_processor.submit(wrong_flow), {},
			"Wrong FlowSpec step should reject at applicability.")
	_state.interaction_flow.step_id = Constants.InteractionStep.ATTACK_MODIFY
	var use: GameCommand = COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, _state, "source-a")
	_processor.submit(use)
	var repeated: GameCommand = COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, _state, "source-a")
	assert_eq(_processor.submit(repeated), {},
			"Repeated resolution should reject without mutation.")
	assert_eq(int(_state.objectives.get(COMMANDS.MUTATION_COUNT_KEY, 0)), 1,
			"Only the accepted command should mutate fixture rule state.")
	assert_engine_error(5,
			"Every rejected fixture command should produce one diagnostic.")


func test_duplicate_open_and_stale_cancel_reject_deterministically() -> void:
	_processor.submit(COMMANDS.make_open())
	assert_eq(_processor.submit(COMMANDS.make_open()), {},
			"Duplicate fixture opening should reject.")
	var stale_cancel: GameCommand = COMMANDS.make_cancel(_state)
	stale_cancel.payload["lifecycle_id"] = "attack_modify:stale"
	assert_eq(_processor.submit(stale_cancel), {},
			"Stale cancellation should reject.")
	assert_true(_state.timing_window_state.active,
			"Rejected opening/cancellation should preserve lifecycle state.")
	assert_engine_error(2,
			"Duplicate opening and stale cancellation should be diagnosed.")


func test_explicit_cancellation_cleans_shared_and_fixture_state_after_success() -> void:
	_processor.submit(COMMANDS.make_open())
	_state.objectives[PARTICIPANT.RESOLVED_KEY] = {"source-a": true}
	var result: Dictionary = _processor.submit(COMMANDS.make_cancel(_state))

	assert_true(result.get("fixture_cancelled", false),
			"Replayable cancellation should own its fixture mutation.")
	assert_true(_state.timing_window_state.is_inactive(),
			"Successful cancellation should clear shared lifecycle state.")
	assert_eq(_state.objectives.get(PARTICIPANT.RESOLVED_KEY), {},
			"Cancellation command should clear fixture-owned guard state.")


func test_continuation_failure_preserves_closing_lifecycle_and_rule_state() -> void:
	_processor.submit(COMMANDS.make_open())
	_state.objectives[COMMANDS.CONTINUATION_FAILURE_KEY] = true
	_processor.submit(COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, _state, "source-a"))

	assert_eq(_history_types, [COMMANDS.OPEN_TYPE, COMMANDS.USE_TYPE],
			"Rejected continuation should not enter history.")
	assert_eq(_state.timing_window_state.status,
			TimingWindowState.STATUS_CLOSING,
			"Continuation failure should preserve the active closing lifecycle.")
	assert_true(bool((_state.objectives.get(
			PARTICIPANT.RESOLVED_KEY) as Dictionary).get("source-a", false)),
			"Continuation failure should preserve fixture-owned resolution state.")
	assert_eq(_processor.get_pending_observer_followup_count(), 0,
			"Continuation failure should queue no retry or fallback.")
	assert_engine_error(1,
			"Forced continuation rejection should be diagnosed once.")


func test_observer_followup_runs_before_stale_continuation() -> void:
	RuleRegistry.register_observer(FlowHook.observer(
			"fixture_followup",
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			COMMANDS.USE_TYPE,
			Callable(self, "_late_blocker_followup")))
	_processor.submit(COMMANDS.make_open())
	_processor.submit(COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, _state, "source-a"))

	assert_eq(_history_types, [
		COMMANDS.OPEN_TYPE,
		COMMANDS.USE_TYPE,
		COMMANDS.FOLLOWUP_TYPE,
	], "Observer follow-up should remain ahead of the stale continuation.")
	assert_eq(_state.timing_window_state.status, TimingWindowState.STATUS_OPEN,
			"Follow-up-created blocker should restore closing lifecycle to open.")
	assert_false(bool(_state.objectives.get(COMMANDS.COMPLETED_KEY, false)),
			"Stale continuation must not mutate after a blocker appears.")
	assert_engine_error(1,
			"The queued stale continuation should reject once.")


func test_replay_consumes_recorded_continuation_without_synthesizing_duplicate() -> void:
	_processor.submit(COMMANDS.make_open())
	_processor.submit(COMMANDS.make_resolution(
			COMMANDS.DECLINE_TYPE, _state, "source-a"))
	var recorded: Array[Dictionary] = _processor.serialize_history()

	var replay_state: GameState = _make_state(["source-a"])
	GameManager.current_game_state = replay_state
	var replay_processor: Node = PROCESSOR_SCRIPT.new()
	add_child_autofree(replay_processor)
	COMMANDS.register()
	RuleRegistry.clear()
	COMMANDS.register_participant()
	replay_processor.replay_commands(recorded)

	assert_eq(replay_processor.get_command_count(), 3,
			"Replay should consume opening, decline, and recorded continuation.")
	assert_eq(replay_processor.get_pending_observer_followup_count(), 0,
			"Replay should not synthesize a duplicate continuation.")
	assert_true(replay_state.timing_window_state.is_inactive(),
			"Recorded continuation should close the replayed lifecycle.")


func _record_history_type(command: GameCommand, _result: Dictionary) -> void:
	_history_types.append(command.command_type)


func _late_blocker_followup(_state_arg: GameState,
		_command: GameCommand,
		_result: Dictionary) -> GameCommand:
	return COMMANDS.AddFixtureBlockerCommand.new(0, {
		"runtime_source_id": "late-source",
	})


func _make_state(source_ids: Array[String]) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0,
			Constants.Visibility.ALL,
			{"attacker_player": 0})
	state.objectives[PARTICIPANT.SOURCES_KEY] = source_ids.duplicate()
	state.objectives[PARTICIPANT.RESOLVED_KEY] = {}
	return state
