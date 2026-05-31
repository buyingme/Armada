## Test: YourTurnBanner
##
## Unit tests for the YourTurnBanner UI component.
## Requirements: HO-004, HO-005.
extends GutTest


var _banner: YourTurnBanner = null


func before_each() -> void:
	_banner = YourTurnBanner.new()
	add_child_autofree(_banner)


func test_initial_state_is_hidden() -> void:
	assert_false(_banner.visible,
			"Banner should be hidden initially")


func test_show_banner_makes_visible() -> void:
	_banner.show_banner(0)
	assert_true(_banner.visible,
			"Banner should be visible after show_banner")


func test_show_banner_uses_projected_player_label_expected() -> void:
	_banner.show_banner(0, YourTurnBanner.DEFAULT_DURATION, "Galactic Empire Player")
	var label: Label = _banner._title_label
	assert_true(label.text.contains("Galactic Empire Player"),
			"Label should contain the projected player label")


func test_show_banner_without_label_uses_neutral_fallback_expected() -> void:
	_banner.show_banner(1)
	var label: Label = _banner._title_label
	assert_true(label.text.contains("Player 1"),
			"Label should fall back to a neutral player-index label")


func test_dismiss_hides_banner() -> void:
	_banner.show_banner(0)
	_banner.dismiss()
	assert_false(_banner.visible,
			"Banner should be hidden after dismiss")


func test_update_size_sets_width() -> void:
	var vp: Vector2 = Vector2(1280, 720)
	_banner.update_size(vp)
	assert_eq(_banner.size.x, vp.x * 0.5,
			"Banner width should be 50%% of viewport width")


func test_update_size_centres_vertically() -> void:
	var vp: Vector2 = Vector2(1280, 720)
	_banner.update_size(vp)
	var expected_y: float = (vp.y - _banner.size.y) * 0.5
	assert_almost_eq(_banner.position.y, expected_y, 1.0,
			"Banner should be vertically centred")
