## Narrow presentation-only side-assignment dialog for MATCH-003.
## It never derives principal authority; it can only return the explicit
## endpoint -> saved-player proposal selected by the host.
class_name NetworkSideAssignmentDialog
extends PanelContainer


signal assignment_confirmed(proposals: Dictionary)
signal cancelled()


var _selectors: Dictionary = {}
var _confirm: Button
var _status: Label
var _rows_container: VBoxContainer


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func configure(endpoint_labels: Dictionary, endpoint_ids: Array[int],
		available_players: Array[int], saved_side_labels: Dictionary = {}) -> void:
	for child: Node in _rows_container.get_children():
		child.queue_free()
	_selectors = {}
	var rows := VBoxContainer.new()
	rows.name = "AssignmentRows"
	rows.add_theme_constant_override("separation", 8)
	_rows_container.add_child(rows)
	for endpoint_id: int in endpoint_ids:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.custom_minimum_size = Vector2(190, 0)
		label.text = str(endpoint_labels.get(endpoint_id, "Endpoint %d" % endpoint_id))
		row.add_child(label)
		var selector := OptionButton.new()
		selector.add_item("Choose saved side", -1)
		for player_index: int in available_players:
			selector.add_item(str(saved_side_labels.get(player_index,
					"Unknown Faction — Unnamed Fleet")), player_index)
		selector.item_selected.connect(_refresh_confirmation)
		row.add_child(selector)
		rows.add_child(row)
		_selectors[endpoint_id] = selector
	_refresh_confirmation(0)


func show_modal() -> void:
	visible = true
	await get_tree().process_frame
	position = (get_viewport_rect().size - size) * 0.5


func hide_modal() -> void:
	visible = false


func _build_ui() -> void:
	add_theme_stylebox_override("panel", UIStyleHelper.create_modal_panel_style(0.0))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Assign Saved Sides"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_status = Label.new()
	_status.text = "Both endpoints must be assigned different saved sides."
	box.add_child(_status)
	_rows_container = VBoxContainer.new()
	box.add_child(_rows_container)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func() -> void: hide_modal(); cancelled.emit())
	actions.add_child(cancel)
	_confirm = Button.new()
	_confirm.text = "Resume With This Assignment"
	_confirm.disabled = true
	_confirm.pressed.connect(_confirm_assignment)
	actions.add_child(_confirm)
	box.add_child(actions)


func _refresh_confirmation(_selected: int) -> void:
	var selected: Dictionary = {}
	for endpoint_id: Variant in _selectors.keys():
		var selector: OptionButton = _selectors[endpoint_id] as OptionButton
		var player_index: int = selector.get_selected_id()
		if player_index < 0 or selected.has(player_index):
			_confirm.disabled = true
			return
		selected[player_index] = true
	_confirm.disabled = selected.size() != _selectors.size()


func _confirm_assignment() -> void:
	var proposals: Dictionary = {}
	for endpoint_id: Variant in _selectors.keys():
		var selector: OptionButton = _selectors[endpoint_id] as OptionButton
		proposals[int(endpoint_id)] = selector.get_selected_id()
	hide_modal()
	assignment_confirmed.emit(proposals)
