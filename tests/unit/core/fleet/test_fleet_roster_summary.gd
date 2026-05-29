## Test: FleetRosterSummary
##
## Unit tests for fleet-builder point summary calculations.
extends GutTest


func test_calculate_empty_roster_returns_limit_expected() -> void:
	var roster: FleetRoster = FleetRosterDraftHelper.create_default_roster()

	var summary: Dictionary = FleetRosterSummary.calculate(roster)

	assert_eq(summary.get(FleetRosterSummary.KEY_TOTAL_POINTS, -1), 0,
		"Empty roster should have zero total points")
	assert_eq(summary.get(FleetRosterSummary.KEY_POINT_LIMIT, 0), 180,
		"Default draft should use Core Set 180 limit")


func test_calculate_populated_roster_splits_categories_expected() -> void:
	var roster: FleetRoster = FleetRosterDraftHelper.create_default_roster()
	FleetRosterDraftHelper.add_ship(roster, "cr90_corvette_a", "ship-1")
	FleetRosterDraftHelper.add_squadron(roster, "x_wing_squadron", "squad-1")
	FleetRosterDraftHelper.add_upgrade(roster, "ship-1", "general_dodonna", "up-1")

	var summary: Dictionary = FleetRosterSummary.calculate(roster)

	assert_eq(summary.get(FleetRosterSummary.KEY_SHIP_POINTS, 0), 44,
		"CR90 Corvette A should contribute 44 ship points")
	assert_eq(summary.get(FleetRosterSummary.KEY_SQUADRON_POINTS, 0), 13,
		"X-wing Squadron should contribute 13 squadron points")
	assert_eq(summary.get(FleetRosterSummary.KEY_UPGRADE_POINTS, 0), 20,
		"General Dodonna should contribute 20 upgrade points")
	assert_eq(summary.get(FleetRosterSummary.KEY_TOTAL_POINTS, 0), 77,
		"Total should include ship, squadron, and upgrade points")