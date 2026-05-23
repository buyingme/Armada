## ConfirmAttackDiceCommand
##
## Marker command submitted by the attacking controller after attack dice and
## optional attack modifiers are final. The attack pipeline reacts to the
## broadcast result and advances to accuracy/defense/damage resolution.
##
## Rules Reference: RRG "Attack", Steps 3-5, p.2.
class_name ConfirmAttackDiceCommand
extends GameCommand


const TYPE: String = "confirm_attack_dice"


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int,
			pl: Dictionary) -> GameCommand:
		return ConfirmAttackDiceCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)


## Validates that the attack controller may confirm the current dice result.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var flow_error: String = _validate_attack_modify_flow(game_state)
	if flow_error != "":
		return flow_error
	var dice_results: Array = game_state.interaction_flow.payload.get(
			"dice_results", []) as Array
	if dice_results.is_empty():
		return "No attack dice results to confirm."
	return ""


## Echoes the attack identity for the attack pipeline reaction.
func execute(_game_state: GameState) -> Dictionary:
	return payload.duplicate(true)


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
		return "Attack dice confirmation belongs to player %d." % attacker
	return ""
