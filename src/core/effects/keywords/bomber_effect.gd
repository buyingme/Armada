## BomberEffect
##
## Keyword: Bomber — while attacking a ship, each critical icon (E) adds
## 1 damage to the damage total.  Normally squadron-vs-ship attacks ignore
## critical icons for damage; Bomber overrides this.
##
## Rules Reference: "Squadron Keywords", RRG p.12;
##   SM-030 — "While attacking a ship, each E icon adds 1 damage."
class_name BomberEffect
extends GameEffect


func _init() -> void:
	source_type = EffectSource.KEYWORD
	source_id = "bomber"


## Responds to ATTACK_CALC_DAMAGE — adjusts damage total when a Bomber
## squadron attacks a ship.
func get_hooks() -> Array[StringName]:
	return [&"ATTACK_CALC_DAMAGE"]


## Only fires when this squadron is the attacker and the defender is a ship.
func should_trigger(context: EffectContext) -> bool:
	if context == null:
		return false
	if context.attacker != owner:
		return false
	# Defender must be a ship (ShipInstance), not a squadron.
	return context.defender is ShipInstance


## Recalculates damage counting critical icons, which the base
## squadron-vs-ship formula already includes (Dice.calculate_damage counts
## crits).  The fix: replace the squadron-damage-formula result with the
## ship-damage-formula result so crits count.
func resolve(context: EffectContext) -> void:
	# The context was populated with calculate_damage_vs_squadron (crits = 0).
	# Recalculate with the ship formula (crits = 1 each).
	var full_damage: int = Dice.calculate_damage(context.dice_results)
	if full_damage > context.damage_total:
		context.damage_total = full_damage
