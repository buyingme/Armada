## LoggingMode
##
## Singleton that controls file-based game logging.
## When enabled (via `--logging` CLI flag), all [GameLogger] output is
## mirrored to a timestamped log file at `user://logs/game_<timestamp>.log`.
##
## The logger also subscribes to [EventBus] signals to automatically log
## game flow events: phase transitions, active player changes, command
## dial assignments, activations, handoffs, and auto-pass detection.
##
## Requirements: LOG-001–023.
extends Node


## Whether file logging is active this session.
## Requirements: LOG-001 — off by default, activated by `--logging` flag.
var enabled: bool = false

## The path to the current session's log file (empty when disabled).
var log_file_path: String = ""

## Logger instance for this autoload's own messages.
var _log: GameLogger = GameLogger.new("LoggingMode")

## Human-readable phase names for log messages.
const PHASE_NAMES: Dictionary = {
	Constants.GamePhase.SETUP: "Setup",
	Constants.GamePhase.COMMAND: "Command",
	Constants.GamePhase.SHIP: "Ship",
	Constants.GamePhase.SQUADRON: "Squadron",
	Constants.GamePhase.STATUS: "Status",
}

## Human-readable faction names for log messages.
const FACTION_NAMES: Dictionary = {
	Constants.Faction.REBEL_ALLIANCE: "Rebel",
	Constants.Faction.GALACTIC_EMPIRE: "Imperial",
}


func _ready() -> void:
	# Application-launch cleanup: wipe log files from previous sessions
	# before we open today's file.  Runs unconditionally so old logs
	# don't accumulate even when the user launches without --logging.
	_cleanup_old_logs()
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.has("--logging"):
		_enable_file_logging()


## Removes every [code]*.log[/code] file in [PathConfig.LOGS_DIR].
## Called from [method _ready] before the current session's log file
## is opened.  No-op if the directory does not exist.
func _cleanup_old_logs() -> void:
	var dir_path: String = PathConfig.LOGS_DIR
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".log"):
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()


## Enables file logging, creates the log directory and file, writes the
## session header, and connects to EventBus signals.
## Requirements: LOG-001, LOG-002, LOG-003, LOG-004.
func _enable_file_logging() -> void:
	enabled = true
	var timestamp: String = Time.get_datetime_string_from_system().replace(
			":", "").replace("-", "").replace("T", "_")
	var dir_path: String = PathConfig.LOGS_DIR
	DirAccess.make_dir_recursive_absolute(dir_path)
	log_file_path = "%s/game_%s.log" % [dir_path, timestamp]

	# Open file and write header.
	GameLogger.enable_file_logging(log_file_path)
	_write_session_header()
	_connect_event_signals()
	_log.info("File logging enabled: %s" % log_file_path)


## Writes the session header block at the top of the log file.
## Requirements: LOG-004 — version, Godot version, OS, timestamp, play mode.
func _write_session_header() -> void:
	var header_lines: PackedStringArray = PackedStringArray()
	header_lines.append("========================================")
	header_lines.append("Star Wars: Armada — Game Log")
	header_lines.append("========================================")
	var app_version: String = ProjectSettings.get_setting(
			"application/config/version", "unknown")
	header_lines.append("App Version : %s" % app_version)
	header_lines.append("Godot       : %s" % Engine.get_version_info().get(
			"string", "unknown"))
	header_lines.append("OS          : %s" % OS.get_name())
	header_lines.append("Session     : %s" % Time.get_datetime_string_from_system())
	header_lines.append("Play Mode   : %s" % _get_play_mode_name())
	header_lines.append("========================================")
	header_lines.append("")
	GameLogger.write_raw_to_file("\n".join(header_lines) + "\n")


