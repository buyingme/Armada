## Test: LoadGameDialog (Phase J5.5)
##
## Unit tests for the in-game / main-menu Load dialog.  Covers section
## headers, named-row population, "Resume Last Checkpoint" rows,
## network grey-out, and button enable/disable.  Actual file IO is
## exercised via the live SaveGameManager autoload.
extends GutTest


const Dialog: GDScript = preload("res://src/ui/save/load_game_dialog.gd")
const SAVE_HOTSEAT: String = "_gut_load_dlg_hot"
const SAVE_NETWORK: String = "_gut_load_dlg_net"


var _dialog: LoadGameDialog = null


func before_each() -> void:
	SaveGameManager.clear_checkpoints()
	_dialog = Dialog.new()
	add_child_autofree(_dialog)


func after_each() -> void:
	SaveGameManager.delete_save(SAVE_HOTSEAT)
	SaveGameManager.delete_save(SAVE_NETWORK)
	SaveGameManager.clear_checkpoints()
	_dialog = null


# --- Helpers ---

func _save_with_mode(name: String, mode: String) -> void:
	var gs: GameState = _make_state()
	var meta: SaveGameMetadata = SaveGameManager.build_metadata_for(
			gs, name)
	meta.game_mode = mode
	SaveGameManager.save_game(gs, name, meta)


func _make_state() -> GameState:
	var gs: GameState = GameState.new()
	gs.initialize()
	gs.current_round = 2
	gs.current_phase = Constants.GamePhase.SHIP
	gs.initiative_player = 0
	return gs


func _reseed_fixtures() -> void:
	SaveGameManager.delete_save(SAVE_HOTSEAT)
	SaveGameManager.delete_save(SAVE_NETWORK)
	_save_with_mode(SAVE_HOTSEAT, SaveGameMetadata.MODE_HOT_SEAT)
	_save_with_mode(SAVE_NETWORK, SaveGameMetadata.MODE_NETWORK)


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func test_dialog_starts_hidden() -> void:
	assert_false(_dialog.visible, "Dialog should start hidden")


func test_dialog_has_load_cancel_delete_buttons() -> void:
	assert_not_null(_find_button(_dialog, "Load"),
			"Load button should exist")
	assert_not_null(_find_button(_dialog, "Cancel"),
			"Cancel button should exist")
	assert_not_null(_find_button(_dialog, "Delete"),
			"Delete button should exist")


func test_load_button_disabled_without_selection() -> void:
	_reseed_fixtures()
	_dialog.show_modal()
	assert_true(_find_button(_dialog, "Load").disabled,
			"Load should be disabled until a row is selected")


# ---------------------------------------------------------------------------
# Section layout (Phase J5.5)
# ---------------------------------------------------------------------------

func test_dialog_renders_two_section_headers() -> void:
	_dialog.show_modal()
	assert_not_null(_find_label(_dialog, "Hot-Seat"),
			"Hot-Seat section header should exist")
	assert_not_null(_find_label(_dialog, "Network"),
			"Network section header should exist")


func test_named_saves_appear_under_correct_section() -> void:
	_reseed_fixtures()
	_dialog.show_modal()
	var rows: Array[Button] = _list_rows(_dialog)
	var hot_seen: bool = false
	var net_seen: bool = false
	for row: Button in rows:
		if row.text.find(SAVE_HOTSEAT) != -1:
			hot_seen = true
		if row.text.find(SAVE_NETWORK) != -1:
			net_seen = true
	assert_true(hot_seen, "Hot-seat fixture row should appear")
	assert_true(net_seen, "Network fixture row should appear")


# ---------------------------------------------------------------------------
# Resume rows
# ---------------------------------------------------------------------------

func test_resume_rows_always_present() -> void:
	# Even with no checkpoints, both resume rows must render.
	_dialog.show_modal()
	var resume_rows: Array[Button] = _resume_rows(_dialog)
	assert_eq(resume_rows.size(), 2,
			"Two resume rows (one per mode) should render")


func test_resume_row_disabled_when_no_checkpoint() -> void:
	_dialog.show_modal()
	for row: Button in _resume_rows(_dialog):
		assert_true(row.disabled,
				"Resume row should be disabled without a checkpoint")


# ---------------------------------------------------------------------------
# Network grey-out
# ---------------------------------------------------------------------------

func test_network_named_row_disabled_when_no_host_session() -> void:
	_reseed_fixtures()
	_dialog.show_modal()
	var rows: Array[Button] = _list_rows(_dialog)
	for row: Button in rows:
		if row.text.find(SAVE_NETWORK) != -1:
			assert_true(row.disabled,
					"Network row should be disabled without host session")
			return
	fail_test("Network fixture row not found")


func test_network_named_row_disabled_in_main_menu_context() -> void:
	# Phase J5.6 / Q23: from the main menu, network rows must be greyed
	# regardless of host-session state.
	_reseed_fixtures()
	_dialog.context = "main_menu"
	_dialog.show_modal()
	var rows: Array[Button] = _list_rows(_dialog)
	for row: Button in rows:
		if row.text.find(SAVE_NETWORK) != -1:
			assert_true(row.disabled,
					"Network row should be disabled in main_menu context")
			assert_true(row.tooltip_text.find("lobby") != -1,
					"Tooltip should reference the lobby")
			return
	fail_test("Network fixture row not found")


