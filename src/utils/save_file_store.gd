## SaveFileStore
##
## Private file-system helpers used by SaveGameManager to keep the autoload
## below the Phase K size ceiling.
extends RefCounted


## Returns whether a save-file directory entry should be shown to players.
static func should_list_save_entry(
		dir: DirAccess,
		entry: String,
		save_ext: String,
		system_prefix: String) -> bool:
	if dir.current_is_dir() or not entry.ends_with(save_ext):
		return false
	if not entry.begins_with(system_prefix):
		return true
	return is_instance_valid(LoggingMode) \
			and LoggingMode.enabled \
			and _is_numbered_debug_snapshot(entry, save_ext)


## Removes transient checkpoints and replay files from the previous session.
static func cleanup_session_artifacts(
		save_dir: String,
		save_ext: String,
		system_prefix: String,
		replay_dir: String) -> void:
	_delete_numbered_debug_snapshots(save_dir, save_ext, system_prefix)
	_delete_files_in_dir(replay_dir, ".json")


## Writes the signed save payload to [param file_path].
static func write_payload(
		file_path: String,
		header: Dictionary,
		body: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"header": header, "state": body}, "\t"))
	file.close()
	return true


## Reads a JSON save payload. Returns an empty dictionary on missing/invalid data.
static func read_payload(file_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Dictionary = json.data as Dictionary
	return {} if data == null else data


static func _delete_numbered_debug_snapshots(
		save_dir: String,
		save_ext: String,
		system_prefix: String) -> void:
	if not DirAccess.dir_exists_absolute(save_dir):
		return
	var dir: DirAccess = DirAccess.open(save_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if _is_deletable_debug_snapshot(dir, entry, save_ext, system_prefix):
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()


static func _is_deletable_debug_snapshot(
		dir: DirAccess,
		entry: String,
		save_ext: String,
		system_prefix: String) -> bool:
	return not dir.current_is_dir() \
			and entry.begins_with(system_prefix) \
			and _is_numbered_debug_snapshot(entry, save_ext)


static func _delete_files_in_dir(dir_path: String, extension: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(extension):
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()


static func _is_numbered_debug_snapshot(file_name: String, save_ext: String) -> bool:
	if not file_name.ends_with(save_ext):
		return false
	var stem: String = file_name.substr(0, file_name.length() - save_ext.length())
	var us: int = stem.rfind("_")
	if us < 0:
		return false
	var tail: String = stem.substr(us + 1)
	return not tail.is_empty() and tail.is_valid_int()
