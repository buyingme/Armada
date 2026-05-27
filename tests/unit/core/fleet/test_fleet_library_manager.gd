## Test: FleetLibraryManager
##
## Unit tests for FB8 local fleet library persistence and import/export.
extends GutTest


var _library_manager_script: GDScript = preload(
		"res://src/core/fleet/fleet_library_manager.gd")

var _manager: FleetLibraryManager
var _original_library_dir: String = ""
var _test_library_dir: String = "user://test_fleet_library"


func before_each() -> void:
	_original_library_dir = _library_manager_script.LIBRARY_DIR
	_library_manager_script.LIBRARY_DIR = _test_library_dir
	_cleanup_test_dir()
	_manager = FleetLibraryManager.new()


func after_each() -> void:
	_cleanup_test_dir()
	_library_manager_script.LIBRARY_DIR = _original_library_dir


func test_save_then_list_then_load_round_trip_expected() -> void:
	var roster: FleetRoster = _create_roster("fleet-alpha", "Alpha Fleet")

	var saved: Dictionary = _manager.save_roster(roster)
	var listed: Array[Dictionary] = _manager.list_fleets()
	var loaded: Dictionary = _manager.load_roster("fleet-alpha")

	assert_true(saved.get("ok", false), "Saving roster should succeed")
	assert_eq(listed.size(), 1, "Library should contain one fleet summary")
	assert_true(loaded.get("ok", false), "Loading saved roster should succeed")
	assert_eq((loaded.get("roster") as FleetRoster).name, "Alpha Fleet",
		"Loaded roster should preserve fleet name")


func test_save_same_fleet_creates_version_snapshots_expected() -> void:
	var roster: FleetRoster = _create_roster("fleet-alpha", "Alpha Fleet")
	_manager.save_roster(roster)
	roster.name = "Alpha Fleet Mk II"
	_manager.save_roster(roster)

	var versions: Dictionary = _manager.list_versions("fleet-alpha")

	assert_true(versions.get("ok", false), "Version listing should succeed")
	assert_eq((versions.get("versions", []) as Array).size(), 2,
		"Saving same fleet twice should create two versions")


func test_restore_version_appends_new_active_snapshot_expected() -> void:
	var roster: FleetRoster = _create_roster("fleet-alpha", "Alpha Fleet")
	var first: Dictionary = _manager.save_roster(roster)
	roster.name = "Alpha Fleet Mk II"
	_manager.save_roster(roster)

	var restored: Dictionary = _manager.restore_version(
		"fleet-alpha", String(first.get("version_id", "")))
	var loaded: Dictionary = _manager.load_roster("fleet-alpha")

	assert_true(restored.get("ok", false), "Restore version should succeed")
	assert_eq((loaded.get("roster") as FleetRoster).name, "Alpha Fleet",
		"Restored version should become active snapshot")


func test_duplicate_fleet_creates_independent_record_expected() -> void:
	var source: FleetRoster = _create_roster("fleet-source", "Source Fleet")
	_manager.save_roster(source)

	var duplicated: Dictionary = _manager.duplicate_fleet(
		"fleet-source", "fleet-copy", "Copied Fleet")
	var loaded: Dictionary = _manager.load_roster("fleet-copy")

	assert_true(duplicated.get("ok", false), "Duplicating fleet should succeed")
	assert_true(loaded.get("ok", false), "Duplicated fleet should be loadable")
	assert_eq((loaded.get("roster") as FleetRoster).name, "Copied Fleet",
		"Duplicated fleet should use requested name")


func test_delete_fleet_removes_record_expected() -> void:
	var roster: FleetRoster = _create_roster("fleet-alpha", "Alpha Fleet")
	_manager.save_roster(roster)

	var deleted: Dictionary = _manager.delete_fleet("fleet-alpha")
	var loaded: Dictionary = _manager.load_roster("fleet-alpha")

	assert_true(deleted.get("ok", false), "Delete should succeed")
	assert_false(loaded.get("ok", false), "Deleted fleet should no longer load")
	assert_eq(loaded.get("reason", ""), "missing",
		"Deleted fleet should report missing record")


func test_import_invalid_json_returns_readable_error_expected() -> void:
	var result: Dictionary = _manager.import_roster_json("{ broken")

	assert_false(result.get("ok", false), "Invalid JSON import should fail")
	assert_eq(result.get("reason", ""), "parse_error",
		"Invalid JSON should report parse_error reason")
	assert_false(String(result.get("message", "")).is_empty(),
		"Invalid JSON should return a readable message")


func test_import_export_round_trip_preserves_unknown_fields_expected() -> void:
	var import_payload: Dictionary = {
		"format_version": 1,
		"kind": "fleet_export",
		"fleet": {
			"format_version": 1,
			"kind": "fleet_roster",
			"fleet_id": "fleet-imported",
			"name": "Imported Fleet",
			"faction": "REBEL_ALLIANCE",
			"point_format": {"id": "CUSTOM", "limit": 180},
			"ships": [],
			"squadrons": [],
			"objectives": {},
			"future_field": {"nested": 7},
		},
	}
	var imported: Dictionary = _manager.import_roster_json(
		JSON.stringify(import_payload, "\t"))
	var exported: Dictionary = _manager.export_roster_json("fleet-imported")
	var parsed: Dictionary = _parse_json(exported.get("json_text", "") as String)
	var fleet_payload: Dictionary = parsed.get("fleet", {}) as Dictionary

	assert_true(imported.get("ok", false), "Import should succeed")
	assert_true(exported.get("ok", false), "Export should succeed")
	assert_true(fleet_payload.has("future_field"),
		"Export should preserve unknown imported fleet fields")
	assert_eq(int((fleet_payload.get("future_field", {}) as Dictionary).get("nested", 0)), 7,
		"Unknown field payload should round-trip unchanged")


func _create_roster(fleet_id: String, name: String) -> FleetRoster:
	var roster: FleetRoster = FleetRoster.create(fleet_id, name, "REBEL_ALLIANCE")
	roster.point_format = {"id": "CUSTOM", "limit": 180}
	var objectives: FleetObjectiveSelection = FleetObjectiveSelection.new()
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_DEFENSE, "obj_def_fire_lanes")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_NAVIGATION,
		"obj_nav_intel_sweep")
	roster.set_objectives(objectives)
	return roster


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


func _parse_json(json_text: String) -> Dictionary:
	var json: JSON = JSON.new()
	assert_eq(json.parse(json_text), OK, "Exported JSON should parse")
	return json.data as Dictionary
