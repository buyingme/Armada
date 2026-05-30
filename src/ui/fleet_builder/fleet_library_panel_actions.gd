## Fleet Library Panel Actions
##
## UI-independent operation adapter for FleetLibraryPanel. It keeps file-backed
## library calls and current-roster copying out of the Control script.
class_name FleetLibraryPanelActions
extends RefCounted


var _library_manager: FleetLibraryManager = FleetLibraryManager.new()
var _current_roster_provider: Callable = Callable()


## Injects the library service and current-roster provider.
func initialize(library_manager: FleetLibraryManager,
		current_roster_provider: Callable) -> void:
	if library_manager != null:
		_library_manager = library_manager
	_current_roster_provider = current_roster_provider


## Returns true when a current editable roster is available.
func has_current_roster() -> bool:
	return current_roster() != null


## Returns the current editable roster from the injected provider.
func current_roster() -> FleetRoster:
	if not _current_roster_provider.is_valid():
		return null
	return _current_roster_provider.call() as FleetRoster


## Saves the current roster as a new local version.
func save_current() -> Dictionary:
	var roster: FleetRoster = current_roster()
	if roster == null:
		return _failure("invalid_roster", "No active roster to save.")
	return _library_manager.save_roster(roster)


## Saves a copied current roster under the requested target id and optional name.
func save_current_as(target_id: String, target_name: String) -> Dictionary:
	var roster: FleetRoster = current_roster()
	if roster == null:
		return _failure("invalid_roster", "No active roster to save.")
	if target_id.strip_edges().is_empty():
		return _failure("invalid_target", "Target fleet id is required.")
	var target_roster: FleetRoster = _target_roster_copy(roster, target_id, target_name)
	var result: Dictionary = _library_manager.save_roster(target_roster)
	if bool(result.get("ok", false)):
		result["roster"] = target_roster
	return result


## Loads a fleet roster version.
func open_roster(fleet_id: String, version_id: String = "") -> Dictionary:
	if fleet_id.strip_edges().is_empty():
		return _failure("invalid_fleet_id", "Select a fleet to open.")
	return _library_manager.load_roster(fleet_id, version_id)


## Duplicates a saved fleet record.
func duplicate_fleet(source_id: String, target_id: String,
		target_name: String) -> Dictionary:
	if source_id.strip_edges().is_empty():
		return _failure("invalid_fleet_id", "Select a fleet to duplicate.")
	return _library_manager.duplicate_fleet(source_id, target_id, target_name)


## Deletes a saved fleet record.
func delete_fleet(fleet_id: String) -> Dictionary:
	if fleet_id.strip_edges().is_empty():
		return _failure("invalid_fleet_id", "Select a fleet to delete.")
	return _library_manager.delete_fleet(fleet_id)


## Restores a saved version and loads the new active roster snapshot.
func restore_and_load(fleet_id: String, version_id: String) -> Dictionary:
	if fleet_id.strip_edges().is_empty() or version_id.strip_edges().is_empty():
		return _failure("invalid_version", "Select a fleet version to restore.")
	var restored: Dictionary = _library_manager.restore_version(fleet_id, version_id)
	if not bool(restored.get("ok", false)):
		return restored
	var loaded: Dictionary = _library_manager.load_roster(fleet_id)
	if not bool(loaded.get("ok", false)):
		return loaded
	loaded["version_id"] = str(restored.get("version_id", ""))
	loaded["restored_from"] = version_id
	return loaded


## Exports the selected fleet version to the FB8 JSON contract.
func export_json(fleet_id: String, version_id: String = "") -> Dictionary:
	if fleet_id.strip_edges().is_empty():
		return _failure("invalid_fleet_id", "Select a fleet to export.")
	return _library_manager.export_roster_json(fleet_id, version_id)


## Imports fleet JSON and loads the imported active roster.
func import_and_load(json_text: String) -> Dictionary:
	if json_text.strip_edges().is_empty():
		return _failure("empty_import", "Paste fleet JSON before importing.")
	var imported: Dictionary = _library_manager.import_roster_json(json_text)
	if not bool(imported.get("ok", false)):
		return imported
	return _library_manager.load_roster(str(imported.get("fleet_id", "")))


func _target_roster_copy(roster: FleetRoster, target_id: String,
		target_name: String) -> FleetRoster:
	var copy: FleetRoster = FleetRoster.deserialize(roster.serialize())
	copy.fleet_id = target_id.strip_edges()
	if not target_name.strip_edges().is_empty():
		copy.name = target_name.strip_edges()
	return copy


func _failure(reason: String, message: String) -> Dictionary:
	return {"ok": false, "reason": reason, "message": message}
