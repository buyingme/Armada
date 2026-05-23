## CounterChoiceCommand
##
## Marker command submitted by the squadron owner who may resolve Counter.
## The command records whether that player accepts or skips the optional
## Counter attack; the active attack pipeline reacts to the broadcast result.
##
## Rules Reference: RRG "Squadron Keywords" — Counter.
class_name CounterChoiceCommand
extends GameCommand


const TYPE: String = "counter_choice"


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int,
			pl: Dictionary) -> GameCommand:
		return CounterChoiceCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)


## Validates ownership, active flow surface, and Counter identity metadata.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var phase_error: String = _validate_phase(game_state)
	if phase_error != "":
		return phase_error
	var flow_error: String = _validate_flow(game_state)
	if flow_error != "":
		return flow_error
	if not payload.has("accepted"):
		return "Counter choice missing accepted flag."
	return _validate_identity(game_state.interaction_flow.payload)


## Echoes the choice payload for the attack pipeline reaction.
func execute(_game_state: GameState) -> Dictionary:
	var result: Dictionary = payload.duplicate(true)
	result["accepted"] = bool(payload.get("accepted", false))
	return result


func _validate_phase(game_state: GameState) -> String:
	var phase: Constants.GamePhase = game_state.current_phase
	if phase != Constants.GamePhase.SHIP \
			and phase != Constants.GamePhase.SQUADRON:
		return "Not in Ship or Squadron Phase."
	return ""


func _validate_flow(game_state: GameState) -> String:
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null or flow.flow_type != Constants.InteractionFlow.ATTACK:
		return "No active attack flow."
	if flow.step_id != Constants.InteractionStep.ATTACK_COUNTER_CHOICE:
		return "Not in Counter choice step."
	if not bool(flow.payload.get(CounterKeyword.PAYLOAD_AVAILABLE, false)):
		return "No Counter choice is pending."
	var controller: int = int(flow.payload.get(
			CounterKeyword.PAYLOAD_CONTROLLER_PLAYER, -1))
	if player_index != controller:
		return "Counter choice belongs to player %d." % controller
	return ""


func _validate_identity(flow_payload: Dictionary) -> String:
	var keys: Array[String] = ["counter_attacker_player",
			"counter_attacker_squadron_index", "counter_target_player",
			"counter_target_squadron_index"]
	for key: String in keys:
		if not payload.has(key) or not flow_payload.has(key):
			return "Counter choice identity mismatch."
		if int(payload.get(key, -999)) != int(flow_payload.get(key, -999)):
			return "Counter choice identity mismatch."
	return ""
