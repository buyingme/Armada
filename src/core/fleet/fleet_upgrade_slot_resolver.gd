## Fleet Upgrade Slot Resolver
##
## Resolves the first open ship upgrade slot for an editable roster assignment.
## Rules Reference: RRG 1.5.0 Fleet Building, upgrade-card assignment.
class_name FleetUpgradeSlotResolver
extends RefCounted


const KEY_SLOT: String = "slot"
const KEY_SLOT_INDEX: String = "slot_index"


## Creates an assignment for the first open matching slot, or null when no slot
## is available. Validation remains authoritative for all construction errors.
static func create_first_available_assignment(ship_entry: FleetShipEntry,
		ship_data: ShipData, upgrade_data: UpgradeData,
		assignment_id: String) -> FleetUpgradeAssignment:
	var slot_info: Dictionary = find_first_available_slot(ship_entry, ship_data, upgrade_data)
	if slot_info.is_empty():
		return null
	var assignment: FleetUpgradeAssignment = FleetUpgradeAssignment.new()
	assignment.entry_id = assignment_id
	assignment.data_key = upgrade_data.data_key
	assignment.slot = str(slot_info.get(KEY_SLOT, ""))
	assignment.slot_index = int(slot_info.get(KEY_SLOT_INDEX, 0))
	return assignment


## Returns the first open matching slot as {slot, slot_index}, or an empty
## dictionary when the ship cannot equip the upgrade type.
static func find_first_available_slot(ship_entry: FleetShipEntry,
		ship_data: ShipData, upgrade_data: UpgradeData) -> Dictionary:
	if ship_entry == null or ship_data == null or upgrade_data == null:
		return {}
	if _normalized(upgrade_data.upgrade_type) == "COMMANDER":
		return {KEY_SLOT: "COMMANDER", KEY_SLOT_INDEX: 0}
	var slots_by_type: Dictionary = _slots_by_type(ship_data)
	var occupied: Dictionary = _occupied_slots(ship_entry)
	for raw_slot: Variant in slots_by_type.keys():
		var slot_name: String = str(raw_slot)
		if not assignment_matches_slot(slot_name, upgrade_data.upgrade_type):
			continue
		var open_index: int = _first_open_index(slot_name, slots_by_type, occupied)
		if open_index >= 0:
			return {KEY_SLOT: slot_name, KEY_SLOT_INDEX: open_index}
	return {}


## Returns true when [param slot_name] can hold [param upgrade_type].
static func assignment_matches_slot(slot_name: String, upgrade_type: String) -> bool:
	var normalized_slot: String = _normalized(slot_name)
	var normalized_type: String = _normalized(upgrade_type)
	if normalized_type.is_empty():
		return true
	return normalized_slot == normalized_type


static func _slots_by_type(ship_data: ShipData) -> Dictionary:
	var slots: Dictionary = {}
	for raw_slot: Variant in ship_data.upgrade_slots:
		var slot_name: String = _normalized(str(raw_slot))
		if slot_name.is_empty():
			continue
		if not slots.has(slot_name):
			slots[slot_name] = []
		(slots[slot_name] as Array).append(slot_name)
	return slots


static func _occupied_slots(ship_entry: FleetShipEntry) -> Dictionary:
	var occupied: Dictionary = {}
	for assignment: FleetUpgradeAssignment in ship_entry.upgrades:
		occupied[_slot_key(assignment.slot, assignment.slot_index)] = true
	return occupied


static func _first_open_index(slot_name: String,
		slots_by_type: Dictionary, occupied: Dictionary) -> int:
	var slot_entries: Array = slots_by_type.get(slot_name, []) as Array
	for slot_index: int in range(slot_entries.size()):
		if not occupied.has(_slot_key(slot_name, slot_index)):
			return slot_index
	return -1


static func _slot_key(slot_name: String, slot_index: int) -> String:
	return "%s:%d" % [_normalized(slot_name), slot_index]


static func _normalized(value: String) -> String:
	return value.strip_edges().to_upper()
