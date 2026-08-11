## TWI-002 Slice 8B-2 H9 persistence, replay, and network evidence.
extends GutTest


const PROCESSOR_SCRIPT: GDScript = preload(
		"res://src/autoload/command_processor.gd")
const SAVE_MANAGER_SCRIPT: GDScript = preload(
		"res://src/autoload/save_game_manager.gd")
const H9_RULE: GDScript = preload(
		"res://src/core/effects/rules/upgrades/turbolasers/h9_turbolasers.gd")
const CF_RULE: GDScript = preload(
		"res://src/core/effects/rules/concentrate_fire_token.gd")
const H9_USE: GDScript = preload(
		"res://src/core/commands/use_h9_command.gd")
const H9_DECLINE: GDScript = preload(
		"res://src/core/commands/decline_h9_command.gd")
const CF_USE: GDScript = preload(
		"res://src/core/commands/use_concentrate_fire_token_reroll_command.gd")
const CF_DECLINE: GDScript = preload(
		"res://src/core/commands/decline_concentrate_fire_token_reroll_command.gd")
const ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")
const DEFINITIONS: GDScript = preload(
		"res://src/core/timing_windows/timing_window_definitions.gd")
const OPPORTUNITY: GDScript = preload(
		"res://src/core/timing_windows/timing_window_opportunity.gd")
const CURRENT_ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")

const TEST_SAVE: String = "_gut_slice_8b2_h9"

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
	H9_RULE.register()
	CF_RULE.register()
	H9_USE.register()
	H9_DECLINE.register()
	CF_USE.register()
	CF_DECLINE.register()
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


func test_save_load_and_reconnect_preserve_h9_guard_and_remaining_blocker() -> void:
	var state: GameState = _make_pending_state()
	GameManager.current_game_state = state
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	CommandProcessor.reset()
	assert_true(CommandProcessor.restore_next_sequence(1))
	var h9_source: Dictionary = _h9_source(state)
	assert_false(CommandProcessor.submit_deferred_followups(H9_USE.new(
			0, _h9_use_payload(state, h9_source, 0))).is_empty())
	assert_eq(CommandProcessor.get_pending_observer_followup_count(), 0)
	assert_eq(_opportunity_capabilities(state), [CF_RULE.CAPABILITY_ID])
	var expected_projection: Dictionary = UIProjector.project(
			state, 0).timing_window
	var expected_dice_projection: Array[Dictionary] = UIProjector.project(
			state, 0).attack_dice_results
	assert_eq(expected_dice_projection, state.current_attack_state.dice_results)

	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	assert_true(manager.save_game(state, TEST_SAVE))
	var loaded: Dictionary = manager.load_game(TEST_SAVE)
	assert_true(bool(loaded.get("ok", false)))
	var restored: GameState = loaded.get("state") as GameState
	var metadata: SaveGameMetadata = loaded.get("meta") as SaveGameMetadata
	assert_not_null(restored)
	assert_not_null(metadata)
	assert_eq(metadata.save_format_version, 3)
	assert_eq(SaveGameMetadata.CURRENT_VERSION, 3)
	assert_eq(GameReplay.FORMAT_VERSION, 5)
	assert_eq(UIProjector.project(restored, 0).timing_window,
			expected_projection)
	assert_eq(UIProjector.project(restored, 0).attack_dice_results,
			expected_dice_projection)
	assert_eq(_opportunity_capabilities(restored), [CF_RULE.CAPABILITY_ID])
	assert_eq(H9_RULE.resolution_guard(_h9_source(restored)), {
		H9_RULE.GUARD_ATTACK_ID: "attack:0",
		H9_RULE.GUARD_RESOLUTION: H9_RULE.RESOLUTION_USED,
	})

	var reconnect: GameState = GameState.deserialize(
			StateFilter.filter_for_player(state.serialize(), 0))
	assert_not_null(reconnect)
	assert_eq(UIProjector.project(reconnect, 0).timing_window,
			expected_projection)
	assert_eq(UIProjector.project(reconnect, 0).attack_dice_results,
			expected_dice_projection)
	assert_eq(_opportunity_capabilities(reconnect), [CF_RULE.CAPABILITY_ID])
	assert_eq(H9_RULE.resolution_guard(_h9_source(reconnect)), {
		H9_RULE.GUARD_ATTACK_ID: "attack:0",
		H9_RULE.GUARD_RESOLUTION: H9_RULE.RESOLUTION_USED,
	})

	GameManager.current_game_state = restored
	var restored_processor: Node = _make_processor(restored)
	assert_true(restored_processor.restore_next_sequence(
			metadata.next_command_sequence))
	assert_false(restored_processor.submit(CF_DECLINE.new(
			0, _cf_identity_payload(restored))).is_empty())
	assert_eq(_history_types(restored_processor.serialize_history()), [
		CF_DECLINE.TYPE,
		ConfirmAttackDiceCommand.TYPE,
	])
	assert_true(H9_RULE.resolution_guard(_h9_source(restored)).is_empty())
	assert_eq(restored.current_attack_state.stage,
			CurrentAttackState.STAGE_ACCURACY)
	manager.delete_save(TEST_SAVE)
	manager.free()


