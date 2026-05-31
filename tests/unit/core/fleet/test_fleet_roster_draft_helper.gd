## Test: FleetRosterDraftHelper
##
## Unit tests for UI-facing fleet roster draft mutations.
extends GutTest


func test_create_default_roster_core_set_180_expected() -> void:
	var roster: FleetRoster = FleetRosterDraftHelper.create_default_roster()

	assert_eq(roster.name, "New Fleet", "Default draft should have a display name")
	assert_eq(roster.faction, "REBEL_ALLIANCE", "Default draft should be Rebel")
	assert_eq(int(roster.point_format.get("limit", 0)), 180,
		"Default draft should use the Core Set 180 limit")
	assert_eq(roster.map.get("grid", ""), FleetBuilderOptions.MAP_GRID_3X3,
		"Default Core Set draft should choose a 3x3 map")


func test_add_ship_and_squadron_updates_roster_expected() -> void:
	var roster: FleetRoster = FleetRosterDraftHelper.create_default_roster()

	var ship_added: bool = FleetRosterDraftHelper.add_ship(
			roster, "cr90_corvette_a", "ship-1")
	var squadron_added: bool = FleetRosterDraftHelper.add_squadron(
			roster, "x_wing_squadron", "squad-1")

	assert_true(ship_added, "Draft helper should add valid ships")
	assert_true(squadron_added, "Draft helper should add valid squadrons")
	assert_eq(roster.ships.size(), 1, "Roster should contain one ship")
	assert_eq(roster.squadrons.size(), 1, "Roster should contain one squadron")


func test_add_upgrade_assigns_first_matching_slot_expected() -> void:
	var roster: FleetRoster = FleetRosterDraftHelper.create_default_roster()
	FleetRosterDraftHelper.add_ship(roster, "cr90_corvette_a", "ship-1")

	var added: bool = FleetRosterDraftHelper.add_upgrade(
			roster, "ship-1", "general_dodonna", "upgrade-1")

	assert_true(added, "Draft helper should assign a commander to an officer slot")
	assert_eq(roster.get_ship("ship-1").upgrades[0].slot, "OFFICER",
		"Commander should be stored against the ship's officer slot")


func test_set_objective_uses_catalog_category_expected() -> void:
	var roster: FleetRoster = FleetRosterDraftHelper.create_default_roster()

	var updated: bool = FleetRosterDraftHelper.set_objective(roster, "obj_ass_most_wanted")

	assert_true(updated, "Draft helper should set a loadable objective")
	assert_eq(roster.objectives.assault_objective_key, "obj_ass_most_wanted",
		"Most Wanted should populate the Assault objective slot")


func test_set_map_uses_filename_size_prefix_expected() -> void:
	var roster: FleetRoster = FleetRosterDraftHelper.create_default_roster()

	var updated: bool = FleetRosterDraftHelper.set_map(
			roster, "map_3x6_distant-planet_v4.jpg")

	assert_true(updated, "Draft helper should accept known map filenames")
	assert_eq(roster.map.get("grid", ""), FleetBuilderOptions.MAP_GRID_3X6,
		"Map payload should derive 3x6 grid from filename")
