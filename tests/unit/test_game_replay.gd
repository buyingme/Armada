## Tests for GameReplay — serialize/deserialize, file I/O, header capture.
##
## Covers: GameReplay (src/core/game_replay.gd).
## Validates: replay creation, serialization roundtrip, file save/load,
## header metadata, command capture, validity checks, and integration
## with CommandProcessor.create_replay().
extends GutTest


const EXACT_REPLAY_SEED: int = 8707258039180871004


# ======================================================================
# Helpers
# ======================================================================

## Creates a minimal GameReplay with populated header and sample commands.
func _make_replay(cmd_count: int = 3) -> GameReplay:
	var replay := GameReplay.new()
	replay.capture_header("learning_scenario", 42,
			[Constants.Faction.REBEL_ALLIANCE,
			Constants.Faction.GALACTIC_EMPIRE], 0, 0, _binding())
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
func _temp_path(replay_name: String = "test_replay") -> String:
	return "res://tests/fixtures/%s.json" % replay_name


## Deletes a file if it exists (cleanup).
func _cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _binding() -> Dictionary:
	return MatchPlayerControlBinding.create_hot_seat_human().serialize()


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


func test_capture_header_stores_reconstructed_initial_sequence() -> void:
	var replay := GameReplay.new()
	replay.capture_header("checkpoint", 1, [], 0, 14)
	assert_eq(replay.header["initial_command_sequence"], 14)


func test_create_replay_rejects_unpaired_reconstructed_cursor() -> void:
	var previous_state: GameState = GameManager.current_game_state
	var state := GameState.new()
	state.initialize()
	GameManager.current_game_state = state
	CommandProcessor.reset()
	assert_true(CommandProcessor.restore_next_sequence(14))

	assert_null(CommandProcessor.create_replay(),
			"Nonzero replay capture requires a paired reconstructed initial state")
	assert_engine_error(1,
			"Unsupported reconstructed replay capture should diagnose once")

	CommandProcessor.reset()
	GameManager.current_game_state = previous_state


func test_ux_005_cutover_uses_replay_format_seven() -> void:
	assert_eq(GameReplay.FORMAT_VERSION, 7,
			"UX-005 acknowledgement semantics require replay format 7")
	assert_eq(GameReplay.SIGNED_FORMAT_VERSION, GameReplay.FORMAT_VERSION,
			"Signing must not create a second semantic replay format")


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


func test_deserialize_rejects_missing_command_sequence() -> void:
	var data: Dictionary = _make_replay(1).serialize()
	(data["commands"] as Array)[0].erase("sequence")
	assert_null(GameReplay.deserialize(data),
			"Full-game replay must reject a missing sequence before playback.")


func test_deserialize_rejects_negative_command_sequence() -> void:
	var data: Dictionary = _make_replay(1).serialize()
	(data["commands"] as Array)[0]["sequence"] = -1
	assert_null(GameReplay.deserialize(data),
			"Full-game replay must reject a negative sequence.")


func test_deserialize_rejects_duplicate_or_gapped_command_sequence() -> void:
	var duplicate: Dictionary = _make_replay(3).serialize()
	(duplicate["commands"] as Array)[1]["sequence"] = 0
	assert_null(GameReplay.deserialize(duplicate),
			"Full-game replay must reject duplicate sequence values.")
	var gap: Dictionary = _make_replay(3).serialize()
	(gap["commands"] as Array)[1]["sequence"] = 2
	assert_null(GameReplay.deserialize(gap),
			"Full-game replay must reject sequence gaps.")


func test_deserialize_accepts_integral_json_float_sequences() -> void:
	var data: Dictionary = _make_replay(2).serialize()
	(data["commands"] as Array)[0]["sequence"] = 0.0
	(data["commands"] as Array)[1]["sequence"] = 1.0
	assert_not_null(GameReplay.deserialize(data),
			"JSON-parsed integral numbers should preserve contiguous sequences.")


func test_deserialize_accepts_contiguous_reconstructed_sequence_column() -> void:
	var replay: GameReplay = _make_replay(3)
	replay.header["initial_command_sequence"] = 14
	for index: int in range(replay.commands.size()):
		replay.commands[index]["sequence"] = 14 + index
	assert_not_null(GameReplay.deserialize(replay.serialize()))


