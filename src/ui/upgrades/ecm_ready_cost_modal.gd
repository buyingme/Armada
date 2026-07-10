## ECMReadyCostModal
##
## Public Status Phase prompt for Electronic Countermeasures' Repair-token
## ready cost. This modal is presentation-only: it renders projected choices
## and emits submission signals that ModalRouter routes through commands.
class_name ECMReadyCostModal
extends PanelContainer


signal ready_submitted(runtime_upgrade_id: String, owner_player: int)
signal decline_submitted(runtime_upgrade_id: String, owner_player: int)

const CHOICE_KEY: String = "ecm_ready_cost_choices"

var _choices: Array[Dictionary] = []
var _local_player: int = -1
var _title_label: Label = null
var _subtitle_label: Label = null
var _choice_box: VBoxContainer = null


func _ready() -> void:
	_ensure_ui()
	_refresh()


func open_from_intent(intent: UIProjector.UIIntent,
		local_player: int) -> void:
	_local_player = local_player
	_choices = _choices_from_intent(intent)
	_ensure_ui()
	_refresh()
	visible = not _choices.is_empty()
	if visible:
		centre_on_screen()


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func choice_count() -> int:
	return _choices.size()


func centre_on_screen(viewport_size: Vector2 = Vector2.ZERO) -> void:
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport_rect().size
	position = (viewport_size - custom_minimum_size) * 0.5


func _choices_from_intent(intent: UIProjector.UIIntent) -> Array[Dictionary]:
	var raw: Variant = intent.payload.get(CHOICE_KEY,
			intent.payload.get("optional_status_rules", []))
	if not raw is Array or (raw as Array).is_empty():
		raw = intent.affordances.get(CHOICE_KEY,
				intent.affordances.get("optional_status_rules", []))
	var choices: Array[Dictionary] = []
	if not raw is Array:
		return choices
	for entry: Variant in raw as Array:
		if not entry is Dictionary:
			continue
		var choice: Dictionary = (entry as Dictionary).duplicate(true)
		if str(choice.get("accepted_command", "")) != "ready_ecm":
			continue
		choices.append(choice)
	return choices


func _ensure_ui() -> void:
	if _title_label != null:
		return
	visible = false
	custom_minimum_size = Vector2(500, 220)
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
			"Electronic Countermeasures", UIStyleHelper.FONT_BODY)
	_subtitle_label = UIStyleHelper.create_section_label(
			"", UIStyleHelper.FONT_HINT, UIStyleHelper.DIMMED_HINT)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 8)
	layout.add_child(_title_label)
	layout.add_child(_subtitle_label)
	layout.add_child(_choice_box)


func _refresh() -> void:
	if _title_label == null:
		return
	_subtitle_label.text = _subtitle_text()
	_rebuild_choices()


func _subtitle_text() -> String:
	if _choices.is_empty():
		return "No Electronic Countermeasures ready-cost choices are available."
	return "Spend 1 Repair token to ready this card, or decline."


func _rebuild_choices() -> void:
	for child: Node in _choice_box.get_children():
		child.queue_free()
	for index: int in range(_choices.size()):
		_choice_box.add_child(_build_choice_row(_choices[index], index))


func _build_choice_row(choice: Dictionary, index: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ECMReadyChoice_%d" % index
	row.add_theme_constant_override("separation", 8)
	var label: Label = UIStyleHelper.create_section_label(
			_choice_label(choice), UIStyleHelper.FONT_HINT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var ready_button: Button = Button.new()
	ready_button.name = "ReadyButton_%d" % index
	ready_button.text = "Ready"
	ready_button.disabled = not _can_act(choice)
	ready_button.custom_minimum_size = Vector2(92, 34)
	ready_button.pressed.connect(_on_ready_pressed.bind(choice))
	row.add_child(ready_button)
	var decline_button: Button = Button.new()
	decline_button.name = "DeclineButton_%d" % index
	decline_button.text = "Decline"
	decline_button.disabled = not _can_act(choice)
	decline_button.custom_minimum_size = Vector2(92, 34)
	decline_button.pressed.connect(_on_decline_pressed.bind(choice))
	row.add_child(decline_button)
	return row


func _choice_label(choice: Dictionary) -> String:
	var source_ref: String = str(choice.get("source_ship_ref", "")).strip_edges()
	if source_ref.is_empty():
		return str(choice.get("prompt",
				"Spend 1 Repair token to ready Electronic Countermeasures?"))
	return "%s (%s)" % [
		str(choice.get("prompt",
				"Spend 1 Repair token to ready Electronic Countermeasures?")),
		source_ref,
	]


func _can_act(choice: Dictionary) -> bool:
	var owner: int = int(choice.get("owner_player", -1))
	return _local_player < 0 or _local_player == owner


func _on_ready_pressed(choice: Dictionary) -> void:
	if not _can_act(choice):
		return
	ready_submitted.emit(
			str(choice.get("runtime_upgrade_id", "")),
			int(choice.get("owner_player", -1)))


func _on_decline_pressed(choice: Dictionary) -> void:
	if not _can_act(choice):
		return
	decline_submitted.emit(
			str(choice.get("runtime_upgrade_id", "")),
			int(choice.get("owner_player", -1)))
