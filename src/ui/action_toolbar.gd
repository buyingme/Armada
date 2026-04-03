## ActionToolbar
##
## Lower-right toolbar that hosts action buttons for the game board.
## Contains the tooltip toggle (relocated from TooltipManager),
## the "Display Maneuver Tool" button (M), the "Range Overlay" button (R),
## the "Targeting List" button (T), the "Attack Simulator" button (A),
## and audio controls (play/pause, next track, volume ±).
##
## Requirements: MT-U-001, MT-U-002, RO-001, TL-UI-001, AC-13,
## MUS-011–MUS-014.
class_name ActionToolbar
extends HBoxContainer


## Logger.
var _log: GameLogger = GameLogger.new("ActionToolbar")

## Reference to the tooltip toggle button (reparented from TooltipManager).
var _tooltip_toggle: Button = null

## "Display Maneuver Tool" button.
var _maneuver_tool_btn: Button = null

## "Range Overlay" button.
var _range_overlay_btn: Button = null

## "Targeting List" button.
var _targeting_list_btn: Button = null

## "Attack Simulator" button.
var _attack_sim_btn: Button = null

## Music play/pause toggle button.
var _music_toggle_btn: Button = null

## Next track button.
var _music_next_btn: Button = null

## Volume down button.
var _vol_down_btn: Button = null

## Volume up button.
var _vol_up_btn: Button = null


func _init() -> void:
	name = "ActionToolbar"
	add_theme_constant_override("separation", 4)


## Sets up the toolbar after being added to the scene tree.
## Reparents the tooltip toggle and creates the action buttons.
func setup_buttons() -> void:
	_reparent_tooltip_toggle()
	_create_maneuver_tool_button()
	_create_range_overlay_button()
	_create_targeting_list_button()
	_create_attack_sim_button()
	_create_audio_separator()
	_create_music_toggle_button()
	_create_music_next_button()
	_create_vol_down_button()
	_create_vol_up_button()
	call_deferred("_deferred_position")


## Positions the toolbar at the lower-right corner of the screen.
## [param viewport_size] — current viewport dimensions.
func update_position(viewport_size: Vector2) -> void:
	var pad: float = GameScale.tooltip_toggle_button_edge_padding
	position = Vector2(
			viewport_size.x - size.x - pad,
			viewport_size.y - size.y - pad)


## Reparents the tooltip toggle from TooltipManager's canvas layer.
func _reparent_tooltip_toggle() -> void:
	_tooltip_toggle = TooltipManager.get_toggle_button()
	if _tooltip_toggle == null:
		_log.warn("Tooltip toggle button not found.")
		return
	if _tooltip_toggle.get_parent():
		_tooltip_toggle.get_parent().remove_child(_tooltip_toggle)
	_reset_control_layout(_tooltip_toggle)
	add_child(_tooltip_toggle)


## Creates the maneuver tool button.
func _create_maneuver_tool_button() -> void:
	_maneuver_tool_btn = Button.new()
	_maneuver_tool_btn.name = "ManeuverToolButton"
	_maneuver_tool_btn.text = "M"
	_maneuver_tool_btn.flat = true
	var btn_size: float = GameScale.tooltip_toggle_button_size
	_maneuver_tool_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	_maneuver_tool_btn.add_theme_font_size_override("font_size", 16)
	_maneuver_tool_btn.add_theme_color_override(
			"font_color", Color(1.0, 1.0, 1.0, 0.7))
	_maneuver_tool_btn.add_theme_color_override(
			"font_hover_color", Color.WHITE)
	_maneuver_tool_btn.tooltip_text = "Display Maneuver Tool"
	_maneuver_tool_btn.pressed.connect(_on_maneuver_tool_pressed)
	add_child(_maneuver_tool_btn)


## Resets a Control's anchor/offset for container layout.
func _reset_control_layout(ctrl: Control) -> void:
	ctrl.anchors_preset = Control.PRESET_TOP_LEFT
	ctrl.anchor_left = 0.0
	ctrl.anchor_top = 0.0
	ctrl.anchor_right = 0.0
	ctrl.anchor_bottom = 0.0
	ctrl.offset_left = 0.0
	ctrl.offset_top = 0.0
	ctrl.offset_right = 0.0
	ctrl.offset_bottom = 0.0


## Emits the maneuver tool request signal.
func _on_maneuver_tool_pressed() -> void:
	_log.info("Maneuver Tool button pressed.")
	EventBus.maneuver_tool_requested.emit()


