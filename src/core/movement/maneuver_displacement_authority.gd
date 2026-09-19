## Pure model-space authority for one complete Squadron displacement batch.
## Tentative order and UI state never enter this analysis.
class_name ManeuverDisplacementAuthority
extends RefCounted


const EPSILON: float = 0.001
const TOUCH_TOLERANCE: float = 5.0
const CONTACT_GAP: float = 1.0
const ARC_STEPS: int = 48


## Validates exact identity coverage, global placement legality, and the
## authority-derived maximum total/direct-touch counts.
static func analyze_batch(game_state: GameState, moving_owner: int,
		moving_ship_index: int, affected: Array,
		placements: Array, excluded: Array) -> Dictionary:
	var invalid: Dictionary = _invalid_result(0, 0, 0, 0,
			"Invalid displacement batch.")
	if game_state == null:
		return invalid
	var moving: ShipInstance = game_state.get_ship(
			moving_owner, moving_ship_index)
	if moving == null or moving.is_destroyed() or moving.ship_data == null:
		return invalid
	var identities: Array[Dictionary] = _canonical_identities(affected)
	if identities.size() != affected.size():
		return invalid
	var submitted: Dictionary = _validate_submitted_union(
			game_state, identities, placements, excluded)
	if not bool(submitted.get("ok", false)):
		return _invalid_result(0, placements.size(), 0, 0,
				str(submitted.get("reason", "Invalid identity union.")))
	var play_area: Vector2 = GameScale.play_area_size_px
	var moved_base := ShipBase.new(moving.ship_data.ship_size,
			Transform2D(deg_to_rad(moving.rotation_deg),
					moving.get_pixel_position(play_area)))
	var fixed_ships: Array[ShipBase] = _fixed_ships(
			game_state, moving_owner, moving_ship_index, play_area)
	var fixed_squadrons: Array[SquadronBase] = _fixed_squadrons(
			game_state, identities, play_area)
	var submitted_geometry: Dictionary = _validate_positions(
			placements, moved_base, fixed_ships, fixed_squadrons, play_area)
	var maxima: Dictionary = _derive_maxima(
			identities.size(), moved_base, fixed_ships, fixed_squadrons,
			play_area, placements)
	var required_count: int = int(maxima.get("placeable_count", 0))
	var required_direct: int = int(maxima.get("direct_touch_count", 0))
	var submitted_direct: int = int(
			submitted_geometry.get("direct_touch_count", 0))
	if not bool(submitted_geometry.get("ok", false)):
		return _invalid_result(required_count, placements.size(),
				required_direct, submitted_direct,
				str(submitted_geometry.get("reason", "Illegal placement.")))
	if placements.size() != required_count \
			or submitted_direct != required_direct:
		return _invalid_result(required_count, placements.size(),
				required_direct, submitted_direct,
				"Submitted batch is below an authoritative maximum.")
	return {
		"ok": true,
		"reason": "",
		"required_placeable_count": required_count,
		"submitted_placeable_count": placements.size(),
		"required_direct_touch_count": required_direct,
		"submitted_direct_touch_count": submitted_direct,
	}


static func _derive_maxima(count: int, moved_base: ShipBase,
		fixed_ships: Array[ShipBase], fixed_squadrons: Array[SquadronBase],
		play_area: Vector2, submitted: Array) -> Dictionary:
	if count <= 0:
		return {"placeable_count": 0, "direct_touch_count": 0}
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var direct: Array[Vector2] = _direct_candidates(
			moved_base, radius, fixed_ships, fixed_squadrons, play_area)
	# Legal submitted direct positions are also exact model-space witnesses;
	# including them prevents candidate discretisation from rejecting a legal
	# player-selected maximum.
	for raw: Variant in submitted:
		if not raw is Dictionary:
			continue
		var data: Dictionary = raw as Dictionary
		var point := Vector2(float(data.get("pos_x", -1.0)) * play_area.x,
				float(data.get("pos_y", -1.0)) * play_area.y)
		if _is_direct_position(point, radius, moved_base) \
				and _position_clear(point, radius, moved_base, fixed_ships,
						fixed_squadrons, play_area):
			_append_unique_point(direct, point)
	for total: int in range(count, 0, -1):
		for desired_direct: int in range(mini(total, direct.size()), 0, -1):
			if _arrangement_exists(direct, desired_direct,
					total - desired_direct, radius, moved_base, fixed_ships,
					fixed_squadrons, play_area, submitted):
				return {"placeable_count": total,
					"direct_touch_count": desired_direct}
	return {"placeable_count": 0, "direct_touch_count": 0}


