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


# --- token_label_offsets ---

func test_default_token_label_offsets_is_empty() -> void:
	var ship := ShipData.new()
	assert_eq(ship.token_label_offsets.size(), 0,
		"Default token_label_offsets should be empty")


func test_from_dict_parses_token_label_offsets() -> void:
	var data: Dictionary = {
		"token_label_offsets": {
			"shield_front": [51, -9],
			"hull": [21, 34],
		}
	}
	var ship: ShipData = ShipData.from_dict(data)
	assert_eq(ship.token_label_offsets.size(), 2,
		"Should parse 2 offset entries")


func test_from_dict_offsets_are_vector2() -> void:
	var data: Dictionary = {
		"token_label_offsets": {
			"shield_front": [51, -9],
		}
	}
	var ship: ShipData = ShipData.from_dict(data)
	var offset: Vector2 = ship.token_label_offsets["shield_front"]
	assert_eq(offset, Vector2(51, -9),
		"shield_front offset should be Vector2(51, -9)")


func test_from_dict_offsets_all_six_keys() -> void:
	var data: Dictionary = {
		"token_label_offsets": {
			"shield_front": [51, -9],
			"shield_left": [-9, 85],
			"shield_right": [112, 85],
			"shield_rear": [51, 180],
			"hull": [21, 34],
			"speed": [83, 34],
		}
	}
	var ship: ShipData = ShipData.from_dict(data)
	assert_eq(ship.token_label_offsets.size(), 6,
		"Should parse all 6 offset keys")
	assert_true(ship.token_label_offsets.has("shield_front"),
		"Should have shield_front key")
	assert_true(ship.token_label_offsets.has("hull"),
		"Should have hull key")
	assert_true(ship.token_label_offsets.has("speed"),
		"Should have speed key")


func test_from_dict_missing_offsets_gives_empty() -> void:
	var ship: ShipData = ShipData.from_dict({"ship_name": "No Offsets"})
	assert_eq(ship.token_label_offsets.size(), 0,
		"Missing token_label_offsets should result in empty dict")


func test_from_dict_offset_with_short_array_is_skipped() -> void:
	var data: Dictionary = {
		"token_label_offsets": {
			"shield_front": [51],
		}
	}
	var ship: ShipData = ShipData.from_dict(data)
	assert_eq(ship.token_label_offsets.size(), 0,
		"Array with fewer than 2 elements should be skipped")


# --- firing_arc_boundaries ---

func test_default_firing_arc_boundaries_is_empty() -> void:
	var ship := ShipData.new()
	assert_eq(ship.firing_arc_boundaries.size(), 0,
		"Default firing_arc_boundaries should be empty")


func test_from_dict_parses_firing_arc_boundaries() -> void:
	var data: Dictionary = {
		"firing_arc_boundaries": {
			"_comment": "ignored",
			"inner_point_front_left": [71, 124],
			"outer_point_front_left": [25, 73],
		}
	}
	var ship: ShipData = ShipData.from_dict(data)
	assert_eq(ship.firing_arc_boundaries.size(), 2,
		"Should parse 2 boundary entries (skipping _comment)")


func test_from_dict_firing_arc_boundaries_are_vector2() -> void:
	var data: Dictionary = {
		"firing_arc_boundaries": {
			"inner_point_front_left": [71, 124],
		}
	}
	var ship: ShipData = ShipData.from_dict(data)
	var pt: Vector2 = ship.firing_arc_boundaries["inner_point_front_left"]
	assert_eq(pt, Vector2(71, 124),
		"Boundary point should be Vector2(71, 124)")


func test_from_dict_firing_arc_boundaries_skip_comment() -> void:
	var data: Dictionary = {
		"firing_arc_boundaries": {
			"_comment": "skip me",
			"inner_point_front_left": [71, 124],
		}
	}
	var ship: ShipData = ShipData.from_dict(data)
	assert_false(ship.firing_arc_boundaries.has("_comment"),
		"Keys starting with _ should be skipped")


func test_from_dict_missing_firing_arc_boundaries_gives_empty() -> void:
	var ship: ShipData = ShipData.from_dict({"ship_name": "No Arcs"})
	assert_eq(ship.firing_arc_boundaries.size(), 0,
		"Missing firing_arc_boundaries should result in empty dict")


