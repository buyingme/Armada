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
		"flow_payload": {"attack_id": "attack:0", "modified_damage": 4,
			"defender_zone": "front"},
		"final": false,
		"source_attack_id": "attack:0",
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


func test_execute_defense_tokens_prefers_defender_identity() -> void:
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_DEFENSE_TOKENS),
		"controller_player": 0,
		"flow_payload": {"attack_id": "attack:0", "attacker_player": 0,
			"defender_player": 1},
		"final": false,
		"source_attack_id": "attack:0",
	})
	cmd.execute(_state)

	assert_eq(_state.interaction_flow.controller_player, 1,
			"DEFENDER_OR_ATTACKER should prefer defender identity over snapshot controller.")


func test_execute_defense_tokens_falls_back_to_attacker_identity() -> void:
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_DEFENSE_TOKENS),
		"controller_player": - 1,
		"flow_payload": {"attack_id": "attack:0", "attacker_player": 0,
			"defender_player": - 1},
		"final": false,
		"source_attack_id": "attack:0",
	})
	cmd.execute(_state)

	assert_eq(_state.interaction_flow.controller_player, 0,
			"DEFENDER_OR_ATTACKER should fall back to attacker identity.")


func test_execute_resolve_damage_uses_attacker_identity() -> void:
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE),
		"controller_player": 1,
		"flow_payload": {"attack_id": "attack:0", "attacker_player": 0,
			"defender_player": 1},
		"final": false,
		"source_attack_id": "attack:0",
	})
	cmd.execute(_state)

	assert_eq(_state.interaction_flow.controller_player, 0,
			"ATTACK_RESOLVE_DAMAGE should resolve to the attacker identity.")


func test_execute_critical_choice_uses_chooser_payload() -> void:
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_CRITICAL_CHOICE),
		"controller_player": 0,
		"flow_payload": {"attack_id": "attack:0", "chooser_player": 1},
		"final": false,
		"source_attack_id": "attack:0",
	})
	cmd.execute(_state)

	assert_eq(_state.interaction_flow.controller_player, 1,
			"PAYLOAD_CONTROLLER should resolve from the chooser payload.")


func test_execute_counter_choice_uses_counter_controller_payload() -> void:
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_COUNTER_CHOICE),
		"controller_player": 0,
		"flow_payload": {"attack_id": "attack:0", "controller_player": 1,
				CounterKeyword.PAYLOAD_CONTROLLER_PLAYER: 1},
		"final": false,
		"source_attack_id": "attack:0",
	})
	cmd.execute(_state)

	assert_eq(_state.interaction_flow.controller_player, 1,
			"Counter choice should resolve to the Counter squadron owner.")


func test_execute_final_clears_flow() -> void:
	# Pre-seed interaction_flow with a non-empty value.
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			0,
			Constants.Visibility.ALL,
			{"attack_id": "attack:0", "attacker_player": 0})
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.NONE),
		"controller_player": - 1,
		"flow_payload": {},
		"final": true,
		"source_attack_id": "attack:0",
	})
	cmd.execute(_state)

	assert_eq(_state.interaction_flow.flow_type,
			Constants.InteractionFlow.NONE,
			"final=true should clear flow_type to NONE")


func test_serialize_roundtrip_preserves_payload() -> void:
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_MODIFY),
		"controller_player": 0,
		"flow_payload": {"attack_id": "attack:0",
			"dice_results": [ {"face": "hit"}]},
		"final": false,
		"source_attack_id": "attack:0",
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


