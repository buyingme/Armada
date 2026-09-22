extends GutTest


const ASSIGNMENT: GDScript = preload(
		"res://src/core/damage/immediate_damage_authority.gd")
const COMMAND: GDScript = preload(
		"res://src/core/commands/candidate_resolve_immediate_effect_command.gd")

var _state: GameState
var _ship: ShipInstance
var _sequence: int = 100


func before_each() -> void:
	_sequence = 100
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	_ship = ShipInstance.create_from_data("immediate", _ship_data(), 2, 0)
	_state.get_player_state(0).ships.append(_ship)


func test_structural_draws_extra_then_flips_or_completes_when_exhausted() -> void:
	_assign("structural_damage", "immediate", [
			_card("damage:999", "ordinary", "persistent"),
	])
	var result: Dictionary = _resolve({})
	assert_true(bool(result["effect_result"]["additional_card_dealt"]))
	assert_eq(result["damage_application"]["facedown_delta"], 2)
	assert_eq(result["damage_application"]["faceup_removals"],
			["faceup:101:0"])
	assert_eq(_ship.facedown_damage.size(), 2)

	_reset_ship()
	_assign("structural_damage", "immediate")
	result = _resolve({})
	assert_false(bool(result["effect_result"]["additional_card_dealt"]))
	assert_eq(_ship.facedown_damage.size(), 1)
	assert_false(_ship.has_active_immediate_resolution())


func test_structural_reshuffles_discard_without_synthesizing_damage() -> void:
	_assign("structural_damage", "immediate")
	var recycled: DamageCard = _card(
			"damage:recycled", "ordinary", "persistent")
	_state.damage_deck = DamageDeck.deserialize_for_save7({
		"draw_pile": [],
		"discard_pile": [recycled.serialize_for_save7("discard")],
	})
	var result: Dictionary = _resolve({})
	assert_true(bool(result["effect_result"]["additional_card_dealt"]))
	assert_eq(result["damage_application"]["facedown_delta"], 2)
	assert_eq(_ship.facedown_damage.size(), 2)
	assert_eq(_state.damage_deck.get_total_count(), 0)


func test_projector_unique_is_automatic_and_positive_tie_requires_owner() -> void:
	_assign("projector_misaligned", "immediate")
	var result: Dictionary = _resolve({})
	assert_eq(result["effect_result"], {"zone": "front", "shields_lost": 2})
	assert_eq(_ship.current_shields["front"], 0)

	_reset_ship()
	_ship.current_shields["left"] = 2
	_assign("projector_misaligned", "immediate")
	var command: GameCommand = _command({"projector_zone": "left"})
	assert_eq(command.player_index, 0)
	assert_eq(command.validate(_state), "")
	result = command.execute(_state)
	assert_eq(result["effect_result"], {"zone": "left", "shields_lost": 2})


func test_projector_zero_all_zone_tie_and_pending_revalidation() -> void:
	_ship.current_shields = {"front": 0, "left": 0, "right": 0, "rear": 0}
	_assign("projector_misaligned", "immediate")
	var result: Dictionary = _resolve({})
	assert_eq(result["effect_result"], {"zone": "", "shields_lost": 0})

	_reset_ship()
	_ship.current_shields = {"front": 1, "left": 1, "right": 1, "rear": 1}
	_assign("projector_misaligned", "immediate")
	var tied: GameCommand = _command({"projector_zone": "left"})
	assert_eq(tied.validate(_state), "")
	_ship.current_shields["right"] = 2
	assert_ne(tied.validate(_state), "")
	assert_eq(tied.execute(_state), {})


func test_life_support_clears_tokens_but_retains_faceup_persistent_source() -> void:
	assert_true(_ship.command_tokens.add_token(Constants.CommandType.REPAIR))
	_assign("life_support_failure", "immediate_persistent")
	var result: Dictionary = _resolve({})
	assert_eq(result["source_disposition"], "faceup")
	assert_eq(result["effect_result"], {"tokens_cleared": true})
	assert_eq(_ship.command_tokens.get_token_count(), 0)
	assert_eq(_ship.faceup_damage.size(), 1)
	assert_false(_ship.has_active_immediate_resolution())


func test_injured_zero_and_one_are_automatic_multiple_is_owner_choice() -> void:
	_ship.defense_tokens.clear()
	_assign("injured_crew", "immediate")
	var result: Dictionary = _resolve({})
	assert_eq(result["effect_result"], {"defense_token_index": -1})

	_reset_ship()
	_ship.defense_tokens = [_ship.defense_tokens[0].duplicate(true)]
	_assign("injured_crew", "immediate")
	result = _resolve({})
	assert_eq(result["effect_result"], {"defense_token_index": 0})
	assert_eq(_ship.defense_tokens[0]["state"],
			Constants.DefenseTokenState.DISCARDED)

	_reset_ship()
	_assign("injured_crew", "immediate")
	var command: GameCommand = _command({"defense_token_index": 1})
	assert_eq(command.player_index, 0)
	assert_eq(command.validate(_state), "")
	result = command.execute(_state)
	assert_eq(result["effect_result"], {"defense_token_index": 1})


