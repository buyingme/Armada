## Pure authority-side derivation for one committed Ship Maneuver course.
## It reads canonical model state and never consults scene tokens, ghosts,
## caller-authored transforms, or presentation overlap flags.
class_name ManeuverAuthority
extends RefCounted


const EPSILON: float = 0.00001


## Returns an internal exact derivation dictionary with `ok` and `reason`.
## Successful results contain the actual final transform, stable collision
## evidence, affected Squadron identities, and play-area disposition.
static func derive(game_state: GameState, owner_player: int, ship_index: int,
		candidate_speed: int, yaw_clicks: Array,
		yaw_bonus_joint: int) -> Dictionary:
	var reason: String = validate_course_intent(
			game_state, owner_player, ship_index, candidate_speed,
			yaw_clicks, yaw_bonus_joint)
	if not reason.is_empty():
		return {"ok": false, "reason": reason}
	var ship: ShipInstance = game_state.get_ship(owner_player, ship_index)
	var play_area: Vector2 = GameScale.play_area_size_px
	var start_transform := Transform2D(
			deg_to_rad(ship.rotation_deg),
			Vector2(ship.pos_x * play_area.x, ship.pos_y * play_area.y))
	var navigation_chart: Array = ManeuverRuleResolver.apply_yaw_modifiers(
			ship.ship_data.navigation_chart, ship, game_state)
	var committed_tool: ManeuverToolState = _course_tool(
			ship, candidate_speed, yaw_clicks, yaw_bonus_joint,
			navigation_chart)
	if committed_tool == null:
		return {"ok": false, "reason": "Unable to derive committed course."}
	var tool_side: String = committed_tool.compute_ghost_side()
	var attempted_transform: Transform2D = _transform_for_speed(
			ship, start_transform, committed_tool, tool_side,
			candidate_speed)
	var other_ships: Array[Dictionary] = _other_ship_bases(
			game_state, owner_player, ship_index, play_area)
	var attempted_overlaps: Array[Dictionary] = _overlapping_ships(
			ship.ship_data.ship_size, attempted_transform, other_ships)
	var final_transform: Transform2D = attempted_transform
	var temporary_speed: int = candidate_speed
	if not attempted_overlaps.is_empty():
		while temporary_speed > 0:
			temporary_speed -= 1
			var reduced_yaw: Array = yaw_clicks.slice(0, temporary_speed)
			var reduced_bonus: int = yaw_bonus_joint \
					if yaw_bonus_joint < temporary_speed else -1
			var reduced_tool: ManeuverToolState = _course_tool(
					ship, temporary_speed, reduced_yaw, reduced_bonus,
					navigation_chart)
			final_transform = _transform_for_speed(
					ship, start_transform, reduced_tool, tool_side,
					temporary_speed)
			if _overlapping_ships(ship.ship_data.ship_size,
					final_transform, other_ships).is_empty():
				break
	var collision: Dictionary = {"kind": "none"}
	if not attempted_overlaps.is_empty():
		var closest: Dictionary = _closest_collision(
				attempted_transform.origin, attempted_overlaps)
		collision = {
			"kind": "closest_ship",
			"target_owner_player": int(closest["owner_player"]),
			"target_ship_index": int(closest["ship_index"]),
		}
	var normalized_position := Vector2(
			final_transform.origin.x / play_area.x,
			final_transform.origin.y / play_area.y)
	return {
		"ok": true,
		"reason": "",
		"tool_side": tool_side,
		"attempted_transform": attempted_transform,
		"final_transform": final_transform,
		"temporary_final_speed": temporary_speed,
		"pos_x": normalized_position.x,
		"pos_y": normalized_position.y,
		"rotation_deg": rad_to_deg(final_transform.get_rotation()),
		"ship_collision": collision,
		"affected_squadrons": _affected_squadrons(
				game_state, ship.ship_data.ship_size,
				final_transform, play_area),
		"outside_play_area": not _base_inside_play_area(
				ship.ship_data.ship_size, final_transform, play_area),
	}


