## Test: Electronic Countermeasures Status Phase ready cost
##
## Focused CAP-ECM-001 coverage for the deferred Repair-token ready-cost slice.
extends GutTest


const ECM_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/defensive_retrofit/electronic_countermeasures.gd")
const READY_ECM_COMMAND_SCRIPT: GDScript = preload(
		"res://src/core/commands/ready_ecm_command.gd")
const DECLINE_ECM_READY_COMMAND_SCRIPT: GDScript = preload(
		"res://src/core/commands/decline_ecm_ready_command.gd")
const COMMAND_APPLICABILITY_SCRIPT: GDScript = preload(
		"res://src/core/commands/command_applicability.gd")
const FLOW_SPEC_SCRIPT: GDScript = preload(
		"res://src/core/state/flow_spec.gd")

const ECM_ASSIGNMENT_ID: String = "ecm-1"
const ECM_RUNTIME_ID: String = "1:ship:defender:upgrade:ecm-1"


class AwaitingRemoteSubmitter:
	extends CommandSubmitter

	var submitted_commands: Array[GameCommand] = []


	func submit(command: GameCommand) -> Dictionary:
		submitted_commands.append(command)
		return {"awaiting_remote": true}


class RejectingSubmitter:
	extends CommandSubmitter

	var submitted_commands: Array[GameCommand] = []


	func submit(command: GameCommand) -> Dictionary:
		submitted_commands.append(command)
		return {}


var _state: GameState
var _saved_registry: Dictionary = {}
var _saved_game_state: GameState = null
var _saved_is_game_active: bool = false
var _saved_active_player: int = 0
var _saved_submitter: CommandSubmitter = null
var _token_changed_ships: Array[ShipInstance] = []
var _card_changed_ships: Array[ShipInstance] = []


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	GameCommand._registry.clear()
	READY_ECM_COMMAND_SCRIPT.register()
	DECLINE_ECM_READY_COMMAND_SCRIPT.register()
	StartRoundCommand.register()
	StatusPhaseCleanupCommand.register()
	_saved_game_state = GameManager.current_game_state
	_saved_is_game_active = GameManager.is_game_active
	_saved_active_player = GameManager.active_player
	_saved_submitter = GameManager.get_command_submitter()
	CommandProcessor.reset()
	RuleRegistry.clear()
	ECM_SCRIPT.register()
	_state = _make_status_state()
	GameManager.current_game_state = _state
	GameManager.is_game_active = true
	GameManager.active_player = 0
	_token_changed_ships.clear()
	_card_changed_ships.clear()
	EventBus.command_tokens_changed.connect(_on_command_tokens_changed)
	EventBus.ship_defense_token_changed.connect(_on_ship_defense_token_changed)


func after_each() -> void:
	if EventBus.command_tokens_changed.is_connected(_on_command_tokens_changed):
		EventBus.command_tokens_changed.disconnect(_on_command_tokens_changed)
	if EventBus.ship_defense_token_changed.is_connected(
			_on_ship_defense_token_changed):
		EventBus.ship_defense_token_changed.disconnect(
				_on_ship_defense_token_changed)
	GameManager.current_game_state = _saved_game_state
	GameManager.is_game_active = _saved_is_game_active
	GameManager.active_player = _saved_active_player
	GameManager.set_command_submitter(_saved_submitter)
	CommandProcessor.reset()
	GameCommand._registry = _saved_registry
	RuleRegistry.clear()
	RuleBootstrap.bootstrap_rules()


func test_ready_ecm_validation_rejects_invalid_sources_and_windows() -> void:
	assert_ne(_ready_ecm(0).validate(_state), "",
			"Wrong player should not ready ECM.")

	_state.current_phase = Constants.GamePhase.SHIP
	assert_ne(_ready_ecm().validate(_state), "",
			"Wrong phase should reject ready cost.")
	_state.current_phase = Constants.GamePhase.STATUS
	_state.interaction_flow = InteractionFlow.empty()
	assert_ne(_ready_ecm().validate(_state), "",
			"Wrong window should reject ready cost.")

	_state = _make_status_state()
	GameManager.current_game_state = _state
	_ship().runtime_upgrades.clear()
	assert_ne(_ready_ecm().validate(_state), "",
			"Missing runtime upgrade should reject ready cost.")

	_state = _make_status_state()
	GameManager.current_game_state = _state
	_ecm_upgrade()["data_key"] = "expanded_hangar_bay"
	assert_ne(_ready_ecm().validate(_state), "",
			"Wrong data_key should reject ready cost.")


