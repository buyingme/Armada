## Tests for P3 ResolveDamageCommand.
##
## Covers: validate (happy + rejection), execute for ship and squadron
## targets, serialize/deserialize roundtrip.
extends GutTest


var _state: GameState


## Creates a minimal ShipData for testing.
func _make_ship_data() -> ShipData:
	var data := ShipData.new()
	data.hull = 5
	data.max_speed = 2
	data.command_value = 2
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = ["brace", "redirect"]
	data.navigation_chart = [[1], [1, 1]]
	return data


## Creates a ShipInstance and adds it to the player's fleet.
## Returns the ship index.
func _add_ship(player: int) -> int:
	var ship := ShipInstance.create_from_data(
			"test_ship", _make_ship_data(), 2, player)
	var ps: PlayerState = _state.get_player_state(player)
	ps.ships.append(ship)
	return ps.ships.size() - 1


## Creates a minimal SquadronData for testing.
func _make_squadron_data() -> SquadronData:
	var data := SquadronData.new()
	data.hull = 3
	data.speed = 3
	data.defense_tokens = ["BRACE"]
	return data


## Creates a SquadronInstance and adds it to the player's fleet.
## Returns the squadron index.
func _add_squadron(player: int) -> int:
	var sq := SquadronInstance.create_from_data(
			"test_squadron", _make_squadron_data(), player)
	var ps: PlayerState = _state.get_player_state(player)
	ps.squadrons.append(sq)
	return ps.squadrons.size() - 1


## Creates a serialized damage card dict.
func _make_card(title: String, is_faceup: bool = false) -> Dictionary:
	return {
		"trait_type": "Ship",
		"title": title,
		"is_faceup": is_faceup,
		"effect_text": "Test effect.",
		"timing": "persistent" if is_faceup else "",
		"effect_id": title.to_lower().replace(" ", "_"),
	}


## Creates a serialized legacy persistent damage card dict.
func _make_ruptured_engine_card() -> Dictionary:
	return {
		"trait_type": "Ship",
		"title": "Ruptured Engine",
		"is_faceup": true,
		"effect_text": "After you execute a maneuver, if your speed is greater than 1, suffer 1 damage.",
		"timing": "persistent",
		"effect_id": "ruptured_engine",
	}


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_round = 1
	_state.current_phase = Constants.GamePhase.SHIP
	ResolveDamageCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("resolve_damage")


# ======================================================================
# Validate — Ship Target
# ======================================================================

func test_validate_ship_ok() -> void:
	var idx: int = _add_ship(1)
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "ship",
		"owner_player": 1,
		"ship_index": idx,
		"hull_zone": "FRONT",
		"shield_damage": 2,
		"damage_cards": [_make_card("Structural Damage")],
		"target_destroyed": false,
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid ship damage in Ship Phase.")


func test_validate_ship_ok_squadron_phase() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var idx: int = _add_ship(1)
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "ship",
		"owner_player": 1,
		"ship_index": idx,
		"hull_zone": "FRONT",
		"shield_damage": 1,
		"damage_cards": [],
		"target_destroyed": false,
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept ship damage in Squadron Phase.")


func test_validate_ship_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.COMMAND
	var idx: int = _add_ship(1)
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "ship",
		"owner_player": 1,
		"ship_index": idx,
		"hull_zone": "FRONT",
		"shield_damage": 1,
		"damage_cards": [],
		"target_destroyed": false,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Ship/Squadron Phase.")


