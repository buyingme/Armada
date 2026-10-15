## Focused regressions for the accepted Counter inspection-release ordering.
extends GutTest


const SaveManagerScript: GDScript = preload(
		"res://src/autoload/save_game_manager.gd")
const TEST_SAVE: String = "counter_parent_identity_save10"
const TEST_SAVE_DIR: String = "user://counter_parent_identity_save10"
var _test_signing_key: PackedByteArray = PackedByteArray([
	0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
	0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
	0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
	0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20,
])


var _state: GameState
var _previous_state: GameState
var _previous_mode: PlayMode.Mode
var _previous_role: NetworkManager.Role
var _previous_save_dir: String
var _previous_key_file: String
var _manager: Node


func before_each() -> void:
	_previous_state = GameManager.current_game_state
	_previous_mode = PlayMode.current_mode
	_previous_role = NetworkManager.role
	_previous_save_dir = SaveGameManager.SAVE_DIR
	_previous_key_file = SaveGameManager.SIGNING_KEY_FILE
	SaveGameManager.SAVE_DIR = TEST_SAVE_DIR
	SaveGameManager.SIGNING_KEY_FILE = TEST_SAVE_DIR.path_join("key.bin")
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	CommandProcessor.reset()
	_manager = SaveManagerScript.new()
	_manager._signing_key = _test_signing_key
	_manager.delete_save(TEST_SAVE)
	_state = _counter_release_state(false)
	GameManager.current_game_state = _state


func after_each() -> void:
	_manager.delete_save(TEST_SAVE)
	_manager.free()
	_manager = null
	CommandProcessor.reset()
	GameManager.current_game_state = _previous_state
	PlayMode.set_mode(_previous_mode)
	NetworkManager.role = _previous_role
	SaveGameManager.SAVE_DIR = _previous_save_dir
	SaveGameManager.SIGNING_KEY_FILE = _previous_key_file


func test_final_ack_queues_child_begin_then_child_publication() -> void:
	assert_true(CommandProcessor.restore_next_sequence(51))
	var inspection: CompletedAttackInspection = \
			_state.completed_attack_inspection
	var result: Dictionary = CommandProcessor.submit(
			AcknowledgeAttackResultCommand.new(1, {
				"inspection_id": inspection.inspection_id(),
			}))

	assert_true(bool(result.get("satisfied", false)))
	var types: Array[String] = []
	for command: GameCommand in CommandProcessor.get_history():
		types.append(command.command_type)
	assert_eq(types, ["acknowledge_attack_result", "begin_attack",
			"publish_attack_flow", "publish_attack_flow"])
	var begin: GameCommand = CommandProcessor.get_history()[1]
	assert_eq(begin.player_index, 1,
			"The authoritative follow-up retains the child Counter attacker.")
	assert_eq(str(begin.payload.get("completed_attack_inspection_id", "")),
			"completed:attack:50")
	assert_null(_state.completed_attack_inspection)
	assert_true(_state.current_attack_state.active)
	assert_eq(_state.current_attack_state.attack_id, "attack:52")
	assert_eq(_state.current_attack_state.attack_kind,
			SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER)
	assert_eq(_state.interaction_flow.payload.get("attack_id"), "attack:52")
	assert_eq(_state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_ROLL,
			"Locked Counter Declare must advance automatically to Roll.")
	assert_eq(_state.interaction_flow.controller_player, 1)
	assert_eq(_state.interaction_flow.payload.get("attacker_name"),
			"TIE Fighter Squadron")
	assert_eq(_state.interaction_flow.payload.get("defender_name"),
			"X-wing Squadron")
	var declare: GameCommand = CommandProcessor.get_history()[2]
	var roll: GameCommand = CommandProcessor.get_history()[3]
	assert_eq(declare.payload.get("step_id"),
			int(Constants.InteractionStep.ATTACK_DECLARE))
	assert_eq(roll.payload.get("step_id"),
			int(Constants.InteractionStep.ATTACK_ROLL))
	assert_eq(declare.payload.get("flow_payload"),
			roll.payload.get("flow_payload"),
			"Declare and Roll must preserve one locked child identity.")
	assert_eq(CommandProcessor.get_next_sequence(), 55)


