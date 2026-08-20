## Slice 8A regression coverage for authoritative squadron target presentation
## and atomic recovery from a rejected BeginAttackCommand.
extends GutTest


const SHIP_TOKEN_SCENE: PackedScene = preload(
		"res://src/scenes/tokens/ship_token.tscn")
const SQUADRON_TOKEN_SCENE: PackedScene = preload(
		"res://src/scenes/tokens/squadron_token.tscn")

const CR90_KEY: String = "cr90_corvette_a"
const NEBULON_KEY: String = "nebulon_b_escort_frigate"
const VICTORY_KEY: String = "victory_ii_class_star_destroyer"
const TIE_KEY: String = "tie_fighter_squadron"
const HOWLRUNNER_KEY: String = "tie_fighter_howlrunner"

const FORENSIC_TIE_0_NORM := Vector2(
		0.407147838451244, 0.395567152235243)
const COMPARISON_TIE_5_PX := Vector2(820.0, 900.0)
const FORENSIC_NEBULON_NORM := Vector2(
		0.305568892867477, 0.448125429506655)
const FORENSIC_VICTORY_PX := Vector2(1036.4, 780.8)
const BUG_025_VICTORY_PX := Vector2(1037.8625, 736.1537)
const BUG_025_NEBULON_PX := Vector2(660.0288, 967.9509)

var _saved_state: GameState = null
var _saved_active: bool = false
var _saved_active_player: int = 0
var _saved_submitter: CommandSubmitter = null
var _saved_activating_squadron: SquadronInstance = null
var _saved_squadrons_activated: int = 0
var _saved_play_mode: PlayMode.Mode
var _saved_network_role: NetworkManager.Role
var _saved_local_player: int = -1
var _saved_log_level: GameLogger.Level

var _ship_tokens: Array[ShipToken] = []
var _squadron_tokens: Array[SquadronToken] = []


class AwaitingSubmitter:
	extends CommandSubmitter

	var submitted: Array[GameCommand] = []

	func submit(command: GameCommand) -> Dictionary:
		submitted.append(command)
		return {"awaiting_remote": true}


func before_each() -> void:
	_saved_state = GameManager.current_game_state
	_saved_active = GameManager.is_game_active
	_saved_active_player = GameManager.active_player
	_saved_submitter = GameManager.get_command_submitter()
	_saved_activating_squadron = GameManager._activating_squadron
	_saved_squadrons_activated = GameManager._squadrons_activated_this_turn
	_saved_play_mode = PlayMode.current_mode
	_saved_network_role = NetworkManager.role
	_saved_local_player = NetworkManager._local_player_index
	_saved_log_level = GameLogger.min_level
	GameLogger.min_level = GameLogger.Level.WARNING
	_ship_tokens.clear()
	_squadron_tokens.clear()
	GameScale._load_scale_config()
	RuleBootstrap.bootstrap_rules()
	CommandProcessor.reset()
	GameManager.set_command_submitter(LocalCommandSubmitter.new())
	GameManager._activating_squadron = null
	GameManager._squadrons_activated_this_turn = 0
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	NetworkManager.role = NetworkManager.Role.NONE
	NetworkManager._local_player_index = -1


func after_each() -> void:
	RuleBootstrap.bootstrap_rules()
	CommandProcessor.reset()
	GameManager.current_game_state = _saved_state
	GameManager.is_game_active = _saved_active
	GameManager.active_player = _saved_active_player
	GameManager.set_command_submitter(_saved_submitter)
	GameManager._activating_squadron = _saved_activating_squadron
	GameManager._squadrons_activated_this_turn = _saved_squadrons_activated
	PlayMode.current_mode = _saved_play_mode
	NetworkManager.role = _saved_network_role
	NetworkManager._local_player_index = _saved_local_player
	GameLogger.min_level = _saved_log_level
	GameScale._load_scale_config()


func test_bug_025_forensic_tie_and_control_tie_target_nebulon() -> void:
	var state: GameState = _make_forensic_state()
	_install_state(state)
	var composition: Dictionary = _make_composition(state)
	var controller: SquadronPhaseController = composition["controller"]
	var tie_0: SquadronInstance = state.get_squadron(1, 0)
	var tie_5: SquadronInstance = state.get_squadron(1, 5)

	assert_eq(state.find_squadron_index(tie_0), 0)
	assert_eq(state.find_squadron_index(tie_5), 5)
	assert_eq(tie_0.data_key, tie_5.data_key,
			"Both physical entities intentionally share one data identity.")
	assert_almost_eq(tie_0.get_pixel_position(GameScale.play_area_size_px),
			Vector2(879.4393, 854.4250), Vector2(0.01, 0.01))

	var tie_0_candidates: Array[Dictionary] = \
			TargetingListBuilder.authoritative_squadron_target_entries(
					state, 1, 0)
	var tie_5_candidates: Array[Dictionary] = \
			TargetingListBuilder.authoritative_squadron_target_entries(
					state, 1, 5)
	assert_eq(_nebulon_zones(tie_0_candidates), [
			int(Constants.HullZone.FRONT)],
			"The reproduced distance-1 TIE must recover the Nebulon FRONT zone.")
	assert_eq(_nebulon_zones(tie_5_candidates), [
			int(Constants.HullZone.FRONT), int(Constants.HullZone.RIGHT)],
			"Identical TIE index 5 retains legal FRONT/RIGHT candidates.")

	var all_squads: Array[Dictionary] = \
			controller._build_all_squadron_positions()
	var obstruction_bodies: Array = controller._build_obstruction_bodies()
	assert_true(controller._squadron_has_valid_targets(
			tie_0, _token_for_squadron(tie_0), all_squads,
			obstruction_bodies),
			"Squadron Phase projection must use the repaired shared legality.")
	assert_true(controller._squadron_has_valid_targets(
			tie_5, _token_for_squadron(tie_5), all_squads,
			obstruction_bodies))


func test_bug_025_victory_side_arc_projects_and_begins_nebulon() -> void:
	for defender_rotation: float in [35.0, 45.0, 55.0]:
		CommandProcessor.reset()
		var state: GameState = _make_bug_025_ship_state(
				NEBULON_KEY, BUG_025_NEBULON_PX, defender_rotation)
		_install_state(state)
		var candidates: Array[Dictionary] = \
				TargetingListBuilder.authoritative_ship_target_entries(
						state, 1, 0)
		var side_candidates: Array[Dictionary] = _ship_target_candidates(
				candidates, Constants.HullZone.RIGHT, 0, 0)
		assert_false(side_candidates.is_empty(),
				"VSD RIGHT arc must offer the Nebulon at %.0f degrees." \
						% defender_rotation)
		if side_candidates.is_empty():
			continue
		var result: Dictionary = CommandProcessor.submit(BeginAttackCommand.new(
				1, _ship_begin_payload(state, side_candidates[0])))
		assert_false(result.is_empty(),
				"Begin must accept the same VSD side-arc candidate as projection.")
		assert_true(state.current_attack_state.active)
		assert_eq(state.current_attack_state.attacker_zone,
				int(Constants.HullZone.RIGHT))
		assert_eq(state.current_attack_state.defender_player, 0)
		assert_eq(state.current_attack_state.defender_index, 0)
		assert_eq(_history_types(), [BeginAttackCommand.TYPE])


