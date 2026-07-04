## Test: FleetValidator
##
## Unit tests for FB6 baseline fleet-construction validation rules.
extends GutTest


const FleetValidatorDoubleScript: GDScript = preload(
		"res://tests/fixtures/fleet/fleet_validator_double.gd")


var _validator: FleetValidator


func before_each() -> void:
	_validator = FleetValidator.new()


func test_validate_legal_core_set_180_fleet_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	roster.add_squadron(_create_squadron("squad-1", "x_wing_squadron"))
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(result.is_valid(), "Legal 180-point fleet should validate")


func test_validate_legal_standard_400_fleet_expected() -> void:
	var roster: FleetRoster = _create_roster("GALACTIC_EMPIRE", 400)
	_add_ship_with_commander(roster, "ship-1", "victory_ii_class_star_destroyer",
		"grand_moff_tarkin")
	roster.add_squadron(_create_squadron("squad-1", "tie_fighter_squadron"))
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(result.is_valid(), "Legal 400-point fleet should validate")


func test_validate_legal_custom_limit_fleet_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 250)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	roster.add_squadron(_create_squadron("squad-1", "x_wing_squadron"))
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_false(_has_rule_error(result, FleetValidator.RULE_POINTS_LIMIT),
		"Fleet under custom point limit should not report point-limit error")


func test_validate_over_limit_fleet_reports_points_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 60)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	roster.add_squadron(_create_squadron("squad-1", "x_wing_squadron"))
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_POINTS_LIMIT),
		"Over-limit fleet should report point-limit error")


func test_validate_mixed_faction_reports_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	roster.add_squadron(_create_squadron("squad-1", "tie_fighter_squadron"))
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_FACTION_ALIGNMENT),
		"Mixed-faction roster should report faction-alignment error")


func test_validate_zero_commander_reports_count_and_flagship_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	roster.add_ship(_create_ship("ship-1", "cr90_corvette_a"))
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_COMMANDER_COUNT),
		"Roster without commander should report commander-count error")
	assert_true(_has_rule_error(result, FleetValidator.RULE_FLAGSHIP_COUNT),
		"Roster without commander should report flagship-count error")


func test_validate_two_commanders_reports_count_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	_add_ship_with_commander(roster, "ship-2", "nebulon_b_support_refit", "general_dodonna")
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_COMMANDER_COUNT),
		"Roster with two commanders should report commander-count error")


func test_validate_excessive_squadron_points_reports_cap_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	for squad_index: int in range(5):
		roster.add_squadron(_create_squadron("squad-%d" % squad_index, "x_wing_squadron"))
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_SQUADRON_CAP),
		"Roster over one-third squadron cap should report squadron-cap error")


func test_validate_squadron_cap_rounded_up_boundary_allowed_expected() -> void:
	var validator: Variant = _create_test_validator("ship-test", ["OFFICER"])
	validator.add_squadron_override("cap_squadron", _create_squadron_data(
		"cap_squadron", 61))
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 181)
	_add_ship_with_commander(roster, "ship-1", "ship-test", "general_dodonna")
	roster.add_squadron(_create_squadron("squad-1", "cap_squadron"))
	_set_valid_objectives(roster)

	var result: FleetValidationResult = validator.validate(roster)

	assert_false(_has_rule_error(result, FleetValidator.RULE_SQUADRON_CAP),
		"Squadron cap should round one-third up for agreed point limits")


func test_validate_unique_squadron_limit_reports_error_expected() -> void:
	var validator: Variant = _create_test_validator("ship-test", ["OFFICER"])
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "ship-test", "general_dodonna")
	for index: int in range(3):
		var key: String = "ace_%d" % index
		validator.add_squadron_override(key, _create_squadron_data(key, 1, true, key, true))
		roster.add_squadron(_create_squadron("squad-%d" % index, key))
	_set_valid_objectives(roster)

	var result: FleetValidationResult = validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_UNIQUE_SQUADRON_LIMIT),
		"Too many unique squadrons with defense tokens should report limit error")


func test_validate_duplicate_unique_upgrades_reports_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_upgrade(roster, "ship-1", "cr90_corvette_a", "leia_organa")
	_add_ship_with_upgrade(roster, "ship-2", "nebulon_b_support_refit", "leia_organa")
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "upg-cmd", "general_dodonna",
		"COMMANDER")
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_UNIQUE_UPGRADE),
		"Duplicate unique upgrades should report unique-upgrade error")


func test_validate_duplicate_unique_squadrons_reports_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	roster.add_squadron(_create_squadron("squad-1", "x_wing_luke_skywalker"))
	roster.add_squadron(_create_squadron("squad-2", "x_wing_luke_skywalker"))
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_UNIQUE_SQUADRON),
		"Duplicate unique squadrons should report unique-squadron error")


