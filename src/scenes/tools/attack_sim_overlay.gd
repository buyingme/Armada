## AttackSimOverlay
##
## Visual aids drawn on the game board when an attacker is selected in the
## Attack Simulator.  Added as a child of the token container so it renders
## in world space alongside tokens.
##
## For hull zone selection: draws two firing arc boundary lines and a LOS marker.
## For squadron selection: draws a close-range circle.
## The range overlay (RangeOverlayScene) is managed separately by the game board.
##
## Requirements: AS-VIS-002, AS-VIS-003, AS-VIS-010.
## Rules Reference: "Firing Arcs", p.3; "Line of Sight", p.6.
class_name AttackSimOverlay
extends Node2D


## Logger.
var _log: GameLogger = GameLogger.new("AttackSimOverlay")

## Colour for firing arc boundary lines — white, 60 % opacity.
## Requirements: AS-VIS-002.
const ARC_LINE_COLOUR: Color = Color(1.0, 1.0, 1.0, 0.6)

## Width of firing arc boundary lines in pixels.
const ARC_LINE_WIDTH: float = 1.5

## Colour for LOS targeting point marker — yellow, 60 % opacity.
## Requirements: AS-VIS-003.
const LOS_MARKER_COLOUR: Color = Color(1.0, 1.0, 0.0, 0.6)

## Radius of the LOS marker circle in pixels (6 px diameter → 3 px radius).
const LOS_MARKER_RADIUS: float = 3.0

## Colour for squadron close-range circle — white, 30 % opacity.
## Requirements: AS-VIS-010.
const SQUAD_CIRCLE_COLOUR: Color = Color(1.0, 1.0, 1.0, 0.3)

## Width of the squadron circle line in pixels.
const SQUAD_CIRCLE_WIDTH: float = 1.5

## Number of segments for drawn circles.
const CIRCLE_SEGMENTS: int = 64

## Play area side length — lines are clipped to this boundary.
var _play_area_side: float = 0.0

# --- Hull zone visuals ---

## Start point of the left arc boundary line (world space).
var _arc_line_left_start: Vector2 = Vector2.ZERO
## End point of the left arc boundary line (extended to play area edge).
var _arc_line_left_end: Vector2 = Vector2.ZERO
## Start point of the right arc boundary line (world space).
var _arc_line_right_start: Vector2 = Vector2.ZERO
## End point of the right arc boundary line (extended to play area edge).
var _arc_line_right_end: Vector2 = Vector2.ZERO
## World-space position of the LOS targeting point.
var _los_position: Vector2 = Vector2.ZERO
## Whether hull zone visuals should be drawn.
var _draw_hull_zone: bool = false

# --- Squadron visuals ---

## World-space centre of the squadron.
var _squad_centre: Vector2 = Vector2.ZERO
## Radius of the close-range circle (base radius + close range distance).
var _squad_circle_radius: float = 0.0
## Whether squadron visuals should be drawn.
var _draw_squadron: bool = false


## Sets up the overlay for a hull zone attacker.
## [param inner_left] — world-space inner boundary point (left side of arc).
## [param outer_left] — world-space outer boundary point (left side of arc).
## [param inner_right] — world-space inner boundary point (right side of arc).
## [param outer_right] — world-space outer boundary point (right side of arc).
## [param los_pos] — world-space LOS targeting point.
## Requirements: AS-VIS-002, AS-VIS-003.
func setup_hull_zone(inner_left: Vector2, outer_left: Vector2,
		inner_right: Vector2, outer_right: Vector2,
		los_pos: Vector2) -> void:
	_play_area_side = GameScale.play_area_side_px
	_draw_hull_zone = true
	_draw_squadron = false
	# Arc boundary left line: inner → outer, extended to play area edge.
	_arc_line_left_start = inner_left
	_arc_line_left_end = _extend_to_boundary(inner_left, outer_left)
	# Arc boundary right line: inner → outer, extended to play area edge.
	_arc_line_right_start = inner_right
	_arc_line_right_end = _extend_to_boundary(inner_right, outer_right)
	# LOS marker.
	_los_position = los_pos
	_log.debug("Hull zone overlay set up. Arc lines: L(%s → %s), R(%s → %s), LOS: %s" % [
			_arc_line_left_start, _arc_line_left_end,
			_arc_line_right_start, _arc_line_right_end,
			_los_position])
	queue_redraw()


## Sets up the overlay for a squadron attacker.
## [param centre] — world-space position of the squadron token.
## [param base_radius] — radius of the squadron's circular base in pixels.
## Requirements: AS-VIS-010.
func setup_squadron(centre: Vector2, base_radius: float) -> void:
	_draw_hull_zone = false
	_draw_squadron = true
	_squad_centre = centre
	_squad_circle_radius = base_radius + GameScale.range_close_px
	_log.debug("Squadron overlay set up. Centre: %s, radius: %.1f" % [
			_squad_centre, _squad_circle_radius])
	queue_redraw()


## Clears all visual aid data.
func clear() -> void:
	_draw_hull_zone = false
	_draw_squadron = false
	queue_redraw()


func _draw() -> void:
	if _draw_hull_zone:
		_draw_arc_lines()
		_draw_los_marker()
	if _draw_squadron:
		_draw_close_range_circle()


# =========================================================================
# Drawing helpers
# =========================================================================

## Draws the two firing arc boundary lines.
func _draw_arc_lines() -> void:
	draw_line(_arc_line_left_start, _arc_line_left_end,
			ARC_LINE_COLOUR, ARC_LINE_WIDTH, true)
	draw_line(_arc_line_right_start, _arc_line_right_end,
			ARC_LINE_COLOUR, ARC_LINE_WIDTH, true)


## Draws the LOS targeting point marker.
func _draw_los_marker() -> void:
	draw_circle(_los_position, LOS_MARKER_RADIUS, LOS_MARKER_COLOUR)


## Draws the close-range circle around a squadron.
func _draw_close_range_circle() -> void:
	draw_arc(_squad_centre, _squad_circle_radius, 0.0, TAU,
			CIRCLE_SEGMENTS, SQUAD_CIRCLE_COLOUR, SQUAD_CIRCLE_WIDTH, true)


# =========================================================================
# Geometry helpers
# =========================================================================

## Extends a ray from [param origin] through [param through] until it
## reaches the play area boundary rectangle [0, 0] → [side, side].
## Returns the intersection point on the boundary.
func _extend_to_boundary(origin: Vector2, through: Vector2) -> Vector2:
	var direction: Vector2 = (through - origin).normalized()
	if direction.is_zero_approx():
		return through
	var side: float = _play_area_side
	if side <= 0.0:
		return through
	# Find the minimum positive t where the ray exits the [0, side] box.
	var t_min: float = INF
	# Left edge (x = 0).
	if direction.x < -1e-6:
		var t: float = (0.0 - origin.x) / direction.x
		if t > 0.0:
			t_min = minf(t_min, t)
	# Right edge (x = side).
	if direction.x > 1e-6:
		var t: float = (side - origin.x) / direction.x
		if t > 0.0:
			t_min = minf(t_min, t)
	# Top edge (y = 0).
	if direction.y < -1e-6:
		var t: float = (0.0 - origin.y) / direction.y
		if t > 0.0:
			t_min = minf(t_min, t)
	# Bottom edge (y = side).
	if direction.y > 1e-6:
		var t: float = (side - origin.y) / direction.y
		if t > 0.0:
			t_min = minf(t_min, t)
	if t_min == INF:
		return through
	return origin + direction * t_min
