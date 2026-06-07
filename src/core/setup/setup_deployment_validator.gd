## SetupDeploymentValidator
##
## Authoritative validator and setup-state tracker for setup deployment picks.
## It keeps ship/squadron deployment legality and alternating pick state in
## serialized setup state so hot-seat, network, save/load, and replay all
## project the same deployment controller.
class_name SetupDeploymentValidator
extends RefCounted


const COMPONENT_SHIP: String = "ship"
const COMPONENT_SQUADRON: String = "squadron"
const KEY_COMPONENT_TYPE: String = "component_type"
const KEY_ALLOWED_COMPONENT_TYPES: String = "allowed_component_types"
const KEY_DEPLOYMENT_CONTROLLER: String = "deployment_controller"
const KEY_DEPLOYMENT_PICK: String = "deployment_pick"
const KEY_DEPLOYMENTS: String = "deployments"
const KEY_OWNER_PLAYER: String = "owner_player"
const KEY_REMAINING_SHIP_KEYS: String = "remaining_ship_keys"
const KEY_REMAINING_SQUADRON_KEYS: String = "remaining_squadron_keys"
const KEY_ROSTER_ENTRY_IDS: String = "roster_entry_ids"
const KEY_ROSTER_ENTRY_ID: String = "roster_entry_id"
const KEY_SETUP_PACKAGE_HASH: String = "setup_package_hash"
const KEY_SETUP_STATE: String = "setup_state"
const KEY_REQUIRED_COUNT: String = "required_count"
const GAME_SCALE_SCRIPT: GDScript = preload("res://src/autoload/game_scale.gd")
const RANGE_FINDER_SCRIPT: GDScript = preload("res://src/core/geometry/range_finder.gd")


## Validates one setup deployment command against the authoritative setup state.
static func validate_commit(game_state: GameState,
		player_index: int,
		payload: Dictionary) -> String:
	var target: RefCounted = _find_target(game_state, payload)
	var target_error: String = _target_error(game_state, payload, target)
	if target_error != "":
		return target_error
	apply_to_state(game_state)
	var step_error: String = _step_error(game_state, player_index, payload)
	if step_error != "":
		return step_error
	var duplicate_error: String = _duplicate_error(game_state, payload)
	if duplicate_error != "":
		return duplicate_error
	if str(payload.get(KEY_COMPONENT_TYPE, "")) == COMPONENT_SHIP:
		return _ship_error(game_state, payload, target as ShipInstance)
	return _squadron_error(game_state, payload, target as SquadronInstance)


## Returns the remaining legal deployment keys for the active controller.
static func available_pick_keys(game_state: GameState) -> Dictionary:
	apply_to_state(game_state)
	var setup_state: Dictionary = _setup_state(game_state)
	var controller: int = int(setup_state.get(KEY_DEPLOYMENT_CONTROLLER, -1))
	return {
		KEY_REMAINING_SHIP_KEYS: _available_ship_keys_for_controller(setup_state, controller),
		KEY_REMAINING_SQUADRON_KEYS: _available_squadron_keys_for_controller(
				game_state, setup_state, controller),
	}


## Recomputes serialized setup deployment progress from committed state.
static func apply_to_state(game_state: GameState) -> void:
	if game_state == null or not game_state.objectives.has(KEY_SETUP_PACKAGE_HASH):
		return
	var setup_state: Dictionary = _setup_state(game_state)
	var remaining_ships: Array[String] = _remaining_keys(game_state, COMPONENT_SHIP)
	var remaining_squadrons: Array[String] = _remaining_keys(game_state, COMPONENT_SQUADRON)
	setup_state[KEY_REMAINING_SHIP_KEYS] = remaining_ships.duplicate()
	setup_state[KEY_REMAINING_SQUADRON_KEYS] = remaining_squadrons.duplicate()
	var progress: Dictionary = _deployment_progress(game_state,
			remaining_ships, remaining_squadrons)
	setup_state[KEY_DEPLOYMENT_CONTROLLER] = int(progress.get(KEY_DEPLOYMENT_CONTROLLER, -1))
	setup_state[KEY_DEPLOYMENT_PICK] = (progress.get(KEY_DEPLOYMENT_PICK, {}) as Dictionary).duplicate(true)
	setup_state[KEY_ALLOWED_COMPONENT_TYPES] = _string_array(
			progress.get(KEY_ALLOWED_COMPONENT_TYPES, [])).duplicate()
	game_state.objectives[KEY_SETUP_STATE] = setup_state


