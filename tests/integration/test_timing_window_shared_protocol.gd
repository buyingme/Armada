## Reusable TEST-003 shared-protocol evidence for timing-window consumers.
## These tests prove lifecycle infrastructure only and make no CAP claim.
extends GutTest


const PROCESSOR_SCRIPT: GDScript = preload(
		"res://src/autoload/command_processor.gd")
const DEFINITIONS: GDScript = preload(
		"res://src/core/timing_windows/timing_window_definitions.gd")
const ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")
const COMMANDS: GDScript = preload(
		"res://tests/fixtures/timing_window_command_fixtures.gd")
const PARTICIPANT: GDScript = preload(
		"res://tests/fixtures/timing_window_participant_fixture.gd")

var _saved_registry: Dictionary = {}
var _saved_state: GameState = null
var _saved_active: bool = false
var _saved_submitter: CommandSubmitter = null
var _saved_play_mode: PlayMode.Mode
var _saved_network_role: NetworkManager.Role
var _saved_local_player: int = -1
var _broadcast_results: Array[Dictionary] = []


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	_saved_state = GameManager.current_game_state
	_saved_active = GameManager.is_game_active
	_saved_submitter = GameManager.get_command_submitter()
	_saved_play_mode = PlayMode.current_mode
	_saved_network_role = NetworkManager.role
	_saved_local_player = NetworkManager._local_player_index
	_broadcast_results.clear()
	RuleRegistry.clear()
	COMMANDS.register()
	assert_true(COMMANDS.register_participant())
	CommandProcessor.reset()


func after_each() -> void:
	var capture: Callable = Callable(self, "_capture_network_result")
	if NetworkManager.command_result_received.is_connected(capture):
		NetworkManager.command_result_received.disconnect(capture)
	RuleRegistry.clear()
	GameCommand._registry = _saved_registry
	GameManager.current_game_state = _saved_state
	GameManager.is_game_active = _saved_active
	GameManager.set_command_submitter(_saved_submitter)
	PlayMode.current_mode = _saved_play_mode
	NetworkManager.role = _saved_network_role
	NetworkManager._local_player_index = _saved_local_player
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()


func test_active_reconnect_restores_state_cursor_visibility_and_projection() -> void:
	var state: GameState = _make_state(["source-a"], ["source-b"])
	var processor: Node = _make_processor(state)
	processor.submit(COMMANDS.make_open())
	processor.submit(COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, state, "source-a"))
	var serialized: Dictionary = state.serialize()

	assert_false(JSON.stringify(serialized).contains("opportunity_id"),
			"Canonical state must not serialize derived opportunities.")
	assert_false(JSON.stringify(serialized).contains("rule_script"),
			"Canonical state must not serialize participant registration.")
	var filtered: Dictionary = StateFilter.filter_for_player(serialized, 1)
	var filtered_json: String = JSON.stringify(filtered)
	assert_false(filtered_json.contains("source-b"),
			"Owner-only runtime source must not enter an observer snapshot.")
	assert_false(filtered_json.contains(PARTICIPANT.VISIBILITY_KEY),
			"Private visibility metadata must not enter an observer snapshot.")
	var restored: GameState = GameState.deserialize(filtered)
	assert_not_null(restored)
	var forged_hidden: GameCommand = COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, restored, "source-b", 0)
	assert_eq(forged_hidden.validate(restored),
			"Missing fixture runtime source.",
			"Filtered hidden data must not authorize a forged command.")
	var meta: SaveGameMetadata = SaveGameMetadata.new()
	meta.set_next_command_sequence(processor.get_next_sequence())
	var cursor_result: Dictionary = SaveGameManager.reconstruction_cursor_for(
			meta, restored)
	assert_true(bool(cursor_result.get("ok", false)))

	assert_true(GameManager.start_new_game_from_state(
			restored,
			"timing-window-fixture",
			int(cursor_result.get("next_command_sequence", -1))))

	assert_eq(CommandProcessor.get_next_sequence(), 2)
	assert_eq(GameManager._next_network_result_sequence, 2)
	var projected: Dictionary = UIProjector.project(restored, 1).timing_window
	assert_true((projected.get("opportunities", []) as Array).is_empty(),
			"Reconnect projection must re-derive only snapshot-visible sources.")
	var derivation: Dictionary = ORCHESTRATOR.derive_current_opportunities(
			restored)
	assert_true(bool(derivation.get(ORCHESTRATOR.KEY_OK, false)))
	assert_eq((derivation.get(ORCHESTRATOR.KEY_OPPORTUNITIES) as Array).size(), 0,
			"Filtered private sources must not be resurrected after reconnect.")


