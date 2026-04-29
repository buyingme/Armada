## Tests for PublishAttackFlowCommand.
##
## Covers register/factory, execute (regular snapshot + final clears
## flow), and serialize/deserialize roundtrip.  Phase I6b-3 fix.
extends GutTest


var _state: GameState


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_round = 1
	_state.current_phase = Constants.GamePhase.SHIP
	PublishAttackFlowCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("publish_attack_flow")


func test_execute_writes_attack_flow_snapshot() -> void:
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_DEFENSE_TOKENS),
		"controller_player": 1,
		"flow_payload": {"modified_damage": 4, "defender_zone": "front"},
		"final": false,
	})
	var result: Dictionary = cmd.execute(_state)

	assert_true(result.get("applied", false), "execute should report applied")
	var flow: InteractionFlow = _state.interaction_flow
	assert_eq(flow.flow_type,
			Constants.InteractionFlow.ATTACK,
			"flow_type should be ATTACK")
	assert_eq(int(flow.step_id),
			int(Constants.InteractionStep.ATTACK_DEFENSE_TOKENS),
			"step_id should match payload")
	assert_eq(flow.controller_player, 1,
			"controller_player should match payload")
	assert_eq(int(flow.payload.get("modified_damage", 0)), 4,
			"payload.modified_damage should match")


func test_execute_final_clears_flow() -> void:
	# Pre-seed interaction_flow with a non-empty value.
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			0,
			Constants.Visibility.ALL,
			{"x": 1})
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.NONE),
		"controller_player": -1,
		"flow_payload": {},
		"final": true,
	})
	cmd.execute(_state)

	assert_eq(_state.interaction_flow.flow_type,
			Constants.InteractionFlow.NONE,
			"final=true should clear flow_type to NONE")


func test_serialize_roundtrip_preserves_payload() -> void:
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_MODIFY),
		"controller_player": 0,
		"flow_payload": {"dice_results": [{"face": "hit"}]},
		"final": false,
	})
	var dict: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(dict)

	assert_not_null(restored, "deserialize should succeed")
	assert_eq(restored.command_type, "publish_attack_flow",
			"command_type should round-trip")
	assert_eq(int(restored.payload.get("step_id", -1)),
			int(Constants.InteractionStep.ATTACK_MODIFY),
			"step_id should round-trip")
	var pl: Dictionary = restored.payload.get("flow_payload", {})
	var dice: Array = pl.get("dice_results", [])
	assert_eq(dice.size(), 1, "flow_payload should round-trip")


func test_validate_always_returns_empty() -> void:
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.NONE),
		"controller_player": -1,
		"flow_payload": {},
		"final": true,
	})
	assert_eq(cmd.validate(_state), "",
			"validate should always pass for snapshot commands")
