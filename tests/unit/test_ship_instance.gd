## Test: ShipInstance
##
## Unit tests for ShipInstance — runtime ship state.
## Rules Reference: SU-021–026, DM-001–003, DT-001–002, CP-001–007, CM-004–006.
extends GutTest


var _ship_data: ShipData = null
var _instance: ShipInstance = null


func before_each() -> void:
	_ship_data = ShipData.new()
	_ship_data.ship_name = "Test Ship"
	_ship_data.hull = 5
	_ship_data.max_speed = 3
	_ship_data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	_ship_data.defense_tokens = ["Evade", "Redirect", "Brace"]
	_instance = ShipInstance.create_from_data("test_ship", _ship_data, 2, 0)


# --- Factory / Initialization ---

func test_create_from_data_sets_data_key() -> void:
	assert_eq(_instance.data_key, "test_ship",
			"data_key should match the key passed to factory")


func test_create_from_data_stores_ship_data_ref() -> void:
	assert_eq(_instance.ship_data, _ship_data,
			"ship_data reference should be stored")


func test_create_from_data_hull_starts_at_max() -> void:
	assert_eq(_instance.current_hull, 5,
			"current_hull should start at max (5)")


func test_create_from_data_speed_uses_initial() -> void:
	assert_eq(_instance.current_speed, 2,
			"current_speed should be initial_speed (2), not max_speed")


func test_create_from_data_shields_at_max() -> void:
	assert_eq(int(_instance.current_shields["FRONT"]), 3,
			"FRONT shields should start at max (3)")
	assert_eq(int(_instance.current_shields["LEFT"]), 2,
			"LEFT shields should start at max (2)")
	assert_eq(int(_instance.current_shields["RIGHT"]), 2,
			"RIGHT shields should start at max (2)")
	assert_eq(int(_instance.current_shields["REAR"]), 1,
			"REAR shields should start at max (1)")


func test_create_from_data_defense_tokens_all_ready() -> void:
	assert_eq(_instance.defense_tokens.size(), 3,
			"Should have 3 defense tokens")
	for token: Dictionary in _instance.defense_tokens:
		assert_eq(token["state"], Constants.DefenseTokenState.READY,
				"All tokens should start READY (SU-026)")


func test_create_from_data_defense_token_types() -> void:
	assert_eq(_instance.defense_tokens[0]["type"], Constants.DefenseToken.EVADE,
			"First token should be EVADE")
	assert_eq(_instance.defense_tokens[1]["type"], Constants.DefenseToken.REDIRECT,
			"Second token should be REDIRECT")
	assert_eq(_instance.defense_tokens[2]["type"], Constants.DefenseToken.BRACE,
			"Third token should be BRACE")


func test_create_from_data_no_damage() -> void:
	assert_eq(_instance.facedown_damage.size(), 0,
			"Should start with no facedown damage")
	assert_eq(_instance.faceup_damage.size(), 0,
			"Should start with no faceup damage")


func test_create_from_data_not_activated() -> void:
	assert_false(_instance.activated_this_round,
			"Should start unactivated")


func test_create_from_data_owner_player() -> void:
	assert_eq(_instance.owner_player, 0,
			"owner_player should match factory arg")


# --- Damage ---

func test_get_total_damage_empty() -> void:
	assert_eq(_instance.get_total_damage(), 0,
			"No damage cards means total damage 0")


func test_get_total_damage_facedown_only() -> void:
	_instance.facedown_damage.append(DamageCard.create("Ship", "Test"))
	_instance.facedown_damage.append(DamageCard.create("Crew", "Test2"))
	assert_eq(_instance.get_total_damage(), 2,
			"Total damage should count facedown cards")


func test_get_total_damage_mixed() -> void:
	_instance.facedown_damage.append(DamageCard.create("Ship", "A"))
	_instance.faceup_damage.append(DamageCard.create("Crew", "B"))
	assert_eq(_instance.get_total_damage(), 2,
			"Total damage should count both facedown and faceup")