## Returns a start-round rejection when setup deployment still has missing or
## partial picks, otherwise the empty string.
static func completion_error(game_state: GameState) -> String:
	apply_to_state(game_state)
	var setup_state: Dictionary = _setup_state(game_state)
	if not (setup_state.get(KEY_REMAINING_SHIP_KEYS, []) as Array).is_empty():
		return "Setup requires every ship to be deployed before round one."
	if not (setup_state.get(KEY_REMAINING_SQUADRON_KEYS, []) as Array).is_empty():
		return "Setup requires every squadron to be deployed before round one."
	var pick: Dictionary = setup_state.get(KEY_DEPLOYMENT_PICK, {}) as Dictionary
	if not pick.is_empty():
		return "Setup requires the current squadron deployment pick to finish before round one."
	return ""


static func _target_error(game_state: GameState,
		payload: Dictionary,
		target: RefCounted) -> String:
	if game_state == null:
		return "Game state is required."
	if game_state.current_phase != Constants.GamePhase.SETUP:
		return "Setup deployment is only legal during SETUP."
	if not game_state.objectives.has(KEY_SETUP_PACKAGE_HASH):
		return "No setup-package game is active."
	var component_type: String = str(payload.get(KEY_COMPONENT_TYPE, "")).strip_edges()
	if component_type != COMPONENT_SHIP and component_type != COMPONENT_SQUADRON:
		return "Setup deployment requires component_type ship or squadron."
	if str(payload.get(KEY_ROSTER_ENTRY_ID, "")).strip_edges().is_empty():
		return "Setup deployment requires roster_entry_id."
	if target == null:
		return "Setup deployment target was not found in the live game state."
	return ""


static func _step_error(game_state: GameState,
		player_index: int,
		payload: Dictionary) -> String:
	var setup_state: Dictionary = _setup_state(game_state)
	var controller_player: int = int(setup_state.get(KEY_DEPLOYMENT_CONTROLLER, -1))
	if controller_player != player_index:
		return "Only the active deployment player may place the current setup pick."
	if _placed_count(game_state, COMPONENT_SHIP) + _placed_count(game_state, COMPONENT_SQUADRON) == 0:
		if str(payload.get(KEY_COMPONENT_TYPE, "")) != COMPONENT_SHIP:
			return "The first deployment pick must be a ship."
		return ""
	var component_type: String = str(payload.get(KEY_COMPONENT_TYPE, ""))
	var pick: Dictionary = setup_state.get(KEY_DEPLOYMENT_PICK, {}) as Dictionary
	if not pick.is_empty():
		if component_type != COMPONENT_SQUADRON:
			return "The current squadron deployment pick must finish before another pick begins."
		return _pick_owner_error(setup_state, payload)
	if component_type == COMPONENT_SHIP:
		if _remaining_count_for_player(
				_setup_array(setup_state, KEY_REMAINING_SHIP_KEYS), player_index) <= 0:
			return "The active player has no ships remaining for setup deployment."
		return ""
	if not _can_start_squadron_pick(game_state, setup_state, player_index):
		return "Setup deployment cannot start a squadron pick yet."
	return ""


static func _pick_owner_error(setup_state: Dictionary,
		payload: Dictionary) -> String:
	var pick: Dictionary = setup_state.get(KEY_DEPLOYMENT_PICK, {}) as Dictionary
	if pick.is_empty():
		return ""
	if int(payload.get(KEY_OWNER_PLAYER, -1)) != int(pick.get(KEY_OWNER_PLAYER, -1)):
		return "The current squadron deployment pick must stay with the active player."
	return ""