func test_unsatisfied_or_wrong_source_inspection_derives_nothing() -> void:
	assert_null(CurrentAttackContinuation.derive_reconstructed_inspection_release(
			_state))


func test_destroyed_counter_attacker_derives_and_validates_exact_child() -> void:
	_state = _counter_release_state(true, true)
	var child: GameCommand = CurrentAttackContinuation \
			.derive_reconstructed_inspection_release(_state)
	assert_not_null(child)
	if child == null:
		return
	child.sequence = 52
	assert_eq(child.validate(_state), "")
	assert_false(child.execute(_state).is_empty())
	assert_true(_state.current_attack_state.active)
	assert_eq(_state.current_attack_state.attack_kind,
			SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER)
	assert_true(_state.get_squadron(1, 0).is_destroyed())


func test_destroyed_counter_target_still_rejects_child_derivation() -> void:
	_state = _counter_release_state(true, true)
	_state.get_squadron(0, 0).mark_destroyed()
	assert_null(CurrentAttackContinuation.derive_reconstructed_inspection_release(
			_state))


func test_counter_begin_revalidates_parent_inspection_source() -> void:
	_state = _counter_release_state(true, true)
	var child: GameCommand = CurrentAttackContinuation \
			.derive_reconstructed_inspection_release(_state)
	assert_not_null(child)
	if child == null:
		return
	var explicit_replay: GameCommand = GameCommand.deserialize(child.serialize())
	assert_not_null(explicit_replay)
	_state.interaction_flow.payload["attack_id"] = "attack:other"
	assert_eq(child.validate(_state),
			"Counter parent inspection does not match the accepted choice.")
	assert_eq(explicit_replay.validate(_state),
			"Counter parent inspection does not match the accepted choice.",
			"Explicit replay Begin must enforce the same source validation.")
	assert_not_null(_state.completed_attack_inspection)
	assert_false(_state.current_attack_state.active)
	_state = _counter_release_state(true)
	_state.interaction_flow.payload["attack_id"] = "attack:49"
	assert_null(CurrentAttackContinuation.derive_reconstructed_inspection_release(
			_state))


func test_passive_modes_never_synthesize_child_begin() -> void:
	_state = _counter_release_state(true)
	var marker := AcknowledgeAttackResultCommand.new(1, {
		"inspection_id": "completed:attack:50",
	})
	for mode: String in [CurrentAttackContinuation.MODE_NETWORK_MIRROR,
			CurrentAttackContinuation.MODE_REPLAY]:
		var processed: Dictionary = \
				CurrentAttackContinuation.process_successful_command(
						_state, marker, {"satisfied": true}, mode)
		assert_null(processed.get(CurrentAttackContinuation.KEY_CONTINUATION))


func test_delayed_parent_clear_rejects_after_child_replacement() -> void:
	_state = _counter_release_state(true)
	var child: GameCommand = \
			CurrentAttackContinuation.derive_reconstructed_inspection_release(_state)
	assert_not_null(child)
	child.sequence = 52
	assert_eq(child.validate(_state), "")
	assert_false(child.execute(_state).is_empty())
	var child_source: String = _state.current_attack_state.attack_id
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			1, Constants.Visibility.ALL,
			{"attack_id": child_source, "attacker_player": 1})
	var delayed := PublishAttackFlowCommand.new(0, {
		"step_id": int(Constants.InteractionStep.NONE),
		"controller_player": -1,
		"flow_payload": {},
		"final": true,
		"source_attack_id": "attack:50",
	})
	var before: Dictionary = _state.interaction_flow.serialize()
	assert_ne(delayed.validate(_state), "")
	assert_eq(_state.interaction_flow.serialize(), before)


