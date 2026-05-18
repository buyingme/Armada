## Tests for concrete GameCommand subclasses (Tier 1).
##
## Covers: AssignDialCommand, ActivateShipCommand, EndActivationCommand,
## ConvertDialToTokenCommand, ActivateSquadronCommand, SpendTokenCommand,
## SpendDialCommand.
## Each command is tested for validate (happy + rejection) and execute.
extends GutTest


var _state: GameState


## Creates a minimal ShipData for test fixtures.
func _make_ship_data(command_value: int = 2) -> ShipData:
	var data := ShipData.new()
	data.hull = 4
	data.max_speed = 3
	data.command_value = command_value
	data.shields = {"front": 2, "left": 1, "right": 1, "rear": 1}
	data.defense_tokens = []
	data.navigation_chart = [[1], [1, 1], [0, 1, 1]]
	return data


## Creates a ShipInstance and adds it to the given player's fleet.
## Returns the ship index.
func _add_ship(player: int, cmd_val: int = 2) -> int:
	var ship := ShipInstance.create_from_data(
			"test_ship", _make_ship_data(cmd_val), 2, player)
	var ps: PlayerState = _state.get_player_state(player)
	ps.ships.append(ship)
	return ps.ships.size() - 1


## Creates a minimal SquadronInstance and adds it to the player's fleet.
## Returns the squadron index.
func _add_squadron(player: int) -> int:
	var data := SquadronData.new()
	data.hull = 3
	var sq := SquadronInstance.create_from_data(
			"test_squad", data, player)
	var ps: PlayerState = _state.get_player_state(player)
	ps.squadrons.append(sq)
	return ps.squadrons.size() - 1


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_round = 1
	# Register command types.
	AssignDialCommand.register()
	ActivateShipCommand.register()
	EndActivationCommand.register()
	ConvertDialToTokenCommand.register()
	ActivateSquadronCommand.register()
	SpendTokenCommand.register()
	SpendDialCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("assign_dials")
	GameCommand._registry.erase("activate_ship")
	GameCommand._registry.erase("end_activation")
	GameCommand._registry.erase("convert_dial_to_token")
	GameCommand._registry.erase("activate_squadron")
	GameCommand._registry.erase("spend_token")
	GameCommand._registry.erase("spend_dial")


# ======================================================================
# AssignDialCommand
# ======================================================================

