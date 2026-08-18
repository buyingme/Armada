## Production-composition evidence for canonical active-attack resume.
extends GutTest


const CURRENT_ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")
const SAVE_MANAGER_SCRIPT: GDScript = preload(
		"res://src/autoload/save_game_manager.gd")
const TIMING_WINDOW_ORCHESTRATOR: GDScript = preload(
		"res://src/core/timing_windows/timing_window_orchestrator.gd")
const CF_RULE: GDScript = preload(
		"res://src/core/effects/rules/concentrate_fire_token.gd")
const CF_USE: GDScript = preload(
		"res://src/core/commands/use_concentrate_fire_token_reroll_command.gd")
const CF_DECLINE: GDScript = preload(
		"res://src/core/commands/decline_concentrate_fire_token_reroll_command.gd")
const H9_RULE: GDScript = preload(
		"res://src/core/effects/rules/upgrades/turbolasers/h9_turbolasers.gd")
const H9_USE: GDScript = preload(
		"res://src/core/commands/use_h9_command.gd")
const H9_DECLINE: GDScript = preload(
		"res://src/core/commands/decline_h9_command.gd")
const TEST_SAVE: String = "_gut_slice_8a_production_resume"
const GAME_BOARD_SCENE: PackedScene = preload(
		"res://src/scenes/game_board/game_board.tscn")
const GAME_BOARD_PATH: String = "res://src/scenes/game_board/game_board.tscn"
const DECOY_SHIP_KEY: String = "cr90_corvette_a"
const DECOY_SQUADRON_KEY: String = "x_wing_squadron"

var _saved_state: GameState = null
var _saved_registry: Dictionary = {}
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


class AwaitingRecordingSubmitter:
	extends CommandSubmitter

	var submitted_commands: Array[GameCommand] = []


	func submit(command: GameCommand) -> Dictionary:
		submitted_commands.append(command)
		return {"awaiting_remote": true}


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


class NetworkStreamExecutingSubmitter:
	extends CommandSubmitter

	var authenticated_player: int = 0
	var accepted_stream: Array[Dictionary] = []
	var peer_player_rejections: Array[GameCommand] = []
	var processor_rejections: Array[GameCommand] = []
	var _submission_depth: int = 0


	func submit(command: GameCommand) -> Dictionary:
		if command.player_index != authenticated_player:
			peer_player_rejections.append(command)
			return {}
		_submission_depth += 1
		var result: Dictionary = CommandProcessor.submit_deferred_followups(
				command)
		if result.is_empty():
			processor_rejections.append(command)
		else:
			accepted_stream.append({
				"command": command.serialize(),
				"result": result.duplicate(true),
			})
		_submission_depth -= 1
		if _submission_depth == 0:
			CommandProcessor.drain_observer_followups(
					Callable(self, "_submit_followup"))
		return result


	func ordered_stream() -> Array[Dictionary]:
		var ordered: Array[Dictionary] = accepted_stream.duplicate(true)
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int((a.get("command") as Dictionary).get("sequence", -1)) \
					< int((b.get("command") as Dictionary).get("sequence", -1)))
		return ordered


	func _submit_followup(command: GameCommand) -> void:
		submit(command)


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
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
	RuleRegistry.clear()
	CF_RULE.register()
	H9_RULE.register()
	CF_USE.register()
	CF_DECLINE.register()
	H9_USE.register()
	H9_DECLINE.register()
	RollDiceCommand.register()
	ConfirmAttackDiceCommand.register()
	CommitAccuracyCommand.register()
	PublishAttackFlowCommand.register()
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
	RuleRegistry.clear()
	GameCommand._registry = _saved_registry
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
			AttackExecutor.RESUME_TIMING_WINDOW)
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
	var reconstruction: Dictionary = \
			TIMING_WINDOW_ORCHESTRATOR.reconcile(state)
	assert_true(bool(reconstruction.get(
			TIMING_WINDOW_ORCHESTRATOR.KEY_OK, false)), str(reconstruction))
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
	var panel: AttackSimPanel = board._target_selector.get_panel()
	assert_true(panel.is_awaiting_result_confirmation(),
			"Canonical completion should leave the resolved result visible.")
	assert_eq(CommandProcessor.get_next_sequence(), 35)

	panel._on_confirm_pressed()
	await get_tree().process_frame
	assert_eq(_history_types(), ["resolve_damage", "complete_attack",
			"advance_activation_step"])
	assert_eq(CommandProcessor.get_next_sequence(), 36)
	await get_tree().process_frame
	assert_eq(_history_types(), ["resolve_damage", "complete_attack",
			"advance_activation_step"],
			"Deferred production resume must remain single-shot.")
	assert_eq(_command_count(CommandProcessor.get_history(), "complete_attack"),
			1, "Acknowledge Result must not repeat canonical attack completion.")


func test_live_ship_completion_presents_result_without_transient_submit_flag() \
		-> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_DEFENSE, {
		"attack_id": "attack:37",
		"dice_results": [_hit_die()],
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
	})
	GameManager.current_game_state = state
	GameManager.is_game_active = true
	var executor: AttackExecutor = _make_composition(state)
	var panel: AttackSimPanel = \
			executor._target_selector.ensure_panel_for_projection()
	executor._connect_attack_panel_signals()
	panel.show_initial_attack_exec("Victory II")
	panel.show_target_selected(
			"Victory II", "FRONT", "CR90", "FRONT", "Clear",
			Constants.RANGE_BAND_CLOSE)
	panel.show_dice_results([_hit_die()])
	panel.show_damage_info("FRONT: 2 shield, 1 card(s) | Hull 3/4")
	var displayed_result: String = panel.get_body_text()
	var canonical_before: Dictionary = CurrentAttackState.inactive().serialize()
	assert_true(state.set_current_attack_state(CurrentAttackState.inactive()))
	executor._state.exec_mode = true
	executor._applied_damage_attack_id = "attack:37"
	executor._pending_finalize_after_completion = false
	var history_before: Array[String] = _history_types()

	executor.apply_complete_attack_result({
		"attack_id": "attack:37",
		"completed": true,
	})

	assert_true(panel.is_awaiting_result_confirmation(),
			"An accepted live ship completion must not depend on a transient flag.")
	assert_eq(panel._confirm_button.text, "Acknowledge Result")
	assert_eq(panel.get_body_text(), displayed_result)
	assert_true(panel._dice_container.visible)
	assert_true(panel._damage_info_container.visible)
	assert_string_contains(panel._damage_info_label.text, "2 shield")
	assert_eq(state.current_attack_state.serialize(), canonical_before)
	assert_eq(_history_types(), history_before,
			"Presenting the result must submit no semantic command.")

	panel._on_confirm_pressed()

	assert_eq(state.current_attack_state.serialize(), canonical_before)
	assert_eq(_command_count(CommandProcessor.get_history(), "complete_attack"),
			0, "Acknowledgement must not duplicate canonical attack completion.")


func test_real_game_board_anti_squadron_result_waits_for_acknowledgement() -> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_DEFENSE, {
		"attack_id": "attack:36",
		"dice_results": [_hit_die()],
		"defender_kind": CurrentAttackState.KIND_SQUADRON,
		"defender_zone": -1,
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
	})
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 37))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)

	await get_tree().process_frame
	assert_true(state.current_attack_state.is_inactive())
	var panel: AttackSimPanel = board._target_selector.get_panel()
	assert_true(panel.is_awaiting_result_confirmation(),
			"Anti-squadron damage must remain visible after canonical completion.")
	assert_eq(_command_count(CommandProcessor.get_history(), "complete_attack"), 1)

	panel._on_confirm_pressed()
	await get_tree().process_frame
	assert_false(panel.is_awaiting_result_confirmation())
	assert_eq(_command_count(CommandProcessor.get_history(), "complete_attack"),
			1, "Anti-squadron acknowledgement must be presentation-only.")


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
			restored, "twi-002-production",
			metadata.next_command_sequence))
	assert_eq(CommandProcessor.get_next_sequence(), 13)
	var executor: AttackExecutor = _make_composition(restored)

	var plan: Dictionary = executor.resume_current_attack(
			_find_ship_token, _find_squadron_token)

	assert_true(bool(plan.get(AttackExecutor.RESUME_KEY_OK, false)))
	assert_eq(plan.get(AttackExecutor.RESUME_KEY_TRANSITION),
			AttackExecutor.RESUME_TIMING_WINDOW)
	assert_eq(CommandProcessor.get_next_sequence(), 13)
	assert_eq(CommandProcessor.get_command_count(), 0)
	assert_false(restored.interaction_flow.payload.has("fictional"))
	assert_eq(restored.interaction_flow.payload.get("attack_id"), "attack:12")
	manager.delete_save(TEST_SAVE)
	manager.free()


