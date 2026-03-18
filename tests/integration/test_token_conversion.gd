## test_token_conversion.gd
##
## Integration tests for Phase 4d: Keep-or-Convert Dial Choice.
## Tests GameManager.activate_ship_as_token(), ShipCardPanel drop detection,
## help text creation/cleanup, and the full token conversion activation path.
##
## Requirements: UI-027 (help text), UI-028 (drag-to-card converts to token),
## SP-011 (keep-or-convert), CM-004–006 (token rules).
extends GutTest


# --- Signal trackers ---
var _dials_changed_ships: Array = []
var _tokens_changed_ships: Array = []
var _active_player_changes: Array = []


func before_each() -> void:
	_dials_changed_ships.clear()
	_tokens_changed_ships.clear()
	_active_player_changes.clear()
	if not EventBus.command_dials_changed.is_connected(_track_dials_changed):
		EventBus.command_dials_changed.connect(_track_dials_changed)
	if not EventBus.command_tokens_changed.is_connected(_track_tokens_changed):
		EventBus.command_tokens_changed.connect(_track_tokens_changed)
	if not EventBus.active_player_changed.is_connected(_track_active_player):
		EventBus.active_player_changed.connect(_track_active_player)


func after_each() -> void:
	if EventBus.command_dials_changed.is_connected(_track_dials_changed):
		EventBus.command_dials_changed.disconnect(_track_dials_changed)
	if EventBus.command_tokens_changed.is_connected(_track_tokens_changed):
		EventBus.command_tokens_changed.disconnect(_track_tokens_changed)
	if EventBus.active_player_changed.is_connected(_track_active_player):
		EventBus.active_player_changed.disconnect(_track_active_player)
	GameManager.end_game()


func _track_dials_changed(ship: RefCounted) -> void:
	_dials_changed_ships.append(ship)


func _track_tokens_changed(ship: RefCounted) -> void:
	_tokens_changed_ships.append(ship)


func _track_active_player(player: int) -> void:
	_active_player_changes.append(player)


# ---------------------------------------------------------------------------
# Two-step reveal flow: first click reveals, second click drags
# ---------------------------------------------------------------------------

func test_first_click_reveals_dial_on_stack() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	# Simulate first click: reveal top dial (stays on stack).
	var dial: Dictionary = ship.command_dial_stack.reveal_top()
	assert_false(dial.is_empty(),
			"reveal_top should return the dial")
	assert_eq(dial["state"], CommandDialStack.STATE_REVEALED,
			"Dial should be revealed after first click")
	assert_eq(int(dial["command"]), Constants.CommandType.NAVIGATE,
			"Revealed command should be NAVIGATE")
	# Dial is still on the stack (not dragged yet).
	assert_eq(ship.command_dial_stack.get_dial_count(), 1,
			"Dial should still be in the stack after reveal")


func test_second_click_can_use_already_revealed_dial() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	# First click: reveal.
	ship.command_dial_stack.reveal_top()
	# Second click: read revealed dial for drag (what game_board does).
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	assert_false(revealed.is_empty(),
			"Revealed dial should be available for second click")
	assert_eq(int(revealed["command"]), Constants.CommandType.NAVIGATE,
			"Revealed command should be NAVIGATE")


func test_cancel_after_reveal_unreveals_dial() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	ship.command_dial_stack.reveal_top()
	ship.command_dial_stack.unreveal_top()
	assert_eq(ship.command_dial_stack.get_hidden_count(), 1,
			"Hidden count should be 1 after unreveal")
	assert_true(ship.command_dial_stack.get_revealed_dial().is_empty(),
			"No revealed dial after unreveal")


func test_is_ship_phase_eligible_true_for_own_ship() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	assert_true(panel._is_ship_phase_eligible(ship),
			"Should be eligible during Ship Phase for own unactivated ship")