func test_bug_025_ship_controls_reject_illegal_arc_and_clear_between_states() \
		-> void:
	var control_state: GameState = _make_bug_025_ship_state(
			CR90_KEY, BUG_025_NEBULON_PX, 45.0)
	_install_state(control_state)
	var control_candidates: Array[Dictionary] = _ship_target_candidates(
			TargetingListBuilder.authoritative_ship_target_entries(
					control_state, 1, 0),
			Constants.HullZone.RIGHT, 0, 0)
	assert_false(control_candidates.is_empty(),
			"A non-Nebulon ship at the same legal geometry remains a control target.")

	CommandProcessor.reset()
	var illegal_state: GameState = _make_bug_025_ship_state(
			NEBULON_KEY, BUG_025_NEBULON_PX, 45.0)
	_install_state(illegal_state)
	var legal_candidates: Array[Dictionary] = _ship_target_candidates(
			TargetingListBuilder.authoritative_ship_target_entries(
					illegal_state, 1, 0),
			Constants.HullZone.RIGHT, 0, 0)
	assert_false(legal_candidates.is_empty())
	if legal_candidates.is_empty():
		return
	var forged_payload: Dictionary = _ship_begin_payload(
			illegal_state, legal_candidates[0])
	forged_payload["attacker_zone"] = int(Constants.HullZone.LEFT)
	assert_eq(CommandProcessor.submit(
			BeginAttackCommand.new(1, forged_payload)), {},
			"Authoritative Begin must still reject an illegal attacker arc.")
	assert_true(illegal_state.current_attack_state.is_inactive())
	assert_true(_history_types().is_empty())
	assert_engine_error(1,
			"The forged illegal arc must fail authoritative target validation.")

	var far_state: GameState = _make_bug_025_ship_state(
			NEBULON_KEY, Vector2(200.0, 2000.0), 45.0)
	_install_state(far_state)
	assert_true(_ship_target_candidates(
			TargetingListBuilder.authoritative_ship_target_entries(
					far_state, 1, 0),
			Constants.HullZone.RIGHT, 0, 0).is_empty(),
			"A new attacker query must not retain the previous target list.")


func test_bug_005_inside_distance_one_previews_and_begins_both_pairings() \
		-> void:
	_assert_production_distance_thresholds_are_distinct()
	for defender_kind: String in [
		CurrentAttackState.KIND_SQUADRON,
		CurrentAttackState.KIND_SHIP,
	]:
		CommandProcessor.reset()
		var state: GameState = _make_distance_boundary_state(
				defender_kind, 179.0)
		_install_state(state)
		var candidates: Array[Dictionary] = \
				TargetingListBuilder.authoritative_squadron_target_entries(
						state, 0, 0)
		assert_eq(candidates.size(), 1,
				"Preview must expose the exact inside-distance-1 %s target." \
						% defender_kind)
		if candidates.size() != 1:
			continue
		var payload: Dictionary = _squadron_begin_payload(
				state, candidates[0])
		var result: Dictionary = CommandProcessor.submit(
				BeginAttackCommand.new(0, payload))
		assert_false(result.is_empty(),
				"Begin must accept the same inside-distance-1 target as Preview.")
		assert_true(state.current_attack_state.active)
		assert_eq(state.current_attack_state.defender_kind, defender_kind)
		assert_eq(state.get_squadron(0, 0).attack_action_disposition,
				SquadronInstance.ATTACK_ACTION_BEGUN)
		assert_eq(_history_types(), [BeginAttackCommand.TYPE])


func test_bug_005_close_only_interval_rejects_preview_and_begin_both_pairings() \
		-> void:
	_assert_production_distance_thresholds_are_distinct()
	for defender_kind: String in [
		CurrentAttackState.KIND_SQUADRON,
		CurrentAttackState.KIND_SHIP,
	]:
		CommandProcessor.reset()
		var state: GameState = _make_distance_boundary_state(
				defender_kind, 183.0)
		_install_state(state)
		var owner_before: Dictionary = state.get_squadron(
				0, 0).activation_action_state_snapshot()
		var candidates: Array[Dictionary] = \
				TargetingListBuilder.authoritative_squadron_target_entries(
						state, 0, 0)
		assert_true(candidates.is_empty(),
				"Preview must reject a target outside distance 1 but in close range.")
		var payload: Dictionary = _forged_close_only_begin_payload(
				state, defender_kind)
		assert_eq(CommandProcessor.submit(
				BeginAttackCommand.new(0, payload)), {})
		assert_true(state.current_attack_state.is_inactive())
		assert_eq(state.get_squadron(
				0, 0).activation_action_state_snapshot(), owner_before)
		assert_true(_history_types().is_empty())
		assert_eq(CommandProcessor.get_next_sequence(), 0)
	assert_engine_error(2,
			"Both close-only Begin attempts must fail authoritative revalidation.")


func test_all_four_declaration_skip_rows_are_preview_independent() -> void:
	var without_preview: Dictionary = {}
	for previewed: bool in [false, true]:
		for context: String in [
			SkipAttackCommand.CONTEXT_SHIP_ATTACK,
			"non_rogue_squadron_phase",
			"rogue_squadron_phase",
			SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
		]:
			CommandProcessor.reset()
			var fixture: Dictionary = _make_declaration_skip_fixture(context)
			var state: GameState = fixture.get("state") as GameState
			var payload: Dictionary = fixture.get("payload", {}) as Dictionary
			_install_state(state)
			var before_preview: Dictionary = state.serialize()
			if previewed:
				var candidates: Array[Dictionary] = []
				if context == SkipAttackCommand.CONTEXT_SHIP_ATTACK:
					candidates = \
							TargetingListBuilder.authoritative_ship_target_entries(
									state, 0, 0)
				else:
					candidates = TargetingListBuilder \
							.authoritative_squadron_target_entries(state, 0, 0)
				assert_false(candidates.is_empty(),
						"Preview fixture must expose a replaceable candidate.")
				assert_eq(state.serialize(), before_preview,
						"Preview query must not mutate canonical owners.")
			var result: Dictionary = CommandProcessor.submit(
					SkipAttackCommand.new(0, payload))
			assert_false(result.is_empty())
			assert_true(state.current_attack_state.is_inactive())
			assert_eq(_history_types(), [SkipAttackCommand.new().command_type])
			var outcome: Dictionary = _declaration_skip_outcome(
					state, result, context)
			var restored: GameState = GameState.deserialize(
					JSON.parse_string(JSON.stringify(state.serialize())))
			assert_not_null(restored,
					"Every post-Skip row must reconstruct from canonical owners.")
			if restored != null:
				if context == "rogue_squadron_phase":
					restored.get_squadron(0, 0).squadron_data = \
							state.get_squadron(0, 0).squadron_data
				assert_eq(CanonicalJson.hash(_declaration_skip_outcome(
						restored, result, context)), CanonicalJson.hash(outcome),
						"Post-Skip reconstruction must preserve the %s row." \
								% context)
			if previewed:
				assert_eq(outcome, without_preview.get(context, {}),
						"Preview must not alter the %s Skip row." % context)
			else:
				without_preview[context] = outcome


func test_all_squadron_declaration_contexts_begin_with_exact_owner_transition() \
		-> void:
	for context: String in [
		"non_rogue_squadron_phase",
		"rogue_squadron_phase",
		SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
	]:
		CommandProcessor.reset()
		var fixture: Dictionary = _make_declaration_skip_fixture(context)
		var state: GameState = fixture.get("state") as GameState
		_install_state(state)
		var candidates: Array[Dictionary] = TargetingListBuilder \
				.authoritative_squadron_target_entries(state, 0, 0)
		assert_false(candidates.is_empty(),
				"The %s Begin row must have an authoritative candidate." % context)
		if candidates.is_empty():
			continue
		var payload: Dictionary = _squadron_begin_payload(
				state, candidates[0])
		var result: Dictionary = CommandProcessor.submit(
				BeginAttackCommand.new(0, payload))
		assert_false(result.is_empty(),
				"The %s Begin row must be accepted." % context)
		assert_true(state.current_attack_state.active)
		assert_eq(_history_types(), [BeginAttackCommand.TYPE])
		var squadron: SquadronInstance = state.get_squadron(0, 0)
		assert_eq(squadron.attack_action_disposition,
				SquadronInstance.ATTACK_ACTION_BEGUN)
		assert_false(squadron.activated_this_round,
				"An active attack has not completed its activation.")
		var rogue: bool = context == "rogue_squadron_phase"
		var independent_actions: bool = rogue or context \
				== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND
		assert_eq(squadron.has_remaining_move_action(rogue),
				independent_actions,
				"Rogue and commanded squadrons retain unused movement.")
		if context \
				== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
			var ship: ShipInstance = state.get_ship(0, 0)
			assert_eq(ship.squadron_command_opportunity_disposition,
					ShipInstance.ACTIVATION_DISPOSITION_OPEN)
			assert_eq(ship.squadron_command_activations_committed, 1)
		var restored: GameState = GameState.deserialize(
				JSON.parse_string(JSON.stringify(state.serialize())))
		assert_not_null(restored,
				"The %s post-Begin owners must reconstruct." % context)
		if restored != null:
			if rogue:
				restored.get_squadron(0, 0).squadron_data = \
						squadron.squadron_data
			assert_eq(restored.get_squadron(
					0, 0).activation_action_state_snapshot(),
					squadron.activation_action_state_snapshot())
			assert_eq(restored.current_attack_state.serialize(),
					state.current_attack_state.serialize())


