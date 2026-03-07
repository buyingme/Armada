## Squadron Data
##
## Resource that defines the static data for a squadron type.
## Keywords are stored as structured dictionaries: {"name": String, "value": int (optional)}
## This allows keywords with numeric values (Counter 2, Snipe 3) to be handled generically.
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

## Keyword abilities as structured data.
## Each entry: {"name": "Bomber"} or {"name": "Counter", "value": 2}
@export var keywords: Array[Dictionary] = []

## Reminder text for each keyword, keyed by keyword name.
## Displayed to the player on the in-game card view.
@export var keyword_reminder_text: Dictionary = {}

## Special ability text for unique squadrons (beyond standard keywords).
## Empty string for generic squadrons.
@export var ability_text: String = ""

## Whether this is a unique (named) squadron.
@export var is_unique: bool = false

## The defense tokens available (for unique squadrons).
@export var defense_tokens: Array = []


## --- Helper Methods ---

## Returns true if this squadron has the given keyword.
func has_keyword(keyword_name: String) -> bool:
	for kw: Dictionary in keywords:
		if kw.get("name", "") == keyword_name:
			return true
	return false


## Returns the numeric value of a keyword, or 0 if not found / no value.
func get_keyword_value(keyword_name: String) -> int:
	for kw: Dictionary in keywords:
		if kw.get("name", "") == keyword_name:
			return kw.get("value", 0) as int
	return 0
