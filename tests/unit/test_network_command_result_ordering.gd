## Test: network command result ordering
##
## Focused regressions for client-side application of authoritative server
## command results in server sequence order.
extends GutTest


const CF_PRODUCTION: GDScript = preload(
		"res://tests/fixtures/bug071_production_attack_builder.gd")
const CF_DIAL_USE: GDScript = preload(
		"res://src/core/commands/use_concentrate_fire_dial_command.gd")
const CF_TOKEN_DECLINE: GDScript = preload(
		"res://src/core/commands/decline_concentrate_fire_token_reroll_command.gd")

var _saved_play_mode: PlayMode.Mode
var _saved_role: NetworkManager.Role
var _saved_local_player_index: int = -1
var _saved_state: GameState = null
var _saved_active: bool = false
var _saved_submitter: CommandSubmitter = null
var _saved_registry: Dictionary = {}


func before_each() -> void:
	_saved_play_mode = PlayMode.current_mode
	_saved_role = NetworkManager.role
	_saved_local_player_index = NetworkManager._local_player_index
	_saved_state = GameManager.current_game_state
	_saved_active = GameManager.is_game_active
	_saved_submitter = GameManager.get_command_submitter()
	_saved_registry = GameCommand._registry.duplicate()
	GameCommand._registry.clear()
	AssignDialCommand.register()
	AdvancePhaseCommand.register()
	TarkinChoiceCommand.register()
	SelectRedirectZoneCommand.register()
	SetSpeedCommand.register()
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager.role = NetworkManager.Role.CLIENT
	NetworkManager._local_player_index = 1


func after_each() -> void:
	PlayMode.current_mode = _saved_play_mode
	NetworkManager.role = _saved_role
	NetworkManager._local_player_index = _saved_local_player_index
	GameManager.current_game_state = _saved_state
	GameManager.is_game_active = _saved_active
	GameManager.set_command_submitter(_saved_submitter)
	GameCommand._registry = _saved_registry
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	RuleRegistry.clear()


func test_real_cf_dial_and_token_results_apply_in_order_without_peer_rng() -> void:
	var context: Dictionary = CF_PRODUCTION.committed_dial(
			1, CurrentAttackState.CF_CHOICE_BOTH)
	assert_false(context.is_empty())
	if context.is_empty():
		return
	CF_DIAL_USE.register()
	CF_TOKEN_DECLINE.register()
	var authority: GameState = context["state"] as GameState
	var before_dial: Dictionary = authority.serialize()
	var sequence: int = int(context["command_sequence"])
	var dial_command: GameCommand = CF_DIAL_USE.new(1, context["dial_payload"])
	var dial_result: Dictionary = CommandProcessor.submit_deferred_followups(
			dial_command)
	assert_false(dial_result.is_empty())
	var token_payload: Dictionary = {}
	for opportunity: Dictionary in UIProjector.project(
			authority, 1).timing_window.get("opportunities", []):
		if str(opportunity.get("capability_id", "")) \
				== "command_token.concentrate_fire":
			token_payload = (opportunity.get("decline_intent", {}) \
					as Dictionary).get("payload", {})
	assert_false(token_payload.is_empty())
	if token_payload.is_empty():
		return
	var token_command: GameCommand = CF_TOKEN_DECLINE.new(1, token_payload)
	var token_result: Dictionary = CommandProcessor.submit_deferred_followups(
			token_command)
	assert_false(token_result.is_empty())
	var authority_final: Dictionary = authority.serialize()
	var client: GameState = GameState.deserialize_passive_network(
			StateFilter.filter_for_player(before_dial, 1))
	assert_not_null(client)
	if client == null:
		return
	GameManager.current_game_state = client
	GameManager.is_game_active = true
	GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	CommandProcessor.reset()
	assert_true(CommandProcessor.restore_next_sequence(sequence))
	GameManager._reset_network_result_ordering()
	assert_null(client.rng)
	var dial_envelope: Dictionary = NetworkManager._build_result_envelope(
			dial_command, dial_result, 1)
	var token_envelope: Dictionary = NetworkManager._build_result_envelope(
			token_command, token_result, 1)
	GameManager._on_network_command_result(
			token_command.serialize(), token_envelope)
	assert_eq(client.serialize(), StateFilter.filter_for_player(before_dial, 1))
	assert_eq(CommandProcessor.get_next_sequence(), sequence)
	assert_eq(GameManager._pending_network_results.size(), 1)
	GameManager._on_network_command_result(
			dial_command.serialize(), dial_envelope)
	assert_eq(client.serialize(), StateFilter.filter_for_player(authority_final, 1))
	assert_eq(CommandProcessor.get_next_sequence(), sequence + 2)
	assert_eq(GameManager._next_network_result_sequence, sequence + 2)
	assert_eq(GameManager._pending_network_results.size(), 0)
	assert_eq(client.current_attack_state.cf_token_resolution,
			CurrentAttackState.RESOLUTION_DECLINED)
	assert_false(client.get_ship(1, 0).command_tokens.has_token(
			Constants.CommandType.CONCENTRATE_FIRE))


