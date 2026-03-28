## SquadronMoveOverlay
##
## Visual overlay drawn on the game board when a squadron is selected during
## the Squadron Phase.  Draws two circles centred on the squadron's position:
##
## 1. **Movement range** — translucent brownish filled circle whose radius
##    equals the max movement distance for the squadron's speed.
##    Hidden if the squadron cannot move (engagement).
## 2. **Armament range** — coloured outlined circle at distance 1 (both
##    anti-squadron and battery armament are range 1 for squadrons).
##    Green for Imperial, red for Rebel.
##
## Requirements: SQM-001, SQM-002.
## Rules Reference: "Squadron Movement" p.19; "Engagement" p.4.
class_name SquadronMoveOverlay
extends Node2D


## Translucent brown fill for the movement area.
const MOVE_FILL_COLOUR: Color = Color(0.6, 0.4, 0.2, 0.2)
## Outline colour for the movement area.
const MOVE_OUTLINE_COLOUR: Color = Color(0.6, 0.4, 0.2, 0.5)
## Movement outline width.
const MOVE_OUTLINE_WIDTH: float = 2.0

## Red armament circle colour (Rebel).
const ARMAMENT_COLOUR_REBEL: Color = Color(0.8, 0.3, 0.3, 0.5)
## Green armament circle colour (Imperial).
const ARMAMENT_COLOUR_IMPERIAL: Color = Color(0.3, 0.8, 0.3, 0.5)
## Armament circle outline width.
const ARMAMENT_OUTLINE_WIDTH: float = 2.5

## Number of segments for circle drawing.
const CIRCLE_SEGMENTS: int = 48

## Maximum movement distance in pixels (0 = cannot move).
var _move_radius_px: float = 0.0
## Whether movement should be shown (false if squadron cannot move).
var _show_movement: bool = true
## Armament (distance 1) radius in pixels.
var _armament_radius_px: float = 0.0
## Faction colour for the armament circle.
var _armament_colour: Color = ARMAMENT_COLOUR_REBEL


## Configures the overlay for a given squadron.
## [param center_pos] — world position of the squadron token.
## [param speed] — the squadron's speed value.
## [param can_move] — whether the squadron is allowed to move.
## [param faction] — the squadron's faction (determines armament circle colour).
## [param base_radius] — the squadron token's base radius in pixels.
##   The drawn circles are enlarged by this amount so their edge represents
##   the furthest point the token's edge can reach (not its centre).
## Rules Reference: "Range and Distance", p.11 — measured from nearest edge.
func setup(
		center_pos: Vector2,
		speed: int,
		can_move: bool,
		faction: Constants.Faction,
		base_radius: float = 0.0) -> void:
	position = center_pos
	_show_movement = can_move
	_move_radius_px = (_get_max_move_distance(speed) + base_radius) \
			if can_move else 0.0
	_armament_radius_px = _get_distance_1_px() + base_radius
	if faction == Constants.Faction.GALACTIC_EMPIRE:
		_armament_colour = ARMAMENT_COLOUR_IMPERIAL
	else:
		_armament_colour = ARMAMENT_COLOUR_REBEL
	queue_redraw()


## Returns the movement radius in pixels (for external validation display).
func get_move_radius_px() -> float:
	return _move_radius_px


func _draw() -> void:
	# Movement range circle (filled + outline).
	if _show_movement and _move_radius_px > 0.0:
		draw_circle(Vector2.ZERO, _move_radius_px, MOVE_FILL_COLOUR)
		draw_arc(Vector2.ZERO, _move_radius_px, 0.0, TAU,
				CIRCLE_SEGMENTS, MOVE_OUTLINE_COLOUR, MOVE_OUTLINE_WIDTH, true)
	# Armament range circle (outline only).
	if _armament_radius_px > 0.0:
		draw_arc(Vector2.ZERO, _armament_radius_px, 0.0, TAU,
				CIRCLE_SEGMENTS, _armament_colour, ARMAMENT_OUTLINE_WIDTH, true)


## Returns the maximum distance in pixels a squadron with [param speed]
## can move.  Mirrors [method SquadronMover._get_max_move_distance].
## Rules Reference: SM-002 — "up to the distance band matching its speed."
static func _get_max_move_distance(speed: int) -> float:
	var band_idx: int = clampi(speed - 1, 0,
			GameScale.distance_bands_px.size() - 1)
	if band_idx < GameScale.distance_bands_px.size():
		return GameScale.distance_bands_px[band_idx]
	return 999999.0


## Returns the pixel threshold for distance band 1 (armament / engagement range).
static func _get_distance_1_px() -> float:
	if GameScale.distance_bands_px.size() > 0:
		return GameScale.distance_bands_px[0]
	return 100.0
