## Test: DebugAnnotationModal
##
## Unit tests for the annotation text input modal.
extends GutTest


func test_modal_creates_successfully() -> void:
	var modal: DebugAnnotationModal = DebugAnnotationModal.new()
	assert_not_null(modal, "Modal should be created")
	assert_true(modal is PanelContainer,
			"Modal should extend PanelContainer")
	modal.free()


func test_modal_has_standard_panel_style() -> void:
	var modal: DebugAnnotationModal = DebugAnnotationModal.new()
	var style: StyleBox = modal.get_theme_stylebox("panel")
	assert_not_null(style, "Modal should have a panel stylebox")
	modal.free()


func test_modal_has_line_edit_child() -> void:
	var modal: DebugAnnotationModal = DebugAnnotationModal.new()
	var found_line_edit: bool = _has_child_of_type(modal, "LineEdit")
	assert_true(found_line_edit,
			"Modal should contain a LineEdit somewhere in its tree")
	modal.free()


func test_modal_has_ok_button() -> void:
	var modal: DebugAnnotationModal = DebugAnnotationModal.new()
	var ok_btn: Button = _find_button_by_text(modal, "OK")
	assert_not_null(ok_btn, "Modal should contain an OK button")
	modal.free()


func test_modal_has_cancel_button() -> void:
	var modal: DebugAnnotationModal = DebugAnnotationModal.new()
	var cancel_btn: Button = _find_button_by_text(modal, "Cancel")
	assert_not_null(cancel_btn,
			"Modal should contain a Cancel button")
	modal.free()


func test_ok_button_starts_disabled() -> void:
	var modal: DebugAnnotationModal = DebugAnnotationModal.new()
	var ok_btn: Button = _find_button_by_text(modal, "OK")
	assert_true(ok_btn.disabled,
			"OK button should be disabled when text is empty")
	modal.free()


func test_modal_minimum_width() -> void:
	var modal: DebugAnnotationModal = DebugAnnotationModal.new()
	assert_eq(int(modal.custom_minimum_size.x),
			DebugAnnotationModal.MODAL_WIDTH,
			"Modal minimum width should match MODAL_WIDTH constant")
	modal.free()


func test_modal_mouse_filter_stops_propagation() -> void:
	var modal: DebugAnnotationModal = DebugAnnotationModal.new()
	assert_eq(modal.mouse_filter, Control.MOUSE_FILTER_STOP,
			"Modal should stop mouse events from passing through")
	modal.free()


func test_modal_emits_annotation_submitted() -> void:
	var modal: DebugAnnotationModal = DebugAnnotationModal.new()
	add_child_autoqfree(modal)
	watch_signals(modal)
	# Simulate typing and submitting.
	var line_edit: LineEdit = _find_line_edit(modal)
	assert_not_null(line_edit, "Should find the LineEdit")
	line_edit.text = "Test annotation"
	line_edit.text_changed.emit("Test annotation")
	var ok_btn: Button = _find_button_by_text(modal, "OK")
	ok_btn.pressed.emit()
	assert_signal_emitted(modal, "annotation_submitted",
			"Should emit annotation_submitted on OK")


func test_modal_emits_cancelled() -> void:
	var modal: DebugAnnotationModal = DebugAnnotationModal.new()
	add_child_autoqfree(modal)
	watch_signals(modal)
	var cancel_btn: Button = _find_button_by_text(modal, "Cancel")
	cancel_btn.pressed.emit()
	assert_signal_emitted(modal, "cancelled",
			"Should emit cancelled on Cancel press")


func test_empty_text_does_not_submit() -> void:
	var modal: DebugAnnotationModal = DebugAnnotationModal.new()
	add_child_autoqfree(modal)
	watch_signals(modal)
	var ok_btn: Button = _find_button_by_text(modal, "OK")
	# OK is disabled with empty text — pressing it should do nothing.
	assert_true(ok_btn.disabled,
			"OK should be disabled with empty text")
	assert_signal_not_emitted(modal, "annotation_submitted",
			"Should not emit with empty text")


# --- Helpers ---

## Recursively searches for a child of the given class name.
func _has_child_of_type(node: Node, type_name: String) -> bool:
	for child: Node in node.get_children():
		if child.get_class() == type_name:
			return true
		if _has_child_of_type(child, type_name):
			return true
	return false


## Finds a Button with matching text anywhere in the tree.
func _find_button_by_text(node: Node, text: String) -> Button:
	for child: Node in node.get_children():
		if child is Button and (child as Button).text == text:
			return child as Button
		var result: Button = _find_button_by_text(child, text)
		if result:
			return result
	return null


## Finds the first LineEdit in the tree.
func _find_line_edit(node: Node) -> LineEdit:
	for child: Node in node.get_children():
		if child is LineEdit:
			return child as LineEdit
		var result: LineEdit = _find_line_edit(child)
		if result:
			return result
	return null
