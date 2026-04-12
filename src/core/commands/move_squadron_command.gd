## MoveSquadronCommand
##
## Records a squadron's movement to a new board position during the
## Squadron Phase. Position is stored as normalised coordinates matching
## the [code]learning_scenario.json[/code] format ([code]pos_x[/code],
## [code]pos_y[/code]: 0.0–1.0). The [method execute] method updates the
## [SquadronInstance] model so the position is part of game-state
## serialization.
##
## Payload:
##   "squadron_index" — index of the squadron in the player's fleet array.
##   "pos_x"          — normalised X (0.0 = left, 1.0 = right).
##   "pos_y"          — normalised Y (0.0 = top,  1.0 = bottom).
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
	if not payload.has("pos_x") or not payload.has("pos_y"):
		return "Missing target position."
	return ""


## Updates the squadron's normalised position in [GameState] and returns
## the movement data for the presentation layer to apply.
func execute(game_state: GameState) -> Dictionary:
	var sq: SquadronInstance = game_state.get_squadron(
			player_index, payload.get("squadron_index", -1))
	var new_x: float = float(payload.get("pos_x", 0.0))
	var new_y: float = float(payload.get("pos_y", 0.0))
	if sq != null:
		sq.pos_x = new_x
		sq.pos_y = new_y
	return {
		"squadron_index": payload.get("squadron_index", -1),
		"pos_x": new_x,
		"pos_y": new_y,
	}
