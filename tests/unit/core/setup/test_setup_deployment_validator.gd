## Test: SetupDeploymentValidator
##
## Focused unit tests for FB14G setup deployment sequencing and geometry
## validation.
extends GutTest


const COMPONENT_SHIP: String = "ship"
const COMPONENT_SQUADRON: String = "squadron"
const MAP_3X6: String = "map_3x6_distant-planet_v4.jpg"
const SETUP_DEPLOYMENT_VALIDATOR_SCRIPT: GDScript = preload(
		"res://src/core/setup/setup_deployment_validator.gd")

var _state: GameState = null


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SETUP
	_state.current_round = 0
	_state.initiative_player = 1
	_state.objectives = {
		FleetSetupBootstrapper.KEY_SETUP_PACKAGE_HASH: "hash",
		FleetSetupBootstrapper.KEY_SETUP_STATE: {
			"player_display_names": ["Alex", "Blake"],
		},
		FleetSetupBootstrapper.KEY_MAP: {"filename": MAP_3X6},
		FleetSetupBootstrapper.KEY_OBSTACLES: _six_obstacles(),
		FleetSetupBootstrapper.KEY_DEPLOYMENTS: [],
	}


func test_validate_commit_wrong_controller_rejected() -> void:
	_add_ship(1, "ship-1", "victory_ii_class_star_destroyer", 0.48, 0.18)
	SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.apply_to_state(_state)

	var result: String = SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.validate_commit(
			_state, 0, _ship_payload(1, "ship-1", 0.48, 0.12, 180.0, 2))

	assert_ne(result, "",
			"Only the active setup deployment controller should place the next ship.")


func test_validate_commit_ship_outside_own_deployment_zone_rejected() -> void:
	_add_ship(1, "ship-1", "victory_ii_class_star_destroyer", 0.48, 0.18)
	SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.apply_to_state(_state)

	var result: String = SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.validate_commit(
			_state, 1, _ship_payload(1, "ship-1", 0.48, 0.32, 180.0, 2))

	assert_ne(result, "",
			"Ship deployment should reject placements outside the owning deployment zone.")


func test_validate_commit_imperial_host_rebel_client_uses_player_one_top_zone_expected() -> void:
	_state.initiative_player = 1
	_set_player_factions(Constants.Faction.GALACTIC_EMPIRE,
			Constants.Faction.REBEL_ALLIANCE)
	_add_ship(1, "ship-1", "cr90_corvette_a", 0.48, 0.18)
	SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.apply_to_state(_state)

	var legal: String = SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.validate_commit(
			_state, 1, _ship_payload(1, "ship-1", 0.48, 0.12, 180.0, 2))
	var illegal: String = SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.validate_commit(
			_state, 1, _ship_payload(1, "ship-1", 0.48, 0.88, 180.0, 2))

	assert_eq(legal, "",
			"Rebel player 1 should deploy legally in the player 1 top zone.")
	assert_ne(illegal, "",
			"Rebel player 1 should be rejected from the player 0 bottom zone.")


func test_validate_commit_rebel_host_imperial_client_uses_player_zero_bottom_zone_expected() -> void:
	_state.initiative_player = 0
	_set_player_factions(Constants.Faction.REBEL_ALLIANCE,
			Constants.Faction.GALACTIC_EMPIRE)
	_add_ship(0, "ship-1", "cr90_corvette_a", 0.48, 0.82)
	SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.apply_to_state(_state)

	var legal: String = SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.validate_commit(
			_state, 0, _ship_payload(0, "ship-1", 0.48, 0.88, 0.0, 2))
	var illegal: String = SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.validate_commit(
			_state, 0, _ship_payload(0, "ship-1", 0.48, 0.12, 0.0, 2))

	assert_eq(legal, "",
			"Rebel player 0 should deploy legally in the player 0 bottom zone.")
	assert_ne(illegal, "",
			"Rebel player 0 should be rejected from the player 1 top zone.")


func test_validate_commit_imperial_player_zero_still_uses_bottom_zone_expected() -> void:
	_state.initiative_player = 0
	_set_player_factions(Constants.Faction.GALACTIC_EMPIRE,
			Constants.Faction.REBEL_ALLIANCE)
	_add_ship(0, "ship-1", "victory_ii_class_star_destroyer", 0.48, 0.82)
	SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.apply_to_state(_state)

	var legal: String = SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.validate_commit(
			_state, 0, _ship_payload(0, "ship-1", 0.48, 0.88, 0.0, 2))
	var illegal: String = SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.validate_commit(
			_state, 0, _ship_payload(0, "ship-1", 0.48, 0.12, 0.0, 2))

	assert_eq(legal, "",
			"Imperial player 0 should use the player 0 bottom zone.")
	assert_ne(illegal, "",
			"Imperial player 0 should not be allowed to deploy in the player 1 top zone.")


