## Derives the next mandatory Gather Attack Dice obligation from canonical state.
## This helper owns no state. Registered rule hooks remain the source of each
## card's die-removal operation; resolved identities live on CurrentAttackState.
class_name AttackGatherReadiness
extends RefCounted


const POINT_DEFENSE: String = "damage_card.point_defense_failure"
const DAMAGED_MUNITIONS: String = "damage_card.damaged_munitions"


static func derive(game_state: GameState, attack: CurrentAttackState) -> Dictionary:
	if game_state == null or attack == null or not attack.active \
			or attack.stage != CurrentAttackState.STAGE_PRE_ROLL:
		return _failure("No pre-roll current attack.")
	var pool: Dictionary = attack.dice_pool
	var colors: Array[String] = []
	for color: String in [DicePool.RED_KEY, DicePool.BLUE_KEY,
			DicePool.BLACK_KEY]:
		if int(pool.get(color, 0)) > 0:
			colors.append(color)
	var required: Array[String] = []
	if attack.attacker_kind == CurrentAttackState.KIND_SHIP:
		var ship: ShipInstance = game_state.get_ship(
				attack.attacker_player, attack.attacker_index)
		if ship == null:
			return _failure("Attacking ship is missing.")
		for card: Variant in ship.faceup_damage:
			if not card is DamageCard:
				continue
			var effect_id: String = (card as DamageCard).effect_id
			if effect_id == "point_defense_failure" \
					and attack.defender_kind == CurrentAttackState.KIND_SQUADRON \
					and not required.has(POINT_DEFENSE):
				required.append(POINT_DEFENSE)
			if effect_id == "damaged_munitions" \
					and attack.defender_kind == CurrentAttackState.KIND_SHIP \
					and not required.has(DAMAGED_MUNITIONS):
				required.append(DAMAGED_MUNITIONS)
	var hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL, "dice_pool")
	for resolved_id: String in attack.resolved_pool_choices:
		if not required.has(resolved_id):
			return _failure("Resolved Gather choice has no applicable source.")
	if not colors.is_empty():
		for hook: FlowHook in hooks:
			if not hook.callback.is_valid():
				return _failure("Invalid registered Gather modifier.")
			var context := EffectContext.new()
			context.attacker = game_state.get_ship(
					attack.attacker_player, attack.attacker_index) \
					if attack.attacker_kind == CurrentAttackState.KIND_SHIP \
					else game_state.get_squadron(
						attack.attacker_player, attack.attacker_index)
			context.defender = game_state.get_ship(
					attack.defender_player, attack.defender_index) \
					if attack.defender_kind == CurrentAttackState.KIND_SHIP \
					else game_state.get_squadron(
						attack.defender_player, attack.defender_index)
			context.attacking_zone = attack.attacker_zone
			context.defending_zone = attack.defender_zone
			context.range_band = attack.range_band
			context.dice_pool = pool.duplicate(true)
			var changed: Variant = hook.callback.call(context)
			if not changed is EffectContext:
				return _failure("Registered Gather modifier returned invalid state.")
			context = changed as EffectContext
			var pending_id: String = str(context.get_meta_value(
					EffectContext.META_PENDING_DIE_REMOVAL_RULE_ID, ""))
			if context.dice_pool != pool \
					or (not pending_id.is_empty() \
						and (pending_id != hook.rule_id \
							or not [POINT_DEFENSE, DAMAGED_MUNITIONS].has(pending_id))):
				return _failure("Unknown or inconsistent mandatory Gather modifier.")
	for rule_id: String in required:
		var registered: bool = false
		for hook: FlowHook in hooks:
			if hook.rule_id == rule_id and hook.callback.is_valid():
				registered = true
				break
		if not registered:
			return _failure("Applicable gather rule is not registered: %s." % rule_id)
		if not attack.resolved_pool_choices.has(rule_id):
			return {"ok": true, "complete": false, "choice_kind": "rule",
				"rule_id": rule_id, "available_colours": colors,
				"no_die": colors.is_empty()}
	if attack.obstructed and not attack.obstruction_resolved:
		return {"ok": true, "complete": false,
			"choice_kind": "obstruction",
			"rule_id": "", "available_colours": colors,
			"no_die": colors.is_empty()}
	return {"ok": true, "complete": true,
		"empty": colors.is_empty(), "available_colours": colors}


static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
