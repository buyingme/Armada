## Bomber Keyword
##
## Static rule hook for the Bomber squadron keyword.
## Rules Reference: RRG "Squadron Keywords" — "While attacking a ship,
## each of your critical icons adds 1 damage to the damage total."
class_name BomberKeyword
extends RefCounted


const RULE_ID: String = "squadron_keyword.bomber"
const KEYWORD_NAME: String = "Bomber"

static var _rule_instance: BomberKeyword = null


## Registers the attack-damage modifier hook for Bomber squadrons.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = BomberKeyword.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.modifier(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
				RuleSurface.TARGET_ATTACK_DAMAGE,
				Callable(_rule_instance, "modify_attack_damage")),
	])


## Counts critical icons as damage when a Bomber squadron attacks a ship.
func modify_attack_damage(context: EffectContext) -> EffectContext:
	if context == null:
		return context
	var attacker: SquadronInstance = context.attacker as SquadronInstance
	if attacker == null or not _has_bomber(attacker):
		return context
	if not context.defender is ShipInstance:
		return context
	var bomber_damage: int = Dice.calculate_damage(context.dice_results)
	if bomber_damage > context.damage_total:
		context.damage_total = bomber_damage
	return context


func _has_bomber(squadron: SquadronInstance) -> bool:
	if squadron.squadron_data == null:
		return false
	for keyword_var: Variant in squadron.squadron_data.keywords:
		if not keyword_var is Dictionary:
			continue
		var keyword: Dictionary = keyword_var as Dictionary
		if str(keyword.get("name", "")).to_lower() == KEYWORD_NAME.to_lower():
			return true
	return false
