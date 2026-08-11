## Test: SquadronInstance
##
## Unit tests for SquadronInstance — runtime squadron state.
## Rules Reference: SU-024–025.
extends GutTest


var _squad_data: SquadronData = null
var _instance: SquadronInstance = null


func before_each() -> void:
	_squad_data = SquadronData.new()
	_squad_data.squadron_name = "Test Squadron"
	_squad_data.hull = 3
	_squad_data.speed = 4
	_squad_data.defense_tokens = ["Brace", "Scatter"]
	_instance = SquadronInstance.create_from_data("test_squad", _squad_data, 1)


# --- Factory / Initialization ---

func test_create_from_data_sets_data_key() -> void:
	assert_eq(_instance.data_key, "test_squad",
			"data_key should match the key passed to factory")


func test_create_from_data_stores_data_ref() -> void:
	assert_eq(_instance.squadron_data, _squad_data,
			"squadron_data reference should be stored")


func test_create_from_data_hull_starts_at_max() -> void:
	assert_eq(_instance.current_hull, 3,
			"current_hull should start at max (3)")


func test_create_from_data_not_activated() -> void:
	assert_false(_instance.activated_this_round,
			"Should start unactivated (SU-025)")


func test_create_from_data_not_engaged() -> void:
	assert_false(_instance.is_engaged,
			"Should start not engaged")


func test_create_from_data_owner_player() -> void:
	assert_eq(_instance.owner_player, 1,
			"owner_player should match factory arg")


func test_create_from_data_defense_tokens() -> void:
	assert_eq(_instance.defense_tokens.size(), 2,
			"Should have 2 defense tokens")
	assert_eq(_instance.defense_tokens[0]["type"], Constants.DefenseToken.BRACE,
			"First token should be BRACE")
	assert_eq(_instance.defense_tokens[1]["type"], Constants.DefenseToken.SCATTER,
			"Second token should be SCATTER")


func test_create_from_data_defense_tokens_all_ready() -> void:
	for token: Dictionary in _instance.defense_tokens:
		assert_eq(token["state"], Constants.DefenseTokenState.READY,
				"All tokens should start READY")


func test_create_no_defense_tokens() -> void:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "Generic Squad"
	data.hull = 3
	data.speed = 3
	data.defense_tokens = []
	var inst: SquadronInstance = SquadronInstance.create_from_data(
			"generic", data, 0)
	assert_eq(inst.defense_tokens.size(), 0,
			"Generic squadron should have no defense tokens")


# --- Damage ---

func test_is_destroyed_false_initially() -> void:
	assert_false(_instance.is_destroyed(),
			"Squadron should not be destroyed initially")


func test_suffer_damage_reduces_hull() -> void:
	var dealt: int = _instance.suffer_damage(2)
	assert_eq(dealt, 2, "Should deal 2 damage")
	assert_eq(_instance.current_hull, 1, "Hull should be 1 after 2 damage")


func test_suffer_damage_clamped_to_hull() -> void:
	var dealt: int = _instance.suffer_damage(10)
	assert_eq(dealt, 3, "Should only deal up to current hull (3)")
	assert_eq(_instance.current_hull, 0, "Hull should be 0")


func test_is_destroyed_when_hull_zero() -> void:
	_instance.suffer_damage(3)
	assert_true(_instance.is_destroyed(),
			"Squadron should be destroyed at hull 0")


func test_mark_destroyed_sets_flag() -> void:
	_instance.mark_destroyed()
	assert_true(_instance.is_destroyed(),
			"Squadron should be destroyed after mark_destroyed()")


func test_mark_destroyed_persists_even_if_hull_restored() -> void:
	# Arrange — mark destroyed, then reset hull (hypothetical edge case).
	_instance.suffer_damage(3)
	_instance.mark_destroyed()
	_instance.current_hull = 3
	# Assert — must still report destroyed.
	assert_true(_instance.is_destroyed(),
			"Squadron must stay destroyed after mark_destroyed()")


# --- Defense Tokens ---

func test_get_active_token_count() -> void:
	assert_eq(_instance.get_active_token_count(), 2,
			"Both tokens should be active initially")


func test_ready_defense_tokens() -> void:
	_instance.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	_instance.ready_defense_tokens()
	assert_eq(_instance.defense_tokens[0]["state"],
			Constants.DefenseTokenState.READY,
			"EXHAUSTED tokens should become READY")


# --- Activation ---

func test_reset_activation() -> void:
	_instance.activated_this_round = true
	_instance.reset_activation()
	assert_false(_instance.activated_this_round,
			"Activation flag should be reset")


# --- TWI-003 Slice 1 owner-local action substrate ---

