## ActivateSquadronCommand
##
## Establishes one canonical squadron activation in Squadron Phase or during
## an open ship Squadron-command opportunity.
##
## Payload:
##   "squadron_index" — index of the squadron in the player's fleet array.
##   "activation_context" — squadron_phase or ship_squadron_command.
##   Ship-command context also carries the commanding ship owner/index and
##   stable ship activation identity.
##
## Rules Reference: "Squadron Phase", SQ-003 — activate a squadron.
class_name ActivateSquadronCommand
extends GameCommand


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("activate_squadron", func(
			player: int, pl: Dictionary) -> GameCommand:
		return ActivateSquadronCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "activate_squadron", p_payload)


## Validates that squadron activation is legal.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	if game_state.current_phase != Constants.GamePhase.SQUADRON \
			and game_state.current_phase != Constants.GamePhase.SHIP:
		return "Not in Squadron or Ship Phase."
	if not game_state.validate_declaration_adjacent_state():
		return "Declaration-adjacent state is invalid."
	if game_state.get_active_squadron_activation() != null:
		return "Another squadron activation is active."
	var sq: SquadronInstance = _get_squadron(game_state)
	if sq == null:
		return "Squadron not found."
	if sq.is_destroyed():
		return "Squadron is destroyed."
	if sq.activated_this_round:
		return "Squadron already activated this round."
	if sq.has_activation_action_state():
		return "Squadron activation history was not reset."
	var context: String = str(payload.get("activation_context", ""))
	if game_state.current_phase == Constants.GamePhase.SQUADRON:
		if context != SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
			return "Wrong Squadron Phase activation context."
		if player_index != game_state.squadron_phase_controller_player:
			return "Squadron activation belongs to the canonical controller."
		if game_state.squadron_phase_activations_committed \
					>= Constants.SQUADRONS_PER_ACTIVATION:
			return "No Squadron Phase activation remains this turn."
		return ""
	if context != SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		return "Wrong ship Squadron-command activation context."
	var commanding_ship: ShipInstance = _get_commanding_ship(game_state)
	if commanding_ship == null or commanding_ship.owner_player != player_index:
		return "Commanding ship not found or not controlled."
	var ship_identity: String = str(payload.get(
			"ship_activation_identity", ""))
	if ship_identity.is_empty() \
			or ship_identity != commanding_ship.ship_activation_identity:
		return "Stale or missing commanding ship activation identity."
	if commanding_ship.squadron_command_opportunity_disposition \
			!= ShipInstance.ACTIVATION_DISPOSITION_OPEN:
		return "Squadron-command opportunity is not open."
	var capacity: int = SquadronCommandResolver.authoritative_capacity(
			commanding_ship)
	if capacity <= commanding_ship.squadron_command_activations_committed:
		return "No Squadron-command activation remains."
	if not SquadronCommandResolver.is_squadron_in_authoritative_range(
			commanding_ship, sq):
		return "Squadron is outside close-medium command range."
	return ""


## Initializes the squadron action owner and, for command context, commits one
## activation slot on the commanding ShipInstance in the same transaction.
func execute(game_state: GameState) -> Dictionary:
	if sequence < 0:
		return {}
	var squadron: SquadronInstance = _get_squadron(game_state)
	if squadron == null:
		return {}
	var context: String = str(payload.get("activation_context", ""))
	var action_before: Dictionary = squadron.activation_action_state_snapshot()
	var commanding_ship: ShipInstance = null
	var ship_before: Dictionary = {}
	if context == SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		commanding_ship = _get_commanding_ship(game_state)
		if commanding_ship == null:
			return {}
		ship_before = commanding_ship.ship_activation_boundary_snapshot()
	var activation_identity: String = "squadron-activation:%d" % sequence
	if not squadron.initialize_activation_action_state(
			activation_identity, context,
			int(payload.get("commanding_ship_player", -1)),
			int(payload.get("commanding_ship_index", -1))):
		return {}
	if commanding_ship != null \
			and not commanding_ship.commit_squadron_command_activation(
					str(payload.get("ship_activation_identity", ""))):
		squadron.restore_activation_action_state(action_before)
		return {}
	if not game_state.validate_declaration_adjacent_state():
		squadron.restore_activation_action_state(action_before)
		if commanding_ship != null:
			commanding_ship.restore_ship_activation_boundary(ship_before)
		return {}
	var flow_type: Constants.InteractionFlow = \
			Constants.InteractionFlow.SQUADRON_ACTIVATION
	var step: Constants.InteractionStep = Constants.InteractionStep.ACTION_CHOICE
	var flow_payload: Dictionary = {
		"squadron_index": payload.get("squadron_index", -1),
		"activation_id": activation_identity,
		"activation_context": context,
	}
	if commanding_ship != null:
		flow_type = Constants.InteractionFlow.SHIP_ACTIVATION
		step = Constants.InteractionStep.SQUADRON_STEP
		flow_payload["ship_index"] = payload.get("commanding_ship_index", -1)
		flow_payload["ship_activation_identity"] = payload.get(
				"ship_activation_identity", "")
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			flow_type, step, game_state,
			{"active_player": player_index}, Constants.Visibility.ALL,
			flow_payload)
	return {
		"squadron_index": payload.get("squadron_index", -1),
		"activation_id": activation_identity,
		"activation_context": context,
		"commanding_ship_player": payload.get("commanding_ship_player", -1),
		"commanding_ship_index": payload.get("commanding_ship_index", -1),
	}


## Returns the squadron instance from the payload, or null.
func _get_squadron(game_state: GameState) -> SquadronInstance:
	var ps: PlayerState = game_state.get_player_state(player_index)
	if ps == null:
		return null
	var idx: int = payload.get("squadron_index", -1)
	if idx < 0 or idx >= ps.squadrons.size():
		return null
	return ps.squadrons[idx] as SquadronInstance


func _get_commanding_ship(game_state: GameState) -> ShipInstance:
	if typeof(payload.get("commanding_ship_player")) != TYPE_INT \
			or typeof(payload.get("commanding_ship_index")) != TYPE_INT:
		return null
	return game_state.get_ship(
			int(payload.get("commanding_ship_player", -1)),
			int(payload.get("commanding_ship_index", -1)))