func test_is_ship_phase_eligible_true_even_after_reveal() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	# First click: reveal dial (hidden count becomes 0).
	ship.command_dial_stack.reveal_top()
	assert_true(panel._is_ship_phase_eligible(ship),
			"Should still be eligible after reveal (for second click)")


func test_activate_ship_works_with_already_revealed() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	ship.command_dial_stack.reveal_top()
	GameManager.activate_ship(ship)
	assert_eq(GameManager.get_activating_ship(), ship,
			"Ship should be activated even with pre-revealed dial")
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	assert_false(revealed.is_empty(),
			"Dial should still be revealed after activate_ship")


func test_activate_as_token_works_with_already_revealed() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	ship.command_dial_stack.reveal_top()
	var result: Dictionary = GameManager.activate_ship_as_token(ship)
	assert_false(result.is_empty(),
			"activate_ship_as_token should succeed with pre-revealed dial")
	assert_eq(int(result["command"]), Constants.CommandType.NAVIGATE,
			"Should return NAVIGATE command type")
	assert_true(result["token_added"],
			"Token should be added")


## Regression: CR90 (command value 1) — after step 1, the revealed dial's
## composite Control must have nonzero size so the second click can hit it.
## This is a domain-level test: after reveal on a 1-dial ship, the revealed
## dial should be retrievable for step 2 (the visual hit-test fix is in
## _create_dial_rect setting size alongside custom_minimum_size).
func test_one_dial_ship_step2_after_reveal() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	# Step 1: reveal the only dial.
	ship.command_dial_stack.reveal_top()
	assert_eq(ship.command_dial_stack.get_hidden_count(), 0,
			"Hidden count should be 0 after revealing the only dial")
	# Step 2: the revealed dial should still be available.
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	assert_false(revealed.is_empty(),
			"Revealed dial must be available for step 2 on a 1-dial ship")
	# Can activate with it.
	GameManager.activate_ship(ship)
	assert_eq(GameManager.get_activating_ship(), ship,
			"1-dial ship should activate successfully after reveal")


## Regression: clicking step 1 on ship B should unreveal ship A's dial
## (player changed their mind).
func test_unreveal_other_ships_on_step1() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var ship_a: ShipInstance = _create_ship_with_dials(0, 1)
	ship_a.data_key = "ship_a"
	var ship_b: ShipInstance = _create_ship_with_dials(0, 2)
	ship_b.data_key = "ship_b"
	panel.add_ship_entry(ship_a)
	panel.add_ship_entry(ship_b)
	_setup_game_in_ship_phase([ship_a, ship_b], [])
	# Step 1 on ship A.
	ship_a.command_dial_stack.reveal_top()
	assert_false(ship_a.command_dial_stack.get_revealed_dial().is_empty(),
			"Ship A dial should be revealed")
	# Now step 1 on ship B through the panel helper.
	panel._unreveal_other_ships(ship_b)
	assert_true(ship_a.command_dial_stack.get_revealed_dial().is_empty(),
			"Ship A's dial should be unrevealed when step 1 starts on ship B")
	assert_eq(ship_a.command_dial_stack.get_hidden_count(), 1,
			"Ship A should have 1 hidden dial again")


# ---------------------------------------------------------------------------
# activate_ship_as_token — core domain tests
# ---------------------------------------------------------------------------

func test_activate_ship_as_token_reveals_and_spends_dial() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	var result: Dictionary = GameManager.activate_ship_as_token(ship)
	assert_false(result.is_empty(),
			"activate_ship_as_token should return a non-empty result")
	assert_eq(int(result["command"]), Constants.CommandType.NAVIGATE,
			"Revealed command should be NAVIGATE")
	# The dial should be spent — no revealed dial remains.
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	assert_true(revealed.is_empty(),
			"Dial should be immediately spent (no revealed dial)")
	# Spent history should contain the dial.
	assert_eq(ship.command_dial_stack.get_spent_history().size(), 1,
			"Spent history should have 1 entry after token conversion")