## Creates the range overlay button.
## Requirements: RO-001.
func _create_range_overlay_button() -> void:
	_range_overlay_btn = Button.new()
	_range_overlay_btn.name = "RangeOverlayButton"
	_range_overlay_btn.text = "R"
	_range_overlay_btn.flat = true
	var btn_size: float = GameScale.tooltip_toggle_button_size
	_range_overlay_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	_range_overlay_btn.add_theme_font_size_override("font_size", 16)
	_range_overlay_btn.add_theme_color_override(
			"font_color", Color(1.0, 1.0, 1.0, 0.7))
	_range_overlay_btn.add_theme_color_override(
			"font_hover_color", Color.WHITE)
	_range_overlay_btn.tooltip_text = "Range Overlay"
	_range_overlay_btn.pressed.connect(_on_range_overlay_pressed)
	add_child(_range_overlay_btn)


## Emits the range overlay request signal.
## Requirements: RO-002.
func _on_range_overlay_pressed() -> void:
	_log.info("Range Overlay button pressed.")
	EventBus.range_overlay_requested.emit()


## Creates the targeting list button.
## Requirements: TL-UI-001.
func _create_targeting_list_button() -> void:
	_targeting_list_btn = Button.new()
	_targeting_list_btn.name = "TargetingListButton"
	_targeting_list_btn.text = "T"
	_targeting_list_btn.flat = true
	var btn_size: float = GameScale.tooltip_toggle_button_size
	_targeting_list_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	_targeting_list_btn.add_theme_font_size_override("font_size", 16)
	_targeting_list_btn.add_theme_color_override(
			"font_color", Color(1.0, 1.0, 1.0, 0.7))
	_targeting_list_btn.add_theme_color_override(
			"font_hover_color", Color.WHITE)
	_targeting_list_btn.tooltip_text = "Targeting List"
	_targeting_list_btn.pressed.connect(_on_targeting_list_pressed)
	add_child(_targeting_list_btn)


## Emits the targeting list request signal.
## Requirements: TL-UI-001.
func _on_targeting_list_pressed() -> void:
	_log.info("Targeting List button pressed.")
	EventBus.targeting_list_requested.emit()


## Creates the attack simulator button.
## Requirements: AS-ACT-001.
func _create_attack_sim_button() -> void:
	_attack_sim_btn = Button.new()
	_attack_sim_btn.name = "AttackSimButton"
	_attack_sim_btn.text = "A"
	_attack_sim_btn.flat = true
	var btn_size: float = GameScale.tooltip_toggle_button_size
	_attack_sim_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	_attack_sim_btn.add_theme_font_size_override("font_size", 16)
	_attack_sim_btn.add_theme_color_override(
			"font_color", Color(1.0, 1.0, 1.0, 0.7))
	_attack_sim_btn.add_theme_color_override(
			"font_hover_color", Color.WHITE)
	_attack_sim_btn.tooltip_text = "Attack Simulator"
	_attack_sim_btn.pressed.connect(_on_attack_sim_pressed)
	add_child(_attack_sim_btn)


## Emits the attack simulator request signal.
## Requirements: AS-ACT-001.
func _on_attack_sim_pressed() -> void:
	_log.info("Attack Simulator button pressed.")
	EventBus.attack_simulator_requested.emit()


# ---------------------------------------------------------------------------
# Audio controls
# ---------------------------------------------------------------------------

## Creates a thin vertical separator between tool buttons and audio controls.
func _create_audio_separator() -> void:
	var sep: VSeparator = VSeparator.new()
	sep.name = "AudioSeparator"
	sep.custom_minimum_size = Vector2(8, 0)
	sep.add_theme_constant_override("separation", 0)
	sep.modulate = Color(1.0, 1.0, 1.0, 0.3)
	add_child(sep)


## Creates the music play/pause toggle button.
## Requirements: MUS-011.
func _create_music_toggle_button() -> void:
	_music_toggle_btn = Button.new()
	_music_toggle_btn.name = "MusicToggleButton"
	_music_toggle_btn.text = "\u23f8"
	_music_toggle_btn.flat = true
	var btn_size: float = GameScale.tooltip_toggle_button_size
	_music_toggle_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	_music_toggle_btn.add_theme_font_size_override("font_size", 14)
	_music_toggle_btn.add_theme_color_override(
			"font_color", Color(1.0, 1.0, 1.0, 0.7))
	_music_toggle_btn.add_theme_color_override(
			"font_hover_color", Color.WHITE)
	_music_toggle_btn.tooltip_text = "Pause / Resume Music"
	_music_toggle_btn.pressed.connect(_on_music_toggle_pressed)
	add_child(_music_toggle_btn)


