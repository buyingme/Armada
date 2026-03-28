## SwarmEffect
##
## Keyword: Swarm — while attacking a squadron that is also engaged with
## another friendly squadron, the attacker may reroll 1 die.
##
## Rules Reference: "Squadron Keywords", RRG p.12;
##   SM-032 — "While attacking a squadron engaged with another friendly
##   squadron, you may reroll 1 die."
class_name SwarmEffect
extends GameEffect


func _init() -> void:
	source_type = EffectSource.KEYWORD
	source_id = "swarm"


## Responds to ATTACK_MODIFY_DICE_ATTACKER — offers a die reroll when
## the Swarm condition is met.
func get_hooks() -> Array[StringName]:
	return [&"ATTACK_MODIFY_DICE_ATTACKER"]


## Fires when this squadron attacks another squadron that is engaged with
## at least one other friendly squadron.
func should_trigger(context: EffectContext) -> bool:
	if context == null:
		return false
	if context.attacker != owner:
		return false
	# Defender must be a squadron.
	if not context.defender is SquadronInstance:
		return false
	# Check metadata flag set by the engagement system before entering
	# the attack pipeline: "swarm_eligible" == true means at least one
	# other friendly squadron also engages the target.
	return context.get_meta_value("swarm_eligible", false) as bool


## Rerolls the worst die in the pool (the one with the lowest damage).
func resolve(context: EffectContext) -> void:
	if context.dice_results.is_empty():
		return
	# Find the die with the lowest damage to reroll.
	var worst_idx: int = -1
	var worst_dmg: int = 999
	for i: int in range(context.dice_results.size()):
		var face: Constants.DiceFace = (
				context.dice_results[i]["face"] as Constants.DiceFace)
		var dmg: int = Dice.get_face_damage(face)
		if dmg < worst_dmg:
			worst_dmg = dmg
			worst_idx = i
	if worst_idx < 0:
		return
	# Reroll: replace the face with a new random roll of the same colour.
	var color: Constants.DiceColor = (
			context.dice_results[worst_idx]["color"]
			as Constants.DiceColor)
	var new_face: Constants.DiceFace = Dice.roll_die(color)
	context.dice_results[worst_idx]["face"] = new_face
