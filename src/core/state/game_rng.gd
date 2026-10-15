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
## The seed is stored in [member GameState] and persisted across save/load.
## In multiplayer the authoritative host owns the live RNG; passive Network
## snapshots omit it.  The existing replay bootstrap may distribute its
## recorded initial seed through game configuration before play begins.
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
		"initial_seed": str(initial_seed),
		"state": str(_rng.state),
	}


## Deserializes a [GameRng] from a previously serialized dictionary.
static func deserialize(data: Dictionary) -> GameRng:
	if data.size() != 2 or not data.has("initial_seed") \
			or not data.has("state"):
		return null
	var decoded_seed: Variant = _decode_exact_int64(data.get("initial_seed"))
	var decoded_state: Variant = _decode_exact_int64(data.get("state"))
	if decoded_seed == null or decoded_state == null or int(decoded_seed) == 0:
		return null
	var rng := GameRng.new(int(decoded_seed))
	rng.set_state(int(decoded_state))
	return rng


static func _decode_exact_int64(raw: Variant) -> Variant:
	if typeof(raw) != TYPE_STRING:
		return null
	var encoded: String = raw as String
	if encoded.is_empty() or not encoded.is_valid_int():
		return null
	var value: int = encoded.to_int()
	if str(value) != encoded:
		return null
	return value
