## Fleet Roster Summary
##
## Computes display totals for editable fleet-builder rosters without putting
## catalog lookups or point math in presentation code.
class_name FleetRosterSummary
extends RefCounted


const KEY_SHIP_POINTS: String = "ship_points"
const KEY_SQUADRON_POINTS: String = "squadron_points"
const KEY_UPGRADE_POINTS: String = "upgrade_points"
const KEY_TOTAL_POINTS: String = "total_points"
const KEY_POINT_LIMIT: String = "point_limit"


## Returns JSON-safe point totals for [param roster]. Missing catalog records
## contribute zero points so the validator can report the actual reference issue.
static func calculate(roster: FleetRoster) -> Dictionary:
	var ship_points: int = _ship_base_points(roster)
	var squadron_points: int = _squadron_points(roster)
	var upgrade_points: int = _upgrade_points(roster)
	return {
		KEY_SHIP_POINTS: ship_points,
		KEY_SQUADRON_POINTS: squadron_points,
		KEY_UPGRADE_POINTS: upgrade_points,
		KEY_TOTAL_POINTS: ship_points + squadron_points + upgrade_points,
		KEY_POINT_LIMIT: _point_limit(roster),
	}


static func _ship_base_points(roster: FleetRoster) -> int:
	if roster == null:
		return 0
	var total: int = 0
	for ship_entry: FleetShipEntry in roster.ships:
		var ship_data: ShipData = AssetLoader.load_ship_data(ship_entry.data_key)
		if ship_data != null:
			total += ship_data.point_cost
	return total


static func _squadron_points(roster: FleetRoster) -> int:
	if roster == null:
		return 0
	var total: int = 0
	for squadron_entry: FleetSquadronEntry in roster.squadrons:
		var data: SquadronData = AssetLoader.load_squadron_data(squadron_entry.data_key)
		if data != null:
			total += data.point_cost
	return total


static func _upgrade_points(roster: FleetRoster) -> int:
	if roster == null:
		return 0
	var total: int = 0
	for ship_entry: FleetShipEntry in roster.ships:
		total += _ship_upgrade_points(ship_entry)
	return total


static func _ship_upgrade_points(ship_entry: FleetShipEntry) -> int:
	var total: int = 0
	for assignment: FleetUpgradeAssignment in ship_entry.upgrades:
		var data: UpgradeData = AssetLoader.load_upgrade_data(assignment.data_key)
		if data != null:
			total += data.point_cost
	return total


static func _point_limit(roster: FleetRoster) -> int:
	if roster == null:
		return FleetValidator.DEFAULT_POINT_LIMIT
	return int(roster.point_format.get("limit", FleetValidator.DEFAULT_POINT_LIMIT))
