## TokenMover
##
## Pure logic for debug-mode token movement: resolves a desired world position
## into a valid position respecting token–token and deployment-zone collisions.
##
## Collision model (DBG-020, DBG-022, DBG-032):
##   1. Apply boundary constraints (play area + deployment zone) to the desired
##      position (the mouse cursor).
##   2. If the constrained position does not overlap any token, return it.
##   3. Otherwise, for EACH blocker the token overlaps, compute the closest
##      non-overlapping position by projecting outward from the blocker along
##      the direction from the blocker's centre to the constrained position
##      (Minkowski-sum boundary push-out).
##   4. Among all push-out candidates that satisfy every constraint (no overlap
##      with ANY token, within deployment zone, within play area), return the
##      one whose centre is closest to the constrained position.
##   5. Fallback: if no single-blocker push-out is conflict-free, keep the
##      token at its current position.
##
## Jump-past (former DBG-021) is subsumed: if the footprint fits at the desired
## position, step 2 returns it immediately — no special case needed.
##
## Deployment zone boundaries continue to act as walls (DBG-032).
##
## This class is scene-tree independent (RefCounted).
class_name TokenMover
extends RefCounted


## Logger for diagnostic output.
var _log: GameLogger = GameLogger.new("TokenMover")

## Maximum binary-search iterations for push-out resolution.
const MAX_BINARY_STEPS: int = 20

## Small epsilon for overlap tolerance (pixels).
const OVERLAP_EPSILON: float = 1.0


## Resolves a desired position for a ship token, accounting for collisions
## with other tokens and (optionally) deployment zone boundaries.
## Returns the best valid position — the closest legal position to the mouse.
##
## [param desired_pos] — where the mouse wants to place the token (world).
## [param current_pos] — the token's current world position (fallback).
## [param ship_size] — the size class of the moving ship.
## [param rotation_rad] — the ship's current rotation.
## [param faction] — the moving token's faction (for deployment zone).
## [param other_ship_rects] — Array of Dictionaries: {position, rotation, half_w, half_l}.
## [param other_squad_circles] — Array of Dictionaries: {position, radius}.
## [param deploy_line_y_top] — Y of the top deployment line (-1 to disable).
## [param deploy_line_y_bottom] — Y of the bottom deployment line (-1 to disable).
## [param play_area_side] — legacy square play area side in pixels.
## [param enforce_deploy_zones] — when false, deployment zone clamping is
##     skipped (debug mode). Zone logic is preserved for full-game use.
## DBG-020, DBG-022, DBG-032, DBG-034
func resolve_ship_position(
		desired_pos: Vector2,
		current_pos: Vector2,
		ship_size: Constants.ShipSize,
		rotation_rad: float,
		faction: Constants.Faction,
		other_ship_rects: Array,
		other_squad_circles: Array,
		deploy_line_y_top: float,
		deploy_line_y_bottom: float,
		play_area_side: float,
		enforce_deploy_zones: bool = true
) -> Vector2:
	return resolve_ship_position_in_area(
			desired_pos,
			current_pos,
			ship_size,
			rotation_rad,
			faction,
			other_ship_rects,
			other_squad_circles,
			deploy_line_y_top,
			deploy_line_y_bottom,
			_square_play_area_size(play_area_side),
			enforce_deploy_zones)


