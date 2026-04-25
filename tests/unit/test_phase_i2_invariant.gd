## Invariant test for Phase I2: each command's [code]execute()[/code] must
## populate [code]GameState.interaction_flow[/code] with the same flow_type /
## step_id / controller / payload that the legacy
## [code]_publish_interaction_state_for_command()[/code] producer in
## [GameManager] would have emitted.
##
## Once Phase I6 lands and the legacy producer is deleted, this test deletes
## with it.  Until then it is the safety net guaranteeing the new path
## stays in lock-step with the old.
##
## See [code]docs/refactoring_phase_i_plan.md[/code] §I2.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers — set up minimal viable state
# ---------------------------------------------------------------------------

func _make_state(phase: Constants.GamePhase = Constants.GamePhase.SHIP,
		initiative: int = 0) -> GameState:
	var s: GameState = GameState.new()
	s.initialize()
	s.current_phase = phase
	s.initiative_player = initiative
	return s


func _make_ship_with_dial(state: GameState, player: int,
		command: int = Constants.CommandType.SQUADRON) -> int:
	# Build a minimal ShipInstance with a single hidden dial.
	var ship: ShipInstance = ShipInstance.new()
	ship.owner_player = player
	ship.activated_this_round = false
	ship.command_dial_stack = CommandDialStack.create(1)
	ship.command_dial_stack.assign_dials([command], 1)
	ship.command_tokens = CommandTokenManager.new()
	state.player_states[player].ships.append(ship)
	return state.player_states[player].ships.size() - 1


# ---------------------------------------------------------------------------
# AdvancePhaseCommand
# ---------------------------------------------------------------------------

func test_advance_phase_to_ship_sets_wait_for_ship_select() -> void:
	var s: GameState = _make_state(Constants.GamePhase.COMMAND, 1)
	var cmd: AdvancePhaseCommand = AdvancePhaseCommand.new(0,
			{"next_phase": int(Constants.GamePhase.SHIP)})
	cmd.execute(s)
	assert_eq(s.interaction_flow.flow_type,
			Constants.InteractionFlow.SHIP_ACTIVATION)
	assert_eq(s.interaction_flow.step_id,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT)
	assert_eq(s.interaction_flow.controller_player, 1,
			"Controller must be initiative_player.")


func test_advance_phase_to_squadron_sets_wait_for_squad_select() -> void:
	var s: GameState = _make_state(Constants.GamePhase.SHIP, 0)
	var cmd: AdvancePhaseCommand = AdvancePhaseCommand.new(0,
			{"next_phase": int(Constants.GamePhase.SQUADRON)})
	cmd.execute(s)
	assert_eq(s.interaction_flow.flow_type,
			Constants.InteractionFlow.SQUADRON_ACTIVATION)
	assert_eq(s.interaction_flow.step_id,
			Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT)
	assert_eq(s.interaction_flow.controller_player, 0)


func test_advance_phase_to_status_does_not_change_flow() -> void:
	var s: GameState = _make_state(Constants.GamePhase.SQUADRON, 0)
	var cmd: AdvancePhaseCommand = AdvancePhaseCommand.new(0,
			{"next_phase": int(Constants.GamePhase.STATUS)})
	cmd.execute(s)
	# Legacy producer also did not emit for this transition.
	assert_eq(s.interaction_flow.flow_type, Constants.InteractionFlow.NONE,
			"STATUS phase should not produce a flow update yet.")


# ---------------------------------------------------------------------------
# ActivateShipCommand
# ---------------------------------------------------------------------------

func test_activate_ship_sets_activation_modal_open() -> void:
	var s: GameState = _make_state()
	var idx: int = _make_ship_with_dial(s, 0)
	var cmd: ActivateShipCommand = ActivateShipCommand.new(0,
			{"ship_index": idx})
	cmd.execute(s)
	assert_eq(s.interaction_flow.flow_type,
			Constants.InteractionFlow.SHIP_ACTIVATION)
	assert_eq(s.interaction_flow.step_id,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN)
	assert_eq(s.interaction_flow.controller_player, 0)
	assert_eq(s.interaction_flow.payload.get("ship_index", -1), idx)


# ---------------------------------------------------------------------------
# ConvertDialToTokenCommand
# ---------------------------------------------------------------------------

func test_convert_dial_to_token_sets_activation_modal_open() -> void:
	var s: GameState = _make_state()
	var idx: int = _make_ship_with_dial(s, 1, Constants.CommandType.NAVIGATE)
	var cmd: ConvertDialToTokenCommand = ConvertDialToTokenCommand.new(1,
			{"ship_index": idx})
	cmd.execute(s)
	assert_eq(s.interaction_flow.flow_type,
			Constants.InteractionFlow.SHIP_ACTIVATION)
	assert_eq(s.interaction_flow.step_id,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN)
	assert_eq(s.interaction_flow.controller_player, 1)
	assert_eq(s.interaction_flow.payload.get("ship_index", -1), idx)


