## SetupPlacementModal
##
## Bottom-centre setup modal for obstacle placement and setup summary state.
## It renders projected controller copy, remaining obstacle actions, and the
## current setup status without owning any gameplay legality logic.
class_name SetupPlacementModal
extends PanelContainer


signal obstacle_selected(obstacle_key: String)
signal cancel_preview_requested()
signal confirm_preview_requested()
signal start_round_requested()

const BUTTON_WIDTH_PX: float = 220.0
const MODAL_MAX_WIDTH: float = 380.0
const MODAL_WIDTH_FRACTION: float = 0.34
const OBSTACLE_LIST_HEIGHT_PX: float = 196.0

var _title_label: Label = null
var _prompt_label: Label = null
var _pending_label: Label = null
var _status_label: Label = null
var _obstacle_scroll: ScrollContainer = null
var _obstacle_list: VBoxContainer = null
var _obstacle_buttons: Dictionary = {}
var _cancel_button: Button = null
var _confirm_button: Button = null
var _start_button: Button = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_apply_anchor_position()


func _ready() -> void:
	_build_ui()


## Keeps the modal bottom-centred for the current viewport width.
func centre_on_screen(viewport_size: Vector2) -> void:
	var panel_width: float = minf(MODAL_MAX_WIDTH,
			viewport_size.x * MODAL_WIDTH_FRACTION)
	custom_minimum_size = Vector2(panel_width, 0.0)
	offset_left = - panel_width * 0.5
	offset_right = panel_width * 0.5


## Renders the obstacle-placement step with selectable remaining obstacles.
func render_obstacle_step(title_text: String,
		prompt_text: String,
		pending_text: String,
		status_text: String,
		status_colour: Color,
		obstacle_entries: Array[Dictionary],
		show_cancel: bool,
		show_confirm: bool,
		confirm_disabled: bool) -> void:
	_apply_common_text(title_text, prompt_text, pending_text,
			status_text, status_colour)
	_set_obstacle_list_visible(true)
	_sync_obstacle_buttons(obstacle_entries)
	_cancel_button.visible = show_cancel
	_cancel_button.disabled = not show_cancel
	_confirm_button.visible = show_confirm
	_confirm_button.disabled = confirm_disabled
	_start_button.visible = false


## Renders a non-obstacle setup summary step such as deployment or review.
func render_setup_summary(title_text: String,
		prompt_text: String,
		pending_text: String,
		status_text: String,
		status_colour: Color,
		show_start_button: bool,
		start_button_disabled: bool) -> void:
	_apply_common_text(title_text, prompt_text, pending_text,
			status_text, status_colour)
	_set_obstacle_list_visible(false)
	_cancel_button.visible = false
	_confirm_button.visible = false
	_start_button.visible = show_start_button
	_start_button.disabled = start_button_disabled


func _apply_anchor_position() -> void:
	var panel_width: float = MODAL_MAX_WIDTH
	custom_minimum_size = Vector2(panel_width, 0.0)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = - panel_width * 0.5
	offset_right = panel_width * 0.5
	offset_top = -40.0
	offset_bottom = -40.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


func _build_ui() -> void:
	add_theme_stylebox_override("panel",
			UIStyleHelper.create_modal_panel_style(0.0))
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "ContentMargin"
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	margin.add_child(_build_content_vbox())


func _build_content_vbox() -> VBoxContainer:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.add_theme_constant_override("separation", 12)
	vbox.add_child(_build_header_section())
	vbox.add_child(_build_obstacle_scroll())
	vbox.add_child(_build_footer_buttons())
	return vbox


func _build_header_section() -> VBoxContainer:
	var header: VBoxContainer = VBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_title_label = UIStyleHelper.create_title_label("Setup", UIStyleHelper.GOLD_TITLE)
	_title_label.name = "TitleLabel"
	_prompt_label = UIStyleHelper.create_section_label(
			"", UIStyleHelper.FONT_BODY, UIStyleHelper.BODY_TEXT)
	_prompt_label.name = "PromptLabel"
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pending_label = UIStyleHelper.create_section_label(
			"", UIStyleHelper.FONT_SUBTITLE, UIStyleHelper.BLUE_ACCENT)
	_pending_label.name = "PendingLabel"
	_pending_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label = UIStyleHelper.create_section_label(
			"", UIStyleHelper.FONT_SUBTITLE, UIStyleHelper.BODY_TEXT)
	_status_label.name = "StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_title_label)
	header.add_child(_prompt_label)
	header.add_child(_pending_label)
	header.add_child(_status_label)
	return header