## Resolves a desired ship position inside a rectangular play area.
func resolve_ship_position_in_area(
		desired_pos: Vector2,
		current_pos: Vector2,
		ship_size: Constants.ShipSize,
		rotation_rad: float,
		faction: Constants.Faction,
		other_ship_rects: Array,
		other_squad_circles: Array,
		deploy_line_y_top: float,
		deploy_line_y_bottom: float,
		play_area_size: Vector2,
		enforce_deploy_zones: bool = true
) -> Vector2:
	var base_size: Vector2 = GameScale.get_base_size(ship_size)
	var half_w: float = base_size.x * 0.5
	var half_l: float = base_size.y * 0.5

	# Step 1 — apply boundary constraints to the desired position.
	var candidate: Vector2 = _clamp_ship_candidate(
			desired_pos, half_w, half_l, rotation_rad, faction,
			deploy_line_y_top, deploy_line_y_bottom, play_area_size,
			enforce_deploy_zones)

	# Step 2 — if no overlap, return immediately.
	if not _ship_overlaps_any(candidate, rotation_rad, half_w, half_l,
			other_ship_rects, other_squad_circles):
		return candidate

	# Steps 3+4 — primary push-out, then cascade fallback.
	return _resolve_ship_pushout(
			desired_pos, current_pos, candidate, rotation_rad,
			half_w, half_l, faction, other_ship_rects, other_squad_circles,
			deploy_line_y_top, deploy_line_y_bottom, play_area_size,
			enforce_deploy_zones)


## Clamps a desired position to play-area and (optionally) deployment zone.
func _clamp_ship_candidate(
		pos: Vector2, hw: float, hl: float, rot: float,
		faction: Constants.Faction,
		top_y: float, bottom_y: float, play_area_size: Vector2,
		enforce_zones: bool) -> Vector2:
	var result: Vector2 = _clamp_rotated_rect_to_play_area(
			pos, hw, hl, rot, play_area_size)
	if enforce_zones:
		result = _apply_deploy_zone_ship(
				result, hw, hl, rot, faction, top_y, bottom_y)
	return result


## Performs primary + cascade push-out for a ship, returning the best
## valid position or [param current_pos] as fallback.
func _resolve_ship_pushout(
		desired_pos: Vector2, current_pos: Vector2,
		candidate: Vector2, rot: float, hw: float, hl: float,
		faction: Constants.Faction,
		other_ships: Array, other_squads: Array,
		top_y: float, bottom_y: float, play_area_size: Vector2,
		enforce_zones: bool) -> Vector2:
	var primary: Dictionary = _collect_ship_pushouts(
			candidate, rot, hw, hl, other_ships, other_squads,
			faction, top_y, bottom_y, play_area_size, enforce_zones)
	var best: Vector2 = _pick_closest(primary.valid, candidate)
	if best != Vector2.INF:
		_log.debug("Ship resolved (primary): mouse=(%.0f,%.0f) result=(%.0f,%.0f) v=%d i=%d" % [
				desired_pos.x, desired_pos.y, best.x, best.y,
				primary.valid.size(), primary.invalid.size()])
		return best
	best = _cascade_ship_pushout(
			primary.invalid, rot, hw, hl, other_ships, other_squads,
			faction, top_y, bottom_y, play_area_size, enforce_zones, candidate)
	if best != Vector2.INF:
		_log.debug("Ship resolved (cascade): mouse=(%.0f,%.0f) result=(%.0f,%.0f)" % [
				desired_pos.x, desired_pos.y, best.x, best.y])
		return best
	_log.debug("Ship push-out fallback to current_pos (mouse=%.0f,%.0f)" % [
			desired_pos.x, desired_pos.y])
	return current_pos


## Re-pushes each failed candidate from all blockers (cascade step).
func _cascade_ship_pushout(
		invalid: Array, rot: float, hw: float, hl: float,
		other_ships: Array, other_squads: Array,
		faction: Constants.Faction,
		top_y: float, bottom_y: float, play_area_size: Vector2,
		enforce_zones: bool, candidate: Vector2) -> Vector2:
	var all_secondary: Array = []
	for pos: Vector2 in invalid:
		var secondary: Dictionary = _collect_ship_pushouts(
				pos, rot, hw, hl, other_ships, other_squads,
				faction, top_y, bottom_y, play_area_size, enforce_zones)
		all_secondary.append_array(secondary.valid)
	return _pick_closest(all_secondary, candidate)