func test_save_load_reconstructs_inactive_step_six_continuation() -> void:
	var source: GameState = _inactive_ship_continuation_state(true)
	GameManager.current_game_state = source
	assert_true(CommandProcessor.restore_next_sequence(41))
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	assert_true(manager.save_game(source, TEST_SAVE))
	var loaded: Dictionary = manager.load_game(TEST_SAVE)
	assert_true(bool(loaded.get("ok", false)))
	var restored: GameState = loaded.get("state") as GameState
	assert_not_null(restored)
	assert_true(GameManager.start_new_game_from_state(
			restored, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 41))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var ship: ShipInstance = restored.get_ship(1, 0)

	assert_true(restored.current_attack_state.is_inactive())
	assert_true(ship.attack_step_active)
	assert_eq(ship.committed_attack_count, 1)
	assert_eq(ship.anti_squadron_attack_zone, Constants.HullZone.FRONT)
	assert_eq(GameManager.get_activating_ship(), ship)
	assert_true(board._activation_ctx.is_active())
	assert_true(board._activation_ctx.ship_activation_state.is_at_step(
			ShipActivationState.Step.ATTACK))
	assert_true(board._attack_executor.is_in_exec_mode())
	assert_true(board._attack_executor.is_target_selecting())
	assert_eq(board._attack_executor._state.attacker_zone,
			Constants.HullZone.FRONT)
	assert_eq(board._attack_executor._state.attacked_squads.size(), 1)
	assert_eq(restored.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_DECLARE)
	assert_eq(CommandProcessor.get_next_sequence(), 41)
	assert_true(_history_types().is_empty())
	manager.delete_save(TEST_SAVE)
	manager.free()


func test_save_load_reconstructs_inactive_second_normal_attack() -> void:
	var source: GameState = _inactive_ship_continuation_state(false)
	GameManager.current_game_state = source
	assert_true(CommandProcessor.restore_next_sequence(43))
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	assert_true(manager.save_game(source, TEST_SAVE))
	var loaded: Dictionary = manager.load_game(TEST_SAVE)
	assert_true(bool(loaded.get("ok", false)))
	var restored: GameState = loaded.get("state") as GameState
	assert_not_null(restored)
	assert_true(GameManager.start_new_game_from_state(
			restored, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 43))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var ship: ShipInstance = restored.get_ship(1, 0)

	assert_true(restored.current_attack_state.is_inactive())
	assert_true(ship.attack_step_active)
	assert_eq(ship.committed_attack_count, 1)
	assert_eq(ship.anti_squadron_attack_zone, -1)
	assert_eq(GameManager.get_activating_ship(), ship)
	assert_true(board._activation_ctx.ship_activation_state.is_at_step(
			ShipActivationState.Step.ATTACK))
	assert_true(board._attack_executor.is_in_exec_mode())
	assert_true(board._attack_executor.is_selecting())
	assert_false(board._attack_executor.is_target_selecting())
	assert_eq(board._attack_executor._state.fired_zones,
			[Constants.HullZone.FRONT])
	assert_eq(board._attack_executor._state.current_attack, 1)
	assert_eq(restored.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_DECLARE)
	assert_eq(CommandProcessor.get_next_sequence(), 43)
	assert_true(_history_types().is_empty())
	manager.delete_save(TEST_SAVE)
	manager.free()


func test_production_save_load_reconstructs_commanded_post_skip_projection() \
		-> void:
	var source: GameState = _command_squadron_projection_state(true)
	GameManager.current_game_state = source
	assert_true(CommandProcessor.restore_next_sequence(49))
	var manager: Node = SAVE_MANAGER_SCRIPT.new()
	assert_true(manager.save_game(source, TEST_SAVE))
	var loaded: Dictionary = manager.load_game(TEST_SAVE)
	assert_true(bool(loaded.get("ok", false)))
	var restored: GameState = loaded.get("state") as GameState
	var metadata: SaveGameMetadata = loaded.get("meta") as SaveGameMetadata
	assert_true(GameManager.start_new_game_from_state(
			restored, LearningScenarioSetup.DEFAULT_SCENARIO_ID,
			metadata.next_command_sequence))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var modal: SquadronActivationModal = \
			board._squadron_phase_controller.get_modal()

	assert_eq(metadata.save_format_version, SaveGameMetadata.CURRENT_VERSION)
	assert_true(modal.is_command_mode())
	assert_eq(modal.get_state(), SquadronActivationModal.State.ACTION_CHOICE)
	assert_eq(modal.get_selected_token().get_squadron_instance(),
			restored.get_squadron(0, 0))
	assert_eq(restored.get_squadron(0, 0).attack_action_disposition,
			SquadronInstance.ATTACK_ACTION_DECLINED)
	assert_true(_history_types().is_empty())
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
			client_state, "twi-002-production", 15))
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


func test_reconnect_reconstructs_inactive_step_six_continuation() -> void:
	var server_state: GameState = _inactive_ship_continuation_state(true)
	var filtered: Dictionary = StateFilter.filter_for_player(
			server_state.serialize(), 1)
	var client_state: GameState = GameState.deserialize(filtered)
	assert_not_null(client_state)
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	assert_true(GameManager.start_new_game_from_state(
			client_state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 45))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var ship: ShipInstance = client_state.get_ship(1, 0)

	assert_true(client_state.current_attack_state.is_inactive())
	assert_eq(GameManager.get_activating_ship(), ship)
	assert_true(board._attack_executor.is_in_exec_mode())
	assert_true(board._attack_executor.is_target_selecting())
	assert_eq(board._attack_executor._state.attacker_zone,
			Constants.HullZone.FRONT)
	assert_eq(board._attack_executor._state.attacked_squads.size(), 1)
	assert_eq(client_state.interaction_flow.controller_player, 1)
	assert_eq(CommandProcessor.get_next_sequence(), 45)
	assert_true(_history_types().is_empty())


func test_reconnect_reconstructs_inactive_second_normal_attack() -> void:
	var server_state: GameState = _inactive_ship_continuation_state(false)
	var filtered: Dictionary = StateFilter.filter_for_player(
			server_state.serialize(), 1)
	var client_state: GameState = GameState.deserialize(filtered)
	assert_not_null(client_state)
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	assert_true(GameManager.start_new_game_from_state(
			client_state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 47))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var ship: ShipInstance = client_state.get_ship(1, 0)

	assert_true(client_state.current_attack_state.is_inactive())
	assert_eq(GameManager.get_activating_ship(), ship)
	assert_true(board._attack_executor.is_in_exec_mode())
	assert_true(board._attack_executor.is_selecting())
	assert_false(board._attack_executor.is_target_selecting())
	assert_eq(board._attack_executor._state.fired_zones,
			[Constants.HullZone.FRONT])
	assert_eq(board._attack_executor._state.current_attack, 1)
	assert_eq(client_state.interaction_flow.controller_player, 1)
	assert_eq(CommandProcessor.get_next_sequence(), 47)
	assert_true(_history_types().is_empty())