static func _duplicate_error(game_state: GameState, payload: Dictionary) -> String:
	var key: String = _deployment_key_from_payload(payload)
	if _deployment_key_map(game_state).has(key):
		return "Setup deployment for %s has already been committed." % key
	return ""


static func _ship_error(game_state: GameState,
		payload: Dictionary,
		ship: ShipInstance) -> String:
	if not payload.has("speed"):
		return "Ship deployment requires an explicit speed selection."
	var ship_data: ShipData = _ship_data(ship)
	if ship_data == null:
		return "Setup deployment target ship data could not be loaded."
	var speed: int = int(payload.get("speed", -1))
	if speed < FleetRosterSetupHelper.DEFAULT_DEPLOYMENT_SPEED or speed > ship_data.max_speed:
		return "Setup ship deployment speed is not legal for this ship."
	return _ship_geometry_error(game_state, payload, ship, ship_data)


static func _ship_geometry_error(game_state: GameState,
		payload: Dictionary,
		ship: ShipInstance,
		ship_data: ShipData) -> String:
	var play_area_size: Vector2 = _play_area_size_px(game_state)
	var pixel_pos: Vector2 = _pixel_position(payload, play_area_size)
	var extents: Vector2 = _rotated_ship_extents(ship_data,
			deg_to_rad(float(payload.get("rotation_deg", 0.0))))
	if not _extents_within_play_area(pixel_pos, extents, play_area_size):
		return "Setup ship deployment must stay within the play area."
	return _deployment_zone_error(pixel_pos, extents,
			game_state.get_player_state(ship.owner_player))


static func _deployment_zone_error(pixel_pos: Vector2,
		extents: Vector2,
		player_state: PlayerState) -> String:
	if player_state == null:
		return "Setup deployment player state was not found."
	var top_y: float = DeploymentZoneOverlay.get_top_line_y()
	var bottom_y: float = DeploymentZoneOverlay.get_bottom_line_y()
	match player_state.faction:
		Constants.Faction.GALACTIC_EMPIRE:
			if pixel_pos.y + extents.y > top_y:
				return "Setup ship deployment must stay inside the owning deployment zone."
		Constants.Faction.REBEL_ALLIANCE:
			if pixel_pos.y - extents.y < bottom_y:
				return "Setup ship deployment must stay inside the owning deployment zone."
	return ""


static func _squadron_error(game_state: GameState,
		payload: Dictionary,
		squadron: SquadronInstance) -> String:
	var play_area_size: Vector2 = _play_area_size_px(game_state)
	var pixel_pos: Vector2 = _pixel_position(payload, play_area_size)
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	if not _extents_within_play_area(pixel_pos, Vector2(radius, radius), play_area_size):
		return "Setup squadron deployment must stay within the setup area."
	return _friendly_ship_range_error(game_state, squadron.owner_player, pixel_pos, radius)


static func _friendly_ship_range_error(game_state: GameState,
		owner_player: int,
		squadron_pos: Vector2,
		squadron_radius: float) -> String:
	var min_distance: float = _minimum_friendly_ship_distance(
			game_state, owner_player, squadron_pos, squadron_radius)
	if min_distance == INF:
		return "Setup squadron deployment requires a friendly ship in play."
	var min_band: float = _distance_band_px(1)
	var max_band: float = _distance_band_px(2)
	if min_distance < min_band - 0.01 or min_distance > max_band + 0.01:
		return "Setup squadron deployment must be within distance 1-2 of a friendly ship."
	return ""


static func _minimum_friendly_ship_distance(game_state: GameState,
		owner_player: int,
		squadron_pos: Vector2,
		squadron_radius: float) -> float:
	var player_state: PlayerState = game_state.get_player_state(owner_player)
	if player_state == null:
		return INF
	var deployed_keys: Dictionary = _deployment_key_map(game_state)
	var best: float = INF
	for raw_ship: Variant in player_state.ships:
		if not raw_ship is ShipInstance:
			continue
		var ship: ShipInstance = raw_ship as ShipInstance
		var deployment_key: String = _deployment_key(
				owner_player, COMPONENT_SHIP, ship.roster_entry_id)
		if not deployed_keys.has(deployment_key):
			continue
		best = minf(best, _distance_to_ship(squadron_pos, squadron_radius,
				ship, _play_area_size_px(game_state)))
	return best