func test_activate_ship_as_token_adds_command_token() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	var result: Dictionary = GameManager.activate_ship_as_token(ship)
	assert_true(result["token_added"],
			"Token should be added successfully")
	assert_true(ship.command_tokens.has_token(Constants.CommandType.NAVIGATE),
			"Ship should now hold a NAVIGATE command token")


func test_activate_ship_as_token_sets_activating_ship() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	GameManager.activate_ship_as_token(ship)
	assert_eq(GameManager.get_activating_ship(), ship,
			"get_activating_ship() should return the activated ship")


func test_activate_ship_as_token_emits_dials_changed() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	_dials_changed_ships.clear()
	GameManager.activate_ship_as_token(ship)
	assert_true(_dials_changed_ships.has(ship),
			"command_dials_changed should fire for the activated ship")


func test_activate_ship_as_token_emits_tokens_changed() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	_tokens_changed_ships.clear()
	GameManager.activate_ship_as_token(ship)
	assert_true(_tokens_changed_ships.has(ship),
			"command_tokens_changed should fire when token is added")


func test_activate_ship_as_token_duplicate_token_auto_discarded() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 2)
	_setup_game_in_ship_phase([ship], [])
	# Pre-load a NAVIGATE token so the second one is a duplicate.
	ship.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	_tokens_changed_ships.clear()
	var result: Dictionary = GameManager.activate_ship_as_token(ship)
	assert_false(result.is_empty(),
			"Activation should succeed even with duplicate token")
	# force_add_token adds the duplicate, then auto-discards it (CM-005).
	assert_true(result["token_added"],
			"Token should be force-added before auto-discard")
	assert_eq(ship.command_tokens.get_token_count(), 1,
			"Token count should be 1 after duplicate auto-discard")
	assert_false(result.get("needs_discard", false),
			"Duplicate does not require player discard choice")


func test_activate_ship_as_token_overflow_needs_discard() -> void:
	var ship: ShipInstance = _create_ship_with_dials_and_command_value(0, 1, 1)
	_setup_game_in_ship_phase([ship], [])
	# Fill the token slot with a different type so it's at capacity.
	ship.command_tokens.add_token(Constants.CommandType.REPAIR)
	_tokens_changed_ships.clear()
	var result: Dictionary = GameManager.activate_ship_as_token(ship)
	assert_true(result["token_added"],
			"Token should be force-added despite overflow")
	assert_true(result.get("needs_discard", false),
			"Overflow should require player to discard a token (CM-004)")
	assert_eq(ship.command_tokens.get_token_count(), 2,
			"Both tokens should be present until player resolves discard")


func test_activate_ship_as_token_rejects_already_activated() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	ship.activated_this_round = true
	var prev_level: GameLogger.Level = GameLogger.min_level
	GameLogger.min_level = GameLogger.Level.ERROR
	var result: Dictionary = GameManager.activate_ship_as_token(ship)
	GameLogger.min_level = prev_level
	assert_true(result.is_empty(),
			"Should not activate an already-activated ship")


func test_activate_ship_as_token_rejects_when_another_activating() -> void:
	var ship_a: ShipInstance = _create_ship_with_dials(0, 1)
	var ship_b: ShipInstance = _create_ship_with_dials(0, 1)
	ship_b.data_key = "test_ship_b"
	_setup_game_in_ship_phase([ship_a, ship_b], [])
	GameManager.activate_ship(ship_a)
	var prev_level: GameLogger.Level = GameLogger.min_level
	GameLogger.min_level = GameLogger.Level.ERROR
	var result: Dictionary = GameManager.activate_ship_as_token(ship_b)
	GameLogger.min_level = prev_level
	assert_true(result.is_empty(),
			"Should not activate while another ship is activating")


# ---------------------------------------------------------------------------
# End Activation after token conversion — dial already spent
# ---------------------------------------------------------------------------

