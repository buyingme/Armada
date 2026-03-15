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
