## Fleet Validator
##
## Baseline fleet-construction validation over static catalog metadata.
## Returns deterministic structured issues via [FleetValidationResult].
class_name FleetValidator
extends RefCounted


const DEFAULT_POINT_LIMIT: int = 400
const SQUADRON_CAP_DIVISOR: float = 3.0

const RULE_POINTS_LIMIT: String = "fleet.points.limit"
const RULE_FACTION_ALIGNMENT: String = "fleet.faction.alignment"
const RULE_COMMANDER_COUNT: String = "fleet.commander.count"
const RULE_FLAGSHIP_COUNT: String = "fleet.flagship.count"
const RULE_SQUADRON_CAP: String = "fleet.squadrons.cap"
const RULE_UNIQUE_UPGRADE: String = "fleet.unique.upgrade"
const RULE_UNIQUE_SQUADRON: String = "fleet.unique.squadron"
const RULE_OBJECTIVE_REQUIRED: String = "fleet.objective.required"
const RULE_OBJECTIVE_INVALID: String = "fleet.objective.invalid"
const RULE_OBJECTIVE_CATEGORY: String = "fleet.objective.category"

const OBJECTIVE_CATEGORIES: Array[String] = [
	FleetObjectiveSelection.CATEGORY_ASSAULT,
	FleetObjectiveSelection.CATEGORY_DEFENSE,
	FleetObjectiveSelection.CATEGORY_NAVIGATION,
]

var _ship_cache: Dictionary = {}
var _squadron_cache: Dictionary = {}
var _upgrade_cache: Dictionary = {}
var _objective_cache: Dictionary = {}


## Validates [param roster] and returns deterministic structured issues.
func validate(roster: FleetRoster) -> FleetValidationResult:
	_clear_caches()
	var result: FleetValidationResult = FleetValidationResult.new()
	_validate_points_limit(roster, result)
	_validate_faction_alignment(roster, result)
	_validate_commander_and_flagship(roster, result)
	_validate_squadron_cap(roster, result)
	_validate_unique_constraints(roster, result)
	_validate_objective_selection(roster, result)
	return result


func _validate_points_limit(roster: FleetRoster,
		result: FleetValidationResult) -> void:
	var point_limit: int = _point_limit(roster)
	var fleet_points: int = _fleet_points(roster)
	if fleet_points <= point_limit:
		return
	result.add_error(RULE_POINTS_LIMIT,
		"Fleet points %d exceed limit %d." % [fleet_points, point_limit], [],
		["RRG 1.5.0 Fleet Building"])


func _validate_faction_alignment(roster: FleetRoster,
		result: FleetValidationResult) -> void:
	var faction_value: int = _faction_value(roster.faction)
	if faction_value < 0:
		result.add_error(RULE_FACTION_ALIGNMENT,
			"Roster faction '%s' is invalid." % roster.faction, [], [])
		return
	_validate_ship_faction(roster, faction_value, result)
	_validate_squadron_faction(roster, faction_value, result)
	_validate_upgrade_faction(roster, faction_value, result)


func _validate_commander_and_flagship(roster: FleetRoster,
		result: FleetValidationResult) -> void:
	var commander_count: int = 0
	var flagship_count: int = 0
	for ship_entry: FleetShipEntry in _sorted_ships(roster):
		var ship_commander_count: int = _count_ship_commanders(ship_entry)
		commander_count += ship_commander_count
		if ship_commander_count > 0:
			flagship_count += 1
	if commander_count != 1:
		result.add_error(RULE_COMMANDER_COUNT,
			"Fleet must include exactly one commander (found %d)." % commander_count, [],
			["RRG 1.5.0 Fleet Building"])
	if flagship_count != 1:
		result.add_error(RULE_FLAGSHIP_COUNT,
			"Fleet must have exactly one flagship (found %d)." % flagship_count, [],
			["RRG 1.5.0 Fleet Building"])


func _validate_squadron_cap(roster: FleetRoster,
		result: FleetValidationResult) -> void:
	var point_limit: int = _point_limit(roster)
	var squadron_cap: int = int(floor(point_limit / SQUADRON_CAP_DIVISOR))
	var squadron_points: int = _squadron_points(roster)
	if squadron_points <= squadron_cap:
		return
	result.add_error(RULE_SQUADRON_CAP,
		"Squadron points %d exceed one-third cap %d." % [squadron_points, squadron_cap],
		[], ["RRG 1.5.0 Fleet Building"])


func _validate_unique_constraints(roster: FleetRoster,
		result: FleetValidationResult) -> void:
	var unique_upgrades: Dictionary = {}
	var unique_squadrons: Dictionary = {}
	_validate_unique_upgrades(roster, unique_upgrades, result)
	_validate_unique_squadrons(roster, unique_squadrons, result)