func test_filtered_reconnect_reconstructs_phase_pre_begin_projection() -> void:
	var server_state: GameState = _phase_squadron_projection_state(false)
	var filtered: Dictionary = StateFilter.filter_for_player(
			server_state.serialize(), 1)
	var client_state: GameState = GameState.deserialize(filtered)
	assert_not_null(client_state)
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	assert_true(GameManager.start_new_game_from_state(
			client_state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 50))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var modal: SquadronActivationModal = \
			board._squadron_phase_controller.get_modal()

	assert_eq(modal.get_state(), SquadronActivationModal.State.ACTION_CHOICE)
	assert_eq(modal.get_selected_token().get_squadron_instance(),
			client_state.get_squadron(0, 0))
	assert_false(modal._is_interactable,
			"A reconnecting non-controller gets projection, not authority.")
	assert_eq(CommandProcessor.get_next_sequence(), 50)
	assert_true(_history_types().is_empty())


func test_filtered_reconnect_reconstructs_commanded_post_skip_projection() \
		-> void:
	var server_state: GameState = _command_squadron_projection_state(true)
	var filtered: Dictionary = StateFilter.filter_for_player(
			server_state.serialize(), 1)
	var client_state: GameState = GameState.deserialize(filtered)
	assert_not_null(client_state)
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	assert_true(GameManager.start_new_game_from_state(
			client_state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 51))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var modal: SquadronActivationModal = \
			board._squadron_phase_controller.get_modal()

	assert_true(modal.is_command_mode())
	assert_eq(modal.get_state(), SquadronActivationModal.State.ACTION_CHOICE)
	assert_eq(modal.get_selected_token().get_squadron_instance(),
			client_state.get_squadron(0, 0))
	assert_true(modal._has_attacked)
	assert_false(modal._is_interactable,
			"A reconnecting non-controller gets projection, not authority.")
	assert_eq(CommandProcessor.get_next_sequence(), 51)
	assert_true(_history_types().is_empty())


func test_scene_recreation_restores_ship_pre_begin_projection_from_owner() -> void:
	var state: GameState = _ship_declaration_projection_state(false)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 51))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var ship: ShipInstance = state.get_ship(1, 0)

	assert_eq(GameManager.get_activating_ship(), ship)
	assert_true(board._activation_ctx.ship_activation_state.is_at_step(
			ShipActivationState.Step.ATTACK))
	assert_true(board._ship_activation_controller.is_activation_modal_open())
	assert_true(board._panel_mgr.activation_modal._is_interactable,
			"The canonical ship owner must remain interactive despite stale flow.")
	assert_true(state.current_attack_state.is_inactive())
	assert_true(_history_types().is_empty(),
			"Reconstruction must not synthesize a semantic command.")


func test_scene_recreation_restores_ship_post_skip_maneuver_projection() -> void:
	var state: GameState = _ship_declaration_projection_state(true)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 53))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var ship: ShipInstance = state.get_ship(1, 0)

	assert_false(ship.attack_step_active)
	assert_eq(ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_OPEN)
	assert_true(board._activation_ctx.ship_activation_state.is_at_step(
			ShipActivationState.Step.MANEUVER))
	assert_true(board._ship_activation_controller.is_activation_modal_open())
	assert_true(board._panel_mgr.activation_modal._is_interactable,
			"The canonical ship owner must control post-Skip Maneuver.")
	assert_true(_history_types().is_empty())


func test_live_zero_attack_skip_projects_canonical_maneuver_boundary() -> void:
	var state: GameState = _ship_declaration_projection_state(false)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 53))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var ship: ShipInstance = state.get_ship(1, 0)
	var activation_modal: ActivationModal = board._panel_mgr.activation_modal

	activation_modal._on_attack_pressed()
	var panel: AttackSimPanel = board._target_selector.get_panel()
	assert_not_null(panel)
	assert_true(panel._skip_attack_button.visible,
			"Voluntary Skip remains available before BeginAttack commitment.")
	assert_false(board._ship_activation_controller.is_activation_modal_open())

	panel.skip_attack_pressed.emit()

	assert_true(state.current_attack_state.is_inactive())
	assert_false(ship.attack_step_active)
	assert_eq(ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_OPEN)
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.MANEUVER_STEP)
	assert_true(board._activation_ctx.ship_activation_state.is_at_step(
			ShipActivationState.Step.MANEUVER))
	assert_true(board._ship_activation_controller.is_activation_modal_open(),
			"Accepted canonical Skip must project usable Maneuver interaction.")
	assert_true(activation_modal._is_interactable)
	assert_false(GameManager.submit_execute_maneuver(
			ship, 0, [], ship.pos_x, ship.pos_y,
			ship.rotation_deg).is_empty(),
			"The projected interaction must use the canonical OPEN opportunity.")
	assert_eq(ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_CONSUMED)
	assert_false(GameManager.submit_advance_activation_step(
			ship, "activation_done").is_empty())
	EventBus.activation_ended.emit()
	assert_true(ship.activated_this_round,
			"Maneuver and End Activation must complete normally after Skip.")
	assert_eq(_history_types().count("execute_maneuver"), 1)
	assert_eq(_history_types().count("end_activation"), 1)


func test_network_owner_waits_then_projects_mirrored_skip_to_maneuver() -> void:
	var state: GameState = _ship_declaration_projection_state(false)
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	var submitter := AwaitingRecordingSubmitter.new()
	GameManager.set_command_submitter(submitter)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 57))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var ship: ShipInstance = state.get_ship(1, 0)
	var activation_modal: ActivationModal = board._panel_mgr.activation_modal

	activation_modal._on_attack_pressed()
	var panel: AttackSimPanel = board._target_selector.get_panel()
	panel.skip_attack_pressed.emit()
	assert_eq(submitter.submitted_commands.size(), 1)
	var mirrored: GameCommand = submitter.submitted_commands[0]
	assert_eq(mirrored.command_type, "skip_attack")
	assert_eq(mirrored.payload.get("reason"), "voluntary")
	assert_true(ship.attack_step_active,
			"A network client must wait for the authoritative result.")
	assert_false(board._ship_activation_controller.is_activation_modal_open())

	mirrored.sequence = CommandProcessor.get_next_sequence()
	assert_false(CommandProcessor.submit_mirror(mirrored).is_empty())

	assert_false(ship.attack_step_active)
	assert_eq(ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_OPEN)
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.MANEUVER_STEP)
	assert_true(board._activation_ctx.ship_activation_state.is_at_step(
			ShipActivationState.Step.MANEUVER))
	assert_true(board._ship_activation_controller.is_activation_modal_open())
	assert_true(activation_modal._is_interactable,
			"The authenticated canonical ship owner controls Maneuver.")


