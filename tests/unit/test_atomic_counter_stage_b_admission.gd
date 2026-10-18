## Stage B: command admission protects complete Counter publications and choices.
extends GutTest


const PROCESSOR: GDScript = preload("res://src/autoload/command_processor.gd")
const ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")

var _state: GameState
var _processor: Node
var _previous_state: GameState
var _saved_registry: Dictionary
var _hook_calls: int = 0


func before_each() -> void:
	_previous_state = GameManager.current_game_state
	_saved_registry = GameCommand._registry.duplicate()
	_hook_calls = 0
	RuleRegistry.clear()
	CoolantDischarge.register()
	EscortKeyword.register()
	CounterKeyword.register()
	PublishAttackFlowCommand.register()
	CounterChoiceCommand.register()
	_state = _resolved_parent()
	GameManager.current_game_state = _state
	_processor = PROCESSOR.new()
	add_child_autofree(_processor)


func after_each() -> void:
	RuleRegistry.clear()
	GameCommand._registry = _saved_registry
	GameManager.current_game_state = _previous_state


func test_complete_counter_publication_direct_and_json_converge() -> void:
	for json_path: bool in [false, true]:
		var state: GameState = _resolved_parent()
		GameManager.current_game_state = state
		var command: GameCommand = _publication()
		if json_path:
			command = _json_command(command)
		assert_not_null(command)
		assert_eq(_processor.preflight(command, state), "")
		assert_eq(command.validate(state), "")
		assert_false(_processor.submit(command).is_empty())
		var restored: GameState = GameState.deserialize(
				JSON.parse_string(JSON.stringify(state.serialize())) as Dictionary)
		assert_not_null(restored)
		if restored != null:
			assert_eq(CanonicalJson.hash(restored.interaction_flow.serialize()),
					CanonicalJson.hash(state.interaction_flow.serialize()))
			assert_eq(CanonicalJson.hash(restored.serialize()),
					CanonicalJson.hash(state.serialize()))
		_processor.reset()
	GameManager.current_game_state = _state


func test_five_canonical_predecessors_accept_direct_and_json() -> void:
	for route: String in _predecessor_routes():
		for json_path: bool in [false, true]:
			_state = _route_state(route)
			GameManager.current_game_state = _state
			_processor.reset()
			var command: GameCommand = _publication()
			if json_path:
				command = _json_command(command)
			assert_not_null(command)
			if command == null:
				continue
			assert_eq(_processor.preflight(command, _state), "", route)
			assert_eq(command.validate(_state), "", route)
			assert_false(_processor.submit(command).is_empty(), route)
			var restored: GameState = GameState.deserialize(
					JSON.parse_string(JSON.stringify(_state.serialize())) as Dictionary)
			assert_not_null(restored, route)
			if restored != null:
				assert_eq(CanonicalJson.hash(restored.interaction_flow.serialize()),
						CanonicalJson.hash(_state.interaction_flow.serialize()), route)
	GameManager.current_game_state = _state


func test_five_predecessors_reject_wrong_owner_and_projection_atomically() -> void:
	var rejection_count: int = 0
	for route: String in _predecessor_routes():
		for specimen: String in ["source", "controller", "participant",
				"defender",
				"phase", "defense_fact", "projection"]:
			for json_path: bool in [false, true]:
				_state = _route_state(route)
				GameManager.current_game_state = _state
				_processor.reset()
				match specimen:
					"source":
						_state.interaction_flow.payload["attack_id"] = "attack:70"
					"controller":
						_state.interaction_flow.controller_player = 0 \
								if route == "attack_defense" else 1
					"participant":
						if route.begins_with("attack_"):
							_state.interaction_flow.payload["attacker_player"] = 1
						else:
							_state.interaction_flow.payload["squadron_index"] = 1
					"defender":
						_state.interaction_flow.payload["defender_player"] = 0
					"phase":
						_state.current_phase = Constants.GamePhase.SHIP \
								if route != "ship_command" \
								else Constants.GamePhase.SQUADRON
					"defense_fact":
						assert_true(_state.set_current_attack_state(
								_state.current_attack_state.with_patch({
									"defense_stage": CurrentAttackState.DEFENSE_PENDING})))
					"projection":
						if route.begins_with("attack_"):
							_state.interaction_flow.payload["final_damage"] = 2
						else:
							_state.interaction_flow.payload["activation_id"] = "wrong"
				var command: GameCommand = _publication()
				if json_path:
					command = _json_command(command)
				assert_not_null(command, "%s: %s" % [route, specimen])
				if command != null:
					_assert_rejected(command)
					rejection_count += 1
	assert_engine_error(rejection_count)
	GameManager.current_game_state = _state


