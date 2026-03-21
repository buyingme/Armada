## Test: RangeOverlayCalculator
##
## Unit tests for the range overlay geometry calculator.
## Verifies arc boundary lines, band polygon generation, and helper methods.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a simple square base polygon centred at origin, 100×100 px.
func _make_square_base() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-50.0, -50.0),  # front-left
		Vector2( 50.0, -50.0),  # front-right
		Vector2( 50.0,  50.0),  # rear-right
		Vector2(-50.0,  50.0),  # rear-left
	])


## Creates a set of symmetric boundary points around a 100×100 base.
## Inner points at the base corners, outer points pushed outward.
func _make_symmetric_boundaries() -> Dictionary:
	return {
		"inner_point_front_left":  Vector2(-50.0, -50.0),
		"outer_point_front_left":  Vector2(-80.0, -80.0),
		"inner_point_front_right": Vector2( 50.0, -50.0),
		"outer_point_front_right": Vector2( 80.0, -80.0),
		"inner_point_rear_left":   Vector2(-50.0,  50.0),
		"outer_point_rear_left":   Vector2(-80.0,  80.0),
		"inner_point_rear_right":  Vector2( 50.0,  50.0),
		"outer_point_rear_right":  Vector2( 80.0,  80.0),
	}


## Creates boundary points where all inner points coincide (like CR90).
func _make_single_inner_boundaries() -> Dictionary:
	return {
		"inner_point_front_left":  Vector2(0.0, 0.0),
		"outer_point_front_left":  Vector2(-50.0, -50.0),
		"inner_point_front_right": Vector2(0.0, 0.0),
		"outer_point_front_right": Vector2( 50.0, -50.0),
		"inner_point_rear_left":   Vector2(0.0, 0.0),
		"outer_point_rear_left":   Vector2(-50.0,  50.0),
		"inner_point_rear_right":  Vector2(0.0, 0.0),
		"outer_point_rear_right":  Vector2( 50.0,  50.0),
	}


# ---------------------------------------------------------------------------
# _extend_ray
# ---------------------------------------------------------------------------

func test_extend_ray_horizontal_right() -> void:
	var result: Vector2 = RangeOverlayCalculator._extend_ray(
			Vector2.ZERO, Vector2(10.0, 0.0), 100.0)
	assert_almost_eq(result.x, 110.0, 0.01,
		"Should extend 100px beyond outer point along +X")
	assert_almost_eq(result.y, 0.0, 0.01,
		"Y should stay at 0 for horizontal ray")


func test_extend_ray_diagonal() -> void:
	var inner := Vector2.ZERO
	var outer := Vector2(10.0, 10.0)
	var result: Vector2 = RangeOverlayCalculator._extend_ray(inner, outer, 100.0)
	var dir: Vector2 = (outer - inner).normalized()
	var expected: Vector2 = outer + dir * 100.0
	assert_almost_eq(result.x, expected.x, 0.01,
		"X should match expected diagonal extension")
	assert_almost_eq(result.y, expected.y, 0.01,
		"Y should match expected diagonal extension")


func test_extend_ray_zero_distance() -> void:
	var result: Vector2 = RangeOverlayCalculator._extend_ray(
			Vector2.ZERO, Vector2(5.0, 0.0), 0.0)
	assert_almost_eq(result.x, 5.0, 0.01,
		"Zero extension should return the outer point")


# ---------------------------------------------------------------------------
# _ensure_cw
# ---------------------------------------------------------------------------

func test_ensure_cw_already_clockwise() -> void:
	# CW per Godot convention (Y-up math): traces right→up→left→down.
	var poly := PackedVector2Array([
		Vector2(0, 10), Vector2(10, 10),
		Vector2(10, 0), Vector2(0, 0),
	])
	assert_true(Geometry2D.is_polygon_clockwise(poly),
		"Precondition: polygon should already be CW per Godot")
	var result: PackedVector2Array = RangeOverlayCalculator._ensure_cw(poly)
	assert_eq(result[0], poly[0],
		"CW polygon should be returned unchanged")


