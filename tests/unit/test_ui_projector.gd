## Unit tests for [UIProjector] (Phase I4 pilot — HUD).
extends GutTest


func _make_state_with_flow(flow_type: Constants.InteractionFlow,
		controller: int) -> GameState:
	var gs: GameState = GameState.new()
	gs.interaction_flow = InteractionFlow.make(
			flow_type,
			Constants.InteractionStep.NONE,
			controller,
			Constants.Visibility.ALL,
			{})
	return gs


func _make_state_with_flow_step(flow_type: Constants.InteractionFlow,
		step_id: Constants.InteractionStep,
		controller: int,
		payload: Dictionary = {}) -> GameState:
	var gs: GameState = GameState.new()
	gs.interaction_flow = InteractionFlow.make(
			flow_type,
			step_id,
			controller,
			Constants.Visibility.ALL,
			payload)
	return gs


func _make_identity_state(
		player_zero_faction: Constants.Faction,
		player_one_faction: Constants.Faction) -> GameState:
	var gs: GameState = GameState.new()
	gs.initialize()
	gs.get_player_state(0).faction = player_zero_faction
	gs.get_player_state(1).faction = player_one_faction
	return gs


# ---------------------------------------------------------------------------
# Empty / null
# ---------------------------------------------------------------------------

func test_null_state_returns_empty_intent() -> void:
	var intent: UIProjector.UIIntent = UIProjector.project(null, 0)
	assert_eq(intent.hud_status_text, "")
	assert_false(intent.is_interactive)
	assert_eq(intent.controller_player, -1)


func test_no_flow_returns_empty_intent() -> void:
	var gs: GameState = GameState.new()
	# Default interaction_flow is empty (flow_type == NONE).
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
	assert_eq(intent.hud_status_text, "")
	assert_false(intent.is_interactive)


# ---------------------------------------------------------------------------
# Controller / opponent wording
# ---------------------------------------------------------------------------

func test_controller_viewer_sees_make_your_choices() -> void:
	var gs: GameState = _make_state_with_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION, 0)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
	assert_eq(intent.hud_status_text, "make your choices")
	assert_true(intent.is_interactive)
	assert_eq(intent.controller_player, 0)


func test_project_controller_identity_from_state_expected() -> void:
	var gs: GameState = _make_identity_state(
			Constants.Faction.GALACTIC_EMPIRE,
			Constants.Faction.REBEL_ALLIANCE)
	gs.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.NONE,
			0,
			Constants.Visibility.ALL,
			{})

	var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)

	assert_eq(intent.controller_player_label, "Galactic Empire Player",
			"Projected flow identity should use the controller's faction.")
	assert_eq(intent.controller_player_faction,
			int(Constants.Faction.GALACTIC_EMPIRE),
			"Projected flow identity should carry the controller faction enum.")


func test_setup_projection_uses_setup_display_name_expected() -> void:
	var gs: GameState = _make_identity_state(
			Constants.Faction.GALACTIC_EMPIRE,
			Constants.Faction.REBEL_ALLIANCE)
	gs.current_phase = Constants.GamePhase.SETUP
	gs.objectives = {
		FleetSetupBootstrapper.KEY_SETUP_PACKAGE_HASH: "hash",
		FleetSetupBootstrapper.KEY_SETUP_STATE: {
			"player_display_names": ["Alex", "Blake"],
		},
	}
	gs.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SETUP,
			Constants.InteractionStep.SETUP_OBSTACLE_PLACEMENT,
			1,
			Constants.Visibility.ALL,
			{"controller_player": 1})

	var intent: UIProjector.UIIntent = UIProjector.project(gs, 1)

	assert_eq(intent.controller_player_label, "Blake",
			"Setup projection should use serialized setup display names.")


func test_opponent_viewer_sees_waiting() -> void:
	var gs: GameState = _make_state_with_flow(
			Constants.InteractionFlow.SHIP_ACTIVATION, 0)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 1)
	assert_eq(intent.hud_status_text, "waiting for opponent's choice")
	assert_false(intent.is_interactive)
	assert_eq(intent.controller_player, 0)


