## DamageCardEffect
##
## A configurable [GameEffect] subclass that implements legacy persistent
## damage card effects not yet migrated to RuleRegistry. The behaviour is
## driven by the [member effect_id] string, which maps to the card's JSON
## `effect_id` field.
##
## Each persistent card registers one DamageCardEffect instance when dealt
## faceup. The effect is unregistered when the card is repaired (discarded)
## or the ship is destroyed.
##
## Rules Reference: RRG "Damage Cards", p.4; individual card texts.
class_name DamageCardEffect
extends GameEffect


## Identifies which damage card effect this instance implements.
## Must match the `effect_id` from damage_cards.json.
var effect_id: String = ""

## Reference to the DamageCard this effect is attached to.
## Preserved for legacy persistent effects that need card identity.
var damage_card: DamageCard = null


func _init() -> void:
	source_type = EffectSource.DAMAGE_CARD


## Returns the hook points this effect responds to, based on [member effect_id].
func get_hooks() -> Array[StringName]:
	match effect_id:
		"coolant_discharge":
			return [&"ATTACK_VALIDATE_TARGET", &"ATTACK_CALC_DAMAGE"]
		"depowered_armament":
			return [&"ATTACK_VALIDATE_TARGET"]
		"disengaged_fire_control":
			return [&"ATTACK_VALIDATE_TARGET"]
		"blinded_gunners":
			return [&"ATTACK_SPEND_ACCURACY"]
		"targeter_disruption":
			return [&"ATTACK_RESOLVE_CRITICAL"]
		_:
			return _get_non_attack_hooks()


## Returns hooks for movement, command, and repair effects.
func _get_non_attack_hooks() -> Array[StringName]:
	match effect_id:
		"thrust_control_malfunction":
			return [&"MANEUVER_DETERMINE_YAWS"]
		"ruptured_engine", "damaged_controls":
			return [&"AFTER_MANEUVER_EXECUTE"]
		"thruster_fissure":
			return [&"ON_SPEED_CHANGE"]
		"power_failure":
			return [&"CALC_ENGINEERING_VALUE"]
		"life_support_failure":
			return [&"ON_COMMAND_TOKEN_GAIN"]
		_:
			return []


## Returns true if this effect should fire for the given context.
## Each effect validates that the owner ship is the relevant participant.
func should_trigger(context: EffectContext) -> bool:
	if context == null or owner == null:
		return false
	match effect_id:
		"coolant_discharge":
			return _trigger_coolant_discharge(context)
		"depowered_armament":
			return _trigger_depowered_armament(context)
		"disengaged_fire_control":
			return _trigger_disengaged_fire_control(context)
		"blinded_gunners":
			return context.attacker == owner
		"targeter_disruption":
			return context.attacker == owner
		_:
			return _should_trigger_non_attack(context)


## Checks non-attack effects (movement, command, repair, status).
func _should_trigger_non_attack(context: EffectContext) -> bool:
	match effect_id:
		"thrust_control_malfunction", "thruster_fissure", \
				"power_failure", "life_support_failure":
			return context.get_meta_value("ship", null) == owner
		"ruptured_engine":
			return _trigger_ruptured_engine(context)
		"damaged_controls":
			return _trigger_damaged_controls(context)
		_:
			return false


## Mutates the context to apply this effect.
func resolve(context: EffectContext) -> void:
	match effect_id:
		"coolant_discharge":
			_resolve_coolant_discharge(context)
		"depowered_armament", "disengaged_fire_control", \
				"blinded_gunners", "life_support_failure":
			context.cancelled = true
		"targeter_disruption":
			context.critical_allowed = false
		_:
			_resolve_non_attack(context)


## Resolves movement, command, and repair effects.
func _resolve_non_attack(context: EffectContext) -> void:
	match effect_id:
		"thrust_control_malfunction":
			_resolve_thrust_control(context)
		"ruptured_engine", "damaged_controls", "thruster_fissure":
			context.set_meta_value("persistent_effect_id", effect_id)
			_resolve_suffer_facedown(context)
		"power_failure":
			_resolve_power_failure(context)


