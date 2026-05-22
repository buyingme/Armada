## Test: Power Failure Rule
##
## Verifies the Phase N3 RuleRegistry engineering-value modifier for the
## Power Failure damage card.
extends GutTest


const SHIP_KEY_CR90: String = "cr90_corvette_a"
const OWNER_PLAYER: int = 0
const SHIP_INDEX: int = 0

var _state: GameState = null


func before_each() -> void:
	RuleRegistry.clear()
	PowerFailure.register()
	_state = _make_state()


func after_each() -> void:
	RuleRegistry.clear()


func test_register_adds_engineering_modifier_hook() -> void:
	var hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.REPAIR_STEP,
			PowerFailure.TARGET_ENGINEERING_VALUE)
	assert_eq(hooks.size(), 1,
			"Power Failure should register one engineering modifier.")
	assert_eq(hooks[0].rule_id, PowerFailure.RULE_ID,
			"Engineering modifier should carry the Power Failure rule id.")
	assert_eq(RuleRegistry.registered_hook_count(), 1,
			"Power Failure should register exactly one hook.")


func test_modifier_halves_even_engineering_value() -> void:
	var ship: ShipInstance = _make_custom_ship(OWNER_PLAYER, 4)
	_add_power_failure(ship)
	var ctx: EffectContext = _apply_modifier(ship, 4)
	assert_eq(int(ctx.get_meta_value("engineering_value", -1)), 2,
			"Power Failure should halve 4 engineering to 2.")


func test_modifier_rounds_down_odd_engineering_value() -> void:
	var ship: ShipInstance = _make_custom_ship(OWNER_PLAYER, 5)
	_add_power_failure(ship)
	var ctx: EffectContext = _apply_modifier(ship, 5)
	assert_eq(int(ctx.get_meta_value("engineering_value", -1)), 2,
			"Power Failure should halve 5 engineering to 2, rounded down.")


func test_modifier_stacks_multiple_power_failures_successively() -> void:
	var ship: ShipInstance = _make_custom_ship(OWNER_PLAYER, 5)
	_add_power_failure(ship)
	_add_power_failure(ship)
	var ctx: EffectContext = _apply_modifier(ship, 5)
	assert_eq(int(ctx.get_meta_value("engineering_value", -1)), 1,
			"Two Power Failure copies should reduce 5 to 2, then to 1.")


func test_modifier_allows_ship_without_card() -> void:
	var ship: ShipInstance = _make_custom_ship(OWNER_PLAYER, 5)
	var ctx: EffectContext = _apply_modifier(ship, 5)
	assert_eq(int(ctx.get_meta_value("engineering_value", -1)), 5,
			"Ships without Power Failure should keep full engineering value.")


func test_repair_resolver_uses_rule_modifier_without_legacy_registry() -> void:
	var ship: ShipInstance = _make_custom_ship(OWNER_PLAYER, 5)
	_prepare_repair_dial(ship)
	_add_power_failure(ship)
	var resolver: RepairResolver = RepairResolver.create(
			ship, DamageDeck.new(), null)
	assert_eq(resolver.get_total_points(), 2,
			"RepairResolver should consume RuleRegistry engineering modifiers.")


func test_modifier_applies_after_save_load_without_legacy_effect() -> void:
	var ship: ShipInstance = _state.get_ship(OWNER_PLAYER, SHIP_INDEX)
	_prepare_repair_dial(ship)
	_add_power_failure(ship)
	var restored: GameState = GameState.deserialize(_state.serialize())
	EffectFactory.rebuild_runtime_effects(restored, restored.initiative_player)
	var restored_ship: ShipInstance = restored.get_ship(OWNER_PLAYER, SHIP_INDEX)
	var resolver: RepairResolver = RepairResolver.create(
			restored_ship, restored.damage_deck, restored.effect_registry)
	assert_eq(restored.effect_registry.get_effect_count(), 0,
			"Power Failure should not rebuild a legacy effect after N3.")
	assert_eq(resolver.get_total_points(), 1,
			"RuleRegistry should still halve CR90 engineering after save/load.")


func _apply_modifier(ship: ShipInstance,
		engineering_value: int) -> EffectContext:
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("engineering_value", engineering_value)
	return RuleSurface.apply_modifiers(ctx,
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.REPAIR_STEP,
			PowerFailure.TARGET_ENGINEERING_VALUE)


func _make_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.damage_deck = DamageDeck.new()
	state.damage_deck.initialize()
	state.get_player_state(OWNER_PLAYER).ships.append(
			_make_ship(OWNER_PLAYER))
	return state


func _make_ship(owner_player: int) -> ShipInstance:
	var template: ShipData = AssetLoader.load_ship_data(SHIP_KEY_CR90)
	assert_not_null(template,
			"Test fixture requires ship data for %s." % SHIP_KEY_CR90)
	return ShipInstance.create_from_data(
			SHIP_KEY_CR90, template, 2, owner_player)


func _make_custom_ship(owner_player: int,
		engineering_value: int) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = 5
	data.max_speed = 3
	data.engineering_value = engineering_value
	data.command_value = 1
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = ["evade", "brace", "redirect"]
	data.navigation_chart = [[1], [1, 1], [0, 1, 1]]
	return ShipInstance.create_from_data("test_ship", data, 1, owner_player)


func _prepare_repair_dial(ship: ShipInstance) -> void:
	ship.command_dial_stack.assign_dials([Constants.CommandType.REPAIR], 1)
	ship.command_dial_stack.reveal_top()


func _add_power_failure(ship: ShipInstance) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", "Power Failure")
	card.effect_id = PowerFailure.EFFECT_ID
	card.effect_text = "Your engineering value is reduced to half its value, " \
			+"rounded down."
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card