func test_validate_duplicate_unique_squadron_group_reports_error_expected() -> void:
	var validator: Variant = _create_test_validator("ship-test", ["OFFICER"])
	validator.add_squadron_override("ace_a", _create_squadron_data(
		"Ace A", 1, true, "shared_ace", true))
	validator.add_squadron_override("ace_b", _create_squadron_data(
		"Ace B", 1, true, "shared_ace", true))
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "ship-test", "general_dodonna")
	roster.add_squadron(_create_squadron("squad-1", "ace_a"))
	roster.add_squadron(_create_squadron("squad-2", "ace_b"))
	_set_valid_objectives(roster)

	var result: FleetValidationResult = validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_UNIQUE_SQUADRON),
		"Squadrons sharing a unique group should report unique-squadron error")


func test_validate_missing_catalog_references_report_errors_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	var ship_entry: FleetShipEntry = _create_ship("ship-1", "missing_ship")
	_add_upgrade_to_ship(ship_entry, "upgrade-1", "missing_upgrade", "OFFICER")
	roster.add_ship(ship_entry)
	roster.add_squadron(_create_squadron("squad-1", "missing_squadron"))
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_SHIP_REFERENCE),
		"Missing ship catalog references should report ship-reference error")
	assert_true(_has_rule_error(result, FleetValidator.RULE_UPGRADE_REFERENCE),
		"Missing upgrade catalog references should report upgrade-reference error")
	assert_true(_has_rule_error(result, FleetValidator.RULE_SQUADRON_REFERENCE),
		"Missing squadron catalog references should report squadron-reference error")


func test_validate_invalid_objectives_reports_category_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	var objectives: FleetObjectiveSelection = FleetObjectiveSelection.new()
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_def_fire_lanes")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_DEFENSE, "obj_def_fire_lanes")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_NAVIGATION, "obj_nav_intel_sweep")
	roster.set_objectives(objectives)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_OBJECTIVE_CATEGORY),
		"Objective category mismatch should report objective-category error")


func test_validate_core_set_with_3x6_map_reports_grid_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	_set_valid_objectives(roster)
	roster.map = FleetBuilderOptions.map_payload("map_3x6_distant-planet_v4.jpg")

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_MAP_GRID),
		"Core Set 180 fleets should require 3x3 maps")


func test_validate_standard_with_3x3_map_reports_grid_error_expected() -> void:
	var roster: FleetRoster = _create_roster("GALACTIC_EMPIRE", 400)
	_add_ship_with_commander(roster, "ship-1", "victory_ii_class_star_destroyer",
		"grand_moff_tarkin")
	_set_valid_objectives(roster)
	roster.map = FleetBuilderOptions.map_payload("map_3x3_distant_planet_v3.jpg")

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_MAP_GRID),
		"Standard 400 fleets should require 3x6 maps")


func test_validate_missing_map_reports_required_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	_set_valid_objectives(roster)
	roster.map = {}

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_MAP_REQUIRED),
		"Rosters without a selected map should report map-required")


func test_validate_missing_objective_reports_required_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	var objectives: FleetObjectiveSelection = FleetObjectiveSelection.new()
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_DEFENSE, "obj_def_fire_lanes")
	roster.set_objectives(objectives)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_OBJECTIVE_REQUIRED),
		"Missing objective category should report objective-required error")


func test_validate_commander_uses_commander_slot_without_ship_bar_expected() -> void:
	var validator: Variant = _create_test_validator("ship-test", ["OFFICER"])
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "ship-test", "general_dodonna")
	_set_valid_objectives(roster)

	var result: FleetValidationResult = validator.validate(roster)

	assert_false(_has_rule_error(result, FleetValidator.RULE_UPGRADE_SLOT),
		"Commander assignment should not require a ship COMMANDER upgrade-bar slot")


func test_validate_commander_does_not_consume_officer_slot_expected() -> void:
	var validator: Variant = _create_test_validator("ship-test", ["OFFICER"])
	validator.add_upgrade_override("officer_copy", _create_upgrade_data(
		"officer_copy", "OFFICER"))
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "ship-test", "general_dodonna")
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "officer-1", "officer_copy",
		"OFFICER")
	_set_valid_objectives(roster)

	var result: FleetValidationResult = validator.validate(roster)

	assert_false(_has_rule_error(result, FleetValidator.RULE_UPGRADE_SLOT),
		"Officer slot should remain available after the commander assignment")


func test_validate_commander_assigned_to_officer_slot_reports_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	var ship_entry: FleetShipEntry = _create_ship("ship-1", "cr90_corvette_a")
	_add_upgrade_to_ship(ship_entry, "ship-1-cmd", "general_dodonna", "OFFICER")
	roster.add_ship(ship_entry)
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_UPGRADE_SLOT),
		"Commander assignment to OFFICER should report slot validation error")