func test_ensure_cw_reverses_ccw() -> void:
	# CCW per Godot convention: traces right→down→left→up in Y-up math.
	var poly := PackedVector2Array([
		Vector2(0, 0), Vector2(10, 0),
		Vector2(10, 10), Vector2(0, 10),
	])
	assert_false(Geometry2D.is_polygon_clockwise(poly),
		"Precondition: polygon should be CCW per Godot")
	var result: PackedVector2Array = RangeOverlayCalculator._ensure_cw(poly)
	assert_true(Geometry2D.is_polygon_clockwise(result),
		"Result should be CW after reversal")


func test_ensure_cw_degenerate_returns_unchanged() -> void:
	var poly := PackedVector2Array([Vector2.ZERO, Vector2(1, 0)])
	var result: PackedVector2Array = RangeOverlayCalculator._ensure_cw(poly)
	assert_eq(result.size(), 2,
		"Degenerate polygon (< 3 verts) should be returned unchanged")


# ---------------------------------------------------------------------------
# _build_sector
# ---------------------------------------------------------------------------

func test_build_sector_triangle_when_inner_points_coincide() -> void:
	var sector: PackedVector2Array = RangeOverlayCalculator._build_sector(
			Vector2.ZERO, Vector2(-50, -50),
			Vector2.ZERO, Vector2( 50, -50))
	assert_eq(sector.size(), 3,
		"Coincident inner points should produce a triangle")
	assert_true(Geometry2D.is_polygon_clockwise(sector),
		"Sector should be CW")


func test_build_sector_quad_when_inner_points_differ() -> void:
	var sector: PackedVector2Array = RangeOverlayCalculator._build_sector(
			Vector2(-5, 0), Vector2(-50, -50),
			Vector2( 5, 0), Vector2( 50, -50))
	assert_eq(sector.size(), 4,
		"Distinct inner points should produce a quad")
	assert_true(Geometry2D.is_polygon_clockwise(sector),
		"Sector should be CW")


# ---------------------------------------------------------------------------
# _ring_in_sector
# ---------------------------------------------------------------------------

func test_ring_in_sector_returns_non_empty() -> void:
	# Inner: 50px square; Outer: 200px square (simple offset).
	var inner := PackedVector2Array([
		Vector2(-50, -50), Vector2(50, -50),
		Vector2(50, 50), Vector2(-50, 50),
	])
	var outer := PackedVector2Array([
		Vector2(-200, -200), Vector2(200, -200),
		Vector2(200, 200), Vector2(-200, 200),
	])
	# Sector covering the "front" (negative Y) region.
	var sector := PackedVector2Array([
		Vector2(0, 0), Vector2(500, -500), Vector2(-500, -500),
	])
	sector = RangeOverlayCalculator._ensure_cw(sector)
	var result: Array = RangeOverlayCalculator._ring_in_sector(
			inner, outer, sector)
	assert_true(result.size() > 0,
		"Ring in sector should produce at least one polygon")


func test_ring_in_sector_empty_when_no_overlap() -> void:
	# Outer is entirely in positive-Y; sector covers negative-Y.
	var inner := PackedVector2Array([
		Vector2(-10, 100), Vector2(10, 100),
		Vector2(10, 120), Vector2(-10, 120),
	])
	var outer := PackedVector2Array([
		Vector2(-20, 90), Vector2(20, 90),
		Vector2(20, 130), Vector2(-20, 130),
	])
	var sector := PackedVector2Array([
		Vector2(0, 0), Vector2(-500, -500), Vector2(500, -500),
	])
	sector = RangeOverlayCalculator._ensure_cw(sector)
	var result: Array = RangeOverlayCalculator._ring_in_sector(
			inner, outer, sector)
	assert_eq(result.size(), 0,
		"No overlap with sector should return empty")


# ---------------------------------------------------------------------------
# Full compute()
# ---------------------------------------------------------------------------

func test_compute_symmetric_produces_four_zones() -> void:
	var calc := RangeOverlayCalculator.new()
	calc.compute(
		_make_square_base(),
		_make_symmetric_boundaries(),
		100.0, 200.0, 400.0)
	assert_eq(calc.band_polygons.size(), 4,
		"Should produce band polygons for all 4 hull zones")
	assert_true(calc.band_polygons.has(Constants.HullZone.FRONT),
		"Should have FRONT zone")
	assert_true(calc.band_polygons.has(Constants.HullZone.LEFT),
		"Should have LEFT zone")
	assert_true(calc.band_polygons.has(Constants.HullZone.RIGHT),
		"Should have RIGHT zone")
	assert_true(calc.band_polygons.has(Constants.HullZone.REAR),
		"Should have REAR zone")