func _predecessor_routes() -> Array[String]:
	return ["attack_modify", "attack_defense", "attack_damage",
			"squadron_phase", "ship_command"]


func _route_state(route: String) -> GameState:
	var state: GameState = _resolved_parent()
	var original: SquadronInstance = state.get_squadron(0, 0)
	var flow_type: Constants.InteractionFlow = Constants.InteractionFlow.ATTACK
	var step: Constants.InteractionStep = Constants.InteractionStep.ATTACK_MODIFY
	var controller: int = 0
	var projection: Dictionary = {"attack_id": "attack:71",
		"attacker_kind": "squadron", "attacker_player": 0,
		"attacker_squadron_index": 0, "target_kind": "squadron",
		"defender_player": 1, "target_squadron_index": 0,
		"dice_results": state.current_attack_state.dice_results,
		"locked_tokens": state.current_attack_state.accuracy_locked_tokens,
		"final_damage": 1}
	match route:
		"attack_defense":
			step = Constants.InteractionStep.ATTACK_DEFENSE_TOKENS
			controller = 1
		"attack_damage":
			step = Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE
		"squadron_phase":
			flow_type = Constants.InteractionFlow.SQUADRON_ACTIVATION
			step = Constants.InteractionStep.SQUAD_ATTACK
			projection = {"squadron_index": 0,
				"activation_id": original.activation_id,
				"activation_context": original.activation_context}
		"ship_command":
			state.clear_squadron_phase_progress()
			state.current_phase = Constants.GamePhase.SHIP
			original.reset_activation_action_state()
			var ship := ShipInstance.create_from_data(
					ATTACK_FIXTURE.SHIP_KEY,
					AssetLoader.load_ship_data(ATTACK_FIXTURE.SHIP_KEY), 2, 0)
			ship.roster_entry_id = "stage-b-command-ship"
			assert_true(ship.command_dial_stack.assign_dials(
					[Constants.CommandType.SQUADRON], 1))
			assert_false(ship.command_dial_stack.reveal_top().is_empty())
			assert_true(ship.establish_ship_activation("ship-activation:stage-b"))
			assert_true(ship.open_squadron_command_opportunity(
					ship.ship_activation_identity))
			assert_true(ship.commit_squadron_command_activation(
					ship.ship_activation_identity))
			state.get_player_state(0).ships.append(ship)
			assert_true(original.initialize_activation_action_state(
					"squadron-activation:stage-b-command",
					SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
					0, 0))
			assert_true(original.commit_attack_action_begun(
					original.activation_id, false))
			flow_type = Constants.InteractionFlow.SHIP_ACTIVATION
			step = Constants.InteractionStep.SQUADRON_STEP
			projection = {"squadron_index": 0,
				"activation_id": original.activation_id,
				"activation_context": original.activation_context,
				"ship_index": 0,
				"ship_activation_identity": ship.ship_activation_identity}
	state.interaction_flow = InteractionFlow.make(flow_type, step,
			controller, Constants.Visibility.ALL, projection)
	assert_true(state.validate_declaration_adjacent_state(), route)
	return state


func test_owner_backed_enclosing_squadron_predecessor_is_narrow() -> void:
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SQUADRON_ACTIVATION,
			Constants.InteractionStep.ACTION_CHOICE,
			0, Constants.Visibility.ALL, {})
	_assert_rejected(_publication())
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SQUADRON_ACTIVATION,
			Constants.InteractionStep.SQUAD_ATTACK,
			0, Constants.Visibility.ALL, {})
	assert_false(_processor.submit(_publication()).is_empty())
	assert_not_null(GameState.deserialize(JSON.parse_string(
			JSON.stringify(_state.serialize())) as Dictionary))
	assert_engine_error(1)


