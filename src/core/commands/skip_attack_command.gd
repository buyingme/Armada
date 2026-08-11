## SkipAttackCommand
##
## Records an active attack terminal choice or atomically consumes one
## supported no-active declaration opportunity.
##
## Payload:
##   "reason" — optional human-readable reason for the skip
##              (e.g. "no_targets", "voluntary", "squadron_done").
##   "ship_index" — required stable attacker identity for "squadron_done".
##
## Rules Reference: "Attack", p.2 —
## "A ship can perform up to two attacks during its activation."
class_name SkipAttackCommand
extends GameCommand


const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")
const H9_RULE: GDScript = preload(
		"res://src/core/effects/rules/upgrades/turbolasers/h9_turbolasers.gd")
const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")
const CONTEXT_SHIP_ATTACK: String = "ship_attack"
const TERMINAL_REASONS: Array[String] = [
	"cancelled",
	"flow_replaced",
	"flow_terminated",
]


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("skip_attack", func(player: int,
			pl: Dictionary) -> GameCommand:
		return SkipAttackCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "skip_attack", p_payload)


## Validates that skipping is legal.
## Allowed in both Ship and Squadron phases (squadrons may skip attacks).
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	var attack: CurrentAttackState = game_state.current_attack_state
	if not attack.active:
		if str(payload.get("reason", "")) == "squadron_done":
			var ship: ShipInstance = _squadron_iteration_ship(game_state)
			if ship == null:
				return "No active anti-squadron continuation."
			return ""
		return _validate_declaration_skip(game_state)
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if player_index != attack.attacker_player:
		return "Attack cancellation belongs to the attacker."
	if not TERMINAL_REASONS.has(str(payload.get("reason", ""))):
		return "Invalid active-attack terminal reason."
	if game_state.timing_window_state.active:
		var context: Dictionary = game_state.timing_window_state.continuation_context
		if str(context.get(TimingWindowState.CONTINUATION_KEY_SOURCE_ID, "")) \
				!= attack.attack_id \
				or str(payload.get(
						TimingWindowOrchestrator.COMMAND_KEY_LIFECYCLE_ID, "")) \
						!= game_state.timing_window_state.lifecycle_id:
			return "Timing lifecycle does not match the current attack."
	return ""


## Retires an active cancelled attack, or records a non-attack skip.
func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var attack_id: String = attack.attack_id
	var cleared: Array[String] = []
	var h9_cleared: Array[String] = []
	var continuation: String = ""
	if attack.active:
		if not game_state.set_current_attack_state(CurrentAttackState.inactive()):
			return {}
		if game_state.timing_window_state.active:
			var cancelled: Dictionary = TimingWindowOrchestrator.cancel_window(
					game_state, game_state.timing_window_state.lifecycle_id)
			if not bool(cancelled.get(TimingWindowOrchestrator.KEY_OK, false)):
				game_state.set_current_attack_state(attack)
				return {}
		cleared = ECM_SCRIPT.clear_attack_state(game_state, attack_id)
		h9_cleared = H9_RULE.clear_attack_guards(game_state, attack_id)
	elif str(payload.get("reason", "")) == "squadron_done":
		var ship: ShipInstance = _squadron_iteration_ship(game_state)
		if ship == null:
			return {}
		ship.end_anti_squadron_attack()
		continuation = CompleteAttackCommand.CONTINUATION_NORMAL_ATTACK \
				if ship.committed_attack_count < 2 \
				else CompleteAttackCommand.CONTINUATION_ATTACK_STEP_COMPLETE
	else:
		return _execute_declaration_skip(game_state)
	var result: Dictionary = {
		"attack_id": attack_id,
		"skipped": true,
		"reason": payload.get("reason", "voluntary"),
		"ecm_cleared_runtime_upgrade_ids": cleared,
		"h9_cleared_runtime_upgrade_ids": h9_cleared,
	}
	if not continuation.is_empty():
		result["continuation"] = continuation
	return result


