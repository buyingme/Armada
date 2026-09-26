extends GutTest


const COMMAND: GDScript = preload(
		"res://src/core/commands/candidate_resolve_thruster_fissure_command.gd")
const APPLY: GDScript = preload(
		"res://src/core/commands/candidate_apply_maneuver_transform_command.gd")
const EVALUATOR: GDScript = preload(
		"res://src/core/movement/maneuver_pre_movement_evaluator.gd")
const PROCESSOR: GDScript = preload("res://src/autoload/command_processor.gd")

const ACTIVATION_ID := "ship-activation:20"
const EXECUTION_ID := "maneuver:20"

var _state: GameState
var _ship: ShipInstance


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	_state.damage_deck = _deck([])
	_ship = ShipInstance.create_from_data("thruster", _ship_data(), 1, 0)
	_ship.pos_x = 0.25
	_ship.pos_y = 0.25
	_state.get_player_state(0).ships.append(_ship)
	assert_true(_ship.establish_ship_activation(ACTIVATION_ID))
	assert_true(_ship.open_maneuver_opportunity(ACTIVATION_ID))


func test_each_faceup_instance_resolves_before_transform_application() -> void:
	_add_thruster("damage:1", "faceup:1:0")
	_add_thruster("damage:2", "faceup:2:0")
	_commit(true)
	assert_eq(EVALUATOR.unresolved_thruster_fissures(_ship),
			["faceup:1:0", "faceup:2:0"])
	assert_ne(_apply().validate(_state), "")

	var first: Dictionary = _resolve("faceup:1:0", "front")
	assert_eq(first["damage_application"]["shield_changes"], [
		{"zone": "front", "new_shields": 0},
	])
	assert_eq(EVALUATOR.unresolved_thruster_fissures(_ship), ["faceup:2:0"])
	assert_ne(_apply().validate(_state), "")

	assert_false(_resolve("faceup:2:0", "left").is_empty())
	assert_true(EVALUATOR.unresolved_thruster_fissures(_ship).is_empty())
	var applied: Dictionary = _apply().execute(_state)
	assert_false(applied.is_empty())
	assert_eq(Vector2(_ship.pos_x, _ship.pos_y), Vector2(0.5, 0.6))


func test_duplicate_stale_wrong_actor_and_nonqualifying_change_reject() -> void:
	_add_thruster("damage:3", "faceup:3:0")
	_commit(true)
	var command: GameCommand = _command("faceup:3:0", "front")
	command.player_index = 1
	assert_ne(command.validate(_state), "")
	command.player_index = 0
	command.payload["maneuver_execution_id"] = "maneuver:stale"
	assert_ne(command.validate(_state), "")
	command.payload["maneuver_execution_id"] = EXECUTION_ID
	assert_false(command.execute(_state).is_empty())
	assert_ne(command.validate(_state), "")

	_reset_execution(false)
	assert_true(EVALUATOR.unresolved_thruster_fissures(_ship).is_empty())
	assert_ne(_command("faceup:3:0", "front").validate(_state), "")


func test_hull_damage_destroys_before_movement_and_cleans_execution() -> void:
	_ship.current_shields["front"] = 0
	_ship.ship_data.hull = 2
	_add_thruster("damage:4", "faceup:4:0")
	_state.damage_deck = _deck([_card("damage:5", "ordinary")])
	_commit(true)
	var before := Vector2(_ship.pos_x, _ship.pos_y)
	var command: GameCommand = _command("faceup:4:0", "front")
	assert_eq(command.validate(_state), "")
	var result: Dictionary = command.execute(_state)
	assert_true(bool(result["damage_application"]["destroyed"]))
	assert_true(_ship.is_destroyed())
	assert_false(_ship.has_active_maneuver_execution())
	assert_eq(Vector2(_ship.pos_x, _ship.pos_y), before)
	assert_eq(_apply().execute(_state), {})


func test_v3_processor_pre_movement_death_cleans_once_without_transform() -> void:
	_ship.current_shields["front"] = 0
	_ship.ship_data.hull = 2
	_add_thruster("damage:v3:thruster", "faceup:v3:thruster")
	_state.damage_deck = _deck([_card("damage:v3:lethal", "ordinary")])
	_commit(true)
	GameManager.current_game_state = _state
	var processor: Node = PROCESSOR.new()
	add_child_autofree(processor)
	var before := Vector2(_ship.pos_x, _ship.pos_y)

	assert_false(processor.submit(
			_command("faceup:v3:thruster", "front")).is_empty())

	assert_true(_ship.has_finalized_destruction())
	assert_eq(Vector2(_ship.pos_x, _ship.pos_y), before)
	assert_eq(_processor_types(processor), [
		"resolve_thruster_fissure", "destroy_unit", "advance_phase"])
	assert_false(_processor_types(processor).has("apply_maneuver_transform"))
	assert_false(_processor_types(processor).has("complete_maneuver"))