func test_deserialize_rejects_every_non_current_semantic_format() -> void:
	for format: int in [1, 2, 3, 4, 99]:
		var data: Dictionary = _make_replay(1).serialize()
		(data["header"] as Dictionary)["format_version"] = format
		(data["commands"] as Array)[0]["type"] = "unknown_before_apply"
		assert_null(GameReplay.deserialize(data),
				"Unsupported format %d must reject before playback." % format)


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
	assert_eq(int(loaded.header["rng_seed"]), 42,
			"File roundtrip should preserve rng_seed.")
	assert_eq(loaded.get_command_count(), 4,
			"File roundtrip should preserve command count.")
	_cleanup_file(path)


func test_disk_roundtrip_preserves_exact_seed_and_declared_numeric_types() -> void:
	var original := GameReplay.new()
	original.capture_header("slice-8a-numeric-schema", EXACT_REPLAY_SEED,
			[Constants.Faction.REBEL_ALLIANCE,
			Constants.Faction.GALACTIC_EMPIRE], 0, 0, _binding())
	original.set_commands([
		{
			"type": "begin_attack",
			"player": 0,
			"sequence": 0,
			"payload": {
				"attacker_player": 0,
				"attacker_index": 1,
				"attacker_zone": 2,
				"defender_player": 1,
				"defender_index": 3,
				"defender_zone": 0,
			},
		},
		{
			"type": "execute_maneuver",
			"player": 0,
			"sequence": 1,
			"payload": {
				"ship_index": 1,
				"speed": 3,
				"yaw_clicks": [0, 1, 2],
				"yaw_bonus_joint": -1,
				"speed_delta": 0,
				"pos_x": 0.375,
				"pos_y": 0.625,
				"rotation_deg": 90.0,
			},
		},
		{
			"type": "commit_accuracy",
			"player": 0,
			"sequence": 2,
			"payload": {"locked_tokens": [0, 2]},
		},
		{
			"type": "commit_defense",
			"player": 1,
			"sequence": 3,
			"payload": {"ship_index": 3, "selected_indices": [1, 4]},
		},
		{
			"type": "publish_attack_flow",
			"player": 0,
			"sequence": 4,
			"payload": {
				"step_id": int(Constants.InteractionStep.ATTACK_DEFENSE_TOKENS),
				"controller_player": 1,
				"flow_payload": {
					"attacker_player": 0,
					"defender_zone": "front",
					"dice_pool": {"RED": 3},
					"dice_results": [
						{"color": 0, "face": 4},
						{"color": 1, "face": "hit"},
					],
					"defense_tokens": [{"type": 2, "state": 0}],
					"locked_tokens": [2],
				},
			},
		},
		{
			"type": "roll_dice",
			"player": 0,
			"sequence": 5,
			"payload": {"dice_pool": {"RED": 2, "BLUE": 1}},
		},
	])
	var path: String = _temp_path("numeric_schema_roundtrip")
	assert_eq(original.save_to_file(path), OK)
	var raw_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var raw_json: String = raw_file.get_as_text()
	raw_file.close()
	assert_true(raw_json.contains(
			'"rng_seed": "8707258039180871004"'),
			"Exact replay seed must use its canonical decimal representation.")
	var raw_decoder := JSON.new()
	assert_eq(raw_decoder.parse(raw_json), OK)
	var json_commands: Array = (raw_decoder.data as Dictionary)["commands"]
	assert_typeof(json_commands[0]["payload"]["attacker_player"], TYPE_FLOAT,
			"Godot JSON exposes the persisted numeric type mismatch.")
	assert_typeof(json_commands[1]["payload"]["pos_x"], TYPE_FLOAT)

	var loaded: GameReplay = GameReplay.load_from_file(path)
	assert_not_null(loaded)
	assert_typeof(loaded.header["rng_seed"], TYPE_INT)
	assert_eq(loaded.header["rng_seed"], EXACT_REPLAY_SEED)
	assert_typeof(loaded.header["format_version"], TYPE_INT)
	assert_typeof(loaded.header["initial_command_sequence"], TYPE_INT)
	assert_typeof(loaded.commands[0]["player"], TYPE_INT)
	assert_typeof(loaded.commands[0]["sequence"], TYPE_INT)
	var begin_payload: Dictionary = loaded.commands[0]["payload"]
	for field: String in [
			"attacker_player", "attacker_index", "attacker_zone",
			"defender_player", "defender_index", "defender_zone"]:
		assert_typeof(begin_payload[field], TYPE_INT,
				"%s must be restored to int." % field)
	var maneuver_payload: Dictionary = loaded.commands[1]["payload"]
	for field: String in [
			"ship_index", "speed", "yaw_bonus_joint", "speed_delta"]:
		assert_typeof(maneuver_payload[field], TYPE_INT,
				"%s must be restored to int." % field)
	for yaw: Variant in maneuver_payload["yaw_clicks"]:
		assert_typeof(yaw, TYPE_INT, "Yaw entries must be restored to int.")
	for field: String in ["pos_x", "pos_y", "rotation_deg"]:
		assert_typeof(maneuver_payload[field], TYPE_FLOAT,
				"%s is a legitimate float and must remain float." % field)
	var accuracy_payload: Dictionary = loaded.commands[2]["payload"]
	for token_index: Variant in accuracy_payload["locked_tokens"]:
		assert_typeof(token_index, TYPE_INT)
	var defense_payload: Dictionary = loaded.commands[3]["payload"]
	for token_index: Variant in defense_payload["selected_indices"]:
		assert_typeof(token_index, TYPE_INT)
	var flow_payload: Dictionary = loaded.commands[4]["payload"]["flow_payload"]
	assert_typeof(flow_payload["attacker_player"], TYPE_INT)
	assert_typeof(flow_payload["dice_pool"]["RED"], TYPE_INT)
	assert_typeof(flow_payload["dice_results"][0]["color"], TYPE_INT)
	assert_typeof(flow_payload["dice_results"][0]["face"], TYPE_INT)
	assert_eq(flow_payload["dice_results"][1]["face"], "hit",
			"Known structured string identity must remain unchanged.")
	assert_eq(flow_payload["defender_zone"], "front",
			"Known structured string zone identity must remain unchanged.")
	assert_typeof(flow_payload["defense_tokens"][0]["type"], TYPE_INT)
	assert_typeof(flow_payload["defense_tokens"][0]["state"], TYPE_INT)
	assert_typeof(flow_payload["locked_tokens"][0], TYPE_INT)
	var roll_payload: Dictionary = loaded.commands[5]["payload"]
	assert_typeof(roll_payload["dice_pool"]["RED"], TYPE_INT)
	assert_typeof(roll_payload["dice_pool"]["BLUE"], TYPE_INT)
	_cleanup_file(path)


