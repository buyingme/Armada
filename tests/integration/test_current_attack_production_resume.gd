## Slice 8A production-composition evidence for canonical active-attack resume.
extends GutTest


const CURRENT_ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")
const SAVE_MANAGER_SCRIPT: GDScript = preload(
		"res://src/autoload/save_game_manager.gd")
const TEST_SAVE: String = "_gut_slice_8a_production_resume"
const GAME_BOARD_SCENE: PackedScene = preload(
		"res://src/scenes/game_board/game_board.tscn")
const GAME_BOARD_PATH: String = "res://src/scenes/game_board/game_board.tscn"
const DECOY_SHIP_KEY: String = "cr90_corvette_a"
const DECOY_SQUADRON_KEY: String = "x_wing_squadron"

var _saved_state: GameState = null
var _saved_active: bool = false
var _saved_submitter: CommandSubmitter = null
var _saved_play_mode: PlayMode.Mode
var _saved_network_role: NetworkManager.Role
var _saved_local_player: int = -1
var _saved_replaying: bool = false
var _saved_preloaded: bool = false
var _saved_active_player: int = -1
var _saved_activating_ship: ShipInstance = null

var _ship_tokens: Array[ShipToken] = []
var _squadron_tokens: Array[SquadronToken] = []


class AuthenticatedRecordingSubmitter:
	extends CommandSubmitter

	var authenticated_player: int = 1
	var submitted_commands: Array[GameCommand] = []
	var peer_player_rejections: Array[GameCommand] = []


	func submit(command: GameCommand) -> Dictionary:
		if command.player_index != authenticated_player:
			peer_player_rejections.append(command)
			return {}
		submitted_commands.append(command)
		return {"submitted": true}


class AuthenticatedExecutingSubmitter:
	extends CommandSubmitter

	var authenticated_player: int = 1
	var submitted_commands: Array[GameCommand] = []
	var accepted_commands: Array[GameCommand] = []
	var peer_player_rejections: Array[GameCommand] = []
	var processor_rejections: Array[GameCommand] = []


	func submit(command: GameCommand) -> Dictionary:
		if command.player_index != authenticated_player:
			peer_player_rejections.append(command)
			return {}
		submitted_commands.append(command)
		var result: Dictionary = CommandProcessor.submit(command)
		if result.is_empty():
			processor_rejections.append(command)
		else:
			accepted_commands.append(command)
		return result


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_active = GameManager.is_game_active
	_saved_submitter = GameManager.get_command_submitter()
	_saved_play_mode = PlayMode.current_mode
	_saved_network_role = NetworkManager.role
	_saved_local_player = NetworkManager._local_player_index
	_saved_replaying = CommandProcessor.is_replaying
	_saved_preloaded = GameManager.is_state_preloaded
	_saved_active_player = GameManager.active_player
	_saved_activating_ship = GameManager._activating_ship
	_ship_tokens.clear()
	_squadron_tokens.clear()
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	GameManager.set_command_submitter(LocalCommandSubmitter.new())
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	NetworkManager._local_player_index = -1


func after_each() -> void:
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	manager.delete_save(TEST_SAVE)
	manager.free()
	CommandProcessor.reset()
	CommandProcessor.is_replaying = _saved_replaying
	GameManager.current_game_state = _saved_state
	GameManager.is_game_active = _saved_active
	GameManager.is_state_preloaded = _saved_preloaded
	GameManager.active_player = _saved_active_player
	GameManager._activating_ship = _saved_activating_ship
	GameManager.set_command_submitter(_saved_submitter)
	GameManager._reset_network_result_ordering()
	PlayMode.current_mode = _saved_play_mode
	NetworkManager.role = _saved_network_role
	NetworkManager._local_player_index = _saved_local_player