## Resolves a desired position for a squadron token.
## Same projection-based approach as ship but with circular footprint.
## [param enforce_deploy_zones] — when false, zone clamping is skipped.
## DBG-020, DBG-022, DBG-032, DBG-034
func resolve_squadron_position(
		desired_pos: Vector2,
		current_pos: Vector2,
		radius: float,
		faction: Constants.Faction,
		other_ship_rects: Array,
		other_squad_circles: Array,
		deploy_line_y_top: float,
		deploy_line_y_bottom: float,
		play_area_side: float,
		enforce_deploy_zones: bool = true
) -> Vector2:
	return resolve_squadron_position_in_area(
			desired_pos,
			current_pos,
			radius,
			faction,
			other_ship_rects,
			other_squad_circles,
			deploy_line_y_top,
			deploy_line_y_bottom,
			_square_play_area_size(play_area_side),
			enforce_deploy_zones)


## Resolves a desired squadron position inside a rectangular play area.
func resolve_squadron_position_in_area(
		desired_pos: Vector2,
		current_pos: Vector2,
		radius: float,
		faction: Constants.Faction,
		other_ship_rects: Array,
		other_squad_circles: Array,
		deploy_line_y_top: float,
		deploy_line_y_bottom: float,
		play_area_size: Vector2,
		enforce_deploy_zones: bool = true
) -> Vector2:
	var candidate: Vector2 = _clamp_circle_candidate(
			desired_pos, radius, faction,
			deploy_line_y_top, deploy_line_y_bottom, play_area_size,
			enforce_deploy_zones)

	if not _circle_overlaps_any(candidate, radius,
			other_ship_rects, other_squad_circles):
		return candidate

	# Steps 3+4 — primary push-out, then cascade fallback.
	return _resolve_circle_pushout(
			desired_pos, current_pos, candidate, radius, faction,
			other_ship_rects, other_squad_circles,
			deploy_line_y_top, deploy_line_y_bottom, play_area_size,
			enforce_deploy_zones)


## Clamps a desired position to play-area and (optionally) deployment zone
## for a circular (squadron) footprint.
func _clamp_circle_candidate(
		pos: Vector2, radius: float,
		faction: Constants.Faction,
		top_y: float, bottom_y: float, play_area_size: Vector2,
		enforce_zones: bool) -> Vector2:
	var result: Vector2 = _clamp_circle_to_play_area(pos, radius, play_area_size)
	if enforce_zones:
		result = _apply_deploy_zone_circle(
				result, radius, faction, top_y, bottom_y)
	return result


## Performs primary + cascade push-out for a squadron, returning the best
## valid position or [param current_pos] as fallback.
func _resolve_circle_pushout(
		desired_pos: Vector2, current_pos: Vector2,
		candidate: Vector2, radius: float,
		faction: Constants.Faction,
		other_ships: Array, other_squads: Array,
		top_y: float, bottom_y: float, play_area_size: Vector2,
		enforce_zones: bool) -> Vector2:
	var primary: Dictionary = _collect_circle_pushouts(
			candidate, radius, other_ships, other_squads,
			faction, top_y, bottom_y, play_area_size, enforce_zones)
	var best: Vector2 = _pick_closest(primary.valid, candidate)
	if best != Vector2.INF:
		_log.debug("Squadron resolved (primary): mouse=(%.0f,%.0f) result=(%.0f,%.0f) v=%d i=%d" % [
				desired_pos.x, desired_pos.y, best.x, best.y,
				primary.valid.size(), primary.invalid.size()])
		return best
	best = _cascade_circle_pushout(
			primary.invalid, radius, other_ships, other_squads,
			faction, top_y, bottom_y, play_area_size, enforce_zones, candidate)
	if best != Vector2.INF:
		_log.debug("Squadron resolved (cascade): mouse=(%.0f,%.0f) result=(%.0f,%.0f)" % [
				desired_pos.x, desired_pos.y, best.x, best.y])
		return best
	_log.debug("Squadron push-out fallback to current_pos (mouse=%.0f,%.0f)" % [
			desired_pos.x, desired_pos.y])
	return current_pos


