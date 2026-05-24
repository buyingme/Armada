## Tests for DebugDealDamageCommand.
##
## Covers: validate (happy + rejection), execute (persistent +
## non-persistent cards), serialize/deserialize roundtrip.
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


## Adds a ship to the given player's fleet.  Returns the ship index.
func _add_ship(player: int, speed: int = 2) -> int:
	var ship := ShipInstance.create_from_data(
			"test_ship", _make_ship_data(), speed, player)
	var ps: PlayerState = _state.get_player_state(player)
	ps.ships.append(ship)
	return ps.ships.size() - 1


## Builds a serialized legacy persistent damage card (Ruptured Engine).
func _make_persistent_card_data() -> Dictionary:
	var card := DamageCard.new()
	card.effect_id = "ruptured_engine"
	card.title = "Ruptured Engine"
	card.timing = "persistent"
	card.trait_type = "Ship"
	card.effect_text = "After maneuvering at speed greater than 1, suffer 1 damage."
	card.is_faceup = true
	return card.serialize()


## Builds a serialized immediate damage card (Structural Damage).
func _make_immediate_card_data() -> Dictionary:
	var card := DamageCard.new()
	card.effect_id = "structural_damage"
	card.title = "Structural Damage"
	card.timing = "immediate"
	card.trait_type = "Ship"
	card.effect_text = "Deal 1 facedown damage card."
	card.is_faceup = true
	return card.serialize()


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_round = 1
	_state.current_phase = Constants.GamePhase.SHIP
	DebugDealDamageCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("debug_deal_damage")


# ======================================================================
# Validate — happy path
# ======================================================================

func test_validate_ok_persistent() -> void:
	var idx: int = _add_ship(0)
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "ruptured_engine",
		"card_data": _make_persistent_card_data(),
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid debug damage with persistent card")


func test_validate_ok_any_phase() -> void:
	var idx: int = _add_ship(0)
	_state.current_phase = Constants.GamePhase.COMMAND
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "ruptured_engine",
		"card_data": _make_persistent_card_data(),
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept debug damage in any phase")


# ======================================================================
# Validate — rejection
# ======================================================================

func test_validate_missing_ship() -> void:
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": 99,
		"effect_id": "ruptured_engine",
		"card_data": _make_persistent_card_data(),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid ship_index")


func test_validate_invalid_owner() -> void:
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": - 1,
		"ship_index": 0,
		"effect_id": "ruptured_engine",
		"card_data": _make_persistent_card_data(),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid owner_player")


func test_validate_missing_effect_id() -> void:
	var idx: int = _add_ship(0)
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "",
		"card_data": _make_persistent_card_data(),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject empty effect_id")


func test_validate_missing_card_data() -> void:
	var idx: int = _add_ship(0)
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "ruptured_engine",
		"card_data": {},
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject empty card_data")


func test_validate_no_game_state() -> void:
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"effect_id": "ruptured_engine",
		"card_data": _make_persistent_card_data(),
	})
	assert_ne(cmd.validate(null), "",
			"Should reject null game state")


# ======================================================================
# Execute — persistent card
# ======================================================================

func test_execute_adds_faceup_card() -> void:
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	assert_eq(ship.faceup_damage.size(), 0,
			"Pre-condition: no faceup damage")
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "ruptured_engine",
		"card_data": _make_persistent_card_data(),
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(ship.faceup_damage.size(), 1,
			"Should have 1 faceup damage card")
	var card: DamageCard = ship.faceup_damage[0]
	assert_true(card.is_faceup,
			"Card should be faceup")
	assert_eq(card.effect_id, "ruptured_engine",
			"Card effect_id should match")
	assert_eq(card.title, "Ruptured Engine",
			"Card title should match")
	assert_eq(result.get("effect_id"), "ruptured_engine",
			"Result should contain effect_id")
	assert_eq(result.get("card_title"), "Ruptured Engine",
			"Result should contain card_title")
	assert_false(result.get("persistent_registered", true),
			"Ruptured Engine should not register transient runtime effects.")
	assert_eq(result.get("new_hull"), 4,
			"New hull should be hull(5) - faceup(1) = 4")


func test_execute_movement_card_does_not_register_persistent_effect() -> void:
	var idx: int = _add_ship(0)
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "ruptured_engine",
		"card_data": _make_persistent_card_data(),
	})
	var result: Dictionary = cmd.execute(_state)
	assert_false(result.get("persistent_registered", true),
			"Debug damage should not register transient runtime effects.")


# ======================================================================
# Execute — immediate (non-persistent) card
# ======================================================================

func test_execute_immediate_no_persistent_registration() -> void:
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "structural_damage",
		"card_data": _make_immediate_card_data(),
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(ship.faceup_damage.size(), 1,
			"Should have 1 faceup damage card")
	assert_false(result.get("persistent_registered", true),
			"Immediate card should not register persistent effect")


# ======================================================================
# Execute — hull calculation
# ======================================================================

func test_execute_hull_decreases() -> void:
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	# Add a pre-existing facedown card to test hull math.
	var existing := DamageCard.create("Ship", "Existing")
	ship.add_facedown_damage(existing)
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "ruptured_engine",
		"card_data": _make_persistent_card_data(),
	})
	var result: Dictionary = cmd.execute(_state)
	# hull(5) - facedown(1) - faceup(1) = 3
	assert_eq(result.get("new_hull"), 3,
			"Hull should account for all existing damage")


# ======================================================================
# Serialize / Deserialize roundtrip
# ======================================================================

func test_roundtrip() -> void:
	var idx: int = _add_ship(0)
	var card_data: Dictionary = _make_persistent_card_data()
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": idx,
		"effect_id": "ruptured_engine",
		"card_data": card_data,
	})
	cmd.sequence = 55
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored,
			"Deserialized command should not be null")
	assert_is(restored, DebugDealDamageCommand,
			"Should deserialize to DebugDealDamageCommand")
	assert_eq(restored.player_index, 0,
			"Player index should roundtrip")
	assert_eq(restored.sequence, 55,
			"Sequence should roundtrip")
	assert_eq(restored.payload.get("effect_id"), "ruptured_engine",
			"effect_id should roundtrip")
	assert_eq(restored.payload.get("owner_player"), 0,
			"owner_player should roundtrip")
	assert_eq(restored.payload.get("ship_index"), idx,
			"ship_index should roundtrip")
	var restored_card: Dictionary = restored.payload.get("card_data", {})
	assert_false(restored_card.is_empty(),
			"card_data should roundtrip")
	assert_eq(restored_card.get("effect_id"), "ruptured_engine",
			"card_data.effect_id should roundtrip")
