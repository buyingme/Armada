## SkipAttackModifierCommand
##
## Marker command for a controller-owned optional attack modifier skip.
## It is used when the acting player is not the local attack pipeline owner,
## so network and replay observe the same choice boundary as the UI.
##
## Rules Reference: RRG "Attack", modify dice, p.2.
class_name SkipAttackModifierCommand
extends GameCommand


const TYPE: String = "skip_attack_modifier"


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int,
			pl: Dictionary) -> GameCommand:
		return SkipAttackModifierCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)


## Validates that the attacking controller may skip the active modifier.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return "No current attack."
	if attack.attack_id != str(payload.get("attack_id", "")):
		return "Stale current-attack identity."
	if attack.stage != CurrentAttackState.STAGE_ATTACK_MODIFY:
		return "Not in attack modify step."
	if player_index != attack.attacker_player:
		return "Attack modifier belongs to player %d." % attack.attacker_player
	var source_rule_id: String = str(payload.get("source_rule_id", ""))
	if source_rule_id.is_empty():
		return "Missing source_rule_id."
	if source_rule_id == SwarmKeyword.RULE_ID:
		return _validate_swarm_skip(game_state, attack)
	if source_rule_id == RerollAttackDieCommand.SOURCE_CONCENTRATE_FIRE_TOKEN:
		return "" if attack.cf_token_resolution \
				== CurrentAttackState.RESOLUTION_PENDING \
				else "No Concentrate Fire token reroll is pending."
	return "Unsupported attack modifier skip: %s." % source_rule_id


## Echoes the skipped modifier source for the attack pipeline reaction.
func execute(game_state: GameState) -> Dictionary:
	var attack: CurrentAttackState = game_state.current_attack_state
	var source_rule_id: String = str(payload.get("source_rule_id", ""))
	if source_rule_id == RerollAttackDieCommand.SOURCE_CONCENTRATE_FIRE_TOKEN:
		var replacement: CurrentAttackState = attack.with_patch({
			"cf_token_resolution": CurrentAttackState.RESOLUTION_DECLINED,
		})
		if replacement == null or not game_state.set_current_attack_state(replacement):
			return {}
	return {"attack_id": attack.attack_id, "source_rule_id": source_rule_id}


func _validate_swarm_skip(game_state: GameState,
		attack: CurrentAttackState) -> String:
	if attack.attacker_kind != CurrentAttackState.KIND_SQUADRON \
			or attack.defender_kind != CurrentAttackState.KIND_SQUADRON:
		return "No Swarm reroll is pending."
	var attacker: SquadronInstance = game_state.get_squadron(
			attack.attacker_player, attack.attacker_index)
	var target: SquadronInstance = game_state.get_squadron(
			attack.defender_player, attack.defender_index)
	if attacker == null or target == null:
		return "No Swarm reroll is pending."
	return ""
