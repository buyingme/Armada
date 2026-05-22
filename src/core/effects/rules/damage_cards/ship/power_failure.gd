## Power Failure
##
## Static rule hook for the Power Failure damage card.
## Rules Reference: Damage Card "Power Failure" — "Your engineering value
## is reduced to half its value, rounded down." FAQ v3.3.1: multiple copies
## apply successively.
class_name PowerFailure
extends RefCounted


const RULE_ID: String = "damage_card.power_failure"
const EFFECT_ID: String = "power_failure"
const TARGET_ENGINEERING_VALUE: String = "engineering_value"

static var _rule_instance: PowerFailure = null


## Registers the repair-step engineering-value modifier hook.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = PowerFailure.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.modifier(RULE_ID,
				Constants.InteractionFlow.SHIP_ACTIVATION,
				Constants.InteractionStep.REPAIR_STEP,
				TARGET_ENGINEERING_VALUE,
				Callable(_rule_instance, "apply_engineering_modifier")),
	])


## Applies all faceup Power Failure copies to the engineering value.
func apply_engineering_modifier(context: EffectContext) -> EffectContext:
	if context == null:
		return context
	var ship: ShipInstance = context.get_meta_value("ship", null) as ShipInstance
	if ship == null:
		return context
	var copies: int = _count_power_failures(ship)
	if copies <= 0:
		return context
	var engineering_value: int = int(context.get_meta_value(
			"engineering_value", 0))
	for _copy_index: int in range(copies):
		engineering_value = floori(float(engineering_value) / 2.0)
	context.set_meta_value("engineering_value", engineering_value)
	return context


func _count_power_failures(ship: ShipInstance) -> int:
	var count: int = 0
	for card_var: Variant in ship.faceup_damage:
		if not card_var is DamageCard:
			continue
		var card: DamageCard = card_var as DamageCard
		if card.is_faceup and card.effect_id == EFFECT_ID:
			count += 1
	return count