func test_from_dict_firing_arc_boundaries_all_eight_keys() -> void:
	var data: Dictionary = {
		"firing_arc_boundaries": {
			"inner_point_front_left":  [71, 124],
			"outer_point_front_left":  [25, 73],
			"inner_point_front_right": [71, 124],
			"outer_point_front_right": [117, 73],
			"inner_point_rear_left":   [71, 124],
			"outer_point_rear_left":   [25, 175],
			"inner_point_rear_right":  [71, 124],
			"outer_point_rear_right":  [117, 175],
		}
	}
	var ship: ShipData = ShipData.from_dict(data)
	assert_eq(ship.firing_arc_boundaries.size(), 8,
		"Should parse all 8 boundary keys")


# --- line_of_sight_origins ---

func test_default_line_of_sight_origins_is_empty() -> void:
	var ship := ShipData.new()
	assert_eq(ship.line_of_sight_origins.size(), 0,
		"Default line_of_sight_origins should be empty")


func test_from_dict_parses_line_of_sight_origins() -> void:
	var data: Dictionary = {
		"line_of_sight_origins": {
			"FRONT": [71, 62],
			"REAR":  [71, 186],
		}
	}
	var ship: ShipData = ShipData.from_dict(data)
	assert_eq(ship.line_of_sight_origins.size(), 2,
		"Should parse 2 LOS origin entries")


func test_from_dict_line_of_sight_origins_are_vector2() -> void:
	var data: Dictionary = {
		"line_of_sight_origins": {
			"FRONT": [71, 62],
		}
	}
	var ship: ShipData = ShipData.from_dict(data)
	var pt: Vector2 = ship.line_of_sight_origins["FRONT"]
	assert_eq(pt, Vector2(71, 62),
		"LOS origin should be Vector2(71, 62)")


func test_from_dict_line_of_sight_origins_skip_comment() -> void:
	var data: Dictionary = {
		"line_of_sight_origins": {
			"_comment": "skip me",
			"FRONT": [71, 62],
		}
	}
	var ship: ShipData = ShipData.from_dict(data)
	assert_false(ship.line_of_sight_origins.has("_comment"),
		"Keys starting with _ should be skipped")


func test_from_dict_missing_line_of_sight_origins_gives_empty() -> void:
	var ship: ShipData = ShipData.from_dict({"ship_name": "No LOS"})
	assert_eq(ship.line_of_sight_origins.size(), 0,
		"Missing line_of_sight_origins should result in empty dict")


# ---------------------------------------------------------------------------
# Range overlay fields  (RO-DATA-03)
# ---------------------------------------------------------------------------

func test_default_range_overlay_image_is_empty() -> void:
	var ship: ShipData = ShipData.new()
	assert_eq(ship.range_overlay_image, "",
		"Default range_overlay_image should be empty string")


func test_default_range_overlay_origin_is_zero() -> void:
	var ship: ShipData = ShipData.new()
	assert_eq(ship.range_overlay_origin_px, Vector2.ZERO,
		"Default range_overlay_origin_px should be Vector2.ZERO")


func test_from_dict_parses_range_overlay() -> void:
	var data: Dictionary = {
		"ship_name": "Test Ship",
		"range_overlay": {
			"image": "arcs_test_overlay.png",
			"origin_px": [400.5, 500.5],
		},
	}
	var ship: ShipData = ShipData.from_dict(data)
	assert_eq(ship.range_overlay_image, "arcs_test_overlay.png",
		"Should parse range_overlay image filename")
	assert_almost_eq(ship.range_overlay_origin_px.x, 400.5, 0.01,
		"Should parse overlay origin x")
	assert_almost_eq(ship.range_overlay_origin_px.y, 500.5, 0.01,
		"Should parse overlay origin y")


func test_from_dict_missing_range_overlay_gives_defaults() -> void:
	var ship: ShipData = ShipData.from_dict({"ship_name": "No Overlay"})
	assert_eq(ship.range_overlay_image, "",
		"Missing range_overlay should give empty image string")
	assert_eq(ship.range_overlay_origin_px, Vector2.ZERO,
		"Missing range_overlay should give zero origin")