## Creates the next-track button.
## Requirements: MUS-012.
func _create_music_next_button() -> void:
	_music_next_btn = Button.new()
	_music_next_btn.name = "MusicNextButton"
	_music_next_btn.text = "\u23ed"
	_music_next_btn.flat = true
	var btn_size: float = GameScale.tooltip_toggle_button_size
	_music_next_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	_music_next_btn.add_theme_font_size_override("font_size", 14)
	_music_next_btn.add_theme_color_override(
			"font_color", Color(1.0, 1.0, 1.0, 0.7))
	_music_next_btn.add_theme_color_override(
			"font_hover_color", Color.WHITE)
	_music_next_btn.tooltip_text = "Next Track"
	_music_next_btn.pressed.connect(_on_music_next_pressed)
	add_child(_music_next_btn)


## Creates the volume-down button.
## Requirements: MUS-013.
func _create_vol_down_button() -> void:
	_vol_down_btn = Button.new()
	_vol_down_btn.name = "VolDownButton"
	_vol_down_btn.text = "\u2212"
	_vol_down_btn.flat = true
	var btn_size: float = GameScale.tooltip_toggle_button_size
	_vol_down_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	_vol_down_btn.add_theme_font_size_override("font_size", 16)
	_vol_down_btn.add_theme_color_override(
			"font_color", Color(1.0, 1.0, 1.0, 0.7))
	_vol_down_btn.add_theme_color_override(
			"font_hover_color", Color.WHITE)
	_vol_down_btn.tooltip_text = "Volume Down"
	_vol_down_btn.pressed.connect(_on_vol_down_pressed)
	add_child(_vol_down_btn)


## Creates the volume-up button.
## Requirements: MUS-013.
func _create_vol_up_button() -> void:
	_vol_up_btn = Button.new()
	_vol_up_btn.name = "VolUpButton"
	_vol_up_btn.text = "+"
	_vol_up_btn.flat = true
	var btn_size: float = GameScale.tooltip_toggle_button_size
	_vol_up_btn.custom_minimum_size = Vector2(btn_size, btn_size)
	_vol_up_btn.add_theme_font_size_override("font_size", 16)
	_vol_up_btn.add_theme_color_override(
			"font_color", Color(1.0, 1.0, 1.0, 0.7))
	_vol_up_btn.add_theme_color_override(
			"font_hover_color", Color.WHITE)
	_vol_up_btn.tooltip_text = "Volume Up"
	_vol_up_btn.pressed.connect(_on_vol_up_pressed)
	add_child(_vol_up_btn)


## Toggles music play/pause and updates the button label.
func _on_music_toggle_pressed() -> void:
	MusicManager.toggle_pause()
	_update_toggle_label()
	SfxManager.play_sfx("skip_beep")


## Skips to the next track in the playlist.
func _on_music_next_pressed() -> void:
	MusicManager.skip_to_next()
	_update_toggle_label()
	SfxManager.play_sfx("skip_beep")


## Decreases music volume by one step.
func _on_vol_down_pressed() -> void:
	var current: int = MusicManager.get_volume_percent()
	MusicManager.set_volume_percent(current - 10)
	SfxManager.play_sfx("skip_beep")


## Increases music volume by one step.
func _on_vol_up_pressed() -> void:
	var current: int = MusicManager.get_volume_percent()
	MusicManager.set_volume_percent(current + 10)
	SfxManager.play_sfx("skip_beep")


## Updates the play/pause button label to reflect current state.
func _update_toggle_label() -> void:
	if _music_toggle_btn == null:
		return
	_music_toggle_btn.text = "\u25b6" if MusicManager.is_paused() else "\u23f8"


## Enables or disables the simulation tool buttons (M, R, T, A).
## [param disabled] — when [code]true[/code], the buttons are greyed-out
## and ignore clicks (used while the activation-mode maneuver tool is active).
func set_tool_buttons_disabled(disabled: bool) -> void:
	if _maneuver_tool_btn:
		_maneuver_tool_btn.disabled = disabled
	if _range_overlay_btn:
		_range_overlay_btn.disabled = disabled
	if _targeting_list_btn:
		_targeting_list_btn.disabled = disabled
	if _attack_sim_btn:
		_attack_sim_btn.disabled = disabled


## Deferred position update after layout calculates sizes.
func _deferred_position() -> void:
	if not is_inside_tree():
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	update_position(vp_size)
