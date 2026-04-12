## ExecuteManeuverCommand
##
## Records a ship's maneuver execution during the Ship Phase. The command
## carries both the deterministic inputs (speed, yaw clicks) for validation
## and the final world-space transform for replay application.
##
## Because ship position lives at the scene level
## ([code]ShipToken.global_position[/code]) and overlap resolution depends
## on pixel-precise scene-tree geometry, the presentation layer computes
## and supplies [code]final_x[/code]/[code]final_y[/code]/
## [code]final_rotation[/code]. This command validates the maneuver inputs
## and records the result.
##
## Payload:
##   "ship_index"      — index of the ship in the player's fleet array.
##   "speed"           — int, the speed used for this maneuver.
##   "yaw_clicks"      — Array[int], signed clicks per joint.
##   "final_x"         — float, final world-space X after overlap resolution.
##   "final_y"         — float, final world-space Y after overlap resolution.
##   "final_rotation"  — float, final rotation in radians.
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
	var speed: int = payload.get("speed", -1)
	if speed < 0:
		return "Invalid speed."
	var yaw_clicks: Array = payload.get("yaw_clicks", [])
	if speed > 0 and yaw_clicks.is_empty():
		return "Missing yaw clicks for non-zero speed."
	if speed > 0 and ship.ship_data != null:
		if not ManeuverCalculator.validate_yaw_clicks(
				ship.ship_data.navigation_chart, speed, yaw_clicks):
			return "Yaw clicks exceed navigation chart limits."
	if not payload.has("final_x") or not payload.has("final_y"):
		return "Missing final position."
	if not payload.has("final_rotation"):
		return "Missing final rotation."
	return ""


## No core-model mutation — position lives at scene level.
## Returns the maneuver data for the presentation layer to apply.
func execute(_game_state: GameState) -> Dictionary:
	return {
		"ship_index": payload.get("ship_index", -1),
		"speed": payload.get("speed", 0),
		"yaw_clicks": payload.get("yaw_clicks", []),
		"final_x": float(payload.get("final_x", 0.0)),
		"final_y": float(payload.get("final_y", 0.0)),
		"final_rotation": float(payload.get("final_rotation", 0.0)),
	}
