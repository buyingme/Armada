## Fleet Library Manager
##
## File-backed local fleet library with version snapshots and import/export
## helpers for the fleet roster JSON contract.
class_name FleetLibraryManager
extends RefCounted


const RECORD_FORMAT_VERSION: int = 1
const RECORD_KIND: String = "fleet_library_record"
const EXPORT_FORMAT_VERSION: int = 1
const EXPORT_KIND: String = "fleet_export"
const FILE_EXT: String = ".json"

static var LIBRARY_DIR: String = PathConfig.SAVES_DIR + "/fleets"


## Saves [param roster] as the active library version for its fleet id.
func save_roster(roster: FleetRoster, source: String = "local") -> Dictionary:
	if roster == null:
		return _failure("invalid_roster", "Roster is null.")
	var payload: Dictionary = roster.serialize()
	var normalized: Dictionary = _normalize_roster_payload(payload, source)
	return _save_payload(normalized, source)


## Loads the active or requested version of [param fleet_id].
func load_roster(fleet_id: String, version_id: String = "") -> Dictionary:
	var record_result: Dictionary = _read_record(fleet_id)
	if not bool(record_result.get("ok", false)):
		return record_result
	var record: Dictionary = record_result.get("record", {}) as Dictionary
	var version: Dictionary = _active_or_requested_version(record, version_id)
	if version.is_empty():
		return _failure("version_not_found", "Requested version was not found.")
	var payload: Dictionary = version.get("roster", {}) as Dictionary
	var roster: FleetRoster = FleetRoster.deserialize(payload)
	return {
		"ok": true,
		"fleet_id": fleet_id,
		"version_id": String(version.get("version_id", "")),
		"roster": roster,
	}


## Lists all fleet summaries in deterministic fleet-id order.
func list_fleets() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for path: String in _list_record_paths():
		var record_result: Dictionary = _read_record_path(path)
		if not bool(record_result.get("ok", false)):
			continue
		var record: Dictionary = record_result.get("record", {}) as Dictionary
		summaries.append(_summarize_record(record))
	summaries.sort_custom(_summary_before)
	return summaries


## Deletes the fleet record for [param fleet_id].
func delete_fleet(fleet_id: String) -> Dictionary:
	var path: String = _record_path(fleet_id)
	if not FileAccess.file_exists(path):
		return _failure("missing", "Fleet record does not exist.")
	var err: Error = DirAccess.remove_absolute(path)
	if err != OK:
		return _failure("delete_failed", "Failed to delete fleet record.")
	return {"ok": true, "fleet_id": fleet_id}


## Duplicates [param source_fleet_id] to [param new_fleet_id] and name.
func duplicate_fleet(source_fleet_id: String, new_fleet_id: String,
		new_name: String) -> Dictionary:
	if new_fleet_id.strip_edges().is_empty():
		return _failure("invalid_fleet_id", "New fleet id is required.")
	var loaded: Dictionary = load_roster(source_fleet_id)
	if not bool(loaded.get("ok", false)):
		return loaded
	var roster: FleetRoster = loaded.get("roster") as FleetRoster
	if roster == null:
		return _failure("invalid_roster", "Source roster could not be read.")
	roster.fleet_id = new_fleet_id
	if not new_name.strip_edges().is_empty():
		roster.name = new_name
	roster.source = "duplicate"
	roster.updated_at = _iso_timestamp()
	return save_roster(roster, "duplicate")


## Lists version snapshots for [param fleet_id].
func list_versions(fleet_id: String) -> Dictionary:
	var record_result: Dictionary = _read_record(fleet_id)
	if not bool(record_result.get("ok", false)):
		return record_result
	var record: Dictionary = record_result.get("record", {}) as Dictionary
	var versions: Array = record.get("versions", []) as Array
	var summary: Array[Dictionary] = []
	for version: Variant in versions:
		if version is Dictionary:
			summary.append(_summarize_version(version as Dictionary))
	return {
		"ok": true,
		"fleet_id": fleet_id,
		"active_version_id": String(record.get("active_version_id", "")),
		"versions": summary,
	}


## Restores [param version_id] as a new active snapshot.
func restore_version(fleet_id: String, version_id: String) -> Dictionary:
	var record_result: Dictionary = _read_record(fleet_id)
	if not bool(record_result.get("ok", false)):
		return record_result
	var record: Dictionary = record_result.get("record", {}) as Dictionary
	var source_version: Dictionary = _find_version(record, version_id)
	if source_version.is_empty():
		return _failure("version_not_found", "Requested version was not found.")
	_append_version(record, source_version.get("roster", {}) as Dictionary,
		"restore", version_id)
	var write_result: Dictionary = _write_record(record)
	if not bool(write_result.get("ok", false)):
		return write_result
	return {
		"ok": true,
		"fleet_id": fleet_id,
		"restored_from": version_id,
		"version_id": String(record.get("active_version_id", "")),
	}