func test_reconstruction_rejects_h9_guard_without_matching_lifecycle() -> void:
	var state: GameState = _make_pending_state()
	GameManager.current_game_state = state
	var processor: Node = _make_processor(state)
	assert_false(processor.submit_deferred_followups(H9_DECLINE.new(
			0, _h9_identity_payload(state, _h9_source(state)))).is_empty())
	var invalid_data: Dictionary = state.serialize()
	invalid_data["timing_window_state"] = TimingWindowState.new().serialize()

	assert_null(GameState.deserialize(invalid_data))


func test_decline_round_trips_through_save_reconnect_network_and_replay() -> void:
	var initial: GameState = _make_pending_state()
	var initial_data: Dictionary = initial.serialize()
	var initial_dice: Array[Dictionary] = \
			initial.current_attack_state.dice_results
	var authority_state: GameState = GameState.deserialize(initial_data)
	GameManager.current_game_state = authority_state
	GameManager.is_game_active = true
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = 0
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	var host := NetworkHostCommandSubmitter.new()
	GameManager.set_command_submitter(host)
	NetworkManager.command_result_received.connect(_capture_network_result)

	var decline_result: Dictionary = host.submit(H9_DECLINE.new(
			0, _h9_identity_payload(authority_state, _h9_source(authority_state))))
	assert_false(decline_result.is_empty())
	assert_eq(_history_types(CommandProcessor.serialize_history()), [
		H9_DECLINE.TYPE,
	])
	_assert_declined_h9_state(authority_state, initial_dice)
	assert_eq(CommandProcessor.get_pending_observer_followup_count(), 0)
	var controller_projection: Dictionary = UIProjector.project(
			authority_state, 0).timing_window
	var passive_projection: Dictionary = UIProjector.project(
			authority_state, 1).timing_window

	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	assert_true(manager.save_game(authority_state, TEST_SAVE))
	var loaded: Dictionary = manager.load_game(TEST_SAVE)
	assert_true(bool(loaded.get("ok", false)))
	var restored: GameState = loaded.get("state") as GameState
	var metadata: SaveGameMetadata = loaded.get("meta") as SaveGameMetadata
	assert_not_null(restored)
	assert_not_null(metadata)
	assert_eq(metadata.save_format_version, 3)
	assert_eq(SaveGameMetadata.CURRENT_VERSION, 3)
	assert_eq(GameReplay.FORMAT_VERSION, 5)
	_assert_declined_h9_state(restored, initial_dice)
	assert_eq(UIProjector.project(restored, 0).timing_window,
			controller_projection)
	assert_eq(UIProjector.project(restored, 1).timing_window,
			passive_projection)

	for viewer_player: int in [0, 1]:
		var reconnect: GameState = GameState.deserialize(
				StateFilter.filter_for_player(
					authority_state.serialize(), viewer_player))
		assert_not_null(reconnect)
		_assert_declined_h9_state(reconnect, initial_dice)
		assert_eq(UIProjector.project(
				reconnect, viewer_player).timing_window,
				UIProjector.project(
					authority_state, viewer_player).timing_window)

	assert_false(host.submit(CF_DECLINE.new(
			0, _cf_identity_payload(authority_state))).is_empty())
	var authoritative_history: Array[Dictionary] = \
			CommandProcessor.serialize_history()
	assert_eq(_history_types(authoritative_history), [
		H9_DECLINE.TYPE,
		CF_DECLINE.TYPE,
		ConfirmAttackDiceCommand.TYPE,
	])
	assert_false(_history_types(authoritative_history).has(H9_USE.TYPE))
	assert_eq(_broadcast_command_data(), authoritative_history)
	assert_eq(authority_state.current_attack_state.dice_results, initial_dice)
	assert_true(H9_RULE.resolution_guard(
			_h9_source(authority_state)).is_empty())
	assert_true(authority_state.timing_window_state.is_inactive())
	assert_eq(authority_state.current_attack_state.stage,
			CurrentAttackState.STAGE_ACCURACY)
	var authority_hash: String = CanonicalJson.hash(authority_state.serialize())
	var authority_next_sequence: int = CommandProcessor.get_next_sequence()

	var replay_file := GameReplay.new()
	replay_file.capture_header(
			"slice-8b2-h9-decline", 7419, [0, 1], 0, 0)
	replay_file.set_commands(authoritative_history)
	var replay_data: Dictionary = replay_file.serialize()
	assert_eq((replay_data.get("header", {}) as Dictionary).get(
			"format_version"), 5)
	assert_not_null(GameReplay.deserialize(replay_data))

	var client_state: GameState = GameState.deserialize(initial_data)
	GameManager.current_game_state = client_state
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	_apply_broadcast_to_client(0)
	_assert_declined_h9_state(client_state, initial_dice)
	assert_eq(CommandProcessor.get_next_sequence(), 1)
	assert_eq(UIProjector.project(client_state, 0).timing_window,
			controller_projection)
	assert_eq(UIProjector.project(client_state, 1).timing_window,
			passive_projection)
	for index: int in range(1, _broadcast_results.size()):
		_apply_broadcast_to_client(index)
	assert_eq(CommandProcessor.serialize_history(), authoritative_history)
	assert_eq(CommandProcessor.get_next_sequence(), authority_next_sequence)
	assert_eq(CanonicalJson.hash(client_state.serialize()), authority_hash)
	assert_eq(client_state.current_attack_state.dice_results, initial_dice)
	assert_eq(H9_RULE.resolution_guard(_h9_source(client_state)),
			H9_RULE.resolution_guard(_h9_source(authority_state)))
	assert_eq(client_state.timing_window_state.serialize(),
			authority_state.timing_window_state.serialize())
	assert_eq(UIProjector.project(client_state, 0).timing_window,
			UIProjector.project(authority_state, 0).timing_window)
	assert_eq(UIProjector.project(client_state, 1).timing_window,
			UIProjector.project(authority_state, 1).timing_window)
	assert_eq(UIProjector.project(client_state, 1).attack_dice_results,
			UIProjector.project(authority_state, 1).attack_dice_results,
			"Passive network projection must show authoritative dice after decline.")

	var replay_state: GameState = GameState.deserialize(initial_data)
	var replay_processor: Node = _make_processor(replay_state)
	for command_data: Dictionary in authoritative_history:
		assert_false(replay_processor.submit_replay(
				GameCommand.deserialize(command_data)).is_empty())
	assert_eq(replay_processor.serialize_history(), authoritative_history)
	assert_eq(replay_processor.get_next_sequence(), authority_next_sequence)
	assert_eq(CanonicalJson.hash(replay_state.serialize()), authority_hash)
	assert_eq(replay_state.current_attack_state.dice_results, initial_dice)
	assert_eq(H9_RULE.resolution_guard(_h9_source(replay_state)),
			H9_RULE.resolution_guard(_h9_source(authority_state)))
	assert_eq(replay_state.timing_window_state.serialize(),
			authority_state.timing_window_state.serialize())
	assert_eq(UIProjector.project(replay_state, 0).timing_window,
			UIProjector.project(authority_state, 0).timing_window)
	assert_eq(UIProjector.project(replay_state, 1).timing_window,
			UIProjector.project(authority_state, 1).timing_window)
	manager.delete_save(TEST_SAVE)
	manager.free()


