## Test: Grand Moff Tarkin command choice
##
## Focused CAP-UPG-001 tests for phase-entry prompting, replayable choice/
## decline, token grants, blocker handling, projection, and persistence.
extends GutTest


const TARKIN_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/upgrades/commander/grand_moff_tarkin.gd")
const LIFE_SUPPORT_FAILURE_SCRIPT: GDScript = preload(
		"res://src/core/effects/rules/damage_cards/ship/life_support_failure.gd")

const TARKIN_RUNTIME_ID: String = \
		"1:ship:imperial-ship-1:upgrade:imperial-cmd"

var _state: GameState
var _saved_registry: Dictionary = {}
var _token_changed_ships: Array[ShipInstance] = []
var _duplicate_events: Array[Dictionary] = []
var _discard_required_ships: Array[ShipInstance] = []


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	GameCommand._registry.clear()
	AdvancePhaseCommand.register()
	TarkinChoiceCommand.register()
	DiscardTokenCommand.register()
	RuleRegistry.clear()
	_state = _make_tarkin_state()
	GameManager.current_game_state = _state
	_token_changed_ships.clear()
	_duplicate_events.clear()
	_discard_required_ships.clear()
	EventBus.command_tokens_changed.connect(_on_command_tokens_changed)
	EventBus.duplicate_token_discarded.connect(_on_duplicate_token_discarded)
	EventBus.token_discard_required.connect(_on_token_discard_required)


func after_each() -> void:
	if EventBus.command_tokens_changed.is_connected(_on_command_tokens_changed):
		EventBus.command_tokens_changed.disconnect(_on_command_tokens_changed)
	if EventBus.duplicate_token_discarded.is_connected(_on_duplicate_token_discarded):
		EventBus.duplicate_token_discarded.disconnect(_on_duplicate_token_discarded)
	if EventBus.token_discard_required.is_connected(_on_token_discard_required):
		EventBus.token_discard_required.disconnect(_on_token_discard_required)
	GameManager.current_game_state = null
	GameCommand._registry = _saved_registry
	RuleBootstrap.bootstrap_rules()


# ---------------------------------------------------------------------------
# Prompt / Projection
# ---------------------------------------------------------------------------

func test_advance_phase_enters_tarkin_prompt_before_ship_selection() -> void:
	var result: Dictionary = _advance_to_ship_phase()

	assert_eq(result.get("new_phase", -1), int(Constants.GamePhase.SHIP),
			"Phase advance should still enter Ship Phase.")
	assert_eq(_state.interaction_flow.step_id,
			Constants.InteractionStep.TARKIN_COMMAND_CHOICE,
			"Tarkin source should prompt before normal ship selection.")
	assert_eq(_state.interaction_flow.controller_player, 1,
			"Tarkin owner should control the prompt.")
	assert_eq(_state.interaction_flow.payload.get("runtime_upgrade_id", ""),
			TARKIN_RUNTIME_ID,
			"Prompt payload should bind the runtime upgrade source.")


func test_projector_shows_public_tarkin_prompt_to_both_players() -> void:
	_advance_to_ship_phase()

	var owner_intent: UIProjector.UIIntent = _project_after_reconnect(_state, 1)
	var opponent_intent: UIProjector.UIIntent = _project_after_reconnect(_state, 0)

	assert_eq(owner_intent.modal_kind, Constants.ModalKind.TARKIN_COMMAND_CHOICE,
			"Owner should project the Tarkin modal.")
	assert_eq(opponent_intent.modal_kind, Constants.ModalKind.TARKIN_COMMAND_CHOICE,
			"Opponent should observe the public Tarkin modal.")
	assert_true(owner_intent.is_interactive,
			"Owner should be able to answer the Tarkin prompt.")
	assert_false(opponent_intent.is_interactive,
			"Opponent should observe without controlling the prompt.")
	assert_eq(opponent_intent.payload.get("runtime_upgrade_id", ""),
			TARKIN_RUNTIME_ID,
			"Public prompt payload should survive opponent filtering.")


# ---------------------------------------------------------------------------
# Choice Execution
# ---------------------------------------------------------------------------