func test_ready_ecm_validation_rejects_card_state_and_token_failures() -> void:
	var card_state: Dictionary = _ecm_card_state()
	card_state["exhausted"] = false
	card_state["readied"] = true
	assert_ne(_ready_ecm().validate(_state), "",
			"Already ready ECM should reject ready cost.")

	_state = _make_status_state()
	GameManager.current_game_state = _state
	card_state = _ecm_card_state()
	card_state["discarded"] = true
	assert_ne(_ready_ecm().validate(_state), "",
			"Discarded ECM should reject ready cost.")

	_state = _make_status_state()
	GameManager.current_game_state = _state
	card_state = _ecm_card_state()
	card_state["disabled"] = true
	assert_ne(_ready_ecm().validate(_state), "",
			"Disabled ECM should reject ready cost.")

	_state = _make_status_state(false)
	GameManager.current_game_state = _state
	assert_ne(_ready_ecm().validate(_state), "",
			"Missing Repair token should reject ready cost.")


func test_ready_ecm_spends_repair_token_readies_card_and_retains_guard() -> void:
	var result: Dictionary = _ready_ecm().execute(_state)
	var card_state: Dictionary = _ecm_card_state()
	var guard: Dictionary = ECM_SCRIPT.status_ready_cost_guard(_ecm_upgrade())

	assert_true(result.get("token_spent", false),
			"ReadyECMCommand should spend the Repair token.")
	assert_false(_ship().command_tokens.has_token(Constants.CommandType.REPAIR),
			"Source ship should no longer have the Repair token.")
	assert_false(card_state.get("exhausted", true),
			"ReadyECMCommand should clear exhausted state.")
	assert_true(card_state.get("readied", false),
			"ReadyECMCommand should set readied state.")
	assert_eq(guard.get("status", ""), "ready",
			"ReadyECMCommand should retain the authoritative ready guard.")
	assert_eq(guard.get("runtime_upgrade_id", ""), ECM_RUNTIME_ID,
			"Guard should identify the source runtime upgrade.")


func test_decline_ecm_ready_records_guard_without_spending_or_readying() -> void:
	var result: Dictionary = _decline_ecm_ready().execute(_state)
	var card_state: Dictionary = _ecm_card_state()
	var guard: Dictionary = ECM_SCRIPT.status_ready_cost_guard(_ecm_upgrade())

	assert_true(result.get("declined", false),
			"DeclineECMReadyCommand should record explicit decline.")
	assert_true(_ship().command_tokens.has_token(Constants.CommandType.REPAIR),
			"Decline should not spend the Repair token.")
	assert_true(card_state.get("exhausted", false),
			"Decline should leave ECM exhausted.")
	assert_false(card_state.get("readied", true),
			"Decline should not ready ECM.")
	assert_eq(guard.get("status", ""), "declined",
			"DeclineECMReadyCommand should retain the authoritative guard.")


func test_duplicate_ready_or_decline_rejected_after_guard_written() -> void:
	_decline_ecm_ready().execute(_state)

	assert_ne(_ready_ecm().validate(_state), "",
			"Ready should reject after decline guard exists.")
	assert_ne(_decline_ecm_ready().validate(_state), "",
			"Decline should reject after decline guard exists.")