func test_real_save10_and_reconnect_restore_counter_parent_identity() -> void:
	_state = _counter_release_state(true)
	GameManager.current_game_state = _state
	assert_true(CommandProcessor.restore_next_sequence(51))
	var source_flow: Dictionary = _state.interaction_flow.serialize()
	var source_inspection: Dictionary = \
			_state.completed_attack_inspection.serialize()
	var metadata: SaveGameMetadata = _manager.build_metadata_for(
			_state, TEST_SAVE)
	metadata.game_mode = SaveGameMetadata.MODE_NETWORK
	assert_eq(metadata.save_format_version, 10)
	assert_true(_manager.save_game(_state, TEST_SAVE, metadata))

	var raw_payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			SaveGameManager.SAVE_DIR.path_join(
					TEST_SAVE + SaveManagerScript.SAVE_EXT))) as Dictionary
	var raw_flow_payload: Dictionary = \
			(raw_payload["state"]["interaction_flow"] as Dictionary)["payload"] \
					as Dictionary
	for key: String in _counter_identity_keys():
		assert_eq(typeof(raw_flow_payload[key]), TYPE_FLOAT,
				"Real Save-10 JSON must exercise numeric type restoration.")

	var loaded_result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_true(bool(loaded_result.get("ok", false)),
			"Signed Save-10 Counter parent state must load.")
	var loaded: GameState = loaded_result.get("state") as GameState
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_eq((loaded_result.get("meta") as SaveGameMetadata).save_format_version,
			10)
	_assert_counter_parent_state(loaded, source_flow, source_inspection)
	assert_eq(loaded.completed_attack_inspection.serialize(), source_inspection)
	assert_false(loaded.current_attack_state.active)
	for key: String in _counter_identity_keys():
		assert_eq(typeof(loaded.interaction_flow.payload[key]), TYPE_INT,
				"%s must be canonical int after signed Save-10 load." % key)

	var child: GameCommand = \
			CurrentAttackContinuation.derive_reconstructed_inspection_release(
					loaded)
	assert_not_null(child,
			"Satisfied restored inspection must derive the child Counter Begin.")
	if child != null:
		assert_eq(child.command_type, BeginAttackCommand.TYPE)
		assert_eq(child.payload.get("completed_attack_inspection_id"),
				"completed:attack:50")

	var filtered: Dictionary = StateFilter.filter_for_player_checked(
			loaded.serialize(), 1)
	assert_true(bool(filtered.get(StateFilter.KEY_OK, false)))
	var passive: GameState = GameState.deserialize_passive_network(
			filtered.get(StateFilter.KEY_STATE, {}) as Dictionary)
	assert_not_null(passive)
	if passive != null:
		_assert_counter_parent_state(passive, source_flow, source_inspection)
		for key: String in _counter_identity_keys():
			assert_eq(typeof(passive.interaction_flow.payload[key]), TYPE_INT)


func test_save10_and_reconnect_reconstruct_active_destroyed_counter_child() \
		-> void:
	_state = _counter_release_state(false, true)
	GameManager.current_game_state = _state
	assert_true(CommandProcessor.restore_next_sequence(51))
	var parent_inspection: CompletedAttackInspection = \
			_state.completed_attack_inspection
	assert_false(CommandProcessor.submit(
			AcknowledgeAttackResultCommand.new(1, {
				"inspection_id": parent_inspection.inspection_id(),
			})).is_empty())
	assert_true(_state.current_attack_state.active)
	assert_eq(_state.current_attack_state.attack_kind,
			SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER)
	assert_true(_state.get_squadron(1, 0).is_destroyed())

	assert_true(_manager.save_game(_state, TEST_SAVE))
	var loaded_result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_true(bool(loaded_result.get("ok", false)))
	var metadata: SaveGameMetadata = loaded_result.get("meta") \
			as SaveGameMetadata
	assert_eq(metadata.save_format_version, 10)
	var loaded: GameState = loaded_result.get("state") as GameState
	assert_not_null(loaded)
	if loaded == null:
		return
	_assert_destroyed_counter_presentation_reconstructs(loaded)

	var filtered: Dictionary = StateFilter.filter_for_player_checked(
			loaded.serialize(), 0)
	assert_true(bool(filtered.get(StateFilter.KEY_OK, false)))
	var reconnect: GameState = GameState.deserialize_passive_network(
			filtered.get(StateFilter.KEY_STATE, {}) as Dictionary)
	assert_not_null(reconnect)
	if reconnect != null:
		_assert_destroyed_counter_presentation_reconstructs(reconnect)


