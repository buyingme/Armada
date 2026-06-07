## CommitSetupObstacleCommand
##
## Records one normalized obstacle placement during the setup phase.
## The command updates [member GameState.objectives] so hot-seat,
## network mirrors, save/load, and round-one setup validation read the
## same authoritative obstacle payload.
##
## Payload keys: [code]data_key[/code] (String), [code]pos_x[/code]
## (float), [code]pos_y[/code] (float), [code]rotation_deg[/code] (float).
##
## Rules Reference: "Setup", step 5, RRG 1.5.0 — players place
## obstacle tokens before deployment.
class_name CommitSetupObstacleCommand
extends GameCommand


const KEY_SETUP_PACKAGE_HASH: String = "setup_package_hash"
const KEY_OBSTACLES: String = "obstacles"


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("commit_setup_obstacle", func(player: int,
			pl: Dictionary) -> GameCommand:
		return CommitSetupObstacleCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "commit_setup_obstacle", p_payload)


## Validates the setup obstacle placement payload.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SETUP:
		return "Setup obstacle placement is only legal during SETUP."
	if not game_state.objectives.has(KEY_SETUP_PACKAGE_HASH):
		return "No setup-package game is active."
	if str(payload.get("data_key", "")).strip_edges().is_empty():
		return "Setup obstacle placement requires data_key."
	return _validate_normalized_position(payload)


## Applies the placement to the authoritative setup obstacle payload.
func execute(game_state: GameState) -> Dictionary:
	var obstacles: Array[Dictionary] = _dict_array_from(
			game_state.objectives.get(KEY_OBSTACLES, []))
	var obstacle: Dictionary = _payload_obstacle()
	_upsert_obstacle(obstacles, obstacle)
	game_state.objectives[KEY_OBSTACLES] = obstacles
	SetupInteractionFlowResolver.apply_to_state(game_state)
	return {
		"obstacle": obstacle.duplicate(true),
		"obstacle_count": obstacles.size(),
	}


static func _validate_normalized_position(values: Dictionary) -> String:
	var pos_x: float = float(values.get("pos_x", -1.0))
	var pos_y: float = float(values.get("pos_y", -1.0))
	if pos_x < 0.0 or pos_x > 1.0 or pos_y < 0.0 or pos_y > 1.0:
		return "Setup obstacle placement must stay within the play area."
	return ""


func _payload_obstacle() -> Dictionary:
	return {
		"data_key": str(payload.get("data_key", "")).strip_edges(),
		"pos_x": float(payload.get("pos_x", 0.0)),
		"pos_y": float(payload.get("pos_y", 0.0)),
		"rotation_deg": float(payload.get("rotation_deg", 0.0)),
	}


static func _upsert_obstacle(obstacles: Array[Dictionary], obstacle: Dictionary) -> void:
	var key: String = str(obstacle.get("data_key", ""))
	for index: int in range(obstacles.size()):
		if str(obstacles[index].get("data_key", "")) == key:
			obstacles[index] = obstacle.duplicate(true)
			return
	obstacles.append(obstacle.duplicate(true))


static func _dict_array_from(raw_values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not raw_values is Array:
		return result
	for raw_value: Variant in raw_values as Array:
		if raw_value is Dictionary:
			result.append((raw_value as Dictionary).duplicate(true))
	return result
