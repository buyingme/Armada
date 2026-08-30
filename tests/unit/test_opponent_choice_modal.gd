## DBG-001 keeps ordinary required-choice Escape behavior while exposing only
## the bounded debug picker cancellation path.
extends GutTest

var _modal: OpponentChoiceModal


func before_each() -> void:
	_modal = OpponentChoiceModal.new()
	add_child_autofree(_modal)


func _choice() -> Dictionary:
	return {"card_title": "Test", "effect_text": "Test", "chooser": "owner",
		"multi_select": false, "max_selections": 1,
		"options": [{"id": "one", "label": "One", "available": true}]}


func test_debug_cancellable_picker_emits_cancel_and_closes() -> void:
	watch_signals(_modal)
	_modal.open_debug_cancellable(_choice())
	_modal._cancel_debug_choice()
	assert_signal_emitted(_modal, "debug_choice_cancelled")
	assert_false(_modal.visible)


func test_ordinary_picker_escape_remains_non_cancelling() -> void:
	_modal.open(_choice())
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	_modal._unhandled_input(escape)
	assert_true(_modal.visible)
