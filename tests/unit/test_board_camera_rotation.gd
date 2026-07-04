## Test: Board Camera — Rotation
##
## Unit tests for the BoardCamera rotate_to_player method.
## Requirements: BP-001, BP-002.
extends GutTest


var _camera: BoardCamera = null
var _perspective_complete_count: int = 0


func before_each() -> void:
	_perspective_complete_count = 0
	_camera = BoardCamera.new()
	add_child_autofree(_camera)
	EventBus.perspective_change_complete.connect(
			_on_perspective_complete)


func after_each() -> void:
	if EventBus.perspective_change_complete.is_connected(
			_on_perspective_complete):
		EventBus.perspective_change_complete.disconnect(
				_on_perspective_complete)


func _on_perspective_complete() -> void:
	_perspective_complete_count += 1


func test_initial_player_is_zero() -> void:
	assert_eq(_camera.get_current_player(), 0,
			"Camera should face player 0 initially")


func test_rotate_to_same_player_emits_complete() -> void:
	_camera.rotate_to_player(0)
	assert_eq(_perspective_complete_count, 1,
			"Rotating to same player should emit complete immediately")


func test_rotate_to_player_one_updates_current() -> void:
	_camera.rotate_to_player(1)
	assert_eq(_camera.get_current_player(), 1,
			"Current player should update to 1")


func test_rotate_to_player_zero_updates_current() -> void:
	_camera.rotate_to_player(1)
	_camera.rotate_to_player(0)
	assert_eq(_camera.get_current_player(), 0,
			"Current player should update to 0")


func test_player_zero_perspective_is_not_rotated() -> void:
	_camera.rotate_to_player(0)
	assert_almost_eq(_camera.rotation, 0.0, 0.001,
			"Player 0 should use the not-rotated board edge.")


func test_player_one_perspective_is_rotated() -> void:
	_camera.rotate_to_player(1)
	await get_tree().create_timer(BoardCamera.ROTATE_DURATION + 0.1).timeout
	assert_almost_eq(_camera.rotation, PI, 0.001,
			"Player 1 should use the rotated board edge.")
