## Test: UpgradeData
##
## Unit tests for UpgradeData resource — defaults, properties, and data integrity.
extends GutTest


const FixturesScript: GDScript = preload("res://tests/fixtures/fixtures.gd")


# --- Default Values ---

func test_default_upgrade_name_is_empty() -> void:
	var upgrade := UpgradeData.new()
	assert_eq(upgrade.upgrade_name, "", "Default upgrade name should be empty")


func test_default_upgrade_type_is_empty() -> void:
	var upgrade := UpgradeData.new()
	assert_eq(upgrade.upgrade_type, "", "Default upgrade type should be empty")


func test_default_point_cost_is_zero() -> void:
	var upgrade := UpgradeData.new()
	assert_eq(upgrade.point_cost, 0, "Default point cost should be 0")


func test_default_is_not_unique() -> void:
	var upgrade := UpgradeData.new()
	assert_false(upgrade.is_unique, "Default upgrade should not be unique")


func test_default_is_not_modification() -> void:
	var upgrade := UpgradeData.new()
	assert_false(upgrade.is_modification, "Default upgrade should not be modification")


func test_default_is_not_exhaustible() -> void:
	var upgrade := UpgradeData.new()
	assert_false(upgrade.is_exhaustible, "Default upgrade should not be exhaustible")


func test_default_effect_text_is_empty() -> void:
	var upgrade := UpgradeData.new()
	assert_eq(upgrade.effect_text, "", "Default effect text should be empty")


func test_default_faction_restriction_is_empty() -> void:
	var upgrade := UpgradeData.new()
	assert_eq(upgrade.faction_restriction.size(), 0, "Default faction restriction should be empty")


func test_default_size_restriction_is_empty() -> void:
	var upgrade := UpgradeData.new()
	assert_eq(upgrade.size_restriction.size(), 0, "Default size restriction should be empty")


# --- from_dict ---

func test_from_dict_parses_upgrade_identity_expected() -> void:
	var data: Dictionary = _load_general_dodonna_record()
	var upgrade: UpgradeData = UpgradeData.from_dict(data)
	assert_eq(upgrade.data_key, "general_dodonna", "Should parse stable upgrade key")
	assert_eq(upgrade.upgrade_name, "General Dodonna", "Should parse upgrade name")
	assert_eq(upgrade.upgrade_type, "COMMANDER", "Should parse upgrade slot")
	assert_eq(upgrade.point_cost, 20, "Should parse upgrade cost")


func test_from_dict_parses_catalog_metadata_expected() -> void:
	var data: Dictionary = _load_general_dodonna_record()
	var upgrade: UpgradeData = UpgradeData.from_dict(data)
	assert_eq(upgrade.wave, 0, "Core Set upgrades should parse as wave 0")
	assert_eq(upgrade.expansion, "core_set", "Should parse source expansion")
	assert_true(upgrade.available_through.has("star_wars_armada_core_set"),
		"Should parse product availability")
	assert_eq(upgrade.card_image, "w0_general_dodonna_card.png", "Should parse card image")


func test_from_dict_parses_restrictions_expected() -> void:
	var data: Dictionary = _load_general_dodonna_record()
	var upgrade: UpgradeData = UpgradeData.from_dict(data)
	assert_true(upgrade.is_unique, "General Dodonna should be unique")
	assert_eq(upgrade.unique_group, "general_dodonna", "Should parse unique group")
	assert_eq(upgrade.faction_restriction[0], Constants.Faction.REBEL_ALLIANCE,
		"Should parse Rebel faction restriction")
	assert_eq(upgrade.size_restriction.size(), 0, "Should preserve empty size restrictions")


func test_from_dict_preserves_rules_metadata_expected() -> void:
	var data: Dictionary = _load_general_dodonna_record()
	var upgrade: UpgradeData = UpgradeData.from_dict(data)
	assert_eq(upgrade.rules_reference_ids[0], "upgrade.general_dodonna",
		"Should parse rules-reference ids")
	assert_eq(upgrade.rules_integration.get("status", ""), "NOT_INTEGRATED",
		"Should parse implementation status")
	assert_eq(upgrade.rule_surfaces[0].get("surface", ""), "damage.before_faceup_card_dealt",
		"Should preserve future RuleRegistry surface metadata")


# --- TestFixtures Integration ---

func test_fixture_upgrade_has_valid_name() -> void:
	var upgrade: UpgradeData = FixturesScript.create_test_upgrade()
	assert_ne(upgrade.upgrade_name, "", "Test upgrade should have a name")


func test_fixture_upgrade_has_type() -> void:
	var upgrade: UpgradeData = FixturesScript.create_test_upgrade()
	assert_ne(upgrade.upgrade_type, "", "Test upgrade should have a type")


func test_fixture_upgrade_has_positive_cost() -> void:
	var upgrade: UpgradeData = FixturesScript.create_test_upgrade()
	assert_true(upgrade.point_cost > 0, "Test upgrade should have positive cost")


func test_fixture_upgrade_is_unique() -> void:
	var upgrade: UpgradeData = FixturesScript.create_test_upgrade()
	assert_true(upgrade.is_unique, "Test commander upgrade should be unique")


func test_fixture_upgrade_has_effect_text() -> void:
	var upgrade: UpgradeData = FixturesScript.create_test_upgrade()
	assert_ne(upgrade.effect_text, "", "Test upgrade should have effect text")


# --- Property Assignment ---

func test_set_modification_flag() -> void:
	# Arrange
	var upgrade := UpgradeData.new()

	# Act
	upgrade.is_modification = true

	# Assert
	assert_true(upgrade.is_modification, "Should be able to set modification flag")


func test_set_exhaustible_flag() -> void:
	# Arrange
	var upgrade := UpgradeData.new()

	# Act
	upgrade.is_exhaustible = true

	# Assert
	assert_true(upgrade.is_exhaustible, "Should be able to set exhaustible flag")


func test_set_faction_restriction() -> void:
	# Arrange
	var upgrade := UpgradeData.new()

	# Act
	upgrade.faction_restriction = [Constants.Faction.REBEL_ALLIANCE]

	# Assert
	assert_eq(upgrade.faction_restriction.size(), 1, "Should have one faction restriction")
	assert_eq(upgrade.faction_restriction[0], Constants.Faction.REBEL_ALLIANCE, "Should be restricted to Rebels")


func _load_general_dodonna_record() -> Dictionary:
	return AssetLoader.load_json("upgrades/commander/", "general_dodonna.json")
