## Tests for P6 commands: SetSpeedCommand, OverlapDamageCommand,
## PersistentEffectDamageCommand.
##
## Covers: validate (happy + rejection), execute, serialize/deserialize
## roundtrip for all 3 commands.
extends GutTest


var _state: GameState


## Creates a minimal ShipData for testing.
func _make_ship_data() -> ShipData:
	var data := ShipData.new()
	data.hull = 5
	data.max_speed = 3
	data.command_value = 2
	data.engineering_value = 3
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = ["evade", "brace"]
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	return data


## Adds a ship to the given player's fleet. Returns the ship index.
func _add_ship(player: int, speed: int = 2) -> int:
	var ship := ShipInstance.create_from_data(
			"test_ship", _make_ship_data(), speed, player)
	var ps: PlayerState = _state.get_player_state(player)
	ps.ships.append(ship)
	return ps.ships.size() - 1


## Creates a serialized DamageCard dictionary for command payloads.
func _make_card_data(title: String = "Test Card") -> Dictionary:
	var card := DamageCard.create("Ship", title)
	card.is_faceup = false
	return card.serialize()


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_round = 1
	_state.current_phase = Constants.GamePhase.SHIP
	_state.damage_deck = DamageDeck.new()
	_state.damage_deck.initialize()
	SetSpeedCommand.register()
	OverlapDamageCommand.register()
	PersistentEffectDamageCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("set_speed")
	GameCommand._registry.erase("overlap_damage")
	GameCommand._registry.erase("persistent_effect_damage")


# ======================================================================
# SetSpeedCommand — validate
# ======================================================================

