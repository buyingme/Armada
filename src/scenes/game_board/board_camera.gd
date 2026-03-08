## BoardCamera
##
## Camera2D controller for the game board.
## Supports right-click drag to pan and scroll-wheel to zoom.
## Camera position is clamped to the play area with a configurable margin.
##
## Attach this script to a Camera2D node. Call [method reset_to_default_view]
## after GameScale is initialised to frame the full play area.
##
## Rules Reference: UI-001 (pannable / zoomable play area view).
class_name BoardCamera
extends Camera2D


## Minimum zoom factor (fully zoomed out — shows more of the play area).
const ZOOM_MIN: float = 0.20

## Maximum zoom factor (fully zoomed in).
const ZOOM_MAX: float = 5.0

## Zoom change applied per scroll-wheel tick.
const ZOOM_STEP: float = 0.10

## Extra space in pixels beyond the play area edges within which
## the camera may still be positioned.
const BOUNDARY_MARGIN_PX: float = 300.0

## Whether the player is currently dragging to pan.
var _is_panning: bool = false

## Screen-space mouse position at the moment a pan drag began.
var _drag_start_screen: Vector2 = Vector2.ZERO

## Camera world-space position at the moment a pan drag began.
var _drag_start_camera: Vector2 = Vector2.ZERO


func _ready() -> void:
	reset_to_default_view()


## Resets the camera so the full play area is visible and centred.
func reset_to_default_view() -> void:
	if GameScale.play_area_side_px <= 0.0:
		return
	var side: float = GameScale.play_area_side_px
	position = Vector2(side * 0.5, side * 0.5)
	# Fit the entire play area into the viewport while keeping aspect ratio.
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x > 0.0 and vp_size.y > 0.0:
		var fit_zoom: float = minf(vp_size.x / side, vp_size.y / side)
		zoom = Vector2(fit_zoom, fit_zoom)
	else:
		zoom = Vector2.ONE


## Returns the play-area side length in pixels from [GameScale].
func get_play_area_side() -> float:
	return GameScale.play_area_side_px


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _is_panning:
		_handle_pan_motion(event as InputEventMouseMotion)


## Handles mouse button press/release for pan and zoom.
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_RIGHT:
			_is_panning = event.pressed
			if event.pressed:
				_drag_start_screen = event.position
				_drag_start_camera = position
		MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(ZOOM_STEP, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(-ZOOM_STEP, event.position)


## Pans the camera as the mouse moves during a right-click drag.
func _handle_pan_motion(event: InputEventMouseMotion) -> void:
	var screen_delta: Vector2 = event.position - _drag_start_screen
	var world_delta: Vector2 = screen_delta / zoom
	var new_pos: Vector2 = _drag_start_camera - world_delta
	position = _clamp_position(new_pos)


## Adjusts zoom by [delta], keeping the world point under [screen_pivot] fixed.
func _apply_zoom(delta: float, screen_pivot: Vector2) -> void:
	var old_zoom: float = zoom.x
	var new_zoom: float = clampf(old_zoom + delta, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(new_zoom, old_zoom):
		return
	var world_before: Vector2 = _screen_to_world(screen_pivot)
	zoom = Vector2(new_zoom, new_zoom)
	var world_after: Vector2 = _screen_to_world(screen_pivot)
	position = _clamp_position(position + world_before - world_after)


## Converts a screen-space position to world-space for this camera.
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var vp_size: Vector2 = get_viewport_rect().size
	return position + (screen_pos - vp_size * 0.5) / zoom


## Clamps [pos] so the camera stays within the play area + margin.
func _clamp_position(pos: Vector2) -> Vector2:
	var side: float = GameScale.play_area_side_px
	if side <= 0.0:
		return pos
	var m: float = BOUNDARY_MARGIN_PX
	return Vector2(
			clampf(pos.x, -m, side + m),
			clampf(pos.y, -m, side + m)
	)
