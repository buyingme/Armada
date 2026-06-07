## StartRoundCommand
##
## Starts a new round by incrementing [member GameState.current_round]
## and resetting [member GameState.current_phase] to COMMAND.
##
## This is the only command that transitions from STATUS to COMMAND.
## The presentation layer is responsible for emitting EventBus signals
## and setting up the dial-assignment flow after the command executes.
##
## Payload:  (none required)
##
## Rules Reference: "Game Round", GF-002, GF-003 — six rounds,
## strict phase order; "Command Phase", p.3.
class_name StartRoundCommand
extends GameCommand


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")

const KEY_SETUP_PACKAGE_HASH: String = "setup_package_hash"
const KEY_SETUP_STATE: String = "setup_state"
const KEY_DEPLOYMENTS: String = "deployments"
const KEY_OBSTACLES: String = "obstacles"
const SETUP_STATUS_COMPLETE: String = "COMPLETE"
const STANDARD_OBSTACLE_COUNT: int = 6


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("start_round", func(player: int,
			pl: Dictionary) -> GameCommand:
		return StartRoundCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "start_round", p_payload)


## Validates that starting a new round is legal.
## Must be in SETUP (initial game start) or STATUS phase, and the next
## round must not exceed MAX_ROUNDS.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.STATUS and phase != Constants.GamePhase.SETUP:
		return "Can only start a new round from STATUS or SETUP phase."
	var setup_error: String = _setup_package_error(game_state, phase)
	if setup_error != "":
		return setup_error
	if game_state.current_round >= Constants.MAX_ROUNDS:
		return "Already at maximum rounds (%d)." % Constants.MAX_ROUNDS
	return ""


## Increments round counter and resets phase to COMMAND.
## Returns {"new_round": int, "new_phase": int}.
func execute(game_state: GameState) -> Dictionary:
	_mark_setup_complete_if_needed(game_state)
	game_state.current_round += 1
	game_state.current_phase = Constants.GamePhase.COMMAND
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.COMMAND_PHASE,
			Constants.InteractionStep.SELECT_DIALS,
			game_state,
			{"controller_player": game_state.initiative_player})
	return {
		"new_round": game_state.current_round,
		"new_phase": int(Constants.GamePhase.COMMAND),
	}


static func _setup_package_error(game_state: GameState,
		phase: Constants.GamePhase) -> String:
	if phase != Constants.GamePhase.SETUP:
		return ""
	if not _has_setup_package(game_state):
		return ""
	var setup_state: Dictionary = _setup_state(game_state)
	if str(setup_state.get("status", "")) == SETUP_STATUS_COMPLETE:
		return ""
	var obstacle_error: String = _obstacle_error(game_state)
	if obstacle_error != "":
		return obstacle_error
	return _deployment_error(game_state)


func _mark_setup_complete_if_needed(game_state: GameState) -> void:
	if game_state.current_phase != Constants.GamePhase.SETUP:
		return
	if not _has_setup_package(game_state):
		return
	var setup_state: Dictionary = _setup_state(game_state).duplicate(true)
	setup_state["status"] = SETUP_STATUS_COMPLETE
	setup_state["completed_by_player"] = player_index
	game_state.objectives[KEY_SETUP_STATE] = setup_state


static func _has_setup_package(game_state: GameState) -> bool:
	return game_state.objectives.has(KEY_SETUP_PACKAGE_HASH)


static func _obstacle_error(game_state: GameState) -> String:
	var obstacles: Array[Dictionary] = _dict_array_from(
			game_state.objectives.get(KEY_OBSTACLES, []))
	if obstacles.size() < STANDARD_OBSTACLE_COUNT:
		return "Setup requires six obstacle placements before round one."
	return ""


static func _deployment_error(game_state: GameState) -> String:
	var placements: Dictionary = _deployment_key_map(game_state)
	for missing_key: String in _missing_deployment_keys(game_state, placements):
		return "Setup deployment is missing for %s." % missing_key
	return ""


static func _deployment_key_map(game_state: GameState) -> Dictionary:
	var placements: Dictionary = {}
	var raw_deployments: Variant = game_state.objectives.get(KEY_DEPLOYMENTS, [])
	for deployment: Dictionary in _dict_array_from(raw_deployments):
		placements[_deployment_key_from_payload(deployment)] = true
	return placements


static func _missing_deployment_keys(game_state: GameState,
		placements: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	for player_state: PlayerState in game_state.player_states:
		_append_missing_ships(player_state, placements, missing)
		_append_missing_squadrons(player_state, placements, missing)
	return missing


static func _append_missing_ships(player_state: PlayerState,
		placements: Dictionary, missing: Array[String]) -> void:
	for raw_ship: Variant in player_state.ships:
		if not raw_ship is ShipInstance:
			continue
		var ship: ShipInstance = raw_ship as ShipInstance
		var key: String = _deployment_key(
				ship.owner_player, "ship", ship.roster_entry_id)
		if not placements.has(key):
			missing.append(key)


static func _append_missing_squadrons(player_state: PlayerState,
		placements: Dictionary, missing: Array[String]) -> void:
	for raw_squadron: Variant in player_state.squadrons:
		if not raw_squadron is SquadronInstance:
			continue
		var squadron: SquadronInstance = raw_squadron as SquadronInstance
		var key: String = _deployment_key(
				squadron.owner_player, "squadron", squadron.roster_entry_id)
		if not placements.has(key):
			missing.append(key)


static func _deployment_key_from_payload(deployment: Dictionary) -> String:
	return _deployment_key(
			int(deployment.get("owner_player", -1)),
			str(deployment.get("component_type", "")),
			str(deployment.get("roster_entry_id", "")))


static func _deployment_key(owner_player: int,
		component_type: String, roster_entry_id: String) -> String:
	return "%d:%s:%s" % [owner_player, component_type, roster_entry_id]


static func _setup_state(game_state: GameState) -> Dictionary:
	var raw_state: Variant = game_state.objectives.get(
			KEY_SETUP_STATE, {})
	if raw_state is Dictionary:
		return raw_state as Dictionary
	return {}


static func _dict_array_from(raw_values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_values is Array:
		return result
	for raw_value: Variant in raw_values as Array:
		if raw_value is Dictionary:
			result.append((raw_value as Dictionary).duplicate(true))
	return result
