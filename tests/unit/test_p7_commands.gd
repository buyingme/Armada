## Tests for P7 commands: DiscardTokenCommand, RevealDialCommand.
##
## Covers: validate (happy + rejection), execute, serialize/deserialize
## roundtrip for both commands.
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


## Adds tokens to a ship to cause overflow (3 tokens > command_value 2).
func _overflow_ship(player: int, ship_index: int) -> void:
	var ship: ShipInstance = _state.get_ship(player, ship_index)
	ship.command_tokens.force_add_token(Constants.CommandType.NAVIGATE)
	ship.command_tokens.force_add_token(Constants.CommandType.REPAIR)
	ship.command_tokens.force_add_token(
			Constants.CommandType.CONCENTRATE_FIRE)


## Pushes hidden dials onto a ship's stack for testing.
func _push_dials(player: int, ship_index: int,
		commands: Array[int]) -> void:
	var ship: ShipInstance = _state.get_ship(player, ship_index)
	ship.command_dial_stack.assign_dials(commands, _state.current_round)


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_round = 1
	_state.current_phase = Constants.GamePhase.SHIP
	DiscardTokenCommand.register()
	RevealDialCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("discard_token")
	GameCommand._registry.erase("reveal_dial")


# ======================================================================
# DiscardTokenCommand — validate
# ======================================================================

