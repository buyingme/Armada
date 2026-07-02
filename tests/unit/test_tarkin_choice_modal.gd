## Test: TarkinChoiceModal
##
## Verifies the presentation-only Grand Moff Tarkin choice prompt.
extends GutTest


var _modal: TarkinChoiceModal = null


func before_each() -> void:
	_modal = TarkinChoiceModal.new()
	add_child(_modal)


func after_each() -> void:
	if _modal != null:
		remove_child(_modal)
		_modal.free()
	_modal = null


func test_open_from_intent_interactive_emits_choice() -> void:
	var intent: UIProjector.UIIntent = _intent(true)
	watch_signals(_modal)

	_modal.open_from_intent(intent)
	(_modal.find_child("CommandButton_0", true, false) as Button).pressed.emit()

	assert_true(_modal.is_open(),
			"Opening from intent should make the prompt visible.")
	assert_signal_emitted(_modal, "choice_submitted",
			"Interactive command button should emit a choice.")


func test_open_from_intent_passive_disables_submission() -> void:
	var intent: UIProjector.UIIntent = _intent(false)
	watch_signals(_modal)

	_modal.open_from_intent(intent)
	var command_button: Button = _modal.find_child(
			"CommandButton_0", true, false) as Button
	var decline_button: Button = _find_button("Decline")
	command_button.pressed.emit()
	decline_button.pressed.emit()

	assert_true(command_button.disabled,
			"Passive observers should see disabled command controls.")
	assert_true(decline_button.disabled,
			"Passive observers should not be able to decline for the owner.")
	assert_signal_not_emitted(_modal, "choice_submitted",
			"Passive command button should not emit a choice.")
	assert_signal_not_emitted(_modal, "decline_submitted",
			"Passive decline button should not emit.")


func test_decline_button_emits_decline() -> void:
	var intent: UIProjector.UIIntent = _intent(true)
	watch_signals(_modal)

	_modal.open_from_intent(intent)
	_find_button("Decline").pressed.emit()

	assert_signal_emitted(_modal, "decline_submitted",
			"Interactive decline button should emit an explicit decline.")


func _intent(interactive: bool) -> UIProjector.UIIntent:
	var intent: UIProjector.UIIntent = UIProjector.UIIntent.new()
	intent.is_interactive = interactive
	intent.payload = {
		"runtime_upgrade_id": "tarkin-runtime",
		"available_commands": [
			int(Constants.CommandType.NAVIGATE),
			int(Constants.CommandType.SQUADRON),
		],
	}
	return intent


func _find_button(text: String) -> Button:
	for child: Node in _modal.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button != null and button.text == text:
			return button
	return null