func test_validate_officer_assigned_to_commander_slot_reports_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "ship-1-officer",
		"leia_organa", "COMMANDER")
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_UPGRADE_SLOT),
		"Normal officer upgrades should still require an OFFICER ship slot")


func test_validate_ship_with_commander_counts_as_flagship_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	roster.add_ship(_create_ship("ship-1", "nebulon_b_support_refit"))
	_add_ship_with_commander(roster, "ship-2", "cr90_corvette_a", "general_dodonna")
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_false(_has_rule_error(result, FleetValidator.RULE_FLAGSHIP_COUNT),
		"The ship carrying the commander should still count as the flagship")


func test_validate_upgrade_slot_mismatch_reports_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "ship-1-h9", "h9_turbolasers", "OFFICER")
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_UPGRADE_SLOT),
		"Upgrade assigned to the wrong slot should report slot validation error")


func test_validate_duplicate_upgrade_per_ship_reports_error_expected() -> void:
	var validator: Variant = _create_test_validator("ship-test", [
		"OFFICER",
		"OFFICER",
	])
	validator.add_upgrade_override("officer_copy", _create_upgrade_data("officer_copy",
		"OFFICER"))

	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "ship-test", "general_dodonna")
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "dup-1", "officer_copy", "OFFICER", 0)
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "dup-2", "officer_copy", "OFFICER", 1)
	_set_valid_objectives(roster)

	var result: FleetValidationResult = validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_UPGRADE_DUPLICATE_PER_SHIP),
		"Assigning the same upgrade twice on one ship should report duplicate error")


func test_validate_multiple_titles_reports_limit_error_expected() -> void:
	var validator: Variant = _create_test_validator("ship-test", [
		"OFFICER",
		"TITLE",
		"TITLE",
	])
	validator.add_upgrade_override("title_one", _create_upgrade_data("title_one", "TITLE"))
	validator.add_upgrade_override("title_two", _create_upgrade_data("title_two", "TITLE"))

	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "ship-test", "general_dodonna")
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "title-1", "title_one", "TITLE", 0)
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "title-2", "title_two", "TITLE", 1)
	_set_valid_objectives(roster)

	var result: FleetValidationResult = validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_UPGRADE_TITLE_LIMIT),
		"More than one TITLE upgrade on one ship should report title-limit error")


func test_validate_multiple_modifications_reports_limit_error_expected() -> void:
	var validator: Variant = _create_test_validator("ship-test", [
		"OFFICER",
		"TURBOLASERS",
		"ION_CANNONS",
	])
	validator.add_upgrade_override("mod_a",
		_create_upgrade_data("mod_a", "TURBOLASERS", true))
	validator.add_upgrade_override("mod_b",
		_create_upgrade_data("mod_b", "ION_CANNONS", true))

	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "ship-test", "general_dodonna")
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "mod-1", "mod_a", "TURBOLASERS", 0)
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "mod-2", "mod_b", "ION_CANNONS", 0)
	_set_valid_objectives(roster)

	var result: FleetValidationResult = validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_UPGRADE_MODIFICATION_LIMIT),
		"More than one Modification upgrade on one ship should report modification-limit error")


func test_validate_ship_data_restriction_reports_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "cr90_corvette_a", "general_dodonna")
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "title-1", "redemption", "TITLE", 0)
	_set_valid_objectives(roster)

	var result: FleetValidationResult = _validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_UPGRADE_RESTRICTION),
		"Title restricted to another ship should report upgrade-restriction error")


func test_validate_ship_class_restriction_reports_error_expected() -> void:
	var validator: Variant = _create_test_validator("ship-test", ["OFFICER", "TITLE"])
	validator.add_ship_class_override("ship-test", "cr90_corvette")
	var title: UpgradeData = _create_upgrade_data("nebulon_title", "TITLE")
	title.ship_class_restriction = ["nebulon_b_frigate"]
	validator.add_upgrade_override("nebulon_title", title)
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "ship-test", "general_dodonna")
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "title-1", "nebulon_title", "TITLE", 0)
	_set_valid_objectives(roster)

	var result: FleetValidationResult = validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_UPGRADE_RESTRICTION),
		"Upgrade with unmatched ship-class restriction should report restriction error")


