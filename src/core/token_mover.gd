## TokenMover
##
## Pure logic for debug-mode token movement: resolves a desired world position
## into a valid position respecting token–token and deployment-zone collisions.
##
## Collision model:
##   1. Move the token toward the target position.
##   2. If the footprint overlaps ANY other token, slide to the contact point
##      along the movement direction (DBG-020).
##   3. If the target is BEYOND the blocker and the footprint fits on the far
##      side, jump past to resume following the cursor (DBG-021).
##   4. Deployment zone boundaries act as walls for faction-owned tokens
##      (DBG-032).
##
## This class is scene-tree independent (RefCounted).
class_name TokenMover
extends RefCounted


## Maximum binary-search iterations for slide-to-contact resolution.
const MAX_BINARY_STEPS: int = 16

## Small epsilon for overlap tolerance (pixels).
const OVERLAP_EPSILON: float = 1.0


## Resolves a desired position for a ship token, accounting for collisions
## with other tokens and deployment zone boundaries.
## Returns the best valid position.
##
## [param desired_pos] — where the mouse wants to place the token (world).
## [param current_pos] — the token's current world position.
## [param ship_size] — the size class of the moving ship.
## [param rotation_rad] — the ship's current rotation.
## [param faction] — the moving token's faction (for deployment zone).
## [param other_ship_rects] — Array of Dictionaries: {position, rotation, half_w, half_l}.
## [param other_squad_circles] — Array of Dictionaries: {position, radius}.
## [param deploy_line_y_top] — Y of the top deployment line (-1 to disable).
## [param deploy_line_y_bottom] — Y of the bottom deployment line (-1 to disable).
## [param play_area_side] — play area side in pixels.
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

	# First try the desired position.
	var candidate: Vector2 = desired_pos

	# Clamp to play area bounds.
	candidate = _clamp_to_play_area(candidate, play_area_side)

	# Check deployment zone boundary.
	candidate = _apply_deploy_zone_ship(
			candidate, half_w, half_l, rotation_rad, faction,
			deploy_line_y_top, deploy_line_y_bottom)

	# Check for overlap with other tokens at candidate position.
	if not _ship_overlaps_any(candidate, rotation_rad, half_w, half_l,
			other_ship_rects, other_squad_circles):
		return candidate

	# Overlap detected — try jump-past first. If the cursor is beyond all
	# blockers and the token fits on the far side, jump there.
	var jump_pos: Vector2 = _try_jump_past_ship(
			desired_pos, current_pos, rotation_rad, half_w, half_l,
			other_ship_rects, other_squad_circles,
			faction, deploy_line_y_top, deploy_line_y_bottom, play_area_side)
	if jump_pos != Vector2.INF:
		return jump_pos

	# Fall back to slide-to-contact via binary search between current and desired.
	return _binary_search_ship(
			current_pos, desired_pos, rotation_rad, half_w, half_l,
			other_ship_rects, other_squad_circles,
			faction, deploy_line_y_top, deploy_line_y_bottom, play_area_side)


## Resolves a desired position for a squadron token.
## Same logic as ship but with circular footprint.
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

	# Try jump-past.
	var jump_pos: Vector2 = _try_jump_past_circle(
			desired_pos, current_pos, radius,
			other_ship_rects, other_squad_circles,
			faction, deploy_line_y_top, deploy_line_y_bottom, play_area_side)
	if jump_pos != Vector2.INF:
		return jump_pos

	# Binary search slide-to-contact.
	return _binary_search_circle(
			current_pos, desired_pos, radius,
			other_ship_rects, other_squad_circles,
			faction, deploy_line_y_top, deploy_line_y_bottom, play_area_side)


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
# Binary search slide-to-contact
# ---------------------------------------------------------------------------

## Binary searches between [start] and [end] to find the furthest position
## along that line where the ship does NOT overlap anything.
func _binary_search_ship(
		start: Vector2, end: Vector2, rot: float, hw: float, hl: float,
		other_ships: Array, other_squads: Array,
		faction: Constants.Faction,
		top_y: float, bottom_y: float, side: float
) -> Vector2:
	var lo: float = 0.0
	var hi: float = 1.0
	var best: Vector2 = start

	for _i: int in range(MAX_BINARY_STEPS):
		var mid: float = (lo + hi) * 0.5
		var candidate: Vector2 = start.lerp(end, mid)
		candidate = _clamp_to_play_area(candidate, side)
		candidate = _apply_deploy_zone_ship(
				candidate, hw, hl, rot, faction, top_y, bottom_y)
		if _ship_overlaps_any(candidate, rot, hw, hl, other_ships, other_squads):
			hi = mid
		else:
			lo = mid
			best = candidate

	return best


## Binary search for circular (squadron) tokens.
func _binary_search_circle(
		start: Vector2, end: Vector2, radius: float,
		other_ships: Array, other_squads: Array,
		faction: Constants.Faction,
		top_y: float, bottom_y: float, side: float
) -> Vector2:
	var lo: float = 0.0
	var hi: float = 1.0
	var best: Vector2 = start

	for _i: int in range(MAX_BINARY_STEPS):
		var mid: float = (lo + hi) * 0.5
		var candidate: Vector2 = start.lerp(end, mid)
		candidate = _clamp_to_play_area(candidate, side)
		candidate = _apply_deploy_zone_circle(
				candidate, radius, faction, top_y, bottom_y)
		if _circle_overlaps_any(candidate, radius, other_ships, other_squads):
			hi = mid
		else:
			lo = mid
			best = candidate

	return best


# ---------------------------------------------------------------------------
# Jump-past logic
# ---------------------------------------------------------------------------

## Tries to place the ship on the far side of all blockers.
## Returns Vector2.INF if no valid jump-past position exists.
## DBG-021 — jump past when cursor is beyond blocker and footprint fits.
func _try_jump_past_ship(
		desired: Vector2, current: Vector2,
		rot: float, hw: float, hl: float,
		other_ships: Array, other_squads: Array,
		faction: Constants.Faction,
		top_y: float, bottom_y: float, side: float
) -> Vector2:
	# The jump candidate is the desired position itself.
	var candidate: Vector2 = _clamp_to_play_area(desired, side)
	candidate = _apply_deploy_zone_ship(
			candidate, hw, hl, rot, faction, top_y, bottom_y)
	if not _ship_overlaps_any(candidate, rot, hw, hl, other_ships, other_squads):
		return candidate
	# Suppress unused variable warning.
	var _c: Vector2 = current
	return Vector2.INF


## Tries to place a squadron on the far side of all blockers.
func _try_jump_past_circle(
		desired: Vector2, current: Vector2, radius: float,
		other_ships: Array, other_squads: Array,
		faction: Constants.Faction,
		top_y: float, bottom_y: float, side: float
) -> Vector2:
	var candidate: Vector2 = _clamp_to_play_area(desired, side)
	candidate = _apply_deploy_zone_circle(
			candidate, radius, faction, top_y, bottom_y)
	if not _circle_overlaps_any(candidate, radius, other_ships, other_squads):
		return candidate
	var _c: Vector2 = current
	return Vector2.INF
