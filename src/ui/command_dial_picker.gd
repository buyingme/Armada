## CommandDialPicker
##
## Modal dialog for assigning command dials during the Command Phase.
## Centres on screen with a selection area (4 command icons in cycle order)
## and a stack area showing dials already queued. Players click a command
## icon in the selection area to add it to the stack.
##
## Round 1: player must assign N dials (ship's command value).
## Rounds 2+: player assigns exactly 1 new dial.
## A CONFIRM button enables only when the correct number is placed.
## Dials in the stack can be clicked to remove them.
##
## All artwork uses the PNG assets under command_tokens/:
##   cmd_dial_hidden.png (60×58) — facedown background
##   cmd_navigate.png, cmd_squadron.png, cmd_concentrate_fire.png,
##   cmd_repair.png (45×45) — command icons
##
## Rules Reference: CP-001–005; UI-005, UI-021.
## Requirements: GC-008.
class_name CommandDialPicker
extends PanelContainer


## The fixed cycle order of command types.
## Rules Reference: CP-005.
const COMMAND_CYCLE: Array[int] = [
	Constants.CommandType.NAVIGATE,
	Constants.CommandType.SQUADRON,
	Constants.CommandType.CONCENTRATE_FIRE,
	Constants.CommandType.REPAIR,
]

## Human-readable labels for each command type.
const COMMAND_LABELS: Dictionary = {
	Constants.CommandType.NAVIGATE: "Navigate",
	Constants.CommandType.SQUADRON: "Squadron",
	Constants.CommandType.CONCENTRATE_FIRE: "Conc. Fire",
	Constants.CommandType.REPAIR: "Repair",
}

## Map from command type to icon filename.
const CMD_ICON_FILENAMES: Dictionary = {
	Constants.CommandType.NAVIGATE: "cmd_navigate.png",
	Constants.CommandType.SQUADRON: "cmd_squadron.png",
	Constants.CommandType.CONCENTRATE_FIRE: "cmd_concentrate_fire.png",
	Constants.CommandType.REPAIR: "cmd_repair.png",
}

## Hidden dial background filename.
const CMD_DIAL_HIDDEN_FILE: String = "cmd_dial_hidden.png"

## Icon size in the selection area.
const ICON_SIZE: Vector2 = Vector2(56, 56)

## Icon size in the stack area (slightly smaller).
const STACK_ICON_SIZE: Vector2 = Vector2(48, 48)

## The ship instance whose dials are being assigned.
var _ship_instance: ShipInstance = null

## The current round number.
var _current_round: int = 1

## Number of new dials required this round.
var _dials_needed: int = 0

## Queued command types (new dials being assigned).
var _queued_commands: Array[int] = []

## Cached textures: {key: Texture2D}.
var _tex_cache: Dictionary = {}

## UI references.
var _title_label: Label = null
var _selection_container: HBoxContainer = null
var _stack_container: HBoxContainer = null
var _confirm_button: Button = null
var _stack_label: Label = null


## Opens the picker for the given ship and round.
## [param ship] — the ShipInstance to assign dials to.
## [param current_round] — the current round number.
func open(ship: ShipInstance, current_round: int) -> void:
	_ship_instance = ship
	_current_round = current_round
	_queued_commands.clear()

	if ship.command_dial_stack:
		_dials_needed = ship.command_dial_stack.get_dials_needed()
	else:
		_dials_needed = ship.ship_data.command_value

	_build_ui()
	_update_confirm_state()
	visible = true


## Closes the picker without confirming.
func close() -> void:
	visible = false
	_ship_instance = null


## Returns true if the picker is currently open.
func is_open() -> bool:
	return visible and _ship_instance != null


