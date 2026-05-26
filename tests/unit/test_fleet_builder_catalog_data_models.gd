## Test: Fleet Builder Catalog Data Models
##
## Unit tests for static ObjectiveData, ObstacleData, and RuleReferenceData parsing.
extends GutTest


func test_objective_from_dict_parses_identity_expected() -> void:
	var data: Dictionary = _load_most_wanted_record()
	var objective: ObjectiveData = ObjectiveData.from_dict(data)
	assert_eq(objective.data_key, "obj_ass_most_wanted", "Should parse objective key")
	assert_eq(objective.objective_name, "Most Wanted", "Should parse objective name")
	assert_eq(objective.category, "ASSAULT", "Should parse objective category")
	assert_eq(objective.wave, 0, "Core Set objectives should parse as wave 0")


func test_objective_from_dict_preserves_setup_metadata_expected() -> void:
	var data: Dictionary = _load_most_wanted_record()
	var objective: ObjectiveData = ObjectiveData.from_dict(data)
	assert_eq(objective.victory_token_points, null, "Should preserve null victory token points")
	assert_true(objective.task_force_recommended, "Should parse task-force recommendation")
	assert_eq(objective.setup_effects[0].get("kind", ""), "choose_objective_ship_pair",
		"Should preserve setup effect descriptors")
	assert_eq(int(objective.objective_tokens.get("count", 0)), 2, "Should preserve token metadata")


func test_objective_from_dict_preserves_rules_metadata_expected() -> void:
	var data: Dictionary = _load_most_wanted_record()
	var objective: ObjectiveData = ObjectiveData.from_dict(data)
	assert_eq(objective.rules_integration.get("status", ""), "NOT_INTEGRATED",
		"Should parse objective implementation status")
	assert_eq(objective.rule_surfaces[0].get("surface", ""), "attack.dice_pool",
		"Should preserve rule surface metadata")
	assert_eq(objective.errata[0].get("field", ""), "special_rule_text",
		"Should preserve structured errata notes")


func test_rule_reference_from_dict_parses_registry_mapping_expected() -> void:
	var data: Dictionary = AssetLoader.load_json("rules/", "squadron_keyword_bomber.json")
	var rule_reference: RuleReferenceData = RuleReferenceData.from_dict(data)
	assert_eq(rule_reference.data_key, "squadron_keyword.bomber", "Should parse dotted rule id")
	assert_eq(rule_reference.display_name, "Bomber", "Should parse display name")
	assert_true(rule_reference.implemented_rule_ids.has("squadron_keyword.bomber"),
		"Should preserve RuleRegistry id mapping")
	assert_eq(rule_reference.implementation_status, "INTEGRATED", "Should parse status")


func test_obstacle_from_dict_parses_future_catalog_shape_expected() -> void:
	var data: Dictionary = _create_obstacle_record()
	var obstacle: ObstacleData = ObstacleData.from_dict(data)
	assert_eq(obstacle.data_key, "asteroid_field_1", "Should parse obstacle key")
	assert_eq(obstacle.obstacle_type, "ASTEROID", "Should parse obstacle type")
	assert_eq(obstacle.shape_metadata.get("width_mm", 0), 92, "Should preserve shape metadata")
	assert_true(obstacle.search_tags.has("asteroid"), "Should parse search tags")


func _load_most_wanted_record() -> Dictionary:
	return AssetLoader.load_json("objectives/", "obj_ass_most_wanted.json")


func _create_obstacle_record() -> Dictionary:
	return {
		"data_key": "asteroid_field_1",
		"kind": "obstacle_component",
		"obstacle_name": "Asteroid Field 1",
		"obstacle_type": "ASTEROID",
		"token_image": "asteroid_field_1.png",
		"wave": 0,
		"expansion": "core_set",
		"available_through": ["star_wars_armada_core_set"],
		"setup_constraints": ["distance_1_from_edges"],
		"shape_metadata": {"width_mm": 92, "height_mm": 48},
		"rules_reference_ids": ["obstacle.asteroid"],
		"rules_integration": {"status": "NOT_INTEGRATED"},
		"search_tags": ["obstacle", "asteroid"],
		"source_refs": ["Resources/Game_Components/obstacles/obstacles_specs.txt"],
	}