static func _distance_to_ship(squadron_pos: Vector2,
		squadron_radius: float,
		ship: ShipInstance,
		play_area_size: Vector2) -> float:
	var ship_data: ShipData = _ship_data(ship)
	if ship_data == null:
		return INF
	var ship_pos: Vector2 = ship.get_pixel_position(play_area_size)
	var base_size: Vector2 = GameScale.get_base_size(ship_data.ship_size)
	var best: float = INF
	for zone: Constants.HullZone in [
		Constants.HullZone.FRONT,
		Constants.HullZone.LEFT,
		Constants.HullZone.RIGHT,
		Constants.HullZone.REAR,
	]:
		var edge: Array[Vector2] = RANGE_FINDER_SCRIPT.get_hull_zone_edge(
				ship_pos,
				ship.get_rotation_rad(),
				base_size.x * 0.5,
				base_size.y * 0.5,
				zone)
		best = minf(best, float(RANGE_FINDER_SCRIPT.measure_range_squad_to_ship(
				squadron_pos, squadron_radius, edge).get("distance", INF)))
	return best


static func _deployment_progress(game_state: GameState,
		remaining_ships: Array[String],
		remaining_squadrons: Array[String]) -> Dictionary:
	var ship_totals: Dictionary = _unit_totals_by_player(game_state, COMPONENT_SHIP, remaining_ships)
	var squadron_totals: Dictionary = _unit_totals_by_player(
			game_state, COMPONENT_SQUADRON, remaining_squadrons)
	var deployed_ships: Dictionary = {0: 0, 1: 0}
	var deployed_squadrons: Dictionary = {0: 0, 1: 0}
	var controller: int = game_state.initiative_player
	var pick: Dictionary = {}
	for deployment: Dictionary in _ordered_all_deployments(game_state):
		controller = _next_available_player_for_counts(
				controller, ship_totals, squadron_totals, deployed_ships, deployed_squadrons)
		if controller < 0:
			return _progress_result(-1, pick, [])
		if not pick.is_empty():
			pick = _consume_partial_squadron_pick(
					deployment, controller, pick, deployed_squadrons)
			if pick.is_empty():
				controller = _next_player_after_pick_for_counts(
						controller,
						ship_totals,
						squadron_totals,
						deployed_ships,
						deployed_squadrons)
			continue
		if str(deployment.get(KEY_COMPONENT_TYPE, "")) == COMPONENT_SHIP:
			deployed_ships[controller] = int(deployed_ships.get(controller, 0)) + 1
			controller = _next_player_after_pick_for_counts(
					controller,
					ship_totals,
					squadron_totals,
					deployed_ships,
					deployed_squadrons)
			continue
		pick = _start_squadron_pick_from_deployment(
				deployment,
				controller,
				ship_totals,
				squadron_totals,
				deployed_ships,
				deployed_squadrons)
	if not pick.is_empty():
		return _progress_result(controller, pick, [COMPONENT_SQUADRON])
	controller = _next_available_player_for_counts(
			controller, ship_totals, squadron_totals, deployed_ships, deployed_squadrons)
	if controller < 0:
		return _progress_result(-1, {}, [])
	return _progress_result(controller, {}, _allowed_component_types_for_player(
				controller,
				ship_totals,
				squadron_totals,
				deployed_ships,
				deployed_squadrons))


static func _progress_result(controller: int,
		pick: Dictionary,
		allowed_component_types: Array[String]) -> Dictionary:
	return {
		KEY_DEPLOYMENT_CONTROLLER: controller,
		KEY_DEPLOYMENT_PICK: pick.duplicate(true),
		KEY_ALLOWED_COMPONENT_TYPES: allowed_component_types.duplicate(),
	}