func test_deserialize_rejects_noncanonical_exact_seed_representation() -> void:
	var numeric_seed: Dictionary = _make_replay(1).serialize()
	(numeric_seed["header"] as Dictionary)["rng_seed"] = 42.0
	assert_null(GameReplay.deserialize(numeric_seed),
			"Persisted numeric seeds must not be accepted after JSON decoding.")
	var padded_seed: Dictionary = _make_replay(1).serialize()
	(padded_seed["header"] as Dictionary)["rng_seed"] = "00042"
	assert_null(GameReplay.deserialize(padded_seed),
			"Noncanonical decimal seed strings must be rejected.")


func test_command_reconstruction_rejects_noncanonical_integer_payloads() -> void:
	var base: Dictionary = {
		"type": "begin_attack",
		"player": 0.0,
		"sequence": 0.0,
		"payload": {"attacker_player": 0.0},
	}
	var canonical: Dictionary = GameCommand.canonicalize_serialized(base)
	assert_typeof(canonical["player"], TYPE_INT)
	assert_typeof(canonical["sequence"], TYPE_INT)
	assert_typeof(canonical["payload"]["attacker_player"], TYPE_INT)

	var fractional: Dictionary = base.duplicate(true)
	(fractional["payload"] as Dictionary)["attacker_player"] = 0.5
	assert_true(GameCommand.canonicalize_serialized(fractional).is_empty())
	var string_value: Dictionary = base.duplicate(true)
	(string_value["payload"] as Dictionary)["attacker_player"] = "0"
	assert_true(GameCommand.canonicalize_serialized(string_value).is_empty())
	var unsafe_value: Dictionary = base.duplicate(true)
	(unsafe_value["payload"] as Dictionary)["attacker_player"] = \
			9007199254740992.0
	assert_true(GameCommand.canonicalize_serialized(unsafe_value).is_empty())


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
