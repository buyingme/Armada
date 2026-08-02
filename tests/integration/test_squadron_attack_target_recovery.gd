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


func test_exact_owner_local_ties_have_distinct_nebulon_legality() -> void:
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
	assert_eq(_nebulon_zones(tie_0_candidates), [],
			"Forensic TIE index 0 has no legal Nebulon hull zone.")
	assert_eq(_nebulon_zones(tie_5_candidates), [
			int(Constants.HullZone.FRONT), int(Constants.HullZone.RIGHT)],
			"Identical TIE index 5 retains legal FRONT/RIGHT candidates.")

	var all_squads: Array[Dictionary] = \
			controller._build_all_squadron_positions()
	var obstruction_bodies: Array = controller._build_obstruction_bodies()
	assert_false(controller._squadron_has_valid_targets(
			tie_0, _token_for_squadron(tie_0), all_squads,
			obstruction_bodies))
	assert_true(controller._squadron_has_valid_targets(
			tie_5, _token_for_squadron(tie_5), all_squads,
			obstruction_bodies))


func test_production_selection_never_previews_non_candidate_nebulon_zone() -> void:
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
	assert_false(modal._attack_button.visible,
			"Action availability must fail closed for exact TIE index 0.")
	var enclosing_flow: Dictionary = state.interaction_flow.serialize()

	# Exercise the same production composition defensively even if a stale
	# caller attempted to enter attack selection despite the hidden action.
	executor.start_squadron_attack(tie_0_token)
	selector._try_select_target_ship_zone(
			nebulon_token, Constants.HullZone.FRONT)
	selector._try_select_target_ship_zone(
			nebulon_token, Constants.HullZone.RIGHT)

	assert_false(selector.has_declaration_candidate())
	assert_null(selector.get_state().defender_ship)
	assert_true(state.current_attack_state.is_inactive())
	assert_false(state.timing_window_state.active)
	assert_eq(state.interaction_flow.serialize(), enclosing_flow,
			"Transient target selection must not replace enclosing flow.")
	assert_eq(CommandProcessor.get_next_sequence(), 116)
	assert_eq(_history_types(), ["activate_squadron"])


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
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SQUADRON
	state.initiative_player = 0
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SQUADRON_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT, 1)
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


func _make_replacement_state(unique_target: bool) -> GameState:
	var state: GameState = _make_forensic_state()
	state.current_phase = Constants.GamePhase.SHIP
	state.get_ship(0, 1).begin_attack_step()
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