# ---------------------------------------------------------------------------
# ExecuteManeuverCommand
# ---------------------------------------------------------------------------

func test_execute_maneuver_sets_maneuver_step() -> void:
	var s: GameState = _make_state()
	var idx: int = _make_ship_with_dial(s, 0)
	var cmd: ExecuteManeuverCommand = ExecuteManeuverCommand.new(0, {
		"ship_index": idx,
		"speed": 1,
		"yaw_clicks": [0],
		"pos_x": 0.5,
		"pos_y": 0.5,
		"rotation_deg": 0.0,
	})
	cmd.execute(s)
	assert_eq(s.interaction_flow.flow_type,
			Constants.InteractionFlow.SHIP_ACTIVATION)
	assert_eq(s.interaction_flow.step_id,
			Constants.InteractionStep.MANEUVER_STEP)
	assert_eq(s.interaction_flow.controller_player, 0)


# ---------------------------------------------------------------------------
# EndActivationCommand
# ---------------------------------------------------------------------------

func test_end_activation_p0_passes_to_p1_for_select() -> void:
	var s: GameState = _make_state()
	var idx: int = _make_ship_with_dial(s, 0)
	var cmd: EndActivationCommand = EndActivationCommand.new(0,
			{"ship_index": idx})
	cmd.execute(s)
	assert_eq(s.interaction_flow.flow_type,
			Constants.InteractionFlow.SHIP_ACTIVATION)
	assert_eq(s.interaction_flow.step_id,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT)
	assert_eq(s.interaction_flow.controller_player, 1,
			"Alternation: next activator is the opposing player.")


func test_end_activation_p1_passes_to_p0() -> void:
	var s: GameState = _make_state()
	var idx: int = _make_ship_with_dial(s, 1)
	var cmd: EndActivationCommand = EndActivationCommand.new(1,
			{"ship_index": idx})
	cmd.execute(s)
	assert_eq(s.interaction_flow.controller_player, 0)


# ---------------------------------------------------------------------------
# ActivateSquadronCommand
# ---------------------------------------------------------------------------

func test_activate_squadron_sets_action_choice() -> void:
	var s: GameState = _make_state(Constants.GamePhase.SQUADRON, 0)
	var sq: SquadronInstance = SquadronInstance.new()
	sq.owner_player = 0
	s.player_states[0].squadrons.append(sq)
	var cmd: ActivateSquadronCommand = ActivateSquadronCommand.new(0,
			{"squadron_index": 0})
	cmd.execute(s)
	assert_eq(s.interaction_flow.flow_type,
			Constants.InteractionFlow.SQUADRON_ACTIVATION)
	assert_eq(s.interaction_flow.step_id,
			Constants.InteractionStep.ACTION_CHOICE)
	assert_eq(s.interaction_flow.controller_player, 0)
	assert_eq(s.interaction_flow.payload.get("squadron_index", -1), 0)


# ---------------------------------------------------------------------------
# AdvanceActivationStepCommand
# ---------------------------------------------------------------------------

func test_advance_activation_step_maneuver_step() -> void:
	var s: GameState = _make_state()
	var idx: int = _make_ship_with_dial(s, 0)
	var cmd: AdvanceActivationStepCommand = \
			AdvanceActivationStepCommand.new(0, {
		"ship_index": idx,
		"step_id": "maneuver_step",
	})
	cmd.execute(s)
	assert_eq(s.interaction_flow.flow_type,
			Constants.InteractionFlow.SHIP_ACTIVATION)
	assert_eq(s.interaction_flow.step_id,
			Constants.InteractionStep.MANEUVER_STEP)
	assert_eq(s.interaction_flow.controller_player, 0)
	assert_eq(s.interaction_flow.payload.get("ship_index", -1), idx)


# ---------------------------------------------------------------------------
# Round-trip — interaction_flow survives serialize/deserialize after a command
# ---------------------------------------------------------------------------

func test_flow_set_by_command_survives_state_round_trip() -> void:
	var s: GameState = _make_state()
	var idx: int = _make_ship_with_dial(s, 0)
	ActivateShipCommand.new(0, {"ship_index": idx}).execute(s)
	var clone: GameState = GameState.deserialize(s.serialize())
	assert_true(clone.interaction_flow.equals(s.interaction_flow),
			"Command-driven flow must round-trip through serialize().")