func test_controller_minus_one_returns_empty_status() -> void:
	# Some flows (e.g. STATUS_CLEANUP) have no human controller.
	var gs: GameState = _make_state_with_flow(
			Constants.InteractionFlow.STATUS_CLEANUP, -1)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
	assert_eq(intent.hud_status_text, "")
	assert_false(intent.is_interactive)


# ---------------------------------------------------------------------------
# Command phase: both players see same prompt
# ---------------------------------------------------------------------------

func test_command_phase_player_zero_sees_make_your_choices() -> void:
	var gs: GameState = _make_state_with_flow(
			Constants.InteractionFlow.COMMAND_PHASE, 0)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
	assert_eq(intent.hud_status_text, "make your choices")


func test_command_phase_player_one_also_sees_make_your_choices() -> void:
	# In COMMAND phase the controller field names "the active dial-author"
	# but both players choose simultaneously; both see the prompt.
	var gs: GameState = _make_state_with_flow(
			Constants.InteractionFlow.COMMAND_PHASE, 0)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 1)
	assert_eq(intent.hud_status_text, "make your choices")


# ---------------------------------------------------------------------------
# Attack flow
# ---------------------------------------------------------------------------

func test_attack_attacker_viewer_is_interactive() -> void:
	var gs: GameState = _make_state_with_flow(
			Constants.InteractionFlow.ATTACK, 0)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
	assert_true(intent.is_interactive)
	assert_eq(intent.hud_status_text, "make your choices")


func test_attack_defender_viewer_is_passive() -> void:
	# Defender is the controller during DEFENSE_TOKENS step.
	var gs: GameState = _make_state_with_flow(
			Constants.InteractionFlow.ATTACK, 1)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
	assert_false(intent.is_interactive)
	assert_eq(intent.hud_status_text, "waiting for opponent's choice")


# ---------------------------------------------------------------------------
# UIIntent default values
# ---------------------------------------------------------------------------

func test_default_intent_values() -> void:
	var intent: UIProjector.UIIntent = UIProjector.UIIntent.new()
	assert_eq(intent.hud_status_text, "")
	assert_false(intent.is_interactive)
	assert_eq(intent.controller_player, -1)
	assert_eq(intent.flow_type, Constants.InteractionFlow.NONE)
	assert_eq(intent.step_id, Constants.InteractionStep.NONE)
	assert_eq(intent.modal_kind, Constants.ModalKind.NONE)
	assert_eq(intent.payload, {})
	assert_eq(intent.affordances, {})
	assert_eq(intent.perspective_player, -1)
	assert_eq(intent.perspective_player_label, "")
	assert_eq(intent.perspective_player_faction, -1)
	assert_eq(intent.controller_player_label, "")
	assert_eq(intent.controller_player_faction, -1)
	assert_false(intent.needs_handoff_overlay)
	assert_false(intent.needs_turn_banner)
	assert_false(intent.needs_waiting_overlay)
	assert_false(intent.should_begin_command_dial_flow)
	assert_false(intent.should_begin_passive_squadron_observer)


# ---------------------------------------------------------------------------
# Phase L5 — active-player turn-transition projection
# ---------------------------------------------------------------------------

func test_turn_transition_shared_command_projects_handoff() -> void:
	var gs: GameState = _make_identity_state(
			Constants.Faction.GALACTIC_EMPIRE,
			Constants.Faction.REBEL_ALLIANCE)
	var intent: UIProjector.UIIntent = UIProjector.project_turn_transition(
			Constants.GamePhase.COMMAND, 0, 0, true, gs)
	assert_eq(intent.controller_player_label, "Galactic Empire Player",
			"Shared-screen handoff should name the active player's faction.")
	assert_eq(intent.controller_player_faction,
			int(Constants.Faction.GALACTIC_EMPIRE),
			"Shared-screen handoff should carry the active player's faction.")
	assert_eq(intent.perspective_player_label, "Galactic Empire Player",
			"Shared-screen perspective label should follow the active player.")
	assert_eq(intent.perspective_player, 0,
			"Shared screen should rotate to the active player.")
	assert_true(intent.needs_handoff_overlay,
			"Command Phase shared-screen transition should show handoff.")
	assert_false(intent.should_begin_command_dial_flow,
			"Shared-screen command dial flow waits for handoff acceptance.")
	assert_eq(intent.hud_status_text, "",
			"Shared-screen handoff should not render network status text.")


