## Test: Component Catalog Schema Contract
##
## Guards the FB1 static catalog schema and required fleet-builder metadata for
## ships, squadrons, upgrades, objectives, obstacles, and rules references.
extends GutTest

const SCHEMA_PATH: String = "res://Resources/Game_Components/card_data_schema.json"
const README_PATH: String = "res://Resources/Game_Components/README.md"
const RULES_README_PATH: String = "res://Resources/Game_Components/rules/README.md"
const COMPONENT_ROOT: String = "res://Resources/Game_Components/"

const REQUIRED_SCHEMA_DEFINITIONS: Array[String] = [
	"ship_card",
	"squadron_card",
	"upgrade_card",
	"objective_card",
	"obstacle_component",
	"rules_reference",
	"rules_integration",
]

const OBJECTIVE_FILES: Array[String] = [
	"objectives/obj_ass_advanced_gunnery.json",
	"objectives/obj_ass_most_wanted.json",
	"objectives/obj_ass_opening_salvo.json",
	"objectives/obj_ass_precision_strike.json",
	"objectives/obj_def_contested_outpost.json",
	"objectives/obj_def_fire_lanes.json",
	"objectives/obj_def_fleet_ambush.json",
	"objectives/obj_def_hyperspace_assault.json",
	"objectives/obj_nav_dangerous_territory.json",
	"objectives/obj_nav_intel_sweep.json",
	"objectives/obj_nav_minefields.json",
	"objectives/obj_nav_superior_positions.json",
]

const SQUADRON_FILES: Array[String] = [
	"squadrons/tie_advanced_squadron.json",
	"squadrons/tie_bomber_squadron.json",
	"squadrons/tie_fighter_howlrunner.json",
	"squadrons/tie_fighter_squadron.json",
	"squadrons/tie_interceptor_squadron.json",
	"squadrons/x_wing_luke_skywalker.json",
	"squadrons/x_wing_squadron.json",
]

const UPGRADE_FILES: Array[String] = [
	"upgrades/commander/general_dodonna.json",
	"upgrades/commander/grand_moff_tarkin.json",
	"upgrades/defensive_retrofit/electronic_countermeasures.json",
	"upgrades/ion_cannons/overload_pulse.json",
	"upgrades/offensive_retrofit/expanded_hangar_bay.json",
	"upgrades/officer/defense_liaison.json",
	"upgrades/officer/leia_organa.json",
	"upgrades/officer/weapons_liaison.json",
	"upgrades/officer/wulff_yularen.json",
	"upgrades/ordnance/assault_concussion_missiles.json",
	"upgrades/support_team/engineering_team.json",
	"upgrades/support_team/nav_team.json",
	"upgrades/title/dodonnas_pride.json",
	"upgrades/title/dominator.json",
	"upgrades/title/redemption.json",
	"upgrades/turbolasers/enhanced_armament.json",
	"upgrades/turbolasers/h9_turbolasers.json",
	"upgrades/weapon_team/gunnery_team.json",
]

const OBSTACLE_FILES: Array[String] = [
	"obstacles/asteroid_1.json",
	"obstacles/asteroid_2.json",
	"obstacles/asteroid_3.json",
	"obstacles/debris_1.json",
	"obstacles/debris_2.json",
	"obstacles/station.json",
]

const RULE_REFERENCE_FILES: Array[String] = [
	"rules/squadron_keyword_bomber.json",
	"rules/squadron_keyword_counter.json",
	"rules/squadron_keyword_escort.json",
	"rules/squadron_keyword_heavy.json",
	"rules/squadron_keyword_swarm.json",
]


func test_schema_definitions_include_fleet_builder_records_expected() -> void:
	# Arrange
	var schema: Dictionary = _load_json(SCHEMA_PATH)
	var definitions: Dictionary = schema.get("definitions", {})

	# Act / Assert
	for definition_name: String in REQUIRED_SCHEMA_DEFINITIONS:
		assert_has(definitions, definition_name,
			"Schema should define '%s' for FB1 catalog records" % definition_name)


func test_component_readme_lists_new_catalog_folders_expected() -> void:
	# Arrange
	var readme_text: String = _load_text(README_PATH)
	var expected_folders: Array[String] = ["upgrades/", "objectives/", "obstacles/", "rules/"]

	# Act / Assert
	for folder_name: String in expected_folders:
		assert_true(readme_text.contains(folder_name),
			"README should list '%s' for FB1 catalog structure" % folder_name)


func test_rules_reference_folder_readme_exists_expected() -> void:
	# Arrange / Act
	var exists: bool = FileAccess.file_exists(RULES_README_PATH)

	# Assert
	assert_true(exists, "Rules reference folder should have a committed README contract")


func test_objective_records_have_required_fb1_metadata_expected() -> void:
	# Arrange / Act / Assert
	for file_path: String in OBJECTIVE_FILES:
		var record: Dictionary = _load_component_record(file_path)
		_assert_common_catalog_metadata(record, file_path)
		assert_eq(record.get("kind", ""), "objective_card",
			"%s should be an objective_card record" % file_path)
		var rules_integration: Dictionary = record.get("rules_integration", {})
		assert_eq(rules_integration.get("status", ""), "NOT_INTEGRATED",
			"%s objective rules should remain marked not integrated" % file_path)


