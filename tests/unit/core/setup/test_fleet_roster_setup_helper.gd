## Test: FleetRosterSetupHelper
##
## Unit tests for FB12 roster-to-runtime conversion from setup packages.
extends GutTest


func test_prepare_runtime_rebel_imperial_rosters_expected() -> void:
	var rebel_roster: Dictionary = _rebel_roster()
	var imperial_roster: Dictionary = _imperial_roster()
	var package: FleetSetupPackage = _package_from_rosters(rebel_roster, imperial_roster)

	var result: Dictionary = FleetRosterSetupHelper.prepare_runtime(package)
	var player_states: Array = result.get("player_states", []) as Array
	var ships: Array = result.get("ships", []) as Array
	var squadrons: Array = result.get("squadrons", []) as Array
	var rebel_state: PlayerState = player_states[0] as PlayerState
	var imperial_state: PlayerState = player_states[1] as PlayerState
	var rebel_ship: ShipInstance = _ship_by_entry(ships, "rebel-ship-1")
	var imperial_squadron: SquadronInstance = _squadron_by_entry(
		squadrons, "imperial-squadron-1")

	assert_true(result.get("ok", false),
		"Embedded rosters should convert to runtime state")
	assert_eq(rebel_state.faction, Constants.Faction.REBEL_ALLIANCE,
		"Player 0 faction should come from the embedded roster")
	assert_eq(imperial_state.faction, Constants.Faction.GALACTIC_EMPIRE,
		"Player 1 faction should come from the embedded roster")
	assert_eq(rebel_state.fleet_points, _roster_points(rebel_roster),
		"Player state should carry computed rebel fleet points")
	assert_eq(imperial_state.fleet_points, _roster_points(imperial_roster),
		"Player state should carry computed imperial fleet points")
	assert_eq(rebel_ship.roster_entry_id, "rebel-ship-1",
		"Ship instance should preserve roster entry identity")
	assert_eq(rebel_ship.current_speed,
		FleetRosterSetupHelper.DEFAULT_DEPLOYMENT_SPEED,
		"Undeployed ships should use the minimum legal deployment speed")
	assert_eq(imperial_squadron.owner_player, 1,
		"Squadron instance should preserve owning player")


func test_prepare_runtime_duplicate_ship_instances_preserve_identity_expected() -> void:
	var rebel_roster: Dictionary = _rebel_roster()
	var ships: Array = rebel_roster.get("ships", []) as Array
	ships.append(_ship_entry("rebel-ship-2", "cr90_corvette_a", []))
	var package: FleetSetupPackage = _package_from_rosters(
		rebel_roster, _imperial_roster())

	var result: Dictionary = FleetRosterSetupHelper.prepare_runtime(package)
	var runtime_ships: Array = result.get("ships", []) as Array
	var first_ship: ShipInstance = _ship_by_entry(runtime_ships, "rebel-ship-1")
	var second_ship: ShipInstance = _ship_by_entry(runtime_ships, "rebel-ship-2")

	assert_true(result.get("ok", false), "Duplicate ship cards should create instances")
	assert_not_null(first_ship, "First duplicate ship should be present")
	assert_not_null(second_ship, "Second duplicate ship should be present")
	assert_eq(first_ship.data_key, second_ship.data_key,
		"Duplicate ships should retain the same static data key")
	assert_ne(first_ship.roster_entry_id, second_ship.roster_entry_id,
		"Duplicate ships should retain distinct roster identities")