func test_validate_commit_ship_illegal_speed_rejected() -> void:
	_add_ship(1, "ship-1", "victory_ii_class_star_destroyer", 0.48, 0.18)
	SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.apply_to_state(_state)

	var result: String = SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.validate_commit(
			_state, 1, _ship_payload(1, "ship-1", 0.48, 0.12, 180.0, 9))

	assert_ne(result, "",
			"Ship deployment should reject speeds beyond the ship chart.")


func test_validate_commit_squadron_outside_distance_two_rejected() -> void:
	_add_ship(1, "ship-1", "victory_ii_class_star_destroyer", 0.48, 0.18)
	_add_ship(0, "ship-2", "cr90_corvette_a", 0.52, 0.82)
	_add_squadron(1, "sq-1", "tie_fighter_squadron")
	_add_squadron(1, "sq-2", "tie_fighter_squadron")
	_state.objectives[FleetSetupBootstrapper.KEY_DEPLOYMENTS] = [
		_ship_payload(1, "ship-1", 0.48, 0.18, 180.0, 2),
		_ship_payload(0, "ship-2", 0.52, 0.82, 0.0, 2),
	]
	SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.apply_to_state(_state)

	var result: String = SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.validate_commit(
			_state, 1, _squadron_payload(1, "sq-1", 0.48, 0.5))

	assert_ne(result, "",
			"Squadron deployment should reject positions beyond distance 2 of a friendly ship.")


func test_available_pick_keys_after_first_ship_each_player_include_ship_and_squadrons_expected() -> void:
	_add_ship(0, "ship-1", "cr90_corvette_a", 0.52, 0.82)
	_add_ship(0, "ship-2", "cr90_corvette_a", 0.62, 0.82)
	_add_ship(1, "ship-3", "victory_ii_class_star_destroyer", 0.48, 0.18)
	_add_squadron(0, "sq-1", "x_wing_squadron")
	_add_squadron(0, "sq-2", "x_wing_squadron")
	_state.objectives[FleetSetupBootstrapper.KEY_DEPLOYMENTS] = [
		_ship_payload(0, "ship-1", 0.52, 0.82, 0.0, 2),
		_ship_payload(1, "ship-3", 0.48, 0.18, 180.0, 2),
	]

	var available: Dictionary = SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.available_pick_keys(_state)

	assert_true((available.get("remaining_ship_keys", []) as Array).has("0:ship:ship-2"),
			"After each player deploys one ship, the controller should still be able to deploy a remaining ship.")
	assert_true((available.get("remaining_squadron_keys", []) as Array).has("0:squadron:sq-1"),
			"After each player deploys one ship, the controller should also be able to start an eligible squadron pick.")


func test_validate_commit_squadron_after_each_player_first_ship_expected() -> void:
	_add_ship(0, "ship-1", "cr90_corvette_a", 0.52, 0.82)
	_add_ship(0, "ship-2", "cr90_corvette_a", 0.62, 0.82)
	_add_ship(1, "ship-3", "victory_ii_class_star_destroyer", 0.48, 0.18)
	_add_squadron(0, "sq-1", "x_wing_squadron")
	_add_squadron(0, "sq-2", "x_wing_squadron")
	_state.objectives[FleetSetupBootstrapper.KEY_DEPLOYMENTS] = [
		_ship_payload(0, "ship-1", 0.52, 0.82, 0.0, 2),
		_ship_payload(1, "ship-3", 0.48, 0.18, 180.0, 2),
	]

	var result: String = SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.validate_commit(
			_state, 0, _squadron_payload(0, "sq-1", 0.44, 0.76))

	assert_eq(result, "",
			"After each player deploys one ship, the active player should be allowed to start a legal squadron pick even if ships remain.")


