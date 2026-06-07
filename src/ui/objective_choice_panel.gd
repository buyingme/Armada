## Objective Choice Panel
##
## Renders up to three objective cards side by side, supports local preview
## selection, and emits a confirmed choice or passive acknowledgement.
extends PanelContainer


signal objective_confirmed(objective_key: String)
signal confirmation_acknowledged()

const CARD_MIN_SIZE: Vector2 = Vector2(220, 420)
const CARD_IMAGE_HEIGHT: float = 320.0

var _payload: Dictionary = {}
var _selected_objective_key: String = ""
var _title_label: Label = null
var _subtitle_label: Label = null
var _cards_box: HBoxContainer = null
var _status_label: Label = null
var _confirm_button: Button = null
var _card_buttons: Dictionary = {}


func _ready() -> void:
	_ensure_ui()
	_refresh()


## Applies a new panel payload.
func configure(payload: Dictionary) -> void:
	_payload = payload.duplicate(true)
	if _selection_locked():
		_selected_objective_key = _confirmed_objective_key()
	elif not _objective_keys().has(_selected_objective_key):
		_selected_objective_key = _default_selection_key()
	_ensure_ui()
	_refresh()


## Returns the objective keys currently displayed by the chooser.
func available_objective_keys() -> Array[String]:
	var keys: Array[String] = []
	for objective: Dictionary in _objectives():
		keys.append(str(objective.get("data_key", "")))
	return keys


## Selects an objective locally when the panel is interactive.
func choose_objective(objective_key: String) -> void:
	if not _can_select() or not available_objective_keys().has(objective_key):
		return
	_selected_objective_key = objective_key
	refresh_card_states()
	_refresh_confirm_button()


## Confirms the current selection or passive acknowledgement.
func confirm_current_selection() -> void:
	_on_confirm_pressed()


func _ensure_ui() -> void:
	if _title_label != null:
		return
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
	_title_label = UIStyleHelper.create_section_label("Objectives", UIStyleHelper.FONT_BODY)
	_subtitle_label = UIStyleHelper.create_section_label(
			"", UIStyleHelper.FONT_HINT, UIStyleHelper.DIMMED_HINT)
	_cards_box = HBoxContainer.new()
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.add_theme_constant_override("separation", 12)
	_status_label = UIStyleHelper.create_section_label(
			"", UIStyleHelper.FONT_HINT, UIStyleHelper.DIMMED_HINT)
	_confirm_button = Button.new()
	_confirm_button.custom_minimum_size = Vector2(180, 40)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_child(_confirm_button)
	layout.add_child(_title_label)
	layout.add_child(_subtitle_label)
	layout.add_child(_cards_box)
	layout.add_child(_status_label)
	layout.add_child(button_row)


func _refresh() -> void:
	if _title_label == null:
		return
	_title_label.text = str(_payload.get("heading", "Objectives"))
	_subtitle_label.text = str(_payload.get("subtitle", ""))
	_status_label.text = str(_payload.get("status_text", ""))
	_rebuild_cards()
	_refresh_confirm_button()


func _rebuild_cards() -> void:
	for child: Node in _cards_box.get_children():
		child.queue_free()
	_card_buttons.clear()
	for objective: Dictionary in _objectives():
		var button: Button = _build_card_button(objective)
		_cards_box.add_child(button)
		_card_buttons[str(objective.get("data_key", ""))] = button
	refresh_card_states()


func refresh_card_states() -> void:
	for objective_key: String in _card_buttons.keys():
		var button: Button = _card_buttons[objective_key] as Button
		if button == null:
			continue
		_apply_card_visuals(button, objective_key)


