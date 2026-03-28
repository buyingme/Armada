## LineOfSightChecker
##
## Pure-logic class for tracing line of sight between hull zones and
## squadrons, detecting LOS blocking by the defender's other hull zones,
## and detecting obstruction by intervening ships or obstacles.
##
## All methods are static — no scene-tree or Node dependency.
##
## Requirements: TL-LOS-001–009, TL-ALGO-002.
## Rules Reference: "Line of Sight", p.10; "Obstructed", p.13.
class_name LineOfSightChecker
extends RefCounted


## Result of a LOS trace.
## [param has_los]       — true if line of sight exists.
## [param obstructed]    — true if LOS is obstructed (but still valid).
## [param obstructed_by] — names of obstructing entities.
class LOSResult:
	extends RefCounted
	var has_los: bool = true
	var obstructed: bool = false
	var obstructed_by: Array[String] = []


## An obstruction body: an oriented rectangle or convex polygon that may
## obstruct LOS.  Used for intervening ships and future obstacles.
class ObstructionBody:
	extends RefCounted
	## Display name (for the obstructed_by list).
	var entity_name: String = ""
	## World-space corners of the convex polygon (4 for a ship base).
	var polygon: Array[Vector2] = []

	static func from_ship_base(
			ship_name: String,
			pos: Vector2,
			rot: float,
			half_w: float,
			half_l: float) -> ObstructionBody:
		var body: ObstructionBody = ObstructionBody.new()
		body.entity_name = ship_name
		body.polygon = _make_rect_polygon(pos, rot, half_w, half_l)
		return body

	static func _make_rect_polygon(
			pos: Vector2, rot: float,
			hw: float, hl: float) -> Array[Vector2]:
		var corners: Array[Vector2] = []
		var offsets: Array[Vector2] = [
			Vector2(-hw, -hl),
			Vector2(hw, -hl),
			Vector2(hw, hl),
			Vector2(-hw, hl),
		]
		for off: Vector2 in offsets:
			corners.append(pos + off.rotated(rot))
		return corners


# =========================================================================
# LOS Trace  (TL-LOS-001–003)
# =========================================================================

## Traces LOS between two ship hull zones and checks for blocking and
## obstruction.
##
## [param atk_los_pt]    — world-space targeting point of attacking hull zone.
## [param def_los_pt]    — world-space targeting point of defending hull zone.
## [param def_zone]      — the defending hull zone enum.
## [param def_pos]       — defender ship world position.
## [param def_rot]       — defender ship rotation.
## [param def_half_w]    — defender half-width.
## [param def_half_l]    — defender half-length.
## [param bodies]        — array of ObstructionBody for intervening ships.
## [param obstacles]     — array of ObstructionBody for obstacles (future).
## [param def_arc_pts]   — (optional) defender arc boundary points in world
##   space.  When present the hull-zone blocking check uses the real arc
##   boundary lines instead of rectangle-edge heuristics.
## Requirements: TL-LOS-001, TL-LOS-004, TL-LOS-005, TL-LOS-008.
static func trace_los_ship_to_ship(
		atk_los_pt: Vector2,
		def_los_pt: Vector2,
		def_zone: Constants.HullZone,
		def_pos: Vector2,
		def_rot: float,
		def_half_w: float,
		def_half_l: float,
		bodies: Array,
		obstacles: Array,
		def_arc_pts: Dictionary = {}) -> LOSResult:
	var result: LOSResult = LOSResult.new()
	# TL-LOS-004: check if LOS line enters defender through a different HZ.
	if _los_blocked_by_other_hull_zone(
			atk_los_pt, def_los_pt, def_zone,
			def_pos, def_rot, def_half_w, def_half_l, def_arc_pts):
		result.has_los = false
		return result
	# TL-LOS-005/008: check intervening ships and obstacles.
	_check_obstruction(atk_los_pt, def_los_pt, bodies, result)
	_check_obstruction(atk_los_pt, def_los_pt, obstacles, result)
	return result


## Traces LOS from a ship hull zone to a squadron.
## Squadrons never block/obstruct (TL-LOS-006), so no defender HZ check.
## Requirements: TL-LOS-002.
static func trace_los_ship_to_squadron(
		atk_los_pt: Vector2,
		squad_centre: Vector2,
		squad_radius: float,
		bodies: Array,
		obstacles: Array) -> LOSResult:
	# LOS target = closest point on squadron base to atk_los_pt.
	var target: Vector2 = RangeFinder.closest_point_on_circle(
			atk_los_pt, squad_centre, squad_radius)
	var result: LOSResult = LOSResult.new()
	_check_obstruction(atk_los_pt, target, bodies, result)
	_check_obstruction(atk_los_pt, target, obstacles, result)
	return result


