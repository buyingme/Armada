## Ship Data
##
## Resource that defines the static data for a ship type.
## Loaded from data files; instances are created from this template.
class_name ShipData
extends Resource


## The display name of the ship.
@export var ship_name: String = ""

## The faction this ship belongs to.
@export var faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE

## The size class of the ship.
@export var ship_size: Constants.ShipSize = Constants.ShipSize.SMALL

## The point cost of this ship.
@export var point_cost: int = 0

## The hull value (hit points before destruction).
@export var hull: int = 0

## The command value (size of command stack).
@export var command_value: int = 0

## The squadron value (number of squadrons that can be activated).
@export var squadron_value: int = 0

## The engineering value (repair points available).
@export var engineering_value: int = 0

## The maximum speed.
@export var max_speed: int = 0

## Shield values per hull zone: {HullZone: int}
@export var shields: Dictionary = {}

## Battery armament per hull zone: {HullZone: {DiceColor: int}}
@export var battery_armament: Dictionary = {}

## Anti-squadron armament: {DiceColor: int}
@export var anti_squadron_armament: Dictionary = {}

## Defense tokens available: Array[DefenseToken]
@export var defense_tokens: Array = []

## Available upgrade slots: Array[String]
@export var upgrade_slots: Array = []

## The navigation chart: Array of yaw values per speed joint.
## Index 0 = speed 1, each entry is an Array of yaw values per joint.
@export var navigation_chart: Array = []


## Creates a ShipData from a raw JSON dictionary keyed by the field names in
## card_data_schema.json. Enum string values ("SMALL", "MEDIUM", "LARGE",
## faction names) are parsed into their typed enum equivalents.
## Rules Reference: Resources/Game_Components/card_data_schema.json
static func from_dict(data: Dictionary) -> ShipData:
	var s: ShipData = ShipData.new()
	s.ship_name = data.get("ship_name", "")
	s.faction = _parse_faction(data.get("faction", "REBEL_ALLIANCE"))
	s.ship_size = _parse_ship_size(data.get("ship_size", "SMALL"))
	s.point_cost = int(data.get("point_cost", 0))
	s.hull = int(data.get("hull", 0))
	s.command_value = int(data.get("command_value", 0))
	s.squadron_value = int(data.get("squadron_value", 0))
	s.engineering_value = int(data.get("engineering_value", 0))
	s.max_speed = int(data.get("max_speed", 0))
	s.shields = data.get("shields", {})
	s.battery_armament = data.get("battery_armament", {})
	s.anti_squadron_armament = data.get("anti_squadron_armament", {})
	s.defense_tokens = data.get("defense_tokens", [])
	s.upgrade_slots = data.get("upgrade_slots", [])
	s.navigation_chart = data.get("navigation_chart", [])
	return s


## Parses a ship_size JSON string into the ShipSize enum.
## Rules Reference: "Ship Bases", p.12.
static func _parse_ship_size(value: String) -> Constants.ShipSize:
	match value.to_upper():
		"SMALL":
			return Constants.ShipSize.SMALL
		"MEDIUM":
			return Constants.ShipSize.MEDIUM
		"LARGE":
			return Constants.ShipSize.LARGE
		_:
			push_error("ShipData: unknown ship_size '%s' — defaulting to SMALL" % value)
			return Constants.ShipSize.SMALL


## Parses a faction JSON string into the Faction enum.
static func _parse_faction(value: String) -> Constants.Faction:
	match value.to_upper():
		"REBEL_ALLIANCE":
			return Constants.Faction.REBEL_ALLIANCE
		"GALACTIC_EMPIRE":
			return Constants.Faction.GALACTIC_EMPIRE
		"GALACTIC_REPUBLIC":
			return Constants.Faction.GALACTIC_REPUBLIC
		"SEPARATIST_ALLIANCE":
			return Constants.Faction.SEPARATIST_ALLIANCE
		_:
			push_error("ShipData: unknown faction '%s' — defaulting to REBEL_ALLIANCE" % value)
			return Constants.Faction.REBEL_ALLIANCE
