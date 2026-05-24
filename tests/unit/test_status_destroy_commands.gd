## Tests for §4.6 P2 status-phase and destruction command subclasses.
##
## Covers: StatusPhaseCleanupCommand, DestroyUnitCommand.
## Each command is tested for validate (happy + rejection), execute,
## and serialize/deserialize roundtrip.
extends GutTest


var _state: GameState


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_round = 1
	_state.current_phase = Constants.GamePhase.STATUS
	StatusPhaseCleanupCommand.register()
	DestroyUnitCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("status_phase_cleanup")
	GameCommand._registry.erase("destroy_unit")


## Creates a minimal ShipInstance with defense tokens.
func _make_ship(owner: int, token_count: int = 2) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = 5
	data.point_cost = 50
	data.shields = {"FRONT": 2, "LEFT": 1, "RIGHT": 1, "REAR": 1}
	data.max_speed = 2
	data.engineering_value = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1]]
	var tokens: Array = []
	for j: int in range(token_count):
		tokens.append("EVADE")
	data.defense_tokens = tokens
	var si: ShipInstance = ShipInstance.create_from_data(
			"test_ship", data, 2, owner)
	return si


## Creates a minimal SquadronInstance with one defense token.
func _make_squadron(owner: int) -> SquadronInstance:
	var data: SquadronData = SquadronData.new()
	data.hull = 3
	data.point_cost = 10
	data.speed = 3
	data.defense_tokens = ["BRACE"]
	var sqi: SquadronInstance = SquadronInstance.create_from_data(
			"test_squad", data, owner)
	return sqi


# ======================================================================
# StatusPhaseCleanupCommand — validate
# ======================================================================

func test_cleanup_validate_ok_in_status_phase() -> void:
	var cmd := StatusPhaseCleanupCommand.new(0, {})
	assert_eq(cmd.validate(_state), "",
			"Should accept cleanup during STATUS phase.")


func test_cleanup_validate_rejects_non_status_phase() -> void:
	_state.current_phase = Constants.GamePhase.COMMAND
	var cmd := StatusPhaseCleanupCommand.new(0, {})
	assert_ne(cmd.validate(_state), "",
			"Should reject cleanup outside STATUS phase.")


func test_cleanup_validate_rejects_ship_phase() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var cmd := StatusPhaseCleanupCommand.new(0, {})
	assert_ne(cmd.validate(_state), "",
			"Should reject cleanup during SHIP phase.")


func test_cleanup_validate_rejects_null_state() -> void:
	var cmd := StatusPhaseCleanupCommand.new(0, {})
	assert_ne(cmd.validate(null), "",
			"Should reject null game state.")


# ======================================================================
# StatusPhaseCleanupCommand — execute: token readying
# ======================================================================

func test_cleanup_readies_exhausted_ship_tokens() -> void:
	var ship: ShipInstance = _make_ship(0)
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	_state.get_player_state(0).ships.append(ship)

	var cmd := StatusPhaseCleanupCommand.new(0, {})
	cmd.execute(_state)

	assert_eq(int(ship.defense_tokens[0]["state"]),
			int(Constants.DefenseTokenState.READY),
			"Exhausted token should be readied (ST-001).")


func test_cleanup_does_not_ready_discarded_ship_tokens() -> void:
	var ship: ShipInstance = _make_ship(0)
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.DISCARDED
	_state.get_player_state(0).ships.append(ship)

	var cmd := StatusPhaseCleanupCommand.new(0, {})
	cmd.execute(_state)

	assert_eq(int(ship.defense_tokens[0]["state"]),
			int(Constants.DefenseTokenState.DISCARDED),
			"Discarded token should stay discarded.")


func test_cleanup_readies_exhausted_squadron_tokens() -> void:
	var squad: SquadronInstance = _make_squadron(1)
	squad.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	_state.get_player_state(1).squadrons.append(squad)

	var cmd := StatusPhaseCleanupCommand.new(0, {})
	cmd.execute(_state)

	assert_eq(int(squad.defense_tokens[0]["state"]),
			int(Constants.DefenseTokenState.READY),
			"Squadron exhausted token should be readied.")


# ======================================================================
# StatusPhaseCleanupCommand — execute: activation reset
# ======================================================================