func test_builder_stamps_installed_flow_before_serialized_snapshot() -> void:
	assert_not_null(CurrentAttackStateFixture.install(_state, {
		"attack_id": "attack:42",
	}))
	var flow := InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			0,
			Constants.Visibility.ALL,
			{"final_damage": 1})
	_state.interaction_flow = flow

	var cmd: PublishAttackFlowCommand = \
			GameManager.build_publish_attack_flow_command(_state, flow, 0)

	assert_not_null(cmd, "A valid live ATTACK projection should publish.")
	assert_same(_state.interaction_flow, flow,
			"The builder must stamp the actual installed projection.")
	assert_eq(flow.payload.get("attack_id"), "attack:42",
			"The installed projection must retain the canonical source.")
	assert_eq(cmd.payload.get("source_attack_id"), "attack:42")
	var command_payload: Dictionary = cmd.payload.get("flow_payload", {})
	assert_eq(command_payload.get("attack_id"), "attack:42",
			"The outgoing snapshot must carry the installed source.")
	var restored: GameCommand = GameCommand.deserialize(cmd.serialize())
	assert_not_null(restored, "The stamped publication must serialize.")
	assert_eq((restored.payload.get("flow_payload", {}) as Dictionary).get(
			"attack_id"), "attack:42")


func test_builder_accepts_matching_installed_source() -> void:
	assert_not_null(CurrentAttackStateFixture.install(_state, {
		"attack_id": "attack:42",
	}))
	var flow := InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			0,
			Constants.Visibility.ALL,
			{"attack_id": "attack:42", "final_damage": 1})
	_state.interaction_flow = flow

	var cmd: PublishAttackFlowCommand = \
			GameManager.build_publish_attack_flow_command(_state, flow, 0)

	assert_not_null(cmd, "A matching installed source should remain valid.")
	assert_eq(flow.payload.get("attack_id"), "attack:42")
	assert_eq((cmd.payload.get("flow_payload", {}) as Dictionary).get(
			"attack_id"), "attack:42")


func test_builder_rejects_mismatching_installed_source_without_mutation() -> void:
	assert_not_null(CurrentAttackStateFixture.install(_state, {
		"attack_id": "attack:42",
	}))
	var flow := InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			0,
			Constants.Visibility.ALL,
			{"attack_id": "attack:41", "final_damage": 1})
	_state.interaction_flow = flow
	var before: Dictionary = flow.serialize()

	var cmd: PublishAttackFlowCommand = \
			GameManager.build_publish_attack_flow_command(_state, flow, 0)

	assert_null(cmd, "A conflicting installed source must fail closed.")
	assert_eq(flow.serialize(), before,
			"Rejected projection identity must not be mutated.")


func test_validate_accepts_matching_active_attack_snapshot() -> void:
	assert_not_null(CurrentAttackStateFixture.install(_state, {
		"attack_id": "attack:7",
	}))
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_DECLARE),
		"controller_player": 0,
		"flow_payload": {"attack_id": "attack:7"},
		"final": false,
		"source_attack_id": "attack:7",
	})
	assert_eq(cmd.validate(_state), "",
			"A matching active attack snapshot should validate.")


func test_validate_rejects_stale_attack_snapshot() -> void:
	assert_not_null(CurrentAttackStateFixture.install(_state, {
		"attack_id": "attack:8",
	}))
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_DECLARE),
		"controller_player": 0,
		"flow_payload": {"attack_id": "attack:7"},
		"final": false,
		"source_attack_id": "attack:7",
	})
	assert_ne(cmd.validate(_state), "",
			"A stale source identity must be rejected.")


func test_validate_accepts_matching_terminal_clear() -> void:
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			0,
			Constants.Visibility.ALL,
			{"attack_id": "attack:9", "attacker_player": 0})
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.NONE),
		"controller_player": - 1,
		"flow_payload": {},
		"final": true,
		"source_attack_id": "attack:9",
	})
	assert_eq(cmd.validate(_state), "",
			"A source-matching terminal clear should validate.")


func test_validate_rejects_partial_exact_schema() -> void:
	var cmd := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.NONE),
		"controller_player": - 1,
		"flow_payload": {},
		"final": true,
	})
	assert_ne(cmd.validate(_state), "",
			"Missing source identity must fail the exact schema.")
