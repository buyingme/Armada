## SetupObstacleValidator
##
## Validates setup-phase obstacle placements against the accepted setup-flow
## contract. Validation is authoritative for hot-seat, network, replay, and
## direct command submission, so UI previews remain advisory only.
##
## Rules Reference: "Setup", RRG 1.5.0 p.11; "Obstacles", RRG 1.5.0 p.12.
class_name SetupObstacleValidator
extends RefCounted


const ERROR_DEPLOYMENT_ZONE: String = "Setup obstacle placement cannot overlap a deployment zone."
const GAME_SCALE_SCRIPT: GDScript = preload("res://src/autoload/game_scale.gd")
const KEY_FILENAME: String = "filename"
const KEY_MAP: String = "map"
const KEY_OBSTACLES: String = "obstacles"
const KEY_SETUP_PACKAGE_HASH: String = "setup_package_hash"
const SETUP_INTERACTION_FLOW_RESOLVER_SCRIPT: GDScript = preload(
		"res://src/core/setup/setup_interaction_flow_resolver.gd")
const SHAPE_TYPE_ORIENTED_BOX: String = "oriented_box"


## Validates one `commit_setup_obstacle` submission against live setup state.
static func validate_commit(game_state: GameState,
		player_index: int,
		payload: Dictionary) -> String:
	var data_key: String = str(payload.get("data_key", "")).strip_edges()
	var obstacles: Array[Dictionary] = _dict_array_from(
			game_state.objectives.get(KEY_OBSTACLES, []))
	var key_error: String = _key_error(data_key)
	if key_error != "":
		return key_error
	var state_error: String = _state_error(game_state, player_index, obstacles, data_key)
	if state_error != "":
		return state_error
	return _geometry_error(game_state, obstacles, payload)


static func _key_error(data_key: String) -> String:
	if not AssetLoader.list_obstacle_keys().has(data_key):
		return "Setup obstacle placement requires a standard obstacle token key."
	return ""


static func _state_error(game_state: GameState,
		player_index: int,
		obstacles: Array[Dictionary],
		data_key: String) -> String:
	var count_error: String = _count_error(obstacles)
	if count_error != "":
		return count_error
	var duplicate_error: String = _duplicate_error(obstacles, data_key)
	if duplicate_error != "":
		return duplicate_error
	return _controller_error(game_state, player_index)


static func _count_error(obstacles: Array[Dictionary]) -> String:
	if obstacles.size() >= StartRoundCommand.STANDARD_OBSTACLE_COUNT:
		return "Setup already has six obstacle placements."
	return ""


static func _duplicate_error(obstacles: Array[Dictionary], data_key: String) -> String:
	for obstacle: Dictionary in obstacles:
		if str(obstacle.get("data_key", "")) == data_key:
			return "Setup obstacle %s has already been placed." % data_key
	return ""


static func _controller_error(game_state: GameState, player_index: int) -> String:
	if not game_state.objectives.has(KEY_SETUP_PACKAGE_HASH):
		return "No setup-package game is active."
	var flow: InteractionFlow = SETUP_INTERACTION_FLOW_RESOLVER_SCRIPT.build_for_state(game_state)
	if flow.flow_type != Constants.InteractionFlow.SETUP \
			or flow.step_id != Constants.InteractionStep.SETUP_OBSTACLE_PLACEMENT:
		return "Setup obstacle placement is only legal during obstacle placement."
	if flow.controller_player != player_index:
		return "Only the active setup player may place the next obstacle."
	return ""


static func _geometry_error(game_state: GameState,
		obstacles: Array[Dictionary],
		payload: Dictionary) -> String:
	var play_area_size: Vector2 = _play_area_size_px(game_state)
	var polygon: PackedVector2Array = _obstacle_polygon(payload, play_area_size)
	if polygon.is_empty():
		return "Setup obstacle placement is missing obstacle footprint metadata."
	var board_error: String = _board_error(polygon, play_area_size)
	if board_error != "":
		return board_error
	var zone_error: String = _deployment_zone_error(game_state, polygon, play_area_size)
	if zone_error != "":
		return zone_error
	return _separation_error(obstacles, polygon, play_area_size)


