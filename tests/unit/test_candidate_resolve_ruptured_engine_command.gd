extends GutTest


const COMMAND: GDScript = preload(
		"res://src/core/commands/candidate_resolve_ruptured_engine_command.gd")
const EVALUATOR: GDScript = preload(
		"res://src/core/movement/maneuver_execution_evaluator.gd")

const ACTIVATION_ID := "ship-activation:80"
const EXECUTION_ID := "maneuver:80"

var _state: GameState
var _ship: ShipInstance


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	_state.damage_deck = _deck([
		_card("damage:draw:0", "ordinary"),
		_card("damage:draw:1", "ordinary"),
	])
	_ship = ShipInstance.create_from_data("ruptured", _ship_data(), 1, 0)
	_ship.roster_entry_id = "ruptured-ship"
	_ship.current_speed = 2
	_state.get_player_state(0).ships.append(_ship)
	assert_true(_ship.establish_ship_activation(ACTIVATION_ID))
	assert_true(_ship.open_maneuver_opportunity(ACTIVATION_ID))
	assert_true(_ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, {
				"yaw_clicks": [0], "yaw_bonus_joint": -1,
				"pos_x": 0.4, "pos_y": 0.4, "rotation_deg": 0.0,
			}, {"kind": "none"}))
	assert_false(_ship.apply_maneuver_final_transform(
			ACTIVATION_ID, EXECUTION_ID).is_empty())
	_add_source("damage:source:0", "faceup:source:0")
	_add_source("damage:source:1", "faceup:source:1")


func test_rederives_each_still_faceup_copy_then_completes() -> void:
	var first: Dictionary = EVALUATOR.next_action(_state, 0, 0)
	assert_eq(first["command_type"], "resolve_ruptured_engine")
	assert_eq(first["payload"]["public_card_ref"], "faceup:source:0")
	var command: GameCommand = _command("faceup:source:0", "front")
	assert_eq(command.validate(_state), "")
	assert_false(command.execute(_state).is_empty())
	assert_eq(_ship.current_shields["front"], 0)
	assert_ne(command.validate(_state), "")

	var second: Dictionary = EVALUATOR.next_action(_state, 0, 0)
	assert_eq(second["payload"]["public_card_ref"], "faceup:source:1")
	assert_false(_command("faceup:source:1", "front").execute(_state).is_empty())
	assert_eq(_ship.get_facedown_damage_count(), 1)
	assert_eq(EVALUATOR.next_action(_state, 0, 0)["command_type"],
			"complete_maneuver")


func test_speed_survival_faceup_and_obstacle_order_are_rederived() -> void:
	_ship.current_speed = 0
	assert_ne(_command("faceup:source:0", "front").validate(_state), "")
	_ship.current_speed = 1
	assert_ne(_command("faceup:source:0", "front").validate(_state), "")
	_ship.current_speed = 2
	var source: DamageCard = _ship.faceup_card_for_public_ref(
			"faceup:source:0")
	source.flip_facedown()
	_ship.faceup_damage.erase(source)
	_ship.facedown_damage.append(source)
	assert_ne(_command("faceup:source:0", "front").validate(_state), "")

	_ship.mark_destroyed()
	assert_ne(_command("faceup:source:1", "front").validate(_state), "")


func test_lethal_hull_point_converges_on_passive_peer_and_cleans_execution() -> void:
	var second: DamageCard = _ship.faceup_card_for_public_ref(
			"faceup:source:1")
	_ship.faceup_damage.erase(second)
	_ship.ship_data.hull = 2
	_ship.current_shields["front"] = 0
	var authority_command: GameCommand = _command("faceup:source:0", "front")
	var result: Dictionary = authority_command.execute(_state)
	assert_true(bool(result["damage_application"]["destroyed"]))
	assert_false(_ship.has_active_maneuver_execution())

	var passive := GameState.new()
	passive.initialize()
	passive.current_phase = Constants.GamePhase.SHIP
	passive.damage_deck = null
	passive.rng = null
	var mirror := ShipInstance.create_from_data(
			"ruptured", _ship_data(), 2, 0)
	mirror.ship_data.hull = 2
	mirror.roster_entry_id = "ruptured-ship"
	mirror.current_speed = 2
	mirror.current_shields["front"] = 0
	var public_source := DamageCard.create("Ship", "Ruptured Engine")
	public_source.effect_id = "ruptured_engine"
	public_source.timing = "persistent"
	public_source.is_faceup = true
	public_source.public_card_ref = "faceup:source:0"
	mirror.add_faceup_damage(public_source)
	passive.get_player_state(0).ships.append(mirror)
	passive.passive_damage_ledger = PassiveDamageLedger.deserialize({
		"schema_version": 1,
		"draw_count": 2,
		"discard_pile": [],
		"facedown_counts": {"0:ruptured-ship": 0},
	}, ["0:ruptured-ship"])
	assert_true(mirror.bind_passive_damage_ledger(
			passive.passive_damage_ledger, "0:ruptured-ship"))
	assert_true(mirror.establish_ship_activation(ACTIVATION_ID))
	assert_true(mirror.open_maneuver_opportunity(ACTIVATION_ID))
	assert_true(mirror.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, false, {
				"yaw_clicks": [0], "yaw_bonus_joint": -1,
				"pos_x": 0.4, "pos_y": 0.4, "rotation_deg": 0.0,
			}, {"kind": "none"}))
	assert_false(mirror.apply_maneuver_final_transform(
			ACTIVATION_ID, EXECUTION_ID).is_empty())
	var passive_command: GameCommand = COMMAND.new(
			0, authority_command.payload.duplicate(true))
	var projected: Dictionary = passive_command.project_application_result(
			result, 1)
	assert_eq(passive_command.execute_with_application_result(
			passive, projected), projected)
	assert_true(mirror.is_destroyed())
	assert_eq(mirror.get_facedown_damage_count(), 1)
	assert_eq(passive.passive_damage_ledger.draw_count, 1)
	assert_false(mirror.has_active_maneuver_execution())


func _command(public_ref: String, zone: String) -> GameCommand:
	return COMMAND.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
		"public_card_ref": public_ref,
		"hull_zone": zone,
	})


func _add_source(physical_id: String, public_ref: String) -> void:
	var card: DamageCard = _card(physical_id, "ruptured_engine")
	card.flip_faceup()
	card.public_card_ref = public_ref
	_ship.add_faceup_damage(card)


func _deck(cards: Array[DamageCard]) -> DamageDeck:
	var draw: Array[Dictionary] = []
	for card: DamageCard in cards:
		draw.append(card.serialize_for_save7("draw"))
	return DamageDeck.deserialize_for_save7({
		"draw_pile": draw, "discard_pile": []})


func _card(physical_id: String, effect: String) -> DamageCard:
	var card := DamageCard.new()
	card.physical_card_id = physical_id
	card.effect_id = effect
	card.title = effect
	card.trait_type = "Ship"
	card.timing = "persistent"
	return card


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 6
	data.max_speed = 3
	data.command_value = 1
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data
