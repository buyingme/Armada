## Test: ShipToken
##
## Unit tests for ShipToken — verifies instantiation, arc overlay toggle,
## and per-class API without depending on real asset textures or GameScale.
extends GutTest


const SHIP_TOKEN_SCENE: PackedScene = preload(
		"res://src/scenes/tokens/ship_token.tscn")

## Shared placement used across tests (small Rebel ship at center).
var _placement: TokenPlacement = null


func before_each() -> void:
	_placement = TokenPlacement.new(
			"cr90_corvette_a", true,
			Constants.Faction.REBEL_ALLIANCE,
			0.5, 0.5, 0.0,
			Constants.ShipSize.SMALL)


func after_each() -> void:
	_placement = null


# --- Instantiation ---

func test_scene_instantiates_as_ship_token() -> void:
	# Act
	var instance: Node = SHIP_TOKEN_SCENE.instantiate()
	add_child_autofree(instance)
	# Assert
	assert_true(instance is ShipToken,
			"Instantiated node should be of type ShipToken")


# --- setup() ---

func test_setup_does_not_crash_with_zero_game_scale() -> void:
	# Arrange — GameScale may be uninitialised (all px values = 0).
	var token: ShipToken = SHIP_TOKEN_SCENE.instantiate() as ShipToken
	add_child_autofree(token)
	# Act — must not crash even with zero-sized base.
	token.setup(_placement)
	# Assert
	assert_true(true, "setup() completed without crashing")


func test_setup_sets_correct_faction() -> void:
	var token: ShipToken = SHIP_TOKEN_SCENE.instantiate() as ShipToken
	add_child_autofree(token)
	token.setup(_placement)
	assert_eq(int(token.get_faction()), int(Constants.Faction.REBEL_ALLIANCE),
			"Faction should match the placement's faction (Rebel Alliance)")


func test_setup_sets_correct_ship_size() -> void:
	var token: ShipToken = SHIP_TOKEN_SCENE.instantiate() as ShipToken
	add_child_autofree(token)
	token.setup(_placement)
	assert_eq(int(token.get_ship_size()), int(Constants.ShipSize.SMALL),
			"Ship size should match the placement's ship size (SMALL)")


# --- Arc overlay ---

func test_arc_overlay_initially_hidden() -> void:
	var token: ShipToken = SHIP_TOKEN_SCENE.instantiate() as ShipToken
	add_child_autofree(token)
	token.setup(_placement)
	assert_false(token.is_arc_overlay_visible(),
			"Firing arc overlay should be hidden by default")


func test_toggle_arc_overlay_makes_it_visible() -> void:
	var token: ShipToken = SHIP_TOKEN_SCENE.instantiate() as ShipToken
	add_child_autofree(token)
	token.setup(_placement)
	# Act
	token.toggle_arc_overlay()
	# Assert
	assert_true(token.is_arc_overlay_visible(),
			"Firing arc overlay should be visible after first toggle")


func test_toggle_arc_overlay_twice_hides_it_again() -> void:
	var token: ShipToken = SHIP_TOKEN_SCENE.instantiate() as ShipToken
	add_child_autofree(token)
	token.setup(_placement)
	token.toggle_arc_overlay()
	token.toggle_arc_overlay()
	assert_false(token.is_arc_overlay_visible(),
			"Firing arc overlay should be hidden again after two toggles")
