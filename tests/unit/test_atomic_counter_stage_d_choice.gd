## Stage D: source-bound Counter decisions and atomic parent retirement.
extends GutTest


const ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")

var _previous_state: GameState
var _previous_submitter: CommandSubmitter
var _previous_mode: PlayMode.Mode
var _state: GameState


func before_each() -> void:
	_previous_state = GameManager.current_game_state
	_previous_submitter = GameManager.get_command_submitter()
	_previous_mode = PlayMode.current_mode
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	GameManager.set_command_submitter(LocalCommandSubmitter.new())
	CommandProcessor.reset()
	_state = _parent_with_choice(true)
	GameManager.current_game_state = _state
	assert_true(CommandProcessor.restore_next_sequence(72))


func after_each() -> void:
	CommandProcessor.reset()
	GameManager.current_game_state = _previous_state
	GameManager.set_command_submitter(_previous_submitter)
	PlayMode.set_mode(_previous_mode)


func test_choice_commits_exact_parent_and_inspection_witness_direct_json() -> void:
	for accepted: bool in [true, false]:
		for json_path: bool in [false, true]:
			_reset_parent(true)
			var choice: GameCommand = _choice(accepted)
			if json_path:
				choice = _json_command(choice)
			assert_not_null(choice)
			assert_false(CommandProcessor.submit(choice).is_empty())
			assert_eq(_history_types(), ["counter_choice", "complete_attack"])
			assert_false(_state.current_attack_state.active)
			var inspection: CompletedAttackInspection = \
					_state.completed_attack_inspection
			assert_not_null(inspection)
			if inspection == null:
				continue
			assert_eq(inspection.source_attack_id(), "attack:71")
			assert_eq(inspection.counter_disposition(),
					CurrentAttackState.COUNTER_ACCEPTED if accepted \
					else CurrentAttackState.COUNTER_DECLINED)
			assert_eq(_state.interaction_flow.step_id,
					Constants.InteractionStep.ATTACK_COUNTER_CHOICE if accepted \
					else Constants.InteractionStep.ACTION_CHOICE)
			var restored: GameState = _json_state(_state)
			assert_not_null(restored)
			if restored != null:
				assert_eq(CanonicalJson.hash(restored.serialize()),
						CanonicalJson.hash(_state.serialize()))


func test_no_inspection_accept_replaces_parent_and_decline_retires() -> void:
	for accepted: bool in [true, false]:
		_reset_parent(false)
		assert_false(CommandProcessor.submit(_choice(accepted)).is_empty())
		assert_null(_state.completed_attack_inspection)
		if accepted:
			assert_eq(_history_types(), ["counter_choice", "begin_attack"])
			assert_true(_state.current_attack_state.active)
			assert_eq(_state.current_attack_state.attack_kind,
					SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER)
			assert_eq(_state.current_attack_state.attack_id, "attack:73")
			assert_eq(_state.interaction_flow.step_id,
					Constants.InteractionStep.ATTACK_DECLARE)
			assert_eq(_state.interaction_flow.payload.get("attack_id"),
					"attack:73")
			assert_eq(CommandProcessor.get_history()[1].payload.get(
					"counter_source_attack_id"), "attack:71")
		else:
			assert_eq(_history_types(), ["counter_choice", "complete_attack"])
			assert_false(_state.current_attack_state.active)
			assert_eq(_state.interaction_flow.step_id,
					Constants.InteractionStep.ACTION_CHOICE)
		var restored: GameState = _json_state(_state)
		assert_not_null(restored)
		if restored != null:
			assert_eq(CanonicalJson.hash(restored.serialize()),
					CanonicalJson.hash(_state.serialize()))


