## TokenPlacement
##
## Data object describing the initial placement of a single ship or squadron
## token for the Learning Scenario. Created by [LearningScenarioSetup].
##
## All positions are normalised: 0.0 = left/top edge of play area,
## 1.0 = right/bottom edge of play area.
##
## Rules Reference: "Learning Scenario Setup Diagram", SWM01-ARMADA-LEARN-TO-PLAY p.6.
class_name TokenPlacement
extends RefCounted


## Key used to look up JSON + PNG in Resources/Game_Components.
var data_key: String

## True if this token is a ship, false if it is a squadron.
var is_ship: bool

## Faction that controls this token.
var faction: Constants.Faction

## Normalised X position (0 = left edge, 1 = right edge).
var pos_x: float

## Normalised Y position (0 = top edge, 1 = bottom edge).
var pos_y: float

## Initial rotation in radians. 0 = facing -Y (up on screen).
## Rules Reference: ships start facing the opposite deployment zone.
var rotation_rad: float

## Ship size (used for base polygon dimensions; ignored for squadrons).
var ship_size: Constants.ShipSize


func _init(
		key: String,
		ship: bool,
		fac: Constants.Faction,
		x: float,
		y: float,
		rot: float,
		size: Constants.ShipSize = Constants.ShipSize.SMALL
) -> void:
	data_key = key
	is_ship = ship
	faction = fac
	pos_x = x
	pos_y = y
	rotation_rad = rot
	ship_size = size


## Returns the normalised position as a Vector2.
func get_normalised_position() -> Vector2:
	return Vector2(pos_x, pos_y)


## Returns the pixel position within a play area of the given side length.
func get_pixel_position(play_area_side_px: float) -> Vector2:
	return get_normalised_position() * play_area_side_px