func test_prepare_runtime_materializes_ship_runtime_upgrades_expected() -> void:
	var package: FleetSetupPackage = _package_from_rosters(
		_rebel_roster(), _imperial_roster())

	var result: Dictionary = FleetRosterSetupHelper.prepare_runtime(package)
	var runtime_ships: Array = result.get("ships", []) as Array
	var rebel_ship: ShipInstance = _ship_by_entry(runtime_ships, "rebel-ship-1")
	var runtime_upgrade: Dictionary = rebel_ship.get_runtime_upgrade(
			"0:ship:rebel-ship-1:upgrade:rebel-cmd")
	var card_state: Dictionary = runtime_upgrade.get("card_state", {}) as Dictionary

	assert_true(result.get("ok", false),
			"Runtime setup should accept roster upgrades")
	assert_eq(rebel_ship.runtime_upgrades.size(), 1,
			"Runtime setup should attach one upgrade instance to the source ship")
	assert_eq(runtime_upgrade.get("data_key", ""), "general_dodonna",
			"Runtime upgrade should preserve the static upgrade data key")
	assert_eq(runtime_upgrade.get("owner_player_id", -1), 0,
			"Runtime upgrade should preserve owning player")
	assert_eq(runtime_upgrade.get("source_ship_ref", ""), "0:ship:rebel-ship-1",
			"Runtime upgrade should preserve source ship reference")
	assert_eq(runtime_upgrade.get("source_roster_entry_id", ""), "rebel-ship-1",
			"Runtime upgrade should preserve source roster entry id")
	assert_eq(runtime_upgrade.get("source_assignment_id", ""), "rebel-cmd",
			"Runtime upgrade should preserve source assignment id")
	assert_eq(runtime_upgrade.get("slot", ""), "OFFICER",
			"Runtime upgrade should preserve assignment slot")
	assert_false(card_state.get("exhausted", true),
			"Runtime upgrade should start unexhausted")
	assert_true(card_state.get("readied", false),
			"Runtime upgrade should start readied")
	assert_true((runtime_upgrade.get("trigger_guards", {}) as Dictionary).is_empty(),
			"Runtime upgrade should start with empty trigger guards")
	assert_true((runtime_upgrade.get("rule_state", {}) as Dictionary).is_empty(),
			"Runtime upgrade should start with empty rule state")


func test_prepare_runtime_materializes_each_equipped_ship_upgrade_expected() -> void:
	var rebel_roster: Dictionary = _rebel_roster()
	var ships: Array = rebel_roster.get("ships", []) as Array
	var rebel_ship_entry: Dictionary = ships[0] as Dictionary
	var upgrades: Array = rebel_ship_entry.get("upgrades", []) as Array
	upgrades.append(_upgrade_entry("rebel-support", "engineering_team",
			"SUPPORT_TEAM"))
	var package: FleetSetupPackage = _package_from_rosters(
			rebel_roster, _imperial_roster())

	var result: Dictionary = FleetRosterSetupHelper.prepare_runtime(package)
	var runtime_ships: Array = result.get("ships", []) as Array
	var rebel_ship: ShipInstance = _ship_by_entry(runtime_ships, "rebel-ship-1")
	var commander: Dictionary = rebel_ship.get_runtime_upgrade(
			"0:ship:rebel-ship-1:upgrade:rebel-cmd")
	var support_team: Dictionary = rebel_ship.get_runtime_upgrade(
			"0:ship:rebel-ship-1:upgrade:rebel-support")

	assert_true(result.get("ok", false),
			"Runtime setup should accept multiple roster upgrades")
	assert_eq(rebel_ship.runtime_upgrades.size(), 2,
			"Runtime setup should create one instance per equipped upgrade")
	assert_eq(commander.get("data_key", ""), "general_dodonna",
			"Runtime setup should keep the commander instance")
	assert_eq(support_team.get("data_key", ""), "engineering_team",
			"Runtime setup should materialize the support-team instance")