func test_satisfied_inspection_consumes_exactly_once_into_child_and_roll() -> void:
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	assert_false(CommandProcessor.submit(_choice(true)).is_empty())
	var inspection: CompletedAttackInspection = _state.completed_attack_inspection
	assert_not_null(inspection)
	if inspection == null:
		return
	for player: int in [0, 1]:
		assert_false(CommandProcessor.submit(
				AcknowledgeAttackResultCommand.new(player, {
					"inspection_id": inspection.inspection_id(),
				})).is_empty())
	assert_null(_state.completed_attack_inspection)
	assert_eq(_history_types(), ["counter_choice", "complete_attack",
			"acknowledge_attack_result", "acknowledge_attack_result",
			"begin_attack", "publish_attack_flow"])
	assert_eq(CommandProcessor.get_history()[4].payload.get(
			"counter_source_attack_id"), "attack:71")
	assert_eq(_state.current_attack_state.attack_kind,
			SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER)
	assert_eq(_state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_ROLL)
	assert_eq(_state.interaction_flow.payload.get("attack_id"),
			_state.current_attack_state.attack_id)
	assert_null(CurrentAttackContinuation \
			.derive_reconstructed_inspection_release(_state))


func test_counter_child_completion_creates_j_only_when_required() -> void:
	for with_inspection: bool in [false, true]:
		_reset_parent(with_inspection)
		assert_false(CommandProcessor.submit(_choice(true)).is_empty())
		if with_inspection:
			var inspection: CompletedAttackInspection = \
					_state.completed_attack_inspection
			assert_not_null(inspection)
			if inspection == null:
				continue
			for player: int in [0, 1]:
				assert_false(CommandProcessor.submit(
						AcknowledgeAttackResultCommand.new(player, {
							"inspection_id": inspection.inspection_id(),
						})).is_empty())
		var child: CurrentAttackState = _state.current_attack_state
		assert_eq(child.attack_kind,
				SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER)
		var resolved: CurrentAttackState = child.with_patch({
			"stage": CurrentAttackState.STAGE_RESOLVED,
			"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
			"damage_stage": CurrentAttackState.DAMAGE_RESOLVED,
			"accuracy_complete": true,
			"resolved_outcome": {"target_kind": "squadron",
				"requested_hull_damage": 0, "actual_hull_damage": 0,
				"post_resolution_hull": 2, "destroyed": false},
		})
		assert_not_null(resolved)
		if resolved == null:
			continue
		assert_true(_state.set_current_attack_state(resolved))
		assert_false(CommandProcessor.submit(CompleteAttackCommand.new(1, {
			"attack_id": child.attack_id,
		})).is_empty())
		assert_false(_state.current_attack_state.active)
		if with_inspection:
			var j: CompletedAttackInspection = \
					_state.completed_attack_inspection
			assert_not_null(j)
			if j != null:
				assert_eq(j.source_attack_id(), child.attack_id)
				assert_eq(j.counter_disposition(),
						CurrentAttackState.COUNTER_UNDECIDED)
		else:
			assert_null(_state.completed_attack_inspection)
			assert_eq(_state.interaction_flow.step_id,
				Constants.InteractionStep.ACTION_CHOICE)
		var restored: GameState = _json_state(_state)
		assert_not_null(restored)
		if restored != null:
			assert_eq(CanonicalJson.hash(restored.serialize()),
					CanonicalJson.hash(_state.serialize()))


func test_commanded_ship_route_survives_decline_and_child_completion() -> void:
	for accepted: bool in [false, true]:
		_reset_parent(false, true)
		assert_false(CommandProcessor.submit(_choice(accepted)).is_empty())
		if accepted:
			var child: CurrentAttackState = _state.current_attack_state
			assert_eq(child.attack_kind,
					SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER)
			var resolved: CurrentAttackState = child.with_patch({
				"stage": CurrentAttackState.STAGE_RESOLVED,
				"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
				"damage_stage": CurrentAttackState.DAMAGE_RESOLVED,
				"accuracy_complete": true,
				"resolved_outcome": {"target_kind": "squadron",
					"requested_hull_damage": 0, "actual_hull_damage": 0,
					"post_resolution_hull": 2, "destroyed": false},
			})
			assert_not_null(resolved)
			if resolved == null:
				continue
			assert_true(_state.set_current_attack_state(resolved))
			assert_false(CommandProcessor.submit(CompleteAttackCommand.new(1, {
				"attack_id": child.attack_id,
			})).is_empty())
		assert_false(_state.current_attack_state.active)
		assert_eq(_state.interaction_flow.flow_type,
				Constants.InteractionFlow.SHIP_ACTIVATION)
		assert_eq(_state.interaction_flow.step_id,
				Constants.InteractionStep.SQUADRON_STEP)
		assert_eq(_state.interaction_flow.payload.get("ship_index"), 0)
		var restored: GameState = _json_state(_state)
		assert_not_null(restored)
		if restored != null:
			assert_eq(CanonicalJson.hash(restored.serialize()),
					CanonicalJson.hash(_state.serialize()))