func test_start_round_blocked_until_ready_cost_choice_resolved_then_clears_guard() -> void:
	assert_ne(StartRoundCommand.new(0, {}).validate(_state), "",
			"start_round should be blocked while ECM ready-cost is unresolved.")
	assert_false(COMMAND_APPLICABILITY_SCRIPT.check_command(
			"start_round",
			Constants.GamePhase.STATUS,
			_state.interaction_flow,
			_state).get(COMMAND_APPLICABILITY_SCRIPT.KEY_ALLOWED, true),
			"CommandApplicability should block start_round with unresolved ECM.")

	_ready_ecm().execute(_state)
	var start := StartRoundCommand.new(0, {})
	assert_eq(start.validate(_state), "",
			"start_round should be allowed after ECM ready-cost resolves.")
	var result: Dictionary = start.execute(_state)

	assert_true((result.get("ecm_status_ready_cost_cleared", []) as Array
			).has(ECM_RUNTIME_ID),
			"start_round should report clearing the ECM ready-cost guard.")
	assert_true(ECM_SCRIPT.status_ready_cost_guard(_ecm_upgrade()).is_empty(),
			"start_round should clear the authoritative ready-cost guard.")
	assert_eq(_state.current_phase, Constants.GamePhase.COMMAND,
			"start_round should still enter Command Phase.")


func test_game_manager_ready_path_records_choice_then_start_round() -> void:
	GameManager.set_command_submitter(LocalCommandSubmitter.new())

	var result: Dictionary = GameManager.submit_ready_ecm_runtime(
			1, ECM_RUNTIME_ID)
	var history: Array[GameCommand] = CommandProcessor.get_history()

	assert_false(result.is_empty(),
			"ReadyECMCommand should execute successfully.")
	assert_eq(history.size(), 2,
			"Successful final ready choice should be followed by start_round.")
	assert_eq(history[0].command_type, "ready_ecm",
			"ECM choice should be recorded before round continuation.")
	assert_eq(history[1].command_type, "start_round",
			"GameManager should submit StartRoundCommand after final choice.")
	assert_eq(_state.current_phase, Constants.GamePhase.COMMAND,
			"Final ready choice should continue into Command Phase.")


func test_game_manager_decline_path_records_choice_then_start_round() -> void:
	GameManager.set_command_submitter(LocalCommandSubmitter.new())

	var result: Dictionary = GameManager.submit_decline_ecm_ready_runtime(
			1, ECM_RUNTIME_ID)
	var history: Array[GameCommand] = CommandProcessor.get_history()

	assert_false(result.is_empty(),
			"DeclineECMReadyCommand should execute successfully.")
	assert_eq(history.size(), 2,
			"Successful final decline should be followed by start_round.")
	assert_eq(history[0].command_type, "decline_ecm_ready",
			"ECM decline should be recorded before round continuation.")
	assert_eq(history[1].command_type, "start_round",
			"GameManager should submit StartRoundCommand after final decline.")
	assert_eq(_state.current_phase, Constants.GamePhase.COMMAND,
			"Final decline should continue into Command Phase.")


func test_game_manager_waits_for_all_ecm_ready_cost_choices() -> void:
	GameManager.set_command_submitter(LocalCommandSubmitter.new())
	var second_runtime_id: String = _add_exhausted_ecm_ship_to_state(
			_state, 1, "defender-2", "ecm-2")
	_state.interaction_flow.payload = \
			ECM_SCRIPT.decorate_status_ready_cost_payload(
					_state, _state.interaction_flow.payload)

	var first_result: Dictionary = GameManager.submit_ready_ecm_runtime(
			1, ECM_RUNTIME_ID)
	var first_history: Array[GameCommand] = CommandProcessor.get_history()

	assert_false(first_result.is_empty(),
			"First ECM ready-cost choice should execute.")
	assert_eq(first_history.size(), 1,
			"First choice should not start the round while another remains.")
	assert_eq(first_history[0].command_type, "ready_ecm",
			"First command should be the first ECM choice.")
	assert_eq(_state.current_phase, Constants.GamePhase.STATUS,
			"Status Phase should remain active while another choice remains.")

	var second_result: Dictionary = GameManager.submit_decline_ecm_ready_runtime(
			1, second_runtime_id)
	var full_history: Array[GameCommand] = CommandProcessor.get_history()

	assert_false(second_result.is_empty(),
			"Final ECM ready-cost choice should execute.")
	assert_eq(full_history.size(), 3,
			"Only the final choice should append one start_round.")
	assert_eq(full_history[1].command_type, "decline_ecm_ready",
			"Second command should be the final ECM choice.")
	assert_eq(full_history[2].command_type, "start_round",
			"Final choice should be followed by exactly one start_round.")
	assert_eq(_state.current_phase, Constants.GamePhase.COMMAND,
			"Final choice should continue to the next round.")


