## PublishAttackFlowCommand
##
## Synchronisation command that broadcasts the current attack
## [InteractionFlow] snapshot from the host (the peer driving the
## attack via [AttackExecutor] / [AttackFlowFSM]) to all peers.
##
## Why this exists — Phase I6b-3 fix:
##
## [AttackFlowFSM.advance] and [AttackFlowFSM.patch_payload] are called
## from [code]src/scenes/game_board/attack_executor.gd[/code] (host-only
## presentation code) and mutate
## [member GameState.interaction_flow] directly.  Before Phase I6c, the
## legacy [code]NetworkInteractionState[/code] parallel channel
## replicated those mutations to the client; that channel was deleted in
## [code]c3e8343[/code], leaving the client's
## [member GameState.interaction_flow] frozen at whatever step the last
## actual command set.
##
## This command re-establishes the replication via the canonical command
## channel:  the host submits it after every FSM transition, the
## broadcast applies it on every peer, and [UIProjector.project] on the
## client now sees the up-to-date attack step (in particular,
## [constant Constants.InteractionStep.ATTACK_DEFENSE_TOKENS] for the
## defender mirror panel).
##
## **No game-logic side effects.**  This command only writes
## [member GameState.interaction_flow]; it never mutates ships,
## tokens, dice, or any other gameplay state.
##
## Payload:
##   "step_id"             — int, [enum Constants.InteractionStep]
##   "controller_player"   — int (-1 when no controller)
##   "flow_payload"        — Dictionary (deep-copied attack payload)
##   "final"               — bool; when true, clears the flow to
##                            [method InteractionFlow.empty]
##   "source_attack_id"    — required canonical attack lifecycle identity
##
## Plan: [code]docs/refactoring_phase_i_plan.md[/code] §I6b-3.
class_name PublishAttackFlowCommand
extends GameCommand


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")
const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("publish_attack_flow", func(player: int,
			pl: Dictionary) -> GameCommand:
		return PublishAttackFlowCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "publish_attack_flow", p_payload)


func validate(game_state: GameState) -> String:
	var base: String = super.validate(game_state)
	if not base.is_empty():
		return base
	if payload.size() != 5:
		return "Attack-flow publication payload does not match its exact schema."
	for key: String in ["step_id", "controller_player", "flow_payload",
			"final", "source_attack_id"]:
		if not payload.has(key):
			return "Attack-flow publication payload does not match its exact schema."
	if typeof(payload.get("step_id")) != TYPE_INT \
			or typeof(payload.get("controller_player")) != TYPE_INT \
			or not payload.get("flow_payload") is Dictionary \
			or typeof(payload.get("final")) != TYPE_BOOL \
			or typeof(payload.get("source_attack_id")) != TYPE_STRING:
		return "Attack-flow publication payload has invalid field types."
	var source_attack_id: String = str(payload["source_attack_id"])
	if not _is_canonical_attack_id(source_attack_id):
		return "Attack-flow publication has invalid source attack identity."
	var flow_payload: Dictionary = payload["flow_payload"] as Dictionary
	if bool(payload["final"]):
		return _validate_final(game_state, source_attack_id, flow_payload)
	return _validate_non_final(game_state, source_attack_id, flow_payload)


## Writes the snapshot into [member GameState.interaction_flow] on the
## receiving peer.
func execute(game_state: GameState) -> Dictionary:
	if bool(payload.get("final", false)):
		game_state.interaction_flow = InteractionFlow.empty()
		return {"applied": true, "final": true}
	var step_id: Constants.InteractionStep = (int(
			payload.get("step_id",
			int(Constants.InteractionStep.NONE)))
			as Constants.InteractionStep)
	var flow_payload: Dictionary = (payload.get("flow_payload", {})
			as Dictionary).duplicate(true)
	flow_payload.erase("ecm_pending_authorization")
	if step_id == Constants.InteractionStep.ATTACK_DEFENSE_TOKENS:
		flow_payload = ECM_SCRIPT.decorate_projection_payload(
				game_state, flow_payload)
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.ATTACK,
			step_id,
			game_state,
			_attack_controller_context(flow_payload),
			Constants.Visibility.ALL,
			flow_payload)
	return {"applied": true, "step_id": int(step_id)}


func _validate_non_final(game_state: GameState, source_attack_id: String,
		flow_payload: Dictionary) -> String:
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack == null or not attack.active:
		return "Attack-flow publication requires an active current attack."
	if attack.attack_id != source_attack_id:
		return "Stale attack-flow publication source identity."
	if typeof(flow_payload.get("attack_id")) != TYPE_STRING \
			or str(flow_payload.get("attack_id", "")) != source_attack_id:
		return "Attack-flow payload source identity mismatch."
	var step_id: int = int(payload["step_id"])
	if not FLOW_SPEC_SCRIPT.has_spec(
			int(Constants.InteractionFlow.ATTACK), step_id):
		return "Attack-flow publication has an invalid interaction step."
	return ""


func _validate_final(game_state: GameState, source_attack_id: String,
		flow_payload: Dictionary) -> String:
	if not flow_payload.is_empty():
		return "Final attack-flow publication must carry an empty flow payload."
	var attack: CurrentAttackState = game_state.current_attack_state
	if attack != null and attack.active:
		return "Final attack-flow publication cannot clear an active attack."
	var flow: InteractionFlow = game_state.interaction_flow
	if flow == null or flow.flow_type != Constants.InteractionFlow.ATTACK:
		return "Final attack-flow publication has no matching attack projection."
	if typeof(flow.payload.get("attack_id")) != TYPE_STRING \
			or str(flow.payload.get("attack_id", "")) != source_attack_id:
		return "Final attack-flow publication source identity mismatch."
	var projected_attacker: Variant = flow.payload.get("attacker_player")
	if typeof(projected_attacker) != TYPE_INT \
			or int(projected_attacker) != player_index:
		return "Final attack-flow publication attacker identity mismatch."
	var inspection: CompletedAttackInspection = \
			game_state.completed_attack_inspection
	if inspection != null:
		var inspection_data: Dictionary = inspection.serialize()
		var inspection_attacker: Dictionary = inspection_data.get(
				"attacker", {}) as Dictionary
		if inspection.source_attack_id() != source_attack_id \
				or int(inspection_attacker.get("player", -1)) != player_index:
			return "Final attack-flow publication inspection identity mismatch."
	return ""


static func _is_canonical_attack_id(value: String) -> bool:
	if not value.begins_with("attack:"):
		return false
	var raw_sequence: String = value.trim_prefix("attack:")
	return raw_sequence.is_valid_int() and raw_sequence.to_int() >= 0 \
			and str(raw_sequence.to_int()) == raw_sequence


func _attack_controller_context(flow_payload: Dictionary) -> Dictionary:
	var snapshot_controller: int = int(payload.get("controller_player", -1))
	return {
		"attacker_player": _first_valid_player([
				flow_payload.get("attacker_player", -1),
				payload.get("attacker_player", -1),
				snapshot_controller,
		]),
		"defender_player": _first_valid_player([
				flow_payload.get("defender_player", -1),
				payload.get("defender_player", -1),
		]),
		"controller_player": _first_valid_player([
				flow_payload.get("chooser_player", -1),
				flow_payload.get("controller_player", -1),
				snapshot_controller,
		]),
	}


func _first_valid_player(candidates: Array) -> int:
	for candidate: Variant in candidates:
		var player: int = int(candidate)
		if player >= 0 and player < Constants.PLAYER_COUNT:
			return player
	return -1
