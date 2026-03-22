## RangeFinder
##
## Pure-logic class for firing-arc containment tests, closest-point-on-edge
## calculations, and range measurement between hull zones and squadrons.
##
## All methods are static or work on plain Vector2/Dictionary data — no
## scene-tree or Node dependency.
##
## Requirements: TL-RNG-001–006, TL-ARC-001–006, TL-ALGO-001.
## Rules Reference: "Measuring Firing Arc and Range", p.10; "Firing Arc", p.8;
## "Attack Range", p.3; "Range and Distance", p.14.
class_name RangeFinder
extends RefCounted


## ─── Firing-Arc Boundary Key Names ──────────────────────────────────────
## Match the JSON keys in each ship's firing_arc_boundaries dict.
const _ARC_KEYS: Dictionary = {
	Constants.HullZone.FRONT: {
		"inner_a": "inner_point_front_left",
		"outer_a": "outer_point_front_left",
		"inner_b": "inner_point_front_right",
		"outer_b": "outer_point_front_right",
	},
	Constants.HullZone.LEFT: {
		"inner_a": "inner_point_front_left",
		"outer_a": "outer_point_front_left",
		"inner_b": "inner_point_rear_left",
		"outer_b": "outer_point_rear_left",
	},
	Constants.HullZone.RIGHT: {
		"inner_a": "inner_point_front_right",
		"outer_a": "outer_point_front_right",
		"inner_b": "inner_point_rear_right",
		"outer_b": "outer_point_rear_right",
	},
	Constants.HullZone.REAR: {
		"inner_a": "inner_point_rear_left",
		"outer_a": "outer_point_rear_left",
		"inner_b": "inner_point_rear_right",
		"outer_b": "outer_point_rear_right",
	},
}

## Number of sample points along a hull-zone edge for in-arc checks.
const EDGE_SAMPLE_COUNT: int = 9

## Epsilon for cross-product sign comparison.  Points exactly on a boundary
## ray should be considered "inside" (TL-ARC-002), but floating-point
## rounding in position arithmetic can produce tiny non-zero cross products.
## A small negative tolerance absorbs that error.
const _ARC_EPSILON: float = 1e-3


# =========================================================================
# Firing-Arc Test  (TL-ARC-001–006)
# =========================================================================

## Returns true if [param point] lies inside the firing arc of [param zone]
## for a ship whose world-space boundary points are [param arc_pts].
## The arc is the infinite sector between two boundary rays.
## Points on the boundary line are considered inside (TL-ARC-002).
## Rules Reference: "Firing Arc", p.8.
static func is_point_in_arc(
		point: Vector2,
		zone: Constants.HullZone,
		arc_pts: Dictionary) -> bool:
	var keys: Dictionary = _ARC_KEYS[zone]
	var inner_a: Vector2 = arc_pts[keys["inner_a"]]
	var outer_a: Vector2 = arc_pts[keys["outer_a"]]
	var inner_b: Vector2 = arc_pts[keys["inner_b"]]
	var outer_b: Vector2 = arc_pts[keys["outer_b"]]
	# Each boundary line runs from inner to outer, defining a ray direction.
	# The arc is the region that is on the "correct" side of both rays.
	# For boundary A the arc interior is to the RIGHT of the ray (A→outer_a).
	# For boundary B the arc interior is to the LEFT of the ray (B→outer_b).
	var dir_a: Vector2 = outer_a - inner_a
	var dir_b: Vector2 = outer_b - inner_b
	var to_pt_a: Vector2 = point - inner_a
	var to_pt_b: Vector2 = point - inner_b
	var cross_a: float = dir_a.cross(to_pt_a)
	var cross_b: float = dir_b.cross(to_pt_b)
	# Determine which side is "inside" for each boundary.
	# Use the opposite boundary's outer point as the reference interior point.
	var ref_a: Vector2 = outer_b - inner_a
	var ref_b: Vector2 = outer_a - inner_b
	var ref_cross_a: float = dir_a.cross(ref_a)
	var ref_cross_b: float = dir_b.cross(ref_b)
	# Point must be on the same side as the reference for both boundaries.
	# A point whose cross product is effectively zero lies on the boundary
	# line itself and counts as inside (TL-ARC-002).  We use a relative
	# epsilon scaled to the vector magnitudes to absorb float rounding.
	var eps_a: float = dir_a.length() * to_pt_a.length() * _ARC_EPSILON
	var eps_b: float = dir_b.length() * to_pt_b.length() * _ARC_EPSILON
	var side_a: bool = absf(cross_a) < eps_a or (cross_a * ref_cross_a) > 0.0
	var side_b: bool = absf(cross_b) < eps_b or (cross_b * ref_cross_b) > 0.0
	return side_a and side_b


