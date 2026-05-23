## Escort Keyword
##
## Static rule hook for the Escort squadron keyword.
## Rules Reference: RRG "Squadron Keywords" — "Squadrons you are engaged
## with cannot attack squadrons that lack escort unless performing a counter
## attack."
class_name EscortKeyword
extends RefCounted


const RULE_ID: String = "squadron_keyword.escort"
const REJECTION_REASON: String = \
		"Escort: must attack an engaged squadron with Escort."

static var _rule_instance: EscortKeyword = null


## Registers attack-target blocking and direct publish validation hooks.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = EscortKeyword.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.blocker(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_DECLARE,
				RuleSurface.TARGET_ATTACK_TARGET,
				Callable(_rule_instance, "block_attack_target")),
		FlowHook.validator(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_DECLARE,
				RuleSurface.COMMAND_PUBLISH_ATTACK_FLOW,
				Callable(_rule_instance, "validate_attack_flow_publish")),
	])


## Returns blocker metadata when Escort makes a squadron target illegal.
func block_attack_target(context: EffectContext) -> Dictionary:
	if context == null:
		return _not_blocked()
	var attacker: SquadronInstance = context.attacker as SquadronInstance
	var target: SquadronInstance = context.defender as SquadronInstance
	if _is_blocked(attacker, target, context.metadata):
		return _blocked(REJECTION_REASON)
	return _not_blocked()


## Rejects direct attack-flow publications for illegal Escort targets.
func validate_attack_flow_publish(game_state: GameState,
		command: GameCommand) -> Dictionary:
	if game_state == null or command == null:
		return _allow()
	var flow_payload: Dictionary = command.payload.get("flow_payload", {})
	if not _is_squadron_target_publish(flow_payload):
		return _allow()
	var attacker: SquadronInstance = _published_squadron(
			game_state, flow_payload, "attacker")
	var target: SquadronInstance = _published_squadron(
			game_state, flow_payload, "target")
	var metadata: Dictionary = _metadata_from_state(game_state, flow_payload)
	if _is_blocked(attacker, target, metadata):
		return _deny(REJECTION_REASON)
	return _allow()


func _is_blocked(attacker: SquadronInstance,
		target: SquadronInstance,
		metadata: Dictionary) -> bool:
	var all_squadrons: Array[Dictionary] = _typed_squadron_entries(
			metadata.get(SquadronKeywordRuleHelper.PAYLOAD_ALL_SQUADRONS, []))
	return SquadronKeywordRuleHelper.is_escort_target_blocked(
			attacker,
			metadata.get(SquadronKeywordRuleHelper.PAYLOAD_ATTACKER_POS,
					Vector2.ZERO),
			target,
			metadata.get(SquadronKeywordRuleHelper.PAYLOAD_TARGET_POS,
					Vector2.ZERO),
			all_squadrons,
			str(metadata.get(SquadronKeywordRuleHelper.PAYLOAD_ATTACK_KIND,
					SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD)),
			metadata.get(SquadronKeywordRuleHelper.META_OBSTRUCTION_BODIES, []))


func _typed_squadron_entries(raw_entries: Variant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not raw_entries is Array:
		return entries
	for entry_var: Variant in raw_entries as Array:
		if entry_var is Dictionary:
			entries.append(entry_var as Dictionary)
	return entries


func _is_squadron_target_publish(flow_payload: Dictionary) -> bool:
	return str(flow_payload.get("attacker_kind", "")) == "squadron" \
			and str(flow_payload.get("target_kind", "")) == "squadron"


func _published_squadron(game_state: GameState,
		flow_payload: Dictionary,
		prefix: String) -> SquadronInstance:
	var owner: int = int(flow_payload.get("%s_player" % prefix, -1))
	var key: String = "%s_squadron_index" % prefix
	if prefix == "target":
		owner = int(flow_payload.get("defender_player",
				1 - int(flow_payload.get("attacker_player", 0))))
	var squadron_index: int = int(flow_payload.get(key, -1))
	return game_state.get_squadron(owner, squadron_index)


func _metadata_from_state(game_state: GameState,
		flow_payload: Dictionary) -> Dictionary:
	var attacker: SquadronInstance = _published_squadron(
			game_state, flow_payload, "attacker")
	var target: SquadronInstance = _published_squadron(
			game_state, flow_payload, "target")
	return {
		SquadronKeywordRuleHelper.PAYLOAD_ATTACKER_POS:
				SquadronKeywordRuleHelper.position_from_state(attacker),
		SquadronKeywordRuleHelper.PAYLOAD_TARGET_POS:
				SquadronKeywordRuleHelper.position_from_state(target),
		SquadronKeywordRuleHelper.PAYLOAD_ALL_SQUADRONS:
				SquadronKeywordRuleHelper.positions_from_state(game_state),
		SquadronKeywordRuleHelper.PAYLOAD_ATTACK_KIND:
				SquadronKeywordRuleHelper.attack_kind_from_payload(flow_payload),
		SquadronKeywordRuleHelper.META_OBSTRUCTION_BODIES:
				EngagementResolver.obstruction_bodies_from_state(game_state),
	}


func _allow() -> Dictionary:
	return {"allowed": true, "reason": ""}


func _deny(reason: String) -> Dictionary:
	return {"allowed": false, "reason": reason}


func _blocked(reason: String) -> Dictionary:
	return {"blocked": true, "reason": reason}


func _not_blocked() -> Dictionary:
	return {"blocked": false, "reason": ""}