func _validate_declaration_skip(game_state: GameState) -> String:
	if not game_state.validate_declaration_adjacent_state():
		return "Declaration-adjacent state is invalid."
	var context: String = str(payload.get("declaration_context", ""))
	if context == CONTEXT_SHIP_ATTACK:
		if game_state.current_phase != Constants.GamePhase.SHIP \
				or typeof(payload.get("ship_index")) != TYPE_INT:
			return "Invalid ship declaration context."
		var ship: ShipInstance = game_state.get_ship(
				player_index, int(payload.get("ship_index", -1)))
		if ship == null or ship.is_destroyed() or not ship.attack_step_active:
			return "No active authoritative ship Attack-step opportunity."
		if str(payload.get("ship_activation_identity", "")) \
				!= ship.ship_activation_identity \
				or ship.ship_activation_identity.is_empty():
			return "Stale or missing ship activation identity."
		if ship.maneuver_opportunity_disposition \
				!= ShipInstance.ACTIVATION_DISPOSITION_UNREACHED:
			return "Ship declaration opportunity was already consumed."
		return ""
	if context != SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE \
			and context \
					!= SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		return "Unsupported no-active declaration context."
	if typeof(payload.get("squadron_index")) != TYPE_INT:
		return "Missing squadron declaration identity."
	var squadron: SquadronInstance = game_state.get_squadron(
			player_index, int(payload.get("squadron_index", -1)))
	if squadron == null or squadron.is_destroyed() \
			or squadron.activated_this_round:
		return "No active authoritative squadron declaration opportunity."
	if str(payload.get("activation_id", "")) != squadron.activation_id \
			or context != squadron.activation_context:
		return "Stale or wrong-context squadron activation identity."
	if not squadron.has_remaining_attack_action(_is_rogue(squadron)):
		return "Squadron attack action is not available."
	if context == SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
		if game_state.current_phase != Constants.GamePhase.SQUADRON \
				or player_index != game_state.squadron_phase_controller_player:
			return "Squadron declaration belongs to the canonical controller."
		return ""
	if game_state.current_phase != Constants.GamePhase.SHIP:
		return "Commanded squadron declaration is not in Ship Phase."
	var commanding_ship: ShipInstance = game_state.get_ship(
			squadron.commanding_ship_player, squadron.commanding_ship_index)
	if commanding_ship == null or commanding_ship.owner_player != player_index:
		return "Commanding ship is unavailable."
	if str(payload.get("ship_activation_identity", "")) \
			!= commanding_ship.ship_activation_identity \
			or commanding_ship.squadron_command_opportunity_disposition \
					!= ShipInstance.ACTIVATION_DISPOSITION_OPEN:
		return "Ship Squadron-command opportunity does not match."
	var capacity: int = SquadronCommandResolver.authoritative_capacity(
			commanding_ship)
	if commanding_ship.squadron_command_activations_committed <= 0 \
			or commanding_ship.squadron_command_activations_committed > capacity:
		return "Commanding ship activation budget is invalid."
	return ""


func _execute_declaration_skip(game_state: GameState) -> Dictionary:
	var context: String = str(payload.get("declaration_context", ""))
	if context == CONTEXT_SHIP_ATTACK:
		return _execute_ship_declaration_skip(game_state)
	return _execute_squadron_declaration_skip(game_state, context)


func _execute_ship_declaration_skip(game_state: GameState) -> Dictionary:
	var ship: ShipInstance = game_state.get_ship(
			player_index, int(payload.get("ship_index", -1)))
	if ship == null:
		return {}
	var progress_before: Dictionary = ship.attack_progress_snapshot()
	var boundary_before: Dictionary = ship.ship_activation_boundary_snapshot()
	var identity: String = str(payload.get("ship_activation_identity", ""))
	if not ship.open_maneuver_opportunity(identity):
		return {}
	ship.end_attack_step()
	if not game_state.validate_declaration_adjacent_state():
		ship.restore_attack_progress(progress_before)
		ship.restore_ship_activation_boundary(boundary_before)
		return {}
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			game_state, {"active_player": player_index},
			Constants.Visibility.ALL,
			{"ship_index": payload.get("ship_index", -1),
				"ship_activation_identity": identity})
	return {
		"attack_id": "",
		"skipped": true,
		"reason": payload.get("reason", "voluntary"),
		"declaration_skip": true,
		"declaration_context": CONTEXT_SHIP_ATTACK,
		"ship_index": payload.get("ship_index", -1),
		"ship_activation_identity": identity,
		"maneuver_open": true,
	}