func test_validate_size_restriction_reports_error_expected() -> void:
	var validator: Variant = _create_test_validator("ship-test", [
		"OFFICER",
		"OFFICER",
	])
	validator.add_upgrade_override("size_locked",
		_create_upgrade_data("size_locked", "OFFICER", false,
			[Constants.ShipSize.LARGE]))

	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_commander(roster, "ship-1", "ship-test", "general_dodonna")
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "size-1", "size_locked", "OFFICER", 1)
	_set_valid_objectives(roster)

	var result: FleetValidationResult = validator.validate(roster)

	assert_true(_has_rule_error(result, FleetValidator.RULE_UPGRADE_RESTRICTION),
		"Upgrade with unmatched size restriction should report restriction error")


func _create_roster(faction: String, point_limit: int) -> FleetRoster:
	var roster: FleetRoster = FleetRoster.create("fleet-1", "Validation Fleet", faction)
	roster.point_format = {"id": "CUSTOM", "limit": point_limit}
	roster.map = FleetBuilderOptions.default_map_for_point_format(roster.point_format)
	return roster


func _set_valid_objectives(roster: FleetRoster) -> void:
	var objectives: FleetObjectiveSelection = FleetObjectiveSelection.new()
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_DEFENSE, "obj_def_fire_lanes")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_NAVIGATION, "obj_nav_intel_sweep")
	roster.set_objectives(objectives)


func _add_ship_with_commander(roster: FleetRoster, ship_id: String,
		ship_key: String, commander_key: String) -> void:
	var ship_entry: FleetShipEntry = _create_ship(ship_id, ship_key)
	_add_upgrade_to_ship(ship_entry, "%s-cmd" % ship_id, commander_key, "COMMANDER")
	roster.add_ship(ship_entry)


func _add_ship_with_upgrade(roster: FleetRoster, ship_id: String,
		ship_key: String, upgrade_key: String) -> void:
	var ship_entry: FleetShipEntry = _create_ship(ship_id, ship_key)
	_add_upgrade_to_ship(ship_entry, "%s-upg" % ship_id, upgrade_key, "OFFICER")
	roster.add_ship(ship_entry)


func _add_upgrade_to_ship(ship_entry: FleetShipEntry,
		upgrade_id: String, upgrade_key: String, slot: String,
		slot_index: int = 0) -> void:
	var assignment: FleetUpgradeAssignment = FleetUpgradeAssignment.new()
	assignment.entry_id = upgrade_id
	assignment.data_key = upgrade_key
	assignment.slot = slot
	assignment.slot_index = slot_index
	ship_entry.add_upgrade(assignment)


func _create_test_validator(ship_key: String,
		slots: Array[String]) -> Variant:
	var validator: Variant = FleetValidatorDoubleScript.new()
	validator.add_ship_override(ship_key, _create_ship_data(slots))
	return validator


func _create_ship_data(slots: Array[String]) -> ShipData:
	var ship_data: ShipData = ShipData.new()
	ship_data.ship_name = "Test Ship"
	ship_data.faction = Constants.Faction.REBEL_ALLIANCE
	ship_data.ship_size = Constants.ShipSize.SMALL
	ship_data.point_cost = 60
	ship_data.upgrade_slots.assign(slots)
	return ship_data


func _create_upgrade_data(data_key: String, upgrade_type: String,
		is_modification: bool = false,
		size_restriction: Array = []) -> UpgradeData:
	var upgrade_data: UpgradeData = UpgradeData.new()
	upgrade_data.data_key = data_key
	upgrade_data.upgrade_name = data_key
	upgrade_data.upgrade_type = upgrade_type
	upgrade_data.is_modification = is_modification
	upgrade_data.size_restriction = size_restriction.duplicate()
	return upgrade_data


func _create_squadron_data(squadron_name: String, point_cost: int,
		is_unique: bool = false, unique_group: String = "",
		has_defense_token: bool = false) -> SquadronData:
	var squadron_data: SquadronData = SquadronData.new()
	squadron_data.squadron_name = squadron_name
	squadron_data.faction = Constants.Faction.REBEL_ALLIANCE
	squadron_data.point_cost = point_cost
	squadron_data.is_unique = is_unique
	squadron_data.unique_group = unique_group
	if has_defense_token:
		squadron_data.defense_tokens = ["BRACE"]
	return squadron_data


func _create_ship(entry_id: String, data_key: String) -> FleetShipEntry:
	var ship_entry: FleetShipEntry = FleetShipEntry.new()
	ship_entry.entry_id = entry_id
	ship_entry.data_key = data_key
	return ship_entry


func _create_squadron(entry_id: String, data_key: String) -> FleetSquadronEntry:
	var squadron_entry: FleetSquadronEntry = FleetSquadronEntry.new()
	squadron_entry.entry_id = entry_id
	squadron_entry.data_key = data_key
	return squadron_entry


func _has_rule_error(result: FleetValidationResult, rule_id: String) -> bool:
	for issue: Dictionary in result.errors:
		if str(issue.get("rule_id", "")) == rule_id:
			return true
	return false
