## Focused Slice 3 tests for lifecycle and command-stream coordination.
extends GutTest


const ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")
const DEFINITIONS: GDScript = preload(
		"res://src/core/timing_windows/timing_window_definitions.gd")
const PROCESSOR_SCRIPT: GDScript = preload(
		"res://src/autoload/command_processor.gd")

const TEST_COMMAND_TYPE: String = "debug_deal_damage"
const CONTINUATION_TYPE: String = "confirm_attack_dice"

var _state: GameState = null
var _processor: Node = null
var _saved_registry: Dictionary = {}


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	GameCommand._registry.clear()
	GameCommand.register_type(TEST_COMMAND_TYPE, func(player: int,
			payload: Dictionary) -> GameCommand:
		return FixtureCommand.new(player, TEST_COMMAND_TYPE, payload))
	GameCommand.register_type(CONTINUATION_TYPE, func(player: int,
			payload: Dictionary) -> GameCommand:
		return FixtureCommand.new(player, CONTINUATION_TYPE, payload))
	_state = GameState.new()
	_state.initialize()
	GameManager.current_game_state = _state
	_processor = PROCESSOR_SCRIPT.new()
	add_child_autofree(_processor)


func after_each() -> void:
	GameManager.current_game_state = null
	GameCommand._registry = _saved_registry


func test_open_creates_one_active_lifecycle_from_command_sequence() -> void:
	var result: Dictionary = _open(7)

	assert_true(result.get(ORCHESTRATOR.KEY_OK, false),
			"Known timing window should open from authoritative context.")
	assert_true(_state.timing_window_state.active,
			"Opening should install active lifecycle state on GameState.")
	assert_eq(_state.timing_window_state.lifecycle_id, "attack_modify:7",
			"Lifecycle identity should derive from window and command sequence.")
	assert_eq(_state.timing_window_state.controller_player, 0,
			"Fixed attacker policy should resolve from authoritative context.")


func test_duplicate_open_rejects_and_same_type_reopen_gets_fresh_identity() -> void:
	assert_true(_open(2).get(ORCHESTRATOR.KEY_OK, false),
			"First opening should succeed.")
	assert_false(_open(3).get(ORCHESTRATOR.KEY_OK, true),
			"Opening while active should reject without replacement.")
	assert_true(ORCHESTRATOR.cancel_window(
			_state, "attack_modify:2").get(ORCHESTRATOR.KEY_OK, false),
			"Explicit cancellation should retire the first lifecycle.")
	assert_true(_open(3).get(ORCHESTRATOR.KEY_OK, false),
			"Close-and-open after cancellation should succeed.")
	assert_eq(_state.timing_window_state.lifecycle_id, "attack_modify:3",
			"Same-type reopen should use a fresh lifecycle identity.")


func test_attack_modify_replacement_is_prohibited() -> void:
	_open(4)
	var result: Dictionary = ORCHESTRATOR.replace_window(
			_state, "attack_modify:4", DEFINITIONS.ATTACK_MODIFY, 5, _context())
	assert_false(result.get(ORCHESTRATOR.KEY_OK, true),
			"Static Attack Modify policy should reject active replacement.")
	assert_eq(_state.timing_window_state.lifecycle_id, "attack_modify:4",
			"Rejected replacement should preserve the original lifecycle.")


func test_blocker_keeps_open_and_zero_blockers_queues_exactly_one() -> void:
	_open(6)
	var blocked: Dictionary = ORCHESTRATOR._apply_derivation_result(
			_state,
			{ORCHESTRATOR.KEY_OK: true,
			 ORCHESTRATOR.KEY_OPPORTUNITIES: [{"blocking": true}]},
			ORCHESTRATOR.MODE_LIVE_AUTHORITY)
	assert_null(blocked.get(ORCHESTRATOR.KEY_CONTINUATION),
			"A blocker should prevent continuation.")
	assert_eq(_state.timing_window_state.status, TimingWindowState.STATUS_OPEN,
			"Blocked lifecycle should remain open.")

	var clear: Dictionary = ORCHESTRATOR._apply_derivation_result(
			_state,
			{ORCHESTRATOR.KEY_OK: true,
			 ORCHESTRATOR.KEY_OPPORTUNITIES: []},
			ORCHESTRATOR.MODE_LIVE_AUTHORITY)
	assert_not_null(clear.get(ORCHESTRATOR.KEY_CONTINUATION),
			"No blockers should produce one replayable continuation.")
	assert_eq(_state.timing_window_state.status, TimingWindowState.STATUS_CLOSING,
			"Queued continuation should mark the lifecycle closing.")

	var repeated: Dictionary = ORCHESTRATOR._apply_derivation_result(
			_state,
			{ORCHESTRATOR.KEY_OK: true,
			 ORCHESTRATOR.KEY_OPPORTUNITIES: []},
			ORCHESTRATOR.MODE_LIVE_AUTHORITY)
	assert_null(repeated.get(ORCHESTRATOR.KEY_CONTINUATION),
			"Repeated evaluation must not queue a duplicate continuation.")