func test_turn_transition_network_command_starts_dial_flow() -> void:
	var gs: GameState = _make_identity_state(
			Constants.Faction.GALACTIC_EMPIRE,
			Constants.Faction.REBEL_ALLIANCE)
	var intent: UIProjector.UIIntent = UIProjector.project_turn_transition(
			Constants.GamePhase.COMMAND, 0, 1, false, gs)
	assert_eq(intent.perspective_player, 1,
			"Network peer should stay pinned to its local perspective.")
	assert_eq(intent.controller_player_label, "Galactic Empire Player",
			"Network transition should name the active player from state.")
	assert_eq(intent.perspective_player_label, "Rebel Alliance Player",
			"Network perspective label should name the local viewer from state.")
	assert_false(intent.needs_handoff_overlay,
			"Network command transition should not show shared-screen handoff.")
	assert_true(intent.should_begin_command_dial_flow,
			"Network command transition should start the local dial flow.")
	assert_eq(intent.hud_status_text, "make your choices",
			"Both players choose dials during Command Phase.")


func test_turn_transition_network_passive_squadron_waits() -> void:
	var intent: UIProjector.UIIntent = UIProjector.project_turn_transition(
			Constants.GamePhase.SQUADRON, 0, 1, false)
	assert_false(intent.is_interactive,
			"Passive network peer should not be interactive.")
	assert_true(intent.needs_waiting_overlay,
			"Passive network peer should project a waiting state.")
	assert_true(intent.should_begin_passive_squadron_observer,
			"Passive Squadron peer should mirror the Squadron modal state.")
	assert_eq(intent.hud_status_text, "waiting for opponent's choice")


func test_turn_transition_network_active_ship_projects_banner() -> void:
	var intent: UIProjector.UIIntent = UIProjector.project_turn_transition(
			Constants.GamePhase.SHIP, 0, 0, false)
	assert_true(intent.is_interactive,
			"Active network peer should be interactive.")
	assert_true(intent.needs_turn_banner,
			"Active network peer should see the turn banner.")
	assert_false(intent.needs_waiting_overlay,
			"Active network peer should not project waiting state.")
	assert_eq(intent.hud_status_text, "make your choices")


# ---------------------------------------------------------------------------
# Phase I6b — flow_type / step_id / modal_kind / payload projection
# ---------------------------------------------------------------------------

func test_no_flow_modal_kind_is_none() -> void:
	var gs: GameState = GameState.new()
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
	assert_eq(intent.modal_kind, Constants.ModalKind.NONE)
	assert_eq(intent.flow_type, Constants.InteractionFlow.NONE)
	assert_eq(intent.payload, {})


func test_command_phase_modal_kind_is_command_dials() -> void:
	var gs: GameState = _make_state_with_flow_step(
			Constants.InteractionFlow.COMMAND_PHASE,
			Constants.InteractionStep.SELECT_DIALS, 0)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
	assert_eq(intent.modal_kind, Constants.ModalKind.COMMAND_DIALS)
	assert_eq(intent.flow_type, Constants.InteractionFlow.COMMAND_PHASE)
	assert_eq(intent.step_id, Constants.InteractionStep.SELECT_DIALS)


func test_ship_activation_modal_open_maps_to_activation() -> void:
	var gs: GameState = _make_state_with_flow_step(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN, 0)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
	assert_eq(intent.modal_kind, Constants.ModalKind.ACTIVATION)


func test_ship_activation_substeps_map_to_activation() -> void:
	for step in [
			Constants.InteractionStep.REVEAL_DIAL,
			Constants.InteractionStep.SPEND_DIAL,
			Constants.InteractionStep.MANEUVER_STEP,
			Constants.InteractionStep.REPAIR_STEP,
			Constants.InteractionStep.ATTACK_STEP,
			Constants.InteractionStep.ACTIVATION_DONE]:
		var gs: GameState = _make_state_with_flow_step(
				Constants.InteractionFlow.SHIP_ACTIVATION, step, 0)
		var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
		assert_eq(intent.modal_kind, Constants.ModalKind.ACTIVATION,
				"Step %d should project to ACTIVATION." % step)


