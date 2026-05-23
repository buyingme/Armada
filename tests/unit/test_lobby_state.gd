## Tests for [LobbyState].
##
## Verifies lobby code generation, player management, readiness
## tracking, serialization, and input sanitization.
extends GutTest


# ---------------------------------------------------------------------------
# Code generation (G4.5.7)
# ---------------------------------------------------------------------------

func test_generate_code_returns_correct_length() -> void:
	var code: String = LobbyState.generate_code()
	assert_eq(code.length(), LobbyState.CODE_LENGTH,
			"Code should be %d characters." % LobbyState.CODE_LENGTH)


func test_generate_code_uses_only_valid_chars() -> void:
	for attempt: int in range(20):
		var code: String = LobbyState.generate_code()
		for i: int in range(code.length()):
			assert_true(LobbyState.CODE_CHARS.contains(code[i]),
					"Char '%s' should be in CODE_CHARS." % code[i])


func test_generate_code_produces_different_codes() -> void:
	var codes: Dictionary = {}
	for attempt: int in range(50):
		codes[LobbyState.generate_code()] = true
	assert_gt(codes.size(), 1,
			"50 generated codes should not all be identical.")


# ---------------------------------------------------------------------------
# Player management
# ---------------------------------------------------------------------------

func test_add_player_to_empty_lobby() -> void:
	var lobby: LobbyState = LobbyState.new()
	var result: bool = lobby.add_player(10, "Alice", 0)
	assert_true(result, "Should add player to empty lobby.")
	assert_eq(lobby.get_player_count(), 1, "Should have 1 player.")


func test_add_player_sets_correct_fields() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	var player: Dictionary = lobby.get_player(10)
	assert_eq(player["peer_id"], 10, "Peer ID should match.")
	assert_eq(player["display_name"], "Alice", "Name should match.")
	assert_eq(player["player_index"], 0, "Index should match.")
	assert_false(player["ready"], "Should not be ready initially.")
	assert_eq(player["faction"], "", "Faction should be empty initially.")


func test_add_player_rejects_when_full() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	lobby.add_player(20, "Bob", 1)
	var result: bool = lobby.add_player(30, "Charlie", 2)
	assert_false(result, "Should reject 3rd player.")
	assert_eq(lobby.get_player_count(), 2, "Should still have 2 players.")


func test_add_player_rejects_duplicate_peer() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	var result: bool = lobby.add_player(10, "Alice2", 1)
	assert_false(result, "Should reject duplicate peer_id.")
	assert_eq(lobby.get_player_count(), 1, "Should still have 1 player.")


func test_remove_player_success() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	lobby.add_player(20, "Bob", 1)
	var result: bool = lobby.remove_player(10)
	assert_true(result, "Should remove existing player.")
	assert_eq(lobby.get_player_count(), 1, "Should have 1 player left.")
	assert_false(lobby.has_player(10), "Removed player should be gone.")


func test_remove_player_not_found() -> void:
	var lobby: LobbyState = LobbyState.new()
	var result: bool = lobby.remove_player(99)
	assert_false(result, "Should return false for unknown peer.")


func test_set_player_ready_success() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	var result: bool = lobby.set_player_ready(10, true)
	assert_true(result, "Should find and update player.")
	assert_true(lobby.get_player(10)["ready"], "Should be ready.")


func test_set_player_ready_toggle() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	lobby.set_player_ready(10, true)
	lobby.set_player_ready(10, false)
	assert_false(lobby.get_player(10)["ready"],
			"Should be not ready after toggling off.")


func test_set_player_ready_not_found() -> void:
	var lobby: LobbyState = LobbyState.new()
	var result: bool = lobby.set_player_ready(99, true)
	assert_false(result, "Should return false for unknown peer.")


# ---------------------------------------------------------------------------
# Readiness checks
# ---------------------------------------------------------------------------

func test_is_all_ready_empty_lobby() -> void:
	var lobby: LobbyState = LobbyState.new()
	assert_false(lobby.is_all_ready(),
			"Empty lobby should not be all ready.")


func test_is_all_ready_one_not_ready() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	lobby.add_player(20, "Bob", 1)
	lobby.set_player_ready(10, true)
	assert_false(lobby.is_all_ready(),
			"Should be false when one player is not ready.")


func test_is_all_ready_all_ready() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	lobby.add_player(20, "Bob", 1)
	lobby.set_player_ready(10, true)
	lobby.set_player_ready(20, true)
	assert_true(lobby.is_all_ready(),
			"Should be true when all players are ready.")