static func _pick_payload(controller: int,
		roster_entry_ids: Array[String],
		required_count: int) -> Dictionary:
	if required_count <= 1 and roster_entry_ids.is_empty():
		return {}
	return {
		KEY_OWNER_PLAYER: controller,
		KEY_COMPONENT_TYPE: COMPONENT_SQUADRON,
		KEY_ROSTER_ENTRY_IDS: roster_entry_ids.duplicate(),
		KEY_REQUIRED_COUNT: required_count,
	}


static func _consume_partial_squadron_pick(deployment: Dictionary,
		controller: int,
		pick: Dictionary,
		deployed_squadrons: Dictionary) -> Dictionary:
	var roster_ids: Array[String] = (pick.get(KEY_ROSTER_ENTRY_IDS, []) as Array).duplicate()
	roster_ids.append(str(deployment.get(KEY_ROSTER_ENTRY_ID, "")))
	deployed_squadrons[controller] = int(deployed_squadrons.get(controller, 0)) + 1
	if roster_ids.size() >= int(pick.get(KEY_REQUIRED_COUNT, 1)):
		return {}
	return _pick_payload(controller, _string_array(roster_ids), int(pick.get(KEY_REQUIRED_COUNT, 1)))


static func _start_squadron_pick_from_deployment(deployment: Dictionary,
		controller: int,
		ship_totals: Dictionary,
		squadron_totals: Dictionary,
		deployed_ships: Dictionary,
		deployed_squadrons: Dictionary) -> Dictionary:
	var required_count: int = _required_squadron_pick_count_for_counts(
			controller, ship_totals, squadron_totals, deployed_ships, deployed_squadrons)
	deployed_squadrons[controller] = int(deployed_squadrons.get(controller, 0)) + 1
	if required_count <= 1:
		return {}
	return _pick_payload(controller, [str(deployment.get(KEY_ROSTER_ENTRY_ID, ""))], required_count)


static func _next_player_after_pick_for_counts(controller: int,
		ship_totals: Dictionary,
		squadron_totals: Dictionary,
		deployed_ships: Dictionary,
		deployed_squadrons: Dictionary) -> int:
	var other_player: int = _other_player(controller)
	if _has_legal_pick_for_counts(
			other_player, ship_totals, squadron_totals, deployed_ships, deployed_squadrons):
		return other_player
	if _has_legal_pick_for_counts(
			controller, ship_totals, squadron_totals, deployed_ships, deployed_squadrons):
		return controller
	return -1


static func _next_available_player_for_counts(controller: int,
		ship_totals: Dictionary,
		squadron_totals: Dictionary,
		deployed_ships: Dictionary,
		deployed_squadrons: Dictionary) -> int:
	if controller >= 0 and _has_legal_pick_for_counts(
			controller, ship_totals, squadron_totals, deployed_ships, deployed_squadrons):
		return controller
	var other_player: int = _other_player(max(controller, 0))
	if _has_legal_pick_for_counts(
			other_player, ship_totals, squadron_totals, deployed_ships, deployed_squadrons):
		return other_player
	return -1


static func _has_legal_pick_for_counts(player_index: int,
		ship_totals: Dictionary,
		squadron_totals: Dictionary,
		deployed_ships: Dictionary,
		deployed_squadrons: Dictionary) -> bool:
	return not _allowed_component_types_for_player(
			player_index,
			ship_totals,
			squadron_totals,
			deployed_ships,
			deployed_squadrons).is_empty()


static func _unit_totals_by_player(game_state: GameState,
		component_type: String,
		remaining_keys: Array[String]) -> Dictionary:
	return {
		0: _placed_count_for_player(game_state, component_type, 0)
				+ _remaining_count_for_player(remaining_keys, 0),
		1: _placed_count_for_player(game_state, component_type, 1)
				+ _remaining_count_for_player(remaining_keys, 1),
	}


static func _remaining_ship_count_for_counts(player_index: int,
		ship_totals: Dictionary,
		deployed_ships: Dictionary) -> int:
	return int(ship_totals.get(player_index, 0)) - int(deployed_ships.get(player_index, 0))


