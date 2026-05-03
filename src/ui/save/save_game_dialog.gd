## Save Game Dialog (Phase J4)
##
## Modal shown when the player chooses Save Game from the in-game menu
## (hot-seat or network host only).  Provides a name field with the
## [SaveGameManager.default_save_name] template, validates the input,
## and prompts before overwriting an existing save.
##
## Validation rules:
## - Non-empty (after trimming whitespace).
## - No path separators (`/` or `\`).
## - No leading dot (avoid hidden files like `.signing_key`).
## - Maximum [constant MAX_NAME_LENGTH] characters.
##
## On a valid save attempt the dialog calls [SaveGameManager.save_game]
## and emits [signal saved].  On cancel it emits [signal cancelled].
class_name SaveGameDialog
extends PanelContainer


## Maximum length of a save name, in characters.
const MAX_NAME_LENGTH: int = 64

## Characters that are not allowed anywhere in a save name.
const FORBIDDEN_CHARACTERS: PackedStringArray = ["/", "\\", ":"]


## Emitted when the save completes successfully.  [code]file_name[/code]
## is the trimmed save name (without extension).
signal saved(file_name: String)

## Emitted when the player cancels (Cancel button or Escape).
signal cancelled


var _name_edit: LineEdit = null
var _save_button: Button = null
var _cancel_button: Button = null
var _error_label: Label = null
var _title_label: Label = null
var _confirm_overwrite: ConfirmationDialog = null


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


## Pre-fills the name field with [SaveGameManager.default_save_name].
## Call before [method show_modal].
func prefill_default_name() -> void:
	if not is_instance_valid(SaveGameManager):
		return
	if not is_instance_valid(GameManager):
		return
	var name: String = SaveGameManager.default_save_name(
			GameManager.current_game_state)
	if _name_edit != null:
		_name_edit.text = name
	_clear_error()


## Shows the dialog centred on the viewport and focuses the name field.
func show_modal() -> void:
	_refresh_title()
	visible = true
	await get_tree().process_frame
	var vp_size: Vector2 = get_viewport_rect().size
	position = (vp_size - size) * 0.5
	if _name_edit != null:
		_name_edit.grab_focus()
		_name_edit.select_all()


## Hides the dialog.
func hide_modal() -> void:
	visible = false


func _refresh_title() -> void:
	if _title_label == null:
		return
	var suffix: String = ""
	if is_instance_valid(SaveGameManager) \
			and SaveGameManager.has_checkpoint():
		var meta: SaveGameMetadata = SaveGameManager.checkpoint_metadata()
		if meta != null:
			suffix = " (last safe point: Round %d, %s)" \
					% [meta.current_round, meta.phase]
	_title_label.text = "Save Game" + suffix


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	add_theme_stylebox_override("panel",
			UIStyleHelper.create_modal_panel_style(0.0))
	custom_minimum_size = Vector2(420, 0)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	vbox.add_child(_build_title_label())
	vbox.add_child(_build_name_label())
	_name_edit = LineEdit.new()
	_name_edit.max_length = MAX_NAME_LENGTH
	_name_edit.placeholder_text = "Save name"
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(_on_name_submitted)
	vbox.add_child(_name_edit)
	_error_label = Label.new()
	_error_label.add_theme_color_override(
			"font_color", Color(1.0, 0.6, 0.55))
	_error_label.add_theme_font_size_override("font_size", 13)
	_error_label.visible = false
	vbox.add_child(_error_label)
	vbox.add_child(_build_button_row())
	_confirm_overwrite = ConfirmationDialog.new()
	_confirm_overwrite.dialog_text = ""
	_confirm_overwrite.title = "Overwrite save?"
	_confirm_overwrite.confirmed.connect(_on_overwrite_confirmed)
	add_child(_confirm_overwrite)


