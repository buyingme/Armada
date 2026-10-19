## Completes and retires one resolved individual attack.
class_name CompleteAttackCommand
extends GameCommand

const TYPE: String = "complete_attack"
const CONTINUATION_SQUADRON: String = "squadron_target"
const CONTINUATION_NORMAL_ATTACK: String = "normal_attack"
const CONTINUATION_ATTACK_STEP_COMPLETE: String = "attack_step_complete"
const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")
const H9_RULE: GDScript = preload(
		"res://src/core/effects/rules/upgrades/turbolasers/h9_turbolasers.gd")
const COMPLETED_ATTACK_INSPECTION: GDScript = preload(
		"res://src/core/state/completed_attack_inspection.gd")
const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")

var _log: GameLogger = GameLogger.new("CompleteAttackCommand")

static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int, pl: Dictionary) -> GameCommand:
		return CompleteAttackCommand.new(player, pl))

func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)

func validate(game_state: GameState) -> String:
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return "No current attack."
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if attack.stage != CurrentAttackState.STAGE_RESOLVED \
			or attack.damage_stage != CurrentAttackState.DAMAGE_RESOLVED:
		return "Current attack has not resolved damage."
	if player_index != attack.attacker_player:
		return "Attack completion belongs to the attacker."
	if game_state.timing_window_state.active:
		return "Cannot complete while a timing window is active."
	if game_state.has_completed_attack_inspection():
		return "A completed attack inspection is already pending."
	if attack.resolved_outcome.is_empty():
		return "Current attack has no terminal resolved outcome."
	var counter_parent: bool = attack.counter_disposition \
			!= CurrentAttackState.COUNTER_UNDECIDED
	var counter_child: bool = attack.attack_kind \
			== SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER
	if counter_parent:
		if not CounterPublicationConsistency \
				.reconstructed_state_is_consistent(game_state):
			return "Counter parent decision and publication disagree."
		if attack.counter_disposition == CurrentAttackState.COUNTER_ACCEPTED \
				and game_state.get_distinct_controlling_principal_ids(
						MatchPlayerControlBinding.KIND_HUMAN).is_empty():
			return "Accepted Counter parent requires atomic child Begin."
		if attack.counter_disposition == CurrentAttackState.COUNTER_DECLINED \
				and _counter_enclosing_route(game_state, attack) == null:
			return "Counter parent has no canonical enclosing route."
	elif game_state.interaction_flow != null \
			and game_state.interaction_flow.flow_type \
					== Constants.InteractionFlow.ATTACK \
			and game_state.interaction_flow.step_id \
					== Constants.InteractionStep.ATTACK_COUNTER_CHOICE:
		return "Counter choice has not committed."
	if counter_child and game_state.get_distinct_controlling_principal_ids(
			MatchPlayerControlBinding.KIND_HUMAN).is_empty() \
			and _counter_enclosing_route(game_state, attack) == null:
		return "Counter child has no canonical enclosing route."
	return ""

func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var attack_id: String = attack.attack_id
	var ship: ShipInstance = _tracked_attacker_ship(game_state, attack)
	if ship != null:
		_log.debug("Complete before retiring individual attack: %s" %
				JSON.stringify(ship.attack_progress_snapshot()))
	var exhaust_squadron_iteration: bool = ship != null \
			and ship.anti_squadron_attack_zone >= 0 \
			and not _has_remaining_squadron_target(game_state, attack, ship)
	var required_ids: Array[String] = \
		game_state.get_distinct_controlling_principal_ids(
				MatchPlayerControlBinding.KIND_HUMAN)
	var counter_parent: bool = attack.counter_disposition \
			!= CurrentAttackState.COUNTER_UNDECIDED
	var counter_child: bool = attack.attack_kind \
			== SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER
	var enclosing_route: InteractionFlow = null
	if (counter_parent and attack.counter_disposition \
			== CurrentAttackState.COUNTER_DECLINED) \
			or (counter_child and required_ids.is_empty()):
		enclosing_route = _counter_enclosing_route(game_state, attack)
		if enclosing_route == null:
			return {}
	var inspection: CompletedAttackInspection = null
	if not required_ids.is_empty():
		inspection = COMPLETED_ATTACK_INSPECTION.create_from_attack(
				attack, attack.resolved_outcome, required_ids)
		if inspection == null:
			return {}
	if not game_state.set_current_attack_state(CurrentAttackState.inactive()):
		return {}
	if inspection != null and not game_state.install_completed_attack_inspection(
				inspection):
		game_state.set_current_attack_state(attack)
		return {}
	if enclosing_route != null:
		game_state.interaction_flow = enclosing_route
	# PAC-OD-007 retains an exhausted anti-squadron iteration while a result
	# inspection is pending. SkipAttackCommand(squadron_done) closes it later.
	if exhaust_squadron_iteration and inspection == null:
		ship.end_anti_squadron_attack()
	var cleared: Array[String] = ECM_SCRIPT.clear_attack_state(
			game_state, attack_id)
	var h9_cleared: Array[String] = H9_RULE.clear_attack_guards(
			game_state, attack_id)
	var result: Dictionary = {
		"attack_id": attack_id,
		"completed": true,
		"inspection_id": inspection.inspection_id() if inspection != null else "",
		"ecm_cleared_runtime_upgrade_ids": cleared,
		"h9_cleared_runtime_upgrade_ids": h9_cleared,
	}
	if ship != null:
		result["continuation"] = _derive_ship_continuation(ship)
		_log.debug("Complete continuation=%s progress=%s" % [
			str(result["continuation"]),
			JSON.stringify(ship.attack_progress_snapshot()),
		])
	return result


