## Lobby Room
##
## Full-screen lobby UI shown after hosting or joining a game.
## Displays the lobby name, code, player list with ready indicators,
## and action buttons (Ready, Start, Leave).
##
## Uses [UIStyleHelper] for consistent modal styling.
## Connects to [LobbyManager] signals for lobby state updates.
##
## G4 Network Plan: §4 — G4.5.4
class_name LobbyRoom
extends Control


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Background overlay colour.
const OVERLAY_COLOR: Color = Color(0.05, 0.05, 0.1, 0.85)

## Row background for player slots.
const ROW_BG: Color = Color(0.15, 0.15, 0.22, 0.9)

## Ready indicator colour.
const READY_COLOR: Color = Color(0.4, 0.9, 0.4)

## Not-ready indicator colour.
const NOT_READY_COLOR: Color = Color(0.6, 0.6, 0.6)

## Waiting-for-player text colour.
const WAITING_COLOR: Color = Color(0.5, 0.5, 0.5)


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the user leaves the lobby.
signal leave_requested()

## Emitted when the game is starting (transition to game board).
signal game_start_requested()


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Whether the local player is ready.
var _is_ready: bool = false

## UI element references.
var _panel: PanelContainer
var _title_label: Label
var _code_label: Label
var _player_rows: Array[PanelContainer] = []
var _player_name_labels: Array[Label] = []
var _player_ready_labels: Array[Label] = []
var _ready_button: Button
var _start_button: Button
var _leave_button: Button
var _status_label: Label


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_update_display()
	visibility_changed.connect(_on_visibility_changed)


func _connect_signals() -> void:
	LobbyManager.lobby_updated.connect(_on_lobby_updated)
	LobbyManager.lobby_created.connect(_on_lobby_created)
	LobbyManager.game_starting.connect(_on_game_starting)
	LobbyManager.lobby_error.connect(_on_lobby_error)


## Handles Escape key to leave lobby.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			_on_leave_pressed()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

## Builds the entire lobby room UI in code.
func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_background()
	_panel = _build_main_panel()
	add_child(_panel)


## Creates the dark background overlay.
func _build_background() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = OVERLAY_COLOR
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


## Creates the centred modal panel with lobby content.
## Positioned manually via [method _center_panel] because the
## LobbyRoom starts hidden — anchor-based centering resolves
## against a zero-sized parent.
func _build_main_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	panel.add_theme_stylebox_override("panel",
			UIStyleHelper.create_modal_panel_style(0.0))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_build_header(vbox)
	vbox.add_child(HSeparator.new())
	_build_player_list(vbox)
	vbox.add_child(HSeparator.new())
	_build_status_area(vbox)
	_build_buttons(vbox)

	return panel


## Builds the lobby title and code display.
func _build_header(parent: VBoxContainer) -> void:
	_title_label = UIStyleHelper.create_title_label(
			"Lobby", UIStyleHelper.GOLD_TITLE)
	parent.add_child(_title_label)

	_code_label = UIStyleHelper.create_section_label(
			"Code: ------", UIStyleHelper.FONT_BODY,
			UIStyleHelper.BLUE_ACCENT)
	parent.add_child(_code_label)


## Builds two player rows (one per slot).
func _build_player_list(parent: VBoxContainer) -> void:
	var players_label: Label = UIStyleHelper.create_section_label(
			"Players", UIStyleHelper.FONT_BODY,
			UIStyleHelper.BODY_TEXT)
	players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(players_label)

	for i: int in range(LobbyState.MAX_PLAYERS):
		var row: PanelContainer = _build_player_row(i)
		_player_rows.append(row)
		parent.add_child(row)


## Builds a single player slot row.
func _build_player_row(index: int) -> PanelContainer:
	var row_panel: PanelContainer = PanelContainer.new()
	var row_style: StyleBoxFlat = StyleBoxFlat.new()
	row_style.bg_color = ROW_BG
	row_style.set_corner_radius_all(4)
	row_style.set_content_margin_all(8)
	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row_panel.add_child(hbox)

	var slot_label: Label = Label.new()
	slot_label.text = "P%d:" % (index + 1)
	slot_label.add_theme_font_size_override("font_size",
			UIStyleHelper.FONT_BODY)
	slot_label.add_theme_color_override("font_color",
			UIStyleHelper.DIMMED_HINT)
	slot_label.custom_minimum_size.x = 32
	hbox.add_child(slot_label)

	var name_label: Label = Label.new()
	name_label.text = "Waiting..."
	name_label.add_theme_font_size_override("font_size",
			UIStyleHelper.FONT_BODY)
	name_label.add_theme_color_override("font_color", WAITING_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_name_labels.append(name_label)
	hbox.add_child(name_label)

	var ready_label: Label = Label.new()
	ready_label.text = ""
	ready_label.add_theme_font_size_override("font_size",
			UIStyleHelper.FONT_BODY)
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ready_label.custom_minimum_size.x = 80
	_player_ready_labels.append(ready_label)
	hbox.add_child(ready_label)

	return row_panel


## Builds the status text area.
func _build_status_area(parent: VBoxContainer) -> void:
	_status_label = UIStyleHelper.create_section_label(
			"", UIStyleHelper.FONT_HINT, UIStyleHelper.DIMMED_HINT)
	parent.add_child(_status_label)


## Builds the action buttons.
func _build_buttons(parent: VBoxContainer) -> void:
	var btn_box: HBoxContainer = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 12)
	parent.add_child(btn_box)

	_ready_button = Button.new()
	_ready_button.text = "Ready"
	_ready_button.custom_minimum_size = Vector2(120, 36)
	_ready_button.pressed.connect(_on_ready_pressed)
	btn_box.add_child(_ready_button)

	_start_button = Button.new()
	_start_button.text = "Start Game"
	_start_button.custom_minimum_size = Vector2(120, 36)
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.visible = LobbyManager.is_host()
	_start_button.disabled = true
	btn_box.add_child(_start_button)

	_leave_button = Button.new()
	_leave_button.text = "Leave"
	_leave_button.custom_minimum_size = Vector2(120, 36)
	_leave_button.pressed.connect(_on_leave_pressed)
	btn_box.add_child(_leave_button)


