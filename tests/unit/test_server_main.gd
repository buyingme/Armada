## Tests for G4.10 — Dedicated Server Binary.
##
## Covers:
##   - ServerMain (src/autoload/server_main.gd) — server detection, CLI
##     parsing, environment configuration, graceful shutdown.
##   - GameReplay HMAC signing (src/core/game_replay.gd) — sign, verify,
##     tamper detection, constant-time comparison.
##
## Architecture: ServerMain is an autoload (Node), so we test its methods
## directly.  HMAC tests use GameReplay (RefCounted) with test keys.
extends GutTest


# ======================================================================
# Constants
# ======================================================================

## A deterministic test key for HMAC signing (32 bytes).
var TEST_KEY: PackedByteArray = PackedByteArray([
	0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
	0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10,
	0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
	0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20,
])

## A different key to test wrong-key rejection.
var WRONG_KEY: PackedByteArray = PackedByteArray([
	0xFF, 0xFE, 0xFD, 0xFC, 0xFB, 0xFA, 0xF9, 0xF8,
	0xF7, 0xF6, 0xF5, 0xF4, 0xF3, 0xF2, 0xF1, 0xF0,
	0xEF, 0xEE, 0xED, 0xEC, 0xEB, 0xEA, 0xE9, 0xE8,
	0xE7, 0xE6, 0xE5, 0xE4, 0xE3, 0xE2, 0xE1, 0xE0,
])


# ======================================================================
# Helpers
# ======================================================================

## Creates a minimal GameReplay with populated header and sample commands.
func _make_replay(cmd_count: int = 3) -> GameReplay:
	var replay := GameReplay.new()
	replay.capture_header("learning_scenario", 42,
			[Constants.Faction.REBEL_ALLIANCE,
			Constants.Faction.GALACTIC_EMPIRE], 0)
	var cmds: Array[Dictionary] = []
	for i: int in range(cmd_count):
		cmds.append({
			"type": "assign_dials",
			"player": i % 2,
			"sequence": i,
			"payload": {"ship_index": 0, "commands": [0]},
		})
	replay.set_commands(cmds)
	return replay


# ======================================================================
# ServerMain — server mode detection
# ======================================================================

func test_server_main_exists_as_autoload() -> void:
	assert_not_null(ServerMain,
			"ServerMain autoload should be available.")


func test_server_main_not_server_by_default() -> void:
	# In the test environment we don't pass --server, so it should be false.
	# (The autoload's _ready() already ran; is_server reflects CLI state.)
	assert_false(ServerMain.is_server,
			"ServerMain should not be in server mode during tests.")


func test_server_main_default_port() -> void:
	assert_eq(ServerMain.port, ServerMain.DEFAULT_PORT,
			"Default port should be %d." % ServerMain.DEFAULT_PORT)


func test_server_main_default_scenario_empty() -> void:
	assert_eq(ServerMain.scenario_id, "",
			"Default scenario_id should be empty.")


func test_detect_server_mode_returns_false_without_flag() -> void:
	# _detect_server_mode is tested indirectly via is_server.
	# Without --server or dedicated_server feature, it should be false.
	assert_false(ServerMain.is_server,
			"Should not detect server mode without CLI flag or feature tag.")


# ======================================================================
# ServerMain — constants
# ======================================================================

func test_shutdown_timeout_is_positive() -> void:
	assert_gt(ServerMain.SHUTDOWN_TIMEOUT_SEC, 0.0,
			"Shutdown timeout must be positive.")


func test_default_port_in_valid_range() -> void:
	assert_gt(ServerMain.DEFAULT_PORT, 1023,
			"Default port should be above reserved range.")
	assert_lt(ServerMain.DEFAULT_PORT, 65536,
			"Default port should be within valid TCP/UDP range.")


# ======================================================================
# HMAC Replay Signing — sign_replay
# ======================================================================

