## Test: PlayMode
##
## Unit tests for the PlayMode autoload singleton.
## Requirements: PM-001–004.
extends GutTest


func after_each() -> void:
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT


func test_default_mode_is_hot_seat() -> void:
	assert_eq(PlayMode.current_mode, PlayMode.Mode.HOT_SEAT,
			"Default mode should be HOT_SEAT")


func test_is_hot_seat_returns_true_when_hot_seat() -> void:
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT
	assert_true(PlayMode.is_hot_seat(),
			"is_hot_seat() should be true in HOT_SEAT mode")


func test_is_hot_seat_returns_false_when_network() -> void:
	PlayMode.current_mode = PlayMode.Mode.NETWORK
	assert_false(PlayMode.is_hot_seat(),
			"is_hot_seat() should be false in NETWORK mode")


func test_is_network_returns_true_when_network() -> void:
	PlayMode.current_mode = PlayMode.Mode.NETWORK
	assert_true(PlayMode.is_network(),
			"is_network() should be true in NETWORK mode")


func test_is_network_returns_false_when_hot_seat() -> void:
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT
	assert_false(PlayMode.is_network(),
			"is_network() should be false in HOT_SEAT mode")


func test_set_mode_changes_to_network() -> void:
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	assert_eq(PlayMode.current_mode, PlayMode.Mode.NETWORK,
			"set_mode should change to NETWORK")


func test_set_mode_changes_to_hot_seat() -> void:
	PlayMode.current_mode = PlayMode.Mode.NETWORK
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	assert_eq(PlayMode.current_mode, PlayMode.Mode.HOT_SEAT,
			"set_mode should change to HOT_SEAT")


# ---------------------------------------------------------------------------
# Phase K1 — seat_controls_camera()
# ---------------------------------------------------------------------------


func test_seat_controls_camera_network_always_true() -> void:
	PlayMode.current_mode = PlayMode.Mode.NETWORK
	assert_true(PlayMode.seat_controls_camera(0, 0),
			"network: local seat controls its own camera")
	assert_true(PlayMode.seat_controls_camera(0, 1),
			"network: each peer controls its camera regardless of active player")
	assert_true(PlayMode.seat_controls_camera(1, 0),
			"network: each peer controls its camera regardless of active player")
	assert_true(PlayMode.seat_controls_camera(-1, 0),
			"network: each peer controls its camera even with no active turn")


func test_seat_controls_camera_hot_seat_active_seat_only() -> void:
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT
	assert_true(PlayMode.seat_controls_camera(0, 0),
			"hot-seat: active seat controls camera")
	assert_true(PlayMode.seat_controls_camera(1, 1),
			"hot-seat: active seat controls camera (player 1)")


func test_seat_controls_camera_hot_seat_non_active_false() -> void:
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT
	assert_false(PlayMode.seat_controls_camera(0, 1),
			"hot-seat: non-active seat does not control camera")
	assert_false(PlayMode.seat_controls_camera(1, 0),
			"hot-seat: non-active seat does not control camera")


func test_seat_controls_camera_hot_seat_no_active_turn() -> void:
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT
	assert_false(PlayMode.seat_controls_camera(-1, 0),
			"hot-seat: no active turn means no seat controls the camera")
	assert_false(PlayMode.seat_controls_camera(-1, 1),
			"hot-seat: no active turn means no seat controls the camera")
