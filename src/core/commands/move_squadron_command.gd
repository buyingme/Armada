## MoveSquadronCommand
##
## Records a squadron's movement to a new board position during the
## Squadron Phase. Because squadron position lives at the scene level
## ([code]SquadronToken.global_position[/code]) rather than in the core
## model, this command is primarily a **replay record**. The presentation
## layer applies the position from the command result.
##
## Payload:
##   "squadron_index" — index of the squadron in the player's fleet array.
##   "target_x"       — final world-space X position (float).
##   "target_y"       — final world-space Y position (float).
##
## Rules Reference: "Squadron Phase", p.3 — "Each unactivated squadron
## the active player controls can be activated to move and/or attack."
class_name MoveSquadronCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("move_squadron", func(player: int,
			pl: Dictionary) -> GameCommand:
		return MoveSquadronCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "move_squadron", p_payload)


## Validates that the squadron move is legal.
## Distance/engagement validation is performed by the presentation layer
## ([SquadronPhaseController]) before submitting.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SQUADRON \
			and game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Squadron or Ship Phase."
	var sq: SquadronInstance = game_state.get_squadron(
			player_index, payload.get("squadron_index", -1))
	if sq == null:
		return "Squadron not found."
	if sq.is_destroyed():
		return "Squadron is destroyed."
	if not payload.has("target_x") or not payload.has("target_y"):
		return "Missing target position."
	return ""


## No core-model mutation — position lives at scene level.
## Returns the movement data for the presentation layer to apply.
func execute(_game_state: GameState) -> Dictionary:
	return {
		"squadron_index": payload.get("squadron_index", -1),
		"target_x": float(payload.get("target_x", 0.0)),
		"target_y": float(payload.get("target_y", 0.0)),
	}
