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


# --- Debug Scenario ---

func test_debug_scenario_token_count_matches_resolved_placements() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new("debug_scenario")
	assert_eq(setup.get_token_count(),
			setup.get_ship_placements().size() + setup.get_squadron_placements().size(),
			"Debug Scenario token count should match resolved ship + squadron placements")


func test_debug_scenario_json_is_structurally_valid() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new("debug_scenario")
	var data: Dictionary = _debug_scenario_data()
	assert_false(data.is_empty(),
			"Debug Scenario JSON should load as a non-empty dictionary")
	assert_true(data.has("tokens"),
			"Debug Scenario JSON should include a tokens array")
	assert_true(data.get("tokens", []) is Array,
			"Debug Scenario tokens should be an array")
	for token_index: int in range((data.get("tokens", []) as Array).size()):
		_assert_debug_token_entry_valid(
				(data.get("tokens", []) as Array)[token_index], token_index)
	assert_eq(setup.get_token_count(), (data.get("tokens", []) as Array).size(),
			"Every debug token should resolve to a runtime placement")


func test_debug_scenario_fixed_round1_commands_are_valid_when_enabled() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new("debug_scenario")
	var data: Dictionary = _debug_scenario_data()
	var use_fixed: bool = bool(data.get("use_fixed_round1_commands", false))
	assert_eq(setup.has_fixed_round1_commands(), use_fixed,
			"Debug Scenario fixed-command toggle should be read from JSON")
	if not use_fixed:
		assert_eq(setup.get_fixed_round1_commands().size(), 0,
				"Disabled debug fixed commands should resolve to an empty dictionary")
		return
	var raw_commands: Variant = data.get("fixed_round1_commands", {})
	assert_true(raw_commands is Dictionary,
			"Enabled debug fixed commands should be a dictionary")
	var ship_keys: Dictionary = _debug_ship_keys(data)
	for ship_key: Variant in raw_commands:
		assert_true(ship_keys.has(str(ship_key)),
				"Fixed commands should reference a debug scenario ship key")
		var commands: Variant = (raw_commands as Dictionary)[ship_key]
		assert_true(commands is Array,
				"Fixed command entries should be arrays")
		for command_name: Variant in (commands as Array):
			assert_ne(LearningScenarioSetup._parse_command_name(str(command_name)), -1,
					"Fixed command name should be supported: %s" % str(command_name))


func test_debug_scenario_fixed_round1_command_resolution_is_consistent() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new("debug_scenario")
	if not setup.has_fixed_round1_commands():
		assert_eq(setup.get_fixed_round1_commands().size(), 0,
				"Disabled debug fixed commands should resolve to empty")
		return
	var commands: Dictionary = setup.get_fixed_round1_commands()
	assert_false(commands.is_empty(),
			"Enabled debug fixed commands should resolve at least one ship")
	for ship_key: Variant in commands:
		assert_false(str(ship_key).is_empty(),
				"Resolved fixed command ship keys should be non-empty")
		assert_true(commands[ship_key] is Array,
				"Resolved fixed command stacks should be arrays")


func test_debug_scenario_referenced_map_asset_loads_when_present() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new("debug_scenario")
	var filename: String = setup.get_map_image_filename()
	if filename.is_empty():
		pass_test("Debug Scenario does not reference a map image.")
		return
	assert_not_null(AssetLoader.load_texture("maps/", filename),
			"Debug Scenario referenced map image should load: %s" % filename)


func test_standard_3x6_scenario_loads_map_without_tokens() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new("standard_3x6")
	assert_eq(setup.get_map_image_filename(), "map_3x6_distant-planet_v4.jpg",
			"Standard setup-package scenario should provide a board map")
	assert_eq(setup.get_token_count(), 0,
			"Standard setup-package scenario should not spawn JSON tokens")
	assert_false(setup.has_fixed_round1_commands(),
			"Standard setup-package scenario should use normal command assignment")


func test_debug_scenario_all_card_keys_resolve() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new("debug_scenario")
	for placement: TokenPlacement in setup.get_all_placements():
		if placement.is_ship:
			assert_not_null(AssetLoader.load_ship_data(placement.data_key),
					"Debug ship data_key should resolve: %s" % placement.data_key)
		else:
			assert_not_null(AssetLoader.load_squadron_data(placement.data_key),
					"Debug squadron data_key should resolve: %s" % placement.data_key)