func test_stale_duplicate_and_premature_commands_reject_atomically() -> void:
	_assert_rejected(CompleteAttackCommand.new(0, {"attack_id": "attack:71"}))
	var stale: CounterChoiceCommand = _choice(true)
	stale.payload["attack_id"] = "attack:70"
	_assert_rejected(stale)
	_assert_rejected(_json_command(stale))
	var choice: CounterChoiceCommand = _choice(true)
	var duplicate: CounterChoiceCommand = _choice(false)
	assert_eq(choice.validate(_state), "")
	assert_false(choice.execute(_state).is_empty())
	_assert_rejected(duplicate)
	_assert_rejected(_json_command(duplicate))
	_reset_parent(false)
	assert_false(_choice(true).execute(_state).is_empty())
	_assert_rejected(CompleteAttackCommand.new(0, {"attack_id": "attack:71"}))
	var begin: GameCommand = CurrentAttackContinuation \
			.derive_reconstructed_resolved_attack(_state)
	assert_not_null(begin)
	if begin == null:
		return
	begin.payload["counter_source_attack_id"] = "attack:70"
	_assert_rejected(begin)
	_assert_rejected(_json_command(begin))
	assert_engine_error(8)


func test_real_ui_submitters_use_reconstructed_canonical_source() -> void:
	for mirror_path: bool in [false, true]:
		for accepted: bool in [false, true]:
			_reset_parent(true)
			var restored: GameState = _json_state(_state)
			assert_not_null(restored)
			if restored == null:
				continue
			_state = restored
			GameManager.current_game_state = restored
			GameManager.set_command_submitter(LocalCommandSubmitter.new(
					_state.principal_id_for_player(1)))
			if mirror_path:
				var mirror := AttackPanelMirror.new()
				mirror._submit_counter_choice(accepted)
			else:
				var executor := AttackExecutor.new()
				add_child_autofree(executor)
				if accepted:
					executor._on_counter_attack_requested()
				else:
					executor._on_counter_attack_skipped()
			assert_eq(_history_types(), ["counter_choice", "complete_attack"])
			if CommandProcessor.get_history().is_empty():
				continue
			assert_eq(CommandProcessor.get_history()[0].payload.get("attack_id"),
					"attack:71")
			assert_eq(_state.completed_attack_inspection.counter_disposition(),
					CurrentAttackState.COUNTER_ACCEPTED if accepted \
					else CurrentAttackState.COUNTER_DECLINED)


func _assert_rejected(command: GameCommand) -> void:
	assert_not_null(command)
	if command == null:
		return
	var before: Dictionary = _state.serialize()
	var history: int = CommandProcessor.get_command_count()
	var sequence: int = CommandProcessor.get_next_sequence()
	var queue: int = CommandProcessor.get_pending_observer_followup_count()
	assert_true(CommandProcessor.submit(command).is_empty())
	assert_eq(_state.serialize(), before)
	assert_eq(CommandProcessor.get_command_count(), history)
	assert_eq(CommandProcessor.get_next_sequence(), sequence)
	assert_eq(CommandProcessor.get_pending_observer_followup_count(), queue)


