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
	# At least one ship must still be eligible to activate, otherwise
	# the phase-progression invariant correctly rejects the save.
	var ship: ShipInstance = ShipInstance.new()
	ship.activated_this_round = false
	gs.player_states[0].ships = [ship]
	var result: Dictionary = _manager.can_save_now(gs)
	assert_true(result["ok"],
			"Between-activations idle state is a safe save point: %s" %
			result.get("reason", ""))


func test_can_save_now_rejects_ship_phase_with_no_unactivated_ships() -> void:
	# Last ship just activated; phase-advance command has not yet
	# fired so step_id still reads WAIT_FOR_SHIP_SELECT.  Saving here
	# strands the game in SHIP phase with nothing to do on resume.
	var gs: GameState = _make_game_state()
	gs.interaction_flow.flow_type = Constants.InteractionFlow.SHIP_ACTIVATION
	gs.interaction_flow.step_id = Constants.InteractionStep.WAIT_FOR_SHIP_SELECT
	var ship: ShipInstance = ShipInstance.new()
	ship.activated_this_round = true
	gs.player_states[0].ships = [ship]
	var result: Dictionary = _manager.can_save_now(gs)
	assert_false(result["ok"],
			"Pending phase transition (no activatable ship) blocks save")


func test_can_save_now_rejects_idle_none_step() -> void:
	# step_id == NONE is a transient gap left by commands that don't
	# update the interaction flow (e.g. squadron-command sub-steps).
	# The save gate must reject it: a checkpoint captured here can sit
	# mid-activation.
	var gs: GameState = _make_game_state()
	# default: phase = SHIP, interaction_flow.step_id = NONE
	var result: Dictionary = _manager.can_save_now(gs)
	assert_false(result["ok"],
			"NONE step is not a safe save point (mid-activation risk)")


func test_can_save_now_rejects_ship_with_revealed_dial() -> void:
	# Structural invariant: even at WAIT_FOR_SHIP_SELECT, if any ship
	# has a revealed (popped) command dial, that ship's activation has
	# begun and has not yet finalised — saving now would resume into
	# an inconsistent UI state.
	var gs: GameState = _make_game_state()
	gs.interaction_flow.flow_type = Constants.InteractionFlow.SHIP_ACTIVATION
	gs.interaction_flow.step_id = Constants.InteractionStep.WAIT_FOR_SHIP_SELECT
	var ship: ShipInstance = ShipInstance.new()
	ship.command_dial_stack = CommandDialStack.create(2)
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.SQUADRON],
			gs.current_round)
	ship.command_dial_stack.reveal_top()
	gs.player_states[0].ships = [ship]
	var result: Dictionary = _manager.can_save_now(gs)
	assert_false(result["ok"],
			"Ship with revealed dial blocks save (mid-activation)")


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


# ---------------------------------------------------------------------------
# Phase J6 — network host/client save guard
# ---------------------------------------------------------------------------

func test_save_game_refused_on_network_client() -> void:
	# Force PlayMode = network and NetworkManager role = client.
	var prev_mode: int = PlayMode.current_mode
	var prev_role: int = NetworkManager.role
	var prev_log_level: int = GameLogger.min_level
	GameLogger.min_level = GameLogger.Level.ERROR + 1
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	var gs: GameState = _make_game_state()
	var ok: bool = _manager.save_game(gs, TEST_SAVE)
	assert_false(ok,
			"save_game should refuse on network client (host-only)")
	PlayMode.set_mode(prev_mode)
	NetworkManager.role = prev_role
	GameLogger.min_level = prev_log_level


func test_save_game_allowed_on_network_host() -> void:
	var prev_mode: int = PlayMode.current_mode
	var prev_role: int = NetworkManager.role
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	var gs: GameState = _make_game_state()
	var ok: bool = _manager.save_game(gs, TEST_SAVE)
	assert_true(ok, "save_game should succeed on network host")
	PlayMode.set_mode(prev_mode)
	NetworkManager.role = prev_role


# ---------------------------------------------------------------------------
# Phase J9 — application-launch cleanup
# ---------------------------------------------------------------------------

func test_cleanup_session_artifacts_removes_numbered_checkpoints() -> void:
	var dir_path: String = SaveManagerScript.SAVE_DIR
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var numbered_path: String = "%s/_checkpoint_hot_seat_001.json" % dir_path
	var canonical_path: String = "%s/_checkpoint_hot_seat.json" % dir_path
	var canonical_pre_existed: bool = FileAccess.file_exists(canonical_path)
	var canonical_backup: String = ""
	if canonical_pre_existed:
		canonical_backup = FileAccess.get_file_as_string(canonical_path)
	var numbered_file: FileAccess = FileAccess.open(
			numbered_path, FileAccess.WRITE)
	numbered_file.store_string("{}")
	numbered_file.close()
	var canonical_file: FileAccess = FileAccess.open(
			canonical_path, FileAccess.WRITE)
	canonical_file.store_string("{}")
	canonical_file.close()
	_manager._cleanup_session_artifacts()
	assert_false(FileAccess.file_exists(numbered_path),
			"Numbered checkpoint should be deleted on launch")
	assert_true(FileAccess.file_exists(canonical_path),
			"Canonical checkpoint should be preserved on launch")
	# Restore prior canonical file (or remove the one we created).
	if canonical_pre_existed:
		var f: FileAccess = FileAccess.open(canonical_path, FileAccess.WRITE)
		f.store_string(canonical_backup)
		f.close()
	else:
		DirAccess.remove_absolute(canonical_path)


func test_cleanup_session_artifacts_removes_replays() -> void:
	var dir_path: String = PathConfig.REPLAYS_DIR
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var seeded: String = "%s/_gut_test_replay.json" % dir_path
	var f: FileAccess = FileAccess.open(seeded, FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	assert_true(FileAccess.file_exists(seeded),
			"Seeded replay must exist before cleanup")
	_manager._cleanup_session_artifacts()
	assert_false(FileAccess.file_exists(seeded),
			"Replay file should be deleted on launch")
