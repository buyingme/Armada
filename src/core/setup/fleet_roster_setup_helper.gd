## Fleet Roster Setup Helper
##
## Converts embedded setup-package roster payloads into runtime player, ship,
## and squadron state without reading local fleet-library files.
class_name FleetRosterSetupHelper
extends RefCounted


const COMPONENT_SHIP: String = "ship"
const COMPONENT_SQUADRON: String = "squadron"
const DEFAULT_DEPLOYMENT_SPEED: int = 1
const RULE_PACKAGE: String = "setup.runtime.package"
const RULE_PLAYER_ENTRY: String = "setup.runtime.player_entry"
const RULE_SHIP_DATA: String = "setup.runtime.ship_data"
const RULE_SQUADRON_DATA: String = "setup.runtime.squadron_data"
const RULE_UPGRADE_DATA: String = "setup.runtime.upgrade_data"
const RULE_DEPLOYMENT_SPEED: String = "setup.runtime.deployment_speed"


## Converts [param package] into runtime player states and flattened instances.
## Rules Reference: "Setup", steps 2 and 6, RRG p.16; FAQ "Deploy Ships".
static func prepare_runtime(package: FleetSetupPackage) -> Dictionary:
	var validation: SetupValidationResult = SetupValidationResult.new()
	if package == null:
		validation.add_error(RULE_PACKAGE, "Setup package is required.", [], [])
		return _empty_result(validation)
	_validate_basic_package(package, validation)
	if not validation.is_valid():
		return _empty_result(validation)
	var entries: Array[Dictionary] = _player_entries_by_index(package, validation)
	if not validation.is_valid():
		return _empty_result(validation)
	var player_states: Array[PlayerState] = _create_player_states(entries)
	var ships: Array[ShipInstance] = []
	var squadrons: Array[SquadronInstance] = []
	_create_instances(package, entries, ships, squadrons, validation)
	if not validation.is_valid():
		return _empty_result(validation)
	_attach_instances(player_states, ships, squadrons)
	return _build_result(true, player_states, ships, squadrons, validation)


static func _validate_basic_package(package: FleetSetupPackage,
		validation: SetupValidationResult) -> void:
	for message: String in package.validate_basic():
		validation.add_error(RULE_PACKAGE, message, [], [])


static func _player_entries_by_index(package: FleetSetupPackage,
		validation: SetupValidationResult) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for _index: int in range(Constants.PLAYER_COUNT):
		entries.append({})
	for raw_entry: Dictionary in package.players:
		_place_player_entry(entries, raw_entry, validation)
	for player_index: int in range(Constants.PLAYER_COUNT):
		if entries[player_index].is_empty():
			validation.add_error(RULE_PLAYER_ENTRY,
				"Player %d setup entry is missing." % player_index,
				["players/%d" % player_index], [])
	return entries


static func _place_player_entry(entries: Array[Dictionary], raw_entry: Dictionary,
		validation: SetupValidationResult) -> void:
	var player_index: int = int(raw_entry.get("player_index", -1))
	if not _player_index_valid(player_index):
		validation.add_error(RULE_PLAYER_ENTRY, "Player entry index is out of range.",
			["players"], [])
		return
	if not entries[player_index].is_empty():
		validation.add_error(RULE_PLAYER_ENTRY,
			"Player %d setup entry is duplicated." % player_index,
			["players/%d" % player_index], [])
		return
	entries[player_index] = raw_entry.duplicate(true)


static func _create_player_states(entries: Array[Dictionary]) -> Array[PlayerState]:
	var states: Array[PlayerState] = []
	for player_index: int in range(Constants.PLAYER_COUNT):
		var roster: FleetRoster = _roster_from_player_entry(entries[player_index])
		var state: PlayerState = PlayerState.new()
		state.player_index = player_index
		state.faction = _faction_from_player_entry(entries[player_index], roster)
		state.fleet_points = int(FleetRosterSummary.calculate(roster).get(
			FleetRosterSummary.KEY_TOTAL_POINTS, 0))
		states.append(state)
	return states


