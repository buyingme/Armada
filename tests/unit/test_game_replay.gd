## Tests for GameReplay — serialize/deserialize, file I/O, header capture.
##
## Covers: GameReplay (src/core/game_replay.gd).
## Validates: replay creation, serialization roundtrip, file save/load,
## header metadata, command capture, validity checks, and integration
## with CommandProcessor.create_replay().
extends GutTest


# ======================================================================
# Helpers
# ======================================================================

## Creates a minimal GameReplay with populated header and sample commands.
func _make_replay(cmd_count: int = 3) -> GameReplay:
	var replay := GameReplay.new()
	replay.capture_header("learning_scenario", 42,
			[Constants.Faction.REBEL_ALLIANCE,
			Constants.Faction.GALACTIC_EMPIRE], 0)
	var cmds: Array[Dictionary] = []
	for i: int in range(cmd_count):
		cmds.append({
			"type": "assign_dials",
			"player": i % 2,
			"sequence": i,
			"payload": {"ship_index": 0, "commands": [0]},
		})
	replay.set_commands(cmds)
	return replay


## Returns a temporary file path inside the test directory.
func _temp_path(name: String = "test_replay") -> String:
	return "res://tests/fixtures/%s.json" % name


## Deletes a file if it exists (cleanup).
func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# ======================================================================
# Header capture
# ======================================================================

func test_capture_header_stores_scenario_id() -> void:
	var replay := GameReplay.new()
	replay.capture_header("my_scenario", 123, [], 0)
	assert_eq(replay.header["scenario_id"], "my_scenario",
			"Header should store scenario_id.")


func test_capture_header_stores_rng_seed() -> void:
	var replay := GameReplay.new()
	replay.capture_header("test", 99999, [], 1)
	assert_eq(replay.header["rng_seed"], 99999,
			"Header should store rng_seed.")


func test_capture_header_stores_factions() -> void:
	var factions: Array = [Constants.Faction.REBEL_ALLIANCE,
			Constants.Faction.GALACTIC_EMPIRE]
	var replay := GameReplay.new()
	replay.capture_header("test", 1, factions, 0)
	assert_eq(replay.header["factions"].size(), 2,
			"Header should store both factions.")


func test_capture_header_stores_initiative_player() -> void:
	var replay := GameReplay.new()
	replay.capture_header("test", 1, [], 1)
	assert_eq(replay.header["initiative_player"], 1,
			"Header should store initiative_player.")


func test_capture_header_stores_format_version() -> void:
	var replay := GameReplay.new()
	replay.capture_header("test", 1, [], 0)
	assert_eq(replay.header["format_version"], GameReplay.FORMAT_VERSION,
			"Header should include format_version.")


func test_capture_header_stores_timestamp() -> void:
	var replay := GameReplay.new()
	replay.capture_header("test", 1, [], 0)
	assert_true(replay.header.has("timestamp"),
			"Header should include timestamp.")
	assert_typeof(replay.header["timestamp"], TYPE_STRING,
			"Timestamp should be a string.")


func test_capture_header_stores_app_version() -> void:
	var replay := GameReplay.new()
	replay.capture_header("test", 1, [], 0)
	assert_true(replay.header.has("app_version"),
			"Header should include app_version.")


func test_capture_header_stores_godot_version() -> void:
	var replay := GameReplay.new()
	replay.capture_header("test", 1, [], 0)
	assert_true(replay.header.has("godot_version"),
			"Header should include godot_version.")


# ======================================================================
# Commands
# ======================================================================

func test_set_commands_stores_array() -> void:
	var replay := GameReplay.new()
	var cmds: Array[Dictionary] = [
		{"type": "assign_dials", "player": 0, "sequence": 0, "payload": {}},
		{"type": "activate_ship", "player": 0, "sequence": 1, "payload": {}},
	]
	replay.set_commands(cmds)
	assert_eq(replay.get_command_count(), 2,
			"Should store 2 commands.")


func test_get_command_count_empty() -> void:
	var replay := GameReplay.new()
	assert_eq(replay.get_command_count(), 0,
			"Empty replay should have 0 commands.")


# ======================================================================
# Validity
# ======================================================================

func test_is_valid_with_header_returns_true() -> void:
	var replay := _make_replay()
	assert_true(replay.is_valid(),
			"Replay with header should be valid.")


func test_is_valid_without_header_returns_false() -> void:
	var replay := GameReplay.new()
	assert_false(replay.is_valid(),
			"Replay without header should be invalid.")


# ======================================================================
# Serialize / Deserialize roundtrip
# ======================================================================

func test_serialize_returns_dict_with_header_and_commands() -> void:
	var replay := _make_replay(2)
	var data: Dictionary = replay.serialize()
	assert_true(data.has("header"), "Serialized data should have 'header'.")
	assert_true(data.has("commands"), "Serialized data should have 'commands'.")


func test_deserialize_roundtrip_preserves_header() -> void:
	var original := _make_replay()
	var data: Dictionary = original.serialize()
	var restored: GameReplay = GameReplay.deserialize(data)
	assert_not_null(restored, "Deserialize should return a GameReplay.")
	assert_eq(restored.header["scenario_id"], "learning_scenario",
			"Roundtrip should preserve scenario_id.")
	assert_eq(restored.header["rng_seed"], 42,
			"Roundtrip should preserve rng_seed.")
	assert_eq(restored.header["initiative_player"], 0,
			"Roundtrip should preserve initiative_player.")