static func _remaining_squadron_count_for_counts(player_index: int,
		squadron_totals: Dictionary,
		deployed_squadrons: Dictionary) -> int:
	return int(squadron_totals.get(player_index, 0)) - int(deployed_squadrons.get(player_index, 0))


static func _required_squadron_pick_count_for_counts(player_index: int,
		ship_totals: Dictionary,
		squadron_totals: Dictionary,
		deployed_ships: Dictionary,
		deployed_squadrons: Dictionary) -> int:
	var remaining_ships: int = _remaining_ship_count_for_counts(
			player_index, ship_totals, deployed_ships)
	var remaining_squadrons: int = _remaining_squadron_count_for_counts(
			player_index, squadron_totals, deployed_squadrons)
	if remaining_squadrons <= 1:
		if remaining_ships > 0:
			return 2
		return max(remaining_squadrons, 1)
	return 2


static func _allowed_component_types_for_player(player_index: int,
		ship_totals: Dictionary,
		squadron_totals: Dictionary,
		deployed_ships: Dictionary,
		deployed_squadrons: Dictionary) -> Array[String]:
	var allowed_types: Array[String] = []
	if _remaining_ship_count_for_counts(player_index, ship_totals, deployed_ships) > 0:
		allowed_types.append(COMPONENT_SHIP)
	if _can_start_squadron_pick_for_counts(
			_remaining_ship_count_for_counts(player_index, ship_totals, deployed_ships),
			_remaining_squadron_count_for_counts(player_index, squadron_totals, deployed_squadrons),
			int(deployed_ships.get(player_index, 0)),
			_total_deployments_for_counts(deployed_ships, deployed_squadrons) > 0):
		allowed_types.append(COMPONENT_SQUADRON)
	return allowed_types


static func _can_start_squadron_pick_for_counts(remaining_ships: int,
		remaining_squadrons: int,
		placed_ships: int,
		first_pick_done: bool) -> bool:
	if not first_pick_done or placed_ships <= 0 or remaining_squadrons <= 0:
		return false
	if remaining_squadrons == 1 and remaining_ships > 0:
		return false
	return true


static func _total_deployments_for_counts(deployed_ships: Dictionary,
		deployed_squadrons: Dictionary) -> int:
	return int(deployed_ships.get(0, 0)) \
			+ int(deployed_ships.get(1, 0)) \
			+ int(deployed_squadrons.get(0, 0)) \
			+ int(deployed_squadrons.get(1, 0))


static func _ordered_all_deployments(game_state: GameState) -> Array[Dictionary]:
	return _dict_array_from(game_state.objectives.get(KEY_DEPLOYMENTS, []))


static func _available_ship_keys_for_controller(setup_state: Dictionary,
		controller: int) -> Array[String]:
	return _filter_keys_for_player(_setup_array(setup_state, KEY_REMAINING_SHIP_KEYS), controller)


static func _available_squadron_keys_for_controller(game_state: GameState,
		setup_state: Dictionary,
		controller: int) -> Array[String]:
	var pick: Dictionary = setup_state.get(KEY_DEPLOYMENT_PICK, {}) as Dictionary
	if not pick.is_empty():
		return _filter_keys_for_player(
				_setup_array(setup_state, KEY_REMAINING_SQUADRON_KEYS),
				int(pick.get(KEY_OWNER_PLAYER, -1)))
	if not _can_start_squadron_pick(game_state, setup_state, controller):
		return []
	return _filter_keys_for_player(_setup_array(setup_state, KEY_REMAINING_SQUADRON_KEYS), controller)


static func _can_start_squadron_pick(game_state: GameState,
		setup_state: Dictionary,
		player_index: int) -> bool:
	var remaining_ships: int = _remaining_count_for_player(
			_setup_array(setup_state, KEY_REMAINING_SHIP_KEYS), player_index)
	var remaining_squadrons: int = _remaining_count_for_player(
			_setup_array(setup_state, KEY_REMAINING_SQUADRON_KEYS), player_index)
	return _can_start_squadron_pick_for_counts(
			remaining_ships,
			remaining_squadrons,
			_placed_count_for_player(game_state, COMPONENT_SHIP, player_index),
			_placed_count(game_state, COMPONENT_SHIP) + _placed_count(game_state, COMPONENT_SQUADRON) > 0)