func test_counter_runtime_and_command_boundaries_remain_exact_integer() -> void:
	_state = _counter_release_state(true)
	_state.interaction_flow.payload["counter_attacker_player"] = 1.0
	assert_null(CurrentAttackContinuation.derive_reconstructed_inspection_release(
			_state), "Runtime continuation must reject floating-point identity.")

	var serialized: Dictionary = CounterChoiceCommand.new(
			1, _counter_choice_command_payload()).serialize()
	(serialized["payload"] as Dictionary)["counter_attacker_player"] = 1.5
	assert_null(GameCommand.deserialize(serialized),
			"Command reconstruction must reject fractional identity.")
	(serialized["payload"] as Dictionary)["counter_attacker_player"] = true
	assert_null(GameCommand.deserialize(serialized),
			"Command reconstruction must reject boolean identity.")
	(serialized["payload"] as Dictionary)["counter_attacker_player"] = "1"
	assert_null(GameCommand.deserialize(serialized),
			"Command reconstruction must reject string identity.")


func test_counter_child_exhausted_activation_consumes_j_on_completion() -> void:
	_state = _counter_child_release_state(false, false)
	GameManager.current_game_state = _state
	assert_true(CommandProcessor.restore_next_sequence(81))
	var inspection: CompletedAttackInspection = \
			_state.completed_attack_inspection
	var result: Dictionary = CommandProcessor.submit(
			AcknowledgeAttackResultCommand.new(1, {
				"inspection_id": inspection.inspection_id(),
			}))

	assert_true(bool(result.get("satisfied", false)))
	assert_eq(_history_types(), [AcknowledgeAttackResultCommand.TYPE,
			CompleteSquadronActivationCommand.TYPE])
	var completion: GameCommand = CommandProcessor.get_history()[1]
	assert_eq(completion.player_index, 0,
			"Counter release must return through the original defender activation.")
	assert_eq(completion.payload.get("squadron_index"), 0)
	assert_eq(completion.payload.get("completed_attack_inspection_id"),
			"completed:attack:80")
	assert_null(_state.completed_attack_inspection)
	assert_true(_state.get_squadron(0, 0).activated_this_round)
	assert_eq(_state.interaction_flow.flow_type,
			Constants.InteractionFlow.SQUADRON_ACTIVATION)
	assert_eq(_state.interaction_flow.step_id,
			Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT)


func test_counter_child_legal_move_keeps_j_until_decline_consumes_it() -> void:
	_state = _counter_child_release_state(true, false)
	GameManager.current_game_state = _state
	assert_true(CommandProcessor.restore_next_sequence(81))
	var inspection: CompletedAttackInspection = \
			_state.completed_attack_inspection
	assert_false(CommandProcessor.submit(
			AcknowledgeAttackResultCommand.new(1, {
				"inspection_id": inspection.inspection_id(),
			})).is_empty())

	assert_eq(_history_types(), [AcknowledgeAttackResultCommand.TYPE])
	assert_not_null(_state.completed_attack_inspection)
	assert_true(_state.completed_attack_inspection.is_satisfied())
	assert_null(CurrentAttackContinuation.derive_reconstructed_inspection_release(
			_state), "A derived Move decision must not synthesize a command.")
	var original: SquadronInstance = _state.get_squadron(0, 0)
	assert_true(_state.has_legal_remaining_squadron_move_action(original))
	assert_false(CommandProcessor.submit(DeclineSquadronMoveCommand.new(0, {
		"squadron_index": 0,
		"activation_id": original.activation_id,
		"activation_context": original.activation_context,
		"completed_attack_inspection_id": inspection.inspection_id(),
	})).is_empty())

	assert_eq(_history_types(), [AcknowledgeAttackResultCommand.TYPE,
			DeclineSquadronMoveCommand.TYPE,
			CompleteSquadronActivationCommand.TYPE])
	assert_null(_state.completed_attack_inspection)
	assert_eq(original.move_action_disposition,
			SquadronInstance.MOVE_ACTION_DECLINED)
	assert_true(original.activated_this_round)