func test_validate_ship_invalid_target_type() -> void:
	var cmd := ResolveDamageCommand.new(0, {
		"target_type": "station",
		"owner_player": 0,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid target_type.")


func test_validate_ship_not_found() -> void:
	var cmd := ResolveDamageCommand.new(0, {
		"target_type": "ship",
		"owner_player": 0,
		"ship_index": 99,
		"hull_zone": "FRONT",
		"shield_damage": 0,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid ship index.")


func test_validate_ship_invalid_zone() -> void:
	var idx: int = _add_ship(0)
	var cmd := ResolveDamageCommand.new(0, {
		"target_type": "ship",
		"owner_player": 0,
		"ship_index": idx,
		"hull_zone": "BOGUS",
		"shield_damage": 0,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid hull zone string.")


func test_validate_ship_negative_shield() -> void:
	var idx: int = _add_ship(0)
	var cmd := ResolveDamageCommand.new(0, {
		"target_type": "ship",
		"owner_player": 0,
		"ship_index": idx,
		"hull_zone": "FRONT",
		"shield_damage": - 1,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject negative shield_damage.")


# ======================================================================
# Validate — Squadron Target
# ======================================================================

func test_validate_squadron_ok() -> void:
	var idx: int = _add_squadron(1)
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "squadron",
		"owner_player": 1,
		"squadron_index": idx,
		"hull_damage": 2,
		"target_destroyed": false,
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid squadron damage.")


func test_validate_squadron_not_found() -> void:
	var cmd := ResolveDamageCommand.new(0, {
		"target_type": "squadron",
		"owner_player": 0,
		"squadron_index": 99,
		"hull_damage": 1,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid squadron index.")


func test_validate_squadron_negative_hull() -> void:
	var idx: int = _add_squadron(0)
	var cmd := ResolveDamageCommand.new(0, {
		"target_type": "squadron",
		"owner_player": 0,
		"squadron_index": idx,
		"hull_damage": - 1,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject negative hull_damage.")


# ======================================================================
# Execute — Ship Target: Shield Absorption
# ======================================================================

func test_execute_ship_shields_absorbed() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	assert_eq(int(ship.current_shields.get("FRONT", 0)), 3,
			"FRONT shields should start at 3.")
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "ship",
		"owner_player": 1,
		"ship_index": idx,
		"hull_zone": "FRONT",
		"shield_damage": 2,
		"damage_cards": [],
		"target_destroyed": false,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("shield_absorbed", 0), 2,
			"Should absorb 2 shields.")
	assert_eq(result.get("new_shields", -1), 1,
			"FRONT shields should be 1 after absorbing 2.")
	assert_eq(int(ship.current_shields.get("FRONT", 0)), 1,
			"Ship state should reflect reduced shields.")


func test_execute_ship_shields_capped() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	ship.current_shields["REAR"] = 1
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "ship",
		"owner_player": 1,
		"ship_index": idx,
		"hull_zone": "REAR",
		"shield_damage": 5,
		"damage_cards": [],
		"target_destroyed": false,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("shield_absorbed", 0), 1,
			"Should only absorb 1 (current shield value).")
	assert_eq(int(ship.current_shields.get("REAR", 0)), 0,
			"REAR shields should be 0.")


# ======================================================================
# Execute — Ship Target: Damage Cards
# ======================================================================

func test_execute_ship_facedown_cards() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	var cards: Array = [
		_make_card("Test Card 1"),
		_make_card("Test Card 2"),
	]
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "ship",
		"owner_player": 1,
		"ship_index": idx,
		"hull_zone": "FRONT",
		"shield_damage": 0,
		"damage_cards": cards,
		"target_destroyed": false,
	})
	cmd.execute(_state)
	assert_eq(ship.facedown_damage.size(), 2,
			"Ship should have 2 facedown damage cards.")
	assert_eq(ship.faceup_damage.size(), 0,
			"Ship should have 0 faceup damage cards.")


func test_execute_ship_faceup_card() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	var cards: Array = [_make_card("Structural Damage", true)]
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "ship",
		"owner_player": 1,
		"ship_index": idx,
		"hull_zone": "FRONT",
		"shield_damage": 0,
		"damage_cards": cards,
		"target_destroyed": false,
	})
	cmd.execute(_state)
	assert_eq(ship.faceup_damage.size(), 1,
			"Ship should have 1 faceup damage card.")
	var card: DamageCard = ship.faceup_damage[0] as DamageCard
	assert_eq(card.title, "Structural Damage",
			"Faceup card title should match.")
	assert_true(card.is_faceup,
			"Card should be marked faceup.")


func test_execute_ship_faceup_movement_card_records_no_persistent_runtime() -> void:
	_state.initiative_player = 1
	var idx: int = _add_ship(1)
	var cmd := ResolveDamageCommand.new(0, {
		"target_type": "ship",
		"owner_player": 1,
		"ship_index": idx,
		"hull_zone": "FRONT",
		"shield_damage": 0,
		"damage_cards": [_make_ruptured_engine_card()],
		"target_destroyed": false,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("persistent_registered", -1), 0,
			"Ruptured Engine should not register transient runtime effects.")


func test_execute_ship_mixed_cards() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	var cards: Array = [
		_make_card("Comm Noise", true),
		_make_card("Generic Card 1"),
		_make_card("Generic Card 2"),
	]
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "ship",
		"owner_player": 1,
		"ship_index": idx,
		"hull_zone": "LEFT",
		"shield_damage": 1,
		"damage_cards": cards,
		"target_destroyed": false,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(ship.faceup_damage.size(), 1,
			"Ship should have 1 faceup card.")
	assert_eq(ship.facedown_damage.size(), 2,
			"Ship should have 2 facedown cards.")
	assert_eq(result.get("cards_added", 0), 3,
			"Result should report 3 cards added.")


# ======================================================================
# Execute — Ship Target: Destruction
# ======================================================================

func test_execute_ship_destroyed() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	var cards: Array = []
	for i: int in range(5):
		cards.append(_make_card("Card %d" % i))
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "ship",
		"owner_player": 1,
		"ship_index": idx,
		"hull_zone": "FRONT",
		"shield_damage": 0,
		"damage_cards": cards,
		"target_destroyed": true,
	})
	cmd.execute(_state)
	assert_true(ship.is_destroyed(),
			"Ship should be marked destroyed.")
	assert_eq(ship.get_total_damage(), 5,
			"Ship should have 5 total damage cards.")


func test_execute_ship_not_destroyed() -> void:
	var idx: int = _add_ship(1)
	var ship: ShipInstance = _state.get_ship(1, idx)
	var cards: Array = [_make_card("Minor Hit")]
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "ship",
		"owner_player": 1,
		"ship_index": idx,
		"hull_zone": "FRONT",
		"shield_damage": 0,
		"damage_cards": cards,
		"target_destroyed": false,
	})
	cmd.execute(_state)
	assert_false(ship.is_destroyed(),
			"Ship should NOT be marked destroyed.")


# ======================================================================
# Execute — Squadron Target
# ======================================================================

func test_execute_squadron_damage() -> void:
	var idx: int = _add_squadron(1)
	var sq: SquadronInstance = _state.get_squadron(1, idx)
	assert_eq(sq.current_hull, 3,
			"Squadron hull should start at 3.")
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "squadron",
		"owner_player": 1,
		"squadron_index": idx,
		"hull_damage": 2,
		"target_destroyed": false,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("actual_damage", 0), 2,
			"Should apply 2 hull damage.")
	assert_eq(sq.current_hull, 1,
			"Squadron hull should be 1 after 2 damage.")
	assert_eq(result.get("new_hull", -1), 1,
			"Result should report new hull of 1.")


func test_execute_squadron_destroyed() -> void:
	var idx: int = _add_squadron(1)
	var sq: SquadronInstance = _state.get_squadron(1, idx)
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "squadron",
		"owner_player": 1,
		"squadron_index": idx,
		"hull_damage": 4,
		"target_destroyed": true,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("actual_damage", 0), 3,
			"Actual damage should be capped at hull (3).")
	assert_eq(sq.current_hull, 0,
			"Squadron hull should be 0.")
	assert_true(sq.is_destroyed(),
			"Squadron should be marked destroyed.")
	assert_true(result.get("destroyed", false),
			"Result should report destroyed=true.")


func test_execute_squadron_not_destroyed() -> void:
	var idx: int = _add_squadron(0)
	var sq: SquadronInstance = _state.get_squadron(0, idx)
	var cmd := ResolveDamageCommand.new(0, {
		"target_type": "squadron",
		"owner_player": 0,
		"squadron_index": idx,
		"hull_damage": 1,
		"target_destroyed": false,
	})
	cmd.execute(_state)
	assert_eq(sq.current_hull, 2,
			"Squadron hull should be 2 after 1 damage.")
	assert_false(sq.is_destroyed(),
			"Squadron should NOT be destroyed.")


# ======================================================================
# Serialize / Deserialize Roundtrip
# ======================================================================

func test_serialize_roundtrip_ship() -> void:
	var cmd := ResolveDamageCommand.new(1, {
		"target_type": "ship",
		"owner_player": 1,
		"ship_index": 0,
		"hull_zone": "FRONT",
		"shield_damage": 2,
		"damage_cards": [_make_card("Test Crit", true)],
		"target_destroyed": false,
	})
	cmd.sequence = 42
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored,
			"Deserialized command should not be null.")
	assert_eq(restored.command_type, "resolve_damage",
			"Restored type should match.")
	assert_eq(restored.player_index, 1,
			"Restored player should match.")
	assert_eq(restored.sequence, 42,
			"Restored sequence should match.")
	assert_eq(restored.payload.get("target_type", ""), "ship",
			"Restored target_type should be 'ship'.")
	assert_eq(restored.payload.get("hull_zone", ""), "FRONT",
			"Restored hull_zone should match.")


func test_serialize_roundtrip_squadron() -> void:
	var cmd := ResolveDamageCommand.new(0, {
		"target_type": "squadron",
		"owner_player": 0,
		"squadron_index": 1,
		"hull_damage": 3,
		"target_destroyed": true,
	})
	cmd.sequence = 99
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored,
			"Deserialized command should not be null.")
	assert_eq(restored.command_type, "resolve_damage",
			"Restored type should match.")
	assert_eq(restored.payload.get("target_type", ""), "squadron",
			"Restored target_type should be 'squadron'.")
	assert_eq(restored.payload.get("hull_damage", 0), 3,
			"Restored hull_damage should match.")
	assert_true(restored.payload.get("target_destroyed", false),
			"Restored target_destroyed should be true.")