func test_injured_pending_choice_revalidates_token_state() -> void:
	_assign("injured_crew", "immediate")
	var command: GameCommand = _command({"defense_token_index": 1})
	assert_eq(command.validate(_state), "")
	_ship.defense_tokens[1]["state"] = Constants.DefenseTokenState.DISCARDED
	assert_ne(command.validate(_state), "")
	assert_eq(command.execute(_state), {})


func test_shield_failure_opponent_selects_zero_to_two_distinct_zones() -> void:
	_assign("shield_failure", "immediate")
	var wrong: GameCommand = _command({"shield_zones": ["left"]})
	wrong.player_index = 0
	assert_ne(wrong.validate(_state), "")
	var result: Dictionary = _resolve({"shield_zones": ["left", "rear"]})
	assert_eq(result["effect_result"],
			{"shield_zones": ["left", "rear"]})
	assert_eq(_ship.current_shields["left"], 0)
	assert_eq(_ship.current_shields["rear"], 0)


func test_shield_failure_accepts_zero_one_and_zero_shield_zone() -> void:
	for zones: Array in [[], ["front"], ["left"]]:
		_reset_ship()
		if zones == ["left"]:
			_ship.current_shields["left"] = 0
		_assign("shield_failure", "immediate")
		var result: Dictionary = _resolve({"shield_zones": zones})
		assert_eq(result["effect_result"]["shield_zones"], zones)
		assert_false(_ship.has_active_immediate_resolution())


func test_comm_noise_all_four_availability_branches() -> void:
	_add_hidden_dial()
	_assign("comm_noise", "immediate")
	var result: Dictionary = _resolve({"comm_noise_action": "speed"})
	assert_eq(result["effect_result"],
			{"comm_noise_action": "speed", "new_speed": 1})

	_reset_ship()
	_add_hidden_dial()
	_ship.current_speed = 0
	_assign("comm_noise", "immediate")
	result = _resolve({"comm_noise_action": "dial",
		"replacement_command": int(Constants.CommandType.REPAIR)})
	assert_eq(result["effect_result"]["comm_noise_action"], "dial")
	assert_true(bool(result["effect_result"]["dial_changed"]))

	_reset_ship()
	_assign("comm_noise", "immediate")
	result = _resolve({"comm_noise_action": "speed"})
	assert_eq(result["effect_result"]["new_speed"], 1)

	_reset_ship()
	_ship.current_speed = 0
	_assign("comm_noise", "immediate")
	result = _resolve({"comm_noise_action": "none"})
	assert_eq(result["effect_result"], {"comm_noise_action": "none"})


func test_comm_noise_accepts_every_replacement_command_value() -> void:
	for replacement: int in range(4):
		_reset_ship()
		_ship.current_speed = 0
		_add_hidden_dial()
		_assign("comm_noise", "immediate")
		var result: Dictionary = _resolve({
			"comm_noise_action": "dial",
			"replacement_command": replacement,
		})
		assert_eq(result["effect_result"]["replacement_command"], replacement)
		assert_false(_ship.has_active_immediate_resolution())


func test_stale_duplicate_unknown_or_extra_fields_reject_without_mutation() -> void:
	_assign("shield_failure", "immediate")
	var command: GameCommand = _command({"shield_zones": []})
	command.payload["physical_card_id"] = "damage:100"
	var before: Dictionary = _ship.serialize_damage_state_for_save7()
	assert_ne(command.validate(_state), "")
	assert_eq(command.execute(_state), {})
	assert_eq(_ship.serialize_damage_state_for_save7(), before)
	command.payload.erase("physical_card_id")
	assert_false(command.execute(_state).is_empty())
	assert_ne(command.validate(_state), "")
	assert_eq(command.execute(_state), {})


func test_comm_noise_payload_never_accepts_old_hidden_dial_value() -> void:
	_add_hidden_dial()
	_ship.current_speed = 0
	_assign("comm_noise", "immediate")
	var command: GameCommand = _command({
		"comm_noise_action": "dial",
		"replacement_command": int(Constants.CommandType.REPAIR),
		"old_command": int(Constants.CommandType.NAVIGATE),
	})
	assert_ne(command.validate(_state), "")


