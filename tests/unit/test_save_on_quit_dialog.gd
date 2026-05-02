## Test: SaveOnQuitDialog (Phase J3)
extends GutTest


var _dlg: SaveOnQuitDialog = null


func before_each() -> void:
	_dlg = SaveOnQuitDialog.new()
	add_child_autofree(_dlg)


func _find_button(label_text: String) -> Button:
	for child: Node in _dlg.find_children("*", "Button", true, false):
		var btn: Button = child as Button
		if btn != null and btn.text == label_text:
			return btn
	return null


func test_save_and_quit_button_disabled_when_save_not_allowed() -> void:
	_dlg.configure(false, "Cannot save mid-attack.")
	var btn: Button = _find_button("Save && Quit")
	assert_not_null(btn, "Save & Quit button should exist")
	assert_true(btn.disabled, "Should be disabled when save not allowed")
	assert_eq(btn.tooltip_text, "Cannot save mid-attack.",
			"Tooltip should expose the reason")


func test_save_and_quit_button_enabled_when_save_allowed() -> void:
	_dlg.configure(true, "")
	var btn: Button = _find_button("Save && Quit")
	assert_false(btn.disabled, "Should be enabled when save allowed")


func test_save_and_quit_button_emits_signal() -> void:
	_dlg.configure(true, "")
	watch_signals(_dlg)
	_find_button("Save && Quit").pressed.emit()
	assert_signal_emitted(_dlg, "save_and_quit_requested",
			"Save & Quit press should emit save_and_quit_requested")


func test_quit_without_saving_emits_signal() -> void:
	_dlg.configure(true, "")
	watch_signals(_dlg)
	_find_button("Quit Without Saving").pressed.emit()
	assert_signal_emitted(_dlg, "quit_without_saving_requested",
			"Quit Without Saving press should emit "
			+"quit_without_saving_requested")


func test_cancel_emits_signal_and_hides() -> void:
	_dlg.configure(true, "")
	_dlg.visible = true
	watch_signals(_dlg)
	_find_button("Cancel").pressed.emit()
	assert_signal_emitted(_dlg, "cancelled",
			"Cancel button should emit cancelled")
	assert_false(_dlg.visible, "Cancel should hide the dialog")