func test_assign_dials_validate_ok() -> void:
	_state.current_phase = Constants.GamePhase.COMMAND
	var idx: int = _add_ship(0)
	var cmd := AssignDialCommand.new(0, {
		"ship_index": idx,
		"commands": [Constants.CommandType.NAVIGATE,
				Constants.CommandType.REPAIR],
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid dial assignment.")


func test_assign_dials_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var cmd := AssignDialCommand.new(0, {
		"ship_index": idx,
		"commands": [Constants.CommandType.NAVIGATE,
				Constants.CommandType.REPAIR],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Command Phase.")


func test_assign_dials_validate_bad_ship_index() -> void:
	_state.current_phase = Constants.GamePhase.COMMAND
	var cmd := AssignDialCommand.new(0, {
		"ship_index": 99,
		"commands": [Constants.CommandType.NAVIGATE],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid ship index.")


func test_assign_dials_validate_wrong_count() -> void:
	_state.current_phase = Constants.GamePhase.COMMAND
	var idx: int = _add_ship(0)
	# Ship needs 2 dials (command_value=2), provide 1.
	var cmd := AssignDialCommand.new(0, {
		"ship_index": idx,
		"commands": [Constants.CommandType.NAVIGATE],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject wrong dial count.")


func test_assign_dials_execute_fills_stack() -> void:
	_state.current_phase = Constants.GamePhase.COMMAND
	var idx: int = _add_ship(0)
	var cmd := AssignDialCommand.new(0, {
		"ship_index": idx,
		"commands": [Constants.CommandType.NAVIGATE,
				Constants.CommandType.REPAIR],
	})
	var result: Dictionary = cmd.execute(_state)
	assert_true(result.get("success", false),
			"Execute should return success.")
	var ship: ShipInstance = _state.get_ship(0, idx)
	assert_eq(ship.command_dial_stack.get_hidden_count(), 2,
			"Ship should have 2 hidden dials after assignment.")


func test_assign_dials_serialize_roundtrip() -> void:
	var cmd := AssignDialCommand.new(1, {
		"ship_index": 0,
		"commands": [Constants.CommandType.CONCENTRATE_FIRE],
	})
	cmd.sequence = 5
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Deserialized command should not be null.")
	assert_eq(restored.command_type, "assign_dials",
			"Restored type should match.")
	assert_eq(restored.player_index, 1,
			"Restored player should match.")
	assert_eq(restored.sequence, 5,
			"Restored sequence should match.")


# ======================================================================
# ActivateShipCommand
# ======================================================================

func test_activate_ship_validate_ok() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	# Assign dials so there's something to reveal.
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1)
	var cmd := ActivateShipCommand.new(0, {"ship_index": idx})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid ship activation.")


func test_activate_ship_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.COMMAND
	var idx: int = _add_ship(0)
	var cmd := ActivateShipCommand.new(0, {"ship_index": idx})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Ship Phase.")


func test_activate_ship_validate_already_activated() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	_state.get_ship(0, idx).activated_this_round = true
	var cmd := ActivateShipCommand.new(0, {"ship_index": idx})
	assert_ne(cmd.validate(_state), "",
			"Should reject already-activated ship.")


func test_activate_ship_validate_no_hidden_dials() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	# Empty dial stack has 0 hidden dials.
	var cmd := ActivateShipCommand.new(0, {"ship_index": idx})
	assert_ne(cmd.validate(_state), "",
			"Should reject ship with no hidden dials.")


func test_activate_ship_execute_reveals_dial() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1)
	var cmd := ActivateShipCommand.new(0, {"ship_index": idx})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("command", -1),
			int(Constants.CommandType.NAVIGATE),
			"Should reveal the top dial (NAVIGATE).")
	var revealed: Dictionary = \
			ship.command_dial_stack.get_revealed_dial()
	assert_false(revealed.is_empty(),
			"Ship should have a revealed dial after activation.")


func test_activate_ship_skip_reveal_opens_activation_without_command() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var cmd := ActivateShipCommand.new(0, {
		"ship_index": idx,
		ActivateShipCommand.PAYLOAD_SKIP_REVEAL: true,
		ActivateShipCommand.PAYLOAD_REASON: CrewPanic.EFFECT_ID,
	})
	assert_eq(cmd.validate(_state), "",
			"Skip-reveal activation should allow an empty dial stack.")
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("command", 0), -1,
			"Skip-reveal activation should not expose a command.")
	assert_true(result.get("activation_without_command", false) as bool,
			"Result should identify the no-command activation path.")
	assert_eq(_state.interaction_flow.step_id,
			Constants.InteractionStep.ACTIVATION_MODAL_OPEN,
			"Skip-reveal activation should still open activation flow.")


func test_activate_ship_serialize_roundtrip() -> void:
	var cmd := ActivateShipCommand.new(0, {"ship_index": 1})
	cmd.sequence = 3
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Deserialized command should not be null.")
	assert_eq(restored.command_type, "activate_ship",
			"Restored type should match.")


# ======================================================================
# EndActivationCommand
# ======================================================================

func test_end_activation_validate_ok() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var cmd := EndActivationCommand.new(0, {"ship_index": idx})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid end-activation.")


func test_end_activation_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.COMMAND
	var idx: int = _add_ship(0)
	var cmd := EndActivationCommand.new(0, {"ship_index": idx})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Ship Phase.")


func test_end_activation_validate_already_activated() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	_state.get_ship(0, idx).activated_this_round = true
	var cmd := EndActivationCommand.new(0, {"ship_index": idx})
	assert_ne(cmd.validate(_state), "",
			"Should reject already-activated ship.")


func test_end_activation_execute_spends_dial_marks_activated() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1)
	ship.command_dial_stack.reveal_top()
	var cmd := EndActivationCommand.new(0, {"ship_index": idx})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("spent_command", -1),
			int(Constants.CommandType.NAVIGATE),
			"Should return the spent command type.")
	assert_true(ship.activated_this_round,
			"Ship should be marked as activated.")
	assert_true(ship.command_dial_stack.get_revealed_dial().is_empty(),
			"Revealed dial should be cleared after spending.")


func test_end_activation_execute_no_revealed_dial() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	# Ship has unspent dials but none revealed.
	var ship: ShipInstance = _state.get_ship(0, idx)
	var cmd := EndActivationCommand.new(0, {"ship_index": idx})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("spent_command", -1), -1,
			"Should return -1 when no dial to spend.")
	assert_true(ship.activated_this_round,
			"Ship should still be marked activated.")


func test_end_activation_serialize_roundtrip() -> void:
	var cmd := EndActivationCommand.new(1, {"ship_index": 0})
	cmd.sequence = 7
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Deserialized command should not be null.")
	assert_eq(restored.command_type, "end_activation",
			"Restored type should match.")
	assert_eq(restored.sequence, 7,
			"Restored sequence should match.")


# ======================================================================
# ConvertDialToTokenCommand
# ======================================================================

func test_convert_dial_validate_ok() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1)
	var cmd := ConvertDialToTokenCommand.new(0, {"ship_index": idx})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid dial-to-token.")