static func _setup_array(setup_state: Dictionary, key: String) -> Array[String]:
	var values: Array[String] = []
	var raw_values: Variant = setup_state.get(key, [])
	if not raw_values is Array:
		return values
	for raw_value: Variant in raw_values as Array:
		values.append(str(raw_value))
	return values


static func _filter_keys_for_player(keys: Array[String], player_index: int) -> Array[String]:
	var result: Array[String] = []
	for key: String in keys:
		if int(key.split(":", false, 1)[0]) == player_index:
			result.append(key)
	return result


static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(str(value))
	return result


static func _remaining_count_for_player(keys: Array[String], player_index: int) -> int:
	var count: int = 0
	for key: String in keys:
		if int(key.split(":", false, 1)[0]) == player_index:
			count += 1
	return count


static func _remaining_for_player(player_index: int,
		totals: Dictionary,
		consumed: Dictionary) -> int:
	return int(totals.get(player_index, 0)) - int(consumed.get(player_index, 0))


static func _remaining_keys(game_state: GameState,
		component_type: String) -> Array[String]:
	var missing: Array[String] = []
	var placements: Dictionary = _deployment_key_map(game_state)
	for player_state: PlayerState in game_state.player_states:
		_append_missing_keys(player_state, component_type, placements, missing)
	return missing


static func _append_missing_keys(player_state: PlayerState,
		component_type: String,
		placements: Dictionary,
		missing: Array[String]) -> void:
	var units: Array = player_state.ships if component_type == COMPONENT_SHIP else player_state.squadrons
	for raw_unit: Variant in units:
		var key: String = _unit_deployment_key(raw_unit, component_type)
		if not key.is_empty() and not placements.has(key):
			missing.append(key)


static func _unit_deployment_key(raw_unit: Variant,
		component_type: String) -> String:
	if component_type == COMPONENT_SHIP and raw_unit is ShipInstance:
		var ship: ShipInstance = raw_unit as ShipInstance
		return _deployment_key(ship.owner_player, COMPONENT_SHIP, ship.roster_entry_id)
	if component_type == COMPONENT_SQUADRON and raw_unit is SquadronInstance:
		var squadron: SquadronInstance = raw_unit as SquadronInstance
		return _deployment_key(squadron.owner_player, COMPONENT_SQUADRON,
				squadron.roster_entry_id)
	return ""


static func _deployment_key_map(game_state: GameState) -> Dictionary:
	var placements: Dictionary = {}
	for deployment: Dictionary in _dict_array_from(game_state.objectives.get(KEY_DEPLOYMENTS, [])):
		placements[_deployment_key_from_payload(deployment)] = true
	return placements


static func _deployment_key_from_payload(payload: Dictionary) -> String:
	return _deployment_key(
			int(payload.get(KEY_OWNER_PLAYER, -1)),
			str(payload.get(KEY_COMPONENT_TYPE, "")),
			str(payload.get(KEY_ROSTER_ENTRY_ID, "")))


static func _deployment_key(owner_player: int,
		component_type: String,
		roster_entry_id: String) -> String:
	return "%d:%s:%s" % [owner_player, component_type, roster_entry_id]


static func _ordered_deployments(game_state: GameState,
		component_type: String) -> Array[Dictionary]:
	var deployments: Array[Dictionary] = []
	for deployment: Dictionary in _dict_array_from(game_state.objectives.get(KEY_DEPLOYMENTS, [])):
		if str(deployment.get(KEY_COMPONENT_TYPE, "")) == component_type:
			deployments.append(deployment)
	return deployments


static func _placed_count(game_state: GameState, component_type: String) -> int:
	return _ordered_deployments(game_state, component_type).size()


static func _placed_count_for_player(game_state: GameState,
		component_type: String,
		player_index: int) -> int:
	var count: int = 0
	for deployment: Dictionary in _ordered_deployments(game_state, component_type):
		if int(deployment.get(KEY_OWNER_PLAYER, -1)) == player_index:
			count += 1
	return count


