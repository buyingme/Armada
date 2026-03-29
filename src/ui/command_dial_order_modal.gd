## CommandDialOrderModal
##
## Read-only overlay showing the queued (hidden) command dials for a ship.
## Displays a horizontal row of dial icons in stack order (top = leftmost,
## i.e. next to be revealed). Click anywhere to dismiss.
##
## Rules Reference: UI-022, UI-023 (own ships only — caller enforces).
class_name CommandDialOrderModal
extends PanelContainer


## Mapping from CommandType to the icon filename under command_tokens/.
const CMD_ICON_FILENAMES: Dictionary = {
	Constants.CommandType.NAVIGATE: "cmd_navigate.png",
	Constants.CommandType.SQUADRON: "cmd_squadron.png",
	Constants.CommandType.CONCENTRATE_FIRE: "cmd_concentrate_fire.png",
	Constants.CommandType.REPAIR: "cmd_repair.png",
}

## The icon size for each dial entry.
const DIAL_ICON_SIZE: Vector2 = Vector2(40, 40)

## The ship instance whose dial order is shown.
var _ship_instance: ShipInstance = null

## Title label.
var _title_label: Label = null

## Container for the dial order entries.
var _order_container: HBoxContainer = null

## "No dials" label.
var _empty_label: Label = null


func _init() -> void:
	_apply_anchor_position()


## Opens the modal for the given ship.
## [param ship] — the ShipInstance whose dial order to display.
func open(ship: ShipInstance) -> void:
	_ship_instance = ship
	_build_ui()
	visible = true


## Closes the modal.
func close() -> void:
	visible = false
	_ship_instance = null


## Returns true if the modal is currently open.
func is_open() -> bool:
	return visible and _ship_instance != null


## Builds the complete modal UI.
func _build_ui() -> void:
	for child: Node in get_children():
		child.queue_free()

	custom_minimum_size = Vector2(320, 160)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	# Title.
	_title_label = Label.new()
	var ship_name: String = ""
	if _ship_instance and _ship_instance.ship_data:
		ship_name = _ship_instance.ship_data.ship_name
	_title_label.text = "Command Dial Order — %s" % ship_name
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)

	# Dial order entries.
	_order_container = HBoxContainer.new()
	_order_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_order_container.add_theme_constant_override("separation", 12)

	var queued: Array[Dictionary] = _get_queued_dials()
	if queued.is_empty():
		_empty_label = Label.new()
		_empty_label.text = "No dials in stack."
		_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(_empty_label)
	else:
		for i: int in range(queued.size()):
			var entry: Dictionary = queued[i]
			var entry_vbox: VBoxContainer = VBoxContainer.new()
			entry_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			entry_vbox.add_theme_constant_override("separation", 4)

			# Dial icon.
			var icon: TextureRect = TextureRect.new()
			var cmd: int = int(entry.get("command", 0))
			var tex: Texture2D = _get_cmd_icon_texture(cmd)
			if tex:
				icon.texture = tex
			icon.custom_minimum_size = DIAL_ICON_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			entry_vbox.add_child(icon)

			# Position label (1 = top / next to reveal).
			var pos_label: Label = Label.new()
			pos_label.text = "#%d" % (i + 1)
			pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pos_label.add_theme_font_size_override("font_size", 12)
			entry_vbox.add_child(pos_label)

			_order_container.add_child(entry_vbox)

	vbox.add_child(_order_container)

	# Dismiss hint.
	var hint: Label = Label.new()
	hint.text = "Click anywhere to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(hint)

	margin.add_child(vbox)
	add_child(margin)

	# Style the panel.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.4, 0.5, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)


## Retrieves the queued (hidden) dials from the command dial stack.
## Returns them in stack order (index 0 = top = next to be revealed).
func _get_queued_dials() -> Array[Dictionary]:
	if _ship_instance == null:
		return []
	if _ship_instance.command_dial_stack == null:
		return []
	var all_dials: Array[Dictionary] = (
			_ship_instance.command_dial_stack.get_all_dials())
	var queued: Array[Dictionary] = []
	for dial: Dictionary in all_dials:
		if dial.get("state", "") == CommandDialStack.STATE_HIDDEN:
			queued.append(dial)
	return queued


## Loads a command icon texture for the given command type.
func _get_cmd_icon_texture(cmd: int) -> Texture2D:
	var filename: String = CMD_ICON_FILENAMES.get(cmd, "")
	if filename.is_empty():
		return null
	return AssetLoader.load_texture("command_tokens/", filename)


## Updates the bottom-centre anchored position width for the given viewport.
func centre_on_screen(viewport_size: Vector2) -> void:
	var panel_w: float = minf(320.0, viewport_size.x * 0.35)
	custom_minimum_size = Vector2(panel_w, 0.0)
	offset_left = - panel_w * 0.5
	offset_right = panel_w * 0.5


## Sets bottom-centre anchoring once — called from _init to avoid
## Godot offset recalculation on repeated anchor writes.
func _apply_anchor_position() -> void:
	var panel_w: float = 320.0
	custom_minimum_size = Vector2(panel_w, 0.0)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = - panel_w * 0.5
	offset_right = panel_w * 0.5
	offset_top = -40.0 - 160.0
	offset_bottom = -40.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


## Handle click-anywhere-to-close.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()
			accept_event()
