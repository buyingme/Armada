## Test: FleetUpgradeAssignment
##
## Unit tests for upgrade assignment serialization in editable fleet rosters.
extends GutTest


func test_serialize_populated_assignment_expected() -> void:
	var assignment: FleetUpgradeAssignment = FleetUpgradeAssignment.new()
	assignment.entry_id = "upg-1"
	assignment.data_key = "general_dodonna"
	assignment.slot = "commander"
	assignment.slot_index = 0

	var serialized: Dictionary = assignment.serialize()

	assert_eq(serialized.get("entry_id", ""), "upg-1", "Should keep assignment id")
	assert_eq(serialized.get("data_key", ""), "general_dodonna", "Should keep upgrade key")
	assert_eq(serialized.get("slot", ""), "commander", "Should keep slot")
	assert_eq(serialized.get("slot_index", -1), 0, "Should keep slot index")


func test_deserialize_missing_fields_uses_defaults_expected() -> void:
	var assignment: FleetUpgradeAssignment = FleetUpgradeAssignment.deserialize({})

	assert_eq(assignment.entry_id, "", "Missing id should default to empty")
	assert_eq(assignment.data_key, "", "Missing data key should default to empty")
	assert_eq(assignment.slot, "", "Missing slot should default to empty")
	assert_eq(assignment.slot_index, 0, "Missing slot index should default to zero")


func test_deserialize_serialize_round_trip_expected() -> void:
	var source: Dictionary = {
		"entry_id": "upg-2",
		"data_key": "gunnery_team",
		"slot": "weapon_team",
		"slot_index": 1,
	}

	var assignment: FleetUpgradeAssignment = FleetUpgradeAssignment.deserialize(source)

	assert_eq(assignment.serialize(), source, "Assignment should round-trip through JSON data")