static func _create_instances(package: FleetSetupPackage, entries: Array[Dictionary],
		ships: Array[ShipInstance], squadrons: Array[SquadronInstance],
		validation: SetupValidationResult) -> void:
	for player_index: int in range(Constants.PLAYER_COUNT):
		var roster: FleetRoster = _roster_from_player_entry(entries[player_index])
		_append_ship_instances(package, roster, player_index, ships, validation)
		_append_squadron_instances(package, roster, player_index, squadrons, validation)


static func _append_ship_instances(package: FleetSetupPackage, roster: FleetRoster,
		player_index: int, ships: Array[ShipInstance],
		validation: SetupValidationResult) -> void:
	for ship_entry: FleetShipEntry in roster.ships:
		var ship_data: ShipData = AssetLoader.load_ship_data(ship_entry.data_key)
		if ship_data == null:
			_add_entry_error(validation, RULE_SHIP_DATA, player_index, ship_entry.entry_id,
				"Ship '%s' could not be loaded." % ship_entry.data_key)
			continue
		var deployment: Dictionary = _deployment_for_component(package, COMPONENT_SHIP,
			player_index, ship_entry.entry_id)
		var speed: int = _initial_speed_for_ship(deployment, player_index,
			ship_entry, ship_data, validation)
		var ship: ShipInstance = ShipInstance.create_from_data(
			ship_entry.data_key, ship_data, speed, player_index)
		ship.roster_entry_id = ship_entry.entry_id
		ship.fleet_points = _ship_fleet_points(ship_entry, ship_data, player_index,
			validation)
		_apply_ship_deployment(ship, deployment)
		ships.append(ship)


static func _append_squadron_instances(package: FleetSetupPackage,
		roster: FleetRoster, player_index: int,
		squadrons: Array[SquadronInstance], validation: SetupValidationResult) -> void:
	for squadron_entry: FleetSquadronEntry in roster.squadrons:
		var squadron_data: SquadronData = AssetLoader.load_squadron_data(
			squadron_entry.data_key)
		if squadron_data == null:
			_add_entry_error(validation, RULE_SQUADRON_DATA, player_index,
				squadron_entry.entry_id,
				"Squadron '%s' could not be loaded." % squadron_entry.data_key)
			continue
		var squadron: SquadronInstance = SquadronInstance.create_from_data(
			squadron_entry.data_key, squadron_data, player_index)
		squadron.roster_entry_id = squadron_entry.entry_id
		squadron.fleet_points = squadron_data.point_cost
		_apply_squadron_deployment(squadron, _deployment_for_component(
			package, COMPONENT_SQUADRON, player_index, squadron_entry.entry_id))
		squadrons.append(squadron)


static func _initial_speed_for_ship(deployment: Dictionary, player_index: int,
		ship_entry: FleetShipEntry, ship_data: ShipData,
		validation: SetupValidationResult) -> int:
	var requested_speed: int = _read_deployment_speed(deployment)
	if requested_speed < 0:
		return _minimum_deployment_speed(ship_data)
	if _ship_speed_valid(requested_speed, ship_data):
		return requested_speed
	validation.add_error(RULE_DEPLOYMENT_SPEED,
		"Ship '%s' deployment speed %d is not legal." % [
			ship_entry.entry_id,
			requested_speed,
		], [_entry_path(player_index, ship_entry.entry_id)], [])
	return clampi(requested_speed,
		_minimum_deployment_speed(ship_data), ship_data.max_speed)


static func _ship_fleet_points(ship_entry: FleetShipEntry, ship_data: ShipData,
		player_index: int, validation: SetupValidationResult) -> int:
	var total: int = ship_data.point_cost
	for assignment: FleetUpgradeAssignment in ship_entry.upgrades:
		var upgrade_data: UpgradeData = AssetLoader.load_upgrade_data(assignment.data_key)
		if upgrade_data == null:
			validation.add_error(RULE_UPGRADE_DATA,
				"Upgrade '%s' could not be loaded." % assignment.data_key,
				[_upgrade_path(player_index, ship_entry.entry_id, assignment.entry_id)], [])
			continue
		total += upgrade_data.point_cost
	return total


static func _attach_instances(player_states: Array[PlayerState],
		ships: Array[ShipInstance], squadrons: Array[SquadronInstance]) -> void:
	for ship: ShipInstance in ships:
		if _player_index_valid(ship.owner_player):
			player_states[ship.owner_player].ships.append(ship)
	for squadron: SquadronInstance in squadrons:
		if _player_index_valid(squadron.owner_player):
			player_states[squadron.owner_player].squadrons.append(squadron)


