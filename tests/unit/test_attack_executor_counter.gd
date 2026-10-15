## Test: AttackExecutor Counter Trigger
##
## Regression tests for Counter triggering from the attack damage-resolution
## boundary.
extends GutTest


const CurrentAttackFixture: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")


var _previous_game_state: GameState = null


class StubAttackExecutor:
	extends AttackExecutor

	var confirm_shown: bool = false


	func _attack_exec_show_confirm() -> void:
		confirm_shown = true


func before_each() -> void:
	_previous_game_state = GameManager.current_game_state
	GameManager.current_game_state = null


func after_each() -> void:
	GameManager.current_game_state = _previous_game_state


func test_resolve_damage_zero_damage_squadron_attack_offers_counter() -> void:
	var executor: AttackExecutor = AttackExecutor.new()
	add_child_autofree(executor)
	var attacker: SquadronToken = _make_squadron_token(0, [])
	var defender: SquadronToken = _make_squadron_token(1, [{"name": "Counter", "value": 2}])
	executor._state.attacker_squadron = attacker
	executor._state.defender_squadron = defender
	executor._state.modified_damage = 0
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SQUADRON
	state.player_states[0].squadrons.append(
			attacker.get_squadron_instance())
	state.player_states[1].squadrons.append(
			defender.get_squadron_instance())
	assert_not_null(CurrentAttackFixture.install(state, {
		"attack_id": "attack:20",
		"attacker_player": 0,
		"attacker_kind": CurrentAttackState.KIND_SQUADRON,
		"defender_player": 1,
		"defender_kind": CurrentAttackState.KIND_SQUADRON,
		"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
		"stage": CurrentAttackState.STAGE_DEFENSE,
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
		"dice_results": [{"color": int(Constants.DiceColor.BLUE),
			"face": int(Constants.DiceFace.BLANK)}],
	}), "Fixture should install the canonical zero-damage attack")
	GameManager.current_game_state = state
	executor._flow_fsm.begin(null, 0, -1, {})
	executor._flow_fsm.advance(null, AttackFlowFSM.Step.ROLL)
	executor._flow_fsm.advance(null, AttackFlowFSM.Step.MODIFY)
	executor._flow_fsm.advance(null, AttackFlowFSM.Step.RESOLVE_DAMAGE)

	var command := ResolveDamageCommand.new(0, {"attack_id": "attack:20"})
	assert_eq(command.validate(state), "",
			"Canonical zero-damage resolution should validate")
	executor.apply_damage_result(command.execute(state))

	assert_same(executor._pending_counter_attacker, defender,
			"Zero-damage squadron attacks should still offer defender Counter.")
	assert_same(executor._pending_counter_target, attacker,
			"Counter should target the squadron that performed the attack.")
	assert_eq(executor._flow_fsm.get_interaction_step(),
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE,
			"Counter availability should move into a defender-owned choice step.")
	assert_true(bool(executor._flow_fsm.payload.get(
			CounterKeyword.PAYLOAD_AVAILABLE, false)),
			"Counter payload should mark the optional attack available.")
	assert_eq(executor._flow_fsm.payload.get(
			CounterKeyword.PAYLOAD_DICE_POOL, {}), {"BLUE": 2},
			"Counter payload should expose the defender's Counter dice pool.")


func test_no_defense_damage_result_reconciles_modify_before_counter() -> void:
	var fixture: Dictionary = _counter_damage_fixture("attack:22")
	var executor: AttackExecutor = fixture["executor"] as AttackExecutor
	var state: GameState = fixture["state"] as GameState
	executor._flow_fsm.begin(state, 0, -1, {"attack_id": "attack:22"})
	assert_true(executor._flow_fsm.advance(state, AttackFlowFSM.Step.ROLL))
	assert_true(executor._flow_fsm.advance(state, AttackFlowFSM.Step.MODIFY))

	var accuracy := CommitAccuracyCommand.new(0, {
		"attack_id": "attack:22", "locked_tokens": [],
	})
	assert_eq(accuracy.validate(state), "")
	accuracy.execute(state)
	assert_eq(state.current_attack_state.defense_stage,
			CurrentAttackState.DEFENSE_COMPLETE)
	var damage := ResolveDamageCommand.new(0, {"attack_id": "attack:22"})
	assert_eq(damage.validate(state), "")
	executor.apply_damage_result(damage.execute(state))

	assert_eq(executor._flow_fsm.current_step,
			AttackFlowFSM.Step.COUNTER_CHOICE)
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE)
	assert_eq(state.interaction_flow.controller_player, 1)
	assert_eq(state.interaction_flow.payload.get("attack_id", ""), "attack:22")
	assert_true(bool(state.interaction_flow.payload.get(
			CounterKeyword.PAYLOAD_AVAILABLE, false)))