## Connects to all EventBus signals for automatic game event logging.
## Skips signals that are already connected (idempotent).
## Requirements: LOG-010–020.
func _connect_event_signals() -> void:
	var pairs: Array = [
		["game_started", _on_game_started],
		["game_ended", _on_game_ended],
		["round_started", _on_round_started],
		["round_ended", _on_round_ended],
		["phase_changed", _on_phase_changed],
		["active_player_changed", _on_active_player_changed],
		["command_picker_confirmed", _on_command_picker_confirmed],
		["command_dials_submitted", _on_command_dials_submitted],
		["command_phase_complete", _on_command_phase_complete],
		["handoff_accepted", _on_handoff_accepted],
		["activation_ended", _on_activation_ended],
	]
	for pair: Variant in pairs:
		var sig_name: String = pair[0]
		var handler: Callable = pair[1]
		if not EventBus.is_connected(sig_name, handler):
			EventBus.connect(sig_name, handler)


## Returns how many EventBus signals are connected for testing.
func get_connected_signal_count() -> int:
	if not enabled:
		return 0
	var count: int = 0
	# Check each signal we connect to.
	var signals_to_check: Array[String] = [
		"game_started", "game_ended", "round_started", "round_ended",
		"phase_changed", "active_player_changed", "command_picker_confirmed",
		"command_dials_submitted", "command_phase_complete",
		"handoff_accepted", "activation_ended",
	]
	for sig_name: String in signals_to_check:
		if EventBus.is_connected(sig_name, Callable(self , "_on_" + sig_name)):
			count += 1
	return count


## Disconnects all EventBus signal handlers. Used for test cleanup.
func disconnect_event_signals() -> void:
	var pairs: Array = [
		["game_started", _on_game_started],
		["game_ended", _on_game_ended],
		["round_started", _on_round_started],
		["round_ended", _on_round_ended],
		["phase_changed", _on_phase_changed],
		["active_player_changed", _on_active_player_changed],
		["command_picker_confirmed", _on_command_picker_confirmed],
		["command_dials_submitted", _on_command_dials_submitted],
		["command_phase_complete", _on_command_phase_complete],
		["handoff_accepted", _on_handoff_accepted],
		["activation_ended", _on_activation_ended],
	]
	for pair: Variant in pairs:
		var sig_name: String = pair[0]
		var handler: Callable = pair[1]
		if EventBus.is_connected(sig_name, handler):
			EventBus.disconnect(sig_name, handler)


# ---------------------------------------------------------------------------
# Event handlers — Requirements: LOG-010–020
# ---------------------------------------------------------------------------

## LOG-010 — game_started.
func _on_game_started() -> void:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		_log.info("game_started")
		return
	var init_player: int = gs.initiative_player
	var p0_faction: String = _get_player_faction_name(0)
	var p1_faction: String = _get_player_faction_name(1)
	_log.info("game_started — Player 0: %s, Player 1: %s, Initiative: %d" % [
			p0_faction, p1_faction, init_player])


## LOG-010 — game_ended.
func _on_game_ended(details: Dictionary) -> void:
	var winner: int = details.get("winner_index", -1)
	var reason: String = details.get("reason", "unknown")
	var scores: Array = details.get("scores", [0, 0])
	_log.info("game_ended — Winner: %d, Reason: %s, Scores: %s" % [
			winner, reason, str(scores)])


## LOG-011 — round_started.
func _on_round_started(round_number: int) -> void:
	_log.info("round_started(%d)" % round_number)
	_log_state_snapshot()


## LOG-011 — round_ended.
func _on_round_ended(round_number: int) -> void:
	_log.info("round_ended(%d)" % round_number)


## LOG-012 — phase_changed.
func _on_phase_changed(new_phase: Constants.GamePhase) -> void:
	var phase_name: String = PHASE_NAMES.get(new_phase, "Unknown")
	_log.info("phase_changed(%s)" % phase_name)
	_log_state_snapshot()


## LOG-013 — active_player_changed.
func _on_active_player_changed(player_index: int) -> void:
	var faction: String = _get_player_faction_name(player_index)
	var phase_name: String = _get_current_phase_name()
	_log.info("active_player_changed(%d) — %s, Phase: %s" % [
			player_index, faction, phase_name])


## LOG-014 — command_picker_confirmed.
func _on_command_picker_confirmed(
		ship_ref: RefCounted, commands: Array) -> void:
	var ship_name: String = "Unknown"
	if ship_ref is ShipInstance:
		var si: ShipInstance = ship_ref as ShipInstance
		if si.ship_data != null:
			ship_name = si.ship_data.ship_name
	var cmd_names: PackedStringArray = PackedStringArray()
	for cmd: Variant in commands:
		cmd_names.append(_command_type_name(cmd as int))
	_log.info("command_dials_assigned(%s, [%s])" % [
			ship_name, ", ".join(cmd_names)])