## Re-pushes each failed candidate from all blockers (circle cascade step).
func _cascade_circle_pushout(
		invalid: Array, radius: float,
		other_ships: Array, other_squads: Array,
		faction: Constants.Faction,
		top_y: float, bottom_y: float, play_area_size: Vector2,
		enforce_zones: bool, candidate: Vector2) -> Vector2:
	var all_secondary: Array = []
	for pos: Vector2 in invalid:
		var secondary: Dictionary = _collect_circle_pushouts(
				pos, radius, other_ships, other_squads,
				faction, top_y, bottom_y, play_area_size, enforce_zones)
		all_secondary.append_array(secondary.valid)
	return _pick_closest(all_secondary, candidate)


# ---------------------------------------------------------------------------
# Overlap tests
# ---------------------------------------------------------------------------

## Returns true if a ship footprint at [pos] overlaps any other token.
func _ship_overlaps_any(
		pos: Vector2, rot: float, hw: float, hl: float,
		other_ships: Array, other_squads: Array
) -> bool:
	var xform: Transform2D = Transform2D(rot, pos)
	var ship_base: ShipBase = ShipBase.new(Constants.ShipSize.SMALL, xform)
	# Override half dims to match the actual moving ship.
	ship_base.half_width_px = hw
	ship_base.half_length_px = hl
	var my_poly: PackedVector2Array = ship_base.get_base_polygon()

	for other: Dictionary in other_ships:
		var o_xform: Transform2D = Transform2D(
				other.get("rotation", 0.0) as float,
				other.get("position", Vector2.ZERO) as Vector2)
		var o_base: ShipBase = ShipBase.new(Constants.ShipSize.SMALL, o_xform)
		o_base.half_width_px = other.get("half_w", 0.0) as float
		o_base.half_length_px = other.get("half_l", 0.0) as float
		var o_poly: PackedVector2Array = o_base.get_base_polygon()
		if Geometry2DHelper.distance_polygon_to_polygon(my_poly, o_poly) <= 0.0:
			return true

	for other: Dictionary in other_squads:
		var o_pos: Vector2 = other.get("position", Vector2.ZERO) as Vector2
		var o_r: float = other.get("radius", 0.0) as float
		var sq_base: SquadronBase = SquadronBase.new(o_pos, o_r)
		if sq_base.overlaps_ship(ship_base):
			return true

	return false


## Returns true if a circle at [pos] overlaps any other token.
func _circle_overlaps_any(
		pos: Vector2, radius: float,
		other_ships: Array, other_squads: Array
) -> bool:
	var my_base: SquadronBase = SquadronBase.new(pos, radius)

	for other: Dictionary in other_ships:
		var o_xform: Transform2D = Transform2D(
				other.get("rotation", 0.0) as float,
				other.get("position", Vector2.ZERO) as Vector2)
		var o_base: ShipBase = ShipBase.new(Constants.ShipSize.SMALL, o_xform)
		o_base.half_width_px = other.get("half_w", 0.0) as float
		o_base.half_length_px = other.get("half_l", 0.0) as float
		if my_base.overlaps_ship(o_base):
			return true

	for other: Dictionary in other_squads:
		var o_pos: Vector2 = other.get("position", Vector2.ZERO) as Vector2
		var o_r: float = other.get("radius", 0.0) as float
		var o_base: SquadronBase = SquadronBase.new(o_pos, o_r)
		if my_base.overlaps_squadron(o_base):
			return true

	return false


# ---------------------------------------------------------------------------
# Deployment zone enforcement
# ---------------------------------------------------------------------------

## Clamps a ship position so its rotated bounding box stays within the
## faction's deployment zone (does not cross the deployment line).
## DBG-032 — deployment line acts as wall.
func _apply_deploy_zone_ship(
		pos: Vector2, hw: float, hl: float, rot: float,
		faction: Constants.Faction,
		top_line_y: float, bottom_line_y: float
) -> Vector2:
	if top_line_y < 0.0 and bottom_line_y < 0.0:
		return pos
	# Compute the worst-case Y extent of the rotated rectangle from centre.
	var extent_y: float = absf(hw * sin(rot)) + absf(hl * cos(rot))
	var result: Vector2 = pos
	match faction:
		Constants.Faction.GALACTIC_EMPIRE:
			# Must stay above top_line_y.
			if top_line_y >= 0.0 and (result.y + extent_y) > top_line_y:
				result.y = top_line_y - extent_y
		Constants.Faction.REBEL_ALLIANCE:
			# Must stay below bottom_line_y.
			if bottom_line_y >= 0.0 and (result.y - extent_y) < bottom_line_y:
				result.y = bottom_line_y + extent_y
		_:
			pass
	return result