## Traces LOS from a squadron to a specific hull zone on a defending ship.
##
## The LOS origin is the closest point on the squadron circle to the
## defender's targeting point (TL-LOS-003).  The LOS segment is then
## checked for hull-zone blocking (TL-LOS-004) and obstruction (TL-LOS-005).
##
## [param squad_centre]  — world-space centre of the squadron base.
## [param squad_radius]  — squadron base radius in pixels.
## [param def_los_pt]    — world-space targeting point of the defending hull zone.
## [param def_zone]      — the defending hull zone enum.
## [param def_pos]       — defender ship world position.
## [param def_rot]       — defender ship rotation.
## [param def_half_w]    — defender half-width.
## [param def_half_l]    — defender half-length.
## [param bodies]        — array of ObstructionBody for intervening ships.
## [param obstacles]     — array of ObstructionBody for obstacles (future).
## [param def_arc_pts]   — (optional) defender arc boundary points in world
##   space.
## Requirements: TL-LOS-003, TL-LOS-004, TL-LOS-005, TL-LOS-008.
static func trace_los_squad_to_ship(
		squad_centre: Vector2,
		squad_radius: float,
		def_los_pt: Vector2,
		def_zone: Constants.HullZone,
		def_pos: Vector2,
		def_rot: float,
		def_half_w: float,
		def_half_l: float,
		bodies: Array,
		obstacles: Array,
		def_arc_pts: Dictionary = {}) -> LOSResult:
	# LOS origin = closest point on squadron base to defender's LOS point.
	var los_origin: Vector2 = RangeFinder.closest_point_on_circle(
			def_los_pt, squad_centre, squad_radius)
	var result: LOSResult = LOSResult.new()
	# TL-LOS-004: check if LOS line enters defender through a different HZ.
	if _los_blocked_by_other_hull_zone(
			los_origin, def_los_pt, def_zone,
			def_pos, def_rot, def_half_w, def_half_l, def_arc_pts):
		result.has_los = false
		return result
	# TL-LOS-005/008: check intervening ships and obstacles.
	_check_obstruction(los_origin, def_los_pt, bodies, result)
	_check_obstruction(los_origin, def_los_pt, obstacles, result)
	return result


## Traces LOS from a squadron to another squadron.
## Squadrons never block LOS (TL-LOS-006), and there are no hull zones
## to check.  Only intervening ships/obstacles can obstruct.
##
## [param atk_centre]  — world-space centre of the attacking squadron.
## [param atk_radius]  — attacking squadron base radius in pixels.
## [param def_centre]  — world-space centre of the defending squadron.
## [param def_radius]  — defending squadron base radius in pixels.
## [param bodies]      — array of ObstructionBody for intervening ships.
## [param obstacles]   — array of ObstructionBody for obstacles (future).
## Requirements: TL-LOS-006.
## Rules Reference: "Line of Sight", p.10 — "Squadrons do not block or
## obstruct line of sight."
static func trace_los_squad_to_squad(
		atk_centre: Vector2,
		atk_radius: float,
		def_centre: Vector2,
		def_radius: float,
		bodies: Array,
		obstacles: Array) -> LOSResult:
	# LOS origin = closest point on attacker base to defender's centre.
	var los_origin: Vector2 = RangeFinder.closest_point_on_circle(
			def_centre, atk_centre, atk_radius)
	# LOS target = closest point on defender base to attacker's centre.
	var los_target: Vector2 = RangeFinder.closest_point_on_circle(
			atk_centre, def_centre, def_radius)
	var result: LOSResult = LOSResult.new()
	_check_obstruction(los_origin, los_target, bodies, result)
	_check_obstruction(los_origin, los_target, obstacles, result)
	return result


## Checks if the range path (attacker edge → defender edge within arc)
## is blocked by defender's other hull zone.
## Requirements: TL-LOS-004 (range path check).
## [param atk_edge_pt]   — closest point on attacker edge (already computed).
## [param def_edge_pt]   — closest in-arc point on defender edge (already computed).
## [param def_zone]       — the defending hull zone.
## [param def_pos/rot/hw/hl] — defender geometry.
## [param def_arc_pts]    — (optional) defender arc boundary points.
static func is_range_path_blocked(
		atk_edge_pt: Vector2,
		def_edge_pt: Vector2,
		def_zone: Constants.HullZone,
		def_pos: Vector2,
		def_rot: float,
		def_half_w: float,
		def_half_l: float,
		def_arc_pts: Dictionary = {}) -> bool:
	return _los_blocked_by_other_hull_zone(
			atk_edge_pt, def_edge_pt, def_zone,
			def_pos, def_rot, def_half_w, def_half_l, def_arc_pts)


