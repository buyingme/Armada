## Test: LearningScenarioSetup
##
## Unit tests for LearningScenarioSetup — verifies placement data for all
## thirteen tokens in the Learning Scenario: three ships and ten squadrons.
##
## Rules Reference: "Learning Scenario Setup", steps 4 and 9, p.5–6.
extends GutTest


var _setup: LearningScenarioSetup = null


func before_each() -> void:
	_setup = LearningScenarioSetup.new()


func after_each() -> void:
	_setup = null


# --- Token Count ---

func test_get_all_placements_returns_thirteen_tokens() -> void:
	# Arrange / Act
	var placements: Array[TokenPlacement] = \
			_setup.get_all_placements()
	# Assert
	assert_eq(placements.size(), 13,
			"Learning Scenario has exactly 13 tokens (3 ships + 10 squadrons)")


func test_get_token_count_returns_thirteen() -> void:
	assert_eq(_setup.get_token_count(), 13,
			"get_token_count() should return 13")


func test_get_ship_placements_returns_three_ships() -> void:
	var ships: Array[TokenPlacement] = \
			_setup.get_ship_placements()
	assert_eq(ships.size(), 3,
			"Three ships: Victory II, CR90 Corvette A, Nebulon-B")


func test_get_squadron_placements_returns_ten_squadrons() -> void:
	var squadrons: Array[TokenPlacement] = \
			_setup.get_squadron_placements()
	assert_eq(squadrons.size(), 10,
			"Ten squadrons: 6 TIE Fighters and 4 X-wings")


# --- Factions ---

func test_victory_ii_is_imperial() -> void:
	var victory: TokenPlacement = _find_by_key("victory_ii_class_star_destroyer")
	assert_not_null(victory, "Victory II placement should exist")
	assert_eq(int(victory.faction), int(Constants.Faction.GALACTIC_EMPIRE),
			"Victory II should belong to the Galactic Empire")


func test_cr90_is_rebel() -> void:
	var cr90: TokenPlacement = _find_by_key("cr90_corvette_a")
	assert_not_null(cr90, "CR90 placement should exist")
	assert_eq(int(cr90.faction), int(Constants.Faction.REBEL_ALLIANCE),
			"CR90 Corvette A should belong to the Rebel Alliance")


func test_tie_fighter_is_imperial() -> void:
	var tie: TokenPlacement = _find_by_key("tie_fighter_squadron")
	assert_not_null(tie, "TIE Fighter placement should exist")
	assert_eq(int(tie.faction), int(Constants.Faction.GALACTIC_EMPIRE),
			"TIE Fighter Squadron should belong to the Galactic Empire")


func test_x_wing_is_rebel() -> void:
	var xwing: TokenPlacement = _find_by_key("x_wing_squadron")
	assert_not_null(xwing, "X-wing placement should exist")
	assert_eq(int(xwing.faction), int(Constants.Faction.REBEL_ALLIANCE),
			"X-wing Squadron should belong to the Rebel Alliance")


# --- IS_SHIP flags ---

func test_victory_ii_is_a_ship() -> void:
	var p: TokenPlacement = _find_by_key("victory_ii_class_star_destroyer")
	assert_true(p.is_ship, "Victory II should be flagged as a ship")


func test_tie_fighter_is_not_a_ship() -> void:
	var p: TokenPlacement = _find_by_key("tie_fighter_squadron")
	assert_false(p.is_ship, "TIE Fighter should be flagged as a squadron (not a ship)")


# --- Rotations (deployment facing) ---

func test_imperial_ships_face_south() -> void:
	# Imperials face south (PI rad = +Y = toward Rebel zone at bottom).
	var victory: TokenPlacement = \
			_find_by_key("victory_ii_class_star_destroyer")
	assert_almost_eq(victory.rotation_rad, PI, 0.001,
			"Victory II should face south (PI radians) toward Rebel deployment")


func test_rebel_ships_face_north() -> void:
	# Rebels face north (0 rad = -Y = toward Imperial zone at top).
	var cr90: TokenPlacement = _find_by_key("cr90_corvette_a")
	assert_almost_eq(cr90.rotation_rad, 0.0, 0.001,
			"CR90 should face north (0 radians) toward Imperial deployment")


# --- Deployment zones (normalised Y position) ---