func test_compute_produces_8_arc_lines() -> void:
	var calc := RangeOverlayCalculator.new()
	calc.compute(
		_make_square_base(),
		_make_symmetric_boundaries(),
		100.0, 200.0, 400.0)
	# 4 boundary lines, 1 segment each = 4 line segments.
	assert_eq(calc.arc_lines.size(), 4,
		"Should produce 4 arc boundary line segments")


func test_compute_arc_lines_are_vector2_pairs() -> void:
	var calc := RangeOverlayCalculator.new()
	calc.compute(
		_make_square_base(),
		_make_symmetric_boundaries(),
		100.0, 200.0, 400.0)
	for seg: Array in calc.arc_lines:
		assert_eq(seg.size(), 2,
			"Each line segment should be a [from, to] pair")
		assert_true(seg[0] is Vector2,
			"Segment start should be Vector2")
		assert_true(seg[1] is Vector2,
			"Segment end should be Vector2")


func test_compute_each_zone_has_three_bands() -> void:
	var calc := RangeOverlayCalculator.new()
	calc.compute(
		_make_square_base(),
		_make_symmetric_boundaries(),
		100.0, 200.0, 400.0)
	for zone: int in calc.band_polygons:
		var bands: Dictionary = calc.band_polygons[zone]
		assert_true(bands.has("close"),
			"Zone %d should have close band" % zone)
		assert_true(bands.has("medium"),
			"Zone %d should have medium band" % zone)
		assert_true(bands.has("long"),
			"Zone %d should have long band" % zone)


func test_compute_band_polygons_have_enough_vertices() -> void:
	var calc := RangeOverlayCalculator.new()
	calc.compute(
		_make_square_base(),
		_make_symmetric_boundaries(),
		100.0, 200.0, 400.0)
	for zone: int in calc.band_polygons:
		var bands: Dictionary = calc.band_polygons[zone]
		for band_name: String in bands:
			var polys: Array = bands[band_name]
			for poly: PackedVector2Array in polys:
				assert_true(poly.size() >= 3,
					"Zone %d band %s polygon should have >= 3 vertices" \
					% [zone, band_name])


func test_compute_single_inner_point_produces_valid_output() -> void:
	var calc := RangeOverlayCalculator.new()
	calc.compute(
		_make_square_base(),
		_make_single_inner_boundaries(),
		50.0, 150.0, 300.0)
	assert_eq(calc.band_polygons.size(), 4,
		"Single-inner-point config should still produce 4 zones")
	assert_eq(calc.arc_lines.size(), 4,
		"Should produce 4 arc line segments")


func test_compute_empty_boundaries_produces_nothing() -> void:
	var calc := RangeOverlayCalculator.new()
	calc.compute(_make_square_base(), {}, 100.0, 200.0, 400.0)
	assert_eq(calc.band_polygons.size(), 0,
		"Empty boundaries should produce no band polygons")
	assert_eq(calc.arc_lines.size(), 0,
		"Empty boundaries should produce no arc lines")


func test_compute_degenerate_base_produces_nothing() -> void:
	var calc := RangeOverlayCalculator.new()
	calc.compute(
		PackedVector2Array([Vector2.ZERO]),
		_make_symmetric_boundaries(),
		100.0, 200.0, 400.0)
	assert_eq(calc.band_polygons.size(), 0,
		"Degenerate base should produce no band polygons")


func test_arc_line_extends_beyond_long_range() -> void:
	var calc := RangeOverlayCalculator.new()
	var long_px: float = 400.0
	calc.compute(
		_make_square_base(),
		_make_symmetric_boundaries(),
		100.0, 200.0, long_px)
	# Expected extension = long_px * 1.2 = 480 beyond outer point.
	var seg: Array = calc.arc_lines[0]
	var from: Vector2 = seg[0] as Vector2
	var to: Vector2 = seg[1] as Vector2
	var line_length: float = from.distance_to(to)
	# Inner to outer is ~42.43 px (diagonal of 30×30), plus 480 extension.
	assert_true(line_length > long_px,
		"Arc line should extend beyond the long range distance")