func test_is_destroyed_false_initially() -> void:
	assert_false(_instance.is_destroyed(),
			"Ship should not be destroyed when no damage")


func test_is_destroyed_true_at_hull() -> void:
	for i: int in range(_ship_data.hull):
		_instance.facedown_damage.append(DamageCard.create("Ship", "D%d" % i))
	assert_true(_instance.is_destroyed(),
			"Ship should be destroyed when damage == hull (DM-003)")


func test_is_destroyed_true_above_hull() -> void:
	for i: int in range(_ship_data.hull + 1):
		_instance.facedown_damage.append(DamageCard.create("Ship", "D%d" % i))
	assert_true(_instance.is_destroyed(),
			"Ship should be destroyed when damage > hull")


func test_mark_destroyed_sets_flag() -> void:
	_instance.mark_destroyed()
	assert_true(_instance.is_destroyed(),
			"Ship should be destroyed after mark_destroyed()")


func test_mark_destroyed_persists_after_clear_all_damage_cards() -> void:
	# Arrange — deal lethal damage, then mark destroyed and clear cards
	# (simulates the real GameManager destruction cleanup flow).
	for i: int in range(_ship_data.hull):
		_instance.facedown_damage.append(DamageCard.create("Ship", "D%d" % i))
	_instance.mark_destroyed()
	_instance.clear_all_damage_cards()
	# Assert — must still report destroyed even with 0 damage cards.
	assert_true(_instance.is_destroyed(),
			"Ship must stay destroyed after damage cards are returned (DM-003)")


func test_add_facedown_damage() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Test")
	_instance.add_facedown_damage(card)
	assert_eq(_instance.facedown_damage.size(), 1,
			"Should have 1 facedown damage card")


func test_add_faceup_damage() -> void:
	var card: DamageCard = DamageCard.create("Crew", "Crit")
	_instance.add_faceup_damage(card)
	assert_eq(_instance.faceup_damage.size(), 1,
			"Should have 1 faceup damage card")


# --- Remaining Hull (computed) ---

func test_get_remaining_hull_no_damage() -> void:
	assert_eq(_instance.get_remaining_hull(), 5,
			"Remaining hull should equal max hull when no damage dealt")


func test_get_remaining_hull_after_facedown_damage() -> void:
	_instance.add_facedown_damage(DamageCard.create("Ship", "D1"))
	_instance.add_facedown_damage(DamageCard.create("Ship", "D2"))
	assert_eq(_instance.get_remaining_hull(), 3,
			"Remaining hull should be 5 - 2 = 3 after 2 facedown cards")


func test_get_remaining_hull_after_mixed_damage() -> void:
	_instance.add_faceup_damage(DamageCard.create("Crew", "Crit"))
	_instance.add_facedown_damage(DamageCard.create("Ship", "D1"))
	assert_eq(_instance.get_remaining_hull(), 3,
			"Remaining hull should be 5 - 2 = 3 with mixed damage cards")


func test_get_remaining_hull_at_destruction() -> void:
	for i: int in range(_ship_data.hull):
		_instance.add_facedown_damage(DamageCard.create("Ship", "D%d" % i))
	assert_eq(_instance.get_remaining_hull(), 0,
			"Remaining hull should be 0 when damage equals max hull")


# --- Shields ---

func test_reduce_shields_normal() -> void:
	var reduced: int = _instance.reduce_shields("FRONT", 2)
	assert_eq(reduced, 2, "Should reduce by requested amount")
	assert_eq(int(_instance.current_shields["FRONT"]), 1,
			"FRONT shields should be 1 after reducing by 2")


func test_reduce_shields_clamped_to_zero() -> void:
	var reduced: int = _instance.reduce_shields("REAR", 5)
	assert_eq(reduced, 1, "Should only reduce available shields (1)")
	assert_eq(int(_instance.current_shields["REAR"]), 0,
			"Shields should not go below 0")


