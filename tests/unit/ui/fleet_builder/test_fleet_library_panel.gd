## Test: FleetLibraryPanel
##
## Unit tests for FB10 local fleet library UI operations.
extends GutTest


var _library_manager_script: GDScript = preload(
		"res://src/core/fleet/fleet_library_manager.gd")

var _manager: FleetLibraryManager
var _panel: FleetLibraryPanel
var _current_roster: FleetRoster
var _loaded_roster: FleetRoster
var _original_library_dir: String = ""
var _test_library_dir: String = "user://test_fleet_library_panel"


func before_each() -> void:
	_original_library_dir = _library_manager_script.LIBRARY_DIR
	_library_manager_script.LIBRARY_DIR = _test_library_dir
	_cleanup_test_dir()
	_manager = FleetLibraryManager.new()
	_current_roster = _create_roster("fleet-alpha", "Alpha Fleet")
	_loaded_roster = null
	_panel = FleetLibraryPanel.new()
	_panel.initialize(_manager, Callable(self , "_provide_current_roster"))
	_panel.roster_loaded.connect(_on_roster_loaded)
	add_child(_panel)


func after_each() -> void:
	_free_node(_panel)
	_cleanup_test_dir()
	_library_manager_script.LIBRARY_DIR = _original_library_dir


func test_save_button_lists_current_roster_expected() -> void:
	_panel._on_save_pressed()
	var loaded: Dictionary = _manager.load_roster("fleet-alpha")

	assert_true(loaded.get("ok", false), "Save button should persist current roster")
	assert_eq(_panel._fleet_list.item_count, 1, "Saved roster should appear in fleet list")
	assert_true(_panel._status_label.text.contains("Saved"),
		"Panel should render a save confirmation")


func test_open_button_emits_loaded_roster_expected() -> void:
	_panel._on_save_pressed()
	_current_roster.name = "Unsaved Name"

	_panel._on_open_pressed()

	assert_not_null(_loaded_roster, "Open should emit a loaded roster")
	assert_eq(_loaded_roster.name, "Alpha Fleet",
		"Loaded roster should come from the saved library snapshot")


func test_save_as_uses_target_fields_expected() -> void:
	_panel._target_id_input.text = "fleet-beta"
	_panel._target_name_input.text = "Beta Fleet"

	_panel._on_save_as_pressed()
	var loaded: Dictionary = _manager.load_roster("fleet-beta")

	assert_true(loaded.get("ok", false), "Save As should persist the target id")
	assert_not_null(_loaded_roster, "Save As should emit the saved target roster")
	assert_eq((_loaded_roster as FleetRoster).name, "Beta Fleet",
		"Save As should apply the target fleet name")


func test_save_as_empty_target_shows_target_error_expected() -> void:
	_panel._target_id_input.text = ""

	_panel._on_save_as_pressed()

	assert_true(_panel._status_label.text.contains("Target fleet id"),
		"Missing Save As target should show the target-id validation error")
	assert_null(_loaded_roster, "Invalid Save As should not emit a roster")


func test_duplicate_and_delete_confirmation_expected() -> void:
	_panel._on_save_pressed()
	_panel._target_id_input.text = "fleet-copy"
	_panel._target_name_input.text = "Copied Fleet"

	_panel._on_duplicate_pressed()
	_select_fleet_id("fleet-alpha")
	_panel._on_delete_pressed()
	var armed_text: String = _panel._status_label.text
	_panel._on_delete_pressed()

	assert_true(_manager.load_roster("fleet-copy").get("ok", false),
		"Duplicate should create a second loadable record")
	assert_true(armed_text.contains("confirm"),
		"First Delete press should arm the confirmation state")
	assert_false(_manager.load_roster("fleet-alpha").get("ok", false),
		"Second Delete press should remove the selected fleet")


func test_restore_version_renders_and_loads_restored_roster_expected() -> void:
	_manager.save_roster(_current_roster)
	_current_roster.name = "Alpha Fleet Mk II"
	_manager.save_roster(_current_roster)
	_panel.refresh_library()
	_select_fleet_id("fleet-alpha")
	_select_version_id("v0001")

	_panel._on_restore_pressed()

	assert_eq(_panel._version_list.item_count, 3,
		"Restore should append a new active version row")
	assert_true(_panel._version_list.get_item_text(2).contains("from v0001"),
		"Restored version row should render its source version")
	assert_true(_panel._status_label.text.contains("Restored"),
		"Restore should keep a restore-specific confirmation status")
	assert_not_null(_loaded_roster, "Restore should emit the restored active roster")
	assert_eq(_loaded_roster.name, "Alpha Fleet",
		"Restoring v0001 should load the first saved roster name")


func test_export_button_populates_json_expected() -> void:
	_panel._on_save_pressed()

	_panel._on_export_pressed()

	assert_true(_panel._json_text_edit.text.contains("fleet_export"),
		"Export should place fleet-export JSON in the text area")
	assert_true(_panel._status_label.text.contains("Exported"),
		"Export should render a confirmation status")


func test_import_invalid_json_shows_error_expected() -> void:
	_panel._json_text_edit.text = "{ broken"

	_panel._on_import_pressed()

	assert_null(_loaded_roster, "Invalid import should not emit a roster")
	assert_true(_panel._status_label.text.contains("Invalid JSON"),
		"Invalid import should render the manager error message")


func test_import_json_loads_roster_expected() -> void:
	_panel._json_text_edit.text = JSON.stringify(_export_payload("fleet-imported", "Imported"), "\t")

	_panel._on_import_pressed()

	assert_not_null(_loaded_roster, "Import should emit the imported roster")
	assert_eq(_loaded_roster.fleet_id, "fleet-imported",
		"Imported roster should become the active emitted roster")
	assert_true(_panel._status_label.text.contains("Imported"),
		"Import should render a confirmation status")


func _provide_current_roster() -> FleetRoster:
	return _current_roster


func _on_roster_loaded(roster: FleetRoster) -> void:
	_loaded_roster = roster


func _select_fleet_id(fleet_id: String) -> void:
	for index: int in range(_panel._fleet_list.item_count):
		var summary: Dictionary = _panel._fleet_list.get_item_metadata(index) as Dictionary
		if str(summary.get("fleet_id", "")) == fleet_id:
			_panel._fleet_list.select(index)
			_panel._on_fleet_selected(index)
			return
	fail_test("Fleet id not found: %s" % fleet_id)


func _select_version_id(version_id: String) -> void:
	for index: int in range(_panel._version_list.item_count):
		var version: Dictionary = _panel._version_list.get_item_metadata(index) as Dictionary
		if str(version.get("version_id", "")) == version_id:
			_panel._version_list.select(index)
			_panel._on_version_selected(index)
			return
	fail_test("Version id not found: %s" % version_id)


func _create_roster(fleet_id: String, fleet_name: String) -> FleetRoster:
	var roster: FleetRoster = FleetRoster.create(fleet_id, fleet_name, "REBEL_ALLIANCE")
	roster.point_format = {"id": "CUSTOM", "limit": 180}
	return roster


func _export_payload(fleet_id: String, fleet_name: String) -> Dictionary:
	return {
		"format_version": 1,
		"kind": "fleet_export",
		"fleet": _create_roster(fleet_id, fleet_name).serialize(),
	}


func _cleanup_test_dir() -> void:
	if not DirAccess.dir_exists_absolute(_test_library_dir):
		return
	var dir: DirAccess = DirAccess.open(_test_library_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir():
			DirAccess.remove_absolute("%s/%s" % [_test_library_dir, entry])
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(_test_library_dir)


func _free_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