func test_activation_ended_after_token_convert_marks_activated() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [_create_ship_with_dials(1, 1)])
	GameManager.activate_ship_as_token(ship)
	EventBus.activation_ended.emit()
	assert_true(ship.activated_this_round,
			"Ship should be marked activated after End Activation")


func test_activation_ended_after_token_convert_clears_activating() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [_create_ship_with_dials(1, 1)])
	GameManager.activate_ship_as_token(ship)
	EventBus.activation_ended.emit()
	assert_null(GameManager.get_activating_ship(),
			"Activating ship should be cleared after End Activation")


func test_activation_ended_after_token_convert_does_not_double_spend() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [_create_ship_with_dials(1, 1)])
	GameManager.activate_ship_as_token(ship)
	# Dial was already spent by activate_ship_as_token.
	assert_eq(ship.command_dial_stack.get_spent_history().size(), 1,
			"Should have 1 spent dial before End Activation")
	EventBus.activation_ended.emit()
	# Should still be exactly 1 — no double-spend.
	assert_eq(ship.command_dial_stack.get_spent_history().size(), 1,
			"Should still have 1 spent dial (no double-spend)")


func test_activation_ended_after_token_convert_advances_turn() -> void:
	var rebel: ShipInstance = _create_ship_with_dials(0, 1)
	var imperial: ShipInstance = _create_ship_with_dials(1, 1)
	_setup_game_in_ship_phase([rebel], [imperial])
	GameManager.activate_ship_as_token(rebel)
	_active_player_changes.clear()
	EventBus.activation_ended.emit()
	assert_true(_active_player_changes.size() >= 1,
			"activation_ended should advance turn to next player")
	assert_eq(_active_player_changes[-1], 1,
			"Turn should pass to player 1 after player 0 activates")


# ---------------------------------------------------------------------------
# ShipCardPanel.get_ship_instance_at_screen_pos
# ---------------------------------------------------------------------------

func test_get_ship_instance_at_screen_pos_returns_null_for_empty_panel() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var result: ShipInstance = panel.get_ship_instance_at_screen_pos(
			Vector2(100, 100))
	assert_null(result,
			"Empty panel should return null for any position")


# ---------------------------------------------------------------------------
# Full cycle: token convert → End Activation → next player → activate → end
# ---------------------------------------------------------------------------

func test_full_cycle_token_convert_then_board_drop() -> void:
	var rebel: ShipInstance = _create_ship_with_dials(0, 1)
	var imperial: ShipInstance = _create_ship_with_dials(1, 1)
	_setup_game_in_ship_phase([rebel], [imperial])

	# Player 0: convert dial to token.
	GameManager.activate_ship_as_token(rebel)
	EventBus.activation_ended.emit()
	assert_true(rebel.activated_this_round,
			"Rebel ship should be activated")
	assert_true(rebel.command_tokens.has_token(Constants.CommandType.NAVIGATE),
			"Rebel ship should hold a NAVIGATE token")
	assert_eq(GameManager.get_active_player(), 1,
			"Turn should pass to player 1")

	# Player 1: normal board drop activation.
	GameManager.activate_ship(imperial)
	EventBus.activation_ended.emit()

	# Both done — phase cascades.
	assert_eq(GameManager.get_current_phase(),
			Constants.GamePhase.COMMAND,
			"Should cascade to Command Phase of next round")
	assert_eq(GameManager.get_current_round(), 2,
			"Should be round 2 after both ships activated")


# ---------------------------------------------------------------------------
# Phase 4e: Token Overflow Discard Flow
# ---------------------------------------------------------------------------

## Signal trackers for Phase 4e.
var _discard_required_ships: Array = []
var _discarded_events: Array = []
var _duplicate_discarded_events: Array = []


func _track_discard_required(ship: RefCounted) -> void:
	_discard_required_ships.append(ship)


func _track_token_discarded(ship: RefCounted, cmd: int) -> void:
	_discarded_events.append({"ship": ship, "command": cmd})


