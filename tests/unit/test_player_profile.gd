## Unit tests for PlayerProfile autoload.
## Tests UUID generation, display name management, and persistence.
##
## G4 Network Plan: §3 — G4.1.9 tests
extends GutTest


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

func test_default_display_name_is_not_empty() -> void:
	assert_ne(PlayerProfile.DEFAULT_DISPLAY_NAME, "",
			"Default display name should not be empty.")


func test_settings_path_is_user_dir() -> void:
	assert_true(PlayerProfile.SETTINGS_PATH.begins_with("user://"),
			"Settings path should be in user:// directory.")


func test_section_name_is_player() -> void:
	assert_eq(PlayerProfile.SECTION, "player",
			"Config section should be 'player'.")


# ---------------------------------------------------------------------------
# Client ID
# ---------------------------------------------------------------------------

func test_client_id_is_not_empty() -> void:
	assert_ne(PlayerProfile.client_id, "",
			"Client ID should be generated on _ready().")


func test_client_id_is_uuid_format() -> void:
	# UUID v4 format: 8-4-4-4-12 hex chars.
	var parts: PackedStringArray = PlayerProfile.client_id.split("-")
	assert_eq(parts.size(), 5, "UUID should have 5 dash-separated groups.")
	assert_eq(parts[0].length(), 8, "UUID group 1 should be 8 chars.")
	assert_eq(parts[1].length(), 4, "UUID group 2 should be 4 chars.")
	assert_eq(parts[2].length(), 4, "UUID group 3 should be 4 chars.")
	assert_eq(parts[3].length(), 4, "UUID group 4 should be 4 chars.")
	assert_eq(parts[4].length(), 12, "UUID group 5 should be 12 chars.")


func test_client_id_version_nibble_is_4() -> void:
	# The 13th hex char (first char of group 3) should be '4' for UUID v4.
	var parts: PackedStringArray = PlayerProfile.client_id.split("-")
	assert_eq(parts[2][0], "4",
			"UUID version nibble should be '4'.")


func test_client_id_variant_nibble_is_valid() -> void:
	# The 17th hex char (first char of group 4) should be 8, 9, a, or b.
	var parts: PackedStringArray = PlayerProfile.client_id.split("-")
	var variant_char: String = parts[3][0]
	assert_true(variant_char in ["8", "9", "a", "b"],
			"UUID variant nibble '%s' should be 8/9/a/b." % variant_char)


func test_get_client_id_returns_same_as_property() -> void:
	assert_eq(PlayerProfile.get_client_id(), PlayerProfile.client_id,
			"get_client_id() should return the client_id property.")


# ---------------------------------------------------------------------------
# Display name
# ---------------------------------------------------------------------------

func test_get_display_name_returns_current_name() -> void:
	assert_eq(PlayerProfile.get_display_name(), PlayerProfile.display_name,
			"get_display_name() should return the display_name property.")


func test_set_display_name_updates_name() -> void:
	var original: String = PlayerProfile.display_name
	PlayerProfile.set_display_name("TestName")
	assert_eq(PlayerProfile.display_name, "TestName",
			"Display name should be updated.")
	# Restore.
	PlayerProfile.set_display_name(original)


func test_set_display_name_strips_whitespace() -> void:
	var original: String = PlayerProfile.display_name
	PlayerProfile.set_display_name("  Padded  ")
	assert_eq(PlayerProfile.display_name, "Padded",
			"Display name should have leading/trailing whitespace stripped.")
	# Restore.
	PlayerProfile.set_display_name(original)


func test_set_display_name_truncates_to_32_chars() -> void:
	var original: String = PlayerProfile.display_name
	var long_name: String = "A".repeat(50)
	PlayerProfile.set_display_name(long_name)
	assert_eq(PlayerProfile.display_name.length(), 32,
			"Display name should be truncated to 32 characters.")
	# Restore.
	PlayerProfile.set_display_name(original)


func test_set_display_name_empty_uses_default() -> void:
	var original: String = PlayerProfile.display_name
	PlayerProfile.set_display_name("")
	assert_eq(PlayerProfile.display_name, PlayerProfile.DEFAULT_DISPLAY_NAME,
			"Empty display name should fallback to default.")
	# Restore.
	PlayerProfile.set_display_name(original)


func test_set_display_name_whitespace_only_uses_default() -> void:
	var original: String = PlayerProfile.display_name
	PlayerProfile.set_display_name("   ")
	assert_eq(PlayerProfile.display_name, PlayerProfile.DEFAULT_DISPLAY_NAME,
			"Whitespace-only display name should fallback to default.")
	# Restore.
	PlayerProfile.set_display_name(original)


# ---------------------------------------------------------------------------
# UUID generation (internal)
# ---------------------------------------------------------------------------

func test_generate_uuid_v4_returns_valid_format() -> void:
	var uuid: String = PlayerProfile._generate_uuid_v4()
	var parts: PackedStringArray = uuid.split("-")
	assert_eq(parts.size(), 5, "Generated UUID should have 5 groups.")
	assert_eq(uuid.length(), 36, "UUID should be 36 chars (with dashes).")


func test_generate_uuid_v4_is_unique() -> void:
	var uuid1: String = PlayerProfile._generate_uuid_v4()
	var uuid2: String = PlayerProfile._generate_uuid_v4()
	assert_ne(uuid1, uuid2,
			"Two generated UUIDs should be different.")


func test_generate_uuid_v4_version_nibble() -> void:
	var uuid: String = PlayerProfile._generate_uuid_v4()
	var parts: PackedStringArray = uuid.split("-")
	assert_eq(parts[2][0], "4",
			"Generated UUID version nibble should be '4'.")


func test_generate_uuid_v4_variant_nibble() -> void:
	var uuid: String = PlayerProfile._generate_uuid_v4()
	var parts: PackedStringArray = uuid.split("-")
	var variant_char: String = parts[3][0]
	assert_true(variant_char in ["8", "9", "a", "b"],
			"Generated UUID variant nibble '%s' should be 8/9/a/b." % variant_char)
