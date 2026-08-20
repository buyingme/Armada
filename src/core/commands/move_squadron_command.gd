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
	var inspection_reason: String = \
		game_state.validate_completed_attack_inspection_consumer(
				str(payload.get("completed_attack_inspection_id", "")))
	if inspection_reason != "":
		return inspection_reason
	if game_state.current_phase != Constants.GamePhase.SQUADRON \
			and game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Squadron or Ship Phase."
	var sq: SquadronInstance = game_state.get_squadron(
			player_index, payload.get("squadron_index", -1))
	if sq == null:
		return "Squadron not found."
	if sq.is_destroyed():
		return "Squadron is destroyed."
	if not game_state.validate_declaration_adjacent_state():
		return "Declaration-adjacent state is invalid."
	var activation_identity: String = str(payload.get("activation_id", ""))
	if activation_identity.is_empty() \
			or activation_identity != sq.activation_id:
		return "Stale or missing squadron activation identity."
	var context_error: String = _validate_activation_context(game_state, sq)
	if not context_error.is_empty():
		return context_error
	if not sq.has_remaining_move_action(_is_rogue(sq)):
		return "Squadron movement is not available."
	if not payload.has("pos_x") or not payload.has("pos_y"):
		return "Missing target position."
	if not game_state.can_squadron_move_under_engagement_rules(sq):
		return "Engaged by a non-Heavy squadron."
	return ""


## Updates the squadron's normalised position in [GameState] and returns
## the movement data for the presentation layer to apply.
func execute(game_state: GameState) -> Dictionary:
	var inspection_id: String = str(payload.get(
			"completed_attack_inspection_id", ""))
	var sq: SquadronInstance = game_state.get_squadron(
			player_index, payload.get("squadron_index", -1))
	var new_x: float = float(payload.get("pos_x", 0.0))
	var new_y: float = float(payload.get("pos_y", 0.0))
	if sq == null:
		return {}
	var action_before: Dictionary = sq.activation_action_state_snapshot()
	var old_x: float = sq.pos_x
	var old_y: float = sq.pos_y
	if not sq.commit_move_action(
			str(payload.get("activation_id", "")), _is_rogue(sq)):
		return {}
	sq.pos_x = new_x
	sq.pos_y = new_y
	if not game_state.validate_declaration_adjacent_state():
		sq.pos_x = old_x
		sq.pos_y = old_y
		sq.restore_activation_action_state(action_before)
		return {}
	if not inspection_id.is_empty() \
			and not game_state.consume_completed_attack_inspection(inspection_id):
		sq.pos_x = old_x
		sq.pos_y = old_y
		sq.restore_activation_action_state(action_before)
		return {}
	return {
		"squadron_index": payload.get("squadron_index", -1),
		"pos_x": new_x,
		"pos_y": new_y,
		"activation_id": sq.activation_id,
		"activation_context": sq.activation_context,
	}


func _validate_activation_context(game_state: GameState,
		squadron: SquadronInstance) -> String:
	if squadron.activation_context \
			== SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
		if game_state.current_phase != Constants.GamePhase.SQUADRON:
			return "Squadron activation is not in Squadron Phase."
		if player_index != game_state.squadron_phase_controller_player:
			return "Squadron movement belongs to the canonical controller."
		return ""
	if squadron.activation_context \
			!= SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND \
			or game_state.current_phase != Constants.GamePhase.SHIP:
		return "Squadron activation context is invalid."
	var ship: ShipInstance = game_state.get_ship(
			squadron.commanding_ship_player, squadron.commanding_ship_index)
	if ship == null or ship.owner_player != player_index:
		return "Commanding ship is unavailable."
	if str(payload.get("ship_activation_identity", "")) \
			!= ship.ship_activation_identity \
			or ship.squadron_command_opportunity_disposition \
					!= ShipInstance.ACTIVATION_DISPOSITION_OPEN:
		return "Ship Squadron-command opportunity does not match."
	var capacity: int = SquadronCommandResolver.authoritative_capacity(ship)
	if ship.squadron_command_activations_committed <= 0 \
			or ship.squadron_command_activations_committed > capacity:
		return "Commanding ship activation budget is invalid."
	return ""


func _is_rogue(squadron: SquadronInstance) -> bool:
	return squadron.squadron_data != null \
			and squadron.squadron_data.has_keyword("Rogue")