func test_live_remaining_attack_skip_projects_same_maneuver_boundary() -> void:
	var state: GameState = _inactive_ship_continuation_state(false)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 55))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var ship: ShipInstance = state.get_ship(1, 0)
	var panel: AttackSimPanel = board._target_selector.get_panel()
	assert_not_null(panel)
	assert_true(panel._skip_attack_button.visible,
			"The remaining uncommitted attack opportunity may be declined.")
	assert_true(panel.skip_attack_pressed.is_connected(
			Callable(board._attack_executor, "_on_attack_skip")),
			"Reconstructed continuation must wire the usable Skip intent.")
	var used_zone_candidate: Dictionary = {}
	for candidate: Dictionary in \
			TargetingListBuilder.authoritative_ship_target_entries(state, 1, 0):
		if int(candidate.get("attacker_zone", -1)) \
				== int(Constants.HullZone.FRONT):
			used_zone_candidate = candidate
			break
	assert_false(used_zone_candidate.is_empty(),
			"The fixture must expose a forged candidate from the used hull zone.")
	var second_begin: Dictionary = CommandProcessor.submit(
			BeginAttackCommand.new(1, {
				"attacker_player": 1,
				"attacker_kind": CurrentAttackState.KIND_SHIP,
				"attacker_index": 0,
				"attacker_zone": int(used_zone_candidate.get(
						"attacker_zone", -1)),
				"defender_player": int(used_zone_candidate.get(
						"target_owner", -1)),
				"defender_kind": str(used_zone_candidate.get(
						"target_kind", "")),
				"defender_index": int(used_zone_candidate.get(
						"target_index", -1)),
				"defender_zone": int(used_zone_candidate.get(
						"target_zone", -1)),
				"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
				"range_band": str(used_zone_candidate.get("range_band", "")),
				"obstructed": bool(used_zone_candidate.get("obstructed", false)),
				"ship_activation_identity": ship.ship_activation_identity,
			}))
	assert_engine_error(1,
			"The rejected second Begin should diagnose the used hull zone.")
	assert_true(second_begin.is_empty())
	assert_true(state.current_attack_state.is_inactive())
	assert_true(ship.attack_step_active)
	assert_eq(ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_UNREACHED)

	panel.skip_attack_pressed.emit()

	assert_eq(ship.committed_attack_count, 1)
	assert_eq(ship.used_attack_hull_zones,
			[int(Constants.HullZone.FRONT)])
	assert_false(ship.attack_step_active)
	assert_eq(ship.maneuver_opportunity_disposition,
			ShipInstance.ACTIVATION_DISPOSITION_OPEN)
	assert_true(board._activation_ctx.ship_activation_state.is_at_step(
			ShipActivationState.Step.MANEUVER))
	assert_true(board._ship_activation_controller.is_activation_modal_open())


func test_game_manager_does_not_rewrite_post_commit_voluntary_skip() -> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_PRE_ROLL, {
		"attack_id": "attack:57",
		"attacker_player": 0,
		"dice_pool": {"BLUE": 2},
	})
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 58))
	var attack_before: Dictionary = state.current_attack_state.serialize()
	var history_before: int = CommandProcessor.get_command_count()

	var result: Dictionary = GameManager.submit_skip_attack(0, "voluntary")
	assert_engine_error(1,
			"Authoritative rejection should be reported without state mutation.")

	assert_true(result.is_empty(),
			"A forged post-commit voluntary Skip must fail authoritatively.")
	assert_eq(state.current_attack_state.serialize(), attack_before,
			"Rejection must preserve canonical attack and dice state.")
	assert_eq(CommandProcessor.get_command_count(), history_before,
			"Rejected commands must not enter replay history.")


func test_post_commit_resume_does_not_project_voluntary_skip() -> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_PRE_ROLL, {
		"attack_id": "attack:59",
		"attacker_player": 0,
		"dice_pool": {"BLUE": 2},
	})
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 60))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var panel: AttackSimPanel = board._target_selector.get_panel()

	assert_true(state.current_attack_state.active)
	assert_not_null(panel)
	assert_false(panel._skip_attack_button.visible,
			"Voluntary Skip must not be projected after BeginAttack commitment.")


func test_ship_reconstruction_gives_non_owner_read_only_mirror_despite_stale_flow() \
		-> void:
	for post_skip: bool in [false, true]:
		var state: GameState = _ship_declaration_projection_state(post_skip)
		# The fixture's stale flow names player 0, while canonical ship owner is 1.
		PlayMode.set_mode(PlayMode.Mode.NETWORK)
		NetworkManager.role = NetworkManager.Role.CLIENT
		NetworkManager._local_player_index = 0
		assert_true(GameManager.start_new_game_from_state(
				state, LearningScenarioSetup.DEFAULT_SCENARIO_ID,
				70 + int(post_skip)))
		var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
		add_child_autofree(board)

		assert_true(board._ship_activation_controller.is_activation_modal_open())
		assert_false(board._panel_mgr.activation_modal._is_interactable,
				"A stale flow controller must not make the non-owner interactive.")
		assert_true(_history_types().is_empty())
		board.queue_free()
		await get_tree().process_frame


func test_scene_recreation_restores_phase_squadron_pre_begin_projection() -> void:
	var state: GameState = _phase_squadron_projection_state(false)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 55))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	var modal: SquadronActivationModal = \
			board._squadron_phase_controller.get_modal()

	assert_eq(GameManager.get_activating_squadron(), squadron)
	assert_eq(modal.get_selected_token().get_squadron_instance(), squadron)
	assert_eq(modal.get_state(), SquadronActivationModal.State.ACTION_CHOICE)
	assert_true(modal.visible)
	assert_true(_history_types().is_empty())


func test_scene_recreation_restores_phase_squadron_active_begin_continuation() -> void:
	var state: GameState = _state_at(CurrentAttackState.STAGE_DEFENSE, {
		"attack_id": "attack:56",
		"attacker_kind": CurrentAttackState.KIND_SQUADRON,
		"dice_results": [_hit_die()],
	})
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 57))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var modal: SquadronActivationModal = \
			board._squadron_phase_controller.get_modal()

	assert_eq(modal.get_state(), SquadronActivationModal.State.ATTACKING)
	assert_false(modal.visible)
	assert_true(board._attack_executor.is_in_exec_mode())
	assert_true(_history_types().is_empty())


func test_scene_recreation_restores_phase_squadron_post_skip_projection() -> void:
	var state: GameState = _phase_squadron_projection_state(true)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 59))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	var modal: SquadronActivationModal = \
			board._squadron_phase_controller.get_modal()

	assert_eq(squadron.attack_action_disposition,
			SquadronInstance.ATTACK_ACTION_DECLINED)
	assert_eq(modal.get_selected_token().get_squadron_instance(), squadron)
	assert_eq(modal.get_state(), SquadronActivationModal.State.ACTION_CHOICE)
	assert_true(modal._has_attacked)
	assert_false(modal._has_moved)
	assert_true(_history_types().is_empty())


func test_scene_recreation_restores_commanded_squadron_pre_begin_projection() \
		-> void:
	var state: GameState = _command_squadron_projection_state(false)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 60))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	var modal: SquadronActivationModal = \
			board._squadron_phase_controller.get_modal()

	assert_true(modal.is_command_mode())
	assert_eq(modal.get_selected_token().get_squadron_instance(), squadron)
	assert_eq(modal.get_state(), SquadronActivationModal.State.ACTION_CHOICE)
	assert_eq(squadron.attack_action_disposition,
			SquadronInstance.ATTACK_ACTION_AVAILABLE)
	assert_true(_history_types().is_empty())


func test_scene_recreation_restores_commanded_squadron_active_begin_continuation() \
		-> void:
	var state: GameState = _command_squadron_active_begin_state()
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 61))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var modal: SquadronActivationModal = \
			board._squadron_phase_controller.get_modal()

	assert_true(state.current_attack_state.active)
	assert_true(modal.is_command_mode())
	assert_eq(modal.get_state(), SquadronActivationModal.State.ATTACKING)
	assert_false(modal.visible)
	assert_true(board._attack_executor.is_in_exec_mode())
	assert_true(_history_types().is_empty())


func test_scene_recreation_restores_commanded_squadron_post_skip_projection() -> void:
	var state: GameState = _command_squadron_projection_state(true)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 61))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var ship: ShipInstance = state.get_ship(0, 0)
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	var modal: SquadronActivationModal = \
			board._squadron_phase_controller.get_modal()

	assert_eq(GameManager.get_activating_ship(), ship)
	assert_true(board._activation_ctx.ship_activation_state.is_at_step(
			ShipActivationState.Step.SQUADRON))
	assert_true(modal.is_command_mode())
	assert_eq(modal.get_selected_token().get_squadron_instance(), squadron)
	assert_eq(modal.get_state(), SquadronActivationModal.State.ACTION_CHOICE)
	assert_true(modal._has_attacked)
	assert_false(modal._has_moved)
	assert_true(_history_types().is_empty())


