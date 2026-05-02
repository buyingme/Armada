## Test: SaveGameManager (Phase J1)
##
## Unit tests for SaveGameManager — save / load with metadata header,
## HMAC signing, can_save_now safe-point gate, list_with_meta.
extends GutTest


const TEST_SAVE: String = "_gut_test_save"
const SaveManagerScript: GDScript = preload(
		"res://src/autoload/save_game_manager.gd")

var _manager: Node = null


func before_each() -> void:
	# Use a fresh instance so we get an isolated _signing_key cache.
	# (Saves still write to the shared res://saves/ dir; we use a unique
	# TEST_SAVE filename to avoid collisions and clean up in after_each.)
	_manager = SaveManagerScript.new()


func after_each() -> void:
	_manager.delete_save(TEST_SAVE)
	_manager.delete_save(TEST_SAVE + "_b")
	_manager.free()


# --- Helpers ---

func _make_game_state() -> GameState:
	var gs: GameState = GameState.new()
	gs.initialize()
	gs.current_round = 3
	gs.current_phase = Constants.GamePhase.SHIP
	gs.initiative_player = 1
	gs.player_states[0].faction = Constants.Faction.REBEL_ALLIANCE
	gs.player_states[0].score = 45
	gs.player_states[1].faction = Constants.Faction.GALACTIC_EMPIRE
	gs.player_states[1].score = 30
	gs.damage_deck = DamageDeck.new()
	gs.damage_deck.initialize()
	return gs


# ---------------------------------------------------------------------------
# Save / Load round-trip
# ---------------------------------------------------------------------------

func test_save_and_load_round_trip() -> void:
	var gs: GameState = _make_game_state()
	var ok: bool = _manager.save_game(gs, TEST_SAVE)
	assert_true(ok, "save_game should succeed for a valid game state")
	var result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_true(result["ok"], "load_game should succeed for a valid save")
	var loaded: GameState = result["state"]
	assert_not_null(loaded, "load_game should return a GameState")
	assert_eq(loaded.current_round, 3,
			"Round-trip should preserve current_round")
	assert_eq(loaded.initiative_player, 1,
			"Round-trip should preserve initiative_player")


func test_round_trip_preserves_player_scores() -> void:
	var gs: GameState = _make_game_state()
	_manager.save_game(gs, TEST_SAVE)
	var result: Dictionary = _manager.load_game(TEST_SAVE)
	var loaded: GameState = result["state"]
	assert_eq(loaded.player_states[0].score, 45,
			"Round-trip should preserve player 0 score")
	assert_eq(loaded.player_states[1].score, 30,
			"Round-trip should preserve player 1 score")


func test_round_trip_preserves_damage_deck() -> void:
	var gs: GameState = _make_game_state()
	for i: int in range(5):
		gs.damage_deck.draw_card()
	_manager.save_game(gs, TEST_SAVE)
	var result: Dictionary = _manager.load_game(TEST_SAVE)
	var loaded: GameState = result["state"]
	assert_not_null(loaded.damage_deck,
			"Round-trip should restore damage_deck")
	assert_eq(loaded.damage_deck.get_draw_count(),
			DamageDeck.DECK_SIZE - 5,
			"Round-trip should preserve draw count")


# ---------------------------------------------------------------------------
# Metadata header
# ---------------------------------------------------------------------------

func test_save_writes_metadata_header() -> void:
	var gs: GameState = _make_game_state()
	_manager.save_game(gs, TEST_SAVE)
	var result: Dictionary = _manager.load_game(TEST_SAVE)
	var meta: SaveGameMetadata = result["meta"]
	assert_not_null(meta, "Loaded result must include metadata")
	assert_eq(meta.save_format_version, SaveGameMetadata.CURRENT_VERSION,
			"Header records the current format version")
	assert_eq(meta.current_round, 3,
			"Header round matches game state")
	assert_eq(meta.phase, "Ship", "Header phase is the enum label")
	assert_eq(meta.display_name, TEST_SAVE,
			"Header display_name defaults to the file name")
	assert_false(meta.created_at.is_empty(),
			"Header records a created_at timestamp")