# =========================================================================
# Segment-vs-Polygon Intersection
# =========================================================================

## Returns true if the segment [param p1]→[param p2] intersects the
## convex polygon defined by [param polygon] (array of Vector2, wound CCW
## or CW).
static func segment_intersects_polygon(
		p1: Vector2, p2: Vector2, polygon: Array[Vector2]) -> bool:
	var n: int = polygon.size()
	if n < 3:
		return false
	# Check if either endpoint is inside the polygon.
	if _point_in_polygon(p1, polygon):
		return true
	if _point_in_polygon(p2, polygon):
		return true
	# Check segment against each edge of the polygon.
	for i: int in range(n):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % n]
		if _segments_intersect(p1, p2, a, b):
			return true
	return false


# =========================================================================
# Internal Helpers
# =========================================================================

## Checks if the LOS segment enters the defender's base through a hull zone
## that is NOT the defending hull zone.
## Returns true if blocked (no LOS).
## Requirements: TL-LOS-004.
## Rules Reference: "Line of Sight", p.10; "Hull Zones", p.9.
##
## When [param def_arc_pts] contains the firing arc boundary data, we
## check whether the LOS segment crosses any of the 4 arc boundary lines
## (inner_point → outer_point).  Each boundary separates two adjacent hull
## zones; if the segment crosses any boundary, it must be entering through
## a hull zone other than the one containing the LOS target point.
##
## Fallback: when arc data is absent, we use the rectangle-edge +
## 1/3-length-division heuristic.
static func _los_blocked_by_other_hull_zone(
		seg_start: Vector2,
		seg_end: Vector2,
		def_zone: Constants.HullZone,
		def_pos: Vector2,
		def_rot: float,
		def_half_w: float,
		def_half_l: float,
		def_arc_pts: Dictionary = {}) -> bool:
	# --- Primary path: arc boundary intersection ---
	if _has_arc_boundary_keys(def_arc_pts):
		return _los_blocked_by_arc_boundaries(
				seg_start, seg_end, def_arc_pts)
	# --- Fallback: rectangle edge + 1/3-length classification ---
	return _los_blocked_by_rect_classify(
			seg_start, seg_end, def_zone,
			def_pos, def_rot, def_half_w, def_half_l)


## Returns true when [param arc_pts] contains all 8 boundary keys needed
## for the arc-based check.
static func _has_arc_boundary_keys(arc_pts: Dictionary) -> bool:
	if arc_pts.is_empty():
		return false
	for key: String in _ARC_BOUNDARY_PAIRS:
		if not arc_pts.has(key):
			return false
	return true


## The 4 arc boundary segments, each as [inner_key, outer_key].
const _ARC_BOUNDARY_PAIRS: Array[String] = [
	"inner_point_front_left", "outer_point_front_left",
	"inner_point_front_right", "outer_point_front_right",
	"inner_point_rear_left", "outer_point_rear_left",
	"inner_point_rear_right", "outer_point_rear_right",
]


## Checks if the LOS segment crosses any of the 4 arc boundary lines.
## Each boundary is drawn from the inner point (near ship centre) to the
## outer point (on the base edge).  Crossing any boundary means the LOS
## line passes through more than one hull zone → blocked.
## Rules Reference: "Hull Zones", p.9.
static func _los_blocked_by_arc_boundaries(
		seg_start: Vector2,
		seg_end: Vector2,
		arc_pts: Dictionary) -> bool:
	for i: int in range(0, _ARC_BOUNDARY_PAIRS.size(), 2):
		var inner: Vector2 = arc_pts[_ARC_BOUNDARY_PAIRS[i]]
		var outer: Vector2 = arc_pts[_ARC_BOUNDARY_PAIRS[i + 1]]
		if _segments_intersect(seg_start, seg_end, inner, outer):
			return true
	return false


## Fallback hull-zone blocking when arc boundary data is unavailable.
## Uses rectangle edges and the 1/3-length classification heuristic.
static func _los_blocked_by_rect_classify(
		seg_start: Vector2,
		seg_end: Vector2,
		def_zone: Constants.HullZone,
		def_pos: Vector2,
		def_rot: float,
		def_half_w: float,
		def_half_l: float) -> bool:
	var zones: Array = [
		Constants.HullZone.FRONT,
		Constants.HullZone.REAR,
		Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT,
	]
	var best_t: float = INF
	for zone: int in zones:
		var edge: Array[Vector2] = RangeFinder.get_hull_zone_edge(
				def_pos, def_rot, def_half_w, def_half_l,
				zone as Constants.HullZone)
		var t: float = _segment_intersection_t(
				seg_start, seg_end, edge[0], edge[1])
		if t >= 0.0 and t < best_t:
			best_t = t
	if best_t >= INF:
		return false
	var entry_world: Vector2 = seg_start + (seg_end - seg_start) * best_t
	var entry_local: Vector2 = (entry_world - def_pos).rotated(-def_rot)
	var entry_zone: Constants.HullZone = _classify_local_point(
			entry_local, def_half_w, def_half_l)
	return entry_zone != def_zone


