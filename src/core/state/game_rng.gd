## GameRng
##
## Central seeded random number generator for all game-mechanics RNG.
## Wraps Godot's [RandomNumberGenerator] so that every game session can
## be replayed deterministically from the same seed.
##
## Usage:
## [codeblock]
## var rng := GameRng.new(12345)
## var index: int = rng.randi_range(0, 7)
## rng.shuffle(my_array)
## [/codeblock]
##
## The seed is stored in [member GameState] and persisted across
## save/load.  For multiplayer the host generates the seed and
## transmits it to all clients at game start.
class_name GameRng
extends RefCounted


## The initial seed provided at construction.
var initial_seed: int = 0

## The underlying Godot RNG instance.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Creates a new [GameRng] with the given [param p_seed].
## If [param p_seed] is [code]0[/code] a random seed is chosen.
func _init(p_seed: int = 0) -> void:
	if p_seed == 0:
		_rng.randomize()
		initial_seed = _rng.seed
	else:
		initial_seed = p_seed
		_rng.seed = p_seed


## Returns a random integer in the inclusive range
## [[param from], [param to]].
func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Returns a random integer using the full 32-bit range.
func randi() -> int:
	return _rng.randi()


## Shuffles [param array] in-place using the seeded RNG.
## Implements the Fisher-Yates (Knuth) shuffle.
func shuffle(array: Array) -> void:
	for i: int in range(array.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = array[i]
		array[i] = array[j]
		array[j] = tmp


## Returns the current internal RNG state so it can be restored later.
func get_state() -> int:
	return _rng.state


## Restores the internal RNG state previously obtained via [method get_state].
func set_state(p_state: int) -> void:
	_rng.state = p_state


## Serializes the RNG to a dictionary for save/load.
func serialize() -> Dictionary:
	return {
		"initial_seed": initial_seed,
		"state": _rng.state,
	}


## Deserializes a [GameRng] from a previously serialized dictionary.
static func deserialize(data: Dictionary) -> GameRng:
	var rng := GameRng.new(data.get("initial_seed", 0))
	var saved_state: int = data.get("state", 0)
	if saved_state != 0:
		rng.set_state(saved_state)
	return rng
