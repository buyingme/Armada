## Test: SaveGameMetadata
##
## Unit tests for the save-game header schema (Phase J1).
extends GutTest


# ---------------------------------------------------------------------------
# to_dict / from_dict round-trip
# ---------------------------------------------------------------------------

func test_round_trip_preserves_all_fields() -> void:
	var meta: SaveGameMetadata = SaveGameMetadata.new()
	meta.scenario_id = "learning_scenario"
	meta.scenario_name = "Learning Scenario"
	meta.game_mode = SaveGameMetadata.MODE_HOT_SEAT
	meta.current_round = 4
	meta.phase = "Ship"
	meta.created_at = "2026-05-02T10:00:00"
	meta.app_version = "4.5.1.stable"
	meta.display_name = "MySave"
	meta.set_next_command_sequence(42)
	var restored: SaveGameMetadata = SaveGameMetadata.from_dict(meta.to_dict())
	assert_eq(restored.scenario_id, meta.scenario_id)
	assert_eq(restored.scenario_name, meta.scenario_name)
	assert_eq(restored.game_mode, meta.game_mode)
	assert_eq(restored.current_round, meta.current_round)
	assert_eq(restored.phase, meta.phase)
	assert_eq(restored.created_at, meta.created_at)
	assert_eq(restored.app_version, meta.app_version)
	assert_eq(restored.display_name, meta.display_name)
	assert_true(restored.has_next_command_sequence)
	assert_eq(restored.next_command_sequence, 42)
	assert_eq(restored.save_format_version,
			SaveGameMetadata.CURRENT_VERSION)


# ---------------------------------------------------------------------------
# validate
# ---------------------------------------------------------------------------

func _valid_meta() -> SaveGameMetadata:
	var m: SaveGameMetadata = SaveGameMetadata.new()
	m.scenario_id = "learning_scenario"
	m.scenario_name = "Learning Scenario"
	m.game_mode = SaveGameMetadata.MODE_HOT_SEAT
	m.current_round = 1
	m.phase = "Command"
	m.display_name = "MySave"
	return m


func test_validate_accepts_valid_metadata() -> void:
	var result: Dictionary = _valid_meta().validate()
	assert_true(result["ok"], "Valid metadata should pass: %s" %
			result.get("reason", ""))


func test_validate_rejects_unsupported_version() -> void:
	var m: SaveGameMetadata = _valid_meta()
	m.save_format_version = 999
	var result: Dictionary = m.validate()
	assert_false(result["ok"])
	assert_eq(result["reason"], "version_unsupported")


func test_validate_rejects_missing_scenario() -> void:
	var m: SaveGameMetadata = _valid_meta()
	m.scenario_id = ""
	assert_eq(m.validate()["reason"], "scenario_missing")


func test_validate_rejects_invalid_mode() -> void:
	var m: SaveGameMetadata = _valid_meta()
	m.game_mode = "solo"
	assert_eq(m.validate()["reason"], "mode_invalid")


func test_validate_rejects_invalid_display_name() -> void:
	var m: SaveGameMetadata = _valid_meta()
	m.display_name = ""
	assert_eq(m.validate()["reason"], "display_name_invalid")


func test_from_dict_distinguishes_missing_legacy_cursor() -> void:
	var data: Dictionary = _valid_meta().to_dict()
	data.erase("next_command_sequence")
	var restored: SaveGameMetadata = SaveGameMetadata.from_dict(data)
	assert_false(restored.has_next_command_sequence)
	assert_eq(restored.next_command_sequence, 0)


func test_validate_rejects_fractional_negative_or_non_numeric_cursor() -> void:
	for invalid_value: Variant in [-1, 1.5, "2"]:
		var data: Dictionary = _valid_meta().to_dict()
		data["next_command_sequence"] = invalid_value
		var restored: SaveGameMetadata = SaveGameMetadata.from_dict(data)
		assert_eq(restored.validate().get("reason"), "schema_invalid")


# ---------------------------------------------------------------------------
# is_display_name_valid
# ---------------------------------------------------------------------------

func test_display_name_rejects_empty() -> void:
	assert_false(SaveGameMetadata.is_display_name_valid(""))


func test_display_name_rejects_path_separators() -> void:
	assert_false(SaveGameMetadata.is_display_name_valid("a/b"))
	assert_false(SaveGameMetadata.is_display_name_valid("a\\b"))


func test_display_name_rejects_unsafe_chars() -> void:
	assert_false(SaveGameMetadata.is_display_name_valid("a:b"))
	assert_false(SaveGameMetadata.is_display_name_valid("a*b"))
	assert_false(SaveGameMetadata.is_display_name_valid("a?b"))
	assert_false(SaveGameMetadata.is_display_name_valid("a|b"))


func test_display_name_rejects_too_long() -> void:
	var long_name: String = ""
	for i: int in range(SaveGameMetadata.MAX_DISPLAY_NAME_LEN + 1):
		long_name += "x"
	assert_false(SaveGameMetadata.is_display_name_valid(long_name))


func test_display_name_accepts_normal_names() -> void:
	assert_true(SaveGameMetadata.is_display_name_valid("MySave"))
	assert_true(SaveGameMetadata.is_display_name_valid(
			"Learning_HotSeat_R2_Ship"))
	assert_true(SaveGameMetadata.is_display_name_valid("Save 1"))


func test_display_name_rejects_dot_names() -> void:
	assert_false(SaveGameMetadata.is_display_name_valid("."))
	assert_false(SaveGameMetadata.is_display_name_valid(".."))


# ---------------------------------------------------------------------------
# build_default_name
# ---------------------------------------------------------------------------

func test_build_default_name_format() -> void:
	var name: String = SaveGameMetadata.build_default_name(
			"Learning Scenario",
			SaveGameMetadata.MODE_HOT_SEAT,
			3,
			"Ship")
	# Scenario name has whitespace stripped → "LearningScenario".
	assert_eq(name, "LearningScenario_HotSeat_R3_Ship")


func test_build_default_name_uses_network_label() -> void:
	var name: String = SaveGameMetadata.build_default_name(
			"Test", SaveGameMetadata.MODE_NETWORK, 7, "Squadron")
	assert_eq(name, "Test_Network_R7_Squadron")


# ---------------------------------------------------------------------------
# phase_label
# ---------------------------------------------------------------------------

func test_phase_label_for_each_enum_value() -> void:
	assert_eq(SaveGameMetadata.phase_label(Constants.GamePhase.SETUP), "Setup")
	assert_eq(SaveGameMetadata.phase_label(Constants.GamePhase.COMMAND),
			"Command")
	assert_eq(SaveGameMetadata.phase_label(Constants.GamePhase.SHIP), "Ship")
	assert_eq(SaveGameMetadata.phase_label(Constants.GamePhase.SQUADRON),
			"Squadron")
	assert_eq(SaveGameMetadata.phase_label(Constants.GamePhase.STATUS),
			"Status")
