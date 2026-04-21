## Unit tests for NetworkInteractionState domain object.
## Covers: construction defaults, round-trip serialization, version comparisons,
## and deserialization forward-compatibility (missing keys use defaults).
##
## G4 Network Plan: §G4.6.6, T1a C1
extends GutTest


# ---------------------------------------------------------------------------
# Construction defaults
# ---------------------------------------------------------------------------

func test_new_flow_type_is_empty() -> void:
	# Arrange / Act
	var s: NetworkInteractionState = NetworkInteractionState.new()
	# Assert
	assert_eq(s.flow_type, "", "Default flow_type should be empty string.")


func test_new_step_id_is_empty() -> void:
	var s: NetworkInteractionState = NetworkInteractionState.new()
	assert_eq(s.step_id, "", "Default step_id should be empty string.")


func test_new_controller_player_is_minus_one() -> void:
	var s: NetworkInteractionState = NetworkInteractionState.new()
	assert_eq(s.controller_player, -1,
			"Default controller_player should be -1 (no player).")


func test_new_visible_to_is_all() -> void:
	var s: NetworkInteractionState = NetworkInteractionState.new()
	assert_eq(s.visible_to, "all", "Default visible_to should be 'all'.")


func test_new_payload_is_empty() -> void:
	var s: NetworkInteractionState = NetworkInteractionState.new()
	assert_eq(s.payload.size(), 0, "Default payload should be empty.")


func test_new_version_is_zero() -> void:
	var s: NetworkInteractionState = NetworkInteractionState.new()
	assert_eq(s.version, 0, "Default version should be 0.")


func test_new_ui_status_text_is_empty() -> void:
	var s: NetworkInteractionState = NetworkInteractionState.new()
	assert_eq(s.ui_status_text, "", "Default ui_status_text should be empty.")


# ---------------------------------------------------------------------------
# Round-trip serialization
# ---------------------------------------------------------------------------

func test_serialize_deserialize_round_trip_preserves_flow_type() -> void:
	# Arrange
	var s: NetworkInteractionState = NetworkInteractionState.new()
	s.flow_type = "ship_activation"
	# Act
	var restored: NetworkInteractionState = NetworkInteractionState.deserialize(s.serialize())
	# Assert
	assert_eq(restored.flow_type, "ship_activation",
			"flow_type must survive round-trip.")


func test_serialize_deserialize_round_trip_preserves_step_id() -> void:
	var s: NetworkInteractionState = NetworkInteractionState.new()
	s.step_id = "roll_dice"
	var restored: NetworkInteractionState = NetworkInteractionState.deserialize(s.serialize())
	assert_eq(restored.step_id, "roll_dice", "step_id must survive round-trip.")


func test_serialize_deserialize_round_trip_preserves_controller_player() -> void:
	var s: NetworkInteractionState = NetworkInteractionState.new()
	s.controller_player = 1
	var restored: NetworkInteractionState = NetworkInteractionState.deserialize(s.serialize())
	assert_eq(restored.controller_player, 1,
			"controller_player must survive round-trip.")


func test_serialize_deserialize_round_trip_preserves_visible_to() -> void:
	var s: NetworkInteractionState = NetworkInteractionState.new()
	s.visible_to = "owner_only"
	var restored: NetworkInteractionState = NetworkInteractionState.deserialize(s.serialize())
	assert_eq(restored.visible_to, "owner_only",
			"visible_to must survive round-trip.")


func test_serialize_deserialize_round_trip_preserves_version() -> void:
	var s: NetworkInteractionState = NetworkInteractionState.new()
	s.version = 42
	var restored: NetworkInteractionState = NetworkInteractionState.deserialize(s.serialize())
	assert_eq(restored.version, 42, "version must survive round-trip.")


func test_serialize_deserialize_round_trip_preserves_ui_status_text() -> void:
	var s: NetworkInteractionState = NetworkInteractionState.new()
	s.ui_status_text = "waiting for opponent's choice"
	var restored: NetworkInteractionState = NetworkInteractionState.deserialize(s.serialize())
	assert_eq(restored.ui_status_text, "waiting for opponent's choice",
			"ui_status_text must survive round-trip.")


func test_serialize_deserialize_round_trip_preserves_payload() -> void:
	# Arrange
	var s: NetworkInteractionState = NetworkInteractionState.new()
	s.payload = {"ship_id": "cr90a_1", "zone": 2}
	# Act
	var restored: NetworkInteractionState = NetworkInteractionState.deserialize(s.serialize())
	# Assert
	assert_eq(restored.payload.get("ship_id", ""), "cr90a_1",
			"payload ship_id must survive round-trip.")
	assert_eq(restored.payload.get("zone", -1), 2,
			"payload zone must survive round-trip.")


