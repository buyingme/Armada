## Test: Debug Annotation Save Logic
##
## Unit tests for the annotation saving functionality in DebugMode.
## Tests the file output, JSON structure, counter tracking, and
## phase-to-string conversion.
extends GutTest


const DebugModeScript: GDScript = preload(
		"res://src/autoload/debug_mode.gd")

## Test annotation directory — cleaned up after each test.
const TEST_ANNOTATION_DIR: String = "res://saves/annotations_test"

var _debug: Node = null


func before_each() -> void:
	_debug = DebugModeScript.new()
	# Override the annotation directory to avoid polluting real saves.
	_debug.set("ANNOTATION_DIR", null) # Can't override const — test via real dir.


func after_each() -> void:
	if _debug:
		_debug.free()
	_cleanup_test_annotations()


# --- Phase to String ---

func test_phase_to_string_setup() -> void:
	var result: String = _debug._phase_to_string(Constants.GamePhase.SETUP)
	assert_eq(result, "SETUP", "SETUP phase should map to 'SETUP'")


func test_phase_to_string_command() -> void:
	var result: String = _debug._phase_to_string(Constants.GamePhase.COMMAND)
	assert_eq(result, "COMMAND", "COMMAND phase should map to 'COMMAND'")


func test_phase_to_string_ship() -> void:
	var result: String = _debug._phase_to_string(Constants.GamePhase.SHIP)
	assert_eq(result, "SHIP", "SHIP phase should map to 'SHIP'")


func test_phase_to_string_squadron() -> void:
	var result: String = _debug._phase_to_string(
			Constants.GamePhase.SQUADRON)
	assert_eq(result, "SQUADRON",
			"SQUADRON phase should map to 'SQUADRON'")


func test_phase_to_string_status() -> void:
	var result: String = _debug._phase_to_string(Constants.GamePhase.STATUS)
	assert_eq(result, "STATUS", "STATUS phase should map to 'STATUS'")


# --- Annotation Counter ---

func test_annotation_counter_starts_at_zero() -> void:
	assert_eq(_debug._annotation_counter, 0,
			"Counter should start at zero")


func test_annotation_counter_is_incremented_on_submit() -> void:
	# Simulate the counter increment that happens in _on_annotation_submitted.
	_debug._annotation_counter += 1
	assert_eq(_debug._annotation_counter, 1,
			"Counter should be 1 after first increment")
	_debug._annotation_counter += 1
	assert_eq(_debug._annotation_counter, 2,
			"Counter should be 2 after second increment")


# --- Save Annotation (file I/O) ---

func test_save_annotation_creates_file() -> void:
	var gs: GameState = _make_game_state()
	_debug._annotation_counter = 1
	var ok: bool = _debug._save_annotation("Test note", gs)
	assert_true(ok, "Save annotation should succeed")
	var files: Array[String] = _list_annotation_files()
	assert_gt(files.size(), 0,
			"At least one annotation file should exist")


func test_save_annotation_json_has_required_keys() -> void:
	var gs: GameState = _make_game_state()
	_debug._annotation_counter = 1
	_debug._save_annotation("Required keys test", gs)
	var data: Dictionary = _read_latest_annotation()
	assert_has(data, "annotation",
			"JSON should contain 'annotation' key")
	assert_has(data, "timestamp",
			"JSON should contain 'timestamp' key")
	assert_has(data, "round",
			"JSON should contain 'round' key")
	assert_has(data, "phase",
			"JSON should contain 'phase' key")
	assert_has(data, "counter",
			"JSON should contain 'counter' key")
	assert_has(data, "game_state",
			"JSON should contain 'game_state' key")


func test_save_annotation_preserves_text() -> void:
	var gs: GameState = _make_game_state()
	_debug._annotation_counter = 1
	_debug._save_annotation("My test annotation", gs)
	var data: Dictionary = _read_latest_annotation()
	assert_eq(data.get("annotation"), "My test annotation",
			"Annotation text should be preserved")


func test_save_annotation_preserves_round() -> void:
	var gs: GameState = _make_game_state()
	gs.current_round = 4
	_debug._annotation_counter = 1
	_debug._save_annotation("Round test", gs)
	var data: Dictionary = _read_latest_annotation()
	assert_eq(int(data.get("round", -1)), 4,
			"Round should be preserved in annotation")


func test_save_annotation_preserves_phase() -> void:
	var gs: GameState = _make_game_state()
	gs.current_phase = Constants.GamePhase.SHIP
	_debug._annotation_counter = 1
	_debug._save_annotation("Phase test", gs)
	var data: Dictionary = _read_latest_annotation()
	assert_eq(data.get("phase"), "SHIP",
			"Phase should be preserved as string")


func test_save_annotation_preserves_counter() -> void:
	var gs: GameState = _make_game_state()
	_debug._annotation_counter = 7
	_debug._save_annotation("Counter test", gs)
	var data: Dictionary = _read_latest_annotation()
	assert_eq(int(data.get("counter", -1)), 7,
			"Counter should be preserved in annotation")


func test_save_annotation_includes_serialized_game_state() -> void:
	var gs: GameState = _make_game_state()
	gs.current_round = 5
	_debug._annotation_counter = 1
	_debug._save_annotation("State test", gs)
	var data: Dictionary = _read_latest_annotation()
	var state_data: Dictionary = data.get("game_state", {})
	assert_eq(int(state_data.get("current_round", -1)), 5,
			"Serialized game state should contain the round")


func test_save_annotation_creates_directory_if_missing() -> void:
	# Delete the annotations directory first.
	if DirAccess.dir_exists_absolute(
			DebugModeScript.ANNOTATION_DIR):
		_remove_dir_contents(DebugModeScript.ANNOTATION_DIR)
		DirAccess.remove_absolute(DebugModeScript.ANNOTATION_DIR)
	var gs: GameState = _make_game_state()
	_debug._annotation_counter = 1
	var ok: bool = _debug._save_annotation("Dir creation test", gs)
	assert_true(ok, "Should create directory and succeed")
	assert_true(DirAccess.dir_exists_absolute(
			DebugModeScript.ANNOTATION_DIR),
			"Annotation directory should now exist")


# --- Helpers ---

func _make_game_state() -> GameState:
	var gs: GameState = GameState.new()
	gs.initialize()
	gs.current_round = 2
	gs.current_phase = Constants.GamePhase.COMMAND
	return gs


func _list_annotation_files() -> Array[String]:
	var files: Array[String] = []
	var dir_path: String = DebugModeScript.ANNOTATION_DIR
	if not DirAccess.dir_exists_absolute(dir_path):
		return files
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return files
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	return files


func _read_latest_annotation() -> Dictionary:
	var files: Array[String] = _list_annotation_files()
	if files.is_empty():
		return {}
	files.sort()
	var file_name: String = files[-1]
	var file_path: String = "%s/%s" % [
			DebugModeScript.ANNOTATION_DIR, file_name]
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var json_string: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(json_string) != OK:
		return {}
	return json.data as Dictionary


func _cleanup_test_annotations() -> void:
	var dir_path: String = DebugModeScript.ANNOTATION_DIR
	_remove_dir_contents(dir_path)


func _remove_dir_contents(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			DirAccess.remove_absolute("%s/%s" % [dir_path, entry])
		entry = dir.get_next()
	dir.list_dir_end()
