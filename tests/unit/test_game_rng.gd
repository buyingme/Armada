## Tests for GameRng — seeded random number generator.
extends GutTest


const OBSERVED_LARGE_VALUE: String = "5975857563556095516"
const LARGE_NEGATIVE_VALUE: String = "-5975857563556095516"
const INT64_MIN_TEXT: String = "-9223372036854775808"
const INT64_MAX_TEXT: String = "9223372036854775807"


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

func test_exact_json_roundtrip_preserves_large_signed_values_and_stream() -> void:
	for values: Array in [
		[OBSERVED_LARGE_VALUE, LARGE_NEGATIVE_VALUE],
		[LARGE_NEGATIVE_VALUE, OBSERVED_LARGE_VALUE],
	]:
		var rng := GameRng.new(values[0].to_int())
		rng.set_state(values[1].to_int())
		var parsed: Variant = JSON.parse_string(JSON.stringify(rng.serialize()))
		assert_true(parsed is Dictionary)
		var restored: GameRng = GameRng.deserialize(parsed as Dictionary)
		assert_not_null(restored)
		if restored == null:
			continue
		assert_eq(restored.initial_seed, rng.initial_seed)
		assert_eq(restored.get_state(), rng.get_state())
		assert_eq(restored.randi(), rng.randi(),
				"The next full-range outcome must remain aligned.")
		assert_eq(restored.randi_range(-37, 91), rng.randi_range(-37, 91),
				"The next bounded outcome must remain aligned.")
		assert_eq(restored.get_state(), rng.get_state(),
				"Both streams must remain aligned after continued consumption.")


func test_serialize_contains_expected_keys() -> void:
	var rng := GameRng.new(42)
	var data: Dictionary = rng.serialize()
	assert_eq(data.size(), 2)
	assert_typeof(data.get("initial_seed"), TYPE_STRING)
	assert_typeof(data.get("state"), TYPE_STRING)
	assert_eq(data.get("initial_seed"), "42")
	assert_eq(data.get("state"), str(rng.get_state()))


func test_signed_int64_limits_survive_exactly_for_both_fields() -> void:
	for values: Array in [
		[INT64_MIN_TEXT, INT64_MAX_TEXT],
		[INT64_MAX_TEXT, INT64_MIN_TEXT],
	]:
		var restored: GameRng = _json_rng(values[0], values[1])
		assert_not_null(restored)
		if restored == null:
			continue
		assert_eq(str(restored.initial_seed), values[0])
		assert_eq(str(restored.get_state()), values[1])
		assert_eq(restored.serialize(), {
			"initial_seed": values[0],
			"state": values[1],
		})


func test_current_state_zero_is_restored_but_initial_seed_zero_rejects() -> void:
	var restored: GameRng = _json_rng("42", "0")
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.get_state(), 0,
				"A zero current state must be assigned, not treated as absent.")
	assert_null(_json_rng("0", "42"),
			"A zero seed must reject instead of requesting random initialization.")


func test_each_exact_field_rejects_noncanonical_or_invalid_values() -> void:
	var invalid_values: Array = [
		123,
		1.5,
		null,
		true,
		[],
		{},
		"",
		"01",
		"+1",
		" 1",
		"1 ",
		"-0",
		"1e3",
		"1.0",
		"-9223372036854775809",
		"9223372036854775808",
	]
	for field: String in ["initial_seed", "state"]:
		for invalid: Variant in invalid_values:
			var encoded: Dictionary = {
				"initial_seed": "42",
				"state": "73",
			}
			encoded[field] = invalid
			_assert_rng_rejected_at_json_boundaries(encoded,
					"%s=%s" % [field, var_to_str(invalid)])
		var missing: Dictionary = {
			"initial_seed": "42",
			"state": "73",
		}
		missing.erase(field)
		_assert_rng_rejected_at_json_boundaries(missing,
				"missing %s" % field)


func test_full_authority_rng_container_rejects_invalid_shapes() -> void:
	var invalid_containers: Array = [
		null,
		true,
		42,
		"rng",
		[],
		{},
		{"initial_seed": "42"},
		{"state": "73"},
		{"initial_seed": "42", "state": "73", "extra": "no"},
	]
	for invalid: Variant in invalid_containers:
		var body: Dictionary = _full_authority_body()
		body["rng"] = invalid
		var parsed: Variant = JSON.parse_string(JSON.stringify(body))
		assert_true(parsed is Dictionary)
		assert_null(GameState.deserialize(parsed as Dictionary),
				"Invalid full-authority rng container must reject: %s" \
				% var_to_str(invalid))
	var absent: Dictionary = _full_authority_body()
	absent.erase("rng")
	var parsed_absent: Variant = JSON.parse_string(JSON.stringify(absent))
	assert_null(GameState.deserialize(parsed_absent as Dictionary),
			"A full-authority representation must contain rng.")


func _json_rng(seed_text: String, state_text: String) -> GameRng:
	var parsed: Variant = JSON.parse_string(JSON.stringify({
		"initial_seed": seed_text,
		"state": state_text,
	}))
	return GameRng.deserialize(parsed as Dictionary)


func _assert_rng_rejected_at_json_boundaries(
		encoded: Dictionary, context: String) -> void:
	var parsed_rng: Variant = JSON.parse_string(JSON.stringify(encoded))
	assert_true(parsed_rng is Dictionary)
	assert_null(GameRng.deserialize(parsed_rng as Dictionary),
			"GameRng must reject %s." % context)
	var body: Dictionary = _full_authority_body()
	body["rng"] = encoded
	var parsed_body: Variant = JSON.parse_string(JSON.stringify(body))
	assert_true(parsed_body is Dictionary)
	assert_null(GameState.deserialize(parsed_body as Dictionary),
			"GameState must fail closed for %s." % context)


func _full_authority_body() -> Dictionary:
	var state := GameState.new()
	state.rng = GameRng.new(42)
	state.initialize()
	state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human())
	state.damage_deck = DamageDeck.new()
	state.damage_deck.set_rng(state.rng)
	state.damage_deck.initialize()
	return state.serialize()
