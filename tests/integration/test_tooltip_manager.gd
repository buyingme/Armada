## Test: Tooltip Manager
##
## Integration tests for the TooltipManager autoload singleton.
## Tests the hover FSM, programmatic show/hide, toggle button, and
## registration lifecycle.
##
## Requirements: TT-061–063.
extends GutTest


# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

## Creates a minimal Control, adds it to the tree, and returns it.
func _make_control() -> Control:
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(100, 50)
	ctrl.size = Vector2(100, 50)
	add_child_autofree(ctrl)
	return ctrl


## Short-hand to read the tooltip manager's FSM state.
func _state() -> int:
	return TooltipManager._state


## Short-hand to check panel visibility.
func _visible() -> bool:
	return TooltipManager._panel.visible


# ------------------------------------------------------------------
# Setup / Teardown
# ------------------------------------------------------------------

func before_each() -> void:
	TooltipManager.tooltips_enabled = true
	TooltipManager.hide_tooltip()
	TooltipManager._registrations.clear()


func after_each() -> void:
	TooltipManager.hide_tooltip()
	TooltipManager._registrations.clear()


# ------------------------------------------------------------------
# Hover delay (TT-002)
# ------------------------------------------------------------------

## Entering a registered region starts the delay timer (WAITING state).
func test_register_and_enter_transitions_to_waiting() -> void:
	# Arrange
	var ctrl: Control = _make_control()
	TooltipManager.register(ctrl, func() -> String: return "Hello")

	# Act — simulate mouse_entered signal
	ctrl.mouse_entered.emit()

	# Assert
	assert_eq(_state(), TooltipManager.State.WAITING,
			"State should be WAITING after entering a registered region")


## After the delay timer fires, the tooltip becomes SHOWING.
func test_delay_timeout_transitions_to_showing() -> void:
	# Arrange
	var ctrl: Control = _make_control()
	TooltipManager.register(ctrl, func() -> String: return "Test text")
	ctrl.mouse_entered.emit()

	# Act — manually fire the delay callback
	TooltipManager._on_delay_timeout()
	await get_tree().process_frame

	# Assert
	assert_eq(_state(), TooltipManager.State.SHOWING,
			"State should be SHOWING after delay timeout")
	assert_true(_visible(), "Tooltip panel should be visible after delay")


# ------------------------------------------------------------------
# Hover exit (TT-003)
# ------------------------------------------------------------------

## Exiting the region hides the tooltip and returns to IDLE.
func test_exit_region_hides_tooltip_and_returns_to_idle() -> void:
	# Arrange — get to SHOWING state
	var ctrl: Control = _make_control()
	TooltipManager.register(ctrl, func() -> String: return "Help")
	ctrl.mouse_entered.emit()
	TooltipManager._on_delay_timeout()
	await get_tree().process_frame

	# Act
	ctrl.mouse_exited.emit()

	# Assert
	assert_eq(_state(), TooltipManager.State.IDLE,
			"State should be IDLE after exiting region")
	assert_false(_visible(),
			"Tooltip panel should be hidden after exiting region")


# ------------------------------------------------------------------
# Empty callback suppresses tooltip (TT-013)
# ------------------------------------------------------------------

## Callback returning "" prevents the tooltip from appearing.
func test_empty_callback_suppresses_tooltip() -> void:
	# Arrange
	var ctrl: Control = _make_control()
	TooltipManager.register(ctrl, func() -> String: return "")
	ctrl.mouse_entered.emit()

	# Act
	TooltipManager._on_delay_timeout()
	await get_tree().process_frame

	# Assert
	assert_eq(_state(), TooltipManager.State.IDLE,
			"State should be IDLE when callback returns empty string")
	assert_false(_visible(),
			"Tooltip should not appear for empty callback result")


# ------------------------------------------------------------------
# Programmatic show_text (TT-005, TT-007)
# ------------------------------------------------------------------

## show_text with force=true enters FORCED state, bypassing toggle.
func test_show_text_forced_enters_forced_state() -> void:
	# Arrange
	TooltipManager.tooltips_enabled = false # toggle off

	# Act
	TooltipManager.show_text("Discard a token", Vector2.INF, 0.0, true)
	await get_tree().process_frame

	# Assert
	assert_eq(_state(), TooltipManager.State.FORCED,
			"show_text(force=true) should enter FORCED state")
	assert_true(_visible(),
			"Tooltip should be visible in FORCED state even with toggle off")


# ------------------------------------------------------------------
# Auto-hide with duration (TT-006)
# ------------------------------------------------------------------

## show_text with duration > 0 starts the auto-hide timer.
func test_show_text_with_duration_starts_auto_hide() -> void:
	# Arrange + Act
	TooltipManager.show_text("Duplicate discarded", Vector2.INF, 2.0)

	# Assert
	assert_eq(_state(), TooltipManager.State.FORCED,
			"State should be FORCED after show_text with duration")
	assert_false(TooltipManager._auto_hide_timer.is_stopped(),
			"Auto-hide timer should be running")

	# Simulate timeout
	TooltipManager._on_auto_hide_timeout()
	assert_eq(_state(), TooltipManager.State.IDLE,
			"State should be IDLE after auto-hide fires")
	assert_false(_visible(),
			"Tooltip should be hidden after auto-hide fires")


