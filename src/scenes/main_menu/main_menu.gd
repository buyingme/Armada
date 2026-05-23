## Main Menu — Splash Screen & Menu
##
## Entry point scene for the game.  Shows a splash background with
## "ARMADA / digital" title text, then after 2 seconds (or any input)
## reveals a main-menu modal with game-mode buttons.
## Requirements: UI-029, UI-030, UI-031, UI-032, UI-033.
extends Control

## Path to the splash background image.
const SPLASH_PATH: String = "res://Resources/Game_Components/screen_art/splash.jpg"
## Path to the learning-scenario game board scene.
const GAME_BOARD_PATH: String = "res://src/scenes/game_board/game_board.tscn"
## Default scenario id used by the temporary new-game scenario picker.
const SCENARIO_LEARNING_ID: String = "learning_scenario"
## Debug scenario id used by the temporary new-game scenario picker.
const SCENARIO_DEBUG_ID: String = "debug_scenario"
## Delay before the menu modal appears (seconds).
const SPLASH_DELAY: float = 2.0
## Duration for the toast notification (seconds).
const TOAST_DURATION: float = 2.0

## UI references built in [method _build_ui].
var _menu_panel: PanelContainer
var _scenario_dialog: PanelContainer
var _host_dialog: PanelContainer
var _join_dialog: PanelContainer
var _prefs_dialog: PanelContainer
var _lobby_room: LobbyRoom
var _toast_label: Label
var _splash_timer: Timer
var _toast_timer: Timer
var _host_name_input: LineEdit
var _host_lobby_name_input: LineEdit
var _host_password_input: LineEdit
var _host_port_input: LineEdit
var _join_ip_input: LineEdit
var _join_name_input: LineEdit
var _join_password_input: LineEdit
var _join_port_input: LineEdit
var _join_error_label: Label
var _prefs_name_input: LineEdit
var _load_dialog: LoadGameDialog
var _scenario_option: OptionButton
## Whether the menu modal has been shown yet.
var _menu_shown: bool = false


func _ready() -> void:
	# Phase L0.5b — replay-driver bypass.  When the game is launched
	# with --replay in hot-seat mode, skip the splash + menu entirely
	# and load the game board directly so [ReplayDriver] can begin
	# submitting commands once [signal EventBus.game_started] fires.
	#
	# Network replays (--replay with --server or --connect) must NOT
	# bypass: the lobby bootstrap drives the
	# [signal LobbyManager.game_starting] → [code]_on_lobby_game_start[/code]
	# chain which sets [code]PlayMode.NETWORK[/code], installs the
	# correct command submitter, and only then changes scene.  If
	# we bypass for the host it loads the board as a hot-seat solo
	# game and the replay diverges before the client connects
	# (L0.5c fix).
	if ReplayDriver.enabled and not ReplayDriver.is_network_session():
		call_deferred("_enter_game_board_for_replay")
		return
	_build_ui()
	_start_splash_timer()
	MusicManager.play("rebel_theme")


## Replay-driver entry point: jump straight to the game board scene.
func _enter_game_board_for_replay() -> void:
	get_tree().change_scene_to_file(GAME_BOARD_PATH)


## Builds the entire UI tree in code: splash background, title text,
## menu modal (initially hidden), host/join dialogs, lobby room, and
## toast label.
func _build_ui() -> void:
	_build_splash_background()
	_build_title_labels()
	_menu_panel = _build_menu_modal()
	_menu_panel.visible = false
	add_child(_menu_panel)
	_scenario_dialog = _build_scenario_dialog()
	_scenario_dialog.visible = false
	add_child(_scenario_dialog)
	_host_dialog = _build_host_dialog()
	_host_dialog.visible = false
	add_child(_host_dialog)
	_join_dialog = _build_join_dialog()
	_join_dialog.visible = false
	add_child(_join_dialog)
	_prefs_dialog = _build_prefs_dialog()
	_prefs_dialog.visible = false
	add_child(_prefs_dialog)
	_lobby_room = LobbyRoom.new()
	_lobby_room.visible = false
	_lobby_room.leave_requested.connect(_on_lobby_leave)
	_lobby_room.game_start_requested.connect(_on_lobby_game_start)
	add_child(_lobby_room)
	_build_toast_label()


## Creates the full-screen splash background image.
func _build_splash_background() -> void:
	var bg: TextureRect = TextureRect.new()
	bg.texture = load(SPLASH_PATH) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


