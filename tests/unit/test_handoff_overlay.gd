## Test: HandoffOverlay
##
## Unit tests for the HandoffOverlay UI component.
## Requirements: HO-001–003.
extends GutTest


var _overlay: HandoffOverlay = null


func before_each() -> void:
	_overlay = HandoffOverlay.new()
	add_child_autofree(_overlay)


func test_initial_state_is_hidden() -> void:
	assert_false(_overlay.visible,
			"Overlay should be hidden initially")


func test_show_handoff_makes_visible() -> void:
	_overlay.show_handoff(0, "Command Phase")
	assert_true(_overlay.visible,
			"Overlay should be visible after show_handoff")


func test_show_handoff_player_zero_rebel() -> void:
	_overlay.show_handoff(0, "Command Phase")
	var title: Label = _overlay._title_label
	assert_true(title.text.contains("Rebel"),
			"Title should contain 'Rebel' for player 0")


func test_show_handoff_player_one_imperial() -> void:
	_overlay.show_handoff(1, "Command Phase")
	var title: Label = _overlay._title_label
	assert_true(title.text.contains("Imperial"),
			"Title should contain 'Imperial' for player 1")


func test_show_handoff_displays_phase_name() -> void:
	_overlay.show_handoff(0, "Ship Phase")
	var phase: Label = _overlay._phase_label
	assert_true(phase.text.contains("Ship Phase"),
			"Phase label should show 'Ship Phase'")


func test_dismiss_hides_overlay() -> void:
	_overlay.show_handoff(0, "Command Phase")
	_overlay.dismiss()
	assert_false(_overlay.visible,
			"Overlay should be hidden after dismiss")


func test_update_size_sets_dimensions() -> void:
	var vp: Vector2 = Vector2(1280, 720)
	_overlay.update_size(vp)
	assert_eq(_overlay.size, vp,
			"Overlay size should match viewport dimensions")