## Builds the complete picker UI.
func _build_ui() -> void:
	# Clear previous content.
	for child: Node in get_children():
		child.queue_free()

	custom_minimum_size = Vector2(400, 320)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)

	# Title.
	_title_label = Label.new()
	var ship_name: String = ""
	if _ship_instance and _ship_instance.ship_data:
		ship_name = _ship_instance.ship_data.ship_name
	_title_label.text = "Assign Command Dials — %s (Round %d)" % [
			ship_name, _current_round]
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title_label)

	# Subtitle showing how many dials needed.
	var subtitle: Label = Label.new()
	subtitle.text = "Select %d command%s:" % [
			_dials_needed, "" if _dials_needed == 1 else "s"]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	# Show existing dials already in the stack (from previous rounds).
	# This gives the player context for what commands are coming up.
	_build_existing_stack_display(vbox)

	# Selection area: 4 command icons in cycle order.
	_selection_container = HBoxContainer.new()
	_selection_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_selection_container.add_theme_constant_override("separation", 16)
	for cmd: int in COMMAND_CYCLE:
		var icon_btn: VBoxContainer = _create_icon_button(cmd, ICON_SIZE)
		_selection_container.add_child(icon_btn)
	vbox.add_child(_selection_container)

	# Separator.
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	# Stack label.
	_stack_label = Label.new()
	_stack_label.text = "Dial Stack (top → bottom):"
	vbox.add_child(_stack_label)

	# Stack area: shows queued dials.
	_stack_container = HBoxContainer.new()
	_stack_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_stack_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_stack_container)

	# Confirm button.
	_confirm_button = Button.new()
	_confirm_button.text = "CONFIRM"
	_confirm_button.custom_minimum_size = Vector2(120, 36)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_child(_confirm_button)
	vbox.add_child(btn_container)

	margin.add_child(vbox)
	add_child(margin)

	# Style the panel.
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.5, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)


## Called when a command icon button is clicked.
func _on_command_selected(cmd: int) -> void:
	if _queued_commands.size() >= _dials_needed:
		return
	_queued_commands.append(cmd)
	_refresh_stack_display()
	_update_confirm_state()


## Refreshes the visual stack display with command dial icons.
func _refresh_stack_display() -> void:
	if _stack_container == null:
		return
	for child: Node in _stack_container.get_children():
		child.queue_free()

	for i: int in range(_queued_commands.size()):
		var cmd: int = _queued_commands[i]
		var dial_entry: VBoxContainer = _create_stack_entry(cmd, i)
		_stack_container.add_child(dial_entry)


## Called when a dial in the stack is clicked to remove it.
func _on_dial_removed(index: int) -> void:
	if index >= 0 and index < _queued_commands.size():
		_queued_commands.remove_at(index)
		_refresh_stack_display()
		_update_confirm_state()


## Updates the CONFIRM button enabled state.
func _update_confirm_state() -> void:
	if _confirm_button:
		_confirm_button.disabled = (
				_queued_commands.size() != _dials_needed)


## Called when the CONFIRM button is pressed.
## Closes first, then emits the signal so that signal handlers can
## re-open the picker for the next ship without it being hidden.
func _on_confirm_pressed() -> void:
	if _queued_commands.size() != _dials_needed:
		return
	if _ship_instance == null:
		return

	# Convert queued commands to a plain Array for the signal.
	var commands: Array = []
	for cmd: int in _queued_commands:
		commands.append(cmd)

	var ship_ref: ShipInstance = _ship_instance
	# Close before emitting so handlers can re-open for next ship.
	close()
	EventBus.command_picker_confirmed.emit(ship_ref, commands)


## Centres this picker on the given viewport size.
func centre_on_screen(viewport_size: Vector2) -> void:
	var panel_size: Vector2 = custom_minimum_size
	position = (viewport_size - panel_size) * 0.5


# ---------------------------------------------------------------------------
# Graphic helpers
# ---------------------------------------------------------------------------

## Creates a clickable icon button for a command type in the selection area.
## Returns a VBoxContainer with the icon TextureRect + label.
func _create_icon_button(cmd: int,
		icon_size: Vector2) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)

	var btn: Button = Button.new()
	btn.custom_minimum_size = icon_size + Vector2(8, 8)
	btn.pressed.connect(_on_command_selected.bind(cmd))

	# Add icon as child of the button.
	var tex: Texture2D = _get_cmd_icon_texture(cmd)
	if tex:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = tex
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = icon_size
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)
		btn.text = ""
	else:
		btn.text = COMMAND_LABELS.get(cmd, "?")

	col.add_child(btn)

	# Label below icon.
	var lbl: Label = Label.new()
	lbl.text = COMMAND_LABELS.get(cmd, "?")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	col.add_child(lbl)

	return col


