## OverlapResolver
##
## Pure logic for detecting and resolving overlaps after a ship executes
## a maneuver.  Scene-tree independent (extends RefCounted).
##
## Ship–ship overlap: if the final position overlaps another ship, the
## speed is temporarily reduced by 1 and the maneuver is retried.
## This repeats until there is no overlap or speed reaches 0 (ship stays
## in place).  Both ships receive one facedown damage card.
##
## Ship–squadron overlap: the ship finishes its move normally.  Any
## overlapped squadrons must be placed by the opposing player so
## they touch the ship's base.
##
## Rules Reference: RRG "Overlapping", p.8.
## Requirements: OV-001–004, OV-010–013.
class_name OverlapResolver
extends RefCounted


var _log: GameLogger = GameLogger.new("OverlapResolver")


## Result of [method check_ship_ship_overlap].
## [member overlaps] — true if the final position overlaps another ship.
## [member final_transform] — resolved final Transform2D (may be at
##     reduced speed or the ship's original transform if speed hit 0).
## [member final_speed] — the speed at which the ship actually moved.
## [member overlapped_ship] — the closest overlapped ShipBase (for damage).
## [member original_speed] — the speed the ship started with.
## [member stayed_in_place] — true if the ship could not move at all.
class ShipShipResult extends RefCounted:
	var overlaps: bool = false
	var final_transform: Transform2D = Transform2D.IDENTITY
	var final_speed: int = 0
	var overlapped_ship_index: int = -1
	var original_speed: int = 0
	var stayed_in_place: bool = false


## Checks whether the moving ship overlaps any other ship at its target
## position.  If so, performs the temporary speed reduction loop.
##
## [param tool_state] — the ManeuverToolState with current joint settings.
## [param attach_pos] — the maneuver tool attachment world position.
## [param attach_rot] — the maneuver tool attachment heading (radians).
## [param ghost_side] — "left" or "right" (tool placement side).
## [param moving_ship_size] — the moving ship's size enum.
## [param other_ships] — Array of ShipBase for every other ship on the board.
## [param original_transform] — the ship's transform before moving.
##
## Returns a [ShipShipResult].
## Rules Reference: RRG "Overlapping", p.8; OV-010–013.
func check_ship_ship_overlap(
		tool_state: ManeuverToolState,
		attach_pos: Vector2,
		attach_rot: float,
		ghost_side: String,
		moving_ship_size: Constants.ShipSize,
		other_ships: Array,
		original_transform: Transform2D) -> ShipShipResult:
	var result: ShipShipResult = ShipShipResult.new()
	var current_speed: int = tool_state.get_simulated_speed()
	result.original_speed = current_speed

	# Try at current speed, then reduce until 0.
	while current_speed >= 0:
		var xform: Transform2D = _compute_xform_at_speed(
				tool_state, current_speed, attach_pos,
				attach_rot, ghost_side, original_transform)
		var closest_idx: int = _find_closest_overlap(
				moving_ship_size, xform, other_ships)

		if closest_idx < 0:
			_fill_success_result(result, current_speed, xform)
			tool_state.set_simulated_speed(result.original_speed)
			return result

		_last_overlap_idx = closest_idx
		_log.info("Overlap at speed %d with ship %d — reducing." % [
				current_speed, closest_idx])
		current_speed -= 1

	_fill_stayed_in_place_result(result, original_transform)
	tool_state.set_simulated_speed(result.original_speed)
	return result


## Computes the ship transform at a given speed (0 = original position).
func _compute_xform_at_speed(
		tool_state: ManeuverToolState,
		speed: int,
		attach_pos: Vector2,
		attach_rot: float,
		ghost_side: String,
		original_transform: Transform2D) -> Transform2D:
	if speed == 0:
		return original_transform
	tool_state.set_simulated_speed(speed)
	return tool_state.compute_final_transform(
			attach_pos, attach_rot, ghost_side)


## Returns the index of the closest overlapping ship, or -1 if none.
func _find_closest_overlap(
		ship_size: Constants.ShipSize,
		xform: Transform2D,
		other_ships: Array) -> int:
	var moving_base: ShipBase = ShipBase.new(ship_size, xform)
	var moving_poly: PackedVector2Array = moving_base.get_base_polygon()
	var closest_idx: int = -1
	var closest_dist: float = INF

	for i: int in range(other_ships.size()):
		var other: ShipBase = other_ships[i] as ShipBase
		var other_poly: PackedVector2Array = other.get_base_polygon()
		var dist: float = Geometry2DHelper.distance_polygon_to_polygon(
				moving_poly, other_poly)
		if dist <= 0.0:
			var d: float = xform.origin.distance_to(
					other.ship_transform.origin)
			if d < closest_dist:
				closest_dist = d
				closest_idx = i
	return closest_idx


## Fills the result for a successful (non-stuck) maneuver.
func _fill_success_result(
		result: ShipShipResult,
		speed: int,
		xform: Transform2D) -> void:
	result.overlaps = (speed != result.original_speed)
	result.final_transform = xform
	result.final_speed = speed
	result.stayed_in_place = false
	if result.overlaps:
		result.overlapped_ship_index = _last_overlap_idx
	_log.info("Maneuver resolved at speed %d (original %d)." % [
			speed, result.original_speed])


