## Tests for P4 RepairActionCommand.
##
## Covers: validate (happy + rejection) for all three action types,
## execute for move_shields, recover_shields, repair_hull,
## serialize/deserialize roundtrip.
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
	data.engineering_value = 3
	return data


## Creates a ShipInstance and adds it to the player's fleet.
## Returns the ship index.
func _add_ship(player: int) -> int:
	var ship := ShipInstance.create_from_data(
			"test_ship", _make_ship_data(), 2, player)
	var ps: PlayerState = _state.get_player_state(player)
	ps.ships.append(ship)
	return ps.ships.size() - 1


## Creates a facedown DamageCard and adds it to the ship.
func _add_facedown_card(ship: ShipInstance, card_title: String) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", card_title)
	card.is_faceup = false
	ship.facedown_damage.append(card)
	return card


## Creates a faceup DamageCard and adds it to the ship.
func _add_faceup_card(ship: ShipInstance, card_title: String) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", card_title)
	card.is_faceup = true
	card.timing = "persistent"
	card.effect_id = card_title.to_lower().replace(" ", "_")
	ship.faceup_damage.append(card)
	return card


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_round = 1
	_state.current_phase = Constants.GamePhase.SHIP
	_state.damage_deck = DamageDeck.new()
	_state.damage_deck.initialize()
	RepairActionCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("repair_action")


# ======================================================================
# Validate — move_shields
# ======================================================================

func test_validate_move_shields_ok() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	ps.ships[idx].current_shields["REAR"] = 0 # below max of 1
	var cmd := RepairActionCommand.new(0, {
		"action_type": "move_shields",
		"owner_player": 0,
		"ship_index": idx,
		"from_zone": "FRONT",
		"to_zone": "REAR",
	})
	assert_eq(cmd.validate(_state), "",
			"move_shields should validate when source has shields and target below max")


