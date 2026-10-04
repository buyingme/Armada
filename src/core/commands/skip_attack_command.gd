## SkipAttackCommand
##
## Records an active attack terminal choice or atomically consumes one
## supported no-active declaration opportunity.
##
## Payload:
##   "reason" — optional human-readable reason for the skip
##              (e.g. "no_targets", "voluntary", "squadron_done",
##              "anti_squadron_voluntary_done").
##   "ship_index" — required stable attacker identity for anti-squadron
##              child-finish reasons.
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
const GATHER_READINESS: GDScript = preload(
		"res://src/core/commands/attack_gather_readiness.gd")
const CONTEXT_SHIP_ATTACK: String = "ship_attack"
const REASON_SQUADRON_DONE: String = "squadron_done"
const REASON_ANTI_SQUADRON_VOLUNTARY_DONE: String = \
		"anti_squadron_voluntary_done"
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
	var inspection_reason: String = \
		game_state.validate_completed_attack_inspection_consumer(
				str(payload.get("completed_attack_inspection_id", "")))
	if inspection_reason != "":
		return inspection_reason
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	var attack: CurrentAttackState = game_state.current_attack_state
	if not attack.active:
		var reason: String = str(payload.get("reason", ""))
		if reason == REASON_SQUADRON_DONE \
				or reason == REASON_ANTI_SQUADRON_VOLUNTARY_DONE:
			var ship: ShipInstance = _squadron_iteration_ship(game_state)
			if ship == null:
				return "No active anti-squadron continuation."
			if reason == REASON_ANTI_SQUADRON_VOLUNTARY_DONE \
					or not str(payload.get(
							"completed_attack_inspection_id", "")).is_empty():
				var context_reason: String = \
						_validate_anti_squadron_child_finish_inspection(
								game_state, ship,
								reason == REASON_SQUADRON_DONE)
				if context_reason != "":
					return context_reason
			elif reason == REASON_SQUADRON_DONE:
				var return_reason: String = \
						_validate_cancelled_anti_squadron_finish(game_state, ship)
				if not return_reason.is_empty():
					return return_reason
			return ""
		return _validate_declaration_skip(game_state)
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if player_index != attack.attacker_player:
		return "Attack cancellation belongs to the attacker."
	if not TERMINAL_REASONS.has(str(payload.get("reason", ""))):
		return "Invalid active-attack terminal reason."
	if str(payload.get("reason", "")) == "cancelled":
		if game_state.timing_window_state.active:
			return "Gather cancellation cannot retire an active timing lifecycle."
		var readiness: Dictionary = GATHER_READINESS.derive(
				game_state, attack)
		if not bool(readiness.get("ok", false)):
			return str(readiness.get("reason", "Invalid Gather state."))
		if not bool(readiness.get("complete", false)) \
				or not bool(readiness.get("empty", false)):
			return "Gather cancellation requires a complete empty pool."
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
	var inspection_id: String = str(payload.get(
			"completed_attack_inspection_id", ""))
	var attack: CurrentAttackState = game_state.current_attack_state
	var attack_id: String = attack.attack_id
	var cleared: Array[String] = []
	var h9_cleared: Array[String] = []
	var continuation: String = ""
	var result: Dictionary = {}
	if attack.active:
		var cancellation_route: Dictionary = {}
		var cancellation_ship: ShipInstance = null
		var progress_before: Dictionary = {}
		if str(payload.get("reason", "")) == "cancelled":
			cancellation_route = _active_cancellation_route(game_state, attack)
			if cancellation_route.is_empty():
				return {}
			if attack.attacker_kind == CurrentAttackState.KIND_SHIP:
				cancellation_ship = game_state.get_ship(
						attack.attacker_player, attack.attacker_index)
				if cancellation_ship != null:
					progress_before = cancellation_ship.attack_progress_snapshot()
		if not game_state.set_current_attack_state(CurrentAttackState.inactive()):
			return {}
		if not cancellation_route.is_empty():
			if cancellation_ship != null \
					and cancellation_ship.anti_squadron_attack_zone >= 0 \
					and not cancellation_ship \
							.record_anti_squadron_cancellation_return(attack_id):
				game_state.set_current_attack_state(attack)
				cancellation_ship.restore_attack_progress(progress_before)
				return {}
			var enclosing: InteractionFlow = FLOW_SPEC_SCRIPT.make_interaction_flow(
					int(cancellation_route["flow_type"])
							as Constants.InteractionFlow,
					int(cancellation_route["step"])
							as Constants.InteractionStep, game_state,
					{"active_player": attack.attacker_player},
					Constants.Visibility.ALL,
					cancellation_route["payload"])
			if enclosing == null:
				game_state.set_current_attack_state(attack)
				if cancellation_ship != null:
					cancellation_ship.restore_attack_progress(progress_before)
				return {}
			game_state.interaction_flow = enclosing
		if game_state.timing_window_state.active:
			var cancelled: Dictionary = TimingWindowOrchestrator.cancel_window(
					game_state, game_state.timing_window_state.lifecycle_id)
			if not bool(cancelled.get(TimingWindowOrchestrator.KEY_OK, false)):
				game_state.set_current_attack_state(attack)
				return {}
		cleared = ECM_SCRIPT.clear_attack_state(game_state, attack_id)
		h9_cleared = H9_RULE.clear_attack_guards(game_state, attack_id)
	elif str(payload.get("reason", "")) in [
		REASON_SQUADRON_DONE,
		REASON_ANTI_SQUADRON_VOLUNTARY_DONE,
	]:
		var ship: ShipInstance = _squadron_iteration_ship(game_state)
		if ship == null:
			return {}
		var progress_before: Dictionary = ship.attack_progress_snapshot()
		ship.end_anti_squadron_attack()
		if not inspection_id.is_empty() \
			and not game_state.consume_completed_attack_inspection(inspection_id):
			ship.restore_attack_progress(progress_before)
			return {}
		continuation = CompleteAttackCommand.CONTINUATION_NORMAL_ATTACK \
				if ship.committed_attack_count < 2 \
				else CompleteAttackCommand.CONTINUATION_ATTACK_STEP_COMPLETE
	else:
		result = _execute_declaration_skip(game_state)
		if result.is_empty() or (not inspection_id.is_empty() \
				and not game_state.consume_completed_attack_inspection(inspection_id)):
			return {}
		return result
	result = {
		"attack_id": attack_id,
		"attacker_index": attack.attacker_index if attack.active else -1,
		"attacker_kind": attack.attacker_kind if attack.active else "",
		"skipped": true,
		"reason": payload.get("reason", "voluntary"),
		"ecm_cleared_runtime_upgrade_ids": cleared,
		"h9_cleared_runtime_upgrade_ids": h9_cleared,
	}
	if not continuation.is_empty():
		result["continuation"] = continuation
	return result


