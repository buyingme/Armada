## Tests for G2 Tier 3 movement command subclasses.
##
## Covers: MoveSquadronCommand, ExecuteManeuverCommand.
## Each command is tested for validate (happy + rejection), execute,
## and serialize/deserialize roundtrip.
extends GutTest


var _state: GameState


## Creates a minimal ShipData with a navigation chart.
func _make_ship_data() -> ShipData:
	var data := ShipData.new()
	data.hull = 5
	data.max_speed = 3
	data.command_value = 2
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = []
	# Nav chart: speed 1 = [1], speed 2 = [1, 1], speed 3 = [0, 1, 1]
	data.navigation_chart = [[1], [1, 1], [0, 1, 1]]
	return data


## Creates a ShipInstance and adds it to the given player's fleet.
## Returns the ship index.
func _add_ship(player: int) -> int:
	var ship := ShipInstance.create_from_data(
			"test_ship", _make_ship_data(), 2, player)
	var ps: PlayerState = _state.get_player_state(player)
	ps.ships.append(ship)
	return ps.ships.size() - 1


## Creates a minimal SquadronInstance and adds it to the player's fleet.
## Returns the squadron index.
func _add_squadron(player: int) -> int:
	var data := SquadronData.new()
	data.hull = 3
	data.speed = 3
	data.defense_tokens = []
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
	MoveSquadronCommand.register()
	ExecuteManeuverCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("move_squadron")
	GameCommand._registry.erase("execute_maneuver")


# ======================================================================
# GameState.get_squadron() helper
# ======================================================================

func test_get_squadron_returns_valid() -> void:
	var idx: int = _add_squadron(0)
	var sq: SquadronInstance = _state.get_squadron(0, idx)
	assert_not_null(sq, "Should return squadron at valid index.")
	assert_eq(sq.data_key, "test_squad",
			"Should return correct squadron.")


func test_get_squadron_returns_null_bad_index() -> void:
	assert_null(_state.get_squadron(0, 99),
			"Should return null for out-of-range index.")


# ======================================================================
# MoveSquadronCommand
# ======================================================================