func test_bug_025_production_selection_and_begin_accept_forensic_nebulon() \
		-> void:
	var state: GameState = _make_forensic_state()
	_install_state(state)
	assert_true(CommandProcessor.restore_next_sequence(115))
	var composition: Dictionary = _make_composition(state)
	var controller: SquadronPhaseController = composition["controller"]
	var selector: TargetSelector = composition["selector"]
	var executor: AttackExecutor = composition["executor"]
	var modal: SquadronActivationModal = controller.get_modal()
	var tie_0_token: SquadronToken = _token_for_squadron(
			state.get_squadron(1, 0))
	var nebulon_token: ShipToken = _token_for_ship(state.get_ship(0, 1))

	_activate_through_controller(controller, tie_0_token)
	assert_eq(state.find_squadron_index(
			GameManager.get_activating_squadron()), 0)
	assert_true(modal._attack_button.visible,
			"Action availability must expose the repaired legal target.")
	var enclosing_flow: Dictionary = state.interaction_flow.serialize()

	modal._on_attack_pressed()
	selector._try_select_target_ship_zone(
			nebulon_token, Constants.HullZone.FRONT)

	assert_true(selector.has_declaration_candidate())
	assert_eq(selector.get_state().defender_ship, nebulon_token)
	assert_true(state.current_attack_state.is_inactive())
	assert_false(state.timing_window_state.active)
	assert_eq(state.interaction_flow.serialize(), enclosing_flow,
			"Transient target selection must not replace enclosing flow before Begin.")
	assert_eq(CommandProcessor.get_next_sequence(), 116)
	assert_eq(_history_types(), ["activate_squadron"])

	executor._on_declaration_confirm()

	assert_true(state.current_attack_state.active,
			"Authoritative Begin must accept the same repaired target projection.")
	assert_eq(state.current_attack_state.attacker_index, 0)
	assert_eq(state.current_attack_state.defender_index, 1)
	assert_eq(state.current_attack_state.defender_zone,
			int(Constants.HullZone.FRONT))
	assert_eq(_history_types(), ["activate_squadron", "begin_attack"])


func test_bug_018_modal_skip_commits_action_then_allows_next_squadron() -> void:
	var state: GameState = _make_forensic_state()
	_place_squadron(state.get_squadron(1, 0), Vector2(1900.0, 200.0))
	_install_state(state)
	var composition: Dictionary = _make_composition(state)
	var controller: SquadronPhaseController = composition["controller"]
	var modal: SquadronActivationModal = controller.get_modal()
	var skipped: SquadronInstance = state.get_squadron(1, 0)
	var skipped_token: SquadronToken = _token_for_squadron(skipped)

	_activate_through_controller(controller, skipped_token)
	assert_true(modal._move_button.visible,
			"The reproduced squadron must have a legal movement action.")
	assert_false(modal._attack_button.visible,
			"The reproduced squadron must have no legal attack targets.")
	assert_eq(CompleteSquadronActivationCommand.new(1, {
		"squadron_index": 0,
		"activation_id": skipped.activation_id,
		"activation_context": skipped.activation_context,
	}).validate(state), "Squadron still has an available action.",
			"Completion must reject before the semantic action transition.")

	modal._on_skip_pressed()

	assert_eq(skipped.attack_action_disposition,
			SquadronInstance.ATTACK_ACTION_DECLINED)
	assert_false(skipped.move_action_committed)
	assert_true(skipped.activated_this_round)
	assert_eq(state.squadron_phase_activations_committed, 1)
	assert_eq(_history_types(), ["activate_squadron", "skip_attack"])
	assert_false(_history_types().has(
			CompleteSquadronActivationCommand.TYPE),
			"Accepted declaration Skip completes this non-Rogue row atomically.")
	assert_eq(modal.get_state(),
			SquadronActivationModal.State.WAITING_FOR_SELECTION)

	var replay: GameReplay = CommandProcessor.create_replay()
	assert_not_null(replay,
			"Production replay capture must include the repaired progression.")
	if replay != null:
		var replay_data: Dictionary = replay.serialize()
		assert_eq((replay_data["header"] as Dictionary)["format_version"],
				GameReplay.FORMAT_VERSION,
				"UX-005 replay cutover applies even though this declaration skip " \
				+ "does not create a completed-attack acknowledgement.")
		assert_not_null(GameReplay.deserialize(replay_data))
		assert_eq((replay.commands[0] as Dictionary)["type"],
				"activate_squadron")
		assert_eq((replay.commands[1] as Dictionary)["type"], "skip_attack")

	var next_token: SquadronToken = _token_for_squadron(
			state.get_squadron(1, 1))
	assert_true(controller.try_handle_squadron_click(next_token),
			"The next eligible squadron must be activatable.")
	assert_eq(_history_types(), [
		"activate_squadron", "skip_attack", "activate_squadron"])


func test_bug_018_network_controller_waits_for_authoritative_skip_result() \
		-> void:
	var state: GameState = _make_forensic_state()
	_install_state(state)
	var composition: Dictionary = _make_composition(state)
	var controller: SquadronPhaseController = composition["controller"]
	var modal: SquadronActivationModal = controller.get_modal()
	var skipped: SquadronInstance = state.get_squadron(1, 0)
	_activate_through_controller(controller, _token_for_squadron(skipped))

	var submitter := AwaitingSubmitter.new()
	GameManager.set_command_submitter(submitter)
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1
	modal._on_skip_pressed()

	assert_eq(submitter.submitted.size(), 1)
	assert_eq(submitter.submitted[0].command_type, "skip_attack")
	assert_eq(modal.get_state(), SquadronActivationModal.State.ACTION_CHOICE,
			"Client presentation must wait for authoritative acceptance.")
	assert_eq(skipped.attack_action_disposition,
			SquadronInstance.ATTACK_ACTION_AVAILABLE)
	assert_false(skipped.activated_this_round)

	var mirrored: GameCommand = submitter.submitted[0]
	mirrored.sequence = CommandProcessor.get_next_sequence()
	assert_false(CommandProcessor.submit_mirror(mirrored).is_empty())

	assert_eq(skipped.attack_action_disposition,
			SquadronInstance.ATTACK_ACTION_DECLINED)
	assert_true(skipped.activated_this_round)
	assert_eq(modal.get_state(),
			SquadronActivationModal.State.WAITING_FOR_SELECTION)
	assert_eq(_history_types(), ["activate_squadron", "skip_attack"])


