## Quit Confirmation Modal
##
## Displays a centred confirmation dialog asking the player whether to
## quit the current game and return to the main menu.
## Shown when the player presses Escape while no other modal or tool
## is consuming the key.
##
## Emits [signal confirmed] when Yes is pressed and [signal cancelled]
## when No is pressed or Escape is pressed again.
##
## Requirements: UI-034.
class_name QuitConfirmationModal
extends PanelContainer

## Emitted when the player confirms they want to quit.
signal confirmed
## Emitted when the player cancels (No button or Escape).
signal cancelled


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


## Builds the modal UI: question label + Yes / No buttons.
func _build_ui() -> void:
	_apply_panel_style()
	var margin: MarginContainer = _build_margin_layout()
	add_child(margin)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	vbox.add_child(_build_question_label())
	vbox.add_child(_build_button_row())


## Applies the standard modal panel style (ui_styling.md §1).
func _apply_panel_style() -> void:
	add_theme_stylebox_override("panel",
			UIStyleHelper.create_modal_panel_style(0.0))


## Creates the inner MarginContainer.
func _build_margin_layout() -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	return margin


## Creates the question text label.
func _build_question_label() -> Label:
	var label: Label = Label.new()
	label.text = "Quit game and exit to main menu?"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## Creates the Yes / No button row.
func _build_button_row() -> HBoxContainer:
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn_yes: Button = Button.new()
	btn_yes.text = "Yes"
	btn_yes.custom_minimum_size = Vector2(100, 36)
	btn_yes.pressed.connect(_on_yes_pressed)
	btn_row.add_child(btn_yes)
	var btn_no: Button = Button.new()
	btn_no.text = "No"
	btn_no.custom_minimum_size = Vector2(100, 36)
	btn_no.pressed.connect(_on_no_pressed)
	btn_row.add_child(btn_no)
	return btn_row


## Shows the modal centred on viewport.
func show_modal() -> void:
	visible = true
	# Centre after becoming visible so size is computed.
	await get_tree().process_frame
	var vp_size: Vector2 = get_viewport_rect().size
	position = (vp_size - size) * 0.5


## Hides the modal.
func hide_modal() -> void:
	visible = false


## Escape key dismisses (same as No). UI-034.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_on_no_pressed()
			get_viewport().set_input_as_handled()


func _on_yes_pressed() -> void:
	SfxManager.play_sfx("droid_sound")
	hide_modal()
	confirmed.emit()


func _on_no_pressed() -> void:
	SfxManager.play_sfx("skip_beep")
	hide_modal()
	cancelled.emit()
