## Compartment Fire
##
## Static rule hook for the Compartment Fire damage card.
## Rules Reference: Damage Card "Compartment Fire" —
## "You cannot ready your defense tokens during the Status Phase."
class_name CompartmentFire
extends RefCounted


const RULE_ID: String = "damage_card.compartment_fire"
const EFFECT_ID: String = "compartment_fire"

static var _rule_instance: CompartmentFire = null


## Registers the status-cleanup defense-token readying modifier hook.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = CompartmentFire.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.modifier(RULE_ID,
				Constants.InteractionFlow.STATUS_CLEANUP,
				Constants.InteractionStep.STATUS_CLEANUP_STEP,
				StatusPhaseCleanupCommand.TARGET_DEFENSE_TOKEN_READYING,
				Callable(_rule_instance, "apply_status_ready_tokens")),
	])


## Applies the card's status-phase readying blocker to the supplied context.
## The context must include `ship` metadata when called from status cleanup.
func apply_status_ready_tokens(context: EffectContext) -> EffectContext:
	if context == null:
		return context
	var ship_var: Variant = context.get_meta_value("ship", null)
	if not ship_var is ShipInstance:
		return context
	if _has_compartment_fire(ship_var as ShipInstance):
		context.cancelled = true
	return context


func _has_compartment_fire(ship: ShipInstance) -> bool:
	for card_var: Variant in ship.faceup_damage:
		if not card_var is DamageCard:
			continue
		var card: DamageCard = card_var as DamageCard
		if card.effect_id == EFFECT_ID:
			return true
	return false
