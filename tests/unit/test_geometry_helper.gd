## Tests for Geometry2DHelper
##
## Covers: point_in_polygon, point_on_segment, closest_point_on_segment,
##   closest_point_on_polygon, distance_point_to_polygon, segments_intersect,
##   line_intersection, distance_polygon_to_polygon, transform_polygon,
##   make_rect_polygon, make_circle_polygon
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_square(size: float) -> PackedVector2Array:
	return Geometry2DHelper.make_rect_polygon(size, size)


func _make_unit_square() -> PackedVector2Array:
	# Square with corners at (±0.5, ±0.5)
	return _make_square(1.0)


# ---------------------------------------------------------------------------
# point_in_polygon
# ---------------------------------------------------------------------------

func test_point_in_polygon_inside_returns_true() -> void:
	var poly: PackedVector2Array = _make_unit_square()
	var result: bool = Geometry2DHelper.point_in_polygon(Vector2(0.0, 0.0), poly)
	assert_true(result, "Centre of square should be inside polygon")


func test_point_in_polygon_outside_returns_false() -> void:
	var poly: PackedVector2Array = _make_unit_square()
	var result: bool = Geometry2DHelper.point_in_polygon(Vector2(2.0, 0.0), poly)
	assert_false(result, "Point far outside square should not be inside polygon")


func test_point_in_polygon_near_edge_outside_returns_false() -> void:
	var poly: PackedVector2Array = _make_unit_square()
	var result: bool = Geometry2DHelper.point_in_polygon(Vector2(0.6, 0.0), poly)
	assert_false(result, "Point just outside edge should not be inside")


# ---------------------------------------------------------------------------
# point_on_segment
# ---------------------------------------------------------------------------

func test_point_on_segment_midpoint_returns_true() -> void:
	var result: bool = Geometry2DHelper.point_on_segment(
			Vector2(5.0, 0.0), Vector2(0.0, 0.0), Vector2(10.0, 0.0))
	assert_true(result, "Midpoint of segment should be on segment")


func test_point_on_segment_endpoint_returns_true() -> void:
	var result: bool = Geometry2DHelper.point_on_segment(
			Vector2(0.0, 0.0), Vector2(0.0, 0.0), Vector2(10.0, 0.0))
	assert_true(result, "Endpoint should be on segment")


func test_point_on_segment_outside_returns_false() -> void:
	var result: bool = Geometry2DHelper.point_on_segment(
			Vector2(11.0, 0.0), Vector2(0.0, 0.0), Vector2(10.0, 0.0))
	assert_false(result, "Point beyond endpoint should not be on segment")


# ---------------------------------------------------------------------------
# closest_point_on_segment
# ---------------------------------------------------------------------------

func test_closest_point_on_segment_perpendicular_foot() -> void:
	var result: Vector2 = Geometry2DHelper.closest_point_on_segment(
			Vector2(5.0, 3.0), Vector2(0.0, 0.0), Vector2(10.0, 0.0))
	assert_almost_eq(result.x, 5.0, 0.01,
			"Closest point x should be directly below query point")
	assert_almost_eq(result.y, 0.0, 0.01,
			"Closest point y should be on segment")


func test_closest_point_on_segment_clamped_to_end() -> void:
	var result: Vector2 = Geometry2DHelper.closest_point_on_segment(
			Vector2(15.0, 3.0), Vector2(0.0, 0.0), Vector2(10.0, 0.0))
	assert_almost_eq(result.x, 10.0, 0.01, "Should clamp to end of segment")


# ---------------------------------------------------------------------------
# closest_point_on_polygon
# ---------------------------------------------------------------------------

func test_closest_point_on_polygon_outside_point() -> void:
	var poly: PackedVector2Array = _make_unit_square()
	var p: Vector2 = Vector2(2.0, 0.0)
	var result: Vector2 = Geometry2DHelper.closest_point_on_polygon(p, poly)
	assert_almost_eq(result.x, 0.5, 0.01, "Closest point should be on right edge")
	assert_almost_eq(result.y, 0.0, 0.01, "Closest point y should be 0")


# ---------------------------------------------------------------------------
# distance_point_to_polygon
# ---------------------------------------------------------------------------

func test_distance_point_to_polygon_inside_is_zero() -> void:
	var poly: PackedVector2Array = _make_unit_square()
	var d: float = Geometry2DHelper.distance_point_to_polygon(
			Vector2(0.0, 0.0), poly)
	assert_almost_eq(d, 0.0, 0.01, "Point inside polygon: distance should be 0")


func test_distance_point_to_polygon_outside() -> void:
	var poly: PackedVector2Array = _make_unit_square()
	var d: float = Geometry2DHelper.distance_point_to_polygon(
			Vector2(2.0, 0.0), poly)
	assert_almost_eq(d, 1.5, 0.01, "Distance from (2,0) to right edge (0.5) = 1.5")


