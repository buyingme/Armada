## SetupInteractionFlowResolver
##
## Derives the authoritative setup [InteractionFlow] from serialized
## setup-package state after the board bootstrap has created a live
## [GameState]. This keeps obstacle placement, deployment, and setup
## review authority in domain state so hot-seat, network, save/load,
## and replay all project the same setup controller.
class_name SetupInteractionFlowResolver
extends RefCounted


const KEY_DEPLOYMENTS: String = "deployments"
const KEY_OBSTACLES: String = "obstacles"
const KEY_PLAYER_DISPLAY_NAMES: String = "player_display_names"
const KEY_REMAINING_SHIP_KEYS: String = "remaining_ship_keys"
const KEY_REMAINING_SQUADRON_KEYS: String = "remaining_squadron_keys"
const KEY_SETUP_PACKAGE_HASH: String = "setup_package_hash"
const KEY_SETUP_STATE: String = "setup_state"
const KEY_SETUP_STEP: String = "setup_step"
const KEY_FIRST_PLAYER: String = "first_player"
const KEY_OBSTACLE_COUNT: String = "obstacle_count"
const SETUP_STATUS_COMPLETE: String = "COMPLETE"
const STEP_OBSTACLE_PLACEMENT: String = "obstacle_placement"
const STEP_SETUP_REVIEW: String = "setup_review"
const STEP_SHIP_DEPLOYMENT: String = "ship_deployment"
const STEP_SQUADRON_DEPLOYMENT: String = "squadron_deployment"


## Recomputes [member GameState.interaction_flow] from current setup state.
static func apply_to_state(game_state: GameState) -> void:
	if game_state == null:
		return
	game_state.interaction_flow = build_for_state(game_state)


## Builds the current setup interaction flow from authoritative state.
static func build_for_state(game_state: GameState) -> InteractionFlow:
	if not _has_runtime_setup(game_state) or _setup_complete(game_state):
		return InteractionFlow.empty()
	if _obstacle_count(game_state) < StartRoundCommand.STANDARD_OBSTACLE_COUNT:
		return _obstacle_flow(game_state)
	var remaining_ships: Array[String] = _remaining_ship_keys(game_state)
	if not remaining_ships.is_empty():
		return _ship_flow(game_state, remaining_ships)
	var remaining_squadrons: Array[String] = _remaining_squadron_keys(game_state)
	if not remaining_squadrons.is_empty():
		return _squadron_flow(game_state, remaining_squadrons)
	return _review_flow(game_state)


static func _obstacle_flow(game_state: GameState) -> InteractionFlow:
	var obstacle_count: int = _obstacle_count(game_state)
	var controller_player: int = _obstacle_controller(game_state, obstacle_count)
	var payload: Dictionary = _controller_payload(
			game_state, controller_player, STEP_OBSTACLE_PLACEMENT)
	payload[KEY_OBSTACLE_COUNT] = obstacle_count
	return InteractionFlow.make(
			Constants.InteractionFlow.SETUP,
			Constants.InteractionStep.SETUP_OBSTACLE_PLACEMENT,
			controller_player,
			Constants.Visibility.ALL,
			payload)


static func _ship_flow(game_state: GameState,
		remaining_keys: Array[String]) -> InteractionFlow:
	var controller_player: int = _deployment_controller(game_state)
	var payload: Dictionary = _controller_payload(
			game_state, controller_player, STEP_SHIP_DEPLOYMENT)
	payload[KEY_REMAINING_SHIP_KEYS] = remaining_keys.duplicate()
	return InteractionFlow.make(
			Constants.InteractionFlow.SETUP,
			Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT,
			controller_player,
			Constants.Visibility.ALL,
			payload)


static func _squadron_flow(game_state: GameState,
		remaining_keys: Array[String]) -> InteractionFlow:
	var controller_player: int = _deployment_controller(game_state)
	var payload: Dictionary = _controller_payload(
			game_state, controller_player, STEP_SQUADRON_DEPLOYMENT)
	payload[KEY_REMAINING_SQUADRON_KEYS] = remaining_keys.duplicate()
	return InteractionFlow.make(
			Constants.InteractionFlow.SETUP,
			Constants.InteractionStep.SETUP_SQUADRON_DEPLOYMENT,
			controller_player,
			Constants.Visibility.ALL,
			payload)


static func _review_flow(game_state: GameState) -> InteractionFlow:
	var payload: Dictionary = _base_payload(game_state)
	payload[KEY_SETUP_STEP] = STEP_SETUP_REVIEW
	return InteractionFlow.make(
			Constants.InteractionFlow.SETUP,
			Constants.InteractionStep.SETUP_REVIEW,
			-1,
			Constants.Visibility.ALL,
			payload)


