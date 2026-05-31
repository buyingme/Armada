## Unit tests for FiringArcOverlay.
##
## Covers rectangular debug-line extent sizing for 3x6 play areas.
extends GutTest


var _overlay: FiringArcOverlay = null

var _scale_config: Dictionary = {
	"ruler_total_length_px": 720,
	"physical_dimensions_mm": {
		"ruler_length": 305.0,
		"play_area_ruler_multiplier": 3.0,
		"maneuver_segments": 5,
		"small_base_width": 43.0,
		"small_base_length": 71.0,
		"medium_base_width": 63.0,
		"medium_base_length": 102.0,
		"large_base_width": 77.5,
		"large_base_length": 129.0,
		"squadron_base_diameter": 34.2,
	},
	"range_bands": {
		"close": {"max_px": 292},
		"medium": {"max_px": 442},
		"long": {"max_px": 720},
	},
	"distance_bands_px": [181, 294, 434, 577, 720],
	"base_graphics": {
		"small_ship": {
			"base_region_width_px": 103,
			"base_region_length_px": 171,
		},
		"medium_ship": {
			"base_region_width_px": 148,
			"base_region_length_px": 243,
		},
		"squadron_base": {
			"base_region_diameter_px": 82,
		},
	},
}


func before_each() -> void:
	_overlay = FiringArcOverlay.new()
	add_child_autofree(_overlay)
	GameScale.initialise_from_dict(_scale_config)
	GameScale.configure_play_area_for_map_filename("map_3x6_distant_planet_v4.jpg")


func test_set_arc_boundaries_uses_rectangular_play_area_extent() -> void:
	_overlay.set_arc_boundaries({
		"inner_point_front_left": Vector2(-10.0, -10.0),
		"outer_point_front_left": Vector2(-20.0, -20.0),
	})
	var expected: float = GameScale.play_area_size_px.length() * 2.0
	assert_almost_eq(_overlay._debug_extend_px, expected, 0.1,
			"Debug arc lines should scale from the rectangular play-area extent.")