func test_reduce_shields_invalid_zone() -> void:
	var reduced: int = _instance.reduce_shields("INVALID", 1)
	assert_eq(reduced, 0, "Invalid zone should reduce 0")


func test_restore_shields_normal() -> void:
	_instance.reduce_shields("FRONT", 2)
	var restored: int = _instance.restore_shields("FRONT", 1)
	assert_eq(restored, 1, "Should restore 1 shield")
	assert_eq(int(_instance.current_shields["FRONT"]), 2,
			"FRONT shields should be 2 after restoring 1")


func test_restore_shields_clamped_to_max() -> void:
	_instance.reduce_shields("FRONT", 1)
	var restored: int = _instance.restore_shields("FRONT", 5)
	assert_eq(restored, 1, "Should only restore up to max (3)")
	assert_eq(int(_instance.current_shields["FRONT"]), 3,
			"FRONT shields should cap at max")


func test_get_max_shields() -> void:
	assert_eq(_instance.get_max_shields("FRONT"), 3,
			"Max FRONT shields should be 3")
	assert_eq(_instance.get_max_shields("LEFT"), 2,
			"Max LEFT shields should be 2")


# --- Speed ---

func test_set_speed_normal() -> void:
	_instance.set_speed(3)
	assert_eq(_instance.current_speed, 3,
			"Speed should be set to 3")


func test_set_speed_clamped_high() -> void:
	_instance.set_speed(10)
	assert_eq(_instance.current_speed, 3,
			"Speed should be clamped to max_speed (3)")


func test_set_speed_clamped_low() -> void:
	_instance.set_speed(-1)
	assert_eq(_instance.current_speed, 0,
			"Speed should not go below 0")


# --- Defense Tokens ---

func test_exhaust_defense_token() -> void:
	_instance.exhaust_defense_token(0)
	assert_eq(_instance.defense_tokens[0]["state"],
			Constants.DefenseTokenState.EXHAUSTED,
			"Token should be EXHAUSTED after exhaust (DT-001)")


func test_exhaust_already_exhausted_no_change() -> void:
	_instance.exhaust_defense_token(0)
	_instance.exhaust_defense_token(0)
	assert_eq(_instance.defense_tokens[0]["state"],
			Constants.DefenseTokenState.EXHAUSTED,
			"Already EXHAUSTED token should stay EXHAUSTED")


func test_discard_defense_token() -> void:
	_instance.discard_defense_token(1)
	assert_eq(_instance.defense_tokens[1]["state"],
			Constants.DefenseTokenState.DISCARDED,
			"Token should be DISCARDED (DT-002)")


func test_ready_defense_tokens_readies_exhausted() -> void:
	_instance.exhaust_defense_token(0)
	_instance.exhaust_defense_token(2)
	_instance.ready_defense_tokens()
	assert_eq(_instance.defense_tokens[0]["state"],
			Constants.DefenseTokenState.READY,
			"EXHAUSTED tokens should be READY after Status Phase")
	assert_eq(_instance.defense_tokens[2]["state"],
			Constants.DefenseTokenState.READY,
			"EXHAUSTED tokens should be READY after Status Phase")


func test_ready_defense_tokens_ignores_discarded() -> void:
	_instance.discard_defense_token(1)
	_instance.ready_defense_tokens()
	assert_eq(_instance.defense_tokens[1]["state"],
			Constants.DefenseTokenState.DISCARDED,
			"DISCARDED tokens should stay DISCARDED")


func test_get_active_token_count_all_ready() -> void:
	assert_eq(_instance.get_active_token_count(), 3,
			"All 3 tokens are active initially")


func test_get_active_token_count_with_discarded() -> void:
	_instance.discard_defense_token(0)
	assert_eq(_instance.get_active_token_count(), 2,
			"Discarding 1 should leave 2 active")


