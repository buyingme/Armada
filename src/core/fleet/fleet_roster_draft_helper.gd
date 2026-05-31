## Fleet Roster Draft Helper
##
## Thin mutation helper for the fleet-builder UI. It edits [FleetRoster] through
## roster APIs and leaves legality decisions to [FleetValidator].
class_name FleetRosterDraftHelper
extends RefCounted


const DEFAULT_FLEET_ID: String = "draft-fleet"
const DEFAULT_NAME: String = "New Fleet"


## Creates the default local draft used when opening the fleet-builder scene.
static func create_default_roster() -> FleetRoster:
	var roster: FleetRoster = FleetRoster.create(
			DEFAULT_FLEET_ID, DEFAULT_NAME, FleetBuilderOptions.default_faction())
	roster.point_format = FleetBuilderOptions.default_point_format()
	roster.map = FleetBuilderOptions.default_map_for_point_format(roster.point_format)
	return roster


## Adds a ship catalog entry to [param roster].
static func add_ship(roster: FleetRoster, data_key: String, entry_id: String) -> bool:
	if roster == null:
		return false
	var entry: FleetShipEntry = FleetShipEntry.new()
	entry.entry_id = entry_id
	entry.data_key = data_key
	return roster.add_ship(entry)


## Adds a squadron catalog entry to [param roster].
static func add_squadron(roster: FleetRoster, data_key: String, entry_id: String) -> bool:
	if roster == null:
		return false
	var entry: FleetSquadronEntry = FleetSquadronEntry.new()
	entry.entry_id = entry_id
	entry.data_key = data_key
	return roster.add_squadron(entry)


## Adds an upgrade to the first open matching slot on [param ship_entry_id].
static func add_upgrade(roster: FleetRoster, ship_entry_id: String,
		data_key: String, assignment_id: String) -> bool:
	var ship_entry: FleetShipEntry = _ship_entry(roster, ship_entry_id)
	if ship_entry == null:
		return false
	var ship_data: ShipData = AssetLoader.load_ship_data(ship_entry.data_key)
	var upgrade_data: UpgradeData = AssetLoader.load_upgrade_data(data_key)
	var assignment: FleetUpgradeAssignment = FleetUpgradeSlotResolver.create_first_available_assignment(
			ship_entry, ship_data, upgrade_data, assignment_id)
	if assignment == null:
		return false
	return ship_entry.add_upgrade(assignment)


## Sets an objective by loading its catalog category.
static func set_objective(roster: FleetRoster, data_key: String) -> bool:
	if roster == null:
		return false
	var objective: ObjectiveData = AssetLoader.load_objective_data(data_key)
	if objective == null:
		return false
	return roster.objectives.set_objective(objective.category, data_key)


## Sets a roster map by filename when it is known and size-classed.
static func set_map(roster: FleetRoster, filename: String) -> bool:
	if roster == null:
		return false
	var payload: Dictionary = FleetBuilderOptions.map_payload(filename)
	if payload.is_empty():
		return false
	roster.map = payload
	return true


static func _ship_entry(roster: FleetRoster, ship_entry_id: String) -> FleetShipEntry:
	if roster == null:
		return null
	return roster.get_ship(ship_entry_id)
