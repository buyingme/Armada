## Test: SquadronToken
##
## Unit tests for SquadronToken — verifies instantiation and basic API
## without depending on real asset textures or GameScale data.
extends GutTest


const SQUADRON_TOKEN_SCENE: PackedScene = preload(
		"res://src/scenes/tokens/squadron_token.tscn")

var _placement: TokenPlacement = null


func before_each() -> void:
	_placement = TokenPlacement.new(
			"x_wing_squadron", false,
			Constants.Faction.REBEL_ALLIANCE,
			0.5, 0.5, 0.0)


func after_each() -> void:
	_placement = null


# --- Instantiation ---

func test_scene_instantiates_as_squadron_token() -> void:
	var instance: Node = SQUADRON_TOKEN_SCENE.instantiate()
	add_child_autofree(instance)
	assert_true(instance is SquadronToken,
			"Instantiated node should be of type SquadronToken")


# --- setup() ---

func test_setup_does_not_crash_with_zero_game_scale() -> void:
	var token: SquadronToken = SQUADRON_TOKEN_SCENE.instantiate() as SquadronToken
	add_child_autofree(token)
	token.setup(_placement)
	assert_true(true, "setup() completed without crashing")


func test_setup_sets_correct_faction() -> void:
	var token: SquadronToken = SQUADRON_TOKEN_SCENE.instantiate() as SquadronToken
	add_child_autofree(token)
	token.setup(_placement)
	assert_eq(int(token.get_faction()), int(Constants.Faction.REBEL_ALLIANCE),
			"Faction should match the placement (Rebel Alliance)")


func test_setup_sets_imperial_faction_correctly() -> void:
	var imperial_placement: TokenPlacement = \
			TokenPlacement.new(
					"tie_fighter_squadron", false,
					Constants.Faction.GALACTIC_EMPIRE,
					0.35, 0.15, PI)
	var token: SquadronToken = SQUADRON_TOKEN_SCENE.instantiate() as SquadronToken
	add_child_autofree(token)
	token.setup(imperial_placement)
	assert_eq(int(token.get_faction()), int(Constants.Faction.GALACTIC_EMPIRE),
			"Faction should match the placement (Galactic Empire)")


# --- Radius ---

func test_get_radius_px_returns_non_negative() -> void:
	# GameScale may be uninitialised; radius defaults to 0.
	var token: SquadronToken = SQUADRON_TOKEN_SCENE.instantiate() as SquadronToken
	add_child_autofree(token)
	token.setup(_placement)
	assert_true(token.get_radius_px() >= 0.0,
			"Base radius should be non-negative even with uninitialised GameScale")
