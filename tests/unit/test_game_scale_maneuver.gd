## Tests for GameScale maneuver tool config loading
##
## Verifies that the maneuver_tool section of scale_config.json is correctly
## parsed into GameScale.maneuver_tool_config.
##
## Requirements: MT-D-001, AC-09.
extends GutTest


## Minimal config dictionary containing maneuver_tool data for testing.
var TEST_CONFIG: Dictionary = {
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
	"maneuver_tool": {
		"yaw_degrees_per_click": 22.5,
		"root": {
			"image": "root_filled.png",
			"entry_intersection": {"x": 18, "y": 118},
			"exit_intersection": {"x": 18, "y": 18},
			"contact_left": {"x": 0, "y": 99},
			"contact_right": {"x": 35, "y": 99},
		},
		"segment": {
			"image": "segment_filled.png",
			"entry_intersection": {"x": 21, "y": 149},
			"exit_intersection": {"x": 21, "y": 18},
			"contact_left": {"x": 3, "y": 100},
			"contact_right": {"x": 38, "y": 100},
		},
		"segment_end": {
			"image": "segment_end.png",
			"entry_intersection": {"x": 21, "y": 80},
			"contact_left": {"x": 3, "y": 31},
			"contact_right": {"x": 38, "y": 31},
			"speed_reduction_button": {"x": 11, "y": 77},
			"speed_increase_button": {"x": 30, "y": 77},
		},
	},
}


func before_each() -> void:
	GameScale.initialise_from_dict(TEST_CONFIG)


func test_maneuver_tool_config_is_loaded() -> void:
	assert_false(GameScale.maneuver_tool_config.is_empty(),
			"maneuver_tool_config should not be empty after loading")


func test_yaw_degrees_per_click_matches_config() -> void:
	var yaw: float = float(GameScale.maneuver_tool_config.get(
			"yaw_degrees_per_click", 0.0))
	assert_almost_eq(yaw, 22.5, 0.01,
			"yaw_degrees_per_click should be 22.5")


func test_root_entry_intersection_is_vector2() -> void:
	var root: Dictionary = GameScale.maneuver_tool_config.get("root", {})
	var entry: Variant = root.get("entry_intersection")
	assert_true(entry is Vector2, "entry_intersection should be Vector2")
	assert_eq(entry, Vector2(18, 118),
			"Root entry_intersection should be (18, 118)")


func test_root_has_contact_points() -> void:
	var root: Dictionary = GameScale.maneuver_tool_config.get("root", {})
	var left: Variant = root.get("contact_left")
	var right: Variant = root.get("contact_right")
	assert_true(left is Vector2, "contact_left should be Vector2")
	assert_true(right is Vector2, "contact_right should be Vector2")
	assert_eq(left, Vector2(0, 99),
			"Root contact_left should be (0, 99)")
	assert_eq(right, Vector2(35, 99),
			"Root contact_right should be (35, 99)")


func test_segment_end_has_no_exit_intersection() -> void:
	var seg_end: Dictionary = GameScale.maneuver_tool_config.get(
			"segment_end", {})
	assert_false(seg_end.has("exit_intersection"),
			"segment_end should not have exit_intersection")


func test_segment_has_exit_intersection() -> void:
	var seg: Dictionary = GameScale.maneuver_tool_config.get("segment", {})
	assert_true(seg.has("exit_intersection"),
			"segment should have exit_intersection")
	assert_eq(seg["exit_intersection"], Vector2(21, 18),
			"Segment exit should be (21, 18)")


func test_segment_end_has_contact_points() -> void:
	var seg_end: Dictionary = GameScale.maneuver_tool_config.get(
			"segment_end", {})
	assert_true(seg_end.has("contact_left"),
			"segment_end should have contact_left")
	assert_eq(seg_end["contact_left"], Vector2(3, 31),
			"segment_end contact_left should be (3, 31)")


func test_segment_end_has_speed_buttons() -> void:
	var seg_end: Dictionary = GameScale.maneuver_tool_config.get(
			"segment_end", {})
	assert_true(seg_end.has("speed_reduction_button"),
			"segment_end should have speed_reduction_button")
	assert_eq(seg_end["speed_reduction_button"], Vector2(11, 77),
			"speed_reduction_button should be (11, 77)")
	assert_true(seg_end.has("speed_increase_button"),
			"segment_end should have speed_increase_button")
	assert_eq(seg_end["speed_increase_button"], Vector2(30, 77),
			"speed_increase_button should be (30, 77)")
