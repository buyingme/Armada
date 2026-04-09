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


func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.has("--debug-mode"):
		enabled = true
		_log.info("Debug mode auto-enabled via --debug-mode CLI flag")


## Keyboard shortcut: F12 toggles debug mode, Ctrl+S saves positions,
## F5 quicksaves, F8 quickloads (debug mode only).
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_F12:
			enabled = not enabled
			get_viewport().set_input_as_handled()
		elif enabled:
			match key_event.keycode:
				KEY_S:
					if key_event.ctrl_pressed:
						save_positions_requested.emit()
						get_viewport().set_input_as_handled()
				KEY_F5:
					_quicksave()
					get_viewport().set_input_as_handled()
				KEY_F8:
					_quickload()
					get_viewport().set_input_as_handled()


## Saves the current game state to [code]res://saves/quicksave.json[/code].
func _quicksave() -> void:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		_log.warn("No active game state to save.")
		return
	var ok: bool = SaveGameManager.save_game(gs)
	if ok:
		_log.info("Quicksave complete.")
	else:
		_log.error("Quicksave failed.")


## Loads a game state from [code]res://saves/quicksave.json[/code] and logs it.
## Full state restoration is not yet implemented — this logs the loaded data
## so you can verify the JSON round-trip in the console.
func _quickload() -> void:
	var loaded: GameState = SaveGameManager.load_game()
	if loaded == null:
		_log.warn("Quickload failed — no save file found.")
		return
	_log.info("Quickload OK — round %d, phase %d, p0 score %d, p1 score %d" % [
		loaded.current_round,
		loaded.current_phase,
		loaded.player_states[0].score,
		loaded.player_states[1].score,
	])


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