## Clamps a squadron (circle) position so it stays within the deployment zone.
func _apply_deploy_zone_circle(
		pos: Vector2, radius: float,
		faction: Constants.Faction,
		top_line_y: float, bottom_line_y: float
) -> Vector2:
	if top_line_y < 0.0 and bottom_line_y < 0.0:
		return pos
	var result: Vector2 = pos
	match faction:
		Constants.Faction.GALACTIC_EMPIRE:
			if top_line_y >= 0.0 and (result.y + radius) > top_line_y:
				result.y = top_line_y - radius
		Constants.Faction.REBEL_ALLIANCE:
			if bottom_line_y >= 0.0 and (result.y - radius) < bottom_line_y:
				result.y = bottom_line_y + radius
		_:
			pass
	return result


# ---------------------------------------------------------------------------
# Clamp to play area
# ---------------------------------------------------------------------------

func _clamp_rotated_rect_to_play_area(
		pos: Vector2, hw: float, hl: float, rot: float,
		play_area_size: Vector2) -> Vector2:
	var extents: Vector2 = _rotated_rect_extents(hw, hl, rot)
	return _clamp_to_play_area_with_extents(pos, extents, play_area_size)


func _clamp_circle_to_play_area(
		pos: Vector2, radius: float, play_area_size: Vector2) -> Vector2:
	return _clamp_to_play_area_with_extents(
			pos, Vector2(radius, radius), play_area_size)


func _clamp_to_play_area_with_extents(
		pos: Vector2, extents: Vector2, play_area_size: Vector2) -> Vector2:
	if play_area_size.x <= 0.0 or play_area_size.y <= 0.0:
		return pos
	return Vector2(
			_clamp_axis_with_extent(pos.x, play_area_size.x, extents.x),
			_clamp_axis_with_extent(pos.y, play_area_size.y, extents.y))


func _clamp_axis_with_extent(value: float, axis_size: float, extent: float) -> float:
	if extent * 2.0 >= axis_size:
		return axis_size * 0.5
	return clampf(value, extent, axis_size - extent)


func _rotated_rect_extents(hw: float, hl: float, rot: float) -> Vector2:
	return Vector2(
			absf(hw * cos(rot)) + absf(hl * sin(rot)),
			absf(hw * sin(rot)) + absf(hl * cos(rot)))


func _square_play_area_size(side: float) -> Vector2:
	return Vector2(side, side)


# ---------------------------------------------------------------------------
# Push-out candidate collection
# ---------------------------------------------------------------------------

## Collects push-out candidates for a ship from overlapping blockers only.
## Returns {"valid": Array[Vector2], "invalid": Array[Vector2]}.
func _collect_ship_pushouts(
		from_pos: Vector2, rot: float, hw: float, hl: float,
		other_ships: Array, other_squads: Array,
		faction: Constants.Faction,
		top_y: float, bottom_y: float, play_area_size: Vector2,
		enforce_deploy_zones: bool = true
) -> Dictionary:
	var valid: Array = []
	var invalid: Array = []
	for other: Dictionary in other_ships:
		if not _ship_overlaps_any(from_pos, rot, hw, hl, [other], []):
			continue
		var pushed: Vector2 = _push_ship_from_ship(from_pos, rot, hw, hl, other)
		pushed = _clamp_rotated_rect_to_play_area(pushed, hw, hl, rot, play_area_size)
		if enforce_deploy_zones:
			pushed = _apply_deploy_zone_ship(pushed, hw, hl, rot, faction, top_y, bottom_y)
		if _ship_overlaps_any(pushed, rot, hw, hl, other_ships, other_squads):
			invalid.append(pushed)
		else:
			valid.append(pushed)
	for other: Dictionary in other_squads:
		if not _ship_overlaps_any(from_pos, rot, hw, hl, [], [other]):
			continue
		var pushed: Vector2 = _push_ship_from_circle(from_pos, rot, hw, hl, other)
		pushed = _clamp_rotated_rect_to_play_area(pushed, hw, hl, rot, play_area_size)
		if enforce_deploy_zones:
			pushed = _apply_deploy_zone_ship(pushed, hw, hl, rot, faction, top_y, bottom_y)
		if _ship_overlaps_any(pushed, rot, hw, hl, other_ships, other_squads):
			invalid.append(pushed)
		else:
			valid.append(pushed)
	return {"valid": valid, "invalid": invalid}


