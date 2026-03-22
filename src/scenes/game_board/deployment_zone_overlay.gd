## DeploymentZoneOverlay
##
## Draws two thin blue horizontal lines marking the deployment zone boundaries.
## Each line is at distance band 3 (GameScale.distance_bands_px[2]) inward
## from the top and bottom board edges.
##
## Only visible when DebugMode is enabled (DBG-030).
##
## Requirements: DBG-030, DBG-031
class_name DeploymentZoneOverlay
extends Node2D


## Colour for the deployment zone lines.
const LINE_COLOUR: Color = Color(0.3, 0.5, 1.0, 0.8)

## Line width in pixels.
const LINE_WIDTH: float = 2.0


## Returns the Y coordinate of the top deployment line (Imperial zone boundary).
## Returns -1.0 if distance bands are not loaded.
static func get_top_line_y() -> float:
	if GameScale.distance_bands_px.size() < 3:
		return -1.0
	return GameScale.distance_bands_px[2]


## Returns the Y coordinate of the bottom deployment line (Rebel zone boundary).
## Returns -1.0 if distance bands are not loaded.
static func get_bottom_line_y() -> float:
	if GameScale.distance_bands_px.size() < 3:
		return -1.0
	return GameScale.play_area_side_px - GameScale.distance_bands_px[2]


## Returns true if [param pos_y] is within the deployment zone for [param faction].
## Imperial zone: top edge (0) up to top_line_y.
## Rebel zone: bottom_line_y down to bottom edge (play_area_side_px).
## Returns true (in zone) if deployment zones are not loaded.
## DBG-033 — used to detect zone crossings for toast warnings.
static func is_in_deploy_zone(pos_y: float, faction: Constants.Faction) -> bool:
	var top_y: float = get_top_line_y()
	var bottom_y: float = get_bottom_line_y()
	if top_y < 0.0 or bottom_y < 0.0:
		return true
	match faction:
		Constants.Faction.GALACTIC_EMPIRE:
			return pos_y <= top_y
		Constants.Faction.REBEL_ALLIANCE:
			return pos_y >= bottom_y
		_:
			return true


func _draw() -> void:
	var side: float = GameScale.play_area_side_px
	if side <= 0.0:
		return
	var top_y: float = get_top_line_y()
	var bottom_y: float = get_bottom_line_y()
	if top_y >= 0.0:
		draw_line(Vector2(0.0, top_y), Vector2(side, top_y),
				LINE_COLOUR, LINE_WIDTH)
	if bottom_y >= 0.0:
		draw_line(Vector2(0.0, bottom_y), Vector2(side, bottom_y),
				LINE_COLOUR, LINE_WIDTH)