func _reset_parent(with_inspection: bool, commanded: bool = false) -> void:
	CommandProcessor.reset()
	assert_true(CommandProcessor.restore_next_sequence(72))
	_state = _parent_with_choice(with_inspection, commanded)
	GameManager.current_game_state = _state


func _parent_with_choice(with_inspection: bool,
		commanded: bool = false) -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SQUADRON
	var binding: MatchPlayerControlBinding = \
			MatchPlayerControlBinding.create_two_human()
	if not with_inspection:
		var kinds: Array[String] = [MatchPlayerControlBinding.KIND_AUTOMATED]
		var indexes: Array[int] = [0, 0]
		binding = MatchPlayerControlBinding.create_new(kinds, indexes)
	assert_true(state.install_match_player_control_binding(binding))
	var deck := DamageDeck.new()
	deck.set_rng(state.rng)
	deck.initialize()
	state.damage_deck = deck
	var counter := SquadronInstance.create_from_data(
			"tie_interceptor_squadron",
			AssetLoader.load_squadron_data("tie_interceptor_squadron"), 1)
	counter.roster_entry_id = "stage-d-counter"
	counter.pos_x = 0.51
	counter.pos_y = 0.50
	state.get_player_state(1).squadrons.append(counter)
	assert_not_null(ATTACK_FIXTURE.install(state, {
		"attack_id": "attack:71", "attacker_kind": "squadron",
		"defender_kind": "squadron",
		"stage": CurrentAttackState.STAGE_RESOLVED,
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
		"resolved_outcome": {"target_kind": "squadron",
			"requested_hull_damage": 1, "actual_hull_damage": 1,
			"post_resolution_hull": 2, "destroyed": false},
	}))
	var original: SquadronInstance = state.get_squadron(0, 0)
	original.roster_entry_id = "stage-d-original"
	original.pos_x = 0.50
	original.pos_y = 0.50
	if commanded:
		state.clear_squadron_phase_progress()
		state.current_phase = Constants.GamePhase.SHIP
		original.reset_activation_action_state()
		var ship := ShipInstance.create_from_data(
				ATTACK_FIXTURE.SHIP_KEY,
				AssetLoader.load_ship_data(ATTACK_FIXTURE.SHIP_KEY), 2, 0)
		ship.roster_entry_id = "stage-d-command-ship"
		assert_true(ship.command_dial_stack.assign_dials(
				[Constants.CommandType.SQUADRON], 1))
		assert_false(ship.command_dial_stack.reveal_top().is_empty())
		assert_true(ship.establish_ship_activation("ship-activation:stage-d"))
		assert_true(ship.open_squadron_command_opportunity(
				ship.ship_activation_identity))
		assert_true(ship.commit_squadron_command_activation(
				ship.ship_activation_identity))
		state.get_player_state(0).ships.append(ship)
		assert_true(original.initialize_activation_action_state(
				"squadron-activation:stage-d-command",
				SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
				0, 0))
		assert_true(original.commit_attack_action_begun(
					original.activation_id, false))
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0, Constants.Visibility.ALL, {"attack_id": "attack:71"})
	var publication: GameCommand = CurrentAttackContinuation \
			.derive_reconstructed_resolved_attack(state)
	assert_not_null(publication)
	if publication != null:
		assert_eq(publication.validate(state), "")
		assert_false(publication.execute(state).is_empty())
	return state


func _choice(accepted: bool) -> CounterChoiceCommand:
	var context: Dictionary = GameManager.counter_choice_context_for_parent()
	context["accepted"] = accepted
	return CounterChoiceCommand.new(1, context)


func _json_command(command: GameCommand) -> GameCommand:
	return GameCommand.deserialize(JSON.parse_string(
			JSON.stringify(command.serialize())) as Dictionary)


func _json_state(state: GameState) -> GameState:
	return GameState.deserialize(JSON.parse_string(
			JSON.stringify(state.serialize())) as Dictionary)


func _history_types() -> Array[String]:
	var result: Array[String] = []
	for command: GameCommand in CommandProcessor.get_history():
		result.append(command.command_type)
	return result
