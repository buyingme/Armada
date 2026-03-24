## Unit tests for AttackSimPanel
##
## Covers: AS-PNL-001, AS-PNL-002, AS-PNL-003, AS-VIS-004, AS-VIS-011.
extends GutTest


var _panel: AttackSimPanel = null


func before_each() -> void:
	_panel = AttackSimPanel.new()
	add_child_autofree(_panel)


func test_initial_state_hidden() -> void:
	assert_false(_panel.visible,
			"Panel should be hidden initially.")


func test_show_initial_makes_visible() -> void:
	_panel.show_initial()
	assert_true(_panel.visible,
			"Panel should be visible after show_initial().")


func test_show_initial_title_text() -> void:
	_panel.show_initial()
	assert_eq(_panel.get_title_text(), "Attack Simulator",
			"Title should say 'Attack Simulator'.")


func test_show_initial_body_text() -> void:
	_panel.show_initial()
	assert_eq(_panel.get_body_text(), AttackSimPanel.INITIAL_PROMPT,
			"Body should show the initial prompt.")


func test_close_hides_panel() -> void:
	_panel.show_initial()
	_panel.close()
	assert_false(_panel.visible,
			"Panel should be hidden after close().")


func test_show_hull_zone_selected_updates_title() -> void:
	_panel.show_initial()
	_panel.show_hull_zone_selected("CR90 Corvette A", "FRONT")
	assert_eq(_panel.get_title_text(),
			"Attacking: CR90 Corvette A — FRONT arc",
			"Title should show ship name and zone.")


func test_show_hull_zone_selected_updates_body() -> void:
	_panel.show_initial()
	_panel.show_hull_zone_selected("CR90 Corvette A", "FRONT")
	assert_string_contains(_panel.get_body_text(), "not yet implemented",
			"Body should indicate next step is not yet implemented.")


func test_show_squadron_selected_updates_title() -> void:
	_panel.show_initial()
	_panel.show_squadron_selected("X-wing Alpha")
	assert_eq(_panel.get_title_text(),
			"Attacking: X-wing Alpha",
			"Title should show squadron name.")


func test_show_squadron_selected_updates_body() -> void:
	_panel.show_initial()
	_panel.show_squadron_selected("X-wing Alpha")
	assert_string_contains(_panel.get_body_text(), "not yet implemented",
			"Body should indicate next step is not yet implemented.")
