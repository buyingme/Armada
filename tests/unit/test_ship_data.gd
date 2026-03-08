## Test: ShipData
##
## Unit tests for ShipData resource — defaults, property access, and data integrity.
extends GutTest


# --- Default Values ---

func test_default_ship_name_is_empty() -> void:
	var ship := ShipData.new()
	assert_eq(ship.ship_name, "", "Default ship name should be empty")


func test_default_faction_is_rebel() -> void:
	var ship := ShipData.new()
	assert_eq(ship.faction, Constants.Faction.REBEL_ALLIANCE, "Default faction should be REBEL_ALLIANCE")


func test_default_ship_size_is_small() -> void:
	var ship := ShipData.new()
	assert_eq(ship.ship_size, Constants.ShipSize.SMALL, "Default ship size should be SMALL")


func test_default_hull_is_zero() -> void:
	var ship := ShipData.new()
	assert_eq(ship.hull, 0, "Default hull should be 0")


func test_default_point_cost_is_zero() -> void:
	var ship := ShipData.new()
	assert_eq(ship.point_cost, 0, "Default point cost should be 0")


func test_default_shields_is_empty() -> void:
	var ship := ShipData.new()
	assert_eq(ship.shields.size(), 0, "Default shields dict should be empty")


func test_default_defense_tokens_is_empty() -> void:
	var ship := ShipData.new()
	assert_eq(ship.defense_tokens.size(), 0, "Default defense tokens should be empty")


func test_default_upgrade_slots_is_empty() -> void:
	var ship := ShipData.new()
	assert_eq(ship.upgrade_slots.size(), 0, "Default upgrade slots should be empty")


# --- TestFixtures Integration ---

func test_fixture_small_ship_has_valid_name() -> void:
	var ship: ShipData = TestFixtures.create_test_small_ship()
	assert_ne(ship.ship_name, "", "Test small ship should have a name")


func test_fixture_small_ship_has_four_hull_zones() -> void:
	var ship: ShipData = TestFixtures.create_test_small_ship()
	assert_eq(ship.shields.size(), 4, "Small ship should have shields for all 4 hull zones")
	assert_has(ship.shields, Constants.HullZone.FRONT, "Should have FRONT shields")
	assert_has(ship.shields, Constants.HullZone.LEFT, "Should have LEFT shields")
	assert_has(ship.shields, Constants.HullZone.RIGHT, "Should have RIGHT shields")
	assert_has(ship.shields, Constants.HullZone.REAR, "Should have REAR shields")


func test_fixture_small_ship_has_battery_armament() -> void:
	var ship: ShipData = TestFixtures.create_test_small_ship()
	assert_eq(ship.battery_armament.size(), 4, "Should have battery armament for all 4 hull zones")


func test_fixture_small_ship_has_defense_tokens() -> void:
	var ship: ShipData = TestFixtures.create_test_small_ship()
	assert_true(ship.defense_tokens.size() > 0, "Small ship should have at least one defense token")


func test_fixture_large_ship_is_imperial() -> void:
	var ship: ShipData = TestFixtures.create_test_large_ship()
	assert_eq(ship.faction, Constants.Faction.GALACTIC_EMPIRE, "Test large ship should be Imperial")


func test_fixture_large_ship_has_higher_hull() -> void:
	var small: ShipData = TestFixtures.create_test_small_ship()
	var large: ShipData = TestFixtures.create_test_large_ship()
	assert_true(large.hull > small.hull, "Large ship should have more hull than small ship")


func test_fixture_large_ship_has_higher_command() -> void:
	var small: ShipData = TestFixtures.create_test_small_ship()
	var large: ShipData = TestFixtures.create_test_large_ship()
	assert_true(large.command_value > small.command_value, "Large ship should have higher command value")


# --- Data Integrity ---

func test_ship_shields_are_non_negative() -> void:
	var ship: ShipData = TestFixtures.create_test_small_ship()
	for zone: Constants.HullZone in ship.shields:
		var shield_value: int = ship.shields[zone]
		assert_true(shield_value >= 0, "Shield value for zone %s should be non-negative" % zone)


func test_ship_point_cost_is_positive() -> void:
	var ship: ShipData = TestFixtures.create_test_small_ship()
	assert_true(ship.point_cost > 0, "Ship point cost should be positive")


func test_ship_hull_is_positive() -> void:
	var ship: ShipData = TestFixtures.create_test_small_ship()
	assert_true(ship.hull > 0, "Ship hull should be positive")


# --- from_dict ---

func test_from_dict_parses_ship_name() -> void:
	var ship: ShipData = ShipData.from_dict({"ship_name": "CR90 Corvette A"})
	assert_eq(ship.ship_name, "CR90 Corvette A",
		"from_dict should parse ship_name")


func test_from_dict_parses_ship_size_small() -> void:
	var ship: ShipData = ShipData.from_dict({"ship_size": "SMALL"})
	assert_eq(ship.ship_size, Constants.ShipSize.SMALL,
		"from_dict should parse SMALL")


func test_from_dict_parses_ship_size_medium() -> void:
	var ship: ShipData = ShipData.from_dict({"ship_size": "MEDIUM"})
	assert_eq(ship.ship_size, Constants.ShipSize.MEDIUM,
		"from_dict should parse MEDIUM")


func test_from_dict_parses_ship_size_large() -> void:
	var ship: ShipData = ShipData.from_dict({"ship_size": "LARGE"})
	assert_eq(ship.ship_size, Constants.ShipSize.LARGE,
		"from_dict should parse LARGE")


func test_from_dict_parses_rebel_faction() -> void:
	var ship: ShipData = ShipData.from_dict({"faction": "REBEL_ALLIANCE"})
	assert_eq(ship.faction, Constants.Faction.REBEL_ALLIANCE,
		"from_dict should parse REBEL_ALLIANCE")


func test_from_dict_parses_imperial_faction() -> void:
	var ship: ShipData = ShipData.from_dict({"faction": "GALACTIC_EMPIRE"})
	assert_eq(ship.faction, Constants.Faction.GALACTIC_EMPIRE,
		"from_dict should parse GALACTIC_EMPIRE")


func test_from_dict_parses_point_cost() -> void:
	var ship: ShipData = ShipData.from_dict({"point_cost": 57})
	assert_eq(ship.point_cost, 57,
		"from_dict should parse point_cost")


func test_from_dict_unknown_size_defaults_to_small_and_errors() -> void:
	var ship: ShipData = ShipData.from_dict({"ship_size": "BOGUS"})
	assert_eq(ship.ship_size, Constants.ShipSize.SMALL,
		"Unknown ship_size should default to SMALL")
	assert_push_error(1,
		"Should log a push_error for unknown ship_size")