func test_choice_grants_selected_token_to_friendly_ships_only() -> void:
	_add_imperial_ship("imperial-ship-2")
	_advance_to_ship_phase()

	var result: Dictionary = _submit_choice(Constants.CommandType.REPAIR)

	assert_eq((result.get("grants", []) as Array).size(), 2,
			"Tarkin should grant once per friendly ship.")
	assert_true(_ship(1, 0).command_tokens.has_token(Constants.CommandType.REPAIR),
			"Source friendly ship should gain the chosen token.")
	assert_true(_ship(1, 1).command_tokens.has_token(Constants.CommandType.REPAIR),
			"Second friendly ship should gain the chosen token.")
	assert_false(_ship(0, 0).command_tokens.has_token(Constants.CommandType.REPAIR),
			"Enemy ship must not gain Tarkin's token.")
	assert_eq(_state.interaction_flow.step_id,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			"Choice should transition to normal ship selection.")


func test_granted_tokens_remain_after_tarkin_source_destroyed() -> void:
	_add_imperial_ship("imperial-ship-2")
	_advance_to_ship_phase()

	var result: Dictionary = _submit_choice(Constants.CommandType.NAVIGATE)
	var source_ship: ShipInstance = _ship(1, 0)
	var other_friendly: ShipInstance = _ship(1, 1)
	source_ship.mark_destroyed()

	assert_eq(result.get("command", -1), int(Constants.CommandType.NAVIGATE),
			"Tarkin should resolve with the chosen command.")
	assert_true(source_ship.command_tokens.has_token(Constants.CommandType.NAVIGATE),
			"The source ship should keep the already-granted token.")
	assert_true(other_friendly.command_tokens.has_token(
			Constants.CommandType.NAVIGATE),
			"Other friendly ships should keep already-granted tokens.")
	assert_true(source_ship.is_destroyed(),
			"The ship carrying Tarkin should be destroyed after resolution.")


func test_decline_records_public_guard_without_granting_tokens() -> void:
	_advance_to_ship_phase()

	var result: Dictionary = _submit_decline()
	var runtime_upgrade: Dictionary = _runtime_upgrade()
	var rule_state: Dictionary = runtime_upgrade.get("rule_state", {})
	var last_choice: Dictionary = rule_state.get(
			TARKIN_SCRIPT.RULE_STATE_LAST_CHOICE, {})

	assert_true(result.get("declined", false),
			"Decline should be explicit in the replayable command result.")
	assert_eq(_ship(1, 0).command_tokens.get_token_count(), 0,
			"Decline should not grant command tokens.")
	assert_true(TARKIN_SCRIPT.has_used_this_ship_phase(
			runtime_upgrade, _state.current_round),
			"Decline should still consume the once-per-Ship-Phase guard.")
	assert_true(last_choice.get("declined", false),
			"Runtime upgrade rule_state should publicly record the decline.")


func test_duplicate_granted_token_auto_discards_without_overflow() -> void:
	_ship(1, 0).command_tokens.force_add_token(Constants.CommandType.NAVIGATE)
	_advance_to_ship_phase()

	var result: Dictionary = _submit_choice(Constants.CommandType.NAVIGATE)
	var grant: Dictionary = ((result.get("grants", []) as Array)[0]
			as Dictionary)

	assert_eq(_ship(1, 0).command_tokens.get_token_count(), 1,
			"Duplicate grant should auto-discard back to one token.")
	assert_true(grant.get("duplicate", false),
			"Grant result should report duplicate auto-discard.")
	assert_false(grant.get("overflow", true),
			"Duplicate auto-discard should not create overflow.")


func test_non_duplicate_overflow_reuses_discard_token_command() -> void:
	var source: ShipInstance = _ship(1, 0)
	source.command_tokens.max_tokens = 1
	source.command_tokens.force_add_token(Constants.CommandType.NAVIGATE)
	_advance_to_ship_phase()

	var result: Dictionary = _submit_choice(Constants.CommandType.REPAIR)
	var discard := DiscardTokenCommand.new(1, {
		"ship_index": 0,
		"token_type": int(Constants.CommandType.NAVIGATE),
	})

	assert_true((((result.get("grants", []) as Array)[0] as Dictionary)
			).get("overflow", false),
			"Non-duplicate over-capacity grant should report overflow.")
	assert_eq(source.command_tokens.get_token_count(), 2,
			"Overflow token should remain until DiscardTokenCommand resolves it.")
	assert_eq(discard.validate(_state), "",
			"Existing DiscardTokenCommand should resolve Tarkin overflow.")