## Exports a fleet version using the FB8 JSON contract.
func export_roster_json(fleet_id: String, version_id: String = "") -> Dictionary:
	var record_result: Dictionary = _read_record(fleet_id)
	if not bool(record_result.get("ok", false)):
		return record_result
	var record: Dictionary = record_result.get("record", {}) as Dictionary
	var version: Dictionary = _active_or_requested_version(record, version_id)
	if version.is_empty():
		return _failure("version_not_found", "Requested version was not found.")
	var payload: Dictionary = {
		"format_version": EXPORT_FORMAT_VERSION,
		"kind": EXPORT_KIND,
		"fleet": (version.get("roster", {}) as Dictionary).duplicate(true),
		"metadata": {
			"fleet_id": fleet_id,
			"version_id": String(version.get("version_id", "")),
			"exported_at": _iso_timestamp(),
		},
	}
	return {
		"ok": true,
		"fleet_id": fleet_id,
		"version_id": String(version.get("version_id", "")),
		"json_text": JSON.stringify(payload, "\t"),
	}


## Imports a fleet from JSON text and stores it as a new local snapshot.
func import_roster_json(json_text: String) -> Dictionary:
	var parsed: Dictionary = _parse_json_dict(json_text)
	if not bool(parsed.get("ok", false)):
		return parsed
	var payload: Dictionary = parsed.get("data", {}) as Dictionary
	var roster_payload: Dictionary = _imported_roster_payload(payload)
	if roster_payload.is_empty():
		return _failure("schema_invalid", "Import JSON is missing fleet roster data.")
	var normalized: Dictionary = _normalize_roster_payload(roster_payload, "import")
	return _save_payload(normalized, "import")


func _save_payload(roster_payload: Dictionary, source: String) -> Dictionary:
	var fleet_id: String = String(roster_payload.get("fleet_id", "")).strip_edges()
	if fleet_id.is_empty():
		return _failure("invalid_fleet_id", "Fleet id is required.")
	var record_result: Dictionary = _read_record(fleet_id)
	var record: Dictionary = _empty_record(fleet_id)
	if bool(record_result.get("ok", false)):
		record = record_result.get("record", {}) as Dictionary
	_append_version(record, roster_payload, source)
	record["name"] = String(roster_payload.get("name", ""))
	record["faction"] = String(roster_payload.get("faction", ""))
	record["updated_at"] = _iso_timestamp()
	var write_result: Dictionary = _write_record(record)
	if not bool(write_result.get("ok", false)):
		return write_result
	return {
		"ok": true,
		"fleet_id": fleet_id,
		"version_id": String(record.get("active_version_id", "")),
	}


func _append_version(record: Dictionary, roster_payload: Dictionary,
		source: String, restored_from: String = "") -> void:
	var versions: Array = record.get("versions", []) as Array
	var version_id: String = _next_version_id(versions)
	versions.append(_new_version_entry(version_id, roster_payload, source, restored_from))
	record["versions"] = versions
	record["active_version_id"] = version_id


func _new_version_entry(version_id: String, roster_payload: Dictionary,
		source: String, restored_from: String) -> Dictionary:
	var entry: Dictionary = {
		"version_id": version_id,
		"saved_at": _iso_timestamp(),
		"source": source,
		"roster": roster_payload.duplicate(true),
		"canonical_hash": CanonicalJson.hash(roster_payload),
	}
	if not restored_from.is_empty():
		entry["restored_from"] = restored_from
	return entry


func _next_version_id(versions: Array) -> String:
	return "v%04d" % (versions.size() + 1)


func _imported_roster_payload(payload: Dictionary) -> Dictionary:
	if String(payload.get("kind", "")) == EXPORT_KIND:
		var exported_fleet: Variant = payload.get("fleet", {})
		if exported_fleet is Dictionary:
			return (exported_fleet as Dictionary).duplicate(true)
	if String(payload.get("kind", "")) == FleetRoster.KIND:
		return payload.duplicate(true)
	if payload.has("fleet_id") and payload.has("name") and payload.has("faction"):
		return payload.duplicate(true)
	return {}