func test_real_cf_bad_earlier_result_holds_later_then_reconnect_recovers() -> void:
	var context: Dictionary = CF_PRODUCTION.committed_dial(
			1, CurrentAttackState.CF_CHOICE_BOTH)
	assert_false(context.is_empty())
	if context.is_empty():
		return
	var authority: GameState = context["state"] as GameState
	var before_dial: Dictionary = authority.serialize()
	var sequence: int = int(context["command_sequence"])
	var dial_command: GameCommand = CF_DIAL_USE.new(1, context["dial_payload"])
	var dial_result: Dictionary = CommandProcessor.submit_deferred_followups(
			dial_command)
	assert_false(dial_result.is_empty())
	var after_dial: Dictionary = authority.serialize()
	var token_payload: Dictionary = {}
	for opportunity: Dictionary in UIProjector.project(
			authority, 1).timing_window.get("opportunities", []):
		if str(opportunity.get("capability_id", "")) \
				== "command_token.concentrate_fire":
			token_payload = (opportunity.get("decline_intent", {}) \
					as Dictionary).get("payload", {})
	assert_false(token_payload.is_empty())
	if token_payload.is_empty():
		return
	var token_command: GameCommand = CF_TOKEN_DECLINE.new(1, token_payload)
	var token_result: Dictionary = CommandProcessor.submit_deferred_followups(
			token_command)
	assert_false(token_result.is_empty())
	var authority_final: Dictionary = authority.serialize()
	var client: GameState = GameState.deserialize_passive_network(
			StateFilter.filter_for_player(before_dial, 1))
	assert_not_null(client)
	if client == null:
		return
	GameManager.current_game_state = client
	GameManager.is_game_active = true
	GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	CommandProcessor.reset()
	assert_true(CommandProcessor.restore_next_sequence(sequence))
	GameManager._reset_network_result_ordering()
	var later: Dictionary = NetworkManager._build_result_envelope(
			token_command, token_result, 1)
	var bad_earlier: Dictionary = NetworkManager._build_result_envelope(
			dial_command, dial_result, 1)
	bad_earlier["application_result"] = {"new_face": 999}
	GameManager._on_network_command_result(token_command.serialize(), later)
	GameManager._on_network_command_result(
			dial_command.serialize(), bad_earlier)
	assert_eq(client.serialize(), StateFilter.filter_for_player(before_dial, 1))
	assert_eq(CommandProcessor.get_next_sequence(), sequence)
	assert_eq(GameManager._next_network_result_sequence, sequence)
	assert_eq(GameManager._pending_network_results.size(), 2)
	assert_eq(CommandProcessor.get_command_count(), 0)
	assert_engine_error(2)
	var reconnected: GameState = GameState.deserialize_passive_network(
			StateFilter.filter_for_player(after_dial, 1))
	assert_not_null(reconnected)
	if reconnected == null:
		return
	assert_true(GameManager.start_new_game_from_state(reconnected,
			LearningScenarioSetup.DEFAULT_SCENARIO_ID, sequence + 1))
	GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	GameManager._on_network_command_result(token_command.serialize(), later)
	assert_eq(reconnected.serialize(),
			StateFilter.filter_for_player(authority_final, 1))
	assert_eq(CommandProcessor.get_next_sequence(), sequence + 2)
	assert_eq(GameManager._pending_network_results.size(), 0)
	var after_success: Dictionary = reconnected.serialize()
	GameManager._on_network_command_result(token_command.serialize(), later)
	assert_eq(reconnected.serialize(), after_success)
	assert_eq(CommandProcessor.get_next_sequence(), sequence + 2)
	assert_engine_error(3)


