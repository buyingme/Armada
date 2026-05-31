## Fleet Validator
##
## Baseline fleet-construction validation over static catalog metadata.
## Returns deterministic structured issues via [FleetValidationResult].
class_name FleetValidator
extends RefCounted


const DEFAULT_POINT_LIMIT: int = 400
const SQUADRON_CAP_DIVISOR: float = 3.0
const UNIQUE_SQUADRON_LIMIT_DIVISOR: float = 100.0

const RULE_SHIP_REFERENCE: String = "fleet.catalog.ship"
const RULE_SQUADRON_REFERENCE: String = "fleet.catalog.squadron"
const RULE_UPGRADE_REFERENCE: String = "fleet.catalog.upgrade"
const RULE_POINTS_LIMIT: String = "fleet.points.limit"
const RULE_FACTION_ALIGNMENT: String = "fleet.faction.alignment"
const RULE_COMMANDER_COUNT: String = "fleet.commander.count"
const RULE_FLAGSHIP_COUNT: String = "fleet.flagship.count"
const RULE_SQUADRON_CAP: String = "fleet.squadrons.cap"
const RULE_UNIQUE_UPGRADE: String = "fleet.unique.upgrade"
const RULE_UNIQUE_SQUADRON: String = "fleet.unique.squadron"
const RULE_UNIQUE_SQUADRON_LIMIT: String = "fleet.unique.squadron.limit"
const RULE_UPGRADE_SLOT: String = "fleet.upgrade.slot"
const RULE_UPGRADE_DUPLICATE_PER_SHIP: String = "fleet.upgrade.duplicate.per_ship"
const RULE_UPGRADE_TITLE_LIMIT: String = "fleet.upgrade.title.limit"
const RULE_UPGRADE_MODIFICATION_LIMIT: String = "fleet.upgrade.modification.limit"
const RULE_UPGRADE_RESTRICTION: String = "fleet.upgrade.restriction"
const RULE_OBJECTIVE_REQUIRED: String = "fleet.objective.required"
const RULE_OBJECTIVE_INVALID: String = "fleet.objective.invalid"
const RULE_OBJECTIVE_CATEGORY: String = "fleet.objective.category"
const RULE_MAP_REQUIRED: String = "fleet.map.required"
const RULE_MAP_INVALID: String = "fleet.map.invalid"
const RULE_MAP_GRID: String = "fleet.map.grid"

var _ship_cache: Dictionary = {}
var _ship_record_cache: Dictionary = {}
var _squadron_cache: Dictionary = {}
var _upgrade_cache: Dictionary = {}
var _objective_cache: Dictionary = {}


## Validates [param roster] and returns deterministic structured issues.
func validate(roster: FleetRoster) -> FleetValidationResult:
	_clear_caches()
	var result: FleetValidationResult = FleetValidationResult.new()
	_validate_catalog_references(roster, result)
	_validate_points_limit(roster, result)
	_validate_faction_alignment(roster, result)
	_validate_commander_and_flagship(roster, result)
	_validate_squadron_cap(roster, result)
	_validate_unique_constraints(roster, result)
	_validate_upgrade_assignments(roster, result)
	_validate_objective_selection(roster, result)
	_validate_map_selection(roster, result)
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
	var squadron_cap: int = int(ceil(point_limit / SQUADRON_CAP_DIVISOR))
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
	_validate_unique_squadron_limit(roster, result)


func _validate_catalog_references(roster: FleetRoster,
		result: FleetValidationResult) -> void:
	for ship_entry: FleetShipEntry in _sorted_ships(roster):
		if _load_ship(ship_entry.data_key) == null:
			result.add_error(RULE_SHIP_REFERENCE,
				"Ship '%s' could not be loaded." % ship_entry.data_key,
				[ship_entry.entry_id], [])
		for assignment: FleetUpgradeAssignment in _sorted_assignments(ship_entry):
			if _load_upgrade(assignment.data_key) == null:
				result.add_error(RULE_UPGRADE_REFERENCE,
					"Upgrade '%s' could not be loaded." % assignment.data_key,
					[ship_entry.entry_id, assignment.entry_id], [])
	for squadron_entry: FleetSquadronEntry in _sorted_squadrons(roster):
		if _load_squadron(squadron_entry.data_key) == null:
			result.add_error(RULE_SQUADRON_REFERENCE,
				"Squadron '%s' could not be loaded." % squadron_entry.data_key,
				[squadron_entry.entry_id], [])


