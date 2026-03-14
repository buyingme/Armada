## DebugMode
##
## Global debug mode toggle for development tooling.
## When enabled, provides interactive token placement: select, drag, rotate,
## and save positions. When disabled, all debug interactions are inactive.
##
## Requirements: DBG-001, DBG-002, DBG-003
extends Node


## Emitted when debug mode is toggled on or off.
signal debug_mode_changed(enabled: bool)

## Emitted when the user presses the save-positions action.
signal save_positions_requested()

## Whether debug mode is currently active.
var enabled: bool = false:
	set(value):
		if enabled != value:
			enabled = value
			debug_mode_changed.emit(enabled)
			_log.info("Debug mode %s" % ("ENABLED" if enabled else "DISABLED"))

## The token currently selected for dragging (null = nothing selected).
var selected_token: Node2D = null

## Logger instance.
var _log: GameLogger = GameLogger.new("DebugMode")


## Keyboard shortcut: F12 toggles debug mode, Ctrl+S saves positions.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_F12:
			enabled = not enabled
			get_viewport().set_input_as_handled()
		elif enabled and key_event.keycode == KEY_S and key_event.ctrl_pressed:
			save_positions_requested.emit()
			get_viewport().set_input_as_handled()


## Selects a token for debug dragging.
## DBG-010 — left-click selects a token.
func select_token(token: Node2D) -> void:
	if not enabled:
		return
	if selected_token == token:
		deselect_token()
		return
	selected_token = token
	_log.debug("Selected token: %s" % token.name)


## Deselects the currently selected token.
## DBG-010 — left-click same token or empty space deselects.
func deselect_token() -> void:
	if selected_token != null:
		_log.debug("Deselected token: %s" % selected_token.name)
		selected_token = null


## Returns true when a token is actively selected for dragging.
func has_selection() -> bool:
	return enabled and selected_token != null
