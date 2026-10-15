## Production-boundary regressions for exact authoritative RNG persistence.
extends GutTest


const SaveManagerScript: GDScript = preload(
		"res://src/autoload/save_game_manager.gd")
const CURRENT_ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")
const TEST_SAVE: String = "exact_rng_primary"
const SECOND_SAVE: String = "exact_rng_second"
const EXACT_SEED_TEXT: String = "5975857563556095516"
const EXACT_STATE_TEXT: String = "-7473184280779029157"
const TEST_SAVE_DIR: String = "user://exact_rng_save_serialization"
var _test_key: PackedByteArray = PackedByteArray([
	0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
	0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
	0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
	0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20,
])


var _manager: Node = null
var _previous_save_dir: String = ""
var _previous_key_file: String = ""
var _previous_mode: PlayMode.Mode
var _previous_role: NetworkManager.Role
var _previous_game_state: GameState = null
var _previous_game_active: bool = false
var _previous_active_player: int = 0


func before_each() -> void:
	_previous_save_dir = SaveManagerScript.SAVE_DIR
	_previous_key_file = SaveManagerScript.SIGNING_KEY_FILE
	_previous_mode = PlayMode.current_mode
	_previous_role = NetworkManager.role
	_previous_game_state = GameManager.current_game_state
	_previous_game_active = GameManager.is_game_active
	_previous_active_player = GameManager.active_player
	SaveGameManager.SAVE_DIR = TEST_SAVE_DIR
	SaveGameManager.SIGNING_KEY_FILE = TEST_SAVE_DIR.path_join("key.bin")
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	CommandProcessor.reset()
	_manager = SaveManagerScript.new()
	_manager._signing_key = _test_key
	_cleanup_test_files()


func after_each() -> void:
	_cleanup_test_files()
	_manager.free()
	_manager = null
	SaveGameManager.SAVE_DIR = _previous_save_dir
	SaveGameManager.SIGNING_KEY_FILE = _previous_key_file
	PlayMode.set_mode(_previous_mode)
	NetworkManager.role = _previous_role
	GameManager.current_game_state = _previous_game_state
	GameManager.is_game_active = _previous_game_active
	GameManager.active_player = _previous_active_player
	CommandProcessor.reset()


func test_real_signed_save_roundtrip_is_exact_and_continues_deterministically() -> void:
	var source: GameState = _make_roll_state(false)
	assert_true(CommandProcessor.restore_next_sequence(1))
	var source_hash: String = CanonicalJson.hash(source.serialize())
	assert_true(_manager.save_game(source, TEST_SAVE))

	var raw_json: String = FileAccess.get_file_as_string(_path_for(TEST_SAVE))
	assert_true(raw_json.contains(
			'"initial_seed": "' + EXACT_SEED_TEXT + '"'))
	assert_true(raw_json.contains(
			'"state": "' + EXACT_STATE_TEXT + '"'))
	var payload: Dictionary = JSON.parse_string(raw_json) as Dictionary
	var parsed_rng: Dictionary = (payload.get("state") as Dictionary).get(
			"rng") as Dictionary
	assert_typeof(parsed_rng.get("initial_seed"), TYPE_STRING)
	assert_typeof(parsed_rng.get("state"), TYPE_STRING)
	assert_eq(parsed_rng.get("initial_seed"), EXACT_SEED_TEXT)
	assert_eq(parsed_rng.get("state"), EXACT_STATE_TEXT)
	assert_true(IntegritySigner.verify(
			payload.get("header") as Dictionary,
			payload.get("state") as Dictionary,
			_test_key))

	var loaded_result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_true(bool(loaded_result.get("ok", false)),
			"Untouched format-10 signed save must load.")
	var loaded: GameState = loaded_result.get("state") as GameState
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_eq(str(loaded.rng.initial_seed), EXACT_SEED_TEXT)
	assert_eq(str(loaded.rng.get_state()), EXACT_STATE_TEXT)
	assert_eq(CanonicalJson.hash(loaded.serialize()), source_hash,
			"Canonical state hash must be identical immediately after load.")
	assert_eq(loaded.damage_deck._rng, loaded.rng,
			"The restored deck must be rebound to the one restored GameRng.")

	var second_meta: SaveGameMetadata = _manager.build_metadata_for(
			loaded, SECOND_SAVE)
	assert_true(_manager.save_game(loaded, SECOND_SAVE, second_meta))
	var second_result: Dictionary = _manager.load_game(SECOND_SAVE)
	assert_true(bool(second_result.get("ok", false)))
	var second_loaded: GameState = second_result.get("state") as GameState
	assert_not_null(second_loaded)
	if second_loaded != null:
		assert_eq(CanonicalJson.hash(second_loaded.serialize()), source_hash)
		assert_eq(str(second_loaded.rng.initial_seed), EXACT_SEED_TEXT)
		assert_eq(str(second_loaded.rng.get_state()), EXACT_STATE_TEXT)

	var source_roll := RollDiceCommand.new(0, {"attack_id": "attack:0"})
	var loaded_roll := RollDiceCommand.new(0, {"attack_id": "attack:0"})
	var source_result: Dictionary = source_roll.execute(source)
	var continued_result: Dictionary = loaded_roll.execute(loaded)
	assert_eq(continued_result, source_result,
			"A real authoritative dice transaction must produce the same result.")
	assert_eq(loaded.rng.get_state(), source.rng.get_state(),
			"The loaded and uninterrupted RNG streams must remain aligned.")
	assert_eq(CanonicalJson.hash(loaded.serialize()),
			CanonicalJson.hash(source.serialize()),
			"The authoritative states must converge after the same transaction.")