func test_victory_ii_in_top_deployment_zone() -> void:
	var p: TokenPlacement = \
			_find_by_key("victory_ii_class_star_destroyer")
	assert_true(p.pos_y < 0.40,
			"Victory II should be in the top (Imperial) deployment zone (pos_y < 0.40)")


func test_rebels_in_bottom_deployment_zone() -> void:
	var cr90: TokenPlacement = _find_by_key("cr90_corvette_a")
	assert_true(cr90.pos_y > 0.60,
			"CR90 should be in the bottom (Rebel) zone (pos_y > 0.60)")


func test_nebulon_b_in_rebel_deployment_zone() -> void:
	var neb: TokenPlacement = _find_by_key("nebulon_b_escort_frigate")
	assert_true(neb.pos_y > 0.60,
			"Nebulon-B should be in the bottom (Rebel) zone (pos_y > 0.60)")


# --- Pixel position conversion ---

func test_get_pixel_position_center_maps_to_half_side() -> void:
	# A normalised position of (0.5, 0.5) should map to half the play area.
	var play_size: Vector2 = Vector2(2000.0, 2000.0)
	var p: TokenPlacement = \
			TokenPlacement.new(
					"test", true, Constants.Faction.REBEL_ALLIANCE,
					0.5, 0.5, 0.0)
	var px_pos: Vector2 = p.get_pixel_position(play_size)
	assert_almost_eq(px_pos.x, 1000.0, 0.001, "x = 0.5 × 2000 should be 1000")
	assert_almost_eq(px_pos.y, 1000.0, 0.001, "y = 0.5 × 2000 should be 1000")


func test_get_normalised_position_returns_correct_vector() -> void:
	var p: TokenPlacement = \
			TokenPlacement.new(
					"test", false, Constants.Faction.GALACTIC_EMPIRE,
					0.35, 0.15, 0.0)
	var n: Vector2 = p.get_normalised_position()
	assert_almost_eq(n.x, 0.35, 0.001, "Normalised x should be 0.35")
	assert_almost_eq(n.y, 0.15, 0.001, "Normalised y should be 0.15")


# --- All tokens have non-empty data keys ---

func test_all_placements_have_non_empty_data_keys() -> void:
	for p: TokenPlacement in _setup.get_all_placements():
		assert_ne(p.data_key, "",
				"Every placement must have a non-empty data_key (got empty for a token)")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Returns the first placement whose data_key matches [key], or null.
func _find_by_key(key: String) -> TokenPlacement:
	for p: TokenPlacement in _setup.get_all_placements():
		if p.data_key == key:
			return p
	return null


# ---------------------------------------------------------------------------
# Map image
# ---------------------------------------------------------------------------

func test_get_map_image_filename_returns_configured_value() -> void:
	var filename: String = _setup.get_map_image_filename()
	assert_eq(filename, "map_3x3_distant_planet_v3.jpg",
			"Should return the map_image value from the scenario JSON")


func test_get_map_image_filename_is_valid_asset() -> void:
	var filename: String = _setup.get_map_image_filename()
	var texture: Texture2D = AssetLoader.load_texture("maps/", filename)
	assert_not_null(texture,
			"The configured map image should exist and load as a Texture2D")


# ---------------------------------------------------------------------------
# Phase 3 — Instance creation
# ---------------------------------------------------------------------------

func test_create_ship_instances_returns_three() -> void:
	var ships: Array[ShipInstance] = _setup.create_ship_instances()
	assert_eq(ships.size(), 3,
			"Should create 3 ship instances (1 Imperial + 2 Rebel)")


func test_create_ship_instances_speed_is_2() -> void:
	## Rules Reference: SU-021 — all ships start at speed 2.
	var ships: Array[ShipInstance] = _setup.create_ship_instances()
	for inst: ShipInstance in ships:
		assert_eq(inst.current_speed, 2,
				"All ships should start at speed 2 (SU-021): %s" % inst.data_key)


func test_create_ship_instances_shields_at_max() -> void:
	## Rules Reference: SU-022 — shields start at maximum.
	var ships: Array[ShipInstance] = _setup.create_ship_instances()
	for inst: ShipInstance in ships:
		for zone: String in inst.current_shields:
			assert_eq(int(inst.current_shields[zone]),
					inst.get_max_shields(zone),
					"Shields should be max for %s zone %s" % [inst.data_key, zone])


