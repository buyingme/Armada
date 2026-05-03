## Game Menu Modal (Phase J3)
##
## In-game ESC menu shown when the player presses Escape on the main
## game board with no other modal open.  Replaces the legacy
## [code]QuitConfirmationModal[/code] (Phase J3 / Q10).
##
## Buttons:
## | Mode           | Visible                                    |
## |----------------|--------------------------------------------|
## | Hot-seat       | Resume \u00b7 Save Game \u00b7 Load Game \u00b7 Quit Game |
## | Network host   | Resume \u00b7 Save Game \u00b7 Load Game \u00b7 Quit Game |
## | Network client | Resume \u00b7 Quit Game                          |
##
## Save / Load buttons are stub-disabled until slices J4 / J5.  They
## emit their respective signals so the host scene can wire them.
##
## ESC opens the modal; pressing ESC again or Resume closes it.
##
## Quit triggers an unsaved-changes check via [SaveGameManager.is_dirty]:
## when the game has advanced past the last save, [SaveOnQuitDialog]
## opens with the three Save & Quit / Quit Without Saving / Cancel
## options before the actual quit fires.
class_name GameMenuModal
extends PanelContainer


enum Mode {
	HOT_SEAT,
	NETWORK_HOST,
	NETWORK_CLIENT,
}


## Emitted when the player chooses Resume (or presses ESC while open).
signal resume_requested

## Emitted when the player chooses Save Game.
signal save_requested

## Emitted when the player chooses Load Game.
signal load_requested

## Emitted when the player has confirmed they want to quit (after the
## "Save first?" sub-dialog has been resolved one way or another).
## [code]save_first[/code] is true when the user picked "Save & Quit".
signal quit_requested(save_first: bool)


## The current mode (controls button visibility).
var mode: Mode = Mode.HOT_SEAT

## Optional override for the [SaveGameManager.is_dirty] check (used by
## tests).  When non-negative, takes precedence over the autoload.
var dirty_override: int = -1

var _btn_resume: Button = null
var _btn_save: Button = null
var _btn_load: Button = null
var _btn_quit: Button = null
var _save_on_quit_dialog: SaveOnQuitDialog = null
var _save_game_dialog: SaveGameDialog = null
var _load_game_dialog: LoadGameDialog = null
## When true, a successful save in the [SaveGameDialog] is followed by
## emitting [signal quit_requested].  Used by the dirty-quit flow.
var _save_then_quit: bool = false


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


## Sets the mode and rebuilds button visibility / disabled state.
## Should be called once after construction and again whenever play
## mode changes.
func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_apply_mode_visibility()


## Shows the modal, centred on the viewport.
func show_modal() -> void:
	_apply_mode_visibility()
	visible = true
	await get_tree().process_frame
	var vp_size: Vector2 = get_viewport_rect().size
	position = (vp_size - size) * 0.5


## Hides the modal.
func hide_modal() -> void:
	visible = false


## Toggles visibility (used by ESC handler).  Returns the new visibility.
func toggle() -> bool:
	if visible:
		hide_modal()
	else:
		show_modal()
	return visible


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	add_theme_stylebox_override("panel",
			UIStyleHelper.create_modal_panel_style(0.0))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	vbox.add_child(_build_title_label())
	_btn_resume = _make_button("Resume")
	_btn_resume.pressed.connect(_on_resume_pressed)
	vbox.add_child(_btn_resume)
	_btn_save = _make_button("Save Game")
	_btn_save.pressed.connect(_on_save_pressed)
	vbox.add_child(_btn_save)
	_btn_load = _make_button("Load Game")
	_btn_load.pressed.connect(_on_load_pressed)
	vbox.add_child(_btn_load)
	_btn_quit = _make_button("Quit Game")
	_btn_quit.pressed.connect(_on_quit_pressed)
	vbox.add_child(_btn_quit)


func _build_title_label() -> Label:
	var label: Label = Label.new()
	label.text = "Game Menu"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	return label


