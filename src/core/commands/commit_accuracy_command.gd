## Commits the Accuracy token locks for one current attack.
class_name CommitAccuracyCommand
extends GameCommand

const TYPE: String = "commit_accuracy"

static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int, pl: Dictionary) -> GameCommand:
		return CommitAccuracyCommand.new(player, pl))

func _init(p_player: int = 0, p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)

func validate(game_state: GameState) -> String:
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return "No current attack."
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if attack.stage != CurrentAttackState.STAGE_ACCURACY \
			or attack.accuracy_complete:
		return "Accuracy selection is not pending."
	if player_index != attack.attacker_player:
		return "Accuracy selection belongs to the attacker."
	var raw_locks: Variant = payload.get("locked_tokens")
	if not raw_locks is Array:
		return "Invalid Accuracy locks."
	var seen: Dictionary = {}
	var defender: RefCounted = _entity_for(
			game_state, attack.defender_kind,
			attack.defender_player, attack.defender_index)
	var defense_tokens: Array[Dictionary] = _defense_tokens(defender)
	for raw: Variant in raw_locks as Array:
		if typeof(raw) != TYPE_INT or int(raw) < 0 or seen.has(int(raw)):
			return "Invalid Accuracy lock target."
		if defender == null or int(raw) >= defense_tokens.size():
			return "Accuracy lock target does not exist."
		seen[int(raw)] = true
	var spendable: int = Dice.count_accuracy(attack.dice_results)
	if spendable > 0 and _accuracy_spend_blocked(game_state, attack):
		spendable = 0
	if seen.size() > spendable:
		return "Too many Accuracy lock targets."
	return ""

func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var locks: Array = (payload.get("locked_tokens", []) as Array).duplicate()
	var replacement: CurrentAttackState = attack.with_patch({
		"accuracy_locked_tokens": locks,
		"accuracy_complete": true,
		"stage": CurrentAttackState.STAGE_DEFENSE,
		"defense_stage": CurrentAttackState.DEFENSE_PENDING \
				if _has_defense_interaction(game_state, attack) \
				else CurrentAttackState.DEFENSE_COMPLETE,
	})
	if replacement == null or not game_state.set_current_attack_state(replacement):
		return {}
	return {"attack_id": attack.attack_id, "locked_tokens": locks}


func _accuracy_spend_blocked(game_state: GameState,
		attack: CurrentAttackState) -> bool:
	var context := EffectContext.new()
	context.attacker = _entity_for(game_state, attack.attacker_kind,
			attack.attacker_player, attack.attacker_index)
	context.defender = _entity_for(game_state, attack.defender_kind,
			attack.defender_player, attack.defender_index)
	return RuleSurface.is_blocked(
			context,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			RuleSurface.TARGET_ACCURACY_SPEND)


func _entity_for(game_state: GameState, kind: String,
		owner: int, index: int) -> RefCounted:
	if kind == CurrentAttackState.KIND_SHIP:
		return game_state.get_ship(owner, index)
	return game_state.get_squadron(owner, index)


func _defense_tokens(defender: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if defender != null:
		result.assign(defender.get("defense_tokens") as Array)
	return result


func _has_defense_interaction(game_state: GameState,
		attack: CurrentAttackState) -> bool:
	var defender: RefCounted = _entity_for(
			game_state, attack.defender_kind,
			attack.defender_player, attack.defender_index)
	for token: Dictionary in _defense_tokens(defender):
		if int(token.get("state", -1)) \
				!= int(Constants.DefenseTokenState.DISCARDED):
			return true
	return false
