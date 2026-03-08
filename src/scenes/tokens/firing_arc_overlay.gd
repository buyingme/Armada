## FiringArcOverlay
##
## Draws semi-transparent firing arc wedges for the four hull zones of a ship.
## Attach as a direct child of ShipToken. The overlay inherits the parent
## node's position and rotation, so it draws in ship-local space.
##
## Visibility should be toggled by the player (UI-011). Call
## [method set_visible] to show or hide all arcs at once.
##
## Angle convention in _draw(): ship faces -Y (up on screen).
##   angle 0   = +X (right)   angle -π/2 = -Y (ship facing, FRONT centre)
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

## Number of polygon segments used to approximate the curved arc edge.
const ARC_SEGMENTS: int = 24

## Per-zone fill colours (keyed by HullZone int value).
## FRONT=0 blue, LEFT=1 green, RIGHT=2 yellow, REAR=3 red.
## Rules Reference: UI-011 colour coding.
const _ZONE_BASE_COLOURS: Array[Color] = [
	Color(0.30, 0.70, 1.00),  # FRONT — blue
	Color(0.30, 1.00, 0.40),  # LEFT  — green
	Color(1.00, 0.90, 0.20),  # RIGHT — yellow
	Color(1.00, 0.35, 0.30),  # REAR  — red
]

## Arc angle ranges in radians [from, to] per hull zone.
## Angles follow Godot 2D convention: 0 = +X (right), -π/2 = -Y (up = ship forward).
## Indices match Constants.HullZone: FRONT=0, LEFT=1, RIGHT=2, REAR=3.
## Each zone spans 90° (π/2 rad), bounded by the four 45° diagonal lines.
##
## Boundary diagram (ship faces -Y = up on screen, rotation=0):
##   upper-left diagonal = -3π/4  → LEFT/FRONT boundary
##   upper-right diagonal = -π/4  → FRONT/RIGHT boundary
##   lower-right diagonal =  π/4  → RIGHT/REAR boundary
##   lower-left diagonal  =  3π/4 → REAR/LEFT boundary
const _ZONE_ANGLES: Array[Array] = [
	[-2.35619449, -0.78539816],  # FRONT (0): -3π/4 to -π/4  (upper/forward quadrant)
	[ 2.35619449,  3.92699082],  # LEFT  (1):  3π/4 to  5π/4 (port = left when facing -Y)
	[-0.78539816,  0.78539816],  # RIGHT (2): -π/4 to   π/4  (starboard = right when facing -Y)
	[ 0.78539816,  2.35619449],  # REAR  (3):  π/4 to   3π/4 (lower/aft quadrant)
]


func _draw() -> void:
	for zone_int: int in range(4):
		var angles: Array = _ZONE_ANGLES[zone_int]
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