func test_apply_to_state_first_squadron_pick_tracks_partial_batch_expected() -> void:
	_add_ship(1, "ship-1", "victory_ii_class_star_destroyer", 0.48, 0.18)
	_add_ship(0, "ship-2", "cr90_corvette_a", 0.52, 0.82)
	_add_squadron(1, "sq-1", "tie_fighter_squadron")
	_add_squadron(1, "sq-2", "tie_fighter_squadron")
	_state.objectives[FleetSetupBootstrapper.KEY_DEPLOYMENTS] = [
		_ship_payload(1, "ship-1", 0.48, 0.18, 180.0, 2),
		_ship_payload(0, "ship-2", 0.52, 0.82, 0.0, 2),
		_squadron_payload(1, "sq-1", 0.48, 0.30),
	]
	SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.apply_to_state(_state)
	var setup_state: Dictionary = _state.objectives[FleetSetupBootstrapper.KEY_SETUP_STATE]
	var pick: Dictionary = setup_state.get("deployment_pick", {})

	assert_eq(int(setup_state.get("deployment_controller", -1)), 1,
			"The same player should retain control during a two-squadron pick.")
	assert_eq(int(pick.get("required_count", 0)), 2,
			"Serialized setup state should preserve the required two-squadron batch size.")
	assert_eq((pick.get("roster_entry_ids", []) as Array).size(), 1,
			"Serialized setup state should list the already committed squadron in the current pick.")


func test_completion_error_partial_squadron_pick_rejected() -> void:
	_add_ship(1, "ship-1", "victory_ii_class_star_destroyer", 0.48, 0.18)
	_add_ship(0, "ship-2", "cr90_corvette_a", 0.52, 0.82)
	_add_squadron(1, "sq-1", "tie_fighter_squadron")
	_add_squadron(1, "sq-2", "tie_fighter_squadron")
	_state.objectives[FleetSetupBootstrapper.KEY_DEPLOYMENTS] = [
		_ship_payload(1, "ship-1", 0.48, 0.18, 180.0, 2),
		_ship_payload(0, "ship-2", 0.52, 0.82, 0.0, 2),
		_squadron_payload(1, "sq-1", 0.48, 0.30),
	]

	var result: String = SETUP_DEPLOYMENT_VALIDATOR_SCRIPT.completion_error(_state)

	assert_ne(result, "",
			"Setup completion should reject a partial two-squadron pick.")


func _add_ship(owner_player: int,
		roster_entry_id: String,
		data_key: String,
		pos_x: float,
		pos_y: float) -> void:
	var ship: ShipInstance = ShipInstance.new()
	ship.owner_player = owner_player
	ship.roster_entry_id = roster_entry_id
	ship.data_key = data_key
	ship.ship_data = AssetLoader.load_ship_data(data_key)
	ship.pos_x = pos_x
	ship.pos_y = pos_y
	_state.get_player_state(owner_player).ships.append(ship)


func _add_squadron(owner_player: int,
		roster_entry_id: String,
		data_key: String) -> void:
	var squadron: SquadronInstance = SquadronInstance.new()
	squadron.owner_player = owner_player
	squadron.roster_entry_id = roster_entry_id
	squadron.data_key = data_key
	squadron.squadron_data = AssetLoader.load_squadron_data(data_key)
	_state.get_player_state(owner_player).squadrons.append(squadron)


func _set_player_factions(player_zero: Constants.Faction,
		player_one: Constants.Faction) -> void:
	_state.get_player_state(0).faction = player_zero
	_state.get_player_state(1).faction = player_one


func _ship_payload(owner_player: int,
		roster_entry_id: String,
		pos_x: float,
		pos_y: float,
		rotation_deg: float,
		speed: int) -> Dictionary:
	return {
		"owner_player": owner_player,
		"component_type": COMPONENT_SHIP,
		"roster_entry_id": roster_entry_id,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"rotation_deg": rotation_deg,
		"speed": speed,
	}


func _squadron_payload(owner_player: int,
		roster_entry_id: String,
		pos_x: float,
		pos_y: float) -> Dictionary:
	return {
		"owner_player": owner_player,
		"component_type": COMPONENT_SQUADRON,
		"roster_entry_id": roster_entry_id,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"rotation_deg": 0.0,
	}


func _six_obstacles() -> Array[Dictionary]:
	return [
		_obstacle("asteroid_1", 0.14, 0.5, 1, 0),
		_obstacle("asteroid_2", 0.30, 0.66, 0, 1),
		_obstacle("asteroid_3", 0.48, 0.34, 1, 2),
		_obstacle("debris_1", 0.66, 0.66, 0, 3),
		_obstacle("debris_2", 0.84, 0.5, 1, 4),
		_obstacle("station", 0.5, 0.82, 0, 5),
	]


func _obstacle(data_key: String,
		pos_x: float,
		pos_y: float,
		placing_player: int,
		placement_order: int) -> Dictionary:
	return {
		"data_key": data_key,
		"pos_x": pos_x,
		"pos_y": pos_y,
		"rotation_deg": 0.0,
		"placing_player": placing_player,
		"placement_order": placement_order,
	}