func test_commanded_move_no_target_waits_for_skip_and_preserves_capacity() \
		-> void:
	var state: GameState = _command_squadron_projection_state(false)
	var ship: ShipInstance = state.get_ship(0, 0)
	ship.ship_data = ship.ship_data.duplicate(true) as ShipData
	ship.ship_data.squadron_value = 2
	var second := SquadronInstance.create_from_data(
			DECOY_SQUADRON_KEY,
			AssetLoader.load_squadron_data(DECOY_SQUADRON_KEY), 0)
	second.pos_x = 0.44
	second.pos_y = 0.51
	second.roster_entry_id = "projection-command-squadron-2"
	state.get_player_state(0).squadrons.append(second)
	var enemy_data: SquadronData = AssetLoader.load_squadron_data(
			"tie_fighter_squadron").duplicate(true) as SquadronData
	enemy_data.keywords.append({"name": "Heavy"})
	var enemy := SquadronInstance.create_from_data(
			"tie_fighter_squadron", enemy_data, 1)
	enemy.pos_x = 0.5
	enemy.pos_y = 0.46
	enemy.roster_entry_id = "projection-command-target"
	state.get_player_state(1).squadrons.append(enemy)
	assert_false(TargetingListBuilder.authoritative_squadron_target_entries(
			state, 0, 0).is_empty())
	assert_false(TargetingListBuilder.authoritative_squadron_target_entries(
			state, 0, 1).is_empty())
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 63))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var controller: SquadronPhaseController = board._squadron_phase_controller
	var modal: SquadronActivationModal = controller.get_modal()
	var first: SquadronInstance = state.get_squadron(0, 0)
	var first_token: SquadronToken = modal.get_selected_token()
	var observed: Dictionary = {}
	CommandProcessor.command_executed.connect(
			func(command: GameCommand, _result: Dictionary) -> void:
				if command.command_type != "move_squadron":
					return
				observed["complete_error"] = \
						CompleteSquadronActivationCommand.new(0, {
							"squadron_index": 0,
							"activation_id": first.activation_id,
							"activation_context": first.activation_context,
						}).validate(state)
				observed["dial_still_revealed"] = not ship.command_dial_stack \
						.get_revealed_dial().is_empty(),
			CONNECT_ONE_SHOT)

	modal._on_move_pressed()
	first_token.global_position += Vector2(-300.0, -100.0)
	controller._commit_squadron_placement(first_token)

	assert_eq(observed.get("complete_error", ""),
			"Squadron still has an available action.",
			"Move alone must not make CompleteSquadronActivation legal.")
	assert_true(bool(observed.get("dial_still_revealed", false)),
			"The command dial must remain until canonical command completion.")
	assert_true(first.move_action_committed)
	assert_true(TargetingListBuilder.authoritative_squadron_target_entries(
			state, 0, 0).is_empty(),
			"Post-movement target availability must be re-derived.")
	assert_eq(first.attack_action_disposition,
			SquadronInstance.ATTACK_ACTION_DECLINED)
	assert_true(first.activated_this_round)
	assert_eq(modal.get_state(),
			SquadronActivationModal.State.WAITING_FOR_SELECTION,
			"Accepted Skip should expose the remaining command capacity.")
	assert_eq(_history_types().count("skip_attack"), 1)
	assert_eq(_history_types().count(
			CompleteSquadronActivationCommand.TYPE), 0)
	assert_eq(_history_types().count("spend_dial"), 0)

	var second_token: SquadronToken = _board_squadron_token(board, second)
	assert_true(controller.try_handle_squadron_click(second_token),
			"A second commanded squadron remains selectable within capacity.")
	modal._on_move_pressed()
	second_token.global_position += Vector2(450.0, -100.0)
	controller._commit_squadron_placement(second_token)

	assert_true(second.move_action_committed)
	assert_eq(second.attack_action_disposition,
			SquadronInstance.ATTACK_ACTION_DECLINED)
	assert_true(second.activated_this_round)
	assert_eq(ship.squadron_command_activations_committed, 2)
	assert_eq(_history_types().count("skip_attack"), 2)
	assert_eq(_history_types().count(
			CompleteSquadronActivationCommand.TYPE), 0)
	assert_eq(_history_types().count("spend_dial"), 1,
			"Final command completion must spend the dial exactly once.")
	assert_true(ship.command_dial_stack.get_revealed_dial().is_empty())


func test_network_commanded_no_target_waits_for_mirrored_skip() -> void:
	var state: GameState = _command_squadron_projection_state(false)
	var ship: ShipInstance = state.get_ship(0, 0)
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	assert_true(squadron.commit_move_action(squadron.activation_id, false))
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 0
	var submitter := AwaitingRecordingSubmitter.new()
	GameManager.set_command_submitter(submitter)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 67))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var modal: SquadronActivationModal = \
			board._squadron_phase_controller.get_modal()
	modal._has_moved = false
	modal._has_targets = false
	modal._state = SquadronActivationModal.State.MOVING

	modal.notify_move_completed()

	assert_eq(submitter.submitted_commands.size(), 1)
	var mirrored_skip: GameCommand = submitter.submitted_commands[0]
	assert_eq(mirrored_skip.command_type, "skip_attack")
	assert_eq(mirrored_skip.payload.get("reason"), "no_targets")
	assert_true(modal._declaration_skip_pending)
	assert_eq(modal.get_state(), SquadronActivationModal.State.MOVING,
			"Network presentation must wait for authoritative Skip acceptance.")
	assert_eq(squadron.attack_action_disposition,
			SquadronInstance.ATTACK_ACTION_AVAILABLE)
	assert_false(ship.command_dial_stack.get_revealed_dial().is_empty())

	mirrored_skip.sequence = CommandProcessor.get_next_sequence()
	assert_false(CommandProcessor.submit_mirror(mirrored_skip).is_empty())
	assert_eq(squadron.attack_action_disposition,
			SquadronInstance.ATTACK_ACTION_DECLINED)
	assert_true(squadron.activated_this_round)
	assert_eq(submitter.submitted_commands.size(), 3,
			"Accepted final Skip should request one dial spend and one next step.")
	assert_eq(submitter.submitted_commands[1].command_type, "spend_dial")
	assert_eq(submitter.submitted_commands[2].command_type,
			"advance_activation_step")
	assert_false(ship.command_dial_stack.get_revealed_dial().is_empty(),
			"The dial remains until the server mirrors its spend command.")

	for index: int in range(1, submitter.submitted_commands.size()):
		var mirrored: GameCommand = submitter.submitted_commands[index]
		mirrored.sequence = CommandProcessor.get_next_sequence()
		assert_false(CommandProcessor.submit_mirror(mirrored).is_empty())
	assert_true(ship.command_dial_stack.get_revealed_dial().is_empty())
	assert_eq(_history_types().count("skip_attack"), 1)
	assert_eq(_history_types().count("spend_dial"), 1)
	assert_eq(_history_types().count(
			CompleteSquadronActivationCommand.TYPE), 0)


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
			submitter.accepted_commands, "publish_attack_flow"), 0,
			"Transient pre-Begin presentation must publish no semantic command.")
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
	assert_true(primary._skip_attack_button.visible,
			"Voluntary Skip remains projected before attack commitment.")

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
	assert_false(primary._confirm_button.visible,
			"Accepted BeginAttack must retire the declaration Confirm control.")
	assert_true(primary._roll_button.visible,
			"The committed pre-roll attack should expose its current Roll action.")
	assert_false(primary._skip_attack_button.visible,
			"BeginAttack commitment must retire voluntary Skip projection.")
	assert_false(mirror.is_open())
	assert_true(submitter.peer_player_rejections.is_empty(),
			"No wrong-peer command may originate from player 1.")
	assert_true(submitter.processor_rejections.is_empty(),
			"No command may fail applicability or player validation.")
	for command: GameCommand in submitter.submitted_commands:
		assert_eq(command.player_index, 1,
				"Every command from this authenticated peer must be player 1.")


