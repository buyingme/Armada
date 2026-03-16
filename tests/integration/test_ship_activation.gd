## Test: Ship Activation via Dial Drag-and-Drop (Phase 4c)
##
## Integration tests for the ship activation trigger: drag initiation from the
## card panel, GameManager activation tracking (reveal / spend / mark), and
## turn advancement after End Activation.
## Requirements: UI-024, UI-025, UI-026, SP-010, SP-011, SP-002.
extends GutTest


var _active_player_changes: Array[int] = []
var _dials_changed_ships: Array[RefCounted] = []
var _drag_started_count: int = 0
var _drag_cancelled_count: int = 0


func before_each() -> void:
	_active_player_changes.clear()
	_dials_changed_ships.clear()
	_drag_started_count = 0
	_drag_cancelled_count = 0
	EventBus.active_player_changed.connect(_on_active_player_changed)
	EventBus.command_dials_changed.connect(_on_command_dials_changed)
	EventBus.dial_drag_started.connect(_on_dial_drag_started)
	EventBus.dial_drag_cancelled.connect(_on_dial_drag_cancelled)
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT


func after_each() -> void:
	if EventBus.active_player_changed.is_connected(
			_on_active_player_changed):
		EventBus.active_player_changed.disconnect(
				_on_active_player_changed)
	if EventBus.command_dials_changed.is_connected(
			_on_command_dials_changed):
		EventBus.command_dials_changed.disconnect(
				_on_command_dials_changed)
	if EventBus.dial_drag_started.is_connected(
			_on_dial_drag_started):
		EventBus.dial_drag_started.disconnect(
				_on_dial_drag_started)
	if EventBus.dial_drag_cancelled.is_connected(
			_on_dial_drag_cancelled):
		EventBus.dial_drag_cancelled.disconnect(
				_on_dial_drag_cancelled)
	GameManager.is_game_active = false
	GameManager.current_game_state = null
	GameManager._activating_ship = null
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT


func _on_active_player_changed(player_index: int) -> void:
	_active_player_changes.append(player_index)


func _on_command_dials_changed(inst: RefCounted) -> void:
	_dials_changed_ships.append(inst)


func _on_dial_drag_started(_inst: RefCounted) -> void:
	_drag_started_count += 1


func _on_dial_drag_cancelled() -> void:
	_drag_cancelled_count += 1


# ---------------------------------------------------------------------------
# GameManager.activate_ship()
# ---------------------------------------------------------------------------

func test_activate_ship_reveals_top_dial() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	GameManager.activate_ship(ship)
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	assert_false(revealed.is_empty(),
			"Top dial should be revealed after activate_ship()")
	assert_eq(int(revealed.get("command", -1)),
			Constants.CommandType.NAVIGATE,
			"Revealed dial should be NAVIGATE (first assigned)")


func test_activate_ship_sets_activating_ship() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	GameManager.activate_ship(ship)
	assert_eq(GameManager.get_activating_ship(), ship,
			"get_activating_ship() should return the activated ship")


func test_activate_ship_emits_command_dials_changed() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	_dials_changed_ships.clear()
	GameManager.activate_ship(ship)
	assert_true(_dials_changed_ships.has(ship),
			"command_dials_changed should fire for the activated ship")


func test_activate_ship_rejects_already_activated() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	ship.activated_this_round = true
	var prev_level: GameLogger.Level = GameLogger.min_level
	GameLogger.min_level = GameLogger.Level.ERROR
	GameManager.activate_ship(ship)
	GameLogger.min_level = prev_level
	assert_null(GameManager.get_activating_ship(),
			"Should not activate an already-activated ship")


func test_activate_ship_rejects_when_another_is_activating() -> void:
	var ship_a: ShipInstance = _create_ship_with_dials(0, 1)
	var ship_b: ShipInstance = _create_ship_with_dials(0, 1)
	ship_b.data_key = "test_ship_b"
	_setup_game_in_ship_phase([ship_a, ship_b], [])
	GameManager.activate_ship(ship_a)
	var prev_level: GameLogger.Level = GameLogger.min_level
	GameLogger.min_level = GameLogger.Level.ERROR
	GameManager.activate_ship(ship_b)
	GameLogger.min_level = prev_level
	assert_eq(GameManager.get_activating_ship(), ship_a,
			"Second activation should be rejected while first is active")


