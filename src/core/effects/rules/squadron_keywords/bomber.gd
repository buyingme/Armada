## Bomber Keyword
##
## Static rule hook for the Bomber squadron keyword.
## Rules Reference: RRG "Squadron Keywords" — "While attacking a ship,
## each of your critical icons adds 1 damage to the damage total and you can
## resolve a critical effect."
class_name BomberKeyword
extends RefCounted


const RULE_ID: String = "squadron_keyword.bomber"
const KEYWORD_NAME: String = "Bomber"

static var _rule_instance: BomberKeyword = null


const NON_BOMBER_CRIT_REASON: String = \
		"Non-Bomber squadrons cannot resolve ship critical effects."


## Registers attack-damage and critical-effect hooks for Bomber squadrons.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = BomberKeyword.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.modifier(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
				RuleSurface.TARGET_ATTACK_DAMAGE,
				Callable(_rule_instance, "modify_attack_damage")),
		FlowHook.blocker(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
				RuleSurface.TARGET_CRITICAL_EFFECT,
				Callable(_rule_instance, "block_non_bomber_critical")),
	])


## Counts critical icons as damage when a Bomber squadron attacks a ship.
func modify_attack_damage(context: EffectContext) -> EffectContext:
	if context == null:
		return context
	var attacker: SquadronInstance = context.attacker as SquadronInstance
	if attacker == null or not SquadronKeywordRuleHelper.has_keyword(
			attacker, SquadronKeywordRuleHelper.KEYWORD_BOMBER):
		return context
	if not context.defender is ShipInstance:
		return context
	var bomber_damage: int = Dice.calculate_damage(context.dice_results)
	if bomber_damage > context.damage_total:
		context.damage_total = bomber_damage
	return context


## Blocks standard critical effects for non-Bomber squadron ship attacks.
func block_non_bomber_critical(context: EffectContext) -> Dictionary:
	if context == null:
		return _not_blocked()
	var attacker: SquadronInstance = context.attacker as SquadronInstance
	if attacker == null or not context.defender is ShipInstance:
		return _not_blocked()
	if SquadronKeywordRuleHelper.has_keyword(
			attacker, SquadronKeywordRuleHelper.KEYWORD_BOMBER):
		return _not_blocked()
	return _blocked(NON_BOMBER_CRIT_REASON)


func _blocked(reason: String) -> Dictionary:
	return {"blocked": true, "reason": reason}


func _not_blocked() -> Dictionary:
	return {"blocked": false, "reason": ""}