func test_contract_2_passive_application_uses_aggregate_result_without_draw() -> void:
	_assign("structural_damage", "immediate", [
		_card("damage:999", "ordinary", "persistent")])
	var authority_command: GameCommand = _command({})
	var authority_result: Dictionary = authority_command.execute(_state)
	var passive := GameState.new()
	passive.initialize()
	passive.damage_deck = null
	passive.rng = null
	var passive_ship := ShipInstance.create_from_data(
			"immediate", _ship_data(), 2, 0)
	passive_ship.roster_entry_id = "ship-0"
	var public_source := DamageCard.create("Ship", "structural_damage")
	public_source.effect_id = "structural_damage"
	public_source.timing = "immediate"
	public_source.is_faceup = true
	public_source.public_card_ref = "faceup:101:0"
	passive_ship.add_faceup_damage(public_source)
	passive.get_player_state(0).ships.append(passive_ship)
	passive.passive_damage_ledger = PassiveDamageLedger.deserialize({
		"schema_version": 1,
		"draw_count": 1,
		"discard_pile": [],
		"facedown_counts": {"0:ship-0": 0},
	}, ["0:ship-0"])
	assert_true(passive_ship.bind_passive_damage_ledger(
			passive.passive_damage_ledger, "0:ship-0"))
	assert_true(passive_ship.establish_filtered_immediate_resolution({
		"immediate_resolution_id": "immediate:faceup:101:0",
		"public_card_ref": "faceup:101:0",
		"effect_id": "structural_damage",
		"actor_player": -1,
		"enclosing_kind": "debug",
		"debug_application_id": "debug:101",
	}))
	var passive_command: GameCommand = COMMAND.new(
			authority_command.player_index, authority_command.payload.duplicate(true))
	assert_eq(passive_command.application_contract_version(), 2)
	var projected: Dictionary = passive_command.project_application_result(
			authority_result, 0)
	assert_false(projected.is_empty())
	assert_eq(passive_command.execute_with_application_result(
			passive, projected), projected)
	assert_eq(passive_ship.get_facedown_damage_count(), 2)
	assert_eq(passive_ship.faceup_damage.size(), 0)
	assert_null(passive.damage_deck)


func test_contract_2_passive_application_applies_each_public_effect() -> void:
	_ship.current_shields["left"] = 2
	_assign("projector_misaligned", "immediate")
	var projector: Dictionary = _resolve_with_passive(
			{"projector_zone": "left"})
	assert_eq((projector["ship"] as ShipInstance).current_shields["left"], 0)

	_reset_ship()
	assert_true(_ship.command_tokens.add_token(Constants.CommandType.REPAIR))
	_assign("life_support_failure", "immediate_persistent")
	var life_support: Dictionary = _resolve_with_passive({})
	assert_eq((life_support["ship"] as ShipInstance).command_tokens \
			.get_token_count(), 0)
	assert_eq((life_support["ship"] as ShipInstance).faceup_damage.size(), 1)

	_reset_ship()
	_assign("injured_crew", "immediate")
	var injured: Dictionary = _resolve_with_passive(
			{"defense_token_index": 1})
	assert_eq((injured["ship"] as ShipInstance).defense_tokens[1]["state"],
			Constants.DefenseTokenState.DISCARDED)

	_reset_ship()
	_assign("shield_failure", "immediate")
	var shield: Dictionary = _resolve_with_passive(
			{"shield_zones": ["left", "rear"]})
	assert_eq((shield["ship"] as ShipInstance).current_shields["left"], 0)
	assert_eq((shield["ship"] as ShipInstance).current_shields["rear"], 0)

	_reset_ship()
	_add_hidden_dial()
	_assign("comm_noise", "immediate")
	var comm: Dictionary = _resolve_with_passive(
			{"comm_noise_action": "speed"})
	assert_eq((comm["ship"] as ShipInstance).current_speed, 1)


func test_contract_2_passive_rejects_inconsistent_public_effect_before_mutation() -> void:
	_assign("shield_failure", "immediate")
	var command: GameCommand = _command({"shield_zones": ["left"]})
	var passive: Dictionary = _passive_mirror()
	var result: Dictionary = command.execute(_state)
	result["effect_result"]["shield_zones"] = ["right"]
	var mirror: GameCommand = COMMAND.new(
			command.player_index, command.payload.duplicate(true))
	var passive_ship: ShipInstance = passive["ship"] as ShipInstance
	var before: Dictionary = passive_ship \
			.serialize_filtered_damage_state_for_protocol7()
	assert_eq(mirror.execute_with_application_result(
			passive["state"] as GameState, result), {})
	assert_eq(passive_ship.serialize_filtered_damage_state_for_protocol7(),
			before)


