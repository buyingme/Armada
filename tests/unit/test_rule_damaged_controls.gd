## Test: Damaged Controls Rule
##
## Verifies the Phase N14 RuleRegistry execute-maneuver overlap observer.
extends GutTest


const SHIP_KEY_CR90: String = "cr90_corvette_a"

var _state: GameState = null
var _ship: ShipInstance = null


func before_each() -> void:
	RuleRegistry.clear()
	DamagedControls.register()
	_state = _make_state()
	_ship = _state.get_ship(0, 0)


func after_each() -> void:
	RuleRegistry.clear()


func test_register_adds_execute_maneuver_observer() -> void:
	var hooks: Array[FlowHook] = RuleRegistry.observers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			RuleSurface.COMMAND_EXECUTE_MANEUVER)
	assert_eq(hooks.size(), 1,
			"Damaged Controls should register one maneuver observer.")
	assert_eq(hooks[0].rule_id, DamagedControls.RULE_ID,
			"Observer should carry the Damaged Controls rule id.")


func test_observer_returns_followup_on_overlap() -> void:
	_add_faceup_damage(_ship)
	var followups: Array[GameCommand] = _observe(true)
	assert_eq(followups.size(), 1,
			"Overlapping maneuvers should create one damage follow-up.")
	assert_eq(followups[0].payload.get("effect_id"), DamagedControls.EFFECT_ID,
			"Follow-up should identify Damaged Controls as the source.")
	assert_true(bool(followups[0].payload.get("draw_from_deck", false)),
			"Observer follow-up should draw the facedown card in execute().")


func test_observer_ignores_non_overlap() -> void:
	_add_faceup_damage(_ship)
	assert_true(_observe(false).is_empty(),
			"Non-overlapping maneuvers should not trigger Damaged Controls.")


func test_observer_ignores_ship_without_card() -> void:
	assert_true(_observe(true).is_empty(),
			"Ships without Damaged Controls should not create follow-ups.")


func test_observer_applies_after_save_load() -> void:
	_add_faceup_damage(_ship)
	var restored: GameState = GameState.deserialize(_state.serialize())
	_state = restored
	_ship = _state.get_ship(0, 0)
	assert_eq(_observe(true).size(), 1,
			"Serialized faceup Damaged Controls should still observe maneuvers.")


func _observe(did_overlap: bool) -> Array[GameCommand]:
	var cmd: GameCommand = ExecuteManeuverCommand.new(0, {"ship_index": 0})
	var result: Dictionary = {"ship_index": 0, "speed": 1,
		"did_overlap": did_overlap}
	var rule: DamagedControls = DamagedControls.new()
	return rule.observe_execute_maneuver(_state, cmd, result)


func _make_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.damage_deck = DamageDeck.new()
	state.damage_deck.initialize()
	state.get_player_state(0).ships.append(_make_ship())
	return state


func _make_ship() -> ShipInstance:
	var data: ShipData = AssetLoader.load_ship_data(SHIP_KEY_CR90)
	assert_not_null(data,
			"Test fixture requires ship data for %s." % SHIP_KEY_CR90)
	return ShipInstance.create_from_data(SHIP_KEY_CR90, data, 1, 0)


func _add_faceup_damage(ship: ShipInstance) -> void:
	var card: DamageCard = DamageCard.create("Ship", "Damaged Controls")
	card.effect_id = DamagedControls.EFFECT_ID
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)