func _build_card_button(objective: Dictionary) -> Button:
	var objective_key: String = str(objective.get("data_key", ""))
	var button: Button = Button.new()
	button.custom_minimum_size = CARD_MIN_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_objective_pressed.bind(objective_key))
	var content: VBoxContainer = VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 8)
	var texture_rect: TextureRect = TextureRect.new()
	texture_rect.texture = _objective_texture(objective_key)
	texture_rect.custom_minimum_size = Vector2(CARD_MIN_SIZE.x - 24.0, CARD_IMAGE_HEIGHT)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title: Label = Label.new()
	title.text = str(objective.get("objective_name", objective_key))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var category: Label = Label.new()
	category.text = str(objective.get("category", "")).capitalize()
	category.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	category.add_theme_font_size_override("font_size", UIStyleHelper.FONT_HINT)
	category.add_theme_color_override("font_color", UIStyleHelper.DIMMED_HINT)
	category.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.offset_left = 12.0
	content.offset_top = 12.0
	content.offset_right = -12.0
	content.offset_bottom = -12.0
	content.add_child(texture_rect)
	content.add_child(title)
	content.add_child(category)
	button.add_child(content)
	return button


func _apply_card_visuals(button: Button, objective_key: String) -> void:
	var is_chosen: bool = _displayed_choice_key() == objective_key
	var is_dimmed: bool = _selection_locked() and not is_chosen
	button.disabled = not _can_select() or is_dimmed
	button.modulate = Color(0.45, 0.45, 0.45, 0.85) if is_dimmed else Color(1, 1, 1, 1)
	var style: StyleBoxFlat = _card_style(is_chosen, _selection_locked())
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", style)


func _refresh_confirm_button() -> void:
	if _confirm_button == null:
		return
	if _selection_locked():
		_confirm_button.text = str(_payload.get("locked_button_text", "Confirm"))
		_confirm_button.disabled = not _can_confirm()
		return
	_confirm_button.text = str(_payload.get("selection_button_text", "Confirm Objective"))
	_confirm_button.disabled = not _can_select() or _selected_objective_key.is_empty()


func _on_objective_pressed(objective_key: String) -> void:
	choose_objective(objective_key)


func _on_confirm_pressed() -> void:
	if _selection_locked():
		if _can_confirm():
			confirmation_acknowledged.emit()
		return
	if _selected_objective_key.is_empty():
		return
	objective_confirmed.emit(_selected_objective_key)


func _card_style(is_selected: bool, is_locked: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.95)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = UIStyleHelper.DIMMED_HINT
	if is_selected:
		style.bg_color = Color(0.18, 0.22, 0.32, 0.98)
		style.border_color = UIStyleHelper.BLUE_ACCENT
	if is_locked and is_selected:
		style.border_color = Color(0.4, 0.9, 0.4)
	return style


func _objective_texture(objective_key: String) -> Texture2D:
	var data: ObjectiveData = AssetLoader.load_objective_data(objective_key)
	if data == null or data.card_image.is_empty():
		return null
	return AssetLoader.load_texture(AssetLoader.OBJECTIVE_FOLDER, data.card_image)


func _objectives() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = _payload.get("objectives", [])
	if not raw is Array:
		return result
	for entry: Variant in raw as Array:
		if entry is Dictionary:
			result.append((entry as Dictionary).duplicate(true))
	return result


func _objective_keys() -> Array[String]:
	var keys: Array[String] = []
	for objective: Dictionary in _objectives():
		keys.append(str(objective.get("data_key", "")))
	return keys


func _default_selection_key() -> String:
	var keys: Array[String] = _objective_keys()
	return "" if keys.is_empty() else keys[0]


func _confirmed_objective_key() -> String:
	return str(_payload.get("confirmed_key", ""))


func _displayed_choice_key() -> String:
	return _confirmed_objective_key() if _selection_locked() else _selected_objective_key


func _selection_locked() -> bool:
	return bool(_payload.get("selection_locked", false))


func _can_select() -> bool:
	return bool(_payload.get("can_select", false)) and not _selection_locked()


func _can_confirm() -> bool:
	return bool(_payload.get("can_confirm", false))