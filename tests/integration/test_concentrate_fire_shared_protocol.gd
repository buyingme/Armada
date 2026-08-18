## TWI-002 Slice 8B-1 persistence, replay, and network protocol evidence.
extends GutTest


const PROCESSOR_SCRIPT: GDScript = preload(
		"res://src/autoload/command_processor.gd")
const SAVE_MANAGER_SCRIPT: GDScript = preload(
		"res://src/autoload/save_game_manager.gd")
const RULE: GDScript = preload(
		"res://src/core/effects/rules/concentrate_fire_token.gd")
const USE_COMMAND: GDScript = preload(
		"res://src/core/commands/use_concentrate_fire_token_reroll_command.gd")
const DECLINE_COMMAND: GDScript = preload(
		"res://src/core/commands/decline_concentrate_fire_token_reroll_command.gd")
const ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")
const DEFINITIONS: GDScript = preload(
		"res://src/core/timing_windows/timing_window_definitions.gd")
const OPPORTUNITY: GDScript = preload(
		"res://src/core/timing_windows/timing_window_opportunity.gd")
const CURRENT_ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")

const TEST_SAVE: String = "_gut_slice_8b1_concentrate_fire"

var _saved_registry: Dictionary = {}
var _saved_state: GameState = null
var _saved_active: bool = false
var _saved_submitter: CommandSubmitter = null
var _saved_play_mode: PlayMode.Mode
var _saved_network_role: NetworkManager.Role
var _saved_local_player: int = -1
var _broadcast_results: Array[Dictionary] = []


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	_saved_state = GameManager.current_game_state
	_saved_active = GameManager.is_game_active
	_saved_submitter = GameManager.get_command_submitter()
	_saved_play_mode = PlayMode.current_mode
	_saved_network_role = NetworkManager.role
	_saved_local_player = NetworkManager._local_player_index
	_broadcast_results.clear()
	RuleRegistry.clear()
	RULE.register()
	USE_COMMAND.register()
	DECLINE_COMMAND.register()
	ConfirmAttackDiceCommand.register()
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()


func after_each() -> void:
	var capture: Callable = Callable(self, "_capture_network_result")
	if NetworkManager.command_result_received.is_connected(capture):
		NetworkManager.command_result_received.disconnect(capture)
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	manager.delete_save(TEST_SAVE)
	manager.free()
	RuleRegistry.clear()
	GameCommand._registry = _saved_registry
	GameManager.current_game_state = _saved_state
	GameManager.is_game_active = _saved_active
	GameManager.set_command_submitter(_saved_submitter)
	PlayMode.current_mode = _saved_play_mode
	NetworkManager.role = _saved_network_role
	NetworkManager._local_player_index = _saved_local_player
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()


func test_save_load_and_reconnect_rederive_pending_choice_at_version_three() -> void:
	var state: GameState = _make_pending_state()
	GameManager.current_game_state = state
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	CommandProcessor.reset()
	assert_true(CommandProcessor.restore_next_sequence(1))
	var expected_projection: Dictionary = UIProjector.project(
			state, 0).timing_window

	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	assert_true(manager.save_game(state, TEST_SAVE))
	var loaded: Dictionary = manager.load_game(TEST_SAVE)
	assert_true(bool(loaded.get("ok", false)))
	var restored: GameState = loaded.get("state") as GameState
	var metadata: SaveGameMetadata = loaded.get("meta") as SaveGameMetadata
	assert_not_null(restored)
	assert_not_null(metadata)
	assert_eq(metadata.save_format_version, 4)
	assert_eq(SaveGameMetadata.CURRENT_VERSION, 4)
	assert_eq(GameReplay.FORMAT_VERSION, 6)
	assert_eq(UIProjector.project(restored, 0).timing_window,
			expected_projection)
	assert_eq((ORCHESTRATOR.derive_current_opportunities(restored).get(
			ORCHESTRATOR.KEY_OPPORTUNITIES, []) as Array).size(), 1)

	var reconnect: GameState = GameState.deserialize(
			StateFilter.filter_for_player(state.serialize(), 0))
	assert_not_null(reconnect)
	assert_eq(UIProjector.project(reconnect, 0).timing_window,
			expected_projection)
	assert_eq((ORCHESTRATOR.derive_current_opportunities(reconnect).get(
			ORCHESTRATOR.KEY_OPPORTUNITIES, []) as Array).size(), 1)

	assert_true(GameManager.start_new_game_from_state(
			restored, "twi-002-production",
			metadata.next_command_sequence))
	assert_false(CommandProcessor.submit(DECLINE_COMMAND.new(
			0, _identity_payload(restored))).is_empty())
	assert_eq(_history_types(CommandProcessor.serialize_history()), [
		DECLINE_COMMAND.TYPE,
		ConfirmAttackDiceCommand.TYPE,
	])
	assert_eq(restored.current_attack_state.stage,
			CurrentAttackState.STAGE_ACCURACY)
	manager.delete_save(TEST_SAVE)
	manager.free()


