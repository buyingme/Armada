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


func test_command_choices_reuse_token_graphics_and_standard_hierarchy() -> void:
	_modal.open_from_intent(_intent(true))
	var choice: VBoxContainer = _modal.find_child(
			"CommandChoice_0", true, false) as VBoxContainer
	var icon: TextureRect = _modal.find_child(
			"CommandIcon_0", true, false) as TextureRect
	var button: Button = _modal.find_child(
			"CommandButton_0", true, false) as Button

	assert_not_null(choice)
	assert_not_null(icon)
	assert_not_null(icon.texture,
			"Tarkin command choices should use the standard command-token art.")
	assert_not_null(button)
	assert_lt(icon.get_index(), button.get_index(),
			"Token graphic should sit above the semantic choice button.")


func test_repeated_open_rebuilds_once_and_centres_actual_modal_size() -> void:
	var intent: UIProjector.UIIntent = _intent(true)
	intent.payload["available_commands"] = [
		int(Constants.CommandType.NAVIGATE),
		int(Constants.CommandType.SQUADRON),
		int(Constants.CommandType.CONCENTRATE_FIRE),
		int(Constants.CommandType.REPAIR),
	]
	_modal.open_from_intent(intent)
	_modal.open_from_intent(intent)

	assert_eq(_modal._commands_box.get_child_count(), 4,
			"Reopening must not leave deferred stale choices in layout.")
	var viewport_size: Vector2 = Vector2(1000, 700)
	_modal.centre_on_screen(viewport_size)
	assert_almost_eq((_modal.position + _modal.size * 0.5).x,
			viewport_size.x * 0.5, 0.1,
			"Repeated Tarkin modal should remain horizontally centred.")
	assert_almost_eq((_modal.position + _modal.size * 0.5).y,
			viewport_size.y * 0.5, 0.1,
			"Repeated Tarkin modal should remain vertically centred.")


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