func _execute_squadron_declaration_skip(
		game_state: GameState, context: String) -> Dictionary:
	var squadron: SquadronInstance = game_state.get_squadron(
			player_index, int(payload.get("squadron_index", -1)))
	if squadron == null:
		return {}
	var action_before: Dictionary = squadron.activation_action_state_snapshot()
	var activated_before: bool = squadron.activated_this_round
	var phase_before: Dictionary = game_state.squadron_phase_progress_snapshot()
	if not squadron.commit_attack_action_declined(
			str(payload.get("activation_id", "")), _is_rogue(squadron)):
		return {}
	var activation_complete: bool = squadron.is_activation_action_complete(
			_is_rogue(squadron))
	var phase_result: Dictionary = {}
	if activation_complete:
		squadron.activated_this_round = true
		if context == SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
			phase_result = game_state.commit_squadron_phase_activation(
					player_index)
			if phase_result.is_empty():
				_restore_squadron_declaration_skip(game_state, squadron,
						action_before, activated_before, phase_before)
				return {}
	if not game_state.validate_declaration_adjacent_state():
		_restore_squadron_declaration_skip(game_state, squadron,
				action_before, activated_before, phase_before)
		return {}
	var controller: int = player_index
	var flow_type: Constants.InteractionFlow = \
			Constants.InteractionFlow.SQUADRON_ACTIVATION
	var step: Constants.InteractionStep = Constants.InteractionStep.ACTION_CHOICE
	var route_payload: Dictionary = {
		"squadron_index": payload.get("squadron_index", -1),
		"activation_id": squadron.activation_id,
		"activation_context": context,
	}
	if context == SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
		if activation_complete:
			controller = int(phase_result.get("controller_player", -1))
			step = Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT
	else:
		flow_type = Constants.InteractionFlow.SHIP_ACTIVATION
		step = Constants.InteractionStep.SQUADRON_STEP
		route_payload["ship_index"] = squadron.commanding_ship_index
		route_payload["ship_activation_identity"] = payload.get(
				"ship_activation_identity", "")
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			flow_type, step, game_state,
			{"active_player": controller}, Constants.Visibility.ALL,
			route_payload)
	var result: Dictionary = {
		"attack_id": "",
		"skipped": true,
		"reason": payload.get("reason", "voluntary"),
		"declaration_skip": true,
		"declaration_context": context,
		"squadron_index": payload.get("squadron_index", -1),
		"activation_id": squadron.activation_id,
		"activation_complete": activation_complete,
		"movement_remains": squadron.has_remaining_move_action(
				_is_rogue(squadron)),
	}
	result.merge(phase_result, true)
	return result


func _restore_squadron_declaration_skip(game_state: GameState,
		squadron: SquadronInstance, action_snapshot: Dictionary,
		activated_before: bool, phase_snapshot: Dictionary) -> void:
	squadron.restore_activation_action_state(action_snapshot)
	squadron.activated_this_round = activated_before
	game_state.restore_squadron_phase_progress(phase_snapshot)


func _is_rogue(squadron: SquadronInstance) -> bool:
	return squadron != null and squadron.squadron_data != null \
			and squadron.squadron_data.has_keyword("Rogue")


func _squadron_iteration_ship(game_state: GameState) -> ShipInstance:
	if typeof(payload.get("ship_index")) != TYPE_INT:
		return null
	var ship: ShipInstance = game_state.get_ship(
			player_index, int(payload.get("ship_index", -1)))
	if ship == null or not ship.attack_step_active \
			or ship.anti_squadron_attack_zone < 0:
		return null
	return ship