func test_activation_action_defaults_serialize_on_owner() -> void:
	assert_false(_instance.has_activation_action_state())
	assert_true(_instance.is_activation_action_state_valid())
	assert_false(_instance.has_remaining_move_action(false))
	assert_false(_instance.has_remaining_attack_action(false))
	assert_false(_instance.is_activation_action_complete(false))
	var serialized: Dictionary = _instance.serialize()
	for key: String in [
			"activation_id", "activation_context",
			"commanding_ship_player", "commanding_ship_index",
			"move_action_committed", "attack_action_disposition"]:
		assert_true(serialized.has(key),
				"Slice 2 must serialize owner field '%s'." % key)


func test_initialize_squadron_phase_action_state_has_stable_identity() -> void:
	assert_true(_instance.initialize_activation_action_state(
			"squadron-activation:10",
			SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE))
	assert_eq(_instance.activation_id, "squadron-activation:10")
	assert_eq(_instance.attack_action_disposition,
			SquadronInstance.ATTACK_ACTION_AVAILABLE)
	assert_eq(_instance.commanding_ship_player, -1)
	assert_eq(_instance.commanding_ship_index, -1)
	assert_true(_instance.is_activation_action_state_valid())

	assert_false(_instance.initialize_activation_action_state(
			"squadron-activation:11",
			SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE))
	assert_eq(_instance.activation_id, "squadron-activation:10",
			"Identity must remain stable until reset.")


func test_activation_context_requires_exact_commanding_ship_reference() -> void:
	assert_false(_instance.initialize_activation_action_state(
			"squadron-activation:10",
			SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND))
	assert_false(_instance.initialize_activation_action_state(
			"squadron-activation:10",
			SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE, 0, 1))
	assert_false(_instance.initialize_activation_action_state(
			"squadron-activation:10", "unsupported_context"))
	assert_true(_instance.initialize_activation_action_state(
			"squadron-activation:10",
			SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
			0, 2))
	assert_true(_instance.is_activation_action_state_valid())


func test_non_rogue_move_commits_once_and_completes_action_sequence() -> void:
	assert_true(_instance.initialize_activation_action_state(
			"squadron-activation:10",
			SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE))
	assert_true(_instance.has_remaining_move_action(false))
	assert_true(_instance.has_remaining_attack_action(false))
	assert_true(_instance.commit_move_action("squadron-activation:10", false))
	assert_false(_instance.commit_move_action("squadron-activation:10", false))
	assert_false(_instance.has_remaining_move_action(false))
	assert_false(_instance.has_remaining_attack_action(false))
	assert_true(_instance.is_activation_action_complete(false))
	assert_false(_instance.commit_attack_action_begun(
			"squadron-activation:10", false),
			"A non-Rogue attack must not become available after movement.")


func test_attack_disposition_commits_available_to_one_terminal_value() -> void:
	assert_true(_instance.initialize_activation_action_state(
			"squadron-activation:10",
			SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE))
	assert_true(_instance.commit_attack_action_begun(
			"squadron-activation:10", false))
	assert_eq(_instance.attack_action_disposition,
			SquadronInstance.ATTACK_ACTION_BEGUN)
	assert_false(_instance.commit_attack_action_declined(
			"squadron-activation:10", false))
	assert_false(_instance.commit_attack_action_begun(
			"squadron-activation:10", false))
	assert_true(_instance.is_activation_action_complete(false))


func test_rogue_actions_remain_independent_until_both_are_committed() -> void:
	assert_true(_instance.initialize_activation_action_state(
			"squadron-activation:10",
			SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE))
	assert_true(_instance.commit_attack_action_declined(
			"squadron-activation:10", true))
	assert_true(_instance.has_remaining_move_action(true))
	assert_false(_instance.is_activation_action_complete(true))
	assert_true(_instance.commit_move_action("squadron-activation:10", true))
	assert_true(_instance.is_activation_action_complete(true))


func test_commanded_squadron_actions_remain_independent() -> void:
	assert_true(_instance.initialize_activation_action_state(
			"squadron-activation:10",
			SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
			0, 2))
	assert_true(_instance.commit_move_action("squadron-activation:10", false))
	assert_true(_instance.has_remaining_attack_action(false))
	assert_true(_instance.commit_attack_action_declined(
			"squadron-activation:10", false))
	assert_true(_instance.is_activation_action_complete(false))


func test_activation_action_snapshot_restore_is_exact_and_owner_local() -> void:
	_instance.current_hull = 2
	_instance.is_engaged = true
	assert_true(_instance.initialize_activation_action_state(
			"squadron-activation:10",
			SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
			0, 2))
	assert_true(_instance.commit_move_action("squadron-activation:10", false))
	var snapshot: Dictionary = _instance.activation_action_state_snapshot()

	assert_true(_instance.commit_attack_action_declined(
			"squadron-activation:10", false))
	assert_true(_instance.restore_activation_action_state(snapshot))
	assert_eq(_instance.activation_action_state_snapshot(), snapshot)
	assert_eq(_instance.current_hull, 2)
	assert_true(_instance.is_engaged)


