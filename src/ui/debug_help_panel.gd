## DebugHelpPanel
##
## Screen-space panel listing all debug-mode keyboard shortcuts and controls.
## Displayed on the left side of the viewport when debug mode is active.
##
## This is a pure UI widget — it reads no game state and emits no signals.
## Parent is responsible for adding it to a CanvasLayer and toggling visibility.
##
## Requirements: DBG-002 (debug HUD)
class_name DebugHelpPanel
extends PanelContainer


## Width of the panel in screen pixels.
const PANEL_WIDTH_PX: int = 260

## Vertical margin from the top of the viewport.
const MARGIN_TOP_PX: int = 10

## Horizontal margin from the left edge.
const MARGIN_LEFT_PX: int = 10

## Font size for the header line.
const HEADER_FONT_SIZE: int = 18

## Font size for the body text.
const BODY_FONT_SIZE: int = 14

## Text colour for the header.
const HEADER_COLOUR: Color = Color(1.0, 0.3, 0.3)

## Text colour for the body lines.
const BODY_COLOUR: Color = Color(0.85, 0.85, 0.85)

## Semi-transparent dark background.
const BG_COLOUR: Color = Color(0.08, 0.08, 0.15, 0.85)


func _ready() -> void:
	_build_ui()


## Constructs the panel layout.
func _build_ui() -> void:
	_apply_panel_style()
	position = Vector2(MARGIN_LEFT_PX, MARGIN_TOP_PX)
	custom_minimum_size = Vector2(PANEL_WIDTH_PX, 0)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)
	_populate_shortcut_entries(vbox)


## Applies the debug panel's background style.
func _apply_panel_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BG_COLOUR
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", style)


## Populates all section headers, separators, and shortcut lines.
func _populate_shortcut_entries(vbox: VBoxContainer) -> void:
	_add_header(vbox, "DEBUG MODE")
	_add_separator(vbox)
	_add_line(vbox, "F12", "Toggle debug mode")
	_add_line(vbox, "Left-click token", "Select / deselect")
	_add_line(vbox, "Left-click empty", "Deselect token")
	_add_line(vbox, "Move mouse", "Drag selected token")
	_add_line(vbox, "Two-finger rotate", "Rotate selected token")
	_add_line(vbox, "Ctrl + S", "Save positions to JSON")
	_add_separator(vbox)
	_add_section_header(vbox, "Camera")
	_add_line(vbox, "Right-click drag", "Pan camera")
	_add_line(vbox, "Scroll wheel", "Zoom in / out")
	_add_line(vbox, "Two-finger swipe", "Pan camera (trackpad)")
	_add_line(vbox, "Pinch", "Zoom (trackpad)")
	_add_separator(vbox)
	_add_section_header(vbox, "Tools")
	_add_line(vbox, "M", "Maneuver Tool (toggle)")
	_add_line(vbox, "R", "Range Overlay (toggle)")
	_add_line(vbox, "T", "Targeting List (toggle)")
	_add_separator(vbox)
	_add_section_header(vbox, "Cheats")
	_add_line(vbox, "Shift + D", "Deal faceup damage card")
	_add_separator(vbox)
	_add_section_header(vbox, "Save / Load")
	_add_line(vbox, "F5", "Quicksave game state")
	_add_line(vbox, "F8", "Quickload game state")


## Adds the main header label to the container.
func _add_header(parent: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", HEADER_COLOUR)
	label.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)
	parent.add_child(label)


## Adds a section sub-header.
func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", HEADER_COLOUR)
	label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	parent.add_child(label)


## Adds a shortcut → description line.
func _add_line(parent: VBoxContainer, shortcut: String, desc: String) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var key_label: Label = Label.new()
	key_label.text = shortcut
	key_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	key_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	key_label.custom_minimum_size = Vector2(130, 0)
	hbox.add_child(key_label)

	var desc_label: Label = Label.new()
	desc_label.text = desc
	desc_label.add_theme_color_override("font_color", BODY_COLOUR)
	desc_label.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	hbox.add_child(desc_label)


## Adds a horizontal separator line.
func _add_separator(parent: VBoxContainer) -> void:
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	parent.add_child(sep)
