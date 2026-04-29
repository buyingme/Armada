## Unit tests for DefenseMirrorPanel
##
## Phase I6b-3 slice A — read-only defender mirror panel.
extends GutTest


var _panel: DefenseMirrorPanel = null


func before_each() -> void:
	_panel = DefenseMirrorPanel.new()
	add_child_autofree(_panel)


func test_initial_state_hidden() -> void:
	assert_false(_panel.visible,
			"Mirror should be hidden initially.")
	assert_false(_panel.is_open(),
			"is_open() should be false initially.")


func test_open_makes_visible() -> void:
	_panel.open("Demolisher", Constants.HullZone.FRONT, 4, 0)
	assert_true(_panel.visible,
			"Panel should be visible after open().")
	assert_true(_panel.is_open(),
			"is_open() should be true after open().")


func test_open_renders_ship_name_in_title() -> void:
	_panel.open("CR90 Corvette A", Constants.HullZone.LEFT, 2, 0)
	assert_string_contains(_panel._title_label.text, "CR90 Corvette A",
			"Title should contain the defender ship name.")


func test_open_renders_zone_name() -> void:
	_panel.open("Demolisher", Constants.HullZone.REAR, 3, 0)
	assert_string_contains(_panel._info_label.text, "REAR",
			"Info label should display the hit zone.")


func test_open_renders_modified_damage() -> void:
	_panel.open("Demolisher", Constants.HullZone.FRONT, 7, 0)
	assert_string_contains(_panel._damage_label.text, "7",
			"Damage label should display the modified damage.")


func test_open_hides_tokens_label_when_no_locked_tokens() -> void:
	_panel.open("Demolisher", Constants.HullZone.FRONT, 4, 0)
	assert_false(_panel._tokens_label.visible,
			"Tokens label should be hidden when no tokens are locked.")


func test_open_shows_tokens_label_when_locked_tokens_present() -> void:
	_panel.open("Demolisher", Constants.HullZone.FRONT, 4, 2)
	assert_true(_panel._tokens_label.visible,
			"Tokens label should be visible when tokens are locked.")
	assert_string_contains(_panel._tokens_label.text, "2",
			"Tokens label should display the locked count.")


func test_close_hides_panel() -> void:
	_panel.open("Demolisher", Constants.HullZone.FRONT, 4, 0)
	_panel.close()
	assert_false(_panel.visible,
			"Panel should be hidden after close().")
	assert_false(_panel.is_open(),
			"is_open() should be false after close().")


func test_close_is_idempotent_when_already_closed() -> void:
	_panel.close()
	assert_false(_panel.visible,
			"close() on a hidden panel should remain hidden.")


func test_open_after_close_rebuilds_state() -> void:
	_panel.open("Ship A", Constants.HullZone.FRONT, 3, 1)
	_panel.close()
	_panel.open("Ship B", Constants.HullZone.LEFT, 5, 0)
	assert_string_contains(_panel._title_label.text, "Ship B",
			"Reopening should refresh the ship name.")
	assert_string_contains(_panel._info_label.text, "LEFT",
			"Reopening should refresh the hit zone.")
	assert_string_contains(_panel._damage_label.text, "5",
			"Reopening should refresh the modified damage.")
	assert_false(_panel._tokens_label.visible,
			"Reopening with zero locked tokens should hide that row.")


func test_open_handles_unknown_zone_value() -> void:
	_panel.open("Demolisher", -1, 4, 0)
	assert_string_contains(_panel._info_label.text, "?",
			"Unknown zone should fall back to '?'.")