func test_host_client_and_format_five_replay_preserve_use_and_continuation() -> void:
	var initial: GameState = _make_pending_state()
	var initial_data: Dictionary = initial.serialize()
	var authority_state: GameState = GameState.deserialize(initial_data)
	GameManager.current_game_state = authority_state
	GameManager.is_game_active = true
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = 0
	NetworkManager._host_match_principal_id = authority_state.principal_id_for_player(0)
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	var host := NetworkHostCommandSubmitter.new()
	GameManager.set_command_submitter(host)
	NetworkManager.command_result_received.connect(_capture_network_result)

	assert_false(host.submit(USE_COMMAND.new(
			0, _use_payload(authority_state, 1))).is_empty())
	var authoritative_history: Array[Dictionary] = \
			CommandProcessor.serialize_history()
	var authority_final: Dictionary = authority_state.serialize()
	assert_eq(_history_types(authoritative_history), [
		USE_COMMAND.TYPE,
		ConfirmAttackDiceCommand.TYPE,
	])
	assert_eq(_broadcast_command_data(), authoritative_history)

	var replay_file := GameReplay.new()
	replay_file.capture_header(
			"twi-002-production", 9917, [0, 1], 0, 0,
			initial.serialize().get("match_player_control_binding", {}))
	replay_file.set_commands(authoritative_history)
	var replay_data: Dictionary = replay_file.serialize()
	assert_eq((replay_data.get("header", {}) as Dictionary).get(
			"format_version"), 6)
	assert_not_null(GameReplay.deserialize(replay_data))

	var client_state: GameState = GameState.deserialize(initial_data)
	GameManager.current_game_state = client_state
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	for index: int in range(_broadcast_results.size()):
		_apply_broadcast_to_client(index)
	assert_eq(CommandProcessor.serialize_history(), authoritative_history)
	assert_eq(client_state.serialize(), authority_final)
	assert_eq(UIProjector.project(client_state, 1).timing_window,
			UIProjector.project(authority_state, 1).timing_window)
	assert_eq(UIProjector.project(client_state, 1).attack_dice_results,
			UIProjector.project(authority_state, 1).attack_dice_results,
			"Passive network projection must show the authoritative reroll.")

	var replay_state: GameState = GameState.deserialize(initial_data)
	var replay_processor: Node = _make_processor(replay_state)
	for command_data: Dictionary in authoritative_history:
		assert_false(replay_processor.submit_replay(
				GameCommand.deserialize(command_data)).is_empty())
	assert_eq(replay_processor.serialize_history(), authoritative_history)
	assert_eq(replay_state.serialize(), authority_final)
	assert_eq(UIProjector.project(replay_state, 0).attack_dice_results,
			UIProjector.project(authority_state, 0).attack_dice_results,
			"Replay must derive the same Concentrate Fire result projection.")
	assert_eq(replay_processor.get_pending_observer_followup_count(), 0)


