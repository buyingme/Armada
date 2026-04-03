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
## Delay before the menu modal appears (seconds).
const SPLASH_DELAY: float = 2.0
## Duration for the toast notification (seconds).
const TOAST_DURATION: float = 2.0

## UI references built in [method _build_ui].
var _menu_panel: PanelContainer
var _toast_label: Label
var _splash_timer: Timer
var _toast_timer: Timer
## Whether the menu modal has been shown yet.
var _menu_shown: bool = false


func _ready() -> void:
	_build_ui()
	_start_splash_timer()


## Builds the entire UI tree in code: splash background, title text,
## menu modal (initially hidden), and toast label.
func _build_ui() -> void:
	# --- Splash background ---
	var bg: TextureRect = TextureRect.new()
	bg.texture = load(SPLASH_PATH) as Texture2D
	bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# --- Title labels — centred horizontally, positioned ~8% from top ---
	# (moved up by 1/4 screen compared to the original top-1/3 placement)
	var title_armada: Label = Label.new()
	title_armada.text = "ARMADA"
	title_armada.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_armada.add_theme_font_size_override("font_size", 128)
	title_armada.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
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
	title_digital.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95, 0.85))
	title_digital.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_digital.anchor_left = 0.0
	title_digital.anchor_right = 1.0
	title_digital.anchor_top = 0.08
	title_digital.anchor_bottom = 0.08
	title_digital.offset_top = 140.0
	title_digital.grow_vertical = Control.GROW_DIRECTION_END
	add_child(title_digital)

	# --- Menu modal (initially hidden) ---
	_menu_panel = _build_menu_modal()
	_menu_panel.visible = false
	add_child(_menu_panel)

	# --- Toast label (initially hidden) ---
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
	_toast_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
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

	# Standard modal style (ui_styling.md §1).
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.5, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	# Inner margin (ui_styling.md §3).
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

	# Modal title.
	var title: Label = Label.new()
	title.text = "Main Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	vbox.add_child(title)

	# Separator.
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# Buttons.
	var btn_new_game: Button = _create_menu_button("New Game")
	btn_new_game.pressed.connect(_on_new_game_pressed)
	vbox.add_child(btn_new_game)

	var btn_load_game: Button = _create_menu_button("Load Game")
	btn_load_game.pressed.connect(_on_load_game_pressed)
	vbox.add_child(btn_load_game)

	var btn_learning: Button = _create_menu_button("Learning Scenario")
	btn_learning.pressed.connect(_on_learning_scenario_pressed)
	vbox.add_child(btn_learning)

	# Extra space before Quit.
	var spacer: Control = Control.new()
	spacer.custom_minimum_size.y = 8.0
	vbox.add_child(spacer)

	var btn_quit: Button = _create_menu_button("Quit")
	btn_quit.pressed.connect(_on_quit_pressed)
	vbox.add_child(btn_quit)

	return panel


## Creates a standard menu button with consistent sizing.
func _create_menu_button(label_text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(200, 44)
	return btn


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


## Placeholder — shows "Coming Soon" toast. UI-032.
func _on_new_game_pressed() -> void:
	_show_toast("Coming Soon")


## Placeholder — shows "Coming Soon" toast. UI-032.
func _on_load_game_pressed() -> void:
	_show_toast("Coming Soon")


## Transitions to the learning scenario game board. UI-031.
func _on_learning_scenario_pressed() -> void:
	get_tree().change_scene_to_file(GAME_BOARD_PATH)


## Quits the application. UI-033.
func _on_quit_pressed() -> void:
	get_tree().quit()


## Shows a brief toast message near the bottom of the screen.
func _show_toast(message: String) -> void:
	_toast_label.text = message
	_toast_label.visible = true
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