func test_network_roll_mirror_completes_projection_handoff_once() -> void:
	var context: Dictionary = _network_roll_context()
	var state: GameState = context.get("state") as GameState
	var executor: AttackExecutor = context.get("executor") as AttackExecutor
	var panel: AttackSimPanel = context.get("panel") as AttackSimPanel
	var submitter: AuthenticatedRecordingSubmitter = \
			context.get("submitter") as AuthenticatedRecordingSubmitter

	assert_eq(state.current_attack_state.stage,
			CurrentAttackState.STAGE_ATTACK_MODIFY)
	assert_true(state.timing_window_state.active)
	assert_eq(executor._flow_fsm.current_step, AttackFlowFSM.Step.MODIFY,
			"The ordered mirror must complete Roll -> Modify after projection.")
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_MODIFY)
	assert_false(panel._roll_button.visible,
			"The completed presentation handoff must retire Roll Dice.")
	assert_eq(panel.timing_window_choice_count(), 2)
	assert_false(executor._state.dice_results.is_empty())
	var publish_count: int = _command_count(
			submitter.submitted_commands, "publish_attack_flow")
	assert_eq(publish_count, 2,
			"One derived handoff publishes its step and canonical dice payload.")

	EventBus.network_dice_result.emit({})

	assert_eq(executor._flow_fsm.current_step, AttackFlowFSM.Step.MODIFY)
	assert_eq(_command_count(
			submitter.submitted_commands, "publish_attack_flow"), publish_count,
			"A duplicate network result must not repeat the derived handoff.")


func test_hotseat_and_network_roll_reach_same_derived_interaction() -> void:
	var hotseat: Dictionary = _hotseat_roll_context()
	var hotseat_snapshot: Dictionary = _roll_interaction_snapshot(hotseat)
	var hotseat_board: GameBoard = hotseat.get("board") as GameBoard
	hotseat_board.queue_free()
	await get_tree().process_frame
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()

	var network: Dictionary = _network_roll_context()
	var network_snapshot: Dictionary = _roll_interaction_snapshot(network)

	assert_eq(network_snapshot, hotseat_snapshot,
			"Accepted RollDice must derive the same actionable next interaction.")


func test_zero_opportunity_network_roll_hands_defense_to_defender_client() \
		-> void:
	var state: GameState = _zero_opportunity_roll_state()
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = 0
	var host_submitter := NetworkStreamExecutingSubmitter.new()
	GameManager.set_command_submitter(host_submitter)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 0))
	var host_board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(host_board)
	var host_executor: AttackExecutor = host_board._attack_executor
	var host_panel: AttackSimPanel = host_board._target_selector.get_panel()
	assert_eq(host_executor._flow_fsm.current_step, AttackFlowFSM.Step.ROLL)
	assert_true(host_panel._roll_button.visible)
	# A connected client starts from the same deterministic setup/RNG state;
	# later command-result projection remains viewer-specific.
	var client_initial_data: Dictionary = state.serialize()

	host_panel._roll_button.pressed.emit()

	assert_eq(state.current_attack_state.stage,
			CurrentAttackState.STAGE_DEFENSE)
	assert_eq(state.current_attack_state.defense_stage,
			CurrentAttackState.DEFENSE_PENDING)
	assert_eq(state.current_attack_state.defender_player, 1)
	assert_eq(host_executor._flow_fsm.current_step,
			AttackFlowFSM.Step.DEFENSE_TOKENS,
			"The accepted roll must project every lifecycle step before Defense.")
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)
	assert_eq(state.interaction_flow.controller_player, 1,
			"The canonical defender must control the published Defense step.")
	assert_true(host_submitter.peer_player_rejections.is_empty())
	assert_true(host_submitter.processor_rejections.is_empty())
	var authoritative_stream: Array[Dictionary] = \
			host_submitter.ordered_stream()
	assert_true(_stream_has_type(authoritative_stream, "roll_dice"))
	assert_true(_stream_has_type(
			authoritative_stream, "confirm_attack_dice"))
	assert_true(_stream_has_type(authoritative_stream, "commit_accuracy"))

	host_board.queue_free()
	await get_tree().process_frame
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	var client_state: GameState = GameState.deserialize(client_initial_data)
	assert_not_null(client_state)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	var client_submitter := AuthenticatedRecordingSubmitter.new()
	client_submitter.authenticated_player = 1
	GameManager.set_command_submitter(client_submitter)
	assert_true(GameManager.start_new_game_from_state(
			client_state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 0))
	var client_board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(client_board)
	for entry: Dictionary in authoritative_stream:
		var command: GameCommand = GameCommand.deserialize(
				entry.get("command") as Dictionary)
		assert_not_null(command)
		assert_true(GameManager._apply_network_command_result(
				command, entry.get("result") as Dictionary))
	await get_tree().process_frame

	var mirror: AttackPanelMirror = client_board._panel_mgr.attack_panel_mirror
	assert_eq(client_state.current_attack_state.stage,
			CurrentAttackState.STAGE_DEFENSE)
	assert_eq(client_state.current_attack_state.defender_player, 1)
	assert_eq(client_state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)
	assert_eq(client_state.interaction_flow.controller_player, 1)
	assert_true(mirror.is_open(),
			"The defender client must receive the published attack handoff.")
	assert_true(mirror._defense_signal_connected,
			"Player 1 must receive the interactive defense-token controls.")
	assert_false(client_board._attack_executor.is_in_exec_mode(),
			"The defender mirror must not become the canonical attack owner.")
	assert_true(client_submitter.submitted_commands.is_empty(),
			"Mirroring the authoritative stream must synthesize no commands.")
	mirror.get_panel().defense_tokens_done.emit()
	assert_eq(client_submitter.submitted_commands.size(), 1)
	var defense_command: GameCommand = client_submitter.submitted_commands[0]
	assert_eq(defense_command.command_type, "commit_defense")
	assert_eq(defense_command.player_index, 1)
	assert_eq(defense_command.payload.get("attack_id"), "attack:0")
	assert_true(client_submitter.peer_player_rejections.is_empty())


func test_network_client_real_panel_constructs_h9_use() -> void:
	_assert_network_timing_intent(H9_RULE.CAPABILITY_ID, H9_USE.TYPE, false)


func test_network_client_real_panel_constructs_h9_decline() -> void:
	_assert_network_timing_intent(
			H9_RULE.CAPABILITY_ID, H9_DECLINE.TYPE, true)


func test_network_client_real_panel_constructs_concentrate_fire_use() -> void:
	_assert_network_timing_intent(CF_RULE.CAPABILITY_ID, CF_USE.TYPE, false)


func test_network_client_real_panel_constructs_concentrate_fire_decline() -> void:
	_assert_network_timing_intent(
			CF_RULE.CAPABILITY_ID, CF_DECLINE.TYPE, true)


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
	GameManager.set_command_submitter(LocalCommandSubmitter.new(
			state.principal_id_for_player(0)))
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


func _network_roll_context() -> Dictionary:
	var state: GameState = _roll_state()
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 0
	var submitter := AuthenticatedRecordingSubmitter.new()
	submitter.authenticated_player = 0
	GameManager.set_command_submitter(submitter)
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 0))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var executor: AttackExecutor = board._attack_executor
	var panel: AttackSimPanel = board._target_selector.get_panel()
	assert_true(executor.is_in_exec_mode())
	assert_eq(executor._flow_fsm.current_step, AttackFlowFSM.Step.ROLL)
	assert_true(panel._roll_button.visible)
	assert_false(panel._skip_attack_button.visible,
			"Network projection must also retire voluntary Skip after Begin.")
	assert_true(executor._state.dice_results.is_empty())

	var roll := RollDiceCommand.new(0, {"attack_id": "attack:0"})
	roll.sequence = 0
	assert_true(GameManager._apply_network_command_result(
			roll, {"attack_id": "attack:0"}))
	assert_eq(_history_types(), ["roll_dice"])
	return {
		"state": state,
		"board": board,
		"executor": executor,
		"panel": panel,
		"submitter": submitter,
	}


