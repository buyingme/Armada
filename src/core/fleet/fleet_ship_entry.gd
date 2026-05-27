## Fleet Ship Entry
##
## Editable fleet-builder entry for one ship card plus its assigned upgrades.
## Runtime ship state is created later from this static roster payload.
class_name FleetShipEntry
extends RefCounted


## Stable roster-local id for this ship entry.
var entry_id: String = ""

## Catalog data key for the selected ship card.
var data_key: String = ""

## Optional display override used by the fleet-builder UI.
var custom_name: String = ""

## Upgrade assignments attached to this ship entry.
var upgrades: Array[FleetUpgradeAssignment] = []


## Adds an upgrade assignment when its id and catalog key are valid and unique.
func add_upgrade(assignment: FleetUpgradeAssignment) -> bool:
	if assignment == null:
		return false
	if assignment.entry_id.strip_edges().is_empty():
		return false
	if assignment.data_key.strip_edges().is_empty():
		return false
	if get_upgrade(assignment.entry_id) != null:
		return false
	upgrades.append(assignment)
	return true


## Removes the upgrade assignment with [param upgrade_entry_id], if present.
func remove_upgrade(upgrade_entry_id: String) -> bool:
	for index: int in range(upgrades.size()):
		if upgrades[index].entry_id == upgrade_entry_id:
			upgrades.remove_at(index)
			return true
	return false


## Returns the upgrade assignment with [param upgrade_entry_id], or null.
func get_upgrade(upgrade_entry_id: String) -> FleetUpgradeAssignment:
	for assignment: FleetUpgradeAssignment in upgrades:
		if assignment.entry_id == upgrade_entry_id:
			return assignment
	return null


## Serializes this ship entry with upgrades in deterministic id order.
func serialize() -> Dictionary:
	return {
		"entry_id": entry_id,
		"data_key": data_key,
		"custom_name": custom_name,
		"upgrades": _serialize_upgrades_sorted(),
	}


## Deserializes a ship entry from JSON-safe roster data.
static func deserialize(data: Dictionary) -> FleetShipEntry:
	var entry: FleetShipEntry = FleetShipEntry.new()
	entry.entry_id = str(data.get("entry_id", ""))
	entry.data_key = str(data.get("data_key", ""))
	entry.custom_name = str(data.get("custom_name", ""))
	entry._load_upgrades(data.get("upgrades", []))
	return entry


func _load_upgrades(raw_upgrades: Variant) -> void:
	if not raw_upgrades is Array:
		return
	for raw_upgrade: Variant in raw_upgrades as Array:
		if raw_upgrade is Dictionary:
			add_upgrade(FleetUpgradeAssignment.deserialize(raw_upgrade as Dictionary))


func _serialize_upgrades_sorted() -> Array[Dictionary]:
	var sorted: Array[FleetUpgradeAssignment] = []
	sorted.assign(upgrades)
	sorted.sort_custom(_upgrade_before)
	var result: Array[Dictionary] = []
	for assignment: FleetUpgradeAssignment in sorted:
		result.append(assignment.serialize())
	return result


static func _upgrade_before(left: FleetUpgradeAssignment,
		right: FleetUpgradeAssignment) -> bool:
	return left.entry_id < right.entry_id
