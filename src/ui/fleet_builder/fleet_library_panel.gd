## Fleet Library Panel
##
## Reusable fleet-builder widget for local library save/load, version restore,
## and JSON import/export actions backed by FleetLibraryManager.
class_name FleetLibraryPanel
extends VBoxContainer


## Emitted when an open, save-as, restore, or import operation should replace
## the active editable roster in the parent scene.
signal roster_loaded(roster: FleetRoster)

## Emitted whenever the panel changes its user-visible operation status.
signal status_changed(message: String)

var _library_manager: FleetLibraryManager = FleetLibraryManager.new()
var _current_roster_provider: Callable = Callable()
var _actions: FleetLibraryPanelActions = FleetLibraryPanelActions.new()
var _list_presenter: FleetLibraryListPresenter = FleetLibraryListPresenter.new()
var _fleet_list: ItemList
var _version_list: ItemList
var _target_id_input: LineEdit
var _target_name_input: LineEdit
var _json_text_edit: TextEdit
var _status_label: Label
var _save_button: Button
var _save_as_button: Button
var _open_button: Button
var _duplicate_button: Button
var _delete_button: Button
var _restore_button: Button
var _export_button: Button
var _import_button: Button
var _selected_fleet_id: String = ""
var _selected_version_id: String = ""
var _pending_delete_fleet_id: String = ""


func _init() -> void:
	name = "Library"


func _ready() -> void:
	_build_ui()
	refresh_library()
	sync_current_roster_fields()


## Injects the library service and current-roster provider used by button flows.
func initialize(library_manager: FleetLibraryManager,
		current_roster_provider: Callable) -> void:
	if library_manager != null:
		_library_manager = library_manager
	_current_roster_provider = current_roster_provider
	_actions.initialize(_library_manager, _current_roster_provider)
	if _fleet_list != null:
		refresh_library()
		sync_current_roster_fields()


## Refreshes fleet and version lists from the configured FleetLibraryManager.
func refresh_library() -> void:
	if _fleet_list == null:
		return
	var previous_id: String = _selected_fleet_id
	_selected_fleet_id = _list_presenter.populate_fleets(
			_fleet_list, _library_manager.list_fleets(), previous_id)
	_refresh_versions()


## Updates save-as target fields from the active roster when no fleet is selected.
func sync_current_roster_fields() -> void:
	if _target_id_input == null or not _selected_fleet_id.is_empty():
		return
	var roster: FleetRoster = _actions.current_roster()
	if roster == null:
		return
	_target_id_input.text = roster.fleet_id
	_target_name_input.text = roster.name
	_update_button_states()


func _build_ui() -> void:
	var refs: Dictionary = FleetLibraryPanelView.new().build(self )
	_assign_refs(refs)
	_connect_refs()


func _assign_refs(refs: Dictionary) -> void:
	_target_id_input = refs.get("target_id_input", null) as LineEdit
	_target_name_input = refs.get("target_name_input", null) as LineEdit
	_fleet_list = refs.get("fleet_list", null) as ItemList
	_version_list = refs.get("version_list", null) as ItemList
	_json_text_edit = refs.get("json_text_edit", null) as TextEdit
	_status_label = refs.get("status_label", null) as Label
	_save_button = refs.get("save_button", null) as Button
	_open_button = refs.get("open_button", null) as Button
	_delete_button = refs.get("delete_button", null) as Button
	_save_as_button = refs.get("save_as_button", null) as Button
	_duplicate_button = refs.get("duplicate_button", null) as Button
	_restore_button = refs.get("restore_button", null) as Button
	_export_button = refs.get("export_button", null) as Button
	_import_button = refs.get("import_button", null) as Button


