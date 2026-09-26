extends GutTest


const OVERLAP: GDScript = preload(
		"res://src/core/geometry/obstacle_overlap_authority.gd")
const CONTOUR: GDScript = preload(
		"res://src/core/geometry/obstacle_contour.gd")
const CATALOG: GDScript = preload(
		"res://src/core/geometry/obstacle_contour_catalog.gd")


func test_synthetic_overlap_rotation_touch_and_deterministic_order() -> void:
	var contour: RefCounted = _square()
	var ship := ShipBase.new(Constants.ShipSize.SMALL,
			Transform2D(0.0, Vector2(100.0, 100.0)))
	assert_true(OVERLAP.has_positive_overlap(
			ship, contour, Transform2D(0.0, Vector2(100.0, 100.0)), 0.00001))
	assert_true(OVERLAP.has_positive_overlap(
			ship, contour, Transform2D(PI / 4.0, Vector2(100.0, 100.0)),
			0.00001))
	assert_false(OVERLAP.has_positive_overlap(
			ship, contour, Transform2D(0.0, Vector2(1000.0, 1000.0)),
			0.00001))

	var ship_edge: float = ship.half_width_px
	var touching_x: float = 100.0 + ship_edge + 10.0
	assert_false(OVERLAP.has_positive_overlap(
			ship, contour, Transform2D(0.0, Vector2(touching_x, 100.0)),
			0.00001))
	assert_eq(OVERLAP.overlapping_ids(ship, [
		{"obstacle_id": "obstacle:2", "contour": contour,
			"transform": Transform2D(0.0, Vector2(100.0, 100.0)),
			"area_epsilon": 0.00001},
		{"obstacle_id": "obstacle:1", "contour": contour,
			"transform": Transform2D(0.0, Vector2(100.0, 100.0)),
			"area_epsilon": 0.00001},
	]), ["obstacle:1", "obstacle:2"])
	var scaled := Transform2D(0.0, Vector2.ZERO).scaled(
			Vector2(3.0, 0.25))
	scaled.origin = Vector2(100.0, 100.0)
	assert_true(OVERLAP.has_positive_overlap(
			ship, contour, scaled, 0.00001))


func test_schema_rejects_wrong_winding_and_round_trips_synthetic_data() -> void:
	var contour: RefCounted = _square()
	var serialized: Dictionary = contour.serialize()
	assert_false(serialized.is_empty())
	assert_eq(CONTOUR.from_dictionary(serialized).serialize(), serialized)
	serialized["winding"] = CONTOUR.WINDING_COUNTERCLOCKWISE
	assert_null(CONTOUR.from_dictionary(serialized))


func test_all_approved_contours_overlap_at_representative_rotations() -> void:
	var contours: Dictionary = CATALOG.load_all()
	assert_eq(contours.keys().size(), 6)
	var ship := ShipBase.new(Constants.ShipSize.SMALL,
			Transform2D(0.0, Vector2(500.0, 500.0)))
	for key: String in [
		"asteroid_1", "asteroid_2", "asteroid_3",
		"debris_1", "debris_2", "station",
	]:
		for rotation: float in [0.0, 37.0, 123.0]:
			assert_true(OVERLAP.has_positive_overlap(
					ship, contours[key], Transform2D(
							deg_to_rad(rotation), Vector2(500.0, 500.0)),
					0.00001), "%s at %s degrees" % [key, rotation])
		assert_false(OVERLAP.has_positive_overlap(
				ship, contours[key], Transform2D(
						0.0, Vector2(1500.0, 1500.0)), 0.00001), key)


func test_v9_all_approved_contours_distinguish_boundary_inward_and_outward() \
		-> void:
	var contours: Dictionary = CATALOG.load_all()
	var ship_center := Vector2(500.0, 500.0)
	var ship := ShipBase.new(Constants.ShipSize.SMALL,
			Transform2D(0.0, ship_center))
	for key: String in [
		"asteroid_1", "asteroid_2", "asteroid_3",
		"debris_1", "debris_2", "station",
	]:
		var contour: RefCounted = contours[key]
		for rotation_degrees: float in [0.0, 37.0]:
			var rotation: float = deg_to_rad(rotation_degrees)
			var min_x: float = INF
			for vertex: Vector2 in contour.vertices:
				min_x = minf(min_x,
						(vertex - contour.local_origin).rotated(rotation).x)
			var tangent_origin := Vector2(
					ship_center.x + ship.half_width_px - min_x,
					ship_center.y)
			var tangent := Transform2D(rotation, tangent_origin)
			var inward := Transform2D(rotation,
					tangent_origin + Vector2(-0.1, 0.0))
			var outward := Transform2D(rotation,
					tangent_origin + Vector2(0.1, 0.0))
			assert_false(OVERLAP.has_positive_overlap(
					ship, contour, tangent, 0.00001),
					"%s tangent at %s°" % [key, rotation_degrees])
			assert_true(OVERLAP.has_positive_overlap(
					ship, contour, inward, 0.00001),
					"%s inward at %s°" % [key, rotation_degrees])
			assert_false(OVERLAP.has_positive_overlap(
					ship, contour, outward, 0.00001),
					"%s outward at %s°" % [key, rotation_degrees])


func _square() -> RefCounted:
	return CONTOUR.from_dictionary({
		"contour_version": "synthetic-v1",
		"content_hash": "synthetic-only-not-evidence",
		"units": "project_pixels",
		"local_origin_x": 0.0,
		"local_origin_y": 0.0,
		"orientation_degrees": 0.0,
		"winding": "clockwise",
		"contact_policy": "positive_area",
		"vertices": [
			{"x": -10.0, "y": -10.0},
			{"x": 10.0, "y": -10.0},
			{"x": 10.0, "y": 10.0},
			{"x": -10.0, "y": 10.0},
		],
	})