func test_create_ship_instances_hull_at_max() -> void:
	var ships: Array[ShipInstance] = _setup.create_ship_instances()
	for inst: ShipInstance in ships:
		assert_eq(inst.current_hull, inst.ship_data.hull,
				"Hull should be max for %s" % inst.data_key)


func test_create_ship_instances_defense_tokens_ready() -> void:
	## Rules Reference: SU-026 — all tokens start READY.
	var ships: Array[ShipInstance] = _setup.create_ship_instances()
	for inst: ShipInstance in ships:
		for token: Dictionary in inst.defense_tokens:
			assert_eq(token["state"], Constants.DefenseTokenState.READY,
					"Defense tokens should start READY for %s" % inst.data_key)


func test_create_ship_instances_owner_player() -> void:
	var ships: Array[ShipInstance] = _setup.create_ship_instances()
	for inst: ShipInstance in ships:
		if inst.ship_data.faction == Constants.Faction.GALACTIC_EMPIRE:
			assert_eq(inst.owner_player, 1,
					"Imperial ships should be player 1: %s" % inst.data_key)
		else:
			assert_eq(inst.owner_player, 0,
					"Rebel ships should be player 0: %s" % inst.data_key)


func test_create_squadron_instances_returns_ten() -> void:
	var squads: Array[SquadronInstance] = _setup.create_squadron_instances()
	assert_eq(squads.size(), 10,
			"Should create 10 squadron instances (6 TIE + 4 X-wing)")


func test_create_squadron_instances_hull_at_max() -> void:
	var squads: Array[SquadronInstance] = _setup.create_squadron_instances()
	for inst: SquadronInstance in squads:
		assert_eq(inst.current_hull, inst.squadron_data.hull,
				"Hull should be max for %s" % inst.data_key)


func test_populate_game_state_sets_initiative() -> void:
	## Rules Reference: SU-020 — Rebel player has initiative.
	var gs: GameState = GameState.new()
	gs.initialize()
	_setup.populate_game_state(gs)
	assert_eq(gs.initiative_player, 0,
			"Rebel player (0) should have initiative (SU-020)")


func test_populate_game_state_sets_factions() -> void:
	var gs: GameState = GameState.new()
	gs.initialize()
	_setup.populate_game_state(gs)
	assert_eq(gs.get_player_state(0).faction, Constants.Faction.REBEL_ALLIANCE,
			"Player 0 should be Rebel")
	assert_eq(gs.get_player_state(1).faction, Constants.Faction.GALACTIC_EMPIRE,
			"Player 1 should be Imperial")


func test_populate_game_state_rebel_ships() -> void:
	var gs: GameState = GameState.new()
	gs.initialize()
	_setup.populate_game_state(gs)
	assert_eq(gs.get_player_state(0).ships.size(), 2,
			"Rebel should have 2 ships (CR90 + Nebulon-B)")


func test_populate_game_state_imperial_ships() -> void:
	var gs: GameState = GameState.new()
	gs.initialize()
	_setup.populate_game_state(gs)
	assert_eq(gs.get_player_state(1).ships.size(), 1,
			"Imperial should have 1 ship (Victory II)")


func test_populate_game_state_rebel_squadrons() -> void:
	var gs: GameState = GameState.new()
	gs.initialize()
	_setup.populate_game_state(gs)
	assert_eq(gs.get_player_state(0).squadrons.size(), 4,
			"Rebel should have 4 squadrons (X-wings)")


func test_populate_game_state_imperial_squadrons() -> void:
	var gs: GameState = GameState.new()
	gs.initialize()
	_setup.populate_game_state(gs)
	assert_eq(gs.get_player_state(1).squadrons.size(), 6,
			"Imperial should have 6 squadrons (TIE Fighters)")


func test_get_damage_deck_returns_initialized() -> void:
	## Rules Reference: SU-029 — damage deck shuffled at setup.
	var deck: DamageDeck = _setup.get_damage_deck()
	assert_not_null(deck, "get_damage_deck should return a DamageDeck")
	assert_eq(deck.get_draw_count(), DamageDeck.DECK_SIZE,
			"Damage deck should have 52 cards")
