## SelectEvadeDieCommand
##
## Marker command submitted by the [b]defender peer[/b] in network mode
## when the player picks a die during the Evade defense-token sub-step
## on the [AttackPanelMirror].  It carries the die index targeted by
## the evade effect.
##
## Phase I6b-3 R3: closes the evade-target authority gap.  The attacker
## peer's [AttackExecutor] reacts to this command via
## [signal CommandProcessor.command_executed] and runs the existing
## remove-die / reroll-die pipeline (depending on range band).
##
## Payload:
##   "defender_kind"  — canonical participant kind (ship or squadron).
##   "defender_index" — index of the defender in the matching fleet list.
##   "die_index"      — index into [code]_state.dice_results[/code] of the
##                      die the defender targeted with the evade effect.
##
## Hot-seat: this command is also submitted in hot-seat for replay
## determinism and to keep a single code path between modes.
##
## Rules Reference: "Evade", DT-001/DT-003, RRG v1.5.0, p.5.
class_name SelectEvadeDieCommand
extends GameCommand


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("select_evade_die", func(player: int,
			pl: Dictionary) -> GameCommand:
		return SelectEvadeDieCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "select_evade_die", p_payload)


## Validates that the canonical defender exists and the die index is
## non-negative.  Whether the index is in range of the current attack's
## dice pool is validated by [AttackExecutor] (which holds the
## authoritative dice-results buffer) before applying the effect.
## Allowed in both Ship and Squadron phases (evade applies to both).
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP \
			and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return "No current attack."
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if attack.stage != CurrentAttackState.STAGE_DEFENSE \
			or attack.defense_stage != CurrentAttackState.DEFENSE_RESOLVING:
		return "Evade resolution is not active."
	if player_index != attack.defender_player \
			or not _payload_matches_defender(attack):
		return "Evade selection does not match the current defender."
	var defender: RefCounted = _defender(game_state, attack)
	if defender == null:
		return "Defender not found."
	var die_index: int = int(payload.get("die_index", -1))
	if die_index < 0 or die_index >= attack.dice_results.size():
		return "Invalid die index %d." % die_index
	var die: Dictionary = attack.dice_results[die_index]
	if typeof(payload.get("expected_color")) != TYPE_INT \
			or int(payload.get("expected_color")) != int(die.get("color", -1)) \
			or typeof(payload.get("expected_face")) != TYPE_INT \
			or int(payload.get("expected_face")) != int(die.get("face", -1)):
		return "Stale Evade die selection."
	var token_index: int = int(payload.get("token_index", -1))
	if not _is_next_unresolved_token(
			attack, defender, token_index, Constants.DefenseToken.EVADE):
		return "No committed Evade effect is pending."
	return ""


## Marker — no game-state mutation here.  The die index is echoed in
## the result so the attacker peer's [AttackExecutor] can drive the
## evade pipeline from the [signal CommandProcessor.command_executed]
## signal.
func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var die_index: int = int(payload.get("die_index", -1))
	var dice: Array[Dictionary] = attack.dice_results
	var old_result: Dictionary = dice[die_index].duplicate(true)
	var new_result: Dictionary = {}
	var rng_state: int = game_state.rng.get_state()
	var rng_used: bool = false
	if attack.range_band == Constants.RANGE_BAND_LONG:
		dice.remove_at(die_index)
	else:
		rng_used = true
		var color: Constants.DiceColor = old_result.get("color") as Constants.DiceColor
		new_result = {
			"color": int(color),
			"face": int(Dice.roll_die(color, game_state.rng)),
		}
		dice[die_index] = new_result
	var token_index: int = int(payload.get("token_index", -1))
	var defender: RefCounted = _defender(game_state, attack)
	var tokens: Array[Dictionary] = _defense_tokens(defender)
	var token_type: int = int(tokens[token_index].get("type", -1))
	var effects: Array[Dictionary] = attack.resolved_defense_effects
	effects.append({"token_index": token_index, "token_type": token_type})
	var replacement: CurrentAttackState = attack.with_patch({
		"dice_results": dice,
		"pending_evade": {},
		"resolved_defense_effects": effects,
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE \
				if _all_committed_effects_resolved(
						attack.committed_defense_tokens, effects) \
				else CurrentAttackState.DEFENSE_RESOLVING,
	})
	if replacement == null or not game_state.set_current_attack_state(replacement):
		if rng_used:
			game_state.rng.set_state(rng_state)
		return {}
	return {
		"attack_id": attack.attack_id,
		"defender_kind": attack.defender_kind,
		"defender_index": attack.defender_index,
		"ship_index": attack.defender_index \
				if attack.defender_kind == CurrentAttackState.KIND_SHIP else -1,
		"token_index": token_index,
		"die_index": die_index,
		"old_result": old_result,
		"new_result": new_result,
		"dice_results": dice,
	}


func _payload_matches_defender(attack: CurrentAttackState) -> bool:
	var kind: String = str(payload.get(
			"defender_kind", CurrentAttackState.KIND_SHIP))
	var index: int = int(payload.get(
			"defender_index", payload.get("ship_index", -1)))
	return kind == attack.defender_kind and index == attack.defender_index


func _defender(game_state: GameState,
		attack: CurrentAttackState) -> RefCounted:
	if attack.defender_kind == CurrentAttackState.KIND_SHIP:
		return game_state.get_ship(attack.defender_player, attack.defender_index)
	return game_state.get_squadron(
			attack.defender_player, attack.defender_index)


func _defense_tokens(defender: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if defender != null:
		result.assign(defender.get("defense_tokens") as Array)
	return result


func _is_next_unresolved_token(attack: CurrentAttackState,
		defender: RefCounted, token_index: int, token_type: int) -> bool:
	var tokens: Array[Dictionary] = _defense_tokens(defender)
	var resolved: Dictionary = {}
	for effect: Dictionary in attack.resolved_defense_effects:
		resolved[int(effect.get("token_index", -1))] = true
	for committed_index: int in attack.committed_defense_tokens:
		if resolved.has(committed_index):
			continue
		return committed_index == token_index \
				and token_index >= 0 and token_index < tokens.size() \
				and int(tokens[token_index].get("type", -1)) == token_type
	return false


func _all_committed_effects_resolved(committed: Array[int],
		effects: Array[Dictionary]) -> bool:
	var resolved: Dictionary = {}
	for effect: Dictionary in effects:
		resolved[int(effect.get("token_index", -1))] = true
	for token_index: int in committed:
		if not resolved.has(token_index):
			return false
	return true
