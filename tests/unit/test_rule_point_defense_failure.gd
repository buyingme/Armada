## Test: Point-Defense Failure Rule
##
## Verifies the Phase M10 attack-roll dice-pool modifier for the
## Point-Defense Failure damage card.
extends GutTest


const SHIP_KEY_CR90: String = "cr90_corvette_a"
const ATTACKER_PLAYER: int = 0
const DEFENDER_PLAYER: int = 1
const SHIP_INDEX: int = 0

var _state: GameState = null
var _resolver: AttackDiceResolver = null


func before_each() -> void:
	RuleRegistry.clear()
	PointDefenseFailure.register()
	_state = _make_state()
	_resolver = AttackDiceResolver.new()


func after_each() -> void:
	RuleRegistry.clear()


func test_modifier_marks_choice_for_ship_attack_against_squadron() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: SquadronInstance = _make_squadron(DEFENDER_PLAYER)
	_add_point_defense_failure(attacker)
	var ctx: EffectContext = _apply_registered_modifier(attacker, defender,
			{DicePool.RED_KEY: 2, DicePool.BLACK_KEY: 1})
	var available: Array = ctx.get_meta_value(
			PointDefenseFailure.META_AVAILABLE_COLOURS, []) as Array
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 3,
			"Point-Defense Failure should not auto-remove before choice.")
	assert_eq(ctx.get_meta_value(PointDefenseFailure.META_PENDING_RULE_ID, ""),
			PointDefenseFailure.RULE_ID,
			"Modifier should expose the pending Point-Defense Failure choice.")
	assert_eq(available, [DicePool.RED_KEY, DicePool.BLACK_KEY],
			"Choice metadata should list only colours present in the pool.")


func test_modifier_removes_chosen_die_against_squadron() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: SquadronInstance = _make_squadron(DEFENDER_PLAYER)
	_add_point_defense_failure(attacker)
	var ctx: EffectContext = _apply_registered_modifier(attacker, defender,
			{DicePool.RED_KEY: 2, DicePool.BLACK_KEY: 1},
			{PointDefenseFailure.META_CHOSEN_COLOUR: DicePool.BLACK_KEY})
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 2,
			"Chosen Point-Defense Failure colour should remove exactly one die.")
	assert_eq(ctx.dice_pool[DicePool.RED_KEY], 2,
			"Choosing black should leave red dice untouched.")
	assert_false(ctx.dice_pool.has(DicePool.BLACK_KEY),
			"Choosing the only black die should erase the black key.")
	assert_eq(ctx.get_meta_value(PointDefenseFailure.META_REMOVED_COLOUR, ""),
			DicePool.BLACK_KEY,
			"Modifier should record the player-selected removed colour.")


func test_modifier_ignores_ship_defender() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: ShipInstance = _make_ship(DEFENDER_PLAYER)
	_add_point_defense_failure(attacker)
	var ctx: EffectContext = _apply_registered_modifier(
			attacker, defender, {DicePool.RED_KEY: 2})
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 2,
			"Point-Defense Failure should apply only against squadrons.")


func test_modifier_allows_ship_without_card() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: SquadronInstance = _make_squadron(DEFENDER_PLAYER)
	var ctx: EffectContext = _apply_registered_modifier(
			attacker, defender, {DicePool.RED_KEY: 2, DicePool.BLUE_KEY: 1})
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 3,
			"Ships without Point-Defense Failure should keep their full pool.")


func test_modifier_ignores_point_defense_on_other_ship() -> void:
	var other_attacker: ShipInstance = _make_ship(ATTACKER_PLAYER)
	_state.get_player_state(ATTACKER_PLAYER).ships.append(other_attacker)
	_add_point_defense_failure(other_attacker)
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: SquadronInstance = _make_squadron(DEFENDER_PLAYER)
	var ctx: EffectContext = _apply_registered_modifier(
			attacker, defender, {DicePool.RED_KEY: 2})
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 2,
			"A different ship's damage card should not affect this attack.")