func test_resume_before_confirmation_ignores_stale_flow_authority() -> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_ATTACK_MODIFY, {
		"attack_id": "attack:6",
		"dice_results": [_accuracy_die()],
	})
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			1, Constants.Visibility.ALL, {
				"attacker_player": 1,
				"defender_player": 0,
				"dice_results": [],
			})
	GameManager.current_game_state = state
	assert_true(CommandProcessor.restore_next_sequence(7))
	var executor: AttackExecutor = _make_composition(state)

	var before: Dictionary = state.current_attack_state.serialize()
	var plan: Dictionary = executor.resume_current_attack(
			_find_ship_token, _find_squadron_token)

	assert_true(bool(plan.get(AttackExecutor.RESUME_KEY_OK, false)))
	assert_eq(plan.get(AttackExecutor.RESUME_KEY_TRANSITION),
			AttackExecutor.RESUME_CONFIRM)
	assert_true(bool(plan.get(AttackExecutor.RESUME_KEY_REQUIRES_INPUT, false)))
	assert_eq(state.current_attack_state.serialize(), before,
			"Scene reconstruction must not write canonical attack facts.")
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_MODIFY)
	assert_eq(state.interaction_flow.controller_player, 0)
	assert_eq(state.interaction_flow.payload.get("attacker_player"), 0)
	assert_eq(state.interaction_flow.payload.get("defender_player"), 1)
	assert_eq(state.interaction_flow.payload.get("dice_results"),
			[_accuracy_die()])
	assert_true(executor.is_in_exec_mode())
	assert_eq(CommandProcessor.get_next_sequence(), 7)
	assert_eq(CommandProcessor.get_command_count(), 0)


func test_resume_reprojects_all_cross_kind_participant_references() -> void:
	var cases: Array[Dictionary] = [
		{"attacker": CurrentAttackState.KIND_SHIP,
			"defender": CurrentAttackState.KIND_SHIP},
		{"attacker": CurrentAttackState.KIND_SHIP,
			"defender": CurrentAttackState.KIND_SQUADRON},
		{"attacker": CurrentAttackState.KIND_SQUADRON,
			"defender": CurrentAttackState.KIND_SHIP},
		{"attacker": CurrentAttackState.KIND_SQUADRON,
			"defender": CurrentAttackState.KIND_SQUADRON},
	]
	for index: int in range(cases.size()):
		_clear_composition_tokens()
		var spec: Dictionary = cases[index]
		var state: GameState = _state_at(
				CurrentAttackState.STAGE_ATTACK_MODIFY, {
					"attack_id": "attack:%d" % (40 + index),
					"attacker_kind": str(spec["attacker"]),
					"defender_kind": str(spec["defender"]),
					"dice_results": [_hit_die()],
					"range_band": Constants.RANGE_BAND_MEDIUM,
					"obstructed": true,
					"obstruction_resolved": true,
				})
		_ensure_cross_kind_decoys(state)
		GameManager.current_game_state = state
		var executor: AttackExecutor = _make_composition(state)
		var scene: AttackState = executor._state
		# Seed mutually inconsistent mirrors to prove reconstruction clears them.
		scene.attacker_ship = _find_ship_token(state.get_ship(0, 0))
		scene.attacker_squadron = _find_squadron_token(
				state.get_squadron(0, 0))
		scene.defender_ship = _find_ship_token(state.get_ship(1, 0))
		scene.defender_squadron = _find_squadron_token(
				state.get_squadron(1, 0))

		var plan: Dictionary = executor.resume_current_attack(
				_find_ship_token, _find_squadron_token)

		assert_true(bool(plan.get(AttackExecutor.RESUME_KEY_OK, false)))
		assert_eq(scene.attacker_zone,
				state.current_attack_state.attacker_zone)
		assert_eq(scene.defender_zone,
				state.current_attack_state.defender_zone)
		assert_eq(scene.dice_results, [_hit_die()])
		assert_eq(scene.range_band, Constants.RANGE_BAND_MEDIUM)
		assert_true(scene.obstructed)
		if str(spec["attacker"]) == CurrentAttackState.KIND_SHIP:
			assert_eq(scene.attacker_ship,
					_find_ship_token(state.get_ship(0, 0)))
			assert_null(scene.attacker_squadron)
			assert_not_null(scene.exec_ship_token)
			assert_null(scene.exec_squad_token)
		else:
			assert_eq(scene.attacker_squadron,
					_find_squadron_token(state.get_squadron(0, 0)))
			assert_null(scene.attacker_ship)
			assert_not_null(scene.exec_squad_token)
			assert_null(scene.exec_ship_token)
		if str(spec["defender"]) == CurrentAttackState.KIND_SHIP:
			assert_eq(scene.defender_ship,
					_find_ship_token(state.get_ship(1, 0)))
			assert_null(scene.defender_squadron)
		else:
			assert_eq(scene.defender_squadron,
					_find_squadron_token(state.get_squadron(1, 0)))
			assert_null(scene.defender_ship)


