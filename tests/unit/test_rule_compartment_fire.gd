## Test: Compartment Fire Rule
##
## Verifies the Phase M8 status-cleanup modifier for the Compartment Fire
## damage card.
extends GutTest


const SHIP_KEY_CR90: String = "cr90_corvette_a"
const OWNER_PLAYER: int = 0
const SHIP_INDEX: int = 0

var _state: GameState = null


func before_each() -> void:
	RuleRegistry.clear()
	CompartmentFire.register()
	_state = _make_state()


func after_each() -> void:
	RuleRegistry.clear()


func test_modifier_blocks_token_readying_for_ship_with_card() -> void:
	var ship: ShipInstance = _state.get_ship(OWNER_PLAYER, SHIP_INDEX)
	_add_compartment_fire(ship)
	var ctx: EffectContext = _apply_registered_modifier(ship)
	assert_true(ctx.cancelled,
			"Compartment Fire should block status-phase token readying.")


func test_modifier_allows_ship_without_card() -> void:
	var ship: ShipInstance = _state.get_ship(OWNER_PLAYER, SHIP_INDEX)
	var ctx: EffectContext = _apply_registered_modifier(ship)
	assert_false(ctx.cancelled,
			"Ships without Compartment Fire should ready normally.")


func test_modifier_ignores_compartment_fire_on_other_ship() -> void:
	var other_ship: ShipInstance = _make_ship(OWNER_PLAYER)
	_state.get_player_state(OWNER_PLAYER).ships.append(other_ship)
	_add_compartment_fire(other_ship)
	var ship: ShipInstance = _state.get_ship(OWNER_PLAYER, SHIP_INDEX)
	var ctx: EffectContext = _apply_registered_modifier(ship)
	assert_false(ctx.cancelled,
			"A different ship's damage card should not block this ship.")


func test_cleanup_blocks_readying_for_ship_with_card() -> void:
	var ship: ShipInstance = _state.get_ship(OWNER_PLAYER, SHIP_INDEX)
	_add_compartment_fire(ship)
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	ship.activated_this_round = true
	var result: Dictionary = StatusPhaseCleanupCommand.new(0, {}).execute(_state)
	assert_eq(int(ship.defense_tokens[0]["state"]),
			int(Constants.DefenseTokenState.EXHAUSTED),
			"Blocked token should remain exhausted during cleanup.")
	assert_eq(result["ships_blocked"], [SHIP_KEY_CR90],
			"Cleanup should report the blocked Compartment Fire ship.")
	assert_false(ship.activated_this_round,
			"Compartment Fire should not block activation reset.")


func test_cleanup_readies_other_ship_without_card() -> void:
	var blocked_ship: ShipInstance = _state.get_ship(OWNER_PLAYER, SHIP_INDEX)
	_add_compartment_fire(blocked_ship)
	blocked_ship.defense_tokens[0]["state"] = \
			Constants.DefenseTokenState.EXHAUSTED
	var ready_ship: ShipInstance = _make_ship(OWNER_PLAYER)
	ready_ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	_state.get_player_state(OWNER_PLAYER).ships.append(ready_ship)
	var result: Dictionary = StatusPhaseCleanupCommand.new(0, {}).execute(_state)
	assert_eq(int(ready_ship.defense_tokens[0]["state"]),
			int(Constants.DefenseTokenState.READY),
			"Ships without the card should still ready defense tokens.")
	assert_eq(result["ships_readied"], 1,
			"Cleanup should count only the unblocked ship as readied.")


func test_cleanup_blocks_after_save_load_without_legacy_effect() -> void:
	var ship: ShipInstance = _state.get_ship(OWNER_PLAYER, SHIP_INDEX)
	_add_compartment_fire(ship)
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	var restored: GameState = GameState.deserialize(_state.serialize())
	EffectFactory.rebuild_runtime_effects(restored, restored.initiative_player)
	var restored_ship: ShipInstance = restored.get_ship(OWNER_PLAYER, SHIP_INDEX)
	var result: Dictionary = StatusPhaseCleanupCommand.new(0, {}).execute(restored)
	assert_eq(restored.effect_registry.get_effect_count(), 0,
			"Compartment Fire should no longer require a legacy effect bridge.")
	assert_eq(int(restored_ship.defense_tokens[0]["state"]),
			int(Constants.DefenseTokenState.EXHAUSTED),
			"RuleRegistry should still block the restored ship's readying.")
	assert_eq(result["ships_blocked"], [SHIP_KEY_CR90],
			"Restored cleanup should report the blocked ship.")


func _apply_registered_modifier(ship: ShipInstance) -> EffectContext:
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	var hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			int(Constants.InteractionFlow.STATUS_CLEANUP),
			int(Constants.InteractionStep.STATUS_CLEANUP_STEP),
			StatusPhaseCleanupCommand.TARGET_DEFENSE_TOKEN_READYING)
	assert_eq(hooks.size(), 1,
			"Compartment Fire should register one readying modifier.")
	var raw: Variant = hooks[0].callback.call(ctx)
	if raw is EffectContext:
		ctx = raw as EffectContext
	return ctx


func _make_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.STATUS
	state.get_player_state(OWNER_PLAYER).ships.append(_make_ship(OWNER_PLAYER))
	return state


func _make_ship(owner_player: int) -> ShipInstance:
	var template: ShipData = AssetLoader.load_ship_data(SHIP_KEY_CR90)
	assert_not_null(template,
			"Test fixture requires ship data for %s." % SHIP_KEY_CR90)
	return ShipInstance.create_from_data(
			SHIP_KEY_CR90, template, 2, owner_player)


func _add_compartment_fire(ship: ShipInstance) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", "Compartment Fire")
	card.effect_id = CompartmentFire.EFFECT_ID
	card.effect_text = "You cannot ready your defense tokens during the Status Phase."
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card
