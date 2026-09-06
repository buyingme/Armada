extends GutTest


const KEY_A := "0:ship-a"
const KEY_B := "1:ship-b"


func _card(title: String = "Public Card", faceup: bool = false) -> Dictionary:
	return {
		"trait_type": "Ship", "title": title, "is_faceup": faceup,
		"effect_text": "", "timing": "persistent", "effect_id": "fixture",
	}


func _data(draws: int = 2, discards: Array = [],
		counts: Dictionary = {KEY_A: 1, KEY_B: 0}) -> Dictionary:
	return {
		"schema_version": PassiveDamageLedger.SCHEMA_VERSION,
		"draw_count": draws,
		"discard_pile": discards,
		"facedown_counts": counts,
	}


func test_strict_round_trip_keeps_only_aggregate_hidden_state() -> void:
	var ledger := PassiveDamageLedger.deserialize(
			_data(3, [_card("Discard")]), [KEY_A, KEY_B])
	assert_not_null(ledger)
	assert_eq(ledger.serialize(), _data(3, [_card("Discard")]))


func test_unknown_missing_and_malformed_fields_reject() -> void:
	var unknown := _data()
	unknown["hidden_order"] = [_card("Secret")]
	assert_null(PassiveDamageLedger.deserialize(unknown, [KEY_A, KEY_B]))
	var missing := _data()
	missing.erase("draw_count")
	assert_null(PassiveDamageLedger.deserialize(missing, [KEY_A, KEY_B]))
	var fractional := _data()
	fractional["draw_count"] = 1.5
	assert_null(PassiveDamageLedger.deserialize(fractional, [KEY_A, KEY_B]))
	var malformed_card := _data(1, [_card()])
	malformed_card["discard_pile"][0]["title"] = 7
	assert_null(PassiveDamageLedger.deserialize(
			malformed_card, [KEY_A, KEY_B]))


func test_ship_key_set_must_be_exact() -> void:
	assert_null(PassiveDamageLedger.deserialize(_data(), [KEY_A]))
	var unknown := _data()
	unknown["facedown_counts"]["0:unknown"] = 0
	assert_null(PassiveDamageLedger.deserialize(unknown, [KEY_A, KEY_B]))


func test_consumes_draw_count_before_public_discard_reshuffle() -> void:
	var ledger := PassiveDamageLedger.deserialize(
			_data(1, [_card("A"), _card("B")]), [KEY_A, KEY_B])
	assert_true(ledger.consume_hidden_draws(2))
	assert_eq(ledger.draw_count, 1)
	assert_eq(ledger.discard_pile.size(), 0)


func test_insufficient_draw_rejects_before_mutation() -> void:
	var ledger := PassiveDamageLedger.deserialize(
			_data(0, [_card("A")]), [KEY_A, KEY_B])
	var before: Dictionary = ledger.serialize()
	assert_false(ledger.consume_hidden_draws(2))
	assert_eq(ledger.serialize(), before)


func test_named_facedown_counts_never_expose_identity() -> void:
	var ledger := PassiveDamageLedger.deserialize(_data(), [KEY_A, KEY_B])
	assert_true(ledger.increment_facedown(KEY_B, 2))
	assert_true(ledger.decrement_facedown(KEY_A))
	assert_eq(ledger.get_facedown_count(KEY_A), 0)
	assert_eq(ledger.get_facedown_count(KEY_B), 2)
	assert_false(JSON.stringify(ledger.serialize()).contains("Secret"))


func test_public_card_transition_requires_exact_canonical_schema() -> void:
	var faceup: Dictionary = _card("Known", true)
	assert_not_null(PassiveDamageLedger.deserialize_public_card(faceup, true))
	faceup["extra"] = "rejected"
	assert_null(PassiveDamageLedger.deserialize_public_card(faceup, true))
