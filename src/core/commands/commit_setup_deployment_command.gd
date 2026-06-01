## CommitSetupDeploymentCommand
##
## Records one normalized ship or squadron deployment placement during the
## setup phase. The command keeps the runtime instance position in sync with
## the authoritative deployment payload stored in [member GameState.objectives].
##
## Payload keys: [code]owner_player[/code] (int), [code]component_type[/code]
## ("ship" or "squadron"), [code]roster_entry_id[/code] (String),
## [code]pos_x[/code] (float), [code]pos_y[/code] (float),
## [code]rotation_deg[/code] (float), optional [code]speed[/code] (int).
##
## Rules Reference: "Setup", step 6, RRG 1.5.0 — ships and squadrons are
## deployed before round one begins.
class_name CommitSetupDeploymentCommand
extends GameCommand


const COMPONENT_SHIP: String = "ship"
const COMPONENT_SQUADRON: String = "squadron"
const KEY_DEPLOYMENTS: String = "deployments"
const KEY_SETUP_PACKAGE_HASH: String = "setup_package_hash"


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("commit_setup_deployment", func(player: int,
			pl: Dictionary) -> GameCommand:
		return CommitSetupDeploymentCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "commit_setup_deployment", p_payload)


## Validates the setup deployment payload and target.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SETUP:
		return "Setup deployment is only legal during SETUP."
	if not game_state.objectives.has(KEY_SETUP_PACKAGE_HASH):
		return "No setup-package game is active."
	var target_error: String = _validate_target(game_state)
	if target_error != "":
		return target_error
	return _validate_normalized_position(payload)


## Applies the deployment to runtime state and the setup deployment payload.
func execute(game_state: GameState) -> Dictionary:
	var deployments: Array[Dictionary] = _dict_array_from(
			game_state.objectives.get(KEY_DEPLOYMENTS, []))
	var deployment: Dictionary = _payload_deployment(game_state)
	_apply_runtime_deployment(game_state, deployment)
	_upsert_deployment(deployments, deployment)
	game_state.objectives[KEY_DEPLOYMENTS] = deployments
	return {"deployment": deployment.duplicate(true)}


func _validate_target(game_state: GameState) -> String:
	var component_type: String = str(payload.get("component_type", "")).strip_edges()
	if component_type != COMPONENT_SHIP and component_type != COMPONENT_SQUADRON:
		return "Setup deployment requires component_type ship or squadron."
	if str(payload.get("roster_entry_id", "")).strip_edges().is_empty():
		return "Setup deployment requires roster_entry_id."
	if _find_target(game_state) == null:
		return "Setup deployment target was not found in the live game state."
	return ""


static func _validate_normalized_position(values: Dictionary) -> String:
	var pos_x: float = float(values.get("pos_x", -1.0))
	var pos_y: float = float(values.get("pos_y", -1.0))
	if pos_x < 0.0 or pos_x > 1.0 or pos_y < 0.0 or pos_y > 1.0:
		return "Setup deployment must stay within the play area."
	return ""


func _payload_deployment(game_state: GameState) -> Dictionary:
	var target: RefCounted = _find_target(game_state)
	var deployment: Dictionary = {
		"owner_player": int(payload.get("owner_player", -1)),
		"component_type": str(payload.get("component_type", "")).strip_edges(),
		"roster_entry_id": str(payload.get("roster_entry_id", "")).strip_edges(),
		"pos_x": float(payload.get("pos_x", 0.0)),
		"pos_y": float(payload.get("pos_y", 0.0)),
		"rotation_deg": float(payload.get("rotation_deg", 0.0)),
	}
	if target is ShipInstance:
		deployment["speed"] = _deployment_speed(target as ShipInstance)
	return deployment


func _find_target(game_state: GameState) -> RefCounted:
	var player_state: PlayerState = game_state.get_player_state(
			int(payload.get("owner_player", -1)))
	if player_state == null:
		return null
	if str(payload.get("component_type", "")) == COMPONENT_SHIP:
		return _find_ship(player_state)
	return _find_squadron(player_state)


func _find_ship(player_state: PlayerState) -> ShipInstance:
	for raw_ship: Variant in player_state.ships:
		if raw_ship is ShipInstance \
				and (raw_ship as ShipInstance).roster_entry_id == payload.get("roster_entry_id", ""):
			return raw_ship as ShipInstance
	return null


func _find_squadron(player_state: PlayerState) -> SquadronInstance:
	for raw_squadron: Variant in player_state.squadrons:
		if raw_squadron is SquadronInstance \
				and (raw_squadron as SquadronInstance).roster_entry_id == payload.get("roster_entry_id", ""):
			return raw_squadron as SquadronInstance
	return null


func _deployment_speed(ship: ShipInstance) -> int:
	if payload.has("speed"):
		return int(payload.get("speed", ship.current_speed))
	return ship.current_speed


func _apply_runtime_deployment(game_state: GameState, deployment: Dictionary) -> void:
	var target: RefCounted = _find_target(game_state)
	if target == null:
		return
	_apply_runtime_position(target, deployment)
	if target is ShipInstance and deployment.has("speed"):
		(target as ShipInstance).current_speed = int(deployment.get("speed", 0))


static func _apply_runtime_position(target: RefCounted, deployment: Dictionary) -> void:
	if target is ShipInstance:
		var ship: ShipInstance = target as ShipInstance
		ship.pos_x = float(deployment.get("pos_x", ship.pos_x))
		ship.pos_y = float(deployment.get("pos_y", ship.pos_y))
		ship.rotation_deg = float(deployment.get("rotation_deg", ship.rotation_deg))
		return
	if target is SquadronInstance:
		var squadron: SquadronInstance = target as SquadronInstance
		squadron.pos_x = float(deployment.get("pos_x", squadron.pos_x))
		squadron.pos_y = float(deployment.get("pos_y", squadron.pos_y))
		squadron.rotation_deg = float(deployment.get("rotation_deg", squadron.rotation_deg))


static func _upsert_deployment(deployments: Array[Dictionary], deployment: Dictionary) -> void:
	for index: int in range(deployments.size()):
		if _deployment_key(deployments[index]) == _deployment_key(deployment):
			deployments[index] = deployment.duplicate(true)
			return
	deployments.append(deployment.duplicate(true))


static func _deployment_key(deployment: Dictionary) -> String:
	return "%d:%s:%s" % [
		int(deployment.get("owner_player", -1)),
		str(deployment.get("component_type", "")),
		str(deployment.get("roster_entry_id", "")),
	]


static func _dict_array_from(raw_values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_values is Array:
		return result
	for raw_value: Variant in raw_values as Array:
		if raw_value is Dictionary:
			result.append((raw_value as Dictionary).duplicate(true))
	return result