func test_validate_move_shields_wrong_phase() -> void:
	var idx: int = _add_ship(0)
	_state.current_phase = Constants.GamePhase.COMMAND
	var cmd := RepairActionCommand.new(0, {
		"action_type": "move_shields",
		"owner_player": 0,
		"ship_index": idx,
		"from_zone": "FRONT",
		"to_zone": "REAR",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when not in Ship Phase")


func test_validate_move_shields_same_zone() -> void:
	var idx: int = _add_ship(0)
	var cmd := RepairActionCommand.new(0, {
		"action_type": "move_shields",
		"owner_player": 0,
		"ship_index": idx,
		"from_zone": "FRONT",
		"to_zone": "FRONT",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject same source and target zone")


func test_validate_move_shields_no_source_shields() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	ps.ships[idx].current_shields["LEFT"] = 0
	var cmd := RepairActionCommand.new(0, {
		"action_type": "move_shields",
		"owner_player": 0,
		"ship_index": idx,
		"from_zone": "LEFT",
		"to_zone": "REAR",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when source zone has 0 shields")


func test_validate_move_shields_target_at_max() -> void:
	var idx: int = _add_ship(0)
	var cmd := RepairActionCommand.new(0, {
		"action_type": "move_shields",
		"owner_player": 0,
		"ship_index": idx,
		"from_zone": "LEFT",
		"to_zone": "FRONT",
	})
	# FRONT shields start at max (3/3)
	assert_ne(cmd.validate(_state), "",
			"Should reject when target zone is at max shields")


func test_validate_move_shields_ship_not_found() -> void:
	var cmd := RepairActionCommand.new(0, {
		"action_type": "move_shields",
		"owner_player": 0,
		"ship_index": 99,
		"from_zone": "FRONT",
		"to_zone": "REAR",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when ship index is out of bounds")


func test_validate_move_shields_invalid_zone() -> void:
	var idx: int = _add_ship(0)
	var cmd := RepairActionCommand.new(0, {
		"action_type": "move_shields",
		"owner_player": 0,
		"ship_index": idx,
		"from_zone": "BOGUS",
		"to_zone": "REAR",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid zone name")


# ======================================================================
# Validate — recover_shields
# ======================================================================

func test_validate_recover_shields_ok() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	ps.ships[idx].current_shields["FRONT"] = 1 # below max of 3
	var cmd := RepairActionCommand.new(0, {
		"action_type": "recover_shields",
		"owner_player": 0,
		"ship_index": idx,
		"zone": "FRONT",
	})
	assert_eq(cmd.validate(_state), "",
			"recover_shields should validate when zone below max")


func test_validate_recover_shields_at_max() -> void:
	var idx: int = _add_ship(0)
	var cmd := RepairActionCommand.new(0, {
		"action_type": "recover_shields",
		"owner_player": 0,
		"ship_index": idx,
		"zone": "FRONT",
	})
	# FRONT starts at 3/3
	assert_ne(cmd.validate(_state), "",
			"Should reject when zone is already at max shields")


func test_validate_recover_shields_invalid_zone() -> void:
	var idx: int = _add_ship(0)
	var cmd := RepairActionCommand.new(0, {
		"action_type": "recover_shields",
		"owner_player": 0,
		"ship_index": idx,
		"zone": "NOWHERE",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid zone name")


# ======================================================================
# Validate — repair_hull
# ======================================================================

func test_validate_repair_hull_ok_facedown() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	_add_facedown_card(ps.ships[idx], "Structural Damage")
	var cmd := RepairActionCommand.new(0, {
		"action_type": "repair_hull",
		"owner_player": 0,
		"ship_index": idx,
		"card_is_faceup": false,
		"card_index": 0,
	})
	assert_eq(cmd.validate(_state), "",
			"repair_hull should validate for valid facedown card index")


func test_validate_repair_hull_ok_faceup() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	_add_faceup_card(ps.ships[idx], "Structural Damage")
	var cmd := RepairActionCommand.new(0, {
		"action_type": "repair_hull",
		"owner_player": 0,
		"ship_index": idx,
		"card_is_faceup": true,
		"card_index": 0,
	})
	assert_eq(cmd.validate(_state), "",
			"repair_hull should validate for valid faceup card index")


func test_validate_repair_hull_bad_index() -> void:
	var idx: int = _add_ship(0)
	var cmd := RepairActionCommand.new(0, {
		"action_type": "repair_hull",
		"owner_player": 0,
		"ship_index": idx,
		"card_is_faceup": false,
		"card_index": 5,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when card index is out of bounds")


func test_validate_repair_hull_negative_index() -> void:
	var idx: int = _add_ship(0)
	var cmd := RepairActionCommand.new(0, {
		"action_type": "repair_hull",
		"owner_player": 0,
		"ship_index": idx,
		"card_is_faceup": false,
		"card_index": - 1,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject negative card index")


# ======================================================================
# Validate — unknown action type
# ======================================================================

func test_validate_unknown_action_type() -> void:
	var idx: int = _add_ship(0)
	var cmd := RepairActionCommand.new(0, {
		"action_type": "bogus",
		"owner_player": 0,
		"ship_index": idx,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject unknown action_type")


# ======================================================================
# Execute — move_shields
# ======================================================================

func test_execute_move_shields() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	# FRONT=3, REAR=1 → after move: FRONT=2, REAR=2 (max REAR=1 but we
	# lower FRONT shields first to make room)
	# Actually REAR max is 1 and REAR is already 1. Use LEFT→REAR where
	# REAR < max doesn't hold. Let's reduce REAR to 0 first.
	ship.current_shields["REAR"] = 0
	var cmd := RepairActionCommand.new(0, {
		"action_type": "move_shields",
		"owner_player": 0,
		"ship_index": idx,
		"from_zone": "FRONT",
		"to_zone": "REAR",
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("action_type"), "move_shields",
			"Result should echo action_type")
	assert_eq(int(ship.current_shields["FRONT"]), 2,
			"FRONT should drop from 3 to 2")
	assert_eq(int(ship.current_shields["REAR"]), 1,
			"REAR should rise from 0 to 1")
	assert_eq(int(result.get("from_shields")), 2,
			"Result should report new FRONT shield value")
	assert_eq(int(result.get("to_shields")), 1,
			"Result should report new REAR shield value")


# ======================================================================
# Execute — recover_shields
# ======================================================================

func test_execute_recover_shields() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	ship.current_shields["LEFT"] = 0 # max is 2
	var cmd := RepairActionCommand.new(0, {
		"action_type": "recover_shields",
		"owner_player": 0,
		"ship_index": idx,
		"zone": "LEFT",
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("action_type"), "recover_shields",
			"Result should echo action_type")
	assert_eq(int(ship.current_shields["LEFT"]), 1,
			"LEFT should rise from 0 to 1")
	assert_eq(int(result.get("new_shields")), 1,
			"Result should report new shield value")


# ======================================================================
# Execute — repair_hull (facedown)
# ======================================================================

func test_execute_repair_hull_facedown() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	_add_facedown_card(ship, "Structural Damage")
	assert_eq(ship.facedown_damage.size(), 1, "Precondition: 1 facedown card")
	var cmd := RepairActionCommand.new(0, {
		"action_type": "repair_hull",
		"owner_player": 0,
		"ship_index": idx,
		"card_is_faceup": false,
		"card_index": 0,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("action_type"), "repair_hull",
			"Result should echo action_type")
	assert_eq(ship.facedown_damage.size(), 0,
			"Facedown card should be removed")
	assert_eq(int(result.get("new_hull")), 5,
			"Hull should be fully restored (5 - 0 = 5)")


func test_execute_repair_hull_faceup() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	_add_faceup_card(ship, "Structural Damage")
	assert_eq(ship.faceup_damage.size(), 1, "Precondition: 1 faceup card")
	var cmd := RepairActionCommand.new(0, {
		"action_type": "repair_hull",
		"owner_player": 0,
		"ship_index": idx,
		"card_is_faceup": true,
		"card_index": 0,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(ship.faceup_damage.size(), 0,
			"Faceup card should be removed")
	assert_eq(result.get("card_title"), "Structural Damage",
			"Result should include card title")
	assert_true(result.get("card_is_faceup", false) as bool,
			"Result should indicate faceup")


func test_execute_repair_hull_discard_to_deck() -> void:
	var idx: int = _add_ship(0)
	var ps: PlayerState = _state.get_player_state(0)
	var ship: ShipInstance = ps.ships[idx]
	_add_facedown_card(ship, "Hull Breach")
	var initial_discard: int = _state.damage_deck.get_discard_count()
	var cmd := RepairActionCommand.new(0, {
		"action_type": "repair_hull",
		"owner_player": 0,
		"ship_index": idx,
		"card_is_faceup": false,
		"card_index": 0,
	})
	cmd.execute(_state)
	assert_eq(_state.damage_deck.get_discard_count(), initial_discard + 1,
			"Discard pile should grow by 1")


# ======================================================================
# Serialize / Deserialize roundtrip
# ======================================================================

func test_serialize_deserialize_move_shields() -> void:
	var cmd := RepairActionCommand.new(0, {
		"action_type": "move_shields",
		"owner_player": 0,
		"ship_index": 0,
		"from_zone": "FRONT",
		"to_zone": "REAR",
	})
	cmd.sequence = 42
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Deserialized command should not be null")
	assert_eq(restored.command_type, "repair_action",
			"Type should match")
	assert_eq(restored.player_index, 0, "Player should match")
	assert_eq(restored.sequence, 42, "Sequence should match")
	assert_eq(restored.payload.get("action_type"), "move_shields",
			"action_type should survive roundtrip")
	assert_eq(restored.payload.get("from_zone"), "FRONT",
			"from_zone should survive roundtrip")
	assert_eq(restored.payload.get("to_zone"), "REAR",
			"to_zone should survive roundtrip")


func test_serialize_deserialize_repair_hull() -> void:
	var cmd := RepairActionCommand.new(1, {
		"action_type": "repair_hull",
		"owner_player": 1,
		"ship_index": 0,
		"card_is_faceup": true,
		"card_index": 2,
	})
	cmd.sequence = 7
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Deserialized command should not be null")
	assert_eq(restored.payload.get("action_type"), "repair_hull",
			"action_type should survive roundtrip")
	assert_eq(restored.payload.get("card_is_faceup"), true,
			"card_is_faceup should survive roundtrip")
	assert_eq(int(restored.payload.get("card_index")), 2,
			"card_index should survive roundtrip")