func test_real_game_board_ready_reconstructs_before_routing_or_activation() -> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_ATTACK_MODIFY, {
		"attack_id": "attack:30",
		"dice_results": [_hit_die()],
	})
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			1, Constants.Visibility.ALL, {"fictional": true})
	var before: Dictionary = state.current_attack_state.serialize()
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 31))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)

	assert_false(board._active_attack_reconstruction_blocked)
	assert_not_null(board._command_router_adapter,
			"Routing should be installed only after reconstruction succeeds.")
	assert_true(board._attack_executor.is_in_exec_mode())
	assert_eq(state.current_attack_state.serialize(), before,
			"Production board reconstruction must not write canonical facts.")
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_MODIFY)
	assert_false(state.interaction_flow.payload.has("fictional"))
	assert_eq(CommandProcessor.get_next_sequence(), 31)
	assert_eq(CommandProcessor.get_command_count(), 0)


func test_real_game_board_schedules_one_deterministic_continuation() -> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_DEFENSE, {
		"attack_id": "attack:32",
		"dice_results": [_hit_die()],
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
	})
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 33))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	assert_false(board._scheduled_attack_resume_key.is_empty(),
			"Production board should schedule the command-owned continuation.")
	var duplicate_plan: Dictionary = {
		AttackExecutor.RESUME_KEY_OK: true,
		AttackExecutor.RESUME_KEY_ATTACK_ID: "attack:32",
		AttackExecutor.RESUME_KEY_TRANSITION: AttackExecutor.RESUME_DAMAGE,
		AttackExecutor.RESUME_KEY_REQUIRES_INPUT: false,
		"stage": CurrentAttackState.STAGE_DEFENSE,
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
	}
	assert_false(board._schedule_active_attack_resume(duplicate_plan),
			"The same production continuation must not be queued twice.")

	await get_tree().process_frame
	assert_true(state.current_attack_state.is_inactive())
	assert_eq(_history_types(), ["resolve_damage", "complete_attack"])
	assert_eq(CommandProcessor.get_next_sequence(), 35)
	await get_tree().process_frame
	assert_eq(_history_types(), ["resolve_damage", "complete_attack"],
			"Deferred production resume must remain single-shot.")


func test_real_game_board_ready_failure_remains_inert_and_single_shot() -> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_ATTACK_MODIFY, {
		"attack_id": "attack:34",
		"dice_results": [_hit_die()],
	})
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			1, Constants.Visibility.ALL, {"stale": true})
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 35))
	var removed_defender: ShipInstance = state.get_ship(1, 0)
	assert_not_null(removed_defender)
	state.get_player_state(1).ships.remove_at(0)
	assert_true(state.current_attack_state.is_valid(),
			"The canonical attack payload must remain schema-valid.")
	assert_true(state.current_attack_state.active)
	assert_false(state.validate_current_attack_references(),
			"The accepted state should now expose the missing runtime reference.")
	var canonical_before: Dictionary = state.current_attack_state.serialize()
	var flow_before: Dictionary = state.interaction_flow.serialize()
	var state_before: Dictionary = state.serialize()
	var history_before: Array[Dictionary] = CommandProcessor.serialize_history()
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	assert_eq(board.scene_file_path, GAME_BOARD_PATH,
			"Failure evidence must use the real packed GameBoard scene.")
	add_child_autofree(board)

	assert_true(board._active_attack_reconstruction_blocked)
	assert_eq(board._active_attack_reconstruction_failure,
			"Canonical attack entity reference is missing.")
	assert_eq(board.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(board.is_processing())
	assert_false(board.is_processing_input())
	assert_false(board.is_processing_unhandled_input())
	assert_null(board._command_router_adapter,
			"Command routing must not be installed after reconstruction failure.")
	assert_false(board._attack_executor.is_in_exec_mode())
	assert_true(board._scheduled_attack_resume_key.is_empty())
	assert_eq(state.current_attack_state.serialize(), canonical_before)
	assert_eq(state.interaction_flow.serialize(), flow_before,
			"Failed reconstruction must not publish a replacement flow.")
	assert_eq(state.serialize(), state_before,
			"Production failure must leave all canonical state unchanged.")
	assert_eq(CommandProcessor.get_next_sequence(), 35)
	assert_eq(CommandProcessor.serialize_history(), history_before)
	assert_true(_history_types().is_empty(),
			"Failure must synthesize no continuation or player decision.")
	assert_false(_history_types().has("begin_attack"))
	assert_false(_history_types().has("complete_attack"))
	assert_false(board._finalize_ready_sequence(),
			"A blocked board must not retry or schedule continuation implicitly.")

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(board._active_attack_reconstruction_blocked)
	assert_eq(board.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_null(board._command_router_adapter)
	assert_true(board._scheduled_attack_resume_key.is_empty())
	assert_eq(state.serialize(), state_before)
	assert_eq(CommandProcessor.get_next_sequence(), 35)
	assert_eq(CommandProcessor.serialize_history(), history_before,
			"Deferred processing must not submit or duplicate a continuation.")
	assert_push_error(1, "The production failure should be surfaced once.")
	assert_not_null(removed_defender,
			"The missing runtime reference is retained only by the test fixture.")


func test_deserialization_rejects_inconsistent_active_attack_reference() -> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_ATTACK_MODIFY, {
		"attack_id": "attack:36",
		"dice_results": [_hit_die()],
	})
	var serialized: Dictionary = state.serialize()
	serialized["current_attack_state"]["defender_index"] = 99
	assert_null(GameState.deserialize(serialized),
			"Inconsistent canonical references must fail before board projection.")


func test_resume_accuracy_rebuilds_pending_canonical_choice() -> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_ACCURACY, {
		"attack_id": "attack:8",
		"dice_results": [_accuracy_die(), _hit_die()],
	})
	GameManager.current_game_state = state
	assert_true(CommandProcessor.restore_next_sequence(9))
	var executor: AttackExecutor = _make_composition(state)

	var plan: Dictionary = executor.resume_current_attack(
			_find_ship_token, _find_squadron_token)

	assert_true(bool(plan.get(AttackExecutor.RESUME_KEY_OK, false)))
	assert_eq(plan.get(AttackExecutor.RESUME_KEY_TRANSITION),
			AttackExecutor.RESUME_ACCURACY)
	assert_true(bool(plan.get(AttackExecutor.RESUME_KEY_REQUIRES_INPUT, false)))
	assert_true(executor._state.accuracy_step)
	assert_eq(executor._state.dice_results,
			state.current_attack_state.dice_results)
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_MODIFY)
	assert_eq(CommandProcessor.get_next_sequence(), 9,
			"Rebuilding Accuracy must not synthesize its decision.")


