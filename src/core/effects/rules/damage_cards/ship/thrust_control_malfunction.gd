## Thrust Control Malfunction
##
## Static rule hook for the Thrust Control Malfunction damage card.
## Rules Reference: Damage Card "Thrust Control Malfunction" — "The yaw
## value for the last adjustable joint at your current speed is reduced by 1."
class_name ThrustControlMalfunction
extends RefCounted


const RULE_ID: String = "damage_card.thrust_control_malfunction"
const EFFECT_ID: String = "thrust_control_malfunction"

static var _rule_instance: ThrustControlMalfunction = null


## Registers the maneuver-step yaw modifier hook.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = ThrustControlMalfunction.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.modifier(RULE_ID,
				Constants.InteractionFlow.SHIP_ACTIVATION,
				Constants.InteractionStep.MANEUVER_STEP,
				RuleSurface.TARGET_MANEUVER_YAW,
				Callable(_rule_instance, "apply_yaw_modifier")),
	])


## Reduces the last adjustable yaw value at the damaged ship's current speed.
func apply_yaw_modifier(context: EffectContext) -> EffectContext:
	if context == null:
		return context
	var ship: ShipInstance = context.get_meta_value("ship", null) as ShipInstance
	if ship == null:
		return context
	var copies: int = _count_faceup_damage(ship)
	if copies <= 0 or int(context.get_meta_value("speed", 0)) != ship.current_speed:
		return context
	var raw_values: Variant = context.get_meta_value("yaw_values", [])
	if not raw_values is Array:
		return context
	var yaw_values: Array = (raw_values as Array).duplicate()
	var joint_index: int = _last_adjustable_joint(yaw_values)
	if joint_index >= 0:
		yaw_values[joint_index] = maxi(0, int(yaw_values[joint_index]) - copies)
		context.set_meta_value("yaw_values", yaw_values)
	return context


func _last_adjustable_joint(yaw_values: Array) -> int:
	for index: int in range(yaw_values.size() - 1, -1, -1):
		if int(yaw_values[index]) > 0:
			return index
	return -1


func _count_faceup_damage(ship: ShipInstance) -> int:
	var count: int = 0
	for card_var: Variant in ship.faceup_damage:
		if not card_var is DamageCard:
			continue
		var card: DamageCard = card_var as DamageCard
		if card.is_faceup and card.effect_id == EFFECT_ID:
			count += 1
	return count
