extends GutTest


const CATALOG: GDScript = preload(
		"res://src/core/geometry/obstacle_contour_catalog.gd")


func test_approved_v3_dataset_loads_exact_six_original_coordinate_contours() -> void:
	var contours: Dictionary = CATALOG.load_all()
	assert_eq(contours.keys().size(), 6)
	for key: String in [
		"asteroid_1", "asteroid_2", "asteroid_3",
		"debris_1", "debris_2", "station",
	]:
		assert_true(contours.has(key), key)
		var contour: RefCounted = contours[key]
		assert_true(contour.is_valid(), key)
		assert_eq(contour.contour_version, CATALOG.DATASET_VERSION)
		assert_eq(contour.content_hash, CATALOG.DATASET_SHA256)
		assert_eq(contour.units, CATALOG.UNITS)
		assert_eq(contour.winding, "clockwise")
		assert_eq(contour.contact_policy, "positive_area")


func test_catalog_fails_closed_for_unknown_key() -> void:
	assert_null(CATALOG.load_one("not_an_obstacle"))