func _active_cancellation_route(game_state: GameState,
		attack: CurrentAttackState) -> Dictionary:
	if attack.attacker_kind == CurrentAttackState.KIND_SHIP:
		var ship: ShipInstance = game_state.get_ship(
				attack.attacker_player, attack.attacker_index)
		if ship == null or not ship.attack_step_active \
				or ship.ship_activation_identity.is_empty():
			return {}
		return {"flow_type": Constants.InteractionFlow.SHIP_ACTIVATION,
			"step": Constants.InteractionStep.ATTACK_STEP,
			"payload": {"ship_index": attack.attacker_index,
				"ship_activation_identity": ship.ship_activation_identity}}
	var squadron: SquadronInstance = game_state.get_squadron(
			attack.attacker_player, attack.attacker_index)
	if squadron == null or squadron.activation_id.is_empty():
		return {}
	var route: Dictionary = {"squadron_index": attack.attacker_index,
		"activation_id": squadron.activation_id,
		"activation_context": squadron.activation_context}
	if squadron.activation_context \
			== SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
		return {"flow_type": Constants.InteractionFlow.SQUADRON_ACTIVATION,
			"step": Constants.InteractionStep.ACTION_CHOICE,
			"payload": route}
	if squadron.activation_context \
			== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		var commanding_ship: ShipInstance = game_state.get_ship(
				squadron.commanding_ship_player, squadron.commanding_ship_index)
		if commanding_ship == null \
				or commanding_ship.ship_activation_identity.is_empty():
			return {}
		route["ship_index"] = squadron.commanding_ship_index
		route["ship_activation_identity"] = \
				commanding_ship.ship_activation_identity
		return {"flow_type": Constants.InteractionFlow.SHIP_ACTIVATION,
			"step": Constants.InteractionStep.SQUADRON_STEP,
			"payload": route}
	return {}