static func _board_error(polygon: PackedVector2Array, play_area_size: Vector2) -> String:
	for point: Vector2 in polygon:
		if point.x < 0.0 or point.x > play_area_size.x:
			return "Setup obstacle footprint must stay inside the setup area."
		if point.y < 0.0 or point.y > play_area_size.y:
			return "Setup obstacle footprint must stay inside the setup area."
	return ""


static func _deployment_zone_error(game_state: GameState,
		polygon: PackedVector2Array,
		play_area_size: Vector2) -> String:
	var top_clearance: float = _distance_band_px(3)
	var bottom_clearance: float = play_area_size.y - _distance_band_px(3)
	for point: Vector2 in polygon:
		if point.y <= top_clearance or point.y >= bottom_clearance:
			return ERROR_DEPLOYMENT_ZONE
	return ""


static func _separation_error(obstacles: Array[Dictionary],
		polygon: PackedVector2Array,
		play_area_size: Vector2) -> String:
	var minimum_gap: float = _distance_band_px(1)
	for obstacle: Dictionary in obstacles:
		var other_polygon: PackedVector2Array = _obstacle_polygon(obstacle, play_area_size)
		if other_polygon.is_empty():
			continue
		var distance: float = Geometry2DHelper.distance_polygon_to_polygon(
				polygon, other_polygon)
		if distance <= minimum_gap + 0.01:
			return "Setup obstacles must be beyond distance 1 of each other."
	return ""


static func _obstacle_polygon(payload: Dictionary,
		play_area_size: Vector2) -> PackedVector2Array:
	var footprint: Vector2 = _footprint_size_px(
			AssetLoader.load_obstacle_data(str(payload.get("data_key", ""))))
	if footprint.x <= 0.0 or footprint.y <= 0.0:
		return PackedVector2Array()
	var base_polygon: PackedVector2Array = Geometry2DHelper.make_rect_polygon(
			footprint.x, footprint.y)
	return Geometry2DHelper.transform_polygon(
			base_polygon,
			deg_to_rad(float(payload.get("rotation_deg", 0.0))),
			Vector2(
				float(payload.get("pos_x", 0.0)) * play_area_size.x,
				float(payload.get("pos_y", 0.0)) * play_area_size.y))


static func _footprint_size_px(obstacle_data: ObstacleData) -> Vector2:
	if obstacle_data == null:
		return Vector2.ZERO
	var metadata: Dictionary = obstacle_data.shape_metadata
	if str(metadata.get("shape_type", "")) != SHAPE_TYPE_ORIENTED_BOX:
		return Vector2.ZERO
	var scale: float = GameScale.squadron_base_diameter_px
	if scale <= 0.0:
		return Vector2.ZERO
	return Vector2(
			float(metadata.get("width_factor", 0.0)) * scale,
			float(metadata.get("height_factor", 0.0)) * scale)


static func _play_area_size_px(game_state: GameState) -> Vector2:
	if GameScale.ruler_length_px > 0.0:
		var rulers: Vector2 = GAME_SCALE_SCRIPT.map_play_area_rulers(_map_filename(game_state))
		return rulers * GameScale.ruler_length_px
	return GameScale.play_area_size_px


static func _map_filename(game_state: GameState) -> String:
	var raw_map: Variant = game_state.objectives.get(KEY_MAP, {})
	if raw_map is Dictionary:
		return str((raw_map as Dictionary).get(KEY_FILENAME, ""))
	return ""


static func _distance_band_px(band: int) -> float:
	var index: int = band - 1
	if index < 0 or index >= GameScale.distance_bands_px.size():
		return 0.0
	return GameScale.distance_bands_px[index]


static func _dict_array_from(raw_values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_values is Array:
		return result
	for raw_value: Variant in raw_values as Array:
		if raw_value is Dictionary:
			result.append((raw_value as Dictionary).duplicate(true))
	return result