func test_h9_then_concentrate_fire_matches_host_client_and_format_five_replay() -> void:
	var result: Dictionary = _run_network_replay_order(true)
	assert_eq(result.get("history_types"), [
		H9_USE.TYPE,
		CF_USE.TYPE,
		ConfirmAttackDiceCommand.TYPE,
	])


func test_concentrate_fire_then_h9_rejects_stale_choice_and_matches_all_modes() -> void:
	var result: Dictionary = _run_network_replay_order(false)
	assert_eq(result.get("history_types"), [
		CF_USE.TYPE,
		H9_USE.TYPE,
		ConfirmAttackDiceCommand.TYPE,
	])
	assert_true(bool(result.get("stale_h9_rejected", false)))


func _run_network_replay_order(h9_first: bool) -> Dictionary:
	var initial: GameState = _make_pending_state()
	var initial_data: Dictionary = initial.serialize()
	var authority_state: GameState = GameState.deserialize(initial_data)
	GameManager.current_game_state = authority_state
	GameManager.is_game_active = true
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = 0
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	var host := NetworkHostCommandSubmitter.new()
	GameManager.set_command_submitter(host)
	NetworkManager.command_result_received.connect(_capture_network_result)

	var stale_h9: GameCommand = H9_USE.new(
			0, _h9_use_payload(authority_state,
					_h9_source(authority_state), 1))
	if h9_first:
		assert_false(host.submit(H9_USE.new(0, _h9_use_payload(
				authority_state, _h9_source(authority_state), 0))).is_empty())
		assert_eq(_opportunity_capabilities(authority_state), [
			CF_RULE.CAPABILITY_ID])
		assert_false(host.submit(CF_USE.new(
				0, _cf_use_payload(authority_state, 1))).is_empty())
	else:
		var before_face: int = int(authority_state.current_attack_state \
				.dice_results[1].get("face", -1))
		assert_false(host.submit(CF_USE.new(
				0, _cf_use_payload(authority_state, 1))).is_empty())
		assert_ne(int(authority_state.current_attack_state.dice_results[1].get(
				"face", -1)), before_face,
				"The deterministic fixture must mutate the projected H9 die.")
		assert_ne(stale_h9.validate(authority_state), "")
		assert_eq(_opportunity_capabilities(authority_state), [
			H9_RULE.CAPABILITY_ID])
		assert_false(host.submit(H9_USE.new(0, _h9_use_payload(
				authority_state, _h9_source(authority_state), 0))).is_empty())

	var authoritative_history: Array[Dictionary] = \
			CommandProcessor.serialize_history()
	var authority_final: Dictionary = authority_state.serialize()
	var authority_hash: String = CanonicalJson.hash(authority_final)
	assert_eq(_broadcast_command_data(), authoritative_history)
	assert_eq(authority_state.current_attack_state.stage,
			CurrentAttackState.STAGE_ACCURACY)
	assert_true(authority_state.timing_window_state.is_inactive())
	assert_true(H9_RULE.resolution_guard(
			_h9_source(authority_state)).is_empty())

	var replay_file := GameReplay.new()
	replay_file.capture_header(
			"twi-002-production", 7419, [0, 1], 0, 0)
	replay_file.set_commands(authoritative_history)
	var replay_data: Dictionary = replay_file.serialize()
	assert_eq((replay_data.get("header", {}) as Dictionary).get(
			"format_version"), 5)
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
	assert_eq(CanonicalJson.hash(client_state.serialize()), authority_hash)
	assert_eq(UIProjector.project(client_state, 1).timing_window,
			UIProjector.project(authority_state, 1).timing_window)
	assert_eq(UIProjector.project(client_state, 1).attack_dice_results,
			UIProjector.project(authority_state, 1).attack_dice_results,
			"Passive network projection must show post-H9 modified dice.")

	var replay_state: GameState = GameState.deserialize(initial_data)
	var replay_processor: Node = _make_processor(replay_state)
	for command_data: Dictionary in authoritative_history:
		assert_false(replay_processor.submit_replay(
				GameCommand.deserialize(command_data)).is_empty())
	assert_eq(replay_processor.serialize_history(), authoritative_history)
	assert_eq(CanonicalJson.hash(replay_state.serialize()), authority_hash)
	assert_eq(UIProjector.project(replay_state, 0).attack_dice_results,
			UIProjector.project(authority_state, 0).attack_dice_results,
			"Replay must derive the same post-H9 dice projection.")
	assert_eq(replay_processor.get_pending_observer_followup_count(), 0)
	return {
		"history_types": _history_types(authoritative_history),
		"stale_h9_rejected": stale_h9.validate(authority_state) != "",
	}


