extends GutTest


const AUTHORITY: GDScript = preload(
		"res://src/core/damage/immediate_damage_authority.gd")
const DEBUG_COMMAND: GDScript = preload(
		"res://src/core/commands/candidate_debug_deal_damage_command.gd")

var _state: GameState
var _ship: ShipInstance


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_ship = ShipInstance.create_from_data("damage-owner", _ship_data(), 1, 0)
	_state.get_player_state(0).ships.append(_ship)


func test_candidate_deck_constructs_52_stable_unique_physical_ids() -> void:
	var deck := DamageDeck.new()
	deck.initialize_for_save7()
	var serialized: Dictionary = deck.serialize_for_save7()
	assert_eq((serialized["draw_pile"] as Array).size(), 52)
	var seen: Dictionary = {}
	for raw: Dictionary in serialized["draw_pile"]:
		var identity: String = str(raw["physical_card_id"])
		assert_true(identity.begins_with("damage:"))
		assert_false(seen.has(identity))
		seen[identity] = true
	assert_eq(seen.size(), 52)
	assert_false(deck.serialize()["draw_pile"][0].has("physical_card_id"),
			"Save 6 remains identity-free before WP6.")


func test_assignment_transfers_same_object_and_establishes_debug_obligation() -> void:
	_state.damage_deck = _deck_with_card(
			_card("damage:4", "structural_damage", "immediate"))
	var addition: Dictionary = AUTHORITY.assign_drawn_faceup(
			_state, 0, 0, 22, 0,
			{"enclosing_kind": "debug", "debug_application_id": "debug:22"},
			-1)
	assert_eq(addition["public_card_ref"], "faceup:22:0")
	assert_eq(addition["immediate_resolution_id"],
			"immediate:faceup:22:0")
	assert_false(addition.has("physical_card_id"))
	assert_eq(_state.damage_deck.get_draw_count(), 0)
	assert_eq(_ship.faceup_damage.size(), 1)
	assert_eq((_ship.faceup_damage[0] as DamageCard).physical_card_id,
			"damage:4")
	assert_eq(_ship.active_immediate_resolution_snapshot()["exact_once_key"],
			"immediate:debug:debug:22:damage:4")
	assert_true(_state.validate_damage_state_for_save7())


func test_duplicate_physical_location_fails_closed() -> void:
	var one: DamageCard = _card("damage:1", "ordinary", "persistent")
	var duplicate: DamageCard = _card("damage:1", "ordinary", "persistent")
	_state.damage_deck = _deck_with_card(one)
	_ship.add_facedown_damage(duplicate)
	assert_false(_state.validate_damage_state_for_save7())


func test_resolution_flip_retires_public_correlation_and_record() -> void:
	_state.damage_deck = _deck_with_card(
			_card("damage:7", "injured_crew", "immediate"))
	AUTHORITY.assign_drawn_faceup(
			_state, 0, 0, 31, 0,
			{"enclosing_kind": "debug", "debug_application_id": "debug:31"},
			-1)
	assert_true(_ship.retire_immediate_resolution(
			"immediate:faceup:31:0", "faceup:31:0", "facedown"))
	assert_false(_ship.has_active_immediate_resolution())
	assert_eq(_ship.faceup_damage.size(), 0)
	assert_eq(_ship.facedown_damage.size(), 1)
	var hidden: DamageCard = _ship.facedown_damage[0] as DamageCard
	assert_eq(hidden.physical_card_id, "damage:7")
	assert_eq(hidden.public_card_ref, "")
	assert_false(hidden.serialize_for_save7("ship").has("public_card_ref"))


func test_immediate_persistent_retirement_keeps_public_card_without_record() -> void:
	_state.damage_deck = _deck_with_card(
			_card("damage:8", "life_support_failure",
					"immediate_persistent"))
	AUTHORITY.assign_drawn_faceup(
			_state, 0, 0, 32, 0,
			{"enclosing_kind": "debug", "debug_application_id": "debug:32"},
			-1)
	assert_true(_ship.retire_immediate_resolution(
			"immediate:faceup:32:0", "faceup:32:0", "faceup"))
	assert_false(_ship.has_active_immediate_resolution())
	assert_eq(_ship.faceup_damage.size(), 1)
	assert_eq((_ship.faceup_damage[0] as DamageCard).public_card_ref,
			"faceup:32:0")


func test_unrelated_removal_rejects_while_obligation_is_unresolved() -> void:
	_state.damage_deck = _deck_with_card(
			_card("damage:9", "shield_failure", "immediate"))
	AUTHORITY.assign_drawn_faceup(
			_state, 0, 0, 33, 0,
			{"enclosing_kind": "debug", "debug_application_id": "debug:33"},
			1)
	var card: DamageCard = _ship.faceup_damage[0] as DamageCard
	assert_false(_ship.remove_damage_card(card))
	assert_eq(_ship.faceup_damage.size(), 1)
	assert_true(_ship.has_active_immediate_resolution())


