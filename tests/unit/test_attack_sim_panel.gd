## Unit tests for AttackSimPanel
##
## Covers: AS-PNL-001, AS-PNL-002, AS-PNL-003, AS-VIS-004, AS-VIS-011,
## AS-PNL-010, AS-PNL-011.
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
	assert_eq(_panel.get_body_text(), "Select a target.",
			"Body should prompt target selection.")


func test_show_squadron_selected_updates_title() -> void:
	_panel.show_initial()
	_panel.show_squadron_selected("X-wing Alpha")
	assert_eq(_panel.get_title_text(),
			"Attacking: X-wing Alpha",
			"Title should show squadron name.")


func test_show_squadron_selected_updates_body() -> void:
	_panel.show_initial()
	_panel.show_squadron_selected("X-wing Alpha")
	assert_eq(_panel.get_body_text(), "Select a target.",
			"Body should prompt target selection.")


func test_show_target_selected_title_ship_to_ship() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"CR90 Corvette A", "FRONT", "VSD", "LEFT", "Clear")
	assert_eq(_panel.get_title_text(),
			"CR90 Corvette A \u2014 FRONT \u2192 VSD \u2014 LEFT",
			"Title should show attacker → target with zones.")


func test_show_target_selected_body_clear() -> void:
	_panel.show_initial()
	_panel.show_target_selected("CR90", "FRONT", "VSD", "LEFT", "Clear")
	assert_eq(_panel.get_body_text(), "LOS: Clear",
			"Body should show LOS result.")


func test_show_target_selected_body_obstructed() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"CR90", "FRONT", "VSD", "LEFT", "Obstructed by Nebulon-B")
	assert_eq(_panel.get_body_text(), "LOS: Obstructed by Nebulon-B",
			"Body should show obstructed result.")


func test_show_target_selected_body_blocked() -> void:
	_panel.show_initial()
	_panel.show_target_selected("CR90", "FRONT", "VSD", "LEFT", "Blocked")
	assert_eq(_panel.get_body_text(), "LOS: Blocked",
			"Body should show blocked result.")


func test_show_target_selected_squadron_attacker() -> void:
	_panel.show_initial()
	_panel.show_target_selected("X-wing Alpha", "", "VSD", "LEFT", "Clear")
	assert_eq(_panel.get_title_text(),
			"X-wing Alpha \u2192 VSD \u2014 LEFT",
			"Squadron attacker should omit zone in title.")


func test_show_target_selected_squadron_target() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"CR90", "FRONT", "TIE Fighter Alpha", "", "Clear")
	assert_eq(_panel.get_title_text(),
			"CR90 \u2014 FRONT \u2192 TIE Fighter Alpha",
			"Squadron target should omit zone in title.")


func test_show_target_selected_both_squadrons() -> void:
	_panel.show_initial()
	_panel.show_target_selected(
			"X-wing Alpha", "", "TIE Fighter Alpha", "", "Clear")
	assert_eq(_panel.get_title_text(),
			"X-wing Alpha \u2192 TIE Fighter Alpha",
			"Both squadrons should omit zones in title.")
