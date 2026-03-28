## Test: ShowSquadronModalButton
##
## Unit tests for the button that re-opens the squadron activation modal.
## Requirements: SQA-011, SQA-013.
extends GutTest


var _button: ShowSquadronModalButton = null


func before_each() -> void:
	_button = ShowSquadronModalButton.new()
	add_child_autofree(_button)


func test_initially_hidden() -> void:
	assert_false(_button.visible,
			"Button should be hidden on creation")


func test_show_button_makes_visible() -> void:
	_button.show_button()
	assert_true(_button.visible,
			"Button should be visible after show_button()")


func test_hide_button_hides() -> void:
	_button.show_button()
	_button.hide_button()
	assert_false(_button.visible,
			"Button should be hidden after hide_button()")


func test_show_button_enables() -> void:
	_button.show_button()
	assert_false(_button.disabled,
			"Button should not be disabled after show_button()")


func test_update_position_centres_horizontally() -> void:
	_button.show_button()
	# Force a minimum size so calculations are meaningful.
	_button.size = Vector2(240, 44)
	var vp: Vector2 = Vector2(800, 600)
	_button.update_position(vp)
	# Centre: (800 - 240) / 2 = 280
	var expected_x: float = (vp.x - _button.size.x) * 0.5
	assert_almost_eq(_button.position.x, expected_x, 1.0,
			"Button should be centred horizontally")


func test_pressed_emits_signal() -> void:
	watch_signals(_button)
	_button.show_button()
	_button._on_pressed()
	assert_signal_emitted(_button, "squadron_modal_requested",
			"Pressing the button should emit squadron_modal_requested")


func test_pressed_hides_itself() -> void:
	_button.show_button()
	_button._on_pressed()
	assert_false(_button.visible,
			"Button should hide itself after press")