func test_destruction_clears_obligation_and_card_cleanup_is_idempotent() -> void:
	_state.damage_deck = _deck_with_card(
			_card("damage:10", "comm_noise", "immediate"))
	AUTHORITY.assign_drawn_faceup(
			_state, 0, 0, 34, 0,
			{"enclosing_kind": "debug", "debug_application_id": "debug:34"},
			-1)
	_ship.mark_destroyed()
	assert_false(_ship.has_active_immediate_resolution())
	assert_eq(_ship.clear_all_damage_cards().size(), 1)
	assert_eq(_ship.clear_all_damage_cards(), [])


func test_strict_ship_round_trip_restores_exact_obligation_reference() -> void:
	_state.damage_deck = _deck_with_card(
			_card("damage:11", "projector_misaligned", "immediate"))
	AUTHORITY.assign_drawn_faceup(
			_state, 0, 0, 35, 0,
			{"enclosing_kind": "debug", "debug_application_id": "debug:35"},
			-1)
	var serialized: Dictionary = _ship.serialize_damage_state_for_save7()
	var restored := ShipInstance.create_from_data(
			"restored", _ship_data(), 1, 0)
	assert_true(restored.install_damage_state_for_save7(serialized))
	assert_eq(restored.active_immediate_resolution_snapshot(),
			_ship.active_immediate_resolution_snapshot())
	assert_eq((restored.faceup_damage[0] as DamageCard).physical_card_id,
			"damage:11")
	var invalid: Dictionary = serialized.duplicate(true)
	invalid["active_immediate_resolution"]["unexpected"] = true
	assert_false(restored.install_damage_state_for_save7(invalid))


func test_maneuver_enclosure_requires_matching_open_execution() -> void:
	assert_true(_ship.establish_ship_activation("ship-activation:90"))
	assert_true(_ship.open_maneuver_opportunity("ship-activation:90"))
	assert_true(_ship.commit_maneuver_execution(
			"ship-activation:90", "maneuver:90", false, {
				"yaw_clicks": [0],
				"yaw_bonus_joint": -1,
				"pos_x": 0.5,
				"pos_y": 0.5,
				"rotation_deg": 0.0,
			}, {"kind": "none"}))
	_state.damage_deck = _deck_with_card(
			_card("damage:12", "structural_damage", "immediate"))
	var addition: Dictionary = AUTHORITY.assign_drawn_faceup(
			_state, 0, 0, 90, 0, {
				"enclosing_kind": "maneuver",
				"ship_activation_identity": "ship-activation:90",
				"maneuver_execution_id": "maneuver:90",
				"maneuver_source_kind": "asteroid",
				"maneuver_source_id": "obstacle:2",
			}, -1)
	assert_false(addition.is_empty())
	assert_eq(_ship.active_immediate_resolution_snapshot()["exact_once_key"],
			"immediate:maneuver:ship-activation:90:maneuver:90:damage:12")


func test_candidate_debug_source_derives_identity_and_public_addition() -> void:
	_state.damage_deck = _deck_with_card(
			_card("damage:13", "structural_damage", "immediate"))
	var command: GameCommand = DEBUG_COMMAND.new(0, {
		"owner_player": 0, "ship_index": 0,
		"effect_id": "structural_damage",
	})
	command.sequence = 44
	assert_eq(command.validate(_state), "")
	var result: Dictionary = command.execute(_state)
	assert_eq(result["debug_application_id"], "debug:44")
	var additions: Array = result["damage_application"]["faceup_additions"]
	assert_eq(additions.size(), 1)
	assert_eq(additions[0]["public_card_ref"], "faceup:44:0")
	assert_false(additions[0].has("physical_card_id"))
	assert_eq(_ship.active_immediate_resolution_snapshot()["exact_once_key"],
			"immediate:debug:debug:44:damage:13")


func test_lethal_debug_assignment_terminates_new_obligation_without_rollback() -> void:
	var lethal_data: ShipData = _ship_data()
	lethal_data.hull = 1
	_ship = ShipInstance.create_from_data("damage-owner", lethal_data, 1, 0)
	_state.get_player_state(0).ships[0] = _ship
	_state.damage_deck = _deck_with_card(
			_card("damage:lethal", "shield_failure", "immediate"))
	var command: GameCommand = DEBUG_COMMAND.new(0, {
		"owner_player": 0, "ship_index": 0,
		"effect_id": "shield_failure",
	})
	command.sequence = 45
	var result: Dictionary = command.execute(_state)
	assert_false(result.is_empty())
	assert_true(bool(result["damage_application"]["destroyed"]))
	assert_true(_ship.has_finalized_destruction())
	assert_false(_ship.has_active_immediate_resolution())
	assert_eq(_ship.faceup_damage.size(), 1)


