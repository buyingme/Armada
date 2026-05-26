## Test: AssetLoader
##
## Unit tests for the AssetLoader utility — asset manifest validation,
## single-category checks, and texture/JSON loading helpers.
extends GutTest


# --- validate_all ---

func test_validate_all_returns_dictionary() -> void:
	var results: Dictionary = AssetLoader.validate_all()
	assert_typeof(results, TYPE_DICTIONARY,
		"validate_all should return a Dictionary")


func test_validate_all_contains_all_categories() -> void:
	var results: Dictionary = AssetLoader.validate_all()
	var expected_categories: Array[String] = [
		"ships", "squadrons", "dice", "defense_tokens",
		"command_tokens", "maps", "tools", "scale",
	]
	for cat: String in expected_categories:
		assert_has(results, cat,
			"Results should contain category '%s'" % cat)


func test_validate_all_scale_is_valid() -> void:
	var results: Dictionary = AssetLoader.validate_all()
	var scale_result: AssetLoader.ValidationResult = results["scale"]
	assert_true(scale_result.is_valid,
		"scale category should be valid — scale_config.json exists")


func test_validate_all_ships_finds_json_files() -> void:
	var results: Dictionary = AssetLoader.validate_all()
	var ships_result: AssetLoader.ValidationResult = results["ships"]
	assert_true(ships_result.found.has("cr90_corvette_a.json"),
		"Should find cr90_corvette_a.json in ships/")


func test_validate_all_maps_finds_jpg_files() -> void:
	var results: Dictionary = AssetLoader.validate_all()
	var maps_result: AssetLoader.ValidationResult = results["maps"]
	assert_true(maps_result.found.has("map_3x3_azure_v3.jpg"),
		"Should find map_3x3_azure_v3.jpg in maps/")


func test_validate_all_dice_finds_die_pngs() -> void:
	var results: Dictionary = AssetLoader.validate_all()
	var dice_result: AssetLoader.ValidationResult = results["dice"]
	assert_true(dice_result.found.has("die_red_hit.png"),
		"Should find die_red_hit.png in dice/")


func test_validate_all_defense_tokens_all_present() -> void:
	var results: Dictionary = AssetLoader.validate_all()
	var dt_result: AssetLoader.ValidationResult = results["defense_tokens"]
	assert_true(dt_result.is_valid,
		"All 10 defense token PNGs should be present")


func test_validate_all_command_tokens_all_present() -> void:
	var results: Dictionary = AssetLoader.validate_all()
	var ct_result: AssetLoader.ValidationResult = results["command_tokens"]
	assert_true(ct_result.is_valid,
		"All 4 command token PNGs should be present")


# --- validate_category ---

func test_validate_category_known_category() -> void:
	var result: AssetLoader.ValidationResult = AssetLoader.validate_category("scale")
	assert_not_null(result,
		"Should return a result for known category 'scale'")


func test_validate_category_unknown_returns_null() -> void:
	var result: AssetLoader.ValidationResult = AssetLoader.validate_category("nonexistent")
	assert_null(result,
		"Should return null for an unknown category")


func test_validate_category_scale_has_correct_total() -> void:
	var result: AssetLoader.ValidationResult = AssetLoader.validate_category("scale")
	assert_eq(result.total_expected, 1,
		"Scale category should expect 1 file")


func test_validate_category_ships_expected_count() -> void:
	var result: AssetLoader.ValidationResult = AssetLoader.validate_category("ships")
	assert_eq(result.total_expected, 15,
		"Ships category should expect 15 files")


# --- ValidationResult ---

func test_validation_result_is_valid_when_no_missing() -> void:
	var result := AssetLoader.ValidationResult.new()
	result.found.append("file.png")
	assert_true(result.is_valid,
		"Should be valid when missing array is empty")


func test_validation_result_is_invalid_when_missing() -> void:
	var result := AssetLoader.ValidationResult.new()
	result.missing.append("absent.png")
	assert_false(result.is_valid,
		"Should be invalid when missing array has entries")


func test_validation_result_total_expected() -> void:
	var result := AssetLoader.ValidationResult.new()
	result.found.append("a.png")
	result.found.append("b.png")
	result.missing.append("c.png")
	assert_eq(result.total_expected, 3,
		"total_expected should be found + missing count")


# --- load_json ---