static func _find_target(game_state: GameState, payload: Dictionary) -> RefCounted:
	var player_state: PlayerState = game_state.get_player_state(
			int(payload.get(KEY_OWNER_PLAYER, -1)))
	if player_state == null:
		return null
	if str(payload.get(KEY_COMPONENT_TYPE, "")) == COMPONENT_SHIP:
		return _find_ship(player_state, str(payload.get(KEY_ROSTER_ENTRY_ID, "")))
	return _find_squadron(player_state, str(payload.get(KEY_ROSTER_ENTRY_ID, "")))


static func _find_ship(player_state: PlayerState,
		roster_entry_id: String) -> ShipInstance:
	for raw_ship: Variant in player_state.ships:
		if raw_ship is ShipInstance and (raw_ship as ShipInstance).roster_entry_id == roster_entry_id:
			return raw_ship as ShipInstance
	return null


static func _find_squadron(player_state: PlayerState,
		roster_entry_id: String) -> SquadronInstance:
	for raw_squadron: Variant in player_state.squadrons:
		if raw_squadron is SquadronInstance \
				and (raw_squadron as SquadronInstance).roster_entry_id == roster_entry_id:
			return raw_squadron as SquadronInstance
	return null


static func _ship_data(ship: ShipInstance) -> ShipData:
	if ship == null:
		return null
	if ship.ship_data != null:
		return ship.ship_data
	return AssetLoader.load_ship_data(ship.data_key)


static func _rotated_ship_extents(ship_data: ShipData, rotation_rad: float) -> Vector2:
	var base_size: Vector2 = GameScale.get_base_size(ship_data.ship_size)
	var half_w: float = base_size.x * 0.5
	var half_l: float = base_size.y * 0.5
	return Vector2(
			absf(half_w * cos(rotation_rad)) + absf(half_l * sin(rotation_rad)),
			absf(half_w * sin(rotation_rad)) + absf(half_l * cos(rotation_rad)))


static func _pixel_position(payload: Dictionary, play_area_size: Vector2) -> Vector2:
	return Vector2(
			float(payload.get("pos_x", 0.0)) * play_area_size.x,
			float(payload.get("pos_y", 0.0)) * play_area_size.y)


static func _extents_within_play_area(pixel_pos: Vector2,
		extents: Vector2,
		play_area_size: Vector2) -> bool:
	return pixel_pos.x >= extents.x \
			and pixel_pos.x <= play_area_size.x - extents.x \
			and pixel_pos.y >= extents.y \
			and pixel_pos.y <= play_area_size.y - extents.y


static func _play_area_size_px(game_state: GameState) -> Vector2:
	var map_filename: String = _map_filename(game_state)
	var rulers: Vector2 = GAME_SCALE_SCRIPT.map_play_area_rulers(map_filename)
	if GameScale.ruler_length_px > 0.0:
		return rulers * GameScale.ruler_length_px
	return GameScale.play_area_size_px


static func _map_filename(game_state: GameState) -> String:
	var raw_map: Variant = game_state.objectives.get("map", {})
	if raw_map is Dictionary:
		return str((raw_map as Dictionary).get("filename", ""))
	return ""


static func _distance_band_px(band: int) -> float:
	var index: int = band - 1
	if index < 0 or index >= GameScale.distance_bands_px.size():
		return 0.0
	return GameScale.distance_bands_px[index]


static func _setup_state(game_state: GameState) -> Dictionary:
	var raw_state: Variant = game_state.objectives.get(KEY_SETUP_STATE, {})
	if raw_state is Dictionary:
		return (raw_state as Dictionary).duplicate(true)
	return {}


static func _other_player(player_index: int) -> int:
	return Constants.PLAYER_COUNT - 1 - player_index


static func _dict_array_from(raw_values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_values is Array:
		return result
	for raw_value: Variant in raw_values as Array:
		if raw_value is Dictionary:
			result.append((raw_value as Dictionary).duplicate(true))
	return result