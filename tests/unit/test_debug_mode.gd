## Test: DebugMode
##
## Unit tests for DebugMode autoload — toggle, selection, and signal emission.
##
## Requirements: DBG-001, DBG-002, DBG-010
extends GutTest


# ---------------------------------------------------------------------------
# Toggle
# ---------------------------------------------------------------------------

func test_debug_mode_starts_disabled() -> void:
	# Assert
	assert_false(DebugMode.enabled,
			"Debug mode should be disabled by default")


func test_toggle_debug_mode_on() -> void:
	# Arrange
	DebugMode.enabled = false
	# Act
	DebugMode.enabled = true
	# Assert
	assert_true(DebugMode.enabled,
			"Debug mode should be enabled after setting to true")
	# Cleanup
	DebugMode.enabled = false


func test_toggle_emits_signal() -> void:
	# Arrange
	DebugMode.enabled = false
	watch_signals(DebugMode)
	# Act
	DebugMode.enabled = true
	# Assert
	assert_signal_emitted(DebugMode, "debug_mode_changed",
			"Toggling should emit debug_mode_changed signal")
	# Cleanup
	DebugMode.enabled = false


func test_setting_same_value_does_not_emit() -> void:
	# Arrange
	DebugMode.enabled = false
	watch_signals(DebugMode)
	# Act — set to same value.
	DebugMode.enabled = false
	# Assert
	assert_signal_not_emitted(DebugMode, "debug_mode_changed",
			"Setting same value should not emit signal")


# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

func test_select_token_when_disabled_does_nothing() -> void:
	# Arrange
	DebugMode.enabled = false
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	# Act
	DebugMode.select_token(node)
	# Assert
	assert_null(DebugMode.selected_token,
			"select_token should be ignored when debug mode is off")


func test_select_token_when_enabled() -> void:
	# Arrange
	DebugMode.enabled = true
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	# Act
	DebugMode.select_token(node)
	# Assert
	assert_eq(DebugMode.selected_token, node,
			"selected_token should be the node that was selected")
	# Cleanup
	DebugMode.deselect_token()
	DebugMode.enabled = false


func test_select_same_token_deselects() -> void:
	# Arrange
	DebugMode.enabled = true
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	DebugMode.select_token(node)
	# Act — select same token again.
	DebugMode.select_token(node)
	# Assert
	assert_null(DebugMode.selected_token,
			"Selecting the same token twice should deselect it")
	# Cleanup
	DebugMode.enabled = false


func test_deselect_clears_selection() -> void:
	# Arrange
	DebugMode.enabled = true
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	DebugMode.select_token(node)
	# Act
	DebugMode.deselect_token()
	# Assert
	assert_null(DebugMode.selected_token,
			"selected_token should be null after deselect")
	# Cleanup
	DebugMode.enabled = false


# ---------------------------------------------------------------------------
# has_selection()
# ---------------------------------------------------------------------------

func test_has_selection_false_when_disabled() -> void:
	# Arrange
	DebugMode.enabled = false
	# Assert
	assert_false(DebugMode.has_selection(),
			"has_selection should be false when debug mode is off")


func test_has_selection_false_when_no_token_selected() -> void:
	# Arrange
	DebugMode.enabled = true
	DebugMode.deselect_token()
	# Assert
	assert_false(DebugMode.has_selection(),
			"has_selection should be false when no token is selected")
	# Cleanup
	DebugMode.enabled = false


func test_has_selection_true_when_token_selected() -> void:
	# Arrange
	DebugMode.enabled = true
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	DebugMode.select_token(node)
	# Assert
	assert_true(DebugMode.has_selection(),
			"has_selection should be true when a token is selected")
	# Cleanup
	DebugMode.deselect_token()
	DebugMode.enabled = false