## Creates the "ARMADA" and "digital" title labels at the top of the screen.
func _build_title_labels() -> void:
	var title_armada: Label = Label.new()
	title_armada.text = "ARMADA"
	title_armada.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_armada.add_theme_font_size_override("font_size", 128)
	title_armada.add_theme_color_override("font_color",
			Color(1.0, 1.0, 1.0, 0.95))
	title_armada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_armada.anchor_left = 0.0
	title_armada.anchor_right = 1.0
	title_armada.anchor_top = 0.08
	title_armada.anchor_bottom = 0.08
	title_armada.grow_vertical = Control.GROW_DIRECTION_END
	add_child(title_armada)

	var title_digital: Label = Label.new()
	title_digital.text = "digital"
	title_digital.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_digital.add_theme_font_size_override("font_size", 72)
	title_digital.add_theme_color_override("font_color",
			Color(0.8, 0.85, 0.95, 0.85))
	title_digital.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_digital.anchor_left = 0.0
	title_digital.anchor_right = 1.0
	title_digital.anchor_top = 0.08
	title_digital.anchor_bottom = 0.08
	title_digital.offset_top = 140.0
	title_digital.grow_vertical = Control.GROW_DIRECTION_END
	add_child(title_digital)


## Creates the toast label (initially hidden) at the bottom of the screen.
func _build_toast_label() -> void:
	_toast_label = Label.new()
	_toast_label.text = ""
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_toast_label.offset_top = -80.0
	_toast_label.offset_bottom = -50.0
	_toast_label.offset_left = -150.0
	_toast_label.offset_right = 150.0
	_toast_label.add_theme_font_size_override("font_size", 16)
	_toast_label.add_theme_color_override("font_color",
			Color(0.9, 0.7, 0.3))
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.visible = false
	add_child(_toast_label)


