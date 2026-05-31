## Test: FleetBuilderOptions
##
## Unit tests for fleet-builder option sets derived from core rules and catalog metadata.
extends GutTest


func test_available_point_formats_returns_core_presets_expected() -> void:
	var formats: Array[Dictionary] = FleetBuilderOptions.available_point_formats()

	assert_eq(str(formats[0].get("id", "")), FleetBuilderOptions.FORMAT_CORE_SET_180,
		"Core Set format should be the first draft preset")
	assert_eq(int(formats[1].get("limit", 0)), FleetValidator.DEFAULT_POINT_LIMIT,
		"Standard format should use the validator default point limit")
	assert_eq(str(formats[2].get("id", "")), FleetBuilderOptions.FORMAT_CUSTOM,
		"Custom format should remain available as a user-facing preset")


func test_default_point_format_returns_serialized_core_set_expected() -> void:
	var format: Dictionary = FleetBuilderOptions.default_point_format()

	assert_eq(str(format.get("id", "")), FleetBuilderOptions.FORMAT_CORE_SET_180,
		"Default draft format should be Core Set 180")
	assert_eq(int(format.get("limit", 0)), FleetBuilderOptions.CORE_SET_POINT_LIMIT,
		"Default draft limit should be the Core Set task-force limit")
	assert_false(format.has("label"), "Serialized point format should not include UI labels")


func test_available_maps_for_core_set_filters_3x3_expected() -> void:
	var maps: Array[Dictionary] = FleetBuilderOptions.available_maps_for_point_format(
			{"id": "CORE_SET_180", "limit": 180})

	assert_false(maps.is_empty(), "Core Set maps should be available")
	assert_true(_all_maps_have_grid(maps, FleetBuilderOptions.MAP_GRID_3X3),
		"Core Set 180 should only offer 3x3 maps")


func test_available_maps_for_300_filters_3x6_expected() -> void:
	var maps: Array[Dictionary] = FleetBuilderOptions.available_maps_for_point_format(
			{"id": "CUSTOM", "limit": 300})

	assert_false(maps.is_empty(), "300 point maps should be available")
	assert_true(_all_maps_have_grid(maps, FleetBuilderOptions.MAP_GRID_3X6),
		"300 point games should only offer 3x6 maps")


func test_default_map_for_standard_400_uses_3x6_expected() -> void:
	var payload: Dictionary = FleetBuilderOptions.default_map_for_point_format(
			{"id": "STANDARD_400", "limit": 400})

	assert_eq(payload.get("grid", ""), FleetBuilderOptions.MAP_GRID_3X6,
		"Standard 400 should default to a 3x6 map")
	assert_eq(payload.get("filename", ""), FleetBuilderOptions.DEFAULT_MAP_3X6,
		"Standard 400 should use the default 3x6 map filename")


func test_available_factions_derives_from_catalog_expected() -> void:
	var factions: Array[String] = FleetBuilderOptions.available_factions(FleetCatalog.new())

	assert_true(factions.has("REBEL_ALLIANCE"), "Rebel faction should come from catalog data")
	assert_true(factions.has("GALACTIC_EMPIRE"), "Imperial faction should come from catalog data")
	assert_eq(factions[0], "REBEL_ALLIANCE", "Faction display order should be stable")


func test_objective_categories_returns_selection_order_expected() -> void:
	var categories: Array[String] = FleetBuilderOptions.objective_categories()

	assert_eq(categories, FleetObjectiveSelection.categories(),
		"Fleet-builder objectives should use FleetObjectiveSelection order")


func test_upgrade_type_groups_derives_available_types_expected() -> void:
	var groups: Array[Dictionary] = FleetBuilderOptions.upgrade_type_groups(FleetCatalog.new())
	var types: Array[String] = _flatten_group_types(groups)

	assert_true(types.has("COMMANDER"), "Commander upgrades should be represented")
	assert_true(types.has("TITLE"), "Title upgrades should be represented")
	assert_true(_group_names(groups).has("Titles"), "Title group should be retained")


func test_rule_filters_derive_from_rules_catalog_expected() -> void:
	var catalog: FleetCatalog = FleetCatalog.new()

	assert_true(FleetBuilderOptions.rule_categories(catalog).has("SQUADRON_KEYWORD"),
		"Rule categories should come from rules-reference entries")
	assert_true(FleetBuilderOptions.rule_statuses(catalog).has("INTEGRATED"),
		"Rule statuses should come from rules-reference entries")


func _flatten_group_types(groups: Array[Dictionary]) -> Array[String]:
	var types: Array[String] = []
	for group: Dictionary in groups:
		for raw_type: Variant in group.get("types", []):
			types.append(str(raw_type))
	return types


func _group_names(groups: Array[Dictionary]) -> Array[String]:
	var names: Array[String] = []
	for group: Dictionary in groups:
		names.append(str(group.get("group", "")))
	return names


func _all_maps_have_grid(maps: Array[Dictionary], grid: String) -> bool:
	for payload: Dictionary in maps:
		if str(payload.get("grid", "")) != grid:
			return false
	return true
