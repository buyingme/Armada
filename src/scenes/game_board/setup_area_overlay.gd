## SetupAreaOverlay
##
## Visual setup-phase overlay that highlights the setup region and the player
## deployment zones during obstacle placement and deployment.
class_name SetupAreaOverlay
extends Node2D


const BOUNDARY_COLOUR: Color = Color(0.52, 0.72, 1.0, 0.38)
const BOUNDARY_WIDTH_PX: float = 2.0
const DEPLOY_ZONE_COLOUR: Color = Color(0.42, 0.62, 1.0, 0.18)
const SETUP_REGION_COLOUR: Color = Color(0.48, 0.68, 1.0, 0.08)

var _modal_kind: Constants.ModalKind = Constants.ModalKind.NONE


## Updates which setup step should display the overlay.
func set_modal_kind(modal_kind: Constants.ModalKind) -> void:
	_modal_kind = modal_kind
	visible = _is_visible_for_step(modal_kind)
	queue_redraw()


func _draw() -> void:
	if not _is_visible_for_step(_modal_kind):
		return
	var play_area_size: Vector2 = GameScale.play_area_size_px
	if play_area_size.x <= 0.0 or play_area_size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, play_area_size), SETUP_REGION_COLOUR, true)
	var top_y: float = DeploymentZoneOverlay.get_top_line_y()
	var bottom_y: float = DeploymentZoneOverlay.get_bottom_line_y()
	if top_y > 0.0:
		draw_rect(Rect2(Vector2.ZERO, Vector2(play_area_size.x, top_y)),
				DEPLOY_ZONE_COLOUR, true)
		draw_line(Vector2(0.0, top_y), Vector2(play_area_size.x, top_y),
				BOUNDARY_COLOUR, BOUNDARY_WIDTH_PX)
	if bottom_y >= 0.0 and bottom_y < play_area_size.y:
		draw_rect(Rect2(Vector2(0.0, bottom_y),
				Vector2(play_area_size.x, play_area_size.y - bottom_y)),
				DEPLOY_ZONE_COLOUR, true)
		draw_line(Vector2(0.0, bottom_y), Vector2(play_area_size.x, bottom_y),
				BOUNDARY_COLOUR, BOUNDARY_WIDTH_PX)


func _is_visible_for_step(modal_kind: Constants.ModalKind) -> bool:
	return modal_kind == Constants.ModalKind.SETUP_OBSTACLE_PLACEMENT \
			or modal_kind == Constants.ModalKind.SETUP_SHIP_DEPLOYMENT \
			or modal_kind == Constants.ModalKind.SETUP_SQUADRON_DEPLOYMENT