func test_token_gain_blocker_prevents_grant_to_blocked_ship() -> void:
	LIFE_SUPPORT_FAILURE_SCRIPT.register()
	_add_life_support_failure(_ship(1, 0))
	_advance_to_ship_phase()

	var result: Dictionary = _submit_choice(Constants.CommandType.SQUADRON)
	var grant: Dictionary = ((result.get("grants", []) as Array)[0]
			as Dictionary)

	assert_true(grant.get("token_blocked", false),
			"Existing token-gain blocker should apply to Tarkin grants.")
	assert_eq(_ship(1, 0).command_tokens.get_token_count(), 0,
			"Blocked ship should not gain a Tarkin token.")


# ---------------------------------------------------------------------------
# Validation / Replay / Persistence
# ---------------------------------------------------------------------------

func test_validate_rejects_wrong_player_wrong_phase_invalid_command_and_duplicate() -> void:
	_advance_to_ship_phase()
	assert_ne(_choice_command(0, Constants.CommandType.NAVIGATE).validate(_state), "",
			"Wrong player should not answer the Tarkin prompt.")
	assert_ne(_choice_command(1, 99).validate(_state), "",
			"Invalid command type should be rejected.")
	_state.current_phase = Constants.GamePhase.COMMAND
	assert_ne(_choice_command(1, Constants.CommandType.NAVIGATE).validate(_state), "",
			"Wrong phase should be rejected.")
	_state.current_phase = Constants.GamePhase.SHIP
	_submit_choice(Constants.CommandType.NAVIGATE)
	assert_ne(_choice_command(1, Constants.CommandType.REPAIR).validate(_state), "",
			"Duplicate Tarkin use in the same Ship Phase should be rejected.")


func test_preflight_blocks_prompt_bypass_until_tarkin_choice_resolves() -> void:
	_advance_to_ship_phase()
	var advance := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.SQUADRON),
	})
	var discard := DiscardTokenCommand.new(1, {
		"ship_index": 0,
		"token_type": int(Constants.CommandType.NAVIGATE),
	})
	var choice: GameCommand = _choice_command(1, Constants.CommandType.NAVIGATE)

	assert_ne(CommandProcessor.preflight(advance, _state), "",
			"advance_phase should not bypass an unresolved Tarkin prompt.")
	assert_ne(CommandProcessor.preflight(discard, _state), "",
			"Other Ship Phase commands should not resolve the prompt.")
	assert_eq(CommandProcessor.preflight(choice, _state), "",
			"The accepted Tarkin choice command should remain legal.")
	choice.execute(_state)
	assert_eq(_state.interaction_flow.step_id,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT,
			"Tarkin choice should be the command path that resolves the prompt.")


func test_validate_rejects_missing_or_destroyed_source() -> void:
	_advance_to_ship_phase()
	var missing := TarkinChoiceCommand.new(1, {
		"runtime_upgrade_id": "missing",
		"command": int(Constants.CommandType.NAVIGATE),
	})
	_ship(1, 0).mark_destroyed()

	assert_ne(missing.validate(_state), "",
			"Unknown runtime_upgrade_id should be rejected.")
	assert_ne(_choice_command(1, Constants.CommandType.NAVIGATE).validate(_state), "",
			"Destroyed Tarkin source should be rejected.")


func test_choice_command_serializes_and_replays_from_history_payload() -> void:
	_advance_to_ship_phase()
	var cmd: GameCommand = _choice_command(1, Constants.CommandType.REPAIR)
	cmd.sequence = 7

	var restored: GameCommand = GameCommand.deserialize(cmd.serialize())
	var result: Dictionary = restored.execute(_state)

	assert_is(restored, TarkinChoiceCommand,
			"Serialized command should deserialize as TarkinChoiceCommand.")
	assert_eq(restored.sequence, 7,
			"Command sequence should round-trip for replay history.")
	assert_eq(result.get("command", -1), int(Constants.CommandType.REPAIR),
			"Replayed command should preserve chosen command.")
	assert_true(_ship(1, 0).command_tokens.has_token(Constants.CommandType.REPAIR),
			"Replayed command should reproduce the token grant.")