## LOG-015 — command_dials_submitted.
func _on_command_dials_submitted(player_index: int) -> void:
	_log.info("command_dials_submitted(player=%d)" % player_index)


## LOG-015 — command_phase_complete.
func _on_command_phase_complete() -> void:
	_log.info("command_phase_complete")


## LOG-016 — handoff_accepted.
func _on_handoff_accepted() -> void:
	var phase_name: String = _get_current_phase_name()
	_log.info("handoff_accepted — Phase: %s" % phase_name)


## LOG-017, LOG-018 — activation_ended.
func _on_activation_ended() -> void:
	var phase_name: String = _get_current_phase_name()
	var player: int = GameManager.get_active_player()
	_log.info("activation_ended — Player: %d, Phase: %s" % [
			player, phase_name])


# ---------------------------------------------------------------------------
# State snapshot — Requirement: LOG-020
# ---------------------------------------------------------------------------

## Logs a summary of current game state at phase boundaries.
## Requirements: LOG-020 — round, ship counts, unactivated counts.
func _log_state_snapshot() -> void:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	var round_num: int = gs.current_round
	var phase_name: String = _get_current_phase_name()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("  [STATE] Round: %d, Phase: %s" % [round_num, phase_name])
	for pi: int in range(Constants.PLAYER_COUNT):
		var ps: PlayerState = gs.get_player_state(pi)
		if ps == null:
			continue
		var faction: String = FACTION_NAMES.get(ps.faction, "P%d" % pi)
		var ship_count: int = ps.ships.size()
		var squad_count: int = ps.squadrons.size()
		var unactivated_ships: int = _count_unactivated_ships(ps)
		var unactivated_squads: int = _count_unactivated_squadrons(ps)
		lines.append("  [STATE] %s — Ships: %d (unactivated: %d), Squads: %d (unactivated: %d)" % [
				faction, ship_count, unactivated_ships,
				squad_count, unactivated_squads])
	GameLogger.write_raw_to_file("\n".join(lines) + "\n")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns the faction name for a player index from GameState.
func _get_player_faction_name(player_index: int) -> String:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return "Player %d" % player_index
	var ps: PlayerState = gs.get_player_state(player_index)
	if ps == null:
		return "Player %d" % player_index
	return FACTION_NAMES.get(ps.faction, "Player %d" % player_index)


## Returns the current phase name from GameManager.
func _get_current_phase_name() -> String:
	var phase: Constants.GamePhase = GameManager.get_current_phase()
	return PHASE_NAMES.get(phase, "Unknown")


## Returns the current play mode as a string.
func _get_play_mode_name() -> String:
	if PlayMode.is_hot_seat():
		return "Hot-Seat"
	return "Network"


## Converts a CommandType int to a human-readable name.
func _command_type_name(cmd: int) -> String:
	match cmd:
		Constants.CommandType.NAVIGATE:
			return "Navigate"
		Constants.CommandType.SQUADRON:
			return "Squadron"
		Constants.CommandType.CONCENTRATE_FIRE:
			return "Concentrate Fire"
		Constants.CommandType.REPAIR:
			return "Repair"
		_:
			return "Unknown(%d)" % cmd


## Counts unactivated ships for a player state.
func _count_unactivated_ships(ps: PlayerState) -> int:
	var count: int = 0
	for s: Variant in ps.ships:
		if s is ShipInstance:
			var si: ShipInstance = s as ShipInstance
			if not si.activated_this_round:
				count += 1
	return count


## Counts unactivated squadrons for a player state.
func _count_unactivated_squadrons(ps: PlayerState) -> int:
	var count: int = 0
	for sq: Variant in ps.squadrons:
		if sq is SquadronInstance:
			var sqi: SquadronInstance = sq as SquadronInstance
			if not sqi.activated_this_round:
				count += 1
	return count


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if enabled:
			_log.info("Session ended — closing log file.")
			GameLogger.disable_file_logging()