func test_counter_child_move_consumes_j_atomically() -> void:
	_state = _counter_child_release_state(true, true)
	GameManager.current_game_state = _state
	var inspection: CompletedAttackInspection = \
			_state.completed_attack_inspection
	var original: SquadronInstance = _state.get_squadron(0, 0)
	var move := MoveSquadronCommand.new(0, {
		"squadron_index": 0,
		"pos_x": 0.30,
		"pos_y": 0.30,
		"activation_id": original.activation_id,
		"activation_context": original.activation_context,
		"completed_attack_inspection_id": inspection.inspection_id(),
	})
	assert_eq(move.validate(_state), "")
	assert_false(move.execute(_state).is_empty())
	assert_null(_state.completed_attack_inspection)
	assert_eq(original.move_action_disposition,
			SquadronInstance.MOVE_ACTION_COMMITTED)
	assert_eq(original.pos_x, 0.30)
	assert_eq(original.pos_y, 0.30)


func test_counter_child_j_mapping_fails_closed_on_inconsistent_context() -> void:
	_state = _counter_child_release_state(false, true)
	var inspection_before: Dictionary = \
			_state.completed_attack_inspection.serialize()
	var original: SquadronInstance = _state.get_squadron(0, 0)
	original.attack_action_disposition = SquadronInstance.ATTACK_ACTION_AVAILABLE
	assert_null(CurrentAttackContinuation.derive_reconstructed_inspection_release(
			_state))
	assert_eq(_state.completed_attack_inspection.serialize(), inspection_before)
	assert_false(original.activated_this_round)

	original.attack_action_disposition = SquadronInstance.ATTACK_ACTION_BEGUN
	_state.current_phase = Constants.GamePhase.SHIP
	assert_null(CurrentAttackContinuation.derive_reconstructed_inspection_release(
			_state))
	assert_eq(_state.completed_attack_inspection.serialize(), inspection_before)


func test_save10_and_reconnect_restore_satisfied_counter_child_j() -> void:
	_state = _counter_child_release_state(false, true)
	GameManager.current_game_state = _state
	var inspection_data: Dictionary = \
			_state.completed_attack_inspection.serialize()
	var metadata: SaveGameMetadata = _manager.build_metadata_for(
			_state, TEST_SAVE)
	metadata.game_mode = SaveGameMetadata.MODE_NETWORK
	assert_eq(metadata.save_format_version, 10)
	assert_true(_manager.save_game(_state, TEST_SAVE, metadata))

	var loaded_result: Dictionary = _manager.load_game(TEST_SAVE)
	assert_true(bool(loaded_result.get("ok", false)))
	var loaded: GameState = loaded_result.get("state") as GameState
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_eq(loaded.completed_attack_inspection.serialize(), inspection_data)
	var completion: GameCommand = \
			CurrentAttackContinuation.derive_reconstructed_inspection_release(
					loaded)
	assert_not_null(completion)
	assert_eq(completion.command_type, CompleteSquadronActivationCommand.TYPE)
	assert_eq(completion.payload.get("completed_attack_inspection_id"),
			"completed:attack:80")

	var filtered: Dictionary = StateFilter.filter_for_player_checked(
			loaded.serialize(), 1)
	assert_true(bool(filtered.get(StateFilter.KEY_OK, false)))
	var passive: GameState = GameState.deserialize_passive_network(
			filtered.get(StateFilter.KEY_STATE, {}) as Dictionary)
	assert_not_null(passive)
	if passive != null:
		assert_eq(passive.completed_attack_inspection.serialize(),
				inspection_data)
		var passive_completion: GameCommand = CurrentAttackContinuation \
				.derive_reconstructed_inspection_release(passive)
		assert_not_null(passive_completion)
		assert_eq(passive_completion.command_type,
				CompleteSquadronActivationCommand.TYPE)


func _history_types() -> Array[String]:
	var result: Array[String] = []
	for command: GameCommand in CommandProcessor.get_history():
		result.append(command.command_type)
	return result


func _counter_identity_keys() -> Array[String]:
	return [
		"counter_attacker_player", "counter_attacker_squadron_index",
		"counter_target_player", "counter_target_squadron_index",
	]