func test_sign_replay_adds_hmac_to_header() -> void:
	var replay := _make_replay()
	var success: bool = replay.sign_replay(TEST_KEY)
	assert_true(success, "sign_replay should return true with valid key.")
	assert_true(replay.header.has("hmac"),
			"Header should contain 'hmac' field after signing.")
	assert_true(replay.header["hmac"] is String,
			"HMAC should be a string.")
	assert_gt((replay.header["hmac"] as String).length(), 0,
			"HMAC should not be empty.")


func test_sign_replay_updates_format_version() -> void:
	var replay := _make_replay()
	replay.sign_replay(TEST_KEY)
	assert_eq(replay.header["format_version"],
			GameReplay.SIGNED_FORMAT_VERSION,
			"Signing should update format_version to SIGNED_FORMAT_VERSION.")


func test_sign_replay_empty_key_returns_false() -> void:
	var replay := _make_replay()
	var empty_key := PackedByteArray()
	var success: bool = replay.sign_replay(empty_key)
	assert_false(success,
			"sign_replay should return false with empty key.")
	assert_false(replay.header.has("hmac"),
			"Header should not have 'hmac' after failed signing.")


func test_sign_replay_hmac_is_hex_encoded() -> void:
	var replay := _make_replay()
	replay.sign_replay(TEST_KEY)
	var hmac_str: String = replay.header["hmac"] as String
	# SHA-256 produces 32 bytes → 64 hex characters.
	assert_eq(hmac_str.length(), 64,
			"HMAC-SHA256 hex digest should be 64 characters.")
	# All characters should be valid hex.
	var hex_valid: bool = true
	for c: String in hmac_str:
		if not "0123456789abcdef".contains(c):
			hex_valid = false
			break
	assert_true(hex_valid,
			"HMAC should only contain lowercase hex characters.")


func test_sign_replay_deterministic() -> void:
	var replay_a := _make_replay()
	var replay_b := _make_replay()
	replay_a.sign_replay(TEST_KEY)
	replay_b.sign_replay(TEST_KEY)
	assert_eq(replay_a.header["hmac"], replay_b.header["hmac"],
			"Same content + same key should produce identical HMAC.")


func test_sign_replay_different_keys_produce_different_hmac() -> void:
	var replay_a := _make_replay()
	var replay_b := _make_replay()
	replay_a.sign_replay(TEST_KEY)
	replay_b.sign_replay(WRONG_KEY)
	assert_ne(replay_a.header["hmac"], replay_b.header["hmac"],
			"Different keys should produce different HMACs.")


# ======================================================================
# HMAC Replay Signing — verify_signature
# ======================================================================

func test_verify_signature_valid() -> void:
	var replay := _make_replay()
	replay.sign_replay(TEST_KEY)
	var valid: bool = replay.verify_signature(TEST_KEY)
	assert_true(valid,
			"Signature should verify with the correct key.")


func test_verify_signature_wrong_key() -> void:
	var replay := _make_replay()
	replay.sign_replay(TEST_KEY)
	var valid: bool = replay.verify_signature(WRONG_KEY)
	assert_false(valid,
			"Signature should not verify with the wrong key.")


func test_verify_signature_no_signature() -> void:
	var replay := _make_replay()
	# Not signed — verify should return false.
	var valid: bool = replay.verify_signature(TEST_KEY)
	assert_false(valid,
			"Unsigned replay should fail verification.")


func test_verify_signature_empty_key() -> void:
	var replay := _make_replay()
	replay.sign_replay(TEST_KEY)
	var valid: bool = replay.verify_signature(PackedByteArray())
	assert_false(valid,
			"Empty key should fail verification.")


func test_verify_signature_tampered_command() -> void:
	var replay := _make_replay()
	replay.sign_replay(TEST_KEY)
	# Tamper with a command.
	replay.commands[0]["player"] = 99
	var valid: bool = replay.verify_signature(TEST_KEY)
	assert_false(valid,
			"Tampered command should fail signature verification.")


