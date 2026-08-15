## TarkinChoiceModal
##
## Public Grand Moff Tarkin prompt rendered from UIProjector payload.
## The modal is presentation-only: submitted choices are emitted as signals and
## routed through the command system by ModalRouter.
class_name TarkinChoiceModal
extends PanelContainer


signal choice_submitted(command: int)
signal decline_submitted()

const COMMAND_LABELS: Dictionary = {
	Constants.CommandType.NAVIGATE: "Navigate",
	Constants.CommandType.SQUADRON: "Squadron",
	Constants.CommandType.CONCENTRATE_FIRE: "Concentrate Fire",
	Constants.CommandType.REPAIR: "Repair",
}
const COMMAND_ICON_FILENAMES: Dictionary = {
	Constants.CommandType.NAVIGATE: "cmd_navigate.png",
	Constants.CommandType.SQUADRON: "cmd_squadron.png",
	Constants.CommandType.CONCENTRATE_FIRE: "cmd_concentrate_fire.png",
	Constants.CommandType.REPAIR: "cmd_repair.png",
}
const COMMAND_ICON_SIZE: Vector2 = Vector2(48, 48)

var _payload: Dictionary = {}
var _is_interactive: bool = false
var _title_label: Label = null
var _subtitle_label: Label = null
var _commands_box: HBoxContainer = null
var _decline_button: Button = null


func _ready() -> void:
	_ensure_ui()
	_refresh()


## Opens the prompt from projected state.
func open_from_intent(intent: UIProjector.UIIntent) -> void:
	_payload = intent.payload.duplicate(true)
	_is_interactive = intent.is_interactive
	_ensure_ui()
	_refresh()
	visible = true
	centre_on_screen()


## Closes the prompt without submitting a choice.
func close() -> void:
	visible = false


## Returns whether the prompt is currently visible.
func is_open() -> bool:
	return visible


## Returns the runtime upgrade id bound to the current prompt payload.
func runtime_upgrade_id() -> String:
	return str(_payload.get("runtime_upgrade_id", ""))


## Repositions the prompt at the centre of the viewport.
func centre_on_screen(viewport_size: Vector2 = Vector2.ZERO) -> void:
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport_rect().size
	reset_size()
	var minimum: Vector2 = get_combined_minimum_size()
	var modal_size: Vector2 = Vector2(
			maxf(custom_minimum_size.x, minimum.x),
			maxf(custom_minimum_size.y, minimum.y))
	size = modal_size
	position = (viewport_size - modal_size) * 0.5


func _ensure_ui() -> void:
	if _title_label != null:
		return
	custom_minimum_size = Vector2(420, 220)
	add_theme_stylebox_override("panel", UIStyleHelper.create_modal_panel_style(0.0))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	_title_label = UIStyleHelper.create_section_label(
			"Grand Moff Tarkin", UIStyleHelper.FONT_BODY)
	_subtitle_label = UIStyleHelper.create_section_label(
			"", UIStyleHelper.FONT_HINT, UIStyleHelper.DIMMED_HINT)
	_commands_box = HBoxContainer.new()
	_commands_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_commands_box.add_theme_constant_override("separation", 8)
	_decline_button = Button.new()
	_decline_button.text = "Decline"
	_decline_button.custom_minimum_size = Vector2(120, 36)
	_decline_button.pressed.connect(_on_decline_pressed)
	var decline_row: HBoxContainer = HBoxContainer.new()
	decline_row.alignment = BoxContainer.ALIGNMENT_CENTER
	decline_row.add_child(_decline_button)
	layout.add_child(_title_label)
	layout.add_child(_subtitle_label)
	layout.add_child(_commands_box)
	layout.add_child(decline_row)


func _refresh() -> void:
	if _title_label == null:
		return
	_subtitle_label.text = _subtitle_text()
	_rebuild_command_buttons()
	_decline_button.disabled = not _is_interactive


func _subtitle_text() -> String:
	if _is_interactive:
		return "Choose one command token to grant to each friendly ship."
	return "Waiting for Grand Moff Tarkin's owner to choose a command."


func _rebuild_command_buttons() -> void:
	for child: Node in _commands_box.get_children():
		_commands_box.remove_child(child)
		child.free()
	for command: int in _available_commands():
		_commands_box.add_child(_build_command_choice(command))


func _available_commands() -> Array[int]:
	var commands: Array[int] = []
	for raw: Variant in _payload.get("available_commands", []):
		commands.append(int(raw))
	return commands


func _build_command_choice(command: int) -> VBoxContainer:
	var choice: VBoxContainer = VBoxContainer.new()
	choice.name = "CommandChoice_%d" % command
	choice.alignment = BoxContainer.ALIGNMENT_CENTER
	choice.add_theme_constant_override("separation", 4)
	var icon: TextureRect = TextureRect.new()
	icon.name = "CommandIcon_%d" % command
	icon.custom_minimum_size = COMMAND_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var filename: String = str(COMMAND_ICON_FILENAMES.get(command, ""))
	if not filename.is_empty():
		icon.texture = AssetLoader.load_texture("command_tokens/", filename)
	choice.add_child(icon)
	var button: Button = Button.new()
	button.name = "CommandButton_%d" % command
	button.text = str(COMMAND_LABELS.get(command, "Command %d" % command))
	button.disabled = not _is_interactive
	button.custom_minimum_size = Vector2(100, 36)
	button.pressed.connect(_on_command_pressed.bind(command))
	choice.add_child(button)
	return choice


func _on_command_pressed(command: int) -> void:
	if not _is_interactive:
		return
	choice_submitted.emit(command)


func _on_decline_pressed() -> void:
	if not _is_interactive:
		return
	decline_submitted.emit()