func test_activate_ship_rejects_empty_dial_stack() -> void:
	var ship: ShipInstance = ShipInstance.new()
	ship.owner_player = 0
	ship.data_key = "test_ship"
	ship.command_dial_stack = CommandDialStack.create(1)
	# No dials assigned — stack is empty.
	_setup_game_in_ship_phase([ship], [])
	var prev_level: GameLogger.Level = GameLogger.min_level
	GameLogger.min_level = GameLogger.Level.ERROR
	GameManager.activate_ship(ship)
	GameLogger.min_level = prev_level
	assert_null(GameManager.get_activating_ship(),
			"Should not activate ship with no dials")


# ---------------------------------------------------------------------------
# _on_activation_ended — Ship Phase: spend + mark + advance
# ---------------------------------------------------------------------------

func test_activation_ended_spends_revealed_dial() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [_create_ship_with_dials(1, 1)])
	GameManager.activate_ship(ship)
	EventBus.activation_ended.emit()
	var revealed: Dictionary = ship.command_dial_stack.get_revealed_dial()
	assert_true(revealed.is_empty(),
			"Revealed dial should be spent after activation_ended")


func test_activation_ended_marks_ship_activated() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [_create_ship_with_dials(1, 1)])
	GameManager.activate_ship(ship)
	EventBus.activation_ended.emit()
	assert_true(ship.activated_this_round,
			"Ship should be marked activated after activation_ended")


func test_activation_ended_clears_activating_ship() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [_create_ship_with_dials(1, 1)])
	GameManager.activate_ship(ship)
	EventBus.activation_ended.emit()
	assert_null(GameManager.get_activating_ship(),
			"Activating ship should be cleared after activation_ended")


func test_activation_ended_emits_dials_changed() -> void:
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [_create_ship_with_dials(1, 1)])
	GameManager.activate_ship(ship)
	_dials_changed_ships.clear()
	EventBus.activation_ended.emit()
	assert_true(_dials_changed_ships.has(ship),
			"command_dials_changed should fire on activation_ended")


func test_activation_ended_advances_turn() -> void:
	var rebel: ShipInstance = _create_ship_with_dials(0, 1)
	var imperial: ShipInstance = _create_ship_with_dials(1, 1)
	_setup_game_in_ship_phase([rebel], [imperial])
	GameManager.activate_ship(rebel)
	_active_player_changes.clear()
	EventBus.activation_ended.emit()
	assert_true(_active_player_changes.size() >= 1,
			"activation_ended should advance turn to next player")
	assert_eq(_active_player_changes[-1], 1,
			"Turn should pass to player 1 after player 0 activates")


# ---------------------------------------------------------------------------
# Full activation cycle: activate → end → next player → activate → end → phase
# ---------------------------------------------------------------------------

func test_full_ship_phase_cycle_both_players_activate() -> void:
	var rebel: ShipInstance = _create_ship_with_dials(0, 1)
	var imperial: ShipInstance = _create_ship_with_dials(1, 1)
	_setup_game_in_ship_phase([rebel], [imperial])

	# Player 0 (initiative) activates.
	GameManager.activate_ship(rebel)
	EventBus.activation_ended.emit()
	# Rebel's dial was spent (appears in spent history).
	assert_eq(rebel.command_dial_stack.get_spent_history().size(), 1,
			"Rebel ship should have 1 spent dial after End Activation")
	assert_eq(GameManager.get_active_player(), 1,
			"Turn should pass to player 1")

	# Player 1 activates.
	GameManager.activate_ship(imperial)
	EventBus.activation_ended.emit()
	# Imperial's dial was spent.
	assert_eq(imperial.command_dial_stack.get_spent_history().size(), 1,
			"Imperial ship should have 1 spent dial after End Activation")

	# Both done — phase cascades through Squadron+Status to next round.
	# Note: Status Phase resets activated_this_round, so check round/phase.
	assert_eq(GameManager.get_current_phase(),
			Constants.GamePhase.COMMAND,
			"Should cascade to Command Phase of next round")
	assert_eq(GameManager.get_current_round(), 2,
			"Should be round 2 after both ships activated")


# ---------------------------------------------------------------------------
# ShipCardPanel._can_start_dial_drag — guard conditions
# ---------------------------------------------------------------------------

func test_can_start_dial_drag_true_in_ship_phase() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	assert_true(panel._can_start_dial_drag(ship),
			"Should allow drag during Ship Phase for own unactivated ship")


func test_can_start_dial_drag_false_in_command_phase() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	GameManager.start_new_game()
	# Phase is COMMAND by default after start_new_game.
	GameManager.current_game_state.get_player_state(0).ships.append(ship)
	assert_false(panel._can_start_dial_drag(ship),
			"Should not allow drag during Command Phase")


