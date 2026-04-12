## Test: GameScale
##
## Unit tests for the GameScale autoload — scale computation,
## range/distance band classification, and base size lookups.
extends GutTest


## Test config matching the real scale_config.json values.
var _test_config: Dictionary = {
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


func test_play_area_size_px() -> void:
	assert_eq(_scale.play_area_size_px, Vector2(2160.0, 2160.0),
		"Play area size should be (2160, 2160) for 3×3 board")


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
	# 720 × (34.2 / 305) ≈ 80.73
	assert_almost_eq(_scale.squadron_base_diameter_px, 80.73, 0.1,
		"Squadron base diameter should be ~80.7 px")


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


func test_get_base_size_large() -> void:
	var size: Vector2 = _scale.get_base_size(Constants.ShipSize.LARGE)
	assert_almost_eq(size.x, _scale.large_base_width_px, 0.01,
		"Large base Vector2.x should match width")
	assert_almost_eq(size.y, _scale.large_base_length_px, 0.01,
		"Large base Vector2.y should match length")


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


# --- Base graphics region data ---

func test_small_base_region_width_loaded() -> void:
	assert_eq(_scale.small_base_region_width_px, 103.0,
		"Small base region width should be 103 px")


func test_small_base_region_length_loaded() -> void:
	assert_eq(_scale.small_base_region_length_px, 171.0,
		"Small base region length should be 171 px")


func test_medium_base_region_width_loaded() -> void:
	assert_eq(_scale.medium_base_region_width_px, 148.0,
		"Medium base region width should be 148 px")


func test_medium_base_region_length_loaded() -> void:
	assert_eq(_scale.medium_base_region_length_px, 243.0,
		"Medium base region length should be 243 px")


func test_squadron_base_region_diameter_loaded() -> void:
	assert_eq(_scale.squadron_base_region_diameter_px, 82.0,
		"Squadron base region diameter should be 82 px")


# --- get_base_sprite_scale ---

func test_get_base_sprite_scale_small_uses_per_axis() -> void:
	# target: ~101.51 x ~167.54; region: 103 x 171
	var tex_size: Vector2 = Vector2(143.0, 211.0)
	var result: Vector2 = _scale.get_base_sprite_scale(
			Constants.ShipSize.SMALL, tex_size)
	var expected_sx: float = _scale.small_base_width_px / 103.0
	var expected_sy: float = _scale.small_base_length_px / 171.0
	assert_almost_eq(result.x, expected_sx, 0.001,
		"Small ship sprite scale X should be target_w / region_w")
	assert_almost_eq(result.y, expected_sy, 0.001,
		"Small ship sprite scale Y should be target_l / region_l")


func test_get_base_sprite_scale_medium_uses_per_axis() -> void:
	var tex_size: Vector2 = Vector2(189.0, 283.0)
	var result: Vector2 = _scale.get_base_sprite_scale(
			Constants.ShipSize.MEDIUM, tex_size)
	var expected_sx: float = _scale.medium_base_width_px / 148.0
	var expected_sy: float = _scale.medium_base_length_px / 243.0
	assert_almost_eq(result.x, expected_sx, 0.001,
		"Medium ship sprite scale X should be target_w / region_w")
	assert_almost_eq(result.y, expected_sy, 0.001,
		"Medium ship sprite scale Y should be target_l / region_l")


func test_get_base_sprite_scale_large_falls_back_to_uniform() -> void:
	# Large base region not yet measured — should fall back to minf()
	var tex_size: Vector2 = Vector2(200.0, 300.0)
	var result: Vector2 = _scale.get_base_sprite_scale(
			Constants.ShipSize.LARGE, tex_size)
	var target: Vector2 = _scale.get_base_size(Constants.ShipSize.LARGE)
	var expected_sf: float = minf(target.x / 200.0, target.y / 300.0)
	assert_almost_eq(result.x, expected_sf, 0.001,
		"Large ship fallback should use uniform scale")
	assert_almost_eq(result.y, expected_sf, 0.001,
		"Large ship fallback scale X and Y should be equal")


func test_get_base_sprite_scale_zero_tex_returns_one() -> void:
	var result: Vector2 = _scale.get_base_sprite_scale(
			Constants.ShipSize.SMALL, Vector2.ZERO)
	assert_eq(result, Vector2.ONE,
		"Zero texture size should return Vector2.ONE")


# --- get_squadron_sprite_scale ---

func test_get_squadron_sprite_scale_uses_region() -> void:
	# target diameter: ~80.73; region diameter: 82
	var tex_size: Vector2 = Vector2(82.0, 82.0)
	var result: Vector2 = _scale.get_squadron_sprite_scale(tex_size)
	var expected_sf: float = _scale.squadron_base_diameter_px / 82.0
	assert_almost_eq(result.x, expected_sf, 0.001,
		"Squadron sprite scale X should be target_d / region_d")
	assert_almost_eq(result.y, expected_sf, 0.001,
		"Squadron sprite scale Y should be target_d / region_d")


func test_get_squadron_sprite_scale_zero_tex_returns_one() -> void:
	var result: Vector2 = _scale.get_squadron_sprite_scale(Vector2.ZERO)
	assert_eq(result, Vector2.ONE,
		"Zero texture size should return Vector2.ONE")


# --- get_squadron_token_sprite_scale ---

func test_get_squadron_token_sprite_scale_fits_max_dim() -> void:
	# Token artwork is 78x67; should be scaled so max dim (78) = diameter.
	var tex_size: Vector2 = Vector2(78.0, 67.0)
	var result: Vector2 = _scale.get_squadron_token_sprite_scale(tex_size)
	var expected_sf: float = _scale.squadron_base_diameter_px / 78.0
	assert_almost_eq(result.x, expected_sf, 0.001,
		"Token sprite scale X should be target_d / max(tex_w, tex_h)")
	assert_almost_eq(result.y, expected_sf, 0.001,
		"Token sprite scale Y should equal X (uniform)")


func test_get_squadron_token_sprite_scale_zero_tex_returns_one() -> void:
	var result: Vector2 = _scale.get_squadron_token_sprite_scale(Vector2.ZERO)
	assert_eq(result, Vector2.ONE,
		"Zero texture size should return Vector2.ONE")