# ---------------------------------------------------------------------------
# segments_intersect
# ---------------------------------------------------------------------------

func test_segments_intersect_crossing_returns_true() -> void:
	var result: bool = Geometry2DHelper.segments_intersect(
			Vector2(0.0, -1.0), Vector2(0.0, 1.0),
			Vector2(-1.0, 0.0), Vector2(1.0, 0.0))
	assert_true(result, "Crossing segments should intersect")


func test_segments_intersect_parallel_returns_false() -> void:
	var result: bool = Geometry2DHelper.segments_intersect(
			Vector2(0.0, 0.0), Vector2(1.0, 0.0),
			Vector2(0.0, 1.0), Vector2(1.0, 1.0))
	assert_false(result, "Parallel segments should not intersect")


func test_segments_intersect_non_crossing_returns_false() -> void:
	var result: bool = Geometry2DHelper.segments_intersect(
			Vector2(0.0, 0.0), Vector2(1.0, 0.0),
			Vector2(2.0, -1.0), Vector2(2.0, 1.0))
	assert_false(result, "Non-overlapping segments should not intersect")


# ---------------------------------------------------------------------------
# line_intersection
# ---------------------------------------------------------------------------

func test_line_intersection_perpendicular_lines() -> void:
	var result: Vector2 = Geometry2DHelper.line_intersection(
			Vector2(0.0, 0.0), Vector2(10.0, 0.0),
			Vector2(5.0, -5.0), Vector2(5.0, 5.0))
	assert_almost_eq(result.x, 5.0, 0.01, "Intersection x should be 5")
	assert_almost_eq(result.y, 0.0, 0.01, "Intersection y should be 0")


func test_line_intersection_parallel_lines_returns_inf() -> void:
	var result: Vector2 = Geometry2DHelper.line_intersection(
			Vector2(0.0, 0.0), Vector2(1.0, 0.0),
			Vector2(0.0, 1.0), Vector2(1.0, 1.0))
	assert_true(is_inf(result.x), "Parallel lines should return INF vector")


# ---------------------------------------------------------------------------
# distance_polygon_to_polygon
# ---------------------------------------------------------------------------

func test_distance_polygon_to_polygon_separated() -> void:
	var poly_a: PackedVector2Array = Geometry2DHelper.make_rect_polygon(10.0, 10.0)
	# Shift poly_b 20 units to the right (centre at x=20, from x=15 to x=25)
	var poly_b: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in Geometry2DHelper.make_rect_polygon(10.0, 10.0):
		poly_b.append(v + Vector2(20.0, 0.0))
	var d: float = Geometry2DHelper.distance_polygon_to_polygon(poly_a, poly_b)
	assert_almost_eq(d, 10.0, 0.1,
			"Distance between adjacent edges should be 10px (5 to 15)")


func test_distance_polygon_to_polygon_overlapping_is_zero() -> void:
	var poly_a: PackedVector2Array = Geometry2DHelper.make_rect_polygon(20.0, 20.0)
	var poly_b: PackedVector2Array = Geometry2DHelper.make_rect_polygon(10.0, 10.0)
	var d: float = Geometry2DHelper.distance_polygon_to_polygon(poly_a, poly_b)
	assert_almost_eq(d, 0.0, 0.01, "Overlapping polygons: distance should be 0")


# ---------------------------------------------------------------------------
# make_rect_polygon
# ---------------------------------------------------------------------------

func test_make_rect_polygon_size() -> void:
	var poly: PackedVector2Array = Geometry2DHelper.make_rect_polygon(100.0, 200.0)
	assert_eq(poly.size(), 4, "Rectangle polygon should have 4 vertices")


func test_make_rect_polygon_extents() -> void:
	var poly: PackedVector2Array = Geometry2DHelper.make_rect_polygon(100.0, 200.0)
	var min_x: float = poly[0].x
	var max_x: float = poly[0].x
	var min_y: float = poly[0].y
	var max_y: float = poly[0].y
	for v: Vector2 in poly:
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
		min_y = minf(min_y, v.y)
		max_y = maxf(max_y, v.y)
	assert_almost_eq(max_x - min_x, 100.0, 0.01, "Rectangle width should be 100")
	assert_almost_eq(max_y - min_y, 200.0, 0.01, "Rectangle height should be 200")


# ---------------------------------------------------------------------------
# make_circle_polygon
# ---------------------------------------------------------------------------

func test_make_circle_polygon_vertex_count() -> void:
	var poly: PackedVector2Array = Geometry2DHelper.make_circle_polygon(50.0, 12)
	assert_eq(poly.size(), 12, "Circle polygon should have requested segment count")


func test_make_circle_polygon_radius() -> void:
	var poly: PackedVector2Array = Geometry2DHelper.make_circle_polygon(50.0, 12)
	for v: Vector2 in poly:
		assert_almost_eq(v.length(), 50.0, 0.01,
				"All vertices should be at radius distance from origin")