func _build_title_label() -> Label:
	var label: Label = Label.new()
	# Phase J5.5: title reports the round/phase that will actually be
	# saved (the most recent safe-point checkpoint), not the live
	# state.  Pressing Save mid-flow always captures the last safe
	# point.
	var suffix: String = ""
	if is_instance_valid(SaveGameManager) \
			and SaveGameManager.has_checkpoint():
		var meta: SaveGameMetadata = SaveGameManager.checkpoint_metadata()
		if meta != null:
			suffix = " (last safe point: Round %d, %s)" \
					% [meta.current_round, meta.phase]
	label.text = "Save Game" + suffix
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label = label
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	return label


func _build_name_label() -> Label:
	var label: Label = Label.new()
	label.text = "Name"
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	return label


func _build_button_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	_cancel_button = _make_button("Cancel")
	_cancel_button.pressed.connect(_on_cancel_pressed)
	row.add_child(_cancel_button)
	_save_button = _make_button("Save")
	_save_button.pressed.connect(_on_save_pressed)
	row.add_child(_save_button)
	return row


func _make_button(label_text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(120, 36)
	return btn


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

## Validates a candidate save name.
## Returns [code]{"ok": bool, "reason": String}[/code].
## Static so it can be exercised by unit tests without a scene tree.
static func validate_name(raw: String) -> Dictionary:
	var trimmed: String = raw.strip_edges()
	if trimmed.is_empty():
		return {"ok": false, "reason": "Name cannot be empty."}
	if trimmed.length() > MAX_NAME_LENGTH:
		return {
			"ok": false,
			"reason": "Name is too long (max %d)." % MAX_NAME_LENGTH,
		}
	if trimmed.begins_with("."):
		return {"ok": false, "reason": "Name cannot start with '.'."}
	for ch: String in FORBIDDEN_CHARACTERS:
		if trimmed.contains(ch):
			return {
				"ok": false,
				"reason": "Name cannot contain '%s'." % ch,
			}
	return {"ok": true, "reason": ""}


# ---------------------------------------------------------------------------
# Input handlers
# ---------------------------------------------------------------------------

## Escape closes the dialog (same as Cancel).
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()


func _on_name_changed(_new_text: String) -> void:
	_clear_error()


func _on_name_submitted(_text: String) -> void:
	_on_save_pressed()


func _on_cancel_pressed() -> void:
	SfxManager.play_sfx("skip_beep")
	hide_modal()
	cancelled.emit()


func _on_save_pressed() -> void:
	var raw: String = "" if _name_edit == null else _name_edit.text
	var check: Dictionary = validate_name(raw)
	if not bool(check.get("ok", false)):
		_show_error(String(check.get("reason", "Invalid name.")))
		return
	var name: String = raw.strip_edges()
	if is_instance_valid(SaveGameManager) \
			and SaveGameManager.save_exists(name):
		_confirm_overwrite.dialog_text = (
				"A save named \"%s\" already exists.\n"
				+"Overwrite it?") % name
		_confirm_overwrite.popup_centered()
		return
	_perform_save(name)


func _on_overwrite_confirmed() -> void:
	var raw: String = "" if _name_edit == null else _name_edit.text
	_perform_save(raw.strip_edges())


func _perform_save(name: String) -> void:
	if not is_instance_valid(SaveGameManager) \
			or not is_instance_valid(GameManager):
		_show_error("Save subsystem unavailable.")
		return
	var ok: bool = SaveGameManager.save_game(
			GameManager.current_game_state, name)
	if not ok:
		_show_error("Save failed. See log for details.")
		return
	# Phase J6: in network mode, the host notifies the client so they
	# see a confirmation toast.
	if PlayMode != null and PlayMode.is_network() \
			and is_instance_valid(NetworkManager) \
			and NetworkManager.is_server():
		NetworkManager.broadcast_save_notification(name)
	SfxManager.play_sfx("droid_sound")
	hide_modal()
	saved.emit(name)


# ---------------------------------------------------------------------------
# Error display
# ---------------------------------------------------------------------------

func _show_error(message: String) -> void:
	if _error_label == null:
		return
	_error_label.text = message
	_error_label.visible = true


func _clear_error() -> void:
	if _error_label == null:
		return
	_error_label.text = ""
	_error_label.visible = false