func test_tampered_rng_string_fails_signature_verification() -> void:
	assert_true(CommandProcessor.restore_next_sequence(1))
	assert_true(_manager.save_game(_make_roll_state(false), TEST_SAVE))
	var payload: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(_path_for(TEST_SAVE))) as Dictionary
	(payload["state"]["rng"] as Dictionary)["state"] = \
			"-6473184280779029157"
	_write_raw_payload(TEST_SAVE, payload)
	var result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_false(bool(result.get("ok", true)))
	assert_eq(result.get("reason"), "signature_invalid")


func test_valid_signature_cannot_legitimize_numeric_or_malformed_rng() -> void:
	for malformed: Variant in [42, 42.5, "01", "9223372036854775808"]:
		var body: Dictionary = _make_roll_state(false).serialize()
		(body["rng"] as Dictionary)["state"] = malformed
		_write_signed_payload(TEST_SAVE, SaveGameMetadata.CURRENT_VERSION, body)
		var result: Dictionary = _manager.load_game(TEST_SAVE)
		assert_false(bool(result.get("ok", true)))
		assert_eq(result.get("reason"), "schema_invalid",
				"Valid signature must not legitimize rng.state=%s." \
				% var_to_str(malformed))


func test_valid_signed_format_nine_named_save_rejects_before_schema_decode() -> void:
	var body: Dictionary = _legacy_numeric_body()
	_write_signed_payload(TEST_SAVE, 9, body)
	var result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_false(bool(result.get("ok", true)))
	assert_eq(result.get("reason"), "version_unsupported")
	assert_eq((result.get("meta") as SaveGameMetadata).save_format_version, 9)


func test_persisted_format_nine_checkpoint_rejects_without_rewrite() -> void:
	var checkpoint_name: String = SaveManagerScript.CHECKPOINT_HOT_SEAT_NAME
	_write_signed_payload(checkpoint_name, 9, _legacy_numeric_body())
	var checkpoint_path: String = _path_for(checkpoint_name)
	var before: String = FileAccess.get_file_as_string(checkpoint_path)
	var installed_before: GameState = GameManager.current_game_state
	_manager._init_checkpoints()
	_manager._restore_checkpoint_slot(SaveGameMetadata.MODE_HOT_SEAT)
	assert_true(_manager.has_checkpoint(SaveGameMetadata.MODE_HOT_SEAT),
			"A valid persisted checkpoint may be restored into the cache.")
	var result: Dictionary = _manager.load_game_from_checkpoint(
			SaveGameMetadata.MODE_HOT_SEAT)
	assert_false(bool(result.get("ok", true)))
	assert_eq(result.get("reason"), "version_unsupported")
	assert_eq(FileAccess.get_file_as_string(checkpoint_path), before,
			"Rejected format-9 checkpoint bytes must remain unchanged.")
	assert_eq(GameManager.current_game_state, installed_before,
			"Rejected checkpoint must not install state.")
	assert_false(FileAccess.file_exists(_path_for("promoted_checkpoint")),
			"Rejected checkpoint must not be promoted under another name.")