func _make_processor(state: GameState) -> Node:
	GameManager.current_game_state = state
	var processor: Node = PROCESSOR_SCRIPT.new()
	add_child_autofree(processor)
	return processor


func _make_pending_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.rng = GameRng.new(7419)
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
			"face": int(Constants.DiceFace.CRITICAL),
		}],
	}))
	var attacker: ShipInstance = state.get_ship(0, 0)
	attacker.roster_entry_id = "attacker-0"
	attacker.begin_attack_step()
	attacker.add_runtime_upgrade(
			H9_RULE.DATA_KEY, "h9-0", "TURBOLASERS", 0)
	assert_true(attacker.command_tokens.add_token(
			Constants.CommandType.CONCENTRATE_FIRE))
	assert_true(bool(ORCHESTRATOR.open_window(
			state,
			DEFINITIONS.ATTACK_MODIFY,
			0,
			_context(state)).get(ORCHESTRATOR.KEY_OK, false)))
	assert_eq(_opportunity_capabilities(state), [
		CF_RULE.CAPABILITY_ID,
		H9_RULE.CAPABILITY_ID,
	])
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


func _h9_source(state: GameState) -> Dictionary:
	for runtime_upgrade: Dictionary in state.get_ship(0, 0).runtime_upgrades:
		if str(runtime_upgrade.get("data_key", "")) == H9_RULE.DATA_KEY:
			return runtime_upgrade
	return {}


