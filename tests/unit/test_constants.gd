## Test: Constants
##
## Unit tests for the Constants autoload and its helper functions.
extends GutTest


func test_get_max_speed_small() -> void:
	var result := Constants.get_max_speed(Constants.ShipSize.SMALL)
	assert_eq(result, 4, "Small ships should have max speed 4")


func test_get_max_speed_medium() -> void:
	var result := Constants.get_max_speed(Constants.ShipSize.MEDIUM)
	assert_eq(result, 3, "Medium ships should have max speed 3")


func test_get_max_speed_large() -> void:
	var result := Constants.get_max_speed(Constants.ShipSize.LARGE)
	assert_eq(result, 3, "Large ships should have max speed 3")


func test_get_max_speed_huge() -> void:
	var result := Constants.get_max_speed(Constants.ShipSize.HUGE)
	assert_eq(result, 2, "Huge ships should have max speed 2")


func test_max_rounds_is_six() -> void:
	assert_eq(Constants.MAX_ROUNDS, 6, "Game should have 6 rounds")


func test_max_fleet_points_is_400() -> void:
	assert_eq(Constants.MAX_FLEET_POINTS, 400, "Fleet limit should be 400 points")


func test_player_count_is_two() -> void:
	assert_eq(Constants.PLAYER_COUNT, 2, "Game should support 2 players")


func test_command_types_count() -> void:
	# Navigate, Squadron, Concentrate Fire, Repair
	assert_eq(Constants.CommandType.size(), 4, "Should have 4 command types")


func test_defense_token_types_count() -> void:
	# Evade, Redirect, Brace, Scatter, Contain, Salvo
	assert_eq(Constants.DefenseToken.size(), 6, "Should have 6 defense token types")


func test_hull_zones_count() -> void:
	# Front, Left, Right, Rear
	assert_eq(Constants.HullZone.size(), 4, "Should have 4 hull zones")


func test_game_phases_count() -> void:
	# Setup, Command, Ship, Squadron, Status
	assert_eq(Constants.GamePhase.size(), 5, "Should have 5 game phases")


func test_dice_colors_count() -> void:
	# Red, Blue, Black
	assert_eq(Constants.DiceColor.size(), 3, "Should have 3 dice colors")


func test_ship_sizes_count() -> void:
	# Small, Medium, Large, Huge
	assert_eq(Constants.ShipSize.size(), 4, "Should have 4 ship sizes")


func test_factions_count() -> void:
	# Rebel Alliance, Galactic Empire, Galactic Republic, Separatist Alliance
	assert_eq(Constants.Faction.size(), 4, "Should have 4 factions")
