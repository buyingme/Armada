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