func test_rejected_begin_recovers_then_deselect_and_skip_progresses() -> void:
	var state: GameState = _make_forensic_state()
	_install_state(state)
	assert_true(CommandProcessor.restore_next_sequence(115))
	var composition: Dictionary = _make_composition(state)
	var controller: SquadronPhaseController = composition["controller"]
	var selector: TargetSelector = composition["selector"]
	var executor: AttackExecutor = composition["executor"]
	var modal: SquadronActivationModal = controller.get_modal()
	var tie_5_token: SquadronToken = _token_for_squadron(
			state.get_squadron(1, 5))
	var nebulon_token: ShipToken = _token_for_ship(state.get_ship(0, 1))

	_activate_through_controller(controller, tie_5_token)
	assert_true(modal._attack_button.visible)
	var enclosing_flow: Dictionary = state.interaction_flow.serialize()
	var before_cursor: int = CommandProcessor.get_next_sequence()
	var before_history: Array[String] = _history_types()
	_register_controlled_begin_blocker()
	watch_signals(CommandProcessor)
	watch_signals(executor)
	watch_signals(modal)

	modal._on_attack_pressed()
	assert_true(controller.is_in_attacking_state())
	assert_eq(state.interaction_flow.serialize(), enclosing_flow,
			"Pre-Begin ATTACK presentation must remain transient.")
	selector._try_select_target_ship_zone(
			nebulon_token, Constants.HullZone.FRONT)
	assert_true(selector.has_declaration_candidate())
	assert_true(state.current_attack_state.is_inactive())
	assert_eq(CommandProcessor.get_next_sequence(), before_cursor)
	assert_eq(_history_types(), before_history)
	executor._on_declaration_confirm()

	assert_engine_error(1,
			"Controlled authoritative rejection should warn exactly once.")
	assert_signal_emitted(CommandProcessor, "command_rejected")
	var rejected: Array = get_signal_parameters(
			CommandProcessor, "command_rejected")
	assert_eq((rejected[0] as GameCommand).command_type,
			BeginAttackCommand.TYPE)
	assert_eq(rejected[1], "Controlled Begin rejection.")
	assert_signal_not_emitted(executor, "attack_exec_cancelled")
	assert_signal_not_emitted(executor, "attack_exec_completed")
	assert_eq(CommandProcessor.get_next_sequence(), before_cursor)
	assert_eq(_history_types(), before_history)
	assert_true(state.current_attack_state.is_inactive())
	assert_false(state.timing_window_state.active)
	assert_eq(state.interaction_flow.serialize(), enclosing_flow)
	assert_true(selector.is_active())
	assert_true(selector.has_declaration_candidate())
	assert_true(executor.is_in_exec_mode())
	assert_true(controller.is_in_attacking_state())
	assert_false(modal.visible)
	assert_false(selector.get_panel()._confirm_button.disabled)
	assert_false(selector.get_panel()._skip_attack_button.disabled)
	assert_false(_history_types().has(BeginAttackCommand.TYPE))
	assert_false(_history_types().has(CompleteAttackCommand.TYPE))

	# Rejection restores the same declaration. Deselect keeps declaration Skip
	# available and accepted Skip ends the enclosing procedural interaction.
	selector.deselect_target()
	assert_false(selector.has_declaration_candidate())
	assert_true(selector.get_panel()._skip_attack_button.visible)
	executor._on_attack_skip()
	assert_signal_emitted(executor, "attack_exec_completed")
	assert_false(controller.is_in_attacking_state())
	assert_eq(controller._squadron_activation_count, 1)
	assert_eq(CommandProcessor.get_next_sequence(), before_cursor + 1)
	assert_eq(_history_types(), before_history + ["skip_attack"])


func test_legal_squadron_target_still_accepts_normal_begin_path() -> void:
	var state: GameState = _make_forensic_state()
	_install_state(state)
	assert_true(CommandProcessor.restore_next_sequence(115))
	var composition: Dictionary = _make_composition(state)
	var controller: SquadronPhaseController = composition["controller"]
	var selector: TargetSelector = composition["selector"]
	var executor: AttackExecutor = composition["executor"]
	var modal: SquadronActivationModal = controller.get_modal()
	var tie_5_token: SquadronToken = _token_for_squadron(
			state.get_squadron(1, 5))
	var nebulon_token: ShipToken = _token_for_ship(state.get_ship(0, 1))

	_activate_through_controller(controller, tie_5_token)
	modal._on_attack_pressed()
	var pre_begin_flow: Dictionary = state.interaction_flow.serialize()
	selector._try_select_target_ship_zone(
			nebulon_token, Constants.HullZone.FRONT)

	assert_true(selector.has_declaration_candidate())
	assert_true(state.current_attack_state.is_inactive())
	assert_eq(CommandProcessor.get_next_sequence(), 116)
	assert_eq(_history_types(), ["activate_squadron"])
	executor._on_declaration_confirm()

	assert_true(state.current_attack_state.active)
	assert_eq(state.current_attack_state.attacker_player, 1)
	assert_eq(state.current_attack_state.attacker_kind,
			CurrentAttackState.KIND_SQUADRON)
	assert_eq(state.current_attack_state.attacker_index, 5)
	assert_eq(state.current_attack_state.defender_player, 0)
	assert_eq(state.current_attack_state.defender_index, 1)
	assert_eq(state.current_attack_state.defender_zone,
			int(Constants.HullZone.FRONT))
	assert_eq(state.current_attack_state.range_band,
			Constants.RANGE_BAND_CLOSE)
	assert_false(state.timing_window_state.active)
	assert_ne(state.interaction_flow.serialize(), pre_begin_flow)
	assert_eq(state.interaction_flow.flow_type,
			Constants.InteractionFlow.ATTACK)
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.ATTACK_DECLARE)
	assert_eq(CommandProcessor.get_next_sequence(), 117)
	assert_eq(_history_types(), ["activate_squadron", "begin_attack"])
	assert_true(selector.get_state().exec_mode)


func test_post_begin_destroyed_squadron_completes_through_production_callback() \
		-> void:
	var state: GameState = _make_forensic_state()
	_install_state(state)
	assert_true(CommandProcessor.restore_next_sequence(115))
	var composition: Dictionary = _make_composition(state)
	var controller: SquadronPhaseController = composition["controller"]
	var selector: TargetSelector = composition["selector"]
	var executor: AttackExecutor = composition["executor"]
	var modal: SquadronActivationModal = controller.get_modal()
	var attacker: SquadronInstance = state.get_squadron(1, 5)
	var attacker_token: SquadronToken = _token_for_squadron(attacker)
	var defender_token: ShipToken = _token_for_ship(state.get_ship(0, 1))

	_activate_through_controller(controller, attacker_token)
	modal._on_attack_pressed()
	selector._try_select_target_ship_zone(
			defender_token, Constants.HullZone.FRONT)
	executor._on_declaration_confirm()
	assert_true(state.current_attack_state.active)
	assert_eq(attacker.attack_action_disposition,
			SquadronInstance.ATTACK_ACTION_BEGUN)

	# Counter is a protected post-Begin effect. Its already-covered production
	# damage route may destroy this attacker before the enclosing callback runs.
	attacker.mark_destroyed()
	assert_true(state.set_current_attack_state(CurrentAttackState.inactive()))
	executor._finish_attack_execution()

	assert_true(attacker.is_destroyed())
	assert_true(attacker.activated_this_round,
			"The existing closure boundary must accept the destroyed attacker.")
	assert_false(controller.is_in_attacking_state())
	assert_eq(_history_types(), ["activate_squadron", "begin_attack",
			CompleteSquadronActivationCommand.TYPE])