func test_resume_during_defense_rebuilds_pending_and_evade_projection() -> void:
	var pending_state: GameState = _state_at(CurrentAttackState.STAGE_DEFENSE, {
		"attack_id": "attack:10",
		"dice_results": [_hit_die()],
		"defense_stage": CurrentAttackState.DEFENSE_PENDING,
	})
	GameManager.current_game_state = pending_state
	var pending_executor: AttackExecutor = _make_composition(pending_state)
	var pending_plan: Dictionary = pending_executor.resume_current_attack(
			_find_ship_token, _find_squadron_token)
	assert_true(bool(pending_plan.get(AttackExecutor.RESUME_KEY_OK, false)))
	assert_eq(pending_plan.get(AttackExecutor.RESUME_KEY_TRANSITION),
			AttackExecutor.RESUME_DEFENSE)
	assert_true(bool(pending_plan.get(
			AttackExecutor.RESUME_KEY_REQUIRES_INPUT, false)))
	assert_eq(pending_state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)
	assert_eq(pending_state.interaction_flow.controller_player, 1)

	var resolving_state: GameState = _state_at(
			CurrentAttackState.STAGE_DEFENSE, {
				"attack_id": "attack:11",
				"dice_results": [_hit_die(), _hit_die()],
				"defense_stage": CurrentAttackState.DEFENSE_PENDING,
			})
	var defender: ShipInstance = resolving_state.get_ship(1, 0)
	var evade_index: int = _token_index(defender, Constants.DefenseToken.EVADE)
	assert_gte(evade_index, 0)
	var attack: CurrentAttackState = resolving_state.current_attack_state
	assert_true(resolving_state.set_current_attack_state(attack.with_patch({
		"defense_stage": CurrentAttackState.DEFENSE_RESOLVING,
		"committed_defense_tokens": [evade_index],
	})))
	defender.defense_tokens[evade_index]["state"] = \
			Constants.DefenseTokenState.EXHAUSTED
	GameManager.current_game_state = resolving_state
	_clear_composition_tokens()
	var resolving_executor: AttackExecutor = _make_composition(resolving_state)
	var resolving_plan: Dictionary = resolving_executor.resume_current_attack(
			_find_ship_token, _find_squadron_token)
	assert_true(bool(resolving_plan.get(AttackExecutor.RESUME_KEY_OK, false)))
	assert_eq(resolving_plan.get(AttackExecutor.RESUME_KEY_TRANSITION),
			AttackExecutor.RESUME_EVADE)
	assert_true(bool(resolving_plan.get(
			AttackExecutor.RESUME_KEY_REQUIRES_INPUT, false)))
	assert_true(resolving_executor._state.evade_step)
	assert_true(bool(resolving_state.interaction_flow.payload.get(
			"evade_active", false)))
	assert_eq(resolving_state.interaction_flow.payload.get(
			"evade_range_band"), resolving_state.current_attack_state.range_band)