func _validate_objective_selection(roster: FleetRoster,
		result: FleetValidationResult) -> void:
	for category: String in FleetObjectiveSelection.categories():
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


func _validate_map_selection(roster: FleetRoster,
		result: FleetValidationResult) -> void:
	var filename: String = _roster_map_filename(roster)
	if filename.is_empty():
		result.add_error(RULE_MAP_REQUIRED,
			"A fleet map must be selected.", [], ["RRG 1.5.0 Play Area"])
		return
	var payload: Dictionary = FleetBuilderOptions.map_payload(filename)
	if payload.is_empty():
		result.add_error(RULE_MAP_INVALID,
			"Map '%s' could not be loaded." % filename, [], [])
		return
	_validate_map_grid(roster, payload, result)


func _validate_map_grid(roster: FleetRoster, payload: Dictionary,
		result: FleetValidationResult) -> void:
	var required_grid: String = FleetBuilderOptions.required_map_grid_for_point_format(
			roster.point_format)
	if required_grid.is_empty() or str(payload.get("grid", "")) == required_grid:
		return
	result.add_error(RULE_MAP_GRID,
		"Point limit %d requires a %s map." % [_point_limit(roster), required_grid],
		[], ["RRG 1.5.0 Play Area", "RRG 1.5.0 Setup Area"])


func _validate_upgrade_assignments(roster: FleetRoster,
		result: FleetValidationResult) -> void:
	for ship_entry: FleetShipEntry in _sorted_ships(roster):
		var ship_data: ShipData = _load_ship(ship_entry.data_key)
		if ship_data == null:
			continue
		var slots_by_type: Dictionary = _ship_slots_by_type(ship_data)
		_validate_ship_upgrade_slots(ship_entry, slots_by_type, result)
		_validate_ship_upgrade_duplicates(ship_entry, result)
		_validate_ship_upgrade_limits(ship_entry, result)
		_validate_ship_upgrade_restrictions(ship_entry, ship_data, result)


func _roster_map_filename(roster: FleetRoster) -> String:
	return str(roster.map.get("filename", roster.map.get("map_image", ""))).strip_edges()


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
		var unique_key: String = _squadron_unique_key(squadron_data)
		if not unique_squadrons.has(unique_key):
			unique_squadrons[unique_key] = squadron_entry.entry_id
			continue
		result.add_error(RULE_UNIQUE_SQUADRON,
			"Unique squadron '%s' appears more than once." % unique_key,
			[unique_squadrons[unique_key], squadron_entry.entry_id], [])


func _validate_unique_squadron_limit(roster: FleetRoster,
		result: FleetValidationResult) -> void:
	var unique_ids: Array[String] = []
	for squadron_entry: FleetSquadronEntry in _sorted_squadrons(roster):
		var squadron_data: SquadronData = _load_squadron(squadron_entry.data_key)
		if squadron_data == null or not _counts_against_unique_squadron_limit(squadron_data):
			continue
		unique_ids.append(squadron_entry.entry_id)
	var limit: int = int(ceil(_point_limit(roster) / UNIQUE_SQUADRON_LIMIT_DIVISOR))
	if unique_ids.size() <= limit:
		return
	result.add_error(RULE_UNIQUE_SQUADRON_LIMIT,
		"Unique squadrons with defense tokens %d exceed limit %d." % [
			unique_ids.size(),
			limit,
		], unique_ids, ["RRG 1.5.0 Fleet Building"])


func _validate_ship_upgrade_slots(ship_entry: FleetShipEntry,
		slots_by_type: Dictionary, result: FleetValidationResult) -> void:
	var occupied: Dictionary = {}
	for assignment: FleetUpgradeAssignment in _sorted_assignments(ship_entry):
		var upgrade_data: UpgradeData = _load_upgrade(assignment.data_key)
		var slot_name: String = _normalized_slot(assignment.slot)
		if slot_name.is_empty():
			result.add_error(RULE_UPGRADE_SLOT,
				"Upgrade '%s' is missing a slot assignment." % assignment.data_key,
				[ship_entry.entry_id, assignment.entry_id], [])
			continue
		if upgrade_data == null:
			continue
		_validate_single_upgrade_slot(ship_entry, assignment, upgrade_data,
			slot_name, slots_by_type, occupied, result)