func test_invalid_reconstruction_install_fails_before_live_state_changes() -> void:
	var invalid: GameState = _make_state(["source-a"])
	assert_true(bool(ORCHESTRATOR.open_window(
			invalid, DEFINITIONS.ATTACK_MODIFY, 4, _context()).get(
					ORCHESTRATOR.KEY_OK, false)))
	invalid.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			1)
	var installed_before: GameState = GameState.new()
	installed_before.initialize()
	GameManager.current_game_state = installed_before
	CommandProcessor.reset()
	assert_true(CommandProcessor.restore_next_sequence(5))

	assert_false(GameManager.start_new_game_from_state(
			invalid, "invalid-fixture", 5))
	assert_same(GameManager.current_game_state, installed_before,
			"Invalid state must fail before canonical state replacement.")
	assert_eq(CommandProcessor.get_next_sequence(), 5,
			"Invalid install must not change the command cursor.")
	assert_push_error(1,
			"Invalid reconstruction should emit one fail-closed diagnostic.")


func test_reconstruction_boundaries_do_not_synthesize_continuation() -> void:
	var state: GameState = _make_state(["source-a"])
	var processor: Node = _make_processor(state)
	processor.submit(COMMANDS.make_open())
	var before_choice: GameState = GameState.deserialize(state.serialize())
	assert_true(before_choice.timing_window_state.active)
	assert_eq(before_choice.timing_window_state.status,
			TimingWindowState.STATUS_OPEN)

	processor.submit_deferred_followups(COMMANDS.make_resolution(
			COMMANDS.DECLINE_TYPE, state, "source-a"))
	assert_eq(state.timing_window_state.status, TimingWindowState.STATUS_CLOSING)
	assert_eq(processor.get_pending_observer_followup_count(), 1)
	var before_continuation: GameState = GameState.deserialize(state.serialize())
	var reconciled: Dictionary = ORCHESTRATOR.reconcile(before_continuation)
	assert_true(bool(reconciled.get(ORCHESTRATOR.KEY_OK, false)))
	assert_null(reconciled.get(ORCHESTRATOR.KEY_CONTINUATION),
			"Reconstruction must never synthesize the recorded continuation.")
	assert_eq(before_continuation.timing_window_state.status,
			TimingWindowState.STATUS_CLOSING)

	GameManager.current_game_state = state
	processor.drain_observer_followups()
	assert_true(state.timing_window_state.is_inactive())
	var after_continuation: GameState = GameState.deserialize(state.serialize())
	assert_true(after_continuation.timing_window_state.is_inactive())
	assert_true((ORCHESTRATOR.derive_current_opportunities(
			after_continuation).get(ORCHESTRATOR.KEY_OPPORTUNITIES) as Array).is_empty())


func test_network_mirror_and_replay_preserve_order_without_synthesis() -> void:
	var authority_state: GameState = _make_state(["source-a"])
	var authority: Node = _make_processor(authority_state)
	authority.submit(COMMANDS.make_open())
	authority.submit(COMMANDS.make_resolution(
			COMMANDS.DECLINE_TYPE, authority_state, "source-a"))
	var recorded: Array[Dictionary] = authority.serialize_history()
	var replay_payload: Dictionary = _make_replay(recorded).serialize()
	assert_not_null(GameReplay.deserialize(replay_payload),
			"Contiguous shared protocol history must be replay-loadable.")

	var mirror_state: GameState = _make_state(["source-a"])
	var mirror: Node = _make_processor(mirror_state)
	for command_data: Dictionary in recorded:
		mirror.submit_mirror(GameCommand.deserialize(command_data))
		assert_eq(mirror.get_pending_observer_followup_count(), 0,
				"Network mirror must not synthesize continuation.")

	var replay_state: GameState = _make_state(["source-a"])
	var replay: Node = _make_processor(replay_state)
	for command_data: Dictionary in recorded:
		replay.submit_replay(GameCommand.deserialize(command_data))
		assert_eq(replay.get_pending_observer_followup_count(), 0,
				"Replay must consume recorded continuation only.")

	assert_eq(_history_sequences(recorded), [0, 1, 2])
	assert_eq(_history_types(recorded), [
		COMMANDS.OPEN_TYPE,
		COMMANDS.DECLINE_TYPE,
		COMMANDS.CONTINUATION_TYPE,
	])
	assert_eq(mirror.serialize_history(), recorded)
	assert_eq(replay.serialize_history(), recorded)
	assert_eq(mirror_state.serialize(), authority_state.serialize())
	assert_eq(replay_state.serialize(), authority_state.serialize())