func _build_obstacle_scroll() -> ScrollContainer:
	_obstacle_scroll = ScrollContainer.new()
	_obstacle_scroll.name = "ObstacleListScroll"
	_obstacle_scroll.custom_minimum_size = Vector2(0.0, OBSTACLE_LIST_HEIGHT_PX)
	_obstacle_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_obstacle_scroll.add_child(_build_obstacle_list())
	return _obstacle_scroll


func _build_obstacle_list() -> VBoxContainer:
	_obstacle_list = VBoxContainer.new()
	_obstacle_list.name = "ObstacleList"
	_obstacle_list.add_theme_constant_override("separation", 6)
	return _obstacle_list


func _build_footer_buttons() -> HBoxContainer:
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	_cancel_button = Button.new()
	_cancel_button.name = "CancelPreviewButton"
	_cancel_button.text = "Cancel Preview"
	_cancel_button.custom_minimum_size = Vector2(BUTTON_WIDTH_PX, 0.0)
	_cancel_button.pressed.connect(_on_cancel_preview_pressed)
	_cancel_button.visible = false
	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmPlacementButton"
	_confirm_button.text = "Confirm Placement"
	_confirm_button.custom_minimum_size = Vector2(BUTTON_WIDTH_PX, 0.0)
	_confirm_button.pressed.connect(_on_confirm_preview_pressed)
	_confirm_button.visible = false
	_start_button = Button.new()
	_start_button.name = "StartRoundButton"
	_start_button.text = "Start Round"
	_start_button.custom_minimum_size = Vector2(BUTTON_WIDTH_PX, 0.0)
	_start_button.pressed.connect(_on_start_round_pressed)
	_start_button.visible = false
	actions.add_child(_cancel_button)
	actions.add_child(_confirm_button)
	actions.add_child(_start_button)
	return actions


func _apply_common_text(title_text: String,
		prompt_text: String,
		pending_text: String,
		status_text: String,
		status_colour: Color) -> void:
	_title_label.text = title_text
	_prompt_label.text = prompt_text
	_pending_label.text = pending_text
	_pending_label.visible = not pending_text.is_empty()
	_status_label.text = status_text
	_status_label.visible = not status_text.is_empty()
	_status_label.add_theme_color_override("font_color", status_colour)


func _set_obstacle_list_visible(list_visible: bool) -> void:
	_obstacle_scroll.visible = list_visible


func _sync_obstacle_buttons(obstacle_entries: Array[Dictionary]) -> void:
	for entry: Dictionary in obstacle_entries:
		var obstacle_key: String = str(entry.get("key", ""))
		var button: Button = _obstacle_buttons.get(obstacle_key, null) as Button
		if button == null:
			button = _build_obstacle_button(obstacle_key)
			_obstacle_buttons[obstacle_key] = button
			_obstacle_list.add_child(button)
		_apply_obstacle_button_state(button, entry)


func _build_obstacle_button(obstacle_key: String) -> Button:
	var button: Button = Button.new()
	button.name = "ObstacleButton_%s" % obstacle_key
	button.custom_minimum_size = Vector2(BUTTON_WIDTH_PX, 0.0)
	button.pressed.connect(_on_obstacle_button_pressed.bind(obstacle_key))
	return button


func _apply_obstacle_button_state(button: Button, entry: Dictionary) -> void:
	button.text = str(entry.get("label", button.name))
	button.disabled = bool(entry.get("disabled", true))
	if bool(entry.get("selected", false)):
		button.add_theme_color_override("font_color", UIStyleHelper.BLUE_ACCENT)
		return
	button.remove_theme_color_override("font_color")


func _on_obstacle_button_pressed(obstacle_key: String) -> void:
	obstacle_selected.emit(obstacle_key)


func _on_cancel_preview_pressed() -> void:
	cancel_preview_requested.emit()


func _on_confirm_preview_pressed() -> void:
	confirm_preview_requested.emit()


func _on_start_round_pressed() -> void:
	start_round_requested.emit()