func test_prepare_runtime_deployment_speed_preserved_expected() -> void:
	var deployments: Array[Dictionary] = [ {
		"owner_player": 0,
		"component_type": "ship",
		"roster_entry_id": "rebel-ship-1",
		"speed": 2,
		"pos_x": 0.5,
		"pos_y": 0.8,
		"rotation_deg": 0.0,
	}]
	var package: FleetSetupPackage = _package_from_rosters(
		_rebel_roster(), _imperial_roster(), deployments)

	var result: Dictionary = FleetRosterSetupHelper.prepare_runtime(package)
	var rebel_ship: ShipInstance = _ship_by_entry(result.get("ships", []) as Array,
		"rebel-ship-1")

	assert_true(result.get("ok", false), "Deployment speed should be accepted")
	assert_eq(rebel_ship.current_speed, 2,
		"Ship instance should preserve setup-package deployment speed")
	assert_almost_eq(rebel_ship.pos_x, 0.5, 0.001,
		"Ship instance should preserve setup-package deployment X position")
	assert_almost_eq(rebel_ship.pos_y, 0.8, 0.001,
		"Ship instance should preserve setup-package deployment Y position")
	assert_almost_eq(rebel_ship.rotation_deg, 0.0, 0.001,
		"Ship instance should preserve setup-package deployment rotation")


func test_prepare_runtime_squadron_deployment_position_preserved_expected() -> void:
	var deployments: Array[Dictionary] = [ {
		"owner_player": 1,
		"component_type": "squadron",
		"roster_entry_id": "imperial-squadron-1",
		"pos_x": 0.35,
		"pos_y": 0.22,
		"rotation_deg": 180.0,
	}]
	var package: FleetSetupPackage = _package_from_rosters(
		_rebel_roster(), _imperial_roster(), deployments)

	var result: Dictionary = FleetRosterSetupHelper.prepare_runtime(package)
	var imperial_squadron: SquadronInstance = _squadron_by_entry(
		result.get("squadrons", []) as Array, "imperial-squadron-1")

	assert_true(result.get("ok", false), "Squadron deployment should be accepted")
	assert_almost_eq(imperial_squadron.pos_x, 0.35, 0.001,
		"Squadron instance should preserve setup-package deployment X position")
	assert_almost_eq(imperial_squadron.pos_y, 0.22, 0.001,
		"Squadron instance should preserve setup-package deployment Y position")
	assert_almost_eq(imperial_squadron.rotation_deg, 180.0, 0.001,
		"Squadron instance should preserve setup-package deployment rotation")


func test_prepare_runtime_ship_deployment_outside_map_rejected_expected() -> void:
	var deployments: Array[Dictionary] = [ {
		"owner_player": 0,
		"component_type": "ship",
		"roster_entry_id": "rebel-ship-1",
		"speed": 2,
		"pos_x": 0.99,
		"pos_y": 0.82,
		"rotation_deg": 0.0,
	}]
	var package: FleetSetupPackage = _package_from_rosters(
			_rebel_roster(), _imperial_roster(), deployments)

	var result: Dictionary = FleetRosterSetupHelper.prepare_runtime(package)
	var validation: SetupValidationResult = result.get("validation") as SetupValidationResult

	assert_false(result.get("ok", false),
			"Ship deployments that spill outside the map should reject conversion")
	assert_true(_has_error(validation, FleetRosterSetupHelper.RULE_DEPLOYMENT_BOUNDS),
			"Out-of-bounds ship deployments should be reported as setup errors")


func test_prepare_runtime_squadron_deployment_outside_map_rejected_expected() -> void:
	var deployments: Array[Dictionary] = [ {
		"owner_player": 1,
		"component_type": "squadron",
		"roster_entry_id": "imperial-squadron-1",
		"pos_x": 0.005,
		"pos_y": 0.24,
		"rotation_deg": 180.0,
	}]
	var package: FleetSetupPackage = _package_from_rosters(
			_rebel_roster(), _imperial_roster(), deployments)

	var result: Dictionary = FleetRosterSetupHelper.prepare_runtime(package)
	var validation: SetupValidationResult = result.get("validation") as SetupValidationResult

	assert_false(result.get("ok", false),
			"Squadron deployments that spill outside the map should reject conversion")
	assert_true(_has_error(validation, FleetRosterSetupHelper.RULE_DEPLOYMENT_BOUNDS),
			"Out-of-bounds squadron deployments should be reported as setup errors")


