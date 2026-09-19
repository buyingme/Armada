extends GutTest


const ORDER: GDScript = preload(
		"res://src/core/commands/candidate_commit_maneuver_obstacle_order_command.gd")
const ASTEROID: GDScript = preload(
		"res://src/core/commands/candidate_resolve_asteroid_overlap_command.gd")
const DEBRIS: GDScript = preload(
		"res://src/core/commands/candidate_resolve_debris_overlap_command.gd")
const STATION: GDScript = preload(
		"res://src/core/commands/candidate_resolve_station_overlap_command.gd")
const IMMEDIATE: GDScript = preload(
		"res://src/core/commands/candidate_resolve_immediate_effect_command.gd")
const EVALUATOR: GDScript = preload(
		"res://src/core/movement/maneuver_execution_evaluator.gd")
const OVERLAP: GDScript = preload(
		"res://src/core/geometry/obstacle_overlap_authority.gd")

const ACTIVATION_ID := "ship-activation:70"
const EXECUTION_ID := "maneuver:70"


func test_asteroid_delegates_every_legal_immediate_card_and_returns_once() -> void:
	for effect: String in [
		"structural_damage", "projector_misaligned",
		"life_support_failure", "injured_crew", "shield_failure",
		"comm_noise",
	]:
		var fixture: Dictionary = _fixture("asteroid_1", [
				_card("damage:%s" % effect, effect, "immediate_persistent" \
						if effect == "life_support_failure" else "immediate")])
		var state: GameState = fixture["state"]
		var ship: ShipInstance = fixture["ship"]
		if effect == "projector_misaligned":
			ship.current_shields = {
				"front": 2, "left": 1, "right": 1, "rear": 1}
		var overlaps: Array[Dictionary] = OVERLAP.overlapping_obstacles(
				state, 0, 0)
		assert_false(overlaps.is_empty(), "%s %s" % [effect, overlaps])
		assert_false(_commit_order(state).execute(state).is_empty(), effect)
		var asteroid: GameCommand = ASTEROID.new(0, _base("obstacle:0"))
		asteroid.sequence = 71
		assert_eq(asteroid.validate(state), "", effect)
		var dealt: Dictionary = asteroid.execute(state)
		assert_false(dealt.is_empty(), effect)
		assert_true(ship.has_active_immediate_resolution(), effect)
		assert_true(not ship.active_asteroid_resolution_snapshot().is_empty(),
				effect)
		var record: Dictionary = ship.active_immediate_resolution_snapshot()
		var payload: Dictionary = {
			"owner_player": 0,
			"ship_index": 0,
			"public_card_ref": record["public_card_ref"],
			"immediate_resolution_id": record["immediate_resolution_id"],
			"enclosing_kind": "maneuver",
			"ship_activation_identity": ACTIVATION_ID,
			"maneuver_execution_id": EXECUTION_ID,
			"maneuver_source_kind": "asteroid",
			"maneuver_source_id": "obstacle:0",
		}
		if effect == "shield_failure":
			payload["shield_zones"] = []
		elif effect == "comm_noise":
			payload["comm_noise_action"] = "speed"
		var actor: int = int(record["actor_player"])
		var resolution: GameCommand = IMMEDIATE.new(
				0 if actor == -1 else actor, payload)
		assert_eq(resolution.validate(state), "", effect)
		assert_false(resolution.execute(state).is_empty(), effect)
		assert_false(ship.has_active_immediate_resolution(), effect)
		assert_true(ship.active_asteroid_resolution_snapshot().is_empty(),
				effect)
		assert_eq(state.obstacle_placement("obstacle:0")[
				"last_maneuver_execution_id"], EXECUTION_ID, effect)
		assert_eq(EVALUATOR.next_action(state, 0, 0)["command_type"],
				"complete_maneuver", effect)


func test_debris_applies_two_points_to_one_zone_and_returns() -> void:
	var fixture: Dictionary = _fixture("debris_1", [
		_card("damage:debris:0", "ordinary", "persistent"),
		_card("damage:debris:1", "ordinary", "persistent"),
	])
	var state: GameState = fixture["state"]
	var ship: ShipInstance = fixture["ship"]
	ship.current_shields["front"] = 0
	assert_false(_commit_order(state).execute(state).is_empty())
	assert_true(not ship.active_debris_resolution_snapshot().is_empty())
	var command: GameCommand = DEBRIS.new(0, _base("obstacle:0").merged({
		"hull_zone": "front",
	}))
	assert_eq(command.validate(state), "")
	var result: Dictionary = command.execute(state)
	assert_eq(result["damage_application"]["facedown_delta"], 2)
	assert_eq(ship.get_facedown_damage_count(), 2)
	assert_true(ship.active_debris_resolution_snapshot().is_empty())
	assert_eq(state.obstacle_placement("obstacle:0")[
			"last_maneuver_execution_id"], EXECUTION_ID)


