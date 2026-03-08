## Tests for SquadronBase
##
## Covers: radius default, closest_point_to, overlaps_ship, overlaps_squadron,
##   is_in_range_of, distance_to_point, distance_to_squadron.
##
## Rules Reference: "Squadrons", p.11; AT-043; SM-001, SM-003
extends GutTest


func _make_squadron(pos: Vector2) -> SquadronBase:
	return SquadronBase.new(pos)


func _make_squadron_custom_radius(pos: Vector2, r: float) -> SquadronBase:
	return SquadronBase.new(pos, r)


# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

func test_default_radius_matches_game_scale() -> void:
	var sq: SquadronBase = _make_squadron(Vector2.ZERO)
	var expected: float = GameScale.squadron_base_diameter_px * 0.5
	assert_almost_eq(sq.radius_px, expected, 0.1,
			"Default radius should be half of GameScale squadron diameter")


func test_custom_radius_is_set() -> void:
	var sq: SquadronBase = _make_squadron_custom_radius(Vector2.ZERO, 50.0)
	assert_almost_eq(sq.radius_px, 50.0, 0.01, "Custom radius should be stored")


func test_position_is_set() -> void:
	var pos: Vector2 = Vector2(100.0, -200.0)
	var sq: SquadronBase = _make_squadron(pos)
	assert_almost_eq(sq.position.x, 100.0, 0.01, "Position X should be stored")
	assert_almost_eq(sq.position.y, -200.0, 0.01, "Position Y should be stored")


# ---------------------------------------------------------------------------
# closest_point_to
# ---------------------------------------------------------------------------

func test_closest_point_to_outside_is_on_perimeter() -> void:
	var sq: SquadronBase = _make_squadron_custom_radius(Vector2.ZERO, 50.0)
	var target: Vector2 = Vector2(200.0, 0.0)
	var closest: Vector2 = sq.closest_point_to(target)
	assert_almost_eq(closest.distance_to(sq.position), 50.0, 0.01,
			"Closest point should be on the perimeter (radius away from centre)")
	assert_almost_eq(closest.x, 50.0, 0.01,
			"Closest point should be on the right side")


func test_closest_point_to_direction_correct() -> void:
	var sq: SquadronBase = _make_squadron_custom_radius(Vector2.ZERO, 40.0)
	var target: Vector2 = Vector2(0.0, -100.0)
	var closest: Vector2 = sq.closest_point_to(target)
	assert_almost_eq(closest.x, 0.0, 0.01, "Closest point X should be 0")
	assert_almost_eq(closest.y, -40.0, 0.01, "Closest point Y should be -radius")


# ---------------------------------------------------------------------------
# overlaps_ship (SM-001)
# ---------------------------------------------------------------------------

func test_overlaps_ship_when_squadron_inside_base() -> void:
	# Ship at origin, squadron at origin — definitely overlapping.
	var ship: ShipBase = ShipBase.new(
			Constants.ShipSize.SMALL, Transform2D.IDENTITY)
	var sq: SquadronBase = _make_squadron(Vector2.ZERO)
	var result: bool = sq.overlaps_ship(ship)
	assert_true(result, "Squadron at ship centre should overlap ship base")


func test_overlaps_ship_when_far_away_returns_false() -> void:
	var ship: ShipBase = ShipBase.new(
			Constants.ShipSize.SMALL, Transform2D.IDENTITY)
	# Move squadron far away
	var sq: SquadronBase = _make_squadron(Vector2(2000.0, 2000.0))
	var result: bool = sq.overlaps_ship(ship)
	assert_false(result, "Squadron far from ship should not overlap ship base")


# ---------------------------------------------------------------------------
# overlaps_squadron (SM-003)
# ---------------------------------------------------------------------------

func test_overlaps_squadron_touching_returns_true() -> void:
	var sq_a: SquadronBase = _make_squadron_custom_radius(Vector2(0.0, 0.0), 50.0)
	var sq_b: SquadronBase = _make_squadron_custom_radius(Vector2(100.0, 0.0), 50.0)
	# Edge-to-edge distance = 0
	var result: bool = sq_a.overlaps_squadron(sq_b)
	assert_true(result, "Touching squadrons should overlap")


func test_overlaps_squadron_separated_returns_false() -> void:
	var sq_a: SquadronBase = _make_squadron_custom_radius(Vector2(0.0, 0.0), 50.0)
	var sq_b: SquadronBase = _make_squadron_custom_radius(Vector2(200.0, 0.0), 50.0)
	var result: bool = sq_a.overlaps_squadron(sq_b)
	assert_false(result, "Squadrons 100 px apart edge-to-edge should not overlap")


# ---------------------------------------------------------------------------
# is_in_range_of (AT-043 — 360° arc)
# ---------------------------------------------------------------------------

func test_is_in_range_of_within_range_returns_true() -> void:
	var sq: SquadronBase = _make_squadron_custom_radius(Vector2.ZERO, 50.0)
	var result: bool = sq.is_in_range_of(Vector2(120.0, 0.0), 100.0)
	# distance edge-to-target = 120 - 50 = 70 ≤ 100
	assert_true(result, "Target within 100 px of squadron edge should be in range")


func test_is_in_range_of_out_of_range_returns_false() -> void:
	var sq: SquadronBase = _make_squadron_custom_radius(Vector2.ZERO, 50.0)
	var result: bool = sq.is_in_range_of(Vector2(200.0, 0.0), 100.0)
	# distance edge-to-target = 200 - 50 = 150 > 100
	assert_false(result, "Target beyond range should not be in range")


# ---------------------------------------------------------------------------
# distance_to_squadron
# ---------------------------------------------------------------------------

func test_distance_to_squadron_separated() -> void:
	var sq_a: SquadronBase = _make_squadron_custom_radius(Vector2(0.0, 0.0), 40.0)
	var sq_b: SquadronBase = _make_squadron_custom_radius(Vector2(200.0, 0.0), 40.0)
	var d: float = sq_a.distance_to_squadron(sq_b)
	assert_almost_eq(d, 120.0, 0.1,
			"Distance between separated squadrons should be 200 - 40 - 40 = 120")


func test_distance_to_squadron_overlapping_is_zero() -> void:
	var sq_a: SquadronBase = _make_squadron_custom_radius(Vector2(0.0, 0.0), 50.0)
	var sq_b: SquadronBase = _make_squadron_custom_radius(Vector2(50.0, 0.0), 50.0)
	var d: float = sq_a.distance_to_squadron(sq_b)
	assert_almost_eq(d, 0.0, 0.01, "Overlapping squadrons: distance should be 0")