## Constructs the menu modal PanelContainer with standard modal styling.
func _build_menu_modal() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.custom_minimum_size = Vector2(320, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
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
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	_populate_menu_vbox(vbox)
	return panel


## Adds title, separator, and game-mode buttons to [param vbox].
func _populate_menu_vbox(vbox: VBoxContainer) -> void:
	var title: Label = Label.new()
	title.text = "Main Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var btn_new_game: Button = _create_menu_button("New Game")
	btn_new_game.pressed.connect(_on_new_game_pressed)
	vbox.add_child(btn_new_game)

	var btn_load_game: Button = _create_menu_button("Load Game")
	btn_load_game.pressed.connect(_on_load_game_pressed)
	vbox.add_child(btn_load_game)

	var btn_host: Button = _create_menu_button("Host Game")
	btn_host.pressed.connect(_on_host_game_pressed)
	vbox.add_child(btn_host)

	var btn_join: Button = _create_menu_button("Join Game")
	btn_join.pressed.connect(_on_join_game_pressed)
	vbox.add_child(btn_join)

	vbox.add_child(HSeparator.new())

	var btn_prefs: Button = _create_menu_button("Preferences")
	btn_prefs.pressed.connect(_on_prefs_pressed)
	vbox.add_child(btn_prefs)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 8.0
	vbox.add_child(spacer)

	var btn_quit: Button = _create_menu_button("Quit")
	btn_quit.pressed.connect(_on_quit_pressed)
	vbox.add_child(btn_quit)


## Creates a standard menu button with consistent sizing.
func _create_menu_button(label_text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(200, 44)
	return btn


## Builds the temporary new-game scenario picker.
func _build_scenario_dialog() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 0)
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
	_populate_scenario_dialog(vbox)
	return panel


func _populate_scenario_dialog(vbox: VBoxContainer) -> void:
	vbox.add_child(UIStyleHelper.create_title_label(
			"New Game", UIStyleHelper.GOLD_TITLE))
	vbox.add_child(HSeparator.new())
	_scenario_option = OptionButton.new()
	_scenario_option.custom_minimum_size = Vector2(260, 36)
	_add_scenario_option("Learning Scenario", SCENARIO_LEARNING_ID)
	_add_scenario_option("Debug Scenario", SCENARIO_DEBUG_ID)
	vbox.add_child(_scenario_option)
	vbox.add_child(_build_scenario_dialog_buttons())


func _add_scenario_option(label_text: String, scenario_id: String) -> void:
	_scenario_option.add_item(label_text)
	var index: int = _scenario_option.get_item_count() - 1
	_scenario_option.set_item_metadata(index, scenario_id)


func _build_scenario_dialog_buttons() -> HBoxContainer:
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	var start_btn: Button = _create_menu_button("Start")
	start_btn.pressed.connect(_on_scenario_start_pressed)
	buttons.add_child(start_btn)
	var cancel_btn: Button = _create_menu_button("Cancel")
	cancel_btn.pressed.connect(_on_scenario_cancel_pressed)
	buttons.add_child(cancel_btn)
	return buttons


## Starts the splash delay timer. UI-030.
func _start_splash_timer() -> void:
	_splash_timer = Timer.new()
	_splash_timer.wait_time = SPLASH_DELAY
	_splash_timer.one_shot = true
	_splash_timer.timeout.connect(_show_menu)
	add_child(_splash_timer)
	_splash_timer.start()


## Any input during the splash delay skips the timer. UI-030.
func _unhandled_input(event: InputEvent) -> void:
	if not _menu_shown and event is InputEventKey or event is InputEventMouseButton:
		if event is InputEventKey and not event.pressed:
			return
		if event is InputEventMouseButton and not event.pressed:
			return
		_show_menu()
		get_viewport().set_input_as_handled()


## Reveals the main-menu modal. Called by timer or input skip.
func _show_menu() -> void:
	if _menu_shown:
		return
	_menu_shown = true
	if _splash_timer and not _splash_timer.is_stopped():
		_splash_timer.stop()
	_menu_panel.visible = true


## Opens the temporary scenario picker for starting a new hot-seat game.
func _on_new_game_pressed() -> void:
	SfxManager.play_sfx("droid_sound_long")
	_menu_panel.visible = false
	_scenario_option.select(0)
	_scenario_dialog.visible = true


## Placeholder — opens the LoadGameDialog (Phase J5).
func _on_load_game_pressed() -> void:
	SfxManager.play_sfx("droid_sound_long")
	if _load_dialog == null:
		_load_dialog = LoadGameDialog.new()
		_load_dialog.transition_to_board_on_load = true
		_load_dialog.context = "main_menu"
		_load_dialog.cancelled.connect(_on_load_dialog_cancelled)
		add_child(_load_dialog)
	_menu_panel.visible = false
	_load_dialog.show_modal()


func _on_load_dialog_cancelled() -> void:
	_menu_panel.visible = true


## Transitions to the learning scenario game board. UI-031.
func _on_learning_scenario_pressed() -> void:
	SfxManager.play_sfx("droid_sound_long")
	_start_scenario(SCENARIO_LEARNING_ID)


func _on_scenario_start_pressed() -> void:
	SfxManager.play_sfx("droid_sound_long")
	_start_scenario(_selected_scenario_id())


func _on_scenario_cancel_pressed() -> void:
	SfxManager.play_sfx("droid_sound_long")
	_scenario_dialog.visible = false
	_menu_panel.visible = true


func _start_scenario(scenario_id: String) -> void:
	GameManager.set_next_scenario_id(scenario_id)
	get_tree().change_scene_to_file(GAME_BOARD_PATH)


func _selected_scenario_id() -> String:
	var selected: int = _scenario_option.selected
	if selected < 0:
		return SCENARIO_LEARNING_ID
	var metadata: Variant = _scenario_option.get_item_metadata(selected)
	if metadata is String:
		return metadata as String
	return SCENARIO_LEARNING_ID


## Shows the host-game dialog. G4.5.5.
func _on_host_game_pressed() -> void:
	SfxManager.play_sfx("droid_sound_long")
	_menu_panel.visible = false
	_host_name_input.text = PlayerProfile.get_display_name()
	_host_lobby_name_input.text = ""
	_host_password_input.text = ""
	_host_port_input.text = str(ServerMain.DEFAULT_PORT)
	_host_dialog.visible = true
	_host_name_input.grab_focus()


## Shows the join-game dialog. G4.5.5.
func _on_join_game_pressed() -> void:
	SfxManager.play_sfx("droid_sound_long")
	_menu_panel.visible = false
	_join_name_input.text = PlayerProfile.get_display_name()
	_join_ip_input.text = ""
	_join_password_input.text = ""
	_join_port_input.text = str(ServerMain.DEFAULT_PORT)
	_join_error_label.text = ""
	_join_error_label.visible = false
	_join_dialog.visible = true
	_join_name_input.grab_focus()


## Quits the application. UI-033.
func _on_quit_pressed() -> void:
	SfxManager.play_sfx("droid_sound_long")
	get_tree().quit()


## Shows the preferences dialog.
func _on_prefs_pressed() -> void:
	SfxManager.play_sfx("droid_sound_long")
	_menu_panel.visible = false
	_prefs_name_input.text = PlayerProfile.get_display_name()
	_prefs_dialog.visible = true
	_prefs_name_input.grab_focus()


# ---------------------------------------------------------------------------
# Preferences dialog
# ---------------------------------------------------------------------------

## Builds the preferences dialog panel.
func _build_prefs_dialog() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
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
	_populate_prefs_dialog(vbox)
	return panel


## Populates the preferences dialog content.
func _populate_prefs_dialog(vbox: VBoxContainer) -> void:
	vbox.add_child(UIStyleHelper.create_title_label(
			"Preferences", UIStyleHelper.GOLD_TITLE))
	vbox.add_child(HSeparator.new())
	var name_label: Label = UIStyleHelper.create_section_label(
			"Player Name:", UIStyleHelper.FONT_BODY,
			UIStyleHelper.BODY_TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(name_label)
	_prefs_name_input = LineEdit.new()
	_prefs_name_input.placeholder_text = "Enter your name"
	_prefs_name_input.max_length = LobbyState.MAX_NAME_LENGTH
	_prefs_name_input.custom_minimum_size.y = 36
	vbox.add_child(_prefs_name_input)
	var btn_box: HBoxContainer = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_box)
	var btn_save: Button = _create_menu_button("Save")
	btn_save.pressed.connect(_on_prefs_save_pressed)
	btn_box.add_child(btn_save)
	var btn_cancel: Button = _create_menu_button("Cancel")
	btn_cancel.pressed.connect(_on_prefs_cancel_pressed)
	btn_box.add_child(btn_cancel)


## Saves preferences and returns to menu.
func _on_prefs_save_pressed() -> void:
	var new_name: String = _prefs_name_input.text.strip_edges()
	if new_name.is_empty():
		_show_toast("Please enter a name.")
		return
	PlayerProfile.set_display_name(new_name)
	_prefs_dialog.visible = false
	_menu_panel.visible = true
	_show_toast("Name saved: %s" % PlayerProfile.get_display_name())


## Cancels preferences dialog and returns to menu.
func _on_prefs_cancel_pressed() -> void:
	_prefs_dialog.visible = false
	_menu_panel.visible = true


# ---------------------------------------------------------------------------
# Host dialog (G4.5.5)
# ---------------------------------------------------------------------------

## Builds the host-game dialog panel.
func _build_host_dialog() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
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
	_populate_host_dialog(vbox)
	return panel


## Populates the host-game dialog content.
func _populate_host_dialog(vbox: VBoxContainer) -> void:
	vbox.add_child(UIStyleHelper.create_title_label(
			"Host Game", UIStyleHelper.GOLD_TITLE))
	vbox.add_child(HSeparator.new())
	var pname_label: Label = UIStyleHelper.create_section_label(
			"Your Name:", UIStyleHelper.FONT_BODY,
			UIStyleHelper.BODY_TEXT)
	pname_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(pname_label)
	_host_name_input = LineEdit.new()
	_host_name_input.placeholder_text = "Enter your name"
	_host_name_input.max_length = LobbyState.MAX_NAME_LENGTH
	_host_name_input.custom_minimum_size.y = 36
	vbox.add_child(_host_name_input)
	var lobby_label: Label = UIStyleHelper.create_section_label(
			"Lobby Name:", UIStyleHelper.FONT_BODY,
			UIStyleHelper.BODY_TEXT)
	lobby_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(lobby_label)
	_host_lobby_name_input = LineEdit.new()
	_host_lobby_name_input.placeholder_text = "My Game"
	_host_lobby_name_input.max_length = LobbyState.MAX_NAME_LENGTH
	_host_lobby_name_input.custom_minimum_size.y = 36
	vbox.add_child(_host_lobby_name_input)
	var pw_label: Label = UIStyleHelper.create_section_label(
			"Password (optional):", UIStyleHelper.FONT_BODY,
			UIStyleHelper.BODY_TEXT)
	pw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(pw_label)
	_host_password_input = LineEdit.new()
	_host_password_input.placeholder_text = "Leave blank for open lobby"
	_host_password_input.secret = true
	_host_password_input.custom_minimum_size.y = 36
	vbox.add_child(_host_password_input)
	var port_label: Label = UIStyleHelper.create_section_label(
			"Port:", UIStyleHelper.FONT_BODY,
			UIStyleHelper.BODY_TEXT)
	port_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(port_label)
	_host_port_input = LineEdit.new()
	_host_port_input.text = str(ServerMain.DEFAULT_PORT)
	_host_port_input.placeholder_text = str(ServerMain.DEFAULT_PORT)
	_host_port_input.custom_minimum_size.y = 36
	vbox.add_child(_host_port_input)
	var btn_box: HBoxContainer = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_box)
	var btn_confirm: Button = _create_menu_button("Host")
	btn_confirm.pressed.connect(_on_host_confirm_pressed)
	btn_box.add_child(btn_confirm)
	var btn_cancel: Button = _create_menu_button("Cancel")
	btn_cancel.pressed.connect(_on_host_cancel_pressed)
	btn_box.add_child(btn_cancel)


