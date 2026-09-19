extends GutTest


const FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")
const ASSIGNMENT: GDScript = preload(
		"res://src/core/damage/immediate_damage_authority.gd")
const ATTACK_DAMAGE: GDScript = preload(
		"res://src/core/commands/candidate_resolve_damage_command.gd")
const DEBUG_DAMAGE: GDScript = preload(
		"res://src/core/commands/candidate_debug_deal_damage_command.gd")
const RESOLVE: GDScript = preload(
		"res://src/core/commands/candidate_resolve_immediate_effect_command.gd")
const EFFECTS: Array[String] = [
	"structural_damage", "projector_misaligned", "life_support_failure",
	"injured_crew", "shield_failure", "comm_noise",
]


func test_all_six_branches_bind_and_resolve_from_attack() -> void:
	for index: int in range(EFFECTS.size()):
		var state: GameState = _attack_state(EFFECTS[index], 100 + index)
		var source: GameCommand = ATTACK_DAMAGE.new(0,
				{"attack_id": "attack:%d" % (100 + index)})
		source.sequence = 100 + index
		var assignment: Dictionary = source.execute(state)
		assert_false(assignment.is_empty(), EFFECTS[index])
		var ship: ShipInstance = state.get_ship(1, 0)
		var resolve: GameCommand = _resolver(ship, EFFECTS[index])
		assert_eq(resolve.validate(state), "", EFFECTS[index])
		assert_false(resolve.execute(state).is_empty(), EFFECTS[index])
		assert_false(ship.has_active_immediate_resolution(), EFFECTS[index])


func test_all_six_branches_bind_and_resolve_from_debug() -> void:
	for index: int in range(EFFECTS.size()):
		var state: GameState = _plain_state()
		var ship: ShipInstance = state.get_ship(0, 0)
		state.damage_deck = _deck(EFFECTS[index])
		var source: GameCommand = DEBUG_DAMAGE.new(0, {
			"owner_player": 0, "ship_index": 0,
			"effect_id": EFFECTS[index],
		})
		source.sequence = 200 + index
		assert_false(source.execute(state).is_empty(), EFFECTS[index])
		var resolve: GameCommand = _resolver(ship, EFFECTS[index])
		assert_eq(resolve.validate(state), "", EFFECTS[index])
		assert_false(resolve.execute(state).is_empty(), EFFECTS[index])
		assert_false(ship.has_active_immediate_resolution(), EFFECTS[index])


func test_direct_maneuver_binding_cannot_bypass_asteroid_enclosure_owner() -> void:
	for index: int in range(EFFECTS.size()):
		var state: GameState = _plain_state()
		var ship: ShipInstance = state.get_ship(0, 0)
		assert_true(ship.establish_ship_activation("ship-activation:matrix"))
		assert_true(ship.open_maneuver_opportunity("ship-activation:matrix"))
		assert_true(ship.commit_maneuver_execution(
				"ship-activation:matrix", "maneuver:matrix", false, {
			"yaw_clicks": [], "yaw_bonus_joint": -1,
			"pos_x": 0.5, "pos_y": 0.5, "rotation_deg": 0.0,
		}, {"kind": "none"}))
		state.damage_deck = _deck(EFFECTS[index])
		var card: DamageCard = state.damage_deck.draw_card()
		card.flip_faceup()
		ship.add_faceup_damage(card)
		var addition: Dictionary = ASSIGNMENT.bind_assigned_faceup(
				state, 0, 0, card, 300 + index, 0, {
			"enclosing_kind": "maneuver",
			"ship_activation_identity": "ship-activation:matrix",
			"maneuver_execution_id": "maneuver:matrix",
			"maneuver_source_kind": "asteroid",
			"maneuver_source_id": "obstacle:synthetic",
		})
		assert_false(addition.is_empty(), EFFECTS[index])
		var resolve: GameCommand = _resolver(ship, EFFECTS[index])
		assert_ne(resolve.validate(state), "", EFFECTS[index])
		assert_true(resolve.execute(state).is_empty(), EFFECTS[index])
		assert_true(ship.has_active_immediate_resolution(), EFFECTS[index])


