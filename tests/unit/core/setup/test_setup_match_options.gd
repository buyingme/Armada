## Test: SetupMatchOptions
##
## Unit tests for the shared FB14A New Game match-type contract.
extends GutTest


const SETUP_MATCH_OPTIONS_SCRIPT: GDScript = preload(
		"res://src/core/setup/setup_match_options.gd")


func test_get_options_contains_required_new_game_choices_expected() -> void:
	var ids: Array[String] = _option_ids()

	assert_eq(ids.size(), 5, "New Game should expose five match choices.")
	assert_true(ids.has(SETUP_MATCH_OPTIONS_SCRIPT.MATCH_STANDARD_400),
			"New Game should include Standard 400.")
	assert_true(ids.has(SETUP_MATCH_OPTIONS_SCRIPT.MATCH_INTERMEDIATE_300),
			"New Game should include Intermediate 300.")
	assert_true(ids.has(SETUP_MATCH_OPTIONS_SCRIPT.MATCH_CORE_SET_180),
			"New Game should include Core Set 180.")
	assert_true(ids.has(SETUP_MATCH_OPTIONS_SCRIPT.MATCH_LEARNING_SCENARIO),
			"New Game should include Learning Scenario.")
	assert_true(ids.has(SETUP_MATCH_OPTIONS_SCRIPT.MATCH_DEBUG_SCENARIO),
			"New Game should include Debug Scenario.")


func test_point_format_for_standard_400_returns_limit_expected() -> void:
	var point_format: Dictionary = SETUP_MATCH_OPTIONS_SCRIPT.point_format_for_match_type(
			SETUP_MATCH_OPTIONS_SCRIPT.MATCH_STANDARD_400)

	assert_eq(point_format.get("id", ""), FleetBuilderOptions.FORMAT_STANDARD_400,
			"Standard 400 should use the standard point-format id.")
	assert_eq(int(point_format.get("limit", 0)), FleetValidator.DEFAULT_POINT_LIMIT,
			"Standard 400 should use a 400-point limit.")


func test_point_format_for_intermediate_300_returns_limit_expected() -> void:
	var point_format: Dictionary = SETUP_MATCH_OPTIONS_SCRIPT.point_format_for_match_type(
			SETUP_MATCH_OPTIONS_SCRIPT.MATCH_INTERMEDIATE_300)

	assert_eq(point_format.get("id", ""), FleetBuilderOptions.FORMAT_CUSTOM,
			"Intermediate 300 should reuse the custom point-format payload.")
	assert_eq(int(point_format.get("limit", 0)), FleetBuilderOptions.CUSTOM_POINT_LIMIT,
			"Intermediate 300 should use a 300-point limit.")


func test_point_format_for_core_set_180_returns_limit_expected() -> void:
	var point_format: Dictionary = SETUP_MATCH_OPTIONS_SCRIPT.point_format_for_match_type(
			SETUP_MATCH_OPTIONS_SCRIPT.MATCH_CORE_SET_180)

	assert_eq(point_format.get("id", ""), FleetBuilderOptions.FORMAT_CORE_SET_180,
			"Core Set 180 should use the Core Set point-format id.")
	assert_eq(int(point_format.get("limit", 0)), FleetBuilderOptions.CORE_SET_POINT_LIMIT,
			"Core Set 180 should use a 180-point limit.")


func test_create_setup_package_draft_for_400_has_map_and_state_expected() -> void:
	var draft: FleetSetupPackage = SETUP_MATCH_OPTIONS_SCRIPT.create_setup_package_draft(
			SETUP_MATCH_OPTIONS_SCRIPT.MATCH_STANDARD_400)
	var validation_status: Dictionary = draft.setup_state.get("validation_status", {}) as Dictionary

	assert_eq(draft.scenario_id, SETUP_MATCH_OPTIONS_SCRIPT.SCENARIO_STANDARD_3X6,
			"400-point setup draft should use the standard map shell scenario.")
	assert_eq(int(draft.point_format.get("limit", 0)), FleetValidator.DEFAULT_POINT_LIMIT,
			"400-point setup draft should carry the selected point limit.")
	assert_false(draft.map.is_empty(), "400-point setup draft should select a map.")
	assert_eq(draft.setup_state.get("match_type", ""),
			SETUP_MATCH_OPTIONS_SCRIPT.MATCH_STANDARD_400,
			"Setup draft should remember the selected match type.")
	assert_false(bool(validation_status.get("ok", true)),
			"New setup drafts should start in an unvalidated state.")


func test_fixed_scenario_match_types_return_scenario_ids_expected() -> void:
	assert_eq(SETUP_MATCH_OPTIONS_SCRIPT.scenario_id_for_match_type(
			SETUP_MATCH_OPTIONS_SCRIPT.MATCH_LEARNING_SCENARIO),
			SETUP_MATCH_OPTIONS_SCRIPT.MATCH_LEARNING_SCENARIO,
			"Learning Scenario should map directly to its scenario id.")
	assert_eq(SETUP_MATCH_OPTIONS_SCRIPT.scenario_id_for_match_type(
			SETUP_MATCH_OPTIONS_SCRIPT.MATCH_DEBUG_SCENARIO),
			SETUP_MATCH_OPTIONS_SCRIPT.MATCH_DEBUG_SCENARIO,
			"Debug Scenario should map directly to its scenario id.")


func test_normalize_match_type_legacy_learning_returns_learning_expected() -> void:
	assert_eq(SETUP_MATCH_OPTIONS_SCRIPT.normalize_match_type_id(
			SETUP_MATCH_OPTIONS_SCRIPT.MATCH_LEARNING_LEGACY),
			SETUP_MATCH_OPTIONS_SCRIPT.MATCH_LEARNING_SCENARIO,
			"Legacy learning lobby values should normalize to learning_scenario.")


func _option_ids() -> Array[String]:
	var ids: Array[String] = []
	for option: Dictionary in SETUP_MATCH_OPTIONS_SCRIPT.get_options():
		ids.append(str(option.get("id", "")))
	return ids