func test_save_load_restores_cursor_before_production_resume() -> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_ATTACK_MODIFY, {
		"attack_id": "attack:12",
		"dice_results": [_hit_die()],
	})
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			1, Constants.Visibility.ALL, {"fictional": "scene authority"})
	GameManager.current_game_state = state
	assert_true(CommandProcessor.restore_next_sequence(13))
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	assert_true(manager.save_game(state, TEST_SAVE))
	var loaded: Dictionary = manager.load_game(TEST_SAVE)
	assert_true(bool(loaded.get("ok", false)))
	var restored: GameState = loaded.get("state") as GameState
	var metadata: SaveGameMetadata = loaded.get("meta") as SaveGameMetadata
	assert_true(GameManager.start_new_game_from_state(
			restored, "slice-8a-pre-activation",
			metadata.next_command_sequence))
	assert_eq(CommandProcessor.get_next_sequence(), 13)
	var executor: AttackExecutor = _make_composition(restored)

	var plan: Dictionary = executor.resume_current_attack(
			_find_ship_token, _find_squadron_token)

	assert_true(bool(plan.get(AttackExecutor.RESUME_KEY_OK, false)))
	assert_eq(plan.get(AttackExecutor.RESUME_KEY_TRANSITION),
			AttackExecutor.RESUME_CONFIRM)
	assert_eq(CommandProcessor.get_next_sequence(), 13)
	assert_eq(CommandProcessor.get_command_count(), 0)
	assert_false(restored.interaction_flow.payload.has("fictional"))
	assert_eq(restored.interaction_flow.payload.get("attack_id"), "attack:12")
	manager.delete_save(TEST_SAVE)
	manager.free()


func test_reconnect_resume_is_passive_and_uses_filtered_canonical_state() -> void:
	var server_state: GameState = _state_at(CurrentAttackState.STAGE_DEFENSE, {
		"attack_id": "attack:14",
		"dice_results": [_hit_die()],
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
	})
	server_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_MODIFY,
			0, Constants.Visibility.ALL, {"dice_results": []})
	var filtered: Dictionary = StateFilter.filter_for_player(
			server_state.serialize(), 1)
	var client_state: GameState = GameState.deserialize(filtered)
	assert_not_null(client_state)
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	assert_true(GameManager.start_new_game_from_state(
			client_state, "slice-8a-pre-activation", 15))
	var executor: AttackExecutor = _make_composition(client_state)

	var plan: Dictionary = executor.resume_current_attack(
			_find_ship_token, _find_squadron_token)

	assert_true(bool(plan.get(AttackExecutor.RESUME_KEY_OK, false)))
	assert_eq(plan.get(AttackExecutor.RESUME_KEY_TRANSITION),
			AttackExecutor.RESUME_DAMAGE)
	assert_false(bool(plan.get(
			AttackExecutor.RESUME_KEY_REQUIRES_INPUT, true)))
	assert_eq(client_state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)
	assert_eq(client_state.interaction_flow.payload.get("dice_results"),
			[_hit_die()])
	assert_false(executor.resume_live_progression(plan),
			"A reconnecting mirror must never author the deterministic follow-up.")
	assert_eq(CommandProcessor.get_next_sequence(), 15)
	assert_eq(CommandProcessor.get_command_count(), 0)


