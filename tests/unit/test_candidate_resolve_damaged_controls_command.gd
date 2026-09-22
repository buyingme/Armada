extends GutTest


const COMMAND: GDScript = preload(
		"res://src/core/commands/candidate_resolve_damaged_controls_command.gd")
const EVALUATOR: GDScript = preload(
		"res://src/core/movement/maneuver_execution_evaluator.gd")


var _state: GameState
var _ship: ShipInstance
var _payload: Dictionary


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	_ship = ShipInstance.create_from_data("moving", _ship_data(4), 1, 0)
	_state.get_player_state(0).ships.append(_ship)
	assert_true(_ship.establish_ship_activation("ship-activation:40"))
	assert_true(_ship.open_maneuver_opportunity("ship-activation:40"))
	assert_true(_ship.commit_maneuver_execution(
			"ship-activation:40", "maneuver:40", false, {
		"yaw_clicks": [0], "yaw_bonus_joint": -1,
		"pos_x": 0.5, "pos_y": 0.5, "rotation_deg": 0.0,
	}, {
		"kind": "closest_ship",
		"target_owner_player": 1,
		"target_ship_index": 0,
		"exact_once_key": "collision:ship-activation:40:maneuver:40:1:0",
		"damage_resolved": false,
	}))
	assert_false(_ship.apply_maneuver_final_transform(
			"ship-activation:40", "maneuver:40").is_empty())
	assert_true(_ship.mark_maneuver_ship_collision_damage_resolved(
			"ship-activation:40", "maneuver:40",
			"collision:ship-activation:40:maneuver:40:1:0"))
	var source := DamageCard.new()
	source.physical_card_id = "damage:source"
	source.public_card_ref = "faceup:39:0"
	source.effect_id = "damaged_controls"
	source.timing = "persistent"
	source.is_faceup = true
	_ship.add_faceup_damage(source)
	_state.damage_deck = _deck(2)
	_payload = {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:40",
		"maneuver_execution_id": "maneuver:40",
		"public_card_ref": "faceup:39:0",
		"overlap_kind": "ship",
	}


func test_ship_branch_draws_once_and_records_per_instance_execution_guard() -> void:
	var command: GameCommand = COMMAND.new(0, _payload)
	assert_eq(command.validate(_state), "")
	var result: Dictionary = command.execute(_state)
	assert_eq(result.keys(), [
		"owner_player", "ship_index", "ship_activation_identity",
		"maneuver_execution_id", "public_card_ref", "overlap_kind",
		"damage_application",
	])
	assert_false(result.has("obstacle_id"))
	assert_eq(result["damage_application"]["facedown_delta"], 1)
	assert_eq((_ship.faceup_damage[0] as DamageCard)
			.last_damaged_controls_execution_id, "maneuver:40")
	assert_ne(COMMAND.new(0, _payload).validate(_state), "")


func test_obstacle_branch_and_stale_collision_boundary_are_unavailable() -> void:
	var obstacle: Dictionary = _payload.duplicate(true)
	obstacle["overlap_kind"] = "obstacle"
	obstacle["obstacle_id"] = "obstacle:0"
	assert_ne(COMMAND.new(0, obstacle).validate(_state), "")
	var stale: Dictionary = _payload.duplicate(true)
	stale["maneuver_execution_id"] = "maneuver:stale"
	assert_ne(COMMAND.new(0, stale).validate(_state), "")


func test_passive_ship_branch_applies_aggregate_damage_without_physical_id() -> void:
	var authority: GameCommand = COMMAND.new(0, _payload)
	var result: Dictionary = authority.execute(_state)
	var passive := GameState.new()
	passive.initialize()
	passive.damage_deck = null
	passive.rng = null
	var mirror := ShipInstance.create_from_data("moving", _ship_data(4), 1, 0)
	mirror.roster_entry_id = "moving"
	var source := DamageCard.create("Ship", "Damaged Controls")
	source.effect_id = "damaged_controls"
	source.timing = "persistent"
	source.is_faceup = true
	source.public_card_ref = "faceup:39:0"
	mirror.add_faceup_damage(source)
	passive.get_player_state(0).ships.append(mirror)
	passive.passive_damage_ledger = PassiveDamageLedger.deserialize({
		"schema_version": 1, "draw_count": 1, "discard_pile": [],
		"facedown_counts": {"0:moving": 0},
	}, ["0:moving"])
	assert_true(mirror.bind_passive_damage_ledger(
			passive.passive_damage_ledger, "0:moving"))
	assert_true(mirror.establish_ship_activation("ship-activation:40"))
	assert_true(mirror.open_maneuver_opportunity("ship-activation:40"))
	assert_true(mirror.commit_maneuver_execution(
			"ship-activation:40", "maneuver:40", false, {
		"yaw_clicks": [0], "yaw_bonus_joint": -1,
		"pos_x": 0.5, "pos_y": 0.5, "rotation_deg": 0.0,
	}, {
		"kind": "closest_ship", "target_owner_player": 1,
		"target_ship_index": 0,
		"exact_once_key": "collision:ship-activation:40:maneuver:40:1:0",
		"damage_resolved": true,
	}))
	assert_false(mirror.apply_maneuver_final_transform(
			"ship-activation:40", "maneuver:40").is_empty())
	var command: GameCommand = COMMAND.new(0, _payload.duplicate(true))
	assert_eq(command.execute_with_application_result(passive, result), result)
	assert_eq(mirror.get_facedown_damage_count(), 1)
	assert_eq(source.physical_card_id, "")
	assert_eq(source.last_damaged_controls_execution_id, "maneuver:40")