## Creates a single stack entry (icon + position label, removable on click).
func _create_stack_entry(cmd: int, index: int) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)

	var btn: Button = Button.new()
	btn.custom_minimum_size = STACK_ICON_SIZE + Vector2(6, 6)
	btn.tooltip_text = "Click to remove"
	btn.pressed.connect(_on_dial_removed.bind(index))

	var tex: Texture2D = _get_cmd_icon_texture(cmd)
	if tex:
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.texture = tex
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = STACK_ICON_SIZE
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_rect)
		btn.text = ""
	else:
		btn.text = COMMAND_LABELS.get(cmd, "?")

	col.add_child(btn)

	# Position label (1 = top).
	var pos_label: Label = Label.new()
	pos_label.text = "#%d" % (index + 1)
	pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_label.add_theme_font_size_override("font_size", 10)
	col.add_child(pos_label)

	return col


## Builds a display of existing dials already in the command stack.
## Only shown when there are hidden dials (rounds 2+). Gives the player
## context about upcoming commands they assigned in prior rounds.
func _build_existing_stack_display(parent: VBoxContainer) -> void:
	if _ship_instance == null or _ship_instance.command_dial_stack == null:
		return
	var all_dials: Array[Dictionary] = _ship_instance.command_dial_stack \
			.get_all_dials()
	# Only show existing hidden dials (not revealed or spent).
	var hidden_cmds: Array[int] = []
	for dial: Dictionary in all_dials:
		if dial.get("state", "") == CommandDialStack.STATE_HIDDEN:
			hidden_cmds.append(int(dial.get("command", 0)))
	if hidden_cmds.is_empty():
		return

	var existing_label: Label = Label.new()
	existing_label.text = "Existing stack (top → bottom):"
	existing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	existing_label.add_theme_font_size_override("font_size", 12)
	existing_label.add_theme_color_override(
			"font_color", Color(0.7, 0.7, 0.7, 0.8))
	parent.add_child(existing_label)

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var small_size: Vector2 = STACK_ICON_SIZE * 0.80
	for i: int in range(hidden_cmds.size()):
		var cmd: int = hidden_cmds[i]
		var col: VBoxContainer = VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 1)
		var tex: Texture2D = _get_cmd_icon_texture(cmd)
		if tex:
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.texture = tex
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = small_size
			icon_rect.modulate.a = 0.6
			col.add_child(icon_rect)
		var pos_lbl: Label = Label.new()
		pos_lbl.text = "#%d" % (i + 1)
		pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pos_lbl.add_theme_font_size_override("font_size", 9)
		pos_lbl.add_theme_color_override(
				"font_color", Color(0.6, 0.6, 0.6, 0.7))
		col.add_child(pos_lbl)
		row.add_child(col)
	parent.add_child(row)


# ---------------------------------------------------------------------------
# Texture loading
# ---------------------------------------------------------------------------

## Loads (or returns cached) a command icon texture.
func _get_cmd_icon_texture(cmd: int) -> Texture2D:
	var filename: String = CMD_ICON_FILENAMES.get(cmd, "")
	if filename.is_empty():
		return null
	var cache_key: String = "cmd_icon_%d" % cmd
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key] as Texture2D
	var tex: Texture2D = AssetLoader.load_texture(
			"command_tokens/", filename)
	if tex:
		_tex_cache[cache_key] = tex
	return tex


## Loads (or returns cached) the hidden dial background texture.
func _get_dial_hidden_texture() -> Texture2D:
	var cache_key: String = "dial_hidden"
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key] as Texture2D
	var tex: Texture2D = AssetLoader.load_texture(
			"command_tokens/", CMD_DIAL_HIDDEN_FILE)
	if tex:
		_tex_cache[cache_key] = tex
	return tex
