## Tests for GameRng — seeded random number generator.
extends GutTest


# ------------------------------------------------------------------
# Construction
# ------------------------------------------------------------------

func test_init_with_seed_stores_seed() -> void:
	var rng := GameRng.new(42)
	assert_eq(rng.initial_seed, 42,
			"initial_seed should match the constructor argument.")


func test_init_zero_seed_randomizes() -> void:
	var rng := GameRng.new(0)
	assert_ne(rng.initial_seed, 0,
			"A zero seed should be replaced by a random non-zero seed.")


func test_init_default_randomizes() -> void:
	var rng := GameRng.new()
	assert_ne(rng.initial_seed, 0,
			"Default constructor should randomize the seed.")


# ------------------------------------------------------------------
# Determinism
# ------------------------------------------------------------------

func test_same_seed_produces_same_sequence() -> void:
	var rng_a := GameRng.new(12345)
	var rng_b := GameRng.new(12345)
	var seq_a: Array[int] = []
	var seq_b: Array[int] = []
	for _i: int in range(20):
		seq_a.append(rng_a.randi())
		seq_b.append(rng_b.randi())
	assert_eq(seq_a, seq_b,
			"Two RNGs with the same seed should produce identical sequences.")


func test_different_seeds_produce_different_sequences() -> void:
	var rng_a := GameRng.new(111)
	var rng_b := GameRng.new(222)
	var same: bool = true
	for _i: int in range(10):
		if rng_a.randi() != rng_b.randi():
			same = false
			break
	assert_false(same,
			"Different seeds should produce different sequences.")


# ------------------------------------------------------------------
# randi_range
# ------------------------------------------------------------------

func test_randi_range_within_bounds() -> void:
	var rng := GameRng.new(999)
	for _i: int in range(50):
		var val: int = rng.randi_range(0, 7)
		assert_true(val >= 0 and val <= 7,
				"randi_range(0, 7) should return 0..7, got %d." % val)


# ------------------------------------------------------------------
# shuffle
# ------------------------------------------------------------------

func test_shuffle_deterministic() -> void:
	var arr_a: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	var arr_b: Array = [1, 2, 3, 4, 5, 6, 7, 8]
	var rng_a := GameRng.new(555)
	var rng_b := GameRng.new(555)
	rng_a.shuffle(arr_a)
	rng_b.shuffle(arr_b)
	assert_eq(arr_a, arr_b,
			"Same-seed shuffles should produce identical orderings.")


func test_shuffle_changes_order() -> void:
	var arr: Array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
	var original: Array = arr.duplicate()
	var rng := GameRng.new(777)
	rng.shuffle(arr)
	# Extremely unlikely (1 in 10!) that shuffle preserves order.
	assert_ne(arr, original,
			"Shuffled array should differ from original.")


func test_shuffle_preserves_elements() -> void:
	var arr: Array = [10, 20, 30, 40, 50]
	var rng := GameRng.new(888)
	rng.shuffle(arr)
	arr.sort()
	assert_eq(arr, [10, 20, 30, 40, 50],
			"Shuffle must preserve all original elements.")


# ------------------------------------------------------------------
# State save / restore
# ------------------------------------------------------------------

func test_get_set_state_restores_sequence() -> void:
	var rng := GameRng.new(100)
	# Advance a few steps.
	for _i: int in range(5):
		rng.randi()
	var saved_state: int = rng.get_state()
	var val_a: int = rng.randi()
	# Restore and re-draw.
	rng.set_state(saved_state)
	var val_b: int = rng.randi()
	assert_eq(val_a, val_b,
			"Restoring state should reproduce the same value.")


# ------------------------------------------------------------------
# Serialization
# ------------------------------------------------------------------

func test_serialize_roundtrip() -> void:
	var rng := GameRng.new(54321)
	# Advance to create non-trivial state.
	for _i: int in range(10):
		rng.randi()
	var data: Dictionary = rng.serialize()
	var restored := GameRng.deserialize(data)
	# Both should produce the same next value.
	var val_orig: int = rng.randi()
	var val_rest: int = restored.randi()
	assert_eq(val_orig, val_rest,
			"Deserialized RNG should continue the same sequence.")
	assert_eq(restored.initial_seed, 54321,
			"Deserialized RNG should preserve the initial seed.")


func test_serialize_contains_expected_keys() -> void:
	var rng := GameRng.new(42)
	var data: Dictionary = rng.serialize()
	assert_true(data.has("initial_seed"),
			"Serialized dict should contain 'initial_seed'.")
	assert_true(data.has("state"),
			"Serialized dict should contain 'state'.")
	assert_eq(data["initial_seed"], 42,
			"Serialized initial_seed should match.")