func test_declaration_skip_with_preview_records_no_begin() -> void:
	var state: GameState = _make_forensic_state()
	_install_state(state)
	var composition: Dictionary = _make_composition(state)
	var controller: SquadronPhaseController = composition["controller"]
	var selector: TargetSelector = composition["selector"]
	var executor: AttackExecutor = composition["executor"]
	var tie_5_token: SquadronToken = _token_for_squadron(
			state.get_squadron(1, 5))
	var nebulon_token: ShipToken = _token_for_ship(state.get_ship(0, 1))

	_activate_through_controller(controller, tie_5_token)
	controller.get_modal()._on_attack_pressed()
	selector._try_select_target_ship_zone(
			nebulon_token, Constants.HullZone.FRONT)
	assert_true(selector.has_declaration_candidate())

	executor._on_attack_skip()

	assert_true(state.current_attack_state.is_inactive())
	assert_eq(_history_types(), ["activate_squadron", "skip_attack"])
	assert_false(_history_types().has(BeginAttackCommand.TYPE))
	assert_false(selector.has_declaration_candidate())
	assert_false(controller.is_in_attacking_state())


func test_rejected_declaration_skip_restores_preview_controls() -> void:
	var state: GameState = _make_forensic_state()
	_install_state(state)
	var composition: Dictionary = _make_composition(state)
	var controller: SquadronPhaseController = composition["controller"]
	var selector: TargetSelector = composition["selector"]
	var executor: AttackExecutor = composition["executor"]
	var tie_5_token: SquadronToken = _token_for_squadron(
			state.get_squadron(1, 5))
	var nebulon_token: ShipToken = _token_for_ship(state.get_ship(0, 1))

	_activate_through_controller(controller, tie_5_token)
	controller.get_modal()._on_attack_pressed()
	selector._try_select_target_ship_zone(
			nebulon_token, Constants.HullZone.FRONT)
	var candidate_before: Dictionary = selector.get_declaration_candidate()
	var history_before: Array[String] = _history_types()
	_register_controlled_declaration_skip_blocker()

	executor._on_attack_skip()

	assert_engine_error(1,
			"Controlled declaration Skip rejection should diagnose once.")
	assert_true(state.current_attack_state.is_inactive())
	assert_eq(_history_types(), history_before)
	assert_eq(selector.get_declaration_candidate(), candidate_before)
	assert_true(selector.get_panel()._confirm_button.visible)
	assert_false(selector.get_panel()._confirm_button.disabled)
	assert_true(selector.get_panel()._skip_attack_button.visible)
	assert_false(selector.get_panel()._skip_attack_button.disabled)
	assert_true(controller.is_in_attacking_state())


func test_ship_preview_a_to_b_to_c_confirms_only_final_candidate() -> void:
	var state: GameState = _make_replacement_state(true)
	_install_replacement_state(state)
	var composition: Dictionary = _make_composition(state)
	var selector: TargetSelector = composition["selector"]
	var executor: AttackExecutor = composition["executor"]
	var nebulon: ShipInstance = state.get_ship(0, 1)
	var victory: ShipInstance = state.get_ship(1, 0)
	var howlrunner: SquadronInstance = state.get_squadron(1, 0)
	var second_tie: SquadronInstance = state.get_squadron(1, 1)
	var geometry: Dictionary = _replacement_geometry(state)
	assert_false(geometry.is_empty())

	executor.start_ship_attack(_token_for_ship(nebulon))
	selector._select_attacker_ship_zone(
			_token_for_ship(nebulon), int(geometry["attacker_zone"]))
	selector._try_select_target_ship_zone(
			_token_for_ship(victory), int(geometry["defender_zone"]))
	assert_true(state.current_attack_state.is_inactive())
	assert_eq(_history_types(), [])
	assert_eq(selector.get_declaration_candidate().get("defender_kind"),
			CurrentAttackState.KIND_SHIP)

	selector._handle_target_squadron_click(_token_for_squadron(howlrunner))
	assert_true(state.current_attack_state.is_inactive())
	assert_eq(_history_types(), [])
	assert_eq(selector.get_declaration_candidate().get("defender_index"), 0)

	selector._handle_target_squadron_click(_token_for_squadron(second_tie))
	assert_true(state.current_attack_state.is_inactive())
	assert_eq(_history_types(), [])
	assert_eq(selector.get_declaration_candidate().get("defender_index"), 1)

	executor._on_declaration_confirm()
	assert_eq(_history_types(), [BeginAttackCommand.TYPE])
	assert_eq(state.current_attack_state.attacker_kind,
			CurrentAttackState.KIND_SHIP)
	assert_eq(state.current_attack_state.attacker_index, 1)
	assert_eq(state.current_attack_state.defender_kind,
			CurrentAttackState.KIND_SQUADRON)
	assert_eq(state.current_attack_state.defender_index, 1)
	assert_eq(state.current_attack_state.dice_pool,
			DicePool.get_attack_pool(nebulon.ship_data.anti_squadron_armament,
					state.current_attack_state.range_band))
	assert_eq(selector.get_state().defender_squadron,
			_token_for_squadron(second_tie))
	assert_null(selector.get_state().defender_ship)
	assert_false(selector.has_declaration_candidate())


func test_illegal_selection_preserves_preview_and_reselect_deselects() -> void:
	var state: GameState = _make_replacement_state(false)
	_install_replacement_state(state)
	var composition: Dictionary = _make_composition(state)
	var selector: TargetSelector = composition["selector"]
	var executor: AttackExecutor = composition["executor"]
	var nebulon: ShipInstance = state.get_ship(0, 1)
	var victory: ShipInstance = state.get_ship(1, 0)
	var friendly: ShipInstance = state.get_ship(0, 0)
	var geometry: Dictionary = _replacement_geometry(state)
	assert_false(geometry.is_empty())

	executor.start_ship_attack(_token_for_ship(nebulon))
	selector._select_attacker_ship_zone(
			_token_for_ship(nebulon), int(geometry["attacker_zone"]))
	selector._try_select_target_ship_zone(
			_token_for_ship(victory), int(geometry["defender_zone"]))
	var candidate_before: Dictionary = selector.get_declaration_candidate()
	var cursor_before: int = CommandProcessor.get_next_sequence()

	selector._try_select_target_ship_zone(
			_token_for_ship(friendly), int(Constants.HullZone.FRONT))

	assert_eq(selector.get_declaration_candidate(), candidate_before)
	assert_true(state.current_attack_state.is_inactive())
	assert_eq(CommandProcessor.get_next_sequence(), cursor_before)
	assert_eq(_history_types(), [])
	assert_eq(selector.get_state().defender_ship, _token_for_ship(victory))

	selector._try_select_target_ship_zone(
			_token_for_ship(victory), int(geometry["defender_zone"]))
	assert_false(selector.has_declaration_candidate())
	assert_true(selector.get_panel()._skip_attack_button.visible)
	assert_false(selector.get_panel()._confirm_button.visible)


