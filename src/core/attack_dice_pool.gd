## AttackDicePool
##
## Manages the dice pool for a single attack: gathering from armament,
## filtering by range, handling obstruction removal, adding dice (Concentrate
## Fire dial), rolling, rerolling, and calculating damage totals.
##
## Pure core logic — extends RefCounted, no scene-tree dependency.
##
## Rules Reference: "Attack", Steps 2–3; "Attack Range"; "Obstructed";
## "Modifying Dice"; "Commands" — Concentrate Fire.
## Requirements: ATK-S2-001–004, ATK-S3-001.
class_name AttackDicePool
extends RefCounted


## The gathered dice pool before rolling: { "RED": int, "BLUE": int, "BLACK": int }.
var _gathered_pool: Dictionary = {}

## The rolled dice results: Array of { "color": DiceColor, "face": DiceFace }.
var _rolled_results: Array[Dictionary] = []

## Whether the attack is obstructed.
var _obstructed: bool = false

## Whether obstruction die has been removed.
var _obstruction_resolved: bool = false

## Whether the dice have been rolled.
var _is_rolled: bool = false

## Whether a Concentrate Fire die was added.
var _cf_die_added: bool = false

## Whether a Concentrate Fire reroll was used.
var _cf_reroll_used: bool = false

## Indices of dice locked by accuracy spending (cannot be modified further).
var _accuracy_locked_token_indices: Array[int] = []

var _log: GameLogger = GameLogger.new("AttackDicePool")


## Gathers the dice pool from the given armament at the given range band.
## [param armament] — { "RED": int, "BLUE": int, "BLACK": int }.
## [param range_band] — "close", "medium", or "long".
## [param obstructed] — whether the attack LOS is obstructed.
## Rules Reference: "Attack", Step 2; "Attack Range".
## Requirements: ATK-S2-001.
func gather(armament: Dictionary, range_band: String,
		obstructed: bool) -> void:
	_gathered_pool = RangeFinder.dice_at_range(armament, range_band)
	_obstructed = obstructed
	_obstruction_resolved = false
	_is_rolled = false
	_rolled_results.clear()
	_cf_die_added = false
	_cf_reroll_used = false
	_accuracy_locked_token_indices.clear()
	_log.info("Gathered pool: %s (obstructed=%s)" %
			[RangeFinder.format_dice(_gathered_pool), str(obstructed)])


## Returns the current gathered pool (before rolling).
func get_gathered_pool() -> Dictionary:
	return _gathered_pool.duplicate()


## Returns the total number of dice in the gathered pool.
func get_gathered_count() -> int:
	var total: int = 0
	for colour: String in _gathered_pool:
		total += int(_gathered_pool[colour])
	return total


## Returns true if the attack is obstructed.
func is_obstructed() -> bool:
	return _obstructed


## Returns true if obstruction has been resolved (die removed).
func is_obstruction_resolved() -> bool:
	return _obstruction_resolved


## Returns true if the pool has 0 dice (attack will be cancelled).
func is_empty() -> bool:
	return get_gathered_count() == 0 and _rolled_results.is_empty()


## Returns the colours available in the gathered pool (for CF dial choices).
func get_available_colours() -> Array[String]:
	var colours: Array[String] = []
	for colour: String in ["RED", "BLUE", "BLACK"]:
		if _gathered_pool.get(colour, 0) > 0:
			colours.append(colour)
	return colours


## Removes one die of the given colour for obstruction.
## Returns true if a die was removed.
## Rules Reference: "Obstructed" — remove 1 die before rolling.
## Requirements: ATK-S2-002.
func remove_obstruction_die(colour: String) -> bool:
	if not _obstructed or _obstruction_resolved:
		return false
	var count: int = _gathered_pool.get(colour, 0)
	if count <= 0:
		return false
	_gathered_pool[colour] = count - 1
	if _gathered_pool[colour] == 0:
		_gathered_pool.erase(colour)
	_obstruction_resolved = true
	_log.info("Obstruction die removed: %s (pool now: %s)" %
			[colour, RangeFinder.format_dice(_gathered_pool)])
	return true


## Auto-removes the obstruction die when only 1 die is in the pool.
## Returns the colour of the removed die, or "" if not auto-removed.
func auto_remove_obstruction() -> String:
	if not _obstructed or _obstruction_resolved:
		return ""
	if get_gathered_count() != 1:
		return ""
	for colour: String in _gathered_pool:
		if _gathered_pool[colour] > 0:
			remove_obstruction_die(colour)
			return colour
	return ""


## Adds a die of the given colour from Concentrate Fire dial.
## The colour must already exist in the pool.
## Returns true if added.
## Rules Reference: "Commands" — P Dial.
## Requirements: ATK-S2-003.
func add_concentrate_fire_die(colour: String) -> bool:
	if _cf_die_added:
		_log.info("CF die already added.")
		return false
	if _gathered_pool.get(colour, 0) <= 0:
		_log.info("CF die colour %s not in pool." % colour)
		return false
	_gathered_pool[colour] = _gathered_pool[colour] + 1
	_cf_die_added = true
	_log.info("CF die added: %s (pool now: %s)" %
			[colour, RangeFinder.format_dice(_gathered_pool)])
	return true


## Returns true if a CF die has been added.
func is_cf_die_added() -> bool:
	return _cf_die_added


