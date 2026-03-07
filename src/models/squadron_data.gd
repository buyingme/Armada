## Squadron Data
##
## Resource that defines the static data for a squadron type.
class_name SquadronData
extends Resource


## The display name of the squadron.
@export var squadron_name: String = ""

## The faction this squadron belongs to.
@export var faction: Constants.Faction = Constants.Faction.REBEL_ALLIANCE

## The point cost of this squadron.
@export var point_cost: int = 0

## The hull value.
@export var hull: int = 0

## The speed value.
@export var speed: int = 0

## Anti-squadron armament: {DiceColor: int}
@export var anti_squadron_armament: Dictionary = {}

## Battery armament (for attacking ships): {DiceColor: int}
@export var battery_armament: Dictionary = {}

## Special keywords (e.g., "Bomber", "Escort", "Counter", etc.)
@export var keywords: Array[String] = []

## Whether this is a unique (named) squadron.
@export var is_unique: bool = false

## The defense tokens available (for unique squadrons).
@export var defense_tokens: Array = []