func _connect_refs() -> void:
	_target_id_input.text_changed.connect(_on_target_text_changed)
	_target_name_input.text_changed.connect(_on_target_text_changed)
	_fleet_list.item_selected.connect(_on_fleet_selected)
	_version_list.item_selected.connect(_on_version_selected)
	_json_text_edit.text_changed.connect(_on_json_text_changed)
	_save_button.pressed.connect(_on_save_pressed)
	_open_button.pressed.connect(_on_open_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_save_as_button.pressed.connect(_on_save_as_pressed)
	_duplicate_button.pressed.connect(_on_duplicate_pressed)
	_restore_button.pressed.connect(_on_restore_pressed)
	_export_button.pressed.connect(_on_export_pressed)
	_import_button.pressed.connect(_on_import_pressed)


func _refresh_versions() -> void:
	_version_list.clear()
	_selected_version_id = ""
	if _selected_fleet_id.is_empty():
		_update_button_states()
		return
	var result: Dictionary = _library_manager.list_versions(_selected_fleet_id)
	if not bool(result.get("ok", false)):
		_show_failure(result)
		return
	_selected_version_id = _list_presenter.populate_versions(_version_list, result)
	_update_button_states()


func _set_selected_fleet_from_index(index: int, update_target: bool) -> void:
	var summary: Dictionary = _list_presenter.fleet_summary_at(_fleet_list, index)
	_selected_fleet_id = _list_presenter.fleet_id_at(_fleet_list, index)
	_pending_delete_fleet_id = ""
	if update_target:
		_set_duplicate_target_fields(summary)


func _on_fleet_selected(index: int) -> void:
	_set_selected_fleet_from_index(index, true)
	_refresh_versions()


func _on_version_selected(index: int) -> void:
	_selected_version_id = _list_presenter.version_id_at(_version_list, index)
	_update_button_states()


func _on_target_text_changed(_new_text: String) -> void:
	_update_button_states()


func _on_json_text_changed() -> void:
	_update_button_states()


func _on_save_pressed() -> void:
	_handle_save_result(_actions.save_current(), "Saved")


func _on_save_as_pressed() -> void:
	var result: Dictionary = _actions.save_current_as(_target_fleet_id(), _target_fleet_name())
	if _handle_save_result(result, "Saved As"):
		roster_loaded.emit(result.get("roster", null) as FleetRoster)


func _on_open_pressed() -> void:
	if _selected_fleet_id.is_empty():
		_show_error("Select a fleet to open.")
		return
	_emit_loaded_roster_result(_actions.open_roster(_selected_fleet_id),
			"Opened %s." % _selected_fleet_id)


func _on_duplicate_pressed() -> void:
	if _selected_fleet_id.is_empty():
		_show_error("Select a fleet to duplicate.")
		return
	var result: Dictionary = _actions.duplicate_fleet(
			_selected_fleet_id, _target_fleet_id(), _target_fleet_name())
	if _handle_save_result(result, "Duplicated"):
		_pending_delete_fleet_id = ""


func _on_delete_pressed() -> void:
	if _selected_fleet_id.is_empty():
		_show_error("Select a fleet to delete.")
		return
	if _pending_delete_fleet_id != _selected_fleet_id:
		_pending_delete_fleet_id = _selected_fleet_id
		_show_warning("Press Delete again to confirm.")
		return
	_handle_delete_result(_actions.delete_fleet(_selected_fleet_id))


func _on_restore_pressed() -> void:
	if _selected_fleet_id.is_empty() or _selected_version_id.is_empty():
		_show_error("Select a fleet version to restore.")
		return
	var result: Dictionary = _actions.restore_and_load(
			_selected_fleet_id, _selected_version_id)
	if not bool(result.get("ok", false)):
		_show_failure(result)
		return
	var restored_id: String = str(result.get("version_id", ""))
	_selected_fleet_id = str(result.get("fleet_id", ""))
	refresh_library()
	_emit_loaded_roster_result(result,
			"Restored %s as %s." % [_selected_fleet_id, restored_id])


func _on_export_pressed() -> void:
	if _selected_fleet_id.is_empty():
		_show_error("Select a fleet to export.")
		return
	var result: Dictionary = _actions.export_json(
			_selected_fleet_id, _selected_version_id)
	if _handle_export_result(result):
		_pending_delete_fleet_id = ""


func _on_import_pressed() -> void:
	var result: Dictionary = _actions.import_and_load(_json_text_edit.text)
	if not bool(result.get("ok", false)):
		_show_failure(result)
		return
	_selected_fleet_id = str(result.get("fleet_id", ""))
	refresh_library()
	_emit_loaded_roster_result(result, "Imported %s." % _selected_fleet_id)


func _handle_save_result(result: Dictionary, verb: String) -> bool:
	if not bool(result.get("ok", false)):
		_show_failure(result)
		return false
	_selected_fleet_id = str(result.get("fleet_id", ""))
	refresh_library()
	_show_success("%s %s as %s." % [verb, _selected_fleet_id,
			str(result.get("version_id", ""))])
	return true


func _handle_delete_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_show_failure(result)
		return
	var deleted_id: String = str(result.get("fleet_id", ""))
	_selected_fleet_id = ""
	_pending_delete_fleet_id = ""
	refresh_library()
	_show_success("Deleted %s." % deleted_id)


func _handle_export_result(result: Dictionary) -> bool:
	if not bool(result.get("ok", false)):
		_show_failure(result)
		return false
	_json_text_edit.text = str(result.get("json_text", ""))
	_show_success("Exported %s." % str(result.get("fleet_id", "")))
	return true


func _emit_loaded_roster_result(result: Dictionary, success_message: String) -> bool:
	if not bool(result.get("ok", false)):
		_show_failure(result)
		return false
	var roster: FleetRoster = result.get("roster", null) as FleetRoster
	if roster == null:
		_show_error("Loaded fleet record did not include a roster.")
		return false
	roster_loaded.emit(roster)
	_show_success(success_message)
	return true


func _target_fleet_id() -> String:
	return _target_id_input.text.strip_edges() if _target_id_input != null else ""


func _target_fleet_name() -> String:
	return _target_name_input.text.strip_edges() if _target_name_input != null else ""


func _set_duplicate_target_fields(summary: Dictionary) -> void:
	var fleet_id: String = str(summary.get("fleet_id", ""))
	var fleet_name: String = str(summary.get("name", ""))
	_target_id_input.text = "%s-copy" % fleet_id
	_target_name_input.text = "%s Copy" % (fleet_name if not fleet_name.is_empty() else fleet_id)
	_update_button_states()


func _update_button_states() -> void:
	if _save_button == null:
		return
	var has_roster: bool = _actions.has_current_roster()
	var has_fleet: bool = not _selected_fleet_id.is_empty()
	_save_button.disabled = not has_roster
	_save_as_button.disabled = not has_roster or _target_fleet_id().is_empty()
	_open_button.disabled = not has_fleet
	_duplicate_button.disabled = not has_fleet or _target_fleet_id().is_empty()
	_delete_button.disabled = not has_fleet
	_restore_button.disabled = not has_fleet or _selected_version_id.is_empty()
	_export_button.disabled = not has_fleet
	_import_button.disabled = _json_text_edit == null or _json_text_edit.text.strip_edges().is_empty()


func _show_success(message: String) -> void:
	_set_status(message, UIStyleHelper.BODY_TEXT)


func _show_warning(message: String) -> void:
	_set_status(message, Color(0.9, 0.7, 0.3))


func _show_error(message: String) -> void:
	_set_status(message, Color(1.0, 0.6, 0.55))


func _show_failure(result: Dictionary) -> void:
	_show_error(str(result.get("message", "Library operation failed.")))


func _set_status(message: String, color: Color) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", color)
	status_changed.emit(message)
