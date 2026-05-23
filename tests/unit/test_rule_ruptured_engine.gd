## Test: Ruptured Engine Rule
##
## Verifies the Phase N13 RuleRegistry execute-maneuver observer.
extends GutTest


const CmdProcessor: GDScript = preload("res://src/autoload/command_processor.gd")
const SHIP_KEY_CR90: String = "cr90_corvette_a"

var _state: GameState = null
var _ship: ShipInstance = null
var _previous_state: GameState = null
var _saved_registry: Dictionary = {}


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	_previous_state = GameManager.current_game_state
	RuleRegistry.clear()
	RupturedEngine.register()
	_state = _make_state()
	_ship = _state.get_ship(0, 0)
	GameManager.current_game_state = _state
	ExecuteManeuverCommand.register()
	PersistentEffectDamageCommand.register()


func after_each() -> void:
	RuleRegistry.clear()
	GameManager.current_game_state = _previous_state
	GameCommand._registry = _saved_registry


func test_register_adds_execute_maneuver_observer() -> void:
	var hooks: Array[FlowHook] = RuleRegistry.observers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			RuleSurface.COMMAND_EXECUTE_MANEUVER)
	assert_eq(hooks.size(), 1,
			"Ruptured Engine should register one maneuver observer.")
	assert_eq(hooks[0].rule_id, RupturedEngine.RULE_ID,
			"Observer should carry the Ruptured Engine rule id.")


func test_observer_returns_draw_followup_above_speed_one() -> void:
	_add_faceup_damage(_ship)
	var followups: Array[GameCommand] = _observe({"speed": 2})
	assert_eq(followups.size(), 1,
			"Speed greater than 1 should create one damage follow-up.")
	assert_eq(followups[0].command_type, "persistent_effect_damage",
			"Follow-up should be a persistent-effect damage command.")
	assert_true(bool(followups[0].payload.get("draw_from_deck", false)),
			"Observer follow-up should draw the facedown card in execute().")
	assert_eq(followups[0].payload.get("effect_id"), RupturedEngine.EFFECT_ID,
			"Follow-up should identify Ruptured Engine as the source.")


func test_followup_draws_facedown_card_from_deck() -> void:
	_add_faceup_damage(_ship)
	var followup: GameCommand = _observe({"speed": 2})[0] as GameCommand
	var result: Dictionary = followup.execute(_state)
	assert_eq(_ship.facedown_damage.size(), 1,
			"Follow-up execution should draw one facedown damage card.")
	assert_eq(int(result.get("cards_added", 0)), 1,
			"Result should report the drawn facedown card.")


func test_command_processor_drains_followup_after_execute_maneuver() -> void:
	_add_faceup_damage(_ship)
	_state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			0)
	var processor: Node = CmdProcessor.new()
	add_child_autofree(processor)
	var before_count: int = _state.damage_deck.get_total_count()
	var result: Dictionary = processor.submit(_execute_maneuver_command())
	var history: Array[GameCommand] = processor.get_history()
	assert_false(result.is_empty(),
			"ExecuteManeuverCommand should succeed in maneuver flow.")
	assert_eq(history.size(), 2,
			"Ruptured Engine follow-up should be recorded after the maneuver.")
	assert_eq(history[0].command_type, "execute_maneuver",
			"Triggering command should be first in history.")
	assert_eq(history[1].command_type, "persistent_effect_damage",
			"Observer follow-up should be second in history.")
	assert_eq(_ship.facedown_damage.size(), 1,
			"Observer follow-up should deal one facedown damage card.")
	assert_eq(_state.damage_deck.get_total_count(), before_count - 1,
			"Follow-up should draw from the authoritative damage deck.")


func test_observer_ignores_speed_one() -> void:
	_add_faceup_damage(_ship)
	assert_true(_observe({"speed": 1}).is_empty(),
			"Speed 1 should not trigger Ruptured Engine.")


func test_observer_applies_after_save_load() -> void:
	_add_faceup_damage(_ship)
	var restored: GameState = GameState.deserialize(_state.serialize())
	_state = restored
	_ship = _state.get_ship(0, 0)
	assert_eq(_observe({"speed": 2}).size(), 1,
			"Serialized faceup Ruptured Engine should still observe maneuvers.")


func _observe(result_patch: Dictionary) -> Array[GameCommand]:
	var cmd: GameCommand = ExecuteManeuverCommand.new(0, {"ship_index": 0})
	var result: Dictionary = {"ship_index": 0, "speed": 2}
	result.merge(result_patch, true)
	var rule: RupturedEngine = RupturedEngine.new()
	return rule.observe_execute_maneuver(_state, cmd, result)


func _execute_maneuver_command() -> ExecuteManeuverCommand:
	return ExecuteManeuverCommand.new(0, {
		"ship_index": 0,
		"speed": 2,
		"yaw_clicks": [0, 0],
		"pos_x": 0.25,
		"pos_y": 0.35,
		"rotation_deg": 0.0,
		"did_overlap": false,
		"speed_delta": 0,
	})


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
	return ShipInstance.create_from_data(SHIP_KEY_CR90, data, 2, 0)


func _add_faceup_damage(ship: ShipInstance) -> void:
	var card: DamageCard = DamageCard.create("Ship", "Ruptured Engine")
	card.effect_id = RupturedEngine.EFFECT_ID
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)