func test_can_start_dial_drag_false_for_opponent_ship() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.GALACTIC_EMPIRE, false, 1)
	var ship: ShipInstance = _create_ship_with_dials(1, 1)
	_setup_game_in_ship_phase([], [ship])
	# Active player is 0 (initiative), but ship belongs to player 1.
	assert_false(panel._can_start_dial_drag(ship),
			"Should not allow drag for opponent's ship")


func test_can_start_dial_drag_false_when_activated() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var ship: ShipInstance = _create_ship_with_dials(0, 1)
	_setup_game_in_ship_phase([ship], [])
	ship.activated_this_round = true
	assert_false(panel._can_start_dial_drag(ship),
			"Should not allow drag for already-activated ship")


func test_can_start_dial_drag_false_when_no_hidden_dials() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var ship: ShipInstance = ShipInstance.new()
	ship.owner_player = 0
	ship.data_key = "test_ship"
	ship.command_dial_stack = CommandDialStack.create(1)
	# No dials assigned — hidden count is 0.
	_setup_game_in_ship_phase([ship], [])
	assert_false(panel._can_start_dial_drag(ship),
			"Should not allow drag when no hidden dials remain")


func test_can_start_dial_drag_false_when_another_is_activating() -> void:
	var panel: ShipCardPanel = ShipCardPanel.new()
	add_child_autofree(panel)
	panel.setup(Constants.Faction.REBEL_ALLIANCE, true, 0)
	var ship_a: ShipInstance = _create_ship_with_dials(0, 1)
	var ship_b: ShipInstance = _create_ship_with_dials(0, 1)
	ship_b.data_key = "test_ship_b"
	_setup_game_in_ship_phase([ship_a, ship_b], [])
	GameManager.activate_ship(ship_a)
	assert_false(panel._can_start_dial_drag(ship_b),
			"Should not allow drag while another ship is being activated")


# ---------------------------------------------------------------------------
# ShipToken.show_revealed_dial / hide_revealed_dial
# ---------------------------------------------------------------------------

func test_show_revealed_dial_creates_child_sprite() -> void:
	var token: ShipToken = ShipToken.new()
	add_child_autofree(token)
	# Manually set base dimensions needed by show_revealed_dial.
	token._half_w = 50.0
	token._half_l = 80.0
	token.show_revealed_dial(Constants.CommandType.NAVIGATE)
	# The sprite is added as a child.
	var found_sprite: bool = false
	for child: Node in token.get_children():
		if child is Sprite2D:
			found_sprite = true
			break
	assert_true(found_sprite,
			"show_revealed_dial should create a Sprite2D child")


func test_hide_revealed_dial_removes_sprite() -> void:
	var token: ShipToken = ShipToken.new()
	add_child_autofree(token)
	token._half_w = 50.0
	token._half_l = 80.0
	token.show_revealed_dial(Constants.CommandType.NAVIGATE)
	token.hide_revealed_dial()
	# After hide, no Sprite2D children should remain (except the main _sprite
	# which is null since we didn't call setup()).
	var sprite_count: int = 0
	for child: Node in token.get_children():
		if child is Sprite2D:
			sprite_count += 1
	assert_eq(sprite_count, 0,
			"hide_revealed_dial should remove the Sprite2D child")


func test_show_revealed_dial_positions_behind_base() -> void:
	var token: ShipToken = ShipToken.new()
	add_child_autofree(token)
	token._half_w = 50.0
	token._half_l = 80.0
	token.show_revealed_dial(Constants.CommandType.NAVIGATE)
	# The sprite should be positioned at positive Y (aft of base).
	var sprite: Sprite2D = null
	for child: Node in token.get_children():
		if child is Sprite2D:
			sprite = child as Sprite2D
			break
	assert_not_null(sprite, "Sprite should exist")
	if sprite:
		assert_gt(sprite.position.y, token._half_l,
				"Dial sprite Y should be beyond the aft edge of the base")
		assert_almost_eq(sprite.position.x, 0.0, 0.1,
				"Dial sprite should be centred horizontally")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Creates a ShipInstance with a dial stack containing [param dial_count]
## NAVIGATE dials already assigned (round 1).
func _create_ship_with_dials(player: int, dial_count: int) -> ShipInstance:
	var ship: ShipInstance = ShipInstance.new()
	ship.owner_player = player
	ship.activated_this_round = false
	ship.data_key = "test_ship"
	ship.ship_data = ShipData.new()
	ship.ship_data.ship_name = "Test Ship"
	ship.command_dial_stack = CommandDialStack.create(dial_count)
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