func test_player_one_pre_begin_ship_attack_keeps_primary_until_begin() -> void:
	var state: GameState = _player_one_ship_attack_state()
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	var submitter := AuthenticatedExecutingSubmitter.new()
	GameManager.set_command_submitter(submitter)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 0))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var executor: AttackExecutor = board._attack_executor
	var selector: TargetSelector = board._target_selector
	var mirror: AttackPanelMirror = board._panel_mgr.attack_panel_mirror
	var controller: ShipActivationController = \
			board._ship_activation_controller
	var vsd: ShipInstance = state.get_ship(1, 0)
	var vsd_token: ShipToken = _board_ship_token(board, vsd)
	assert_not_null(vsd_token)

	controller.on_dial_ship_activated(vsd_token, vsd)
	controller.submit_activation_step("squadron_step")
	controller.submit_activation_step("repair_step")
	controller.submit_activation_step("attack_step")
	assert_true(board._activation_ctx.is_active())
	assert_true(board._activation_ctx.ship_activation_state.is_at_step(
			ShipActivationState.Step.ATTACK))
	assert_eq(GameManager.get_activating_ship(), vsd)
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_STEP)

	board._panel_mgr.activation_modal._on_attack_pressed()

	assert_eq(_command_count(
			submitter.accepted_commands, "publish_attack_flow"), 1,
			"The pre-Begin flow publication must be accepted.")
	assert_true(state.current_attack_state.is_inactive())
	var primary: AttackSimPanel = selector.get_panel()
	assert_not_null(primary)
	var primary_interactive: bool = executor.is_in_exec_mode() \
			and executor.is_selecting() and primary.visible
	var mirror_interactive: bool = mirror.is_open() \
			and mirror._defense_signal_connected
	assert_eq(int(primary_interactive) + int(mirror_interactive), 1)
	assert_true(primary_interactive,
			"The activation owner must retain the sole pre-Begin presentation.")
	assert_false(mirror.is_open(),
			"The pre-Begin mirror must remain passive or closed.")

	var attacker_zone: int = _select_first_legal_attacker_zone(
			selector, vsd_token)
	assert_gte(attacker_zone, 0)
	assert_true(selector.is_target_selecting())
	assert_true(_select_first_legal_ship_target(board, selector, vsd_token),
			"The production selector must find and commit a legal target.")

	assert_eq(_command_count(
			submitter.submitted_commands, "begin_attack"), 0,
			"Target selection must remain preview-only until declaration Confirm.")
	assert_true(state.current_attack_state.is_inactive())
	assert_true(selector.has_declaration_candidate())
	assert_true(primary._confirm_button.visible)

	primary.declaration_confirm_pressed.emit()

	assert_eq(_command_count(
			submitter.submitted_commands, "begin_attack"), 1)
	assert_true(state.current_attack_state.active)
	assert_eq(state.current_attack_state.attacker_player, 1)
	assert_true(executor.is_in_exec_mode())
	assert_false(mirror.is_open())
	assert_true(submitter.peer_player_rejections.is_empty(),
			"No wrong-peer command may originate from player 1.")
	assert_true(submitter.processor_rejections.is_empty(),
			"No command may fail applicability or player validation.")
	for command: GameCommand in submitter.submitted_commands:
		assert_eq(command.player_index, 1,
				"Every command from this authenticated peer must be player 1.")


func test_defender_peer_has_only_interactive_mirror_in_real_board() -> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_DEFENSE, {
		"attack_id": "attack:15",
		"dice_results": [_hit_die()],
		"defense_stage": CurrentAttackState.DEFENSE_PENDING,
	})
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 0
	var submitter := AuthenticatedRecordingSubmitter.new()
	GameManager.set_command_submitter(submitter)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 16))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var executor: AttackExecutor = board._attack_executor
	var primary: AttackSimPanel = board._target_selector.get_panel()
	var mirror: AttackPanelMirror = board._panel_mgr.attack_panel_mirror
	assert_true(executor.is_in_exec_mode())
	assert_true(primary.visible)
	assert_true(primary.skip_attack_pressed.is_connected(
			Callable(executor, "_on_attack_skip")),
			"The fixture must begin with a live primary attacker callback.")

	NetworkManager._local_player_index = 1
	var router: ModalRouter = board._command_router_adapter.get_node(
			"ModalRouter") as ModalRouter
	router.route_command_result(null, {})
	await get_tree().process_frame

	var mirror_interactive: bool = mirror.is_open() \
			and mirror._defense_signal_connected
	var primary_interactive: bool = executor.is_in_exec_mode() \
			and primary.visible
	assert_eq(int(primary_interactive) + int(mirror_interactive), 1)
	assert_true(mirror_interactive,
			"The authenticated defender must own the interactive mirror.")
	assert_false(executor.is_in_exec_mode())
	assert_false(primary.visible)
	assert_false(primary.skip_attack_pressed.is_connected(
			Callable(executor, "_on_attack_skip")))
	assert_false(primary.confirm_pressed.is_connected(
			Callable(executor, "_on_attack_confirm")))
	assert_false(primary.declaration_confirm_pressed.is_connected(
			Callable(executor, "_on_declaration_confirm")))
	assert_false(primary.accuracy_confirmed.is_connected(
			Callable(executor, "_on_attack_accuracy_confirmed")))

	primary.skip_attack_pressed.emit()
	primary.confirm_pressed.emit()
	primary.declaration_confirm_pressed.emit()
	primary.accuracy_confirmed.emit()
	EventBus.network_dice_result.emit({})
	assert_true(submitter.submitted_commands.is_empty(),
			"Inactive primary callbacks must submit no attacker command.")
	mirror.get_panel().defense_tokens_done.emit()

	assert_eq(submitter.submitted_commands.size(), 1)
	var submitted: GameCommand = submitter.submitted_commands[0]
	assert_eq(submitted.command_type, "commit_defense")
	assert_eq(submitted.player_index, 1)
	assert_true(submitter.peer_player_rejections.is_empty(),
			"No command may fail authenticated peer/player ownership.")
	var attacker_owned_types: Array[String] = [
		"begin_attack", "skip_attack", "publish_attack_flow",
		"commit_accuracy", "roll_dice", "confirm_attack_dice",
		"resolve_damage", "complete_attack",
	]
	for command: GameCommand in submitter.submitted_commands:
		assert_false(attacker_owned_types.has(command.command_type),
				"Player 1 must originate no attacker-owned command.")