func test_illegal_damage_flow_reconciliation_fails_without_publication() -> void:
	var fixture: Dictionary = _counter_damage_fixture("attack:23")
	var executor: AttackExecutor = fixture["executor"] as AttackExecutor
	var state: GameState = fixture["state"] as GameState
	executor._flow_fsm.begin(state, 0, -1, {"attack_id": "attack:23"})
	var before: Dictionary = state.interaction_flow.serialize()
	var accuracy := CommitAccuracyCommand.new(0, {
		"attack_id": "attack:23", "locked_tokens": [],
	})
	assert_eq(accuracy.validate(state), "")
	accuracy.execute(state)
	var damage := ResolveDamageCommand.new(0, {"attack_id": "attack:23"})
	assert_eq(damage.validate(state), "")
	executor.apply_damage_result(damage.execute(state))
	assert_push_error(1,
			"Illegal presentation reconciliation should report one error.")

	assert_eq(state.interaction_flow.serialize(), before)
	assert_eq(executor._flow_fsm.current_step, AttackFlowFSM.Step.DECLARE)
	assert_eq(executor._applied_damage_attack_id, "")
	assert_null(executor._pending_counter_attacker)
	assert_null(executor._pending_counter_target)


func test_waiting_remote_result_detected() -> void:
	var executor: AttackExecutor = AttackExecutor.new()
	add_child_autofree(executor)
	assert_true(executor._is_waiting_for_remote_command_result(
			{"awaiting_remote": true}),
			"Network submitter sentinels should not be parsed as dice results.")
	assert_false(executor._is_waiting_for_remote_command_result(
			{"dice_results": []}),
			"Real command results should continue through normal handling.")


func test_destroyed_counter_reconstruction_is_detached_idempotent_and_cleaned() \
		-> void:
	var fixture: Dictionary = _active_destroyed_counter_fixture("attack:30")
	var executor: AttackExecutor = fixture["executor"] as AttackExecutor
	var state: GameState = fixture["state"] as GameState
	var defender_token: SquadronToken = fixture["defender_token"] as SquadronToken
	var refs: Dictionary = executor._resolve_resume_references(
			state, state.current_attack_state, func(_entity: RefCounted): return null,
			func(entity: RefCounted):
				return defender_token \
						if entity == state.get_squadron(0, 0) else null)
	assert_true(bool(refs.get(AttackExecutor.RESUME_KEY_OK, false)))
	var first: SquadronToken = refs.get("attacker_token") as SquadronToken
	assert_not_null(first)
	assert_same(first, executor._transient_destroyed_counter_attacker)
	assert_same(first.get_parent(), executor)
	assert_false(first.visible)

	executor._dispose_transient_destroyed_counter_attacker()
	assert_false(is_instance_valid(first))
	var second_refs: Dictionary = executor._resolve_resume_references(
			state, state.current_attack_state, func(_entity: RefCounted): return null,
			func(entity: RefCounted):
				return defender_token \
						if entity == state.get_squadron(0, 0) else null)
	var second: SquadronToken = second_refs.get("attacker_token") as SquadronToken
	assert_not_null(second)
	assert_ne(second, first)
	executor._reset_exec_state()
	assert_null(executor._transient_destroyed_counter_attacker)
	assert_false(is_instance_valid(second))


func test_destroyed_counter_reconstruction_reuses_existing_detached_token() \
		-> void:
	var fixture: Dictionary = _active_destroyed_counter_fixture("attack:31")
	var executor: AttackExecutor = fixture["executor"] as AttackExecutor
	var state: GameState = fixture["state"] as GameState
	var detached: SquadronToken = fixture["attacker_token"] as SquadronToken
	var defender_token: SquadronToken = fixture["defender_token"] as SquadronToken
	executor._state.defender_squadron = detached
	var refs: Dictionary = executor._resolve_resume_references(
			state, state.current_attack_state, func(_entity: RefCounted): return null,
			func(entity: RefCounted):
				return defender_token \
						if entity == state.get_squadron(0, 0) else null)
	assert_same(refs.get("attacker_token"), detached)
	assert_null(executor._transient_destroyed_counter_attacker)