func test_network_result_ordering_buffers_later_sequence_until_gap_filled() -> void:
	var state: GameState = _install_client_state(false)
	var assign: AssignDialCommand = _assign_cmd(
			0, 0, Constants.CommandType.NAVIGATE, 0)
	var advance: AdvancePhaseCommand = _advance_cmd(1)

	GameManager._on_network_command_result(
			advance.serialize(), _envelope(_advance_result()))

	assert_eq(state.current_phase, Constants.GamePhase.COMMAND,
			"Client must not mirror later advance_phase before sequence 0.")
	assert_eq(CommandProcessor.get_command_count(), 0,
			"Buffered later command should not enter local history yet.")
	assert_eq(GameManager._pending_network_results.size(), 1,
			"Out-of-order advance should be buffered.")

	GameManager._on_network_command_result(
			assign.serialize(), _envelope(_assign_result(0)))

	assert_eq(CommandProcessor.get_command_count(), 2,
			"Missing earlier result should flush assign_dials then advance_phase.")
	assert_eq(CommandProcessor.get_history()[0].command_type, "assign_dials",
			"Earlier assign_dials should mirror first.")
	assert_eq(CommandProcessor.get_history()[1].command_type, "advance_phase",
			"Buffered advance_phase should mirror second.")
	assert_eq(state.current_phase, Constants.GamePhase.SHIP,
			"Client should enter Ship Phase only after earlier result applies.")


func test_network_result_ordering_does_not_enter_ship_before_missing_dial() -> void:
	var state: GameState = _install_client_state(false)
	var first: AssignDialCommand = _assign_cmd(
			1, 0, Constants.CommandType.NAVIGATE, 0)
	var missing: AssignDialCommand = _assign_cmd(
			1, 1, Constants.CommandType.REPAIR, 1)
	var advance: AdvancePhaseCommand = _advance_cmd(2)

	GameManager._on_network_command_result(
			first.serialize(), _envelope(_assign_result(0)))
	GameManager._on_network_command_result(
			advance.serialize(), _envelope(_advance_result()))

	assert_eq(state.current_phase, Constants.GamePhase.COMMAND,
			"Client must stay in Command Phase while sequence 1 is missing.")
	assert_eq(_ship(state, 1, 1).command_dial_stack.get_dial_count(), 0,
			"Second Imperial ship should still be missing its dial.")

	GameManager._on_network_command_result(
			missing.serialize(), _envelope(_assign_result(1)))

	assert_eq(state.current_phase, Constants.GamePhase.SHIP,
			"Client should enter Ship Phase after the missing dial applies.")
	assert_eq(_ship(state, 1, 1).command_dial_stack.get_dial_count(), 1,
			"Missing dial should be applied before phase advancement.")


