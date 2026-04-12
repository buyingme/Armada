## Tests for GameCommand base class.
extends GutTest


# ------------------------------------------------------------------
# Construction
# ------------------------------------------------------------------

func test_init_stores_fields() -> void:
	var cmd := GameCommand.new(1, "test_type", {"key": "val"})
	assert_eq(cmd.player_index, 1, "player_index should be 1.")
	assert_eq(cmd.command_type, "test_type",
			"command_type should be 'test_type'.")
	assert_eq(cmd.payload["key"], "val", "payload should contain 'key'.")
	assert_eq(cmd.sequence, -1, "sequence should default to -1.")


func test_default_init() -> void:
	var cmd := GameCommand.new()
	assert_eq(cmd.player_index, 0, "Default player_index should be 0.")
	assert_eq(cmd.command_type, "", "Default command_type should be ''.")
	assert_true(cmd.payload.is_empty(), "Default payload should be empty.")


# ------------------------------------------------------------------
# Serialization
# ------------------------------------------------------------------

func test_serialize_contains_expected_keys() -> void:
	var cmd := GameCommand.new(0, "roll_dice", {"pool": {"red": 2}})
	cmd.sequence = 5
	var data: Dictionary = cmd.serialize()
	assert_eq(data["type"], "roll_dice", "Serialized type should match.")
	assert_eq(data["player"], 0, "Serialized player should match.")
	assert_eq(data["sequence"], 5, "Serialized sequence should match.")
	assert_true(data.has("payload"), "Serialized data should have payload.")


func test_serialize_roundtrip_with_registry() -> void:
	# Register a test factory.
	GameCommand.register_type("_test_rt", func(p: int,
			pl: Dictionary) -> GameCommand:
		return GameCommand.new(p, "_test_rt", pl))
	var cmd := GameCommand.new(1, "_test_rt", {"x": 42})
	cmd.sequence = 10
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Deserialized command should not be null.")
	assert_eq(restored.command_type, "_test_rt",
			"Restored type should match.")
	assert_eq(restored.player_index, 1,
			"Restored player should match.")
	assert_eq(restored.sequence, 10,
			"Restored sequence should match.")
	assert_eq(restored.payload.get("x", 0), 42,
			"Restored payload should match.")
	# Cleanup registry.
	GameCommand._registry.erase("_test_rt")


func test_deserialize_unknown_type_returns_null() -> void:
	var data := {"type": "_unknown_xyz", "player": 0, "payload": {}}
	var cmd: GameCommand = GameCommand.deserialize(data)
	assert_null(cmd, "Unknown type should return null.")
	# push_warning from _create_by_type — mark it handled.
	assert_engine_error(1,
			"Should warn about unknown type.")


# ------------------------------------------------------------------
# Validate
# ------------------------------------------------------------------

func test_validate_null_state_returns_error() -> void:
	var cmd := GameCommand.new()
	var reason: String = cmd.validate(null)
	assert_ne(reason, "", "Validate with null state should return error.")


func test_validate_valid_state_returns_empty() -> void:
	var cmd := GameCommand.new()
	var state := GameState.new()
	state.initialize()
	var reason: String = cmd.validate(state)
	assert_eq(reason, "", "Validate with valid state should return ''.")


# ------------------------------------------------------------------
# Describe
# ------------------------------------------------------------------

func test_describe_format() -> void:
	var cmd := GameCommand.new(1, "roll_dice")
	cmd.sequence = 7
	var desc: String = cmd.describe()
	assert_string_contains(desc, "roll_dice",
			"Describe should contain command type.")
	assert_string_contains(desc, "7",
			"Describe should contain sequence number.")


# ------------------------------------------------------------------
# Registry
# ------------------------------------------------------------------

func test_register_and_create() -> void:
	GameCommand.register_type("_test_reg", func(p: int,
			pl: Dictionary) -> GameCommand:
		return GameCommand.new(p, "_test_reg", pl))
	var cmd: GameCommand = GameCommand._create_by_type(
			"_test_reg", 0, {"a": 1})
	assert_not_null(cmd, "Registered type should create a command.")
	assert_eq(cmd.command_type, "_test_reg",
			"Created command should have correct type.")
	# Cleanup.
	GameCommand._registry.erase("_test_reg")


func test_create_unregistered_returns_null() -> void:
	var cmd: GameCommand = GameCommand._create_by_type(
			"_no_such_type", 0, {})
	assert_null(cmd, "Unregistered type should return null.")
	# push_warning from _create_by_type — mark it handled.
	assert_engine_error(1,
			"Should warn about unregistered type.")