func test_prompt_and_choice_state_survive_save_load_and_reconnect() -> void:
	_advance_to_ship_phase()
	var prompt_intent: UIProjector.UIIntent = _project_after_reconnect(_state, 1)

	_submit_choice(Constants.CommandType.CONCENTRATE_FIRE)
	var restored: GameState = GameState.deserialize(_state.serialize())
	var restored_ship: ShipInstance = restored.get_ship(1, 0)
	var restored_upgrade: Dictionary = restored_ship.get_runtime_upgrade(
			TARKIN_RUNTIME_ID)

	assert_eq(prompt_intent.step_id,
			Constants.InteractionStep.TARKIN_COMMAND_CHOICE,
			"Reconnect projection should preserve an unresolved Tarkin prompt.")
	assert_true(TARKIN_SCRIPT.has_used_this_ship_phase(
			restored_upgrade, restored.current_round),
			"Save/load should preserve Tarkin trigger guard.")
	assert_true(restored_ship.command_tokens.has_token(
			Constants.CommandType.CONCENTRATE_FIRE),
			"Save/load should preserve granted Tarkin token.")


func test_multi_ship_grant_order_follows_player_state_ship_order() -> void:
	_add_imperial_ship("imperial-ship-2")
	_add_imperial_ship("imperial-ship-3")
	_advance_to_ship_phase()

	var result: Dictionary = _submit_choice(Constants.CommandType.REPAIR)
	var grants: Array = result.get("grants", []) as Array

	assert_eq((grants[0] as Dictionary).get("ship_index", -1), 0,
			"First grant should target the first PlayerState ship.")
	assert_eq((grants[1] as Dictionary).get("ship_index", -1), 1,
			"Second grant should target the second PlayerState ship.")
	assert_eq((grants[2] as Dictionary).get("ship_index", -1), 2,
			"Third grant should target the third PlayerState ship.")


# ---------------------------------------------------------------------------
# Remote Side Effects
# ---------------------------------------------------------------------------

func test_remote_tarkin_choice_grant_emits_token_refresh_for_granted_ships() -> void:
	_add_imperial_ship("imperial-ship-2")
	_advance_to_ship_phase()
	var result: Dictionary = _submit_choice(Constants.CommandType.REPAIR)

	GameManager._handle_remote_command_effects(
			_choice_command(1, Constants.CommandType.REPAIR), result)

	assert_eq(_token_changed_ships.size(), 2,
			"Remote Tarkin grant should refresh each granted friendly ship.")
	assert_true(_token_changed_ships.has(_ship(1, 0)),
			"Remote side effects should refresh the Tarkin source ship.")
	assert_true(_token_changed_ships.has(_ship(1, 1)),
			"Remote side effects should refresh the second friendly ship.")
	assert_eq(_duplicate_events.size(), 0,
			"Plain grants should not emit duplicate feedback.")
	assert_eq(_discard_required_ships.size(), 0,
			"Plain grants should not request overflow discard.")


func test_remote_tarkin_choice_duplicate_emits_duplicate_feedback_only() -> void:
	_ship(1, 0).command_tokens.force_add_token(Constants.CommandType.NAVIGATE)
	_advance_to_ship_phase()
	var result: Dictionary = _submit_choice(Constants.CommandType.NAVIGATE)

	GameManager._handle_remote_command_effects(
			_choice_command(1, Constants.CommandType.NAVIGATE), result)

	assert_eq(_token_changed_ships.size(), 1,
			"Remote duplicate grant should still refresh token display.")
	assert_eq(_duplicate_events.size(), 1,
			"Remote duplicate grant should emit duplicate discard feedback.")
	assert_eq(_duplicate_events[0].get("ship", null), _ship(1, 0),
			"Duplicate feedback should identify the granted ship.")
	assert_eq(_duplicate_events[0].get("token_type", -1),
			int(Constants.CommandType.NAVIGATE),
			"Duplicate feedback should identify the chosen command token.")
	assert_eq(_discard_required_ships.size(), 0,
			"Duplicate auto-discard must not request manual discard.")


func test_remote_tarkin_choice_overflow_emits_discard_required() -> void:
	var source: ShipInstance = _ship(1, 0)
	source.command_tokens.max_tokens = 1
	source.command_tokens.force_add_token(Constants.CommandType.NAVIGATE)
	_advance_to_ship_phase()
	var result: Dictionary = _submit_choice(Constants.CommandType.REPAIR)

	GameManager._handle_remote_command_effects(
			_choice_command(1, Constants.CommandType.REPAIR), result)

	assert_eq(_token_changed_ships.size(), 1,
			"Remote overflow grant should refresh token display.")
	assert_eq(_discard_required_ships.size(), 1,
			"Remote overflow grant should request manual token discard.")
	assert_eq(_discard_required_ships[0], source,
			"Discard request should identify the overflowing ship.")
	assert_eq(_duplicate_events.size(), 0,
			"Non-duplicate overflow should not emit duplicate feedback.")


