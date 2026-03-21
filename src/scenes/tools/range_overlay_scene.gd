## RangeOverlayScene
##
## Draws the range-band overlay and firing arc boundary lines for one ship.
## Added as a child of the token container on the game board (position 0,0,
## no rotation) so all drawing is in world space.
##
## Uses [RangeOverlayCalculator] to compute geometry, then renders via _draw():
## • Semi-transparent band fills (grey/blue/red for close/medium/long).
## • White arc boundary lines extending beyond the ship base.
##
## Requirements: RO-003, RO-004, RO-005, RO-006.
## Rules Reference: "Firing Arcs", p.3; "Range and Distance", p.10.
class_name RangeOverlayScene
extends Node2D


## Band fill colours.
const CLOSE_COLOUR: Color = Color(0.50, 0.50, 0.50, 0.12)   # grey
const MEDIUM_COLOUR: Color = Color(0.27, 0.53, 1.00, 0.12)   # blue #4488FF
const LONG_COLOUR: Color = Color(1.00, 0.27, 0.27, 0.12)     # red  #FF4444

## Arc boundary line style.
const ARC_LINE_COLOUR: Color = Color(1.0, 1.0, 1.0, 0.70)
const ARC_LINE_WIDTH: float = 1.5

## Maps band name → fill colour.
const BAND_COLOURS: Dictionary = {
	"close": CLOSE_COLOUR,
	"medium": MEDIUM_COLOUR,
	"long": LONG_COLOUR,
}

## Cached calculator results.
var _arc_lines: Array = []
var _band_polygons: Dictionary = {}


## Initialises the overlay for [param token].
## Computes all geometry immediately and triggers a draw.
func setup(token: ShipToken) -> void:
	var ship_data: ShipData = token.get_ship_data()
	if ship_data == null:
		return

	var boundaries: Dictionary = token.get_firing_arc_world_points()
	if boundaries.is_empty():
		return

	# Build the base polygon in world space.
	var hw: float = token.get_half_width()
	var hl: float = token.get_half_length()
	var local_base: PackedVector2Array = PackedVector2Array([
		Vector2(-hw, -hl),  # front-left
		Vector2( hw, -hl),  # front-right
		Vector2( hw,  hl),  # rear-right
		Vector2(-hw,  hl),  # rear-left
	])
	var base_poly: PackedVector2Array = PackedVector2Array()
	base_poly.resize(4)
	for i: int in range(4):
		base_poly[i] = token.to_global(local_base[i])

	# Run the calculator.
	var calc: RangeOverlayCalculator = RangeOverlayCalculator.new()
	calc.compute(
		base_poly,
		boundaries,
		GameScale.range_close_px,
		GameScale.range_medium_px,
		GameScale.range_long_px)

	_arc_lines = calc.arc_lines
	_band_polygons = calc.band_polygons
	queue_redraw()


func _draw() -> void:
	_draw_bands()
	_draw_arc_lines()


## Draws all range band fill polygons.
func _draw_bands() -> void:
	for zone: int in _band_polygons:
		var bands: Dictionary = _band_polygons[zone]
		for band_name: String in ["close", "medium", "long"]:
			var colour: Color = BAND_COLOURS.get(band_name, CLOSE_COLOUR)
			var polys: Array = bands.get(band_name, [])
			for poly: PackedVector2Array in polys:
				if poly.size() >= 3:
					draw_colored_polygon(poly, colour)


## Draws the arc boundary lines (white, extended).
func _draw_arc_lines() -> void:
	for seg: Array in _arc_lines:
		if seg.size() >= 2:
			draw_line(seg[0] as Vector2, seg[1] as Vector2,
					ARC_LINE_COLOUR, ARC_LINE_WIDTH)