# ---------------------------------------------------------------------------
# HMAC signing — tamper detection
# ---------------------------------------------------------------------------

func test_load_rejects_tampered_payload() -> void:
	var gs: GameState = _make_game_state()
	_manager.save_game(gs, TEST_SAVE)
	# Hand-edit the save file to flip a value in the body.
	var path: String = SaveManagerScript.SAVE_DIR + "/" + TEST_SAVE \
			+ SaveManagerScript.SAVE_EXT
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var raw: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	json.parse(raw)
	var data: Dictionary = json.data
	# Tamper with the round.
	data["state"]["current_round"] = 99
	var f2: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f2.store_string(JSON.stringify(data, "\t"))
	f2.close()
	var result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_false(result["ok"], "Tampered save should fail to load")
	assert_eq(result["reason"], "signature_invalid",
			"Reason should be signature_invalid")


func test_load_rejects_unsigned_save() -> void:
	# Manually write a save without a signature.
	var path: String = SaveManagerScript.SAVE_DIR + "/" + TEST_SAVE \
			+ SaveManagerScript.SAVE_EXT
	if not DirAccess.dir_exists_absolute(SaveManagerScript.SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SaveManagerScript.SAVE_DIR)
	var meta: SaveGameMetadata = SaveGameMetadata.new()
	meta.scenario_id = "x"
	meta.scenario_name = "X"
	meta.display_name = TEST_SAVE
	var data: Dictionary = {
		"header": meta.to_dict(),
		"state": _make_game_state().serialize(),
	}
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_false(result["ok"], "Unsigned save should fail to load")
	assert_eq(result["reason"], "signature_invalid",
			"Reason should be signature_invalid for unsigned saves")


# ---------------------------------------------------------------------------
# Version rejection
# ---------------------------------------------------------------------------

func test_load_rejects_unsupported_version() -> void:
	var gs: GameState = _make_game_state()
	_manager.save_game(gs, TEST_SAVE)
	var path: String = SaveManagerScript.SAVE_DIR + "/" + TEST_SAVE \
			+ SaveManagerScript.SAVE_EXT
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var raw: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	json.parse(raw)
	var data: Dictionary = json.data
	data["header"]["save_format_version"] = 999
	var f2: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f2.store_string(JSON.stringify(data, "\t"))
	f2.close()
	var result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_false(result["ok"],
			"Save with future version should fail to load")
	assert_eq(result["reason"], "version_unsupported",
			"Reason should be version_unsupported")


# ---------------------------------------------------------------------------
# can_save_now safe-point gate
# ---------------------------------------------------------------------------

func test_can_save_now_rejects_null_state() -> void:
	var result: Dictionary = _manager.can_save_now(null)
	assert_false(result["ok"], "Null state cannot be saved")


func test_can_save_now_rejects_setup_phase() -> void:
	var gs: GameState = _make_game_state()
	gs.current_phase = Constants.GamePhase.SETUP
	var result: Dictionary = _manager.can_save_now(gs)
	assert_false(result["ok"], "SETUP phase is not a safe save point")


func test_can_save_now_rejects_active_interaction_flow() -> void:
	var gs: GameState = _make_game_state()
	gs.interaction_flow.flow_type = Constants.InteractionFlow.ATTACK
	gs.interaction_flow.step_id = Constants.InteractionStep.ATTACK_ROLL
	var result: Dictionary = _manager.can_save_now(gs)
	assert_false(result["ok"],
			"Mid-attack interaction_flow blocks save")


func test_can_save_now_accepts_wait_for_ship_select() -> void:
	# Between activations — InteractionFlow is SHIP_ACTIVATION but
	# step_id is WAIT_FOR_SHIP_SELECT — should be a safe save point.
	var gs: GameState = _make_game_state()
	gs.interaction_flow.flow_type = Constants.InteractionFlow.SHIP_ACTIVATION
	gs.interaction_flow.step_id = Constants.InteractionStep.WAIT_FOR_SHIP_SELECT
	var result: Dictionary = _manager.can_save_now(gs)
	assert_true(result["ok"],
			"Between-activations idle state is a safe save point: %s" %
			result.get("reason", ""))


