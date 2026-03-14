## Test: DebugHelpPanel
##
## Unit tests for the debug-mode help panel UI widget.
## Verifies that the panel constructs its labels and is not empty.
##
## Requirements: DBG-002
extends GutTest


var _panel: DebugHelpPanel = null


func before_each() -> void:
	_panel = DebugHelpPanel.new()
	add_child_autofree(_panel)
	await get_tree().process_frame


func after_each() -> void:
	_panel = null


func test_panel_creates_children() -> void:
	# Assert — the panel should have at least one child (the VBoxContainer).
	assert_true(_panel.get_child_count() > 0,
			"DebugHelpPanel should have at least one child after _ready")


func test_panel_has_vbox_container() -> void:
	# Assert — first child should be a VBoxContainer.
	var first_child: Node = _panel.get_child(0)
	assert_true(first_child is VBoxContainer,
			"First child should be a VBoxContainer")


func test_panel_vbox_has_multiple_entries() -> void:
	# Assert — VBox should have header + separator + lines.
	var vbox: VBoxContainer = _panel.get_child(0) as VBoxContainer
	assert_true(vbox.get_child_count() >= 8,
			"VBox should have at least 8 children (header, separator, 6+ lines)")


func test_panel_starts_with_debug_mode_header() -> void:
	# Assert — first label inside VBox should say "DEBUG MODE".
	var vbox: VBoxContainer = _panel.get_child(0) as VBoxContainer
	var header: Label = vbox.get_child(0) as Label
	assert_eq(header.text, "DEBUG MODE",
			"First label should be the DEBUG MODE header")


func test_panel_has_correct_position() -> void:
	# Assert — panel position should match design constants.
	assert_almost_eq(_panel.position.x, 10.0, 1.0,
			"Panel X should be at left margin")


func test_panel_minimum_width() -> void:
	# Assert — custom_minimum_size should be set.
	assert_eq(_panel.custom_minimum_size.x, float(DebugHelpPanel.PANEL_WIDTH_PX),
			"Panel should have the configured minimum width")