func test_convert_dial_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.COMMAND
	var idx: int = _add_ship(0)
	var cmd := ConvertDialToTokenCommand.new(0, {"ship_index": idx})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Ship Phase.")


func test_convert_dial_validate_no_dials() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var cmd := ConvertDialToTokenCommand.new(0, {"ship_index": idx})
	assert_ne(cmd.validate(_state), "",
			"Should reject ship with no dials.")


func test_convert_dial_execute_adds_token() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1)
	var cmd := ConvertDialToTokenCommand.new(0, {"ship_index": idx})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("command", -1),
			int(Constants.CommandType.NAVIGATE),
			"Should convert the top dial (NAVIGATE).")
	assert_true(result.get("token_added", false),
			"Token should be added.")
	assert_false(result.get("duplicate", true),
			"Should not be a duplicate.")
	assert_true(ship.command_tokens.has_token(
			Constants.CommandType.NAVIGATE),
			"Ship should hold a NAVIGATE token.")


func test_convert_dial_execute_duplicate_discards() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1)
	# Pre-add a NAVIGATE token so the conversion produces a duplicate.
	ship.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	var cmd := ConvertDialToTokenCommand.new(0, {"ship_index": idx})
	var result: Dictionary = cmd.execute(_state)
	assert_true(result.get("duplicate", false),
			"Should flag as duplicate.")
	assert_true(result.get("token_added", false),
			"Token was force-added (then auto-discarded).")


func test_convert_dial_serialize_roundtrip() -> void:
	var cmd := ConvertDialToTokenCommand.new(0, {"ship_index": 1})
	cmd.sequence = 4
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored,
			"Deserialized command should not be null.")
	assert_eq(restored.command_type, "convert_dial_to_token",
			"Restored type should match.")


# ======================================================================
# ActivateSquadronCommand
# ======================================================================

func test_activate_squadron_validate_ok() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var idx: int = _add_squadron(0)
	var cmd := ActivateSquadronCommand.new(0, {
		"squadron_index": idx})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid squadron activation.")


func test_activate_squadron_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_squadron(0)
	var cmd := ActivateSquadronCommand.new(0, {
		"squadron_index": idx})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Squadron Phase.")


func test_activate_squadron_validate_already_activated() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var idx: int = _add_squadron(0)
	var sq: SquadronInstance = \
			_state.get_player_state(0).squadrons[idx] as SquadronInstance
	sq.activated_this_round = true
	var cmd := ActivateSquadronCommand.new(0, {
		"squadron_index": idx})
	assert_ne(cmd.validate(_state), "",
			"Should reject already-activated squadron.")


func test_activate_squadron_validate_bad_index() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var cmd := ActivateSquadronCommand.new(0, {
		"squadron_index": 99})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid squadron index.")


func test_activate_squadron_execute_returns_index() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var idx: int = _add_squadron(0)
	var cmd := ActivateSquadronCommand.new(0, {
		"squadron_index": idx})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("squadron_index", -1), idx,
			"Execute should return squadron index.")


func test_activate_squadron_serialize_roundtrip() -> void:
	var cmd := ActivateSquadronCommand.new(1, {
		"squadron_index": 0})
	cmd.sequence = 9
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored,
			"Deserialized command should not be null.")
	assert_eq(restored.command_type, "activate_squadron",
			"Restored type should match.")


# ======================================================================
# SpendTokenCommand
# ======================================================================

