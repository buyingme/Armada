## SaveGameManager
##
## Autoload singleton responsible for saving and loading game state to disk.
## Serializes the full [GameState] (including all player ships, squadrons,
## damage deck) to a JSON file under [code]res://saves/[/code].
## Files are stored inside the project directory for easy debugging access.
##
## Design:
##   - [method save_game] writes the current [GameState] from [GameManager].
##   - [method load_game] reads a JSON file and returns a [GameState].
##   - Ship/squadron template re-association is the caller's responsibility
##     (via [code]AssetLoader[/code] look-ups), because templates are
##     [Resource] objects that cannot be serialized to JSON.
##
## Rules Reference: General — game state persistence for mid-game save/load.
extends Node


## Directory under the project root where save files are stored.
## Uses [code]res://[/code] so saves land in the project folder for easy
## debugging. Change to [code]user://[/code] for release builds.
const SAVE_DIR: String = "res://saves"

## File extension for save files.
const SAVE_EXT: String = ".json"

## Logger for this system.
var _log: GameLogger = GameLogger.new("SaveGameManager")


## Saves the given [GameState] to a JSON file.
## [param game_state] — the game state to persist.
## [param file_name] — the save file name (without extension).
## Returns [code]true[/code] on success.
func save_game(game_state: GameState, file_name: String = "quicksave") -> bool:
	var dir_path: String = SAVE_DIR
	if not DirAccess.dir_exists_absolute(dir_path):
		var err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			_log.error("Failed to create save directory: %s" % dir_path)
			return false
	var file_path: String = "%s/%s%s" % [dir_path, file_name, SAVE_EXT]
	var data: Dictionary = game_state.serialize()
	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		_log.error("Failed to open save file for writing: %s" % file_path)
		return false
	file.store_string(json_string)
	file.close()
	_log.info("Game saved to %s" % file_path)
	return true


## Loads a [GameState] from a JSON save file.
## [param file_name] — the save file name (without extension).
## Returns the deserialized [GameState], or [code]null[/code] on failure.
## Note: Ship and squadron arrays in each [PlayerState] will be empty;
## the caller must reconstruct them from the serialized data using
## [code]AssetLoader[/code] template look-ups.
func load_game(file_name: String = "quicksave") -> GameState:
	var file_path: String = "%s/%s%s" % [SAVE_DIR, file_name, SAVE_EXT]
	if not FileAccess.file_exists(file_path):
		_log.error("Save file not found: %s" % file_path)
		return null
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_log.error("Failed to open save file for reading: %s" % file_path)
		return null
	var json_string: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(json_string)
	if parse_err != OK:
		_log.error("Failed to parse save JSON: %s (line %d)" %
				[json.get_error_message(), json.get_error_line()])
		return null
	var data: Dictionary = json.data as Dictionary
	if data == null:
		_log.error("Save file does not contain a valid dictionary.")
		return null
	var state: GameState = GameState.deserialize(data)
	_log.info("Game loaded from %s" % file_path)
	return state


## Returns an array of available save file names (without extension).
func list_saves() -> Array[String]:
	var dir_path: String = SAVE_DIR
	var saves: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return saves
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return saves
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(SAVE_EXT):
			saves.append(entry.trim_suffix(SAVE_EXT))
		entry = dir.get_next()
	dir.list_dir_end()
	return saves


## Deletes a save file.
## [param file_name] — the save file name (without extension).
## Returns [code]true[/code] if the file was deleted.
func delete_save(file_name: String) -> bool:
	var file_path: String = "%s/%s%s" % [SAVE_DIR, file_name, SAVE_EXT]
	if not FileAccess.file_exists(file_path):
		_log.info("Save file not found for deletion: %s" % file_path)
		return false
	var err: Error = DirAccess.remove_absolute(file_path)
	if err != OK:
		_log.error("Failed to delete save file: %s" % file_path)
		return false
	_log.info("Save file deleted: %s" % file_path)
	return true