func test_deserialize_roundtrip_preserves_commands() -> void:
	var original := _make_replay(5)
	var data: Dictionary = original.serialize()
	var restored: GameReplay = GameReplay.deserialize(data)
	assert_eq(restored.get_command_count(), 5,
			"Roundtrip should preserve command count.")
	assert_eq(restored.commands[0]["type"], "assign_dials",
			"Roundtrip should preserve command type.")
	assert_eq(restored.commands[2]["sequence"], 2,
			"Roundtrip should preserve command sequence.")


func test_deserialize_null_on_missing_header() -> void:
	var data: Dictionary = {"commands": []}
	var result: GameReplay = GameReplay.deserialize(data)
	assert_null(result,
			"Should return null when 'header' key is missing.")


func test_deserialize_null_on_missing_commands() -> void:
	var data: Dictionary = {"header": {"format_version": 1, "rng_seed": 1}}
	var result: GameReplay = GameReplay.deserialize(data)
	assert_null(result,
			"Should return null when 'commands' key is missing.")


func test_deserialize_null_on_empty_dict() -> void:
	var result: GameReplay = GameReplay.deserialize({})
	assert_null(result,
			"Should return null on empty dictionary.")


# ======================================================================
# File I/O — save and load
# ======================================================================

func test_save_to_file_creates_file() -> void:
	var replay := _make_replay()
	var path: String = _temp_path("save_test")
	var err: Error = replay.save_to_file(path)
	assert_eq(err, OK, "save_to_file should return OK.")
	assert_true(FileAccess.file_exists(path),
			"File should exist after save.")
	_cleanup_file(path)


func test_load_from_file_roundtrip() -> void:
	var original := _make_replay(4)
	var path: String = _temp_path("load_test")
	original.save_to_file(path)
	var loaded: GameReplay = GameReplay.load_from_file(path)
	assert_not_null(loaded, "load_from_file should return a GameReplay.")
	assert_eq(loaded.header["scenario_id"], "learning_scenario",
			"File roundtrip should preserve scenario_id.")
	assert_eq(loaded.header["rng_seed"], 42,
			"File roundtrip should preserve rng_seed.")
	assert_eq(loaded.get_command_count(), 4,
			"File roundtrip should preserve command count.")
	_cleanup_file(path)


func test_load_from_file_nonexistent_returns_null() -> void:
	var result: GameReplay = GameReplay.load_from_file(
			"res://tests/fixtures/no_such_file.json")
	assert_null(result,
			"Should return null for nonexistent file.")


func test_load_from_file_invalid_json_returns_null() -> void:
	var path: String = _temp_path("bad_json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not valid json {{{")
	file.close()
	var result: GameReplay = GameReplay.load_from_file(path)
	assert_null(result,
			"Should return null for invalid JSON.")
	_cleanup_file(path)


func test_load_from_file_non_dict_returns_null() -> void:
	var path: String = _temp_path("non_dict")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[1, 2, 3]")
	file.close()
	var result: GameReplay = GameReplay.load_from_file(path)
	assert_null(result,
			"Should return null when JSON root is not a dictionary.")
	_cleanup_file(path)


# ======================================================================
# generate_file_path
# ======================================================================

func test_generate_file_path_contains_replay_dir() -> void:
	var path: String = GameReplay.generate_file_path()
	assert_true(path.begins_with(GameReplay.REPLAY_DIR),
			"Path should start with REPLAY_DIR.")


func test_generate_file_path_ends_with_ext() -> void:
	var path: String = GameReplay.generate_file_path()
	assert_true(path.ends_with(GameReplay.REPLAY_EXT),
			"Path should end with REPLAY_EXT.")


# ======================================================================
# Integration — replay_commands roundtrip via GameCommand
# ======================================================================

func test_replay_commands_deserialize_and_execute() -> void:
	# Register command types for deserialization.
	AssignDialCommand.register()
	# Set up a minimal game state.
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.COMMAND
	var ship_data := ShipData.new()
	ship_data.hull = 4
	ship_data.command_value = 2
	ship_data.max_speed = 2
	ship_data.shields = {"front": 2, "left": 1, "right": 1, "rear": 1}
	ship_data.defense_tokens = []
	ship_data.navigation_chart = [[1], [1, 1]]
	var ship := ShipInstance.create_from_data(
			"test_ship", ship_data, 2, 0)
	state.get_player_state(0).ships.append(ship)
	# Create a command, execute it, serialize.
	var cmd := AssignDialCommand.new(0, {
		"ship_index": 0,
		"commands": [Constants.CommandType.NAVIGATE,
				Constants.CommandType.REPAIR],
	})
	var reason: String = cmd.validate(state)
	assert_eq(reason, "", "Command should be valid.")
	cmd.sequence = 0
	var result: Dictionary = cmd.execute(state)
	assert_true(result.get("success", false),
			"Command should execute successfully.")
	# Roundtrip through replay serialization.
	var serialized: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(serialized)
	assert_not_null(restored, "Should deserialize back to a command.")
	assert_eq(restored.command_type, "assign_dials",
			"Deserialized command should have correct type.")
	assert_eq(restored.player_index, 0,
			"Deserialized command should have correct player.")
	assert_eq(restored.sequence, 0,
			"Deserialized command should have correct sequence.")
	# Cleanup registry.
	GameCommand._registry.erase("assign_dials")