func test_upgrade_records_have_required_fb1_metadata_expected() -> void:
	# Arrange / Act / Assert
	for file_path: String in UPGRADE_FILES:
		var record: Dictionary = _load_component_record(file_path)
		_assert_common_catalog_metadata(record, file_path)
		assert_eq(record.get("kind", ""), "upgrade_card",
			"%s should be an upgrade_card record" % file_path)
		var rules_integration: Dictionary = record.get("rules_integration", {})
		assert_eq(rules_integration.get("status", ""), "NOT_INTEGRATED",
			"%s upgrade rules should remain marked not integrated" % file_path)


func test_obstacle_records_have_required_fb3_metadata_expected() -> void:
	# Arrange / Act / Assert
	for file_path: String in OBSTACLE_FILES:
		var record: Dictionary = _load_component_record(file_path)
		_assert_common_catalog_metadata(record, file_path)
		assert_eq(record.get("kind", ""), "obstacle_component",
			"%s should be an obstacle_component record" % file_path)
		var token_image: String = str(record.get("token_image", ""))
		assert_true(FileAccess.file_exists(COMPONENT_ROOT + "obstacles/" + token_image),
			"%s should point to a committed obstacle token image" % file_path)
		assert_false(record.get("setup_constraints", []).is_empty(),
			"%s should include setup constraints" % file_path)
		assert_false(record.get("shape_metadata", {}).is_empty(),
			"%s should include draft shape metadata" % file_path)
		var rules_integration: Dictionary = record.get("rules_integration", {})
		assert_eq(rules_integration.get("status", ""), "NOT_INTEGRATED",
			"%s obstacle rules should remain marked not integrated" % file_path)


func test_squadron_records_have_rules_integration_metadata_expected() -> void:
	# Arrange / Act / Assert
	for file_path: String in SQUADRON_FILES:
		var record: Dictionary = _load_component_record(file_path)
		_assert_common_catalog_metadata(record, file_path)
		assert_eq(record.get("kind", ""), "squadron_card",
			"%s should be a squadron_card record" % file_path)
		var rules_integration: Dictionary = record.get("rules_integration", {})
		assert_true(rules_integration.has("status"),
			"%s should expose rules integration status" % file_path)


func test_rule_reference_records_map_to_integrated_rule_ids_expected() -> void:
	# Arrange / Act / Assert
	for file_path: String in RULE_REFERENCE_FILES:
		var record: Dictionary = _load_component_record(file_path)
		assert_eq(record.get("kind", ""), "rules_reference",
			"%s should be a rules_reference record" % file_path)
		assert_eq(record.get("implementation_status", ""), "INTEGRATED",
			"%s should describe an implemented generic keyword" % file_path)
		assert_false(record.get("implemented_rule_ids", []).is_empty(),
			"%s should map to at least one RuleRegistry id" % file_path)


func test_all_component_records_load_as_typed_data_expected() -> void:
	for key: String in AssetLoader.list_ship_keys():
		assert_not_null(AssetLoader.load_ship_data(key),
			"Ship '%s' should parse as typed data" % key)
	for key: String in AssetLoader.list_squadron_keys():
		assert_not_null(AssetLoader.load_squadron_data(key),
			"Squadron '%s' should parse as typed data" % key)
	for key: String in AssetLoader.list_upgrade_keys():
		assert_not_null(AssetLoader.load_upgrade_data(key),
			"Upgrade '%s' should parse as typed data" % key)
	for key: String in AssetLoader.list_objective_keys():
		assert_not_null(AssetLoader.load_objective_data(key),
			"Objective '%s' should parse as typed data" % key)
	for key: String in AssetLoader.list_obstacle_keys():
		assert_not_null(AssetLoader.load_obstacle_data(key),
			"Obstacle '%s' should parse as typed data" % key)
	for key: String in AssetLoader.list_rule_reference_keys():
		assert_not_null(AssetLoader.load_rule_reference_data(key),
			"Rule reference '%s' should parse as typed data" % key)


func test_objective_catalog_categories_complete_expected() -> void:
	var category_counts: Dictionary = {
		"ASSAULT": 0,
		"DEFENSE": 0,
		"NAVIGATION": 0,
	}
	for key: String in AssetLoader.list_objective_keys():
		var objective: ObjectiveData = AssetLoader.load_objective_data(key)
		assert_not_null(objective, "Objective '%s' should load" % key)
		if objective != null and category_counts.has(objective.category):
			category_counts[objective.category] = int(category_counts[objective.category]) + 1

	assert_eq(category_counts.get("ASSAULT", 0), 4,
		"Core Set catalog should include four Assault objectives")
	assert_eq(category_counts.get("DEFENSE", 0), 4,
		"Core Set catalog should include four Defense objectives")
	assert_eq(category_counts.get("NAVIGATION", 0), 4,
		"Core Set catalog should include four Navigation objectives")


func _load_component_record(file_path: String) -> Dictionary:
	return _load_json(COMPONENT_ROOT + file_path)


func _load_json(path: String) -> Dictionary:
	var text: String = _load_text(path)
	var parsed: Variant = JSON.parse_string(text)
	assert_typeof(parsed, TYPE_DICTIONARY, "%s should parse as a JSON object" % path)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var parsed_dictionary: Dictionary = parsed as Dictionary
	return parsed_dictionary


func _load_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "%s should exist" % path)
	if file == null:
		return ""
	return file.get_as_text()


func _assert_common_catalog_metadata(record: Dictionary, file_path: String) -> void:
	var required_fields: Array[String] = [
		"data_key",
		"kind",
		"wave",
		"expansion",
		"available_through",
		"rules_reference_ids",
		"rules_integration",
		"search_tags",
		"source_refs",
	]
	for field_name: String in required_fields:
		assert_has(record, field_name, "%s should include '%s'" % [file_path, field_name])
