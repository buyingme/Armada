## The historical debug command name must remain a behavior-identical alias of
## the single BUG-043 authoritative damage transaction.
extends GutTest


var _state: GameState
var _ship: ShipInstance


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.current_phase = Constants.GamePhase.SHIP
	var data := ShipData.new()
	data.hull = 5
	data.command_value = 2
	data.engineering_value = 3
	data.shields = {"FRONT": 3}
	_ship = ShipInstance.create_from_data("test_ship", data, 2, 0)
	_ship.roster_entry_id = "debug-command-ship"
	_state.get_player_state(0).ships.append(_ship)
	_state.damage_deck = DamageDeck.new()
	_state.damage_deck.initialize()
	DebugDealDamageCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("debug_deal_damage")


func test_historical_name_uses_authoritative_application_contract() -> void:
	var command := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"effect_id": "structural_damage",
	})
	command.sequence = 20
	assert_true(command is CandidateDebugDealDamageCommand)
	assert_eq(command.validate(_state), "")
	var result: Dictionary = command.execute(_state)
	assert_eq(result.keys(), [
		"debug_application_id", "owner_player", "ship_index",
		"damage_application",
	])
	assert_false(result.has("card_index"))
	assert_true(_ship.has_active_immediate_resolution())
	assert_true(_state.validate_damage_state_for_save7())


func test_non_immediate_assignment_has_public_identity_without_obligation() \
		-> void:
	var command := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"effect_id": "capacitor_failure",
	})
	command.sequence = 21
	var result: Dictionary = command.execute(_state)
	var additions: Array = result["damage_application"]["faceup_additions"]
	assert_eq(additions.size(), 1)
	assert_eq(additions[0]["immediate_obligation"], "none")
	assert_false(str(additions[0]["public_card_ref"]).is_empty())
	assert_false(_ship.has_active_immediate_resolution())
	assert_true(_state.validate_damage_state_for_save7())


func test_factory_roundtrip_restores_the_same_authoritative_command() -> void:
	var restored := GameCommand.deserialize({
		"type": "debug_deal_damage",
		"player": 0.0,
		"sequence": 22.0,
		"payload": {
			"owner_player": 0.0,
			"ship_index": 0.0,
			"effect_id": "shield_failure",
		},
	})
	assert_not_null(restored)
	assert_true(restored is CandidateDebugDealDamageCommand)
	assert_eq(restored.application_contract_id(), "debug_deal_damage")
	assert_eq(restored.application_contract_version(), 2)


func test_unavailable_card_and_conflicting_obligation_fail_without_mutation() \
		-> void:
	var unavailable := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"effect_id": "not_in_deck",
	})
	var deck_before: Dictionary = _state.damage_deck.serialize_for_save7()
	assert_ne(unavailable.validate(_state), "")
	assert_true(unavailable.execute(_state).is_empty())
	assert_eq(_state.damage_deck.serialize_for_save7(), deck_before)

	var first := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"effect_id": "structural_damage",
	})
	first.sequence = 23
	assert_false(first.execute(_state).is_empty())
	var second := DebugDealDamageCommand.new(0, {
		"owner_player": 0,
		"ship_index": 0,
		"effect_id": "shield_failure",
	})
	assert_ne(second.validate(_state), "")