func _assign(effect: String, timing: String,
		extra_draw_cards: Array[DamageCard] = []) -> void:
	_sequence += 1
	var draw: Array[Dictionary] = []
	for card: DamageCard in extra_draw_cards:
		draw.append(card.serialize_for_save7("draw"))
	var source: DamageCard = _card("damage:%d" % _sequence, effect, timing)
	draw.append(source.serialize_for_save7("draw"))
	_state.damage_deck = DamageDeck.deserialize_for_save7({
		"draw_pile": draw, "discard_pile": []})
	var actor: int = ASSIGNMENT.derive_actor_player(_ship, source)
	var addition: Dictionary = ASSIGNMENT.assign_drawn_faceup(
			_state, 0, 0, _sequence, 0, {
				"enclosing_kind": "debug",
				"debug_application_id": "debug:%d" % _sequence,
			}, actor)
	assert_false(addition.is_empty())


func _command(choice: Dictionary) -> GameCommand:
	var record: Dictionary = _ship.active_immediate_resolution_snapshot()
	var data: Dictionary = {
		"owner_player": 0,
		"ship_index": 0,
		"public_card_ref": record["public_card_ref"],
		"immediate_resolution_id": record["immediate_resolution_id"],
		"enclosing_kind": "debug",
		"debug_application_id": record["debug_application_id"],
	}
	for key: Variant in choice:
		data[key] = choice[key]
	var actor: int = int(record["actor_player"])
	return COMMAND.new(0 if actor == -1 else actor, data)


func _resolve(choice: Dictionary) -> Dictionary:
	var command: GameCommand = _command(choice)
	assert_eq(command.validate(_state), "")
	return command.execute(_state)


func _resolve_with_passive(choice: Dictionary) -> Dictionary:
	var command: GameCommand = _command(choice)
	assert_eq(command.validate(_state), "")
	var passive: Dictionary = _passive_mirror()
	var result: Dictionary = command.execute(_state)
	var mirror: GameCommand = COMMAND.new(
			command.player_index, command.payload.duplicate(true))
	var projected: Dictionary = mirror.project_application_result(result, 0)
	assert_false(projected.is_empty())
	assert_eq(mirror.execute_with_application_result(
			passive["state"] as GameState, projected), projected)
	return passive


func _passive_mirror() -> Dictionary:
	var passive := GameState.new()
	passive.initialize()
	passive.damage_deck = null
	passive.rng = null
	var mirror := ShipInstance.create_from_data(
			"immediate", _ship_data(), _ship.current_speed, 0)
	mirror.roster_entry_id = "ship-0"
	mirror.current_shields = _ship.current_shields.duplicate(true)
	mirror.defense_tokens = _ship.defense_tokens.duplicate(true)
	mirror.command_tokens = CommandTokenManager.deserialize(
			_ship.command_tokens.serialize())
	mirror.command_dial_stack = CommandDialStack.deserialize(
			_ship.command_dial_stack.serialize())
	var source: DamageCard = _ship.faceup_card_for_public_ref(
			str(_ship.active_immediate_resolution_snapshot()["public_card_ref"]))
	mirror.add_faceup_damage(DamageCard.deserialize_public_faceup(
			source.public_faceup_damage_card()))
	passive.get_player_state(0).ships.append(mirror)
	var hidden_draws: int = _state.damage_deck.get_total_count()
	passive.passive_damage_ledger = PassiveDamageLedger.deserialize({
		"schema_version": 1,
		"draw_count": hidden_draws,
		"discard_pile": [],
		"facedown_counts": {"0:ship-0": 0},
	}, ["0:ship-0"])
	assert_true(mirror.bind_passive_damage_ledger(
			passive.passive_damage_ledger, "0:ship-0"))
	var record: Dictionary = _ship.active_immediate_resolution_snapshot()
	record.erase("physical_card_id")
	record.erase("exact_once_key")
	assert_true(mirror.establish_filtered_immediate_resolution(record))
	return {"state": passive, "ship": mirror}


func _reset_ship() -> void:
	_ship = ShipInstance.create_from_data("immediate", _ship_data(), 2, 0)
	_state.get_player_state(0).ships[0] = _ship


func _add_hidden_dial() -> void:
	assert_true(_ship.command_dial_stack.assign_dials([
		Constants.CommandType.NAVIGATE, Constants.CommandType.SQUADRON], 1))


func _card(identity: String, effect: String, timing: String) -> DamageCard:
	var card := DamageCard.create("Ship", effect)
	card.physical_card_id = identity
	card.effect_id = effect
	card.effect_text = "test"
	card.timing = timing
	return card


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.hull = 8
	data.max_speed = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 2, "left": 1, "right": 1, "rear": 1}
	data.defense_tokens = ["BRACE", "REDIRECT"]
	return data
