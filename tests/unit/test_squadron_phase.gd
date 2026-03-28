## Test: Squadron Phase Activation
##
## Unit tests for the interactive squadron activation flow in GameManager.
## Rules Reference: "Squadron Phase", RRG p.12; SQ-001–005, TF-008–012.
extends GutTest


# --- Helpers ---

## Creates a minimal GameState with squadrons for both players.
## [param p0_count] — number of squadrons for player 0.
## [param p1_count] — number of squadrons for player 1.
func _setup_game(p0_count: int, p1_count: int) -> void:
	GameManager.start_new_game()
	var gs: GameState = GameManager.current_game_state
	gs.initiative_player = 0
	for player_idx: int in range(2):
		var ps: PlayerState = gs.get_player_state(player_idx)
		var count: int = p0_count if player_idx == 0 else p1_count
		for i: int in range(count):
			var data: SquadronData = SquadronData.new()
			data.squadron_name = "Sq%d_%d" % [player_idx, i]
			data.hull = 3
			data.speed = 3
			data.defense_tokens = []
			var inst: SquadronInstance = SquadronInstance.create_from_data(
					"sq_%d_%d" % [player_idx, i], data, player_idx)
			ps.squadrons.append(inst)
	# Advance to squadron phase: COMMAND → SHIP → SQUADRON.
	# Mark all ships as activated (there are none, so just advance).
	gs.current_phase = Constants.GamePhase.SQUADRON
	GameManager.active_player = gs.initiative_player
	GameManager._squadrons_activated_this_turn = 0
	GameManager._activating_squadron = null


func after_each() -> void:
	GameManager.end_game()


# --- Phase start ---

func test_begin_squadron_phase_sets_initiative_player() -> void:
	_setup_game(2, 2)
	var gs: GameState = GameManager.current_game_state
	gs.initiative_player = 0
	GameManager._begin_squadron_phase()
	assert_eq(GameManager.active_player, 0,
			"Initiative player should be active at phase start (TF-008)")


func test_begin_squadron_phase_no_squadrons_auto_skips() -> void:
	_setup_game(0, 0)
	var gs: GameState = GameManager.current_game_state
	# After _begin_squadron_phase with no squadrons, phase should advance.
	GameManager._begin_squadron_phase()
	assert_ne(gs.current_phase, Constants.GamePhase.SQUADRON,
			"Phase should skip SQUADRON when no squadrons exist")


# --- Activation ---

func test_activate_squadron_sets_activating() -> void:
	_setup_game(2, 2)
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	var sq: SquadronInstance = ps.squadrons[0] as SquadronInstance
	GameManager.activate_squadron(sq)
	assert_eq(GameManager.get_activating_squadron(), sq,
			"Activating squadron should be the one passed to activate_squadron")


func test_activate_squadron_rejects_enemy() -> void:
	_setup_game(2, 2)
	var enemy_ps: PlayerState = \
			GameManager.current_game_state.get_player_state(1)
	var enemy_sq: SquadronInstance = \
			enemy_ps.squadrons[0] as SquadronInstance
	GameManager.activate_squadron(enemy_sq)
	assert_null(GameManager.get_activating_squadron(),
			"Should reject squadron not owned by active player")
	# push_warning from _log.warn is caught by GUT as engine error
	assert_engine_error(1,
			"Should push a warning for wrong-player activation")


func test_activate_squadron_rejects_already_activated() -> void:
	_setup_game(2, 2)
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	var sq: SquadronInstance = ps.squadrons[0] as SquadronInstance
	sq.activated_this_round = true
	GameManager.activate_squadron(sq)
	assert_null(GameManager.get_activating_squadron(),
			"Should reject already activated squadron")
	assert_engine_error(1,
			"Should push a warning for already-activated squadron")


func test_activate_squadron_rejects_double_activation() -> void:
	_setup_game(2, 2)
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	var sq_a: SquadronInstance = ps.squadrons[0] as SquadronInstance
	var sq_b: SquadronInstance = ps.squadrons[1] as SquadronInstance
	GameManager.activate_squadron(sq_a)
	GameManager.activate_squadron(sq_b)
	assert_eq(GameManager.get_activating_squadron(), sq_a,
			"Should reject second activation while first is in progress")
	assert_engine_error(1,
			"Should push a warning for double activation")


# --- Activation end ---

func test_squadron_activation_ended_marks_activated() -> void:
	_setup_game(2, 2)
	var ps: PlayerState = GameManager.current_game_state.get_player_state(0)
	var sq: SquadronInstance = ps.squadrons[0] as SquadronInstance
	GameManager.activate_squadron(sq)
	# Simulate activation ending.
	EventBus.squadron_activation_ended.emit(sq)
	assert_true(sq.activated_this_round,
			"Squadron should be marked as activated after activation ends")
	assert_null(GameManager.get_activating_squadron(),
			"Activating squadron should be cleared")


func test_two_activations_then_turn_switches() -> void:
	_setup_game(3, 3)
	var gs: GameState = GameManager.current_game_state
	gs.initiative_player = 0
	GameManager._begin_squadron_phase()
	var ps0: PlayerState = gs.get_player_state(0)
	# Activate first squadron.
	GameManager.activate_squadron(ps0.squadrons[0] as SquadronInstance)
	EventBus.squadron_activation_ended.emit(ps0.squadrons[0])
	# After 1 activation, still player 0's turn (need 2).
	assert_eq(GameManager.active_player, 0,
			"After 1 activation, should still be player 0")
	# Activate second squadron.
	GameManager.activate_squadron(ps0.squadrons[1] as SquadronInstance)
	EventBus.squadron_activation_ended.emit(ps0.squadrons[1])
	# After 2 activations, turn should switch to player 1.
	assert_eq(GameManager.active_player, 1,
			"After 2 activations, turn should pass to player 1 (SQ-002)")


func test_auto_pass_when_no_squadrons_left() -> void:
	_setup_game(1, 2)
	var gs: GameState = GameManager.current_game_state
	gs.initiative_player = 0
	GameManager._begin_squadron_phase()
	var ps0: PlayerState = gs.get_player_state(0)
	# Player 0 activates their only squadron.
	GameManager.activate_squadron(ps0.squadrons[0] as SquadronInstance)
	EventBus.squadron_activation_ended.emit(ps0.squadrons[0])
	# Player 0 has no more squadrons — auto-pass to player 1.
	assert_eq(GameManager.active_player, 1,
			"Player 1 should become active after player 0 auto-passes (TF-009)")


func test_phase_ends_when_all_activated() -> void:
	_setup_game(1, 1)
	var gs: GameState = GameManager.current_game_state
	gs.initiative_player = 0
	GameManager._begin_squadron_phase()
	# Player 0 activates.
	var sq0: SquadronInstance = \
			gs.get_player_state(0).squadrons[0] as SquadronInstance
	GameManager.activate_squadron(sq0)
	EventBus.squadron_activation_ended.emit(sq0)
	# Player 1 activates.
	var sq1: SquadronInstance = \
			gs.get_player_state(1).squadrons[0] as SquadronInstance
	GameManager.activate_squadron(sq1)
	EventBus.squadron_activation_ended.emit(sq1)
	# Both done — phase should advance past SQUADRON.
	assert_ne(gs.current_phase, Constants.GamePhase.SQUADRON,
			"Phase should advance after all squadrons activated")


# --- Constants ---

func test_squadrons_per_activation_is_two() -> void:
	assert_eq(Constants.SQUADRONS_PER_ACTIVATION, 2,
			"SQUADRONS_PER_ACTIVATION should be 2 (SQ-002)")
