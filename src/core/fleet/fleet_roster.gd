## Fleet Roster
##
## Editable fleet-builder state for one player fleet. This model is separate
## from runtime PlayerState and remains JSON-safe for setup package embedding.
class_name FleetRoster
extends RefCounted


const FORMAT_VERSION: int = 1
const KIND: String = "fleet_roster"

## Serialized format version for forward-compatible roster changes.
var format_version: int = FORMAT_VERSION

## Static payload kind discriminator.
var kind: String = KIND

## Stable local or imported fleet id.
var fleet_id: String = ""

## Human-readable fleet name.
var name: String = ""

## Faction key used by catalog records and validators.
var faction: String = ""

## Point-format metadata, for example {"id": "CORE_SET_180", "limit": 180}.
var point_format: Dictionary = {}

## Local creation timestamp metadata; ignored by setup-package gameplay hashes.
var created_at: String = ""

## Local update timestamp metadata; ignored by setup-package gameplay hashes.
var updated_at: String = ""

## Local source marker such as local, import, or network.
var source: String = "local"

## Future sync metadata reserved for local library and remote revisions.
var future_sync: Dictionary = {}

## Editable ship entries.
var ships: Array[FleetShipEntry] = []

## Editable squadron entries.
var squadrons: Array[FleetSquadronEntry] = []

## Editable objective selections.
var objectives: FleetObjectiveSelection = FleetObjectiveSelection.new()


## Creates a roster with the minimum user-facing identity fields populated.
static func create(p_fleet_id: String, p_name: String, p_faction: String) -> FleetRoster:
	var roster: FleetRoster = FleetRoster.new()
	roster.fleet_id = p_fleet_id
	roster.name = p_name
	roster.faction = p_faction
	return roster


## Adds a ship entry when its id and catalog key are valid and roster-unique.
func add_ship(entry: FleetShipEntry) -> bool:
	if entry == null or not _entry_is_valid(entry.entry_id, entry.data_key):
		return false
	if has_entry_id(entry.entry_id):
		return false
	ships.append(entry)
	return true


## Updates an existing ship entry with the same [code]entry_id[/code].
func update_ship(entry: FleetShipEntry) -> bool:
	if entry == null or not _entry_is_valid(entry.entry_id, entry.data_key):
		return false
	var index: int = _find_ship_index(entry.entry_id)
	if index < 0:
		return false
	ships[index] = entry
	return true


## Removes a ship entry by id, if present.
func remove_ship(entry_id: String) -> bool:
	var index: int = _find_ship_index(entry_id)
	if index < 0:
		return false
	ships.remove_at(index)
	return true


## Returns a ship entry by id, or null.
func get_ship(entry_id: String) -> FleetShipEntry:
	var index: int = _find_ship_index(entry_id)
	if index < 0:
		return null
	return ships[index]


## Adds a squadron entry when its id and catalog key are valid and roster-unique.
func add_squadron(entry: FleetSquadronEntry) -> bool:
	if entry == null or not _entry_is_valid(entry.entry_id, entry.data_key):
		return false
	if has_entry_id(entry.entry_id):
		return false
	squadrons.append(entry)
	return true


## Updates an existing squadron entry with the same [code]entry_id[/code].
func update_squadron(entry: FleetSquadronEntry) -> bool:
	if entry == null or not _entry_is_valid(entry.entry_id, entry.data_key):
		return false
	var index: int = _find_squadron_index(entry.entry_id)
	if index < 0:
		return false
	squadrons[index] = entry
	return true


## Removes a squadron entry by id, if present.
func remove_squadron(entry_id: String) -> bool:
	var index: int = _find_squadron_index(entry_id)
	if index < 0:
		return false
	squadrons.remove_at(index)
	return true


## Returns a squadron entry by id, or null.
func get_squadron(entry_id: String) -> FleetSquadronEntry:
	var index: int = _find_squadron_index(entry_id)
	if index < 0:
		return null
	return squadrons[index]


## Returns true when a ship or squadron already uses [param entry_id].
func has_entry_id(entry_id: String) -> bool:
	return _find_ship_index(entry_id) >= 0 or _find_squadron_index(entry_id) >= 0


