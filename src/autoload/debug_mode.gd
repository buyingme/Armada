## DebugMode
##
## Global debug mode toggle for development tooling.
## When enabled, provides interactive token placement: select, drag, rotate,
## and save positions. When disabled, all debug interactions are inactive.
##
## Annotation feature (DBG-060): Shift+A opens a text input modal.
## On confirm the full serialized GameState is saved to
## [code]saves/annotations/[/code] alongside the annotation text,
## and the annotation is logged.
##
## Requirements: DBG-001, DBG-002, DBG-003, DBG-060
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

## Session-scoped annotation counter (resets each launch).
var _annotation_counter: int = 0

## Reference to the currently open annotation modal (null = none open).
var _annotation_modal: DebugAnnotationModal = null

## Directory for annotation save files.
const ANNOTATION_DIR: String = "res://saves/annotations"

## Logger instance.
var _log: GameLogger = GameLogger.new("DebugMode")


func _ready() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.has("--debug-mode"):
		enabled = true
		_log.info("Debug mode auto-enabled via --debug-mode CLI flag")


## Keyboard shortcut: F12 toggles debug mode, Ctrl+S saves positions,
## Shift+A opens annotation modal,
## Shift+R saves a replay file (debug mode only).
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
				KEY_A:
					if key_event.shift_pressed:
						_open_annotation_modal()
						get_viewport().set_input_as_handled()
				KEY_R:
					if key_event.shift_pressed:
						_save_replay()
						get_viewport().set_input_as_handled()


## Saves a replay file containing the full command history and session
## header to [code]res://replays/[/code].
## Triggered by Shift+R in debug mode.
func _save_replay() -> void:
	var replay: GameReplay = CommandProcessor.create_replay()
	if replay == null:
		_log.warn("No active game — cannot save replay.")
		_show_toast("Replay save failed — no active game.")
		return
	var path: String = GameReplay.generate_file_path()
	var err: Error = replay.save_to_file(path)
	if err == OK:
		_log.info("Replay saved: %s (%d commands)." % [
				path, replay.get_command_count()])
		_show_toast("Replay saved (%d cmds)." % replay.get_command_count())
	else:
		_log.error("Replay save failed: %s" % error_string(err))
		_show_toast("Replay save FAILED.")


# ---------------------------------------------------------------------------
# Annotation — DBG-060
# ---------------------------------------------------------------------------

## Opens the annotation text input modal.
## If one is already open it is ignored to prevent duplicates.
func _open_annotation_modal() -> void:
	if _annotation_modal != null:
		return
	if GameManager.current_game_state == null:
		_log.warn("No active game state — cannot annotate.")
		_show_toast("No active game to annotate.")
		return
	_annotation_modal = DebugAnnotationModal.new()
	_annotation_modal.annotation_submitted.connect(_on_annotation_submitted)
	_annotation_modal.cancelled.connect(_on_annotation_cancelled)
	_annotation_modal.tree_exiting.connect(_on_annotation_modal_freed)
	get_tree().root.add_child(_annotation_modal)


## Handles annotation submission: serialize state + write file + log.
func _on_annotation_submitted(text: String) -> void:
	_annotation_counter += 1
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		_log.warn("Game state disappeared before annotation could be saved.")
		return
	var ok: bool = _save_annotation(text, gs)
	if ok:
		_log.info("[ANNOTATION #%d] %s" % [_annotation_counter, text])
		_show_toast("Annotation #%d saved." % _annotation_counter)
	else:
		_log.error("Failed to save annotation #%d." % _annotation_counter)
		_show_toast("Annotation save FAILED.")


## Clears the modal reference on cancel.
func _on_annotation_cancelled() -> void:
	_annotation_modal = null


## Clears the modal reference when it exits the tree.
func _on_annotation_modal_freed() -> void:
	_annotation_modal = null


## Writes the annotation JSON file to [code]saves/annotations/[/code].
## Returns [code]true[/code] on success.
func _save_annotation(text: String, gs: GameState) -> bool:
	if not DirAccess.dir_exists_absolute(ANNOTATION_DIR):
		var err: Error = DirAccess.make_dir_recursive_absolute(ANNOTATION_DIR)
		if err != OK:
			_log.error("Failed to create annotation dir: %s" % ANNOTATION_DIR)
			return false
	var timestamp: String = Time.get_datetime_string_from_system()
	var safe_ts: String = timestamp.replace(":", "").replace("-", "").replace("T", "_")
	var file_name: String = "annotation_%s_%03d.json" % [safe_ts, _annotation_counter]
	var file_path: String = "%s/%s" % [ANNOTATION_DIR, file_name]
	var phase_name: String = _phase_to_string(gs.current_phase)
	var data: Dictionary = {
		"annotation": text,
		"timestamp": timestamp,
		"round": gs.current_round,
		"phase": phase_name,
		"counter": _annotation_counter,
		"game_state": gs.serialize(),
	}
	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		_log.error("Failed to open annotation file: %s" % file_path)
		return false
	file.store_string(json_string)
	file.close()
	return true


## Converts a [enum Constants.GamePhase] to a human-readable string.
func _phase_to_string(phase: Constants.GamePhase) -> String:
	match phase:
		Constants.GamePhase.SETUP:
			return "SETUP"
		Constants.GamePhase.COMMAND:
			return "COMMAND"
		Constants.GamePhase.SHIP:
			return "SHIP"
		Constants.GamePhase.SQUADRON:
			return "SQUADRON"
		Constants.GamePhase.STATUS:
			return "STATUS"
		_:
			return "UNKNOWN"


# ---------------------------------------------------------------------------
# Toast — shared notification helper
# ---------------------------------------------------------------------------

## Shows a brief fade-in/out toast notification at the top of the screen.
func _show_toast(message: String) -> void:
	var root: Window = get_tree().root if get_tree() else null
	if root == null:
		return
	var toast: DebugToast = DebugToast.new(message)
	root.add_child(toast)


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
