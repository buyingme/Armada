## Test: Game Logging Integration
##
## Integration tests that verify game events produce the expected log lines.
## Requirements: LOG-010–020, LOG-033.
extends GutTest


## Temporary log file path.
var _test_log_path: String = "user://logs/_test_integration_logging.log"


func before_each() -> void:
	GameLogger.disable_file_logging()
	DirAccess.make_dir_recursive_absolute("user://logs")
	GameLogger.enable_file_logging(_test_log_path)
	GameLogger.min_level = GameLogger.Level.DEBUG
	GameLogger.min_file_level = GameLogger.Level.DEBUG
	LoggingMode.enabled = true
	LoggingMode.log_file_path = _test_log_path
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT
	_connect_logging_signals()


func after_each() -> void:
	_disconnect_logging_signals()
	GameLogger.disable_file_logging()
	LoggingMode.enabled = false
	LoggingMode.log_file_path = ""
	GameManager.is_game_active = false
	GameManager.current_game_state = null
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT
	if FileAccess.file_exists(_test_log_path):
		DirAccess.remove_absolute(
				ProjectSettings.globalize_path(_test_log_path))


## Connects LoggingMode's event handlers to EventBus signals.
func _connect_logging_signals() -> void:
	if not EventBus.game_started.is_connected(LoggingMode._on_game_started):
		EventBus.game_started.connect(LoggingMode._on_game_started)
	if not EventBus.game_ended.is_connected(LoggingMode._on_game_ended):
		EventBus.game_ended.connect(LoggingMode._on_game_ended)
	if not EventBus.round_started.is_connected(LoggingMode._on_round_started):
		EventBus.round_started.connect(LoggingMode._on_round_started)
	if not EventBus.round_ended.is_connected(LoggingMode._on_round_ended):
		EventBus.round_ended.connect(LoggingMode._on_round_ended)
	if not EventBus.phase_changed.is_connected(LoggingMode._on_phase_changed):
		EventBus.phase_changed.connect(LoggingMode._on_phase_changed)
	if not EventBus.active_player_changed.is_connected(
			LoggingMode._on_active_player_changed):
		EventBus.active_player_changed.connect(
				LoggingMode._on_active_player_changed)
	if not EventBus.command_dials_submitted.is_connected(
			LoggingMode._on_command_dials_submitted):
		EventBus.command_dials_submitted.connect(
				LoggingMode._on_command_dials_submitted)
	if not EventBus.command_phase_complete.is_connected(
			LoggingMode._on_command_phase_complete):
		EventBus.command_phase_complete.connect(
				LoggingMode._on_command_phase_complete)
	if not EventBus.handoff_accepted.is_connected(
			LoggingMode._on_handoff_accepted):
		EventBus.handoff_accepted.connect(
				LoggingMode._on_handoff_accepted)
	if not EventBus.activation_ended.is_connected(
			LoggingMode._on_activation_ended):
		EventBus.activation_ended.connect(
				LoggingMode._on_activation_ended)


## Disconnects LoggingMode's event handlers from EventBus signals.
func _disconnect_logging_signals() -> void:
	var pairs: Array = [
		["game_started", LoggingMode._on_game_started],
		["game_ended", LoggingMode._on_game_ended],
		["round_started", LoggingMode._on_round_started],
		["round_ended", LoggingMode._on_round_ended],
		["phase_changed", LoggingMode._on_phase_changed],
		["active_player_changed", LoggingMode._on_active_player_changed],
		["command_dials_submitted", LoggingMode._on_command_dials_submitted],
		["command_phase_complete", LoggingMode._on_command_phase_complete],
		["handoff_accepted", LoggingMode._on_handoff_accepted],
		["activation_ended", LoggingMode._on_activation_ended],
	]
	for pair: Variant in pairs:
		var sig_name: String = pair[0]
		var handler: Callable = pair[1]
		if EventBus.is_connected(sig_name, handler):
			EventBus.disconnect(sig_name, handler)


## Reads and returns the full log file content.
func _get_log_content() -> String:
	GameLogger.disable_file_logging()
	if FileAccess.file_exists(_test_log_path):
		return FileAccess.get_file_as_string(_test_log_path)
	return ""


