## Test: Targeter Disruption Rule
##
## Verifies the Phase N9 RuleRegistry critical-effect blocker for the
## Targeter Disruption damage card.
extends GutTest


const SHIP_KEY_CR90: String = "cr90_corvette_a"
const ATTACKER_PLAYER: int = 0
const SHIP_INDEX: int = 0

var _state: GameState = null
var _resolver: DefenseTokenResolver = null


func before_each() -> void:
	RuleRegistry.clear()
	TargeterDisruption.register()
	_state = _make_state()
	_resolver = DefenseTokenResolver.new()


func after_each() -> void:
	RuleRegistry.clear()


func test_register_adds_critical_effect_blocker() -> void:
	var blockers: Array[FlowHook] = RuleRegistry.blockers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			RuleSurface.TARGET_CRITICAL_EFFECT)
	assert_eq(blockers.size(), 1,
			"Targeter Disruption should expose critical-effect metadata.")
	assert_eq(RuleRegistry.registered_hook_count(), 1,
			"Targeter Disruption should register one hook.")


func test_blocker_blocks_critical_effect_for_ship_with_card() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_targeter_disruption(attacker)
	assert_true(_critical_effect_blocked(attacker),
			"Targeter Disruption should block critical effects for its ship.")


func test_blocker_allows_critical_effect_without_card() -> void:
	assert_false(_critical_effect_blocked(_attacker_ship()),
			"Ships without Targeter Disruption should resolve critical effects.")


func test_defense_resolver_uses_rule_without_legacy_registry() -> void:
	var attacker: ShipInstance = _attacker_ship()
	_add_targeter_disruption(attacker)
	var faceup: bool = _resolver.determine_first_card_faceup(
			_critical_results(), false, null, attacker)
	assert_false(faceup,
			"RuleRegistry should block the standard critical effect without legacy hooks.")


func test_resolve_damage_command_does_not_register_legacy_effect() -> void:
	var attacker: ShipInstance = _attacker_ship()
	var cmd := ResolveDamageCommand.new(ATTACKER_PLAYER, {
		"target_type": "ship",
		"owner_player": ATTACKER_PLAYER,
		"ship_index": SHIP_INDEX,
		"hull_zone": "FRONT",
		"shield_damage": 0,
		"damage_cards": [_targeter_card_data()],
		"target_destroyed": false,
	})
	var result: Dictionary = cmd.execute(_state)
	assert_eq(int(result.get("persistent_registered", -1)), 0,
			"Targeter Disruption should not register a legacy effect after N9.")
	assert_eq(_state.effect_registry.get_effect_count(), 0,
			"No legacy Targeter Disruption effect should be registered.")
	assert_true(_critical_effect_blocked(attacker),
			"The newly dealt card should still block through RuleRegistry.")


func test_blocker_applies_after_save_load_without_legacy_effect() -> void:
	_add_targeter_disruption(_attacker_ship())
	var restored: GameState = GameState.deserialize(_state.serialize())
	EffectFactory.rebuild_runtime_effects(restored, restored.initiative_player)
	var restored_attacker: ShipInstance = restored.get_ship(
			ATTACKER_PLAYER, SHIP_INDEX)
	assert_eq(restored.effect_registry.get_effect_count(), 0,
			"Targeter Disruption should not rebuild a legacy effect.")
	assert_true(_critical_effect_blocked(restored_attacker),
			"RuleRegistry blocker should still apply after save/load rebuild.")


func _critical_effect_blocked(attacker: ShipInstance) -> bool:
	var context: EffectContext = EffectContext.new()
	context.attacker = attacker
	return RuleSurface.is_blocked(context,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			RuleSurface.TARGET_CRITICAL_EFFECT)


func _critical_results() -> Array[Dictionary]:
	return [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.CRITICAL},
	]


func _make_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.get_player_state(ATTACKER_PLAYER).ships.append(
			_make_ship(ATTACKER_PLAYER))
	return state


func _make_ship(owner_player: int) -> ShipInstance:
	var template: ShipData = AssetLoader.load_ship_data(SHIP_KEY_CR90)
	assert_not_null(template,
			"Test fixture requires ship data for %s." % SHIP_KEY_CR90)
	return ShipInstance.create_from_data(
			SHIP_KEY_CR90, template, 2, owner_player)


func _attacker_ship() -> ShipInstance:
	return _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)


func _add_targeter_disruption(ship: ShipInstance) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", "Targeter Disruption")
	card.effect_id = TargeterDisruption.EFFECT_ID
	card.effect_text = "While attacking, you cannot resolve critical effects."
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card


func _targeter_card_data() -> Dictionary:
	var card: DamageCard = DamageCard.create("Ship", "Targeter Disruption")
	card.effect_id = TargeterDisruption.EFFECT_ID
	card.effect_text = "While attacking, you cannot resolve critical effects."
	card.timing = "persistent"
	card.is_faceup = true
	return card.serialize()