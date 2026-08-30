## DBG-001 selected-card transaction coverage.
extends GutTest

var _state: GameState


func _ship_data() -> ShipData:
	var data := ShipData.new()
	data.hull = 5
	data.command_value = 2
	data.engineering_value = 3
	data.shields = {"FRONT": 3}
	return data


func _add_ship() -> ShipInstance:
	var ship := ShipInstance.create_from_data("test_ship", _ship_data(), 2, 0)
	_state.get_player_state(0).ships.append(ship)
	return ship


func before_each() -> void:
	_state = GameState.new()
	_state.initialize()
	_state.damage_deck = DamageDeck.new()
	_state.damage_deck.initialize()
	DebugDealDamageCommand.register()


func after_each() -> void:
	GameCommand._registry.erase("debug_deal_damage")


func test_validate_requires_current_draw_pile_match() -> void:
	_add_ship()
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0, "ship_index": 0, "effect_id": "not_in_deck"})
	assert_ne(cmd.validate(_state), "")


func test_validate_allows_any_phase_when_effect_is_available() -> void:
	_add_ship()
	_state.current_phase = Constants.GamePhase.COMMAND
	var draw: Array = _state.damage_deck.serialize()["draw_pile"] as Array
	var effect_id: String = str((draw.back() as Dictionary).get("effect_id", ""))
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0, "ship_index": 0, "effect_id": effect_id})
	assert_eq(cmd.validate(_state), "")


func test_validate_rejects_missing_target_and_invalid_owner() -> void:
	_add_ship()
	var missing := DebugDealDamageCommand.new(0, {
		"owner_player": 0, "ship_index": 99, "effect_id": "structural_damage"})
	var invalid_owner := DebugDealDamageCommand.new(0, {
		"owner_player": -1, "ship_index": 0, "effect_id": "structural_damage"})
	assert_ne(missing.validate(_state), "")
	assert_ne(invalid_owner.validate(_state), "")


func test_validate_rejects_missing_effect_and_game_state() -> void:
	_add_ship()
	var missing_effect := DebugDealDamageCommand.new(0, {
		"owner_player": 0, "ship_index": 0, "effect_id": ""})
	assert_ne(missing_effect.validate(_state), "")
	assert_ne(missing_effect.validate(null), "")


func test_validate_rejects_missing_damage_deck() -> void:
	_add_ship()
	_state.damage_deck = null
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0, "ship_index": 0, "effect_id": "structural_damage"})
	assert_ne(cmd.validate(_state), "")


func test_execute_removes_requested_real_card_and_reports_identity() -> void:
	var ship := _add_ship()
	var draw: Array = _state.damage_deck.serialize()["draw_pile"] as Array
	var effect_id: String = str((draw.back() as Dictionary).get("effect_id", ""))
	var before_count: int = _state.damage_deck.get_draw_count()
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0, "ship_index": 0, "effect_id": effect_id})
	assert_eq(cmd.validate(_state), "")
	var result: Dictionary = cmd.execute(_state)
	assert_eq(_state.damage_deck.get_draw_count(), before_count - 1)
	assert_eq(ship.faceup_damage.size(), 1)
	assert_eq(ship.faceup_damage[0].effect_id, effect_id)
	assert_eq(result.get("card_index"), 0)
	assert_eq(result.get("effect_id"), effect_id)
	assert_eq(result.get("owner_player"), 0)
	assert_eq(result.get("ship_index"), 0)
	assert_false(str(result.get("card_title", "")).is_empty())


func test_execute_selected_immediate_card_is_faceup_and_updates_hull() -> void:
	var ship := _add_ship()
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0, "ship_index": 0, "effect_id": "structural_damage"})
	assert_eq(cmd.validate(_state), "")
	var result: Dictionary = cmd.execute(_state)
	assert_eq(ship.faceup_damage.size(), 1)
	assert_true((ship.faceup_damage[0] as DamageCard).is_faceup)
	assert_eq(result.get("new_hull"), ship.ship_data.hull - 1)


func test_unavailable_or_missing_target_leaves_deck_and_ship_unchanged() -> void:
	var ship := _add_ship()
	var before: Dictionary = _state.damage_deck.serialize()
	var unavailable := DebugDealDamageCommand.new(0, {
		"owner_player": 0, "ship_index": 0, "effect_id": "not_in_deck"})
	assert_ne(unavailable.validate(_state), "")
	assert_eq(_state.damage_deck.serialize(), before)
	assert_eq(ship.faceup_damage.size(), 0)
	var missing := DebugDealDamageCommand.new(0, {
		"owner_player": 0, "ship_index": 99, "effect_id": "structural_damage"})
	assert_ne(missing.validate(_state), "")
	assert_eq(_state.damage_deck.serialize(), before)


func test_payload_has_no_presentation_card_identity() -> void:
	_add_ship()
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0, "ship_index": 0, "effect_id": "structural_damage"})
	assert_false((cmd.serialize()["payload"] as Dictionary).has("card_data"))


func test_execute_preserves_existing_damage_hull_calculation() -> void:
	var ship := _add_ship()
	ship.add_facedown_damage(DamageCard.create("Ship", "Existing"))
	var draw: Array = _state.damage_deck.serialize()["draw_pile"] as Array
	var effect_id: String = str((draw.back() as Dictionary).get("effect_id", ""))
	var result: Dictionary = DebugDealDamageCommand.new(0, {
		"owner_player": 0, "ship_index": 0, "effect_id": effect_id}).execute(_state)
	assert_eq(result.get("new_hull"), ship.ship_data.hull - 2)


func test_execute_fails_without_mutation_when_selection_becomes_unavailable() -> void:
	var ship := _add_ship()
	var draw: Array = _state.damage_deck.serialize()["draw_pile"] as Array
	var effect_id: String = str((draw.back() as Dictionary).get("effect_id", ""))
	var cmd := DebugDealDamageCommand.new(0, {
		"owner_player": 0, "ship_index": 0, "effect_id": effect_id})
	while _state.damage_deck.has_debug_draw_card_effect_id(effect_id):
		_state.damage_deck.take_debug_draw_card_by_effect_id(effect_id)
	var before: Dictionary = _state.damage_deck.serialize()
	assert_true(cmd.execute(_state).is_empty())
	assert_eq(_state.damage_deck.serialize(), before)
	assert_eq(ship.faceup_damage.size(), 0)


func test_roundtrip_normalizes_declared_identity_integers() -> void:
	var restored := GameCommand.deserialize({"type": "debug_deal_damage",
		"player": 0.0, "sequence": 2.0,
		"payload": {"owner_player": 0.0, "ship_index": 0.0,
			"effect_id": "structural_damage"}})
	assert_not_null(restored)
	assert_eq(typeof(restored.payload.get("owner_player")), TYPE_INT)
	assert_eq(typeof(restored.payload.get("ship_index")), TYPE_INT)
