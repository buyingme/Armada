## JSON-safe canonical obstacle-contour value type.
## No real-token vertices are supplied before the Owner contour gate.
class_name ObstacleContour
extends RefCounted


const CONTACT_POSITIVE_AREA := "positive_area"
const WINDING_CLOCKWISE := "clockwise"
const WINDING_COUNTERCLOCKWISE := "counterclockwise"

var contour_version: String = ""
var content_hash: String = ""
var units: String = ""
var local_origin: Vector2 = Vector2.ZERO
var orientation_degrees: float = 0.0
var winding: String = ""
var contact_policy: String = ""
var vertices: PackedVector2Array = PackedVector2Array()


static func from_dictionary(data: Dictionary) -> RefCounted:
	var keys: Array[String] = [
		"contour_version", "content_hash", "units", "local_origin_x",
		"local_origin_y", "orientation_degrees", "winding",
		"contact_policy", "vertices",
	]
	if data.size() != keys.size():
		return null
	for key: String in keys:
		if not data.has(key):
			return null
	if typeof(data["contour_version"]) != TYPE_STRING \
			or typeof(data["content_hash"]) != TYPE_STRING \
			or typeof(data["units"]) != TYPE_STRING \
			or typeof(data["local_origin_x"]) != TYPE_FLOAT \
			or typeof(data["local_origin_y"]) != TYPE_FLOAT \
			or typeof(data["orientation_degrees"]) != TYPE_FLOAT \
			or typeof(data["winding"]) != TYPE_STRING \
			or typeof(data["contact_policy"]) != TYPE_STRING \
			or not data["vertices"] is Array:
		return null
	var contour: RefCounted = (load(
			"res://src/core/geometry/obstacle_contour.gd") as GDScript).new()
	contour.contour_version = str(data["contour_version"])
	contour.content_hash = str(data["content_hash"])
	contour.units = str(data["units"])
	contour.local_origin = Vector2(
			float(data["local_origin_x"]), float(data["local_origin_y"]))
	contour.orientation_degrees = float(data["orientation_degrees"])
	contour.winding = str(data["winding"])
	contour.contact_policy = str(data["contact_policy"])
	for raw: Variant in data["vertices"] as Array:
		if not raw is Dictionary or (raw as Dictionary).size() != 2 \
				or typeof((raw as Dictionary).get("x")) != TYPE_FLOAT \
				or typeof((raw as Dictionary).get("y")) != TYPE_FLOAT:
			return null
		contour.vertices.append(Vector2(
				float((raw as Dictionary)["x"]),
				float((raw as Dictionary)["y"])))
	return contour if contour.is_valid() else null


func is_valid() -> bool:
	if contour_version.is_empty() or content_hash.is_empty() \
			or units.is_empty() or vertices.size() < 3 \
			or winding not in [WINDING_CLOCKWISE, WINDING_COUNTERCLOCKWISE] \
			or contact_policy != CONTACT_POSITIVE_AREA \
			or not is_finite(local_origin.x) or not is_finite(local_origin.y) \
			or not is_finite(orientation_degrees):
		return false
	for vertex: Vector2 in vertices:
		if not is_finite(vertex.x) or not is_finite(vertex.y):
			return false
	# Godot world coordinates are y-down. Positive signed area is therefore
	# visually clockwise, matching the approved contour evidence convention.
	return _signed_area(vertices) > 0.0 \
			if winding == WINDING_CLOCKWISE else _signed_area(vertices) < 0.0


func serialize() -> Dictionary:
	if not is_valid():
		return {}
	var serialized_vertices: Array[Dictionary] = []
	for vertex: Vector2 in vertices:
		serialized_vertices.append({"x": vertex.x, "y": vertex.y})
	return {
		"contour_version": contour_version,
		"content_hash": content_hash,
		"units": units,
		"local_origin_x": local_origin.x,
		"local_origin_y": local_origin.y,
		"orientation_degrees": orientation_degrees,
		"winding": winding,
		"contact_policy": contact_policy,
		"vertices": serialized_vertices,
	}


static func _signed_area(polygon: PackedVector2Array) -> float:
	var twice_area: float = 0.0
	for index: int in range(polygon.size()):
		var current: Vector2 = polygon[index]
		var next: Vector2 = polygon[(index + 1) % polygon.size()]
		twice_area += current.x * next.y - next.x * current.y
	return twice_area * 0.5
