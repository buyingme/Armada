## DamageCardEffect
##
## A configurable [GameEffect] subclass that implements all 16 persistent
## damage card effects. The behaviour is driven by the [member effect_id]
## string, which maps to the card's JSON `effect_id` field.
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
## Used by Crew Panic (player may choose to discard the card itself).
var damage_card: DamageCard = null


func _init() -> void:
	source_type = EffectSource.DAMAGE_CARD


## Returns the hook points this effect responds to, based on [member effect_id].
func get_hooks() -> Array[StringName]:
	match effect_id:
		# --- Attack hooks ---
		"coolant_discharge":
			return [&"ATTACK_VALIDATE_TARGET", &"ATTACK_CALC_DAMAGE"]
		"depowered_armament":
			return [&"ATTACK_VALIDATE_TARGET"]
		"disengaged_fire_control":
			return [&"ATTACK_VALIDATE_TARGET"]
		"damaged_munitions":
			return [&"ATTACK_GATHER_DICE"]
		"point_defense_failure":
			return [&"ATTACK_GATHER_DICE"]
		"blinded_gunners":
			return [&"ATTACK_SPEND_ACCURACY"]
		"targeter_disruption":
			return [&"ATTACK_RESOLVE_CRITICAL"]
		"faulty_countermeasures":
			return [&"DEFENSE_VALIDATE_TOKEN"]
		# --- Movement hooks ---
		"thrust_control_malfunction":
			return [&"MANEUVER_DETERMINE_YAWS"]
		"ruptured_engine":
			return [&"AFTER_MANEUVER_EXECUTE"]
		"damaged_controls":
			return [&"AFTER_MANEUVER_EXECUTE"]
		"thruster_fissure":
			return [&"ON_SPEED_CHANGE"]
		# --- Command & Status hooks ---
		"crew_panic":
			return [&"BEFORE_REVEAL_DIAL"]
		"power_failure":
			return [&"CALC_ENGINEERING_VALUE"]
		"compartment_fire":
			return [&"STATUS_READY_TOKENS"]
		# --- Repair & Token hooks ---
		"capacitor_failure":
			return [&"DEFENSE_VALIDATE_TOKEN", &"REPAIR_VALIDATE_SHIELD"]
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
		# --- ATTACK_VALIDATE_TARGET (hooks 1) ---
		"coolant_discharge":
			return _trigger_coolant_discharge(context)
		"depowered_armament":
			return _trigger_depowered_armament(context)
		"disengaged_fire_control":
			return _trigger_disengaged_fire_control(context)
		# --- ATTACK_GATHER_DICE (hook 2) ---
		"damaged_munitions":
			return context.attacker == owner
		"point_defense_failure":
			return context.attacker == owner and \
					context.defender is SquadronInstance
		# --- ATTACK_SPEND_ACCURACY (hook 3) ---
		"blinded_gunners":
			return context.attacker == owner
		# --- ATTACK_RESOLVE_CRITICAL (hook 4) ---
		"targeter_disruption":
			return context.attacker == owner
		# --- DEFENSE_VALIDATE_TOKEN (hook 5) ---
		"faulty_countermeasures":
			return _trigger_faulty_countermeasures(context)
		"capacitor_failure":
			return _trigger_capacitor_failure(context)
		# --- ATTACK_CALC_DAMAGE (for Coolant Discharge bonus) ---
		# Checked by hook name + effect_id.
		# --- MANEUVER_DETERMINE_YAWS (hook 6) ---
		"thrust_control_malfunction":
			return context.get_meta_value("ship", null) == owner
		# --- AFTER_MANEUVER_EXECUTE (hook 7) ---
		"ruptured_engine":
			return _trigger_ruptured_engine(context)
		"damaged_controls":
			return _trigger_damaged_controls(context)
		# --- ON_SPEED_CHANGE (hook 8) ---
		"thruster_fissure":
			return context.get_meta_value("ship", null) == owner
		# --- BEFORE_REVEAL_DIAL (hook 9) ---
		"crew_panic":
			return context.get_meta_value("ship", null) == owner
		# --- CALC_ENGINEERING_VALUE (hook 10) ---
		"power_failure":
			return context.get_meta_value("ship", null) == owner
		# --- STATUS_READY_TOKENS (hook 11) ---
		"compartment_fire":
			return context.get_meta_value("ship", null) == owner
		# --- REPAIR_VALIDATE_SHIELD (hook 12) ---
		# Capacitor Failure handles this in _trigger_capacitor_failure.
		# --- ON_COMMAND_TOKEN_GAIN (hook 13) ---
		"life_support_failure":
			return context.get_meta_value("ship", null) == owner
		_:
			return false


