## Dice
##
## Represents the dice-rolling mechanics for Star Wars: Armada.
## Handles dice pools, rolling, and result interpretation.
class_name Dice
extends RefCounted


## The possible faces for each die color.
## Mapping: DiceColor -> Array of DiceFace (representing the 8 faces).
const DICE_FACES: Dictionary = {
	Constants.DiceColor.RED: [
		Constants.DiceFace.HIT,
		Constants.DiceFace.HIT,
		Constants.DiceFace.CRITICAL,
		Constants.DiceFace.CRITICAL,
		Constants.DiceFace.HIT_HIT,
		Constants.DiceFace.ACCURACY,
		Constants.DiceFace.BLANK,
		Constants.DiceFace.BLANK,
	],
	Constants.DiceColor.BLUE: [
		Constants.DiceFace.HIT,
		Constants.DiceFace.HIT,
		Constants.DiceFace.CRITICAL,
		Constants.DiceFace.CRITICAL,
		Constants.DiceFace.ACCURACY,
		Constants.DiceFace.ACCURACY,
		Constants.DiceFace.HIT,
		Constants.DiceFace.HIT,
	],
	Constants.DiceColor.BLACK: [
		Constants.DiceFace.HIT,
		Constants.DiceFace.HIT,
		Constants.DiceFace.HIT,
		Constants.DiceFace.HIT,
		Constants.DiceFace.HIT_CRITICAL,
		Constants.DiceFace.HIT_CRITICAL,
		Constants.DiceFace.BLANK,
		Constants.DiceFace.BLANK,
	],
}


## Rolls a single die of the given color and returns the face result.
static func roll_die(color: Constants.DiceColor) -> Constants.DiceFace:
	var faces: Array = DICE_FACES[color]
	var index := randi() % faces.size()
	return faces[index] as Constants.DiceFace


## Rolls a pool of dice and returns an array of results.
## [param pool] is a Dictionary mapping DiceColor -> count.
static func roll_pool(pool: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for color in pool:
		var count: int = pool[color]
		for i in range(count):
			var face := roll_die(color)
			results.append({
				"color": color,
				"face": face,
			})
	return results


## Returns the total damage from dice results.
static func calculate_damage(results: Array[Dictionary]) -> int:
	var total := 0
	for result in results:
		total += get_face_damage(result["face"] as Constants.DiceFace)
	return total


## Returns the total damage from dice results when the defender is a squadron.
## Critical icons do not count as damage vs squadrons.
## Rules Reference: "Dice Icons", p.5 — "Critical: If the attacker and
## defender are ships, this icon adds one damage to the damage total."
## A HIT_CRITICAL face counts only its hit portion (1 damage).
static func calculate_damage_vs_squadron(
		results: Array[Dictionary]) -> int:
	var total: int = 0
	for result: Dictionary in results:
		total += get_face_damage_vs_squadron(
				result["face"] as Constants.DiceFace)
	return total


## Returns the damage value for a given dice face.
static func get_face_damage(face: Constants.DiceFace) -> int:
	match face:
		Constants.DiceFace.HIT:
			return 1
		Constants.DiceFace.CRITICAL:
			return 1
		Constants.DiceFace.HIT_CRITICAL:
			return 2
		Constants.DiceFace.HIT_HIT:
			return 2
		Constants.DiceFace.ACCURACY:
			return 0
		Constants.DiceFace.BLANK:
			return 0
		_:
			return 0


## Returns the damage value for a dice face when attacking a squadron.
## Critical icons do not add damage vs squadrons — only hit icons count.
## Rules Reference: "Dice Icons", p.5 — critical adds damage only if
## both attacker and defender are ships.
static func get_face_damage_vs_squadron(face: Constants.DiceFace) -> int:
	match face:
		Constants.DiceFace.HIT:
			return 1
		Constants.DiceFace.CRITICAL:
			return 0
		Constants.DiceFace.HIT_CRITICAL:
			return 1
		Constants.DiceFace.HIT_HIT:
			return 2
		Constants.DiceFace.ACCURACY:
			return 0
		Constants.DiceFace.BLANK:
			return 0
		_:
			return 0


## Returns whether a dice face contains a critical result.
static func has_critical(face: Constants.DiceFace) -> bool:
	return face == Constants.DiceFace.CRITICAL or face == Constants.DiceFace.HIT_CRITICAL


## Returns whether a dice face is an accuracy result.
static func is_accuracy(face: Constants.DiceFace) -> bool:
	return face == Constants.DiceFace.ACCURACY


## Returns the number of accuracy results in a dice result array.
## Requirements: AE-ACC-001.
static func count_accuracy(results: Array[Dictionary]) -> int:
	var count: int = 0
	for result: Dictionary in results:
		if is_accuracy(result["face"] as Constants.DiceFace):
			count += 1
	return count


## Returns whether any die in the results has a critical face.
## Requirements: AE-DMG-010.
## Rules Reference: "Critical Effect", p.4 — standard critical: if at least
## one critical icon, first damage card is faceup.
static func has_any_critical(results: Array[Dictionary]) -> bool:
	for result: Dictionary in results:
		if has_critical(result["face"] as Constants.DiceFace):
			return true
	return false


## Base path for dice face PNG images.
const _DICE_IMAGE_BASE: String = "res://Resources/Game_Components/dice/"

## Mapping from DiceColor enum to the colour portion of the filename.
const _COLOUR_FILE_NAMES: Dictionary = {
	Constants.DiceColor.RED: "red",
	Constants.DiceColor.BLUE: "blue",
	Constants.DiceColor.BLACK: "black",
}

## Mapping from DiceFace enum to the face portion of the filename.
const _FACE_FILE_NAMES: Dictionary = {
	Constants.DiceFace.BLANK: "blank",
	Constants.DiceFace.HIT: "hit",
	Constants.DiceFace.CRITICAL: "crit",
	Constants.DiceFace.HIT_CRITICAL: "hit_crit",
	Constants.DiceFace.ACCURACY: "accuracy",
	Constants.DiceFace.HIT_HIT: "hit_hit",
}


## Returns the resource path for the PNG image representing a die face.
## E.g. [code]get_face_image_path(DiceColor.RED, DiceFace.HIT)[/code]
## returns [code]"res://Resources/Game_Components/dice/die_red_hit.png"[/code].
## Requirements: AE-DICE-002.
static func get_face_image_path(
		color: Constants.DiceColor, face: Constants.DiceFace) -> String:
	var colour_str: String = _COLOUR_FILE_NAMES.get(color, "red")
	var face_str: String = _FACE_FILE_NAMES.get(face, "blank")
	return "%sdie_%s_%s.png" % [_DICE_IMAGE_BASE, colour_str, face_str]
