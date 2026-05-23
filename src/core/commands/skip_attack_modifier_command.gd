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
	var flow_error: String = _validate_attack_modify_flow(game_state)
	if flow_error != "":
		return flow_error
	var source_rule_id: String = str(payload.get("source_rule_id", ""))
	if source_rule_id.is_empty():
		return "Missing source_rule_id."
	if source_rule_id == SwarmKeyword.RULE_ID:
		return _validate_swarm_skip(game_state.interaction_flow.payload)
	return "Unsupported attack modifier skip: %s." % source_rule_id


## Echoes the skipped modifier source for the attack pipeline reaction.
func execute(_game_state: GameState) -> Dictionary:
	return {"source_rule_id": str(payload.get("source_rule_id", ""))}


func _validate_attack_modify_flow(game_state: GameState) -> String:
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP \
			and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null or flow.flow_type != Constants.InteractionFlow.ATTACK:
		return "No active attack flow."
	if flow.step_id != Constants.InteractionStep.ATTACK_MODIFY:
		return "Not in attack modify step."
	var attacker: int = int(flow.payload.get("attacker_player", -1))
	if player_index != attacker:
		return "Attack modifier belongs to player %d." % attacker
	return ""


func _validate_swarm_skip(flow_payload: Dictionary) -> String:
	if not bool(flow_payload.get(SwarmKeyword.PAYLOAD_AVAILABLE, false)):
		return "No Swarm reroll is pending."
	return ""
