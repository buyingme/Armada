## Purpose-specific, read-only consistency policy for a complete Counter
## publication and its canonical parent or legitimate inspection witness.
class_name CounterPublicationConsistency
extends RefCounted


## The same owner comparison used after reconstruction, applied to a detached
## candidate before a publication command installs it.
static func candidate_matches_active_parent(state: GameState,
		candidate: InteractionFlow) -> bool:
	if state == null or candidate == null \
			or state.completed_attack_inspection != null:
		return false
	var parent: CurrentAttackState = state.current_attack_state
	return parent != null and parent.active \
			and parent.counter_disposition \
					== CurrentAttackState.COUNTER_UNDECIDED \
			and _matches_active_parent(state, candidate, parent)


static func reconstructed_state_is_consistent(state: GameState) -> bool:
	if state == null:
		return false
	var flow: InteractionFlow = state.interaction_flow
	var is_counter_step: bool = flow != null \
			and flow.flow_type == Constants.InteractionFlow.ATTACK \
			and flow.step_id == Constants.InteractionStep.ATTACK_COUNTER_CHOICE
	var parent: CurrentAttackState = state.current_attack_state
	var inspection: CompletedAttackInspection = \
			state.completed_attack_inspection
	if parent != null and parent.active:
		if is_counter_step:
			return _matches_active_parent(state, flow, parent)
		return parent.counter_disposition \
				== CurrentAttackState.COUNTER_UNDECIDED
	if inspection != null:
		var witness: String = inspection.counter_disposition()
		if witness != CurrentAttackState.COUNTER_UNDECIDED:
			if not _eligible_inspection_source(state, inspection):
				return false
			if witness == CurrentAttackState.COUNTER_ACCEPTED:
				return is_counter_step \
						and _matches_inspection(state, flow, inspection)
			return not is_counter_step
		if _eligible_inspection_source(state, inspection):
			return false
	return not is_counter_step


static func _matches_active_parent(state: GameState, flow: InteractionFlow,
		parent: CurrentAttackState) -> bool:
	if parent.stage != CurrentAttackState.STAGE_RESOLVED \
			or parent.attacker_kind != CurrentAttackState.KIND_SQUADRON \
			or parent.defender_kind != CurrentAttackState.KIND_SQUADRON:
		return false
	var original: SquadronInstance = state.get_squadron(
			parent.attacker_player, parent.attacker_index)
	var counter: SquadronInstance = state.get_squadron(
			parent.defender_player, parent.defender_index)
	if not _eligible(parent.attack_kind, original, counter):
		return false
	var outcome: Dictionary = parent.resolved_outcome
	return _matches_flow(flow, parent.attack_id, parent.attacker_player,
			parent.attacker_index, parent.defender_player,
			parent.defender_index, counter, outcome,
			parent.counter_disposition)


static func _eligible_inspection_source(state: GameState,
		inspection: CompletedAttackInspection) -> bool:
	var data: Dictionary = inspection.serialize()
	var attacker: Dictionary = data.get("attacker", {}) as Dictionary
	var defender: Dictionary = data.get("defender", {}) as Dictionary
	if attacker.get("kind") != "squadron" \
			or defender.get("kind") != "squadron":
		return false
	var original: SquadronInstance = state.get_squadron(
			int(attacker.get("player", -1)), int(attacker.get("index", -1)))
	var counter: SquadronInstance = state.get_squadron(
			int(defender.get("player", -1)), int(defender.get("index", -1)))
	return _eligible(str(data.get("attack_kind", "")), original, counter)


static func _matches_inspection(state: GameState, flow: InteractionFlow,
		inspection: CompletedAttackInspection) -> bool:
	var data: Dictionary = inspection.serialize()
	var attacker: Dictionary = data["attacker"] as Dictionary
	var defender: Dictionary = data["defender"] as Dictionary
	var counter: SquadronInstance = state.get_squadron(
			int(defender["player"]), int(defender["index"]))
	return _matches_flow(flow, inspection.source_attack_id(),
			int(attacker["player"]), int(attacker["index"]),
			int(defender["player"]), int(defender["index"]), counter,
			data["outcome"] as Dictionary, inspection.counter_disposition())


static func _eligible(attack_kind: String, original: SquadronInstance,
		counter: SquadronInstance) -> bool:
	return original != null and not original.is_destroyed() \
			and CounterKeyword.is_counter_trigger_available(
				attack_kind, original, counter)


static func _matches_flow(flow: InteractionFlow, source: String,
		original_player: int, original_index: int, counter_player: int,
		counter_index: int, counter: SquadronInstance, outcome: Dictionary,
		disposition: String) -> bool:
	if flow == null or counter == null \
			or flow.flow_type != Constants.InteractionFlow.ATTACK \
			or flow.step_id != Constants.InteractionStep.ATTACK_COUNTER_CHOICE \
			or flow.controller_player != counter_player:
		return false
	var payload: Dictionary = flow.payload
	if payload.get("attack_id") != source \
			or payload.get("counter_attack_available") != true \
			or typeof(payload.get("counter_attack_available")) != TYPE_BOOL:
		return false
	var identities: Dictionary = {
		"counter_attacker_player": counter_player,
		"counter_attacker_squadron_index": counter_index,
		"counter_target_player": original_player,
		"counter_target_squadron_index": original_index,
		"counter_controller_player": counter_player,
	}
	for key: String in identities:
		if typeof(payload.get(key)) != TYPE_INT \
				or payload[key] != identities[key]:
			return false
	# Attack FSM patches retain the original declaration identity. When one of
	# those existing members is present, it must still describe this parent.
	var retained: Dictionary = {
		"attacker_kind": "squadron",
		"attacker_player": original_player,
		"attacker_squadron_index": original_index,
		"target_kind": "squadron",
		"defender_player": counter_player,
		"target_squadron_index": counter_index,
	}
	for key: String in retained:
		if payload.has(key) and payload[key] != retained[key]:
			return false
	if payload.has("controller_player") \
			and (typeof(payload["controller_player"]) != TYPE_INT \
				or payload["controller_player"] != counter_player):
		return false
	var expected_count: int = SquadronKeywordRuleHelper.get_keyword_value(
			counter, SquadronKeywordRuleHelper.KEYWORD_COUNTER)
	if expected_count <= 0 \
			or not _pool_matches(payload.get("counter_dice_pool"),
				expected_count):
		return false
	if outcome.get("target_kind") != "squadron" \
			or typeof(outcome.get("requested_hull_damage")) != TYPE_INT \
			or int(outcome["requested_hull_damage"]) < 0 \
			or typeof(payload.get("final_damage")) != TYPE_INT \
			or payload["final_damage"] != outcome["requested_hull_damage"]:
		return false
	if disposition == CurrentAttackState.COUNTER_UNDECIDED:
		return not payload.has("counter_choice_accepted")
	if typeof(payload.get("counter_choice_accepted")) != TYPE_BOOL:
		return false
	return payload["counter_choice_accepted"] \
			== (disposition == CurrentAttackState.COUNTER_ACCEPTED)


static func _pool_matches(raw: Variant, expected_blue: int) -> bool:
	if not raw is Dictionary:
		return false
	var normalized: Dictionary = {}
	for raw_key: Variant in (raw as Dictionary).keys():
		if typeof(raw_key) != TYPE_STRING \
				or typeof((raw as Dictionary)[raw_key]) != TYPE_INT:
			return false
		var count: int = int((raw as Dictionary)[raw_key])
		if count < 0:
			return false
		if count > 0:
			normalized[str(raw_key).to_upper()] = count
	return normalized == {"BLUE": expected_blue}