func test_destroyed_non_counter_reconstruction_fails_closed() -> void:
	var fixture: Dictionary = _active_destroyed_counter_fixture(
			"attack:32", SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD)
	var executor: AttackExecutor = fixture["executor"] as AttackExecutor
	var state: GameState = fixture["state"] as GameState
	var defender_token: SquadronToken = fixture["defender_token"] as SquadronToken
	var refs: Dictionary = executor._resolve_resume_references(
			state, state.current_attack_state,
			func(_entity: RefCounted): return null,
			func(entity: RefCounted):
				return defender_token \
						if entity == state.get_squadron(0, 0) else null)
	assert_false(bool(refs.get(AttackExecutor.RESUME_KEY_OK, false)))
	assert_null(executor._transient_destroyed_counter_attacker)


func test_destroyed_counter_reconstruction_after_canonical_round_trip() -> void:
	var fixture: Dictionary = _active_destroyed_counter_fixture("attack:33")
	var source: GameState = fixture["state"] as GameState
	var restored: GameState = GameState.deserialize(source.serialize())
	assert_not_null(restored)
	GameManager.current_game_state = restored
	var executor := AttackExecutor.new()
	add_child_autofree(executor)
	var restored_defender: SquadronInstance = restored.get_squadron(0, 0)
	var defender_token: SquadronToken = _make_squadron_token(0, [])
	defender_token._squadron_instance = restored_defender

	var refs: Dictionary = executor._resolve_resume_references(
			restored, restored.current_attack_state,
			func(_entity: RefCounted): return null,
			func(entity: RefCounted):
				return defender_token if entity == restored_defender else null)
	assert_true(bool(refs.get(AttackExecutor.RESUME_KEY_OK, false)))
	var transient: SquadronToken = refs.get("attacker_token") as SquadronToken
	assert_not_null(transient)
	assert_same(transient.get_squadron_instance(), restored.get_squadron(1, 0))
	assert_true(transient.get_squadron_instance().is_destroyed())
	assert_false(transient.visible)
	executor._reset_exec_state()
	assert_false(is_instance_valid(transient))


func test_destroyed_counter_failed_reconstruction_cleans_transient() -> void:
	var fixture: Dictionary = _active_destroyed_counter_fixture("attack:34")
	var executor: AttackExecutor = fixture["executor"] as AttackExecutor
	var state: GameState = fixture["state"] as GameState
	var refs: Dictionary = executor._resolve_resume_references(
			state, state.current_attack_state,
			func(_entity: RefCounted): return null,
			func(_entity: RefCounted): return null)
	assert_false(bool(refs.get(AttackExecutor.RESUME_KEY_OK, false)))
	assert_null(executor._transient_destroyed_counter_attacker)


func test_destroyed_counter_reconstruction_rejects_inexact_projection_identity() \
		-> void:
	var fixture: Dictionary = _active_destroyed_counter_fixture("attack:35")
	var executor: AttackExecutor = fixture["executor"] as AttackExecutor
	var state: GameState = fixture["state"] as GameState
	var defender_token: SquadronToken = fixture["defender_token"] as SquadronToken
	for invalid: Variant in [0.5, true, "0", INF]:
		state.interaction_flow.payload["attacker_squadron_index"] = invalid
		var refs: Dictionary = executor._resolve_resume_references(
				state, state.current_attack_state,
				func(_entity: RefCounted): return null,
				func(entity: RefCounted):
					return defender_token \
							if entity == state.get_squadron(0, 0) else null)
		assert_false(bool(refs.get(AttackExecutor.RESUME_KEY_OK, false)),
				"Presentation identity must reject %s." % str(invalid))
		assert_null(executor._transient_destroyed_counter_attacker)


func test_standard_swarm_reroll_echo_updates_attack_results() -> void:
	var executor: StubAttackExecutor = StubAttackExecutor.new()
	add_child_autofree(executor)
	var attacker: SquadronToken = _make_squadron_token(1, [
		{"name": "Swarm"},
	])
	executor._state.attacker_squadron = attacker
	executor._state.squad_exec_mode = true
	executor._state.attack_kind = \
			SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD
	executor._state.dice_results = [{
		"color": Constants.DiceColor.BLUE,
		"face": Constants.DiceFace.HIT,
	}]
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SQUADRON
	assert_not_null(CurrentAttackFixture.install(state, {
		"attack_id": "attack:21",
		"attacker_player": 1,
		"attacker_kind": CurrentAttackState.KIND_SQUADRON,
		"defender_player": 0,
		"defender_kind": CurrentAttackState.KIND_SQUADRON,
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
		"dice_results": [{"color": int(Constants.DiceColor.BLUE),
			"face": int(Constants.DiceFace.CRITICAL)}],
	}), "Fixture should install canonical rerolled dice")
	GameManager.current_game_state = state
	executor._pending_reroll_rule_id = SwarmKeyword.RULE_ID
	var command := RerollAttackDieCommand.new(1, {
		"attack_id": "attack:21",
		"source_rule_id": SwarmKeyword.RULE_ID,
	})
	var result: Dictionary = {
		"die_index": 0,
		"new_result": {
			"color": Constants.DiceColor.BLUE,
			"face": Constants.DiceFace.CRITICAL,
		},
		"dice_results": [{
			"color": Constants.DiceColor.BLUE,
			"face": Constants.DiceFace.CRITICAL,
		}],
		"source_rule_id": SwarmKeyword.RULE_ID,
	}
	executor.apply_remote_counter_reroll_result(command, result)
	var updated: Dictionary = executor._state.dice_results[0]
	assert_eq(updated.get("face", -1), Constants.DiceFace.CRITICAL,
			"Standard Swarm reroll echoes should update the active attack.")
	assert_eq(executor._pending_reroll_rule_id, "",
			"Resolved Swarm rerolls should clear the pending prompt.")
	assert_true(executor.confirm_shown,
			"A resolved Swarm reroll should advance to dice confirmation.")