func _hotseat_roll_context() -> Dictionary:
	var state: GameState = _roll_state()
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	NetworkManager._local_player_index = -1
	GameManager.set_command_submitter(LocalCommandSubmitter.new())
	assert_true(GameManager.start_new_game_from_state(
			state, LearningScenarioSetup.DEFAULT_SCENARIO_ID, 0))
	var board: GameBoard = GAME_BOARD_SCENE.instantiate() as GameBoard
	add_child_autofree(board)
	var executor: AttackExecutor = board._attack_executor
	var panel: AttackSimPanel = board._target_selector.get_panel()
	assert_true(executor.is_in_exec_mode())
	assert_eq(executor._flow_fsm.current_step, AttackFlowFSM.Step.ROLL)
	assert_true(panel._roll_button.visible)
	panel._roll_button.pressed.emit()
	return {
		"state": state,
		"board": board,
		"executor": executor,
		"panel": panel,
	}


func _roll_state() -> GameState:
	var state: GameState = _state_at(CurrentAttackState.STAGE_PRE_ROLL, {
		"attack_id": "attack:0",
		"dice_pool": {"RED": 2, "BLUE": 1},
		"cf_dial_resolution": CurrentAttackState.RESOLUTION_UNAVAILABLE,
		"cf_token_resolution": CurrentAttackState.RESOLUTION_PENDING,
	})
	var attacker: ShipInstance = state.get_ship(0, 0)
	attacker.roster_entry_id = "bug-015-network-attacker"
	attacker.begin_attack_step()
	attacker.commit_attack(
			Constants.HullZone.FRONT, 1, CurrentAttackState.KIND_SHIP, 0)
	attacker.add_runtime_upgrade(
			H9_RULE.DATA_KEY, "bug-015-h9", "TURBOLASERS", 0)
	assert_true(attacker.command_tokens.add_token(
			Constants.CommandType.CONCENTRATE_FIRE))
	return state


func _zero_opportunity_roll_state() -> GameState:
	return _state_at(CurrentAttackState.STAGE_PRE_ROLL, {
		"attack_id": "attack:0",
		"dice_pool": {"RED": 1},
		"cf_dial_resolution": CurrentAttackState.RESOLUTION_UNAVAILABLE,
		"cf_token_resolution": CurrentAttackState.RESOLUTION_UNAVAILABLE,
	})


func _stream_has_type(stream: Array[Dictionary], command_type: String) -> bool:
	for entry: Dictionary in stream:
		var command_data: Dictionary = entry.get("command") as Dictionary
		if str(command_data.get("type", "")) == command_type:
			return true
	return false


func _roll_interaction_snapshot(context: Dictionary) -> Dictionary:
	var state: GameState = context.get("state") as GameState
	var executor: AttackExecutor = context.get("executor") as AttackExecutor
	var panel: AttackSimPanel = context.get("panel") as AttackSimPanel
	var projected: Dictionary = UIProjector.project(state, 0).timing_window
	var capability_ids: Array[String] = []
	for opportunity: Dictionary in projected.get("opportunities", []) as Array:
		capability_ids.append(str(opportunity.get("capability_id", "")))
	return {
		"stage": state.current_attack_state.stage,
		"flow_step": state.interaction_flow.step_id,
		"fsm_step": executor._flow_fsm.current_step,
		"canonical_dice": state.current_attack_state.dice_results.duplicate(true),
		"scene_dice": executor._state.dice_results.duplicate(true),
		"roll_visible": panel._roll_button.visible,
		"choice_count": panel.timing_window_choice_count(),
		"capability_ids": capability_ids,
		"controller_player": int(projected.get("controller_player", -1)),
	}


func _assert_network_timing_intent(
		capability_id: String,
		expected_command_type: String,
		decline: bool) -> void:
	var context: Dictionary = _network_roll_context()
	var state: GameState = context.get("state") as GameState
	var panel: AttackSimPanel = context.get("panel") as AttackSimPanel
	var submitter: AuthenticatedRecordingSubmitter = \
			context.get("submitter") as AuthenticatedRecordingSubmitter
	var projected: Dictionary = UIProjector.project(state, 0).timing_window
	var opportunities: Array = projected.get("opportunities", []) as Array
	var opportunity_index: int = -1
	for index: int in range(opportunities.size()):
		var opportunity: Dictionary = opportunities[index] as Dictionary
		if str(opportunity.get("capability_id", "")) == capability_id:
			opportunity_index = index
			break
	assert_gte(opportunity_index, 0)
	var submitted_before: int = submitter.submitted_commands.size()
	if decline:
		var decline_button: Button = panel.find_child(
				"TimingDeclineButton_%d" % opportunity_index,
				true, false) as Button
		assert_not_null(decline_button)
		decline_button.pressed.emit()
	else:
		var use_button: Button = panel.find_child(
				"TimingUseButton_%d" % opportunity_index,
				true, false) as Button
		assert_not_null(use_button)
		use_button.pressed.emit()
		assert_eq(submitter.submitted_commands.size(), submitted_before,
				"Use without a die must remain local and non-authoritative.")
		assert_false(panel._timing_window_die_intents.is_empty())
		var die_index: int = int(panel._timing_window_die_intents.keys()[0])
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		panel._dice_textures[die_index].gui_input.emit(click)
	assert_eq(submitter.submitted_commands.size(), submitted_before + 1)
	var submitted: GameCommand = submitter.submitted_commands[-1]
	assert_eq(submitted.command_type, expected_command_type)
	assert_eq(submitted.player_index, 0)
	assert_eq(submitted.payload.get("attack_id"), "attack:0")
	assert_eq(submitted.payload.get("lifecycle_id"),
			state.timing_window_state.lifecycle_id)
	if not decline:
		assert_typeof(submitted.payload.get("die_index"), TYPE_INT)


func _state_at(stage: String, options: Dictionary) -> GameState:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.rng = GameRng.new(8108)
	state.damage_deck = DamageDeck.new()
	state.damage_deck.initialize()
	var configured: Dictionary = options.duplicate(true)
	configured["stage"] = stage
	var attacker_kind: String = str(configured.get(
			"attacker_kind", CurrentAttackState.KIND_SHIP))
	if attacker_kind == CurrentAttackState.KIND_SQUADRON:
		state.current_phase = Constants.GamePhase.SQUADRON
	if stage == CurrentAttackState.STAGE_ATTACK_MODIFY \
			and attacker_kind == CurrentAttackState.KIND_SHIP:
		configured["cf_token_resolution"] = \
				CurrentAttackState.RESOLUTION_PENDING
	assert_not_null(CURRENT_ATTACK_FIXTURE.install(state, configured))
	if stage == CurrentAttackState.STAGE_ATTACK_MODIFY \
			and attacker_kind == CurrentAttackState.KIND_SHIP:
		assert_true(state.get_ship(0, 0).command_tokens.add_token(
				Constants.CommandType.CONCENTRATE_FIRE))
		var attack_id: String = state.current_attack_state.attack_id
		var opening_sequence: int = int(attack_id.get_slice(":", 1))
		assert_true(bool(TIMING_WINDOW_ORCHESTRATOR.open_window(
				state,
				TimingWindowDefinitions.ATTACK_MODIFY,
				opening_sequence,
				{
					TimingWindowState.CONTINUATION_KEY_ID:
							ConfirmAttackDiceCommand.TYPE,
					TimingWindowState.CONTINUATION_KEY_RESUME_POINT:
							"attack_after_modify",
					TimingWindowState.CONTINUATION_KEY_SOURCE_ID:
							attack_id,
					TimingWindowState.CONTINUATION_KEY_SOURCE_TYPE:
							"current_attack",
					TimingWindowState.CONTINUATION_KEY_OWNER_PLAYER:
							state.current_attack_state.attacker_player,
				}).get(TIMING_WINDOW_ORCHESTRATOR.KEY_OK, false)))
	return state


