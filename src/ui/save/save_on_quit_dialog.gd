## Save On Quit Dialog (Phase J3 / Q4)
##
## Three-button modal shown when the player presses Quit while the game
## has advanced past the last save.  Choices:
##   - Save & Quit          → emits [signal save_and_quit_requested]
##   - Quit Without Saving  → emits [signal quit_without_saving_requested]
##   - Cancel               → emits [signal cancelled]
##
## The "Save & Quit" button is disabled when [code]can_save_now()[/code]
## returns false.  In that case the dialog shows the supplied tooltip
## reason so the user understands why save is not currently possible.
class_name SaveOnQuitDialog
extends PanelContainer


## Emitted when the player chooses to save before quitting.
signal save_and_quit_requested

## Emitted when the player chooses to quit and discard unsaved progress.
signal quit_without_saving_requested

## Emitted when the player cancels (Cancel button or Escape).
signal cancelled


## Whether saving is currently possible.  When false, the Save & Quit
## button is disabled and shows [member save_disabled_reason] as a tooltip.
var save_allowed: bool = true

## Reason text shown on the disabled Save & Quit button (tooltip).
var save_disabled_reason: String = ""

var _btn_save_and_quit: Button = null
var _btn_quit_without_saving: Button = null
var _btn_cancel: Button = null


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


## Configures the Save & Quit button before showing the dialog.
## [param allowed] — whether saving is currently possible (Phase J5.5:
## [SaveGameManager.has_checkpoint] for the active mode).
## [param reason] — when [param allowed] is false, the human-readable
## block reason; when [param allowed] is true, an informational
## tooltip such as "Saves last safe point: Round N, <Phase>".
func configure(allowed: bool, reason: String) -> void:
	save_allowed = allowed
	save_disabled_reason = reason
	if _btn_save_and_quit:
		_btn_save_and_quit.disabled = not allowed
		_btn_save_and_quit.tooltip_text = reason


## Shows the dialog centred on the viewport.
func show_modal() -> void:
	visible = true
	await get_tree().process_frame
	var vp_size: Vector2 = get_viewport_rect().size
	position = (vp_size - size) * 0.5


## Hides the dialog.
func hide_modal() -> void:
	visible = false


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
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	vbox.add_child(_build_message_label())
	vbox.add_child(_build_button_row())


func _build_message_label() -> Label:
	var label: Label = Label.new()
	label.text = "You have unsaved progress.\nSave the game before quitting?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _build_button_row() -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_btn_save_and_quit = _make_button("Save && Quit")
	_btn_save_and_quit.pressed.connect(_on_save_and_quit_pressed)
	col.add_child(_btn_save_and_quit)
	_btn_quit_without_saving = _make_button("Quit Without Saving")
	_btn_quit_without_saving.pressed.connect(_on_quit_without_saving_pressed)
	col.add_child(_btn_quit_without_saving)
	_btn_cancel = _make_button("Cancel")
	_btn_cancel.pressed.connect(_on_cancel_pressed)
	col.add_child(_btn_cancel)
	return col


func _make_button(label_text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(200, 44)
	return btn


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

## Escape key dismisses (same as Cancel).
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()


func _on_save_and_quit_pressed() -> void:
	if not save_allowed:
		return
	SfxManager.play_sfx("droid_sound")
	hide_modal()
	save_and_quit_requested.emit()


func _on_quit_without_saving_pressed() -> void:
	SfxManager.play_sfx("droid_sound")
	hide_modal()
	quit_without_saving_requested.emit()


func _on_cancel_pressed() -> void:
	SfxManager.play_sfx("skip_beep")
	hide_modal()
	cancelled.emit()
