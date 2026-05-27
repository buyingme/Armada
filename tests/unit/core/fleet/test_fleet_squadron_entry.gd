## Test: FleetSquadronEntry
##
## Unit tests for editable squadron roster entry serialization.
extends GutTest


func test_serialize_populated_entry_expected() -> void:
	var entry: FleetSquadronEntry = FleetSquadronEntry.new()
	entry.entry_id = "squad-1"
	entry.data_key = "x_wing_squadron"
	entry.custom_name = "Escort Wing"

	var serialized: Dictionary = entry.serialize()

	assert_eq(serialized.get("entry_id", ""), "squad-1", "Should keep entry id")
	assert_eq(serialized.get("data_key", ""), "x_wing_squadron", "Should keep data key")
	assert_eq(serialized.get("custom_name", ""), "Escort Wing", "Should keep name")


func test_deserialize_missing_fields_uses_defaults_expected() -> void:
	var entry: FleetSquadronEntry = FleetSquadronEntry.deserialize({})

	assert_eq(entry.entry_id, "", "Missing id should default to empty")
	assert_eq(entry.data_key, "", "Missing data key should default to empty")
	assert_eq(entry.custom_name, "", "Missing name should default to empty")


func test_deserialize_serialize_round_trip_expected() -> void:
	var source: Dictionary = {
		"entry_id": "squad-2",
		"data_key": "tie_fighter_squadron",
		"custom_name": "Black Wing",
	}

	var entry: FleetSquadronEntry = FleetSquadronEntry.deserialize(source)

	assert_eq(entry.serialize(), source, "Squadron entry should round-trip")