func test_move_squadron_validate_ok_squadron_phase() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var idx: int = _add_squadron(0)
	var cmd := MoveSquadronCommand.new(0, {
		"squadron_index": idx,
		"pos_x": 0.5,
		"pos_y": 0.3,
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid move in Squadron Phase.")


func test_move_squadron_validate_ok_ship_phase() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_squadron(0)
	var cmd := MoveSquadronCommand.new(0, {
		"squadron_index": idx,
		"pos_x": 0.5,
		"pos_y": 0.3,
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept move in Ship Phase (squadron command).")


func test_move_squadron_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.COMMAND
	var idx: int = _add_squadron(0)
	var cmd := MoveSquadronCommand.new(0, {
		"squadron_index": idx,
		"pos_x": 0.5,
		"pos_y": 0.3,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Squadron/Ship Phase.")


func test_move_squadron_validate_bad_index() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var cmd := MoveSquadronCommand.new(0, {
		"squadron_index": 99,
		"pos_x": 0.5,
		"pos_y": 0.3,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid squadron index.")


func test_move_squadron_validate_destroyed() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var idx: int = _add_squadron(0)
	var sq: SquadronInstance = _state.get_squadron(0, idx)
	sq.mark_destroyed()
	var cmd := MoveSquadronCommand.new(0, {
		"squadron_index": idx,
		"pos_x": 0.5,
		"pos_y": 0.3,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject destroyed squadron.")


func test_move_squadron_validate_missing_target() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var idx: int = _add_squadron(0)
	var cmd := MoveSquadronCommand.new(0, {
		"squadron_index": idx,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject missing target position.")


func test_move_squadron_execute_returns_position() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var idx: int = _add_squadron(0)
	var cmd := MoveSquadronCommand.new(0, {
		"squadron_index": idx,
		"pos_x": 0.421,
		"pos_y": 0.913,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("squadron_index", -1), idx,
			"Result should include squadron index.")
	assert_almost_eq(result.get("pos_x", 0.0), 0.421, 0.001,
			"Result should include pos_x.")
	assert_almost_eq(result.get("pos_y", 0.0), 0.913, 0.001,
			"Result should include pos_y.")


func test_move_squadron_execute_updates_instance() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var idx: int = _add_squadron(0)
	var sq: SquadronInstance = _state.get_squadron(0, idx)
	assert_almost_eq(sq.pos_x, 0.0, 0.001,
			"pos_x should default to 0.")
	var cmd := MoveSquadronCommand.new(0, {
		"squadron_index": idx,
		"pos_x": 0.6,
		"pos_y": 0.85,
	})
	cmd.execute(_state)
	assert_almost_eq(sq.pos_x, 0.6, 0.001,
			"execute() should update squadron pos_x.")
	assert_almost_eq(sq.pos_y, 0.85, 0.001,
			"execute() should update squadron pos_y.")


func test_move_squadron_serialize_roundtrip() -> void:
	var cmd := MoveSquadronCommand.new(1, {
		"squadron_index": 2,
		"pos_x": 0.8,
		"pos_y": 0.6,
	})
	cmd.sequence = 20
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Deserialized command should not be null.")
	assert_eq(restored.command_type, "move_squadron",
			"Restored type should match.")
	assert_eq(restored.player_index, 1,
			"Restored player should match.")
	assert_eq(restored.sequence, 20,
			"Restored sequence should match.")
	assert_eq(restored.payload.get("squadron_index", -1), 2,
			"Restored squadron_index should match.")


# ======================================================================
# ExecuteManeuverCommand
# ======================================================================

func test_execute_maneuver_validate_ok() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": idx,
		"speed": 2,
		"yaw_clicks": [0, 1],
		"pos_x": 0.5,
		"pos_y": 0.3,
		"rotation_deg": 28.6,
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept valid maneuver.")


func test_execute_maneuver_validate_speed_zero() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": idx,
		"speed": 0,
		"yaw_clicks": [],
		"pos_x": 0.5,
		"pos_y": 0.3,
		"rotation_deg": 0.0,
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept speed-0 maneuver (no movement).")


func test_execute_maneuver_validate_wrong_phase() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var idx: int = _add_ship(0)
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": idx,
		"speed": 2,
		"yaw_clicks": [0, 1],
		"pos_x": 0.5,
		"pos_y": 0.3,
		"rotation_deg": 28.6,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject outside Ship Phase.")


func test_execute_maneuver_validate_bad_ship() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": 99,
		"speed": 2,
		"yaw_clicks": [0, 1],
		"pos_x": 0.5,
		"pos_y": 0.3,
		"rotation_deg": 28.6,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject invalid ship index.")


func test_execute_maneuver_validate_invalid_speed() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": idx,
		"speed": -1,
		"yaw_clicks": [0],
		"pos_x": 0.5,
		"pos_y": 0.3,
		"rotation_deg": 28.6,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject negative speed.")


func test_execute_maneuver_validate_exceeds_yaw_limits() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	# Speed 2, nav chart = [1, 1]. Max yaw per joint is 1.
	# Provide yaw_clicks = [0, 3] — exceeds limit.
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": idx,
		"speed": 2,
		"yaw_clicks": [0, 3],
		"pos_x": 0.5,
		"pos_y": 0.3,
		"rotation_deg": 28.6,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject yaw clicks exceeding nav chart.")


func test_execute_maneuver_validate_wrong_joint_count() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	# Speed 2 requires 2 joints, provide 3.
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": idx,
		"speed": 2,
		"yaw_clicks": [0, 0, 1],
		"pos_x": 0.5,
		"pos_y": 0.3,
		"rotation_deg": 28.6,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject wrong number of yaw click joints.")


func test_execute_maneuver_validate_missing_position() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": idx,
		"speed": 1,
		"yaw_clicks": [0],
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject missing final position.")


func test_execute_maneuver_validate_missing_rotation() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": idx,
		"speed": 1,
		"yaw_clicks": [0],
		"pos_x": 0.5,
		"pos_y": 0.3,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject missing final rotation.")


func test_execute_maneuver_validate_locked_joint_zero_yaw() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	# Speed 3: nav chart = [0, 1, 1]. Joint 0 has max_yaw = 0 (locked).
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": idx,
		"speed": 3,
		"yaw_clicks": [0, 0, 1],
		"pos_x": 0.5,
		"pos_y": 0.3,
		"rotation_deg": 28.6,
	})
	assert_eq(cmd.validate(_state), "",
			"Should accept yaw=0 at locked joint.")


func test_execute_maneuver_validate_locked_joint_nonzero() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	# Speed 3: nav chart = [0, 1, 1]. Joint 0 locked, try to turn at it.
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": idx,
		"speed": 3,
		"yaw_clicks": [1, 0, 0],
		"pos_x": 0.5,
		"pos_y": 0.3,
		"rotation_deg": 28.6,
	})
	assert_ne(cmd.validate(_state), "",
			"Should reject non-zero yaw at locked joint.")


func test_execute_maneuver_execute_returns_data() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": idx,
		"speed": 2,
		"yaw_clicks": [0, -1],
		"pos_x": 0.75,
		"pos_y": 0.42,
		"rotation_deg": -17.2,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(result.get("ship_index", -1), idx,
			"Result should include ship index.")
	assert_eq(result.get("speed", -1), 2,
			"Result should include speed.")
	assert_almost_eq(result.get("pos_x", 0.0), 0.75, 0.001,
			"Result should include pos_x.")
	assert_almost_eq(result.get("pos_y", 0.0), 0.42, 0.001,
			"Result should include pos_y.")
	assert_almost_eq(result.get("rotation_deg", 0.0), -17.2, 0.01,
			"Result should include rotation_deg.")
	var yaw: Array = result.get("yaw_clicks", [])
	assert_eq(yaw.size(), 2,
			"Result should include yaw clicks array.")


func test_execute_maneuver_execute_updates_instance() -> void:
	_state.current_phase = Constants.GamePhase.SHIP
	var idx: int = _add_ship(0)
	var ship: ShipInstance = _state.get_ship(0, idx)
	assert_almost_eq(ship.pos_x, 0.0, 0.001,
			"pos_x should default to 0.")
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": idx,
		"speed": 2,
		"yaw_clicks": [0, 1],
		"pos_x": 0.489,
		"pos_y": 0.35,
		"rotation_deg": 180.0,
	})
	cmd.execute(_state)
	assert_almost_eq(ship.pos_x, 0.489, 0.001,
			"execute() should update ship pos_x.")
	assert_almost_eq(ship.pos_y, 0.35, 0.001,
			"execute() should update ship pos_y.")
	assert_almost_eq(ship.rotation_deg, 180.0, 0.01,
			"execute() should update ship rotation_deg.")


func test_execute_maneuver_serialize_roundtrip() -> void:
	var cmd := ExecuteManeuverCommand.new(0, {
		"ship_index": 1,
		"speed": 3,
		"yaw_clicks": [0, 1, -1],
		"pos_x": 0.6,
		"pos_y": 0.35,
		"rotation_deg": 90.0,
	})
	cmd.sequence = 42
	var data: Dictionary = cmd.serialize()
	var restored: GameCommand = GameCommand.deserialize(data)
	assert_not_null(restored, "Deserialized command should not be null.")
	assert_eq(restored.command_type, "execute_maneuver",
			"Restored type should match.")
	assert_eq(restored.player_index, 0,
			"Restored player should match.")
	assert_eq(restored.sequence, 42,
			"Restored sequence should match.")
	assert_eq(restored.payload.get("speed", -1), 3,
			"Restored speed should match.")
	assert_eq(restored.payload.get("ship_index", -1), 1,
			"Restored ship_index should match.")
