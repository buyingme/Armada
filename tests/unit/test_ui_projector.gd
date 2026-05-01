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
			Constants.InteractionStep.SQUADRON_STEP,
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