func test_cleanup_resets_ship_activation() -> void:
	var ship: ShipInstance = _make_ship(0)
	ship.activated_this_round = true
	_state.get_player_state(0).ships.append(ship)

	var cmd := StatusPhaseCleanupCommand.new(0, {})
	cmd.execute(_state)

	assert_false(ship.activated_this_round,
			"Ship activation should be reset (ST-004).")


func test_cleanup_resets_squadron_activation() -> void:
	var squad: SquadronInstance = _make_squadron(0)
	squad.activated_this_round = true
	_state.get_player_state(0).squadrons.append(squad)

	var cmd := StatusPhaseCleanupCommand.new(0, {})
	cmd.execute(_state)

	assert_false(squad.activated_this_round,
			"Squadron activation should be reset (ST-004).")


# ======================================================================
# StatusPhaseCleanupCommand — execute: skip destroyed units
# ======================================================================

func test_cleanup_skips_destroyed_ship() -> void:
	var ship: ShipInstance = _make_ship(0)
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	ship.activated_this_round = true
	ship.mark_destroyed()
	_state.get_player_state(0).ships.append(ship)

	var cmd := StatusPhaseCleanupCommand.new(0, {})
	cmd.execute(_state)

	assert_eq(int(ship.defense_tokens[0]["state"]),
			int(Constants.DefenseTokenState.EXHAUSTED),
			"Destroyed ship tokens should NOT be readied.")
	assert_true(ship.activated_this_round,
			"Destroyed ship activation should NOT be reset.")


func test_cleanup_skips_destroyed_squadron() -> void:
	var squad: SquadronInstance = _make_squadron(1)
	squad.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	squad.activated_this_round = true
	squad.mark_destroyed()
	_state.get_player_state(1).squadrons.append(squad)

	var cmd := StatusPhaseCleanupCommand.new(0, {})
	cmd.execute(_state)

	assert_eq(int(squad.defense_tokens[0]["state"]),
			int(Constants.DefenseTokenState.EXHAUSTED),
			"Destroyed squadron tokens should NOT be readied.")


# ======================================================================
# StatusPhaseCleanupCommand — execute: spent history
# ======================================================================

func test_cleanup_clears_spent_dial_history() -> void:
	var ship: ShipInstance = _make_ship(0)
	_state.get_player_state(0).ships.append(ship)
	# Simulate a spent dial entry.
	ship.command_dial_stack._spent_history.append(
			{"command": int(Constants.CommandType.NAVIGATE)})

	var cmd := StatusPhaseCleanupCommand.new(0, {})
	cmd.execute(_state)

	assert_eq(ship.command_dial_stack._spent_history.size(), 0,
			"Spent history should be cleared after cleanup.")


# ======================================================================
# StatusPhaseCleanupCommand — execute: result dictionary
# ======================================================================

func test_cleanup_returns_counts() -> void:
	var ship: ShipInstance = _make_ship(0)
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	ship.activated_this_round = true
	_state.get_player_state(0).ships.append(ship)
	var squad: SquadronInstance = _make_squadron(1)
	squad.activated_this_round = true
	_state.get_player_state(1).squadrons.append(squad)

	var cmd := StatusPhaseCleanupCommand.new(0, {})
	var result: Dictionary = cmd.execute(_state)

	assert_eq(result["ships_readied"], 1,
			"Should report 1 ship readied.")
	assert_eq(result["squadrons_readied"], 1,
			"Should report 1 squadron readied.")
	assert_true(result["activations_reset"] >= 2,
			"Should report at least 2 activations reset.")


# ======================================================================
# StatusPhaseCleanupCommand — serialize / deserialize
# ======================================================================

func test_cleanup_serialize_roundtrip() -> void:
	var cmd := StatusPhaseCleanupCommand.new(0, {})
	cmd.sequence = 10
	var data: Dictionary = cmd.serialize()
	assert_eq(data["type"], "status_phase_cleanup",
			"Serialized type should be status_phase_cleanup.")
	assert_eq(data["player"], 0,
			"Serialized player should be 0.")
	assert_eq(data["sequence"], 10,
			"Serialized sequence should be 10.")


func test_cleanup_deserialize() -> void:
	var data: Dictionary = {
		"type": "status_phase_cleanup",
		"player": 1,
		"sequence": 3,
		"payload": {},
	}
	var cmd: GameCommand = GameCommand.deserialize(data)
	assert_not_null(cmd, "Deserialized command should not be null.")
	assert_is(cmd, StatusPhaseCleanupCommand,
			"Deserialized command should be StatusPhaseCleanupCommand.")
	assert_eq(cmd.player_index, 1,
			"Player index should be 1.")
	assert_eq(cmd.sequence, 3,
			"Sequence should be 3.")