# ---------------------------------------------------------------------------
# Trigger helpers
# ---------------------------------------------------------------------------


## Coolant Discharge: Only attack 1 ship per activation.
## ATTACK_VALIDATE_TARGET — cancel if this ship has already attacked.
## ATTACK_CALC_DAMAGE — add +1 damage at close range.
func _trigger_coolant_discharge(context: EffectContext) -> bool:
	if context.attacker != owner:
		return false
	match context.hook:
		&"ATTACK_VALIDATE_TARGET":
			var attacks: int = int(
					context.get_meta_value("ship_attacks_this_round", 0))
			return attacks >= 1
		&"ATTACK_CALC_DAMAGE":
			return context.range_band == "close"
		_:
			return false


## Depowered Armament: Cannot attack at long range.
func _trigger_depowered_armament(context: EffectContext) -> bool:
	return context.attacker == owner and context.range_band == "long"


## Disengaged Fire Control: Cannot attack obstructed targets.
func _trigger_disengaged_fire_control(context: EffectContext) -> bool:
	return context.attacker == owner and \
			context.get_meta_value("is_obstructed", false) as bool


## Ruptured Engine: Suffer 1 damage after maneuver if speed > 1.
func _trigger_ruptured_engine(context: EffectContext) -> bool:
	if context.get_meta_value("ship", null) != owner:
		return false
	var speed: int = int(context.get_meta_value("ship_speed", 0))
	return speed > 1


## Damaged Controls: Suffer 1 extra facedown when overlapping a ship or obstacle.
## Rules Reference: "Damaged Controls" card text, p.5.
func _trigger_damaged_controls(context: EffectContext) -> bool:
	if context.get_meta_value("ship", null) != owner:
		return false
	return context.get_meta_value("did_overlap", false) as bool


# ---------------------------------------------------------------------------
# Resolve helpers
# ---------------------------------------------------------------------------


## Coolant Discharge: ATTACK_VALIDATE_TARGET → cancel; ATTACK_CALC_DAMAGE → +1.
func _resolve_coolant_discharge(context: EffectContext) -> void:
	match context.hook:
		&"ATTACK_VALIDATE_TARGET":
			context.cancelled = true
		&"ATTACK_CALC_DAMAGE":
			context.damage_total += 1


## Thrust Control Malfunction: reduce yaw at last adjustable joint by 1.
func _resolve_thrust_control(context: EffectContext) -> void:
	var yaws: Variant = context.get_meta_value("yaw_values", null)
	if yaws == null or not yaws is Array:
		return
	var yaw_arr: Array = yaws as Array
	if yaw_arr.is_empty():
		return
	# Last joint is the last element.
	var last_idx: int = yaw_arr.size() - 1
	yaw_arr[last_idx] = maxi(0, int(yaw_arr[last_idx]) - 1)
	context.set_meta_value("yaw_values", yaw_arr)


## Flags that 1 facedown damage card should be dealt to the ship.
## The actual draw + add_facedown_damage is performed by the caller via
## [PersistentEffectDamageCommand] so the mutation is replay-safe.
## Used by Ruptured Engine, Damaged Controls, and Thruster Fissure.
func _resolve_suffer_facedown(context: EffectContext) -> void:
	var ship: Variant = context.get_meta_value("ship", null)
	var deck: Variant = context.get_meta_value("damage_deck", null)
	if ship == null or deck == null:
		return
	if not ship is ShipInstance or not deck is DamageDeck:
		return
	context.set_meta_value("extra_damage_dealt", true)

## Power Failure: halve engineering value (rounded down), stackable.
func _resolve_power_failure(context: EffectContext) -> void:
	var eng: int = int(context.get_meta_value("engineering_value", 0))
	eng = eng / 2 # Integer division = floor.
	context.set_meta_value("engineering_value", eng)
