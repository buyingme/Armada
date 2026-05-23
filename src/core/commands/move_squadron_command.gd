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
## Distance validation is performed by the presentation layer
## ([SquadronPhaseController]) before submitting. Engagement validation is
## repeated here so direct command/replay/network submissions respect Heavy.
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
	if not _can_move_under_engagement_rules(game_state, sq):
		return "Engaged by a non-Heavy squadron."
	return ""


func _can_move_under_engagement_rules(game_state: GameState,
		squadron: SquadronInstance) -> bool:
	var all_squadrons: Array[Dictionary] = \
			SquadronKeywordRuleHelper.positions_from_state(game_state)
	var obstruction_bodies: Array = \
			EngagementResolver.obstruction_bodies_from_state(game_state)
	var squadron_pos: Vector2 = \
			SquadronKeywordRuleHelper.position_from_state(squadron)
	return SquadronKeywordRuleHelper.can_move_with_heavy_rule(
			squadron, squadron_pos, all_squadrons, obstruction_bodies)


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