func test_set_speed_validate_ok() -> void:
	var idx: int = _add_ship(0, 2)
	var cmd := SetSpeedCommand.new(0, {
		"ship_index": idx,
		"new_speed": 3,
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid speed within bounds")


func test_set_speed_validate_wrong_phase() -> void:
	var idx: int = _add_ship(0)
	_state.current_phase = Constants.GamePhase.COMMAND
	var cmd := SetSpeedCommand.new(0, {
		"ship_index": idx,
		"new_speed": 1,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when not in Ship Phase")


func test_set_speed_validate_exceeds_max() -> void:
	var idx: int = _add_ship(0)
	var cmd := SetSpeedCommand.new(0, {
		"ship_index": idx,
		"new_speed": 4,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject speed > max_speed")


func test_set_speed_validate_negative() -> void:
	var idx: int = _add_ship(0)
	var cmd := SetSpeedCommand.new(0, {
		"ship_index": idx,
		"new_speed": - 1,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject negative speed")


func test_set_speed_validate_ship_not_found() -> void:
	var cmd := SetSpeedCommand.new(0, {
		"ship_index": 99,
		"new_speed": 1,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when ship index is out of bounds")


# ======================================================================
# SetSpeedCommand — execute
# ======================================================================

func test_set_speed_execute() -> void:
	var idx: int = _add_ship(0, 2)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	assert_eq(ship.current_speed, 2, "Precondition: speed is 2")
	var cmd := SetSpeedCommand.new(0, {
		"ship_index": idx,
		"new_speed": 3,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("old_speed"), 2, "Old speed should be 2")
	assert_eq(result.get("new_speed"), 3, "New speed should be 3")
	assert_eq(ship.current_speed, 3, "Ship speed should be 3")


func test_set_speed_execute_to_zero() -> void:
	var idx: int = _add_ship(0, 2)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	var cmd := SetSpeedCommand.new(0, {
		"ship_index": idx,
		"new_speed": 0,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(ship.current_speed, 0, "Ship speed should be 0")
	assert_eq(result.get("new_speed"), 0, "Result new_speed should be 0")


# ======================================================================
# SetSpeedCommand — serialize/deserialize
# ======================================================================

func test_set_speed_serialize_roundtrip() -> void:
	var cmd := SetSpeedCommand.new(1, {
		"ship_index": 0,
		"new_speed": 2,
	})
	cmd.sequence = 10
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Should deserialize")
	assert_eq(restored.command_type, "set_speed", "Type should match")
	assert_eq(restored.sequence, 10, "Sequence should match")
	assert_eq(restored.payload.get("new_speed"), 2,
			"new_speed survives roundtrip")


# ======================================================================
# OverlapDamageCommand — validate
# ======================================================================

func test_overlap_validate_ok() -> void:
	var m_idx: int = _add_ship(0)
	var o_idx: int = _add_ship(1)
	var cmd := OverlapDamageCommand.new(0, {
		"ship_index": m_idx,
		"other_owner": 1,
		"other_ship_index": o_idx,
		"moving_card": _make_card_data("Moving"),
		"other_card": _make_card_data("Other"),
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid overlap damage")


func test_overlap_validate_wrong_phase() -> void:
	var m_idx: int = _add_ship(0)
	var o_idx: int = _add_ship(1)
	_state.current_phase = Constants.GamePhase.COMMAND
	var cmd := OverlapDamageCommand.new(0, {
		"ship_index": m_idx,
		"other_owner": 1,
		"other_ship_index": o_idx,
		"moving_card": _make_card_data(),
		"other_card": _make_card_data(),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when not in Ship Phase")


func test_overlap_validate_moving_not_found() -> void:
	_add_ship(1)
	var cmd := OverlapDamageCommand.new(0, {
		"ship_index": 99,
		"other_owner": 1,
		"other_ship_index": 0,
		"moving_card": _make_card_data(),
		"other_card": _make_card_data(),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when moving ship not found")


func test_overlap_validate_other_not_found() -> void:
	var m_idx: int = _add_ship(0)
	var cmd := OverlapDamageCommand.new(0, {
		"ship_index": m_idx,
		"other_owner": 1,
		"other_ship_index": 99,
		"moving_card": _make_card_data(),
		"other_card": _make_card_data(),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when overlapped ship not found")


func test_overlap_validate_missing_cards() -> void:
	var m_idx: int = _add_ship(0)
	var o_idx: int = _add_ship(1)
	var cmd := OverlapDamageCommand.new(0, {
		"ship_index": m_idx,
		"other_owner": 1,
		"other_ship_index": o_idx,
		"moving_card": {},
		"other_card": _make_card_data(),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when moving_card data is empty")


# ======================================================================
# OverlapDamageCommand — execute
# ======================================================================

func test_overlap_execute_both_survive() -> void:
	var m_idx: int = _add_ship(0)
	var o_idx: int = _add_ship(1)
	var ps0: PlayerState = _state.get_player_state(0)
	var ps1: PlayerState = _state.get_player_state(1)
	var moving: ShipInstance = ps0.ships[m_idx]
	var other: ShipInstance = ps1.ships[o_idx]
	var cmd := OverlapDamageCommand.new(0, {
		"ship_index": m_idx,
		"other_owner": 1,
		"other_ship_index": o_idx,
		"moving_card": _make_card_data("M"),
		"other_card": _make_card_data("O"),
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(moving.facedown_damage.size(), 1,
			"Moving ship gets 1 facedown card")
	assert_eq(other.facedown_damage.size(), 1,
			"Other ship gets 1 facedown card")
	assert_false(result.get("moving_destroyed", true) as bool,
			"Moving ship should survive")
	assert_false(result.get("other_destroyed", true) as bool,
			"Other ship should survive")
	assert_eq(int(result.get("moving_hull")), 4,
			"Moving hull should be 5 - 1 = 4")
	assert_eq(int(result.get("other_hull")), 4,
			"Other hull should be 5 - 1 = 4")


func test_overlap_execute_moving_destroyed() -> void:
	var m_idx: int = _add_ship(0)
	var o_idx: int = _add_ship(1)
	var ps0: PlayerState = _state.get_player_state(0)
	var moving: ShipInstance = ps0.ships[m_idx]
	# Pre-damage to hull-1 (4 facedown already).
	for i: int in range(4):
		var fd: DamageCard = DamageCard.create("Ship", "pre_%d" % i)
		fd.is_faceup = false
		moving.add_facedown_damage(fd)
	assert_eq(moving.get_total_damage(), 4, "Precondition: 4 damage dealt")
	var cmd := OverlapDamageCommand.new(0, {
		"ship_index": m_idx,
		"other_owner": 1,
		"other_ship_index": o_idx,
		"moving_card": _make_card_data("M"),
		"other_card": _make_card_data("O"),
	})
	var result: Dictionary = cmd.execute(_state)
	assert_true(result.get("moving_destroyed", false) as bool,
			"Moving ship should be destroyed (5 damage vs 5 hull)")
	assert_true(moving.is_destroyed(),
			"Moving ship should be marked destroyed")


# ======================================================================
# OverlapDamageCommand — serialize/deserialize
# ======================================================================

func test_overlap_serialize_roundtrip() -> void:
	var cmd := OverlapDamageCommand.new(0, {
		"ship_index": 0,
		"other_owner": 1,
		"other_ship_index": 0,
		"moving_card": _make_card_data("M"),
		"other_card": _make_card_data("O"),
	})
	cmd.sequence = 25
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Should deserialize")
	assert_eq(restored.command_type, "overlap_damage",
			"Type should match")
	assert_eq(restored.sequence, 25, "Sequence should match")
	var m: Dictionary = restored.payload.get("moving_card", {})
	assert_eq(m.get("title"), "M",
			"moving_card title survives roundtrip")


# ======================================================================
# PersistentEffectDamageCommand — validate
# ======================================================================

func test_persistent_validate_ok() -> void:
	var idx: int = _add_ship(0)
	var cmd := PersistentEffectDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "ruptured_engine",
		"card_data": _make_card_data(),
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid persistent damage")


func test_persistent_validate_wrong_phase() -> void:
	var idx: int = _add_ship(0)
	_state.current_phase = Constants.GamePhase.COMMAND
	var cmd := PersistentEffectDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "ruptured_engine",
		"card_data": _make_card_data(),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when not in Ship Phase")


func test_persistent_validate_unknown_effect() -> void:
	var idx: int = _add_ship(0)
	var cmd := PersistentEffectDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "fake_effect",
		"card_data": _make_card_data(),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject unknown effect_id")


func test_persistent_validate_ship_not_found() -> void:
	var cmd := PersistentEffectDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": 99,
		"effect_id": "crew_panic",
		"card_data": _make_card_data(),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when ship not found")


func test_persistent_validate_missing_card_data() -> void:
	var idx: int = _add_ship(0)
	var cmd := PersistentEffectDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "thruster_fissure",
		"card_data": {},
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when card_data is empty")


func test_persistent_validate_draw_from_deck_ok() -> void:
	var idx: int = _add_ship(0)
	var cmd := PersistentEffectDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "damaged_controls",
		"draw_from_deck": true,
	})
	assert_eq(cmd.validate(_state), "",
			"Observer follow-ups should validate with draw_from_deck.")


# ======================================================================
# PersistentEffectDamageCommand — execute
# ======================================================================

func test_persistent_execute_ruptured_engine() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	var cmd := PersistentEffectDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "ruptured_engine",
		"card_data": _make_card_data("Ruptured Engine Extra"),
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(ship.facedown_damage.size(), 1,
			"Ship should get 1 facedown card")
	assert_eq(int(result.get("new_hull")), 4,
			"Hull should be 5 - 1 = 4")
	assert_false(result.get("destroyed", true) as bool,
			"Ship should survive")


func test_persistent_execute_draw_from_deck() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	var before_count: int = _state.damage_deck.get_total_count()
	var cmd := PersistentEffectDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "thruster_fissure",
		"draw_from_deck": true,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(ship.facedown_damage.size(), 1,
			"Draw-from-deck execution should add one facedown damage card.")
	assert_eq(_state.damage_deck.get_total_count(), before_count - 1,
			"Damage deck should lose the drawn card.")
	assert_eq(int(result.get("cards_added", 0)), 1,
			"Result should report one card added.")
	assert_false(result.get("card_data", {}).is_empty(),
			"Result should include serialized drawn card data for replay/debug.")


func test_persistent_execute_crew_panic() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	var cmd := PersistentEffectDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "crew_panic",
		"card_data": _make_card_data("Crew Panic Extra"),
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(ship.facedown_damage.size(), 1,
			"Ship should get 1 facedown card")
	assert_eq(result.get("effect_id"), "crew_panic",
			"Result should echo effect_id")


func test_persistent_execute_destroyed() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	# Pre-damage to hull-1.
	for i: int in range(4):
		var fd: DamageCard = DamageCard.create("Ship", "pre_%d" % i)
		fd.is_faceup = false
		ship.add_facedown_damage(fd)
	var cmd := PersistentEffectDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "damaged_controls",
		"card_data": _make_card_data("Fatal"),
	})
	var result: Dictionary = cmd.execute(_state)
	assert_true(result.get("destroyed", false) as bool,
			"Ship should be destroyed")
	assert_true(ship.is_destroyed(),
			"Ship should be marked destroyed")


func test_persistent_execute_all_valid_effects() -> void:
	for eff_id: String in PersistentEffectDamageCommand.VALID_EFFECTS:
		var idx: int = _add_ship(0)
		var cmd := PersistentEffectDamageCommand.new(0, {
			"owner_player": 0,
			"ship_index": idx,
			"effect_id": eff_id,
			"card_data": _make_card_data(eff_id),
		})
		assert_eq(cmd.validate(_state), "",
				"Effect '%s' should validate" % eff_id)


# ======================================================================
# PersistentEffectDamageCommand — serialize/deserialize
# ======================================================================

func test_persistent_serialize_roundtrip() -> void:
	var cmd := PersistentEffectDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"effect_id": "thruster_fissure",
		"card_data": _make_card_data("TF"),
	})
	cmd.sequence = 33
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Should deserialize")
	assert_eq(restored.command_type, "persistent_effect_damage",
			"Type should match")
	assert_eq(restored.sequence, 33, "Sequence should match")
	assert_eq(restored.payload.get("effect_id"), "thruster_fissure",
			"effect_id survives roundtrip")
	var cd: Dictionary = restored.payload.get("card_data", {})
	assert_eq(cd.get("title"), "TF",
			"card_data title survives roundtrip")
