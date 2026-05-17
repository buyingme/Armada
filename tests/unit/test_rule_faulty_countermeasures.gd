## Test: Faulty Countermeasures Rule
##
## Verifies the Phase M7 command-time validator for the Faulty
## Countermeasures damage card.
extends GutTest


const CmdProcessor: GDScript = preload("res://src/autoload/command_processor.gd")
const SHIP_KEY_CR90: String = "cr90_corvette_a"
const DEFENDER_PLAYER: int = 1
const DEFENDER_SHIP_INDEX: int = 0


var _processor: Node = null
var _state: GameState = null
var _saved_registry: Dictionary = {}
var _previous_state: GameState = null
var _rejected_reasons: Array[String] = []


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	_previous_state = GameManager.current_game_state
	RuleRegistry.clear()
	FaultyCountermeasures.register()
	CommitDefenseCommand.register()
	SpendDefenseTokenCommand.register()
	_state = _make_state()
	GameManager.current_game_state = _state
	_rejected_reasons.clear()
	_processor = CmdProcessor.new()
	add_child_autofree(_processor)
	_processor.command_rejected.connect(_on_command_rejected)


func after_each() -> void:
	RuleRegistry.clear()
	GameCommand._registry = _saved_registry
	GameManager.current_game_state = _previous_state
	_rejected_reasons.clear()


func test_validator_rejects_exhausted_token_after_registration() -> void:
	var ship: ShipInstance = _state.get_ship(
			DEFENDER_PLAYER, DEFENDER_SHIP_INDEX)
	_add_faulty_countermeasures(ship)
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	var result: Dictionary = _processor.submit(_make_spend_command(0, "discard"))
	assert_true(result.is_empty(),
			"Faulty Countermeasures should reject exhausted tokens.")
	assert_eq(_processor.get_command_count(), 0,
			"Rejected commands should not enter command history.")
	assert_eq(ship.defense_tokens[0]["state"],
			Constants.DefenseTokenState.EXHAUSTED,
			"Rejected spend should leave the token exhausted.")
	assert_true(_rejected_reasons[0].contains("Faulty Countermeasures"),
			"Rejection reason should identify the damage card.")
	assert_engine_error(1,
			"CommandProcessor should warn for the rule-validator rejection.")


func test_validator_allows_ready_token_with_damage_card() -> void:
	var ship: ShipInstance = _state.get_ship(
			DEFENDER_PLAYER, DEFENDER_SHIP_INDEX)
	_add_faulty_countermeasures(ship)
	var result: Dictionary = _processor.submit(_make_spend_command(0, "exhaust"))
	assert_false(result.is_empty(),
			"Ready tokens should still be spendable.")
	assert_eq(ship.defense_tokens[0]["state"],
			Constants.DefenseTokenState.EXHAUSTED,
			"Allowed exhaust should flip the token.")


func test_validator_rejects_commit_with_exhausted_token() -> void:
	_state.current_phase = Constants.GamePhase.SQUADRON
	var ship: ShipInstance = _state.get_ship(
			DEFENDER_PLAYER, DEFENDER_SHIP_INDEX)
	_add_faulty_countermeasures(ship)
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	var result: Dictionary = _processor.submit(_make_commit_command([0]))
	assert_true(result.is_empty(),
			"CommitDefenseCommand should reject blocked exhausted tokens.")
	assert_eq(_processor.get_command_count(), 0,
			"Rejected commit should not enter command history.")
	assert_true(_rejected_reasons[0].contains("Faulty Countermeasures"),
			"Commit rejection reason should identify the damage card.")
	assert_engine_error(1,
			"CommandProcessor should warn for the commit validator rejection.")


