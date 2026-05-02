## Test: IntegritySigner
##
## Unit tests for the shared HMAC-SHA256 signing utility (Phase J1).
extends GutTest


func _key_a() -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.resize(32)
	for i: int in range(32):
		b[i] = i + 1
	return b


func _key_b() -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	b.resize(32)
	for i: int in range(32):
		b[i] = 99
	return b


func _fresh_header() -> Dictionary:
	return {"version": 1, "round": 3, "phase": "Ship"}


func _fresh_body() -> Dictionary:
	return {"score": 45, "fleet": ["a", "b"]}


# ---------------------------------------------------------------------------
# sign / verify happy path
# ---------------------------------------------------------------------------

func test_sign_then_verify_succeeds() -> void:
	var header: Dictionary = _fresh_header()
	var body: Dictionary = _fresh_body()
	var ok: bool = IntegritySigner.sign(header, body, _key_a())
	assert_true(ok, "sign should succeed with a non-empty key")
	assert_true(header.has(IntegritySigner.SIGNATURE_FIELD),
			"sign should populate the signature field on the header")
	assert_true(IntegritySigner.verify(header, body, _key_a()),
			"verify should accept the same {header, body, key} triple")


func test_is_signed_reflects_signature_presence() -> void:
	var header: Dictionary = _fresh_header()
	assert_false(IntegritySigner.is_signed(header),
			"Fresh header is not signed")
	IntegritySigner.sign(header, _fresh_body(), _key_a())
	assert_true(IntegritySigner.is_signed(header),
			"After signing, is_signed returns true")


# ---------------------------------------------------------------------------
# Tamper detection
# ---------------------------------------------------------------------------

func test_verify_rejects_tampered_body() -> void:
	var header: Dictionary = _fresh_header()
	var body: Dictionary = _fresh_body()
	IntegritySigner.sign(header, body, _key_a())
	body["score"] = 999
	assert_false(IntegritySigner.verify(header, body, _key_a()),
			"verify should reject a tampered body")


func test_verify_rejects_tampered_header() -> void:
	var header: Dictionary = _fresh_header()
	var body: Dictionary = _fresh_body()
	IntegritySigner.sign(header, body, _key_a())
	header["round"] = 99
	assert_false(IntegritySigner.verify(header, body, _key_a()),
			"verify should reject a tampered header")


func test_verify_rejects_wrong_key() -> void:
	var header: Dictionary = _fresh_header()
	var body: Dictionary = _fresh_body()
	IntegritySigner.sign(header, body, _key_a())
	assert_false(IntegritySigner.verify(header, body, _key_b()),
			"verify should reject a mismatched key")


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

func test_sign_rejects_empty_key() -> void:
	var header: Dictionary = _fresh_header()
	var ok: bool = IntegritySigner.sign(
			header, _fresh_body(), PackedByteArray())
	assert_false(ok, "sign with empty key must fail")


func test_verify_rejects_empty_key() -> void:
	var header: Dictionary = _fresh_header()
	IntegritySigner.sign(header, _fresh_body(), _key_a())
	assert_false(IntegritySigner.verify(
			header, _fresh_body(), PackedByteArray()),
			"verify with empty key must fail")


func test_verify_rejects_unsigned_header() -> void:
	assert_false(IntegritySigner.verify(
			_fresh_header(), _fresh_body(), _key_a()),
			"verify must fail when no signature is present")


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

func test_sign_is_deterministic_for_same_inputs() -> void:
	var h1: Dictionary = _fresh_header()
	var h2: Dictionary = _fresh_header()
	IntegritySigner.sign(h1, _fresh_body(), _key_a())
	IntegritySigner.sign(h2, _fresh_body(), _key_a())
	assert_eq(h1[IntegritySigner.SIGNATURE_FIELD],
			h2[IntegritySigner.SIGNATURE_FIELD],
			"Same inputs must produce the same signature")


func test_constant_time_compare_handles_lengths() -> void:
	assert_true(IntegritySigner.constant_time_compare("abc", "abc"))
	assert_false(IntegritySigner.constant_time_compare("abc", "abcd"))
	assert_false(IntegritySigner.constant_time_compare("abc", "abd"))
