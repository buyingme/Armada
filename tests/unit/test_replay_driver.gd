## ReplayDriver unit tests — Phase L0.5b.
##
## Covers the pure parsing / dispatch helpers without booting the
## autoload's full scene-bypass path.  The integration-level
## end-to-end (loaded scene → replay → fixture diff) is exercised by
## [scripts/run_baseline_traces.sh] (Phase L0.5c).
extends GutTest


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
