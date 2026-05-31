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


func test_show_handoff_uses_projected_player_label_expected() -> void:
	_overlay.show_handoff(0, "Command Phase", "Galactic Empire Player")
	var title: Label = _overlay._title_label
	assert_true(title.text.contains("Galactic Empire Player"),
			"Title should contain the projected player label")


func test_show_handoff_without_label_uses_neutral_fallback_expected() -> void:
	_overlay.show_handoff(1, "Command Phase")
	var title: Label = _overlay._title_label
	assert_true(title.text.contains("Player 1"),
			"Title should fall back to a neutral player-index label")


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