static func validate_course_intent(game_state: GameState, owner_player: int,
		ship_index: int, candidate_speed: int, yaw_clicks: Array,
		yaw_bonus_joint: int) -> String:
	if game_state == null:
		return "No active game state."
	var ship: ShipInstance = game_state.get_ship(owner_player, ship_index)
	if ship == null or ship.ship_data == null:
		return "Ship not found."
	if ship.is_destroyed():
		return "Ship is destroyed."
	if candidate_speed < 0 or candidate_speed > ship.ship_data.max_speed \
			or candidate_speed > ship.ship_data.navigation_chart.size():
		return "Invalid speed."
	if yaw_clicks.size() != candidate_speed:
		return "Yaw click count does not match speed."
	if yaw_bonus_joint < -1 or yaw_bonus_joint >= candidate_speed:
		return "Invalid yaw bonus joint."
	var sources: Dictionary = derive_navigate_sources(
			ship, candidate_speed, yaw_bonus_joint)
	if not bool(sources.get("ok", false)):
		return str(sources.get("reason", "Invalid Navigate result."))
	var chart: Array = ManeuverRuleResolver.apply_yaw_modifiers(
			ship.ship_data.navigation_chart, ship, game_state)
	for index: int in range(candidate_speed):
		if typeof(yaw_clicks[index]) != TYPE_INT:
			return "Yaw clicks must be integers."
		var maximum: int = ManeuverCalculator.get_max_yaw(
				chart, candidate_speed, index)
		if index == yaw_bonus_joint and maximum < \
				ManeuverToolState.MAX_CLICKS_PER_JOINT:
			maximum += 1
		if absi(int(yaw_clicks[index])) > mini(
				maximum, ManeuverToolState.MAX_CLICKS_PER_JOINT):
			return "Yaw clicks exceed navigation chart limits."
	return ""


## Re-derives the stable affected Squadron set from the applied canonical
## final transform. It is used after movement and during reconstruction.
static func derive_affected_squadrons_from_canonical(game_state: GameState,
		owner_player: int, ship_index: int) -> Array[Dictionary]:
	if game_state == null:
		return []
	var ship: ShipInstance = game_state.get_ship(owner_player, ship_index)
	if ship == null or ship.is_destroyed() or ship.ship_data == null:
		return []
	var play_area: Vector2 = GameScale.play_area_size_px
	var transform := Transform2D(deg_to_rad(ship.rotation_deg),
			ship.get_pixel_position(play_area))
	return _affected_squadrons(game_state, ship.ship_data.ship_size,
			transform, play_area)


static func canonical_ship_is_inside_play_area(game_state: GameState,
		owner_player: int, ship_index: int) -> bool:
	if game_state == null:
		return false
	var ship: ShipInstance = game_state.get_ship(owner_player, ship_index)
	if ship == null or ship.ship_data == null:
		return false
	var play_area: Vector2 = GameScale.play_area_size_px
	return _base_inside_play_area(ship.ship_data.ship_size,
			Transform2D(deg_to_rad(ship.rotation_deg),
					ship.get_pixel_position(play_area)), play_area)


## Derives the minimum Navigate source set for the selected result.
static func derive_navigate_sources(ship: ShipInstance,
		candidate_speed: int, yaw_bonus_joint: int) -> Dictionary:
	if ship == null or ship.ship_data == null:
		return {"ok": false, "reason": "Ship not found."}
	var delta: int = candidate_speed - ship.current_speed
	var needs_yaw: bool = yaw_bonus_joint >= 0
	var dial_available: bool = false
	if ship.command_dial_stack != null:
		var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
		dial_available = not revealed.is_empty() \
				and int(revealed.get("command", -1)) \
						== int(Constants.CommandType.NAVIGATE)
	var token_available: bool = ship.command_tokens != null \
			and ship.command_tokens.has_token(Constants.CommandType.NAVIGATE)
	if delta == 0 and not needs_yaw:
		return {"ok": true, "navigate_dial_spent": false,
			"navigate_token_spent": false,
			"navigate_speed_changed": false}
	if absi(delta) > 2:
		return {"ok": false, "reason": "Navigate speed budget exceeded."}
	var spend_dial: bool = false
	var spend_token: bool = false
	if needs_yaw:
		if not dial_available:
			return {"ok": false,
				"reason": "Navigate dial required for yaw bonus."}
		spend_dial = true
		spend_token = absi(delta) > 1
	elif delta != 0:
		if dial_available:
			spend_dial = true
			spend_token = absi(delta) > 1
		else:
			spend_token = true
	if spend_token and not token_available:
		return {"ok": false, "reason": "Navigate token required."}
	return {"ok": true,
		"navigate_dial_spent": spend_dial,
		"navigate_token_spent": spend_token,
		"navigate_speed_changed": delta != 0}


static func _course_tool(ship: ShipInstance, speed: int, yaw_clicks: Array,
		yaw_bonus_joint: int, navigation_chart: Array) -> ManeuverToolState:
	var tool := ManeuverToolState.new()
	tool.setup(speed, navigation_chart, ship.ship_data.ship_size,
			ship.ship_data.max_speed)
	return tool if tool.configure_authoritative_course(
			speed, yaw_clicks, yaw_bonus_joint) else null


