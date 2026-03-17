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


func test_activate_ship_as_token_duplicate_token_rejected() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 2)
	_setup_game_in_ship_phase([ship], [])
	# Pre-load a NAVIGATE token so the second one is a duplicate.
	ship.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	_tokens_changed_ships.clear()
	var result: Dictionary = GameManager.activate_ship_as_token(ship)
	assert_false(result.is_empty(),
			"Activation should still succeed even if token rejected")
	assert_false(result["token_added"],
			"Token should be rejected — duplicate (CM-005)")
	assert_eq(ship.command_tokens.get_token_count(), 1,
			"Token count should remain 1 (duplicate rejected)")


func test_activate_ship_as_token_overflow_rejected() -> void:
	var ship: ShipInstance = _create_ship_with_dials_and_command_value(0, 1, 1)
	_setup_game_in_ship_phase([ship], [])
	# Fill the token slot with a different type so it's at capacity.
	ship.command_tokens.add_token(Constants.CommandType.REPAIR)
	_tokens_changed_ships.clear()
	var result: Dictionary = GameManager.activate_ship_as_token(ship)
	assert_false(result["token_added"],
			"Token should be rejected — overflow (CM-004)")
	assert_eq(ship.command_tokens.get_token_count(), 1,
			"Token count should remain 1 (overflow rejected)")
	# tokens_changed should NOT be emitted when token wasn't added.
	assert_false(_tokens_changed_ships.has(ship),
			"command_tokens_changed should NOT fire when token rejected")


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