# ------------------------------------------------------------------
# hide_tooltip (TT-007)
# ------------------------------------------------------------------

## hide_tooltip returns from FORCED to IDLE.
func test_hide_tooltip_clears_forced_state() -> void:
	# Arrange
	TooltipManager.show_text("Some help")
	await get_tree().process_frame

	# Act
	TooltipManager.hide_tooltip()

	# Assert
	assert_eq(_state(), TooltipManager.State.IDLE,
			"State should be IDLE after hide_tooltip")
	assert_false(_visible(),
			"Tooltip should be hidden after hide_tooltip")


# ------------------------------------------------------------------
# Deregister (TT-052)
# ------------------------------------------------------------------

## Deregistering a hovered control hides the tooltip.
func test_deregister_hovered_control_hides_tooltip() -> void:
	# Arrange
	var ctrl: Control = _make_control()
	TooltipManager.register(ctrl, func() -> String: return "Info")
	ctrl.mouse_entered.emit()
	TooltipManager._on_delay_timeout()
	await get_tree().process_frame
	assert_true(_visible(), "Pre-condition: tooltip should be visible")

	# Act
	TooltipManager.deregister(ctrl)

	# Assert
	assert_false(_visible(),
			"Tooltip should hide when hovered control is deregistered")
	assert_false(TooltipManager._registrations.has(ctrl),
			"Control should be removed from registration table")


# ------------------------------------------------------------------
# Freed control (TT-052 auto-deregister)
# ------------------------------------------------------------------

## Freeing a registered control auto-deregisters it via tree_exiting.
func test_freed_control_auto_deregisters() -> void:
	# Arrange
	var ctrl: Control = Control.new()
	ctrl.custom_minimum_size = Vector2(100, 50)
	ctrl.size = Vector2(100, 50)
	add_child(ctrl)
	TooltipManager.register(ctrl, func() -> String: return "Gone soon")
	assert_true(TooltipManager._registrations.has(ctrl),
			"Pre-condition: control should be registered")

	# Act
	ctrl.queue_free()
	await get_tree().process_frame

	# Assert
	assert_false(TooltipManager._registrations.has(ctrl),
			"Freed control should be auto-deregistered")


# ------------------------------------------------------------------
# Region change resets delay (TT-004)
# ------------------------------------------------------------------

## Switching from one region to another resets the delay timer.
func test_region_change_resets_delay_timer() -> void:
	# Arrange
	var ctrl_a: Control = _make_control()
	var ctrl_b: Control = _make_control()
	TooltipManager.register(ctrl_a, func() -> String: return "A")
	TooltipManager.register(ctrl_b, func() -> String: return "B")
	ctrl_a.mouse_entered.emit()
	assert_eq(_state(), TooltipManager.State.WAITING,
			"Pre-condition: should be WAITING on first region")

	# Act — enter second region (without explicit exit from first)
	ctrl_b.mouse_entered.emit()

	# Assert
	assert_eq(_state(), TooltipManager.State.WAITING,
			"State should remain WAITING for new region")
	assert_eq(TooltipManager._hovered_control, ctrl_b,
			"Hovered control should switch to B")


# ------------------------------------------------------------------
# Toggle disables hover but not forced (TT-073)
# ------------------------------------------------------------------

## With tooltips disabled, hover does not trigger WAITING.
func test_toggle_disabled_blocks_hover() -> void:
	# Arrange
	var ctrl: Control = _make_control()
	TooltipManager.register(ctrl, func() -> String: return "Hidden")
	TooltipManager.tooltips_enabled = false

	# Act
	ctrl.mouse_entered.emit()

	# Assert
	assert_eq(_state(), TooltipManager.State.IDLE,
			"With toggle off, entering region should not start WAITING")


## With tooltips disabled, show_text(force=true) still works.
func test_toggle_disabled_allows_forced_show() -> void:
	# Arrange
	TooltipManager.tooltips_enabled = false

	# Act
	TooltipManager.show_text("Essential instruction", Vector2.INF, 0.0, true)
	await get_tree().process_frame

	# Assert
	assert_eq(_state(), TooltipManager.State.FORCED,
			"show_text(force=true) should enter FORCED even with toggle off")
	assert_true(_visible(),
			"Tooltip should be visible via forced show_text with toggle off")


## With tooltips disabled, show_text (default force=false) is suppressed.
func test_toggle_disabled_blocks_non_forced_show() -> void:
	# Arrange
	TooltipManager.tooltips_enabled = false

	# Act
	TooltipManager.show_text("Drag help text")
	await get_tree().process_frame

	# Assert
	assert_eq(_state(), TooltipManager.State.IDLE,
			"Non-forced show_text should stay IDLE with toggle off")
	assert_false(_visible(),
			"Tooltip should not be visible for non-forced show_text with toggle off")
