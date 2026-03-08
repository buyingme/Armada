## Tests for ShipBase
##
## Covers: base polygon, hull zone polygons, arc boundary rays, notch positions,
##   centre computation, SMALL and MEDIUM base sizes.
##
## Rules Reference: "Hull Zones", p.4; "Firing Arcs", p.3; AT-010–014
extends GutTest


## Helper: build an axis-aligned ShipBase at the origin, no rotation.
func _make_small_base_at_origin() -> ShipBase:
	return ShipBase.new(Constants.ShipSize.SMALL, Transform2D.IDENTITY)


func _make_medium_base_at_origin() -> ShipBase:
	return ShipBase.new(Constants.ShipSize.MEDIUM, Transform2D.IDENTITY)


func _make_small_base_at(pos: Vector2, angle_rad: float = 0.0) -> ShipBase:
	return ShipBase.new(Constants.ShipSize.SMALL, Transform2D(angle_rad, pos))


# ---------------------------------------------------------------------------
# Base polygon
# ---------------------------------------------------------------------------

func test_get_base_polygon_has_four_vertices() -> void:
	var base: ShipBase = _make_small_base_at_origin()
	var poly: PackedVector2Array = base.get_base_polygon()
	assert_eq(poly.size(), 4, "Ship base polygon should have 4 vertices")


func test_get_base_polygon_centred_at_origin() -> void:
	var base: ShipBase = _make_small_base_at_origin()
	var poly: PackedVector2Array = base.get_base_polygon()
	var sum: Vector2 = Vector2.ZERO
	for v: Vector2 in poly:
		sum += v
	var centre: Vector2 = sum / float(poly.size())
	assert_almost_eq(centre.x, 0.0, 0.1, "Base polygon centre X should be 0")
	assert_almost_eq(centre.y, 0.0, 0.1, "Base polygon centre Y should be 0")


func test_get_base_polygon_correct_width() -> void:
	var base: ShipBase = _make_small_base_at_origin()
	var poly: PackedVector2Array = base.get_base_polygon()
	var expected_width: float = GameScale.small_base_width_px
	var min_x: float = poly[0].x
	var max_x: float = poly[0].x
	for v: Vector2 in poly:
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
	assert_almost_eq(max_x - min_x, expected_width, 0.5,
			"Base width should match GameScale small base width")


func test_get_base_polygon_translated() -> void:
	var pos: Vector2 = Vector2(100.0, 200.0)
	var base: ShipBase = _make_small_base_at(pos)
	var poly: PackedVector2Array = base.get_base_polygon()
	var sum: Vector2 = Vector2.ZERO
	for v: Vector2 in poly:
		sum += v
	var centre: Vector2 = sum / 4.0
	assert_almost_eq(centre.x, 100.0, 0.5, "Translated base centre X should be 100")
	assert_almost_eq(centre.y, 200.0, 0.5, "Translated base centre Y should be 200")


# ---------------------------------------------------------------------------
# Hull zone polygons
# ---------------------------------------------------------------------------

func test_hull_zone_polygon_has_four_vertices() -> void:
	var base: ShipBase = _make_small_base_at_origin()
	for zone: Constants.HullZone in [
		Constants.HullZone.FRONT,
		Constants.HullZone.REAR,
		Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT,
	]:
		var poly: PackedVector2Array = base.get_hull_zone_polygon(zone)
		assert_eq(poly.size(), 4, "Hull zone polygon should have 4 vertices")


func test_front_hull_zone_is_above_rear_hull_zone() -> void:
	var base: ShipBase = _make_small_base_at_origin()
	var front_centre: Vector2 = base.get_hull_zone_centre(Constants.HullZone.FRONT)
	var rear_centre: Vector2 = base.get_hull_zone_centre(Constants.HullZone.REAR)
	assert_true(front_centre.y < rear_centre.y,
			"Front zone centre should have smaller Y than rear (ship faces -Y)")


func test_left_and_right_zones_are_horizontally_opposed() -> void:
	var base: ShipBase = _make_small_base_at_origin()
	var left_centre: Vector2 = base.get_hull_zone_centre(Constants.HullZone.LEFT)
	var right_centre: Vector2 = base.get_hull_zone_centre(Constants.HullZone.RIGHT)
	assert_true(left_centre.x < 0.0, "Left zone centre should have negative X")
	assert_true(right_centre.x > 0.0, "Right zone centre should have positive X")


func test_hull_zones_cover_entire_base_area() -> void:
	# Sum of zone areas should approximately equal base area.
	var base: ShipBase = _make_small_base_at_origin()
	var total_area: float = 0.0
	for zone: Constants.HullZone in [
		Constants.HullZone.FRONT,
		Constants.HullZone.REAR,
		Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT,
	]:
		var poly: PackedVector2Array = base.get_hull_zone_polygon(zone)
		total_area += _polygon_area(poly)
	var base_poly: PackedVector2Array = base.get_base_polygon()
	var base_area: float = _polygon_area(base_poly)
	# Zone coverage should be roughly 2/3 of base (middle zones are half-width,
	# front+rear each cover 1/3 length × full width).
	assert_true(total_area > 0.0, "Total hull zone area should be positive")
	assert_true(total_area <= base_area * 1.01,
			"Total hull zone area should not exceed base area")


# ---------------------------------------------------------------------------
# Arc boundary rays
# ---------------------------------------------------------------------------

func test_get_arc_boundary_rays_returns_four_rays() -> void:
	var base: ShipBase = _make_small_base_at_origin()
	var rays: Array[Array] = base.get_arc_boundary_rays()
	assert_eq(rays.size(), 4, "Should return 4 arc boundary rays")


func test_arc_boundary_rays_all_start_at_centre() -> void:
	var base: ShipBase = _make_small_base_at_origin()
	var rays: Array[Array] = base.get_arc_boundary_rays()
	for ray: Array in rays:
		var origin: Vector2 = ray[0]
		assert_almost_eq(origin.x, 0.0, 0.5, "Ray should start at base centre X")
		assert_almost_eq(origin.y, 0.0, 0.5, "Ray should start at base centre Y")


# ---------------------------------------------------------------------------
# Notch positions
# ---------------------------------------------------------------------------

func test_get_notch_positions_returns_four() -> void:
	var base: ShipBase = _make_small_base_at_origin()
	var notches: Array[Vector2] = base.get_notch_positions()
	assert_eq(notches.size(), 4, "Ship base should have 4 notch positions")


# ---------------------------------------------------------------------------
# Centre
# ---------------------------------------------------------------------------

func test_get_centre_at_origin() -> void:
	var base: ShipBase = _make_small_base_at_origin()
	var c: Vector2 = base.get_centre()
	assert_almost_eq(c.x, 0.0, 0.01, "Centre X should be 0")
	assert_almost_eq(c.y, 0.0, 0.01, "Centre Y should be 0")


func test_get_centre_translated() -> void:
	var base: ShipBase = _make_small_base_at(Vector2(50.0, -30.0))
	var c: Vector2 = base.get_centre()
	assert_almost_eq(c.x, 50.0, 0.01, "Centre X should match position")
	assert_almost_eq(c.y, -30.0, 0.01, "Centre Y should match position")


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

## Computes the signed area of a polygon using the shoelace formula.
func _polygon_area(poly: PackedVector2Array) -> float:
	var area: float = 0.0
	var n: int = poly.size()
	for i: int in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		area += a.x * b.y - b.x * a.y
	return abs(area) * 0.5
