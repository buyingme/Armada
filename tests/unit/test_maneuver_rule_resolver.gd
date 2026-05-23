## Test: ManeuverRuleResolver
##
## Verifies the Phase N maneuver adapter for RuleRegistry movement rules and
## preview warnings derived from serialized faceup damage.
extends GutTest


var _state: GameState = null
var _ship: ShipInstance = null
var _deck: DamageDeck = null


func before_each() -> void:
	RuleRegistry.clear()
	_state = GameState.new()
	_state.initialize()
	_ship = _make_ship()
	_state.get_player_state(0).ships.append(_ship)
	_deck = DamageDeck.new()
	_deck.initialize()


func after_each() -> void:
	RuleRegistry.clear()


func test_apply_yaw_modifiers_preserves_chart_without_ship() -> void:
	var nav_chart: Array = [[2], [1, 2]]
	var result: Array = ManeuverRuleResolver.apply_yaw_modifiers(
			nav_chart, null, _state)
	assert_eq(result, nav_chart,
			"Missing ship should preserve the nav chart.")


func test_apply_yaw_modifiers_uses_rule_thrust_control_current_speed() -> void:
	_add_faceup_damage("thrust_control_malfunction")
	ThrustControlMalfunction.register()
	var result: Array = ManeuverRuleResolver.apply_yaw_modifiers(
			[[2], [1, 2], [0, 1, 2]], _ship, _state)
	assert_eq(result, [[2], [1, 1], [0, 1, 2]],
			"Thrust Control should reduce only the current-speed last joint.")


func test_after_maneuver_returns_ruptured_engine_effect_id() -> void:
	_add_faceup_damage("ruptured_engine")
	var effect_id: String = ManeuverRuleResolver.resolve_after_maneuver_effect_id(
			_state, _ship, _deck, {"speed": 2}, false)
	assert_eq(effect_id, "ruptured_engine",
			"Ruptured Engine should trigger after speed greater than 1 maneuvers.")


func test_after_maneuver_returns_damaged_controls_on_overlap() -> void:
	_add_faceup_damage("damaged_controls")
	var effect_id: String = ManeuverRuleResolver.resolve_after_maneuver_effect_id(
			_state, _ship, _deck, {"speed": 1}, true)
	assert_eq(effect_id, "damaged_controls",
			"Damaged Controls should trigger when the maneuver overlaps.")


func test_speed_change_returns_thruster_fissure_effect_id() -> void:
	_add_faceup_damage("thruster_fissure")
	var effect_id: String = ManeuverRuleResolver.resolve_speed_change_effect_id(
			_state, _ship, _deck)
	assert_eq(effect_id, "thruster_fissure",
			"Thruster Fissure should preview from faceup damage state.")


func test_preview_maneuver_damage_lists_ruptured_engine() -> void:
	_add_faceup_damage("ruptured_engine")
	var effect_ids: Array[String] = \
			ManeuverRuleResolver.preview_maneuver_damage_effect_ids(
					_state, _ship, _deck, 2, false, false)
	assert_eq(effect_ids, ["ruptured_engine"],
			"Preview should expose Ruptured Engine before maneuver commit.")


func test_preview_maneuver_damage_lists_damaged_controls() -> void:
	_add_faceup_damage("damaged_controls")
	var effect_ids: Array[String] = \
			ManeuverRuleResolver.preview_maneuver_damage_effect_ids(
					_state, _ship, _deck, 1, true, false)
	assert_eq(effect_ids, ["damaged_controls"],
			"Preview should expose Damaged Controls when overlap is predicted.")


func test_preview_maneuver_damage_lists_thruster_fissure() -> void:
	_add_faceup_damage("thruster_fissure")
	var effect_ids: Array[String] = \
			ManeuverRuleResolver.preview_maneuver_damage_effect_ids(
					_state, _ship, _deck, 1, false, true)
	assert_eq(effect_ids, ["thruster_fissure"],
			"Preview should expose Thruster Fissure after speed changes.")


func test_preview_maneuver_damage_ignores_unchanged_thruster_fissure() -> void:
	_add_faceup_damage("thruster_fissure")
	var effect_ids: Array[String] = \
			ManeuverRuleResolver.preview_maneuver_damage_effect_ids(
					_state, _ship, _deck, 1, false, false)
	assert_true(effect_ids.is_empty(),
			"Preview should ignore Thruster Fissure before speed changes.")


func test_after_maneuver_without_faceup_damage_returns_empty() -> void:
	_state.effect_registry = null
	var effect_id: String = ManeuverRuleResolver.resolve_after_maneuver_effect_id(
			_state, _ship, _deck, {"speed": 2}, true)
	assert_eq(effect_id, "",
			"Missing faceup movement damage should produce no warning effect id.")


func _add_faceup_damage(effect_id: String) -> void:
	var card: DamageCard = DamageCard.create("Ship", effect_id)
	card.effect_id = effect_id
	card.timing = "persistent"
	card.is_faceup = true
	_ship.add_faceup_damage(card)


func _make_ship() -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.ship_name = "Test Ship"
	data.hull = 5
	data.max_speed = 3
	data.command_value = 2
	data.engineering_value = 3
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = ["evade", "brace"]
	data.navigation_chart = [[2], [1, 2], [0, 1, 2]]
	return ShipInstance.create_from_data("test_ship", data, 2, 0)