## Game Logger
##
## Centralized logging utility with severity levels.
## Provides consistent, formatted log output across the project.
##
## Supports optional file logging: when enabled via [method enable_file_logging],
## all log messages are also written to a file. The file is flushed after
## every write to prevent data loss on crash.
##
## Requirements: LOG-002, LOG-003, LOG-005, LOG-006, LOG-007.
@static_unload
class_name GameLogger
extends RefCounted


enum Level {
	DEBUG,
	INFO,
	WARNING,
	ERROR,
}

## The minimum log level that will be output. Messages below this are suppressed.
static var min_level: Level = Level.DEBUG

## The minimum file log level. Defaults to DEBUG (full verbosity).
## Requirements: LOG-007 — configurable file log level.
static var min_file_level: Level = Level.DEBUG

## Whether file logging is currently active.
static var _file_logging_enabled: bool = false

## The open file handle for log output (null when disabled).
static var _file_handle: FileAccess = null

## The path to the active log file (empty when disabled).
static var _file_path: String = ""

## The name of the system/module using this logger instance.
var context: String = ""


func _init(p_context: String = "") -> void:
	context = p_context


## Enables file logging to the given path.
## Creates the file and keeps it open for the session.
## Requirements: LOG-002, LOG-003.
static func enable_file_logging(path: String) -> bool:
	if _file_logging_enabled:
		disable_file_logging()
	_file_handle = FileAccess.open(path, FileAccess.WRITE)
	if _file_handle == null:
		push_error("GameLogger: Failed to open log file: %s (error %d)" % [
				path, FileAccess.get_open_error()])
		return false
	_file_path = path
	_file_logging_enabled = true
	return true


## Disables file logging and closes the file handle.
## Requirements: LOG-003.
static func disable_file_logging() -> void:
	if _file_handle != null:
		_file_handle.flush()
		_file_handle = null
	_file_logging_enabled = false
	_file_path = ""


## Returns true if file logging is currently active.
static func is_file_logging_enabled() -> bool:
	return _file_logging_enabled


## Returns the path to the active log file (empty when disabled).
static func get_log_file_path() -> String:
	return _file_path


## Writes raw text directly to the log file (no formatting).
## Used for session headers and state snapshots.
## Requirements: LOG-004, LOG-020.
static func write_raw_to_file(text: String) -> void:
	if not _file_logging_enabled or _file_handle == null:
		return
	_file_handle.store_string(text)
	_file_handle.flush()


## Logs a debug message.
func debug(message: String) -> void:
	_log(Level.DEBUG, message)


## Logs an info message.
func info(message: String) -> void:
	_log(Level.INFO, message)


## Logs a warning message.
func warn(message: String) -> void:
	_log(Level.WARNING, message)


## Logs an error message.
func error(message: String) -> void:
	_log(Level.ERROR, message)


## Internal logging implementation.
## Requirements: LOG-005 — mirrors to file when enabled.
## Requirements: LOG-006 — format: [timestamp] [LEVEL] [context] message.
func _log(level: Level, message: String) -> void:
	if level < min_level and (not _file_logging_enabled or level < min_file_level):
		return

	var level_str := _level_to_string(level)
	var timestamp := Time.get_datetime_string_from_system()
	var formatted := "[%s] [%s] [%s] %s" % [timestamp, level_str, context, message]

	# Console output.
	if level >= min_level:
		match level:
			Level.WARNING:
				push_warning(formatted)
			Level.ERROR:
				push_error(formatted)
			_:
				print(formatted)

	# File output.
	if _file_logging_enabled and _file_handle != null and level >= min_file_level:
		_file_handle.store_string(formatted + "\n")
		_file_handle.flush()


## Converts a log level to a string.
static func _level_to_string(level: Level) -> String:
	match level:
		Level.DEBUG:
			return "DEBUG"
		Level.INFO:
			return "INFO"
		Level.WARNING:
			return "WARN"
		Level.ERROR:
			return "ERROR"
		_:
			return "UNKNOWN"