func test_debug_scenario_populate_game_state_matches_resolved_instances() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new("debug_scenario")
	var expected_ships: Array[ShipInstance] = setup.create_ship_instances()
	var expected_squadrons: Array[SquadronInstance] = setup.create_squadron_instances()
	var gs: GameState = GameState.new()
	gs.initialize()
	setup.populate_game_state(gs)
	assert_eq(_total_ship_count(gs), expected_ships.size(),
			"Debug Scenario should register every resolved ship instance")
	assert_eq(_total_squadron_count(gs), expected_squadrons.size(),
			"Debug Scenario should register every resolved squadron instance")
	for ship: ShipInstance in expected_ships:
		assert_true(gs.get_player_state(ship.owner_player).ships.size() > 0,
				"Debug Scenario should register ships on their owning player")
	for squadron: SquadronInstance in expected_squadrons:
		assert_true(gs.get_player_state(squadron.owner_player).squadrons.size() > 0,
				"Debug Scenario should register squadrons on their owning player")


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


func _count_by_key(setup: LearningScenarioSetup, key: String) -> int:
	var count: int = 0
	for p: TokenPlacement in setup.get_all_placements():
		if p.data_key == key:
			count += 1
	return count


func _ship_by_key(ships: Array[ShipInstance], key: String) -> ShipInstance:
	for ship: ShipInstance in ships:
		if ship.data_key == key:
			return ship
	return null


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
	var token: Dictionary = {
		"key": key,
		"pos_x": 0.5,
		"pos_y": 0.2,
		"rotation_deg": 180.0,
		"type": "ship",
		"upgrades": upgrades,
	}
	if not roster_entry_id.is_empty():
		token["roster_entry_id"] = roster_entry_id
	return token


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


func _debug_scenario_data() -> Dictionary:
	return AssetLoader.load_json("scenarios/", "debug_scenario.json")


