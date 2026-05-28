## Fleet Upgrade Assignment
##
## Editable assignment of one upgrade card to a ship roster entry.
## This is builder state only; gameplay upgrade rules are resolved later.
class_name FleetUpgradeAssignment
extends RefCounted


## Stable roster-local id for this upgrade assignment.
var entry_id: String = ""

## Catalog data key for the assigned upgrade card.
var data_key: String = ""

## Upgrade slot label this assignment occupies, such as commander or title.
var slot: String = ""

## Slot index for ships that expose repeated slots of the same type.
var slot_index: int = 0


## Serializes this upgrade assignment to a JSON-safe dictionary.
func serialize() -> Dictionary:
	return {
		"entry_id": entry_id,
		"data_key": data_key,
		"slot": slot,
		"slot_index": slot_index,
	}


## Deserializes an upgrade assignment from JSON-safe roster data.
static func deserialize(data: Dictionary) -> FleetUpgradeAssignment:
	var assignment: FleetUpgradeAssignment = FleetUpgradeAssignment.new()
	assignment.entry_id = str(data.get("entry_id", data.get("assignment_id", "")))
	assignment.data_key = str(data.get("data_key", ""))
	assignment.slot = str(data.get("slot", data.get("slot_type", "")))
	assignment.slot_index = int(data.get("slot_index", 0))
	return assignment