func test_spend_token_validate_ok() -> void:
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	var cmd := SpendTokenCommand.new(0, {
		"ship_index": idx,
		"token_type": int(Constants.CommandType.NAVIGATE),
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid token spend.")


func test_spend_token_validate_no_token() -> void:
	var idx: int = _add_ship(0)
	var cmd := SpendTokenCommand.new(0, {
		"ship_index": idx,
		"token_type": int(Constants.CommandType.NAVIGATE),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject when ship has no such token.")


func test_spend_token_validate_bad_ship() -> void:
	var cmd := SpendTokenCommand.new(0, {
		"ship_index": 99,
		"token_type": int(Constants.CommandType.NAVIGATE),
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid ship index.")


func test_spend_token_execute_removes_token() -> void:
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_tokens.add_token(Constants.CommandType.NAVIGATE)
	var cmd := SpendTokenCommand.new(0, {
		"ship_index": idx,
		"token_type": int(Constants.CommandType.NAVIGATE),
	})
	var result: Dictionary = cmd.execute(_state)
	assert_true(result.get("spent", false),
			"Execute should return spent=true.")
	assert_false(ship.command_tokens.has_token(
			Constants.CommandType.NAVIGATE),
			"Ship should no longer hold the token.")


func test_spend_token_serialize_roundtrip() -> void:
	var cmd := SpendTokenCommand.new(0, {
		"ship_index": 0,
		"token_type": int(Constants.CommandType.REPAIR),
	})
	cmd.sequence = 2
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored,
			"Deserialized command should not be null.")
	assert_eq(restored.command_type, "spend_token",
			"Restored type should match.")


# ======================================================================
# SpendDialCommand
# ======================================================================

func test_spend_dial_validate_ok() -> void:
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1)
	ship.command_dial_stack.reveal_top()
	var cmd := SpendDialCommand.new(0, {"ship_index": idx})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid dial spend.")


func test_spend_dial_validate_no_revealed() -> void:
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1)
	# Dial is hidden, not revealed.
	var cmd := SpendDialCommand.new(0, {"ship_index": idx})
	assert_ne(cmd.validate(_state), "",
			"Should reject when no revealed dial.")


func test_spend_dial_validate_bad_ship() -> void:
	var cmd := SpendDialCommand.new(0, {"ship_index": 99})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid ship index.")


func test_spend_dial_execute_removes_dial() -> void:
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.REPAIR,
			Constants.CommandType.NAVIGATE], 1)
	ship.command_dial_stack.reveal_top()
	assert_false(ship.command_dial_stack.get_revealed_dial().is_empty(),
			"Dial should be revealed before execute.")
	var cmd := SpendDialCommand.new(0, {"ship_index": idx})
	var result: Dictionary = cmd.execute(_state)
	assert_true(result.get("spent", false),
			"Execute should return spent=true.")
	assert_eq(int(result.get("command", -1)),
			int(Constants.CommandType.REPAIR),
			"Result should contain the dial command type.")
	assert_true(ship.command_dial_stack.get_revealed_dial().is_empty(),
			"Dial should be consumed after execute.")


func test_spend_dial_discard_mode() -> void:
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE,
			Constants.CommandType.REPAIR], 1)
	# Dial is hidden — discard mode doesn't require revealed.
	var cmd := SpendDialCommand.new(0, {"ship_index": idx, "mode": "discard"})
	assert_eq(cmd.validate(_state), "",
			"Discard mode should accept hidden dial.")
	var result: Dictionary = cmd.execute(_state)
	assert_true(result.get("spent", false),
			"Execute should return spent=true.")
	assert_eq(result.get("mode", ""), "discard",
			"Result should report discard mode.")
	assert_eq(ship.command_dial_stack.get_dial_count(), 1,
			"Dial stack should have 1 remaining after discarding 1 of 2.")


func test_spend_dial_discard_empty_stack() -> void:
	var idx: int = _add_ship(0)
	var cmd := SpendDialCommand.new(0, {
		"ship_index": idx, "mode": "discard"})
	assert_ne(cmd.validate(_state), "",
			"Should reject discard on empty stack.")


func test_spend_dial_serialize_roundtrip() -> void:
	var cmd := SpendDialCommand.new(0, {"ship_index": 0})
	cmd.sequence = 5
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored,
			"Deserialized command should not be null.")
	assert_eq(restored.command_type, "spend_dial",
			"Restored type should match.")