func _validate_objective_selection(roster: FleetRoster,
		result: FleetValidationResult) -> void:
	for category: String in OBJECTIVE_CATEGORIES:
		var objective_key: String = roster.objectives.get_objective(category)
		if objective_key.strip_edges().is_empty():
			result.add_error(RULE_OBJECTIVE_REQUIRED,
				"Objective category %s must be selected." % category, [],
				["RRG 1.5.0 Fleet Building"])
			continue
		var objective_data: ObjectiveData = _load_objective(objective_key)
		if objective_data == null:
			result.add_error(RULE_OBJECTIVE_INVALID,
				"Objective '%s' could not be loaded." % objective_key, [], [])
			continue
		if objective_data.category != category:
			result.add_error(RULE_OBJECTIVE_CATEGORY,
				"Objective '%s' must be category %s." % [objective_key, category], [], [])


func _validate_ship_faction(roster: FleetRoster,
		faction_value: int, result: FleetValidationResult) -> void:
	for ship_entry: FleetShipEntry in _sorted_ships(roster):
		var ship_data: ShipData = _load_ship(ship_entry.data_key)
		if ship_data != null and int(ship_data.faction) != faction_value:
			result.add_error(RULE_FACTION_ALIGNMENT,
				"Ship '%s' does not match roster faction." % ship_entry.data_key,
				[ship_entry.entry_id], [])


func _validate_squadron_faction(roster: FleetRoster,
		faction_value: int, result: FleetValidationResult) -> void:
	for squadron_entry: FleetSquadronEntry in _sorted_squadrons(roster):
		var squadron_data: SquadronData = _load_squadron(squadron_entry.data_key)
		if squadron_data != null and int(squadron_data.faction) != faction_value:
			result.add_error(RULE_FACTION_ALIGNMENT,
				"Squadron '%s' does not match roster faction." % squadron_entry.data_key,
				[squadron_entry.entry_id], [])


func _validate_upgrade_faction(roster: FleetRoster,
		faction_value: int, result: FleetValidationResult) -> void:
	for ship_entry: FleetShipEntry in _sorted_ships(roster):
		for assignment: FleetUpgradeAssignment in _sorted_assignments(ship_entry):
			var upgrade_data: UpgradeData = _load_upgrade(assignment.data_key)
			if _upgrade_matches_faction(upgrade_data, faction_value):
				continue
			result.add_error(RULE_FACTION_ALIGNMENT,
				"Upgrade '%s' does not match roster faction." % assignment.data_key,
				[ship_entry.entry_id, assignment.entry_id], [])


func _validate_unique_upgrades(roster: FleetRoster,
		unique_upgrades: Dictionary, result: FleetValidationResult) -> void:
	for ship_entry: FleetShipEntry in _sorted_ships(roster):
		for assignment: FleetUpgradeAssignment in _sorted_assignments(ship_entry):
			var upgrade_data: UpgradeData = _load_upgrade(assignment.data_key)
			if upgrade_data == null or not upgrade_data.is_unique:
				continue
			var unique_key: String = _upgrade_unique_key(upgrade_data)
			if not unique_upgrades.has(unique_key):
				unique_upgrades[unique_key] = assignment.entry_id
				continue
			result.add_error(RULE_UNIQUE_UPGRADE,
				"Unique upgrade '%s' appears more than once." % upgrade_data.upgrade_name,
				[unique_upgrades[unique_key], assignment.entry_id], [])


func _validate_unique_squadrons(roster: FleetRoster,
		unique_squadrons: Dictionary, result: FleetValidationResult) -> void:
	for squadron_entry: FleetSquadronEntry in _sorted_squadrons(roster):
		var squadron_data: SquadronData = _load_squadron(squadron_entry.data_key)
		if squadron_data == null or not squadron_data.is_unique:
			continue
		var unique_key: String = squadron_data.squadron_name
		if not unique_squadrons.has(unique_key):
			unique_squadrons[unique_key] = squadron_entry.entry_id
			continue
		result.add_error(RULE_UNIQUE_SQUADRON,
			"Unique squadron '%s' appears more than once." % unique_key,
			[unique_squadrons[unique_key], squadron_entry.entry_id], [])


func _fleet_points(roster: FleetRoster) -> int:
	return _ship_points(roster) + _squadron_points(roster)


func _ship_points(roster: FleetRoster) -> int:
	var total: int = 0
	for ship_entry: FleetShipEntry in _sorted_ships(roster):
		var ship_data: ShipData = _load_ship(ship_entry.data_key)
		if ship_data != null:
			total += ship_data.point_cost
		total += _upgrade_points(ship_entry)
	return total


