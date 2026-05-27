## Test: FleetShipEntry
##
## Unit tests for editable ship roster entries and upgrade assignment ordering.
extends GutTest


func test_add_upgrade_valid_assignment_expected() -> void:
	var ship: FleetShipEntry = _create_ship_entry()
	var assignment: FleetUpgradeAssignment = _create_upgrade("upg-1", "general_dodonna")

	var added: bool = ship.add_upgrade(assignment)

	assert_true(added, "Valid upgrade assignment should be added")
	assert_eq(ship.get_upgrade("upg-1"), assignment, "Added upgrade should be retrievable")


func test_add_upgrade_duplicate_id_rejected_expected() -> void:
	var ship: FleetShipEntry = _create_ship_entry()
	ship.add_upgrade(_create_upgrade("upg-1", "general_dodonna"))

	var added: bool = ship.add_upgrade(_create_upgrade("upg-1", "gunnery_team"))

	assert_false(added, "Duplicate upgrade entry id should be rejected")
	assert_eq(ship.upgrades.size(), 1, "Duplicate should not change upgrades")


func test_add_upgrade_missing_fields_rejected_expected() -> void:
	var ship: FleetShipEntry = _create_ship_entry()
	var assignment: FleetUpgradeAssignment = FleetUpgradeAssignment.new()
	assignment.entry_id = "upg-blank"

	var added: bool = ship.add_upgrade(assignment)

	assert_false(added, "Missing upgrade data key should be rejected")
	assert_true(ship.upgrades.is_empty(), "Rejected assignment should not be stored")


func test_remove_upgrade_existing_assignment_expected() -> void:
	var ship: FleetShipEntry = _create_ship_entry()
	ship.add_upgrade(_create_upgrade("upg-1", "general_dodonna"))

	var removed: bool = ship.remove_upgrade("upg-1")

	assert_true(removed, "Existing upgrade should be removed")
	assert_null(ship.get_upgrade("upg-1"), "Removed upgrade should not be retrievable")


func test_remove_upgrade_missing_assignment_false_expected() -> void:
	var ship: FleetShipEntry = _create_ship_entry()

	assert_false(ship.remove_upgrade("missing"), "Missing upgrade removal should fail")


func test_serialize_orders_upgrades_by_entry_id_expected() -> void:
	var ship: FleetShipEntry = _create_ship_entry()
	ship.add_upgrade(_create_upgrade("upg-b", "gunnery_team"))
	ship.add_upgrade(_create_upgrade("upg-a", "general_dodonna"))

	var upgrades: Array = ship.serialize().get("upgrades", []) as Array

	assert_eq(upgrades[0].get("entry_id", ""), "upg-a",
		"Serialized upgrades should be ordered by entry id")
	assert_eq(upgrades[1].get("entry_id", ""), "upg-b",
		"Serialized upgrades should keep deterministic order")


func test_deserialize_duplicate_upgrades_keeps_first_expected() -> void:
	var ship: FleetShipEntry = FleetShipEntry.deserialize({
		"entry_id": "ship-1",
		"data_key": "cr90_corvette_a",
		"upgrades": [
			{"entry_id": "upg-1", "data_key": "general_dodonna"},
			{"entry_id": "upg-1", "data_key": "gunnery_team"},
		],
	})

	assert_eq(ship.upgrades.size(), 1, "Duplicate upgrade ids should be ignored")
	assert_eq(ship.get_upgrade("upg-1").data_key, "general_dodonna",
		"First duplicate upgrade should be kept")


func test_deserialize_serialize_round_trip_expected() -> void:
	var source: Dictionary = {
		"entry_id": "ship-1",
		"data_key": "cr90_corvette_a",
		"custom_name": "Flagship",
		"upgrades": [{
			"entry_id": "upg-1",
			"data_key": "general_dodonna",
			"slot": "commander",
			"slot_index": 0,
		}],
	}

	var ship: FleetShipEntry = FleetShipEntry.deserialize(source)

	assert_eq(ship.serialize(), source, "Ship entry should round-trip")


func _create_ship_entry() -> FleetShipEntry:
	var ship: FleetShipEntry = FleetShipEntry.new()
	ship.entry_id = "ship-1"
	ship.data_key = "cr90_corvette_a"
	return ship


func _create_upgrade(entry_id: String, data_key: String) -> FleetUpgradeAssignment:
	var assignment: FleetUpgradeAssignment = FleetUpgradeAssignment.new()
	assignment.entry_id = entry_id
	assignment.data_key = data_key
	assignment.slot = "commander"
	assignment.slot_index = 0
	return assignment
