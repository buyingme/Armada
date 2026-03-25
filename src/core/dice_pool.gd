## Dice Pool
##
## Computes the attack dice pool for a given hull-zone armament and range band.
## Filters dice colours by range following the Rules Reference:
## - Red dice: available at close, medium, and long range.
## - Blue dice: available at close and medium range.
## - Black dice: available at close range only.
## Rules Reference: "Attack", Step 2, p.2; "Range and Distance", p.11.
class_name DicePool
extends RefCounted


## Dice-colour keys as they appear in ship JSON / ShipData.battery_armament.
const RED_KEY: String = "RED"
const BLUE_KEY: String = "BLUE"
const BLACK_KEY: String = "BLACK"

## Ordered list of colour keys used for consistent formatting.
const _COLOUR_ORDER: Array[String] = ["RED", "BLUE", "BLACK"]

## Display names for dice colours (lowercase, for UI text).
const _COLOUR_DISPLAY: Dictionary = {
	"RED": "red",
	"BLUE": "blue",
	"BLACK": "black",
}


## Returns the filtered dice pool for an attack from [param armament] at
## [param range_band].  [param armament] is a Dictionary mapping colour
## strings ("RED", "BLUE", "BLACK") to integer counts — the same format
## used in [code]ShipData.battery_armament["FRONT"][/code].
## [param range_band] is one of the [code]Constants.RANGE_BAND_*[/code]
## string constants.
## Returns a Dictionary with the same key format, containing only the
## colours that are valid at the given range.  Colours with zero count
## are omitted.
## Rules Reference: "Attack", Step 2 — "Gather attack dice equal to the
## … battery armament icons … appropriate for the range of the attack."
static func get_attack_pool(
		armament: Dictionary, range_band: String) -> Dictionary:
	if range_band == Constants.RANGE_BAND_BEYOND:
		return {}
	var pool: Dictionary = {}
	# Red dice: close, medium, long.
	var red_count: int = int(armament.get(RED_KEY, 0))
	if red_count > 0:
		pool[RED_KEY] = red_count
	# Blue dice: close, medium only.
	if range_band != Constants.RANGE_BAND_LONG:
		var blue_count: int = int(armament.get(BLUE_KEY, 0))
		if blue_count > 0:
			pool[BLUE_KEY] = blue_count
	# Black dice: close only.
	if range_band == Constants.RANGE_BAND_CLOSE:
		var black_count: int = int(armament.get(BLACK_KEY, 0))
		if black_count > 0:
			pool[BLACK_KEY] = black_count
	return pool


## Returns the total number of dice in [param pool].
static func get_total_count(pool: Dictionary) -> int:
	var total: int = 0
	for key: String in pool:
		total += int(pool[key])
	return total


## Formats [param pool] as a human-readable string, e.g. "2 red, 1 blue".
## Returns "0 dice" when the pool is empty.
## Colours appear in a fixed order: red, blue, black.
static func format_pool(pool: Dictionary) -> String:
	if pool.is_empty():
		return "0 dice"
	var parts: Array[String] = []
	for colour_key: String in _COLOUR_ORDER:
		var count: int = int(pool.get(colour_key, 0))
		if count > 0:
			var display: String = _COLOUR_DISPLAY.get(colour_key, colour_key)
			parts.append("%d %s" % [count, display])
	if parts.is_empty():
		return "0 dice"
	return ", ".join(parts)


## Convenience: computes and formats the dice pool in one call.
## Returns a formatted string like "2 red, 1 blue" for the given
## [param armament] at [param range_band].
static func format_attack_pool(
		armament: Dictionary, range_band: String) -> String:
	var pool: Dictionary = get_attack_pool(armament, range_band)
	return format_pool(pool)