func test_activation_action_reset_clears_only_new_owner_fields() -> void:
	_instance.current_hull = 2
	assert_true(_instance.initialize_activation_action_state(
			"squadron-activation:10",
			SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE))
	assert_true(_instance.commit_attack_action_declined(
			"squadron-activation:10", false))
	_instance.activated_this_round = true

	_instance.reset_activation_action_state()
	assert_true(_instance.is_activation_action_state_valid())
	assert_false(_instance.has_activation_action_state())
	assert_eq(_instance.current_hull, 2)
	assert_true(_instance.activated_this_round,
			"Owner-local reset must not change unrelated activation facts.")


func test_activation_action_validation_rejects_partial_or_invalid_state() -> void:
	_instance.activation_id = "squadron-activation:10"
	assert_false(_instance.is_activation_action_state_valid())
	_instance.reset_activation_action_state()
	_instance.activation_context = \
			SquadronInstance.ACTIVATION_CONTEXT_SQUADRON_PHASE
	assert_false(_instance.is_activation_action_state_valid())
	_instance.reset_activation_action_state()
	_instance.move_action_committed = true
	assert_false(_instance.is_activation_action_state_valid())


# --- Serialization round-trip ---

func test_serialize_contains_expected_keys() -> void:
	var data: Dictionary = _instance.serialize()
	for key: String in ["data_key", "current_hull", "activated_this_round",
			"roster_entry_id", "fleet_points", "is_engaged", "owner_player",
			"pos_x", "pos_y", "rotation_deg", "destroyed", "defense_tokens"]:
		assert_true(data.has(key),
				"serialize() should include key '%s'" % key)


func test_deserialize_round_trip_basic_fields() -> void:
	_instance.suffer_damage(1)
	_instance.activated_this_round = true
	_instance.is_engaged = true
	_instance.roster_entry_id = "squadron-entry-1"
	_instance.fleet_points = 13
	var restored: SquadronInstance = SquadronInstance.deserialize(
			_instance.serialize(), _squad_data)
	assert_eq(restored.data_key, "test_squad",
			"Round-trip should preserve data_key")
	assert_eq(restored.current_hull, 2,
			"Round-trip should preserve current_hull")
	assert_true(restored.activated_this_round,
			"Round-trip should preserve activated_this_round")
	assert_true(restored.is_engaged,
			"Round-trip should preserve is_engaged")
	assert_eq(restored.owner_player, 1,
			"Round-trip should preserve owner_player")
	assert_eq(restored.roster_entry_id, "squadron-entry-1",
			"Round-trip should preserve roster_entry_id")
	assert_eq(restored.fleet_points, 13,
			"Round-trip should preserve fleet_points")


func test_deserialize_round_trip_position() -> void:
	_instance.pos_x = 0.421
	_instance.pos_y = 0.913
	_instance.rotation_deg = 0.0
	var restored: SquadronInstance = SquadronInstance.deserialize(
			_instance.serialize(), _squad_data)
	assert_almost_eq(restored.pos_x, 0.421, 0.001,
			"Round-trip should preserve pos_x")
	assert_almost_eq(restored.pos_y, 0.913, 0.001,
			"Round-trip should preserve pos_y")
	assert_almost_eq(restored.rotation_deg, 0.0, 0.01,
			"Round-trip should preserve rotation_deg")


func test_get_pixel_position() -> void:
	_instance.pos_x = 0.5
	_instance.pos_y = 0.25
	var px: Vector2 = _instance.get_pixel_position(Vector2(1000.0, 800.0))
	assert_almost_eq(px.x, 500.0, 0.01,
			"Pixel X should be pos_x * width_px")
	assert_almost_eq(px.y, 200.0, 0.01,
			"Pixel Y should be pos_y * height_px")


func test_get_rotation_rad() -> void:
	_instance.rotation_deg = 180.0
	assert_almost_eq(_instance.get_rotation_rad(), PI, 0.001,
			"get_rotation_rad should convert degrees to radians")


func test_deserialize_round_trip_defense_tokens() -> void:
	_instance.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	_instance.defense_tokens[1]["state"] = Constants.DefenseTokenState.DISCARDED
	var restored: SquadronInstance = SquadronInstance.deserialize(
			_instance.serialize(), _squad_data)
	assert_eq(restored.defense_tokens.size(), 2,
			"Round-trip should preserve token count")
	assert_eq(restored.defense_tokens[0]["state"],
			Constants.DefenseTokenState.EXHAUSTED,
			"Round-trip should preserve exhausted state")
	assert_eq(restored.defense_tokens[1]["state"],
			Constants.DefenseTokenState.DISCARDED,
			"Round-trip should preserve discarded state")


func test_deserialize_round_trip_destroyed_flag() -> void:
	_instance.mark_destroyed()
	var restored: SquadronInstance = SquadronInstance.deserialize(
			_instance.serialize(), _squad_data)
	assert_true(restored.is_destroyed(),
			"Round-trip should preserve destroyed flag")