func test_new_blocker_restores_closing_lifecycle_to_open() -> void:
	_open(8)
	ORCHESTRATOR._apply_derivation_result(
			_state,
			{ORCHESTRATOR.KEY_OK: true,
			 ORCHESTRATOR.KEY_OPPORTUNITIES: []},
			ORCHESTRATOR.MODE_LIVE_AUTHORITY)

	ORCHESTRATOR._apply_derivation_result(
			_state,
			{ORCHESTRATOR.KEY_OK: true,
			 ORCHESTRATOR.KEY_OPPORTUNITIES: [{"blocking": true}]},
			ORCHESTRATOR.MODE_LIVE_AUTHORITY)

	assert_eq(_state.timing_window_state.status, TimingWindowState.STATUS_OPEN,
			"An earlier follow-up creating a blocker should reopen the lifecycle.")


func test_mirror_replay_and_reconstruction_never_synthesize_continuation() -> void:
	for mode: String in [
		ORCHESTRATOR.MODE_NETWORK_MIRROR,
		ORCHESTRATOR.MODE_REPLAY,
		ORCHESTRATOR.MODE_RECONSTRUCTION,
	]:
		_state.initialize()
		_open(9)
		var result: Dictionary = ORCHESTRATOR._apply_derivation_result(
				_state,
				{ORCHESTRATOR.KEY_OK: true,
				 ORCHESTRATOR.KEY_OPPORTUNITIES: []}, mode)
		assert_null(result.get(ORCHESTRATOR.KEY_CONTINUATION),
				"Passive mode %s must not synthesize commands." % mode)
		assert_eq(_state.timing_window_state.status,
				TimingWindowState.STATUS_CLOSING,
				"Passive mode should reconstruct the same closing lifecycle.")


func test_live_and_mirror_sequence_paths_are_deterministic() -> void:
	var live := FixtureCommand.new(0, TEST_COMMAND_TYPE, {})
	_processor.submit(live)
	assert_eq(live.sequence, 0,
			"Live authority should allocate the current sequence.")
	assert_eq(_processor.get_next_sequence(), 1,
			"Successful live execution should advance the cursor once.")

	var mirror := FixtureCommand.new(0, TEST_COMMAND_TYPE, {})
	mirror.sequence = 1
	_processor.submit_mirror(mirror)
	assert_eq(mirror.sequence, 1,
			"Mirror application should preserve authoritative sequence.")
	assert_eq(_processor.get_next_sequence(), 2,
			"Successful mirror application should advance the same cursor.")


func test_rejected_live_and_mirror_commands_leave_cursor_and_history_unchanged() -> void:
	var claimed := FixtureCommand.new(0, TEST_COMMAND_TYPE, {})
	claimed.sequence = 0
	assert_eq(_processor.submit(claimed), {},
			"Live command claiming a sequence should reject.")
	assert_eq(_processor.get_next_sequence(), 0,
			"Rejected live command should not advance cursor.")

	var gap := FixtureCommand.new(0, TEST_COMMAND_TYPE, {})
	gap.sequence = 2
	assert_eq(_processor.submit_mirror(gap), {},
			"Gapped mirror sequence should reject.")
	assert_eq(_processor.get_next_sequence(), 0,
			"Rejected mirror command should not advance cursor.")
	assert_eq(_processor.get_command_count(), 0,
			"Rejected commands should not enter history.")
	assert_engine_error(2,
			"Both deterministic sequence rejections should be diagnosed.")


func _open(sequence: int) -> Dictionary:
	return ORCHESTRATOR.open_window(
			_state, DEFINITIONS.ATTACK_MODIFY, sequence, _context())


func _context() -> Dictionary:
	return {
		TimingWindowState.CONTINUATION_KEY_ID: CONTINUATION_TYPE,
		TimingWindowState.CONTINUATION_KEY_RESUME_POINT: "attack_after_modify",
		TimingWindowState.CONTINUATION_KEY_SOURCE_ID: "fixture-attack",
		TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE: "current_attack",
		TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER: 0,
	}


class FixtureCommand extends GameCommand:
	func _init(player: int = 0,
			type: String = TEST_COMMAND_TYPE,
			command_payload: Dictionary = {}) -> void:
		super._init(player, type, command_payload)

	func execute(_game_state: GameState) -> Dictionary:
		return {"success": true}
