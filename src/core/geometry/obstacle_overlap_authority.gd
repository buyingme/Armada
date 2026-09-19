## Pure injected-contour overlap algorithm. This file contains no real-token
## data and cannot make obstacle behavior reachable before contour approval.
class_name ObstacleOverlapAuthority
extends RefCounted


const CONTOUR: GDScript = preload(
		"res://src/core/geometry/obstacle_contour.gd")
const CATALOG: GDScript = preload(
		"res://src/core/geometry/obstacle_contour_catalog.gd")
const AREA_EPSILON: float = 0.00001


## Returns stable final-position obstacle evidence from canonical state only.
## Invalid/mixed-version placement data fails closed as an empty result.
static func overlapping_obstacles(game_state: GameState,
		owner_player: int, ship_index: int) -> Array[Dictionary]:
	if game_state == null:
		return []
	var ship: ShipInstance = game_state.get_ship(owner_player, ship_index)
	if ship == null or ship.is_destroyed() or ship.ship_data == null:
		return []
	var raw_obstacles: Variant = game_state.objectives.get("obstacles", [])
	if not raw_obstacles is Array:
		return []
	var contours: Dictionary = CATALOG.load_all()
	if contours.size() != 6:
		return []
	var play_area: Vector2 = GameScale.play_area_size_px
	var ship_base := ShipBase.new(ship.ship_data.ship_size,
			Transform2D(deg_to_rad(ship.rotation_deg),
					ship.get_pixel_position(play_area)))
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw_obstacle: Variant in raw_obstacles as Array:
		if not raw_obstacle is Dictionary:
			return []
		var obstacle: Dictionary = raw_obstacle as Dictionary
		var order: Variant = obstacle.get("placement_order")
		var obstacle_id: String = str(obstacle.get("obstacle_id", ""))
		var data_key: String = str(obstacle.get("data_key", ""))
		if typeof(order) != TYPE_INT \
				or obstacle_id != "obstacle:%d" % int(order) \
				or seen.has(obstacle_id) or not contours.has(data_key) \
				or typeof(obstacle.get("pos_x")) != TYPE_FLOAT \
				or typeof(obstacle.get("pos_y")) != TYPE_FLOAT \
				or typeof(obstacle.get("rotation_deg")) != TYPE_FLOAT \
				or (typeof(obstacle.get("last_maneuver_execution_id")) \
						!= TYPE_STRING and game_state.passive_damage_ledger == null):
			return []
		seen[obstacle_id] = true
		var transform := Transform2D(
				deg_to_rad(float(obstacle["rotation_deg"])),
				Vector2(float(obstacle["pos_x"]) * play_area.x,
						float(obstacle["pos_y"]) * play_area.y))
		if has_positive_overlap(ship_base, contours[data_key], transform,
				AREA_EPSILON):
			result.append({
				"obstacle_id": obstacle_id,
				"data_key": data_key,
				"obstacle_type": _obstacle_type(data_key),
				"placement_order": int(order),
				"last_maneuver_execution_id": str(
						obstacle.get("last_maneuver_execution_id", "")),
			})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["placement_order"]) < int(b["placement_order"]))
	return result


static func unresolved_overlaps(game_state: GameState, owner_player: int,
		ship_index: int, execution_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for obstacle: Dictionary in overlapping_obstacles(
			game_state, owner_player, ship_index):
		if str(obstacle["last_maneuver_execution_id"]) != execution_id:
			result.append(obstacle)
	return result


## Baseline Maneuver invokes only the next typed owner selected by the already
## committed obstacle order. Asteroid opens atomically with its draw command;
## debris and station persist their decision state here.
static func open_next_purpose_resolution(game_state: GameState,
		owner_player: int, ship_index: int) -> bool:
	var ship: ShipInstance = game_state.get_ship(owner_player, ship_index) \
			if game_state != null else null
	if ship == null or ship.is_destroyed():
		return false
	if ship.has_active_obstacle_resolution():
		return true
	var execution: Dictionary = ship.active_maneuver_execution_snapshot()
	var execution_id: String = str(execution.get("maneuver_execution_id", ""))
	var activation_id: String = str(execution.get(
			"ship_activation_identity", ""))
	var order: Array = execution.get("obstacle_resolution_order", []) as Array
	var unresolved_by_id: Dictionary = {}
	for item: Dictionary in unresolved_overlaps(
			game_state, owner_player, ship_index, execution_id):
		unresolved_by_id[str(item["obstacle_id"])] = item
	for raw_id: Variant in order:
		var obstacle_id: String = str(raw_id)
		if not unresolved_by_id.has(obstacle_id):
			continue
		var obstacle: Dictionary = unresolved_by_id[obstacle_id]
		match str(obstacle["obstacle_type"]):
			"asteroid":
				return true
			"debris":
				return ship.open_debris_resolution(
						activation_id, execution_id, obstacle_id, owner_player)
			"station":
				if game_state.selected_objective_key() \
						== "obj_def_contested_outpost":
					return false
				return ship.open_station_resolution(
						activation_id, execution_id, obstacle_id, owner_player)
	return true
static func has_positive_overlap(ship_base: ShipBase,
		contour: RefCounted, obstacle_transform: Transform2D,
		area_epsilon: float) -> bool:
	if ship_base == null or contour == null or not contour is CONTOUR \
			or not contour.is_valid() or not is_finite(area_epsilon) \
			or area_epsilon < 0.0:
		return false
	var contour_transform := obstacle_transform * Transform2D(
			deg_to_rad(contour.orientation_degrees), -contour.local_origin)
	var obstacle_polygon := PackedVector2Array()
	for vertex: Vector2 in contour.vertices:
		obstacle_polygon.append(contour_transform * vertex)
	var intersections: Array[PackedVector2Array] = Geometry2D.intersect_polygons(
			ship_base.get_base_polygon(), obstacle_polygon)
	for polygon: PackedVector2Array in intersections:
		if absf(_signed_area(polygon)) > area_epsilon:
			return true
	return false


static func overlapping_ids(ship_base: ShipBase,
		placements: Array) -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}
	for placement: Dictionary in placements:
		var contour: Variant = placement.get("contour")
		var transform: Variant = placement.get("transform")
		var epsilon: Variant = placement.get("area_epsilon")
		var obstacle_id: String = str(placement.get("obstacle_id", ""))
		if obstacle_id.is_empty() or seen.has(obstacle_id) \
				or not contour is CONTOUR or not transform is Transform2D \
				or typeof(epsilon) != TYPE_FLOAT:
			continue
		seen[obstacle_id] = true
		if has_positive_overlap(
				ship_base, contour as RefCounted, transform as Transform2D,
				float(epsilon)):
			result.append(obstacle_id)
	result.sort()
	return result


static func _signed_area(polygon: PackedVector2Array) -> float:
	var twice_area: float = 0.0
	for index: int in range(polygon.size()):
		var current: Vector2 = polygon[index]
		var next: Vector2 = polygon[(index + 1) % polygon.size()]
		twice_area += current.x * next.y - next.x * current.y
	return twice_area * 0.5


static func _obstacle_type(data_key: String) -> String:
	if data_key.begins_with("asteroid_"):
		return "asteroid"
	if data_key.begins_with("debris_"):
		return "debris"
	return "station" if data_key == "station" else ""