# ---------------------------------------------------------------------------
# LOG-033 — phase transitions produce log lines
# ---------------------------------------------------------------------------

func test_game_start_logs_round_and_phase() -> void:
	GameManager.start_new_game()
	var content: String = _get_log_content()
	assert_string_contains(content, "round_started(1)",
			"Should log round_started(1)")
	assert_string_contains(content, "phase_changed(Command)",
			"Should log phase_changed(Command)")


func test_game_start_logs_active_player() -> void:
	GameManager.start_new_game()
	var content: String = _get_log_content()
	assert_string_contains(content, "active_player_changed(0)",
			"Should log active_player_changed(0) at game start")


func test_command_submit_logs_submission() -> void:
	GameManager.start_new_game()
	EventBus.command_dials_submitted.emit(0)
	var content: String = _get_log_content()
	assert_string_contains(content, "command_dials_submitted(player=0)",
			"Should log command_dials_submitted for player 0")


func test_both_submit_logs_command_phase_complete() -> void:
	GameManager.start_new_game()
	EventBus.command_dials_submitted.emit(0)
	EventBus.command_dials_submitted.emit(1)
	var content: String = _get_log_content()
	assert_string_contains(content, "command_phase_complete",
			"Should log command_phase_complete")


func test_ship_phase_transition_logged() -> void:
	GameManager.start_new_game()
	EventBus.command_dials_submitted.emit(0)
	EventBus.command_dials_submitted.emit(1)
	var content: String = _get_log_content()
	assert_string_contains(content, "phase_changed(Ship)",
			"Should log phase_changed(Ship)")


func test_handoff_accepted_logged() -> void:
	GameManager.start_new_game()
	EventBus.handoff_accepted.emit()
	var content: String = _get_log_content()
	assert_string_contains(content, "handoff_accepted",
			"Should log handoff_accepted")


func test_activation_ended_logged() -> void:
	GameManager.start_new_game()
	EventBus.command_dials_submitted.emit(0)
	EventBus.command_dials_submitted.emit(1)
	# Now in Ship Phase — emit activation_ended.
	EventBus.activation_ended.emit()
	var content: String = _get_log_content()
	assert_string_contains(content, "activation_ended",
			"Should log activation_ended")


func test_game_ended_logged() -> void:
	GameManager.start_new_game()
	GameManager.end_game(0)
	var content: String = _get_log_content()
	assert_string_contains(content, "game_ended",
			"Should log game_ended")


func test_full_flow_produces_ordered_log_sequence() -> void:
	GameManager.start_new_game()
	# Command Phase: both players submit.
	EventBus.command_dials_submitted.emit(0)
	EventBus.command_dials_submitted.emit(1)
	# Ship Phase → activation_ended (no ships → advances).
	EventBus.activation_ended.emit()
	# Squadron Phase → activation_ended (no squadrons → advances).
	EventBus.activation_ended.emit()
	var content: String = _get_log_content()

	# Verify ordering: round_started before phase_changed, Command before Ship.
	var idx_round: int = content.find("round_started(1)")
	var idx_command: int = content.find("phase_changed(Command)")
	var idx_ship: int = content.find("phase_changed(Ship)")
	var idx_squad: int = content.find("phase_changed(Squadron)")
	var idx_status: int = content.find("phase_changed(Status)")

	assert_gt(idx_round, -1, "round_started should appear in log")
	assert_gt(idx_command, -1, "phase_changed(Command) should appear")
	assert_gt(idx_ship, -1, "phase_changed(Ship) should appear")
	assert_gt(idx_squad, -1, "phase_changed(Squadron) should appear")
	assert_gt(idx_status, -1, "phase_changed(Status) should appear")

	assert_lt(idx_round, idx_command,
			"round_started should appear before Command phase")
	assert_lt(idx_command, idx_ship,
			"Command should appear before Ship")
	assert_lt(idx_ship, idx_squad,
			"Ship should appear before Squadron")
	assert_lt(idx_squad, idx_status,
			"Squadron should appear before Status")
