## Test: LoggingMode
##
## Unit tests for the LoggingMode autoload singleton.
## Requirements: LOG-001, LOG-004, LOG-032.
extends GutTest


## Temporary log file path used by tests.
var _test_log_path: String = "res://logs/_test_logging_mode.log"

## Tracks the actual log path created by _enable_file_logging.
var _created_log_path: String = ""


func before_each() -> void:
	LoggingMode.disconnect_event_signals()
	GameLogger.disable_file_logging()
	LoggingMode.enabled = false
	LoggingMode.log_file_path = ""
	_created_log_path = ""


func after_each() -> void:
	LoggingMode.disconnect_event_signals()
	# Capture the path before resetting so we can clean up.
	if _created_log_path.is_empty():
		_created_log_path = LoggingMode.log_file_path
	GameLogger.disable_file_logging()
	LoggingMode.enabled = false
	LoggingMode.log_file_path = ""
	_cleanup_test_file()
	_cleanup_created_file()


func _cleanup_test_file() -> void:
	if FileAccess.file_exists(_test_log_path):
		DirAccess.remove_absolute(
				ProjectSettings.globalize_path(_test_log_path))


func _cleanup_created_file() -> void:
	if _created_log_path.is_empty():
		return
	if FileAccess.file_exists(_created_log_path):
		DirAccess.remove_absolute(
				ProjectSettings.globalize_path(_created_log_path))


# ---------------------------------------------------------------------------
# LOG-001 — disabled by default
# ---------------------------------------------------------------------------

func test_logging_disabled_by_default() -> void:
	assert_false(LoggingMode.enabled,
			"LoggingMode should be disabled by default")


func test_log_file_path_empty_by_default() -> void:
	assert_eq(LoggingMode.log_file_path, "",
			"Log file path should be empty when disabled")


# ---------------------------------------------------------------------------
# LOG-001, LOG-002 — enable_file_logging
# ---------------------------------------------------------------------------

func test_enable_file_logging_sets_enabled() -> void:
	LoggingMode._enable_file_logging()
	_created_log_path = LoggingMode.log_file_path
	assert_true(LoggingMode.enabled,
			"enabled should be true after _enable_file_logging")
	assert_true(GameLogger.is_file_logging_enabled(),
			"GameLogger file logging should be active")
	assert_ne(LoggingMode.log_file_path, "",
			"log_file_path should not be empty")


func test_log_file_path_starts_with_res_logs() -> void:
	LoggingMode._enable_file_logging()
	_created_log_path = LoggingMode.log_file_path
	assert_string_starts_with(LoggingMode.log_file_path, "res://logs/game_",
			"Log file path should start with res://logs/game_")


func test_log_file_path_ends_with_log_extension() -> void:
	LoggingMode._enable_file_logging()
	_created_log_path = LoggingMode.log_file_path
	assert_string_ends_with(LoggingMode.log_file_path, ".log",
			"Log file path should end with .log")


# ---------------------------------------------------------------------------
# LOG-004, LOG-032 — session header
# ---------------------------------------------------------------------------

func test_session_header_written_on_enable() -> void:
	LoggingMode._enable_file_logging()
	_created_log_path = LoggingMode.log_file_path
	GameLogger.disable_file_logging()

	var content: String = FileAccess.get_file_as_string(
			LoggingMode.log_file_path)
	assert_string_contains(content, "Star Wars: Armada",
			"Header should contain project name")
	assert_string_contains(content, "App Version",
			"Header should contain app version line")
	assert_string_contains(content, "Godot",
			"Header should contain Godot version line")
	assert_string_contains(content, "OS",
			"Header should contain OS line")
	assert_string_contains(content, "Session",
			"Header should contain session timestamp line")
	assert_string_contains(content, "Play Mode",
			"Header should contain play mode line")
	assert_string_contains(content, "========",
			"Header should contain separator lines")


# ---------------------------------------------------------------------------
# Phase name helper
# ---------------------------------------------------------------------------

func test_phase_names_cover_all_game_phases() -> void:
	var phases: Array = [
		Constants.GamePhase.SETUP,
		Constants.GamePhase.COMMAND,
		Constants.GamePhase.SHIP,
		Constants.GamePhase.SQUADRON,
		Constants.GamePhase.STATUS,
	]
	for phase: Variant in phases:
		assert_has(LoggingMode.PHASE_NAMES, phase,
				"PHASE_NAMES should contain phase %s" % str(phase))


func test_faction_names_cover_main_factions() -> void:
	assert_has(LoggingMode.FACTION_NAMES,
			Constants.Faction.REBEL_ALLIANCE,
			"FACTION_NAMES should contain REBEL_ALLIANCE")
	assert_has(LoggingMode.FACTION_NAMES,
			Constants.Faction.GALACTIC_EMPIRE,
			"FACTION_NAMES should contain GALACTIC_EMPIRE")


# ---------------------------------------------------------------------------
# Command type helper
# ---------------------------------------------------------------------------

func test_command_type_name_navigate() -> void:
	assert_eq(LoggingMode._command_type_name(Constants.CommandType.NAVIGATE),
			"Navigate", "Navigate command name")


func test_command_type_name_squadron() -> void:
	assert_eq(LoggingMode._command_type_name(Constants.CommandType.SQUADRON),
			"Squadron", "Squadron command name")


func test_command_type_name_concentrate_fire() -> void:
	assert_eq(LoggingMode._command_type_name(
			Constants.CommandType.CONCENTRATE_FIRE),
			"Concentrate Fire", "Concentrate Fire command name")


func test_command_type_name_repair() -> void:
	assert_eq(LoggingMode._command_type_name(Constants.CommandType.REPAIR),
			"Repair", "Repair command name")


func test_command_type_name_unknown() -> void:
	var result: String = LoggingMode._command_type_name(99)
	assert_string_contains(result, "Unknown",
			"Unknown command should contain 'Unknown'")


# ---------------------------------------------------------------------------
# Play mode helper
# ---------------------------------------------------------------------------

func test_get_play_mode_name_hot_seat() -> void:
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT
	assert_eq(LoggingMode._get_play_mode_name(), "Hot-Seat",
			"Hot-seat mode name")


func test_get_play_mode_name_network() -> void:
	PlayMode.current_mode = PlayMode.Mode.NETWORK
	assert_eq(LoggingMode._get_play_mode_name(), "Network",
			"Network mode name")
	# Reset
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT


# ---------------------------------------------------------------------------
# Phase J9 — application-launch cleanup
# ---------------------------------------------------------------------------

func test_cleanup_old_logs_removes_log_files() -> void:
	var dir_path: String = PathConfig.LOGS_DIR
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var seeded: String = "%s/_gut_test_old.log" % dir_path
	var f: FileAccess = FileAccess.open(seeded, FileAccess.WRITE)
	f.store_string("old log content")
	f.close()
	assert_true(FileAccess.file_exists(seeded),
			"Seeded log must exist before cleanup")
	LoggingMode._cleanup_old_logs()
	assert_false(FileAccess.file_exists(seeded),
			"Old .log file should be deleted on launch")
