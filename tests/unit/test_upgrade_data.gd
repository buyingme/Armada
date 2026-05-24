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
