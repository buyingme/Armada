## Test: Game State
##
## Unit tests for GameState and PlayerState classes.
extends GutTest


# --- GameState Initialization ---

func test_initialize_sets_round_to_zero() -> void:
	var state := GameState.new()
	state.initialize()
	assert_eq(state.current_round, 0, "Initial round should be 0")


func test_initialize_sets_phase_to_setup() -> void:
	var state := GameState.new()
	state.initialize()
	assert_eq(state.current_phase, Constants.GamePhase.SETUP, "Initial phase should be SETUP")


func test_initialize_creates_two_player_states() -> void:
	var state := GameState.new()
	state.initialize()
	assert_eq(state.player_states.size(), 2, "Should have 2 player states")


func test_initialize_sets_player_indices() -> void:
	var state := GameState.new()
	state.initialize()
	assert_eq(state.player_states[0].player_index, 0, "First player index should be 0")
	assert_eq(state.player_states[1].player_index, 1, "Second player index should be 1")


func test_initialize_sets_initiative_to_zero() -> void:
	var state := GameState.new()
	state.initialize()
	assert_eq(state.initiative_player, 0, "Initial initiative player should be 0")


func test_initialize_clears_objectives() -> void:
	var state := GameState.new()
	state.objectives = {"selected_objective": {"data_key": "opening_salvo"}}
	state.initialize()
	assert_true(state.objectives.is_empty(),
			"Initialize should clear stale setup/objective payloads")


# --- Player State Access ---

func test_get_player_state_valid_index() -> void:
	var state := GameState.new()
	state.initialize()
	var ps := state.get_player_state(0)
	assert_not_null(ps, "Should return valid player state for index 0")
	assert_eq(ps.player_index, 0)


func test_get_player_state_invalid_index() -> void:
	var state := GameState.new()
	state.initialize()
	var ps := state.get_player_state(5)
	assert_null(ps, "Should return null for invalid index")
	assert_push_error(1, "Should produce exactly 1 push_error for invalid index")


func test_get_initiative_player_state() -> void:
	var state := GameState.new()
	state.initialize()
	state.initiative_player = 1
	var ps := state.get_initiative_player_state()
	assert_eq(ps.player_index, 1, "Should return player 1 when they have initiative")


func test_get_non_initiative_player_state() -> void:
	var state := GameState.new()
	state.initialize()
	state.initiative_player = 0
	var ps := state.get_non_initiative_player_state()
	assert_eq(ps.player_index, 1, "Non-initiative player should be player 1")


# --- Serialization ---

func test_serialize_round_trip() -> void:
	var state := GameState.new()
	state.initialize()
	state.current_round = 3
	state.current_phase = Constants.GamePhase.SHIP
	state.initiative_player = 1

	var data := state.serialize()
	var restored := GameState.deserialize(data)

	assert_eq(restored.current_round, 3, "Round should survive serialization")
	assert_eq(restored.current_phase, Constants.GamePhase.SHIP, "Phase should survive serialization")
	assert_eq(restored.initiative_player, 1, "Initiative should survive serialization")
	assert_eq(restored.player_states.size(), 2, "Player states should survive serialization")


func test_serialize_round_trip_preserves_objectives() -> void:
	var state: GameState = GameState.new()
	state.initialize()
	state.objectives = {
		"selected_objective": {"data_key": "obj_ass_opening_salvo"},
		"setup_package_hash": "abc123",
	}

	var restored: GameState = GameState.deserialize(state.serialize())

	assert_eq(restored.objectives, state.objectives,
		"Objectives/setup payload should survive serialization")


# --- Player State ---

func test_player_state_default_faction() -> void:
	var ps := PlayerState.new()
	assert_eq(ps.faction, Constants.Faction.REBEL_ALLIANCE, "Default faction should be Rebel Alliance")


func test_player_state_serialize_round_trip() -> void:
	var ps := PlayerState.new()
	ps.player_index = 1
	ps.faction = Constants.Faction.GALACTIC_EMPIRE
	ps.fleet_points = 385
	ps.score = 120

	var data := ps.serialize()
	var restored := PlayerState.deserialize(data)

	assert_eq(restored.player_index, 1)
	assert_eq(restored.faction, Constants.Faction.GALACTIC_EMPIRE)
	assert_eq(restored.fleet_points, 385)
	assert_eq(restored.score, 120)
