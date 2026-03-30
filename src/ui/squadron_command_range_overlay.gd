## SquadronCommandRangeOverlay
##
## Visual overlay drawn on the game board when a ship is executing the
## Squadron command.  Draws two concentric rings centred on the
## activating ship showing the close and medium range bands.
## Squadrons within the medium ring (outer) are eligible for activation.
##
## Added as a child of the token container, positioned at the ship's
## world coordinates.  Renders above the map but below all tokens.
##
## Requirements: CM-020 — squadron command is close–medium range.
## Rules Reference: RRG "Commands" p.4 — "Squadrons at close–medium range."
class_name SquadronCommandRangeOverlay
extends Node2D


## Translucent fill for the close range band.
const CLOSE_FILL_COLOUR: Color = Color(0.2, 0.7, 0.5, 0.08)
## Outline colour for the close range boundary.
const CLOSE_OUTLINE_COLOUR: Color = Color(0.3, 0.8, 0.6, 0.45)

## Translucent fill for the medium range band (between close and medium).
const MEDIUM_FILL_COLOUR: Color = Color(0.2, 0.5, 0.8, 0.08)
## Outline colour for the medium range boundary.
const MEDIUM_OUTLINE_COLOUR: Color = Color(0.3, 0.6, 0.9, 0.55)

## Outline widths.
const CLOSE_OUTLINE_WIDTH: float = 1.5
const MEDIUM_OUTLINE_WIDTH: float = 2.5

## Number of segments for circle drawing.
const CIRCLE_SEGMENTS: int = 64

## Close range radius in pixels.
var _close_radius_px: float = 0.0
## Medium range radius in pixels.
var _medium_radius_px: float = 0.0


## Configures the overlay for a ship executing the Squadron command.
## [param ship_pos] — world position of the activating ship.
func setup(ship_pos: Vector2) -> void:
	position = ship_pos
	_close_radius_px = GameScale.range_close_px
	_medium_radius_px = GameScale.range_medium_px
	queue_redraw()


func _draw() -> void:
	if _medium_radius_px <= 0.0:
		return
	# Medium range band fill (outer ring).
	draw_circle(Vector2.ZERO, _medium_radius_px, MEDIUM_FILL_COLOUR)
	# Close range band fill (inner ring — drawn on top, slightly different).
	if _close_radius_px > 0.0:
		draw_circle(Vector2.ZERO, _close_radius_px, CLOSE_FILL_COLOUR)
	# Outlines.
	if _close_radius_px > 0.0:
		draw_arc(Vector2.ZERO, _close_radius_px, 0.0, TAU,
				CIRCLE_SEGMENTS, CLOSE_OUTLINE_COLOUR,
				CLOSE_OUTLINE_WIDTH, true)
	draw_arc(Vector2.ZERO, _medium_radius_px, 0.0, TAU,
			CIRCLE_SEGMENTS, MEDIUM_OUTLINE_COLOUR,
			MEDIUM_OUTLINE_WIDTH, true)
