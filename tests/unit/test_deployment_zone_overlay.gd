## Test: DeploymentZoneOverlay
##
## Unit tests for deployment zone line Y-coordinate calculation.
##
## Requirements: DBG-030, DBG-031
extends GutTest


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
	GameScale.initialise_from_dict(_scale_config)


# ---------------------------------------------------------------------------
# Top line
# ---------------------------------------------------------------------------

func test_top_line_negative_for_3x3_full_setup_area() -> void:
	var top_y: float = DeploymentZoneOverlay.get_top_line_y()
	assert_eq(top_y, -1.0,
			"3x3 maps should not expose standard deployment-zone lines")


func test_top_line_y_equals_distance_band_3_for_3x6() -> void:
	GameScale.configure_play_area_for_map_filename("map_3x6_distant_planet_v4.jpg")
	var top_y: float = DeploymentZoneOverlay.get_top_line_y()
	assert_almost_eq(top_y, 434.0, 0.1,
			"3x6 top deployment line should stay at distance band 3 (434 px)")


# ---------------------------------------------------------------------------
# Bottom line
# ---------------------------------------------------------------------------

func test_bottom_line_negative_for_3x3_full_setup_area() -> void:
	var bottom_y: float = DeploymentZoneOverlay.get_bottom_line_y()
	assert_eq(bottom_y, -1.0,
			"3x3 maps should not expose standard deployment-zone lines")


func test_bottom_line_y_equals_play_area_height_minus_distance_band_3_for_3x6() -> void:
	GameScale.configure_play_area_for_map_filename("map_3x6_distant_planet_v4.jpg")
	var expected: float = GameScale.play_area_size_px.y - 434.0
	var bottom_y: float = DeploymentZoneOverlay.get_bottom_line_y()
	assert_almost_eq(bottom_y, expected, 0.1,
			"3x6 bottom deployment line should use play-area height")


# ---------------------------------------------------------------------------
# Missing distance bands (graceful fallback)
# ---------------------------------------------------------------------------

func test_top_line_negative_when_no_bands() -> void:
	# Arrange — reset to empty config.
	GameScale.initialise_from_dict({
		"ruler_total_length_px": 720,
		"physical_dimensions_mm": {
			"ruler_length": 305.0,
			"play_area_ruler_multiplier": 3.0,
			"maneuver_segments": 5,
			"small_base_width": 43.0, "small_base_length": 71.0,
			"medium_base_width": 63.0, "medium_base_length": 102.0,
			"large_base_width": 77.5, "large_base_length": 129.0,
			"squadron_base_diameter": 34.2,
		},
		"range_bands": {},
		"distance_bands_px": [],
	})
	GameScale.configure_play_area_for_map_filename("map_3x6_distant_planet_v4.jpg")
	# Assert
	assert_eq(DeploymentZoneOverlay.get_top_line_y(), -1.0,
			"Should return -1 when distance bands are not loaded")


func test_bottom_line_negative_when_no_bands() -> void:
	GameScale.initialise_from_dict({
		"ruler_total_length_px": 720,
		"physical_dimensions_mm": {
			"ruler_length": 305.0,
			"play_area_ruler_multiplier": 3.0,
			"maneuver_segments": 5,
			"small_base_width": 43.0, "small_base_length": 71.0,
			"medium_base_width": 63.0, "medium_base_length": 102.0,
			"large_base_width": 77.5, "large_base_length": 129.0,
			"squadron_base_diameter": 34.2,
		},
		"range_bands": {},
		"distance_bands_px": [],
	})
	GameScale.configure_play_area_for_map_filename("map_3x6_distant_planet_v4.jpg")
	assert_eq(DeploymentZoneOverlay.get_bottom_line_y(), -1.0,
			"Should return -1 when distance bands are not loaded")


# ---------------------------------------------------------------------------
# Symmetry — top and bottom are symmetric around the centre
# ---------------------------------------------------------------------------

func test_deployment_lines_symmetric() -> void:
	GameScale.configure_play_area_for_map_filename("map_3x6_distant_planet_v4.jpg")
	var top_y: float = DeploymentZoneOverlay.get_top_line_y()
	var bottom_y: float = DeploymentZoneOverlay.get_bottom_line_y()
	var centre: float = GameScale.play_area_size_px.y * 0.5
	assert_almost_eq(centre - top_y, bottom_y - centre, 0.1,
			"Deployment lines should be symmetric around the board centre")
