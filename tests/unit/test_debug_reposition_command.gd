## DBG-001 authoritative DEBUG transform transaction coverage.
extends GutTest

const CommandScript: GDScript = preload(
		"res://src/core/commands/debug_reposition_command.gd")

var _state: GameState


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.faction = Constants.Faction.REBEL_ALLIANCE
	data.hull = 5
	data.command_value = 2
	data.engineering_value = 3
	data.shields = {"FRONT": 3}
	return data


func _add_ship(player: int, x: float, y: float) -> ShipInstance:
	var ship := ShipInstance.create_from_data("test_ship", _ship_data(), 2, player)
	ship.pos_x = x
	ship.pos_y = y
	_state.get_player_state(player).ships.append(ship)
	return ship


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()


func test_ship_transform_is_canonical_and_has_no_activation_side_effect() -> void:
	var ship := _add_ship(0, 0.2, 0.2)
	var cmd: GameCommand = CommandScript.new(0, {"target_kind": "ship",
		"owner_player": 0, "unit_index": 0, "pos_x": 0.4, "pos_y": 0.5,
		"rotation_deg": 90.0})
	assert_eq(cmd.validate(_state), "")
	var result: Dictionary = cmd.execute(_state)
	assert_eq(ship.pos_x, 0.4)
	assert_eq(ship.pos_y, 0.5)
	assert_eq(ship.rotation_deg, 90.0)
	assert_eq(result.get("target_kind"), "ship")
	assert_false(ship.activated_this_round)


func test_squadron_transform_and_json_integer_normalization() -> void:
	var squadron := SquadronInstance.create_from_data("test", _squadron_data(), 1)
	squadron.pos_x = 0.2
	squadron.pos_y = 0.2
	_state.get_player_state(1).squadrons.append(squadron)
	GameCommand.register_type("debug_reposition", func(player: int,
			payload: Dictionary) -> GameCommand: return CommandScript.new(player, payload))
	var restored := GameCommand.deserialize({"type": "debug_reposition",
		"player": 0.0, "sequence": 0.0, "payload": {"target_kind": "squadron",
			"owner_player": 1.0, "unit_index": 0.0, "pos_x": 0.6,
			"pos_y": 0.7, "rotation_deg": 180.0}})
	assert_not_null(restored)
	assert_eq(typeof(restored.payload.get("owner_player")), TYPE_INT)
	assert_eq(typeof(restored.payload.get("unit_index")), TYPE_INT)
	assert_eq(restored.validate(_state), "")
	restored.execute(_state)
	assert_eq(squadron.rotation_deg, 180.0)


func test_invalid_bounds_or_overlap_reject_without_mutation() -> void:
	var ship := _add_ship(0, 0.2, 0.2)
	_add_ship(1, 0.7, 0.7)
	var invalid: GameCommand = CommandScript.new(0, {"target_kind": "ship",
		"owner_player": 0, "unit_index": 0, "pos_x": 1.2, "pos_y": 0.2,
		"rotation_deg": 0.0})
	assert_ne(invalid.validate(_state), "")
	assert_eq(ship.pos_x, 0.2)
	var collision: GameCommand = CommandScript.new(0, {"target_kind": "ship",
		"owner_player": 0, "unit_index": 0, "pos_x": 0.7, "pos_y": 0.7,
		"rotation_deg": 0.0})
	assert_ne(collision.validate(_state), "")
	assert_eq(ship.pos_x, 0.2)


func _squadron_data() -> SquadronData:
	var data := SquadronData.new()
	data.hull = 3
	data.faction = Constants.Faction.GALACTIC_EMPIRE
	return data