func test_wait_for_ship_select_has_no_modal() -> void:
	var gs: GameState = _make_state_with_flow_step(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT, 0)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
	assert_eq(intent.modal_kind, Constants.ModalKind.NONE)
	assert_false(intent.affordances.has("activation_sequence_button"),
			"Waiting for ship select should not project the sequence button.")


func test_ship_activation_squadron_step_maps_to_squadron_modal() -> void:
	var gs: GameState = _make_state_with_flow_step(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.SQUADRON_STEP, 0)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
	assert_eq(intent.modal_kind, Constants.ModalKind.SQUADRON,
			"SQUADRON_STEP should project the command-mode squadron modal.")
	assert_true(bool(intent.affordances.get(
			"activation_sequence_button", false)),
			"Ship activation should project the sequence-button affordance.")


func test_ship_activation_affordance_visible_to_observer() -> void:
	var gs: GameState = _make_state_with_flow_step(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN, 0)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 1)
	assert_false(intent.is_interactive,
			"Observer should not control the activation modal.")
	assert_true(bool(intent.affordances.get(
			"activation_sequence_button", false)),
			"Common activation modals should remain reopenable by observers.")


func test_squadron_flow_maps_to_squadron() -> void:
	var gs: GameState = _make_state_with_flow_step(
			Constants.InteractionFlow.SQUADRON_ACTIVATION,
			Constants.InteractionStep.ACTION_CHOICE, 1)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 1)
	assert_eq(intent.modal_kind, Constants.ModalKind.SQUADRON)


func test_wait_for_squad_select_has_no_modal() -> void:
	var gs: GameState = _make_state_with_flow_step(
			Constants.InteractionFlow.SQUADRON_ACTIVATION,
			Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT, 1)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 1)
	assert_eq(intent.modal_kind, Constants.ModalKind.NONE)


func test_attack_steps_each_map_to_dedicated_modal_kind() -> void:
	var pairs: Array = [
			[Constants.InteractionStep.ATTACK_DECLARE,
					Constants.ModalKind.ATTACK_DECLARE],
			[Constants.InteractionStep.ATTACK_ROLL,
					Constants.ModalKind.ATTACK_ROLL],
			[Constants.InteractionStep.ATTACK_MODIFY,
					Constants.ModalKind.ATTACK_MODIFY],
			[Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
					Constants.ModalKind.ATTACK_DEFENSE_TOKENS],
			[Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
					Constants.ModalKind.ATTACK_RESOLVE_DAMAGE],
			[Constants.InteractionStep.ATTACK_COUNTER_CHOICE,
					Constants.ModalKind.ATTACK_COUNTER_CHOICE],
			[Constants.InteractionStep.ATTACK_CRITICAL_CHOICE,
					Constants.ModalKind.ATTACK_CRITICAL_CHOICE]]
	for pair in pairs:
		var gs: GameState = _make_state_with_flow_step(
				Constants.InteractionFlow.ATTACK, pair[0], 0)
		var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
		assert_eq(intent.modal_kind, pair[1],
				"Step %d should project to modal_kind %d." % [pair[0], pair[1]])


func test_status_cleanup_and_game_over_map_correctly() -> void:
	var gs1: GameState = _make_state_with_flow_step(
			Constants.InteractionFlow.STATUS_CLEANUP,
			Constants.InteractionStep.STATUS_CLEANUP_STEP, -1)
	assert_eq(UIProjector.project(gs1, 0).modal_kind,
			Constants.ModalKind.STATUS_CLEANUP)
	var gs2: GameState = _make_state_with_flow_step(
			Constants.InteractionFlow.GAME_OVER,
			Constants.InteractionStep.GAME_OVER_STEP, -1)
	assert_eq(UIProjector.project(gs2, 0).modal_kind,
			Constants.ModalKind.GAME_OVER)