func test_passive_application_consumes_aggregate_draw_and_suppresses_transform() -> void:
	_ship.current_shields["front"] = 0
	_ship.ship_data.hull = 2
	_add_thruster("damage:6", "faceup:6:0")
	_state.damage_deck = _deck([_card("damage:7", "ordinary")])
	_commit(true)
	var authority: GameCommand = _command("faceup:6:0", "front")
	var result: Dictionary = authority.execute(_state)
	var passive := GameState.new()
	passive.initialize()
	passive.current_phase = Constants.GamePhase.SHIP
	passive.damage_deck = null
	passive.rng = null
	var mirror := ShipInstance.create_from_data(
			"thruster", _ship_data(), 1, 0)
	mirror.ship_data.hull = 2
	mirror.roster_entry_id = "thruster-passive"
	mirror.pos_x = 0.25
	mirror.pos_y = 0.25
	mirror.current_shields["front"] = 0
	var public_source := DamageCard.create("Ship", "Thruster Fissure")
	public_source.effect_id = "thruster_fissure"
	public_source.timing = "persistent"
	public_source.is_faceup = true
	public_source.public_card_ref = "faceup:6:0"
	mirror.add_faceup_damage(public_source)
	passive.get_player_state(0).ships.append(mirror)
	passive.passive_damage_ledger = PassiveDamageLedger.deserialize({
		"schema_version": 1, "draw_count": 1, "discard_pile": [],
		"facedown_counts": {"0:thruster-passive": 0},
	}, ["0:thruster-passive"])
	assert_true(mirror.bind_passive_damage_ledger(
			passive.passive_damage_ledger, "0:thruster-passive"))
	assert_true(mirror.establish_ship_activation(ACTIVATION_ID))
	assert_true(mirror.open_maneuver_opportunity(ACTIVATION_ID))
	assert_true(mirror.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, true, {
		"yaw_clicks": [0], "yaw_bonus_joint": -1,
		"pos_x": 0.5, "pos_y": 0.6, "rotation_deg": 15.0,
	}, {"kind": "none"}))
	var command: GameCommand = COMMAND.new(0, authority.payload.duplicate(true))
	assert_eq(command.execute_with_application_result(passive, result), result)
	assert_true(mirror.is_destroyed())
	assert_eq(passive.passive_damage_ledger.draw_count, 0)
	assert_false(mirror.has_active_maneuver_execution())
	assert_eq(Vector2(mirror.pos_x, mirror.pos_y), Vector2(0.25, 0.25))


func test_save7_recovery_rederives_same_unresolved_pre_movement_instance() -> void:
	_add_thruster("damage:8", "faceup:8:0")
	_state.damage_deck = _deck([_card("damage:9", "ordinary")])
	_commit(true)
	var recovered := GameState.new()
	recovered.initialize()
	recovered.current_phase = Constants.GamePhase.SHIP
	var mirror := ShipInstance.create_from_data("thruster", _ship_data(), 1, 0)
	mirror.pos_x = _ship.pos_x
	mirror.pos_y = _ship.pos_y
	assert_true(mirror.restore_ship_activation_boundary(
			_ship.ship_activation_boundary_snapshot()))
	assert_true(mirror.install_damage_state_for_save7(
			_ship.serialize_damage_state_for_save7()))
	recovered.get_player_state(0).ships.append(mirror)
	recovered.damage_deck = DamageDeck.deserialize_for_save7(
			_state.damage_deck.serialize_for_save7())
	assert_eq(EVALUATOR.unresolved_thruster_fissures(mirror), ["faceup:8:0"])
	var command: GameCommand = COMMAND.new(0, {
		"owner_player": 0, "ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
		"public_card_ref": "faceup:8:0", "hull_zone": "front",
	})
	assert_eq(command.validate(recovered), "")


func _commit(speed_changed: bool) -> void:
	assert_true(_ship.commit_maneuver_execution(
			ACTIVATION_ID, EXECUTION_ID, speed_changed, {
				"yaw_clicks": [0],
				"yaw_bonus_joint": -1,
				"pos_x": 0.5,
				"pos_y": 0.6,
				"rotation_deg": 15.0,
			}, {"kind": "none"}))


func _reset_execution(speed_changed: bool) -> void:
	assert_true(_ship.clear_maneuver_execution_exceptionally(
			ACTIVATION_ID, EXECUTION_ID))
	_commit(speed_changed)


func _resolve(public_ref: String, zone: String) -> Dictionary:
	return _command(public_ref, zone).execute(_state)


func _command(public_ref: String, zone: String) -> GameCommand:
	return COMMAND.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
		"public_card_ref": public_ref,
		"hull_zone": zone,
	})


func _apply() -> GameCommand:
	return APPLY.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"ship_activation_identity": ACTIVATION_ID,
		"maneuver_execution_id": EXECUTION_ID,
	})


func _add_thruster(physical_id: String, public_ref: String) -> void:
	var card: DamageCard = _card(physical_id, "thruster_fissure")
	card.is_faceup = true
	card.public_card_ref = public_ref
	_ship.add_faceup_damage(card)


func _deck(cards: Array[DamageCard]) -> DamageDeck:
	var draw: Array[Dictionary] = []
	for card: DamageCard in cards:
		draw.append(card.serialize_for_save7("draw"))
	return DamageDeck.deserialize_for_save7({
		"draw_pile": draw,
		"discard_pile": [],
	})


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
	data.hull = 5
	data.max_speed = 3
	data.command_value = 1
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	return data


func _processor_types(processor: Node) -> Array[String]:
	var result: Array[String] = []
	for command: GameCommand in processor.get_history():
		result.append(command.command_type)
	return result
