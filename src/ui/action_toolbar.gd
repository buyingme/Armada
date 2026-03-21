## ActionToolbar
##
## Lower-right toolbar that hosts action buttons for the game board.
## Contains the tooltip toggle (relocated from TooltipManager) and
## the "Display Maneuver Tool" button.
##
## Requirements: MT-U-001, MT-U-002, AC-13.
class_name ActionToolbar
extends HBoxContainer


## Logger.
var _log: GameLogger = GameLogger.new("ActionToolbar")

## Reference to the tooltip toggle button (reparented from TooltipManager).
var _tooltip_toggle: Button = null

## "Display Maneuver Tool" button.
var _maneuver_tool_btn: Button = null


func _init() -> void:
	name = "ActionToolbar"
	add_theme_constant_override("separation", 4)


## Sets up the toolbar after being added to the scene tree.
## Reparents the tooltip toggle and creates the maneuver tool button.
func setup_buttons() -> void:
	_reparent_tooltip_toggle()
	_create_maneuver_tool_button()
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


## Enables or disables the simulation maneuver button.
## [param disabled] — when [code]true[/code], the button is greyed-out
## and ignores clicks (used while the activation-mode maneuver tool is active).
func set_maneuver_button_disabled(disabled: bool) -> void:
	if _maneuver_tool_btn:
		_maneuver_tool_btn.disabled = disabled


## Deferred position update after layout calculates sizes.
func _deferred_position() -> void:
	if not is_inside_tree():
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	update_position(vp_size)
