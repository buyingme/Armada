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
