## Test: GameScale
##
## Unit tests for the GameScale autoload — scale computation,
## range/distance band classification, and base size lookups.
extends GutTest


## Test config matching the real scale_config.json values.
var _test_config: Dictionary = {
	"ruler_total_length_px": 720,
	"range_bands": {
		"close": {"max_px": 292},
		"medium": {"max_px": 442},
		"long": {"max_px": 720},
	},
	"distance_bands_px": [181, 294, 434, 577, 720],
}

## System under test (fresh instance per test).
var _scale: Node = null


func before_each() -> void:
	# Load the script directly so we can test without the autoload singleton.
	var script: GDScript = load("res://src/autoload/game_scale.gd")
	_scale = script.new()
	_scale.initialise_from_dict(_test_config)


func after_each() -> void:
	if _scale:
		_scale.free()
		_scale = null


# --- Initialisation ---

func test_initialise_from_dict_sets_ruler_length() -> void:
	assert_eq(_scale.ruler_length_px, 720.0,
		"Ruler length should be 720 px")


func test_initialise_from_dict_sets_is_initialised() -> void:
	assert_true(_scale.is_initialised,
		"Should be marked as initialised after loading config")


func test_initialise_from_dict_with_zero_ruler_stays_uninitialised() -> void:
	var bad_config: Dictionary = {"ruler_total_length_px": 0}
	var script: GDScript = load("res://src/autoload/game_scale.gd")
	var s: Node = script.new()
	s.initialise_from_dict(bad_config)
	assert_false(s.is_initialised,
		"Should not initialise with zero ruler length")
	s.free()


# --- Range bands ---

func test_range_close_px() -> void:
	assert_eq(_scale.range_close_px, 292.0,
		"Close range boundary should be 292 px")


func test_range_medium_px() -> void:
	assert_eq(_scale.range_medium_px, 442.0,
		"Medium range boundary should be 442 px")


func test_range_long_px() -> void:
	assert_eq(_scale.range_long_px, 720.0,
		"Long range boundary should be 720 px")


# --- Distance bands ---

func test_distance_bands_count() -> void:
	assert_eq(_scale.distance_bands_px.size(), 5,
		"Should have 5 distance bands")


func test_distance_band_1() -> void:
	assert_eq(_scale.distance_bands_px[0], 181.0,
		"Distance band 1 boundary should be 181 px")


func test_distance_band_5() -> void:
	assert_eq(_scale.distance_bands_px[4], 720.0,
		"Distance band 5 boundary should be 720 px")


# --- Play area ---

func test_play_area_side_px() -> void:
	assert_eq(_scale.play_area_side_px, 2160.0,
		"Play area should be 720 × 3 = 2160 px per side")


# --- Base sizes ---

func test_small_base_width() -> void:
	# 720 × (43 / 305) ≈ 101.51
	assert_almost_eq(_scale.small_base_width_px, 101.51, 0.1,
		"Small base width should be ~101.5 px")


func test_small_base_length() -> void:
	# 720 × (71 / 305) ≈ 167.54
	assert_almost_eq(_scale.small_base_length_px, 167.54, 0.1,
		"Small base length should be ~167.5 px")


func test_medium_base_width() -> void:
	# 720 × (63 / 305) ≈ 148.72
	assert_almost_eq(_scale.medium_base_width_px, 148.72, 0.1,
		"Medium base width should be ~148.7 px")


func test_medium_base_length() -> void:
	# 720 × (102 / 305) ≈ 240.79
	assert_almost_eq(_scale.medium_base_length_px, 240.79, 0.1,
		"Medium base length should be ~240.8 px")


func test_squadron_base_diameter() -> void:
	# 720 × (41 / 305) ≈ 96.79
	assert_almost_eq(_scale.squadron_base_diameter_px, 96.79, 0.1,
		"Squadron base diameter should be ~96.8 px")


# --- Maneuver segment ---

func test_maneuver_segment_length() -> void:
	assert_eq(_scale.maneuver_segment_px, 144.0,
		"Maneuver segment should be 720 / 5 = 144 px")


# --- get_base_size ---

func test_get_base_size_small() -> void:
	var size: Vector2 = _scale.get_base_size(Constants.ShipSize.SMALL)
	assert_almost_eq(size.x, _scale.small_base_width_px, 0.01,
		"Small base Vector2.x should match width")
	assert_almost_eq(size.y, _scale.small_base_length_px, 0.01,
		"Small base Vector2.y should match length")


func test_get_base_size_medium() -> void:
	var size: Vector2 = _scale.get_base_size(Constants.ShipSize.MEDIUM)
	assert_almost_eq(size.x, _scale.medium_base_width_px, 0.01,
		"Medium base Vector2.x should match width")
	assert_almost_eq(size.y, _scale.medium_base_length_px, 0.01,
		"Medium base Vector2.y should match length")


func test_get_base_size_large_returns_zero() -> void:
	var size: Vector2 = _scale.get_base_size(Constants.ShipSize.LARGE)
	assert_eq(size, Vector2.ZERO,
		"Large base not defined yet — should return ZERO")
	assert_push_error(1,
		"Should log a push_error for undefined ship size")


# --- get_range_band ---

func test_get_range_band_close() -> void:
	assert_eq(_scale.get_range_band(100.0), "close",
		"100 px should be close range")


func test_get_range_band_close_boundary() -> void:
	assert_eq(_scale.get_range_band(292.0), "close",
		"292 px (boundary) should be close range")


func test_get_range_band_medium() -> void:
	assert_eq(_scale.get_range_band(350.0), "medium",
		"350 px should be medium range")


func test_get_range_band_medium_boundary() -> void:
	assert_eq(_scale.get_range_band(442.0), "medium",
		"442 px (boundary) should be medium range")


func test_get_range_band_long() -> void:
	assert_eq(_scale.get_range_band(600.0), "long",
		"600 px should be long range")


func test_get_range_band_beyond() -> void:
	assert_eq(_scale.get_range_band(800.0), "beyond",
		"800 px should be beyond range")


# --- get_distance_band ---

func test_get_distance_band_1() -> void:
	assert_eq(_scale.get_distance_band(100.0), 1,
		"100 px should be distance band 1")


func test_get_distance_band_3() -> void:
	assert_eq(_scale.get_distance_band(400.0), 3,
		"400 px should be distance band 3")


func test_get_distance_band_5_boundary() -> void:
	assert_eq(_scale.get_distance_band(720.0), 5,
		"720 px should be distance band 5")


func test_get_distance_band_beyond_returns_zero() -> void:
	assert_eq(_scale.get_distance_band(800.0), 0,
		"800 px should return 0 (beyond all distance bands)")
