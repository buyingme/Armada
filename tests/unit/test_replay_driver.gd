## ReplayDriver unit tests — Phase L0.5b.
##
## Covers the pure parsing / dispatch helpers without booting the
## autoload's full scene-bypass path.  The integration-level
## end-to-end (loaded scene → replay → fixture diff) is exercised by
## [scripts/run_baseline_traces.sh] (Phase L0.5c).
extends GutTest


const REPLAY_DRIVER_SCRIPT: GDScript = preload(
		"res://src/autoload/replay_driver.gd")
const BUG071_BUILDER: GDScript = preload(
		"res://tests/fixtures/bug071_production_attack_builder.gd")
const CF_DIAL_USE: GDScript = preload(
		"res://src/core/commands/use_concentrate_fire_dial_command.gd")
const CF_TOKEN_DECLINE: GDScript = preload(
		"res://src/core/commands/decline_concentrate_fire_token_reroll_command.gd")


func test_real_cf_dial_history_round_trips_json_factory_and_driver() -> void:
	var saved_state: GameState = GameManager.current_game_state
	var saved_active: bool = GameManager.is_game_active
	var saved_submitter: CommandSubmitter = GameManager.get_command_submitter()
	var saved_registry: Dictionary = GameCommand._registry.duplicate()
	var saved_mode: PlayMode.Mode = PlayMode.current_mode
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	var built: Dictionary = BUG071_BUILDER.committed_dial(
			1, CurrentAttackState.CF_CHOICE_BOTH)
	assert_false(built.is_empty())
	if built.is_empty():
		return
	var authority: GameState = built["state"]
	var initial: Dictionary = built["initial_state"]
	var dial_command: GameCommand = CF_DIAL_USE.new(1, built["dial_payload"])
	assert_false(CommandProcessor.submit_deferred_followups(
			dial_command).is_empty())
	var projected: Dictionary = UIProjector.project(authority, 1).timing_window
	var decline_payload: Dictionary = {}
	for opportunity: Dictionary in projected.get("opportunities", []):
		if str(opportunity.get("capability_id", "")) \
				== ConcentrateFireTokenRule.CAPABILITY_ID:
			decline_payload = (opportunity.get("decline_intent", {}) \
					as Dictionary).get("payload", {})
	assert_false(decline_payload.is_empty())
	assert_false(CommandProcessor.submit_deferred_followups(
			CF_TOKEN_DECLINE.new(1, decline_payload)).is_empty())
	var authoritative_final: Dictionary = authority.serialize()
	var authoritative_history: Array[Dictionary] = \
			CommandProcessor.serialize_history()
	var replay: GameReplay = CommandProcessor.create_replay()
	assert_not_null(replay)
	var loaded: GameReplay = GameReplay.deserialize(
			JSON.parse_string(JSON.stringify(replay.serialize())))
	assert_not_null(loaded)
	assert_eq(loaded.header.get("format_version"), 11)
	assert_eq(loaded.commands.size(), authoritative_history.size())
	for index: int in range(loaded.commands.size()):
		assert_eq(loaded.commands[index].get("type"),
				authoritative_history[index].get("type"))
		assert_eq(int(loaded.commands[index].get("sequence", -1)), index)
	var replay_state: GameState = GameState.deserialize(initial)
	assert_not_null(replay_state)
	GameManager.current_game_state = replay_state
	GameManager.set_command_submitter(LocalCommandSubmitter.new(
			replay_state.principal_id_for_player(1)))
	CommandProcessor.reset()
	var driver: Node = REPLAY_DRIVER_SCRIPT.new()
	add_child_autofree(driver)
	driver._replay = loaded
	driver.pending_replay_seed = int(loaded.header["rng_seed"])
	CommandProcessor.command_executed.connect(driver._on_command_executed)
	for command_data: Dictionary in loaded.commands:
		assert_not_null(GameCommand.deserialize(command_data))
		var observed: int = driver._observed_count
		assert_true(await driver._submit_local_step(
				command_data, observed, true))
		assert_eq(driver._observed_count, observed + 1)
	assert_eq(CommandProcessor.serialize_history().size(),
			authoritative_history.size())
	assert_eq(replay_state.serialize(), authoritative_final)
	assert_eq(replay_state.rng.get_state(), authority.rng.get_state())
	GameManager.current_game_state = saved_state
	GameManager.is_game_active = saved_active
	GameManager.set_command_submitter(saved_submitter)
	GameCommand._registry = saved_registry
	PlayMode.current_mode = saved_mode
	CommandProcessor.reset()


func test_parse_flag_returns_value_when_present() -> void:
	var args := PackedStringArray(["--replay", "res://r.json", "--other"])
	assert_eq(ReplayDriver.parse_flag(args, "--replay"), "res://r.json")


func test_parse_flag_returns_empty_when_absent() -> void:
	var args := PackedStringArray(["--other", "x"])
	assert_eq(ReplayDriver.parse_flag(args, "--replay"), "")


func test_parse_flag_returns_empty_when_flag_has_no_value() -> void:
	var args := PackedStringArray(["--other", "x", "--replay"])
	assert_eq(ReplayDriver.parse_flag(args, "--replay"), "")


func test_parse_flag_returns_empty_for_empty_args() -> void:
	var args := PackedStringArray([])
	assert_eq(ReplayDriver.parse_flag(args, "--replay"), "")


