extends GutTest


const COMMAND: GDScript = preload(
		"res://src/core/commands/candidate_resolve_ship_collision_damage_command.gd")

const ACTIVATION_ID := "ship-activation:30"
const EXECUTION_ID := "maneuver:30"
const EXACT_KEY := "collision:ship-activation:30:maneuver:30:1:0"

var _state: GameState
var _moving: ShipInstance
var _target: ShipInstance


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	_moving = _ship(0)
	_target = _ship(1)
	_state.get_player_state(0).ships.append(_moving)
	_state.get_player_state(1).ships.append(_target)
	assert_true(_moving.establish_ship_activation(ACTIVATION_ID))
	assert_true(_moving.open_maneuver_opportunity(ACTIVATION_ID))
	assert_true(_moving.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, {
				"yaw_clicks": [0], "yaw_bonus_joint": -1,
				"pos_x": 0.4, "pos_y": 0.4, "rotation_deg": 0.0,
			}, {
				"kind": "closest_ship",
				"target_owner_player": 1,
				"target_ship_index": 0,
				"exact_once_key": EXACT_KEY,
				"damage_resolved": false,
			}))
	assert_false(_moving.apply_maneuver_final_transform(
			ACTIVATION_ID, EXECUTION_ID).is_empty())
	_state.damage_deck = _deck()


func test_uses_immutable_target_and_applies_two_cards_exactly_once() -> void:
	var command: GameCommand = _command()
	assert_eq(command.validate(_state), "")
	var result: Dictionary = command.execute(_state)
	assert_false(result.is_empty())
	assert_eq(_moving.get_facedown_damage_count(), 1)
	assert_eq(_target.get_facedown_damage_count(), 1)
	assert_true(bool(_moving.active_maneuver_execution_snapshot()[
			"ship_collision"]["damage_resolved"]))
	assert_ne(command.validate(_state), "")
	assert_eq(command.execute(_state), {})


func test_wrong_target_key_or_pre_transform_timing_rejects() -> void:
	var wrong: GameCommand = _command()
	wrong.payload["target_owner_player"] = 0
	assert_ne(wrong.validate(_state), "")
	wrong = _command()
	wrong.payload["exact_once_key"] = "wrong"
	assert_ne(wrong.validate(_state), "")

	var fresh := ShipInstance.create_from_data("fresh", _ship_data(), 1, 0)
	_state.get_player_state(0).ships[0] = fresh
	assert_true(fresh.establish_ship_activation(ACTIVATION_ID))
	assert_true(fresh.open_maneuver_opportunity(ACTIVATION_ID))
	assert_true(fresh.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, {
				"yaw_clicks": [0], "yaw_bonus_joint": -1,
				"pos_x": 0.4, "pos_y": 0.4, "rotation_deg": 0.0,
			}, _collision()))
	assert_ne(_command().validate(_state), "")


func test_passive_application_consumes_two_hidden_draws_and_marks_evidence() -> void:
	var authority: GameCommand = _command()
	var result: Dictionary = authority.execute(_state)
	var passive := GameState.new()
	passive.initialize()
	passive.current_phase = Constants.GamePhase.SHIP
	passive.damage_deck = null
	passive.rng = null
	var moving: ShipInstance = _ship(0)
	var target: ShipInstance = _ship(1)
	moving.roster_entry_id = "moving"
	target.roster_entry_id = "target"
	passive.get_player_state(0).ships.append(moving)
	passive.get_player_state(1).ships.append(target)
	passive.passive_damage_ledger = PassiveDamageLedger.deserialize({
		"schema_version": 1, "draw_count": 2, "discard_pile": [],
		"facedown_counts": {"0:moving": 0, "1:target": 0},
	}, ["0:moving", "1:target"])
	assert_true(moving.bind_passive_damage_ledger(
			passive.passive_damage_ledger, "0:moving"))
	assert_true(target.bind_passive_damage_ledger(
			passive.passive_damage_ledger, "1:target"))
	assert_true(moving.establish_ship_activation(ACTIVATION_ID))
	assert_true(moving.open_maneuver_opportunity(ACTIVATION_ID))
	assert_true(moving.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, {
		"yaw_clicks": [0], "yaw_bonus_joint": -1,
		"pos_x": 0.4, "pos_y": 0.4, "rotation_deg": 0.0,
	}, _collision()))
	assert_false(moving.apply_maneuver_final_transform(
			ACTIVATION_ID, EXECUTION_ID).is_empty())
	var mirror: GameCommand = COMMAND.new(0, authority.payload.duplicate(true))
	assert_eq(mirror.execute_with_application_result(passive, result), result)
	assert_eq(moving.get_facedown_damage_count(), 1)
	assert_eq(target.get_facedown_damage_count(), 1)
	assert_eq(passive.passive_damage_ledger.draw_count, 0)
	assert_true(bool(moving.active_maneuver_execution_snapshot()[
			"ship_collision"]["damage_resolved"]))


func test_collision_destruction_keeps_applied_geometry_and_suppresses_return() -> void:
	_moving.ship_data.hull = 1
	var applied_position := Vector2(_moving.pos_x, _moving.pos_y)
	var result: Dictionary = _command().execute(_state)
	assert_false(result.is_empty())
	assert_true(bool(result["moving_damage_application"]["destroyed"]))
	assert_true(_moving.has_finalized_destruction())
	assert_false(_moving.has_active_maneuver_execution())
	assert_eq(Vector2(_moving.pos_x, _moving.pos_y), applied_position)
	assert_eq(_target.get_facedown_damage_count(), 1)


func _command() -> GameCommand:
	return COMMAND.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
		"target_owner_player": 1,
		"target_ship_index": 0,
		"exact_once_key": EXACT_KEY,
	})


func _collision() -> Dictionary:
	return {
		"kind": "closest_ship",
		"target_owner_player": 1,
		"target_ship_index": 0,
		"exact_once_key": EXACT_KEY,
		"damage_resolved": false,
	}


func _deck() -> DamageDeck:
	var cards: Array[Dictionary] = []
	for index: int in range(2):
		var card := DamageCard.new()
		card.physical_card_id = "damage:%d" % index
		card.effect_id = "ordinary"
		card.timing = "persistent"
		cards.append(card.serialize_for_save7("draw"))
	return DamageDeck.deserialize_for_save7({
		"draw_pile": cards,
		"discard_pile": [],
	})


func _ship(owner: int) -> ShipInstance:
	return ShipInstance.create_from_data(
			"collision", _ship_data(), 1, owner)


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 5
	data.max_speed = 2
	data.command_value = 1
	data.navigation_chart = [[1], [1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data