func test_load_json_valid_file() -> void:
	var data: Dictionary = AssetLoader.load_json("scale/", "scale_config.json")
	assert_true(data.has("ruler_total_length_px"),
		"Should load and parse scale_config.json correctly")


func test_load_json_nonexistent_file() -> void:
	var data: Dictionary = AssetLoader.load_json("scale/", "nonexistent.json")
	assert_true(data.is_empty(),
		"Should return empty dict for nonexistent JSON")


func test_load_json_ship_data() -> void:
	var data: Dictionary = AssetLoader.load_json("ships/", "cr90_corvette_a.json")
	assert_false(data.is_empty(),
		"Should load cr90_corvette_a.json")


# --- Catalog Key Discovery ---

func test_list_ship_keys_includes_core_ship_expected() -> void:
	var keys: Array[String] = AssetLoader.list_ship_keys()
	assert_true(keys.has("cr90_corvette_a"),
		"Ship key discovery should include Core Set CR90 A")


func test_list_upgrade_keys_recurses_nested_folders_expected() -> void:
	var keys: Array[String] = AssetLoader.list_upgrade_keys()
	assert_true(keys.has("general_dodonna"),
		"Upgrade key discovery should recurse into commander/")
	assert_true(keys.has("expanded_hangar_bay"),
		"Upgrade key discovery should recurse into offensive_retrofit/")


func test_list_objective_keys_includes_core_objective_expected() -> void:
	var keys: Array[String] = AssetLoader.list_objective_keys()
	assert_true(keys.has("obj_ass_most_wanted"),
		"Objective key discovery should include Most Wanted")


func test_list_rule_reference_keys_uses_data_keys_expected() -> void:
	var keys: Array[String] = AssetLoader.list_rule_reference_keys()
	assert_true(keys.has("squadron_keyword.bomber"),
		"Rules-reference discovery should expose dotted RuleRegistry ids")


func test_list_obstacle_keys_returns_empty_without_json_expected() -> void:
	var keys: Array[String] = AssetLoader.list_obstacle_keys()
	assert_eq(keys.size(), 0,
		"Obstacle key discovery should tolerate source-only obstacle folder")


# --- Typed Catalog Loading ---

func test_load_upgrade_data_nested_key_expected() -> void:
	var upgrade: UpgradeData = AssetLoader.load_upgrade_data("general_dodonna")
	assert_not_null(upgrade, "Should load General Dodonna from nested upgrade folders")
	assert_eq(upgrade.upgrade_name, "General Dodonna", "Should parse loaded upgrade")


func test_load_objective_data_key_expected() -> void:
	var objective: ObjectiveData = AssetLoader.load_objective_data("obj_ass_most_wanted")
	assert_not_null(objective, "Should load Most Wanted objective")
	assert_eq(objective.category, "ASSAULT", "Should parse objective category")


func test_load_rule_reference_data_dotted_key_expected() -> void:
	var rule_reference: RuleReferenceData = AssetLoader.load_rule_reference_data("squadron_keyword.bomber")
	assert_not_null(rule_reference, "Should load Bomber rules reference by dotted id")
	assert_eq(rule_reference.display_name, "Bomber", "Should parse rules reference")


func test_load_rule_reference_data_file_stem_fallback_expected() -> void:
	var rule_reference: RuleReferenceData = AssetLoader.load_rule_reference_data("squadron_keyword_bomber")
	assert_not_null(rule_reference, "Should load Bomber rules reference by file stem")
	assert_eq(rule_reference.data_key, "squadron_keyword.bomber", "Should preserve catalog data key")


func test_load_missing_catalog_records_return_null_expected() -> void:
	assert_null(AssetLoader.load_upgrade_data("missing_upgrade"),
		"Missing upgrade should return null")
	assert_null(AssetLoader.load_objective_data("missing_objective"),
		"Missing objective should return null")
	assert_null(AssetLoader.load_rule_reference_data("missing_rule"),
		"Missing rules reference should return null")


# --- load_texture ---

func test_load_texture_existing_png() -> void:
	var tex: Texture2D = AssetLoader.load_texture("dice/", "die_red_hit.png")
	assert_not_null(tex,
		"Should load die_red_hit.png as Texture2D")


func test_load_texture_nonexistent_returns_null() -> void:
	var tex: Texture2D = AssetLoader.load_texture("dice/", "nonexistent.png")
	assert_null(tex,
		"Should return null for nonexistent texture")