func test_can_start_not_enough_players() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	lobby.set_player_ready(10, true)
	assert_false(lobby.can_start(),
			"Cannot start with only 1 player.")


func test_can_start_not_all_ready() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	lobby.add_player(20, "Bob", 1)
	lobby.set_player_ready(10, true)
	assert_false(lobby.can_start(),
			"Cannot start when not all players are ready.")


func test_can_start_success() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	lobby.add_player(20, "Bob", 1)
	lobby.set_player_ready(10, true)
	lobby.set_player_ready(20, true)
	assert_true(lobby.can_start(),
			"Should be startable with 2 ready players.")


# ---------------------------------------------------------------------------
# Player queries
# ---------------------------------------------------------------------------

func test_get_player_found() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	var p: Dictionary = lobby.get_player(10)
	assert_eq(p["display_name"], "Alice", "Should return correct player.")


func test_get_player_not_found() -> void:
	var lobby: LobbyState = LobbyState.new()
	var p: Dictionary = lobby.get_player(99)
	assert_true(p.is_empty(), "Should return empty dict for unknown peer.")


func test_has_player_true() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	assert_true(lobby.has_player(10), "Should find existing player.")


func test_has_player_false() -> void:
	var lobby: LobbyState = LobbyState.new()
	assert_false(lobby.has_player(99), "Should not find unknown peer.")


func test_has_password_with_hash() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.password_hash = "abc123"
	assert_true(lobby.has_password(), "Should have password.")


func test_has_password_without_hash() -> void:
	var lobby: LobbyState = LobbyState.new()
	assert_false(lobby.has_password(), "Should not have password.")


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func test_serialize_roundtrip() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.lobby_id = "test-id"
	lobby.code = "ABC123"
	lobby.lobby_name = "Test Lobby"
	lobby.host_peer_id = 1
	lobby.scenario = LobbyState.SCENARIO_LEARNING_ID
	lobby.password_hash = "hash123"
	lobby.add_player(1, "Host", 0)
	lobby.add_player(10, "Guest", 1)
	lobby.set_player_ready(1, true)

	var data: Dictionary = lobby.serialize()
	var restored: LobbyState = LobbyState.deserialize(data)

	assert_eq(restored.lobby_id, "test-id", "lobby_id should roundtrip.")
	assert_eq(restored.code, "ABC123", "code should roundtrip.")
	assert_eq(restored.lobby_name, "Test Lobby", "lobby_name should roundtrip.")
	assert_eq(restored.host_peer_id, 1, "host_peer_id should roundtrip.")
	assert_eq(restored.scenario, LobbyState.SCENARIO_LEARNING_ID,
			"scenario should roundtrip.")
	assert_eq(restored.password_hash, "hash123",
			"password_hash should roundtrip.")
	assert_eq(restored.get_player_count(), 2,
			"Should have 2 players after roundtrip.")
	assert_true(restored.get_player(1)["ready"],
			"Host ready status should roundtrip.")
	assert_false(restored.get_player(10)["ready"],
			"Guest ready status should roundtrip.")


func test_serialize_is_deep_copy() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(1, "Host", 0)
	var data: Dictionary = lobby.serialize()
	# Mutate serialized data — original should not change
	data["players"][0]["display_name"] = "Mutated"
	assert_eq(lobby.get_player(1)["display_name"], "Host",
			"Serialized data should be a deep copy.")


func test_deserialize_missing_fields_uses_defaults() -> void:
	var data: Dictionary = {}
	var lobby: LobbyState = LobbyState.deserialize(data)
	assert_eq(lobby.lobby_id, "", "Missing lobby_id defaults to empty.")
	assert_eq(lobby.code, "", "Missing code defaults to empty.")
	assert_eq(lobby.lobby_name, "", "Missing lobby_name defaults to empty.")
	assert_eq(lobby.host_peer_id, 1, "Missing host_peer_id defaults to 1.")
	assert_eq(lobby.scenario, LobbyState.SCENARIO_LEARNING_ID,
			"Missing scenario defaults to learning scenario id.")
	assert_eq(lobby.get_player_count(), 0, "Missing players defaults to 0.")


func test_deserialize_ignores_non_dict_players() -> void:
	var data: Dictionary = {"players": [42, "not_a_dict", null]}
	var lobby: LobbyState = LobbyState.deserialize(data)
	assert_eq(lobby.get_player_count(), 0,
			"Non-dictionary player entries should be skipped.")


# ---------------------------------------------------------------------------
# Input sanitization (G4.5.11)
# ---------------------------------------------------------------------------