func test_counter_publication_owner_and_installed_flow_reject_atomically() -> void:
	for patch: Dictionary in [
			{"counter_target_player": 1},
			{"counter_dice_pool": {"BLUE": 1}},
			{"final_damage": 2},
			{"counter_attack_available": false},
			{"counter_attacker_squadron_index": 3},
	]:
		var command: PublishAttackFlowCommand = _publication()
		(command.payload["flow_payload"] as Dictionary).merge(patch, true)
		_assert_rejected(command)
	assert_false(_processor.submit(_publication()).is_empty())
	for command: PublishAttackFlowCommand in [
			_publication(),
			_previous_step_publication(),
			_stale_publication(),
			_final_publication(),
	]:
		_assert_rejected(command, true)
		var decoded: GameCommand = _json_command(command)
		assert_not_null(decoded)
		if decoded != null:
			_assert_rejected(decoded, true)
	assert_engine_error(13)


func test_counter_choice_malformed_direct_and_json_reject_before_hooks() -> void:
	assert_false(_processor.submit(_publication()).is_empty())
	for patch: Dictionary in [
			{"accepted": "true"}, {"accepted": 1},
			{"counter_attacker_player": []},
			{"counter_target_player": "0"},
			{"counter_target_squadron_index": 0.5},
			{"counter_dice_pool": []},
			{"counter_dice_pool": {"BLUE": "2"}},
			{"counter_dice_pool": {"BLUE": -1}},
			{"attack_id": "attack:old"},
	]:
		var command: CounterChoiceCommand = _choice()
		command.payload.merge(patch, true)
		_assert_rejected(command, true)
		var decoded: GameCommand = _json_command(command)
		if decoded != null:
			_assert_rejected(decoded, true)
	var nonfinite: CounterChoiceCommand = _choice()
	nonfinite.payload["counter_dice_pool"] = {"BLUE": INF}
	_assert_rejected(nonfinite, true)
	var valid_json: GameCommand = _json_command(_choice())
	assert_not_null(valid_json)
	if valid_json != null:
		assert_eq(typeof(valid_json.payload["counter_dice_pool"]["BLUE"]),
				TYPE_INT)
		assert_eq(_processor.preflight(valid_json, _state), "")
		assert_eq(valid_json.validate(_state), "")
	var decline: CounterChoiceCommand = _choice()
	decline.payload["accepted"] = false
	assert_eq(_processor.preflight(decline, _state), "")
	assert_eq(decline.validate(_state), "")
	assert_engine_error(14)


func test_decided_parent_and_inspection_cannot_be_republished_or_cleared() -> void:
	assert_false(_processor.submit(_publication()).is_empty())
	for disposition: String in [CurrentAttackState.COUNTER_ACCEPTED,
			CurrentAttackState.COUNTER_DECLINED]:
		var decided: CurrentAttackState = \
				_state.current_attack_state.with_patch(
						{"counter_disposition": disposition})
		assert_not_null(decided)
		assert_true(_state.set_current_attack_state(decided))
		_state.interaction_flow.payload["counter_choice_accepted"] = \
				disposition == CurrentAttackState.COUNTER_ACCEPTED
		_assert_rejected(_publication(), true)
		_assert_rejected(_final_publication(), true)
	var parent: CurrentAttackState = _state.current_attack_state.with_patch(
			{"counter_disposition": CurrentAttackState.COUNTER_ACCEPTED})
	assert_not_null(parent)
	_state.interaction_flow.payload["counter_choice_accepted"] = true
	assert_true(_state.set_current_attack_state(
			CurrentAttackState.inactive()))
	var inspection: CompletedAttackInspection = \
			CompletedAttackInspection.create_from_attack(parent,
					parent.resolved_outcome,
					[_state.principal_id_for_player(0)])
	assert_not_null(inspection)
	if inspection != null:
		assert_true(_state.install_completed_attack_inspection(inspection))
		_assert_rejected(_publication(), true)
		_assert_rejected(_final_publication(), true)
	assert_engine_error(6)