func test_serialize_produces_no_godot_types() -> void:
	# Arrange
	var s: NetworkInteractionState = NetworkInteractionState.new()
	s.flow_type = "attack"
	s.step_id = "defense_tokens"
	s.controller_player = 0
	s.version = 7
	s.payload = {"key": "value"}
	# Act
	var d: Dictionary = s.serialize()
	# Assert — all values must be plain JSON-safe types
	assert_true(d["flow_type"] is String, "flow_type must be String.")
	assert_true(d["step_id"] is String, "step_id must be String.")
	assert_true(d["controller_player"] is int, "controller_player must be int.")
	assert_true(d["visible_to"] is String, "visible_to must be String.")
	assert_true(d["payload"] is Dictionary, "payload must be Dictionary.")
	assert_true(d["version"] is int, "version must be int.")
	assert_true(d["ui_status_text"] is String, "ui_status_text must be String.")


# ---------------------------------------------------------------------------
# Forward-compatibility: missing keys use defaults
# ---------------------------------------------------------------------------

func test_deserialize_empty_dict_uses_defaults() -> void:
	# Arrange / Act
	var restored: NetworkInteractionState = NetworkInteractionState.deserialize({})
	# Assert
	assert_eq(restored.flow_type, "", "Empty dict: flow_type default is ''.")
	assert_eq(restored.step_id, "", "Empty dict: step_id default is ''.")
	assert_eq(restored.controller_player, -1,
			"Empty dict: controller_player default is -1.")
	assert_eq(restored.visible_to, "all", "Empty dict: visible_to default is 'all'.")
	assert_eq(restored.version, 0, "Empty dict: version default is 0.")
	assert_eq(restored.ui_status_text, "", "Empty dict: ui_status_text default is ''.")


func test_deserialize_partial_dict_preserves_supplied_fields() -> void:
	var d: Dictionary = {"flow_type": "displacement", "version": 3}
	var restored: NetworkInteractionState = NetworkInteractionState.deserialize(d)
	assert_eq(restored.flow_type, "displacement",
			"Supplied flow_type should be used.")
	assert_eq(restored.version, 3, "Supplied version should be used.")
	assert_eq(restored.controller_player, -1,
			"Missing controller_player falls back to -1.")


# ---------------------------------------------------------------------------
# Version comparison
# ---------------------------------------------------------------------------

func test_is_newer_than_returns_true_when_version_higher() -> void:
	# Arrange
	var newer: NetworkInteractionState = NetworkInteractionState.new()
	newer.version = 5
	var older: NetworkInteractionState = NetworkInteractionState.new()
	older.version = 3
	# Act / Assert
	assert_true(newer.is_newer_than(older),
			"version 5 should be newer than version 3.")


func test_is_newer_than_returns_false_when_version_equal() -> void:
	var a: NetworkInteractionState = NetworkInteractionState.new()
	a.version = 4
	var b: NetworkInteractionState = NetworkInteractionState.new()
	b.version = 4
	assert_false(a.is_newer_than(b),
			"Equal versions should not be considered newer.")


func test_is_newer_than_returns_false_when_version_lower() -> void:
	var older: NetworkInteractionState = NetworkInteractionState.new()
	older.version = 2
	var newer: NetworkInteractionState = NetworkInteractionState.new()
	newer.version = 6
	assert_false(older.is_newer_than(newer),
			"version 2 is not newer than version 6.")


func test_same_version_returns_true_for_equal_versions() -> void:
	var a: NetworkInteractionState = NetworkInteractionState.new()
	a.version = 10
	var b: NetworkInteractionState = NetworkInteractionState.new()
	b.version = 10
	assert_true(a.same_version(b), "Equal versions should report same_version true.")


func test_same_version_returns_false_for_different_versions() -> void:
	var a: NetworkInteractionState = NetworkInteractionState.new()
	a.version = 1
	var b: NetworkInteractionState = NetworkInteractionState.new()
	b.version = 2
	assert_false(a.same_version(b),
			"Different versions should report same_version false.")


func test_is_newer_than_version_zero_edge_case() -> void:
	var v0: NetworkInteractionState = NetworkInteractionState.new()
	v0.version = 0
	var v1: NetworkInteractionState = NetworkInteractionState.new()
	v1.version = 1
	assert_true(v1.is_newer_than(v0),
			"version 1 is newer than default version 0.")
	assert_false(v0.is_newer_than(v1),
			"version 0 is not newer than version 1.")


# ---------------------------------------------------------------------------
# Payload isolation (duplicate guard)
# ---------------------------------------------------------------------------

func test_serialize_payload_is_deep_copy() -> void:
	# Arrange
	var s: NetworkInteractionState = NetworkInteractionState.new()
	s.payload = {"ship_id": "original"}
	var d: Dictionary = s.serialize()
	# Act — mutate original
	s.payload["ship_id"] = "mutated"
	# Assert — serialized copy is unaffected
	assert_eq(d["payload"].get("ship_id", ""), "original",
			"Serialised payload must be independent of original after mutation.")


func test_deserialize_payload_is_deep_copy() -> void:
	# Arrange
	var d: Dictionary = {"payload": {"zone": 1}}
	var restored: NetworkInteractionState = NetworkInteractionState.deserialize(d)
	# Act — mutate source dict
	d["payload"]["zone"] = 99
	# Assert — deserialized copy is unaffected
	assert_eq(restored.payload.get("zone", -1), 1,
			"Deserialised payload must be independent of source after mutation.")
