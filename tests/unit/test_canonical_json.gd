## Test: CanonicalJson
##
## Unit tests for deterministic JSON stringification and hashing.
extends GutTest


func test_stringify_sorts_dictionary_keys_recursively_expected() -> void:
	var first: Dictionary = {"b": 2, "a": {"d": 4, "c": [3, 2]}}
	var second: Dictionary = {"a": {"c": [3, 2], "d": 4}, "b": 2}
	assert_eq(CanonicalJson.stringify(first), CanonicalJson.stringify(second),
		"Canonical JSON should ignore dictionary insertion order")


func test_hash_matches_for_equivalent_dictionaries_expected() -> void:
	var first: Dictionary = {"players": [{"name": "Rebel"}], "scenario_id": "demo"}
	var second: Dictionary = {"scenario_id": "demo", "players": [{"name": "Rebel"}]}
	assert_eq(CanonicalJson.hash(first), CanonicalJson.hash(second),
		"Canonical hash should be stable for equivalent dictionaries")


func test_hash_preserves_array_order_expected() -> void:
	var first: Dictionary = {"items": ["a", "b"]}
	var second: Dictionary = {"items": ["b", "a"]}
	assert_ne(CanonicalJson.hash(first), CanonicalJson.hash(second),
		"Canonical hash should preserve array ordering")


func test_stringify_handles_scalar_values_expected() -> void:
	assert_eq(CanonicalJson.stringify(null), "null", "Should stringify null")
	assert_eq(CanonicalJson.stringify(true), "true", "Should stringify booleans")
	assert_eq(CanonicalJson.stringify("fleet"), "\"fleet\"", "Should stringify strings")