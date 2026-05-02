## IntegritySigner
##
## Shared HMAC-SHA256 signing/verification helper used by both replay
## files (G4.10.5) and save-game files (Phase J1).  Provides a canonical
## JSON payload builder so different callers produce a deterministic
## digest from a [Dictionary] (header + body) regardless of map iteration
## order or int/float number representation.
##
## Design:
##   - Static-only API; no instance state.
##   - The signature field is always called [code]"hmac"[/code] and lives
##     in the supplied [code]header[/code] dictionary.
##   - The payload covered by the signature is the canonical JSON of
##     [code]{"header": header_without_hmac, "body": body}[/code].
##   - Number normalisation: payload is round-tripped through Godot's
##     [JSON] parser so int/float distinctions do not affect the digest
##     across save/load cycles.
##   - Constant-time comparison protects against timing side-channels.
##
## Rules Reference: G4.10.5 — replay file integrity.
class_name IntegritySigner
extends RefCounted


## Hash algorithm identifier used by [HMACContext].
const HASH_TYPE: int = HashingContext.HASH_SHA256

## Header field name where the digest is stored.
const SIGNATURE_FIELD: String = "hmac"


## Computes the HMAC-SHA256 over the canonical JSON of
## [code]{"header": header_without_hmac, "body": body}[/code] and stores
## the hex digest in [code]header[SIGNATURE_FIELD][/code].
## [param header] — mutable header dictionary; receives the signature.
## [param body] — body dictionary or array covered by the signature.
## [param secret_key] — raw signing key bytes.
## Returns [code]true[/code] on success, [code]false[/code] if the key
## is empty or the HMAC computation fails.
static func sign(
		header: Dictionary,
		body: Variant,
		secret_key: PackedByteArray) -> bool:
	if secret_key.is_empty():
		return false
	var payload: String = build_signing_payload(header, body)
	var hex: String = compute_hmac(secret_key, payload)
	if hex.is_empty():
		return false
	header[SIGNATURE_FIELD] = hex
	return true


## Verifies the signature stored in [code]header[SIGNATURE_FIELD][/code]
## against the canonical payload of [code]{header_without_hmac, body}[/code].
## [param header] — header dictionary containing the signature.
## [param body] — the body that was signed.
## [param secret_key] — the same key used to sign.
## Returns [code]true[/code] iff the signature is present and matches.
## Constant-time comparison is used to prevent timing attacks.
static func verify(
		header: Dictionary,
		body: Variant,
		secret_key: PackedByteArray) -> bool:
	if secret_key.is_empty():
		return false
	var stored: String = header.get(SIGNATURE_FIELD, "") as String
	if stored.is_empty():
		return false
	var payload: String = build_signing_payload(header, body)
	var expected: String = compute_hmac(secret_key, payload)
	if expected.is_empty():
		return false
	return constant_time_compare(stored, expected)


## Returns [code]true[/code] iff the header carries a non-empty signature
## (without verifying it).  Use [method verify] for actual validation.
static func is_signed(header: Dictionary) -> bool:
	return header.has(SIGNATURE_FIELD) and header.get(SIGNATURE_FIELD, "") != ""


## Builds the canonical signing payload string.  The signature field is
## stripped from the header copy so the digest does not cover itself.
## The payload is round-tripped through [JSON] to normalise number
## representation across save/load cycles (Godot's parser converts all
## numbers to float).
static func build_signing_payload(
		header: Dictionary, body: Variant) -> String:
	var header_copy: Dictionary = header.duplicate()
	header_copy.erase(SIGNATURE_FIELD)
	var payload: Dictionary = {
		"header": header_copy,
		"body": body,
	}
	# Sort keys (third arg) for deterministic ordering, then round-trip
	# through JSON to normalise int/float representation.
	var raw: String = JSON.stringify(payload, "", true)
	var json: JSON = JSON.new()
	json.parse(raw)
	return JSON.stringify(json.data, "", true)


## Computes HMAC-SHA256 over [param message] using [param key].
## Returns the lowercase hex digest, or [code]""[/code] on failure.
static func compute_hmac(
		key: PackedByteArray, message: String) -> String:
	var ctx: HMACContext = HMACContext.new()
	var err: Error = ctx.start(HASH_TYPE, key)
	if err != OK:
		return ""
	err = ctx.update(message.to_utf8_buffer())
	if err != OK:
		return ""
	var digest: PackedByteArray = ctx.finish()
	return digest.hex_encode()


## Constant-time string comparison.  Both strings must be the same
## length for a valid comparison; differing lengths return
## [code]false[/code] immediately (length is not secret).
static func constant_time_compare(a: String, b: String) -> bool:
	if a.length() != b.length():
		return false
	var result: int = 0
	for i: int in range(a.length()):
		result |= a.unicode_at(i) ^ b.unicode_at(i)
	return result == 0
