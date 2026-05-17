## Damaged Munitions
##
## Static rule hook for the Damaged Munitions damage card.
## Rules Reference: Damage Card "Damaged Munitions" —
## "When attacking a ship, before you roll your attack pool, remove 1 die
## of your choice."
class_name DamagedMunitions
extends RefCounted


const RULE_ID: String = "damage_card.damaged_munitions"
const EFFECT_ID: String = "damaged_munitions"
const META_PENDING_RULE_ID: String = "pending_die_removal_rule_id"
const META_PENDING_TITLE: String = "pending_die_removal_title"
const META_AVAILABLE_COLOURS: String = "available_die_colours"
const META_CHOSEN_COLOUR: String = "chosen_die_colour"
const META_REMOVED_COLOUR: String = "removed_die_color"
const CHOICE_TITLE: String = "Damaged Munitions - remove 1 die:"

static var _rule_instance: DamagedMunitions = null


## Registers the attack-roll dice-pool modifier hook.
static func register() -> void:
	if _rule_instance == null:
		_rule_instance = DamagedMunitions.new()
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
## Rules Reference: Damage Card "Damaged Munitions" — "remove 1 die of your
## choice."
func apply_attack_pool_modifier(context: EffectContext) -> EffectContext:
	if context == null:
		return context
	if not context.attacker is ShipInstance:
		return context
	if not context.defender is ShipInstance:
		return context
	var attacker: ShipInstance = context.attacker as ShipInstance
	if not _has_damaged_munitions(attacker):
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


func _has_damaged_munitions(ship: ShipInstance) -> bool:
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