## DebugAnnotationModal
##
## A small modal dialog for entering a debug annotation.
## Shows a text input field with OK / Cancel buttons.
## Emits [signal annotation_submitted] when the user confirms.
##
## The modal centres itself on screen, grabs keyboard focus, and
## can be dismissed via Cancel button or Escape key.
## After submission or cancellation the modal frees itself.
##
## Requirements: DBG-060 (debug annotation feature).
class_name DebugAnnotationModal
extends PanelContainer


## Emitted when the user confirms an annotation.
signal annotation_submitted(text: String)

## Emitted when the modal is cancelled (Escape or Cancel button).
signal cancelled()

## Fixed width for the modal.
const MODAL_WIDTH: int = 420

## The text input field.
var _line_edit: LineEdit = null

## The OK button (disabled until text is entered).
var _ok_button: Button = null


func _init() -> void:
	_apply_style()
	_build_ui()
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_centre_on_screen()
	_line_edit.grab_focus()


## Handles Escape to cancel.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_cancel()


## Applies the standard modal panel style.
func _apply_style() -> void:
	add_theme_stylebox_override("panel",
			UIStyleHelper.create_modal_panel_style())


## Builds the modal layout: title, input field, button row.
func _build_ui() -> void:
	custom_minimum_size = Vector2(MODAL_WIDTH, 0)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	var title: Label = UIStyleHelper.create_title_label(
			"Add Debug Annotation", UIStyleHelper.GOLD_TITLE)
	vbox.add_child(title)

	_line_edit = LineEdit.new()
	_line_edit.placeholder_text = "Describe the current state or issue..."
	_line_edit.custom_minimum_size = Vector2(0, 36)
	_line_edit.text_submitted.connect(_on_text_submitted)
	_line_edit.text_changed.connect(_on_text_changed)
	vbox.add_child(_line_edit)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 12)
	vbox.add_child(button_row)

	_ok_button = Button.new()
	_ok_button.text = "OK"
	_ok_button.custom_minimum_size = Vector2(100, 36)
	_ok_button.disabled = true
	_ok_button.pressed.connect(_on_ok_pressed)
	button_row.add_child(_ok_button)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 36)
	cancel_btn.pressed.connect(_cancel)
	button_row.add_child(cancel_btn)

	var hint: Label = UIStyleHelper.create_dismiss_hint(
			"Press Enter to confirm, Escape to cancel")
	vbox.add_child(hint)


## Centres the modal on screen.
func _centre_on_screen() -> void:
	await get_tree().process_frame
	var vp_size: Vector2 = get_viewport_rect().size
	position = (vp_size - size) * 0.5


## Called when the user types in the input field.
func _on_text_changed(new_text: String) -> void:
	_ok_button.disabled = new_text.strip_edges().is_empty()


## Called when the user presses Enter in the input field.
func _on_text_submitted(_new_text: String) -> void:
	if not _ok_button.disabled:
		_submit()


## Called when the OK button is pressed.
func _on_ok_pressed() -> void:
	_submit()


## Emits the annotation and removes the modal.
func _submit() -> void:
	var text: String = _line_edit.text.strip_edges()
	if text.is_empty():
		return
	annotation_submitted.emit(text)
	queue_free()


## Cancels and removes the modal.
func _cancel() -> void:
	cancelled.emit()
	queue_free()