# ======================================================================
# DestroyUnitCommand — validate
# ======================================================================

func test_destroy_validate_ok() -> void:
	var ship: ShipInstance = _make_ship(0)
	_state.get_player_state(0).ships.append(ship)
	var cmd := DestroyUnitCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid ship destruction.")


func test_destroy_validate_rejects_missing_owner() -> void:
	var cmd := DestroyUnitCommand.new(0, {"ship_index": 0})
	assert_ne(cmd.validate(_state), "",
			"Should reject missing owner_player.")


func test_destroy_validate_rejects_missing_index() -> void:
	var cmd := DestroyUnitCommand.new(0, {"owner_player": 0})
	assert_ne(cmd.validate(_state), "",
			"Should reject missing ship_index.")


func test_destroy_validate_rejects_invalid_ship() -> void:
	var cmd := DestroyUnitCommand.new(0, {
		"owner_player": 0,
		"ship_index": 99,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject non-existent ship.")


func test_destroy_validate_rejects_null_state() -> void:
	var cmd := DestroyUnitCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
	})
	assert_ne(cmd.validate(null), "",
			"Should reject null game state.")


# ======================================================================
# DestroyUnitCommand — execute
# ======================================================================

func test_destroy_clears_damage_cards() -> void:
	var ship: ShipInstance = _make_ship(0)
	ship.add_facedown_damage(DamageCard.create("Ship", "Structural Damage"))
	ship.add_faceup_damage(DamageCard.create("Ship", "Ruptured Engine"))
	_state.get_player_state(0).ships.append(ship)

	var deck: DamageDeck = DamageDeck.new()
	deck.initialize()
	_state.damage_deck = deck

	var cmd := DestroyUnitCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
	})
	var result: Dictionary = cmd.execute(_state)

	assert_eq(ship.facedown_damage.size(), 0,
			"Facedown damage should be cleared.")
	assert_eq(ship.faceup_damage.size(), 0,
			"Faceup damage should be cleared.")
	assert_eq(result["cards_returned"], 2,
			"Should report 2 cards returned.")
	assert_eq(result["data_key"], "test_ship",
			"Should report ship data_key.")


func test_destroy_returns_cards_to_deck() -> void:
	var ship: ShipInstance = _make_ship(0)
	var card: DamageCard = DamageCard.create("Ship", "Structural Damage")
	ship.add_facedown_damage(card)
	_state.get_player_state(0).ships.append(ship)

	var deck: DamageDeck = DamageDeck.new()
	deck.initialize()
	var initial_discard: int = deck._discard_pile.size()
	_state.damage_deck = deck

	var cmd := DestroyUnitCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
	})
	cmd.execute(_state)

	assert_eq(deck._discard_pile.size(), initial_discard + 1,
			"Discard pile should grow by 1 (DM-030).")


# ======================================================================
# DestroyUnitCommand — serialize / deserialize
# ======================================================================

func test_destroy_serialize_roundtrip() -> void:
	var cmd := DestroyUnitCommand.new(1, {
		"owner_player": 1,
		"ship_index": 0,
	})
	cmd.sequence = 77
	var data: Dictionary = cmd.serialize()
	assert_eq(data["type"], "destroy_unit",
			"Serialized type should be destroy_unit.")
	assert_eq(data["player"], 1,
			"Serialized player should be 1.")
	assert_eq(data["payload"]["owner_player"], 1,
			"Payload owner_player should be 1.")
	assert_eq(data["payload"]["ship_index"], 0,
			"Payload ship_index should be 0.")


func test_destroy_deserialize() -> void:
	var data: Dictionary = {
		"type": "destroy_unit",
		"player": 0,
		"sequence": 15,
		"payload": {"owner_player": 0, "ship_index": 1},
	}
	var cmd: GameCommand = GameCommand.deserialize(data)
	assert_not_null(cmd, "Deserialized command should not be null.")
	assert_is(cmd, DestroyUnitCommand,
			"Deserialized command should be DestroyUnitCommand.")
	assert_eq(cmd.player_index, 0,
			"Player index should be 0.")
	assert_eq(cmd.payload["ship_index"], 1,
			"Payload ship_index should be 1.")