## The retained original Squadron is the sole owner of its enclosing action.
## A Counter child reverses the parent roles, so its defender is the original.
func _counter_enclosing_route(game_state: GameState,
		attack: CurrentAttackState) -> InteractionFlow:
	var child: bool = attack.attack_kind \
			== SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER
	var player: int = attack.defender_player if child else attack.attacker_player
	var index: int = attack.defender_index if child else attack.attacker_index
	var squadron: SquadronInstance = game_state.get_squadron(player, index)
	if squadron == null or squadron.activated_this_round \
			or squadron != game_state.get_active_squadron_activation() \
			or squadron.attack_action_disposition \
					!= SquadronInstance.ATTACK_ACTION_BEGUN \
			or squadron.activation_id.is_empty():
		return null
	var context: String = squadron.activation_context
	var route_payload: Dictionary = {
		"squadron_index": index,
		"activation_id": squadron.activation_id,
		"activation_context": context,
	}
	if context == SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE:
		if game_state.current_phase != Constants.GamePhase.SQUADRON \
				or game_state.squadron_phase_controller_player != player:
			return null
		return FLOW_SPEC_SCRIPT.make_interaction_flow(
				Constants.InteractionFlow.SQUADRON_ACTIVATION,
				Constants.InteractionStep.ACTION_CHOICE, game_state,
				{"active_player": player}, Constants.Visibility.ALL,
				route_payload)
	if context != SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND \
			or game_state.current_phase != Constants.GamePhase.SHIP:
		return null
	var ship: ShipInstance = game_state.get_ship(
			squadron.commanding_ship_player, squadron.commanding_ship_index)
	if ship == null or ship != game_state.get_active_ship_activation() \
			or ship.owner_player != player \
			or ship.squadron_command_opportunity_disposition \
					!= ShipInstance.ACTIVATION_DISPOSITION_OPEN:
		return null
	route_payload["ship_index"] = squadron.commanding_ship_index
	route_payload["ship_activation_identity"] = ship.ship_activation_identity
	return FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.SQUADRON_STEP, game_state,
			{"active_player": player}, Constants.Visibility.ALL,
			route_payload)


func _tracked_attacker_ship(game_state: GameState,
		attack: CurrentAttackState) -> ShipInstance:
	if attack.attack_kind != SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD \
			or attack.attacker_kind != CurrentAttackState.KIND_SHIP:
		return null
	var ship: ShipInstance = game_state.get_ship(
			attack.attacker_player, attack.attacker_index)
	return ship if ship != null and ship.attack_step_active else null


func _has_remaining_squadron_target(game_state: GameState,
		attack: CurrentAttackState, ship: ShipInstance) -> bool:
	if attack.defender_kind != CurrentAttackState.KIND_SQUADRON:
		return false
	for candidate: Dictionary in \
			TargetingListBuilder.authoritative_ship_target_entries(
					game_state, attack.attacker_player, attack.attacker_index):
		if int(candidate.get("attacker_zone", -1)) \
				!= ship.anti_squadron_attack_zone \
				or str(candidate.get("target_kind", "")) \
						!= CurrentAttackState.KIND_SQUADRON:
			continue
		var target_owner: int = int(candidate.get("target_owner", -1))
		var target_index: int = int(candidate.get("target_index", -1))
		var squadron: SquadronInstance = game_state.get_squadron(
				target_owner, target_index)
		if squadron == null or squadron.is_destroyed() \
				or ship.has_anti_squadron_target(target_owner, target_index):
			continue
		return true
	return false


func _derive_ship_continuation(ship: ShipInstance) -> String:
	if ship.anti_squadron_attack_zone >= 0:
		return CONTINUATION_SQUADRON
	if ship.committed_attack_count < 2:
		return CONTINUATION_NORMAL_ATTACK
	return CONTINUATION_ATTACK_STEP_COMPLETE