static func _controller_payload(game_state: GameState,
		controller_player: int,
		step_name: String) -> Dictionary:
	var payload: Dictionary = _base_payload(game_state)
	payload["controller_player"] = controller_player
	payload[KEY_SETUP_STEP] = step_name
	return payload


static func _base_payload(game_state: GameState) -> Dictionary:
	return {
		KEY_FIRST_PLAYER: game_state.initiative_player,
		KEY_PLAYER_DISPLAY_NAMES: _player_display_names(game_state),
	}


static func _has_runtime_setup(game_state: GameState) -> bool:
	if game_state == null or game_state.current_phase != Constants.GamePhase.SETUP:
		return false
	return game_state.objectives.has(KEY_SETUP_PACKAGE_HASH)


static func _setup_complete(game_state: GameState) -> bool:
	return str(_setup_state(game_state).get("status", "")) == SETUP_STATUS_COMPLETE


static func _setup_state(game_state: GameState) -> Dictionary:
	var raw_state: Variant = game_state.objectives.get(KEY_SETUP_STATE, {})
	if raw_state is Dictionary:
		return (raw_state as Dictionary).duplicate(true)
	return {}


static func _obstacle_count(game_state: GameState) -> int:
	return _dict_array_from(game_state.objectives.get(KEY_OBSTACLES, [])).size()


static func _obstacle_controller(game_state: GameState, obstacle_count: int) -> int:
	var first_player: int = game_state.initiative_player
	var second_player: int = _other_player(first_player)
	if obstacle_count % 2 == 0:
		return second_player
	return first_player


static func _deployment_controller(game_state: GameState) -> int:
	var placement_count: int = _dict_array_from(
			game_state.objectives.get(KEY_DEPLOYMENTS, [])).size()
	var first_player: int = game_state.initiative_player
	if placement_count % 2 == 0:
		return first_player
	return _other_player(first_player)


static func _player_display_names(game_state: GameState) -> Array[String]:
	var names: Array[String] = []
	var raw_names: Variant = _setup_state(game_state).get(KEY_PLAYER_DISPLAY_NAMES, [])
	if not raw_names is Array:
		return names
	for raw_name: Variant in raw_names as Array:
		names.append(str(raw_name))
	return names


static func _remaining_ship_keys(game_state: GameState) -> Array[String]:
	var missing: Array[String] = []
	var deployments: Dictionary = _deployment_key_map(game_state)
	for player_state: PlayerState in game_state.player_states:
		for raw_ship: Variant in player_state.ships:
			if raw_ship is ShipInstance:
				_append_if_missing(
						missing,
						deployments,
						_deployment_key(
								(raw_ship as ShipInstance).owner_player,
								"ship",
								(raw_ship as ShipInstance).roster_entry_id))
	return missing


static func _remaining_squadron_keys(game_state: GameState) -> Array[String]:
	var missing: Array[String] = []
	var deployments: Dictionary = _deployment_key_map(game_state)
	for player_state: PlayerState in game_state.player_states:
		for raw_squadron: Variant in player_state.squadrons:
			if raw_squadron is SquadronInstance:
				_append_if_missing(
						missing,
						deployments,
						_deployment_key(
								(raw_squadron as SquadronInstance).owner_player,
								"squadron",
								(raw_squadron as SquadronInstance).roster_entry_id))
	return missing


static func _append_if_missing(missing: Array[String],
		deployments: Dictionary,
		deployment_key: String) -> void:
	if deployments.has(deployment_key):
		return
	missing.append(deployment_key)


static func _deployment_key_map(game_state: GameState) -> Dictionary:
	var placements: Dictionary = {}
	for deployment: Dictionary in _dict_array_from(game_state.objectives.get(KEY_DEPLOYMENTS, [])):
		placements[_deployment_key(
				int(deployment.get("owner_player", -1)),
				str(deployment.get("component_type", "")),
				str(deployment.get("roster_entry_id", "")))] = true
	return placements


static func _deployment_key(owner_player: int,
		component_type: String,
		roster_entry_id: String) -> String:
	return "%d:%s:%s" % [owner_player, component_type, roster_entry_id]


static func _dict_array_from(raw_values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_values is Array:
		return result
	for raw_value: Variant in raw_values as Array:
		if raw_value is Dictionary:
			result.append((raw_value as Dictionary).duplicate(true))
	return result


static func _other_player(player_index: int) -> int:
	return Constants.PLAYER_COUNT - 1 - player_index