func test_validator_allows_exhausted_token_without_damage_card() -> void:
	var ship: ShipInstance = _state.get_ship(
			DEFENDER_PLAYER, DEFENDER_SHIP_INDEX)
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	var result: Dictionary = _processor.submit(_make_spend_command(0, "discard"))
	assert_false(result.is_empty(),
			"Absent the damage card, exhausted tokens follow normal discard rules.")
	assert_eq(ship.defense_tokens[0]["state"],
			Constants.DefenseTokenState.DISCARDED,
			"Allowed discard should discard the exhausted token.")


func test_validator_ignores_faulty_countermeasures_on_other_ship() -> void:
	var other_ship: ShipInstance = _make_ship(DEFENDER_PLAYER)
	_state.get_player_state(DEFENDER_PLAYER).ships.append(other_ship)
	_add_faulty_countermeasures(other_ship)
	var defender: ShipInstance = _state.get_ship(
			DEFENDER_PLAYER, DEFENDER_SHIP_INDEX)
	defender.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	var result: Dictionary = _processor.submit(_make_spend_command(0, "discard"))
	assert_false(result.is_empty(),
			"A different ship's damage card should not block the defender.")
	assert_eq(defender.defense_tokens[0]["state"],
			Constants.DefenseTokenState.DISCARDED,
			"Allowed discard should affect only the commanded ship.")


func test_validator_rejects_after_save_load_effect_rebuild() -> void:
	var ship: ShipInstance = _state.get_ship(
			DEFENDER_PLAYER, DEFENDER_SHIP_INDEX)
	_add_faulty_countermeasures(ship)
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	var restored: GameState = GameState.deserialize(_state.serialize())
	EffectFactory.rebuild_runtime_effects(restored, restored.initiative_player)
	GameManager.current_game_state = restored
	var restored_ship: ShipInstance = restored.get_ship(
			DEFENDER_PLAYER, DEFENDER_SHIP_INDEX)
	var result: Dictionary = _processor.submit(_make_spend_command(0, "discard"))
	assert_gt(restored.effect_registry.get_effect_count(), 0,
			"Save/load rebuild should restore legacy runtime hooks too.")
	assert_true(result.is_empty(),
			"Command-time rule should still reject after save/load rebuild.")
	assert_eq(restored_ship.defense_tokens[0]["state"],
			Constants.DefenseTokenState.EXHAUSTED,
			"Rejected spend should leave the restored token exhausted.")
	assert_engine_error(1,
			"CommandProcessor should warn for the rule-validator rejection.")


func _on_command_rejected(_command: GameCommand, reason: String) -> void:
	_rejected_reasons.append(reason)


func _make_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			DEFENDER_PLAYER)
	state.get_player_state(DEFENDER_PLAYER).ships.append(
			_make_ship(DEFENDER_PLAYER))
	return state


func _make_ship(owner_player: int) -> ShipInstance:
	var template: ShipData = AssetLoader.load_ship_data(SHIP_KEY_CR90)
	assert_not_null(template,
			"Test fixture requires ship data for %s." % SHIP_KEY_CR90)
	return ShipInstance.create_from_data(
			SHIP_KEY_CR90, template, 2, owner_player)


func _add_faulty_countermeasures(ship: ShipInstance) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", "Faulty Countermeasures")
	card.effect_id = FaultyCountermeasures.EFFECT_ID
	card.effect_text = "You cannot spend exhausted defense tokens."
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card


func _make_spend_command(token_index: int,
		spend_method: String) -> SpendDefenseTokenCommand:
	return SpendDefenseTokenCommand.new(DEFENDER_PLAYER, {
		"ship_index": DEFENDER_SHIP_INDEX,
		"token_index": token_index,
		"spend_method": spend_method,
	})


func _make_commit_command(selected_indices: Array[int]) -> CommitDefenseCommand:
	var payload_indices: Array = []
	for idx: int in selected_indices:
		payload_indices.append(idx)
	return CommitDefenseCommand.new(DEFENDER_PLAYER, {
		"ship_index": DEFENDER_SHIP_INDEX,
		"selected_indices": payload_indices,
	})