## Logger
##
## Centralized logging utility with severity levels.
## Provides consistent, formatted log output across the project.
class_name Logger
extends RefCounted


enum Level {
	DEBUG,
	INFO,
	WARNING,
	ERROR,
}

## The minimum log level that will be output. Messages below this are suppressed.
static var min_level: Level = Level.DEBUG

## The name of the system/module using this logger instance.
var context: String = ""


func _init(p_context: String = "") -> void:
	context = p_context


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
func _log(level: Level, message: String) -> void:
	if level < min_level:
		return

	var level_str := _level_to_string(level)
	var timestamp := Time.get_datetime_string_from_system()
	var formatted := "[%s] [%s] [%s] %s" % [timestamp, level_str, context, message]

	match level:
		Level.WARNING:
			push_warning(formatted)
		Level.ERROR:
			push_error(formatted)
		_:
			print(formatted)


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
