## Immutable loader for the Owner-approved obstacle contour evidence.
##
## The evidence retains original-PNG coordinates and the original image-centre
## pivot. Bounding-box metadata is intentionally ignored: only the approved
## contour rings can become gameplay geometry.
class_name ObstacleContourCatalog
extends RefCounted


const DATASET_PATH: String = \
		"res://docs/architecture/evidence/ship-maneuver-obstacle-contours/obstacle-alpha-contours-v3.json"
const DATASET_VERSION: String = "obstacle-alpha-mask-contour-evidence-v3"
const DATASET_SHA256: String = \
		"edd2c9597e75a4a092b7c3cc9fe8b899d421b02720a8731b1eb5e6578f505eb0"
const CANONICAL_WORLD_UNITS_PER_NATIVE_SOURCE_PX_AT_CURRENT_SCALE: float = 1.0
const CONTACT_POLICY: String = "positive_area"
const UNITS: String = "canonical_world_units"
const CONTOUR: GDScript = preload(
		"res://src/core/geometry/obstacle_contour.gd")


static func load_all() -> Dictionary:
	if FileAccess.get_sha256(DATASET_PATH) != DATASET_SHA256:
		return {}
	var file := FileAccess.open(DATASET_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {}
	var dataset: Dictionary = parsed as Dictionary
	if str(dataset.get("dataset_version", "")) != DATASET_VERSION \
			or str(dataset.get("contact_policy", "")) \
					!= "positive-area intersection is overlap; boundary-only contact is not overlap" \
			or float(dataset.get(
					"canonical_world_units_per_native_source_px_at_current_scale",
					-1.0)) \
					!= CANONICAL_WORLD_UNITS_PER_NATIVE_SOURCE_PX_AT_CURRENT_SCALE \
			or not dataset.get("obstacles") is Array:
		return {}
	var result: Dictionary = {}
	for raw_obstacle: Variant in dataset["obstacles"] as Array:
		if not raw_obstacle is Dictionary:
			return {}
		var obstacle: Dictionary = raw_obstacle as Dictionary
		var key: String = str(obstacle.get("data_key", ""))
		var image_size: Variant = obstacle.get("image_size_source_px")
		var pivot: Variant = obstacle.get("image_centre_pivot_source_px")
		var rings: Variant = obstacle.get("rings")
		if key.is_empty() or result.has(key) or not image_size is Dictionary \
				or not pivot is Dictionary or not rings is Array \
				or (rings as Array).size() != 1:
			return {}
		var ring: Variant = (rings as Array)[0]
		if not ring is Dictionary \
				or str((ring as Dictionary).get("winding_y_down", "")) \
						!= "clockwise_outer" \
				or not (ring as Dictionary).get(
						"vertices_canonical_world_units") is Array:
			return {}
		var vertices: Array[Dictionary] = []
		for raw_point: Variant in (ring as Dictionary)[
				"vertices_canonical_world_units"] as Array:
			if not raw_point is Array or (raw_point as Array).size() != 2:
				return {}
			vertices.append({"x": float((raw_point as Array)[0]),
				"y": float((raw_point as Array)[1])})
		var contour: RefCounted = CONTOUR.from_dictionary({
			"contour_version": DATASET_VERSION,
			"content_hash": DATASET_SHA256,
			"units": UNITS,
			"local_origin_x": float((pivot as Dictionary).get("x", -1.0)),
			"local_origin_y": float((pivot as Dictionary).get("y", -1.0)),
			"orientation_degrees": 0.0,
			"winding": CONTOUR.WINDING_CLOCKWISE,
			"contact_policy": CONTACT_POLICY,
			"vertices": vertices,
		})
		if contour == null \
				or float((pivot as Dictionary).get("x", -1.0)) \
						!= float((image_size as Dictionary).get("width", -2)) / 2.0 \
				or float((pivot as Dictionary).get("y", -1.0)) \
						!= float((image_size as Dictionary).get("height", -2)) / 2.0:
			return {}
		result[key] = contour
	return result if result.size() == 6 else {}


static func load_one(data_key: String) -> RefCounted:
	return load_all().get(data_key)
