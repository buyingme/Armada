## Test: SetupValidationResult
##
## Unit tests for setup-package validation issue serialization and fleet issue mapping.
extends GutTest


func test_add_error_serializes_issue_expected() -> void:
	var result: SetupValidationResult = SetupValidationResult.new()

	result.add_error("setup.test", "Setup failed.", ["players/0"], ["source-ref"])

	var serialized: Dictionary = result.serialize()
	var errors: Array = serialized.get("errors", []) as Array
	assert_false(result.is_valid(), "A result with errors should be invalid")
	assert_eq(errors.size(), 1, "Serialized errors should contain the added issue")
	assert_eq((errors[0] as Dictionary).get("affected_paths", []), ["players/0"],
		"Serialized issue should keep affected paths")


func test_add_fleet_validation_maps_player_paths_expected() -> void:
	var fleet_result: FleetValidationResult = FleetValidationResult.new()
	fleet_result.add_error("fleet.test", "Fleet failed.", ["ship-1"], ["RRG"])
	var result: SetupValidationResult = SetupValidationResult.new()

	result.add_fleet_validation(1, fleet_result)

	var error: Dictionary = result.errors[0]
	assert_eq(error.get("rule_id", ""), "fleet.test",
		"Fleet validation rule id should be preserved")
	assert_eq((error.get("affected_paths", []) as Array)[0],
		"players/1/roster/entries/ship-1",
		"Fleet entry ids should be mapped into setup package player paths")
	assert_true(str(error.get("message", "")).begins_with("Player 1 roster"),
		"Fleet validation messages should identify the owning player")


func test_deserialize_round_trips_expected() -> void:
	var source: SetupValidationResult = SetupValidationResult.new()
	source.add_warning("setup.warn", "Setup warning.", ["setup_state"], [])

	var restored: SetupValidationResult = SetupValidationResult.deserialize(source.serialize())

	assert_eq(restored.serialize(), source.serialize(),
		"Setup validation result should round-trip through serialization")
