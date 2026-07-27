## Commits one mandatory pre-roll rule or obstruction die-removal choice.
class_name ResolveAttackPoolChoiceCommand
extends GameCommand

const TYPE: String = "resolve_attack_pool_choice"
const REASON_OBSTRUCTION: String = "obstruction"

static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int, pl: Dictionary) -> GameCommand:
		return ResolveAttackPoolChoiceCommand.new(player, pl))

func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)

func validate(game_state: GameState) -> String:
	var attack: CurrentAttackState = game_state.current_attack_state
	var reason: String = _validate_attack(attack)
	if reason != "":
		return reason
	var color: String = str(payload.get("color", "")).to_upper()
	if int(attack.dice_pool.get(color, 0)) <= 0:
		return "Selected die color is not in the current attack pool."
	var choice_kind: String = str(payload.get("choice_kind", ""))
	if choice_kind == REASON_OBSTRUCTION:
		if not attack.obstructed:
			return "Attack is not obstructed."
		return "" if not attack.obstruction_resolved \
				else "Obstruction choice already resolved."
	var rule_id: String = str(payload.get("rule_id", ""))
	if choice_kind != "rule" or rule_id.is_empty():
		return "Invalid attack-pool choice."
	if attack.resolved_pool_choices.has(rule_id):
		return "Attack-pool rule choice already resolved."
	var resolved: Dictionary = _resolve_rule_choice(game_state, attack, rule_id, color)
	if not bool(resolved.get("ok", false)):
		return str(resolved.get("reason", "Invalid attack-pool rule choice."))
	return ""

func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var color: String = str(payload.get("color", "")).to_upper()
	var choice_kind: String = str(payload.get("choice_kind", ""))
	var rule_id: String = str(payload.get("rule_id", ""))
	var pool: Dictionary = attack.dice_pool
	var patch: Dictionary = {}
	if choice_kind == REASON_OBSTRUCTION:
		pool[color] = int(pool.get(color, 0)) - 1
		if int(pool[color]) <= 0:
			pool.erase(color)
		patch["obstruction_resolved"] = true
	else:
		var resolved: Dictionary = _resolve_rule_choice(
				game_state, attack, rule_id, color)
		if not bool(resolved.get("ok", false)):
			return {}
		pool = (resolved.get("dice_pool", {}) as Dictionary).duplicate(true)
		var choices: Array[String] = attack.resolved_pool_choices
		choices.append(rule_id)
		patch["resolved_pool_choices"] = choices
	patch["dice_pool"] = pool
	var replacement: CurrentAttackState = attack.with_patch(patch)
	if replacement == null or not game_state.set_current_attack_state(replacement):
		return {}
	return {
		"attack_id": attack.attack_id,
		"choice_kind": choice_kind,
		"rule_id": rule_id,
		"color": color,
		"dice_pool": pool,
	}

func _validate_attack(attack: CurrentAttackState) -> String:
	if attack == null or not attack.active:
		return "No current attack."
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if attack.stage != CurrentAttackState.STAGE_PRE_ROLL:
		return "Attack is not in pre-roll stage."
	if player_index != attack.attacker_player:
		return "Attack-pool choice belongs to the attacker."
	return ""


func _resolve_rule_choice(game_state: GameState,
		attack: CurrentAttackState,
		rule_id: String,
		color: String) -> Dictionary:
	var context := EffectContext.new()
	context.attacker = _entity_for(game_state, attack.attacker_kind,
			attack.attacker_player, attack.attacker_index)
	context.defender = _entity_for(game_state, attack.defender_kind,
			attack.defender_player, attack.defender_index)
	context.attacking_zone = attack.attacker_zone
	context.defending_zone = attack.defender_zone
	context.range_band = attack.range_band
	context.dice_pool = attack.dice_pool
	context.set_meta_value(EffectContext.META_CHOSEN_DIE_COLOUR, color)
	var matched: bool = false
	for hook: FlowHook in RuleRegistry.modifiers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"dice_pool"):
		if hook.rule_id != rule_id or not hook.callback.is_valid():
			continue
		matched = true
		var changed: Variant = hook.callback.call(context)
		if changed is EffectContext:
			context = changed as EffectContext
		break
	if not matched:
		return {"ok": false, "reason": "Unknown attack-pool rule choice."}
	if str(context.get_meta_value(
			EffectContext.META_REMOVED_DIE_COLOUR, "")).to_upper() != color:
		return {"ok": false, "reason": "Rule did not accept the selected die."}
	var before_count: int = DicePool.get_total_count(attack.dice_pool)
	var after_count: int = DicePool.get_total_count(context.dice_pool)
	if after_count != before_count - 1 or after_count <= 0:
		return {"ok": false, "reason": "Rule produced an invalid attack pool."}
	return {"ok": true, "reason": "", "dice_pool": context.dice_pool}


func _entity_for(game_state: GameState, kind: String,
		owner: int, index: int) -> RefCounted:
	if kind == CurrentAttackState.KIND_SHIP:
		return game_state.get_ship(owner, index)
	return game_state.get_squadron(owner, index)
