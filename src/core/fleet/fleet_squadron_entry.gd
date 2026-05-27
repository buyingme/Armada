## Fleet Squadron Entry
##
## Editable fleet-builder entry for one squadron card. Runtime squadron state is
## created later from this static roster payload.
class_name FleetSquadronEntry
extends RefCounted


## Stable roster-local id for this squadron entry.
var entry_id: String = ""

## Catalog data key for the selected squadron card.
var data_key: String = ""

## Optional display override used by the fleet-builder UI.
var custom_name: String = ""


## Serializes this squadron entry to a JSON-safe dictionary.
func serialize() -> Dictionary:
	return {
		"entry_id": entry_id,
		"data_key": data_key,
		"custom_name": custom_name,
	}


## Deserializes a squadron entry from JSON-safe roster data.
static func deserialize(data: Dictionary) -> FleetSquadronEntry:
	var entry: FleetSquadronEntry = FleetSquadronEntry.new()
	entry.entry_id = str(data.get("entry_id", ""))
	entry.data_key = str(data.get("data_key", ""))
	entry.custom_name = str(data.get("custom_name", ""))
	return entry