func test_resolver_exposes_choice_without_legacy_effect() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	_add_point_defense_failure(attacker)
	var participants: CombatParticipants = CombatParticipants.create(
			_make_ship_token(attacker), Constants.HullZone.FRONT, null,
			null, -1, _make_squadron_token(DEFENDER_PLAYER))
	var ctx: EffectContext = _resolver.apply_gather_context(
			{DicePool.RED_KEY: 2, DicePool.BLUE_KEY: 1}, participants)
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 3,
			"AttackDiceResolver should expose player choice before removal.")
	assert_eq(ctx.get_meta_value(PointDefenseFailure.META_PENDING_RULE_ID, ""),
			PointDefenseFailure.RULE_ID,
			"AttackDiceResolver should preserve RuleRegistry choice metadata.")


func test_resolver_applies_chosen_rule_without_legacy_effect() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	_add_point_defense_failure(attacker)
	var participants: CombatParticipants = CombatParticipants.create(
			_make_ship_token(attacker), Constants.HullZone.FRONT, null,
			null, -1, _make_squadron_token(DEFENDER_PLAYER))
	var ctx: EffectContext = _resolver.apply_rule_pool_modifier(
			{DicePool.RED_KEY: 2, DicePool.BLUE_KEY: 1},
			participants, PointDefenseFailure.RULE_ID,
			{PointDefenseFailure.META_CHOSEN_COLOUR: DicePool.BLUE_KEY})
	assert_eq(ctx.dice_pool[DicePool.RED_KEY], 2,
			"Unselected colours should remain in the pool.")
	assert_false(ctx.dice_pool.has(DicePool.BLUE_KEY),
			"Selected Point-Defense Failure colour should be removed.")


func test_modifier_applies_after_save_load_without_legacy_effect() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	_add_point_defense_failure(attacker)
	var restored: GameState = GameState.deserialize(_state.serialize())
	var restored_attacker: ShipInstance = restored.get_ship(
			ATTACKER_PLAYER, SHIP_INDEX)
	var defender: SquadronInstance = _make_squadron(DEFENDER_PLAYER)
	var ctx: EffectContext = _apply_registered_modifier(restored_attacker,
			defender, {DicePool.RED_KEY: 2},
			{PointDefenseFailure.META_CHOSEN_COLOUR: DicePool.RED_KEY})
	assert_eq(DicePool.get_total_count(ctx.dice_pool), 1,
			"Chosen RuleRegistry removal should work after save/load rebuild.")


func test_modifier_handles_empty_pool() -> void:
	var attacker: ShipInstance = _state.get_ship(ATTACKER_PLAYER, SHIP_INDEX)
	var defender: SquadronInstance = _make_squadron(DEFENDER_PLAYER)
	_add_point_defense_failure(attacker)
	var ctx: EffectContext = _apply_registered_modifier(attacker, defender, {})
	assert_true(ctx.dice_pool.is_empty(),
			"Empty attack pools should remain empty.")
	assert_eq(ctx.get_meta_value(PointDefenseFailure.META_REMOVED_COLOUR, ""), "",
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
			"Point-Defense Failure should register one dice-pool modifier.")
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


func _make_squadron_token(owner_player: int) -> SquadronToken:
	var token: SquadronToken = SquadronToken.new()
	token._placement = TokenPlacement.new(
			"test_squadron", false, Constants.Faction.GALACTIC_EMPIRE,
			0.5, 0.5, 0.0)
	token._radius_px = 20.0
	token._squadron_instance = _make_squadron(owner_player)
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


func _add_point_defense_failure(ship: ShipInstance) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", "Point-Defense Failure")
	card.effect_id = PointDefenseFailure.EFFECT_ID
	card.effect_text = "When attacking a squadron, before you roll your " \
			+"attack pool, remove 1 die of your choice."
	card.timing = "persistent"
	card.is_faceup = true
	ship.add_faceup_damage(card)
	return card
