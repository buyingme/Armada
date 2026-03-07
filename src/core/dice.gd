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


## Returns whether a dice face contains a critical result.
static func has_critical(face: Constants.DiceFace) -> bool:
	return face == Constants.DiceFace.CRITICAL or face == Constants.DiceFace.HIT_CRITICAL


## Returns whether a dice face is an accuracy result.
static func is_accuracy(face: Constants.DiceFace) -> bool:
	return face == Constants.DiceFace.ACCURACY