func test_rejected_ready_cost_choice_does_not_start_round() -> void:
	var submitter := RejectingSubmitter.new()
	GameManager.set_command_submitter(submitter)

	var result: Dictionary = GameManager.submit_ready_ecm_runtime(
			1, ECM_RUNTIME_ID)

	assert_true(result.is_empty(),
			"Rejected ready attempt should return an empty result.")
	assert_eq(submitter.submitted_commands.size(), 1,
			"Rejected ECM choice should not trigger start_round.")
	assert_eq(submitter.submitted_commands[0].command_type, "ready_ecm",
			"Only the rejected ECM choice should be submitted.")
	assert_eq(_state.current_phase, Constants.GamePhase.STATUS,
			"Rejected ECM choice should leave Status Phase unresolved.")


func test_network_client_awaiting_ready_cost_does_not_synthesize_start_round() -> void:
	var submitter := AwaitingRemoteSubmitter.new()
	GameManager.set_command_submitter(submitter)

	var result: Dictionary = GameManager.submit_ready_ecm_runtime(
			1, ECM_RUNTIME_ID)

	assert_true(bool(result.get("awaiting_remote", false)),
			"Network client ready submission should return awaiting_remote.")
	assert_eq(submitter.submitted_commands.size(), 1,
			"Client should submit only the ECM choice locally.")
	assert_eq(submitter.submitted_commands[0].command_type, "ready_ecm",
			"Client should not synthesize StartRoundCommand.")
	assert_true(CommandProcessor.get_history().is_empty(),
			"Awaiting network client should not mutate local history.")


func test_cleanup_owner_clears_guard_on_flow_replacement_and_cancellation() -> void:
	_decline_ecm_ready().execute(_state)
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			0)
	ECM_SCRIPT.clear_status_ready_cost_window_state(_state)
	assert_true(ECM_SCRIPT.status_ready_cost_guard(_ecm_upgrade()).is_empty(),
			"Flow replacement cleanup should remove the status guard.")

	_state = _make_status_state()
	GameManager.current_game_state = _state
	_decline_ecm_ready().execute(_state)
	_state.interaction_flow = InteractionFlow.empty()
	ECM_SCRIPT.clear_status_ready_cost_window_state(_state)
	assert_true(ECM_SCRIPT.status_ready_cost_guard(_ecm_upgrade()).is_empty(),
			"Cancellation cleanup should remove the status guard.")


func test_repeated_status_cleanup_does_not_clear_current_window_decline_guard() -> void:
	_decline_ecm_ready().execute(_state)
	var cleanup_result: Dictionary = StatusPhaseCleanupCommand.new(
			0, {}).execute(_state)
	var guard: Dictionary = ECM_SCRIPT.status_ready_cost_guard(_ecm_upgrade())

	assert_eq(guard.get("status", ""), "declined",
			"Repeated cleanup should retain the current-window decline guard.")
	assert_true((cleanup_result.get("optional_status_rules", []) as Array
			).is_empty(),
			"Repeated cleanup should not re-offer declined ECM.")


func test_repeated_status_cleanup_does_not_clear_current_window_ready_guard() -> void:
	_ready_ecm().execute(_state)
	var cleanup_result: Dictionary = StatusPhaseCleanupCommand.new(
			0, {}).execute(_state)
	var guard: Dictionary = ECM_SCRIPT.status_ready_cost_guard(_ecm_upgrade())

	assert_eq(guard.get("status", ""), "ready",
			"Repeated cleanup should retain the current-window ready guard.")
	assert_true((cleanup_result.get("optional_status_rules", []) as Array
			).is_empty(),
			"Repeated cleanup should not re-offer readied ECM.")