func test_live_authority_resume_drains_one_deterministic_terminal_chain() -> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_DEFENSE, {
		"attack_id": "attack:16",
		"dice_results": [_hit_die()],
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
	})
	GameManager.current_game_state = state
	assert_true(CommandProcessor.restore_next_sequence(17))
	var executor: AttackExecutor = _make_composition(state)
	var plan: Dictionary = executor.resume_current_attack(
			_find_ship_token, _find_squadron_token)

	assert_true(executor.resume_live_progression(plan))
	assert_true(state.current_attack_state.is_inactive())
	assert_eq(CommandProcessor.get_next_sequence(), 19)
	assert_eq(_history_types(), ["resolve_damage", "complete_attack"])
	assert_false(_history_types().has("begin_attack"))
	assert_false(executor.resume_live_progression(plan),
			"A repeated resume plan must not submit duplicate terminal commands.")
	assert_eq(CommandProcessor.get_next_sequence(), 19)
	assert_eq(_history_types(), ["resolve_damage", "complete_attack"])


func _state_at(stage: String, options: Dictionary) -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.rng = GameRng.new(8108)
	state.damage_deck = DamageDeck.new()
	state.damage_deck.initialize()
	var configured: Dictionary = options.duplicate(true)
	configured["stage"] = stage
	assert_not_null(CURRENT_ATTACK_FIXTURE.install(state, configured))
	return state


func _player_one_ship_attack_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.initiative_player = 1
	state.get_player_state(0).faction = Constants.Faction.REBEL_ALLIANCE
	state.get_player_state(1).faction = Constants.Faction.GALACTIC_EMPIRE
	var cr90 := ShipInstance.create_from_data(
			DECOY_SHIP_KEY, AssetLoader.load_ship_data(DECOY_SHIP_KEY), 2, 0)
	cr90.roster_entry_id = "state-a-defender"
	cr90.pos_x = 0.5
	cr90.pos_y = 0.58
	cr90.rotation_deg = 0.0
	state.get_player_state(0).ships.append(cr90)
	var vsd_key: String = "victory_ii_class_star_destroyer"
	var vsd := ShipInstance.create_from_data(
			vsd_key, AssetLoader.load_ship_data(vsd_key), 2, 1)
	vsd.roster_entry_id = "state-a-attacker"
	vsd.pos_x = 0.5
	vsd.pos_y = 0.42
	vsd.rotation_deg = 180.0
	var dials: Array[int] = []
	for _index: int in range(vsd.command_dial_stack.get_dials_needed()):
		dials.append(Constants.CommandType.NAVIGATE)
	assert_true(vsd.command_dial_stack.assign_dials(dials, 1))
	state.get_player_state(1).ships.append(vsd)
	state.damage_deck = DamageDeck.new()
	state.damage_deck.set_rng(state.rng)
	state.damage_deck.initialize()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			1, Constants.Visibility.ALL, {})
	return state


func _board_ship_token(board: GameBoard,
		ship: ShipInstance) -> ShipToken:
	for token: ShipToken in board.get_ship_tokens():
		if token.get_ship_instance() == ship:
			return token
	return null


