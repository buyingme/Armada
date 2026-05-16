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
##
## Plan: [code]docs/refactoring_phase_i_plan.md[/code] §I6b-3.
class_name PublishAttackFlowCommand
extends GameCommand


const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")


## Registers this command type with the [GameCommand] factory.
static func register() -> void:
	GameCommand.register_type("publish_attack_flow", func(player: int,
			pl: Dictionary) -> GameCommand:
		return PublishAttackFlowCommand.new(player, pl))


func _init(p_player: int = 0,
		p_payload: Dictionary = {}) -> void:
	super._init(p_player, "publish_attack_flow", p_payload)


## Always valid — this command is a pure flow-snapshot publication.
func validate(game_state: GameState) -> String:
	return super.validate(game_state)


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
	var flow_payload: Dictionary = payload.get("flow_payload", {})
	game_state.interaction_flow = FLOW_SPEC_SCRIPT.make_interaction_flow(
			Constants.InteractionFlow.ATTACK,
			step_id,
			game_state,
			_attack_controller_context(flow_payload),
			Constants.Visibility.ALL,
			flow_payload)
	return {"applied": true, "step_id": int(step_id)}


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