func _track_duplicate_discarded(ship: RefCounted, cmd: int) -> void:
	_duplicate_discarded_events.append({"ship": ship, "command": cmd})


func _connect_phase4e_signals() -> void:
	_discard_required_ships.clear()
	_discarded_events.clear()
	_duplicate_discarded_events.clear()
	if not EventBus.token_discard_required.is_connected(
			_track_discard_required):
		EventBus.token_discard_required.connect(_track_discard_required)
	if not EventBus.token_discarded.is_connected(_track_token_discarded):
		EventBus.token_discarded.connect(_track_token_discarded)
	if not EventBus.duplicate_token_discarded.is_connected(
			_track_duplicate_discarded):
		EventBus.duplicate_token_discarded.connect(
				_track_duplicate_discarded)


func _disconnect_phase4e_signals() -> void:
	if EventBus.token_discard_required.is_connected(
			_track_discard_required):
		EventBus.token_discard_required.disconnect(_track_discard_required)
	if EventBus.token_discarded.is_connected(_track_token_discarded):
		EventBus.token_discarded.disconnect(_track_token_discarded)
	if EventBus.duplicate_token_discarded.is_connected(
			_track_duplicate_discarded):
		EventBus.duplicate_token_discarded.disconnect(
				_track_duplicate_discarded)


func test_overflow_emits_token_discard_required() -> void:
	_connect_phase4e_signals()
	var ship: ShipInstance = _create_ship_with_dials_and_command_value(0, 1, 1)
	_setup_game_in_ship_phase([ship], [])
	ship.command_tokens.add_token(Constants.CommandType.REPAIR)
	GameManager.activate_ship_as_token(ship)
	assert_eq(_discard_required_ships.size(), 1,
			"token_discard_required should fire once for overflow")
	assert_eq(_discard_required_ships[0], ship,
			"Signal should reference the overflowing ship")
	_disconnect_phase4e_signals()


func test_duplicate_emits_duplicate_token_discarded() -> void:
	_connect_phase4e_signals()
	var ship: ShipInstance = _create_ship_with_dials(0, 2)
	_setup_game_in_ship_phase([ship], [])
	ship.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	GameManager.activate_ship_as_token(ship)
	assert_eq(_duplicate_discarded_events.size(), 1,
			"duplicate_token_discarded should fire once")
	assert_eq(_duplicate_discarded_events[0]["command"],
			Constants.CommandType.NAVIGATE,
			"Should report NAVIGATE as the discarded duplicate")
	assert_eq(_discard_required_ships.size(), 0,
			"Overflow signal should NOT fire for duplicate scenario")
	_disconnect_phase4e_signals()


func test_overflow_resolved_by_manual_discard() -> void:
	_connect_phase4e_signals()
	var ship: ShipInstance = _create_ship_with_dials_and_command_value(0, 1, 1)
	_setup_game_in_ship_phase([ship], [])
	ship.command_tokens.add_token(Constants.CommandType.REPAIR)
	var result: Dictionary = GameManager.activate_ship_as_token(ship)
	assert_true(result.get("needs_discard", false),
			"Should need discard")
	# Player picks REPAIR to discard (simulates ShipCardPanel click).
	ship.command_tokens.remove_token(Constants.CommandType.REPAIR)
	EventBus.command_tokens_changed.emit(ship)
	EventBus.token_discarded.emit(ship, Constants.CommandType.REPAIR)
	assert_eq(ship.command_tokens.get_token_count(), 1,
			"Should have 1 token after discard")
	assert_true(ship.command_tokens.has_token(Constants.CommandType.NAVIGATE),
			"Remaining token should be NAVIGATE")
	assert_eq(_discarded_events.size(), 1,
			"token_discarded should fire once")
	_disconnect_phase4e_signals()


