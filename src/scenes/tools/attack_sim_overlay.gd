## AttackSimOverlay
##
## Visual aids drawn on the game board when an attacker is selected in the
## Attack Simulator.  Added as a child of the token container so it renders
## in world space alongside tokens.
##
## For hull zone selection: draws two firing arc boundary lines and a LOS marker.
## For squadron selection: draws a close-range circle.
## When a target is selected: draws a target LOS marker, a colour-coded
## LOS line, and a colour-coded range measurement line between attacker
## and target.
## The range overlay (RangeOverlayScene) is managed separately by the game board.
##
## Requirements: AS-VIS-002, AS-VIS-003, AS-VIS-010, AS-VIS-020–022,
## AS-RNG-010–013.
## Rules Reference: "Firing Arcs", p.3; "Line of Sight", p.10;
## "Attack Range", p.3.
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
## Requirements: AS-VIS-003, AS-VIS-020.
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

## LOS line colour when clear — yellow, 80 % opacity.
## Requirements: AS-VIS-022.
const LOS_LINE_CLEAR: Color = Color(1.0, 1.0, 0.0, 0.8)

## LOS line colour when obstructed — orange, 80 % opacity.
## Requirements: AS-VIS-022.
const LOS_LINE_OBSTRUCTED: Color = Color(1.0, 0.6, 0.0, 0.8)

## LOS line colour when blocked — red, 60 % opacity.
## Requirements: AS-VIS-022.
const LOS_LINE_BLOCKED: Color = Color(1.0, 0.0, 0.0, 0.6)

## Width of the LOS line in pixels.
## Requirements: AS-VIS-021.
const LOS_LINE_WIDTH: float = 2.0

## Range line colour for close range — grey, 80 % opacity.
## Requirements: AS-RNG-012.
const RANGE_LINE_CLOSE: Color = Color(0.7, 0.7, 0.7, 0.8)

## Range line colour for medium range — blue, 80 % opacity.
## Requirements: AS-RNG-012.
const RANGE_LINE_MEDIUM: Color = Color(0.2, 0.4, 1.0, 0.8)

## Range line colour for long range — red, 80 % opacity.
## Requirements: AS-RNG-012.
const RANGE_LINE_LONG: Color = Color(1.0, 0.15, 0.15, 0.8)

## Range line colour for beyond range — purple, 80 % opacity.
## Requirements: AS-RNG-012.
const RANGE_LINE_BEYOND: Color = Color(0.6, 0.1, 0.9, 0.8)

## Width of the range measurement line in pixels.
const RANGE_LINE_WIDTH: float = 2.0

## LOS status enum for setup_los_line().
enum LOSStatus {CLEAR, OBSTRUCTED, BLOCKED}

## When true, suppresses firing arc boundary lines and range measurement
## line.  LOS markers and LOS line are still drawn.  Used during the real
## attack execution step (as opposed to the free-form attack simulator).
## Requirements: AE-VIS-001.
var attack_execution_mode: bool = false

## Colour for spent hull zone marker — red, 60 % opacity.
## Requirements: AE-2HZ-003.
const SPENT_ZONE_COLOUR: Color = Color(1.0, 0.0, 0.0, 0.6)

## Radius of the spent zone marker in pixels (6 px diameter → 3 px radius).
const SPENT_ZONE_RADIUS: float = 3.0

## Positions of spent hull zone markers (world space).
var _spent_zone_positions: Array[Vector2] = []

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
## Radius of the distance-1 attack range circle (base radius + distance 1).
var _squad_circle_radius: float = 0.0
## Whether squadron visuals should be drawn.
var _draw_squadron: bool = false

# --- Target visuals ---

## World-space position of the target's LOS point.
var _target_los_position: Vector2 = Vector2.ZERO
## Whether a target LOS marker should be drawn.
var _draw_target_marker: bool = false
## Start point of the LOS line (attacker side).
var _los_line_start: Vector2 = Vector2.ZERO
## End point of the LOS line (target side).
var _los_line_end: Vector2 = Vector2.ZERO
## Colour of the LOS line (derived from status).
var _los_line_colour: Color = LOS_LINE_CLEAR
## Whether the LOS line should be drawn.
var _draw_los_line: bool = false

# --- Range line visuals ---

## Start point of the range line (attacker closest point).
var _range_line_start: Vector2 = Vector2.ZERO
## End point of the range line (defender closest point).
var _range_line_end: Vector2 = Vector2.ZERO
## Colour of the range line (derived from range band).
var _range_line_colour: Color = RANGE_LINE_CLOSE
## Whether the range line should be drawn.
var _draw_range_line: bool = false


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
	# Arc boundary lines — suppressed in attack execution mode (AE-VIS-001).
	if not attack_execution_mode:
		_arc_line_left_start = inner_left
		_arc_line_left_end = _extend_to_boundary(inner_left, outer_left)
		_arc_line_right_start = inner_right
		_arc_line_right_end = _extend_to_boundary(inner_right, outer_right)
	# LOS marker.
	_los_position = los_pos
	if attack_execution_mode:
		_log.debug("Hull zone overlay set up (exec mode). LOS: %s" % [
				_los_position])
	else:
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
	_squad_circle_radius = base_radius + GameScale.distance_bands_px[0]
	_log.debug("Squadron overlay set up. Centre: %s, radius: %.1f" % [
			_squad_centre, _squad_circle_radius])
	queue_redraw()