func test_real_host_stream_orders_timing_commands_before_continuation() -> void:
	var initial: GameState = _make_state(["source-a", "source-b"])
	var authority_state: GameState = GameState.deserialize(initial.serialize())
	GameManager.current_game_state = authority_state
	GameManager.is_game_active = true
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = 0
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	var host_submitter: NetworkHostCommandSubmitter = \
			NetworkHostCommandSubmitter.new()
	GameManager.set_command_submitter(host_submitter)
	NetworkManager.command_result_received.connect(_capture_network_result)

	host_submitter.submit(COMMANDS.make_open())
	host_submitter.submit(COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, authority_state, "source-a"))
	host_submitter.submit(COMMANDS.make_resolution(
			COMMANDS.DECLINE_TYPE, authority_state, "source-b"))

	assert_eq(_history_sequences(_broadcast_command_data()), [0, 1, 2, 3])
	assert_eq(_history_types(_broadcast_command_data()), [
		COMMANDS.OPEN_TYPE,
		COMMANDS.USE_TYPE,
		COMMANDS.DECLINE_TYPE,
		COMMANDS.CONTINUATION_TYPE,
	], "The trigger/result must broadcast before its continuation.")
	assert_eq(CommandProcessor.serialize_history(), _broadcast_command_data(),
			"The authoritative broadcast must preserve assigned sequences.")
	var authority_final: Dictionary = authority_state.serialize()

	var client_state: GameState = GameState.deserialize(initial.serialize())
	GameManager.current_game_state = client_state
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	_apply_broadcast_to_client(2)
	assert_eq(CommandProcessor.get_next_sequence(), 0,
			"A later timing result must wait for the missing sequence.")
	assert_eq(GameManager._pending_network_results.size(), 1)
	_apply_broadcast_to_client(0)
	_apply_broadcast_to_client(1)
	assert_eq(CommandProcessor.get_next_sequence(), 3,
			"Filling the gap must flush use then decline in order.")
	_apply_broadcast_to_client(3)

	assert_eq(CommandProcessor.serialize_history(), _broadcast_command_data())
	assert_eq(client_state.serialize(), authority_final,
			"Host and client authoritative state must agree.")
	assert_eq(UIProjector.project(client_state, 1).timing_window,
			UIProjector.project(authority_state, 1).timing_window,
			"Host and client timing projections must agree.")


func test_stale_replay_command_rejects_without_cursor_or_state_advance() -> void:
	var state: GameState = _make_state(["source-a"])
	var processor: Node = _make_processor(state)
	var opening: GameCommand = COMMANDS.make_open()
	opening.sequence = 0
	processor.submit_replay(opening)
	var stale: GameCommand = COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, state, "source-a")
	stale.sequence = 1
	stale.payload["lifecycle_id"] = "attack_modify:stale"

	assert_eq(processor.submit_replay(stale), {})
	assert_eq(processor.get_next_sequence(), 1)
	assert_eq(processor.get_command_count(), 1)
	assert_true(state.timing_window_state.active)
	assert_eq(state.objectives.get(PARTICIPANT.RESOLVED_KEY), {})
	assert_engine_error(1,
			"Stale replay lifecycle rejection should diagnose once.")


