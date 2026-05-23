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
	return _get_non_attack_hooks()


## Returns hooks for movement, command, and repair effects.
func _get_non_attack_hooks() -> Array[StringName]:
	return []


## Returns true if this effect should fire for the given context.
## Each effect validates that the owner ship is the relevant participant.
func should_trigger(context: EffectContext) -> bool:
	if context == null or owner == null:
		return false
	return _should_trigger_non_attack(context)


## Checks non-attack effects (movement, command, repair, status).
func _should_trigger_non_attack(context: EffectContext) -> bool:
	return false


## Mutates the context to apply this effect.
func resolve(context: EffectContext) -> void:
	_resolve_non_attack(context)


## Resolves movement, command, and repair effects.
func _resolve_non_attack(context: EffectContext) -> void:
	pass


# ---------------------------------------------------------------------------
# Trigger helpers
# ---------------------------------------------------------------------------


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