func test_setup_modal_steps_map_correctly() -> void:
	var pairs: Array = [
			[Constants.InteractionStep.SETUP_OBSTACLE_PLACEMENT,
					Constants.ModalKind.SETUP_OBSTACLE_PLACEMENT],
			[Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT,
					Constants.ModalKind.SETUP_SHIP_DEPLOYMENT],
			[Constants.InteractionStep.SETUP_SQUADRON_DEPLOYMENT,
					Constants.ModalKind.SETUP_SQUADRON_DEPLOYMENT],
			[Constants.InteractionStep.SETUP_REVIEW,
					Constants.ModalKind.SETUP_REVIEW],
	]
	for pair in pairs:
		var gs: GameState = _make_state_with_flow_step(
				Constants.InteractionFlow.SETUP, pair[0], 0)
		var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
		assert_eq(intent.modal_kind, pair[1],
				"Setup step %d should map to the expected setup modal." % pair[0])


func test_payload_is_deep_copied_into_intent() -> void:
	# Defense-token step payload mirrors what AttackFlowFSM publishes.
	var payload: Dictionary = {
			"locked_tokens": [Constants.DefenseToken.BRACE],
			"modified_damage": 4,
			"defender_player": 1,
			"dice_pool": [ {"color": "red", "face": "hit"}]}
	var gs: GameState = _make_state_with_flow_step(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS, 1, payload)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 1)
	assert_eq(intent.payload["modified_damage"], 4)
	assert_eq(intent.payload["defender_player"], 1)
	assert_eq(intent.payload["locked_tokens"].size(), 1)
	# Mutating the projected payload must not bleed into the flow.
	intent.payload["modified_damage"] = 999
	assert_eq(gs.interaction_flow.payload["modified_damage"], 4,
			"Projector must deep-copy payload to keep flow immutable.")
	# Mutating a nested array similarly.
	intent.payload["dice_pool"].append({"color": "black"})
	assert_eq(gs.interaction_flow.payload["dice_pool"].size(), 1,
			"Projector must deep-copy nested arrays.")


# ---------------------------------------------------------------------------
# Squadron displacement (Phase I6b-4b)
# ---------------------------------------------------------------------------

func test_squadron_displacement_maps_to_displacement_modal() -> void:
	var gs: GameState = _make_state_with_flow_step(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE,
			1,
			{"ship_index": 0, "displaced_squadrons": [
					{"owner": 1, "squadron_index": 0}]})
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 1)
	assert_eq(intent.modal_kind, Constants.ModalKind.DISPLACEMENT,
			"SQUADRON_DISPLACEMENT should project to ModalKind.DISPLACEMENT.")
	assert_eq(intent.flow_type,
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			"flow_type should be exposed on the intent.")
	assert_true(intent.is_interactive,
			"Controller (squadron owner) is interactive.")


func test_squadron_displacement_non_controller_is_not_interactive() -> void:
	var gs: GameState = _make_state_with_flow_step(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE,
			1,
			{"ship_index": 0, "displaced_squadrons": [
					{"owner": 1, "squadron_index": 0}]})
	# Maneuvering peer (player 0) should still see the modal kind so it
	# can render a "waiting" mirror, but is_interactive is false.
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 0)
	assert_eq(intent.modal_kind, Constants.ModalKind.DISPLACEMENT,
			"Modal kind is independent of viewer.")
	assert_false(intent.is_interactive,
			"Maneuvering peer is not interactive during displacement.")
	assert_eq(intent.hud_status_text, "waiting for opponent's choice",
			"Maneuvering peer waits for opponent during displacement.")


func test_squadron_displacement_payload_round_trip() -> void:
	var payload: Dictionary = {
			"ship_index": 2,
			"displaced_squadrons": [
					{"owner": 1, "squadron_index": 0},
					{"owner": 1, "squadron_index": 1}]}
	var gs: GameState = _make_state_with_flow_step(
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE,
			1, payload)
	var intent: UIProjector.UIIntent = UIProjector.project(gs, 1)
	assert_eq(int(intent.payload.get("ship_index", -1)), 2,
			"ship_index should be carried through the projection.")
	var sq_list: Array = (
			intent.payload.get("displaced_squadrons", []) as Array)
	assert_eq(sq_list.size(), 2,
			"displaced_squadrons should be projected.")