## Clears all visual aid data.
func clear() -> void:
	_draw_hull_zone = false
	_draw_squadron = false
	_draw_target_marker = false
	_draw_los_line = false
	_draw_range_line = false
	_spent_zone_positions.clear()
	queue_redraw()


## Clears only the target-related visuals (marker + LOS line).
## Attacker visuals (arc lines, LOS marker, close-range circle) are kept.
## Requirements: AS-TGT-020.
func clear_target() -> void:
	_draw_target_marker = false
	_draw_los_line = false
	_draw_range_line = false
	queue_redraw()


## Sets up the target LOS marker for a defending hull zone.
## [param los_pos] — world-space LOS targeting point of the defending zone.
## Requirements: AS-VIS-020.
func setup_target_hull_zone(los_pos: Vector2) -> void:
	_target_los_position = los_pos
	_draw_target_marker = true
	_log.debug("Target hull zone marker at %s." % los_pos)
	queue_redraw()


## Sets up the target LOS marker for a defending squadron.
## [param centre] — world-space centre of the defending squadron.
## Requirements: AS-VIS-020.
func setup_target_squadron(centre: Vector2) -> void:
	_target_los_position = centre
	_draw_target_marker = true
	_log.debug("Target squadron marker at %s." % centre)
	queue_redraw()


## Sets up the LOS line between attacker and target.
## [param start_pos] — world-space start point (attacker side).
## [param end_pos] — world-space end point (target side).
## [param los_status] — LOSStatus enum value (CLEAR, OBSTRUCTED, BLOCKED).
## Requirements: AS-VIS-021, AS-VIS-022.
func setup_los_line(start_pos: Vector2, end_pos: Vector2,
		los_status: int) -> void:
	_los_line_start = start_pos
	_los_line_end = end_pos
	_draw_los_line = true
	match los_status:
		LOSStatus.OBSTRUCTED:
			_los_line_colour = LOS_LINE_OBSTRUCTED
		LOSStatus.BLOCKED:
			_los_line_colour = LOS_LINE_BLOCKED
		_:
			_los_line_colour = LOS_LINE_CLEAR
	_log.debug("LOS line set up: %s → %s, status=%d." % [
			start_pos, end_pos, los_status])
	queue_redraw()


## Sets up the range measurement line between attacker and target.
## [param start_pos] — world-space closest point on attacker geometry.
## [param end_pos] — world-space closest point on defender geometry.
## [param range_band] — range band string ("close", "medium", "long", "beyond").
## Requirements: AS-RNG-010, AS-RNG-012.
func setup_range_line(start_pos: Vector2, end_pos: Vector2,
		range_band: String) -> void:
	# Range line suppressed in attack execution mode (AE-VIS-001).
	if attack_execution_mode:
		return
	_range_line_start = start_pos
	_range_line_end = end_pos
	_draw_range_line = true
	match range_band:
		Constants.RANGE_BAND_CLOSE:
			_range_line_colour = RANGE_LINE_CLOSE
		Constants.RANGE_BAND_MEDIUM:
			_range_line_colour = RANGE_LINE_MEDIUM
		Constants.RANGE_BAND_LONG:
			_range_line_colour = RANGE_LINE_LONG
		_:
			_range_line_colour = RANGE_LINE_BEYOND
	_log.debug("Range line set up: %s → %s, band=%s." % [
			start_pos, end_pos, range_band])
	queue_redraw()


## Adds a translucent red dot at [param pos] marking a spent hull zone.
## Requirements: AE-2HZ-003.
func add_spent_zone_marker(pos: Vector2) -> void:
	_spent_zone_positions.append(pos)
	_log.debug("Spent zone marker added at %s." % pos)
	queue_redraw()


func _draw() -> void:
	if _draw_hull_zone:
		if not attack_execution_mode:
			_draw_arc_lines()
		_draw_los_marker()
	if _draw_squadron:
		_draw_close_range_circle()
	if _draw_target_marker:
		_draw_target_los_marker()
	if _draw_los_line:
		_draw_los_line_segment()
	if _draw_range_line:
		_draw_range_line_segment()
	for pos: Vector2 in _spent_zone_positions:
		draw_circle(pos, SPENT_ZONE_RADIUS, SPENT_ZONE_COLOUR)


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


## Draws the target's LOS targeting point marker.
## Requirements: AS-VIS-020.
func _draw_target_los_marker() -> void:
	draw_circle(_target_los_position, LOS_MARKER_RADIUS, LOS_MARKER_COLOUR)


## Draws the colour-coded LOS line between attacker and target.
## Requirements: AS-VIS-021, AS-VIS-022.
func _draw_los_line_segment() -> void:
	draw_line(_los_line_start, _los_line_end,
			_los_line_colour, LOS_LINE_WIDTH, true)


## Draws the colour-coded range measurement line.
## Requirements: AS-RNG-010, AS-RNG-012.
func _draw_range_line_segment() -> void:
	draw_line(_range_line_start, _range_line_end,
			_range_line_colour, RANGE_LINE_WIDTH, true)


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