# ---------------------------------------------------------------------------
# Display updates
# ---------------------------------------------------------------------------

## Refreshes the entire display from the current lobby state.
func _update_display() -> void:
	var lobby: LobbyState = LobbyManager.current_lobby
	if lobby == null:
		_title_label.text = "Lobby"
		_code_label.text = "Code: ------"
		_update_empty_player_rows()
		_status_label.text = "No lobby active."
		return

	_title_label.text = lobby.lobby_name if lobby.lobby_name != "" \
			else "Lobby"
	_code_label.text = "Code: %s" % lobby.code
	_update_player_rows(lobby)
	_update_status(lobby)
	_update_buttons(lobby)


## Updates player rows with current lobby data.
func _update_player_rows(lobby: LobbyState) -> void:
	for i: int in range(LobbyState.MAX_PLAYERS):
		var player: Dictionary = _find_player_by_index(lobby, i)
		if player.is_empty():
			_player_name_labels[i].text = "Waiting..."
			_player_name_labels[i].add_theme_color_override(
					"font_color", WAITING_COLOR)
			_player_ready_labels[i].text = ""
		else:
			_player_name_labels[i].text = player.get(
					"display_name", "Unknown")
			_player_name_labels[i].add_theme_color_override(
					"font_color", UIStyleHelper.BODY_TEXT)
			if player.get("ready", false):
				_player_ready_labels[i].text = "✓ Ready"
				_player_ready_labels[i].add_theme_color_override(
						"font_color", READY_COLOR)
			else:
				_player_ready_labels[i].text = "Not Ready"
				_player_ready_labels[i].add_theme_color_override(
						"font_color", NOT_READY_COLOR)


## Clears all player rows to empty state.
func _update_empty_player_rows() -> void:
	for i: int in range(LobbyState.MAX_PLAYERS):
		_player_name_labels[i].text = "Waiting..."
		_player_name_labels[i].add_theme_color_override(
				"font_color", WAITING_COLOR)
		_player_ready_labels[i].text = ""


## Updates the status label.
func _update_status(lobby: LobbyState) -> void:
	if lobby.get_player_count() < LobbyState.MAX_PLAYERS:
		_status_label.text = "Waiting for opponent to join..."
	elif not lobby.is_all_ready():
		_status_label.text = "Waiting for all players to ready up."
	else:
		_status_label.text = "All players ready!"
		_status_label.add_theme_color_override("font_color",
				READY_COLOR)


## Updates button states based on lobby status.
func _update_buttons(lobby: LobbyState) -> void:
	_ready_button.text = "Not Ready" if _is_ready else "Ready"
	_start_button.visible = LobbyManager.is_host()
	_start_button.disabled = not lobby.can_start()


## Finds a player entry by player_index.
func _find_player_by_index(lobby: LobbyState,
		index: int) -> Dictionary:
	for p: Dictionary in lobby.players:
		if p.get("player_index", -1) == index:
			return p
	return {}


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

## Toggles the local player's ready status.
func _on_ready_pressed() -> void:
	_is_ready = not _is_ready
	LobbyManager.set_ready(_is_ready)
	_ready_button.text = "Not Ready" if _is_ready else "Ready"


## Requests the host to start the game.
func _on_start_pressed() -> void:
	LobbyManager.request_start_game()


## Leaves the lobby and returns to the main menu.
func _on_leave_pressed() -> void:
	LobbyManager.leave_lobby()
	leave_requested.emit()


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Lobby state updated — refresh display.
func _on_lobby_updated(_data: Dictionary) -> void:
	_update_display()


## Lobby created — refresh display.
func _on_lobby_created(_data: Dictionary) -> void:
	_update_display()


## Game starting — emit signal for scene transition.
func _on_game_starting() -> void:
	game_start_requested.emit()


## Lobby error — show in status label.
func _on_lobby_error(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color",
			UIStyleHelper.ERROR_RED)


## Re-centres the panel when the lobby becomes visible.
func _on_visibility_changed() -> void:
	if visible:
		call_deferred("_center_panel")


## Centres the panel on screen using viewport dimensions.
func _center_panel() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_panel.position = (vp - _panel.size) * 0.5