func test_network_client_keeps_confirmed_candidate_until_begin_result() -> void:
	var state: GameState = _make_replacement_state(false)
	_install_replacement_state(state)
	var composition: Dictionary = _make_composition(state)
	var selector: TargetSelector = composition["selector"]
	var executor: AttackExecutor = composition["executor"]
	var nebulon: ShipInstance = state.get_ship(0, 1)
	var tie: SquadronInstance = state.get_squadron(1, 0)
	var geometry: Dictionary = _replacement_geometry(state)
	assert_false(geometry.is_empty())

	executor.start_ship_attack(_token_for_ship(nebulon))
	selector._select_attacker_ship_zone(
			_token_for_ship(nebulon), int(geometry["attacker_zone"]))
	var submitter := AwaitingSubmitter.new()
	GameManager.set_command_submitter(submitter)
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 0
	selector._try_select_target_ship_zone(
			_token_for_ship(state.get_ship(1, 0)),
			int(geometry["defender_zone"]))
	selector._handle_target_squadron_click(_token_for_squadron(tie))
	var canonical_before: Dictionary = \
			state.current_attack_state.serialize()
	var history_before: Array[String] = _history_types()
	assert_true(submitter.submitted.is_empty(),
			"Preview replacement must not submit a semantic network command.")

	executor._on_declaration_confirm()

	assert_eq(submitter.submitted.size(), 1)
	assert_eq(submitter.submitted[0].command_type, BeginAttackCommand.TYPE)
	assert_eq(submitter.submitted[0].payload.get("defender_kind"),
			CurrentAttackState.KIND_SQUADRON)
	assert_eq(submitter.submitted[0].payload.get("defender_index"), 0)
	assert_eq(state.current_attack_state.serialize(), canonical_before)
	assert_eq(_history_types(), history_before)
	assert_true(selector.has_declaration_candidate())
	assert_true(selector.get_panel()._confirm_button.disabled)
	assert_true(selector.get_panel()._skip_attack_button.disabled)
	executor._on_declaration_confirm()
	executor._on_attack_skip()
	selector._try_select_target_ship_zone(
			_token_for_ship(state.get_ship(1, 0)),
			int(geometry["defender_zone"]))
	assert_eq(submitter.submitted.size(), 1,
			"Repeated Confirm, Skip, and replacement input must be gated.")
	assert_eq(selector.get_declaration_candidate().get("defender_index"), 0)

	var panel_controller := AttackPanelController.new()
	add_child_autofree(panel_controller)
	panel_controller.initialize(executor, null, selector)
	panel_controller.react_to_command_rejection(
			submitter.submitted[0], "Controlled network rejection.")
	assert_true(selector.has_declaration_candidate())
	assert_false(selector.get_panel()._confirm_button.disabled)
	assert_false(selector.get_panel()._skip_attack_button.disabled)
	executor._on_declaration_confirm()
	assert_eq(submitter.submitted.size(), 2,
			"Rejected network Begin must release the gate for a later command.")
	assert_eq(submitter.submitted[1].command_type, BeginAttackCommand.TYPE)


func _make_forensic_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SQUADRON
	state.initiative_player = 0
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SQUADRON_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT, 1)
	assert_true(state.initialize_squadron_phase_progress(1))
	state.get_player_state(0).faction = Constants.Faction.REBEL_ALLIANCE
	state.get_player_state(1).faction = Constants.Faction.GALACTIC_EMPIRE

	var cr90: ShipInstance = _make_ship(CR90_KEY, 0)
	_place_ship(cr90, Vector2(1850.0, 1850.0), 45.0)
	state.get_player_state(0).ships.append(cr90)
	var nebulon: ShipInstance = _make_ship(NEBULON_KEY, 0)
	nebulon.pos_x = FORENSIC_NEBULON_NORM.x
	nebulon.pos_y = FORENSIC_NEBULON_NORM.y
	nebulon.rotation_deg = 45.0
	state.get_player_state(0).ships.append(nebulon)
	var victory: ShipInstance = _make_ship(VICTORY_KEY, 1)
	_place_ship(victory, FORENSIC_VICTORY_PX, 135.0)
	state.get_player_state(1).ships.append(victory)

	for index: int in range(6):
		var tie: SquadronInstance = _make_squadron(TIE_KEY, 1)
		if index == 0:
			tie.pos_x = FORENSIC_TIE_0_NORM.x
			tie.pos_y = FORENSIC_TIE_0_NORM.y
		elif index == 5:
			_place_squadron(tie, COMPARISON_TIE_5_PX)
		else:
			_place_squadron(tie, Vector2(1900.0, 200.0 + index * 100.0))
		state.get_player_state(1).squadrons.append(tie)
	return state


func _make_bug_025_ship_state(defender_key: String,
		defender_position: Vector2, defender_rotation: float) -> GameState:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	state.current_round = 3
	state.current_phase = Constants.GamePhase.SHIP
	state.initiative_player = 1
	var defender: ShipInstance = _make_ship(defender_key, 0)
	_place_ship(defender, defender_position, defender_rotation)
	state.get_player_state(0).ships.append(defender)
	var attacker: ShipInstance = _make_ship(VICTORY_KEY, 1)
	_place_ship(attacker, BUG_025_VICTORY_PX, 157.5)
	assert_true(attacker.establish_ship_activation(
			"ship-activation:bug-025"))
	attacker.begin_attack_step()
	state.get_player_state(1).ships.append(attacker)
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ATTACK_STEP, 1,
			Constants.Visibility.ALL, {
				"ship_activation_identity": attacker.ship_activation_identity,
			})
	return state


func _make_distance_boundary_state(defender_kind: String,
		edge_distance_px: float) -> GameState:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SQUADRON
	state.initiative_player = 0
	assert_true(state.initialize_squadron_phase_progress(0))
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SQUADRON_ACTIVATION,
			Constants.InteractionStep.ACTION_CHOICE, 0)
	var attacker: SquadronInstance = _make_squadron(
			"x_wing_squadron", 0)
	var attacker_px := Vector2(700.0, 1000.0)
	_place_squadron(attacker, attacker_px)
	assert_true(attacker.initialize_activation_action_state(
			"squadron-activation:distance-boundary",
			SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE))
	state.get_player_state(0).squadrons.append(attacker)
	var squadron_radius: float = GameScale.squadron_base_diameter_px * 0.5
	if defender_kind == CurrentAttackState.KIND_SQUADRON:
		var defender: SquadronInstance = _make_squadron(
				"tie_fighter_squadron", 1)
		_place_squadron(defender, Vector2(
				attacker_px.x + GameScale.squadron_base_diameter_px \
						+ edge_distance_px,
				attacker_px.y))
		state.get_player_state(1).squadrons.append(defender)
	else:
		var defender: ShipInstance = _make_ship(CR90_KEY, 1)
		var defender_px := Vector2(1100.0, attacker_px.y)
		var base_size: Vector2 = GameScale.get_base_size(
				defender.ship_data.ship_size)
		attacker_px = Vector2(defender_px.x,
				defender_px.y - base_size.y * 0.5 \
						- squadron_radius - edge_distance_px)
		_place_squadron(attacker, attacker_px)
		_place_ship(defender, defender_px, 0.0)
		state.get_player_state(1).ships.append(defender)
	return state