func test_cleanup_close_cancel_reopen_and_failure_outcomes_are_deterministic() -> void:
	var state: GameState = _make_state(["source-a"])
	var processor: Node = _make_processor(state)
	processor.submit(COMMANDS.make_open())
	var first_lifecycle: String = state.timing_window_state.lifecycle_id
	processor.submit(COMMANDS.make_cancel(state))
	assert_true(state.timing_window_state.is_inactive())
	assert_eq(state.objectives.get(PARTICIPANT.RESOLVED_KEY), {})
	assert_false(bool(ORCHESTRATOR.cancel_window(
			state, first_lifecycle).get(ORCHESTRATOR.KEY_OK, true)),
			"Repeated cleanup should remain inactive and report no success.")

	processor.submit(COMMANDS.make_open())
	assert_ne(state.timing_window_state.lifecycle_id, first_lifecycle,
			"Close-and-open must use a fresh sequence-derived identity.")
	var replacement: Dictionary = ORCHESTRATOR.replace_window(
			state,
			state.timing_window_state.lifecycle_id,
			DEFINITIONS.ATTACK_MODIFY,
			processor.get_next_sequence(),
			state.timing_window_state.continuation_context)
	assert_false(bool(replacement.get(ORCHESTRATOR.KEY_OK, true)))
	assert_true(state.timing_window_state.active,
			"Prohibited replacement must preserve the active lifecycle.")

	state.objectives[PARTICIPANT.FAIL_DERIVATION_KEY] = true
	processor.submit(COMMANDS.make_resolution(
			COMMANDS.USE_TYPE, state, "source-a"))
	assert_true(state.timing_window_state.active)
	assert_eq(processor.get_pending_observer_followup_count(), 0)
	assert_engine_error(1,
			"Derivation failure after a successful command should diagnose once.")


func _make_processor(state: GameState) -> Node:
	GameManager.current_game_state = state
	var processor: Node = PROCESSOR_SCRIPT.new()
	add_child_autofree(processor)
	COMMANDS.register()
	return processor


func _make_state(public_source_ids: Array[String],
		private_source_ids: Array[String] = []) -> GameState:
	var state: GameState = GameState.new()
	state.rng = GameRng.new(7007)
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0,
			Constants.Visibility.OWNER if not private_source_ids.is_empty() \
					else Constants.Visibility.ALL,
			{
				"attacker_player": 0,
				PARTICIPANT.PRIVATE_SOURCES_KEY:
						private_source_ids.duplicate(),
				PARTICIPANT.VISIBILITY_KEY: {
					"source-b": PARTICIPANT.VISIBILITY_OWNER_ONLY,
				},
			})
	state.objectives[PARTICIPANT.SOURCES_KEY] = public_source_ids.duplicate()
	state.objectives[PARTICIPANT.RESOLVED_KEY] = {}
	return state


func _context() -> Dictionary:
	return {
		TimingWindowState.CONTINUATION_KEY_ID: COMMANDS.CONTINUATION_TYPE,
		TimingWindowState.CONTINUATION_KEY_RESUME_POINT: "attack_after_modify",
		TimingWindowState.CONTINUATION_KEY_SOURCE_ID: "fixture-attack",
		TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE: "current_attack",
		TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER: 0,
	}


func _capture_network_result(command_data: Dictionary,
		result: Dictionary) -> void:
	_broadcast_results.append({
		"command": command_data.duplicate(true),
		"result": result.duplicate(true),
	})


func _broadcast_command_data() -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	for entry: Dictionary in _broadcast_results:
		commands.append((entry.get("command") as Dictionary).duplicate(true))
	return commands


func _apply_broadcast_to_client(index: int) -> void:
	var entry: Dictionary = _broadcast_results[index]
	GameManager._on_network_command_result(
			entry.get("command") as Dictionary,
			entry.get("result") as Dictionary)


func _make_replay(commands: Array[Dictionary]) -> GameReplay:
	var replay: GameReplay = GameReplay.new()
	replay.capture_header("timing-window-fixture", 7007, [0, 1], 0)
	replay.set_commands(commands)
	return replay


func _history_sequences(commands: Array[Dictionary]) -> Array[int]:
	var sequences: Array[int] = []
	for command: Dictionary in commands:
		sequences.append(int(command.get("sequence", -1)))
	return sequences


func _history_types(commands: Array[Dictionary]) -> Array[String]:
	var types: Array[String] = []
	for command: Dictionary in commands:
		types.append(str(command.get("type", "")))
	return types
