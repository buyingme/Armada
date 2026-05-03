## Load Game Dialog (Phase J5 / J5.5)
##
## Modal listing every save file in [SaveGameManager.SAVE_DIR] grouped
## by game mode.  Reachable from:
## - Main menu \u2192 Load Game
## - In-game ESC menu \u2192 Load Game
##
## Phase J5.5 layout (replaces the J5 filter-tab design):
## - Two stacked sections, headed "Hot-Seat" and "Network".
## - Each section starts with a synthetic **"Resume Last Checkpoint"**
##   row (always present; greyed when no checkpoint exists for that
##   mode).
## - Below the resume row, named saves of that mode are listed.
## - Network rows (resume + named) are greyed out when no host session
##   is currently active \u2014 tooltip "Host a game to load this save".
## - Saves that fail to parse / sign-verify show as a disabled row with
##   the failure reason.
##
## On Load:
## 1. For named saves: [SaveGameManager.load_game].
## 2. For the resume row: [SaveGameManager.load_game_from_checkpoint].
## 3. On success: tear down any active game, then call
##    [GameManager.start_new_game_from_state] to install the loaded
##    state.
## 4. If [member transition_to_board_on_load] is true, switch scenes to
##    the game-board scene.
class_name LoadGameDialog
extends PanelContainer


## Emitted after a successful load.  [code]meta[/code] is the loaded
## [SaveGameMetadata] (so the caller can transition scenes / show a
## toast).  The new [GameState] is already installed in [GameManager].
signal loaded(meta: SaveGameMetadata)

## Emitted when the player cancels (Cancel button or Escape).
signal cancelled


## Whether we should perform the post-load scene transition to the game
## board.  Set to [code]true[/code] when opened from the main menu, and
## [code]false[/code] when opened from the in-game ESC menu (the
## current scene is already the board).
var transition_to_board_on_load: bool = false


## The UI context the dialog was opened from.  Affects the network
## grey-out rule (Phase J5.6 / Q23):
## [br]- [code]"in_game"[/code] (default): network rows enabled iff a
##   host session is active.
## [br]- [code]"main_menu"[/code]: network rows are always disabled
##   with tooltip *"Load network saves from the lobby once both players
##   are connected"*.
## [br]- [code]"lobby"[/code] (J7): hot-seat rows are greyed; network
##   rows are enabled iff both peers are connected and Ready.
var context: String = "in_game"


## Path of the game-board scene used by the post-load transition.
const GAME_BOARD_PATH: String = "res://src/scenes/game_board/game_board.tscn"

## Sentinel name used internally for the resume rows.  Maps to a mode in
## [member _resume_row_mode].
const RESUME_ROW_PREFIX: String = "__resume__"


var _entries: Array[Dictionary] = []
var _selected_name: String = ""
var _selected_is_resume_for_mode: String = ""
var _list_vbox: VBoxContainer = null
var _load_button: Button = null
var _cancel_button: Button = null
var _delete_button: Button = null
var _confirm_delete: ConfirmationDialog = null


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


## Repopulates the list from disk and shows the dialog centred.
func show_modal() -> void:
	_refresh_entries()
	_render_list()
	visible = true
	await get_tree().process_frame
	var vp_size: Vector2 = get_viewport_rect().size
	position = (vp_size - size) * 0.5


## Hides the dialog.
func hide_modal() -> void:
	visible = false


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	add_theme_stylebox_override("panel",
			UIStyleHelper.create_modal_panel_style(0.0))
	custom_minimum_size = Vector2(640, 500)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	vbox.add_child(_build_title_label())
	vbox.add_child(_build_list_scroll())
	vbox.add_child(_build_button_row())
	_confirm_delete = ConfirmationDialog.new()
	_confirm_delete.dialog_text = ""
	_confirm_delete.title = "Delete save?"
	_confirm_delete.confirmed.connect(_on_delete_confirmed)
	add_child(_confirm_delete)


func _build_title_label() -> Label:
	var label: Label = Label.new()
	label.text = "Load Game"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	return label


func _build_list_scroll() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 320)
	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_list_vbox)
	return scroll


