## Test: AttackExecutor Counter Trigger
##
## Regression tests for Counter triggering from the attack damage-resolution
## boundary.
extends GutTest


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
	executor._flow_fsm.begin(null, 0, -1, {})
	executor._flow_fsm.advance(null, AttackFlowFSM.Step.ROLL)
	executor._flow_fsm.advance(null, AttackFlowFSM.Step.MODIFY)

	executor._attack_exec_resolve_damage()

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


func test_waiting_remote_result_detected() -> void:
	var executor: AttackExecutor = AttackExecutor.new()
	add_child_autofree(executor)
	assert_true(executor._is_waiting_for_remote_command_result(
			{"awaiting_remote": true}),
			"Network submitter sentinels should not be parsed as dice results.")
	assert_false(executor._is_waiting_for_remote_command_result(
			{"dice_results": []}),
			"Real command results should continue through normal handling.")


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
	executor._pending_reroll_rule_id = SwarmKeyword.RULE_ID
	var command := RerollAttackDieCommand.new(1, {
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
	var token: SquadronToken = SquadronToken.new()
	token._placement = TokenPlacement.new("test_squadron", false,
			Constants.Faction.REBEL_ALLIANCE, 0.5, 0.5, 0.0)
	token._radius_px = 20.0
	token._squadron_instance = _make_squadron(player, keywords)
	add_child_autofree(token)
	return token


func _make_squadron(player: int,
		keywords: Array[Dictionary]) -> SquadronInstance:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "Test Squadron"
	data.hull = 3
	data.speed = 3
	data.keywords = keywords
	return SquadronInstance.create_from_data("test_squadron", data, player)