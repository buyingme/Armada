## Test: ScenarioSaver
##
## Unit tests for ScenarioSaver — verifying normalised coordinate serialisation
## and JSON roundtrip consistency.
##
## Requirements: DBG-040, DBG-041
extends GutTest


const SHIP_TOKEN_SCENE: PackedScene = preload(
		"res://src/scenes/tokens/ship_token.tscn")
const SQUADRON_TOKEN_SCENE: PackedScene = preload(
		"res://src/scenes/tokens/squadron_token.tscn")


var _saver: ScenarioSaver = null
var _scale_config: Dictionary = {
	"ruler_total_length_px": 720,
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
	_saver = ScenarioSaver.new()
	GameScale.initialise_from_dict(_scale_config)


func after_each() -> void:
	_saver = null


# ---------------------------------------------------------------------------
# _ship_to_dict
# ---------------------------------------------------------------------------

func test_ship_to_dict_normalises_position() -> void:
	# Arrange — place a ship token at known pixel position.
	var placement: TokenPlacement = TokenPlacement.new(
			"cr90_corvette_a", true,
			Constants.Faction.REBEL_ALLIANCE,
			0.5, 0.8, 0.0, Constants.ShipSize.SMALL)
	var token: ShipToken = SHIP_TOKEN_SCENE.instantiate() as ShipToken
	add_child_autofree(token)
	token.setup(placement)
	# Move token to a known position.
	var side: float = GameScale.play_area_side_px
	token.position = Vector2(side * 0.25, side * 0.75)
	# Act
	var dict: Dictionary = _saver._ship_to_dict(token, side)
	# Assert — normalised coords should be 0.25, 0.75.
	assert_almost_eq(float(dict["pos_x"]), 0.25, 0.01,
			"Normalised X should be 0.25")
	assert_almost_eq(float(dict["pos_y"]), 0.75, 0.01,
			"Normalised Y should be 0.75")
	assert_eq(dict["type"], "ship",
			"Type should be 'ship'")
	assert_eq(dict["key"], "cr90_corvette_a",
			"Key should match the placement data_key")


# ---------------------------------------------------------------------------
# _squadron_to_dict
# ---------------------------------------------------------------------------

func test_squadron_to_dict_normalises_position() -> void:
	var placement: TokenPlacement = TokenPlacement.new(
			"x_wing_squadron", false,
			Constants.Faction.REBEL_ALLIANCE,
			0.5, 0.7, 0.0)
	var token: SquadronToken = SQUADRON_TOKEN_SCENE.instantiate() as SquadronToken
	add_child_autofree(token)
	token.setup(placement)
	var side: float = GameScale.play_area_side_px
	token.position = Vector2(side * 0.4, side * 0.6)
	var dict: Dictionary = _saver._squadron_to_dict(token, side)
	assert_almost_eq(float(dict["pos_x"]), 0.4, 0.01,
			"Normalised X should be 0.4")
	assert_almost_eq(float(dict["pos_y"]), 0.6, 0.01,
			"Normalised Y should be 0.6")
	assert_eq(dict["type"], "squadron",
			"Type should be 'squadron'")


# ---------------------------------------------------------------------------
# Rotation persistence
# ---------------------------------------------------------------------------

func test_ship_rotation_saved_as_degrees() -> void:
	var placement: TokenPlacement = TokenPlacement.new(
			"cr90_corvette_a", true,
			Constants.Faction.REBEL_ALLIANCE,
			0.5, 0.8, deg_to_rad(45.0), Constants.ShipSize.SMALL)
	var token: ShipToken = SHIP_TOKEN_SCENE.instantiate() as ShipToken
	add_child_autofree(token)
	token.setup(placement)
	var dict: Dictionary = _saver._ship_to_dict(token, GameScale.play_area_side_px)
	assert_almost_eq(float(dict["rotation_deg"]), 45.0, 0.5,
			"Rotation should be saved as degrees")


# ---------------------------------------------------------------------------
# save_positions rejects zero play area
# ---------------------------------------------------------------------------

func test_save_positions_fails_with_zero_side() -> void:
	var result: bool = _saver.save_positions(
			"scenarios/", "test.json", [], [], 0.0)
	assert_false(result,
			"save_positions should return false when play_area_side is 0")
	assert_push_error(1,
			"Should produce exactly 1 push_error for zero side")