## Rolls all dice in the gathered pool. Can only be called once.
## Returns the rolled results.
## Rules Reference: "Attack", Step 2.
## Requirements: ATK-S2-004.
func roll() -> Array[Dictionary]:
	if _is_rolled:
		_log.info("Already rolled.")
		return _rolled_results
	var enum_pool: Dictionary = _to_enum_pool(_gathered_pool)
	_rolled_results = Dice.roll_pool(enum_pool)
	_is_rolled = true
	_log.info("Rolled %d dice." % _rolled_results.size())
	return _rolled_results


## Returns true if the dice have been rolled.
func is_rolled() -> bool:
	return _is_rolled


## Returns the current rolled results.
func get_results() -> Array[Dictionary]:
	return _rolled_results


## Rerolls the die at the given index (Concentrate Fire token or Evade).
## Returns the new face.
## Rules Reference: "Modifying Dice" — Reroll.
## Requirements: ATK-S3-001.
func reroll_die(index: int) -> Constants.DiceFace:
	if index < 0 or index >= _rolled_results.size():
		return Constants.DiceFace.BLANK
	var colour: Constants.DiceColor = \
			_rolled_results[index]["color"] as Constants.DiceColor
	var new_face: Constants.DiceFace = Dice.roll_die(colour)
	_rolled_results[index]["face"] = new_face
	_log.info("Rerolled die %d: %s" % [index,
			Constants.DiceFace.keys()[new_face]])
	return new_face


## Marks the CF reroll as used.
func mark_cf_reroll_used() -> void:
	_cf_reroll_used = true


## Returns true if the CF reroll has been used.
func is_cf_reroll_used() -> bool:
	return _cf_reroll_used


## Removes a die at the given index from the pool (e.g. Evade cancel).
## Returns the removed die dictionary.
func remove_die(index: int) -> Dictionary:
	if index < 0 or index >= _rolled_results.size():
		return {}
	var removed: Dictionary = _rolled_results[index]
	_rolled_results.remove_at(index)
	# Adjust accuracy-locked indices.
	var new_locked: Array[int] = []
	for locked_idx: int in _accuracy_locked_token_indices:
		if locked_idx < index:
			new_locked.append(locked_idx)
		elif locked_idx > index:
			new_locked.append(locked_idx - 1)
	_accuracy_locked_token_indices = new_locked
	_log.info("Die removed at index %d." % index)
	return removed


## Cancels all dice (Scatter defense token).
func cancel_all() -> void:
	_rolled_results.clear()
	_log.info("All dice cancelled (Scatter).")


## Returns indices of dice showing accuracy faces.
func get_accuracy_indices() -> Array[int]:
	var indices: Array[int] = []
	for i: int in range(_rolled_results.size()):
		if Dice.is_accuracy(
				_rolled_results[i]["face"] as Constants.DiceFace):
			indices.append(i)
	return indices


## Spends an accuracy die at the given index (removes it from pool).
## Requirements: ATK-S3-002.
func spend_accuracy(index: int) -> bool:
	if index < 0 or index >= _rolled_results.size():
		return false
	if not Dice.is_accuracy(
			_rolled_results[index]["face"] as Constants.DiceFace):
		return false
	remove_die(index)
	_log.info("Accuracy spent at index %d." % index)
	return true


## Calculates total damage for a ship-vs-ship attack.
## Damage = sum of all hit + critical icons.
## Rules Reference: "Attack", Step 5.
func calculate_ship_damage() -> int:
	return Dice.calculate_damage(_rolled_results)


## Calculates total damage for a ship-vs-squadron attack.
## Damage = sum of hit icons only (no criticals).
## Rules Reference: "Attack", Step 5.
func calculate_squadron_damage() -> int:
	var total: int = 0
	for result: Dictionary in _rolled_results:
		var face: Constants.DiceFace = result["face"] as Constants.DiceFace
		match face:
			Constants.DiceFace.HIT:
				total += 1
			Constants.DiceFace.HIT_HIT:
				total += 2
			Constants.DiceFace.HIT_CRITICAL:
				total += 1  # Only the hit portion counts vs squadrons.
	return total


## Returns true if the pool contains at least one critical icon.
## Rules Reference: "Critical Effects".
func has_critical() -> bool:
	for result: Dictionary in _rolled_results:
		if Dice.has_critical(result["face"] as Constants.DiceFace):
			return true
	return false


## Returns a human-readable summary of the current pool state.
func get_pool_summary() -> String:
	if not _is_rolled:
		return "Pool: %s" % RangeFinder.format_dice(_gathered_pool)
	var faces: Array[String] = []
	for result: Dictionary in _rolled_results:
		var face_name: String = Constants.DiceFace.keys()[
				result["face"] as int]
		var colour_name: String = Constants.DiceColor.keys()[
				result["color"] as int]
		faces.append("%s_%s" % [colour_name, face_name])
	return "Rolled: [%s]" % ", ".join(faces)


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------


## Converts a string-keyed pool (from RangeFinder) to a DiceColor-keyed pool
## suitable for Dice.roll_pool().
func _to_enum_pool(pool: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for colour: String in pool:
		result[_colour_to_enum(colour)] = pool[colour]
	return result


## Converts a colour string ("RED", "BLUE", "BLACK") to a DiceColor enum.
static func _colour_to_enum(colour: String) -> Constants.DiceColor:
	match colour:
		"RED":
			return Constants.DiceColor.RED
		"BLUE":
			return Constants.DiceColor.BLUE
		"BLACK":
			return Constants.DiceColor.BLACK
		_:
			return Constants.DiceColor.RED