static func _deployment_for_component(package: FleetSetupPackage, component_type: String,
		player_index: int, roster_entry_id: String) -> Dictionary:
	for deployment: Dictionary in package.deployments:
		if str(deployment.get("component_type", "")) != component_type:
			continue
		if int(deployment.get("owner_player", -1)) != player_index:
			continue
		if str(deployment.get("roster_entry_id", "")) == roster_entry_id:
			return deployment.duplicate(true)
	return {}


static func _apply_ship_deployment(
		ship: ShipInstance, deployment: Dictionary) -> void:
	if deployment.is_empty():
		return
	ship.pos_x = float(deployment.get("pos_x", ship.pos_x))
	ship.pos_y = float(deployment.get("pos_y", ship.pos_y))
	ship.rotation_deg = float(deployment.get("rotation_deg", ship.rotation_deg))


static func _apply_squadron_deployment(
		squadron: SquadronInstance, deployment: Dictionary) -> void:
	if deployment.is_empty():
		return
	squadron.pos_x = float(deployment.get("pos_x", squadron.pos_x))
	squadron.pos_y = float(deployment.get("pos_y", squadron.pos_y))
	squadron.rotation_deg = float(deployment.get(
			"rotation_deg", squadron.rotation_deg))


static func _read_deployment_speed(deployment: Dictionary) -> int:
	if deployment.is_empty():
		return -1
	if deployment.has("current_speed"):
		return int(deployment.get("current_speed", -1))
	if deployment.has("speed"):
		return int(deployment.get("speed", -1))
	return -1


static func _ship_speed_valid(speed: int, ship_data: ShipData) -> bool:
	return speed >= _minimum_deployment_speed(ship_data) and speed <= ship_data.max_speed


static func _minimum_deployment_speed(ship_data: ShipData) -> int:
	if ship_data.max_speed < DEFAULT_DEPLOYMENT_SPEED:
		return 0
	return DEFAULT_DEPLOYMENT_SPEED


static func _faction_from_player_entry(entry: Dictionary,
		roster: FleetRoster) -> Constants.Faction:
	var faction_name: String = str(entry.get("faction", ""))
	if faction_name.strip_edges().is_empty():
		faction_name = roster.faction
	match faction_name.to_upper():
		"GALACTIC_EMPIRE":
			return Constants.Faction.GALACTIC_EMPIRE
		"GALACTIC_REPUBLIC":
			return Constants.Faction.GALACTIC_REPUBLIC
		"SEPARATIST_ALLIANCE":
			return Constants.Faction.SEPARATIST_ALLIANCE
		_:
			return Constants.Faction.REBEL_ALLIANCE


static func _roster_from_player_entry(entry: Dictionary) -> FleetRoster:
	return FleetRoster.deserialize(_read_dict(entry.get("roster", {})))


static func _read_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}


static func _add_entry_error(validation: SetupValidationResult, rule_id: String,
		player_index: int, entry_id: String, message: String) -> void:
	validation.add_error(rule_id, message, [_entry_path(player_index, entry_id)], [])


static func _entry_path(player_index: int, entry_id: String) -> String:
	return "players/%d/roster/entries/%s" % [player_index, entry_id]


static func _upgrade_path(player_index: int, ship_entry_id: String,
		upgrade_entry_id: String) -> String:
	return "%s/upgrades/%s" % [_entry_path(player_index, ship_entry_id), upgrade_entry_id]


static func _player_index_valid(player_index: int) -> bool:
	return player_index >= 0 and player_index < Constants.PLAYER_COUNT


static func _empty_result(validation: SetupValidationResult) -> Dictionary:
	var player_states: Array[PlayerState] = []
	var ships: Array[ShipInstance] = []
	var squadrons: Array[SquadronInstance] = []
	return _build_result(false, player_states, ships, squadrons, validation)


static func _build_result(ok: bool, player_states: Array[PlayerState],
		ships: Array[ShipInstance], squadrons: Array[SquadronInstance],
		validation: SetupValidationResult) -> Dictionary:
	return {
		"ok": ok,
		"player_states": player_states,
		"ships": ships,
		"squadrons": squadrons,
		"validation": validation,
	}