## Tests for AdvanceActivationStepCommand.
##
## Covers validate (happy + rejection), execute, and serialize/deserialize.
extends GutTest


var _state: GameState


func _make_ship_data() -> ShipData:
	var data := ShipData.new()
	data.hull = 5
	data.max_speed = 2
	data.command_value = 2
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = ["brace", "redirect"]
	data.navigation_chart = [[1], [1, 1]]
	return data


func _add_ship(player: int) -> int:
	var ship: ShipInstance = ShipInstance.create_from_data(
			"test_ship", _make_ship_data(), 2, player)
	var ps: PlayerState = _state.get_player_state(player)
	ps.ships.append(ship)
	return ps.ships.size() - 1


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	AdvanceActivationStepCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("advance_activation_step")


func test_validate_accepts_repair_step_for_existing_ship() -> void:
	var idx: int = _add_ship(0)
	var cmd := AdvanceActivationStepCommand.new(0, {
		"ship_index": idx,
		"step_id": "repair_step",
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid ship activation step transition.")


func test_validate_rejects_non_ship_phase() -> void:
	var idx: int = _add_ship(0)
	_state.current_phase = Constants.GamePhase.COMMAND
	var cmd := AdvanceActivationStepCommand.new(0, {
		"ship_index": idx,
		"step_id": "repair_step",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject transitions outside Ship Phase.")


func test_validate_rejects_invalid_step_id() -> void:
	var idx: int = _add_ship(0)
	var cmd := AdvanceActivationStepCommand.new(0, {
		"ship_index": idx,
		"step_id": "unknown_step",
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject unknown interaction step ids.")


func test_execute_returns_step_payload_for_timeline() -> void:
	var cmd := AdvanceActivationStepCommand.new(0, {
		"ship_index": 0,
		"step_id": "attack_step",
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("ship_index", -1), 0,
			"Execute should echo ship_index for timeline consumers.")
	assert_eq(result.get("step_id", ""), "attack_step",
			"Execute should echo step_id for timeline consumers.")


func test_serialize_deserialize_roundtrip() -> void:
	var cmd := AdvanceActivationStepCommand.new(1, {
		"ship_index": 1,
		"step_id": "maneuver_step",
	})
	cmd.sequence = 77
	var data: Dictionary = cmd.serialize()
	var copy: GameCommand = GameCommand.deserialize(data)
	assert_not_null(copy, "Deserialized command should not be null.")
	assert_eq(copy.command_type, "advance_activation_step",
			"Type should round-trip.")
	assert_eq(copy.player_index, 1,
			"Player index should round-trip.")
	assert_eq(copy.sequence, 77,
			"Sequence should round-trip.")
	assert_eq(copy.payload.get("step_id", ""), "maneuver_step",
			"Payload step_id should round-trip.")
