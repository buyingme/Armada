## CounterChoiceCommand
##
## Source-bound command submitted by the squadron owner who may resolve Counter.
## It commits the single-use disposition in the active parent Attack state;
## the active attack pipeline reacts to the broadcast result.
##
## Rules Reference: RRG "Squadron Keywords" — Counter.
class_name CounterChoiceCommand
extends GameCommand


const TYPE: String = "counter_choice"
const RESULT_COUNTER_ACCEPTED: String = "counter_accepted"
const COUNTER_CONSISTENCY: GDScript = preload(
		"res://src/core/state/counter_publication_consistency.gd")


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type(TYPE, func(player: int,
			pl: Dictionary) -> GameCommand:
		return CounterChoiceCommand.new(player, pl))


## Pure command-specific guard before Counter's registered rule hook can
## inspect the choice, participant indices, or nested pool.
static func prehook_reason(command: GameCommand,
		game_state: GameState) -> String:
	if typeof(command.payload.get("accepted")) != TYPE_BOOL:
		return "Counter choice requires a native boolean accepted value."
	if typeof(command.payload.get("attack_id")) != TYPE_STRING \
			or str(command.payload.get("attack_id", "")).is_empty():
		return "Counter choice requires an exact source attack identity."
	for key: String in ["counter_attacker_player",
			"counter_attacker_squadron_index", "counter_target_player",
			"counter_target_squadron_index"]:
		if typeof(command.payload.get(key)) != TYPE_INT:
			return "Counter choice has an invalid participant identity."
		var value: int = int(command.payload[key])
		if key.ends_with("_player"):
			if value < 0 or value >= Constants.PLAYER_COUNT:
				return "Counter choice has an invalid participant identity."
		elif value < 0 or value > 2147483647:
			return "Counter choice has an invalid participant identity."
	if not command.payload.get("counter_dice_pool") is Dictionary:
		return "Counter choice requires a Dictionary dice pool."
	var pool: Dictionary = command.payload["counter_dice_pool"] as Dictionary
	if not pool.has("BLUE"):
		return "Counter choice requires BLUE dice."
	for key: Variant in pool:
		if typeof(key) != TYPE_STRING \
				or typeof(pool[key]) != TYPE_INT or int(pool[key]) < 0 \
				or int(pool[key]) > 9007199254740991:
			return "Counter choice has an invalid dice pool."
	if int(pool["BLUE"]) <= 0:
		return "Counter choice requires positive BLUE dice."
	if game_state == null or game_state.current_attack_state == null \
			or not game_state.current_attack_state.active:
		return "Counter choice requires an active parent attack."
	var parent: CurrentAttackState = game_state.current_attack_state
	if parent.attack_id != command.payload["attack_id"] \
			or parent.counter_disposition \
					!= CurrentAttackState.COUNTER_UNDECIDED:
		return "Counter choice source is stale or already decided."
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null or flow.flow_type != Constants.InteractionFlow.ATTACK \
			or flow.step_id != Constants.InteractionStep.ATTACK_COUNTER_CHOICE \
			or flow.payload.get("attack_id") != command.payload["attack_id"]:
		return "Counter choice has no matching installed publication."
	if not COUNTER_CONSISTENCY.reconstructed_state_is_consistent(game_state):
		return "Counter choice publication disagrees with canonical owners."
	return ""


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, TYPE, p_payload)


## Validates ownership, active flow surface, and Counter identity metadata.
func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if base != "":
		return base
	var safe_shape: String = prehook_reason(self, game_state)
	if not safe_shape.is_empty():
		return safe_shape
	var phase_error: String = _validate_phase(game_state)
	if phase_error != "":
		return phase_error
	var flow_error: String = _validate_flow(game_state)
	if flow_error != "":
		return flow_error
	var identity_error: String = _validate_identity(
			game_state.interaction_flow.payload)
	if not identity_error.is_empty():
		return identity_error
	var counter_rule: Dictionary = CounterKeyword.new().validate_counter_choice(
			game_state, self)
	if not bool(counter_rule.get("allowed", false)):
		return str(counter_rule.get("reason", "Invalid Counter choice."))
	return ""


## Commits the single source-scoped decision in the parent Attack owner. The
## flow boolean is only a projection of that accepted canonical replacement.
func execute(game_state: GameState) -> Dictionary:
	var parent: CurrentAttackState = game_state.current_attack_state
	var accepted: bool = bool(payload["accepted"])
	var disposition: String = CurrentAttackState.COUNTER_ACCEPTED \
			if accepted else CurrentAttackState.COUNTER_DECLINED
	var replacement: CurrentAttackState = parent.with_patch({
		"counter_disposition": disposition,
	})
	if replacement == null \
			or not game_state.set_current_attack_state(replacement):
		return {}
	game_state.interaction_flow.payload["counter_choice_accepted"] = accepted
	var result: Dictionary = payload.duplicate(true)
	result.erase("accepted")
	result[RESULT_COUNTER_ACCEPTED] = accepted
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