func test_obstacle_only_speed_zero_branch_resolves_each_copy_once() -> void:
	var fixture: Dictionary = _obstacle_fixture()
	var state: GameState = fixture["state"]
	var ship: ShipInstance = fixture["ship"]
	var first: Dictionary = fixture["payload"]
	var second_source := DamageCard.create("Ship", "Damaged Controls")
	second_source.physical_card_id = "damage:source:second"
	second_source.effect_id = "damaged_controls"
	second_source.timing = "persistent"
	second_source.is_faceup = true
	second_source.public_card_ref = "faceup:39:1"
	ship.add_faceup_damage(second_source)
	assert_eq(ship.current_speed, 0)
	var first_command: GameCommand = COMMAND.new(0, first)
	assert_eq(first_command.validate(state), "")
	assert_false(first_command.execute(state).is_empty())
	var next: Dictionary = EVALUATOR.next_action(state, 0, 0)
	assert_eq(next["command_type"], "resolve_damaged_controls")
	assert_eq(next["payload"]["public_card_ref"], "faceup:39:1")
	assert_false(COMMAND.new(0, next["payload"]).execute(state).is_empty())
	assert_eq(ship.get_facedown_damage_count(), 2)
	assert_eq(EVALUATOR.next_action(state, 0, 0)["command_type"],
			"commit_maneuver_obstacle_order")


func test_ship_plus_obstacle_does_not_resolve_same_copy_twice() -> void:
	_state.objectives["obstacles"] = [_obstacle_placement()]
	var command: GameCommand = COMMAND.new(0, _payload)
	assert_false(command.execute(_state).is_empty())
	var next: Dictionary = EVALUATOR.next_action(_state, 0, 0)
	assert_eq(next["command_type"], "commit_maneuver_obstacle_order")
	assert_ne(next["command_type"], "resolve_damaged_controls")


func test_obstacle_guard_round_trip_prevents_duplicate_after_recovery() -> void:
	var fixture: Dictionary = _obstacle_fixture()
	var state: GameState = fixture["state"]
	var ship: ShipInstance = fixture["ship"]
	var command: GameCommand = COMMAND.new(0, fixture["payload"])
	assert_false(command.execute(state).is_empty())
	var restored: ShipInstance = ShipInstance.deserialize(
			ship.serialize(), ship.ship_data)
	assert_not_null(restored)
	assert_eq((restored.faceup_damage[0] as DamageCard)
			.last_damaged_controls_execution_id, "maneuver:40")
	state.get_player_state(0).ships[0] = restored
	assert_ne(COMMAND.new(0, fixture["payload"]).validate(state), "")


func _obstacle_fixture() -> Dictionary:
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	state.objectives["obstacles"] = [_obstacle_placement()]
	var ship := ShipInstance.create_from_data("moving", _ship_data(8), 0, 0)
	ship.roster_entry_id = "moving"
	ship.pos_x = 0.5
	ship.pos_y = 0.5
	state.get_player_state(0).ships.append(ship)
	assert_true(ship.establish_ship_activation("ship-activation:40"))
	assert_true(ship.open_maneuver_opportunity("ship-activation:40"))
	assert_true(ship.commit_maneuver_execution(
			"ship-activation:40", "maneuver:40", false, {
				"yaw_clicks": [], "yaw_bonus_joint": -1,
				"pos_x": 0.5, "pos_y": 0.5, "rotation_deg": 0.0,
			}, {"kind": "none"}))
	assert_false(ship.apply_maneuver_final_transform(
			"ship-activation:40", "maneuver:40").is_empty())
	var source := DamageCard.create("Ship", "Damaged Controls")
	source.physical_card_id = "damage:source"
	source.effect_id = "damaged_controls"
	source.timing = "persistent"
	source.is_faceup = true
	source.public_card_ref = "faceup:39:0"
	ship.add_faceup_damage(source)
	state.damage_deck = _deck(3)
	return {"state": state, "ship": ship, "payload": {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": "ship-activation:40",
		"maneuver_execution_id": "maneuver:40",
		"public_card_ref": "faceup:39:0",
		"overlap_kind": "obstacle",
		"obstacle_id": "obstacle:0",
	}}


func _obstacle_placement() -> Dictionary:
	return {
		"obstacle_id": "obstacle:0",
		"data_key": "asteroid_1",
		"pos_x": 0.5,
		"pos_y": 0.5,
		"rotation_deg": 0.0,
		"placing_player": 0,
		"placement_order": 0,
		"last_maneuver_execution_id": "",
	}


func _deck(count: int) -> DamageDeck:
	var draw: Array[Dictionary] = []
	for index: int in range(count):
		var card := DamageCard.new()
		card.physical_card_id = "damage:%d" % index
		card.effect_id = "ordinary"
		card.timing = "persistent"
		draw.append(card.serialize_for_save7("draw"))
	return DamageDeck.deserialize_for_save7({
		"draw_pile": draw, "discard_pile": []})


func _ship_data(hull: int) -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = hull
	data.max_speed = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data