func test_all_six_debug_obligations_round_trip_and_rederive_legal_resolution() -> void:
	for index: int in range(EFFECTS.size()):
		var state: GameState = _plain_state()
		var ship: ShipInstance = state.get_ship(0, 0)
		state.damage_deck = _deck(EFFECTS[index])
		var source: GameCommand = DEBUG_DAMAGE.new(0, {
			"owner_player": 0, "ship_index": 0,
			"effect_id": EFFECTS[index],
		})
		source.sequence = 400 + index
		assert_false(source.execute(state).is_empty(), EFFECTS[index])
		var restored := GameState.new()
		restored.initialize()
		restored.current_phase = Constants.GamePhase.SHIP
		var restored_ship := ShipInstance.create_from_data(
				"matrix", _ship_data(), ship.current_speed, 0)
		assert_true(restored_ship.install_damage_state_for_save7(
				ship.serialize_damage_state_for_save7()), EFFECTS[index])
		restored.get_player_state(0).ships.append(restored_ship)
		restored.damage_deck = DamageDeck.deserialize_for_save7(
				state.damage_deck.serialize_for_save7())
		assert_true(restored.validate_damage_state_for_save7(), EFFECTS[index])
		var resolve: GameCommand = _resolver(restored_ship, EFFECTS[index])
		assert_eq(resolve.validate(restored), "", EFFECTS[index])
		assert_false(resolve.execute(restored).is_empty(), EFFECTS[index])


func _resolver(ship: ShipInstance, effect: String) -> GameCommand:
	var record: Dictionary = ship.active_immediate_resolution_snapshot()
	var payload: Dictionary = {
		"owner_player": ship.owner_player,
		"ship_index": 0,
		"public_card_ref": record["public_card_ref"],
		"immediate_resolution_id": record["immediate_resolution_id"],
		"enclosing_kind": record["enclosing_kind"],
	}
	match str(record["enclosing_kind"]):
		"attack":
			payload["attack_id"] = record["attack_id"]
		"debug":
			payload["debug_application_id"] = record["debug_application_id"]
		"maneuver":
			for key: String in [
				"ship_activation_identity", "maneuver_execution_id",
				"maneuver_source_kind", "maneuver_source_id"]:
				payload[key] = record[key]
	if effect == "shield_failure":
		payload["shield_zones"] = []
	if effect == "injured_crew" and ship.defense_tokens.size() > 1:
		payload["defense_token_index"] = 0
	if effect == "comm_noise":
		payload["comm_noise_action"] = "speed"
	var actor: int = int(record["actor_player"])
	return RESOLVE.new(ship.owner_player if actor == -1 else actor, payload)


func _attack_state(effect: String, sequence: int) -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	assert_not_null(FIXTURE.install(state, {
		"attack_id": "attack:%d" % sequence,
		"stage": CurrentAttackState.STAGE_DEFENSE,
		"defense_stage": CurrentAttackState.DEFENSE_COMPLETE,
		"defender_player": 1,
		"defender_index": 0,
		"defender_zone": int(Constants.HullZone.FRONT),
		"dice_results": [{
			"color": int(Constants.DiceColor.RED),
			"face": int(Constants.DiceFace.CRITICAL),
		}],
	}))
	var ship: ShipInstance = state.get_ship(1, 0)
	for zone: String in ship.current_shields:
		ship.current_shields[zone] = 0
	state.damage_deck = _deck(effect)
	return state


func _plain_state() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	var ship := ShipInstance.create_from_data("matrix", _ship_data(), 1, 0)
	ship.pos_x = 0.5
	ship.pos_y = 0.5
	state.get_player_state(0).ships.append(ship)
	state.damage_deck = DamageDeck.deserialize_for_save7({
		"draw_pile": [], "discard_pile": []})
	return state


func _deck(effect: String) -> DamageDeck:
	var card := DamageCard.create("Ship", effect)
	card.physical_card_id = "damage:matrix:%s" % effect
	card.effect_id = effect
	card.timing = "immediate_persistent" \
			if effect == "life_support_failure" else "immediate"
	return DamageDeck.deserialize_for_save7({
		"draw_pile": [card.serialize_for_save7("draw")],
		"discard_pile": [],
	})


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.ship_size = Constants.ShipSize.SMALL
	data.hull = 10
	data.max_speed = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 0, "left": 0, "right": 0, "rear": 0}
	return data