func _assert_counter_parent_state(state: GameState, source_flow: Dictionary,
		source_inspection: Dictionary) -> void:
	assert_not_null(state.interaction_flow)
	assert_eq(state.interaction_flow.flow_type,
			Constants.InteractionFlow.ATTACK)
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE)
	assert_eq(state.interaction_flow.controller_player, 1)
	assert_eq(state.interaction_flow.visible_to, Constants.Visibility.ALL)
	assert_eq(state.interaction_flow.payload.get("attack_id"),
			(source_flow["payload"] as Dictionary).get("attack_id"))
	assert_eq(state.interaction_flow.payload.get("counter_choice_accepted"),
			(source_flow["payload"] as Dictionary).get(
					"counter_choice_accepted"))
	for key: String in _counter_identity_keys():
		assert_eq(state.interaction_flow.payload.get(key),
				(source_flow["payload"] as Dictionary).get(key))
	assert_not_null(state.completed_attack_inspection)
	assert_eq(state.completed_attack_inspection.serialize(), source_inspection)


func _counter_choice_command_payload() -> Dictionary:
	return {
		"accepted": true,
		"counter_attacker_player": 1,
		"counter_attacker_squadron_index": 0,
		"counter_target_player": 0,
		"counter_target_squadron_index": 0,
	}


func _counter_release_state(satisfied: bool,
		destroyed_counter_attacker: bool = false) -> GameState:
	var state := GameState.new()
	state.initialize()
	var deck := DamageDeck.new()
	deck.set_rng(state.rng)
	deck.initialize()
	state.damage_deck = deck
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SQUADRON
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_two_human()))
	var parent_attacker := SquadronInstance.create_from_data(
			"x_wing_squadron",
			AssetLoader.load_squadron_data("x_wing_squadron"), 0)
	parent_attacker.roster_entry_id = "counter-parent-attacker"
	parent_attacker.pos_x = 0.50
	parent_attacker.pos_y = 0.50
	state.get_player_state(0).squadrons.append(parent_attacker)
	var counter_data: SquadronData = AssetLoader.load_squadron_data(
			"tie_fighter_squadron").duplicate(true) as SquadronData
	counter_data.keywords.append({
		"name": SquadronKeywordRuleHelper.KEYWORD_COUNTER,
		"value": 2,
	})
	var counter_attacker := SquadronInstance.create_from_data(
			"tie_fighter_squadron", counter_data, 1)
	counter_attacker.roster_entry_id = "counter-child-attacker"
	counter_attacker.pos_x = 0.51
	counter_attacker.pos_y = 0.50
	if destroyed_counter_attacker:
		counter_attacker.mark_destroyed()
	state.get_player_state(1).squadrons.append(counter_attacker)
	var principals: Array[String] = \
			state.get_distinct_controlling_principal_ids(
					MatchPlayerControlBinding.KIND_HUMAN)
	var received: Array[String] = []
	if satisfied:
		received.assign(principals)
	else:
		received.append(state.principal_id_for_player(0))
	var inspection: CompletedAttackInspection = \
			CompletedAttackInspection.deserialize({
				"inspection_id": "completed:attack:50",
				"source_attack_id": "attack:50",
				"attacker": {"kind": CurrentAttackState.KIND_SQUADRON,
					"player": 0, "index": 0, "zone": -1},
				"defender": {"kind": CurrentAttackState.KIND_SQUADRON,
					"player": 1, "index": 0, "zone": -1},
				"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
				"dice_results": [{"color": int(Constants.DiceColor.BLUE),
					"face": int(Constants.DiceFace.HIT)}],
				"outcome": {"target_kind": CurrentAttackState.KIND_SQUADRON,
					"requested_hull_damage": 1, "actual_hull_damage": 1,
					"post_resolution_hull": 2, "destroyed": false},
				"required_principal_ids": principals,
				"received_principal_ids": received,
			})
	assert_not_null(inspection)
	assert_true(state.install_completed_attack_inspection(inspection))
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_COUNTER_CHOICE,
			1, Constants.Visibility.ALL, {
				"attack_id": "attack:50",
				CounterKeyword.PAYLOAD_AVAILABLE: true,
				CounterKeyword.PAYLOAD_CONTROLLER_PLAYER: 1,
				"counter_choice_accepted": true,
				"counter_attacker_player": 1,
				"counter_attacker_squadron_index": 0,
				"counter_target_player": 0,
				"counter_target_squadron_index": 0,
			})
	assert_true(state.set_current_attack_state(CurrentAttackState.inactive()))
	assert_true(state.validate_declaration_adjacent_state())
	return state


