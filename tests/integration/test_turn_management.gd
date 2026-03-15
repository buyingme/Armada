## Test: Turn Management
##
## Integration tests for GameManager turn management: active player tracking,
## sequential command phase, auto-pass detection, and Ship/Squadron phase
## alternation.
## Requirements: TF-001–014, IN-001–003.
extends GutTest


var _active_player_changes: Array[int] = []
var _command_phase_complete_count: int = 0


func before_each() -> void:
	_active_player_changes.clear()
	_command_phase_complete_count = 0
	EventBus.active_player_changed.connect(_on_active_player_changed)
	EventBus.command_phase_complete.connect(_on_command_phase_complete)
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT


func after_each() -> void:
	if EventBus.active_player_changed.is_connected(
			_on_active_player_changed):
		EventBus.active_player_changed.disconnect(
				_on_active_player_changed)
	if EventBus.command_phase_complete.is_connected(
			_on_command_phase_complete):
		EventBus.command_phase_complete.disconnect(
				_on_command_phase_complete)
	GameManager.is_game_active = false
	GameManager.current_game_state = null
	PlayMode.current_mode = PlayMode.Mode.HOT_SEAT


func _on_active_player_changed(player_index: int) -> void:
	_active_player_changes.append(player_index)


func _on_command_phase_complete() -> void:
	_command_phase_complete_count += 1


# --- Active Player Tracking ---

func test_start_game_sets_active_player_to_initiative() -> void:
	GameManager.start_new_game()
	assert_eq(GameManager.active_player, 0,
			"Active player should be initiative player (0) at game start")


func test_active_player_changed_signal_fires_on_start() -> void:
	GameManager.start_new_game()
	assert_true(_active_player_changes.size() >= 1,
			"active_player_changed should fire on game start")
	assert_eq(_active_player_changes[0], 0,
			"First active player should be initiative player (0)")


func test_get_active_player_returns_current() -> void:
	GameManager.start_new_game()
	assert_eq(GameManager.get_active_player(), 0,
			"get_active_player should return 0")


# --- Sequential Command Phase (Hot-Seat) ---

func test_command_phase_sets_assigning_player_to_initiative() -> void:
	GameManager.start_new_game()
	assert_eq(GameManager.get_command_assigning_player(), 0,
			"Initiative player (0) should assign dials first")


func test_command_dials_submitted_hand_off_to_second_player() -> void:
	GameManager.start_new_game()
	_active_player_changes.clear()
	# Player 0 submits dials.
	EventBus.command_dials_submitted.emit(0)
	assert_eq(GameManager.get_command_assigning_player(), 1,
			"After player 0 submits, player 1 should be assigning")
	assert_true(_active_player_changes.size() >= 1,
			"active_player_changed should fire for handoff")
	assert_eq(_active_player_changes[0], 1,
			"Active player should change to 1 after player 0 submits")


func test_both_players_submitted_completes_command_phase() -> void:
	GameManager.start_new_game()
	EventBus.command_dials_submitted.emit(0)
	EventBus.command_dials_submitted.emit(1)
	assert_eq(_command_phase_complete_count, 1,
			"Command phase should complete after both players submit")
	assert_eq(GameManager.get_current_phase(), Constants.GamePhase.SHIP,
			"Should advance to Ship phase after command phase")


func test_command_assigning_player_reset_after_complete() -> void:
	GameManager.start_new_game()
	EventBus.command_dials_submitted.emit(0)
	EventBus.command_dials_submitted.emit(1)
	assert_eq(GameManager.get_command_assigning_player(), -1,
			"Assigning player should be -1 after command phase completes")


## Regression: _on_command_picker_confirmed previously called
## _check_command_phase_complete() directly *and* emitted
## command_dials_submitted (whose handler also calls the check), causing
## Command → Ship → Squadron in a single frame.
func test_picker_confirmed_path_does_not_double_advance_phase() -> void:
	GameManager.start_new_game()
	# Give each player exactly one ship with command_value 1.
	var gs: GameState = GameManager.current_game_state
	var rebel_ship: ShipInstance = ShipInstance.new()
	rebel_ship.owner_player = 0
	rebel_ship.activated_this_round = false
	rebel_ship.ship_data = ShipData.new()
	rebel_ship.ship_data.ship_name = "TestRebel"
	rebel_ship.command_dial_stack = CommandDialStack.create(1)
	gs.get_player_state(0).ships.append(rebel_ship)

	var imp_ship: ShipInstance = ShipInstance.new()
	imp_ship.owner_player = 1
	imp_ship.activated_this_round = false
	imp_ship.ship_data = ShipData.new()
	imp_ship.ship_data.ship_name = "TestImperial"
	imp_ship.command_dial_stack = CommandDialStack.create(1)
	gs.get_player_state(1).ships.append(imp_ship)

	# Simulate picker-confirmed path: player 0 assigns dial via picker.
	EventBus.command_picker_confirmed.emit(
			rebel_ship, [Constants.CommandType.NAVIGATE])
	# Player 0 done → handoff to player 1 expected.
	assert_eq(GameManager.get_command_assigning_player(), 1,
			"Player 1 should be assigning after player 0 finishes")

	# Player 1 assigns dial via picker.
	EventBus.command_picker_confirmed.emit(
			imp_ship, [Constants.CommandType.NAVIGATE])
	# Should advance to Ship — NOT Squadron.
	assert_eq(GameManager.get_current_phase(), Constants.GamePhase.SHIP,
			"Phase should be Ship after both players submit via picker "
			+ "(not Squadron)")
	assert_eq(_command_phase_complete_count, 1,
			"command_phase_complete should fire exactly once")