static func _arrangement_exists(direct_candidates: Array[Vector2],
		direct_needed: int, secondary_needed: int, radius: float,
		moved_base: ShipBase, fixed_ships: Array[ShipBase],
		fixed_squadrons: Array[SquadronBase], play_area: Vector2,
		submitted: Array, start: int = 0,
		selected: Array[Vector2] = []) -> bool:
	if direct_needed == 0:
		var secondary: Array[Vector2] = _secondary_candidates(
				selected, radius, moved_base, fixed_ships,
				fixed_squadrons, play_area, submitted)
		var witness: Array[Vector2] = []
		return _find_non_overlapping_subset(
				secondary, secondary_needed, radius, selected, witness)
	if direct_candidates.size() - start < direct_needed:
		return false
	for index: int in range(start, direct_candidates.size()):
		var point: Vector2 = direct_candidates[index]
		if _overlaps_any(point, radius, selected):
			continue
		var next: Array[Vector2] = selected.duplicate()
		next.append(point)
		if _arrangement_exists(direct_candidates, direct_needed - 1,
				secondary_needed, radius, moved_base, fixed_ships,
				fixed_squadrons, play_area, submitted, index + 1, next):
			return true
	return false


static func _validate_positions(placements: Array, moved_base: ShipBase,
		fixed_ships: Array[ShipBase], fixed_squadrons: Array[SquadronBase],
		play_area: Vector2) -> Dictionary:
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var positions: Array[Vector2] = []
	var direct: Array[Vector2] = []
	for raw: Variant in placements:
		var data: Dictionary = raw as Dictionary
		var point := Vector2(float(data["pos_x"]) * play_area.x,
				float(data["pos_y"]) * play_area.y)
		if not _position_clear(point, radius, moved_base, fixed_ships,
				fixed_squadrons, play_area) \
				or _overlaps_any(point, radius, positions):
			return {"ok": false, "reason": "A placement overlaps or exits play.",
				"direct_touch_count": direct.size()}
		positions.append(point)
		if _is_direct_position(point, radius, moved_base):
			direct.append(point)
	if not positions.is_empty() and direct.is_empty():
		return {"ok": false,
			"reason": "At least one placed Squadron must touch the moved ship.",
			"direct_touch_count": 0}
	for point: Vector2 in positions:
		if point in direct:
			continue
		var secondary_touch: bool = false
		for anchor: Vector2 in direct:
			var gap: float = point.distance_to(anchor) - radius * 2.0
			if absf(gap) <= TOUCH_TOLERANCE:
				secondary_touch = true
				break
		if not secondary_touch:
			return {"ok": false,
				"reason": "A secondary Squadron does not touch a direct Squadron.",
				"direct_touch_count": direct.size()}
	return {"ok": true, "reason": "",
		"direct_touch_count": direct.size()}


