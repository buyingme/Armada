## RerollAttackDieCommand
##
## Rerolls one attack die during the attack modify step and stores the updated
## dice results in the authoritative interaction-flow payload. The caller also
## receives the updated result so presentation attack state can mirror it.
##
## Payload:
##   "die_index"      — index into the current attack dice results.
##   "dice_results"   — Array of serialized dice result dictionaries.
##   "source_rule_id" — optional rule id such as `squadron_keyword.swarm`.
##
## Rules Reference: RRG "Squadron Keywords", Swarm — "While attacking a
## squadron engaged with another squadron, you may reroll 1 die."
class_name RerollAttackDieCommand
extends GameCommand


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
	var dice_results: Array = payload.get("dice_results", [])
	var die_index: int = int(payload.get("die_index", -1))
	if die_index < 0 or die_index >= dice_results.size():
		return "Invalid die_index."
	if not dice_results[die_index] is Dictionary:
		return "Invalid dice result."
	if str(payload.get("source_rule_id", "")) == SwarmKeyword.RULE_ID:
		return _validate_swarm_reroll(game_state)
	return ""


## Rerolls the selected die using [member GameState.rng].
func execute(game_state: GameState) -> Dictionary:
	var dice_results: Array = payload.get("dice_results", []).duplicate(true)
	var die_index: int = int(payload.get("die_index", -1))
	var old_result: Dictionary = dice_results[die_index] as Dictionary
	var color: Constants.DiceColor = old_result["color"] as Constants.DiceColor
	var new_face: Constants.DiceFace = Dice.roll_die(color, game_state.rng)
	var new_result: Dictionary = {"color": color, "face": new_face}
	dice_results[die_index] = new_result
	_update_flow_payload(game_state, dice_results)
	return {
		"die_index": die_index,
		"old_result": old_result.duplicate(true),
		"new_result": new_result,
		"dice_results": dice_results,
		"source_rule_id": str(payload.get("source_rule_id", "")),
	}


func _update_flow_payload(game_state: GameState,
		dice_results: Array) -> void:
	if game_state == null or game_state.interaction_flow == null:
		return
	game_state.interaction_flow.payload["dice_results"] = \
			dice_results.duplicate(true)


func _validate_swarm_reroll(game_state: GameState) -> String:
	var flow_error: String = _validate_swarm_flow(game_state)
	if flow_error != "":
		return flow_error
	var flow_payload: Dictionary = game_state.interaction_flow.payload
	var attacker: SquadronInstance = _flow_attacker_squadron(
			game_state, flow_payload)
	var target: SquadronInstance = _flow_target_squadron(game_state, flow_payload)
	if attacker == null or target == null:
		return "Swarm reroll requires squadron attacker and target."
	if player_index != attacker.owner_player:
		return "Wrong player for Swarm reroll."
	if not _is_swarm_eligible_from_state(game_state, attacker, target):
		return "Swarm reroll is not eligible."
	return ""


func _validate_swarm_flow(game_state: GameState) -> String:
	if game_state.interaction_flow == null:
		return "Swarm reroll requires an attack flow."
	if game_state.interaction_flow.flow_type != Constants.InteractionFlow.ATTACK:
		return "Swarm reroll requires an attack flow."
	if game_state.interaction_flow.step_id != Constants.InteractionStep.ATTACK_MODIFY:
		return "Swarm reroll is not in the attack modify step."
	var flow_payload: Dictionary = game_state.interaction_flow.payload
	if str(flow_payload.get("target_kind", "")) != "squadron":
		return "Swarm reroll requires a squadron target."
	return ""


func _flow_attacker_squadron(game_state: GameState,
		flow_payload: Dictionary) -> SquadronInstance:
	return game_state.get_squadron(
			int(flow_payload.get("attacker_player", -1)),
			int(flow_payload.get("attacker_squadron_index", -1)))


func _flow_target_squadron(game_state: GameState,
		flow_payload: Dictionary) -> SquadronInstance:
	return game_state.get_squadron(
			int(flow_payload.get("defender_player", -1)),
			int(flow_payload.get("target_squadron_index", -1)))


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