func _make_squadron_token(player: int,
		keywords: Array[Dictionary]) -> SquadronToken:
	var data_key: String = "x_wing_squadron" \
			if player == 0 else "tie_interceptor_squadron"
	var token: SquadronToken = SquadronToken.new()
	token._placement = TokenPlacement.new(data_key, false,
			Constants.Faction.REBEL_ALLIANCE, 0.5, 0.5, 0.0)
	token._radius_px = 20.0
	token._squadron_instance = _make_squadron(data_key, player, keywords)
	add_child_autofree(token)
	return token


func _counter_damage_fixture(attack_id: String) -> Dictionary:
	var executor := AttackExecutor.new()
	add_child_autofree(executor)
	var attacker: SquadronToken = _make_squadron_token(0, [])
	var defender: SquadronToken = _make_squadron_token(
			1, [{"name": "Counter", "value": 2}])
	executor._state.attacker_squadron = attacker
	executor._state.defender_squadron = defender
	executor._state.modified_damage = 0
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SQUADRON
	state.player_states[0].squadrons.append(attacker.get_squadron_instance())
	state.player_states[1].squadrons.append(defender.get_squadron_instance())
	assert_not_null(CurrentAttackFixture.install(state, {
		"attack_id": attack_id,
		"attacker_player": 0,
		"attacker_kind": CurrentAttackState.KIND_SQUADRON,
		"defender_player": 1,
		"defender_kind": CurrentAttackState.KIND_SQUADRON,
		"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
		"stage": CurrentAttackState.STAGE_ACCURACY,
		"dice_results": [{"color": int(Constants.DiceColor.BLUE),
			"face": int(Constants.DiceFace.BLANK)}],
	}), "Fixture should install the no-defense accuracy state")
	GameManager.current_game_state = state
	return {"executor": executor, "state": state}


func _active_destroyed_counter_fixture(attack_id: String,
		attack_kind: String = SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER) \
		-> Dictionary:
	var executor := AttackExecutor.new()
	add_child_autofree(executor)
	var attacker_token: SquadronToken = _make_squadron_token(
			1, [{"name": "Counter", "value": 2}])
	var defender_token: SquadronToken = _make_squadron_token(0, [])
	var attacker: SquadronInstance = attacker_token.get_squadron_instance()
	var defender: SquadronInstance = defender_token.get_squadron_instance()
	attacker.mark_destroyed()
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SQUADRON
	state.player_states[0].squadrons.append(defender)
	state.player_states[1].squadrons.append(attacker)
	assert_not_null(CurrentAttackFixture.install(state, {
		"attack_id": attack_id,
		"attacker_player": 1,
		"attacker_kind": CurrentAttackState.KIND_SQUADRON,
		"attacker_index": 0,
		"defender_player": 0,
		"defender_kind": CurrentAttackState.KIND_SQUADRON,
		"defender_index": 0,
		"attack_kind": attack_kind,
		"stage": CurrentAttackState.STAGE_PRE_ROLL,
		"dice_pool": {"BLUE": 2},
	}))
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			1, Constants.Visibility.ALL, {
				"attack_id": attack_id,
				"attacker_player": 1,
				"attacker_squadron_index": 0,
				"defender_player": 0,
				"target_squadron_index": 0,
			})
	GameManager.current_game_state = state
	return {"executor": executor, "state": state,
		"attacker_token": attacker_token, "defender_token": defender_token}


func _make_squadron(data_key: String, player: int,
		keywords: Array[Dictionary]) -> SquadronInstance:
	var data: SquadronData = AssetLoader.load_squadron_data(
			data_key).duplicate(true) as SquadronData
	data.keywords = keywords
	return SquadronInstance.create_from_data(data_key, data, player)