func test_network_tarkin_command_phase_mirrors_all_imperial_dials_expected() -> void:
	var state: GameState = _install_client_state(true)
	var rebel: AssignDialCommand = _assign_cmd(
			0, 0, Constants.CommandType.SQUADRON, 0)
	var imperial_first: AssignDialCommand = _assign_cmd(
			1, 0, Constants.CommandType.NAVIGATE, 1)
	var imperial_second: AssignDialCommand = _assign_cmd(
			1, 1, Constants.CommandType.REPAIR, 2)
	var advance: AdvancePhaseCommand = _advance_cmd(3)

	GameManager._on_network_command_result(
			rebel.serialize(), _envelope(_assign_result(0)))
	GameManager._on_network_command_result(
			imperial_first.serialize(), _envelope(_assign_result(0)))
	GameManager._on_network_command_result(
			advance.serialize(), _envelope(_advance_result()))

	assert_eq(state.current_phase, Constants.GamePhase.COMMAND,
			"Tarkin prompt must not appear before all earlier dials mirror.")
	assert_eq(_ship(state, 1, 1).command_dial_stack.get_dial_count(), 0,
			"Second Imperial dial should still be pending before sequence 2.")

	GameManager._on_network_command_result(
			imperial_second.serialize(), _envelope(_assign_result(1)))

	assert_eq(state.current_phase, Constants.GamePhase.SHIP,
			"Client should enter Ship Phase after all dial results mirror.")
	assert_eq(state.interaction_flow.step_id,
			Constants.InteractionStep.TARKIN_COMMAND_CHOICE,
			"Tarkin prompt should appear after ordered Command Phase results.")
	assert_eq(_ship(state, 1, 0).command_dial_stack.get_dial_count(), 1,
			"First Imperial ship should have its mirrored command dial.")
	assert_eq(_ship(state, 1, 1).command_dial_stack.get_dial_count(), 1,
			"Second Imperial ship should have its mirrored command dial.")


func test_negative_network_sequence_is_rejected_without_mutation() -> void:
	_install_client_state(false)
	var command: AssignDialCommand = _assign_cmd(
			0, 0, Constants.CommandType.NAVIGATE, -1)

	GameManager._on_network_command_result(
			command.serialize(), _envelope(_assign_result(0)))

	assert_eq(CommandProcessor.get_next_sequence(), 0)
	assert_eq(CommandProcessor.get_command_count(), 0)
	assert_eq(GameManager._pending_network_results.size(), 0)
	assert_engine_error(1,
			"Unsequenced authoritative result should produce one diagnostic.")


func test_failed_mirror_keeps_both_cursors_and_buffer_position() -> void:
	_install_client_state(false)
	var invalid: AssignDialCommand = _assign_cmd(
			0, 99, Constants.CommandType.NAVIGATE, 0)
	var later: AssignDialCommand = _assign_cmd(
			1, 0, Constants.CommandType.REPAIR, 1)
	GameManager._on_network_command_result(
			later.serialize(), _envelope(_assign_result(0)))

	GameManager._on_network_command_result(
			invalid.serialize(), _envelope(_assign_result(99)))

	assert_eq(CommandProcessor.get_next_sequence(), 0,
			"Rejected mirror command must not advance CommandProcessor.")
	assert_eq(GameManager._next_network_result_sequence, 0,
			"Rejected mirror command must not advance network ordering.")
	assert_eq(GameManager._pending_network_results.size(), 2,
			"Failed position and later buffered result must remain fail-closed.")
	assert_engine_error(2,
			"Command rejection and stopped mirror application should diagnose.")


func test_duplicate_buffered_result_cannot_replace_first_payload() -> void:
	_install_client_state(false)
	var first_later: AssignDialCommand = _assign_cmd(
			1, 0, Constants.CommandType.NAVIGATE, 1)
	var duplicate_later: AssignDialCommand = _assign_cmd(
			1, 1, Constants.CommandType.REPAIR, 1)
	GameManager._on_network_command_result(
			first_later.serialize(), _envelope(_assign_result(0)))
	GameManager._on_network_command_result(
			duplicate_later.serialize(), _envelope(_assign_result(1)))
	GameManager._on_network_command_result(
			_assign_cmd(0, 0, Constants.CommandType.SQUADRON, 0).serialize(),
			_envelope(_assign_result(0)))

	assert_eq(CommandProcessor.get_command_count(), 2)
	assert_eq(CommandProcessor.get_history()[1].payload.get("ship_index"), 0,
			"First buffered authoritative payload must win deterministically.")
	assert_engine_error(1,
			"Duplicate buffered result should produce one diagnostic.")