func test_exhaust_invalid_index_no_crash() -> void:
	_instance.exhaust_defense_token(-1)
	_instance.exhaust_defense_token(99)
	assert_true(true, "Invalid index should not crash")


func test_discard_invalid_index_no_crash() -> void:
	_instance.discard_defense_token(-1)
	_instance.discard_defense_token(99)
	assert_true(true, "Invalid index should not crash")


# --- Activation ---

func test_reset_activation() -> void:
	_instance.activated_this_round = true
	_instance.reset_activation()
	assert_false(_instance.activated_this_round,
			"Activation flag should be reset")

# --- Command Dial Stack ---

func test_create_from_data_initialises_command_dial_stack() -> void:
	assert_not_null(_instance.command_dial_stack,
			"command_dial_stack should be initialized by factory")


func test_command_dial_stack_command_value_matches() -> void:
	_ship_data.command_value = 2
	var inst: ShipInstance = ShipInstance.create_from_data(
			"test", _ship_data, 2, 0)
	assert_eq(inst.command_dial_stack.command_value, 2,
			"Stack command_value should match ShipData.command_value")


func test_command_dial_stack_starts_empty() -> void:
	assert_eq(_instance.command_dial_stack.get_dial_count(), 0,
			"Dial stack should start empty")


# --- Command Tokens ---

func test_create_from_data_initialises_command_tokens() -> void:
	assert_not_null(_instance.command_tokens,
			"command_tokens should be initialized by factory")


func test_command_tokens_max_matches_command_value() -> void:
	_ship_data.command_value = 2
	var inst: ShipInstance = ShipInstance.create_from_data(
			"test", _ship_data, 2, 0)
	assert_eq(inst.command_tokens.max_tokens, 2,
			"Token max should match ShipData.command_value (CM-004)")


func test_command_tokens_starts_empty() -> void:
	assert_eq(_instance.command_tokens.get_token_count(), 0,
			"Command tokens should start empty")


# --- is_fully_healthy ---


func test_is_fully_healthy_true_at_creation() -> void:
	assert_true(_instance.is_fully_healthy(),
			"Freshly created ship should be fully healthy")


func test_is_fully_healthy_false_with_facedown_damage() -> void:
	var card: RefCounted = RefCounted.new()
	_instance.add_facedown_damage(card)
	assert_false(_instance.is_fully_healthy(),
			"Ship with facedown damage should not be fully healthy")


func test_is_fully_healthy_false_with_faceup_damage() -> void:
	var card: RefCounted = RefCounted.new()
	_instance.add_faceup_damage(card)
	assert_false(_instance.is_fully_healthy(),
			"Ship with faceup damage should not be fully healthy")


func test_is_fully_healthy_false_with_reduced_shields() -> void:
	_instance.reduce_shields("FRONT", 1)
	assert_false(_instance.is_fully_healthy(),
			"Ship with reduced shields should not be fully healthy")


func test_is_fully_healthy_true_after_shields_restored() -> void:
	_instance.reduce_shields("FRONT", 1)
	_instance.restore_shields("FRONT", 1)
	assert_true(_instance.is_fully_healthy(),
			"Ship should be fully healthy after shields restored")


# --- Serialization round-trip ---

func test_serialize_contains_expected_keys() -> void:
	var data: Dictionary = _instance.serialize()
	for key: String in ["data_key", "current_shields", "current_hull",
			"current_speed", "defense_tokens", "facedown_damage",
			"faceup_damage", "activated_this_round", "owner_player",
			"destroyed", "command_dial_stack", "command_tokens"]:
		assert_true(data.has(key),
				"serialize() should include key '%s'" % key)


func test_serialize_data_key() -> void:
	var data: Dictionary = _instance.serialize()
	assert_eq(data["data_key"], "test_ship",
			"Serialized data_key should match")


