## Test: Thrust Control Malfunction Rule
##
## Verifies the Phase N12 RuleRegistry maneuver-yaw modifier.
extends GutTest


const SHIP_KEY_CR90: String = "cr90_corvette_a"

var _state: GameState = null
var _ship: ShipInstance = null


func before_each() -> void:
	RuleRegistry.clear()
	ThrustControlMalfunction.register()
	_state = _make_state()
	_ship = _state.get_ship(0, 0)


func after_each() -> void:
	RuleRegistry.clear()


func test_register_adds_maneuver_yaw_modifier() -> void:
	var hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			RuleSurface.TARGET_MANEUVER_YAW)
	assert_eq(hooks.size(), 1,
			"Thrust Control should register one maneuver-yaw modifier.")
	assert_eq(hooks[0].rule_id, ThrustControlMalfunction.RULE_ID,
			"Modifier should carry the Thrust Control rule id.")


func test_apply_yaw_modifier_reduces_current_speed_last_joint() -> void:
	_add_faceup_damage(_ship)
	var result: Array = ManeuverRuleResolver.apply_yaw_modifiers(
			[[2], [1, 2], [0, 1, 2]], _ship, _state)
	assert_eq(result, [[2], [1, 1], [0, 1, 2]],
			"Only the last adjustable joint at current speed should lose one yaw.")


func test_apply_yaw_modifier_ignores_ship_without_card() -> void:
	var result: Array = ManeuverRuleResolver.apply_yaw_modifiers(
			[[2], [1, 2], [0, 1, 2]], _ship, _state)
	assert_eq(result, [[2], [1, 2], [0, 1, 2]],
			"Ships without Thrust Control should keep their nav chart.")


func test_apply_yaw_modifier_applies_after_save_load() -> void:
	_add_faceup_damage(_ship)
	var restored: GameState = GameState.deserialize(_state.serialize())
	var restored_ship: ShipInstance = restored.get_ship(0, 0)
	var result: Array = ManeuverRuleResolver.apply_yaw_modifiers(
			[[2], [1, 2], [0, 1, 2]], restored_ship, restored)
	assert_eq(result, [[2], [1, 1], [0, 1, 2]],
			"Serialized faceup damage should drive the yaw modifier after load.")


func _make_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.get_player_state(0).ships.append(_make_ship())
	return state


func _make_ship() -> ShipInstance:
	var data: ShipData = AssetLoader.load_ship_data(SHIP_KEY_CR90)
	assert_not_null(data,
			"Test fixture requires ship data for %s." % SHIP_KEY_CR90)
	return ShipInstance.create_from_data(SHIP_KEY_CR90, data, 2, 0)


func _add_faceup_damage(ship: ShipInstance) -> void:
	var card: DamageCard = DamageCard.create(
			"Ship", "Thrust Control Malfunction")
	card.effect_id = ThrustControlMalfunction.EFFECT_ID
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)