func test_reconstructed_cursor_initializes_network_result_ordering() -> void:
	var state: GameState = _install_client_state(false)
	assert_true(CommandProcessor.restore_next_sequence(4))
	GameManager._reset_network_result_ordering()
	assert_eq(GameManager._next_network_result_sequence, 4)

	GameManager._on_network_command_result(
			_assign_cmd(0, 0, Constants.CommandType.NAVIGATE, 4).serialize(),
			_envelope(_assign_result(0)))

	assert_eq(CommandProcessor.get_next_sequence(), 5)
	assert_eq(GameManager._next_network_result_sequence, 5)
	assert_eq(_ship(state, 0, 0).command_dial_stack.get_dial_count(), 1)


func test_network_rejection_releases_gate_without_entering_ordered_history() -> void:
	_install_client_state(false)
	var submitter := NetworkCommandSubmitter.new()
	submitter._awaiting = true
	submitter._in_flight_count = 1
	submitter._awaiting_command_type = "assign_dials"
	GameManager.set_command_submitter(submitter)
	var rejected: AssignDialCommand = _assign_cmd(
			1, 0, Constants.CommandType.NAVIGATE, -1)
	watch_signals(GameManager)

	GameManager._on_network_command_rejection(
			rejected.serialize(), "Controlled authoritative rejection.")

	assert_false(submitter.is_awaiting_response())
	assert_eq(CommandProcessor.get_command_count(), 0)
	assert_eq(GameManager._pending_network_results.size(), 0)
	assert_signal_emitted(GameManager, "network_command_rejected")
	var args: Array = get_signal_parameters(
			GameManager, "network_command_rejected")
	assert_eq((args[0] as GameCommand).command_type, "assign_dials")
	assert_eq(args[1], "Controlled authoritative rejection.")


func test_bug_043_ordered_set_speed_applies_before_presentation_and_gate_release() -> void:
	var state: GameState = _install_client_state(false)
	state.current_phase = Constants.GamePhase.SHIP
	var ship: ShipInstance = state.get_ship(1, 0)
	var submitter := GameManager.get_command_submitter() \
			as NetworkCommandSubmitter
	submitter._awaiting = true
	submitter._in_flight_count = 1
	submitter._awaiting_command_type = "set_speed"
	var command := SetSpeedCommand.new(1, {
		"ship_index": 0,
		"new_speed": 1,
	})
	command.sequence = 0
	watch_signals(EventBus)

	GameManager._on_network_command_result(
			command.serialize(), _envelope({"new_speed": 1}))

	assert_eq(ship.current_speed, 1,
			"Ordered mirror must commit canonical speed first")
	assert_signal_emitted_with_parameters(
			EventBus, "ship_speed_changed", [ship, 1])
	assert_false(submitter.is_awaiting_response(),
			"Submission gate releases after accepted presentation convergence")


