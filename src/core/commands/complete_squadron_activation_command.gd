## CompleteSquadronActivationCommand
##
## Marker command for a squadron activation that finishes without a movement
## command. This covers Squadron Phase activations and ship-phase Squadron
## command activations. It replaces the old zero-distance move_squadron sync
## marker, which is not legal for engaged squadrons under Heavy rules.
##
## Rules Reference: RRG "Squadron Phase", p.12 — each player activates up
## to two unactivated squadrons.
## Rules Reference: RRG "Commands", p.4 — Squadron command.
class_name CompleteSquadronActivationCommand
extends GameCommand

const TYPE: String = "complete_squadron_activation"
const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int,
			pl: Dictionary) -> GameCommand:
		return CompleteSquadronActivationCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)


## Validates the referenced squadron can be marked complete this turn.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var inspection_reason: String = \
		game_state.validate_completed_attack_inspection_consumer(
				str(payload.get("completed_attack_inspection_id", "")))
	if inspection_reason != "":
		return inspection_reason
	if not _is_legal_phase(game_state.current_phase):
		return "Not in Squadron or Ship Phase."
	var squadron: SquadronInstance = _get_squadron(game_state)
	if squadron == null:
		return "Squadron not found."
	if squadron.activated_this_round:
		return "Squadron activation is already complete."
	if game_state.current_attack_state.active:
		return "Cannot complete a squadron while its attack is active."
	if not game_state.validate_declaration_adjacent_state():
		return "Declaration-adjacent state is invalid."
	if str(payload.get("activation_id", "")) != squadron.activation_id \
			or str(payload.get("activation_context", "")) \
					!= squadron.activation_context:
		return "Stale or wrong-context squadron activation identity."
	if not game_state.is_squadron_activation_action_complete(squadron):
		return "Squadron still has an available action."
	if squadron.activation_context \
			== SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
		if game_state.current_phase != Constants.GamePhase.SQUADRON \
				or player_index != game_state.squadron_phase_controller_player:
			return "Squadron completion belongs to the canonical controller."
	else:
		var ship_error: String = _validate_commanding_ship(game_state, squadron)
		if not ship_error.is_empty():
			return ship_error
	return ""


## Marks the squadron activated and echoes its identity.
func execute(game_state: GameState) -> Dictionary:
	var inspection_id: String = str(payload.get(
			"completed_attack_inspection_id", ""))
	var squadron: SquadronInstance = _get_squadron(game_state)
	if squadron == null \
			or not game_state.is_squadron_activation_action_complete(squadron):
		return {}
	var activated_before: bool = squadron.activated_this_round
	var phase_before: Dictionary = game_state.squadron_phase_progress_snapshot()
	squadron.activated_this_round = true
	var phase_result: Dictionary = {}
	if squadron.activation_context \
			== SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
		phase_result = game_state.commit_squadron_phase_activation(player_index)
		if phase_result.is_empty():
			squadron.activated_this_round = activated_before
			game_state.restore_squadron_phase_progress(phase_before)
			return {}
	if not game_state.validate_declaration_adjacent_state():
		squadron.activated_this_round = activated_before
		game_state.restore_squadron_phase_progress(phase_before)
		return {}
	if not inspection_id.is_empty() \
			and not game_state.consume_completed_attack_inspection(inspection_id):
		squadron.activated_this_round = activated_before
		game_state.restore_squadron_phase_progress(phase_before)
		return {}
	if squadron.activation_context \
			== SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
		game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
				Constants.InteractionFlow.SQUADRON_ACTIVATION,
				Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT,
				game_state,
				{"active_player": int(phase_result.get(
						"controller_player", -1))},
				Constants.Visibility.ALL)
	else:
		# This existing consumer is the terminal commanded-squadron mutation.
		# Once it has atomically consumed a completed-result inspection, restore
		# the enclosing ship-command projection rather than retaining the retired
		# individual attack flow.  It creates no further progression command.
		game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
				Constants.InteractionFlow.SHIP_ACTIVATION,
				Constants.InteractionStep.SQUADRON_STEP,
				game_state,
				{"active_player": player_index},
				Constants.Visibility.ALL,
				{"ship_index": squadron.commanding_ship_index,
					"ship_activation_identity": str(payload.get(
							"ship_activation_identity", ""))})
	var result: Dictionary = {
		"squadron_index": int(payload.get("squadron_index", -1)),
		"activation_id": squadron.activation_id,
		"activation_context": squadron.activation_context,
		"activation_complete": true,
	}
	result.merge(phase_result, true)
	return result


func _is_legal_phase(phase: Constants.GamePhase) -> bool:
	return phase == Constants.GamePhase.SQUADRON \
			or phase == Constants.GamePhase.SHIP


func _get_squadron(game_state: GameState) -> SquadronInstance:
	var player_state: PlayerState = game_state.get_player_state(player_index)
	if player_state == null:
		return null
	var index: int = int(payload.get("squadron_index", -1))
	if index < 0 or index >= player_state.squadrons.size():
		return null
	return player_state.squadrons[index] as SquadronInstance


func _validate_commanding_ship(game_state: GameState,
		squadron: SquadronInstance) -> String:
	if game_state.current_phase != Constants.GamePhase.SHIP \
			or squadron.activation_context \
					!= SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
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