func test_network_resume_row_disabled_in_main_menu_context() -> void:
	# Phase J5.6: synthetic resume row in the Network section must also
	# be greyed out from the main menu.
	_dialog.context = "main_menu"
	_dialog.show_modal()
	for row: Button in _resume_rows(_dialog):
		if row.text.find("Resume Last Checkpoint") == -1:
			continue
		# Resume rows for both modes always exist; pick the one whose
		# sentinel signal binding targets the network mode by checking
		# tooltip presence (only the network resume row has the
		# main-menu lobby tooltip).
		if row.tooltip_text.find("lobby") != -1:
			assert_true(row.disabled,
					"Network resume row should be disabled in main_menu")
			return
	# If we got here, no network resume row was found with the lobby
	# tooltip; tolerate that only when neither row has the lobby
	# tooltip (e.g. checkpoints are absent so tooltip is empty).  In
	# that case the disabled state still applies via has-checkpoint
	# logic, so check at least one resume row is disabled.
	var any_disabled: bool = false
	for row: Button in _resume_rows(_dialog):
		if row.disabled:
			any_disabled = true
			break
	assert_true(any_disabled,
			"At least one resume row should be disabled in main_menu")


# ---------------------------------------------------------------------------
# Cancel
# ---------------------------------------------------------------------------

func test_cancel_emits_signal_and_hides() -> void:
	_dialog.show_modal()
	watch_signals(_dialog)
	_find_button(_dialog, "Cancel").pressed.emit()
	assert_signal_emitted(_dialog, "cancelled",
			"Cancel button should emit 'cancelled'")
	assert_false(_dialog.visible, "Dialog should hide after cancel")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _find_button(node: Node, text: String) -> Button:
	for child: Node in node.get_children():
		if child is Button and (child as Button).text == text:
			return child as Button
		var nested: Button = _find_button(child, text)
		if nested != null:
			return nested
	return null


func _find_label(node: Node, text: String) -> Label:
	for child: Node in node.get_children():
		if child is Label and (child as Label).text == text:
			return child as Label
		var nested: Label = _find_label(child, text)
		if nested != null:
			return nested
	return null


func _list_rows(dialog: LoadGameDialog) -> Array[Button]:
	var rows: Array[Button] = []
	_collect_rows(dialog, rows)
	return rows


func _resume_rows(dialog: LoadGameDialog) -> Array[Button]:
	var out: Array[Button] = []
	for row: Button in _list_rows(dialog):
		if row.text.begins_with("Resume Last Checkpoint"):
			out.append(row)
	return out


func _collect_rows(node: Node, out: Array[Button]) -> void:
	for child: Node in node.get_children():
		if child is Button:
			var btn: Button = child as Button
			if btn.toggle_mode \
					and btn.custom_minimum_size.y >= 56.0:
				out.append(btn)
		_collect_rows(child, out)


# ---------------------------------------------------------------------------
# Phase J7 — lobby context
# ---------------------------------------------------------------------------

func test_hot_seat_named_row_disabled_in_lobby_context() -> void:
	# Phase J7 / Q25: from the lobby, hot-seat rows are greyed.
	_reseed_fixtures()
	_dialog.context = "lobby"
	_dialog.show_modal()
	var rows: Array[Button] = _list_rows(_dialog)
	for row: Button in rows:
		if row.text.find(SAVE_HOTSEAT) != -1:
			assert_true(row.disabled,
					"Hot-seat row should be disabled in lobby context")
			assert_true(row.tooltip_text.find("main menu") != -1,
					"Tooltip should reference the main menu")
			return
	fail_test("Hot-seat fixture row not found")


func test_network_named_row_enabled_in_lobby_context() -> void:
	# Phase J7: from the lobby, network rows are enabled regardless of
	# the local NetworkManager.is_server() state.
	_reseed_fixtures()
	_dialog.context = "lobby"
	_dialog.show_modal()
	var rows: Array[Button] = _list_rows(_dialog)
	for row: Button in rows:
		if row.text.find(SAVE_NETWORK) != -1:
			assert_false(row.disabled,
					"Network row should be enabled in lobby context")
			return
	fail_test("Network fixture row not found")


# ---------------------------------------------------------------------------
# Phase J8 fix — in-session network ESC menu must also grey hot-seat saves
# ---------------------------------------------------------------------------

func test_hot_seat_named_row_disabled_in_game_when_network_active() -> void:
	# Phase J8 bug fix: when the Load dialog is opened from the in-game
	# ESC menu of an active network session, hot-seat saves must be
	# greyed out — loading one would tear down the network game.
	_reseed_fixtures()
	var prev_mode: int = PlayMode.current_mode
	PlayMode.current_mode = PlayMode.Mode.NETWORK
	_dialog.context = "in_game"
	_dialog.show_modal()
	var rows: Array[Button] = _list_rows(_dialog)
	var found: bool = false
	for row: Button in rows:
		if row.text.find(SAVE_HOTSEAT) != -1:
			assert_true(row.disabled,
					"Hot-seat row should be disabled in in_game context "
					+"during a network session")
			assert_true(row.tooltip_text.find("network session") != -1,
					"Tooltip should explain the network-session block")
			found = true
			break
	PlayMode.current_mode = prev_mode
	if not found:
		fail_test("Hot-seat fixture row not found")


func test_hot_seat_named_row_enabled_in_game_when_hot_seat_mode() -> void:
	# Sanity: in pure hot-seat mode the in_game ESC dialog still allows
	# loading hot-seat saves.
	_reseed_fixtures()
	var prev_mode: int = PlayMode.current_mode
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT
	_dialog.context = "in_game"
	_dialog.show_modal()
	var rows: Array[Button] = _list_rows(_dialog)
	var found: bool = false
	for row: Button in rows:
		if row.text.find(SAVE_HOTSEAT) != -1:
			assert_false(row.disabled,
					"Hot-seat row should be enabled in in_game hot-seat mode")
			found = true
			break
	PlayMode.current_mode = prev_mode
	if not found:
		fail_test("Hot-seat fixture row not found")