func _ship_declaration_projection_state(post_skip: bool) -> GameState:
	var state: GameState = _player_one_ship_attack_state()
	var ship: ShipInstance = state.get_ship(1, 0)
	assert_true(ship.establish_ship_activation(
			"ship-activation:projection"))
	assert_true(ship.consume_unreached_squadron_command_opportunity(
			ship.ship_activation_identity, true))
	ship.begin_attack_step()
	if post_skip:
		ship.end_attack_step()
		assert_true(ship.open_maneuver_opportunity(
				ship.ship_activation_identity))
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			0, Constants.Visibility.ALL, {"stale_projection": true})
	assert_true(state.validate_declaration_adjacent_state())
	return state


func _phase_squadron_projection_state(post_skip: bool) -> GameState:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SQUADRON
	state.get_player_state(0).faction = Constants.Faction.REBEL_ALLIANCE
	state.get_player_state(1).faction = Constants.Faction.GALACTIC_EMPIRE
	assert_true(state.initialize_squadron_phase_progress(0))
	var data: SquadronData = AssetLoader.load_squadron_data(
			DECOY_SQUADRON_KEY).duplicate(true) as SquadronData
	if post_skip:
		data.keywords.append({"name": "Rogue"})
	var squadron := SquadronInstance.create_from_data(
			DECOY_SQUADRON_KEY, data, 0)
	squadron.pos_x = 0.5
	squadron.pos_y = 0.52
	squadron.roster_entry_id = "projection-squadron"
	state.get_player_state(0).squadrons.append(squadron)
	var enemy := SquadronInstance.create_from_data(
			"tie_fighter_squadron",
			AssetLoader.load_squadron_data("tie_fighter_squadron"), 1)
	enemy.pos_x = 0.5
	enemy.pos_y = 0.48
	enemy.roster_entry_id = "projection-target"
	state.get_player_state(1).squadrons.append(enemy)
	assert_true(squadron.initialize_activation_action_state(
			"squadron-activation:projection",
			SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE))
	if post_skip:
		assert_true(squadron.commit_attack_action_declined(
				squadron.activation_id, true))
	state.interaction_flow = InteractionFlow.empty()
	assert_true(state.validate_declaration_adjacent_state())
	return state


func _command_squadron_projection_state(post_skip: bool) -> GameState:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.get_player_state(0).faction = Constants.Faction.REBEL_ALLIANCE
	state.get_player_state(1).faction = Constants.Faction.GALACTIC_EMPIRE
	var ship := ShipInstance.create_from_data(
			DECOY_SHIP_KEY,
			AssetLoader.load_ship_data(DECOY_SHIP_KEY), 2, 0)
	ship.pos_x = 0.5
	ship.pos_y = 0.55
	ship.roster_entry_id = "projection-command-ship"
	assert_true(ship.command_dial_stack.assign_dials(
			[Constants.CommandType.SQUADRON], 1))
	assert_false(ship.command_dial_stack.reveal_top().is_empty())
	assert_true(ship.establish_ship_activation(
			"ship-activation:command-projection"))
	assert_true(ship.open_squadron_command_opportunity(
			ship.ship_activation_identity))
	assert_true(ship.commit_squadron_command_activation(
			ship.ship_activation_identity))
	state.get_player_state(0).ships.append(ship)
	var squadron := SquadronInstance.create_from_data(
			DECOY_SQUADRON_KEY,
			AssetLoader.load_squadron_data(DECOY_SQUADRON_KEY), 0)
	squadron.pos_x = 0.5
	squadron.pos_y = 0.51
	squadron.roster_entry_id = "projection-command-squadron"
	state.get_player_state(0).squadrons.append(squadron)
	assert_true(squadron.initialize_activation_action_state(
			"squadron-activation:command-projection",
			SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
			0, 0))
	if post_skip:
		assert_true(squadron.commit_attack_action_declined(
				squadron.activation_id, false))
	state.interaction_flow = InteractionFlow.empty()
	assert_true(state.validate_declaration_adjacent_state())
	return state


func _command_squadron_active_begin_state() -> GameState:
	var state: GameState = _command_squadron_projection_state(false)
	var attacker: SquadronInstance = state.get_squadron(0, 0)
	var defender := SquadronInstance.create_from_data(
			"tie_fighter_squadron",
			AssetLoader.load_squadron_data("tie_fighter_squadron"), 1)
	defender.pos_x = 0.5
	defender.pos_y = 0.48
	defender.roster_entry_id = "projection-command-target"
	state.get_player_state(1).squadrons.append(defender)
	assert_true(attacker.commit_attack_action_begun(
			attacker.activation_id, false))
	var attack := CurrentAttackState.new()
	assert_true(attack.configure_active("attack:61", {
		"attacker_player": 0,
		"attacker_kind": CurrentAttackState.KIND_SQUADRON,
		"attacker_index": 0,
		"attacker_zone": -1,
		"defender_player": 1,
		"defender_kind": CurrentAttackState.KIND_SQUADRON,
		"defender_index": 0,
		"defender_zone": -1,
		"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
		"range_band": Constants.RANGE_BAND_CLOSE,
		"obstructed": false,
		"obstruction_resolved": true,
		"dice_pool": {"BLUE": 1},
		"cf_dial_resolution": CurrentAttackState.RESOLUTION_UNAVAILABLE,
		"cf_token_resolution": CurrentAttackState.RESOLUTION_UNAVAILABLE,
	}))
	assert_true(state.set_current_attack_state(attack))
	state.interaction_flow = InteractionFlow.empty()
	assert_true(state.validate_declaration_adjacent_state())
	return state


func _player_one_ship_attack_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
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


func _inactive_ship_continuation_state(step_six: bool) -> GameState:
	var state: GameState = _player_one_ship_attack_state()
	var attacker: ShipInstance = state.get_ship(1, 0)
	assert_true(attacker.establish_ship_activation(
			"ship-activation:inactive-continuation"))
	attacker.begin_attack_step()
	if step_six:
		_add_rebel_squadron(state, 0.49, 0.55, "step-six-a")
		_add_rebel_squadron(state, 0.51, 0.55, "step-six-b")
		attacker.commit_attack(
				Constants.HullZone.FRONT,
				0,
				CurrentAttackState.KIND_SQUADRON,
				0)
	else:
		attacker.commit_attack(
				Constants.HullZone.FRONT,
				0,
				CurrentAttackState.KIND_SHIP,
				0)
	assert_true(state.set_current_attack_state(CurrentAttackState.inactive()))
	state.interaction_flow = InteractionFlow.empty()
	return state


func _add_rebel_squadron(state: GameState, pos_x: float, pos_y: float,
		roster_id: String) -> void:
	var squadron := SquadronInstance.create_from_data(
			DECOY_SQUADRON_KEY,
			AssetLoader.load_squadron_data(DECOY_SQUADRON_KEY),
			0)
	squadron.roster_entry_id = roster_id
	squadron.pos_x = pos_x
	squadron.pos_y = pos_y
	state.get_player_state(0).squadrons.append(squadron)


func _board_ship_token(board: GameBoard,
		ship: ShipInstance) -> ShipToken:
	for token: ShipToken in board.get_ship_tokens():
		if token.get_ship_instance() == ship:
			return token
	return null


func _board_squadron_token(board: GameBoard,
		squadron: SquadronInstance) -> SquadronToken:
	for token: SquadronToken in board.get_squadron_tokens():
		if token.get_squadron_instance() == squadron:
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