## Collects push-out candidates for a circle (squadron) from overlapping blockers only.
## Returns {"valid": Array[Vector2], "invalid": Array[Vector2]}.
func _collect_circle_pushouts(
		from_pos: Vector2, radius: float,
		other_ships: Array, other_squads: Array,
		faction: Constants.Faction,
		top_y: float, bottom_y: float, play_area_size: Vector2,
		enforce_deploy_zones: bool = true
) -> Dictionary:
	var valid: Array = []
	var invalid: Array = []
	for other: Dictionary in other_ships:
		if not _circle_overlaps_any(from_pos, radius, [other], []):
			continue
		var pushed: Vector2 = _push_circle_from_ship(from_pos, radius, other)
		pushed = _clamp_circle_to_play_area(pushed, radius, play_area_size)
		if enforce_deploy_zones:
			pushed = _apply_deploy_zone_circle(pushed, radius, faction, top_y, bottom_y)
		if _circle_overlaps_any(pushed, radius, other_ships, other_squads):
			invalid.append(pushed)
		else:
			valid.append(pushed)
	for other: Dictionary in other_squads:
		if not _circle_overlaps_any(from_pos, radius, [], [other]):
			continue
		var pushed: Vector2 = _push_circle_from_circle(from_pos, radius, other)
		pushed = _clamp_circle_to_play_area(pushed, radius, play_area_size)
		if enforce_deploy_zones:
			pushed = _apply_deploy_zone_circle(pushed, radius, faction, top_y, bottom_y)
		if _circle_overlaps_any(pushed, radius, other_ships, other_squads):
			invalid.append(pushed)
		else:
			valid.append(pushed)
	return {"valid": valid, "invalid": invalid}


## Returns the candidate from [candidates] closest to [target].
## Returns Vector2.INF if [candidates] is empty.
func _pick_closest(candidates: Array, target: Vector2) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_d: float = INF
	for c: Variant in candidates:
		var pos: Vector2 = c as Vector2
		var d: float = pos.distance_squared_to(target)
		if d < best_d:
			best_d = d
			best = pos
	return best


# ---------------------------------------------------------------------------
# Push-out helpers — project the moving token to the nearest non-overlapping
# position along the ray from a blocker's centre through the desired position.
# DBG-022
# ---------------------------------------------------------------------------

## Pushes a ship away from another ship blocker via binary search along the
## blocker-centre → desired ray to find the closest clear position.
func _push_ship_from_ship(
		desired: Vector2, rot: float, hw: float, hl: float,
		blocker: Dictionary
) -> Vector2:
	var b_pos: Vector2 = blocker.get("position", Vector2.ZERO) as Vector2
	var dir: Vector2 = desired - b_pos
	if dir.length_squared() < 0.01:
		dir = Vector2.UP
	dir = dir.normalized()

	var b_hw: float = blocker.get("half_w", 0.0) as float
	var b_hl: float = blocker.get("half_l", 0.0) as float
	var max_dist: float = (
			sqrt(hw * hw + hl * hl)
			+ sqrt(b_hw * b_hw + b_hl * b_hl)
			+ OVERLAP_EPSILON * 2.0)

	return _ray_binary_search_ship(
			b_pos, dir, max_dist, rot, hw, hl, [blocker], [])