func test_remote_tarkin_choice_decline_emits_no_token_side_effects() -> void:
	_advance_to_ship_phase()
	var result: Dictionary = _submit_decline()

	GameManager._handle_remote_command_effects(
			TarkinChoiceCommand.new(1, {
				"runtime_upgrade_id": TARKIN_RUNTIME_ID,
				"declined": true,
			}), result)

	assert_eq(_token_changed_ships.size(), 0,
			"Remote decline should not refresh command tokens.")
	assert_eq(_duplicate_events.size(), 0,
			"Remote decline should not emit duplicate feedback.")
	assert_eq(_discard_required_ships.size(), 0,
			"Remote decline should not request token discard.")


func _make_tarkin_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.COMMAND
	state.initiative_player = 0
	state.get_player_state(0).ships.append(_make_ship(0, "rebel-ship-1", false))
	state.get_player_state(1).ships.append(_make_ship(1, "imperial-ship-1", true))
	return state


func _make_ship(owner: int, roster_entry_id: String,
		with_tarkin: bool) -> ShipInstance:
	var ship_data: ShipData = AssetLoader.load_ship_data(
			"victory_ii_class_star_destroyer")
	var ship: ShipInstance = ShipInstance.create_from_data(
			"victory_ii_class_star_destroyer", ship_data, 2, owner)
	ship.roster_entry_id = roster_entry_id
	if with_tarkin:
		ship.add_runtime_upgrade("grand_moff_tarkin", "imperial-cmd",
				"COMMANDER", 0)
	return ship


func _add_imperial_ship(roster_entry_id: String) -> void:
	_state.get_player_state(1).ships.append(
			_make_ship(1, roster_entry_id, false))


func _advance_to_ship_phase() -> Dictionary:
	var cmd := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.SHIP),
	})
	return cmd.execute(_state)


func _submit_choice(command: int) -> Dictionary:
	var cmd: GameCommand = _choice_command(1, command)
	assert_eq(cmd.validate(_state), "",
			"Tarkin choice precondition should be valid.")
	return cmd.execute(_state)


func _submit_decline() -> Dictionary:
	var cmd := TarkinChoiceCommand.new(1, {
		"runtime_upgrade_id": TARKIN_RUNTIME_ID,
		"declined": true,
	})
	assert_eq(cmd.validate(_state), "",
			"Tarkin decline precondition should be valid.")
	return cmd.execute(_state)


func _choice_command(player: int,
		command: int) -> TarkinChoiceCommand:
	return TarkinChoiceCommand.new(player, {
		"runtime_upgrade_id": TARKIN_RUNTIME_ID,
		"command": int(command),
	})


func _runtime_upgrade() -> Dictionary:
	return _ship(1, 0).get_runtime_upgrade(TARKIN_RUNTIME_ID)


func _ship(player: int, ship_index: int) -> ShipInstance:
	return _state.get_ship(player, ship_index)


func _project_after_reconnect(
		server_state: GameState,
		viewer: int) -> UIProjector.UIIntent:
	var raw: Dictionary = server_state.serialize()
	var filtered: Dictionary = StateFilter.filter_for_player(raw, viewer)
	var client_state: GameState = GameState.deserialize(filtered)
	return UIProjector.project(client_state, viewer)


func _add_life_support_failure(ship: ShipInstance) -> void:
	var card: DamageCard = DamageCard.create("Crew", "Life Support Failure")
	card.effect_id = "life_support_failure"
	card.flip_faceup()
	ship.faceup_damage.append(card)


func _on_command_tokens_changed(ship: RefCounted) -> void:
	_token_changed_ships.append(ship as ShipInstance)


func _on_duplicate_token_discarded(
		ship: RefCounted,
		token_type: int) -> void:
	_duplicate_events.append({
		"ship": ship,
		"token_type": token_type,
	})


func _on_token_discard_required(ship: RefCounted) -> void:
	_discard_required_ships.append(ship as ShipInstance)