## Mutates the context to apply this effect.
func resolve(context: EffectContext) -> void:
	match effect_id:
		"coolant_discharge":
			_resolve_coolant_discharge(context)
		"depowered_armament":
			context.cancelled = true
		"disengaged_fire_control":
			context.cancelled = true
		"damaged_munitions":
			_resolve_remove_one_die(context)
		"point_defense_failure":
			_resolve_remove_one_die(context)
		"blinded_gunners":
			context.cancelled = true
		"targeter_disruption":
			context.critical_allowed = false
		"faulty_countermeasures":
			context.cancelled = true
		"capacitor_failure":
			_resolve_capacitor_failure(context)
		"thrust_control_malfunction":
			_resolve_thrust_control(context)
		"ruptured_engine":
			_resolve_suffer_facedown(context)
		"damaged_controls":
			_resolve_suffer_facedown(context)
		"thruster_fissure":
			_resolve_suffer_facedown(context)
		"crew_panic":
			_resolve_crew_panic(context)
		"power_failure":
			_resolve_power_failure(context)
		"compartment_fire":
			context.cancelled = true
		"life_support_failure":
			context.cancelled = true


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


## Faulty Countermeasures: Cannot spend exhausted defense tokens.
func _trigger_faulty_countermeasures(context: EffectContext) -> bool:
	if context.defender != owner:
		return false
	var token_state: int = int(
			context.get_meta_value("token_state",
			Constants.DefenseTokenState.READY))
	return token_state == Constants.DefenseTokenState.EXHAUSTED


## Capacitor Failure: On DEFENSE_VALIDATE_TOKEN — block Redirect if the
## zone receiving the redirect has 0 shields.
## On REPAIR_VALIDATE_SHIELD — block recover/move to a zone with 0 shields.
func _trigger_capacitor_failure(context: EffectContext) -> bool:
	match context.hook:
		&"DEFENSE_VALIDATE_TOKEN":
			if context.defender != owner:
				return false
			var token_type: int = int(
					context.get_meta_value("token_type", -1))
			if token_type != Constants.DefenseToken.REDIRECT:
				return false
			var zone_shields: int = int(
					context.get_meta_value("target_zone_shields", 1))
			return zone_shields <= 0
		&"REPAIR_VALIDATE_SHIELD":
			if context.get_meta_value("ship", null) != owner:
				return false
			var target_zone_shields: int = int(
					context.get_meta_value("target_zone_shields", 1))
			return target_zone_shields <= 0
		_:
			return false


## Ruptured Engine: Suffer 1 damage after maneuver if speed > 1.
func _trigger_ruptured_engine(context: EffectContext) -> bool:
	if context.get_meta_value("ship", null) != owner:
		return false
	var speed: int = int(context.get_meta_value("ship_speed", 0))
	return speed > 1


## Damaged Controls: Suffer 1 extra facedown when overlapping an obstacle.
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


## Removes 1 die from the dice pool (attacker removes lowest-value die).
## The removed die is stored in metadata for possible future inspection.
func _resolve_remove_one_die(context: EffectContext) -> void:
	if context.dice_pool.is_empty():
		return
	# Remove one die — prefer the pool with the most dice, or any available.
	for color: Variant in context.dice_pool.keys():
		var count: int = int(context.dice_pool[color])
		if count > 0:
			context.dice_pool[color] = count - 1
			context.set_meta_value("removed_die_color", color)
			return


## Capacitor Failure: cancel redirect or repair shield operation.
func _resolve_capacitor_failure(context: EffectContext) -> void:
	context.cancelled = true


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


## Deals 1 facedown damage card to the ship (used by Ruptured Engine,
## Damaged Controls, Thruster Fissure, Crew Panic).
func _resolve_suffer_facedown(context: EffectContext) -> void:
	var ship: Variant = context.get_meta_value("ship", null)
	var deck: Variant = context.get_meta_value("damage_deck", null)
	if ship == null or deck == null:
		return
	if not ship is ShipInstance or not deck is DamageDeck:
		return
	var si: ShipInstance = ship as ShipInstance
	var dd: DamageDeck = deck as DamageDeck
	var card: DamageCard = dd.draw_card()
	if card:
		si.add_facedown_damage(card)
		context.set_meta_value("extra_damage_dealt", true)


## Crew Panic: suffer 1 facedown OR discard this card.
## The player's choice is stored in metadata.dial_discarded.
func _resolve_crew_panic(context: EffectContext) -> void:
	var discard_card: bool = context.get_meta_value(
			"dial_discarded", false) as bool
	if discard_card:
		# The player chose to discard this damage card instead.
		var ship: Variant = context.get_meta_value("ship", null)
		var deck: Variant = context.get_meta_value("damage_deck", null)
		if ship is ShipInstance and damage_card:
			(ship as ShipInstance).remove_damage_card(damage_card)
			if deck is DamageDeck:
				(deck as DamageDeck).discard(damage_card)
	else:
		# Suffer 1 facedown damage card.
		_resolve_suffer_facedown(context)


## Power Failure: halve engineering value (rounded down), stackable.
func _resolve_power_failure(context: EffectContext) -> void:
	var eng: int = int(context.get_meta_value("engineering_value", 0))
	eng = eng / 2 # Integer division = floor.
	context.set_meta_value("engineering_value", eng)
