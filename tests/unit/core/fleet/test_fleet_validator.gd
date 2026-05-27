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


func test_validate_duplicate_unique_upgrades_reports_error_expected() -> void:
	var roster: FleetRoster = _create_roster("REBEL_ALLIANCE", 180)
	_add_ship_with_upgrade(roster, "ship-1", "cr90_corvette_a", "leia_organa")
	_add_ship_with_upgrade(roster, "ship-2", "nebulon_b_support_refit", "leia_organa")
	_add_upgrade_to_ship(roster.get_ship("ship-1"), "upg-cmd", "general_dodonna", "OFFICER")
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
	_add_upgrade_to_ship(ship_entry, "%s-cmd" % ship_id, commander_key, "OFFICER")
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