func test_verify_signature_tampered_header() -> void:
	var replay := _make_replay()
	replay.sign_replay(TEST_KEY)
	# Tamper with header field (not the HMAC itself).
	replay.header["rng_seed"] = 999999
	var valid: bool = replay.verify_signature(TEST_KEY)
	assert_false(valid,
			"Tampered header should fail signature verification.")


func test_verify_signature_tampered_hmac() -> void:
	var replay := _make_replay()
	replay.sign_replay(TEST_KEY)
	# Directly tamper with the HMAC string.
	replay.header["hmac"] = "0".repeat(64)
	var valid: bool = replay.verify_signature(TEST_KEY)
	assert_false(valid,
			"Tampered HMAC should fail verification.")


# ======================================================================
# HMAC Replay Signing — is_signed
# ======================================================================

func test_is_signed_false_when_unsigned() -> void:
	var replay := _make_replay()
	assert_false(replay.is_signed(),
			"Unsigned replay should return false for is_signed().")


func test_is_signed_true_after_signing() -> void:
	var replay := _make_replay()
	replay.sign_replay(TEST_KEY)
	assert_true(replay.is_signed(),
			"Signed replay should return true for is_signed().")


func test_is_signed_false_if_hmac_empty_string() -> void:
	var replay := _make_replay()
	replay.header["hmac"] = ""
	assert_false(replay.is_signed(),
			"Empty HMAC string should return false for is_signed().")


# ======================================================================
# HMAC — file roundtrip (sign → save → load → verify)
# ======================================================================

func test_signed_replay_survives_file_roundtrip() -> void:
	var replay := _make_replay()
	replay.sign_replay(TEST_KEY)
	var path: String = "res://tests/fixtures/test_signed_replay.json"
	var err: Error = replay.save_to_file(path)
	assert_eq(err, OK, "Signed replay should save successfully.")
	var loaded: GameReplay = GameReplay.load_from_file(path)
	assert_not_null(loaded, "Should load signed replay from file.")
	assert_true(loaded.is_signed(),
			"Loaded replay should still be signed.")
	assert_true(loaded.verify_signature(TEST_KEY),
			"Loaded replay signature should verify correctly.")
	# Cleanup.
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# ======================================================================
# HMAC — constant-time comparison
# ======================================================================

func test_constant_time_compare_equal_strings() -> void:
	var result: bool = GameReplay._constant_time_compare("abcdef", "abcdef")
	assert_true(result,
			"Identical strings should compare equal.")


func test_constant_time_compare_different_strings() -> void:
	var result: bool = GameReplay._constant_time_compare("abcdef", "abcdeg")
	assert_false(result,
			"Different strings should compare not-equal.")


func test_constant_time_compare_different_lengths() -> void:
	var result: bool = GameReplay._constant_time_compare("abc", "abcd")
	assert_false(result,
			"Strings of different lengths should compare not-equal.")


func test_constant_time_compare_empty_strings() -> void:
	var result: bool = GameReplay._constant_time_compare("", "")
	assert_true(result,
			"Two empty strings should compare equal.")


# ======================================================================
# HMAC — compute_hmac_sha256 basic sanity
# ======================================================================

func test_compute_hmac_sha256_returns_64_hex_chars() -> void:
	var result: String = GameReplay._compute_hmac_sha256(
			TEST_KEY, "test message")
	assert_eq(result.length(), 64,
			"HMAC-SHA256 should produce a 64-character hex string.")


func test_compute_hmac_sha256_different_messages() -> void:
	var a: String = GameReplay._compute_hmac_sha256(TEST_KEY, "message A")
	var b: String = GameReplay._compute_hmac_sha256(TEST_KEY, "message B")
	assert_ne(a, b,
			"Different messages should produce different digests.")


func test_compute_hmac_sha256_same_message_deterministic() -> void:
	var a: String = GameReplay._compute_hmac_sha256(TEST_KEY, "same")
	var b: String = GameReplay._compute_hmac_sha256(TEST_KEY, "same")
	assert_eq(a, b,
			"Same key + same message should produce identical digest.")
