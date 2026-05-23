## Test: Counter Attack Marker Commands
##
## Verifies the command-backed boundaries used when a non-active player owns
## Counter and subsequent attack decisions in network/replay flows.
extends GutTest


func test_counter_choice_validate_accepts_controller() -> void:
	var state: GameState = _counter_choice_state()
	var command := CounterChoiceCommand.new(1, _counter_choice_payload(true))

	assert_eq(command.validate(state), "",
			"Counter owner should be allowed to accept the Counter choice.")


func test_counter_choice_validate_rejects_original_attacker() -> void:
	var state: GameState = _counter_choice_state()
	var command := CounterChoiceCommand.new(0, _counter_choice_payload(true))

	assert_eq(command.validate(state), "Counter choice belongs to player 1.",
			"Triggering attacker should not own the Counter choice.")


func test_counter_choice_validate_rejects_missing_identity() -> void:
	var state: GameState = _counter_choice_state()
	var payload: Dictionary = _counter_choice_payload(true)
	payload.erase("counter_target_squadron_index")
	var command := CounterChoiceCommand.new(1, payload)

	assert_eq(command.validate(state), "Counter choice identity mismatch.",
			"Counter choice must carry the exact pending attack identity.")


func test_skip_attack_modifier_validate_rejects_non_attacker() -> void:
	var state: GameState = _swarm_modify_state(true)
	var command := SkipAttackModifierCommand.new(0, {
		"source_rule_id": SwarmKeyword.RULE_ID,
	})

	assert_eq(command.validate(state), "Attack modifier belongs to player 1.",
			"Only the attacking controller may skip Swarm.")


func test_skip_attack_modifier_validate_rejects_no_pending_swarm() -> void:
	var state: GameState = _swarm_modify_state(false)
	var command := SkipAttackModifierCommand.new(1, {
		"source_rule_id": SwarmKeyword.RULE_ID,
	})

	assert_eq(command.validate(state), "No Swarm reroll is pending.",
			"Swarm skip command requires the projected Swarm affordance.")


func test_confirm_attack_dice_validate_requires_dice_results() -> void:
	var state: GameState = _confirm_state([])
	var command := ConfirmAttackDiceCommand.new(1, {})

	assert_eq(command.validate(state), "No attack dice results to confirm.",
			"Confirm command should reject an empty dice-result payload.")


func test_confirm_attack_dice_validate_rejects_non_attacker() -> void:
	var state: GameState = _confirm_state(_one_blue_hit())
	var command := ConfirmAttackDiceCommand.new(0, {})

	assert_eq(command.validate(state),
			"Attack dice confirmation belongs to player 1.",
			"Only the attack controller may confirm attack dice.")


func _counter_choice_state() -> GameState:
	var state: GameState = _base_state()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE,
			1, Constants.Visibility.ALL, _counter_flow_payload(true))
	return state


func _counter_flow_payload(available: bool) -> Dictionary:
	var payload: Dictionary = _counter_choice_payload(false)
	payload.erase("accepted")
	payload[CounterKeyword.PAYLOAD_AVAILABLE] = available
	payload[CounterKeyword.PAYLOAD_CONTROLLER_PLAYER] = 1
	return payload


func _counter_choice_payload(accepted: bool) -> Dictionary:
	return {
		"accepted": accepted,
		"counter_attacker_player": 1,
		"counter_attacker_squadron_index": 0,
		"counter_target_player": 0,
		"counter_target_squadron_index": 0,
	}


func _swarm_modify_state(available: bool) -> GameState:
	var state: GameState = _base_state()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			1, Constants.Visibility.ALL, {
				"attacker_player": 1,
				SwarmKeyword.PAYLOAD_AVAILABLE: available,
			})
	return state


func _confirm_state(dice_results: Array[Dictionary]) -> GameState:
	var state: GameState = _base_state()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			1, Constants.Visibility.ALL, {
				"attacker_player": 1,
				"dice_results": dice_results,
			})
	return state


func _base_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SQUADRON
	return state


func _one_blue_hit() -> Array[Dictionary]:
	return [ {"color": Constants.DiceColor.BLUE,
			"face": Constants.DiceFace.HIT}]