func test_projection_publicly_lists_available_ecm_ready_cost() -> void:
	var owner_intent: UIProjector.UIIntent = UIProjector.project(_state, 1)
	var opponent_intent: UIProjector.UIIntent = UIProjector.project(_state, 0)
	var owner_choices: Array = owner_intent.affordances.get(
			ECM_SCRIPT.READY_COST_AFFORDANCE_KEY, []) as Array
	var opponent_choices: Array = opponent_intent.affordances.get(
			ECM_SCRIPT.READY_COST_AFFORDANCE_KEY, []) as Array

	assert_eq(owner_choices.size(), 1,
			"Owner should see one available ECM ready-cost choice.")
	assert_eq(opponent_choices.size(), 1,
			"Opponent should observe the public ECM ready-cost choice.")
	assert_eq((owner_choices[0] as Dictionary).get("runtime_upgrade_id", ""),
			ECM_RUNTIME_ID,
			"Projected choice should identify the ECM runtime upgrade.")

	_decline_ecm_ready().execute(_state)
	assert_true(ECM_SCRIPT.status_ready_cost_choices(_state).is_empty(),
			"Ready-cost choices should recalculate away after decline.")


func test_save_load_preserves_pending_choice_projection_from_authoritative_state() -> void:
	_state.interaction_flow.payload.clear()
	var restored: GameState = GameState.deserialize(_state.serialize())
	var intent: UIProjector.UIIntent = UIProjector.project(restored, 1)
	var choices: Array = intent.affordances.get(
			ECM_SCRIPT.READY_COST_AFFORDANCE_KEY, []) as Array

	assert_eq(choices.size(), 1,
			"Save/load should reconstruct pending ECM choice from runtime state.")
	assert_eq((choices[0] as Dictionary).get("runtime_upgrade_id", ""),
			ECM_RUNTIME_ID,
			"Reconstructed pending choice should target the ECM runtime id.")


func test_reconnect_preserves_pending_choice_projection_from_authoritative_state() -> void:
	_state.interaction_flow.payload.clear()
	var filtered: Dictionary = StateFilter.filter_for_player(
			_state.serialize(), 0)
	var reconnected: GameState = GameState.deserialize(filtered)
	var intent: UIProjector.UIIntent = UIProjector.project(reconnected, 0)
	var choices: Array = intent.affordances.get(
			ECM_SCRIPT.READY_COST_AFFORDANCE_KEY, []) as Array

	assert_eq(choices.size(), 1,
			"Reconnect should reconstruct pending ECM choice from runtime state.")
	assert_eq((choices[0] as Dictionary).get("runtime_upgrade_id", ""),
			ECM_RUNTIME_ID,
			"Reconnect projection should target the ECM runtime id.")


func test_flow_spec_allows_ready_cost_commands_only_in_status_window() -> void:
	var spec: Dictionary = FLOW_SPEC_SCRIPT.get_spec(
			Constants.InteractionFlow.STATUS_CLEANUP,
			Constants.InteractionStep.STATUS_CLEANUP_STEP)
	var commands: Array = spec.get("allowed_commands", []) as Array
	assert_true(commands.has("ready_ecm"),
			"FlowSpec should allow ReadyECMCommand in status cleanup step.")
	assert_true(commands.has("decline_ecm_ready"),
			"FlowSpec should allow DeclineECMReadyCommand in status cleanup step.")
	assert_true(COMMAND_APPLICABILITY_SCRIPT.check_command(
			"ready_ecm",
			Constants.GamePhase.STATUS,
			_state.interaction_flow,
			_state).get(COMMAND_APPLICABILITY_SCRIPT.KEY_ALLOWED, false),
			"CommandApplicability should allow ready_ecm in the status window.")

	_state.interaction_flow = InteractionFlow.empty()
	assert_false(COMMAND_APPLICABILITY_SCRIPT.check_command(
			"ready_ecm",
			Constants.GamePhase.STATUS,
			_state.interaction_flow,
			_state).get(COMMAND_APPLICABILITY_SCRIPT.KEY_ALLOWED, true),
			"CommandApplicability should reject ready_ecm outside the window.")


