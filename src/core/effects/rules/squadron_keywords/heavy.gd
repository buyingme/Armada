## Heavy Keyword
##
## Static rule hook for the Heavy squadron keyword.
## Rules Reference: RRG "Squadron Keywords" — "You do not prevent engaged
## squadrons from attacking ships or moving."
class_name HeavyKeyword
extends RefCounted


const RULE_ID: String = "squadron_keyword.heavy"
const REJECTION_REASON: String = \
		"Engaged by a non-Heavy squadron: must attack a squadron."

static var _rule_instance: HeavyKeyword = null


## Registers direct attack-flow validation for squadron ship attacks.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = HeavyKeyword.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.validator(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_DECLARE,
				RuleSurface.COMMAND_PUBLISH_ATTACK_FLOW,
				Callable(_rule_instance, "validate_attack_flow_publish")),
	])


## Rejects direct ship-target publications by Heavy-blocked squadrons.
func validate_attack_flow_publish(game_state: GameState,
		command: GameCommand) -> Dictionary:
	if game_state == null or command == null:
		return _allow()
	var flow_payload: Dictionary = command.payload.get("flow_payload", {})
	if not _is_squadron_ship_attack(flow_payload):
		return _allow()
	var attacker: SquadronInstance = _published_attacker(
			game_state, flow_payload)
	if _can_attack_ship(game_state, attacker):
		return _allow()
	return _deny(REJECTION_REASON)


func _is_squadron_ship_attack(flow_payload: Dictionary) -> bool:
	return str(flow_payload.get("attacker_kind", "")) == "squadron" \
			and str(flow_payload.get("target_kind", "")) == "ship"


func _published_attacker(game_state: GameState,
		flow_payload: Dictionary) -> SquadronInstance:
	var owner: int = int(flow_payload.get("attacker_player", -1))
	var squadron_index: int = int(
			flow_payload.get("attacker_squadron_index", -1))
	return game_state.get_squadron(owner, squadron_index)


func _can_attack_ship(game_state: GameState,
		attacker: SquadronInstance) -> bool:
	var all_squadrons: Array[Dictionary] = \
			SquadronKeywordRuleHelper.positions_from_state(game_state)
	var obstruction_bodies: Array = \
			EngagementResolver.obstruction_bodies_from_state(game_state)
	var attacker_pos: Vector2 = \
			SquadronKeywordRuleHelper.position_from_state(attacker)
	return SquadronKeywordRuleHelper.can_attack_ship_with_heavy_rule(
			attacker, attacker_pos, all_squadrons, obstruction_bodies)


func _allow() -> Dictionary:
	return {"allowed": true, "reason": ""}


func _deny(reason: String) -> Dictionary:
	return {"allowed": false, "reason": reason}