func _select_first_legal_attacker_zone(
		selector: TargetSelector, attacker: ShipToken) -> int:
	var resolver: AttackTargetResolver = selector.get_target_resolver()
	for zone: int in [
			Constants.HullZone.FRONT,
			Constants.HullZone.LEFT,
			Constants.HullZone.RIGHT,
			Constants.HullZone.REAR,
	]:
		if not resolver.zone_has_targets(
				attacker, zone as Constants.HullZone):
			continue
		selector._select_attacker_ship_zone(attacker, zone)
		if selector.is_target_selecting():
			return zone
	return -1


func _select_first_legal_ship_target(
		board: GameBoard,
		selector: TargetSelector,
		attacker: ShipToken) -> bool:
	for target: ShipToken in board.get_ship_tokens():
		if target == attacker or target.get_faction() == attacker.get_faction():
			continue
		for zone: int in [
				Constants.HullZone.FRONT,
				Constants.HullZone.LEFT,
				Constants.HullZone.RIGHT,
				Constants.HullZone.REAR,
		]:
			if selector._validate_target_ship_click(target, zone) != "":
				continue
			selector._try_select_target_ship_zone(target, zone)
			return true
	return false


func _command_count(commands: Array[GameCommand],
		command_type: String) -> int:
	var count: int = 0
	for command: GameCommand in commands:
		if command.command_type == command_type:
			count += 1
	return count


func _ensure_cross_kind_decoys(state: GameState) -> void:
	for owner: int in range(Constants.PLAYER_COUNT):
		var player: PlayerState = state.get_player_state(owner)
		if player.ships.is_empty():
			player.ships.append(ShipInstance.create_from_data(
					DECOY_SHIP_KEY,
					AssetLoader.load_ship_data(DECOY_SHIP_KEY), 2, owner))
		if player.squadrons.is_empty():
			player.squadrons.append(SquadronInstance.create_from_data(
					DECOY_SQUADRON_KEY,
					AssetLoader.load_squadron_data(DECOY_SQUADRON_KEY), owner))


func _make_composition(state: GameState) -> AttackExecutor:
	var container: Node2D = Node2D.new()
	add_child_autofree(container)
	for player_index: int in range(Constants.PLAYER_COUNT):
		var player_state: PlayerState = state.get_player_state(player_index)
		for ship: ShipInstance in player_state.ships:
			var ship_scene: PackedScene = preload(
					"res://src/scenes/tokens/ship_token.tscn")
			var ship_token: ShipToken = ship_scene.instantiate() as ShipToken
			container.add_child(ship_token)
			ship_token.bind_instance(ship)
			_ship_tokens.append(ship_token)
		for squadron: SquadronInstance in player_state.squadrons:
			var squadron_scene: PackedScene = preload(
					"res://src/scenes/tokens/squadron_token.tscn")
			var squadron_token: SquadronToken = \
					squadron_scene.instantiate() as SquadronToken
			container.add_child(squadron_token)
			squadron_token.bind_instance(squadron)
			_squadron_tokens.append(squadron_token)
	var selector := TargetSelector.new()
	add_child_autofree(selector)
	selector.initialize(
			_get_ship_tokens, _get_squadron_tokens,
			container, null, AttackState.new(), AttackDiceResolver.new())
	var executor := AttackExecutor.new()
	add_child_autofree(executor)
	executor.initialize(selector, null)
	return executor


func _clear_composition_tokens() -> void:
	_ship_tokens.clear()
	_squadron_tokens.clear()


func _get_ship_tokens() -> Array[ShipToken]:
	return _ship_tokens


func _get_squadron_tokens() -> Array[SquadronToken]:
	return _squadron_tokens


func _find_ship_token(ship: ShipInstance) -> ShipToken:
	for token: ShipToken in _ship_tokens:
		if token.get_ship_instance() == ship:
			return token
	return null


func _find_squadron_token(squadron: SquadronInstance) -> SquadronToken:
	for token: SquadronToken in _squadron_tokens:
		if token.get_squadron_instance() == squadron:
			return token
	return null


func _token_index(ship: ShipInstance, token_type: int) -> int:
	for index: int in range(ship.defense_tokens.size()):
		if int(ship.defense_tokens[index].get("type", -1)) == token_type:
			return index
	return -1


func _history_types() -> Array[String]:
	var result: Array[String] = []
	for command: Dictionary in CommandProcessor.serialize_history():
		result.append(str(command.get("type", "")))
	return result


func _hit_die() -> Dictionary:
	return {
		"color": int(Constants.DiceColor.RED),
		"face": int(Constants.DiceFace.HIT),
	}


func _accuracy_die() -> Dictionary:
	return {
		"color": int(Constants.DiceColor.BLUE),
		"face": int(Constants.DiceFace.ACCURACY),
	}
