## Test: Game Manager — Integration
##
## Integration tests for GameManager verifying game flow,
## round progression, and phase transitions via EventBus signals.
extends GutTest


var _round_started_count: int = 0
var _round_ended_count: int = 0
var _phase_changed_phases: Array = []
var _game_started: bool = false
var _game_ended: bool = false
var _game_ended_winner: int = -1


func before_each() -> void:
	_round_started_count = 0
	_round_ended_count = 0
	_phase_changed_phases.clear()
	_game_started = false
	_game_ended = false
	_game_ended_winner = -1

	EventBus.round_started.connect(_on_round_started)
	EventBus.round_ended.connect(_on_round_ended)
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_ended.connect(_on_game_ended)


func after_each() -> void:
	# Clean up signal connections
	if EventBus.round_started.is_connected(_on_round_started):
		EventBus.round_started.disconnect(_on_round_started)
	if EventBus.round_ended.is_connected(_on_round_ended):
		EventBus.round_ended.disconnect(_on_round_ended)
	if EventBus.phase_changed.is_connected(_on_phase_changed):
		EventBus.phase_changed.disconnect(_on_phase_changed)
	if EventBus.game_started.is_connected(_on_game_started):
		EventBus.game_started.disconnect(_on_game_started)
	if EventBus.game_ended.is_connected(_on_game_ended):
		EventBus.game_ended.disconnect(_on_game_ended)

	# Reset game manager state
	GameManager.is_game_active = false
	GameManager.current_game_state = null


# --- Signal Handlers ---

func _on_round_started(_round: int) -> void:
	_round_started_count += 1


func _on_round_ended(_round: int) -> void:
	_round_ended_count += 1


func _on_phase_changed(phase: Constants.GamePhase) -> void:
	_phase_changed_phases.append(phase)


func _on_game_started() -> void:
	_game_started = true


func _on_game_ended(winner: int) -> void:
	_game_ended = true
	_game_ended_winner = winner


# --- Tests ---

func test_start_new_game_emits_game_started() -> void:
	GameManager.start_new_game()
	assert_true(_game_started, "Should emit game_started signal")


func test_start_new_game_sets_active() -> void:
	GameManager.start_new_game()
	assert_true(GameManager.is_game_active, "Game should be active")


func test_start_new_game_starts_round_one() -> void:
	GameManager.start_new_game()
	assert_eq(GameManager.get_current_round(), 1, "Should be round 1")


func test_start_new_game_begins_with_command_phase() -> void:
	GameManager.start_new_game()
	assert_eq(GameManager.get_current_phase(), Constants.GamePhase.COMMAND,
		"Should start with COMMAND phase")


func test_advance_phase_command_to_ship() -> void:
	GameManager.start_new_game()
	GameManager.advance_phase()
	assert_eq(GameManager.get_current_phase(), Constants.GamePhase.SHIP,
		"Should advance from COMMAND to SHIP")


func test_advance_phase_full_cycle() -> void:
	GameManager.start_new_game()
	# COMMAND -> SHIP -> SQUADRON -> STATUS -> (new round) COMMAND
	GameManager.advance_phase()  # SHIP
	assert_eq(GameManager.get_current_phase(), Constants.GamePhase.SHIP)

	GameManager.advance_phase()  # SQUADRON
	assert_eq(GameManager.get_current_phase(), Constants.GamePhase.SQUADRON)

	GameManager.advance_phase()  # STATUS
	assert_eq(GameManager.get_current_phase(), Constants.GamePhase.STATUS)

	GameManager.advance_phase()  # New round -> COMMAND
	assert_eq(GameManager.get_current_phase(), Constants.GamePhase.COMMAND)
	assert_eq(GameManager.get_current_round(), 2, "Should be round 2 after full cycle")


func test_game_ends_after_six_rounds() -> void:
	GameManager.start_new_game()

	# Play through 6 full rounds
	for round_num in range(6):
		for phase in range(4):  # 4 phase transitions per round
			if GameManager.is_game_active:
				GameManager.advance_phase()

	# After round 6's STATUS phase, advancing should trigger round 7 attempt → game end
	assert_true(_game_ended, "Game should end after 6 rounds")
	assert_false(GameManager.is_game_active, "Game should no longer be active")


func test_end_game_emits_signal_with_winner() -> void:
	GameManager.start_new_game()
	GameManager.end_game(0)
	assert_true(_game_ended, "Should emit game_ended signal")
	assert_eq(_game_ended_winner, 0, "Winner should be player 0")


func test_phase_changed_signals_fired() -> void:
	GameManager.start_new_game()
	# start_new_game fires COMMAND
	assert_eq(_phase_changed_phases.size(), 1)
	assert_eq(_phase_changed_phases[0], Constants.GamePhase.COMMAND)

	GameManager.advance_phase()
	assert_eq(_phase_changed_phases.size(), 2)
	assert_eq(_phase_changed_phases[1], Constants.GamePhase.SHIP)


func test_round_started_signal_count() -> void:
	GameManager.start_new_game()
	assert_eq(_round_started_count, 1, "Should have 1 round_started after new game")

	# Complete round 1
	for i in range(4):
		GameManager.advance_phase()

	assert_eq(_round_started_count, 2, "Should have 2 round_started after completing round 1")