## Classifies a point in the defender's local space into a hull zone using
## the 1/3-length division rule.
## Rules Reference: "Hull Zones", p.9.
static func _classify_local_point(
		local: Vector2,
		half_w: float,
		half_l: float) -> Constants.HullZone:
	var third: float = half_l * 2.0 / 3.0
	var front_y: float = -half_l + third
	var rear_y: float = half_l - third
	if local.y < front_y:
		return Constants.HullZone.FRONT
	if local.y > rear_y:
		return Constants.HullZone.REAR
	if local.x < 0.0:
		return Constants.HullZone.LEFT
	return Constants.HullZone.RIGHT


## Returns the first arc boundary crossed by the LOS segment together
## with the intersection point world-space coordinates, or an empty
## dictionary when no boundary is crossed.
## Used for debug logging.
static func get_blocking_boundary_info(
		seg_start: Vector2,
		seg_end: Vector2,
		arc_pts: Dictionary) -> Dictionary:
	if not _has_arc_boundary_keys(arc_pts):
		return {}
	var best_t: float = INF
	var best_inner: Vector2 = Vector2.ZERO
	var best_outer: Vector2 = Vector2.ZERO
	var best_label: String = ""
	for i: int in range(0, _ARC_BOUNDARY_PAIRS.size(), 2):
		var inner_key: String = _ARC_BOUNDARY_PAIRS[i]
		var outer_key: String = _ARC_BOUNDARY_PAIRS[i + 1]
		var inner: Vector2 = arc_pts[inner_key]
		var outer: Vector2 = arc_pts[outer_key]
		var t: float = _segment_intersection_t(
				seg_start, seg_end, inner, outer)
		if t >= 0.0 and t < best_t:
			best_t = t
			best_inner = inner
			best_outer = outer
			best_label = inner_key.replace("inner_point_", "")
	if best_t >= INF:
		return {}
	var ix: Vector2 = seg_start + (seg_end - seg_start) * best_t
	return {
		"boundary": best_label,
		"inner": best_inner,
		"outer": best_outer,
		"intersection": ix,
	}


## Checks all bodies for obstruction and accumulates into [param result].
static func _check_obstruction(
		seg_start: Vector2,
		seg_end: Vector2,
		bodies: Array,
		result: LOSResult) -> void:
	for body: Variant in bodies:
		if body is ObstructionBody:
			var ob: ObstructionBody = body as ObstructionBody
			if segment_intersects_polygon(seg_start, seg_end, ob.polygon):
				result.obstructed = true
				if not result.obstructed_by.has(ob.entity_name):
					result.obstructed_by.append(ob.entity_name)


## Returns the parametric t (0..1) at which segment p1→p2 intersects
## segment a→b, or -1.0 if no intersection.
static func _segment_intersection_t(
		p1: Vector2, p2: Vector2, a: Vector2, b: Vector2) -> float:
	var d1: Vector2 = p2 - p1
	var d2: Vector2 = b - a
	var cross: float = d1.cross(d2)
	if absf(cross) < 1e-8:
		return -1.0
	var diff: Vector2 = a - p1
	var t: float = diff.cross(d2) / cross
	var u: float = diff.cross(d1) / cross
	if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
		return t
	return -1.0


## Returns true if two segments p1→p2 and a→b intersect (proper or improper).
static func _segments_intersect(
		p1: Vector2, p2: Vector2, a: Vector2, b: Vector2) -> bool:
	return _segment_intersection_t(p1, p2, a, b) >= 0.0


## Returns true if [param pt] is inside the convex polygon [param poly].
## Uses winding number / cross product approach for convex polygons.
static func _point_in_polygon(pt: Vector2, poly: Array[Vector2]) -> bool:
	var n: int = poly.size()
	if n < 3:
		return false
	var positive: int = 0
	var negative: int = 0
	for i: int in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		var cross: float = (b - a).cross(pt - a)
		if cross > 0.0:
			positive += 1
		elif cross < 0.0:
			negative += 1
		if positive > 0 and negative > 0:
			return false
	return true