## Confirms hosting and transitions to the lobby room.
func _on_host_confirm_pressed() -> void:
	var player_name: String = _host_name_input.text.strip_edges()
	if player_name.is_empty():
		_show_toast("Please enter your name.")
		return
	PlayerProfile.set_display_name(player_name)
	var lobby_name: String = _host_lobby_name_input.text.strip_edges()
	if lobby_name.is_empty():
		lobby_name = PlayerProfile.get_display_name() + "'s Game"
	var password: String = _host_password_input.text
	var port: int = _parse_port(_host_port_input.text)
	if port <= 0:
		_show_toast("Invalid port (1–65535).")
		return
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	if not NetworkManager.host(port):
		_show_toast("Failed to host game.")
		_host_dialog.visible = false
		_menu_panel.visible = true
		return
	LobbyManager.create_lobby(lobby_name, password)
	_host_dialog.visible = false
	_show_lobby_room()


## Cancels host dialog and returns to the menu.
func _on_host_cancel_pressed() -> void:
	_host_dialog.visible = false
	_menu_panel.visible = true


# ---------------------------------------------------------------------------
# Join dialog (G4.5.5)
# ---------------------------------------------------------------------------

## Builds the join-game dialog panel.
func _build_join_dialog() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.custom_minimum_size = Vector2(360, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
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
	_populate_join_dialog(vbox)
	return panel


## Populates the join-game dialog content.
func _populate_join_dialog(vbox: VBoxContainer) -> void:
	vbox.add_child(UIStyleHelper.create_title_label(
			"Join Game", UIStyleHelper.GOLD_TITLE))
	vbox.add_child(HSeparator.new())
	var pname_label: Label = UIStyleHelper.create_section_label(
			"Your Name:", UIStyleHelper.FONT_BODY,
			UIStyleHelper.BODY_TEXT)
	pname_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(pname_label)
	_join_name_input = LineEdit.new()
	_join_name_input.placeholder_text = "Enter your name"
	_join_name_input.max_length = LobbyState.MAX_NAME_LENGTH
	_join_name_input.custom_minimum_size.y = 36
	vbox.add_child(_join_name_input)
	var ip_label: Label = UIStyleHelper.create_section_label(
			"Server IP Address:", UIStyleHelper.FONT_BODY,
			UIStyleHelper.BODY_TEXT)
	ip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(ip_label)
	_join_ip_input = LineEdit.new()
	_join_ip_input.text = "127.0.0.1"
	_join_ip_input.placeholder_text = "127.0.0.1"
	_join_ip_input.custom_minimum_size.y = 36
	vbox.add_child(_join_ip_input)
	var pw_label: Label = UIStyleHelper.create_section_label(
			"Password (if required):", UIStyleHelper.FONT_BODY,
			UIStyleHelper.BODY_TEXT)
	pw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(pw_label)
	_join_password_input = LineEdit.new()
	_join_password_input.placeholder_text = "Leave blank if none"
	_join_password_input.secret = true
	_join_password_input.custom_minimum_size.y = 36
	vbox.add_child(_join_password_input)
	var port_label: Label = UIStyleHelper.create_section_label(
			"Port:", UIStyleHelper.FONT_BODY,
			UIStyleHelper.BODY_TEXT)
	port_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(port_label)
	_join_port_input = LineEdit.new()
	_join_port_input.text = str(ServerMain.DEFAULT_PORT)
	_join_port_input.placeholder_text = str(ServerMain.DEFAULT_PORT)
	_join_port_input.custom_minimum_size.y = 36
	vbox.add_child(_join_port_input)
	_join_error_label = Label.new()
	_join_error_label.text = ""
	_join_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_error_label.add_theme_font_size_override("font_size",
			UIStyleHelper.FONT_BODY)
	_join_error_label.add_theme_color_override("font_color",
			UIStyleHelper.ERROR_RED)
	_join_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_join_error_label.visible = false
	vbox.add_child(_join_error_label)
	var btn_box: HBoxContainer = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_box)
	var btn_confirm: Button = _create_menu_button("Connect")
	btn_confirm.pressed.connect(_on_join_confirm_pressed)
	btn_box.add_child(btn_confirm)
	var btn_cancel: Button = _create_menu_button("Cancel")
	btn_cancel.pressed.connect(_on_join_cancel_pressed)
	btn_box.add_child(btn_cancel)


