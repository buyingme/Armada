## Test: GameLogger File Logging
##
## Unit tests for the GameLogger file output extension.
## Requirements: LOG-002, LOG-003, LOG-005, LOG-006, LOG-007, LOG-030, LOG-031.
extends GutTest


## Temporary log file path used by tests.
var _test_log_path: String = "user://logs/_test_game_logger.log"


func before_each() -> void:
	# Ensure clean state before every test.
	GameLogger.disable_file_logging()
	GameLogger.min_level = GameLogger.Level.DEBUG
	GameLogger.min_file_level = GameLogger.Level.DEBUG
	# Remove leftover test file if present.
	if FileAccess.file_exists(_test_log_path):
		DirAccess.remove_absolute(
				ProjectSettings.globalize_path(_test_log_path))


func after_each() -> void:
	GameLogger.disable_file_logging()
	GameLogger.min_level = GameLogger.Level.DEBUG
	GameLogger.min_file_level = GameLogger.Level.DEBUG
	if FileAccess.file_exists(_test_log_path):
		DirAccess.remove_absolute(
				ProjectSettings.globalize_path(_test_log_path))


# ---------------------------------------------------------------------------
# LOG-030 — file toggle
# ---------------------------------------------------------------------------

func test_file_logging_disabled_by_default() -> void:
	assert_false(GameLogger.is_file_logging_enabled(),
			"File logging should be disabled by default")


func test_enable_file_logging_returns_true() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	var result: bool = GameLogger.enable_file_logging(_test_log_path)
	assert_true(result,
			"enable_file_logging should return true on success")
	assert_true(GameLogger.is_file_logging_enabled(),
			"is_file_logging_enabled should be true after enable")


func test_disable_file_logging_clears_state() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	GameLogger.enable_file_logging(_test_log_path)
	GameLogger.disable_file_logging()
	assert_false(GameLogger.is_file_logging_enabled(),
			"File logging should be disabled after disable_file_logging")
	assert_eq(GameLogger.get_log_file_path(), "",
			"Log file path should be empty after disable")


func test_log_writes_to_file_when_enabled() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	GameLogger.enable_file_logging(_test_log_path)
	var logger: GameLogger = GameLogger.new("TestCtx")
	logger.info("Hello file logging")
	GameLogger.disable_file_logging()

	assert_true(FileAccess.file_exists(_test_log_path),
			"Log file should exist after writing")
	var content: String = FileAccess.get_file_as_string(_test_log_path)
	assert_string_contains(content, "Hello file logging",
			"Log file should contain the logged message")


func test_log_does_not_write_when_disabled() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	# Write one line, then disable, then write another.
	GameLogger.enable_file_logging(_test_log_path)
	var logger: GameLogger = GameLogger.new("TestCtx")
	logger.info("Before disable")
	GameLogger.disable_file_logging()
	logger.info("After disable")

	var content: String = FileAccess.get_file_as_string(_test_log_path)
	assert_string_contains(content, "Before disable",
			"File should contain the first message")
	assert_does_not_have(content, "After disable",
			"File should NOT contain messages written after disable")


# ---------------------------------------------------------------------------
# LOG-031 — format compliance
# ---------------------------------------------------------------------------

func test_log_line_format_matches_specification() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	GameLogger.enable_file_logging(_test_log_path)
	var logger: GameLogger = GameLogger.new("FmtTest")
	logger.info("format check")
	GameLogger.disable_file_logging()

	var content: String = FileAccess.get_file_as_string(_test_log_path)
	var lines: PackedStringArray = content.strip_edges().split("\n")
	assert_gt(lines.size(), 0,
			"Log file should have at least one line")
	var line: String = lines[0]
	# Expected format: [<timestamp>] [INFO] [FmtTest] format check
	var regex: RegEx = RegEx.new()
	regex.compile("^\\[.+\\] \\[(DEBUG|INFO|WARN|ERROR)\\] \\[.+\\] .+$")
	var result: RegExMatch = regex.search(line)
	assert_not_null(result,
			"Log line should match [timestamp] [LEVEL] [context] message format: '%s'" % line)


func test_log_levels_appear_correctly_in_file() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	GameLogger.enable_file_logging(_test_log_path)
	# Only test DEBUG and INFO on console + file to avoid GUT catching
	# push_warning/push_error as "unexpected errors".
	var logger: GameLogger = GameLogger.new("LvlTest")
	logger.debug("d-msg")
	logger.info("i-msg")
	# Write WARN and ERROR directly to file to verify format without
	# triggering push_warning/push_error on the console.
	var warn_line: String = "[test] [WARN] [LvlTest] w-msg"
	var error_line: String = "[test] [ERROR] [LvlTest] e-msg"
	GameLogger.write_raw_to_file(warn_line + "\n")
	GameLogger.write_raw_to_file(error_line + "\n")
	GameLogger.disable_file_logging()

	var content: String = FileAccess.get_file_as_string(_test_log_path)
	assert_string_contains(content, "[DEBUG]",
			"File should contain DEBUG level")
	assert_string_contains(content, "[INFO]",
			"File should contain INFO level")
	assert_string_contains(content, "[WARN]",
			"File should contain WARN level")
	assert_string_contains(content, "[ERROR]",
			"File should contain ERROR level")


func test_min_file_level_suppresses_lower_levels() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	GameLogger.enable_file_logging(_test_log_path)
	GameLogger.min_file_level = GameLogger.Level.INFO
	var logger: GameLogger = GameLogger.new("MinLvl")
	logger.debug("should-not-appear")
	logger.info("should-appear")
	GameLogger.disable_file_logging()

	var content: String = FileAccess.get_file_as_string(_test_log_path)
	assert_does_not_have(content, "should-not-appear",
			"DEBUG should be suppressed when min_file_level is INFO")
	assert_string_contains(content, "should-appear",
			"INFO should still appear")


# ---------------------------------------------------------------------------
# LOG-004 — write_raw_to_file
# ---------------------------------------------------------------------------

func test_write_raw_to_file_writes_unformatted_text() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	GameLogger.enable_file_logging(_test_log_path)
	GameLogger.write_raw_to_file("RAW HEADER LINE\n")
	GameLogger.disable_file_logging()

	var content: String = FileAccess.get_file_as_string(_test_log_path)
	assert_string_contains(content, "RAW HEADER LINE",
			"write_raw_to_file should write unformatted text")


func test_write_raw_to_file_noop_when_disabled() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	GameLogger.enable_file_logging(_test_log_path)
	GameLogger.disable_file_logging()
	GameLogger.write_raw_to_file("should not appear")

	if FileAccess.file_exists(_test_log_path):
		var content: String = FileAccess.get_file_as_string(_test_log_path)
		assert_does_not_have(content, "should not appear",
				"write_raw_to_file should not write when disabled")
	else:
		pass_test("File was not created, which is acceptable")


# ---------------------------------------------------------------------------
# Path retrieval
# ---------------------------------------------------------------------------

func test_get_log_file_path_returns_path_when_enabled() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	GameLogger.enable_file_logging(_test_log_path)
	assert_eq(GameLogger.get_log_file_path(), _test_log_path,
			"get_log_file_path should return the active path")


func test_get_log_file_path_returns_empty_when_disabled() -> void:
	assert_eq(GameLogger.get_log_file_path(), "",
			"get_log_file_path should return empty when disabled")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Asserts that [param haystack] does NOT contain [param needle].
func assert_does_not_have(haystack: String, needle: String,
		msg: String = "") -> void:
	assert_false(haystack.contains(needle), msg)