func _upgrade_points(ship_entry: FleetShipEntry) -> int:
	var total: int = 0
	for assignment: FleetUpgradeAssignment in _sorted_assignments(ship_entry):
		var upgrade_data: UpgradeData = _load_upgrade(assignment.data_key)
		if upgrade_data != null:
			total += upgrade_data.point_cost
	return total


func _squadron_points(roster: FleetRoster) -> int:
	var total: int = 0
	for squadron_entry: FleetSquadronEntry in _sorted_squadrons(roster):
		var squadron_data: SquadronData = _load_squadron(squadron_entry.data_key)
		if squadron_data != null:
			total += squadron_data.point_cost
	return total


func _count_ship_commanders(ship_entry: FleetShipEntry) -> int:
	var count: int = 0
	for assignment: FleetUpgradeAssignment in _sorted_assignments(ship_entry):
		var upgrade_data: UpgradeData = _load_upgrade(assignment.data_key)
		if upgrade_data != null and upgrade_data.upgrade_type == "COMMANDER":
			count += 1
	return count


func _point_limit(roster: FleetRoster) -> int:
	if roster.point_format.has("limit"):
		return int(roster.point_format.get("limit", DEFAULT_POINT_LIMIT))
	return DEFAULT_POINT_LIMIT


func _upgrade_matches_faction(upgrade_data: UpgradeData,
		faction_value: int) -> bool:
	if upgrade_data == null:
		return true
	if upgrade_data.faction_restriction.is_empty():
		return true
	return upgrade_data.faction_restriction.has(faction_value)


func _upgrade_unique_key(upgrade_data: UpgradeData) -> String:
	if not upgrade_data.unique_group.is_empty():
		return upgrade_data.unique_group
	return upgrade_data.data_key


func _faction_value(faction_name: String) -> int:
	match faction_name.to_upper():
		"REBEL_ALLIANCE":
			return Constants.Faction.REBEL_ALLIANCE
		"GALACTIC_EMPIRE":
			return Constants.Faction.GALACTIC_EMPIRE
		"GALACTIC_REPUBLIC":
			return Constants.Faction.GALACTIC_REPUBLIC
		"SEPARATIST_ALLIANCE":
			return Constants.Faction.SEPARATIST_ALLIANCE
		_:
			return -1


func _load_ship(data_key: String) -> ShipData:
	if _ship_cache.has(data_key):
		return _ship_cache[data_key]
	var data: ShipData = AssetLoader.load_ship_data(data_key)
	_ship_cache[data_key] = data
	return data


func _load_squadron(data_key: String) -> SquadronData:
	if _squadron_cache.has(data_key):
		return _squadron_cache[data_key]
	var data: SquadronData = AssetLoader.load_squadron_data(data_key)
	_squadron_cache[data_key] = data
	return data


func _load_upgrade(data_key: String) -> UpgradeData:
	if _upgrade_cache.has(data_key):
		return _upgrade_cache[data_key]
	var data: UpgradeData = AssetLoader.load_upgrade_data(data_key)
	_upgrade_cache[data_key] = data
	return data


func _load_objective(data_key: String) -> ObjectiveData:
	if _objective_cache.has(data_key):
		return _objective_cache[data_key]
	var data: ObjectiveData = AssetLoader.load_objective_data(data_key)
	_objective_cache[data_key] = data
	return data


func _clear_caches() -> void:
	_ship_cache.clear()
	_squadron_cache.clear()
	_upgrade_cache.clear()
	_objective_cache.clear()


func _sorted_ships(roster: FleetRoster) -> Array[FleetShipEntry]:
	var sorted: Array[FleetShipEntry] = []
	sorted.assign(roster.ships)
	sorted.sort_custom(_ship_before)
	return sorted


func _sorted_squadrons(roster: FleetRoster) -> Array[FleetSquadronEntry]:
	var sorted: Array[FleetSquadronEntry] = []
	sorted.assign(roster.squadrons)
	sorted.sort_custom(_squadron_before)
	return sorted


func _sorted_assignments(ship_entry: FleetShipEntry) -> Array[FleetUpgradeAssignment]:
	var sorted: Array[FleetUpgradeAssignment] = []
	sorted.assign(ship_entry.upgrades)
	sorted.sort_custom(_assignment_before)
	return sorted


static func _ship_before(left: FleetShipEntry, right: FleetShipEntry) -> bool:
	return left.entry_id < right.entry_id


static func _squadron_before(left: FleetSquadronEntry,
		right: FleetSquadronEntry) -> bool:
	return left.entry_id < right.entry_id


static func _assignment_before(left: FleetUpgradeAssignment,
		right: FleetUpgradeAssignment) -> bool:
	return left.entry_id < right.entry_id