## Confirms joining and initiates connection to the server.
func _on_join_confirm_pressed() -> void:
	var player_name: String = _join_name_input.text.strip_edges()
	if player_name.is_empty():
		_show_toast("Please enter your name.")
		return
	PlayerProfile.set_display_name(player_name)
	var ip: String = _join_ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var password: String = _join_password_input.text
	var port: int = _parse_port(_join_port_input.text)
	if port <= 0:
		_join_error_label.text = "Invalid port (1–65535)."
		_join_error_label.visible = true
		return
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.set_lobby_password(password)
	NetworkManager.handshake_accepted.connect(
			_on_join_accepted, CONNECT_ONE_SHOT)
	NetworkManager.handshake_rejected.connect(
			_on_join_rejected, CONNECT_ONE_SHOT)
	if not NetworkManager.connect_to_server(ip, port):
		_show_toast("Failed to connect.")
		_disconnect_join_signals()
		return
	_show_toast("Connecting...")


## Cancels join dialog and returns to the menu.
func _on_join_cancel_pressed() -> void:
	_join_dialog.visible = false
	_menu_panel.visible = true


## Handshake accepted — transition to lobby room.
func _on_join_accepted(_player_index: int) -> void:
	_disconnect_join_signals()
	_join_dialog.visible = false
	_show_lobby_room()