func _validate_cancelled_anti_squadron_finish(game_state: GameState,
		ship: ShipInstance) -> String:
	if game_state.completed_attack_inspection != null:
		return "No-inspection finish cannot consume a completed result."
	var marker: Dictionary = ship.pending_anti_squadron_cancellation_return()
	if marker.is_empty() or str(payload.get("attack_id", "")) \
			!= str(marker.get("attack_id", "")) \
			or str(payload.get("ship_activation_identity", "")) \
				!= str(marker.get("ship_activation_identity", "")) \
			or int(payload.get("attack_ordinal", -1)) \
				!= int(marker.get("attack_ordinal", -2)) \
			or int(payload.get("zone", -1)) != int(marker.get("zone", -2)):
		return "Stale anti-squadron cancellation-return identity."
	if ship.ship_activation_identity \
			!= str(marker["ship_activation_identity"]) \
			or ship.committed_attack_count != int(marker["attack_ordinal"]) \
			or ship.anti_squadron_attack_zone != int(marker["zone"]) \
			or game_state.current_phase != Constants.GamePhase.SHIP \
			or game_state.get_active_ship_activation() != ship:
		return "Anti-squadron iteration is no longer active."
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null or flow.flow_type \
			!= Constants.InteractionFlow.SHIP_ACTIVATION \
			or flow.step_id != Constants.InteractionStep.ATTACK_STEP \
			or flow.controller_player != player_index \
			or ship.owner_player != player_index \
			or _has_remaining_squadron_target(game_state, ship):
		return "An eligible anti-squadron target remains or the owner changed."
	return ""


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
	var all_squadrons: Array[Dictionary] = \
			SquadronKeywordRuleHelper.positions_from_state(game_state)
	var obstructions: Array = \
			EngagementResolver.obstruction_bodies_from_state(game_state)
	if SquadronKeywordRuleHelper.is_engaged_by_non_heavy(
			squadron, SquadronKeywordRuleHelper.position_from_state(squadron),
			all_squadrons, obstructions):
		return "Engaged squadron must attack an engaged enemy squadron."
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


func _validate_anti_squadron_child_finish_inspection(game_state: GameState,
		ship: ShipInstance, require_target_exhaustion: bool) -> String:
	var inspection: CompletedAttackInspection = game_state.completed_attack_inspection
	if inspection == null:
		return "No completed attack inspection is pending."
	var data: Dictionary = inspection.serialize()
	var attacker: Dictionary = data.get("attacker", {}) as Dictionary
	var defender: Dictionary = data.get("defender", {}) as Dictionary
	if str(attacker.get("kind", "")) != CurrentAttackState.KIND_SHIP \
			or int(attacker.get("player", -1)) != player_index \
			or int(attacker.get("index", -1)) \
				!= int(payload.get("ship_index", -1)) \
			or str(defender.get("kind", "")) != CurrentAttackState.KIND_SQUADRON:
		return "Completed inspection does not match this anti-squadron iteration."
	if require_target_exhaustion \
			and _has_remaining_squadron_target(game_state, ship):
		return "An eligible anti-squadron target remains."
	return ""


func _has_remaining_squadron_target(game_state: GameState,
		ship: ShipInstance) -> bool:
	var ship_index: int = int(payload.get("ship_index", -1))
	for candidate: Dictionary in \
		TargetingListBuilder.authoritative_ship_target_entries(
				game_state, player_index, ship_index):
		if int(candidate.get("attacker_zone", -1)) \
				!= ship.anti_squadron_attack_zone \
			or str(candidate.get("target_kind", "")) \
					!= CurrentAttackState.KIND_SQUADRON:
			continue
		var owner: int = int(candidate.get("target_owner", -1))
		var index: int = int(candidate.get("target_index", -1))
		var squadron: SquadronInstance = game_state.get_squadron(owner, index)
		if squadron != null and not squadron.is_destroyed() \
				and not ship.has_anti_squadron_target(owner, index):
			return true
	return false
