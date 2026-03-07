## Test Fixtures: Ship Data
##
## Factory functions for creating test ship data instances.
## Use these in tests to avoid duplicating test data setup.
class_name TestFixtures
extends RefCounted


## Creates a minimal small ship for testing.
static func create_test_small_ship() -> ShipData:
	var ship := ShipData.new()
	ship.ship_name = "Test Corvette"
	ship.faction = Constants.Faction.REBEL_ALLIANCE
	ship.ship_size = Constants.ShipSize.SMALL
	ship.point_cost = 44
	ship.hull = 4
	ship.command_value = 1
	ship.squadron_value = 1
	ship.engineering_value = 2
	ship.max_speed = 4
	ship.shields = {
		Constants.HullZone.FRONT: 2,
		Constants.HullZone.LEFT: 1,
		Constants.HullZone.RIGHT: 1,
		Constants.HullZone.REAR: 1,
	}
	ship.battery_armament = {
		Constants.HullZone.FRONT: {Constants.DiceColor.RED: 1, Constants.DiceColor.BLUE: 1},
		Constants.HullZone.LEFT: {Constants.DiceColor.RED: 1},
		Constants.HullZone.RIGHT: {Constants.DiceColor.RED: 1},
		Constants.HullZone.REAR: {Constants.DiceColor.RED: 1},
	}
	ship.anti_squadron_armament = {Constants.DiceColor.BLUE: 1}
	ship.defense_tokens = [
		Constants.DefenseToken.EVADE,
		Constants.DefenseToken.REDIRECT,
		Constants.DefenseToken.EVADE,
	]
	return ship


## Creates a minimal large ship for testing.
static func create_test_large_ship() -> ShipData:
	var ship := ShipData.new()
	ship.ship_name = "Test Star Destroyer"
	ship.faction = Constants.Faction.GALACTIC_EMPIRE
	ship.ship_size = Constants.ShipSize.LARGE
	ship.point_cost = 112
	ship.hull = 11
	ship.command_value = 3
	ship.squadron_value = 3
	ship.engineering_value = 4
	ship.max_speed = 2
	ship.shields = {
		Constants.HullZone.FRONT: 4,
		Constants.HullZone.LEFT: 3,
		Constants.HullZone.RIGHT: 3,
		Constants.HullZone.REAR: 2,
	}
	ship.battery_armament = {
		Constants.HullZone.FRONT: {Constants.DiceColor.RED: 3, Constants.DiceColor.BLUE: 2, Constants.DiceColor.BLACK: 1},
		Constants.HullZone.LEFT: {Constants.DiceColor.RED: 1, Constants.DiceColor.BLUE: 1},
		Constants.HullZone.RIGHT: {Constants.DiceColor.RED: 1, Constants.DiceColor.BLUE: 1},
		Constants.HullZone.REAR: {Constants.DiceColor.RED: 1, Constants.DiceColor.BLUE: 1},
	}
	ship.anti_squadron_armament = {Constants.DiceColor.BLUE: 1, Constants.DiceColor.BLACK: 1}
	ship.defense_tokens = [
		Constants.DefenseToken.BRACE,
		Constants.DefenseToken.REDIRECT,
		Constants.DefenseToken.CONTAIN,
		Constants.DefenseToken.REDIRECT,
	]
	return ship


## Creates a minimal squadron for testing.
static func create_test_squadron() -> SquadronData:
	var squad := SquadronData.new()
	squad.squadron_name = "Test X-wing Squadron"
	squad.faction = Constants.Faction.REBEL_ALLIANCE
	squad.point_cost = 13
	squad.hull = 5
	squad.speed = 3
	squad.anti_squadron_armament = {Constants.DiceColor.BLUE: 4}
	squad.battery_armament = {Constants.DiceColor.RED: 1}
	squad.keywords = [
		{"name": "Bomber"},
		{"name": "Escort"},
	]
	squad.keyword_reminder_text = {
		"Bomber": "While attacking a ship, each of your critical icons adds 1 damage to the damage total and you can resolve a critical effect.",
		"Escort": "Squadrons you are engaged with cannot attack squadrons that lack escort unless performing a counter attack.",
	}
	squad.ability_text = ""
	squad.is_unique = false
	return squad


## Creates a minimal upgrade for testing.
static func create_test_upgrade() -> UpgradeData:
	var upgrade := UpgradeData.new()
	upgrade.upgrade_name = "Test Commander"
	upgrade.upgrade_type = "Commander"
	upgrade.point_cost = 28
	upgrade.is_unique = true
	upgrade.effect_text = "Test effect description."
	return upgrade
