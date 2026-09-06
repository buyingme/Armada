## DeclineSquadronMoveCommand
##
## Records the controller's explicit decision not to take a currently legal
## remaining Squadron Move. This is activation history, not movement.
class_name DeclineSquadronMoveCommand
extends GameCommand


const TYPE: String = "decline_squadron_move"


static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int,
			pl: Dictionary) -> GameCommand:
		return DeclineSquadronMoveCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	var schema_reason: String = _validate_payload_schema()
	if not schema_reason.is_empty():
		return schema_reason
	var inspection_reason: String = \
		game_state.validate_completed_attack_inspection_consumer(
				str(payload["completed_attack_inspection_id"]))
	if not inspection_reason.is_empty():
		return inspection_reason
	if game_state.current_phase not in [Constants.GamePhase.SHIP,
			Constants.GamePhase.SQUADRON]:
		return "Not in Squadron or Ship Phase."
	if game_state.current_attack_state.active:
		return "Cannot decline Move while a squadron attack is active."
	if not game_state.validate_declaration_adjacent_state():
		return "Declaration-adjacent state is invalid."
	var squadron: SquadronInstance = game_state.get_squadron(
			player_index, int(payload["squadron_index"]))
	if squadron == null or squadron.is_destroyed():
		return "Squadron not found or destroyed."
	if squadron.activated_this_round:
		return "Squadron activation is already complete."
	if str(payload["activation_id"]) != squadron.activation_id \
			or str(payload["activation_context"]) != squadron.activation_context:
		return "Stale or wrong-context squadron activation identity."
	if squadron.move_action_disposition \
			!= SquadronInstance.MOVE_ACTION_AVAILABLE:
		return "Squadron Move is not available to decline."
	var context_reason: String = _validate_context(game_state, squadron)
	if not context_reason.is_empty():
		return context_reason
	if not game_state.has_legal_remaining_squadron_move_action(squadron):
		return "Squadron has no legal remaining Move to decline."
	return ""


func execute(game_state: GameState) -> Dictionary:
	var squadron: SquadronInstance = game_state.get_squadron(
			player_index, int(payload.get("squadron_index", -1)))
	if squadron == null:
		return {}
	var action_before: Dictionary = squadron.activation_action_state_snapshot()
	var is_rogue: bool = squadron.squadron_data != null \
			and squadron.squadron_data.has_keyword("Rogue")
	if not squadron.decline_move_action(
			str(payload.get("activation_id", "")), is_rogue):
		return {}
	if not game_state.validate_declaration_adjacent_state():
		squadron.restore_activation_action_state(action_before)
		return {}
	var inspection_id: String = str(payload.get(
			"completed_attack_inspection_id", ""))
	if not inspection_id.is_empty() \
			and not game_state.consume_completed_attack_inspection(inspection_id):
		squadron.restore_activation_action_state(action_before)
		return {}
	return {
		"squadron_index": int(payload.get("squadron_index", -1)),
		"activation_id": squadron.activation_id,
		"activation_context": squadron.activation_context,
		"move_disposition": SquadronInstance.MOVE_ACTION_DECLINED,
	}


func _validate_payload_schema() -> String:
	var context: Variant = payload.get("activation_context")
	var expected: Array[String] = [
		"squadron_index", "activation_id", "activation_context",
		"completed_attack_inspection_id",
	]
	if context == SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		expected.append("ship_activation_identity")
	if payload.size() != expected.size():
		return "Decline Squadron Move payload does not match its exact schema."
	for key: String in expected:
		if not payload.has(key):
			return "Decline Squadron Move payload does not match its exact schema."
	if typeof(payload["squadron_index"]) != TYPE_INT \
			or typeof(payload["activation_id"]) != TYPE_STRING \
			or typeof(payload["activation_context"]) != TYPE_STRING \
			or typeof(payload["completed_attack_inspection_id"]) != TYPE_STRING:
		return "Decline Squadron Move payload types are invalid."
	if expected.has("ship_activation_identity") \
			and typeof(payload["ship_activation_identity"]) != TYPE_STRING:
		return "Decline Squadron Move payload types are invalid."
	return ""


func _validate_context(game_state: GameState,
		squadron: SquadronInstance) -> String:
	if squadron.activation_context \
			== SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
		if game_state.current_phase != Constants.GamePhase.SQUADRON \
				or player_index != game_state.squadron_phase_controller_player:
			return "Squadron Move decline belongs to the canonical controller."
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