func _counter_child_release_state(move_legal: bool,
		satisfied: bool) -> GameState:
	var state := GameState.new()
	state.initialize()
	var deck := DamageDeck.new()
	deck.set_rng(state.rng)
	deck.initialize()
	state.damage_deck = deck
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SQUADRON
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_two_human()))
	assert_true(state.initialize_squadron_phase_progress(0))
	var original_data: SquadronData = AssetLoader.load_squadron_data(
			"x_wing_squadron").duplicate(true) as SquadronData
	if move_legal:
		original_data.keywords.append({"name": "Rogue"})
	var original := SquadronInstance.create_from_data(
			"x_wing_squadron", original_data, 0)
	original.roster_entry_id = "counter-original-activation"
	original.pos_x = 0.20
	original.pos_y = 0.20
	state.get_player_state(0).squadrons.append(original)
	var counter := SquadronInstance.create_from_data(
			"tie_interceptor_squadron",
			AssetLoader.load_squadron_data("tie_interceptor_squadron"), 1)
	counter.roster_entry_id = "counter-child-attacker"
	counter.pos_x = 0.80
	counter.pos_y = 0.80
	state.get_player_state(1).squadrons.append(counter)
	assert_true(original.initialize_activation_action_state(
			"squadron-activation:counter-original",
			SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE))
	assert_true(original.commit_attack_action_begun(
			original.activation_id, move_legal))
	var principals: Array[String] = \
			state.get_distinct_controlling_principal_ids(
					MatchPlayerControlBinding.KIND_HUMAN)
	var received: Array[String] = []
	if satisfied:
		received.assign(principals)
	else:
		received.append(state.principal_id_for_player(0))
	var inspection: CompletedAttackInspection = \
			CompletedAttackInspection.deserialize({
				"inspection_id": "completed:attack:80",
				"source_attack_id": "attack:80",
				"attacker": {"kind": CurrentAttackState.KIND_SQUADRON,
					"player": 1, "index": 0, "zone": -1},
				"defender": {"kind": CurrentAttackState.KIND_SQUADRON,
					"player": 0, "index": 0, "zone": -1},
				"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER,
				"dice_results": [{"color": int(Constants.DiceColor.BLUE),
					"face": int(Constants.DiceFace.HIT)}],
				"outcome": {"target_kind": CurrentAttackState.KIND_SQUADRON,
					"requested_hull_damage": 1, "actual_hull_damage": 1,
					"post_resolution_hull": 4, "destroyed": false},
				"required_principal_ids": principals,
				"received_principal_ids": received,
			})
	assert_not_null(inspection)
	assert_true(state.install_completed_attack_inspection(inspection))
	state.interaction_flow = InteractionFlow.empty()
	assert_true(state.validate_declaration_adjacent_state())
	return state


func _assert_destroyed_counter_presentation_reconstructs(
		state: GameState) -> void:
	GameManager.current_game_state = state
	var executor := AttackExecutor.new()
	add_child_autofree(executor)
	var defender: SquadronInstance = state.get_squadron(0, 0)
	var defender_token := SquadronToken.new()
	defender_token._placement = TokenPlacement.new(
			defender.data_key, false, defender.squadron_data.faction,
			defender.pos_x, defender.pos_y, defender.get_rotation_rad(),
			Constants.ShipSize.SMALL)
	defender_token._radius_px = 20.0
	defender_token._squadron_instance = defender
	add_child_autofree(defender_token)
	var refs: Dictionary = executor._resolve_resume_references(
			state, state.current_attack_state,
			func(_entity: RefCounted): return null,
			func(entity: RefCounted):
				return defender_token if entity == defender else null)
	assert_true(bool(refs.get(AttackExecutor.RESUME_KEY_OK, false)),
			"%s attack=%s flow=%s" % [refs,
			state.current_attack_state.serialize(),
			state.interaction_flow.serialize()])
	var transient: SquadronToken = refs.get("attacker_token") as SquadronToken
	assert_not_null(transient)
	if transient == null:
		return
	assert_same(transient.get_squadron_instance(), state.get_squadron(1, 0))
	assert_true(transient.get_squadron_instance().is_destroyed())
	assert_false(transient.visible)
	executor._reset_exec_state()
	assert_false(is_instance_valid(transient))
