## Test: SquadronData
##
## Unit tests for SquadronData resource — defaults, keyword helpers, and data integrity.
extends GutTest


const FixturesScript: GDScript = preload("res://tests/fixtures/fixtures.gd")


# --- Default Values ---

func test_default_squadron_name_is_empty() -> void:
	var squad := SquadronData.new()
	assert_eq(squad.squadron_name, "", "Default squadron name should be empty")


func test_default_faction_is_rebel() -> void:
	var squad := SquadronData.new()
	assert_eq(squad.faction, Constants.Faction.REBEL_ALLIANCE, "Default faction should be REBEL_ALLIANCE")


func test_default_hull_is_zero() -> void:
	var squad := SquadronData.new()
	assert_eq(squad.hull, 0, "Default hull should be 0")


func test_default_speed_is_zero() -> void:
	var squad := SquadronData.new()
	assert_eq(squad.speed, 0, "Default speed should be 0")


func test_default_is_not_unique() -> void:
	var squad := SquadronData.new()
	assert_false(squad.is_unique, "Default squadron should not be unique")


func test_default_unique_group_is_empty() -> void:
	var squad := SquadronData.new()
	assert_eq(squad.unique_group, "", "Default unique group should be empty")


func test_default_keywords_is_empty() -> void:
	var squad := SquadronData.new()
	assert_eq(squad.keywords.size(), 0, "Default keywords should be empty")


func test_default_defense_tokens_is_empty() -> void:
	var squad := SquadronData.new()
	assert_eq(squad.defense_tokens.size(), 0, "Default defense tokens should be empty")


func test_default_ability_text_is_empty() -> void:
	var squad := SquadronData.new()
	assert_eq(squad.ability_text, "", "Default ability text should be empty string")


# --- has_keyword() ---

func test_has_keyword_returns_true_for_existing_keyword() -> void:
	# Arrange
	var squad: SquadronData = FixturesScript.create_test_squadron()

	# Act & Assert
	assert_true(squad.has_keyword("Bomber"), "Test squadron should have Bomber keyword")


func test_has_keyword_returns_true_for_escort() -> void:
	# Arrange
	var squad: SquadronData = FixturesScript.create_test_squadron()

	# Act & Assert
	assert_true(squad.has_keyword("Escort"), "Test squadron should have Escort keyword")


func test_has_keyword_returns_false_for_missing_keyword() -> void:
	# Arrange
	var squad: SquadronData = FixturesScript.create_test_squadron()

	# Act & Assert
	assert_false(squad.has_keyword("Swarm"), "Test squadron should not have Swarm keyword")


func test_has_keyword_empty_keywords() -> void:
	# Arrange
	var squad := SquadronData.new()

	# Act & Assert
	assert_false(squad.has_keyword("Bomber"), "Empty keywords should return false")


# --- get_keyword_value() ---

func test_get_keyword_value_returns_zero_for_valueless_keyword() -> void:
	# Arrange
	var squad: SquadronData = FixturesScript.create_test_squadron()

	# Act
	var value: int = squad.get_keyword_value("Bomber")

	# Assert
	assert_eq(value, 0, "Bomber has no numeric value, should return 0")


func test_get_keyword_value_returns_value_for_valued_keyword() -> void:
	# Arrange
	var squad := SquadronData.new()
	squad.keywords = [ {"name": "Counter", "value": 2}]

	# Act
	var value: int = squad.get_keyword_value("Counter")

	# Assert
	assert_eq(value, 2, "Counter 2 should return value 2")


func test_get_keyword_value_returns_zero_for_missing_keyword() -> void:
	# Arrange
	var squad: SquadronData = FixturesScript.create_test_squadron()

	# Act
	var value: int = squad.get_keyword_value("Counter")

	# Assert
	assert_eq(value, 0, "Missing keyword should return 0")


# --- TestFixtures Integration ---

func test_fixture_squadron_has_valid_name() -> void:
	var squad: SquadronData = FixturesScript.create_test_squadron()
	assert_ne(squad.squadron_name, "", "Test squadron should have a name")


func test_fixture_squadron_has_anti_squadron_dice() -> void:
	var squad: SquadronData = FixturesScript.create_test_squadron()
	assert_true(squad.anti_squadron_armament.size() > 0, "Test squadron should have anti-squadron armament")


func test_fixture_squadron_has_battery_armament() -> void:
	var squad: SquadronData = FixturesScript.create_test_squadron()
	assert_true(squad.battery_armament.size() > 0, "Test squadron should have battery armament")


func test_fixture_squadron_has_keywords() -> void:
	var squad: SquadronData = FixturesScript.create_test_squadron()
	assert_true(squad.keywords.size() > 0, "Test squadron should have keywords")


func test_fixture_squadron_has_reminder_text() -> void:
	var squad: SquadronData = FixturesScript.create_test_squadron()
	assert_true(squad.keyword_reminder_text.size() > 0, "Test squadron should have keyword reminder text")


func test_fixture_squadron_has_positive_hull() -> void:
	var squad: SquadronData = FixturesScript.create_test_squadron()
	assert_true(squad.hull > 0, "Squadron hull should be positive")


func test_fixture_squadron_has_positive_speed() -> void:
	var squad: SquadronData = FixturesScript.create_test_squadron()
	assert_true(squad.speed > 0, "Squadron speed should be positive")


# --- from_dict ---

func test_from_dict_parses_squadron_name() -> void:
	var squad: SquadronData = SquadronData.from_dict({"squadron_name": "X-wing Squadron"})
	assert_eq(squad.squadron_name, "X-wing Squadron",
		"from_dict should parse squadron_name")


func test_from_dict_parses_rebel_faction() -> void:
	var squad: SquadronData = SquadronData.from_dict({"faction": "REBEL_ALLIANCE"})
	assert_eq(squad.faction, Constants.Faction.REBEL_ALLIANCE,
		"from_dict should parse REBEL_ALLIANCE")


func test_from_dict_parses_imperial_faction() -> void:
	var squad: SquadronData = SquadronData.from_dict({"faction": "GALACTIC_EMPIRE"})
	assert_eq(squad.faction, Constants.Faction.GALACTIC_EMPIRE,
		"from_dict should parse GALACTIC_EMPIRE")


func test_from_dict_parses_hull() -> void:
	var squad: SquadronData = SquadronData.from_dict({"hull": 5})
	assert_eq(squad.hull, 5,
		"from_dict should parse hull")


func test_from_dict_parses_speed() -> void:
	var squad: SquadronData = SquadronData.from_dict({"speed": 3})
	assert_eq(squad.speed, 3,
		"from_dict should parse speed")


func test_from_dict_parses_is_unique_false() -> void:
	var squad: SquadronData = SquadronData.from_dict({"is_unique": false})
	assert_false(squad.is_unique,
		"from_dict should parse is_unique false")


func test_from_dict_parses_unique_group() -> void:
	var squad: SquadronData = SquadronData.from_dict({"unique_group": "luke_skywalker"})
	assert_eq(squad.unique_group, "luke_skywalker",
		"from_dict should parse unique squadron group")


func test_from_dict_unknown_faction_defaults_to_rebel_and_errors() -> void:
	var squad: SquadronData = SquadronData.from_dict({"faction": "BOGUS"})
	assert_eq(squad.faction, Constants.Faction.REBEL_ALLIANCE,
		"Unknown faction should default to REBEL_ALLIANCE")
	assert_push_error(1,
		"Should log a push_error for unknown faction")
