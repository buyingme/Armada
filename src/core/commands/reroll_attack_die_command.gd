## RerollAttackDieCommand
##
## Rerolls one canonical current-attack die during the attack modify step.
##
## Payload:
##   "die_index"      — index into the current attack dice results.
##   "attack_id"      — canonical current-attack identity.
##   "expected_color" / "expected_face" — stale-intent guard.
##   "source_rule_id" — optional rule id such as `squadron_keyword.swarm`.
##
## Rules Reference: RRG "Squadron Keywords", Swarm — "While attacking a
## squadron engaged with another squadron, you may reroll 1 die."
class_name RerollAttackDieCommand
extends GameCommand


const SOURCE_CONCENTRATE_FIRE_TOKEN: String = "concentrate_fire_token"


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("reroll_attack_die", func(player: int,
			pl: Dictionary) -> GameCommand:
		return RerollAttackDieCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "reroll_attack_die", p_payload)


## Validates that a die index and current dice result array are present.
## Swarm-sourced rerolls are rechecked from serialized [GameState] so direct,
## replay, and network submissions respect engagement and obstruction.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return "No current attack."
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if attack.stage != CurrentAttackState.STAGE_ATTACK_MODIFY:
		return "Current attack is not in Attack Modify."
	if player_index != attack.attacker_player:
		return "Attack reroll belongs to player %d." % attack.attacker_player
	var dice_results: Array[Dictionary] = attack.dice_results
	var die_index: int = int(payload.get("die_index", -1))
	if die_index < 0 or die_index >= dice_results.size():
		return "Invalid die_index."
	if not dice_results[die_index] is Dictionary:
		return "Invalid dice result."
	var expected: Dictionary = dice_results[die_index]
	if typeof(payload.get("expected_color")) != TYPE_INT \
			or int(payload.get("expected_color")) != int(expected.get("color", -1)) \
			or typeof(payload.get("expected_face")) != TYPE_INT \
			or int(payload.get("expected_face")) != int(expected.get("face", -1)):
		return "Stale attack-die selection."
	var source_rule_id: String = str(payload.get("source_rule_id", ""))
	if source_rule_id == SwarmKeyword.RULE_ID:
		return _validate_swarm_reroll(game_state)
	if source_rule_id == SOURCE_CONCENTRATE_FIRE_TOKEN:
		return _validate_concentrate_fire_token(game_state, attack)
	return "Unsupported attack reroll source."


## Rerolls the selected die using [member GameState.rng].
func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var dice_results: Array[Dictionary] = attack.dice_results
	var die_index: int = int(payload.get("die_index", -1))
	var old_result: Dictionary = dice_results[die_index] as Dictionary
	var color: Constants.DiceColor = old_result["color"] as Constants.DiceColor
	var rng_state: int = game_state.rng.get_state()
	var new_face: Constants.DiceFace = Dice.roll_die(color, game_state.rng)
	var new_result: Dictionary = {"color": color, "face": new_face}
	dice_results[die_index] = new_result
	var patch: Dictionary = {"dice_results": dice_results}
	var spends_cf_token: bool = str(payload.get("source_rule_id", "")) \
			== SOURCE_CONCENTRATE_FIRE_TOKEN
	if spends_cf_token:
		patch["cf_token_resolution"] = CurrentAttackState.RESOLUTION_USED
	var replacement: CurrentAttackState = attack.with_patch(patch)
	if replacement == null or not game_state.set_current_attack_state(replacement):
		game_state.rng.set_state(rng_state)
		return {}
	if spends_cf_token:
		var ship: ShipInstance = game_state.get_ship(
				attack.attacker_player, attack.attacker_index)
		if not ship.command_tokens.spend_token(
				Constants.CommandType.CONCENTRATE_FIRE):
			game_state.set_current_attack_state(attack)
			game_state.rng.set_state(rng_state)
			return {}
	return {
		"attack_id": attack.attack_id,
		"die_index": die_index,
		"old_result": old_result.duplicate(true),
		"new_result": new_result,
		"dice_results": dice_results,
		"source_rule_id": str(payload.get("source_rule_id", "")),
	}

func _validate_swarm_reroll(game_state: GameState) -> String:
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack.attacker_kind != CurrentAttackState.KIND_SQUADRON \
			or attack.defender_kind != CurrentAttackState.KIND_SQUADRON:
		return "Swarm reroll requires squadron attacker and target."
	var attacker: SquadronInstance = game_state.get_squadron(
			attack.attacker_player, attack.attacker_index)
	var target: SquadronInstance = game_state.get_squadron(
			attack.defender_player, attack.defender_index)
	if attacker == null or target == null:
		return "Swarm reroll requires squadron attacker and target."
	if player_index != attacker.owner_player:
		return "Wrong player for Swarm reroll."
	if not _is_swarm_eligible_from_state(game_state, attacker, target):
		return "Swarm reroll is not eligible."
	return ""


func _validate_concentrate_fire_token(game_state: GameState,
		attack: CurrentAttackState) -> String:
	if attack.attacker_kind != CurrentAttackState.KIND_SHIP \
			or attack.cf_token_resolution != CurrentAttackState.RESOLUTION_PENDING:
		return "Concentrate Fire token reroll is not pending."
	var ship: ShipInstance = game_state.get_ship(
			attack.attacker_player, attack.attacker_index)
	if ship == null or ship.command_tokens == null \
			or not ship.command_tokens.has_token(Constants.CommandType.CONCENTRATE_FIRE):
		return "No Concentrate Fire token is available."
	return ""


func _is_swarm_eligible_from_state(game_state: GameState,
		attacker: SquadronInstance,
		target: SquadronInstance) -> bool:
	var all_squadrons: Array[Dictionary] = \
			SquadronKeywordRuleHelper.positions_from_state(game_state)
	var obstruction_bodies: Array = \
			EngagementResolver.obstruction_bodies_from_state(game_state)
	return SquadronKeywordRuleHelper.is_swarm_eligible(
			attacker,
			SquadronKeywordRuleHelper.position_from_state(attacker),
			target,
			SquadronKeywordRuleHelper.position_from_state(target),
			all_squadrons,
			obstruction_bodies)
