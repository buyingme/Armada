## ExecuteManeuverCommand
##
## Records a ship's maneuver execution during the Ship Phase. The command
## carries both the deterministic inputs (speed, yaw clicks) for validation
## and the final position/rotation as normalised coordinates matching the
## [code]learning_scenario.json[/code] format.
##
## The [method execute] method updates the [ShipInstance] model so the
## position is part of game-state serialization.
##
## Payload:
##   "ship_index"    — index of the ship in the player's fleet array.
##   "speed"         — int, the speed used for this maneuver.
##   "yaw_clicks"    — Array[int], signed clicks per joint.
##   "pos_x"         — normalised X (0.0 = left, 1.0 = right).
##   "pos_y"         — normalised Y (0.0 = top,  1.0 = bottom).
##   "rotation_deg"  — rotation in degrees (0 = facing up / -Y).
##   "yaw_bonus_joint" — int, joint index granted +1 yaw via the
##                       Navigate command's yaw bonus, or -1 if none.
##                       Rules Reference: "Navigate" — increase 1 yaw
##                       value by 1 at any joint.
##
## Rules Reference: "Ship Phase", "Execute Maneuver", p.7; MV-001–005.
class_name ExecuteManeuverCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("execute_maneuver", func(player: int,
			pl: Dictionary) -> GameCommand:
		return ExecuteManeuverCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "execute_maneuver", p_payload)


## Validates that the maneuver execution is legal.
## Checks phase, ship existence, and yaw-click legality via
## [ManeuverCalculator.validate_yaw_clicks].
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Ship Phase."
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	if ship == null:
		return "Ship not found."
	var flow_error: String = _validate_activation_flow(game_state)
	if flow_error != "":
		return flow_error
	var speed: int = payload.get("speed", -1)
	if speed < 0:
		return "Invalid speed."
	var yaw_clicks: Array = payload.get("yaw_clicks", [])
	if speed > 0 and yaw_clicks.is_empty():
		return "Missing yaw clicks for non-zero speed."
	if speed > 0 and ship.ship_data != null:
		var bonus_joint: int = int(payload.get("yaw_bonus_joint", -1))
		if not _validate_yaw_clicks_with_bonus(
				ship.ship_data.navigation_chart, speed,
				yaw_clicks, bonus_joint):
			return "Yaw clicks exceed navigation chart limits."
	if not payload.has("pos_x") or not payload.has("pos_y"):
		return "Missing final position."
	if not payload.has("rotation_deg"):
		return "Missing final rotation."
	return ""


func _validate_activation_flow(game_state: GameState) -> String:
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null or flow.flow_type != Constants.InteractionFlow.SHIP_ACTIVATION:
		return ""
	if _is_legacy_activation_open_step(flow.step_id):
		return ""
	if flow.step_id != Constants.InteractionStep.MANEUVER_STEP:
		return "Maneuver command submitted outside Maneuver step."
	if flow.controller_player != player_index:
		return "Maneuver command submitted by non-controller player."
	var flow_ship_index: int = int(flow.payload.get("ship_index", -1))
	var command_ship_index: int = int(payload.get("ship_index", -1))
	if flow_ship_index >= 0 and flow_ship_index != command_ship_index:
		return "Maneuver command submitted for inactive ship."
	return ""


func _is_legacy_activation_open_step(
		step_id: Constants.InteractionStep) -> bool:
	return step_id == Constants.InteractionStep.NONE \
			or step_id == Constants.InteractionStep.WAIT_FOR_SHIP_SELECT \
			or step_id == Constants.InteractionStep.ACTIVATION_MODAL_OPEN \
			or step_id == Constants.InteractionStep.REVEAL_DIAL \
			or step_id == Constants.InteractionStep.SPEND_DIAL


## Updates the ship's normalised position and rotation in [GameState]
## and returns the maneuver data for the presentation layer to apply.
func execute(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, payload.get("ship_index", -1))
	var new_x: float = float(payload.get("pos_x", 0.0))
	var new_y: float = float(payload.get("pos_y", 0.0))
	var new_rot: float = float(payload.get("rotation_deg", 0.0))
	if ship != null:
		ship.pos_x = new_x
		ship.pos_y = new_y
		ship.rotation_deg = new_rot
	# Phase I2: mirror legacy interaction-state.
	game_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			player_index,
			Constants.Visibility.ALL)
	return {
		"ship_index": payload.get("ship_index", -1),
		"speed": payload.get("speed", 0),
		"yaw_clicks": payload.get("yaw_clicks", []),
		"pos_x": new_x,
		"pos_y": new_y,
		"rotation_deg": new_rot,
		"yaw_bonus_joint": int(payload.get("yaw_bonus_joint", -1)),
	}


## Validates yaw clicks, allowing one joint (when [param bonus_joint] >= 0)
## to exceed its navigation-chart limit by 1 due to the Navigate command's
## yaw bonus.
## Rules Reference: "Navigate" — increase 1 yaw value by 1 at any joint.
static func _validate_yaw_clicks_with_bonus(
		nav_chart: Array, speed: int,
		yaw_clicks_per_joint: Array, bonus_joint: int) -> bool:
	var joint_count: int = ManeuverCalculator.get_joint_count(speed)
	if yaw_clicks_per_joint.size() != joint_count:
		return false
	for idx: int in range(joint_count):
		var clicks: int = abs(int(yaw_clicks_per_joint[idx]))
		var max_clicks: int = ManeuverCalculator.get_max_yaw(
				nav_chart, speed, idx)
		if idx == bonus_joint:
			max_clicks += 1
		if clicks > max_clicks:
			return false
	return true