func test_save_load_preserves_ready_and_decline_intermediate_state() -> void:
	_ready_ecm().execute(_state)
	var restored_ready: GameState = GameState.deserialize(_state.serialize())
	var ready_upgrade: Dictionary = restored_ready.get_ship(
			1, 0).get_runtime_upgrade(ECM_RUNTIME_ID)
	assert_eq(ECM_SCRIPT.status_ready_cost_guard(
			ready_upgrade).get("status", ""), "ready",
			"Save/load should preserve the ready guard while window is active.")
	assert_true((ready_upgrade.get("card_state", {}) as Dictionary).get(
			"readied", false),
			"Save/load should preserve readied ECM state.")

	_state = _make_status_state()
	GameManager.current_game_state = _state
	_decline_ecm_ready().execute(_state)
	var restored_decline: GameState = GameState.deserialize(_state.serialize())
	var decline_upgrade: Dictionary = restored_decline.get_ship(
			1, 0).get_runtime_upgrade(ECM_RUNTIME_ID)
	assert_eq(ECM_SCRIPT.status_ready_cost_guard(
			decline_upgrade).get("status", ""), "declined",
			"Save/load should preserve the declined guard while window is active.")


func test_reconnect_preserves_declined_guard_and_public_projection() -> void:
	_decline_ecm_ready().execute(_state)
	var filtered: Dictionary = StateFilter.filter_for_player(
			_state.serialize(), 0)
	var reconnected: GameState = GameState.deserialize(filtered)
	var runtime_upgrade: Dictionary = reconnected.get_ship(
			1, 0).get_runtime_upgrade(ECM_RUNTIME_ID)
	var intent: UIProjector.UIIntent = UIProjector.project(reconnected, 0)

	assert_eq(ECM_SCRIPT.status_ready_cost_guard(
			runtime_upgrade).get("status", ""), "declined",
			"Reconnect should reconstruct the declined ready-cost guard.")
	assert_true((intent.payload.get("optional_status_rules", []) as Array
			).is_empty(),
			"Reconnect projection should not re-offer declined ECM.")


func test_ready_and_decline_commands_serialize_and_replay() -> void:
	var ready: GameCommand = _ready_ecm()
	ready.sequence = 21
	var restored_ready: GameCommand = GameCommand.deserialize(ready.serialize())
	assert_eq(restored_ready.validate(_state), "",
			"Serialized ReadyECMCommand should replay from payload.")
	restored_ready.execute(_state)
	assert_eq(ECM_SCRIPT.status_ready_cost_guard(
			_ecm_upgrade()).get("status", ""), "ready",
			"Replayed ReadyECMCommand should recreate the ready guard.")

	_state = _make_status_state()
	GameManager.current_game_state = _state
	var decline: GameCommand = _decline_ecm_ready()
	decline.sequence = 22
	var restored_decline: GameCommand = GameCommand.deserialize(
			decline.serialize())
	assert_eq(restored_decline.validate(_state), "",
			"Serialized DeclineECMReadyCommand should replay from payload.")
	restored_decline.execute(_state)
	assert_eq(ECM_SCRIPT.status_ready_cost_guard(
			_ecm_upgrade()).get("status", ""), "declined",
			"Replayed DeclineECMReadyCommand should recreate the decline guard.")


func test_remote_ready_cost_side_effects_refresh_public_state() -> void:
	var ready_result: Dictionary = _ready_ecm().execute(_state)
	GameManager._handle_remote_command_effects(_ready_ecm(), ready_result)

	assert_true(_token_changed_ships.has(_ship()),
			"Remote ready should refresh command-token display.")
	assert_true(_card_changed_ships.has(_ship()),
			"Remote ready should refresh runtime card state display.")

	_state = _make_status_state()
	GameManager.current_game_state = _state
	_token_changed_ships.clear()
	_card_changed_ships.clear()
	var decline_result: Dictionary = _decline_ecm_ready().execute(_state)
	GameManager._handle_remote_command_effects(
			_decline_ecm_ready(), decline_result)
	assert_true(_token_changed_ships.is_empty(),
			"Remote decline should not refresh command tokens.")
	assert_true(_card_changed_ships.has(_ship()),
			"Remote decline should refresh public guard/projection state.")


