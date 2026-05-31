## FiringArcOverlay
##
## Draws semi-transparent firing arc wedges for the four hull zones of a ship.
## Attach as a direct child of ShipToken. The overlay inherits the parent
## node's position and rotation, so it draws in ship-local space.
##
## Arc boundaries are read from the ship's JSON data (inner → outer points),
## converted to local space, and drawn as the actual boundary rays.  This
## replaces the old fixed-45° approximation and matches the geometry used
## by [RangeFinder.is_point_in_arc] for targeting.
##
## In debug mode the boundary lines are extended to a long distance
## (≈ play area diagonal) so the exact ray direction is visible at map scale.
##
## Visibility should be toggled by the player (UI-011). Call
## [method set_visible] to show or hide all arcs at once.
##
## Rules Reference: "Firing Arcs", p.3; AT-041–043; UI-011.
class_name FiringArcOverlay
extends Node2D


## Visual radius of each arc wedge in pixels (purely cosmetic).
const ARC_RADIUS_PX: float = 220.0

## Fill transparency (0 = fully transparent, 1 = opaque).
const FILL_ALPHA: float = 0.18

## Border line transparency.
const BORDER_ALPHA: float = 0.70

## Debug-mode extended line transparency.
const DEBUG_LINE_ALPHA: float = 0.55

## Debug-mode extended line width.
const DEBUG_LINE_WIDTH: float = 1.5

## Number of polygon segments used to approximate the curved outer edge.
const ARC_SEGMENTS: int = 24

## Per-zone fill colours (keyed by HullZone int value).
## FRONT=0 blue, LEFT=1 green, RIGHT=2 yellow, REAR=3 red.
## Rules Reference: UI-011 colour coding.
const _ZONE_BASE_COLOURS: Array[Color] = [
	Color(0.30, 0.70, 1.00), # FRONT — blue
	Color(0.30, 1.00, 0.40), # LEFT  — green
	Color(1.00, 0.90, 0.20), # RIGHT — yellow
	Color(1.00, 0.35, 0.30), # REAR  — red
]

## Boundary lines in local space.  Each entry is {inner: Vector2, dir: Vector2}
## where dir = (outer - inner).normalized().
## Set by [method set_arc_boundaries]; empty → fallback to hardcoded 45° angles.
var _boundary_lines: Array[Dictionary] = []

## Boundary zone mapping: _boundary_zones[i] = [zone_a, zone_b] indices that
## share boundary line i.  Used for colouring.
var _boundary_zones: Array[Array] = []

## How far debug boundary lines extend from the inner point (px).
var _debug_extend_px: float = 4000.0


## Configures the overlay to use real arc boundary data from the ship JSON.
## [param local_boundaries] — Dictionary of arc boundary keys → local Vector2.
## Keys: "inner_point_front_left", "outer_point_front_left", etc.
func set_arc_boundaries(local_boundaries: Dictionary) -> void:
	_boundary_lines.clear()
	_boundary_zones.clear()
	if local_boundaries.is_empty():
		queue_redraw()
		return
	var boundary_defs: Array[Dictionary] = _get_boundary_defs()
	for bd: Dictionary in boundary_defs:
		_add_boundary_from_def(bd, local_boundaries)
	# Set debug extend distance based on play area size.
	_debug_extend_px = _compute_debug_extend_px()
	queue_redraw()


func _compute_debug_extend_px() -> float:
	var play_area_size: Vector2 = GameScale.play_area_size_px
	if play_area_size.x > 0.0 and play_area_size.y > 0.0:
		return play_area_size.length() * 2.0
	return GameScale.play_area_side_px * 2.0


## Returns the 4 boundary line definitions (FL, FR, RL, RR).
static func _get_boundary_defs() -> Array[Dictionary]:
	return [
		{
			"inner": "inner_point_front_left",
			"outer": "outer_point_front_left",
			"zones": [Constants.HullZone.FRONT, Constants.HullZone.LEFT],
		},
		{
			"inner": "inner_point_front_right",
			"outer": "outer_point_front_right",
			"zones": [Constants.HullZone.FRONT, Constants.HullZone.RIGHT],
		},
		{
			"inner": "inner_point_rear_left",
			"outer": "outer_point_rear_left",
			"zones": [Constants.HullZone.REAR, Constants.HullZone.LEFT],
		},
		{
			"inner": "inner_point_rear_right",
			"outer": "outer_point_rear_right",
			"zones": [Constants.HullZone.REAR, Constants.HullZone.RIGHT],
		},
	]


## Parses one boundary definition and appends to the overlay arrays.
func _add_boundary_from_def(
		bd: Dictionary, local_boundaries: Dictionary) -> void:
	var inner_key: String = bd["inner"]
	var outer_key: String = bd["outer"]
	if not local_boundaries.has(inner_key) or \
			not local_boundaries.has(outer_key):
		return
	var inner: Vector2 = local_boundaries[inner_key]
	var outer: Vector2 = local_boundaries[outer_key]
	var direction: Vector2 = (outer - inner)
	if direction.length_squared() < 1e-8:
		return
	_boundary_lines.append({
		"inner": inner,
		"dir": direction.normalized(),
	})
	_boundary_zones.append(bd["zones"] as Array)


func _draw() -> void:
	if _boundary_lines.is_empty():
		# Fallback: draw hardcoded 45° wedges (legacy / test).
		_draw_fallback()
	else:
		_draw_from_boundaries()