func _make_processor(state: GameState) -> Node:
	GameManager.current_game_state = state
	var processor: Node = PROCESSOR_SCRIPT.new()
	add_child_autofree(processor)
	return processor


func _make_pending_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.rng = GameRng.new(9917)
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0,
			Constants.Visibility.ALL,
			{"attacker_player": 0})
	assert_not_null(CURRENT_ATTACK_FIXTURE.install(state, {
		"attack_id": "attack:0",
		"stage": CurrentAttackState.STAGE_ATTACK_MODIFY,
		"attacker_kind": CurrentAttackState.KIND_SHIP,
		"defender_kind": CurrentAttackState.KIND_SHIP,
		"cf_token_resolution": CurrentAttackState.RESOLUTION_PENDING,
		"dice_results": [{
			"color": int(Constants.DiceColor.RED),
			"face": int(Constants.DiceFace.HIT),
		}, {
			"color": int(Constants.DiceColor.BLUE),
			"face": int(Constants.DiceFace.ACCURACY),
		}],
	}))
	state.get_ship(0, 0).begin_attack_step()
	assert_true(state.get_ship(0, 0).command_tokens.add_token(
			Constants.CommandType.CONCENTRATE_FIRE))
	assert_true(bool(ORCHESTRATOR.open_window(
			state,
			DEFINITIONS.ATTACK_MODIFY,
			0,
			_context(state)).get(ORCHESTRATOR.KEY_OK, false)))
	return state


func _context(state: GameState) -> Dictionary:
	return {
		TimingWindowState.CONTINUATION_KEY_ID: ConfirmAttackDiceCommand.TYPE,
		TimingWindowState.CONTINUATION_KEY_RESUME_POINT: "attack_after_modify",
		TimingWindowState.CONTINUATION_KEY_SOURCE_ID:
				state.current_attack_state.attack_id,
		TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE: "current_attack",
		TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER: 0,
	}


func _identity_payload(state: GameState) -> Dictionary:
	var attack: CurrentAttackState = state.current_attack_state
	var ship_id: String = RULE.attacking_ship_identity(attack)
	return {
		ORCHESTRATOR.COMMAND_KEY_TIMING_WINDOW_ID:
				state.timing_window_state.timing_window_id,
		ORCHESTRATOR.COMMAND_KEY_LIFECYCLE_ID:
				state.timing_window_state.lifecycle_id,
		OPPORTUNITY.KEY_SOURCE_OWNER_KIND: RULE.SOURCE_OWNER_KIND,
		OPPORTUNITY.KEY_RUNTIME_SOURCE_ID:
				RULE.token_source_identity(ship_id),
		OPPORTUNITY.KEY_SEMANTIC_KEY: RULE.SEMANTIC_KEY,
		RULE.PAYLOAD_ATTACK_ID: attack.attack_id,
		RULE.PAYLOAD_ATTACKING_SHIP_ID: ship_id,
	}


func _use_payload(state: GameState, die_index: int) -> Dictionary:
	var payload: Dictionary = _identity_payload(state)
	var selected: Dictionary = state.current_attack_state.dice_results[die_index]
	payload["die_index"] = die_index
	payload["expected_color"] = int(selected.get("color", -1))
	payload["expected_face"] = int(selected.get("face", -1))
	return payload


func _capture_network_result(command_data: Dictionary,
		result: Dictionary) -> void:
	_broadcast_results.append({
		"command": command_data.duplicate(true),
		"result": result.duplicate(true),
	})


func _broadcast_command_data() -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	for entry: Dictionary in _broadcast_results:
		commands.append((entry.get("command") as Dictionary).duplicate(true))
	return commands


func _apply_broadcast_to_client(index: int) -> void:
	var entry: Dictionary = _broadcast_results[index]
	GameManager._on_network_command_result(
			entry.get("command") as Dictionary,
			entry.get("result") as Dictionary)


func _history_types(commands: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for command: Dictionary in commands:
		result.append(str(command.get("type", "")))
	return result
