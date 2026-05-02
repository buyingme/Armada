## Test: SaveGameDialog (Phase J4)
##
## Unit tests for the save-name validation and dialog state.  The dialog
## itself is exercised in MT-J.4 (manual test) for the full file-write
## round-trip; we only verify pure-logic helpers and basic UI state here.
extends GutTest


const Dialog: GDScript = preload("res://src/ui/save/save_game_dialog.gd")


# ---------------------------------------------------------------------------
# validate_name
# ---------------------------------------------------------------------------

func test_validate_name_accepts_simple_name() -> void:
	var result: Dictionary = Dialog.validate_name("my_save")
	assert_true(result["ok"], "Plain alphanumeric name should be valid")


func test_validate_name_trims_whitespace_then_accepts() -> void:
	var result: Dictionary = Dialog.validate_name("  hello  ")
	assert_true(result["ok"], "Surrounding whitespace should be trimmed")


func test_validate_name_rejects_empty() -> void:
	var result: Dictionary = Dialog.validate_name("")
	assert_false(result["ok"], "Empty name should be rejected")
	assert_string_contains(String(result["reason"]), "empty",
			"Reason should mention 'empty'")


func test_validate_name_rejects_whitespace_only() -> void:
	var result: Dictionary = Dialog.validate_name("   ")
	assert_false(result["ok"],
			"Whitespace-only name should be rejected after trim")


func test_validate_name_rejects_forward_slash() -> void:
	var result: Dictionary = Dialog.validate_name("foo/bar")
	assert_false(result["ok"], "Forward slash should be rejected")


func test_validate_name_rejects_backslash() -> void:
	var result: Dictionary = Dialog.validate_name("foo\\bar")
	assert_false(result["ok"], "Backslash should be rejected")


func test_validate_name_rejects_colon() -> void:
	var result: Dictionary = Dialog.validate_name("foo:bar")
	assert_false(result["ok"], "Colon should be rejected")


func test_validate_name_rejects_leading_dot() -> void:
	var result: Dictionary = Dialog.validate_name(".hidden")
	assert_false(result["ok"], "Leading dot should be rejected")


func test_validate_name_rejects_too_long() -> void:
	var long_name: String = ""
	for i: int in range(Dialog.MAX_NAME_LENGTH + 1):
		long_name += "a"
	var result: Dictionary = Dialog.validate_name(long_name)
	assert_false(result["ok"],
			"Name longer than MAX_NAME_LENGTH should be rejected")


func test_validate_name_accepts_max_length() -> void:
	var max_name: String = ""
	for i: int in range(Dialog.MAX_NAME_LENGTH):
		max_name += "a"
	var result: Dictionary = Dialog.validate_name(max_name)
	assert_true(result["ok"],
			"Name at exactly MAX_NAME_LENGTH should be accepted")


# ---------------------------------------------------------------------------
# Cancel signal
# ---------------------------------------------------------------------------

func test_cancel_button_emits_cancelled_and_hides() -> void:
	var dlg: SaveGameDialog = SaveGameDialog.new()
	add_child_autofree(dlg)
	dlg.visible = true
	watch_signals(dlg)
	for child: Node in dlg.find_children("*", "Button", true, false):
		var btn: Button = child as Button
		if btn != null and btn.text == "Cancel":
			btn.pressed.emit()
			break
	assert_signal_emitted(dlg, "cancelled",
			"Cancel button should emit cancelled")
	assert_false(dlg.visible, "Cancel should hide the dialog")