## Fills the result when the ship cannot move (speed 0, still overlapping).
## Rules Reference: RRG "Overlapping", p.8; OV-010, OV-011.
func _fill_stayed_in_place_result(
		result: ShipShipResult,
		original_transform: Transform2D) -> void:
	result.overlaps = true
	result.final_transform = original_transform
	result.final_speed = 0
	result.overlapped_ship_index = _last_overlap_idx
	result.stayed_in_place = true
	_log.info("Ship stays in place (speed 0). Overlap damage applies.")


## Index of the last-found overlapping ship (used for damage assignment).
var _last_overlap_idx: int = -1


## Finds all squadron tokens whose bases overlap a ship base polygon.
##
## [param ship_base] — the ship's ShipBase at its final position.
## [param squadron_positions] — Array of Dictionaries with keys:
##     "position": Vector2 — squadron world centre.
##     "radius": float — base radius in pixels.
##     "index": int — index in the original squadron list.
##
## Returns an Array of indices into [param squadron_positions] that overlap.
## Rules Reference: RRG "Overlapping", p.8; OV-001.
func find_overlapped_squadrons(
		ship_base: ShipBase,
		squadron_positions: Array) -> Array[int]:
	var result: Array[int] = []
	for entry: Dictionary in squadron_positions:
		var pos: Vector2 = entry["position"] as Vector2
		var radius: float = entry["radius"] as float
		var idx: int = entry["index"] as int
		var sq: SquadronBase = SquadronBase.new(pos, radius)
		if sq.overlaps_ship(ship_base):
			result.append(idx)
	return result


## Validates that a proposed squadron placement position is legal.
## The squadron must touch the ship (distance ≤ tolerance) and must
## not overlap any other ship or squadron.
##
## [param squad_pos] — proposed world position for the squadron centre.
## [param squad_radius] — the squadron's base radius.
## [param touching_ship] — the ShipBase the squadron must touch.
## [param other_ships] — Array of ShipBase for all ships on the board.
## [param other_squads] — Array of SquadronBase for all existing
##     (non-displaced) squadrons.
## [param tolerance] — distance tolerance for "touching" (pixels).
##
## Returns "" if valid, or an error message string if invalid.
## Rules Reference: RRG "Overlapping", p.8; OV-002, OV-020.
func validate_squadron_placement(
		squad_pos: Vector2,
		squad_radius: float,
		touching_ship: ShipBase,
		other_ships: Array,
		other_squads: Array,
		tolerance: float = 5.0) -> String:
	# Must touch the ship base.
	var ship_poly: PackedVector2Array = touching_ship.get_base_polygon()
	var sq: SquadronBase = SquadronBase.new(squad_pos, squad_radius)
	var dist_to_ship: float = Geometry2DHelper.distance_point_to_polygon(
			squad_pos, ship_poly)
	# "Touching" means the edge of the circle is within tolerance of
	# the ship polygon edge.
	var gap: float = dist_to_ship - squad_radius
	if gap > tolerance:
		return "Squadron must be placed touching the ship."
	# Must not overlap the ship itself.
	if sq.overlaps_ship(touching_ship):
		return "Squadron cannot overlap the ship."
	# Must not overlap other ships.
	for other: ShipBase in other_ships:
		if sq.overlaps_ship(other):
			return "Squadron cannot overlap another ship."
	# Must not overlap other squadrons.
	for other: SquadronBase in other_squads:
		if sq.overlaps_squadron(other):
			return "Squadron cannot overlap another squadron."
	return ""


## Computes a snap position so the squadron circle is always in base
## contact with the ship polygon (tangent to the nearest edge).
##
## [param mouse_pos] — the desired world position (e.g. mouse cursor).
## [param squad_radius] — the squadron's base radius in pixels.
## [param ship_base] — the [ShipBase] the squadron must touch.
##
## Returns the snapped squadron centre: the closest point on the ship
## polygon to [param mouse_pos], offset outward by [param squad_radius]
## plus a tiny gap to avoid triggering overlap detection.
## Rules Reference: RRG "Overlapping", p.8 — OV-002.
static func snap_to_ship_edge(
		mouse_pos: Vector2,
		squad_radius: float,
		ship_base: ShipBase) -> Vector2:
	var poly: PackedVector2Array = ship_base.get_base_polygon()
	var closest: Vector2 = Geometry2DHelper.closest_point_on_polygon(
			mouse_pos, poly)
	# Direction from the ship edge outward toward the mouse.
	var dir: Vector2 = (mouse_pos - closest)
	if dir.length_squared() < 0.001:
		# Mouse is exactly on the edge — use the outward normal.
		dir = (closest - ship_base.ship_transform.origin).normalized()
	else:
		dir = dir.normalized()
	# Offset by radius + 1px to guarantee "touching but not overlapping".
	return closest + dir * (squad_radius + 1.0)
