## Test: FleetUpgradeSlotResolver
##
## Unit tests for first-open-slot assignment helper used by fleet-builder UI.
extends GutTest


func test_create_first_available_assignment_commander_uses_commander_slot_expected() -> void:
	var ship_entry: FleetShipEntry = _create_ship_entry("cr90_corvette_a")
	var ship_data: ShipData = AssetLoader.load_ship_data("cr90_corvette_a")
	var upgrade_data: UpgradeData = AssetLoader.load_upgrade_data("general_dodonna")

	var assignment: FleetUpgradeAssignment = _create_first_assignment(
			ship_entry, ship_data, upgrade_data)

	assert_not_null(assignment, "Commander should assign to the commander slot")
	assert_eq(assignment.slot, "COMMANDER", "Commander assignment should use COMMANDER")
	assert_eq(assignment.slot_index, 0, "Commander slot index should be zero")


func test_create_first_available_assignment_tarkin_uses_commander_slot_expected() -> void:
	var ship_entry: FleetShipEntry = _create_ship_entry("victory_ii_class_star_destroyer")
	var ship_data: ShipData = AssetLoader.load_ship_data("victory_ii_class_star_destroyer")
	var upgrade_data: UpgradeData = AssetLoader.load_upgrade_data("grand_moff_tarkin")

	var assignment: FleetUpgradeAssignment = _create_first_assignment(
			ship_entry, ship_data, upgrade_data)

	assert_not_null(assignment, "Tarkin should assign to the commander slot")
	assert_eq(assignment.slot, "COMMANDER", "Tarkin assignment should use COMMANDER")
	assert_eq(assignment.slot_index, 0, "Commander slot index should be zero")


func test_find_first_available_slot_skips_occupied_slot_expected() -> void:
	var ship_entry: FleetShipEntry = _create_ship_entry("cr90_corvette_a")
	ship_entry.add_upgrade(_create_assignment("first", "raymus_antilles", "OFFICER", 0))
	var ship_data: ShipData = AssetLoader.load_ship_data("cr90_corvette_a")
	var upgrade_data: UpgradeData = AssetLoader.load_upgrade_data("leia_organa")

	var slot_info: Dictionary = FleetUpgradeSlotResolver.find_first_available_slot(
			ship_entry, ship_data, upgrade_data)

	assert_true(slot_info.is_empty(),
		"CR90 has no second officer slot once the first is occupied")


func test_commander_assignment_does_not_consume_officer_slot_expected() -> void:
	var ship_entry: FleetShipEntry = _create_ship_entry("cr90_corvette_a")
	ship_entry.add_upgrade(_create_assignment("first", "general_dodonna", "COMMANDER", 0))
	var ship_data: ShipData = AssetLoader.load_ship_data("cr90_corvette_a")
	var upgrade_data: UpgradeData = AssetLoader.load_upgrade_data("leia_organa")

	var slot_info: Dictionary = FleetUpgradeSlotResolver.find_first_available_slot(
			ship_entry, ship_data, upgrade_data)

	assert_eq(slot_info.get(FleetUpgradeSlotResolver.KEY_SLOT, ""), "OFFICER",
		"Officer slot should remain open after assigning a commander")
	assert_eq(slot_info.get(FleetUpgradeSlotResolver.KEY_SLOT_INDEX, -1), 0,
		"Officer upgrade should use the first officer slot")


func _create_ship_entry(data_key: String) -> FleetShipEntry:
	var entry: FleetShipEntry = FleetShipEntry.new()
	entry.entry_id = "ship-1"
	entry.data_key = data_key
	return entry


func _create_first_assignment(ship_entry: FleetShipEntry,
		ship_data: ShipData, upgrade_data: UpgradeData) -> FleetUpgradeAssignment:
	return FleetUpgradeSlotResolver.create_first_available_assignment(
			ship_entry, ship_data, upgrade_data, "upgrade-1")


func _create_assignment(entry_id: String, data_key: String,
		slot: String, slot_index: int) -> FleetUpgradeAssignment:
	var assignment: FleetUpgradeAssignment = FleetUpgradeAssignment.new()
	assignment.entry_id = entry_id
	assignment.data_key = data_key
	assignment.slot = slot
	assignment.slot_index = slot_index
	return assignment
