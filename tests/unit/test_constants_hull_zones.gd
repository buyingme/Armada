## Test: Constants — hull zone adjacency and helpers.
##
## Unit tests for Constants.get_adjacent_hull_zones(),
## Constants.hull_zone_to_string(), Constants.string_to_hull_zone().
## Requirements: AE-DEF-012.
extends GutTest


# =========================================================================
# get_adjacent_hull_zones
# =========================================================================

func test_front_adjacent_to_left_and_right() -> void:
	var adj: Array = Constants.get_adjacent_hull_zones(
			Constants.HullZone.FRONT)
	assert_true(Constants.HullZone.LEFT in adj,
			"FRONT should be adjacent to LEFT")
	assert_true(Constants.HullZone.RIGHT in adj,
			"FRONT should be adjacent to RIGHT")
	assert_eq(adj.size(), 2, "FRONT should have exactly 2 adjacent zones")


func test_rear_adjacent_to_left_and_right() -> void:
	var adj: Array = Constants.get_adjacent_hull_zones(
			Constants.HullZone.REAR)
	assert_true(Constants.HullZone.LEFT in adj,
			"REAR should be adjacent to LEFT")
	assert_true(Constants.HullZone.RIGHT in adj,
			"REAR should be adjacent to RIGHT")


func test_left_adjacent_to_front_and_rear() -> void:
	var adj: Array = Constants.get_adjacent_hull_zones(
			Constants.HullZone.LEFT)
	assert_true(Constants.HullZone.FRONT in adj,
			"LEFT should be adjacent to FRONT")
	assert_true(Constants.HullZone.REAR in adj,
			"LEFT should be adjacent to REAR")


func test_right_adjacent_to_front_and_rear() -> void:
	var adj: Array = Constants.get_adjacent_hull_zones(
			Constants.HullZone.RIGHT)
	assert_true(Constants.HullZone.FRONT in adj,
			"RIGHT should be adjacent to FRONT")
	assert_true(Constants.HullZone.REAR in adj,
			"RIGHT should be adjacent to REAR")


func test_front_not_adjacent_to_rear() -> void:
	var adj: Array = Constants.get_adjacent_hull_zones(
			Constants.HullZone.FRONT)
	assert_false(Constants.HullZone.REAR in adj,
			"FRONT should NOT be adjacent to REAR")


func test_left_not_adjacent_to_right() -> void:
	var adj: Array = Constants.get_adjacent_hull_zones(
			Constants.HullZone.LEFT)
	assert_false(Constants.HullZone.RIGHT in adj,
			"LEFT should NOT be adjacent to RIGHT")


# =========================================================================
# hull_zone_to_string
# =========================================================================

func test_hull_zone_to_string_front() -> void:
	assert_eq(Constants.hull_zone_to_string(Constants.HullZone.FRONT),
			"FRONT", "FRONT should map to 'FRONT'")


func test_hull_zone_to_string_left() -> void:
	assert_eq(Constants.hull_zone_to_string(Constants.HullZone.LEFT),
			"LEFT", "LEFT should map to 'LEFT'")


func test_hull_zone_to_string_right() -> void:
	assert_eq(Constants.hull_zone_to_string(Constants.HullZone.RIGHT),
			"RIGHT", "RIGHT should map to 'RIGHT'")


func test_hull_zone_to_string_rear() -> void:
	assert_eq(Constants.hull_zone_to_string(Constants.HullZone.REAR),
			"REAR", "REAR should map to 'REAR'")


# =========================================================================
# string_to_hull_zone
# =========================================================================

func test_string_to_hull_zone_front() -> void:
	assert_eq(Constants.string_to_hull_zone("FRONT"),
			Constants.HullZone.FRONT,
			"'FRONT' should map to HullZone.FRONT")


func test_string_to_hull_zone_lowercase() -> void:
	assert_eq(Constants.string_to_hull_zone("left"),
			Constants.HullZone.LEFT,
			"'left' (lowercase) should map to HullZone.LEFT")


func test_string_to_hull_zone_mixed_case() -> void:
	assert_eq(Constants.string_to_hull_zone("Right"),
			Constants.HullZone.RIGHT,
			"'Right' (mixed case) should map to HullZone.RIGHT")


func test_string_to_hull_zone_rear() -> void:
	assert_eq(Constants.string_to_hull_zone("REAR"),
			Constants.HullZone.REAR,
			"'REAR' should map to HullZone.REAR")