func _make_declaration_skip_fixture(context: String) -> Dictionary:
	var state := GameState.new()
	state.initialize()
	assert_true(state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	state.current_round = 1
	if context == SkipAttackCommand.CONTEXT_SHIP_ATTACK:
		state.current_phase = Constants.GamePhase.SHIP
		var attacker: ShipInstance = _make_ship(VICTORY_KEY, 0)
		_place_ship(attacker, Vector2(1080.0, 1250.0), 0.0)
		assert_true(attacker.establish_ship_activation(
				"ship-activation:skip-matrix"))
		attacker.begin_attack_step()
		state.get_player_state(0).ships.append(attacker)
		var defender: ShipInstance = _make_ship(CR90_KEY, 1)
		_place_ship(defender, Vector2(1080.0, 900.0), 180.0)
		state.get_player_state(1).ships.append(defender)
		state.interaction_flow = InteractionFlow.make(
				Constants.InteractionFlow.SHIP_ACTIVATION,
				Constants.InteractionStep.ATTACK_STEP, 0)
		return {
			"state": state,
			"payload": {
				"reason": "voluntary",
				"declaration_context": context,
				"ship_index": 0,
				"ship_activation_identity": attacker.ship_activation_identity,
			},
		}
	var attacker_data: SquadronData = AssetLoader.load_squadron_data(
			"x_wing_squadron")
	if context == "rogue_squadron_phase":
		attacker_data.keywords.append({"name": "Rogue"})
	var attacker: SquadronInstance = SquadronInstance.create_from_data(
			"x_wing_squadron", attacker_data, 0)
	_place_squadron(attacker, Vector2(1000.0, 1000.0))
	state.get_player_state(0).squadrons.append(attacker)
	var defender: SquadronInstance = _make_squadron(TIE_KEY, 1)
	_place_squadron(defender, Vector2(1000.0, 850.0))
	state.get_player_state(1).squadrons.append(defender)
	var declaration_context: String = \
			SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE
	var ship_identity: String = ""
	if context \
			== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		state.current_phase = Constants.GamePhase.SHIP
		declaration_context = context
		var commanding_ship: ShipInstance = _make_ship(VICTORY_KEY, 0)
		_place_ship(commanding_ship, Vector2(1000.0, 1200.0), 0.0)
		var dials: Array[int] = []
		for _index: int in range(
				commanding_ship.command_dial_stack.get_dials_needed()):
			dials.append(Constants.CommandType.SQUADRON)
		assert_true(commanding_ship.command_dial_stack.assign_dials(dials, 1))
		assert_false(commanding_ship.command_dial_stack.reveal_top().is_empty())
		assert_true(commanding_ship.establish_ship_activation(
				"ship-activation:command-skip-matrix"))
		ship_identity = commanding_ship.ship_activation_identity
		assert_true(commanding_ship.open_squadron_command_opportunity(
				ship_identity))
		state.get_player_state(0).ships.append(commanding_ship)
		assert_true(attacker.initialize_activation_action_state(
				"squadron-activation:command-skip-matrix",
				declaration_context, 0, 0))
		assert_true(commanding_ship.commit_squadron_command_activation(
				ship_identity))
		state.interaction_flow = InteractionFlow.make(
				Constants.InteractionFlow.SHIP_ACTIVATION,
				Constants.InteractionStep.SQUADRON_STEP, 0)
	else:
		state.current_phase = Constants.GamePhase.SQUADRON
		assert_true(state.initialize_squadron_phase_progress(0))
		assert_true(attacker.initialize_activation_action_state(
				"squadron-activation:phase-skip-matrix",
				declaration_context))
		state.interaction_flow = InteractionFlow.make(
				Constants.InteractionFlow.SQUADRON_ACTIVATION,
				Constants.InteractionStep.ACTION_CHOICE, 0)
	var payload: Dictionary = {
		"reason": "voluntary",
		"declaration_context": declaration_context,
		"squadron_index": 0,
		"activation_id": attacker.activation_id,
		"activation_context": attacker.activation_context,
	}
	if not ship_identity.is_empty():
		payload["ship_activation_identity"] = ship_identity
	return {"state": state, "payload": payload}


func _declaration_skip_outcome(state: GameState, result: Dictionary,
		context: String) -> Dictionary:
	var flow: InteractionFlow = state.interaction_flow
	var outcome: Dictionary = {
		"result": result.duplicate(true),
		"flow": {
			"flow_type": int(flow.flow_type),
			"step_id": int(flow.step_id),
			"controller_player": flow.controller_player,
			"ship_activation_identity": str(flow.payload.get(
					"ship_activation_identity", "")),
			"activation_id": str(flow.payload.get("activation_id", "")),
		},
		"phase_controller": state.squadron_phase_controller_player,
		"phase_count": state.squadron_phase_activations_committed,
	}
	if context == SkipAttackCommand.CONTEXT_SHIP_ATTACK:
		var ship: ShipInstance = state.get_ship(0, 0)
		outcome["ship_boundary"] = ship.ship_activation_boundary_snapshot()
		outcome["attack_progress"] = ship.attack_progress_snapshot()
		return outcome
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	outcome["squadron_action"] = squadron.activation_action_state_snapshot()
	outcome["activated"] = squadron.activated_this_round
	outcome["movement_remains"] = squadron.has_remaining_move_action(
			context == "rogue_squadron_phase")
	if context \
			== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		outcome["ship_boundary"] = state.get_ship(
				0, 0).ship_activation_boundary_snapshot()
	return outcome


func _squadron_begin_payload(state: GameState,
		candidate: Dictionary) -> Dictionary:
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	var payload: Dictionary = {
		"attacker_player": 0,
		"attacker_kind": CurrentAttackState.KIND_SQUADRON,
		"attacker_index": 0,
		"attacker_zone": -1,
		"defender_player": int(candidate.get("target_owner", -1)),
		"defender_kind": str(candidate.get("target_kind", "")),
		"defender_index": int(candidate.get("target_index", -1)),
		"defender_zone": int(candidate.get("target_zone", -1)),
		"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
		"range_band": str(candidate.get("range_band", "")),
		"obstructed": bool(candidate.get("obstructed", false)),
		"dice_pool": (candidate.get("dice", {}) as Dictionary).duplicate(true),
		"activation_id": squadron.activation_id,
		"activation_context": squadron.activation_context,
	}
	if squadron.activation_context \
			== SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND:
		var commanding_ship: ShipInstance = state.get_ship(
				squadron.commanding_ship_player, squadron.commanding_ship_index)
		payload["ship_activation_identity"] = \
				commanding_ship.ship_activation_identity
	return payload


func _ship_begin_payload(state: GameState,
		candidate: Dictionary) -> Dictionary:
	var attacker: ShipInstance = state.get_ship(1, 0)
	return {
		"attacker_player": 1,
		"attacker_kind": CurrentAttackState.KIND_SHIP,
		"attacker_index": 0,
		"attacker_zone": int(candidate.get("attacker_zone", -1)),
		"defender_player": int(candidate.get("target_owner", -1)),
		"defender_kind": str(candidate.get("target_kind", "")),
		"defender_index": int(candidate.get("target_index", -1)),
		"defender_zone": int(candidate.get("target_zone", -1)),
		"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
		"range_band": str(candidate.get("range_band", "")),
		"obstructed": bool(candidate.get("obstructed", false)),
		"dice_pool": (candidate.get("dice", {}) as Dictionary).duplicate(true),
		"ship_activation_identity": attacker.ship_activation_identity,
	}


func _forged_close_only_begin_payload(state: GameState,
		defender_kind: String) -> Dictionary:
	var squadron: SquadronInstance = state.get_squadron(0, 0)
	return {
		"attacker_player": 0,
		"attacker_kind": CurrentAttackState.KIND_SQUADRON,
		"attacker_index": 0,
		"attacker_zone": -1,
		"defender_player": 1,
		"defender_kind": defender_kind,
		"defender_index": 0,
		"defender_zone": -1 \
				if defender_kind == CurrentAttackState.KIND_SQUADRON \
				else int(Constants.HullZone.FRONT),
		"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
		"range_band": Constants.RANGE_BAND_CLOSE,
		"obstructed": false,
		"activation_id": squadron.activation_id,
		"activation_context": squadron.activation_context,
	}


func _assert_production_distance_thresholds_are_distinct() -> void:
	assert_eq(GameScale.distance_bands_px[0], 181.0)
	assert_eq(GameScale.range_close_px, 292.0)
	assert_lt(GameScale.distance_bands_px[0], GameScale.range_close_px)
	assert_eq(GameScale.get_distance_band(179.0), 1)
	assert_eq(GameScale.get_distance_band(183.0), 2)
	assert_eq(GameScale.get_range_band(179.0), Constants.RANGE_BAND_CLOSE)
	assert_eq(GameScale.get_range_band(183.0), Constants.RANGE_BAND_CLOSE)


func _make_replacement_state(unique_target: bool) -> GameState:
	var state: GameState = _make_forensic_state()
	state.current_phase = Constants.GamePhase.SHIP
	state.clear_squadron_phase_progress()
	var attacker: ShipInstance = state.get_ship(0, 1)
	assert_true(attacker.establish_ship_activation(
			"ship-activation:replacement"))
	attacker.begin_attack_step()
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT, 0)
	if unique_target:
		var prior: SquadronInstance = state.get_squadron(1, 0)
		var unique: SquadronInstance = _make_squadron(HOWLRUNNER_KEY, 1)
		unique.pos_x = prior.pos_x
		unique.pos_y = prior.pos_y
		state.get_player_state(1).squadrons[0] = unique
	var comparison: SquadronInstance = state.get_squadron(1, 1)
	var first_target: SquadronInstance = state.get_squadron(1, 0)
	comparison.pos_x = first_target.pos_x + 0.005
	comparison.pos_y = first_target.pos_y + 0.005
	return state


