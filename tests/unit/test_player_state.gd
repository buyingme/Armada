## Test: PlayerState
##
## Unit tests for PlayerState — player data, serialization, and defaults.
extends GutTest


# --- Default Values ---

func test_default_player_index_is_zero() -> void:
	# Arrange & Act
	var state := PlayerState.new()

	# Assert
	assert_eq(state.player_index, 0, "Default player index should be 0")


func test_default_faction_is_rebel() -> void:
	# Arrange & Act
	var state := PlayerState.new()

	# Assert
	assert_eq(state.faction, Constants.Faction.REBEL_ALLIANCE, "Default faction should be REBEL_ALLIANCE")


func test_default_fleet_points_is_zero() -> void:
	# Arrange & Act
	var state := PlayerState.new()

	# Assert
	assert_eq(state.fleet_points, 0, "Default fleet points should be 0")


func test_default_score_is_zero() -> void:
	# Arrange & Act
	var state := PlayerState.new()

	# Assert
	assert_eq(state.score, 0, "Default score should be 0")


func test_default_ships_is_empty() -> void:
	# Arrange & Act
	var state := PlayerState.new()

	# Assert
	assert_eq(state.ships.size(), 0, "Default ships array should be empty")


func test_default_squadrons_is_empty() -> void:
	# Arrange & Act
	var state := PlayerState.new()

	# Assert
	assert_eq(state.squadrons.size(), 0, "Default squadrons array should be empty")


# --- Property Assignment ---

func test_set_faction_imperial() -> void:
	# Arrange
	var state := PlayerState.new()

	# Act
	state.faction = Constants.Faction.GALACTIC_EMPIRE

	# Assert
	assert_eq(state.faction, Constants.Faction.GALACTIC_EMPIRE, "Should be able to set faction to GALACTIC_EMPIRE")


func test_set_fleet_points() -> void:
	# Arrange
	var state := PlayerState.new()

	# Act
	state.fleet_points = 300

	# Assert
	assert_eq(state.fleet_points, 300, "Fleet points should be settable")


func test_set_score() -> void:
	# Arrange
	var state := PlayerState.new()

	# Act
	state.score = 150

	# Assert
	assert_eq(state.score, 150, "Score should be settable")


# --- Serialization ---

func test_serialize_contains_all_fields() -> void:
	# Arrange
	var state := PlayerState.new()
	state.player_index = 1
	state.faction = Constants.Faction.GALACTIC_EMPIRE
	state.fleet_points = 280
	state.score = 125

	# Act
	var data: Dictionary = state.serialize()

	# Assert
	assert_eq(data["player_index"], 1, "Serialized player_index should be 1")
	assert_eq(data["faction"], Constants.Faction.GALACTIC_EMPIRE, "Serialized faction should be GALACTIC_EMPIRE")
	assert_eq(data["fleet_points"], 280, "Serialized fleet_points should be 280")
	assert_eq(data["score"], 125, "Serialized score should be 125")


func test_deserialize_restores_all_fields() -> void:
	# Arrange
	var data: Dictionary = {
		"player_index": 1,
		"faction": Constants.Faction.GALACTIC_EMPIRE,
		"fleet_points": 300,
		"score": 200,
	}

	# Act
	var state: PlayerState = PlayerState.deserialize(data)

	# Assert
	assert_eq(state.player_index, 1, "Deserialized player_index should be 1")
	assert_eq(state.faction, Constants.Faction.GALACTIC_EMPIRE, "Deserialized faction should be GALACTIC_EMPIRE")
	assert_eq(state.fleet_points, 300, "Deserialized fleet_points should be 300")
	assert_eq(state.score, 200, "Deserialized score should be 200")


func test_serialize_deserialize_round_trip() -> void:
	# Arrange
	var original := PlayerState.new()
	original.player_index = 0
	original.faction = Constants.Faction.REBEL_ALLIANCE
	original.fleet_points = 400
	original.score = 75

	# Act
	var restored: PlayerState = PlayerState.deserialize(original.serialize())

	# Assert
	assert_eq(restored.player_index, original.player_index, "Round-trip should preserve player_index")
	assert_eq(restored.faction, original.faction, "Round-trip should preserve faction")
	assert_eq(restored.fleet_points, original.fleet_points, "Round-trip should preserve fleet_points")
	assert_eq(restored.score, original.score, "Round-trip should preserve score")


func test_deserialize_missing_fields_uses_defaults() -> void:
	# Arrange
	var data: Dictionary = {}

	# Act
	var state: PlayerState = PlayerState.deserialize(data)

	# Assert
	assert_eq(state.player_index, 0, "Missing player_index should default to 0")
	assert_eq(state.fleet_points, 0, "Missing fleet_points should default to 0")
	assert_eq(state.score, 0, "Missing score should default to 0")