func _normalize_roster_payload(payload: Dictionary, source: String) -> Dictionary:
	var normalized: Dictionary = payload.duplicate(true)
	if String(normalized.get("fleet_id", "")).strip_edges().is_empty():
		normalized["fleet_id"] = "imported_%d" % Time.get_unix_time_from_system()
	if String(normalized.get("name", "")).strip_edges().is_empty():
		normalized["name"] = "Imported Fleet"
	if String(normalized.get("faction", "")).strip_edges().is_empty():
		normalized["faction"] = "REBEL_ALLIANCE"
	normalized["format_version"] = int(normalized.get(
		"format_version", FleetRoster.FORMAT_VERSION))
	normalized["kind"] = String(normalized.get("kind", FleetRoster.KIND))
	normalized["source"] = source
	normalized["updated_at"] = _iso_timestamp()
	if not normalized.has("created_at"):
		normalized["created_at"] = String(normalized.get("updated_at", ""))
	if not normalized.has("point_format"):
		normalized["point_format"] = {"id": "CUSTOM", "limit": 400}
	if not normalized.has("future_sync"):
		normalized["future_sync"] = {}
	if not normalized.has("ships"):
		normalized["ships"] = []
	if not normalized.has("squadrons"):
		normalized["squadrons"] = []
	if not normalized.has("objectives"):
		normalized["objectives"] = {}
	return normalized


func _active_or_requested_version(record: Dictionary,
		version_id: String) -> Dictionary:
	if version_id.strip_edges().is_empty():
		return _find_version(record, String(record.get("active_version_id", "")))
	return _find_version(record, version_id)


func _find_version(record: Dictionary, version_id: String) -> Dictionary:
	var versions: Array = record.get("versions", []) as Array
	for version: Variant in versions:
		if version is Dictionary:
			var version_dict: Dictionary = version as Dictionary
			if String(version_dict.get("version_id", "")) == version_id:
				return version_dict
	return {}


func _summarize_record(record: Dictionary) -> Dictionary:
	var versions: Array = record.get("versions", []) as Array
	return {
		"fleet_id": String(record.get("fleet_id", "")),
		"name": String(record.get("name", "")),
		"faction": String(record.get("faction", "")),
		"active_version_id": String(record.get("active_version_id", "")),
		"version_count": versions.size(),
		"updated_at": String(record.get("updated_at", "")),
	}


func _summarize_version(version: Dictionary) -> Dictionary:
	return {
		"version_id": String(version.get("version_id", "")),
		"saved_at": String(version.get("saved_at", "")),
		"source": String(version.get("source", "")),
		"canonical_hash": String(version.get("canonical_hash", "")),
		"restored_from": String(version.get("restored_from", "")),
	}


func _read_record(fleet_id: String) -> Dictionary:
	if fleet_id.strip_edges().is_empty():
		return _failure("invalid_fleet_id", "Fleet id is required.")
	return _read_record_path(_record_path(fleet_id))


func _read_record_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _failure("missing", "Fleet record does not exist.")
	var parsed: Dictionary = _parse_json_dict(FileAccess.get_file_as_string(path))
	if not bool(parsed.get("ok", false)):
		return parsed
	var record: Dictionary = parsed.get("data", {}) as Dictionary
	if String(record.get("kind", "")) != RECORD_KIND:
		return _failure("schema_invalid", "Invalid fleet record kind.")
	return {"ok": true, "record": record}


func _write_record(record: Dictionary) -> Dictionary:
	if not _ensure_library_dir():
		return _failure("io_error", "Failed to create fleet library directory.")
	var path: String = _record_path(String(record.get("fleet_id", "")))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _failure("io_error", "Failed to open fleet record for writing.")
	file.store_string(JSON.stringify(record, "\t"))
	file.store_string("\n")
	file.close()
	return {"ok": true}


func _empty_record(fleet_id: String) -> Dictionary:
	return {
		"format_version": RECORD_FORMAT_VERSION,
		"kind": RECORD_KIND,
		"fleet_id": fleet_id,
		"name": "",
		"faction": "",
		"active_version_id": "",
		"updated_at": "",
		"versions": [],
	}


func _record_path(fleet_id: String) -> String:
	return "%s/%s%s" % [LIBRARY_DIR, fleet_id, FILE_EXT]


func _list_record_paths() -> Array[String]:
	var paths: Array[String] = []
	if not _ensure_library_dir():
		return paths
	var dir: DirAccess = DirAccess.open(LIBRARY_DIR)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.ends_with(FILE_EXT):
			paths.append("%s/%s" % [LIBRARY_DIR, entry])
		entry = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths


func _ensure_library_dir() -> bool:
	if DirAccess.dir_exists_absolute(LIBRARY_DIR):
		return true
	return DirAccess.make_dir_recursive_absolute(LIBRARY_DIR) == OK


func _parse_json_dict(json_text: String) -> Dictionary:
	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(json_text)
	if parse_err != OK:
		return _failure("parse_error", "Invalid JSON: %s" % json.get_error_message())
	if not json.data is Dictionary:
		return _failure("schema_invalid", "JSON root must be an object.")
	return {"ok": true, "data": json.data as Dictionary}


func _iso_timestamp() -> String:
	return Time.get_datetime_string_from_system(true)


func _failure(reason: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"message": message,
	}


static func _summary_before(left: Dictionary, right: Dictionary) -> bool:
	return String(left.get("fleet_id", "")) < String(right.get("fleet_id", ""))