func test_candidate_debug_passive_application_installs_filtered_obligation() -> void:
	_state.damage_deck = _deck_with_card(
			_card("damage:15", "structural_damage", "immediate"))
	var authority: GameCommand = DEBUG_COMMAND.new(0, {
		"owner_player": 0, "ship_index": 0,
		"effect_id": "structural_damage",
	})
	authority.sequence = 55
	var authority_result: Dictionary = authority.execute(_state)
	assert_false(authority_result.is_empty())
	var passive := GameState.new()
	passive.initialize()
	assert_true(passive.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()))
	passive.damage_deck = null
	passive.rng = null
	var passive_ship := ShipInstance.create_from_data(
			"damage-owner", _ship_data(), 1, 0)
	passive_ship.roster_entry_id = "passive-debug"
	passive.get_player_state(0).ships.append(passive_ship)
	passive.passive_damage_ledger = PassiveDamageLedger.deserialize({
		"schema_version": 1,
		"draw_count": 1,
		"discard_pile": [],
		"facedown_counts": {"0:passive-debug": 0},
	}, ["0:passive-debug"])
	assert_true(passive_ship.bind_passive_damage_ledger(
			passive.passive_damage_ledger, "0:passive-debug"))
	var mirror: GameCommand = DEBUG_COMMAND.new(0,
			authority.payload.duplicate(true))
	mirror.sequence = 55
	var projected: Dictionary = mirror.project_application_result(
			authority_result, 1)
	assert_eq(mirror.execute_with_application_result(passive, projected),
			projected)
	assert_eq(passive_ship.faceup_damage.size(), 1)
	assert_eq((passive_ship.faceup_damage[0] as DamageCard).physical_card_id, "")
	assert_eq(passive_ship.active_immediate_resolution_snapshot(), {
		"immediate_resolution_id": "immediate:faceup:55:0",
		"public_card_ref": "faceup:55:0",
		"effect_id": "structural_damage",
		"actor_player": -1,
		"enclosing_kind": "debug",
		"debug_application_id": "debug:55",
	})
	assert_eq(passive.passive_damage_ledger.draw_count, 0)
	assert_true(passive_ship.validate_filtered_damage_state_for_protocol7())
	var filtered: Dictionary = passive_ship \
			.serialize_filtered_damage_state_for_protocol7()
	assert_eq(filtered["faceup_damage"][0].keys(), [
		"trait_type", "title", "is_faceup", "effect_text", "timing",
		"effect_id", "public_card_ref",
	])
	assert_false(filtered["active_immediate_resolution"].has(
			"physical_card_id"))
	assert_false(filtered["active_immediate_resolution"].has(
			"exact_once_key"))


func test_redeal_preserves_physical_identity_but_creates_fresh_public_obligation() -> void:
	_state.damage_deck = _deck_with_card(
			_card("damage:16", "structural_damage", "immediate"))
	var first: Dictionary = AUTHORITY.assign_drawn_faceup(
			_state, 0, 0, 60, 0,
			{"enclosing_kind": "debug", "debug_application_id": "debug:60"},
			-1)
	assert_eq(first["public_card_ref"], "faceup:60:0")
	assert_true(_ship.retire_immediate_resolution(
			"immediate:faceup:60:0", "faceup:60:0", "facedown"))
	var physical: DamageCard = _ship.facedown_damage[0] as DamageCard
	assert_true(_ship.remove_damage_card(physical))
	_state.damage_deck.discard(physical)
	var second: Dictionary = AUTHORITY.assign_drawn_faceup(
			_state, 0, 0, 61, 0,
			{"enclosing_kind": "debug", "debug_application_id": "debug:61"},
			-1)
	assert_eq(second["public_card_ref"], "faceup:61:0")
	assert_eq((_ship.faceup_damage[0] as DamageCard).physical_card_id,
			"damage:16")
	assert_ne(second["immediate_resolution_id"],
			first["immediate_resolution_id"])


func _card(identity: String, effect: String, timing: String) -> DamageCard:
	var card := DamageCard.create("Ship", effect)
	card.effect_id = effect
	card.effect_text = "test"
	card.timing = timing
	card.physical_card_id = identity
	return card


func _deck_with_card(card: DamageCard) -> DamageDeck:
	return DamageDeck.deserialize_for_save7({
		"draw_pile": [card.serialize_for_save7("draw")],
		"discard_pile": [],
	})


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.hull = 5
	data.max_speed = 3
	data.command_value = 2
	data.navigation_chart = [[1], [1, 1], [1, 1, 1]]
	data.shields = {"front": 2, "left": 1, "right": 1, "rear": 1}
	return data