# --- Ship Phase Turn Management ---

func test_ship_phase_starts_with_initiative_player() -> void:
	GameManager.start_new_game()
	_active_player_changes.clear()
	# Skip to ship phase.
	EventBus.command_dials_submitted.emit(0)
	EventBus.command_dials_submitted.emit(1)
	# Ship phase should make initiative player active.
	var found_init: bool = false
	for pi: int in _active_player_changes:
		if pi == 0:
			found_init = true
	assert_true(found_init,
			"Ship phase should activate initiative player (0)")


func test_activation_ended_advances_turn() -> void:
	GameManager.start_new_game()
	# Advance to Ship Phase.
	EventBus.command_dials_submitted.emit(0)
	EventBus.command_dials_submitted.emit(1)
	# Now in Ship Phase, active player is 0.
	# Need ships for auto-pass to not trigger.
	_add_test_ships()
	_active_player_changes.clear()
	EventBus.activation_ended.emit()
	assert_true(_active_player_changes.size() >= 1,
			"activation_ended should trigger player change")


# --- Auto-Pass Detection ---

func test_has_unactivated_ships_true_when_ships_exist() -> void:
	GameManager.start_new_game()
	_add_test_ships()
	assert_true(GameManager._has_unactivated_ships(0),
			"Should detect unactivated ships for player 0")
	assert_true(GameManager._has_unactivated_ships(1),
			"Should detect unactivated ships for player 1")


func test_has_unactivated_ships_false_when_all_activated() -> void:
	GameManager.start_new_game()
	_add_test_ships()
	# Mark all player 0's ships as activated.
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	for s: Variant in ps.ships:
		if s is ShipInstance:
			(s as ShipInstance).activated_this_round = true
	assert_false(GameManager._has_unactivated_ships(0),
			"No unactivated ships for player 0 after activation")


func test_auto_pass_when_no_ships() -> void:
	GameManager.start_new_game()
	# No ships registered — both players should auto-pass.
	assert_false(GameManager._has_unactivated_ships(0),
			"No ships means no unactivated ships")
	assert_false(GameManager._has_unactivated_ships(1),
			"No ships means no unactivated ships")


func test_has_unactivated_squadrons_true_when_squadrons_exist() -> void:
	GameManager.start_new_game()
	_add_test_squadrons()
	assert_true(GameManager._has_unactivated_squadrons(0),
			"Should detect unactivated squadrons for player 0")


func test_has_unactivated_squadrons_false_when_all_activated() -> void:
	GameManager.start_new_game()
	_add_test_squadrons()
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	for sq: Variant in ps.squadrons:
		if sq is SquadronInstance:
			(sq as SquadronInstance).activated_this_round = true
	assert_false(GameManager._has_unactivated_squadrons(0),
			"No unactivated squadrons after activation")


func test_ship_phase_auto_pass_advances_to_squadron() -> void:
	GameManager.start_new_game()
	# Skip to ship phase with no ships at all.
	EventBus.command_dials_submitted.emit(0)
	EventBus.command_dials_submitted.emit(1)
	# Both players have no ships — activation_ended should trigger
	# auto-advance through Ship Phase and into Squadron Phase.
	# Since _begin_ship_phase calls _set_active_player which fires
	# the signal, and with no unactivated ships, the first
	# activation_ended should advance past.
	EventBus.activation_ended.emit()
	assert_eq(GameManager.get_current_phase(),
			Constants.GamePhase.SQUADRON,
			"Should auto-advance to Squadron when no ships")


func test_squadron_phase_auto_pass_advances_to_status() -> void:
	GameManager.start_new_game()
	# Skip to squadron phase.
	EventBus.command_dials_submitted.emit(0)
	EventBus.command_dials_submitted.emit(1)
	# Ship → Squadron via activation_ended with no ships.
	EventBus.activation_ended.emit()
	assert_eq(GameManager.get_current_phase(),
			Constants.GamePhase.SQUADRON,
			"Should be in Squadron Phase")
	# Now fire activation_ended in Squadron Phase with no squadrons.
	EventBus.activation_ended.emit()
	assert_eq(GameManager.get_current_phase(),
			Constants.GamePhase.STATUS,
			"Should auto-advance to Status when no squadrons")


# --- Initiative ---

func test_initiative_player_is_zero_by_default() -> void:
	GameManager.start_new_game()
	assert_eq(GameManager.current_game_state.initiative_player, 0,
			"Initiative player should default to 0")


# --- Helpers ---

## Creates minimal ship instances and registers them in GameState.
func _add_test_ships() -> void:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	var rebel_ship: ShipInstance = ShipInstance.new()
	rebel_ship.owner_player = 0
	rebel_ship.activated_this_round = false
	gs.get_player_state(0).ships.append(rebel_ship)

	var imperial_ship: ShipInstance = ShipInstance.new()
	imperial_ship.owner_player = 1
	imperial_ship.activated_this_round = false
	gs.get_player_state(1).ships.append(imperial_ship)


## Creates minimal squadron instances and registers them in GameState.
func _add_test_squadrons() -> void:
	var gs: GameState = GameManager.current_game_state
	if gs == null:
		return
	var rebel_squad: SquadronInstance = SquadronInstance.new()
	rebel_squad.owner_player = 0
	rebel_squad.activated_this_round = false
	gs.get_player_state(0).squadrons.append(rebel_squad)

	var imperial_squad: SquadronInstance = SquadronInstance.new()
	imperial_squad.owner_player = 1
	imperial_squad.activated_this_round = false
	gs.get_player_state(1).squadrons.append(imperial_squad)