## Replaces the objective selection with a serialized copy of [param selection].
func set_objectives(selection: FleetObjectiveSelection) -> void:
	if selection == null:
		objectives = FleetObjectiveSelection.new()
		return
	objectives = FleetObjectiveSelection.deserialize(selection.serialize())


## Serializes this roster with entries in deterministic id order.
func serialize() -> Dictionary:
	return {
		"format_version": format_version,
		"kind": kind,
		"fleet_id": fleet_id,
		"name": name,
		"faction": faction,
		"point_format": point_format.duplicate(true),
		"created_at": created_at,
		"updated_at": updated_at,
		"source": source,
		"future_sync": future_sync.duplicate(true),
		"ships": _serialize_ships_sorted(),
		"squadrons": _serialize_squadrons_sorted(),
		"objectives": objectives.serialize() if objectives else {},
	}


## Deserializes a roster from JSON-safe data.
static func deserialize(data: Dictionary) -> FleetRoster:
	var roster: FleetRoster = FleetRoster.new()
	roster.format_version = int(data.get("format_version", FORMAT_VERSION))
	roster.kind = str(data.get("kind", KIND))
	roster.fleet_id = str(data.get("fleet_id", ""))
	roster.name = str(data.get("name", ""))
	roster.faction = str(data.get("faction", ""))
	roster.point_format = _read_dict(data.get("point_format", {}))
	roster.created_at = str(data.get("created_at", ""))
	roster.updated_at = str(data.get("updated_at", ""))
	roster.source = str(data.get("source", "local"))
	roster.future_sync = _read_dict(data.get("future_sync", {}))
	roster.objectives = _read_objectives(data.get("objectives", {}))
	roster._load_ships(data.get("ships", []))
	roster._load_squadrons(data.get("squadrons", []))
	return roster


## Returns the deterministic hash of this roster's serialized payload.
func canonical_hash() -> String:
	return CanonicalJson.hash(serialize())


func _load_ships(raw_ships: Variant) -> void:
	if not raw_ships is Array:
		return
	for raw_ship: Variant in raw_ships as Array:
		if raw_ship is Dictionary:
			add_ship(FleetShipEntry.deserialize(raw_ship as Dictionary))


func _load_squadrons(raw_squadrons: Variant) -> void:
	if not raw_squadrons is Array:
		return
	for raw_squadron: Variant in raw_squadrons as Array:
		if raw_squadron is Dictionary:
			add_squadron(FleetSquadronEntry.deserialize(raw_squadron as Dictionary))


func _serialize_ships_sorted() -> Array[Dictionary]:
	var sorted: Array[FleetShipEntry] = []
	sorted.assign(ships)
	sorted.sort_custom(_ship_before)
	var result: Array[Dictionary] = []
	for entry: FleetShipEntry in sorted:
		result.append(entry.serialize())
	return result


func _serialize_squadrons_sorted() -> Array[Dictionary]:
	var sorted: Array[FleetSquadronEntry] = []
	sorted.assign(squadrons)
	sorted.sort_custom(_squadron_before)
	var result: Array[Dictionary] = []
	for entry: FleetSquadronEntry in sorted:
		result.append(entry.serialize())
	return result


func _find_ship_index(entry_id: String) -> int:
	for index: int in range(ships.size()):
		if ships[index].entry_id == entry_id:
			return index
	return -1


func _find_squadron_index(entry_id: String) -> int:
	for index: int in range(squadrons.size()):
		if squadrons[index].entry_id == entry_id:
			return index
	return -1


static func _entry_is_valid(entry_id: String, data_key: String) -> bool:
	return not entry_id.strip_edges().is_empty() and not data_key.strip_edges().is_empty()


static func _read_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func _read_objectives(value: Variant) -> FleetObjectiveSelection:
	if value is Dictionary:
		return FleetObjectiveSelection.deserialize(value as Dictionary)
	return FleetObjectiveSelection.new()


static func _ship_before(left: FleetShipEntry, right: FleetShipEntry) -> bool:
	return left.entry_id < right.entry_id


static func _squadron_before(left: FleetSquadronEntry, right: FleetSquadronEntry) -> bool:
	return left.entry_id < right.entry_id