func test_prepare_runtime_missing_ship_data_rejected_expected() -> void:
	var rebel_roster: Dictionary = _rebel_roster()
	var ships: Array = rebel_roster.get("ships", []) as Array
	ships[0] = _ship_entry("rebel-ship-1", "missing_ship_card", [])
	var package: FleetSetupPackage = _package_from_rosters(
		rebel_roster, _imperial_roster())

	var result: Dictionary = FleetRosterSetupHelper.prepare_runtime(package)
	var validation: SetupValidationResult = result.get("validation") as SetupValidationResult

	assert_false(result.get("ok", false), "Missing ship data should reject conversion")
	assert_true(_has_error(validation, FleetRosterSetupHelper.RULE_SHIP_DATA),
		"Missing ship data should be reported as a setup conversion error")


func test_prepare_runtime_reordered_player_entries_match_expected() -> void:
	var direct: FleetSetupPackage = _package_from_rosters(
		_rebel_roster(), _imperial_roster())
	var reordered: FleetSetupPackage = FleetSetupPackage.deserialize(direct.serialize())
	var reordered_players: Array[Dictionary] = [
		direct.players[1].duplicate(true),
		direct.players[0].duplicate(true),
	]
	reordered.players = reordered_players

	var direct_result: Dictionary = FleetRosterSetupHelper.prepare_runtime(direct)
	var reordered_result: Dictionary = FleetRosterSetupHelper.prepare_runtime(reordered)

	assert_true(direct_result.get("ok", false), "Direct package should convert")
	assert_true(reordered_result.get("ok", false), "Reordered package should convert")
	assert_eq(_runtime_digest(direct_result), _runtime_digest(reordered_result),
		"Player-indexed setup packages should convert identically on both peers")


func test_prepare_runtime_player_state_round_trip_preserves_metadata_expected() -> void:
	var package: FleetSetupPackage = _package_from_rosters(
		_rebel_roster(), _imperial_roster())
	var result: Dictionary = FleetRosterSetupHelper.prepare_runtime(package)
	var player_states: Array = result.get("player_states", []) as Array
	var rebel_state: PlayerState = player_states[0] as PlayerState
	var original_ship: ShipInstance = rebel_state.ships[0] as ShipInstance

	var restored: PlayerState = PlayerState.deserialize(rebel_state.serialize())
	var restored_ship: ShipInstance = restored.ships[0] as ShipInstance
	var restored_squadron: SquadronInstance = restored.squadrons[0] as SquadronInstance

	assert_eq(restored.fleet_points, rebel_state.fleet_points,
		"PlayerState serialization should preserve computed fleet points")
	assert_eq(restored_ship.roster_entry_id, "rebel-ship-1",
		"Ship save/load should preserve roster entry identity")
	assert_eq(restored_ship.fleet_points, original_ship.fleet_points,
		"Ship save/load should preserve fleet points")
	assert_eq(restored_ship.runtime_upgrades.size(), 1,
		"Ship save/load should preserve runtime upgrade instances")
	assert_eq(restored_ship.get_runtime_upgrade(
			"0:ship:rebel-ship-1:upgrade:rebel-cmd").get("data_key", ""),
			"general_dodonna",
			"Ship save/load should preserve runtime upgrade data_key")
	assert_eq(restored_squadron.roster_entry_id, "rebel-squadron-1",
		"Squadron save/load should preserve roster entry identity")


func _package_from_rosters(roster_zero: Dictionary, roster_one: Dictionary,
		deployments: Array[Dictionary] = []) -> FleetSetupPackage:
	return FleetSetupPackage.deserialize({
		"format_version": 1,
		"kind": FleetSetupPackage.KIND,
		"scenario_id": FleetSetupPackageBuilder.DEFAULT_SCENARIO_ID,
		"point_format": {"id": "STANDARD_400", "limit": 400},
		"map": FleetBuilderOptions.map_payload("map_3x6_distant-planet_v4.jpg"),
		"first_player": 0,
		"players": [
			_player_entry(0, "REBEL_ALLIANCE", roster_zero),
			_player_entry(1, "GALACTIC_EMPIRE", roster_one),
		],
		"selected_objective": {},
		"obstacles": [],
		"deployments": deployments,
		"setup_state": {},
	})


