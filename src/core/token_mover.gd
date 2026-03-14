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
##      the direction from the blocker's centre to the desired position
##      (Minkowski-sum boundary push-out).
##   4. Among all push-out candidates that satisfy every constraint (no overlap
##      with ANY token, within deployment zone, within play area), return the
##      one whose centre is closest to the desired position.
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


## Maximum binary-search iterations for push-out resolution.
const MAX_BINARY_STEPS: int = 20

## Small epsilon for overlap tolerance (pixels).
const OVERLAP_EPSILON: float = 1.0


## Resolves a desired position for a ship token, accounting for collisions
## with other tokens and deployment zone boundaries.
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
## [param play_area_side] — play area side in pixels.
## DBG-020, DBG-022
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
		play_area_side: float
) -> Vector2:
	var base_size: Vector2 = GameScale.get_base_size(ship_size)
	var half_w: float = base_size.x * 0.5
	var half_l: float = base_size.y * 0.5

	# Step 1 — apply boundary constraints to the desired position.
	var candidate: Vector2 = desired_pos
	candidate = _clamp_to_play_area(candidate, play_area_side)
	candidate = _apply_deploy_zone_ship(
			candidate, half_w, half_l, rotation_rad, faction,
			deploy_line_y_top, deploy_line_y_bottom)

	# Step 2 — if no overlap, return immediately.
	if not _ship_overlaps_any(candidate, rotation_rad, half_w, half_l,
			other_ship_rects, other_squad_circles):
		return candidate

	# Step 3 — for each blocker, compute the push-out candidate.
	var best_pos: Vector2 = current_pos
	var best_dist_sq: float = INF

	for other: Dictionary in other_ship_rects:
		var pushed: Vector2 = _push_ship_from_ship(
				candidate, rotation_rad, half_w, half_l, other)
		pushed = _clamp_to_play_area(pushed, play_area_side)
		pushed = _apply_deploy_zone_ship(
				pushed, half_w, half_l, rotation_rad, faction,
				deploy_line_y_top, deploy_line_y_bottom)
		if not _ship_overlaps_any(pushed, rotation_rad, half_w, half_l,
				other_ship_rects, other_squad_circles):
			var d: float = pushed.distance_squared_to(desired_pos)
			if d < best_dist_sq:
				best_dist_sq = d
				best_pos = pushed

	for other: Dictionary in other_squad_circles:
		var pushed: Vector2 = _push_ship_from_circle(
				candidate, rotation_rad, half_w, half_l, other)
		pushed = _clamp_to_play_area(pushed, play_area_side)
		pushed = _apply_deploy_zone_ship(
				pushed, half_w, half_l, rotation_rad, faction,
				deploy_line_y_top, deploy_line_y_bottom)
		if not _ship_overlaps_any(pushed, rotation_rad, half_w, half_l,
				other_ship_rects, other_squad_circles):
			var d: float = pushed.distance_squared_to(desired_pos)
			if d < best_dist_sq:
				best_dist_sq = d
				best_pos = pushed

	return best_pos


## Resolves a desired position for a squadron token.
## Same projection-based approach as ship but with circular footprint.
## DBG-020, DBG-022
func resolve_squadron_position(
		desired_pos: Vector2,
		current_pos: Vector2,
		radius: float,
		faction: Constants.Faction,
		other_ship_rects: Array,
		other_squad_circles: Array,
		deploy_line_y_top: float,
		deploy_line_y_bottom: float,
		play_area_side: float
) -> Vector2:
	var candidate: Vector2 = desired_pos
	candidate = _clamp_to_play_area(candidate, play_area_side)
	candidate = _apply_deploy_zone_circle(
			candidate, radius, faction,
			deploy_line_y_top, deploy_line_y_bottom)

	if not _circle_overlaps_any(candidate, radius,
			other_ship_rects, other_squad_circles):
		return candidate

	# Push-out candidates from each blocker.
	var best_pos: Vector2 = current_pos
	var best_dist_sq: float = INF

	for other: Dictionary in other_ship_rects:
		var pushed: Vector2 = _push_circle_from_ship(
				candidate, radius, other)
		pushed = _clamp_to_play_area(pushed, play_area_side)
		pushed = _apply_deploy_zone_circle(
				pushed, radius, faction,
				deploy_line_y_top, deploy_line_y_bottom)
		if not _circle_overlaps_any(pushed, radius,
				other_ship_rects, other_squad_circles):
			var d: float = pushed.distance_squared_to(desired_pos)
			if d < best_dist_sq:
				best_dist_sq = d
				best_pos = pushed

	for other: Dictionary in other_squad_circles:
		var pushed: Vector2 = _push_circle_from_circle(
				candidate, radius, other)
		pushed = _clamp_to_play_area(pushed, play_area_side)
		pushed = _apply_deploy_zone_circle(
				pushed, radius, faction,
				deploy_line_y_top, deploy_line_y_bottom)
		if not _circle_overlaps_any(pushed, radius,
				other_ship_rects, other_squad_circles):
			var d: float = pushed.distance_squared_to(desired_pos)
			if d < best_dist_sq:
				best_dist_sq = d
				best_pos = pushed

	return best_pos


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

func _clamp_to_play_area(pos: Vector2, side: float) -> Vector2:
	if side <= 0.0:
		return pos
	return Vector2(clampf(pos.x, 0.0, side), clampf(pos.y, 0.0, side))


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


## Pushes a circle (squadron) away from a ship blocker by projecting outward
## from the ship polygon along the desired direction.
func _push_circle_from_ship(
		desired: Vector2, radius: float, blocker: Dictionary
) -> Vector2:
	var b_pos: Vector2 = blocker.get("position", Vector2.ZERO) as Vector2
	var b_rot: float = blocker.get("rotation", 0.0) as float
	var b_hw: float = blocker.get("half_w", 0.0) as float
	var b_hl: float = blocker.get("half_l", 0.0) as float

	var b_xform: Transform2D = Transform2D(b_rot, b_pos)
	var b_base: ShipBase = ShipBase.new(Constants.ShipSize.SMALL, b_xform)
	b_base.half_width_px = b_hw
	b_base.half_length_px = b_hl
	var b_poly: PackedVector2Array = b_base.get_base_polygon()

	var closest: Vector2 = Geometry2DHelper.closest_point_on_polygon(
			desired, b_poly)
	var dir: Vector2 = desired - closest
	if dir.length_squared() < 0.01:
		dir = desired - b_pos
	if dir.length_squared() < 0.01:
		dir = Vector2.UP
	dir = dir.normalized()
	return closest + dir * (radius + OVERLAP_EPSILON)


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