func _validate_single_upgrade_slot(ship_entry: FleetShipEntry,
		assignment: FleetUpgradeAssignment, upgrade_data: UpgradeData,
		slot_name: String, slots_by_type: Dictionary, occupied: Dictionary,
		result: FleetValidationResult) -> void:
	if not slots_by_type.has(slot_name):
		result.add_error(RULE_UPGRADE_SLOT,
			"Ship '%s' has no %s slot for upgrade '%s'." % [
				ship_entry.data_key,
				slot_name,
				assignment.data_key,
			], [ship_entry.entry_id, assignment.entry_id], [])
		return
	if not _assignment_matches_upgrade_slot(slot_name, upgrade_data):
		result.add_error(RULE_UPGRADE_SLOT,
			"Upgrade '%s' must be assigned to %s slot." % [
				assignment.data_key,
				str(upgrade_data.upgrade_type).to_upper(),
			], [ship_entry.entry_id, assignment.entry_id], [])
		return
	var slot_entries: Array = slots_by_type[slot_name] as Array
	if assignment.slot_index < 0 or assignment.slot_index >= slot_entries.size():
		result.add_error(RULE_UPGRADE_SLOT,
			"Upgrade '%s' uses invalid slot index %d for %s." % [
				assignment.data_key,
				assignment.slot_index,
				slot_name,
			], [ship_entry.entry_id, assignment.entry_id], [])
		return
	var occupancy_key: String = "%s:%d" % [slot_name, assignment.slot_index]
	if occupied.has(occupancy_key):
		result.add_error(RULE_UPGRADE_SLOT,
			"Slot %s[%d] is already occupied." % [slot_name, assignment.slot_index],
			[ship_entry.entry_id, occupied[occupancy_key], assignment.entry_id], [])
		return
	occupied[occupancy_key] = assignment.entry_id


func _validate_ship_upgrade_duplicates(ship_entry: FleetShipEntry,
		result: FleetValidationResult) -> void:
	var seen: Dictionary = {}
	for assignment: FleetUpgradeAssignment in _sorted_assignments(ship_entry):
		if assignment.data_key.strip_edges().is_empty():
			continue
		if _load_upgrade(assignment.data_key) == null:
			continue
		if not seen.has(assignment.data_key):
			seen[assignment.data_key] = assignment.entry_id
			continue
		result.add_error(RULE_UPGRADE_DUPLICATE_PER_SHIP,
			"Upgrade '%s' cannot be assigned multiple times to one ship." %
			assignment.data_key,
			[ship_entry.entry_id, seen[assignment.data_key], assignment.entry_id], [])


func _validate_ship_upgrade_limits(ship_entry: FleetShipEntry,
		result: FleetValidationResult) -> void:
	var title_ids: Array[String] = []
	var modification_ids: Array[String] = []
	for assignment: FleetUpgradeAssignment in _sorted_assignments(ship_entry):
		var upgrade_data: UpgradeData = _load_upgrade(assignment.data_key)
		if upgrade_data == null:
			continue
		if str(upgrade_data.upgrade_type).to_upper() == "TITLE":
			title_ids.append(assignment.entry_id)
		if upgrade_data.is_modification:
			modification_ids.append(assignment.entry_id)
	if title_ids.size() > 1:
		result.add_error(RULE_UPGRADE_TITLE_LIMIT,
			"Ship '%s' can equip only one TITLE upgrade." % ship_entry.data_key,
			_prepend_ship_entry_id(ship_entry.entry_id, title_ids), [])
	if modification_ids.size() > 1:
		result.add_error(RULE_UPGRADE_MODIFICATION_LIMIT,
			"Ship '%s' can equip only one Modification upgrade." % ship_entry.data_key,
			_prepend_ship_entry_id(ship_entry.entry_id, modification_ids), [])


