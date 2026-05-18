## Point-Defense Failure
##
## Static rule hook for the Point-Defense Failure damage card.
## Rules Reference: Damage Card "Point-Defense Failure" —
## "When attacking a squadron, before you roll your attack pool, remove 1 die
## of your choice."
class_name PointDefenseFailure
extends RefCounted


const RULE_ID: String = "damage_card.point_defense_failure"
const EFFECT_ID: String = "point_defense_failure"
const META_PENDING_RULE_ID: String = EffectContext.META_PENDING_DIE_REMOVAL_RULE_ID
const META_PENDING_TITLE: String = EffectContext.META_PENDING_DIE_REMOVAL_TITLE
const META_AVAILABLE_COLOURS: String = EffectContext.META_AVAILABLE_DIE_COLOURS
const META_CHOSEN_COLOUR: String = EffectContext.META_CHOSEN_DIE_COLOUR
const META_REMOVED_COLOUR: String = EffectContext.META_REMOVED_DIE_COLOUR
const CHOICE_TITLE: String = "Point-Defense Failure - remove 1 die:"

static var _rule_instance: PointDefenseFailure = null


## Registers the attack-roll dice-pool modifier hook.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = PointDefenseFailure.new()
	RuleRegistry.register_rule(RULE_ID, [
		FlowHook.modifier(RULE_ID,
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_ROLL,
				"dice_pool",
				Callable(_rule_instance, "apply_attack_pool_modifier")),
	])


## Marks the mandatory pre-roll die-removal choice, or applies it when the
## caller supplies [constant META_CHOSEN_COLOUR]. Active card state is read
## from attacker [member ShipInstance.faceup_damage], not transient registry
## state.
## Rules Reference: Damage Card "Point-Defense Failure" — "remove 1 die of
## your choice."
func apply_attack_pool_modifier(context: EffectContext) -> EffectContext:
	if context == null:
		return context
	if not context.attacker is ShipInstance:
		return context
	if not context.defender is SquadronInstance:
		return context
	var attacker: ShipInstance = context.attacker as ShipInstance
	if not _has_point_defense_failure(attacker):
		return context
	var available: Array[String] = _available_die_colours(context.dice_pool)
	if available.is_empty():
		return context
	var chosen_colour: String = str(context.get_meta_value(
			META_CHOSEN_COLOUR, "")).to_upper()
	if chosen_colour != "":
		_remove_chosen_die(context, chosen_colour, available)
		return context
	_mark_choice_required(context, available)
	return context


func _has_point_defense_failure(ship: ShipInstance) -> bool:
	for card_var: Variant in ship.faceup_damage:
		if not card_var is DamageCard:
			continue
		var card: DamageCard = card_var as DamageCard
		if card.effect_id == EFFECT_ID:
			return true
	return false


func _available_die_colours(pool: Dictionary) -> Array[String]:
	var colours: Array[String] = []
	for colour_key: String in [DicePool.RED_KEY, DicePool.BLUE_KEY,
			DicePool.BLACK_KEY]:
		if int(pool.get(colour_key, 0)) > 0:
			colours.append(colour_key)
	return colours


func _mark_choice_required(context: EffectContext,
		available_colours: Array[String]) -> void:
	context.set_meta_value(META_PENDING_RULE_ID, RULE_ID)
	context.set_meta_value(META_PENDING_TITLE, CHOICE_TITLE)
	context.set_meta_value(META_AVAILABLE_COLOURS,
			available_colours.duplicate())


func _remove_chosen_die(context: EffectContext,
		colour_key: String,
		available_colours: Array[String]) -> void:
	if not available_colours.has(colour_key):
		return
	var count: int = int(context.dice_pool.get(colour_key, 0))
	if count <= 0:
		return
	context.dice_pool[colour_key] = count - 1
	if int(context.dice_pool[colour_key]) <= 0:
		context.dice_pool.erase(colour_key)
	context.set_meta_value(META_REMOVED_COLOUR, colour_key)
