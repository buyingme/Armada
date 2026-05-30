## Fleet Library Panel View
##
## Builds the FleetLibraryPanel controls and returns references for the
## coordinator script to wire to library operations.
class_name FleetLibraryPanelView
extends RefCounted


const TARGET_ID_PLACEHOLDER: String = "Target fleet id"
const TARGET_NAME_PLACEHOLDER: String = "Target fleet name"
const JSON_TEXT_MIN_SIZE: Vector2 = Vector2(0, 120)
const LIST_MIN_HEIGHT: int = 96
const VERSION_MIN_HEIGHT: int = 84
const ACTION_BUTTON_SIZE: Vector2 = Vector2(96, 34)


## Builds all child controls under [param parent] and returns named references.
func build(parent: VBoxContainer) -> Dictionary:
	var refs: Dictionary = {}
	parent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_theme_constant_override("separation", 6)
	parent.add_child(_build_target_fields(refs))
	parent.add_child(_build_fleet_list(refs))
	parent.add_child(_build_primary_actions(refs))
	parent.add_child(_build_version_list(refs))
	parent.add_child(_build_version_actions(refs))
	parent.add_child(_build_json_area(refs))
	refs["status_label"] = _create_status_label()
	parent.add_child(refs["status_label"] as Control)
	return refs


func _build_target_fields(refs: Dictionary) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	refs["target_id_input"] = _create_line_edit(TARGET_ID_PLACEHOLDER)
	refs["target_name_input"] = _create_line_edit(TARGET_NAME_PLACEHOLDER)
	box.add_child(_labeled_control("Target ID", refs["target_id_input"] as Control))
	box.add_child(_labeled_control("Target Name", refs["target_name_input"] as Control))
	return box


func _build_fleet_list(refs: Dictionary) -> VBoxContainer:
	var fleet_list: ItemList = ItemList.new()
	fleet_list.name = "FleetLibraryList"
	fleet_list.custom_minimum_size = Vector2(0, LIST_MIN_HEIGHT)
	refs["fleet_list"] = fleet_list
	return _labeled_control("Saved Fleets", fleet_list)


func _build_primary_actions(refs: Dictionary) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	refs["save_button"] = _action_button("Save")
	refs["open_button"] = _action_button("Open")
	refs["delete_button"] = _action_button("Delete")
	refs["save_as_button"] = _action_button("Save As")
	refs["duplicate_button"] = _action_button("Duplicate")
	box.add_child(_button_row([refs["save_button"], refs["open_button"],
			refs["delete_button"]]))
	box.add_child(_button_row([refs["save_as_button"], refs["duplicate_button"]]))
	return box


func _build_version_list(refs: Dictionary) -> VBoxContainer:
	var version_list: ItemList = ItemList.new()
	version_list.name = "FleetVersionList"
	version_list.custom_minimum_size = Vector2(0, VERSION_MIN_HEIGHT)
	refs["version_list"] = version_list
	return _labeled_control("Versions", version_list)


func _build_version_actions(refs: Dictionary) -> HBoxContainer:
	refs["restore_button"] = _action_button("Restore")
	refs["export_button"] = _action_button("Export")
	refs["import_button"] = _action_button("Import")
	return _button_row([refs["restore_button"], refs["export_button"],
			refs["import_button"]])


func _build_json_area(refs: Dictionary) -> VBoxContainer:
	var text_edit: TextEdit = TextEdit.new()
	text_edit.name = "FleetLibraryJsonText"
	text_edit.custom_minimum_size = JSON_TEXT_MIN_SIZE
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	refs["json_text_edit"] = text_edit
	return _labeled_control("Import / Export JSON", text_edit)


func _create_line_edit(placeholder_text: String) -> LineEdit:
	var input: LineEdit = LineEdit.new()
	input.placeholder_text = placeholder_text
	input.custom_minimum_size.y = 32
	return input


func _action_button(label_text: String) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.custom_minimum_size = ACTION_BUTTON_SIZE
	return button


func _button_row(buttons: Array) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for raw_button: Variant in buttons:
		row.add_child(raw_button as Button)
	return row


func _labeled_control(label_text: String, control: Control) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.add_child(UIStyleHelper.create_section_label(label_text,
			UIStyleHelper.FONT_BODY, UIStyleHelper.BODY_TEXT))
	box.add_child(control)
	return box


func _create_status_label() -> Label:
	var label: Label = UIStyleHelper.create_section_label("Ready",
			UIStyleHelper.FONT_BODY, UIStyleHelper.BODY_TEXT)
	label.name = "FleetLibraryStatus"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
