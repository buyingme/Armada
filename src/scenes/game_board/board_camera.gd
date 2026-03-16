## BoardCamera
##
## Camera2D controller for the game board.
## Supports the following input methods:
##   - Right-click drag       → pan
##   - Scroll wheel           → zoom
##   - Two-finger trackpad swipe  → pan  (InputEventPanGesture, macOS)
##   - Pinch gesture          → zoom (InputEventMagnifyGesture, macOS)
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

## Scaling applied to the magnify gesture factor.
## Factor arrives as a multiplier near 1.0 (e.g. 1.05 = 5% zoom in);
## raising it to this power makes small pinches feel natural.
const ZOOM_MAGNIFY_SENSITIVITY: float = 0.5

## Scaling applied to the trackpad pan delta (screen px → world units).
## The delta is already in screen pixels; dividing by zoom converts to world
## space. This multiplier adjusts feel — 1.0 is a 1:1 finger-to-world ratio.
const PAN_GESTURE_SENSITIVITY: float = 20.0

## Extra space in pixels beyond the play area edges within which
## the camera may still be positioned.
const BOUNDARY_MARGIN_PX: float = 300.0

## Duration of the rotation animation in seconds.
const ROTATE_DURATION: float = 0.5

## Whether the player is currently dragging to pan.
var _is_panning: bool = false

## Screen-space mouse position at the moment a pan drag began.
var _drag_start_screen: Vector2 = Vector2.ZERO

## Camera world-space position at the moment a pan drag began.
var _drag_start_camera: Vector2 = Vector2.ZERO

## The player index the camera currently faces (0 = Rebel, 1 = Imperial).
var _current_player: int = 0

## Active rotation tween (null when idle).
var _rotate_tween: Tween = null


func _ready() -> void:
	# Camera2D ignores Node2D rotation by default — disable that so
	# rotate_to_player() actually rotates the viewport.
	ignore_rotation = false
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
	elif event is InputEventPanGesture:
		_handle_pan_gesture(event as InputEventPanGesture)
	elif event is InputEventMagnifyGesture:
		_handle_magnify_gesture(event as InputEventMagnifyGesture)


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
## The screen delta is rotated by the camera's current rotation so
## panning feels correct when the board is viewed at 180°.
func _handle_pan_motion(event: InputEventMouseMotion) -> void:
	var screen_delta: Vector2 = event.position - _drag_start_screen
	var world_delta: Vector2 = screen_delta.rotated(-rotation) / zoom
	var new_pos: Vector2 = _drag_start_camera - world_delta
	position = _clamp_position(new_pos)


## Pans the camera from a two-finger trackpad swipe.
## [InputEventPanGesture].delta is in screen pixels per frame.
## The delta is rotated by the camera's rotation for correct direction.
## Rules Reference: UI-001 (trackpad pan support).
func _handle_pan_gesture(event: InputEventPanGesture) -> void:
	var world_delta: Vector2 = (event.delta * PAN_GESTURE_SENSITIVITY).rotated(-rotation) / zoom
	position = _clamp_position(position + world_delta)


## Zooms via pinch gesture, keeping the world point under the fingers fixed.
## [InputEventMagnifyGesture].factor is a multiplier (>1 = zoom in).
## Rules Reference: UI-001 (trackpad pinch-to-zoom support).
func _handle_magnify_gesture(event: InputEventMagnifyGesture) -> void:
	var old_zoom: float = zoom.x
	# Apply sensitivity exponent so small pinches produce a usable zoom change.
	var factor: float = pow(event.factor, ZOOM_MAGNIFY_SENSITIVITY)
	var new_zoom: float = clampf(old_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(new_zoom, old_zoom):
		return
	var world_before: Vector2 = _screen_to_world(event.position)
	zoom = Vector2(new_zoom, new_zoom)
	var world_after: Vector2 = _screen_to_world(event.position)
	position = _clamp_position(position + world_before - world_after)


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
## Accounts for camera rotation so zoom pivots work correctly at 180°.
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var vp_size: Vector2 = get_viewport_rect().size
	var screen_offset: Vector2 = (screen_pos - vp_size * 0.5) / zoom
	return position + screen_offset.rotated(-rotation)


## Smoothly rotates the camera so the board faces the given player.
## Player 0 (Rebel) = 0° rotation, Player 1 (Imperial) = 180° rotation.
## The camera rotates around the centre of the play area.
## Emits [signal EventBus.perspective_change_complete] when finished.
## Requirements: BP-001, BP-002.
## [param player_index] — 0 for Rebel perspective, 1 for Imperial.
func rotate_to_player(player_index: int) -> void:
	if player_index == _current_player:
		EventBus.perspective_change_complete.emit()
		return

	_current_player = player_index

	var target_rotation: float = 0.0 if player_index == 0 else PI
	var side: float = GameScale.play_area_side_px
	var centre: Vector2 = Vector2(side * 0.5, side * 0.5)

	# Kill any running rotation tween.
	if _rotate_tween != null and _rotate_tween.is_valid():
		_rotate_tween.kill()

	_rotate_tween = create_tween()
	_rotate_tween.set_ease(Tween.EASE_IN_OUT)
	_rotate_tween.set_trans(Tween.TRANS_CUBIC)
	# Rotate around the play area centre: position stays centred, rotation
	# changes. After the tween, re-centre to account for any drift.
	position = centre
	_rotate_tween.tween_property(self , "rotation", target_rotation,
			ROTATE_DURATION)
	_rotate_tween.tween_callback(EventBus.perspective_change_complete.emit)


## Returns the player index the camera currently faces.
func get_current_player() -> int:
	return _current_player


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
