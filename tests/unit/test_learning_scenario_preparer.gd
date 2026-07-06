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


func test_prepare_debug_scenario_preserves_runtime_upgrades_through_player_state_serialization() -> void:
	var game_state: GameState = _create_game_state()
	LearningScenarioPreparer.prepare_game_state(
			LearningScenarioSetup.new("debug_scenario"), game_state)
	for player_index: int in range(Constants.PLAYER_COUNT):
		var original: PlayerState = game_state.get_player_state(player_index)
		var restored: PlayerState = PlayerState.deserialize(original.serialize())
		assert_eq(restored.ships.size(), original.ships.size(),
				"Debug scenario PlayerState ship count should survive serialization")
		for ship_index: int in range(original.ships.size()):
			var original_ship: ShipInstance = original.ships[ship_index] as ShipInstance
			var restored_ship: ShipInstance = restored.ships[ship_index] as ShipInstance
			assert_eq(restored_ship.runtime_upgrades.size(),
					original_ship.runtime_upgrades.size(),
					"Scenario-created runtime upgrades should survive PlayerState serialization")
			for runtime_upgrade: Dictionary in original_ship.runtime_upgrades:
				var runtime_upgrade_id: String = str(
						runtime_upgrade.get("runtime_upgrade_id", ""))
				var restored_upgrade: Dictionary = restored_ship.get_runtime_upgrade(
						runtime_upgrade_id)
				assert_false(restored_upgrade.is_empty(),
						"Restored debug runtime upgrade should be lookupable by id")
				assert_eq(restored_upgrade.get("data_key", ""),
						runtime_upgrade.get("data_key", ""),
						"Restored runtime upgrade should preserve static upgrade data_key")
				assert_eq(restored_upgrade.get("source_roster_entry_id", ""),
						runtime_upgrade.get("source_roster_entry_id", ""),
						"Restored runtime upgrade should preserve scenario source identity")


func test_synthetic_tarkin_runtime_upgrade_prompts_at_ship_phase() -> void:
	var game_state: GameState = _create_game_state()
	var setup: LearningScenarioSetup = _setup_from_tokens([
		_ship_token("victory_ii_class_star_destroyer", "synthetic-tarkin-vsd", [
			_upgrade("synthetic-tarkin-commander-0",
					"grand_moff_tarkin", "COMMANDER", 0),
		]),
	])
	LearningScenarioPreparer.prepare_game_state(setup, game_state)
	game_state.current_round = 1
	game_state.current_phase = Constants.GamePhase.COMMAND
	var advance := AdvancePhaseCommand.new(0, {
		"next_phase": int(Constants.GamePhase.SHIP),
	})

	advance.execute(game_state)

	assert_eq(game_state.current_phase, Constants.GamePhase.SHIP,
			"Scenario state should reach Ship Phase")
	assert_eq(game_state.interaction_flow.step_id,
			Constants.InteractionStep.TARKIN_COMMAND_CHOICE,
			"Synthetic Tarkin runtime upgrade should produce the Tarkin prompt")
	assert_eq(game_state.interaction_flow.payload.get("runtime_upgrade_id", ""),
			"1:ship:synthetic-tarkin-vsd:upgrade:synthetic-tarkin-commander-0",
			"Prompt should bind to the synthetic scenario-created runtime upgrade")


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


func _setup_from_tokens(tokens: Array) -> LearningScenarioSetup:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new("synthetic")
	setup._data = {
		"map_image": "map_3x3_distant_planet_v3.jpg",
		"scenario_name": "Synthetic Scenario",
		"tokens": tokens,
		"use_fixed_round1_commands": false,
	}
	return setup


func _ship_token(
		key: String,
		roster_entry_id: String,
		upgrades: Array) -> Dictionary:
	return {
		"key": key,
		"pos_x": 0.5,
		"pos_y": 0.2,
		"roster_entry_id": roster_entry_id,
		"rotation_deg": 180.0,
		"type": "ship",
		"upgrades": upgrades,
	}


func _upgrade(
		source_assignment_id: String,
		data_key: String,
		slot: String,
		slot_index: int) -> Dictionary:
	return {
		"source_assignment_id": source_assignment_id,
		"data_key": data_key,
		"slot": slot,
		"slot_index": slot_index,
	}