## Returns true if **any** portion of the defending hull-zone edge is inside
## the attacker's firing arc.  Samples representative points along the edge.
## Requirements: TL-ARC-003.
## [param def_edge_start] — world-space start of the defending hull-zone edge.
## [param def_edge_end]   — world-space end of the defending hull-zone edge.
## [param atk_zone]       — the attacking hull zone enum.
## [param atk_arc_pts]    — world-space boundary points of the attacker.
static func is_hull_zone_edge_in_arc(
		def_edge_start: Vector2,
		def_edge_end: Vector2,
		atk_zone: Constants.HullZone,
		atk_arc_pts: Dictionary) -> bool:
	for i: int in range(EDGE_SAMPLE_COUNT + 1):
		var t: float = float(i) / float(EDGE_SAMPLE_COUNT)
		var pt: Vector2 = def_edge_start.lerp(def_edge_end, t)
		if is_point_in_arc(pt, atk_zone, atk_arc_pts):
			return true
	return false


## Returns true if **any** portion of a squadron's circular base is inside
## the attacker's firing arc.  Tests centre + cardinal edge points.
## Requirements: TL-ARC-004.
static func is_squadron_in_arc(
		squad_centre: Vector2,
		squad_radius: float,
		atk_zone: Constants.HullZone,
		atk_arc_pts: Dictionary) -> bool:
	if is_point_in_arc(squad_centre, atk_zone, atk_arc_pts):
		return true
	# Test 8 evenly-spaced points around the circle.
	for i: int in range(8):
		var angle: float = float(i) * TAU / 8.0
		var pt: Vector2 = squad_centre + Vector2(squad_radius, 0.0).rotated(angle)
		if is_point_in_arc(pt, atk_zone, atk_arc_pts):
			return true
	return false


# =========================================================================
# Hull-Zone Edge Geometry  (TL-ARC-005)
# =========================================================================

## Returns the world-space start and end of a hull-zone edge as a
## two-element array [start, end].
## [param pos]      — ship world position (centre of the base).
## [param rot]      — ship world rotation in radians.
## [param half_w]   — half-width of the base.
## [param half_l]   — half-length of the base.
## [param zone]     — the hull zone whose edge to return.
## Rules Reference: "Hull Zones", p.9.
static func get_hull_zone_edge(
		pos: Vector2,
		rot: float,
		half_w: float,
		half_l: float,
		zone: Constants.HullZone) -> Array[Vector2]:
	var local_start: Vector2
	var local_end: Vector2
	match zone:
		Constants.HullZone.FRONT:
			local_start = Vector2(-half_w, -half_l)
			local_end = Vector2(half_w, -half_l)
		Constants.HullZone.REAR:
			local_start = Vector2(-half_w, half_l)
			local_end = Vector2(half_w, half_l)
		Constants.HullZone.LEFT:
			local_start = Vector2(-half_w, -half_l)
			local_end = Vector2(-half_w, half_l)
		Constants.HullZone.RIGHT:
			local_start = Vector2(half_w, -half_l)
			local_end = Vector2(half_w, half_l)
		_:
			return [pos, pos]
	return [
		pos + local_start.rotated(rot),
		pos + local_end.rotated(rot),
	]


# =========================================================================
# Closest-Point Calculations  (TL-RNG-001, TL-RNG-002)
# =========================================================================