static func _transform_for_speed(ship: ShipInstance,
		start_transform: Transform2D, tool: ManeuverToolState,
		tool_side: String, speed: int) -> Transform2D:
	if speed == 0:
		return start_transform
	var attachment: Dictionary = \
			ManeuverToolState.compute_attachment_from_ship_transform(
					start_transform, ship.ship_data.ship_size, tool_side)
	return tool.compute_final_transform(
			attachment["position"], float(attachment["rotation"]), tool_side)


static func _other_ship_bases(game_state: GameState, moving_owner: int,
		moving_index: int, play_area: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for owner: int in range(game_state.player_states.size()):
		var player_state: PlayerState = game_state.get_player_state(owner)
		if player_state == null:
			continue
		for index: int in range(player_state.ships.size()):
			if owner == moving_owner and index == moving_index:
				continue
			var ship: ShipInstance = game_state.get_ship(owner, index)
			if ship == null or ship.is_destroyed() or ship.ship_data == null:
				continue
			var transform := Transform2D(deg_to_rad(ship.rotation_deg),
					Vector2(ship.pos_x * play_area.x, ship.pos_y * play_area.y))
			result.append({"owner_player": owner, "ship_index": index,
				"base": ShipBase.new(ship.ship_data.ship_size, transform)})
	return result


static func _overlapping_ships(moving_size: Constants.ShipSize,
		moving_transform: Transform2D,
		other_ships: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var moving_polygon: PackedVector2Array = ShipBase.new(
			moving_size, moving_transform).get_base_polygon()
	for entry: Dictionary in other_ships:
		var other_base: ShipBase = entry["base"] as ShipBase
		if _convex_polygons_have_positive_overlap(
				moving_polygon, other_base.get_base_polygon()):
			result.append(entry)
	return result


static func _closest_collision(origin: Vector2,
		overlaps: Array[Dictionary]) -> Dictionary:
	var closest: Dictionary = {}
	var best_distance: float = INF
	for entry: Dictionary in overlaps:
		var base: ShipBase = entry["base"] as ShipBase
		var distance: float = origin.distance_squared_to(
				base.ship_transform.origin)
		var identity_precedes: bool = closest.is_empty() \
				or int(entry["owner_player"]) < int(closest["owner_player"]) \
				or (int(entry["owner_player"]) == int(closest["owner_player"])
					and int(entry["ship_index"]) < int(closest["ship_index"]))
		if distance < best_distance - EPSILON \
				or (absf(distance - best_distance) <= EPSILON
					and identity_precedes):
			closest = entry
			best_distance = distance
	return closest


static func _affected_squadrons(game_state: GameState,
		moving_size: Constants.ShipSize, final_transform: Transform2D,
		play_area: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var moving_base := ShipBase.new(moving_size, final_transform)
	for owner: int in range(game_state.player_states.size()):
		var player_state: PlayerState = game_state.get_player_state(owner)
		if player_state == null:
			continue
		for index: int in range(player_state.squadrons.size()):
			var squadron: SquadronInstance = game_state.get_squadron(owner, index)
			if squadron == null or squadron.is_destroyed():
				continue
			var base := SquadronBase.new(squadron.get_pixel_position(play_area))
			if base.overlaps_ship(moving_base):
				result.append({"owner": owner, "squadron_index": index})
	return result


static func _base_inside_play_area(ship_size: Constants.ShipSize,
		transform: Transform2D, play_area: Vector2) -> bool:
	for point: Vector2 in ShipBase.new(ship_size, transform).get_base_polygon():
		if point.x < -EPSILON or point.y < -EPSILON \
				or point.x > play_area.x + EPSILON \
				or point.y > play_area.y + EPSILON:
			return false
	return true


## Strict convex SAT: touching edges have zero depth and are not overlap.
static func _convex_polygons_have_positive_overlap(a: PackedVector2Array,
		b: PackedVector2Array) -> bool:
	for polygon: PackedVector2Array in [a, b]:
		for index: int in range(polygon.size()):
			var edge: Vector2 = polygon[(index + 1) % polygon.size()] \
					- polygon[index]
			var axis := Vector2(-edge.y, edge.x).normalized()
			var projection_a: Vector2 = _projection(a, axis)
			var projection_b: Vector2 = _projection(b, axis)
			var depth: float = minf(projection_a.y, projection_b.y) \
					- maxf(projection_a.x, projection_b.x)
			if depth <= EPSILON:
				return false
	return true


static func _projection(polygon: PackedVector2Array,
		axis: Vector2) -> Vector2:
	var minimum: float = INF
	var maximum: float = -INF
	for point: Vector2 in polygon:
		var value: float = point.dot(axis)
		minimum = minf(minimum, value)
		maximum = maxf(maximum, value)
	return Vector2(minimum, maximum)
