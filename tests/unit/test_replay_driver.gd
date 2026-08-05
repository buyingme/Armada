## ReplayDriver unit tests — Phase L0.5b.
##
## Covers the pure parsing / dispatch helpers without booting the
## autoload's full scene-bypass path.  The integration-level
## end-to-end (loaded scene → replay → fixture diff) is exercised by
## [scripts/run_baseline_traces.sh] (Phase L0.5c).
extends GutTest


const REPLAY_DRIVER_SCRIPT: GDScript = preload(
		"res://src/autoload/replay_driver.gd")


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
