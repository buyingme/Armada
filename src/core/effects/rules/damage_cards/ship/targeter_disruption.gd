## Targeter Disruption
##
## Static rule hook for the Targeter Disruption damage card.
## Rules Reference: Damage Card "Targeter Disruption" — "While attacking,
## you cannot resolve critical effects."
class_name TargeterDisruption
extends RefCounted


const RULE_ID: String = "damage_card.targeter_disruption"
const EFFECT_ID: String = "targeter_disruption"
const REJECTION_REASON: String = \
		"Targeter Disruption: this ship cannot resolve critical effects."

static var _rule_instance: TargeterDisruption = null


## Registers the critical-effect blocker hook.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = TargeterDisruption.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.blocker(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
				RuleSurface.TARGET_CRITICAL_EFFECT,
				Callable(_rule_instance, "block_critical_effect")),
	])


## Returns blocker metadata when the attacking ship has Targeter Disruption.
func block_critical_effect(context: EffectContext) -> Dictionary:
	if context == null:
		return _not_blocked()
	var attacker: ShipInstance = context.attacker as ShipInstance
	if attacker != null and _has_targeter_disruption(attacker):
		return _blocked(REJECTION_REASON)
	return _not_blocked()


func _has_targeter_disruption(ship: ShipInstance) -> bool:
	for card_var: Variant in ship.faceup_damage:
		if not card_var is DamageCard:
			continue
		var card: DamageCard = card_var as DamageCard
		if card.is_faceup and card.effect_id == EFFECT_ID:
			return true
	return false


func _blocked(reason: String) -> Dictionary:
	return {"blocked": true, "reason": reason}


func _not_blocked() -> Dictionary:
	return {"blocked": false, "reason": ""}