func test_sanitize_name_removes_control_chars() -> void:
	# char(1) = SOH, char(31) = US — both are control characters < 32.
	var dirty: String = "Hello" + char(1) + "World" + char(31) + "!"
	var clean: String = LobbyState.sanitize_name(dirty)
	assert_eq(clean, "HelloWorld!", "Control chars should be removed.")


func test_sanitize_name_clamps_length() -> void:
	var long_name: String = "A".repeat(50)
	var clean: String = LobbyState.sanitize_name(long_name)
	assert_eq(clean.length(), LobbyState.MAX_NAME_LENGTH,
			"Name should be clamped to MAX_NAME_LENGTH.")


func test_sanitize_name_strips_whitespace() -> void:
	var padded: String = "  Hello World  "
	var clean: String = LobbyState.sanitize_name(padded)
	assert_eq(clean, "Hello World",
			"Leading/trailing whitespace should be stripped.")


func test_sanitize_name_custom_max_length() -> void:
	var name: String = "LongName"
	var clean: String = LobbyState.sanitize_name(name, 4)
	assert_eq(clean, "Long",
			"Should respect custom max_length parameter.")


func test_sanitize_name_preserves_normal_text() -> void:
	var normal: String = "Player One"
	var clean: String = LobbyState.sanitize_name(normal)
	assert_eq(clean, "Player One",
			"Normal text should be preserved unchanged.")


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

func test_add_then_remove_then_add_again() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	lobby.remove_player(10)
	var result: bool = lobby.add_player(10, "Alice", 0)
	assert_true(result, "Should allow re-adding after removal.")
	assert_eq(lobby.get_player_count(), 1, "Should have 1 player.")


func test_ready_state_reset_on_rejoin() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(10, "Alice", 0)
	lobby.set_player_ready(10, true)
	lobby.remove_player(10)
	lobby.add_player(10, "Alice", 0)
	assert_false(lobby.get_player(10)["ready"],
			"Ready should be false after re-joining.")


# ---------------------------------------------------------------------------
# Scenario field
# ---------------------------------------------------------------------------

func test_scenario_defaults_to_learning() -> void:
	var lobby: LobbyState = LobbyState.new()
	assert_eq(lobby.scenario, LobbyState.SCENARIO_LEARNING_ID,
			"Scenario should default to the learning scenario id.")


func test_scenario_included_in_serialization() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.scenario = LobbyState.SCENARIO_DEBUG_ID
	var data: Dictionary = lobby.serialize()
	assert_eq(data["scenario"], LobbyState.SCENARIO_DEBUG_ID,
			"Serialized data should contain scenario.")
	var restored: LobbyState = LobbyState.deserialize(data)
	assert_eq(restored.scenario, LobbyState.SCENARIO_DEBUG_ID,
			"Deserialized lobby should have scenario.")


func test_deserialize_legacy_learning_scenario_label_uses_id() -> void:
	var lobby: LobbyState = LobbyState.deserialize({
		"scenario": LobbyState.SCENARIO_LEARNING_LABEL,
	})
	assert_eq(lobby.scenario, LobbyState.SCENARIO_LEARNING_ID,
			"Legacy learning labels should normalize to the scenario id.")


func test_normalize_scenario_debug_label_returns_id() -> void:
	assert_eq(LobbyState.normalize_scenario_id(
			LobbyState.SCENARIO_DEBUG_LABEL), LobbyState.SCENARIO_DEBUG_ID,
			"Debug Scenario label should normalize to debug_scenario.")


func test_scenario_options_include_debug_scenario() -> void:
	var options: Array[Dictionary] = LobbyState.get_scenario_options()
	var ids: Array[String] = []
	for option: Dictionary in options:
		ids.append(str(option.get("id", "")))
	assert_true(ids.has(LobbyState.SCENARIO_DEBUG_ID),
			"Lobby scenario options should include the debug scenario.")


# ---------------------------------------------------------------------------
# Password hash round-trip
# ---------------------------------------------------------------------------

func test_password_hash_sha256_round_trip() -> void:
	var lobby: LobbyState = LobbyState.new()
	var password: String = "secret123"
	lobby.password_hash = password.sha256_text()
	assert_true(lobby.has_password(),
			"Lobby with hash should report has_password.")
	# Verify same password produces same hash.
	assert_eq(password.sha256_text(), lobby.password_hash,
			"SHA-256 of same password should match.")
	# Wrong password should not match.
	assert_ne("wrong_password".sha256_text(), lobby.password_hash,
			"SHA-256 of different password should not match.")