func test_status_cleanup_regression_and_payload_generation() -> void:
	var state: GameState = _make_status_state(false)
	GameManager.current_game_state = state
	var ship: ShipInstance = state.get_ship(1, 0)
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED

	var result: Dictionary = StatusPhaseCleanupCommand.new(0, {}).execute(state)

	assert_eq(int(ship.defense_tokens[0]["state"]),
			int(Constants.DefenseTokenState.READY),
			"Status cleanup should still ready defense tokens.")
	assert_true((result.get("optional_status_rules", []) as Array).is_empty(),
			"No Repair token should mean no ECM ready-cost choice.")
	assert_eq(state.interaction_flow.flow_type,
			Constants.InteractionFlow.STATUS_CLEANUP,
			"Status cleanup should publish the status cleanup flow.")


func _make_status_state(has_repair_token: bool = true) -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_round = 2
	state.current_phase = Constants.GamePhase.STATUS
	var ship: ShipInstance = _add_ship_to_state(state, 1, "defender")
	ship.add_runtime_upgrade(
			"electronic_countermeasures", ECM_ASSIGNMENT_ID,
			"DEFENSIVE_RETROFIT", 0)
	var card_state: Dictionary = ship.get_runtime_upgrade(
			ECM_RUNTIME_ID).get("card_state", {}) as Dictionary
	card_state["exhausted"] = true
	card_state["readied"] = false
	if has_repair_token:
		ship.command_tokens.force_add_token(Constants.CommandType.REPAIR)
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.STATUS_CLEANUP,
			Constants.InteractionStep.STATUS_CLEANUP_STEP,
			-1,
			Constants.Visibility.ALL,
			{"status_phase_cleanup_complete": true})
	state.interaction_flow.payload = ECM_SCRIPT.decorate_status_ready_cost_payload(
			state, state.interaction_flow.payload)
	return state


func _add_ship_to_state(state: GameState,
		player: int,
		roster_entry_id: String) -> ShipInstance:
	var ship := ShipInstance.create_from_data(
			"victory_ii_class_star_destroyer", _make_ship_data(), 2, player)
	ship.roster_entry_id = roster_entry_id
	var ps: PlayerState = state.get_player_state(player)
	ps.ships.append(ship)
	return ship


func _add_exhausted_ecm_ship_to_state(state: GameState,
		player: int,
		roster_entry_id: String,
		assignment_id: String) -> String:
	var ship: ShipInstance = _add_ship_to_state(state, player, roster_entry_id)
	ship.add_runtime_upgrade(
			"electronic_countermeasures", assignment_id,
			"DEFENSIVE_RETROFIT", 0)
	var runtime_upgrade: Dictionary = ship.runtime_upgrades[
			ship.runtime_upgrades.size() - 1] as Dictionary
	var runtime_id: String = str(runtime_upgrade.get("runtime_upgrade_id", ""))
	var card_state: Dictionary = runtime_upgrade.get("card_state", {}) \
			as Dictionary
	card_state["exhausted"] = true
	card_state["readied"] = false
	ship.command_tokens.force_add_token(Constants.CommandType.REPAIR)
	return runtime_id


func _make_ship_data() -> ShipData:
	var data := ShipData.new()
	data.hull = 5
	data.max_speed = 2
	data.command_value = 2
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = ["brace", "redirect", "evade"]
	data.navigation_chart = [[1], [1, 1]]
	return data


func _ship() -> ShipInstance:
	return _state.get_ship(1, 0)


func _ecm_upgrade() -> Dictionary:
	return _ship().get_runtime_upgrade(ECM_RUNTIME_ID)


func _ecm_card_state() -> Dictionary:
	return _ecm_upgrade().get("card_state", {}) as Dictionary


func _ready_ecm(player: int = 1) -> GameCommand:
	return READY_ECM_COMMAND_SCRIPT.new(player, {
		"runtime_upgrade_id": ECM_RUNTIME_ID,
	})


func _decline_ecm_ready(player: int = 1) -> GameCommand:
	return DECLINE_ECM_READY_COMMAND_SCRIPT.new(player, {
		"runtime_upgrade_id": ECM_RUNTIME_ID,
	})


func _on_command_tokens_changed(ship: ShipInstance) -> void:
	_token_changed_ships.append(ship)


func _on_ship_defense_token_changed(ship: ShipInstance) -> void:
	_card_changed_ships.append(ship)