static func _direct_candidates(base: ShipBase, radius: float,
		fixed_ships: Array[ShipBase], fixed_squadrons: Array[SquadronBase],
		play_area: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var step: float = maxf(2.0, radius * 0.2)
	var hw: float = base.half_width_px
	var hl: float = base.half_length_px
	var local_points: Array[Vector2] = []
	var x: float = -hw
	while x <= hw + EPSILON:
		local_points.append(Vector2(x, -hl - radius - CONTACT_GAP))
		local_points.append(Vector2(x, hl + radius + CONTACT_GAP))
		x += step
	var y: float = -hl
	while y <= hl + EPSILON:
		local_points.append(Vector2(-hw - radius - CONTACT_GAP, y))
		local_points.append(Vector2(hw + radius + CONTACT_GAP, y))
		y += step
	var corners: Array[Vector2] = [
		Vector2(-hw, -hl), Vector2(hw, -hl),
		Vector2(hw, hl), Vector2(-hw, hl),
	]
	var angle_starts: Array[float] = [PI, -PI * 0.5, 0.0, PI * 0.5]
	for index: int in range(corners.size()):
		for arc_index: int in range(ARC_STEPS / 4 + 1):
			var angle: float = angle_starts[index] \
					+ (PI * 0.5) * float(arc_index) / float(ARC_STEPS / 4)
			local_points.append(corners[index] + Vector2.from_angle(angle) \
					* (radius + CONTACT_GAP))
	for local: Vector2 in local_points:
		var point: Vector2 = base.ship_transform * local
		if _position_clear(point, radius, base, fixed_ships,
				fixed_squadrons, play_area):
			_append_unique_point(result, point)
	return result


static func _secondary_candidates(direct: Array[Vector2], radius: float,
		moved_base: ShipBase, fixed_ships: Array[ShipBase],
		fixed_squadrons: Array[SquadronBase], play_area: Vector2,
		submitted: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for anchor: Vector2 in direct:
		for index: int in range(ARC_STEPS):
			var point: Vector2 = anchor + Vector2.from_angle(
					TAU * float(index) / float(ARC_STEPS)) \
					* (radius * 2.0 + CONTACT_GAP)
			if not _is_direct_position(point, radius, moved_base) \
					and _position_clear(point, radius, moved_base,
							fixed_ships, fixed_squadrons, play_area):
				_append_unique_point(result, point)
	for raw: Variant in submitted:
		if not raw is Dictionary:
			continue
		var data: Dictionary = raw as Dictionary
		var point := Vector2(float(data.get("pos_x", -1.0)) * play_area.x,
				float(data.get("pos_y", -1.0)) * play_area.y)
		if _is_direct_position(point, radius, moved_base) \
				or not _position_clear(point, radius, moved_base, fixed_ships,
						fixed_squadrons, play_area):
			continue
		for anchor: Vector2 in direct:
			if absf(point.distance_to(anchor) - radius * 2.0) \
					<= TOUCH_TOLERANCE:
				_append_unique_point(result, point)
				break
	return result


static func _find_non_overlapping_subset(candidates: Array[Vector2],
		desired: int, radius: float, fixed: Array[Vector2],
		out: Array[Vector2], start: int = 0) -> bool:
	if desired == 0:
		out.clear()
		return true
	if candidates.size() - start < desired:
		return false
	for index: int in range(start, candidates.size()):
		var point: Vector2 = candidates[index]
		if _overlaps_any(point, radius, fixed):
			continue
		var tail: Array[Vector2] = []
		var next_fixed: Array[Vector2] = fixed.duplicate()
		next_fixed.append(point)
		if _find_non_overlapping_subset(candidates, desired - 1, radius,
				next_fixed, tail, index + 1):
			out.clear()
			out.append(point)
			out.append_array(tail)
			return true
	return false


static func _position_clear(point: Vector2, radius: float,
		moved_base: ShipBase, fixed_ships: Array[ShipBase],
		fixed_squadrons: Array[SquadronBase], play_area: Vector2) -> bool:
	if point.x - radius < -EPSILON or point.y - radius < -EPSILON \
			or point.x + radius > play_area.x + EPSILON \
			or point.y + radius > play_area.y + EPSILON:
		return false
	var base := SquadronBase.new(point, radius)
	if base.overlaps_ship(moved_base):
		return false
	for ship: ShipBase in fixed_ships:
		if base.overlaps_ship(ship):
			return false
	for squadron: SquadronBase in fixed_squadrons:
		if point.distance_to(squadron.position) \
				< radius + squadron.radius_px - EPSILON:
			return false
	return true


static func _is_direct_position(point: Vector2, radius: float,
		base: ShipBase) -> bool:
	var closest: Vector2 = Geometry2DHelper.closest_point_on_polygon(
			point, base.get_base_polygon())
	return absf(point.distance_to(closest) - radius) <= TOUCH_TOLERANCE \
			and not SquadronBase.new(point, radius).overlaps_ship(base)


static func _overlaps_any(point: Vector2, radius: float,
		others: Array[Vector2]) -> bool:
	for other: Vector2 in others:
		if point.distance_to(other) < radius * 2.0 - EPSILON:
			return true
	return false


static func _fixed_ships(game_state: GameState, moving_owner: int,
		moving_index: int, play_area: Vector2) -> Array[ShipBase]:
	var result: Array[ShipBase] = []
	for owner: int in range(game_state.player_states.size()):
		var player: PlayerState = game_state.get_player_state(owner)
		for index: int in range(player.ships.size()):
			if owner == moving_owner and index == moving_index:
				continue
			var ship: ShipInstance = game_state.get_ship(owner, index)
			if ship != null and not ship.is_destroyed():
				result.append(ShipBase.new(ship.ship_data.ship_size,
						Transform2D(deg_to_rad(ship.rotation_deg),
								ship.get_pixel_position(play_area))))
	return result


static func _fixed_squadrons(game_state: GameState, affected: Array[Dictionary],
		play_area: Vector2) -> Array[SquadronBase]:
	var affected_keys: Dictionary = {}
	for identity: Dictionary in affected:
		affected_keys[_identity_key(identity)] = true
	var result: Array[SquadronBase] = []
	for owner: int in range(game_state.player_states.size()):
		var player: PlayerState = game_state.get_player_state(owner)
		for index: int in range(player.squadrons.size()):
			if affected_keys.has("%d:%d" % [owner, index]):
				continue
			var squadron: SquadronInstance = game_state.get_squadron(owner, index)
			if squadron != null and not squadron.is_destroyed():
				result.append(SquadronBase.new(
						squadron.get_pixel_position(play_area)))
	return result


static func _validate_submitted_union(game_state: GameState,
		affected: Array[Dictionary], placements: Array,
		excluded: Array) -> Dictionary:
	var required: Dictionary = {}
	for identity: Dictionary in affected:
		required[_identity_key(identity)] = true
	var submitted: Dictionary = {}
	for raw: Variant in placements:
		if not raw is Dictionary:
			return {"ok": false, "reason": "Invalid placement entry."}
		var data: Dictionary = raw as Dictionary
		if not _has_exact_keys(data,
				["owner", "squadron_index", "pos_x", "pos_y"]) \
				or typeof(data["owner"]) != TYPE_INT \
				or typeof(data["squadron_index"]) != TYPE_INT \
				or typeof(data["pos_x"]) != TYPE_FLOAT \
				or typeof(data["pos_y"]) != TYPE_FLOAT \
				or not is_finite(float(data["pos_x"])) \
				or not is_finite(float(data["pos_y"])):
			return {"ok": false, "reason": "Invalid placement shape."}
		var key: String = "%d:%d" % [data["owner"], data["squadron_index"]]
		if not required.has(key) or submitted.has(key) \
				or game_state.get_squadron(
						int(data["owner"]), int(data["squadron_index"])) == null:
			return {"ok": false, "reason": "Invalid placement identity."}
		submitted[key] = true
	for raw: Variant in excluded:
		if not raw is Dictionary:
			return {"ok": false, "reason": "Invalid exclusion entry."}
		var data: Dictionary = raw as Dictionary
		if not _has_exact_keys(data, ["owner", "squadron_index"]) \
				or typeof(data["owner"]) != TYPE_INT \
				or typeof(data["squadron_index"]) != TYPE_INT:
			return {"ok": false, "reason": "Invalid exclusion shape."}
		var key: String = "%d:%d" % [data["owner"], data["squadron_index"]]
		if not required.has(key) or submitted.has(key):
			return {"ok": false, "reason": "Invalid exclusion identity."}
		submitted[key] = true
	return {"ok": submitted.size() == required.size(),
		"reason": "Incomplete affected identity union."}


static func _canonical_identities(raw: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	for value: Variant in raw:
		if not value is Dictionary:
			return []
		var data: Dictionary = value as Dictionary
		if not _has_exact_keys(data, ["owner", "squadron_index"]) \
				or typeof(data["owner"]) != TYPE_INT \
				or typeof(data["squadron_index"]) != TYPE_INT:
			return []
		var key: String = _identity_key(data)
		if seen.has(key):
			return []
		seen[key] = true
		result.append({"owner": int(data["owner"]),
			"squadron_index": int(data["squadron_index"])})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _identity_key(a) < _identity_key(b))
	return result


static func _identity_key(identity: Dictionary) -> String:
	return "%d:%d" % [int(identity.get("owner", -1)),
			int(identity.get("squadron_index", -1))]


static func _append_unique_point(points: Array[Vector2], point: Vector2) -> void:
	for existing: Vector2 in points:
		if existing.distance_squared_to(point) <= 0.01:
			return
	points.append(point)


static func _invalid_result(required_count: int, submitted_count: int,
		required_direct: int, submitted_direct: int,
		reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"required_placeable_count": required_count,
		"submitted_placeable_count": submitted_count,
		"required_direct_touch_count": required_direct,
		"submitted_direct_touch_count": submitted_direct,
	}


static func _has_exact_keys(data: Dictionary,
		expected: Array[String]) -> bool:
	if data.size() != expected.size():
		return false
	for key: String in expected:
		if not data.has(key):
			return false
	return true