## Draws arcs using the real boundary data.
func _draw_from_boundaries() -> void:
	# Draw filled wedges using boundary-derived angles.
	var angles: Array[float] = _compute_zone_angles()
	for zone_int: int in range(4):
		var a_from: float = angles[zone_int * 2]
		var a_to: float = angles[zone_int * 2 + 1]
		_draw_arc_zone(zone_int, a_from, a_to)
	# Draw boundary lines.
	var is_debug: bool = DebugMode.enabled
	for i: int in range(_boundary_lines.size()):
		var bl: Dictionary = _boundary_lines[i]
		var inner: Vector2 = bl["inner"]
		var dir: Vector2 = bl["dir"]
		var zones: Array = _boundary_zones[i]
		# Bright border line to ARC_RADIUS_PX.
		var zone_a: int = zones[0] as int
		var zone_b: int = zones[1] as int
		var colour_a: Color = _ZONE_BASE_COLOURS[zone_a]
		var colour_b: Color = _ZONE_BASE_COLOURS[zone_b]
		var avg_colour: Color = Color(
				(colour_a.r + colour_b.r) * 0.5,
				(colour_a.g + colour_b.g) * 0.5,
				(colour_a.b + colour_b.b) * 0.5,
				BORDER_ALPHA)
		var short_end: Vector2 = inner + dir * ARC_RADIUS_PX
		draw_line(inner, short_end, avg_colour, 1.5)
		# In debug mode, extend the line across the play area.
		if is_debug:
			var far_end: Vector2 = inner + dir * _debug_extend_px
			var dbg_colour: Color = Color(
					avg_colour.r, avg_colour.g, avg_colour.b, DEBUG_LINE_ALPHA)
			draw_line(short_end, far_end, dbg_colour, DEBUG_LINE_WIDTH)


## Computes [from, to] angle pairs for each hull zone from boundary data.
## Returns a flat array of 8 floats: [FRONT_from, FRONT_to, LEFT_from, …].
func _compute_zone_angles() -> Array[float]:
	# We need to find the angle of each boundary direction from centre.
	# Boundary definitions:
	#   FL boundary separates FRONT (right side of ray) / LEFT (left side)
	#   FR boundary separates FRONT (left side of ray) / RIGHT (right side)
	#   RL boundary separates REAR / LEFT
	#   RR boundary separates REAR / RIGHT
	# Angles of the 4 boundary rays.
	var a_fl: float = _boundary_angle(0) # front-left
	var a_fr: float = _boundary_angle(1) # front-right
	var a_rl: float = _boundary_angle(2) # rear-left
	var a_rr: float = _boundary_angle(3) # rear-right
	# FRONT: from FL to FR (going clockwise in screen space = increasing angle
	# from negative to less negative).
	# LEFT:  from RL to FL (wrapping around -π/π boundary).
	# RIGHT: from FR to RR.
	# REAR:  from RR to RL.
	var result: Array[float] = []
	# FRONT=0
	result.append(a_fl)
	result.append(a_fr)
	# LEFT=1 — goes from RL around through +π/-π to FL
	result.append(a_rl)
	result.append(a_rl + _angle_span(a_rl, a_fl))
	# RIGHT=2
	result.append(a_fr)
	result.append(a_rr)
	# REAR=3
	result.append(a_rr)
	result.append(a_rl)
	return result


## Returns the angle (radians) of boundary line [idx]'s direction.
func _boundary_angle(idx: int) -> float:
	if idx >= _boundary_lines.size():
		return 0.0
	var dir: Vector2 = _boundary_lines[idx]["dir"]
	return atan2(dir.y, dir.x)


## Returns the positive angular span from [a_from] to [a_to] going clockwise
## in screen space (which means going in the direction of increasing angle
## with wrap-around).
static func _angle_span(a_from: float, a_to: float) -> float:
	var span: float = a_to - a_from
	while span < 0.0:
		span += TAU
	while span > TAU:
		span -= TAU
	return span


## Draws arcs with hardcoded 45° angles (fallback when no boundary data).
func _draw_fallback() -> void:
	var fallback_angles: Array[Array] = [
		[-2.35619449, -0.78539816], # FRONT
		[2.35619449, 3.92699082], # LEFT
		[-0.78539816, 0.78539816], # RIGHT
		[0.78539816, 2.35619449], # REAR
	]
	for zone_int: int in range(4):
		var angles: Array = fallback_angles[zone_int]
		_draw_arc_zone(zone_int, float(angles[0]), float(angles[1]))


## Draws a single pie-slice wedge for [zone_int] from [a_from] to [a_to].
func _draw_arc_zone(zone_int: int, a_from: float, a_to: float) -> void:
	var base: Color = _ZONE_BASE_COLOURS[zone_int]
	var fill: Color = Color(base.r, base.g, base.b, FILL_ALPHA)
	var border: Color = Color(base.r, base.g, base.b, BORDER_ALPHA)
	var poly: PackedVector2Array = _build_arc_polygon(a_from, a_to)
	draw_colored_polygon(poly, fill)
	draw_line(Vector2.ZERO, poly[1], border, 1.5)
	draw_line(Vector2.ZERO, poly[poly.size() - 1], border, 1.5)


## Builds a pie-slice polygon from the origin outward.
## Vertices: [origin, arc_start, ..., arc_end].
func _build_arc_polygon(a_from: float, a_to: float) -> PackedVector2Array:
	var poly: PackedVector2Array = PackedVector2Array()
	poly.append(Vector2.ZERO)
	var step: float = (a_to - a_from) / float(ARC_SEGMENTS)
	for i: int in range(ARC_SEGMENTS + 1):
		var a: float = a_from + step * float(i)
		poly.append(Vector2(cos(a), sin(a)) * ARC_RADIUS_PX)
	return poly