func test_bug_030_host_defender_projects_accepted_redirect_shields() -> void:
	var state: GameState = _install_client_state(false)
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager._local_player_index = 0
	var defender: ShipInstance = state.get_ship(0, 0)
	var zone_name: String = Constants.hull_zone_to_string(
			Constants.HullZone.LEFT)
	var shields_before: int = int(defender.current_shields.get(zone_name, 0))
	assert_eq(defender.reduce_shields(zone_name, 1), 1,
			"Fixture models the command-owned mutation before broadcast.")
	var canonical_after_command: Dictionary = defender.serialize()
	var command := SelectRedirectZoneCommand.new(0, {
		"ship_index": 0,
		"zone": int(Constants.HullZone.LEFT),
	})
	watch_signals(EventBus)

	GameManager._on_network_command_result(command.serialize(), _envelope({
		"zone_name": zone_name,
		"new_shields": shields_before - 1,
		"ship_index": 0,
	}))

	assert_signal_emitted_with_parameters(EventBus, "ship_shields_changed", [
			defender, zone_name, shields_before - 1])
	assert_eq(defender.serialize(), canonical_after_command,
			"Accepted-result projection must not repeat shield mutation.")
	assert_eq(CommandProcessor.get_command_count(), 0,
			"Projection must create no replay or semantic command entry.")
	GameManager._on_network_command_rejection(
			command.serialize(), "Controlled rejection after accepted fixture.")
	assert_signal_emit_count(EventBus, "ship_shields_changed", 1,
			"Rejected results must not optimistically refresh shields.")


func _install_client_state(with_tarkin: bool) -> GameState:
	CommandProcessor.reset()
	GameManager._reset_network_result_ordering()
	var state: GameState = _make_command_phase_state(with_tarkin)
	GameManager.current_game_state = state
	GameManager.is_game_active = true
	GameManager._command_submitted = [false, false]
	GameManager._command_assigning_player = -1
	GameManager._activating_ship = null
	GameManager._activating_squadron = null
	GameManager.set_command_submitter(NetworkCommandSubmitter.new())
	return state


func _make_command_phase_state(with_tarkin: bool) -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.COMMAND
	state.initiative_player = 0
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.COMMAND_PHASE,
			Constants.InteractionStep.SELECT_DIALS,
			1)
	state.get_player_state(0).ships.append(
			_make_ship(0, "rebel-ship-1", false))
	state.get_player_state(1).ships.append(
			_make_ship(1, "imperial-ship-1", with_tarkin))
	state.get_player_state(1).ships.append(
			_make_ship(1, "imperial-ship-2", false))
	return state


func _make_ship(owner: int,
		roster_entry_id: String,
		with_tarkin: bool) -> ShipInstance:
	var ship_data: ShipData = AssetLoader.load_ship_data(
			"victory_ii_class_star_destroyer")
	var ship: ShipInstance = ShipInstance.create_from_data(
			"victory_ii_class_star_destroyer", ship_data, 2, owner)
	ship.roster_entry_id = roster_entry_id
	ship.command_dial_stack = CommandDialStack.create(1)
	ship.command_tokens = CommandTokenManager.create(1)
	if with_tarkin:
		ship.add_runtime_upgrade("grand_moff_tarkin", "imperial-cmd",
				"COMMANDER", 0)
	return ship


func _assign_cmd(player: int,
		ship_index: int,
		command: int,
		sequence: int) -> AssignDialCommand:
	var cmd := AssignDialCommand.new(player, {
		"ship_index": ship_index,
		"commands": [int(command)],
	})
	cmd.sequence = sequence
	return cmd


func _advance_cmd(sequence: int) -> AdvancePhaseCommand:
	var cmd := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.SHIP),
	})
	cmd.sequence = sequence
	return cmd


func _assign_result(ship_index: int) -> Dictionary:
	return {"success": true, "ship_index": ship_index}


func _advance_result() -> Dictionary:
	return {
		"previous_phase": int(Constants.GamePhase.COMMAND),
		"new_phase": int(Constants.GamePhase.SHIP),
	}


func _envelope(presentation: Dictionary) -> Dictionary:
	return {
		"protocol_version": NetworkManager.PROTOCOL_VERSION,
		"application_contract": "none",
		"application_contract_version": 0,
		"viewer_player": NetworkManager.get_local_player_index(),
		"application_result": {},
		"presentation_result": presentation,
		"maneuver_consequence_view": {},
	}


func _ship(state: GameState, player: int, ship_index: int) -> ShipInstance:
	return state.get_ship(player, ship_index)