func test_serialize_current_speed() -> void:
	_instance.set_speed(1)
	var data: Dictionary = _instance.serialize()
	assert_eq(data["current_speed"], 1,
			"Serialized current_speed should reflect set_speed()")


func test_deserialize_round_trip_basic_fields() -> void:
	_instance.set_speed(1)
	_instance.activated_this_round = true
	_instance.current_hull = 3
	var data: Dictionary = _instance.serialize()
	var restored: ShipInstance = ShipInstance.deserialize(data, _ship_data)
	assert_eq(restored.data_key, "test_ship",
			"Round-trip should preserve data_key")
	assert_eq(restored.current_speed, 1,
			"Round-trip should preserve current_speed")
	assert_eq(restored.current_hull, 3,
			"Round-trip should preserve current_hull")
	assert_true(restored.activated_this_round,
			"Round-trip should preserve activated_this_round")
	assert_eq(restored.owner_player, 0,
			"Round-trip should preserve owner_player")


func test_deserialize_round_trip_shields() -> void:
	_instance.reduce_shields("FRONT", 2)
	var restored: ShipInstance = ShipInstance.deserialize(
			_instance.serialize(), _ship_data)
	assert_eq(int(restored.current_shields["FRONT"]), 1,
			"Round-trip should preserve reduced shields")
	assert_eq(int(restored.current_shields["LEFT"]), 2,
			"Round-trip should preserve untouched shields")


func test_deserialize_round_trip_defense_tokens() -> void:
	_instance.exhaust_defense_token(0)
	_instance.discard_defense_token(2)
	var restored: ShipInstance = ShipInstance.deserialize(
			_instance.serialize(), _ship_data)
	assert_eq(restored.defense_tokens.size(), 3,
			"Round-trip should preserve token count")
	assert_eq(restored.defense_tokens[0]["state"],
			Constants.DefenseTokenState.EXHAUSTED,
			"Round-trip should preserve exhausted state")
	assert_eq(restored.defense_tokens[1]["state"],
			Constants.DefenseTokenState.READY,
			"Round-trip should preserve ready state")
	assert_eq(restored.defense_tokens[2]["state"],
			Constants.DefenseTokenState.DISCARDED,
			"Round-trip should preserve discarded state")


func test_deserialize_round_trip_damage_cards() -> void:
	var fd_card: DamageCard = DamageCard.create("Ship", "Facedown Hit")
	var fu_card: DamageCard = DamageCard.create("Crew", "Critical Hit")
	fu_card.flip_faceup()
	_instance.add_facedown_damage(fd_card)
	_instance.add_faceup_damage(fu_card)
	var restored: ShipInstance = ShipInstance.deserialize(
			_instance.serialize(), _ship_data)
	assert_eq(restored.facedown_damage.size(), 1,
			"Round-trip should preserve facedown damage count")
	assert_eq(restored.faceup_damage.size(), 1,
			"Round-trip should preserve faceup damage count")
	assert_eq((restored.faceup_damage[0] as DamageCard).title,
			"Critical Hit",
			"Round-trip should preserve faceup card title")
	assert_true((restored.faceup_damage[0] as DamageCard).is_faceup,
			"Round-trip should preserve faceup state on faceup cards")


func test_deserialize_round_trip_destroyed_flag() -> void:
	_instance.mark_destroyed()
	var restored: ShipInstance = ShipInstance.deserialize(
			_instance.serialize(), _ship_data)
	assert_true(restored.is_destroyed(),
			"Round-trip should preserve destroyed flag")


func test_deserialize_round_trip_command_dial_stack() -> void:
	_instance.command_dial_stack.command_value = 2
	var restored: ShipInstance = ShipInstance.deserialize(
			_instance.serialize(), _ship_data)
	assert_not_null(restored.command_dial_stack,
			"Round-trip should restore command_dial_stack")
	assert_eq(restored.command_dial_stack.command_value, 2,
			"Round-trip should preserve command_value")