func test_discard_token_validate_ok() -> void:
	var idx: int = _add_ship(0)
	_overflow_ship(0, idx)
	var cmd := DiscardTokenCommand.new(0, {
		"ship_index": idx,
		"token_type": int(Constants.CommandType.NAVIGATE),
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid discard when ship is in overflow")


func test_discard_token_validate_missing_ship() -> void:
	var cmd := DiscardTokenCommand.new(0, {
		"ship_index": 99,
		"token_type": int(Constants.CommandType.NAVIGATE),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid ship_index")


func test_discard_token_validate_no_such_token() -> void:
	var idx: int = _add_ship(0)
	_overflow_ship(0, idx)
	var cmd := DiscardTokenCommand.new(0, {
		"ship_index": idx,
		"token_type": int(Constants.CommandType.SQUADRON),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject token type the ship does not hold")


func test_discard_token_validate_not_overflow() -> void:
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_tokens.force_add_token(Constants.CommandType.NAVIGATE)
	var cmd := DiscardTokenCommand.new(0, {
		"ship_index": idx,
		"token_type": int(Constants.CommandType.NAVIGATE),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject discard when ship is not in overflow")


func test_discard_token_validate_missing_payload() -> void:
	var cmd := DiscardTokenCommand.new(0, {})
	assert_ne(cmd.validate(_state), "",
			"Should reject missing payload keys")


# ======================================================================
# DiscardTokenCommand — execute
# ======================================================================

func test_discard_token_execute_removes_token() -> void:
	var idx: int = _add_ship(0)
	_overflow_ship(0, idx)
	var ship: ShipInstance = _state.get_ship(0, idx)
	assert_eq(ship.command_tokens.get_token_count(), 3,
			"Pre-condition: 3 tokens (overflow)")
	var cmd := DiscardTokenCommand.new(0, {
		"ship_index": idx,
		"token_type": int(Constants.CommandType.REPAIR),
	})
	var result: Dictionary = cmd.execute(_state)
	assert_true(result.get("discarded", false),
			"Should confirm token was discarded")
	assert_eq(ship.command_tokens.get_token_count(), 2,
			"Should have 2 tokens after discard")
	assert_false(ship.command_tokens.has_token(
			Constants.CommandType.REPAIR),
			"REPAIR token should be gone")
	assert_true(ship.command_tokens.has_token(
			Constants.CommandType.NAVIGATE),
			"NAVIGATE token should remain")


# ======================================================================
# DiscardTokenCommand — serialize/deserialize
# ======================================================================

func test_discard_token_roundtrip() -> void:
	var idx: int = _add_ship(0)
	_overflow_ship(0, idx)
	var cmd := DiscardTokenCommand.new(0, {
		"ship_index": idx,
		"token_type": int(Constants.CommandType.NAVIGATE),
	})
	cmd.sequence = 42
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored,
			"Deserialized command should not be null")
	assert_is(restored, DiscardTokenCommand,
			"Should deserialize to DiscardTokenCommand")
	assert_eq(restored.player_index, 0,
			"Player index should roundtrip")
	assert_eq(restored.payload.get("ship_index"), idx,
			"ship_index should roundtrip")
	assert_eq(restored.payload.get("token_type"),
			int(Constants.CommandType.NAVIGATE),
			"token_type should roundtrip")
	assert_eq(restored.sequence, 42,
			"Sequence number should roundtrip")


# ======================================================================
# RevealDialCommand — validate (reveal)
# ======================================================================

func test_reveal_dial_validate_ok() -> void:
	var idx: int = _add_ship(0)
	_push_dials(0, idx, [int(Constants.CommandType.NAVIGATE),
			int(Constants.CommandType.REPAIR)])
	var cmd := RevealDialCommand.new(0, {
		"ship_index": idx,
		"action": "reveal",
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid reveal")


func test_reveal_dial_validate_wrong_phase() -> void:
	var idx: int = _add_ship(0)
	_push_dials(0, idx, [int(Constants.CommandType.NAVIGATE),
			int(Constants.CommandType.REPAIR)])
	_state.current_phase = Constants.GamePhase.COMMAND
	var cmd := RevealDialCommand.new(0, {
		"ship_index": idx,
		"action": "reveal",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when not in Ship Phase")


func test_reveal_dial_validate_no_hidden_dials() -> void:
	var idx: int = _add_ship(0)
	var cmd := RevealDialCommand.new(0, {
		"ship_index": idx,
		"action": "reveal",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when no hidden dials")


func test_reveal_dial_validate_already_revealed() -> void:
	var idx: int = _add_ship(0)
	_push_dials(0, idx, [int(Constants.CommandType.NAVIGATE),
			int(Constants.CommandType.REPAIR)])
	_state.get_ship(0, idx).command_dial_stack.reveal_top()
	var cmd := RevealDialCommand.new(0, {
		"ship_index": idx,
		"action": "reveal",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when top dial is already revealed")


func test_reveal_dial_validate_invalid_action() -> void:
	var idx: int = _add_ship(0)
	_push_dials(0, idx, [int(Constants.CommandType.NAVIGATE),
			int(Constants.CommandType.REPAIR)])
	var cmd := RevealDialCommand.new(0, {
		"ship_index": idx,
		"action": "flip",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid action string")


func test_reveal_dial_validate_missing_ship() -> void:
	var cmd := RevealDialCommand.new(0, {
		"ship_index": 99,
		"action": "reveal",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid ship_index")


# ======================================================================
# RevealDialCommand — validate (unreveal)
# ======================================================================

func test_unreveal_dial_validate_ok() -> void:
	var idx: int = _add_ship(0)
	_push_dials(0, idx, [int(Constants.CommandType.NAVIGATE),
			int(Constants.CommandType.REPAIR)])
	_state.get_ship(0, idx).command_dial_stack.reveal_top()
	var cmd := RevealDialCommand.new(0, {
		"ship_index": idx,
		"action": "unreveal",
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid unreveal")


func test_unreveal_dial_validate_no_revealed() -> void:
	var idx: int = _add_ship(0)
	_push_dials(0, idx, [int(Constants.CommandType.NAVIGATE),
			int(Constants.CommandType.REPAIR)])
	var cmd := RevealDialCommand.new(0, {
		"ship_index": idx,
		"action": "unreveal",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when no revealed dial exists")


# ======================================================================
# RevealDialCommand — execute (reveal)
# ======================================================================

func test_reveal_dial_execute_reveals_top() -> void:
	var idx: int = _add_ship(0)
	_push_dials(0, idx, [int(Constants.CommandType.REPAIR),
			int(Constants.CommandType.NAVIGATE)])
	var ship: ShipInstance = _state.get_ship(0, idx)
	assert_eq(ship.command_dial_stack.get_hidden_count(), 2,
			"Pre-condition: 2 hidden dials")
	var cmd := RevealDialCommand.new(0, {
		"ship_index": idx,
		"action": "reveal",
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("command"), int(Constants.CommandType.REPAIR),
			"Should return the revealed dial's command type")
	assert_eq(result.get("action"), "reveal",
			"Action should be 'reveal'")
	assert_false(ship.command_dial_stack.get_revealed_dial().is_empty(),
			"Top dial should now be revealed")
	assert_eq(ship.command_dial_stack.get_hidden_count(), 1,
			"One hidden dial should remain")


# ======================================================================
# RevealDialCommand — execute (unreveal)
# ======================================================================

func test_unreveal_dial_execute_hides_top() -> void:
	var idx: int = _add_ship(0)
	_push_dials(0, idx, [int(Constants.CommandType.NAVIGATE),
			int(Constants.CommandType.REPAIR)])
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_dial_stack.reveal_top()
	assert_false(ship.command_dial_stack.get_revealed_dial().is_empty(),
			"Pre-condition: dial is revealed")
	var cmd := RevealDialCommand.new(0, {
		"ship_index": idx,
		"action": "unreveal",
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("command"), int(Constants.CommandType.NAVIGATE),
			"Should return the unrevealed dial's command type")
	assert_eq(result.get("action"), "unreveal",
			"Action should be 'unreveal'")
	assert_true(ship.command_dial_stack.get_revealed_dial().is_empty(),
			"Top dial should now be hidden")
	assert_eq(ship.command_dial_stack.get_hidden_count(), 2,
			"Hidden count should be restored to 2")


# ======================================================================
# RevealDialCommand — serialize/deserialize
# ======================================================================

func test_reveal_dial_roundtrip() -> void:
	var idx: int = _add_ship(0)
	var cmd := RevealDialCommand.new(0, {
		"ship_index": idx,
		"action": "reveal",
	})
	cmd.sequence = 7
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored,
			"Deserialized command should not be null")
	assert_is(restored, RevealDialCommand,
			"Should deserialize to RevealDialCommand")
	assert_eq(restored.player_index, 0,
			"Player index should roundtrip")
	assert_eq(restored.payload.get("ship_index"), idx,
			"ship_index should roundtrip")
	assert_eq(restored.payload.get("action"), "reveal",
			"action should roundtrip")
	assert_eq(restored.sequence, 7,
			"Sequence number should roundtrip")


func test_unreveal_dial_roundtrip() -> void:
	var idx: int = _add_ship(0)
	var cmd := RevealDialCommand.new(0, {
		"ship_index": idx,
		"action": "unreveal",
	})
	cmd.sequence = 8
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored,
			"Deserialized command should not be null")
	assert_is(restored, RevealDialCommand,
			"Should deserialize to RevealDialCommand")
	assert_eq(restored.payload.get("action"), "unreveal",
			"action should roundtrip as 'unreveal'")
