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


## Hides Save / Load for network clients; stubs them disabled in J3.
## Slices J4 / J5 will enable them and wire the dialogs.
func _apply_mode_visibility() -> void:
	if _btn_save == null or _btn_load == null:
		return
	var save_load_visible: bool = mode != Mode.NETWORK_CLIENT
	_btn_save.visible = save_load_visible
	_btn_load.visible = save_load_visible
	# Stub-disabled in J3 \u2014 dialogs come in J4/J5.
	_btn_save.disabled = true
	_btn_save.tooltip_text = "Save dialog wires up in J4."
	_btn_load.disabled = true
	_btn_load.tooltip_text = "Load dialog wires up in J5."


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
	save_requested.emit()


func _on_load_pressed() -> void:
	SfxManager.play_sfx("droid_sound")
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
		var gate: Dictionary = SaveGameManager.can_save_now(
				GameManager.current_game_state)
		allowed = bool(gate.get("ok", false))
		reason = String(gate.get("reason", ""))
	_save_on_quit_dialog.configure(allowed, reason)
	_save_on_quit_dialog.show_modal()


func _on_save_and_quit_chosen() -> void:
	quit_requested.emit(true)


func _on_quit_without_save_chosen() -> void:
	quit_requested.emit(false)


func _on_save_quit_cancelled() -> void:
	# Re-open the menu so the user can pick another action.
	show_modal()


## Returns the [SaveOnQuitDialog] when one has been opened.  Used by
## tests to inspect / drive the sub-modal.
func get_save_on_quit_dialog() -> SaveOnQuitDialog:
	return _save_on_quit_dialog


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
