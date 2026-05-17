## Test: Damaged Munitions Rule
##
## Verifies the Phase M9 attack-roll dice-pool modifier for the Damaged
## Munitions damage card.
extends GutTest


const SHIP_KEY_CR90: String = "cr90_corvette_a"
const ATTACKER_PLAYER: int = 0
const DEFENDER_PLAYER: int = 1
const SHIP_INDEX: int = 0

var _state: GameState = null
var _resolver: AttackDiceResolver = null


func before_each() -> void:
	RuleRegistry.clear()
	DamagedMunitions.register()
	_state = _make_state()
	_resolver = AttackDiceResolver.new()


func after_each() -> void:
	RuleRegistry.clear()


func test_modifier_marks_choice_for_ship_attack_with_card() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: ShipInstance = _state.get_ship(DEFENDER_PLAYER, SHIP_INDEX)
	_add_damaged_munitions(attacker)
	var ctx: EffectContext = _apply_registered_modifier(
			attacker, defender, {DicePool.RED_KEY: 2, DicePool.BLUE_KEY: 1})
	var available: Array = ctx.get_meta_value(
			DamagedMunitions.META_AVAILABLE_COLOURS, []) as Array
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 3,
			"Damaged Munitions should not auto-remove before player choice.")
	assert_eq(ctx.get_meta_value(DamagedMunitions.META_PENDING_RULE_ID, ""),
			DamagedMunitions.RULE_ID,
			"Modifier should expose the pending Damaged Munitions choice.")
	assert_eq(available, [DicePool.RED_KEY, DicePool.BLUE_KEY],
			"Choice metadata should list only colours present in the pool.")
	assert_eq(ctx.get_meta_value(DamagedMunitions.META_REMOVED_COLOUR, ""), "",
			"No removed die should be recorded before a colour is chosen.")


func test_modifier_removes_chosen_die_for_ship_attack_with_card() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: ShipInstance = _state.get_ship(DEFENDER_PLAYER, SHIP_INDEX)
	_add_damaged_munitions(attacker)
	var ctx: EffectContext = _apply_registered_modifier(attacker, defender,
			{DicePool.RED_KEY: 2, DicePool.BLUE_KEY: 1},
			{DamagedMunitions.META_CHOSEN_COLOUR: DicePool.BLUE_KEY})
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 2,
			"Chosen Damaged Munitions colour should remove exactly one die.")
	assert_eq(ctx.dice_pool[DicePool.RED_KEY], 2,
			"Choosing blue should leave red dice untouched.")
	assert_false(ctx.dice_pool.has(DicePool.BLUE_KEY),
			"Choosing the only blue die should erase the blue key.")
	assert_eq(ctx.get_meta_value(DamagedMunitions.META_REMOVED_COLOUR, ""),
			DicePool.BLUE_KEY,
			"Modifier should record the player-selected removed colour.")


func test_modifier_ignores_unavailable_chosen_die() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: ShipInstance = _state.get_ship(DEFENDER_PLAYER, SHIP_INDEX)
	_add_damaged_munitions(attacker)
	var ctx: EffectContext = _apply_registered_modifier(attacker, defender,
			{DicePool.RED_KEY: 2, DicePool.BLUE_KEY: 1},
			{DamagedMunitions.META_CHOSEN_COLOUR: DicePool.BLACK_KEY})
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 3,
			"Unavailable chosen colours should not mutate the pool.")
	assert_eq(ctx.get_meta_value(DamagedMunitions.META_REMOVED_COLOUR, ""), "",
			"Unavailable chosen colours should not record a removal.")


func test_modifier_allows_ship_without_card() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: ShipInstance = _state.get_ship(DEFENDER_PLAYER, SHIP_INDEX)
	var ctx: EffectContext = _apply_registered_modifier(
			attacker, defender, {DicePool.RED_KEY: 2, DicePool.BLUE_KEY: 1})
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 3,
			"Ships without Damaged Munitions should keep their full pool.")


func test_modifier_ignores_damaged_munitions_on_other_ship() -> void:
	var other_attacker: ShipInstance = _make_ship(ATTACKER_PLAYER)
	_state.get_player_state(ATTACKER_PLAYER).ships.append(other_attacker)
	_add_damaged_munitions(other_attacker)
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: ShipInstance = _state.get_ship(DEFENDER_PLAYER, SHIP_INDEX)
	var ctx: EffectContext = _apply_registered_modifier(
			attacker, defender, {DicePool.RED_KEY: 2})
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 2,
			"A different ship's damage card should not affect this attack.")


func test_modifier_ignores_squadron_defender() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	_add_damaged_munitions(attacker)
	var defender: SquadronInstance = _make_squadron(DEFENDER_PLAYER)
	var ctx: EffectContext = _apply_registered_modifier(
			attacker, defender, {DicePool.RED_KEY: 2})
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 2,
			"Damaged Munitions should apply only when attacking a ship.")


func test_resolver_exposes_choice_without_legacy_effect() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: ShipInstance = _state.get_ship(DEFENDER_PLAYER, SHIP_INDEX)
	_add_damaged_munitions(attacker)
	var attacker_token: ShipToken = _make_ship_token(attacker)
	var defender_token: ShipToken = _make_ship_token(defender)
	var participants: CombatParticipants = CombatParticipants.create(
			attacker_token, Constants.HullZone.FRONT, null,
			defender_token, Constants.HullZone.FRONT, null)
	var ctx: EffectContext = _resolver.apply_gather_context(
			{DicePool.RED_KEY: 2, DicePool.BLUE_KEY: 1}, null, participants)
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 3,
			"AttackDiceResolver should expose player choice before removal.")
	assert_eq(ctx.get_meta_value(DamagedMunitions.META_PENDING_RULE_ID, ""),
			DamagedMunitions.RULE_ID,
			"AttackDiceResolver should preserve RuleRegistry choice metadata.")