func _debug_ship_keys(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var tokens: Array = data.get("tokens", []) as Array
	for token: Variant in tokens:
		if not (token is Dictionary):
			continue
		var entry: Dictionary = token as Dictionary
		if str(entry.get("type", "")).strip_edges() == "ship":
			result[str(entry.get("key", "")).strip_edges()] = true
	return result


func _assert_debug_token_entry_valid(token: Variant, token_index: int) -> void:
	assert_true(token is Dictionary,
			"Debug token %d should be a dictionary" % token_index)
	if not (token is Dictionary):
		return
	var entry: Dictionary = token as Dictionary
	var type_name: String = str(entry.get("type", "")).strip_edges()
	var key: String = str(entry.get("key", "")).strip_edges()
	assert_false(key.is_empty(),
			"Debug token %d should include a card key" % token_index)
	assert_true(type_name == "ship" or type_name == "squadron",
			"Debug token %d should use a supported type" % token_index)
	_assert_numeric_field_in_range(entry, "pos_x", 0.0, 1.0, token_index)
	_assert_numeric_field_in_range(entry, "pos_y", 0.0, 1.0, token_index)
	_assert_numeric_field(entry, "rotation_deg", token_index)
	if type_name == "ship":
		assert_not_null(AssetLoader.load_ship_data(key),
				"Debug ship key should resolve: %s" % key)
		_assert_debug_ship_upgrades_valid(entry, token_index)
	elif type_name == "squadron":
		assert_not_null(AssetLoader.load_squadron_data(key),
				"Debug squadron key should resolve: %s" % key)
		assert_false(entry.has("upgrades"),
				"Debug squadron token %d should not declare ship upgrades" % token_index)


func _assert_numeric_field_in_range(entry: Dictionary, field: String,
		minimum: float, maximum: float, token_index: int) -> void:
	_assert_numeric_field(entry, field, token_index)
	if not _is_number(entry.get(field, null)):
		return
	var value: float = float(entry[field])
	assert_true(value >= minimum and value <= maximum,
			"Debug token %d %s should be within %.1f..%.1f" % [
				token_index, field, minimum, maximum])


func _assert_numeric_field(entry: Dictionary, field: String,
		token_index: int) -> void:
	assert_true(entry.has(field),
			"Debug token %d should include %s" % [token_index, field])
	if not entry.has(field):
		return
	assert_true(_is_number(entry[field]),
			"Debug token %d %s should be numeric" % [token_index, field])


func _assert_debug_ship_upgrades_valid(entry: Dictionary, token_index: int) -> void:
	if not entry.has("upgrades"):
		return
	assert_true(entry["upgrades"] is Array,
			"Debug ship token %d upgrades should be an array" % token_index)
	if not (entry["upgrades"] is Array):
		return
	var upgrades: Array = entry["upgrades"] as Array
	for upgrade_index: int in range(upgrades.size()):
		_assert_debug_upgrade_entry_valid(upgrades[upgrade_index],
				token_index, upgrade_index)


func _assert_debug_upgrade_entry_valid(upgrade: Variant,
		token_index: int, upgrade_index: int) -> void:
	assert_true(upgrade is Dictionary,
			"Debug upgrade %d on token %d should be a dictionary" % [
				upgrade_index, token_index])
	if not (upgrade is Dictionary):
		return
	var entry: Dictionary = upgrade as Dictionary
	for field: String in ["data_key", "source_assignment_id", "slot"]:
		assert_false(str(entry.get(field, "")).strip_edges().is_empty(),
				"Debug upgrade %d on token %d should include %s" % [
					upgrade_index, token_index, field])
	assert_true(entry.has("slot_index"),
			"Debug upgrade %d on token %d should include slot_index" % [
				upgrade_index, token_index])
	assert_true(_is_number(entry.get("slot_index", null)),
			"Debug upgrade %d on token %d slot_index should be numeric" % [
				upgrade_index, token_index])
	if _is_number(entry.get("slot_index", null)):
		assert_true(int(entry["slot_index"]) >= 0,
				"Debug upgrade %d on token %d slot_index should be non-negative" % [
					upgrade_index, token_index])
	var data_key: String = str(entry.get("data_key", "")).strip_edges()
	if not data_key.is_empty():
		assert_not_null(AssetLoader.load_upgrade_data(data_key),
				"Debug upgrade data_key should resolve: %s" % data_key)


func _assert_runtime_upgrade_canonical(ship: ShipInstance,
		runtime_upgrade: Dictionary, seen_ids: Dictionary) -> void:
	for field: String in ShipInstance.RUNTIME_UPGRADE_REQUIRED_FIELDS:
		assert_true(runtime_upgrade.has(field),
				"Runtime upgrade should include mandatory field: %s" % field)
	var runtime_upgrade_id: String = str(
			runtime_upgrade.get("runtime_upgrade_id", "")).strip_edges()
	assert_false(runtime_upgrade_id.is_empty(),
			"Runtime upgrade id should be non-empty")
	assert_false(seen_ids.has(runtime_upgrade_id),
			"Runtime upgrade ids should be unique: %s" % runtime_upgrade_id)
	seen_ids[runtime_upgrade_id] = true
	assert_eq(int(runtime_upgrade.get("owner_player_id", -1)), ship.owner_player,
			"Runtime upgrade owner should match owning ship")
	assert_eq(str(runtime_upgrade.get("source_roster_entry_id", "")),
			ship.roster_entry_id,
			"Runtime upgrade source roster id should match owning ship")
	assert_eq(str(runtime_upgrade.get("source_ship_ref", "")),
			"%d:ship:%s" % [ship.owner_player, ship.roster_entry_id],
			"Runtime upgrade source ship ref should match owning ship")
	assert_not_null(AssetLoader.load_upgrade_data(
			str(runtime_upgrade.get("data_key", ""))),
			"Runtime upgrade data_key should resolve")
	var card_state: Dictionary = runtime_upgrade.get("card_state", {}) as Dictionary
	assert_false(card_state.get("exhausted", true),
			"Scenario runtime upgrade should start unexhausted")
	assert_false(card_state.get("discarded", true),
			"Scenario runtime upgrade should start undiscarded")
	assert_false(card_state.get("disabled", true),
			"Scenario runtime upgrade should start enabled")
	assert_true(card_state.get("readied", false),
			"Scenario runtime upgrade should start readied")
	assert_true((runtime_upgrade.get("trigger_guards", {}) as Dictionary).is_empty(),
			"Scenario runtime upgrade should start with empty trigger guards")
	assert_true((runtime_upgrade.get("rule_state", {}) as Dictionary).is_empty(),
			"Scenario runtime upgrade should start with empty rule state")


func _total_ship_count(game_state: GameState) -> int:
	return game_state.get_player_state(0).ships.size() \
			+ game_state.get_player_state(1).ships.size()


func _total_squadron_count(game_state: GameState) -> int:
	return game_state.get_player_state(0).squadrons.size() \
			+ game_state.get_player_state(1).squadrons.size()


func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


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


func test_create_ship_instances_learning_scenario_has_no_runtime_upgrades() -> void:
	var ships: Array[ShipInstance] = _setup.create_ship_instances()
	for ship: ShipInstance in ships:
		assert_eq(ship.runtime_upgrades.size(), 0,
				"Learning Scenario ships should still load without upgrades")
		assert_eq(ship.roster_entry_id, "",
				"Learning Scenario no-upgrade ships should keep legacy identity shape")


func test_debug_scenario_runtime_upgrades_satisfy_canonical_invariants() -> void:
	var setup: LearningScenarioSetup = LearningScenarioSetup.new("debug_scenario")
	var ships: Array[ShipInstance] = setup.create_ship_instances()
	var seen_ids: Dictionary = {}
	for ship: ShipInstance in ships:
		for runtime_upgrade: Dictionary in ship.runtime_upgrades:
			_assert_runtime_upgrade_canonical(ship, runtime_upgrade, seen_ids)


func test_scenario_multiple_upgrades_materialize_deterministically() -> void:
	var setup: LearningScenarioSetup = _setup_from_tokens([
		_ship_token("victory_ii_class_star_destroyer", "scenario-vsd-1", [
			_upgrade("scenario-tarkin", "grand_moff_tarkin", "COMMANDER", 0),
			_upgrade("scenario-dominator", "dominator", "TITLE", 0),
		]),
	])

	var ship: ShipInstance = setup.create_ship_instances()[0]
	var first: Dictionary = ship.runtime_upgrades[0] as Dictionary
	var second: Dictionary = ship.runtime_upgrades[1] as Dictionary

	assert_eq(ship.runtime_upgrades.size(), 2,
			"Scenario setup should create one runtime instance per assigned upgrade")
	assert_eq(first.get("runtime_upgrade_id", ""),
			"1:ship:scenario-vsd-1:upgrade:scenario-tarkin",
			"First runtime upgrade id should be deterministic")
	assert_eq(second.get("runtime_upgrade_id", ""),
			"1:ship:scenario-vsd-1:upgrade:scenario-dominator",
			"Second runtime upgrade id should be deterministic")
	assert_eq(first.get("data_key", ""), "grand_moff_tarkin",
			"First runtime upgrade should preserve input order")
	assert_eq(second.get("data_key", ""), "dominator",
			"Second runtime upgrade should preserve input order")


func test_scenario_duplicate_ship_cards_get_distinct_source_identities() -> void:
	var setup: LearningScenarioSetup = _setup_from_tokens([
		_ship_token("victory_ii_class_star_destroyer", "", [
			_upgrade("scenario-tarkin", "grand_moff_tarkin", "COMMANDER", 0),
		]),
		_ship_token("victory_ii_class_star_destroyer", "", [
			_upgrade("scenario-tarkin", "grand_moff_tarkin", "COMMANDER", 0),
		]),
	])

	var ships: Array[ShipInstance] = setup.create_ship_instances()
	var first: ShipInstance = ships[0]
	var second: ShipInstance = ships[1]
	var first_upgrade: Dictionary = first.runtime_upgrades[0] as Dictionary
	var second_upgrade: Dictionary = second.runtime_upgrades[0] as Dictionary

	assert_eq(first.data_key, second.data_key,
			"Duplicate scenario ships should keep the same static data key")
	assert_ne(first.roster_entry_id, second.roster_entry_id,
			"Duplicate scenario ships should get distinct source identities")
	assert_ne(first_upgrade.get("runtime_upgrade_id", ""),
			second_upgrade.get("runtime_upgrade_id", ""),
			"Duplicate scenario ships should get distinct runtime upgrade ids")


func test_scenario_invalid_upgrade_data_key_is_rejected() -> void:
	var setup: LearningScenarioSetup = _setup_from_tokens([
		_ship_token("victory_ii_class_star_destroyer", "scenario-vsd-1", [
			_upgrade("scenario-missing", "missing_upgrade_data", "OFFICER", 0),
		]),
	])

	var ship: ShipInstance = setup.create_ship_instances()[0]

	assert_eq(ship.runtime_upgrades.size(), 0,
			"Scenario setup should skip unresolved runtime upgrade data_key")
	assert_push_error(1,
			"Invalid scenario upgrade data_key should surface invalid state")


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
