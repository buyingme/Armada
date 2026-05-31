## Test: FleetSetupBootstrapper
##
## Unit tests for FB13 setup-package to GameState bootstrap.
extends GutTest


func test_build_game_state_valid_package_expected() -> void:
	var package: FleetSetupPackage = _package_with_deployments()

	var result: Dictionary = FleetSetupBootstrapper.build_game_state(
			package, {"rng_seed": 12345})
	var state: GameState = result.get("state") as GameState
	var rebel_ship: ShipInstance = state.get_ship(0, 0)
	var imperial_squadron: SquadronInstance = state.get_squadron(1, 0)

	assert_true(result.get("ok", false), "Valid setup package should bootstrap")
	assert_eq(state.current_round, 0, "Bootstrapper should not start the round")
	assert_eq(state.current_phase, Constants.GamePhase.SETUP,
		"Bootstrapper should leave phase at SETUP for GameManager")
	assert_eq(state.initiative_player, 1,
		"Initiative should come from package.first_player")
	assert_eq(state.damage_deck.get_draw_count(), DamageDeck.DECK_SIZE,
		"Bootstrapper should create a full shared damage deck")
	assert_eq(state.objectives.get(FleetSetupBootstrapper.KEY_SETUP_PACKAGE_HASH, ""),
		package.canonical_hash(), "GameState should store the setup package hash")
	assert_eq((state.objectives.get(FleetSetupBootstrapper.KEY_MAP, {}) as Dictionary).get(
		"filename", ""), "map_3x6_distant-planet_v4.jpg",
		"GameState should store the setup package map")
	assert_eq(rebel_ship.roster_entry_id, "rebel-ship-1",
		"Runtime ship should preserve roster identity")
	assert_almost_eq(rebel_ship.pos_x, 0.52, 0.001,
		"Runtime ship should use deployment X position")
	assert_almost_eq(imperial_squadron.pos_y, 0.24, 0.001,
		"Runtime squadron should use deployment Y position")


func test_build_game_state_same_package_and_seed_hash_expected() -> void:
	var package: FleetSetupPackage = _package_with_deployments()

	var first: Dictionary = FleetSetupBootstrapper.build_game_state(
			package, {"rng_seed": 6789})
	var second: Dictionary = FleetSetupBootstrapper.build_game_state(
			FleetSetupPackage.deserialize(package.serialize()), {"rng_seed": 6789})
	var first_state: GameState = first.get("state") as GameState
	var second_state: GameState = second.get("state") as GameState

	assert_true(first.get("ok", false), "First package bootstrap should pass")
	assert_true(second.get("ok", false), "Second package bootstrap should pass")
	assert_eq(CanonicalJson.hash(first_state.serialize()),
		CanonicalJson.hash(second_state.serialize()),
		"Same package and seed should produce identical state hashes")


func test_build_game_state_missing_ship_data_rejected_expected() -> void:
	var package: FleetSetupPackage = _package_from_rosters(
		_broken_rebel_roster(), _imperial_roster(), [])

	var result: Dictionary = FleetSetupBootstrapper.build_game_state(package)
	var validation: SetupValidationResult = result.get("validation") as SetupValidationResult

	assert_false(result.get("ok", false), "Missing ship data should reject bootstrap")
	assert_null(result.get("state"), "Rejected bootstrap should not return a state")
	assert_true(_has_error(validation, FleetRosterSetupHelper.RULE_SHIP_DATA),
		"Missing ship data should be reported by setup validation")


func _package_with_deployments() -> FleetSetupPackage:
	return _package_from_rosters(
		_rebel_roster(), _imperial_roster(), _deployments())


func _package_from_rosters(roster_zero: Dictionary, roster_one: Dictionary,
		deployments: Array[Dictionary]) -> FleetSetupPackage:
	return FleetSetupPackage.deserialize({
		"format_version": 1,
		"kind": FleetSetupPackage.KIND,
		"scenario_id": FleetSetupPackageBuilder.DEFAULT_SCENARIO_ID,
		"point_format": {"id": "STANDARD_400", "limit": 400},
		"map": FleetBuilderOptions.map_payload("map_3x6_distant-planet_v4.jpg"),
		"first_player": 1,
		"players": [
			_player_entry(0, "REBEL_ALLIANCE", roster_zero),
			_player_entry(1, "GALACTIC_EMPIRE", roster_one),
		],
		"selected_objective": _selected_objective(),
		"obstacles": [{"data_key": "asteroid_field", "pos_x": 0.2}],
		"deployments": deployments,
		"setup_state": {"objective_key": "obj_ass_opening_salvo"},
	})


func _deployments() -> Array[Dictionary]:
	var deployments: Array[Dictionary] = []
	deployments.append(_deployment(0, "ship", "rebel-ship-1", 0.52, 0.82, 0.0))
	deployments.append(_deployment(1, "ship", "imperial-ship-1", 0.48, 0.18, 180.0))
	deployments.append(_deployment(0, "squadron", "rebel-squadron-1", 0.45, 0.77, 0.0))
	deployments.append(_deployment(1, "squadron", "imperial-squadron-1", 0.55, 0.24, 180.0))
	return deployments


func _deployment(owner_player: int, component_type: String,
		entry_id: String, pos_x: float, pos_y: float,
		rotation_deg: float) -> Dictionary:
	return {
		"owner_player": owner_player,
		"component_type": component_type,
		"roster_entry_id": entry_id,
		"speed": 2,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"rotation_deg": rotation_deg,
	}


func _selected_objective() -> Dictionary:
	return {
		"data_key": "obj_ass_opening_salvo",
		"owner_player": 0,
		"chosen_by_player": 1,
	}


func _player_entry(player_index: int, faction: String, roster: Dictionary) -> Dictionary:
	return {"player_index": player_index, "faction": faction, "roster": roster}


func _rebel_roster() -> Dictionary:
	var ships: Array[Dictionary] = [_ship_entry("rebel-ship-1", "cr90_corvette_a")]
	var squadrons: Array[Dictionary] = [
		_squadron_entry("rebel-squadron-1", "x_wing_squadron"),
	]
	return _roster("rebel-fleet", "REBEL_ALLIANCE", ships, squadrons)


func _broken_rebel_roster() -> Dictionary:
	var ships: Array[Dictionary] = [_ship_entry("rebel-ship-1", "missing_ship")]
	var squadrons: Array[Dictionary] = [
		_squadron_entry("rebel-squadron-1", "x_wing_squadron"),
	]
	return _roster("rebel-fleet", "REBEL_ALLIANCE", ships, squadrons)


func _imperial_roster() -> Dictionary:
	var ships: Array[Dictionary] = [_ship_entry(
		"imperial-ship-1", "victory_ii_class_star_destroyer")]
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


func _ship_entry(entry_id: String, data_key: String) -> Dictionary:
	return {"entry_id": entry_id, "data_key": data_key, "upgrades": []}


func _squadron_entry(entry_id: String, data_key: String) -> Dictionary:
	return {"entry_id": entry_id, "data_key": data_key}


func _has_error(validation: SetupValidationResult, rule_id: String) -> bool:
	for issue: Dictionary in validation.errors:
		if str(issue.get("rule_id", "")) == rule_id:
			return true
	return false