func test_no_overflow_no_discard_signals() -> void:
	_connect_phase4e_signals()
	var ship: ShipInstance = _create_ship_with_dials(0, 2)
	_setup_game_in_ship_phase([ship], [])
	# No pre-existing tokens — adding one should be fine.
	var result: Dictionary = GameManager.activate_ship_as_token(ship)
	assert_true(result["token_added"],
			"Token should be added normally")
	assert_false(result.get("needs_discard", false),
			"Should not need discard")
	assert_eq(_discard_required_ships.size(), 0,
			"No overflow signal should fire")
	assert_eq(_duplicate_discarded_events.size(), 0,
			"No duplicate signal should fire")
	_disconnect_phase4e_signals()


func test_magnify_blocked_during_discard_mode() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var ship: ShipInstance = _create_ship_with_dials_and_command_value(0, 1, 1)
	_setup_game_in_ship_phase([ship], [])
	panel.add_ship_entry(ship)
	# Pre-fill the single token slot.
	ship.command_tokens.add_token(Constants.CommandType.REPAIR)
	# Trigger overflow — enters discard mode in the panel.
	GameManager.activate_ship_as_token(ship)
	assert_true(panel.is_in_discard_mode(),
			"Panel should be in discard mode after overflow")
	# Try to magnify — should be blocked.
	var entry: Dictionary = panel._entries[0]
	assert_false(entry["magnified"],
			"Entry should start unmagnified")
	# Simulate a left-click on the entry (what _on_entry_gui_input does).
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	panel._on_entry_gui_input(click, 0)
	assert_false(entry["magnified"],
			"Entry should remain unmagnified — magnify blocked during discard")
	assert_true(panel.is_in_discard_mode(),
			"Panel should still be in discard mode after blocked magnify")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a ShipInstance with [param dial_count] NAVIGATE dials assigned
## (round 1). Command value matches dial_count.
func _create_ship_with_dials(player: int, dial_count: int) -> ShipInstance:
	var ship: ShipInstance = ShipInstance.new()
	ship.owner_player = player
	ship.activated_this_round = false
	ship.data_key = "test_ship"
	ship.ship_data = ShipData.new()
	ship.ship_data.ship_name = "Test Ship"
	ship.command_dial_stack = CommandDialStack.create(dial_count)
	ship.command_tokens = CommandTokenManager.create(dial_count)
	var cmds: Array = []
	for _i: int in range(dial_count):
		cmds.append(Constants.CommandType.NAVIGATE)
	ship.command_dial_stack.assign_dials(cmds, 1)
	return ship


## Creates a ShipInstance with a specific command value (may differ from
## dial count). Used to test overflow scenarios where max_tokens < dials.
func _create_ship_with_dials_and_command_value(
		player: int, dial_count: int,
		cmd_value: int) -> ShipInstance:
	var ship: ShipInstance = ShipInstance.new()
	ship.owner_player = player
	ship.activated_this_round = false
	ship.data_key = "test_ship"
	ship.ship_data = ShipData.new()
	ship.ship_data.ship_name = "Test Ship"
	ship.command_dial_stack = CommandDialStack.create(cmd_value)
	ship.command_tokens = CommandTokenManager.create(cmd_value)
	var cmds: Array = []
	for _i: int in range(dial_count):
		cmds.append(Constants.CommandType.NAVIGATE)
	ship.command_dial_stack.assign_dials(cmds, 1)
	return ship


## Sets up a game in Ship Phase with the given rebel and imperial ships.
func _setup_game_in_ship_phase(
		rebel_ships: Array, imperial_ships: Array) -> void:
	GameManager.start_new_game()
	var gs: GameState = GameManager.current_game_state
	for ship: Variant in rebel_ships:
		if ship is ShipInstance:
			gs.get_player_state(0).ships.append(ship)
	for ship: Variant in imperial_ships:
		if ship is ShipInstance:
			gs.get_player_state(1).ships.append(ship)
	# Advance to Ship Phase.
	EventBus.command_dials_submitted.emit(0)
	EventBus.command_dials_submitted.emit(1)