func _replacement_geometry(state: GameState) -> Dictionary:
	var zone_order: Array[int] = [
		int(Constants.HullZone.RIGHT), int(Constants.HullZone.FRONT),
		int(Constants.HullZone.LEFT), int(Constants.HullZone.REAR),
	]
	for attacker_zone: int in zone_order:
		var squad_entry: Dictionary = \
				TargetingListBuilder.authoritative_attack_entry(
						state, 0, CurrentAttackState.KIND_SHIP, 1,
						attacker_zone, 1, CurrentAttackState.KIND_SQUADRON,
						0, -1)
		if squad_entry.is_empty():
			continue
		for defender_zone: int in range(4):
			var ship_entry: Dictionary = \
					TargetingListBuilder.authoritative_attack_entry(
							state, 0, CurrentAttackState.KIND_SHIP, 1,
							attacker_zone, 1, CurrentAttackState.KIND_SHIP,
							0, defender_zone)
			if not ship_entry.is_empty():
				return {
					"attacker_zone": attacker_zone,
					"defender_zone": defender_zone,
				}
	return {}


func _make_ship(key: String, owner: int) -> ShipInstance:
	return ShipInstance.create_from_data(
			key, AssetLoader.load_ship_data(key), 2, owner)


func _make_squadron(key: String, owner: int) -> SquadronInstance:
	return SquadronInstance.create_from_data(
			key, AssetLoader.load_squadron_data(key), owner)


func _place_ship(ship: ShipInstance, pixel_pos: Vector2,
		rotation_deg: float) -> void:
	ship.pos_x = pixel_pos.x / GameScale.play_area_size_px.x
	ship.pos_y = pixel_pos.y / GameScale.play_area_size_px.y
	ship.rotation_deg = rotation_deg


func _place_squadron(squadron: SquadronInstance,
		pixel_pos: Vector2) -> void:
	squadron.pos_x = pixel_pos.x / GameScale.play_area_size_px.x
	squadron.pos_y = pixel_pos.y / GameScale.play_area_size_px.y


func _install_state(state: GameState) -> void:
	GameManager.current_game_state = state
	GameManager.is_game_active = true
	GameManager.active_player = 1
	GameManager.set_command_submitter(LocalCommandSubmitter.new(
			state.principal_id_for_player(GameManager.active_player)))
	GameManager._activating_squadron = null
	GameManager._squadrons_activated_this_turn = 0


func _install_replacement_state(state: GameState) -> void:
	_install_state(state)
	GameManager.active_player = 0


func _make_composition(state: GameState) -> Dictionary:
	var container := Node2D.new()
	add_child_autofree(container)
	for player_index: int in range(Constants.PLAYER_COUNT):
		var player_state: PlayerState = state.get_player_state(player_index)
		for ship: ShipInstance in player_state.ships:
			var ship_token: ShipToken = \
					SHIP_TOKEN_SCENE.instantiate() as ShipToken
			container.add_child(ship_token)
			ship_token.setup(TokenPlacement.new(
					ship.data_key, true, ship.ship_data.faction,
					ship.pos_x, ship.pos_y, ship.get_rotation_rad(),
					ship.ship_data.ship_size))
			ship_token.bind_instance(ship)
			_ship_tokens.append(ship_token)
		for squadron: SquadronInstance in player_state.squadrons:
			var squadron_token: SquadronToken = \
					SQUADRON_TOKEN_SCENE.instantiate() as SquadronToken
			container.add_child(squadron_token)
			squadron_token.setup(TokenPlacement.new(
					squadron.data_key, false, squadron.squadron_data.faction,
					squadron.pos_x, squadron.pos_y,
					squadron.get_rotation_rad()))
			squadron_token.bind_instance(squadron)
			_squadron_tokens.append(squadron_token)

	var selector := TargetSelector.new()
	add_child_autofree(selector)
	selector.initialize(_get_ship_tokens, _get_squadron_tokens,
			container, null, AttackState.new(), AttackDiceResolver.new())
	var executor := AttackExecutor.new()
	add_child_autofree(executor)
	executor.initialize(selector, null)
	var controller := SquadronPhaseController.new()
	add_child_autofree(controller)
	controller.initialize(
			container, _get_squadron_tokens,
			func(token: SquadronToken) -> void:
				executor.start_squadron_attack(token),
			func() -> void: pass,
			func(_token: SquadronToken, _position: Vector2) -> void: pass)
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	controller.create_ui(layer, _register_resizable)
	executor.attack_exec_completed.connect(controller.notify_attack_completed)
	executor.attack_exec_cancelled.connect(controller.notify_attack_cancelled)
	return {
		"controller": controller,
		"selector": selector,
		"executor": executor,
	}


func _activate_through_controller(controller: SquadronPhaseController,
		token: SquadronToken) -> void:
	controller.begin_activation_flow()
	assert_true(controller.try_handle_squadron_click(token),
			"Real modal/controller activation should accept the selected TIE.")
	assert_eq(controller.get_modal().get_state(),
			SquadronActivationModal.State.ACTION_CHOICE)


func _register_resizable(_widget: Control, _method: StringName,
		_only_visible: bool) -> void:
	pass


func _get_ship_tokens() -> Array[ShipToken]:
	return _ship_tokens


func _get_squadron_tokens() -> Array[SquadronToken]:
	return _squadron_tokens


func _token_for_ship(ship: ShipInstance) -> ShipToken:
	for token: ShipToken in _ship_tokens:
		if token.get_ship_instance() == ship:
			return token
	return null


func _token_for_squadron(squadron: SquadronInstance) -> SquadronToken:
	for token: SquadronToken in _squadron_tokens:
		if token.get_squadron_instance() == squadron:
			return token
	return null


func _nebulon_zones(candidates: Array[Dictionary]) -> Array[int]:
	var zones: Array[int] = []
	for candidate: Dictionary in candidates:
		if int(candidate.get("target_owner", -1)) == 0 \
				and str(candidate.get("target_kind", "")) \
						== CurrentAttackState.KIND_SHIP \
				and int(candidate.get("target_index", -1)) == 1:
			zones.append(int(candidate.get("target_zone", -1)))
	zones.sort()
	return zones


func _ship_target_candidates(candidates: Array[Dictionary],
		attacker_zone: Constants.HullZone,
		target_owner: int, target_index: int) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for candidate: Dictionary in candidates:
		if int(candidate.get("attacker_zone", -1)) != int(attacker_zone):
			continue
		if str(candidate.get("target_kind", "")) \
				!= CurrentAttackState.KIND_SHIP:
			continue
		if int(candidate.get("target_owner", -1)) != target_owner:
			continue
		if int(candidate.get("target_index", -1)) != target_index:
			continue
		matches.append(candidate)
	return matches


func _register_controlled_begin_blocker() -> void:
	RuleRegistry.register_validator(FlowHook.validator(
			"test.slice8a.begin_rejection",
			Constants.InteractionFlow.SQUADRON_ACTIVATION,
			Constants.InteractionStep.ACTION_CHOICE,
			BeginAttackCommand.TYPE,
			func(_state: GameState, _command: GameCommand) -> Dictionary:
				return {
					"allowed": false,
					"reason": "Controlled Begin rejection.",
				},
			1000))


func _register_controlled_declaration_skip_blocker() -> void:
	RuleRegistry.register_validator(FlowHook.validator(
			"test.attack.declaration_skip_rejection",
			Constants.InteractionFlow.SQUADRON_ACTIVATION,
			Constants.InteractionStep.ACTION_CHOICE,
			"skip_attack",
			func(_state: GameState, _command: GameCommand) -> Dictionary:
				return {
					"allowed": false,
					"reason": "Controlled declaration Skip rejection.",
				},
			1000))


func _history_types() -> Array[String]:
	var result: Array[String] = []
	for command: GameCommand in CommandProcessor.get_history():
		result.append(command.command_type)
	return result
