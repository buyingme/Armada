extends GutTest


const FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")
const COMMAND: GDScript = preload(
		"res://src/core/commands/candidate_resolve_damage_command.gd")

var _state: GameState


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	assert_not_null(FIXTURE.install(_state, {
		"attack_id": "attack:70",
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
	var defender: ShipInstance = _state.get_ship(1, 0)
	defender.current_shields["FRONT"] = 0
	_state.damage_deck = _deck("structural_damage", "immediate")


func test_attack_faceup_assignment_establishes_exact_public_obligation() -> void:
	var command: GameCommand = COMMAND.new(0, {"attack_id": "attack:70"})
	command.sequence = 70
	assert_eq(command.validate(_state), "")
	var result: Dictionary = command.execute(_state)
	assert_eq(result.keys(), [
		"attack_id", "target_kind", "owner_player", "ship_index",
		"damage_application",
	])
	var additions: Array = result["damage_application"]["faceup_additions"]
	assert_eq(additions.size(), 1)
	assert_eq(additions[0]["public_card_ref"], "faceup:70:0")
	assert_eq(additions[0]["immediate_obligation"], "open")
	var defender: ShipInstance = _state.get_ship(1, 0)
	var record: Dictionary = defender.active_immediate_resolution_snapshot()
	assert_eq(record["enclosing_kind"], "attack")
	assert_eq(record["attack_id"], "attack:70")
	assert_eq(record["public_card_ref"], "faceup:70:0")
	assert_false(result.has("physical_card_id"))


func test_attack_assignment_rolls_back_when_obligation_already_exists() -> void:
	var defender: ShipInstance = _state.get_ship(1, 0)
	var source := DamageCard.new()
	source.physical_card_id = "damage:prior"
	source.public_card_ref = "faceup:prior:0"
	source.effect_id = "structural_damage"
	source.timing = "immediate"
	source.is_faceup = true
	defender.add_faceup_damage(source)
	assert_true(defender.establish_immediate_resolution({
		"immediate_resolution_id": "immediate:faceup:prior:0",
		"public_card_ref": "faceup:prior:0",
		"physical_card_id": "damage:prior",
		"effect_id": "structural_damage",
		"actor_player": -1,
		"exact_once_key": "immediate:attack:attack:70:damage:prior",
		"enclosing_kind": "attack",
		"attack_id": "attack:70",
	}))
	var command: GameCommand = COMMAND.new(0, {"attack_id": "attack:70"})
	command.sequence = 71
	var before: Dictionary = defender.serialize_damage_state_for_save7()
	assert_eq(command.execute(_state), {})
	assert_eq(defender.serialize_damage_state_for_save7(), before)


func test_attack_passive_application_installs_exact_filtered_attack_record() -> void:
	var authority: GameCommand = COMMAND.new(0, {"attack_id": "attack:70"})
	authority.sequence = 70
	var authority_result: Dictionary = authority.execute(_state)
	assert_false(authority_result.is_empty())
	var passive := GameState.new()
	passive.initialize()
	passive.current_phase = Constants.GamePhase.SHIP
	assert_not_null(FIXTURE.install(passive, {
		"attack_id": "attack:70",
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
	var passive_defender: ShipInstance = passive.get_ship(1, 0)
	passive_defender.current_shields["FRONT"] = 0
	passive.damage_deck = null
	passive.rng = null
	var counts: Dictionary = {}
	var keys: Array[String] = []
	for owner: int in range(passive.player_states.size()):
		for raw_ship: Variant in passive.get_player_state(owner).ships:
			var ship: ShipInstance = raw_ship as ShipInstance
			var key: String = PassiveDamageLedger.ship_key(
					owner, ship.roster_entry_id)
			keys.append(key)
			counts[key] = 0
	passive.passive_damage_ledger = PassiveDamageLedger.deserialize({
		"schema_version": 1,
		"draw_count": 1,
		"discard_pile": [],
		"facedown_counts": counts,
	}, keys)
	for owner: int in range(passive.player_states.size()):
		for raw_ship: Variant in passive.get_player_state(owner).ships:
			var ship: ShipInstance = raw_ship as ShipInstance
			assert_true(ship.bind_passive_damage_ledger(
					passive.passive_damage_ledger,
					PassiveDamageLedger.ship_key(owner, ship.roster_entry_id)))
	var mirror: GameCommand = COMMAND.new(0, {"attack_id": "attack:70"})
	mirror.sequence = 70
	var projected: Dictionary = mirror.project_application_result(
			authority_result, 1)
	assert_eq(mirror.execute_with_application_result(passive, projected),
			projected)
	assert_eq(passive_defender.faceup_damage.size(), 1)
	assert_eq(passive_defender.active_immediate_resolution_snapshot(), {
		"immediate_resolution_id": "immediate:faceup:70:0",
		"public_card_ref": "faceup:70:0",
		"effect_id": "structural_damage",
		"actor_player": -1,
		"enclosing_kind": "attack",
		"attack_id": "attack:70",
	})
	assert_eq(passive.passive_damage_ledger.draw_count, 0)


func test_lethal_attack_faceup_assignment_terminates_obligation_and_keeps_damage() -> void:
	var defender: ShipInstance = _state.get_ship(1, 0)
	for index: int in range(defender.ship_data.hull - 1):
		var prior := DamageCard.new()
		prior.physical_card_id = "damage:prior:%d" % index
		prior.effect_id = "ordinary"
		prior.timing = "persistent"
		defender.add_facedown_damage(prior)
	var command: GameCommand = COMMAND.new(0, {"attack_id": "attack:70"})
	command.sequence = 72
	var result: Dictionary = command.execute(_state)
	assert_false(result.is_empty())
	assert_true(bool(result["damage_application"]["destroyed"]))
	assert_true(defender.has_finalized_destruction())
	assert_false(defender.has_active_immediate_resolution())
	assert_eq(defender.get_total_damage(), defender.ship_data.hull)


func _deck(effect: String, timing: String) -> DamageDeck:
	var card := DamageCard.new()
	card.physical_card_id = "damage:0"
	card.trait_type = "Ship"
	card.title = effect
	card.effect_id = effect
	card.timing = timing
	return DamageDeck.deserialize_for_save7({
		"draw_pile": [card.serialize_for_save7("draw")],
		"discard_pile": [],
	})