func _validate_ship_upgrade_restrictions(ship_entry: FleetShipEntry,
		ship_data: ShipData, result: FleetValidationResult) -> void:
	for assignment: FleetUpgradeAssignment in _sorted_assignments(ship_entry):
		var upgrade_data: UpgradeData = _load_upgrade(assignment.data_key)
		if _upgrade_allowed_for_ship(upgrade_data, ship_entry.data_key, ship_data):
			continue
		result.add_error(RULE_UPGRADE_RESTRICTION,
			"Upgrade '%s' does not meet ship restrictions for '%s'." % [
				assignment.data_key,
				ship_entry.data_key,
			], [ship_entry.entry_id, assignment.entry_id], [])


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


func _upgrade_allowed_for_ship(upgrade_data: UpgradeData,
		ship_key: String, ship_data: ShipData) -> bool:
	if upgrade_data == null:
		return true
	if not _upgrade_matches_ship_size(upgrade_data, ship_data):
		return false
	if not _upgrade_matches_ship_data_key(upgrade_data, ship_key):
		return false
	if not _upgrade_matches_ship_class(upgrade_data, ship_key):
		return false
	return true


func _upgrade_matches_ship_size(upgrade_data: UpgradeData,
		ship_data: ShipData) -> bool:
	if upgrade_data.size_restriction.is_empty():
		return true
	return upgrade_data.size_restriction.has(int(ship_data.ship_size))


func _upgrade_matches_ship_data_key(upgrade_data: UpgradeData,
		ship_key: String) -> bool:
	if upgrade_data.ship_data_key_restriction.is_empty():
		return true
	return upgrade_data.ship_data_key_restriction.has(ship_key)


func _upgrade_matches_ship_class(upgrade_data: UpgradeData,
		ship_key: String) -> bool:
	if upgrade_data.ship_class_restriction.is_empty():
		return true
	var ship_class: String = _ship_class(ship_key)
	if ship_class.is_empty():
		return false
	return upgrade_data.ship_class_restriction.has(ship_class)


func _assignment_matches_upgrade_slot(slot_name: String,
		upgrade_data: UpgradeData) -> bool:
	if upgrade_data == null:
		return true
	var upgrade_slot: String = str(upgrade_data.upgrade_type).to_upper()
	if upgrade_slot.is_empty():
		return true
	if upgrade_slot == "COMMANDER" and slot_name == "OFFICER":
		return true
	return slot_name == upgrade_slot


func _ship_slots_by_type(ship_data: ShipData) -> Dictionary:
	var slots_by_type: Dictionary = {}
	for index: int in range(ship_data.upgrade_slots.size()):
		var slot_name: String = _normalized_slot(str(ship_data.upgrade_slots[index]))
		if slot_name.is_empty():
			continue
		if not slots_by_type.has(slot_name):
			slots_by_type[slot_name] = []
		(slots_by_type[slot_name] as Array).append(index)
	return slots_by_type


func _normalized_slot(slot_name: String) -> String:
	return slot_name.strip_edges().to_upper()


func _prepend_ship_entry_id(ship_entry_id: String,
		upgrade_entry_ids: Array[String]) -> Array[String]:
	var combined: Array[String] = [ship_entry_id]
	for entry_id: String in upgrade_entry_ids:
		combined.append(entry_id)
	return combined


func _upgrade_unique_key(upgrade_data: UpgradeData) -> String:
	if not upgrade_data.unique_group.is_empty():
		return upgrade_data.unique_group
	return upgrade_data.data_key


func _squadron_unique_key(squadron_data: SquadronData) -> String:
	if not squadron_data.unique_group.is_empty():
		return squadron_data.unique_group
	return squadron_data.squadron_name


func _counts_against_unique_squadron_limit(squadron_data: SquadronData) -> bool:
	return squadron_data.is_unique and not squadron_data.defense_tokens.is_empty()


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


func _ship_class(data_key: String) -> String:
	if _ship_record_cache.has(data_key):
		return _ship_record_cache[data_key]
	var ship_record: Dictionary = AssetLoader.load_json(AssetLoader.SHIP_FOLDER,
		data_key + AssetLoader.JSON_EXTENSION)
	var ship_class: String = str(ship_record.get("ship_class", ""))
	_ship_record_cache[data_key] = ship_class
	return ship_class


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
	_ship_record_cache.clear()
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
