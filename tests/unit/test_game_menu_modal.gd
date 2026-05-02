## Test: GameMenuModal (Phase J3)
##
## Unit tests for the in-game ESC menu — button visibility per mode,
## ESC toggle, save-on-quit dirty prompt.
extends GutTest


var _modal: GameMenuModal = null


func before_each() -> void:
	_modal = GameMenuModal.new()
	add_child_autofree(_modal)


# ---------------------------------------------------------------------------
# Button visibility per mode (Q / mode matrix)
# ---------------------------------------------------------------------------

func _save_btn(modal: GameMenuModal) -> Button:
	return modal.find_child("*", true, false) as Button if false else _find_button(modal, "Save Game")


func _find_button(modal: GameMenuModal, label_text: String) -> Button:
	for child: Node in modal.find_children("*", "Button", true, false):
		var btn: Button = child as Button
		if btn != null and btn.text == label_text:
			return btn
	return null


func test_hot_seat_mode_shows_all_four_buttons() -> void:
	_modal.set_mode(GameMenuModal.Mode.HOT_SEAT)
	assert_not_null(_find_button(_modal, "Resume"),
			"Resume button should always be present")
	assert_true(_find_button(_modal, "Save Game").visible,
			"Save Game should be visible in hot-seat")
	assert_true(_find_button(_modal, "Load Game").visible,
			"Load Game should be visible in hot-seat")
	assert_not_null(_find_button(_modal, "Quit Game"),
			"Quit Game should be present")


func test_network_host_mode_shows_all_four_buttons() -> void:
	_modal.set_mode(GameMenuModal.Mode.NETWORK_HOST)
	assert_true(_find_button(_modal, "Save Game").visible,
			"Save Game should be visible for network host")
	assert_true(_find_button(_modal, "Load Game").visible,
			"Load Game should be visible for network host")


func test_network_client_mode_hides_save_and_load() -> void:
	_modal.set_mode(GameMenuModal.Mode.NETWORK_CLIENT)
	assert_false(_find_button(_modal, "Save Game").visible,
			"Save Game should be hidden for network clients")
	assert_false(_find_button(_modal, "Load Game").visible,
			"Load Game should be hidden for network clients")
	assert_not_null(_find_button(_modal, "Resume"),
			"Resume should still be present for clients")
	assert_not_null(_find_button(_modal, "Quit Game"),
			"Quit Game should still be present for clients")


func test_save_button_enabled_at_safe_point_load_stubbed() -> void:
	_modal.set_mode(GameMenuModal.Mode.HOT_SEAT)
	# Without an active GameManager game, can_save_now() returns
	# {ok: false, ...}, so the Save button is disabled with a tooltip.
	# Load remains stub-disabled until J5.
	var save_btn: Button = _find_button(_modal, "Save Game")
	assert_not_null(save_btn, "Save Game button should exist")
	assert_true(_find_button(_modal, "Load Game").disabled,
			"Load Game is stub-disabled until J5")


# ---------------------------------------------------------------------------
# ESC / toggle behaviour
# ---------------------------------------------------------------------------

func test_toggle_opens_then_closes() -> void:
	assert_false(_modal.visible, "Modal starts hidden")
	_modal.toggle()
	assert_true(_modal.visible, "First toggle should open")
	_modal.toggle()
	assert_false(_modal.visible, "Second toggle should close")


# ---------------------------------------------------------------------------
# Resume signal
# ---------------------------------------------------------------------------

func test_resume_button_emits_resume_and_hides() -> void:
	_modal.set_mode(GameMenuModal.Mode.HOT_SEAT)
	watch_signals(_modal)
	_modal.show_modal()
	_find_button(_modal, "Resume").pressed.emit()
	assert_signal_emitted(_modal, "resume_requested",
			"Resume button should emit resume_requested")
	assert_false(_modal.visible, "Resume should hide the modal")


# ---------------------------------------------------------------------------
# Dirty-on-quit dispatch
# ---------------------------------------------------------------------------

func test_quit_when_clean_emits_quit_directly() -> void:
	_modal.set_mode(GameMenuModal.Mode.HOT_SEAT)
	_modal.dirty_override = 0 # clean
	watch_signals(_modal)
	_find_button(_modal, "Quit Game").pressed.emit()
	assert_signal_emitted(_modal, "quit_requested",
			"Clean quit should emit quit_requested directly")
	assert_null(_modal.get_save_on_quit_dialog(),
			"No save-on-quit dialog when clean")


func test_quit_when_dirty_opens_save_on_quit_dialog() -> void:
	_modal.set_mode(GameMenuModal.Mode.HOT_SEAT)
	_modal.dirty_override = 1 # dirty
	_modal.show_modal()
	_find_button(_modal, "Quit Game").pressed.emit()
	# Allow the deferred show_modal to settle.
	await get_tree().process_frame
	var sub: SaveOnQuitDialog = _modal.get_save_on_quit_dialog()
	assert_not_null(sub, "Dirty quit should open SaveOnQuitDialog")
	assert_true(sub.visible, "SaveOnQuitDialog should be visible")
	assert_false(_modal.visible,
			"Game menu should hide when sub-dialog opens")


func test_dirty_quit_save_and_quit_opens_save_dialog_then_quits() -> void:
	# J4: "Save & Quit" routes through SaveGameDialog.  When the dialog
	# emits `saved`, the menu emits quit_requested(false) since the game
	# is now clean.
	_modal.set_mode(GameMenuModal.Mode.HOT_SEAT)
	_modal.dirty_override = 1
	_modal.show_modal()
	_find_button(_modal, "Quit Game").pressed.emit()
	await get_tree().process_frame
	var sub: SaveOnQuitDialog = _modal.get_save_on_quit_dialog()
	sub.save_and_quit_requested.emit()
	await get_tree().process_frame
	var save_dlg: SaveGameDialog = _modal.get_save_game_dialog()
	assert_not_null(save_dlg,
			"Save & Quit should open the SaveGameDialog")
	watch_signals(_modal)
	# Simulate a successful save by emitting the dialog's saved signal.
	save_dlg.saved.emit("test_save")
	assert_signal_emitted(_modal, "quit_requested",
			"Save then quit should emit quit_requested after save")
	var params: Array = get_signal_parameters(_modal, "quit_requested")
	assert_eq(params, [false],
			"After save, quit_requested should fire with save_first=false")


func test_dirty_quit_quit_without_saving_emits_quit_with_false() -> void:
	_modal.set_mode(GameMenuModal.Mode.HOT_SEAT)
	_modal.dirty_override = 1
	_modal.show_modal()
	_find_button(_modal, "Quit Game").pressed.emit()
	await get_tree().process_frame
	watch_signals(_modal)
	var sub: SaveOnQuitDialog = _modal.get_save_on_quit_dialog()
	sub.quit_without_saving_requested.emit()
	assert_signal_emitted(_modal, "quit_requested",
			"Quit Without Saving should emit quit_requested")
	var params: Array = get_signal_parameters(_modal, "quit_requested")
	assert_eq(params, [false],
			"Quit Without Saving should emit save_first=false")


func test_dirty_quit_cancel_reopens_menu() -> void:
	_modal.set_mode(GameMenuModal.Mode.HOT_SEAT)
	_modal.dirty_override = 1
	_modal.show_modal()
	_find_button(_modal, "Quit Game").pressed.emit()
	await get_tree().process_frame
	var sub: SaveOnQuitDialog = _modal.get_save_on_quit_dialog()
	sub.cancelled.emit()
	await get_tree().process_frame
	assert_true(_modal.visible,
			"Cancel should re-open the game menu")