func test_station_use_decline_no_option_and_unsupported_objective() -> void:
	var fixture: Dictionary = _fixture("station", [])
	var state: GameState = fixture["state"]
	var ship: ShipInstance = fixture["ship"]
	var source: DamageCard = _card(
			"damage:station:0", "ruptured_engine", "persistent")
	source.flip_faceup()
	source.public_card_ref = "faceup:station:0"
	ship.add_faceup_damage(source)
	assert_false(_commit_order(state).execute(state).is_empty())
	var use_command: GameCommand = STATION.new(0, _base("obstacle:0").merged({
		"action": "use_faceup",
		"public_card_ref": "faceup:station:0",
	}))
	assert_eq(use_command.validate(state), "")
	assert_false(use_command.execute(state).is_empty())
	assert_true(ship.faceup_damage.is_empty())
	assert_eq(state.damage_deck.get_discard_count(), 1)

	fixture = _fixture("station", [])
	state = fixture["state"]
	ship = fixture["ship"]
	assert_false(_commit_order(state).execute(state).is_empty())
	var no_option: GameCommand = STATION.new(0, _base("obstacle:0").merged({
		"action": "no_option",
	}))
	assert_eq(no_option.validate(state), "")
	assert_false(no_option.execute(state).is_empty())

	fixture = _fixture("station", [])
	state = fixture["state"]
	state.objectives["selected_objective"] = {
		"data_key": "obj_def_contested_outpost"}
	assert_ne(_commit_order(state).validate(state), "")
	assert_true((fixture["ship"] as ShipInstance) \
			.active_station_resolution_snapshot().is_empty())


func test_nested_asteroid_state_round_trips_and_mismatches_fail_closed() -> void:
	var fixture: Dictionary = _fixture("asteroid_1", [
		_card("damage:save:0", "shield_failure", "immediate")])
	var state: GameState = fixture["state"]
	var ship: ShipInstance = fixture["ship"]
	assert_false(_commit_order(state).execute(state).is_empty())
	var asteroid: GameCommand = ASTEROID.new(0, _base("obstacle:0"))
	asteroid.sequence = 72
	assert_eq(asteroid.validate(state), "")
	assert_false(asteroid.execute(state).is_empty())
	var serialized: Dictionary = ship.serialize()
	var restored: ShipInstance = ShipInstance.deserialize(
			serialized, ship.ship_data)
	assert_not_null(restored)
	assert_eq(restored.active_asteroid_resolution_snapshot(),
			ship.active_asteroid_resolution_snapshot())
	var invalid: Dictionary = serialized.duplicate(true)
	invalid["active_asteroid_resolution"]["immediate_resolution_id"] = \
			"immediate:stale"
	assert_null(ShipInstance.deserialize(invalid, ship.ship_data))


func _fixture(obstacle_key: String,
		deck_cards: Array[DamageCard]) -> Dictionary:
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	state.damage_deck = _deck(deck_cards)
	var ship := ShipInstance.create_from_data("obstacle", _ship_data(), 1, 0)
	ship.roster_entry_id = "obstacle-ship"
	ship.pos_x = 0.5
	ship.pos_y = 0.5
	ship.current_speed = 1
	state.get_player_state(0).ships.append(ship)
	assert_true(ship.establish_ship_activation(ACTIVATION_ID))
	assert_true(ship.open_maneuver_opportunity(ACTIVATION_ID))
	assert_true(ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, {
				"yaw_clicks": [0], "yaw_bonus_joint": -1,
				"pos_x": 0.5, "pos_y": 0.5, "rotation_deg": 0.0,
			}, {"kind": "none"}))
	assert_false(ship.apply_maneuver_final_transform(
			ACTIVATION_ID, EXECUTION_ID).is_empty())
	state.objectives["obstacles"] = [{
		"obstacle_id": "obstacle:0",
		"data_key": obstacle_key,
		"pos_x": 0.5,
		"pos_y": 0.5,
		"rotation_deg": 0.0,
		"placing_player": 0,
		"placement_order": 0,
		"last_maneuver_execution_id": "",
	}]
	return {"state": state, "ship": ship}


func _commit_order(state: GameState) -> GameCommand:
	return ORDER.new(0, _identity_base().merged({
		"obstacle_ids": ["obstacle:0"],
	}))


func _base(obstacle_id: String) -> Dictionary:
	return _identity_base().merged({
		"obstacle_id": obstacle_id,
	})


func _identity_base() -> Dictionary:
	return {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
	}


func _deck(cards: Array[DamageCard]) -> DamageDeck:
	var draw: Array[Dictionary] = []
	for card: DamageCard in cards:
		draw.append(card.serialize_for_save7("draw"))
	return DamageDeck.deserialize_for_save7({
		"draw_pile": draw,
		"discard_pile": [],
	})


func _card(physical_id: String, effect: String,
		timing: String) -> DamageCard:
	var card := DamageCard.new()
	card.physical_card_id = physical_id
	card.effect_id = effect
	card.title = effect
	card.trait_type = "Ship"
	card.timing = timing
	return card


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 8
	data.max_speed = 3
	data.command_value = 1
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data