func _h9_identity_payload(state: GameState,
		runtime_upgrade: Dictionary) -> Dictionary:
	var runtime_upgrade_id: String = str(runtime_upgrade.get(
			"runtime_upgrade_id", ""))
	return {
		ORCHESTRATOR.COMMAND_KEY_TIMING_WINDOW_ID:
				state.timing_window_state.timing_window_id,
		ORCHESTRATOR.COMMAND_KEY_LIFECYCLE_ID:
				state.timing_window_state.lifecycle_id,
		OPPORTUNITY.KEY_SOURCE_OWNER_KIND: H9_RULE.SOURCE_OWNER_KIND,
		OPPORTUNITY.KEY_RUNTIME_SOURCE_ID: runtime_upgrade_id,
		OPPORTUNITY.KEY_SEMANTIC_KEY: H9_RULE.SEMANTIC_KEY,
		H9_RULE.PAYLOAD_ATTACK_ID: state.current_attack_state.attack_id,
		H9_RULE.PAYLOAD_RUNTIME_UPGRADE_ID: runtime_upgrade_id,
	}


func _h9_use_payload(state: GameState,
		runtime_upgrade: Dictionary,
		die_index: int) -> Dictionary:
	var payload: Dictionary = _h9_identity_payload(state, runtime_upgrade)
	var selected: Dictionary = state.current_attack_state.dice_results[die_index]
	payload.merge({
		"die_index": die_index,
		"expected_color": int(selected.get("color", -1)),
		"expected_face": int(selected.get("face", -1)),
		H9_RULE.PAYLOAD_TARGET_FACE: int(Constants.DiceFace.ACCURACY),
	})
	return payload


func _cf_identity_payload(state: GameState) -> Dictionary:
	var attack: CurrentAttackState = state.current_attack_state
	var ship_id: String = CF_RULE.attacking_ship_identity(attack)
	return {
		ORCHESTRATOR.COMMAND_KEY_TIMING_WINDOW_ID:
				state.timing_window_state.timing_window_id,
		ORCHESTRATOR.COMMAND_KEY_LIFECYCLE_ID:
				state.timing_window_state.lifecycle_id,
		OPPORTUNITY.KEY_SOURCE_OWNER_KIND: CF_RULE.SOURCE_OWNER_KIND,
		OPPORTUNITY.KEY_RUNTIME_SOURCE_ID:
				CF_RULE.token_source_identity(ship_id),
		OPPORTUNITY.KEY_SEMANTIC_KEY: CF_RULE.SEMANTIC_KEY,
		CF_RULE.PAYLOAD_ATTACK_ID: attack.attack_id,
		CF_RULE.PAYLOAD_ATTACKING_SHIP_ID: ship_id,
	}


func _cf_use_payload(state: GameState, die_index: int) -> Dictionary:
	var payload: Dictionary = _cf_identity_payload(state)
	var selected: Dictionary = state.current_attack_state.dice_results[die_index]
	payload.merge({
		"die_index": die_index,
		"expected_color": int(selected.get("color", -1)),
		"expected_face": int(selected.get("face", -1)),
	})
	return payload


func _opportunity_capabilities(state: GameState) -> Array[String]:
	var result: Dictionary = ORCHESTRATOR.derive_current_opportunities(state)
	assert_true(bool(result.get(ORCHESTRATOR.KEY_OK, false)))
	var capabilities: Array[String] = []
	for opportunity: Dictionary in result.get(
			ORCHESTRATOR.KEY_OPPORTUNITIES, []):
		capabilities.append(str(opportunity.get(
				OPPORTUNITY.KEY_CAPABILITY_ID, "")))
	capabilities.sort()
	return capabilities


func _assert_declined_h9_state(state: GameState,
		expected_dice: Array[Dictionary]) -> void:
	assert_eq(state.current_attack_state.dice_results, expected_dice)
	assert_eq(H9_RULE.resolution_guard(_h9_source(state)), {
		H9_RULE.GUARD_ATTACK_ID: "attack:0",
		H9_RULE.GUARD_RESOLUTION: H9_RULE.RESOLUTION_DECLINED,
	})
	assert_eq(_opportunity_capabilities(state), [CF_RULE.CAPABILITY_ID])
	assert_true(state.timing_window_state.active)
	assert_eq(state.timing_window_state.status, TimingWindowState.STATUS_OPEN)


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