## Returns the closest point on the segment [param a]→[param b] to [param p].
static func closest_point_on_segment(
		p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 1e-8:
		return a
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t


## Returns the minimum distance between two line segments
## [param a1]→[param a2] and [param b1]→[param b2].
static func segment_to_segment_distance(
		a1: Vector2, a2: Vector2,
		b1: Vector2, b2: Vector2) -> float:
	# Sample both directions and take the minimum.
	var d1: float = (closest_point_on_segment(a1, b1, b2) - a1).length()
	var d2: float = (closest_point_on_segment(a2, b1, b2) - a2).length()
	var d3: float = (closest_point_on_segment(b1, a1, a2) - b1).length()
	var d4: float = (closest_point_on_segment(b2, a1, a2) - b2).length()
	return minf(minf(d1, d2), minf(d3, d4))


## Returns the closest point on a circle (centre, radius) to [param p].
## If [param p] is at the circle centre, returns a point at angle 0.
static func closest_point_on_circle(
		p: Vector2, centre: Vector2, radius: float) -> Vector2:
	var diff: Vector2 = p - centre
	if diff.length_squared() < 1e-8:
		return centre + Vector2(radius, 0.0)
	return centre + diff.normalized() * radius


# =========================================================================
# Attack Range Measurement  (TL-RNG-001, TL-ARC-006)
# =========================================================================

## Measures the attack range from one hull zone to another hull zone,
## considering ONLY the defender portion inside the attacker's firing arc.
## Returns the pixel distance, or INF if no portion is inside the arc.
##
## [param atk_edge]     — [start, end] of the attacking hull-zone edge.
## [param def_edge]     — [start, end] of the defending hull-zone edge.
## [param atk_zone]     — the attacking hull zone enum.
## [param atk_arc_pts]  — world-space boundary points of the attacker.
## Requirements: TL-RNG-001, TL-ARC-006.
static func measure_attack_range_ship(
		atk_edge: Array[Vector2],
		def_edge: Array[Vector2],
		atk_zone: Constants.HullZone,
		atk_arc_pts: Dictionary) -> float:
	var best: float = INF
	# Sample many points on the defender edge; keep only those inside arc.
	var def_start: Vector2 = def_edge[0]
	var def_end: Vector2 = def_edge[1]
	var count: int = EDGE_SAMPLE_COUNT
	for i: int in range(count + 1):
		var t: float = float(i) / float(count)
		var def_pt: Vector2 = def_start.lerp(def_end, t)
		if not is_point_in_arc(def_pt, atk_zone, atk_arc_pts):
			continue
		# Distance from this within-arc defender point to closest on atk edge.
		var cp: Vector2 = closest_point_on_segment(
				def_pt, atk_edge[0], atk_edge[1])
		var d: float = cp.distance_to(def_pt)
		if d < best:
			best = d
	# Also check attacker edge points → closest in-arc defender point.
	for atk_pt: Vector2 in [atk_edge[0], atk_edge[1]]:
		for j: int in range(count + 1):
			var t2: float = float(j) / float(count)
			var def_pt2: Vector2 = def_start.lerp(def_end, t2)
			if not is_point_in_arc(def_pt2, atk_zone, atk_arc_pts):
				continue
			var d2: float = atk_pt.distance_to(def_pt2)
			if d2 < best:
				best = d2
	return best


## Measures the attack range from a hull zone to a squadron base,
## considering ONLY the squadron portion inside the firing arc.
## Returns the pixel distance, or INF if no portion is inside the arc.
## Requirements: TL-RNG-002.
static func measure_attack_range_squadron(
		atk_edge: Array[Vector2],
		squad_centre: Vector2,
		squad_radius: float,
		atk_zone: Constants.HullZone,
		atk_arc_pts: Dictionary) -> float:
	var best: float = INF
	# Sample points on the circle edge; keep only those inside the arc.
	var sample_count: int = 16
	var pts: Array[Vector2] = [squad_centre]
	for i: int in range(sample_count):
		var angle: float = float(i) * TAU / float(sample_count)
		pts.append(squad_centre + Vector2(squad_radius, 0.0).rotated(angle))
	for pt: Vector2 in pts:
		if not is_point_in_arc(pt, atk_zone, atk_arc_pts):
			continue
		var cp: Vector2 = closest_point_on_segment(
				pt, atk_edge[0], atk_edge[1])
		var d: float = cp.distance_to(pt)
		if d < best:
			best = d
	return best


# =========================================================================
# Maximum Attack Range  (TL-RNG-004, TL-RNG-005)
# =========================================================================

## Returns the maximum attack range band ("close", "medium", or "long")
## for the given battery armament dictionary {DiceColor_string: int}.
## Returns "close" if only black, "medium" if at least one blue,
## "long" if at least one red.
## Requirements: TL-RNG-004.
## Rules Reference: "Attack Range", p.3.
static func max_attack_range_band(armament: Dictionary) -> String:
	var has_red: bool = armament.get("RED", 0) > 0
	var has_blue: bool = armament.get("BLUE", 0) > 0
	if has_red:
		return Constants.RANGE_BAND_LONG
	if has_blue:
		return Constants.RANGE_BAND_MEDIUM
	return Constants.RANGE_BAND_CLOSE


## Returns true if the given range band is within the maximum attack range
## determined by the armament.
## E.g. if max is "medium", then "close" and "medium" are valid but "long"
## isn't.
static func is_within_max_range(
		measured_band: String, armament: Dictionary) -> bool:
	var max_band: String = max_attack_range_band(armament)
	return _band_order(measured_band) <= _band_order(max_band)


## Returns the dice available at the given range band from the armament.
## At close: all colours; medium: blue + red; long: red only.
## Requirements: TL-LIST-003.
## Rules Reference: "Attack", Step 2, p.2.
static func dice_at_range(
		armament: Dictionary, range_band: String) -> Dictionary:
	var result: Dictionary = {}
	var order: int = _band_order(range_band)
	if order < 0:
		return result
	# Red available at all bands (close/medium/long).
	if armament.get("RED", 0) > 0:
		result["RED"] = armament["RED"]
	# Blue available at close and medium.
	if order <= 1 and armament.get("BLUE", 0) > 0:
		result["BLUE"] = armament["BLUE"]
	# Black available at close only.
	if order <= 0 and armament.get("BLACK", 0) > 0:
		result["BLACK"] = armament["BLACK"]
	return result


## Formats a dice dictionary into a human-readable string.
## Example: "2 red, 1 blue".
static func format_dice(dice: Dictionary) -> String:
	var parts: Array[String] = []
	for colour: String in ["RED", "BLUE", "BLACK"]:
		var count: int = dice.get(colour, 0)
		if count > 0:
			parts.append("%d %s" % [count, colour.to_lower()])
	if parts.is_empty():
		return "no dice"
	return ", ".join(parts)


# =========================================================================
# Internal Helpers
# =========================================================================

## Returns a numeric ordering for range bands (lower = closer).
static func _band_order(band: String) -> int:
	match band:
		Constants.RANGE_BAND_CLOSE:
			return 0
		Constants.RANGE_BAND_MEDIUM:
			return 1
		Constants.RANGE_BAND_LONG:
			return 2
		_:
			return 99