func _build_button_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	_delete_button = _make_action_button("Delete")
	_delete_button.disabled = true
	_delete_button.pressed.connect(_on_delete_pressed)
	row.add_child(_delete_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_cancel_button = _make_action_button("Cancel")
	_cancel_button.pressed.connect(_on_cancel_pressed)
	row.add_child(_cancel_button)
	_load_button = _make_action_button("Load")
	_load_button.disabled = true
	_load_button.pressed.connect(_on_load_pressed)
	row.add_child(_load_button)
	return row


func _make_action_button(label_text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(120, 36)
	return btn


# ---------------------------------------------------------------------------
# Population
# ---------------------------------------------------------------------------

func _refresh_entries() -> void:
	_entries.clear()
	if is_instance_valid(SaveGameManager):
		_entries = SaveGameManager.list_with_meta()
	_selected_name = ""
	_selected_is_resume_for_mode = ""


func _render_list() -> void:
	if _list_vbox == null:
		return
	for child: Node in _list_vbox.get_children():
		_list_vbox.remove_child(child)
		child.queue_free()
	_render_section(SaveGameMetadata.MODE_HOT_SEAT, "Hot-Seat")
	_render_section(SaveGameMetadata.MODE_NETWORK, "Network")
	_update_action_button_states()


func _render_section(mode: String, header_text: String) -> void:
	_list_vbox.add_child(_build_section_header(header_text))
	# Resume row first.
	_list_vbox.add_child(_build_resume_row(mode))
	# Named saves of this mode.
	var any: bool = false
	for entry: Dictionary in _entries:
		if _entry_mode(entry) != mode:
			continue
		_list_vbox.add_child(_build_named_row(entry))
		any = true
	if not any:
		var hint: Label = Label.new()
		hint.text = "    (no named saves)"
		hint.add_theme_color_override(
				"font_color", Color(0.55, 0.6, 0.7))
		_list_vbox.add_child(hint)


func _build_section_header(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override(
			"font_color", Color(0.7, 0.85, 1.0))
	return label


func _build_resume_row(mode: String) -> Button:
	var row: Button = _make_row_button()
	var has: bool = is_instance_valid(SaveGameManager) \
			and SaveGameManager.has_checkpoint(mode)
	var network_blocked: bool = mode == SaveGameMetadata.MODE_NETWORK \
			and _is_network_blocked()
	var hot_seat_blocked: bool = mode == SaveGameMetadata.MODE_HOT_SEAT \
			and _is_hot_seat_blocked()
	row.disabled = not has or network_blocked or hot_seat_blocked
	row.text = _resume_row_label(mode, has)
	if network_blocked:
		row.tooltip_text = _network_blocked_tooltip()
	elif hot_seat_blocked:
		row.tooltip_text = _hot_seat_blocked_tooltip()
	else:
		row.tooltip_text = ""
	# Encode "this is a resume row for mode X" via a sentinel name.
	var sentinel: String = RESUME_ROW_PREFIX + mode
	row.toggled.connect(_on_resume_row_toggled.bind(mode, sentinel, row))
	return row


func _resume_row_label(mode: String, has: bool) -> String:
	if not has:
		return "Resume Last Checkpoint\n   Empty \u2014 play a turn to create one."
	var meta: SaveGameMetadata = SaveGameManager.checkpoint_metadata(mode)
	if meta == null:
		return "Resume Last Checkpoint"
	return "Resume Last Checkpoint\n   %s \u00b7 Round %d \u00b7 %s \u00b7 %s" % [
			meta.scenario_name,
			meta.current_round,
			meta.phase,
			meta.created_at]


func _build_named_row(entry: Dictionary) -> Button:
	var row: Button = _make_row_button()
	var name: String = String(entry.get("name", ""))
	var disabled: bool = _row_is_disabled(entry)
	row.disabled = disabled
	row.text = _row_label(entry)
	if disabled:
		row.tooltip_text = _row_disabled_reason(entry)
	row.toggled.connect(_on_named_row_toggled.bind(name, row))
	return row


func _make_row_button() -> Button:
	var row: Button = Button.new()
	row.toggle_mode = true
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, 56)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row


func _entry_mode(entry: Dictionary) -> String:
	var meta: SaveGameMetadata = entry.get("meta") as SaveGameMetadata
	if meta == null:
		return SaveGameMetadata.MODE_HOT_SEAT
	return meta.game_mode


func _row_label(entry: Dictionary) -> String:
	var meta: SaveGameMetadata = entry.get("meta") as SaveGameMetadata
	var name: String = String(entry.get("name", ""))
	if meta == null:
		return "%s   [unreadable: %s]" % [
				name, String(entry.get("reason", "unknown"))]
	var display: String = meta.display_name
	if display.is_empty():
		display = name
	return "%s\n   %s \u00b7 Round %d \u00b7 %s \u00b7 %s" % [
			display,
			meta.scenario_name,
			meta.current_round,
			meta.phase,
			meta.created_at]


func _row_is_disabled(entry: Dictionary) -> bool:
	if not bool(entry.get("valid", false)):
		return true
	var meta: SaveGameMetadata = entry.get("meta") as SaveGameMetadata
	if meta == null:
		return true
	if meta.game_mode == SaveGameMetadata.MODE_NETWORK \
			and _is_network_blocked():
		return true
	if meta.game_mode == SaveGameMetadata.MODE_HOT_SEAT \
			and _is_hot_seat_blocked():
		return true
	return false


func _row_disabled_reason(entry: Dictionary) -> String:
	if not bool(entry.get("valid", false)):
		return "Cannot read save: %s" % String(entry.get("reason", ""))
	var meta: SaveGameMetadata = entry.get("meta") as SaveGameMetadata
	if meta != null \
			and meta.game_mode == SaveGameMetadata.MODE_NETWORK \
			and _is_network_blocked():
		return _network_blocked_tooltip()
	if meta != null \
			and meta.game_mode == SaveGameMetadata.MODE_HOT_SEAT \
			and _is_hot_seat_blocked():
		return _hot_seat_blocked_tooltip()
	return ""


func _has_host_session() -> bool:
	if not is_instance_valid(NetworkManager):
		return false
	return NetworkManager.is_server()


## True when network rows must be greyed out in the current context.
## Phase J5.6: in [code]"main_menu"[/code] context, network loads are
## always blocked (must use the lobby).  Phase J7: in [code]"lobby"[/code]
## context, network loads are always allowed (host has authority).
## Otherwise we fall back to the existing host-session rule.
func _is_network_blocked() -> bool:
	if context == "main_menu":
		return true
	if context == "lobby":
		return false
	return not _has_host_session()


## Tooltip shown on greyed network rows.  Phase J5.6.
func _network_blocked_tooltip() -> String:
	if context == "main_menu":
		return ("Load network saves from the lobby once both players "
				+"are connected.")
	return "Host a game to load this save."


## True when hot-seat rows must be greyed out.  Phase J7: hot-seat
## saves cannot be loaded from inside a network lobby.  Phase J8 fix:
## also greyed when the dialog is opened from the in-game ESC menu of
## an active network session — loading a hot-seat save there would
## tear down the network game without including the connected client.
func _is_hot_seat_blocked() -> bool:
	if context == "lobby":
		return true
	if context == "in_game" and is_instance_valid(PlayMode) \
			and PlayMode.is_network():
		return true
	return false


## Tooltip shown on greyed hot-seat rows in lobby context.  Phase J7.
func _hot_seat_blocked_tooltip() -> String:
	if context == "in_game":
		return ("Hot-seat saves cannot be loaded during a network "
				+"session.  Quit to the main menu first.")
	return "Hot-seat saves can only be loaded from the main menu."


func _update_action_button_states() -> void:
	if _load_button == null or _delete_button == null:
		return
	var has_selection: bool = not _selected_name.is_empty() \
			or not _selected_is_resume_for_mode.is_empty()
	# Delete only applies to named saves.
	_delete_button.disabled = _selected_name.is_empty()
	if not has_selection:
		_load_button.disabled = true
		return
	if not _selected_is_resume_for_mode.is_empty():
		# Resume row is always loadable when selected (rows are
		# disabled at the button level when not loadable, which means
		# they cannot be selected in the first place).
		_load_button.disabled = false
		return
	var entry: Dictionary = _find_entry(_selected_name)
	_load_button.disabled = _row_is_disabled(entry)


func _find_entry(name: String) -> Dictionary:
	if name.is_empty():
		return {}
	for entry: Dictionary in _entries:
		if String(entry.get("name", "")) == name:
			return entry
	return {}


# ---------------------------------------------------------------------------
# Input handlers
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_on_cancel_pressed()
			get_viewport().set_input_as_handled()


func _on_named_row_toggled(pressed: bool, name: String, row: Button) -> void:
	if not pressed:
		if _selected_name == name:
			_selected_name = ""
			_update_action_button_states()
		return
	_clear_other_toggles(row)
	_selected_name = name
	_selected_is_resume_for_mode = ""
	_update_action_button_states()


func _on_resume_row_toggled(
		pressed: bool, mode: String, _sentinel: String, row: Button) -> void:
	if not pressed:
		if _selected_is_resume_for_mode == mode:
			_selected_is_resume_for_mode = ""
			_update_action_button_states()
		return
	_clear_other_toggles(row)
	_selected_name = ""
	_selected_is_resume_for_mode = mode
	_update_action_button_states()


func _clear_other_toggles(keep: Button) -> void:
	for child: Node in _list_vbox.get_children():
		if child == keep:
			continue
		var other: Button = child as Button
		if other != null and other.toggle_mode:
			other.button_pressed = false


func _on_cancel_pressed() -> void:
	SfxManager.play_sfx("skip_beep")
	hide_modal()
	cancelled.emit()


func _on_load_pressed() -> void:
	var result: Dictionary
	if not _selected_is_resume_for_mode.is_empty():
		result = SaveGameManager.load_game_from_checkpoint(
				_selected_is_resume_for_mode)
	elif not _selected_name.is_empty():
		result = SaveGameManager.load_game(_selected_name)
	else:
		return
	if not bool(result.get("ok", false)):
		push_warning("LoadGameDialog: load failed (%s)"
				% String(result.get("reason", "")))
		_refresh_entries()
		_render_list()
		return
	var loaded_state: GameState = result.get("state") as GameState
	var meta: SaveGameMetadata = result.get("meta") as SaveGameMetadata
	if loaded_state == null or meta == null:
		push_warning("LoadGameDialog: load returned no state/meta.")
		return
	# Phase J7: in lobby context, delegate to LobbyManager which
	# installs locally, broadcasts the state to the client, and
	# triggers the same scene transition as a fresh lobby start.
	# Phase J7+: any host-side network load (lobby OR in-session)
	# routes through the same broadcast path so the client always
	# learns about the load and reloads its board scene.  The
	# in-session host's own scene reload happens inside
	# LobbyManager.host_load_save → _maybe_force_board_reload.
	var host_network_load: bool = (
			is_instance_valid(PlayMode) and PlayMode.is_network()
			and is_instance_valid(NetworkManager)
			and NetworkManager.is_server())
	if context == "lobby" or host_network_load:
		SfxManager.play_sfx("droid_sound")
		hide_modal()
		LobbyManager.host_load_save(loaded_state, meta)
		loaded.emit(meta)
		return
	SfxManager.play_sfx("droid_sound")
	hide_modal()
	GameManager.start_new_game_from_state(
			loaded_state, meta.scenario_id)
	loaded.emit(meta)
	if transition_to_board_on_load:
		get_tree().change_scene_to_file(GAME_BOARD_PATH)


func _on_delete_pressed() -> void:
	if _selected_name.is_empty():
		return
	_confirm_delete.dialog_text = (
			"Delete the save \"%s\"?\nThis cannot be undone."
			% _selected_name)
	_confirm_delete.popup_centered()


func _on_delete_confirmed() -> void:
	if _selected_name.is_empty():
		return
	if is_instance_valid(SaveGameManager):
		SaveGameManager.delete_save(_selected_name)
	_refresh_entries()
	_render_list()