func test_can_save_now_accepts_idle_state() -> void:
	var gs: GameState = _make_game_state()
	# default: phase = SHIP, interaction_flow = NONE
	var result: Dictionary = _manager.can_save_now(gs)
	assert_true(result["ok"],
			"Idle SHIP phase with no flow is a safe save point: %s" %
			result.get("reason", ""))


# ---------------------------------------------------------------------------
# list_with_meta
# ---------------------------------------------------------------------------

func test_list_with_meta_returns_header_per_save() -> void:
	var gs: GameState = _make_game_state()
	_manager.save_game(gs, TEST_SAVE)
	var rows: Array[Dictionary] = _manager.list_with_meta()
	var found: bool = false
	for row: Dictionary in rows:
		if row["name"] == TEST_SAVE:
			found = true
			assert_true(row["valid"],
					"Just-saved file should be valid")
			assert_not_null(row["meta"],
					"Row should include parsed metadata")
			assert_eq((row["meta"] as SaveGameMetadata).current_round, 3,
					"Metadata round should match the saved state")
			break
	assert_true(found, "list_with_meta should include the test save")


func test_list_with_meta_sorts_by_created_at_descending() -> void:
	# Save twice with slight delay implicit in timestamp resolution.
	var gs: GameState = _make_game_state()
	_manager.save_game(gs, TEST_SAVE)
	# Mutate meta on second save so timestamps differ.
	var meta: SaveGameMetadata = _manager.build_metadata_for(
			gs, TEST_SAVE + "_b")
	# Force a clearly newer timestamp.
	meta.created_at = "2099-12-31T23:59:59"
	_manager.save_game(gs, TEST_SAVE + "_b", meta)
	var rows: Array[Dictionary] = _manager.list_with_meta()
	var first_b_idx: int = -1
	var first_a_idx: int = -1
	for i: int in range(rows.size()):
		if rows[i]["name"] == TEST_SAVE + "_b" and first_b_idx == -1:
			first_b_idx = i
		elif rows[i]["name"] == TEST_SAVE and first_a_idx == -1:
			first_a_idx = i
	assert_true(first_b_idx >= 0 and first_a_idx >= 0,
			"Both test saves should appear in list_with_meta")
	assert_lt(first_b_idx, first_a_idx,
			"Newer timestamp should sort before older")


# ---------------------------------------------------------------------------
# Default name builder
# ---------------------------------------------------------------------------

func test_default_save_name_uses_template() -> void:
	var gs: GameState = _make_game_state()
	# scenario_id is "" in test context — falls back to "Unknown".
	var name: String = _manager.default_save_name(gs)
	# Template: {scenario}_{mode}_R{round}_{phase}.
	assert_true(name.contains("R3"),
			"Default name should embed the round (R3): %s" % name)
	assert_true(name.contains("Ship"),
			"Default name should embed the phase (Ship): %s" % name)
	assert_true(name.contains("HotSeat") or name.contains("Network"),
			"Default name should embed the mode label: %s" % name)


# ---------------------------------------------------------------------------
# Load missing / parse error
# ---------------------------------------------------------------------------

func test_load_missing_returns_failure() -> void:
	var result: Dictionary = _manager.load_game("_nonexistent_12345")
	assert_false(result["ok"], "Missing save should fail to load")
	assert_eq(result["reason"], "missing",
			"Reason should be 'missing'")


# ---------------------------------------------------------------------------
# Delete
# ---------------------------------------------------------------------------

func test_delete_save_removes_file() -> void:
	var gs: GameState = _make_game_state()
	_manager.save_game(gs, TEST_SAVE)
	var deleted: bool = _manager.delete_save(TEST_SAVE)
	assert_true(deleted, "delete_save should return true")
	assert_does_not_have(_manager.list_saves(), TEST_SAVE,
			"Deleted save should no longer appear in list")


func test_delete_nonexistent_returns_false() -> void:
	var deleted: bool = _manager.delete_save("_nonexistent_12345")
	assert_false(deleted,
			"delete_save should return false for missing file")