func test_registered_hooks_do_not_observe_unsafe_publication_or_choice() -> void:
	RuleRegistry.register_rule("test.stage_b.hook_probe", [
		FlowHook.validator("test.stage_b.hook_probe",
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_MODIFY,
				"publish_attack_flow", Callable(self, "_probe_hook")),
		FlowHook.validator("test.stage_b.hook_probe",
				Constants.InteractionFlow.ATTACK,
				Constants.InteractionStep.ATTACK_COUNTER_CHOICE,
				CounterChoiceCommand.TYPE, Callable(self, "_probe_hook")),
	])
	var wrong_container: PublishAttackFlowCommand = _publication()
	wrong_container.payload["flow_payload"] = []
	_assert_rejected(wrong_container, true)
	var wrong_integer: PublishAttackFlowCommand = _publication()
	wrong_integer.payload["flow_payload"]["attacker_player"] = []
	_assert_rejected(wrong_integer, true)
	assert_eq(_hook_calls, 0)
	assert_false(_processor.submit(_publication()).is_empty())
	_hook_calls = 0
	var wrong_choice: CounterChoiceCommand = _choice()
	wrong_choice.payload["accepted"] = "true"
	_assert_rejected(wrong_choice, true)
	var wrong_pool: CounterChoiceCommand = _choice()
	wrong_pool.payload["counter_dice_pool"] = {"BLUE": "2"}
	_assert_rejected(wrong_pool, true)
	assert_eq(_hook_calls, 0)
	assert_engine_error(4)


func _probe_hook(_state_value: GameState,
		_command: GameCommand) -> Dictionary:
	_hook_calls += 1
	return {"allowed": true, "reason": ""}


func _assert_rejected(command: GameCommand, prehook: bool = false) -> void:
	var state_before: Dictionary = _state.serialize()
	var command_before: Dictionary = command.payload.duplicate(true)
	var history_before: int = _processor.get_command_count()
	var sequence_before: int = _processor.get_next_sequence()
	var queue_before: int = _processor.get_pending_observer_followup_count()
	if prehook:
		assert_ne(_processor.preflight(command, _state), "")
	assert_true(_processor.submit(command).is_empty())
	assert_eq(_state.serialize(), state_before)
	assert_eq(CanonicalJson.hash(_state.serialize()),
			CanonicalJson.hash(state_before))
	assert_eq(_processor.get_command_count(), history_before)
	assert_eq(_processor.get_next_sequence(), sequence_before)
	assert_eq(_processor.get_pending_observer_followup_count(), queue_before)
	assert_eq(command.payload, command_before)


func _resolved_parent() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SQUADRON
	state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human())
	var deck := DamageDeck.new()
	deck.set_rng(state.rng)
	deck.initialize()
	state.damage_deck = deck
	var counter := SquadronInstance.create_from_data(
			"tie_interceptor_squadron",
			AssetLoader.load_squadron_data("tie_interceptor_squadron"), 1)
	counter.roster_entry_id = "stage-b-counter"
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
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0, Constants.Visibility.ALL, {"attack_id": "attack:71"})
	return state


func _publication() -> PublishAttackFlowCommand:
	return PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.ATTACK_COUNTER_CHOICE),
		"controller_player": 1,
		"flow_payload": {"attack_id": "attack:71",
			"counter_attack_available": true,
			"counter_controller_player": 1,
			"controller_player": 1,
			"counter_attacker_player": 1,
			"counter_attacker_squadron_index": 0,
			"counter_target_player": 0,
			"counter_target_squadron_index": 0,
			"counter_dice_pool": {"BLUE": 2},
			"final_damage": 1},
		"final": false, "source_attack_id": "attack:71",
	})


func _previous_step_publication() -> PublishAttackFlowCommand:
	var command: PublishAttackFlowCommand = _publication()
	command.payload["step_id"] = int(Constants.InteractionStep.ATTACK_MODIFY)
	return command


func _stale_publication() -> PublishAttackFlowCommand:
	var command: PublishAttackFlowCommand = _publication()
	command.payload["source_attack_id"] = "attack:72"
	return command


func _final_publication() -> PublishAttackFlowCommand:
	var command: PublishAttackFlowCommand = _publication()
	command.payload["final"] = true
	command.payload["flow_payload"] = {}
	return command


func _choice() -> CounterChoiceCommand:
	return CounterChoiceCommand.new(1, {
		"attack_id": "attack:71", "accepted": true,
		"counter_attacker_player": 1,
		"counter_attacker_squadron_index": 0,
		"counter_target_player": 0,
		"counter_target_squadron_index": 0,
		"counter_dice_pool": {"BLUE": 2},
	})


func _json_command(command: GameCommand) -> GameCommand:
	return GameCommand.deserialize(JSON.parse_string(
			JSON.stringify(command.serialize())) as Dictionary)
