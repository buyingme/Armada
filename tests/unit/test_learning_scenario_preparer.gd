## Test: LearningScenarioPreparer
##
## Unit tests for scene-independent Learning Scenario preparation.
extends GutTest


func test_prepare_game_state_registers_instances_expected() -> void:
	var game_state: GameState = _create_game_state()
	var prepared: Dictionary = LearningScenarioPreparer.prepare_game_state(
			LearningScenarioSetup.new(), game_state)
	assert_eq((prepared["ships"] as Array[ShipInstance]).size(), 3,
		"Should return three prepared ship instances")
	assert_eq(game_state.get_player_state(0).ships.size(), 2,
		"Rebel player should receive two ships")
	assert_eq(game_state.get_player_state(1).squadrons.size(), 6,
		"Imperial player should receive six squadrons")


func test_prepare_game_state_sets_factions_and_initiative_expected() -> void:
	var game_state: GameState = _create_game_state()
	LearningScenarioPreparer.prepare_game_state(LearningScenarioSetup.new(), game_state)
	assert_eq(game_state.initiative_player, LearningScenarioSetup.REBEL_PLAYER,
		"Learning Scenario gives initiative to the Rebel player")
	assert_eq(game_state.get_player_state(0).faction, Constants.Faction.REBEL_ALLIANCE,
		"Player 0 should be Rebel")
	assert_eq(game_state.get_player_state(1).faction, Constants.Faction.GALACTIC_EMPIRE,
		"Player 1 should be Imperial")


func test_prepare_game_state_seeds_normalized_positions_expected() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new()
	var game_state: GameState = _create_game_state()
	var prepared: Dictionary = LearningScenarioPreparer.prepare_game_state(setup, game_state)
	var first_ship: ShipInstance = (prepared["ships"] as Array[ShipInstance])[0]
	var first_placement: TokenPlacement = setup.get_ship_placements()[0]
	assert_almost_eq(first_ship.pos_x, first_placement.pos_x, 0.001,
		"Prepared ship should keep normalized scenario X")
	assert_almost_eq(first_ship.rotation_deg, rad_to_deg(first_placement.rotation_rad), 0.001,
		"Prepared ship should keep scenario rotation in degrees")


func test_prepare_game_state_assigns_damage_deck_expected() -> void:
	var game_state: GameState = _create_game_state()
	LearningScenarioPreparer.prepare_game_state(LearningScenarioSetup.new(), game_state)
	assert_not_null(game_state.damage_deck, "Prepared game state should have a damage deck")
	assert_eq(game_state.damage_deck.get_draw_count(), DamageDeck.DECK_SIZE,
		"Prepared damage deck should be initialized")


func test_prepare_game_state_null_inputs_returns_empty_expected() -> void:
	var prepared: Dictionary = LearningScenarioPreparer.prepare_game_state(null, null)
	assert_eq((prepared.get("ships", []) as Array).size(), 0,
		"Null setup inputs should return no ships")
	assert_eq((prepared.get("squadrons", []) as Array).size(), 0,
		"Null setup inputs should return no squadrons")


func _create_game_state() -> GameState:
	var game_state: GameState = GameState.new()
	game_state.initialize()
	return game_state