func test_protocol_ten_network_resume_roll_converges_without_passive_rng() -> void:
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	var uninterrupted: GameState = _make_roll_state(true)
	assert_true(CommandProcessor.restore_next_sequence(1))
	var meta: SaveGameMetadata = _manager.build_metadata_for(
			uninterrupted, TEST_SAVE)
	meta.game_mode = SaveGameMetadata.MODE_NETWORK
	assert_true(_manager.save_game(uninterrupted, TEST_SAVE, meta))
	var loaded_result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_true(bool(loaded_result.get("ok", false)))
	var loaded: GameState = loaded_result.get("state") as GameState
	var loaded_meta: SaveGameMetadata = loaded_result.get("meta") as SaveGameMetadata
	assert_not_null(loaded)
	assert_eq(NetworkManager.PROTOCOL_VERSION, 11)
	assert_true(GameManager.start_new_game_from_state(
			loaded, loaded_meta.scenario_id, loaded_meta.next_command_sequence))
	var host: GameState = GameManager.current_game_state
	assert_eq(str(host.rng.initial_seed), EXACT_SEED_TEXT)
	assert_eq(str(host.rng.get_state()), EXACT_STATE_TEXT)

	var filter_result: Dictionary = StateFilter.filter_for_player_checked(
			host.serialize(), 1)
	assert_true(bool(filter_result.get(StateFilter.KEY_OK, false)))
	var passive_data: Dictionary = filter_result.get(
			StateFilter.KEY_STATE, {}) as Dictionary
	assert_false(passive_data.is_empty())
	assert_false(passive_data.has("rng"))
	var passive: GameState = GameState.deserialize_passive_network(passive_data)
	assert_not_null(passive)
	assert_null(passive.rng)

	var expected_command := RollDiceCommand.new(0, {"attack_id": "attack:0"})
	var host_command := RollDiceCommand.new(0, {"attack_id": "attack:0"})
	var passive_command := RollDiceCommand.new(0, {"attack_id": "attack:0"})
	var expected_result: Dictionary = expected_command.execute(uninterrupted)
	var host_result: Dictionary = host_command.execute(host)
	assert_eq(host_result, expected_result)
	assert_eq(host.rng.get_state(), uninterrupted.rng.get_state())
	var envelope: Dictionary = NetworkManager._build_result_envelope(
			host_command, host_result, 1)
	assert_eq(envelope.get("protocol_version"), 11)
	assert_false(passive_command.execute_with_application_result(
			passive, envelope.get("application_result") as Dictionary).is_empty())
	assert_null(passive.rng)
	assert_eq(passive.current_attack_state.dice_results,
			host.current_attack_state.dice_results,
			"Command-owned passive application must converge to the public roll.")
	assert_eq(passive.current_attack_state.stage,
			host.current_attack_state.stage)
	assert_eq(passive.ship_target_attack_counts,
			host.ship_target_attack_counts)
	assert_true(passive.validate_for_passive_network_installation())


func _make_roll_state(network_binding: bool) -> GameState:
	var state := GameState.new()
	state.rng = GameRng.new(EXACT_SEED_TEXT.to_int())
	state.initialize()
	var binding: MatchPlayerControlBinding = \
			MatchPlayerControlBinding.create_two_human() if network_binding \
			else MatchPlayerControlBinding.create_hot_seat_human()
	assert_true(state.install_match_player_control_binding(binding))
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.damage_deck = DamageDeck.new()
	state.damage_deck.set_rng(state.rng)
	state.damage_deck.initialize()
	state.rng.set_state(EXACT_STATE_TEXT.to_int())
	assert_not_null(CURRENT_ATTACK_FIXTURE.install(state, {
		"attack_id": "attack:0",
		"dice_pool": {"RED": 2, "BLUE": 1},
	}))
	return state


func _legacy_numeric_body() -> Dictionary:
	var body: Dictionary = _make_roll_state(false).serialize()
	body["rng"] = {"initial_seed": 42, "state": 73}
	return body


func _write_signed_payload(
		file_name: String, version: int, body: Dictionary) -> void:
	var meta: SaveGameMetadata = _manager.build_metadata_for(
			_make_roll_state(false), file_name)
	meta.save_format_version = version
	var header: Dictionary = meta.to_dict()
	assert_true(IntegritySigner.sign(header, body, _test_key))
	assert_true(_manager._write_payload(file_name, header, body))


func _write_raw_payload(file_name: String, payload: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(_path_for(file_name), FileAccess.WRITE)
	assert_not_null(file)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
		file.close()


func _path_for(file_name: String) -> String:
	return SaveManagerScript.SAVE_DIR.path_join(
			file_name + SaveManagerScript.SAVE_EXT)


func _cleanup_test_files() -> void:
	for name: String in [
		TEST_SAVE,
		SECOND_SAVE,
		SaveManagerScript.CHECKPOINT_HOT_SEAT_NAME,
		SaveManagerScript.CHECKPOINT_NETWORK_NAME,
		"promoted_checkpoint",
	]:
		var path: String = _path_for(name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