func test_resolver_applies_chosen_rule_without_legacy_effect() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: ShipInstance = _state.get_ship(DEFENDER_PLAYER, SHIP_INDEX)
	_add_damaged_munitions(attacker)
	var participants: CombatParticipants = CombatParticipants.create(
			_make_ship_token(attacker), Constants.HullZone.FRONT, null,
			_make_ship_token(defender), Constants.HullZone.FRONT, null)
	var ctx: EffectContext = _resolver.apply_rule_pool_modifier(
			{DicePool.RED_KEY: 2, DicePool.BLUE_KEY: 1},
			participants, DamagedMunitions.RULE_ID,
			{DamagedMunitions.META_CHOSEN_COLOUR: DicePool.RED_KEY})
	assert_eq(ctx.dice_pool[DicePool.RED_KEY], 1,
			"Selected Damaged Munitions colour should be removed by resolver.")
	assert_eq(ctx.dice_pool[DicePool.BLUE_KEY], 1,
			"Unselected colours should remain in the pool.")


func test_modifier_applies_after_save_load_without_legacy_effect() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	_add_damaged_munitions(attacker)
	var restored: GameState = GameState.deserialize(_state.serialize())
	EffectFactory.rebuild_runtime_effects(restored, restored.initiative_player)
	var restored_attacker: ShipInstance = restored.get_ship(
			ATTACKER_PLAYER, SHIP_INDEX)
	var restored_defender: ShipInstance = restored.get_ship(
			DEFENDER_PLAYER, SHIP_INDEX)
	var ctx: EffectContext = _apply_registered_modifier(restored_attacker,
			restored_defender, {DicePool.RED_KEY: 2},
			{DamagedMunitions.META_CHOSEN_COLOUR: DicePool.RED_KEY})
	assert_eq(restored.effect_registry.get_effect_count(), 0,
			"Damaged Munitions should no longer require a legacy effect bridge.")
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 1,
			"Chosen RuleRegistry removal should work after save/load rebuild.")


func test_modifier_handles_empty_pool() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: ShipInstance = _state.get_ship(DEFENDER_PLAYER, SHIP_INDEX)
	_add_damaged_munitions(attacker)
	var ctx: EffectContext = _apply_registered_modifier(attacker, defender, {})
	assert_true(ctx.dice_pool.is_empty(),
			"Empty attack pools should remain empty.")
	assert_eq(ctx.get_meta_value("removed_die_color", ""), "",
			"No removed die should be recorded for an empty pool.")


func _apply_registered_modifier(attacker: RefCounted,
		defender: RefCounted,
		pool: Dictionary,
		metadata: Dictionary = {}) -> EffectContext:
	var ctx: EffectContext = EffectContext.new()
	ctx.attacker = attacker
	ctx.defender = defender
	ctx.dice_pool = pool.duplicate()
	ctx.metadata = metadata.duplicate(true)
	var hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			int(Constants.InteractionFlow.ATTACK),
			int(Constants.InteractionStep.ATTACK_ROLL),
			"dice_pool")
	assert_eq(hooks.size(), 1,
			"Damaged Munitions should register one dice-pool modifier.")
	var raw_context: Variant = hooks[0].callback.call(ctx)
	if raw_context is EffectContext:
		ctx = raw_context as EffectContext
	return ctx


func _make_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.get_player_state(ATTACKER_PLAYER).ships.append(
			_make_ship(ATTACKER_PLAYER))
	state.get_player_state(DEFENDER_PLAYER).ships.append(
			_make_ship(DEFENDER_PLAYER))
	return state


func _make_ship(owner_player: int) -> ShipInstance:
	var template: ShipData = AssetLoader.load_ship_data(SHIP_KEY_CR90)
	assert_not_null(template,
			"Test fixture requires ship data for %s." % SHIP_KEY_CR90)
	return ShipInstance.create_from_data(
			SHIP_KEY_CR90, template, 2, owner_player)


func _make_ship_token(instance: ShipInstance) -> ShipToken:
	var token: ShipToken = ShipToken.new()
	token._placement = TokenPlacement.new(
			SHIP_KEY_CR90, true, Constants.Faction.REBEL_ALLIANCE,
			0.5, 0.5, 0.0, Constants.ShipSize.SMALL)
	token._half_w = 30.0
	token._half_l = 50.0
	token._ship_data = instance.ship_data
	token._ship_instance = instance
	add_child_autofree(token)
	return token


func _make_squadron(owner_player: int) -> SquadronInstance:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "Test Squadron"
	data.hull = 3
	data.speed = 3
	data.defense_tokens = []
	data.keywords = []
	return SquadronInstance.create_from_data("test_squadron", data, owner_player)


func _add_damaged_munitions(ship: ShipInstance) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", "Damaged Munitions")
	card.effect_id = DamagedMunitions.EFFECT_ID
	card.effect_text = "When attacking a ship, before you roll your attack pool, " \
			+ "remove 1 die of your choice."
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card