func _make_button(label_text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(200, 44)
	return btn


## Hides Save / Load for network clients; Save is enabled for hot-seat
## and network host (J4); Load is enabled in J5.
func _apply_mode_visibility() -> void:
	if _btn_save == null or _btn_load == null:
		return
	var save_load_visible: bool = mode != Mode.NETWORK_CLIENT
	_btn_save.visible = save_load_visible
	_btn_load.visible = save_load_visible
	_apply_save_button_state()
	_btn_load.disabled = false
	_btn_load.tooltip_text = ""


## Updates the Save Game button's enabled state.  Phase J5.5: enabled
## whenever a checkpoint exists for the current mode (the named save is
## written from the checkpoint payload, not the live state).  Tooltip
## reports the checkpoint's round/phase so the player knows which moment
## will be saved.  Falls back to the legacy [SaveGameManager.can_save_now]
## gate only when no checkpoint has been written yet.
func _apply_save_button_state() -> void:
	if _btn_save == null:
		return
	if not is_instance_valid(SaveGameManager):
		_btn_save.disabled = true
		_btn_save.tooltip_text = ""
		return
	if SaveGameManager.has_checkpoint():
		var meta: SaveGameMetadata = SaveGameManager.checkpoint_metadata()
		_btn_save.disabled = false
		if meta != null:
			_btn_save.tooltip_text = "Saves last safe point: Round %d, %s" \
					% [meta.current_round, meta.phase]
		else:
			_btn_save.tooltip_text = ""
		return
	# No checkpoint yet \u2014 fall back to legacy gate (e.g. before the
	# first command_executed has fired).
	var gate: Dictionary = {"ok": false, "reason": "No checkpoint yet."}
	if is_instance_valid(GameManager):
		gate = SaveGameManager.can_save_now(GameManager.current_game_state)
	var ok: bool = bool(gate.get("ok", false))
	_btn_save.disabled = not ok
	_btn_save.tooltip_text = "" if ok else String(gate.get("reason", ""))


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

## Escape closes the modal (Resume).
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_on_resume_pressed()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_resume_pressed() -> void:
	SfxManager.play_sfx("skip_beep")
	hide_modal()
	resume_requested.emit()


func _on_save_pressed() -> void:
	SfxManager.play_sfx("droid_sound")
	_save_then_quit = false
	hide_modal()
	_open_save_dialog()
	save_requested.emit()


func _on_load_pressed() -> void:
	SfxManager.play_sfx("droid_sound")
	hide_modal()
	_open_load_dialog()
	load_requested.emit()


func _on_quit_pressed() -> void:
	if _is_dirty():
		hide_modal()
		_show_save_on_quit_dialog()
		return
	SfxManager.play_sfx("droid_sound")
	hide_modal()
	quit_requested.emit(false)


# ---------------------------------------------------------------------------
# Dirty / save-on-quit handling
# ---------------------------------------------------------------------------

func _is_dirty() -> bool:
	if dirty_override >= 0:
		return dirty_override == 1
	if not is_instance_valid(SaveGameManager):
		return false
	return SaveGameManager.is_dirty()


func _show_save_on_quit_dialog() -> void:
	if _save_on_quit_dialog == null:
		_save_on_quit_dialog = SaveOnQuitDialog.new()
		_save_on_quit_dialog.name = "SaveOnQuitDialog"
		# Mirror this modal's parent so it sits on the same canvas layer.
		var host: Node = get_parent()
		if host != null:
			host.add_child(_save_on_quit_dialog)
		else:
			add_child(_save_on_quit_dialog)
		_save_on_quit_dialog.save_and_quit_requested.connect(
				_on_save_and_quit_chosen)
		_save_on_quit_dialog.quit_without_saving_requested.connect(
				_on_quit_without_save_chosen)
		_save_on_quit_dialog.cancelled.connect(_on_save_quit_cancelled)
	var allowed: bool = true
	var reason: String = ""
	if is_instance_valid(SaveGameManager) \
			and is_instance_valid(GameManager):
		# Phase J5.5: Save & Quit is allowed whenever a checkpoint
		# exists for the current mode.  The dialog tooltip reports
		# which round/phase will be saved.
		if SaveGameManager.has_checkpoint():
			allowed = true
			var meta: SaveGameMetadata = SaveGameManager.checkpoint_metadata()
			if meta != null:
				reason = "Saves last safe point: Round %d, %s" \
						% [meta.current_round, meta.phase]
		else:
			var gate: Dictionary = SaveGameManager.can_save_now(
					GameManager.current_game_state)
			allowed = bool(gate.get("ok", false))
			reason = String(gate.get("reason", ""))
	_save_on_quit_dialog.configure(allowed, reason)
	_save_on_quit_dialog.show_modal()


func _on_save_and_quit_chosen() -> void:
	_save_then_quit = true
	_open_save_dialog()


func _on_quit_without_save_chosen() -> void:
	quit_requested.emit(false)


func _on_save_quit_cancelled() -> void:
	# Re-open the menu so the user can pick another action.
	show_modal()


## Returns the [SaveOnQuitDialog] when one has been opened.  Used by
## tests to inspect / drive the sub-modal.
func get_save_on_quit_dialog() -> SaveOnQuitDialog:
	return _save_on_quit_dialog


## Returns the [SaveGameDialog] when one has been opened.  Used by
## tests to inspect / drive the dialog.
func get_save_game_dialog() -> SaveGameDialog:
	return _save_game_dialog


## Returns the [LoadGameDialog] when one has been opened.  Used by
## tests to inspect / drive the dialog.
func get_load_game_dialog() -> LoadGameDialog:
	return _load_game_dialog


# ---------------------------------------------------------------------------
# Save dialog wiring (J4)
# ---------------------------------------------------------------------------

func _open_save_dialog() -> void:
	if _save_game_dialog == null:
		_save_game_dialog = SaveGameDialog.new()
		_save_game_dialog.name = "SaveGameDialog"
		var host: Node = get_parent()
		if host != null:
			host.add_child(_save_game_dialog)
		else:
			add_child(_save_game_dialog)
		_save_game_dialog.saved.connect(_on_save_dialog_saved)
		_save_game_dialog.cancelled.connect(_on_save_dialog_cancelled)
	_save_game_dialog.prefill_default_name()
	_save_game_dialog.show_modal()


func _on_save_dialog_saved(_file_name: String) -> void:
	if _save_then_quit:
		_save_then_quit = false
		quit_requested.emit(false)
	# Otherwise the menu stays closed; the player has saved and resumed.


func _on_save_dialog_cancelled() -> void:
	# Re-open the game menu so the player can pick another action.
	_save_then_quit = false
	show_modal()


# ---------------------------------------------------------------------------
# Load dialog wiring (J5)
# ---------------------------------------------------------------------------

func _open_load_dialog() -> void:
	if _load_game_dialog == null:
		_load_game_dialog = LoadGameDialog.new()
		_load_game_dialog.name = "LoadGameDialog"
		var host: Node = get_parent()
		if host != null:
			host.add_child(_load_game_dialog)
		else:
			add_child(_load_game_dialog)
		_load_game_dialog.loaded.connect(_on_load_dialog_loaded)
		_load_game_dialog.cancelled.connect(_on_load_dialog_cancelled)
	# In-game load (Phase J5.6): tear down the current board scene and
	# reload it.  GameBoard._ready will detect the preloaded flag set by
	# GameManager.start_new_game_from_state and rebuild from the loaded
	# state instead of bootstrapping a fresh game.
	_load_game_dialog.transition_to_board_on_load = true
	_load_game_dialog.context = "in_game"
	_load_game_dialog.show_modal()


func _on_load_dialog_loaded(_meta: SaveGameMetadata) -> void:
	# Game has been replaced; menu state is stale, so do nothing further.
	pass


func _on_load_dialog_cancelled() -> void:
	show_modal()


# ---------------------------------------------------------------------------
# Mode resolver
# ---------------------------------------------------------------------------

## Resolves the current play mode from the autoloads.
## Returns [enum Mode].
static func resolve_current_mode() -> Mode:
	if is_instance_valid(PlayMode) and PlayMode.is_network():
		if is_instance_valid(NetworkManager) and NetworkManager.is_server():
			return Mode.NETWORK_HOST
		return Mode.NETWORK_CLIENT
	return Mode.HOT_SEAT