func _player_entry(player_index: int, faction: String, roster: Dictionary) -> Dictionary:
	return {
		"player_index": player_index,
		"display_name": _display_name_for_player(player_index),
		"faction": faction,
		"roster": roster,
	}


func _display_name_for_player(player_index: int) -> String:
	if player_index == 0:
		return "Player One"
	return "Player Two"


func _rebel_roster() -> Dictionary:
	var ships: Array[Dictionary] = [_ship_entry("rebel-ship-1", "cr90_corvette_a", [
		_upgrade_entry("rebel-cmd", "general_dodonna", "OFFICER"),
	])]
	var squadrons: Array[Dictionary] = [
		_squadron_entry("rebel-squadron-1", "x_wing_squadron"),
	]
	return _roster("rebel-fleet", "REBEL_ALLIANCE", ships, squadrons)


func _imperial_roster() -> Dictionary:
	var ships: Array[Dictionary] = [_ship_entry(
		"imperial-ship-1", "victory_ii_class_star_destroyer", [
			_upgrade_entry("imperial-cmd", "grand_moff_tarkin", "OFFICER"),
		])]
	var squadrons: Array[Dictionary] = [
		_squadron_entry("imperial-squadron-1", "tie_fighter_squadron"),
	]
	return _roster("imperial-fleet", "GALACTIC_EMPIRE", ships, squadrons)


func _roster(fleet_id: String, faction: String, ships: Array[Dictionary],
		squadrons: Array[Dictionary]) -> Dictionary:
	return {
		"format_version": 1,
		"kind": FleetRoster.KIND,
		"fleet_id": fleet_id,
		"name": fleet_id,
		"faction": faction,
		"point_format": {"id": "STANDARD_400", "limit": 400},
		"map": FleetBuilderOptions.map_payload("map_3x6_distant-planet_v4.jpg"),
		"ships": ships,
		"squadrons": squadrons,
		"objectives": {},
	}


func _ship_entry(entry_id: String, data_key: String,
		upgrades: Array[Dictionary]) -> Dictionary:
	return {"entry_id": entry_id, "data_key": data_key, "upgrades": upgrades}


func _squadron_entry(entry_id: String, data_key: String) -> Dictionary:
	return {"entry_id": entry_id, "data_key": data_key}


func _upgrade_entry(entry_id: String, data_key: String, slot: String) -> Dictionary:
	return {"entry_id": entry_id, "data_key": data_key, "slot": slot}


func _roster_points(roster_data: Dictionary) -> int:
	var roster: FleetRoster = FleetRoster.deserialize(roster_data)
	return int(FleetRosterSummary.calculate(roster).get(FleetRosterSummary.KEY_TOTAL_POINTS, 0))


func _runtime_digest(result: Dictionary) -> String:
	var states: Array = result.get("player_states", []) as Array
	var serialized_states: Array[Dictionary] = []
	for state_variant: Variant in states:
		serialized_states.append((state_variant as PlayerState).serialize())
	return CanonicalJson.stringify({"players": serialized_states})


func _ship_by_entry(ships: Array, roster_entry_id: String) -> ShipInstance:
	for ship_variant: Variant in ships:
		var ship: ShipInstance = ship_variant as ShipInstance
		if ship.roster_entry_id == roster_entry_id:
			return ship
	return null


func _squadron_by_entry(squadrons: Array, roster_entry_id: String) -> SquadronInstance:
	for squadron_variant: Variant in squadrons:
		var squadron: SquadronInstance = squadron_variant as SquadronInstance
		if squadron.roster_entry_id == roster_entry_id:
			return squadron
	return null


func _has_error(validation: SetupValidationResult, rule_id: String) -> bool:
	for issue: Dictionary in validation.errors:
		if str(issue.get("rule_id", "")) == rule_id:
			return true
	return false
