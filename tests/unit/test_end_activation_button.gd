## Test: EndActivationButton
##
## Unit tests for the EndActivationButton UI component.
## Requirements: TF-005, TF-011.
extends GutTest


var _button: EndActivationButton = null
var _activation_ended_count: int = 0


func before_each() -> void:
	_activation_ended_count = 0
	_button = EndActivationButton.new()
	add_child_autofree(_button)
	EventBus.activation_ended.connect(_on_activation_ended)


func after_each() -> void:
	if EventBus.activation_ended.is_connected(_on_activation_ended):
		EventBus.activation_ended.disconnect(_on_activation_ended)


func _on_activation_ended() -> void:
	_activation_ended_count += 1


func test_initial_state_is_hidden() -> void:
	assert_false(_button.visible,
			"Button should be hidden initially")


func test_show_button_makes_visible() -> void:
	_button.show_button()
	assert_true(_button.visible,
			"Button should be visible after show_button")


func test_show_button_enables_interaction() -> void:
	_button.show_button()
	assert_false(_button.disabled,
			"Button should not be disabled after show_button")


func test_hide_button_hides() -> void:
	_button.show_button()
	_button.hide_button()
	assert_false(_button.visible,
			"Button should be hidden after hide_button")


func test_text_is_end_activation() -> void:
	assert_eq(_button.text, "End Activation",
			"Button text should be 'End Activation'")


func test_update_position_centres_horizontally() -> void:
	_button.show_button()
	var vp: Vector2 = Vector2(1280, 720)
	# Force size to be calculated.
	_button.size = _button.custom_minimum_size
	_button.update_position(vp)
	var expected_x: float = (vp.x - _button.size.x) * 0.5
	assert_almost_eq(_button.position.x, expected_x, 1.0,
			"Button should be horizontally centred")
