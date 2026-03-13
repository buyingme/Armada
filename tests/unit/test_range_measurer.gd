## Tests for RangeMeasurer
##
## Covers: ship-to-ship range, ship-to-squadron range, squadron-to-squadron range,
##   overlapping (zero distance), band classification convenience methods.
##
## Rules Reference: "Attack", step 1, p.1; AT-050, AT-051, AT-052
extends GutTest


## Helper: small ship at a given position, no rotation.
func _make_ship(pos: Vector2) -> ShipBase:
	return ShipBase.new(Constants.ShipSize.SMALL, Transform2D(0.0, pos))


## Helper: squadron base at the given position using the GameScale default radius.
func _make_squadron(pos: Vector2) -> SquadronBase:
	return SquadronBase.new(pos)


# ---------------------------------------------------------------------------
# Ship to Ship (AT-050)
# ---------------------------------------------------------------------------

func test_ship_to_ship_separated_is_positive() -> void:
	# Two ships separated by 500 px — range should be positive.
	var attacker: ShipBase = _make_ship(Vector2(0.0, 0.0))
	var defender: ShipBase = _make_ship(Vector2(0.0, 500.0))
	var d: float = RangeMeasurer.measure_ship_to_ship(
			attacker, Constants.HullZone.REAR,
			defender, Constants.HullZone.FRONT)
	assert_true(d > 0.0, "Separated ships should have positive range")


func test_ship_to_ship_overlapping_is_zero() -> void:
	# Two ships at the same position — hull zones overlap.
	var attacker: ShipBase = _make_ship(Vector2(0.0, 0.0))
	var defender: ShipBase = _make_ship(Vector2(0.0, 0.0))
	var d: float = RangeMeasurer.measure_ship_to_ship(
			attacker, Constants.HullZone.FRONT,
			defender, Constants.HullZone.FRONT)
	assert_almost_eq(d, 0.0, 0.01, "Overlapping zones should have zero range")


func test_ship_to_ship_distance_is_symmetric() -> void:
	var a: ShipBase = _make_ship(Vector2(0.0, 0.0))
	var b: ShipBase = _make_ship(Vector2(200.0, 0.0))
	var d_ab: float = RangeMeasurer.measure_ship_to_ship(
			a, Constants.HullZone.RIGHT, b, Constants.HullZone.LEFT)
	var d_ba: float = RangeMeasurer.measure_ship_to_ship(
			b, Constants.HullZone.LEFT, a, Constants.HullZone.RIGHT)
	assert_almost_eq(d_ab, d_ba, 0.5,
			"Range measurement should be symmetric")


# ---------------------------------------------------------------------------
# Ship to Squadron (AT-051)
# ---------------------------------------------------------------------------

func test_ship_to_squadron_distant_is_positive() -> void:
	var ship: ShipBase = _make_ship(Vector2(0.0, 0.0))
	var squadron_pos: Vector2 = Vector2(0.0, -500.0)
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var d: float = RangeMeasurer.measure_ship_to_squadron(
			ship, Constants.HullZone.FRONT, squadron_pos, radius)
	assert_true(d > 0.0, "Distant squadron should have positive range from ship")


func test_ship_to_squadron_touching_hull_zone_is_near_zero() -> void:
	var ship: ShipBase = _make_ship(Vector2(0.0, 0.0))
	# Squadron touching the FRONT hull zone edge.
	var half_len: float = GameScale.small_base_length_px * 0.5
	var third: float = half_len * 2.0 / 3.0
	# Front zone extends from -half_len to (-half_len + third).
	var front_edge_y: float = - half_len
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var squadron_pos: Vector2 = Vector2(0.0, front_edge_y - radius)
	var d: float = RangeMeasurer.measure_ship_to_squadron(
			ship, Constants.HullZone.FRONT, squadron_pos, radius)
	assert_almost_eq(d, 0.0, 1.0,
			"Squadron touching hull zone edge should have near-zero range")


# ---------------------------------------------------------------------------
# Squadron to Squadron (AT-052)
# ---------------------------------------------------------------------------

func test_squadron_to_squadron_separated() -> void:
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var d: float = RangeMeasurer.measure_squadron_to_squadron(
			Vector2(0.0, 0.0), radius,
			Vector2(300.0, 0.0), radius)
	var expected: float = 300.0 - 2.0 * radius
	assert_almost_eq(d, expected, 1.0, "Squadron-to-squadron distance should match")


func test_squadron_to_squadron_overlapping_is_zero() -> void:
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var d: float = RangeMeasurer.measure_squadron_to_squadron(
			Vector2(0.0, 0.0), radius,
			Vector2(radius, 0.0), radius)
	assert_almost_eq(d, 0.0, 0.01, "Overlapping squadrons should have zero range")


# ---------------------------------------------------------------------------
# Band classification
# ---------------------------------------------------------------------------

func test_get_ship_to_ship_band_close() -> void:
	# Close range max is ~292 px. Put both ships adjacent.
	var radius: float = GameScale.small_base_length_px * 0.5
	var a: ShipBase = _make_ship(Vector2(0.0, 0.0))
	var b: ShipBase = _make_ship(Vector2(0.0, - (2.0 * radius + 100.0)))
	var band: String = RangeMeasurer.get_ship_to_ship_band(
			a, Constants.HullZone.FRONT, b, Constants.HullZone.REAR)
	assert_eq(band, "close", "Ships within 292 px should be at close range")