func test_autoload_inert_when_no_replay_flag() -> void:
	assert_false(ReplayDriver.enabled,
			"ReplayDriver must be inert when no --replay CLI flag")
	assert_eq(ReplayDriver.pending_replay_seed, 0,
			"pending_replay_seed must be 0 in normal sessions")


func test_replay_scenario_is_explicit_reconstruction_input() -> void:
	var previous: String = ReplayDriver.pending_replay_scenario_id
	ReplayDriver.pending_replay_scenario_id = "debug_scenario"
	assert_eq(ReplayDriver.get_pending_replay_scenario_id(), "debug_scenario",
			"Replay bootstrap must retain the scenario recorded in its header.")
	ReplayDriver.pending_replay_scenario_id = previous


func test_network_sync_gate_dial_lookahead_selects_client_batch() -> void:
	var commands: Array[Dictionary] = [
		{"type": "assign_dials", "player": 0, "sequence": 1},
		{"type": "assign_dials", "player": 0, "sequence": 2},
		{"type": "assign_dials", "player": 1, "sequence": 3},
		{"type": "assign_dials", "player": 1, "sequence": 4},
		{"type": "advance_phase", "player": 0, "sequence": 5},
	]

	var lookahead: Array[Dictionary] = \
			ReplayDriver.network_sync_gate_dial_lookahead(commands, 0, 1)

	assert_eq(lookahead.size(), 2)
	assert_eq(int(lookahead[0].get("sequence", -1)), 3)
	assert_eq(int(lookahead[1].get("sequence", -1)), 4)


func test_network_sync_gate_dial_lookahead_stays_with_first_local_run() -> void:
	var commands: Array[Dictionary] = [
		{"type": "assign_dials", "player": 0, "sequence": 1},
		{"type": "assign_dials", "player": 1, "sequence": 2},
		{"type": "assign_dials", "player": 0, "sequence": 3},
		{"type": "assign_dials", "player": 1, "sequence": 4},
	]

	var lookahead: Array[Dictionary] = \
			ReplayDriver.network_sync_gate_dial_lookahead(commands, 0, 1)

	assert_eq(lookahead.size(), 1)
	assert_eq(int(lookahead[0].get("sequence", -1)), 2)


func test_network_sync_gate_dial_lookahead_rejects_non_gate_boundary() -> void:
	var commands: Array[Dictionary] = [
		{"type": "start_round", "player": 0, "sequence": 0},
		{"type": "assign_dials", "player": 1, "sequence": 1},
	]

	assert_true(ReplayDriver.network_sync_gate_dial_lookahead(
			commands, 0, 1).is_empty())
	assert_true(ReplayDriver.network_sync_gate_dial_lookahead(
			commands, 1, 1).is_empty())


func test_replay_bootstrap_game_state_defaults_timing_window_inactive() -> void:
	var state := GameState.new()
	state.initialize()

	assert_true(state.timing_window_state.is_inactive(),
			"Replay bootstrap state should default timing-window state inactive")


func test_network_replay_exposes_exact_pending_header_seed() -> void:
	var driver = _network_replay_driver(30671017)

	assert_true(driver.is_network_replay_bootstrap_active(),
			"Enabled network replay should activate replay RNG bootstrap.")
	assert_eq(driver.get_pending_network_replay_seed(), 30671017,
			"Network replay bootstrap should expose the exact header seed.")
	assert_true(driver.validate_network_replay_seed(30671017),
			"The distributed seed should validate against the header seed.")
	assert_eq(driver.pending_replay_seed, 30671017,
			"Validation alone must not consume the one-shot seed.")


func test_network_replay_rejects_missing_zero_and_mismatched_seed() -> void:
	var driver = _network_replay_driver(30671017)

	assert_false(driver.validate_network_replay_seed(null),
			"Missing network replay seed must fail closed.")
	assert_false(driver.validate_network_replay_seed(0),
			"Zero/fallback network replay seed must fail closed.")
	assert_false(driver.validate_network_replay_seed(30671018),
			"Mismatched network replay seed must fail closed.")
	assert_false(driver.consume_network_replay_seed(30671018),
			"A mismatch must not consume bootstrap state.")
	assert_eq(driver.pending_replay_seed, 30671017,
			"Failed validation must preserve the accepted pending seed.")


func test_network_replay_seed_is_consumed_exactly_once_after_match() -> void:
	var driver = _network_replay_driver(30671017)

	assert_true(driver.consume_network_replay_seed(30671017),
			"Matching network replay seed should be consumed once.")
	assert_eq(driver.pending_replay_seed, 0,
			"Successful consumption should clear pending state.")
	assert_false(driver.consume_network_replay_seed(30671017),
			"Cleared bootstrap state must not be consumable twice.")


func test_inactive_replay_does_not_expose_pending_network_seed() -> void:
	var driver = _network_replay_driver(30671017)
	driver.enabled = false

	assert_false(driver.is_network_replay_bootstrap_active(),
			"Normal network games must not activate replay bootstrap.")
	assert_eq(driver.get_pending_network_replay_seed(), 0,
			"Inactive replay bootstrap must not expose stale pending state.")
	assert_false(driver.validate_network_replay_seed(30671017),
			"Normal network games must not validate against replay state.")
	assert_eq(driver.pending_replay_seed, 30671017,
			"Normal network flow must not consume replay-bootstrap state.")


func _network_replay_driver(seed_value: int):
	var driver = REPLAY_DRIVER_SCRIPT.new()
	add_child_autofree(driver)
	driver.enabled = true
	driver._connect_target = "127.0.0.1:7350"
	driver.pending_replay_seed = seed_value
	return driver