## Pushes a ship away from a circle (squadron) blocker.
func _push_ship_from_circle(
		desired: Vector2, rot: float, hw: float, hl: float,
		blocker: Dictionary
) -> Vector2:
	var b_pos: Vector2 = blocker.get("position", Vector2.ZERO) as Vector2
	var b_r: float = blocker.get("radius", 0.0) as float
	var dir: Vector2 = desired - b_pos
	if dir.length_squared() < 0.01:
		dir = Vector2.UP
	dir = dir.normalized()

	var max_dist: float = (
			sqrt(hw * hw + hl * hl) + b_r + OVERLAP_EPSILON * 2.0)

	return _ray_binary_search_ship(
			b_pos, dir, max_dist, rot, hw, hl, [], [blocker])


## Pushes a circle (squadron) away from another circle using the exact
## Minkowski-sum formula (no binary search needed).
func _push_circle_from_circle(
		desired: Vector2, radius: float, blocker: Dictionary
) -> Vector2:
	var b_pos: Vector2 = blocker.get("position", Vector2.ZERO) as Vector2
	var b_r: float = blocker.get("radius", 0.0) as float
	var dir: Vector2 = desired - b_pos
	if dir.length_squared() < 0.01:
		dir = Vector2.UP
	dir = dir.normalized()
	var contact_dist: float = radius + b_r + OVERLAP_EPSILON
	return b_pos + dir * contact_dist


## Pushes a circle (squadron) away from a ship blocker via binary search
## along a ray from the ship's centre through the desired position.
## Uses centre-based direction to avoid the inverted-direction bug that
## occurs when desired is inside the ship polygon.
func _push_circle_from_ship(
		desired: Vector2, radius: float, blocker: Dictionary
) -> Vector2:
	var b_pos: Vector2 = blocker.get("position", Vector2.ZERO) as Vector2
	var b_rot: float = blocker.get("rotation", 0.0) as float
	var b_hw: float = blocker.get("half_w", 0.0) as float
	var b_hl: float = blocker.get("half_l", 0.0) as float
	var dir: Vector2 = desired - b_pos
	if dir.length_squared() < 0.01:
		dir = Vector2.UP
	dir = dir.normalized()
	var max_dist: float = (
			sqrt(b_hw * b_hw + b_hl * b_hl)
			+ radius + OVERLAP_EPSILON * 2.0)
	return _ray_binary_search_circle(
			b_pos, dir, max_dist, radius, [blocker], [])


# ---------------------------------------------------------------------------
# Ray binary search — finds the closest point along a ray from [origin] in
# [direction] (within [max_dist]) where the token does NOT overlap the
# specified blocker(s).
# ---------------------------------------------------------------------------

## Binary search along a ray for a ship footprint.
func _ray_binary_search_ship(
		origin: Vector2, direction: Vector2, max_dist: float,
		rot: float, hw: float, hl: float,
		ship_blockers: Array, circle_blockers: Array
) -> Vector2:
	var lo: float = 0.0
	var hi: float = max_dist
	for _i: int in range(MAX_BINARY_STEPS):
		var mid: float = (lo + hi) * 0.5
		var test: Vector2 = origin + direction * mid
		if _ship_overlaps_any(test, rot, hw, hl,
				ship_blockers, circle_blockers):
			lo = mid
		else:
			hi = mid
	return origin + direction * hi


## Binary search along a ray for a circular (squadron) footprint.
func _ray_binary_search_circle(
		origin: Vector2, direction: Vector2, max_dist: float,
		radius: float,
		ship_blockers: Array, circle_blockers: Array
) -> Vector2:
	var lo: float = 0.0
	var hi: float = max_dist
	for _i: int in range(MAX_BINARY_STEPS):
		var mid: float = (lo + hi) * 0.5
		var test: Vector2 = origin + direction * mid
		if _circle_overlaps_any(test, radius,
				ship_blockers, circle_blockers):
			lo = mid
		else:
			hi = mid
	return origin + direction * hi
