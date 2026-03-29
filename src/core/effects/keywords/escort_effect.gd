## EscortEffect
##
## Keyword: Escort — squadrons engaged with a squadron that has Escort
## cannot attack non-Escort squadrons.
##
## Rules Reference: "Squadron Keywords", RRG p.12;
##   SM-031 — "Squadrons engaged with you are heavied … must attack
##   squadrons with Escort if able."
class_name EscortEffect
extends GameEffect


func _init() -> void:
	source_type = EffectSource.KEYWORD
	source_id = "escort"


## Responds to SQUADRON_MUST_ATTACK_ENGAGED — forces attackers engaged
## with this Escort to target it (or another Escort) rather than a
## non-Escort squadron.
func get_hooks() -> Array[StringName]:
	return [&"SQUADRON_MUST_ATTACK_ENGAGED"]


## Fires when any squadron is choosing an attack target.
func should_trigger(context: EffectContext) -> bool:
	if context == null:
		return false
	# Only relevant when the proposed defender is NOT an Escort squadron.
	if context.defender == null:
		return false
	if context.defender == owner:
		return false # targeting this Escort is fine
	# Check the defender has Escort — if so, selecting it is allowed.
	if context.defender is SquadronInstance:
		var def_sq: SquadronInstance = context.defender as SquadronInstance
		if def_sq.squadron_data and def_sq.squadron_data.has_keyword("Escort"):
			return false # targeting another Escort is fine
	return true


## Blocks the target selection (sets cancelled = true) so the UI can
## inform the player they must pick an Escort target.
func resolve(context: EffectContext) -> void:
	context.cancelled = true
