## Test: FleetCatalog
##
## Unit tests for deterministic fleet-builder catalog queries and rule lookups.
extends GutTest


var _catalog: FleetCatalog


func before_each() -> void:
	_catalog = FleetCatalog.new()


func test_query_components_returns_deterministic_order_expected() -> void:
	var first: Array[Dictionary] = _catalog.query_components()
	var second: Array[Dictionary] = _catalog.query_components()

	assert_false(first.is_empty(), "Catalog query should return entries")
	assert_eq(_signature(first), _signature(second),
		"Repeated queries should produce deterministic ordering")


func test_query_components_filters_component_type_expected() -> void:
	var results: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_UPGRADE],
	})

	assert_false(results.is_empty(), "Upgrade query should return results")
	for entry: Dictionary in results:
		assert_eq(entry.get("component_type", ""), FleetCatalog.COMPONENT_UPGRADE,
			"Component-type filter should keep only upgrades")


func test_query_components_filters_faction_expected() -> void:
	var results: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_SHIP],
		"faction": "REBEL_ALLIANCE",
	})

	assert_false(results.is_empty(), "Faction filter should return ship results")
	for entry: Dictionary in results:
		assert_eq(entry.get("faction", ""), "REBEL_ALLIANCE",
			"Faction filter should keep only Rebel ships")


func test_query_components_faction_filter_includes_neutral_upgrades_expected() -> void:
	var results: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_UPGRADE],
		"faction": "REBEL_ALLIANCE",
	})

	assert_true(_contains_key(results, "leia_organa"),
		"Faction filter should include matching Rebel upgrades")
	assert_true(_contains_key(results, "h9_turbolasers"),
		"Faction filter should include unrestricted upgrades")
	assert_false(_contains_key(results, "grand_moff_tarkin"),
		"Faction filter should exclude opponent-only upgrades")


func test_query_components_filters_point_range_expected() -> void:
	var results: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_UPGRADE],
		"min_point_cost": 3,
		"max_point_cost": 3,
	})

	assert_false(results.is_empty(), "Point-range filter should return upgrades")
	for entry: Dictionary in results:
		assert_eq(int(entry.get("point_cost", -1)), 3,
			"Point-range filter should keep exact-cost upgrades")


func test_query_components_filters_upgrade_type_expected() -> void:
	var results: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_UPGRADE],
		"upgrade_type": "OFFICER",
	})

	assert_false(results.is_empty(), "Upgrade-type filter should return results")
	for entry: Dictionary in results:
		assert_eq(entry.get("upgrade_type", ""), "OFFICER",
			"Upgrade-type filter should keep only OFFICER upgrades")


func test_query_components_filters_wave_and_expansion_expected() -> void:
	var results: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_OBSTACLE],
		"wave": 0,
		"expansion": "core_set",
	})

	assert_eq(results.size(), 6, "Core Set obstacle query should return six records")
	for entry: Dictionary in results:
		assert_eq(int(entry.get("wave", -1)), 0, "Obstacle wave should match filter")
		assert_eq(entry.get("expansion", ""), "core_set", "Obstacle expansion should match")


func test_query_components_filters_keyword_expected() -> void:
	var results: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_SQUADRON],
		"keyword": "Bomber",
	})

	assert_false(results.is_empty(), "Keyword filter should return squadron entries")
	assert_true(_contains_key(results, "x_wing_squadron"),
		"Bomber keyword filter should include X-wing Squadron")


func test_query_components_filters_rules_category_expected() -> void:
	var results: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_SQUADRON],
		"rules_category": "SQUADRON_KEYWORD",
	})

	assert_false(results.is_empty(), "Rules-category filter should return squadrons")
	assert_true(_contains_key(results, "x_wing_squadron"),
		"Rules-category filter should include squadrons linked to keyword rules")


func test_query_components_filters_implementation_status_expected() -> void:
	var results: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_RULE_REFERENCE],
		"implementation_status": "INTEGRATED",
	})

	assert_false(results.is_empty(), "Integrated rules filter should return records")
	for entry: Dictionary in results:
		assert_eq(entry.get("implementation_status", ""), "INTEGRATED",
			"Implementation-status filter should keep integrated rules")


func test_query_components_case_insensitive_text_and_tag_expected() -> void:
	var text_results: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_UPGRADE],
		"text": "LEIA ORGANA",
	})
	var tag_results: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_UPGRADE],
		"tag": "rebel",
	})

	assert_true(_contains_key(text_results, "leia_organa"),
		"Case-insensitive text search should include Leia Organa")
	assert_true(_contains_key(tag_results, "leia_organa"),
		"Tag search should include upgrades tagged as rebel")


func test_query_components_filter_combination_expected() -> void:
	var results: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_UPGRADE],
		"faction": "REBEL_ALLIANCE",
		"upgrade_type": "OFFICER",
		"min_point_cost": 3,
		"max_point_cost": 3,
		"tag": "rebel",
	})

	assert_true(_contains_key(results, "leia_organa"),
		"Combined filters should include Leia Organa")


func test_query_components_empty_result_expected() -> void:
	var results: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_SHIP],
		"faction": "SEPARATIST_ALLIANCE",
		"wave": 99,
	})

	assert_true(results.is_empty(), "Impossible filter combination should return empty")


func test_get_rules_for_component_returns_linked_generic_rules_expected() -> void:
	var entries: Array[Dictionary] = _catalog.query_components({
		"component_types": [FleetCatalog.COMPONENT_SQUADRON],
		"text": "X-wing Squadron",
	})
	assert_false(entries.is_empty(), "Should find X-wing squadron catalog entry")

	var rules: Array[RuleReferenceData] = _catalog.get_rules_for_component(entries[0], true)

	assert_false(rules.is_empty(), "X-wing squadron should resolve linked generic rules")
	assert_true(_contains_rule(rules, "squadron_keyword.bomber"),
		"Resolved linked rules should include Bomber")


func test_get_rules_by_category_returns_sorted_rules_expected() -> void:
	var rules: Array[RuleReferenceData] = _catalog.get_rules_by_category(
		"SQUADRON_KEYWORD", "INTEGRATED")

	assert_false(rules.is_empty(), "Category lookup should return integrated keyword rules")
	assert_true(_contains_rule(rules, "squadron_keyword.bomber"),
		"Category lookup should include Bomber")
	assert_eq(_rule_signature(rules), _sorted_rule_signature(rules),
		"Category lookup should return deterministically sorted rule ids")


func _contains_key(entries: Array[Dictionary], data_key: String) -> bool:
	for entry: Dictionary in entries:
		if str(entry.get("data_key", "")) == data_key:
			return true
	return false


func _contains_rule(rules: Array[RuleReferenceData], rule_id: String) -> bool:
	for rule: RuleReferenceData in rules:
		if rule.data_key == rule_id:
			return true
	return false


func _signature(entries: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in entries:
		result.append("%s:%s" % [entry.get("component_type", ""), entry.get("data_key", "")])
	return result


func _rule_signature(rules: Array[RuleReferenceData]) -> Array[String]:
	var result: Array[String] = []
	for rule: RuleReferenceData in rules:
		result.append(rule.data_key)
	return result


func _sorted_rule_signature(rules: Array[RuleReferenceData]) -> Array[String]:
	var result: Array[String] = _rule_signature(rules)
	result.sort()
	return result