## Handshake rejected — show error inside the join dialog.
func _on_join_rejected(reason: String) -> void:
	_disconnect_join_signals()
	_join_error_label.text = reason
	_join_error_label.visible = true


## Disconnects one-shot join signals if still connected.
func _disconnect_join_signals() -> void:
	if NetworkManager.handshake_accepted.is_connected(_on_join_accepted):
		NetworkManager.handshake_accepted.disconnect(_on_join_accepted)
	if NetworkManager.handshake_rejected.is_connected(_on_join_rejected):
		NetworkManager.handshake_rejected.disconnect(_on_join_rejected)


# ---------------------------------------------------------------------------
# Lobby room transitions (G4.5.5)
# ---------------------------------------------------------------------------

## Shows the lobby room and hides other panels.
func _show_lobby_room() -> void:
	_menu_panel.visible = false
	_host_dialog.visible = false
	_join_dialog.visible = false
	_lobby_room.visible = true


## Called when the user leaves the lobby room.
func _on_lobby_leave() -> void:
	_lobby_room.visible = false
	_menu_panel.visible = true


## Called when the game is starting from the lobby.
## Sets the play mode to NETWORK and swaps the command submitter before
## transitioning to the game board scene.
## G4.6.5.1 — submitter swap on game start.
func _on_lobby_game_start() -> void:
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	if NetworkManager.is_server():
		GameManager.set_command_submitter(NetworkHostCommandSubmitter.new())
	else:
		GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	get_tree().change_scene_to_file(GAME_BOARD_PATH)


## Parses a port string and returns the port if valid (1..65535),
## otherwise returns 0.  Whitespace is trimmed; empty input is invalid.
func _parse_port(text: String) -> int:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty() or not trimmed.is_valid_int():
		return 0
	var port: int = trimmed.to_int()
	if port < 1 or port > 65535:
		return 0
	return port


## Shows a brief toast message near the bottom of the screen.
func _show_toast(message: String) -> void:
	_toast_label.text = message
	_toast_label.visible = true
	move_child(_toast_label, get_child_count() - 1)
	if _toast_timer:
		_toast_timer.stop()
		_toast_timer.queue_free()
	_toast_timer = Timer.new()
	_toast_timer.wait_time = TOAST_DURATION
	_toast_timer.one_shot = true
	_toast_timer.timeout.connect(_hide_toast)
	add_child(_toast_timer)
	_toast_timer.start()


## Hides the toast label.
func _hide_toast() -> void:
	_toast_label.visible = false
