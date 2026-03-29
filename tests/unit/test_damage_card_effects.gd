## Test: DamageCardEffect + DamageCardEffectFactory
##
## Unit tests for all 16 persistent damage card effects and the factory
## that registers/unregisters them in the EffectRegistry.
##
## Rules Reference: RRG "Damage Cards", p.4; individual card texts.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


## Creates a minimal ShipInstance.
func _make_ship(owner_player: int = 0) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = 5
	data.max_speed = 3
	data.engineering_value = 4
	data.command_value = 2
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = ["evade", "brace", "redirect"]
	data.navigation_chart = [[1], [1, 1], [0, 1, 1]]
	return ShipInstance.create_from_data("test_ship", data, 2, owner_player)


## Creates a minimal SquadronInstance.
func _make_squadron(owner_player: int = 0) -> SquadronInstance:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "Test Squadron"
	data.hull = 3
	data.speed = 3
	data.defense_tokens = []
	data.keywords = []
	return SquadronInstance.create_from_data("test_sq", data, owner_player)


## Creates a DamageCard with the given effect_id.
func _make_card(eid: String) -> DamageCard:
	var card: DamageCard = DamageCard.create("Ship", eid)
	card.effect_id = eid
	card.timing = "persistent"
	card.is_faceup = true
	return card


## Creates a DamageCardEffect for the given effect_id, owned by ship.
func _make_effect(eid: String, ship: ShipInstance,
		card: DamageCard = null) -> DamageCardEffect:
	var effect: DamageCardEffect = DamageCardEffect.new()
	effect.effect_id = eid
	effect.source_id = eid
	effect.owner = ship
	effect.damage_card = card if card else _make_card(eid)
	return effect


## Creates an EffectContext with common fields set.
func _make_context(hook: StringName) -> EffectContext:
	var ctx: EffectContext = EffectContext.new()
	ctx.hook = hook
	return ctx


## Creates a DamageDeck for testing.
func _make_deck() -> DamageDeck:
	var deck: DamageDeck = DamageDeck.new()
	deck.initialize()
	return deck


# ---------------------------------------------------------------------------
# DamageCardEffectFactory
# ---------------------------------------------------------------------------


func test_factory_is_persistent_returns_true_for_persistent_cards() -> void:
	var card: DamageCard = _make_card("blinded_gunners")
	assert_true(DamageCardEffectFactory.is_persistent(card),
			"Blinded Gunners should be persistent")


func test_factory_is_persistent_returns_false_for_immediate_cards() -> void:
	var card: DamageCard = DamageCard.create("Ship", "Structural Damage")
	card.effect_id = "structural_damage"
	assert_false(DamageCardEffectFactory.is_persistent(card),
			"Structural Damage is immediate, not persistent")


func test_factory_register_creates_and_registers() -> void:
	var ship: ShipInstance = _make_ship()
	var card: DamageCard = _make_card("blinded_gunners")
	var reg: EffectRegistry = EffectRegistry.new()
	var effect: DamageCardEffect = DamageCardEffectFactory.register_effect(
			card, ship, reg)
	assert_not_null(effect, "Should return created effect")
	assert_eq(reg.get_effect_count(), 1, "Should register 1 effect")
	assert_eq(effect.owner, ship, "Effect owner should be the ship")
	assert_eq(effect.effect_id, "blinded_gunners",
			"Effect ID should match card")


func test_factory_unregister_removes_by_card() -> void:
	var ship: ShipInstance = _make_ship()
	var card: DamageCard = _make_card("blinded_gunners")
	var reg: EffectRegistry = EffectRegistry.new()
	DamageCardEffectFactory.register_effect(card, ship, reg)
	assert_eq(reg.get_effect_count(), 1, "Pre: 1 effect")
	var removed: bool = DamageCardEffectFactory.unregister_effect(card, reg)
	assert_true(removed, "Should find and unregister effect")
	assert_eq(reg.get_effect_count(), 0, "Post: 0 effects")


func test_factory_register_returns_null_for_immediate() -> void:
	var ship: ShipInstance = _make_ship()
	var card: DamageCard = DamageCard.create("Ship", "Structural Damage")
	card.effect_id = "structural_damage"
	var reg: EffectRegistry = EffectRegistry.new()
	var effect: DamageCardEffect = DamageCardEffectFactory.register_effect(
			card, ship, reg)
	assert_null(effect, "Should return null for non-persistent card")
	assert_eq(reg.get_effect_count(), 0, "Should not register anything")


# ---------------------------------------------------------------------------
# get_hooks
# ---------------------------------------------------------------------------


func test_blinded_gunners_hooks() -> void:
	var e: DamageCardEffect = _make_effect("blinded_gunners", _make_ship())
	var hooks: Array[StringName] = e.get_hooks()
	assert_has(hooks, &"ATTACK_SPEND_ACCURACY",
			"Blinded Gunners should hook ATTACK_SPEND_ACCURACY")


func test_capacitor_failure_hooks() -> void:
	var e: DamageCardEffect = _make_effect("capacitor_failure", _make_ship())
	var hooks: Array[StringName] = e.get_hooks()
	assert_has(hooks, &"DEFENSE_VALIDATE_TOKEN",
			"Should hook DEFENSE_VALIDATE_TOKEN")
	assert_has(hooks, &"REPAIR_VALIDATE_SHIELD",
			"Should hook REPAIR_VALIDATE_SHIELD")


func test_coolant_discharge_hooks() -> void:
	var e: DamageCardEffect = _make_effect("coolant_discharge", _make_ship())
	var hooks: Array[StringName] = e.get_hooks()
	assert_has(hooks, &"ATTACK_VALIDATE_TARGET",
			"Should hook ATTACK_VALIDATE_TARGET")
	assert_has(hooks, &"ATTACK_CALC_DAMAGE",
			"Should hook ATTACK_CALC_DAMAGE for close-range bonus")


# ---------------------------------------------------------------------------
# Blinded Gunners — cannot spend accuracy icons
# ---------------------------------------------------------------------------


func test_blinded_gunners_triggers_when_owner_attacks() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("blinded_gunners", ship)
	var ctx: EffectContext = _make_context(&"ATTACK_SPEND_ACCURACY")
	ctx.attacker = ship
	assert_true(e.should_trigger(ctx),
			"Should trigger when owner is attacker")


func test_blinded_gunners_no_trigger_when_other_attacks() -> void:
	var ship: ShipInstance = _make_ship()
	var other: ShipInstance = _make_ship(1)
	var e: DamageCardEffect = _make_effect("blinded_gunners", ship)
	var ctx: EffectContext = _make_context(&"ATTACK_SPEND_ACCURACY")
	ctx.attacker = other
	assert_false(e.should_trigger(ctx),
			"Should not trigger when other ship attacks")


func test_blinded_gunners_cancels() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("blinded_gunners", ship)
	var ctx: EffectContext = _make_context(&"ATTACK_SPEND_ACCURACY")
	ctx.attacker = ship
	e.resolve(ctx)
	assert_true(ctx.cancelled, "Should cancel accuracy spending")


# ---------------------------------------------------------------------------
# Targeter Disruption — cannot resolve critical effects
# ---------------------------------------------------------------------------


func test_targeter_disruption_blocks_critical() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("targeter_disruption", ship)
	var ctx: EffectContext = _make_context(&"ATTACK_RESOLVE_CRITICAL")
	ctx.attacker = ship
	ctx.critical_allowed = true
	e.resolve(ctx)
	assert_false(ctx.critical_allowed,
			"Should set critical_allowed = false")


# ---------------------------------------------------------------------------
# Depowered Armament — cannot attack at long range
# ---------------------------------------------------------------------------


func test_depowered_armament_triggers_at_long() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("depowered_armament", ship)
	var ctx: EffectContext = _make_context(&"ATTACK_VALIDATE_TARGET")
	ctx.attacker = ship
	ctx.range_band = "long"
	assert_true(e.should_trigger(ctx),
			"Should trigger at long range")


func test_depowered_armament_no_trigger_at_close() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("depowered_armament", ship)
	var ctx: EffectContext = _make_context(&"ATTACK_VALIDATE_TARGET")
	ctx.attacker = ship
	ctx.range_band = "close"
	assert_false(e.should_trigger(ctx),
			"Should not trigger at close range")


# ---------------------------------------------------------------------------
# Disengaged Fire Control — cannot attack obstructed targets
# ---------------------------------------------------------------------------


func test_disengaged_fire_control_triggers_when_obstructed() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("disengaged_fire_control", ship)
	var ctx: EffectContext = _make_context(&"ATTACK_VALIDATE_TARGET")
	ctx.attacker = ship
	ctx.set_meta_value("is_obstructed", true)
	assert_true(e.should_trigger(ctx),
			"Should trigger when target is obstructed")


# ---------------------------------------------------------------------------
# Damaged Munitions — remove 1 die when attacking a ship
# ---------------------------------------------------------------------------


func test_damaged_munitions_removes_one_die() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("damaged_munitions", ship)
	var ctx: EffectContext = _make_context(&"ATTACK_GATHER_DICE")
	ctx.attacker = ship
	ctx.dice_pool = {0: 2, 1: 1} # 2 red, 1 blue
	e.resolve(ctx)
	var total: int = 0
	for count: Variant in ctx.dice_pool.values():
		total += int(count)
	assert_eq(total, 2, "Should have 1 fewer die")


# ---------------------------------------------------------------------------
# Point-Defense Failure — remove 1 die vs squadrons
# ---------------------------------------------------------------------------


func test_point_defense_failure_triggers_vs_squadron() -> void:
	var ship: ShipInstance = _make_ship()
	var sq: SquadronInstance = _make_squadron(1)
	var e: DamageCardEffect = _make_effect("point_defense_failure", ship)
	var ctx: EffectContext = _make_context(&"ATTACK_GATHER_DICE")
	ctx.attacker = ship
	ctx.defender = sq
	assert_true(e.should_trigger(ctx),
			"Should trigger vs squadron")


func test_point_defense_failure_no_trigger_vs_ship() -> void:
	var ship: ShipInstance = _make_ship()
	var defender: ShipInstance = _make_ship(1)
	var e: DamageCardEffect = _make_effect("point_defense_failure", ship)
	var ctx: EffectContext = _make_context(&"ATTACK_GATHER_DICE")
	ctx.attacker = ship
	ctx.defender = defender
	assert_false(e.should_trigger(ctx),
			"Should not trigger vs ship")


# ---------------------------------------------------------------------------
# Faulty Countermeasures — cannot spend exhausted defense tokens
# ---------------------------------------------------------------------------


func test_faulty_countermeasures_blocks_exhausted_token() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("faulty_countermeasures", ship)
	var ctx: EffectContext = _make_context(&"DEFENSE_VALIDATE_TOKEN")
	ctx.defender = ship
	ctx.set_meta_value("token_state", Constants.DefenseTokenState.EXHAUSTED)
	assert_true(e.should_trigger(ctx),
			"Should trigger for exhausted tokens")
	e.resolve(ctx)
	assert_true(ctx.cancelled, "Should cancel spending")


func test_faulty_countermeasures_allows_ready_token() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("faulty_countermeasures", ship)
	var ctx: EffectContext = _make_context(&"DEFENSE_VALIDATE_TOKEN")
	ctx.defender = ship
	ctx.set_meta_value("token_state", Constants.DefenseTokenState.READY)
	assert_false(e.should_trigger(ctx),
			"Should not trigger for ready tokens")


# ---------------------------------------------------------------------------
# Capacitor Failure — blocks Redirect if zone has 0 shields,
# and blocks repair shield ops to 0-shield zones
# ---------------------------------------------------------------------------


func test_capacitor_failure_blocks_redirect_to_empty_zone() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("capacitor_failure", ship)
	var ctx: EffectContext = _make_context(&"DEFENSE_VALIDATE_TOKEN")
	ctx.defender = ship
	ctx.set_meta_value("token_type", Constants.DefenseToken.REDIRECT)
	ctx.set_meta_value("target_zone_shields", 0)
	assert_true(e.should_trigger(ctx),
			"Should trigger for Redirect to 0-shield zone")


func test_capacitor_failure_allows_redirect_to_shielded_zone() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("capacitor_failure", ship)
	var ctx: EffectContext = _make_context(&"DEFENSE_VALIDATE_TOKEN")
	ctx.defender = ship
	ctx.set_meta_value("token_type", Constants.DefenseToken.REDIRECT)
	ctx.set_meta_value("target_zone_shields", 2)
	assert_false(e.should_trigger(ctx),
			"Should not trigger for zone with shields")


func test_capacitor_failure_blocks_repair_to_empty_zone() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("capacitor_failure", ship)
	var ctx: EffectContext = _make_context(&"REPAIR_VALIDATE_SHIELD")
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("target_zone_shields", 0)
	assert_true(e.should_trigger(ctx),
			"Should trigger for repair to 0-shield zone")


# ---------------------------------------------------------------------------
# Coolant Discharge — 1 attack/round, +1 damage at close
# ---------------------------------------------------------------------------


func test_coolant_discharge_blocks_second_attack() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("coolant_discharge", ship)
	var ctx: EffectContext = _make_context(&"ATTACK_VALIDATE_TARGET")
	ctx.attacker = ship
	ctx.set_meta_value("ship_attacks_this_round", 1)
	assert_true(e.should_trigger(ctx),
			"Should trigger when ship already attacked once")
	e.resolve(ctx)
	assert_true(ctx.cancelled, "Should cancel second attack")


func test_coolant_discharge_allows_first_attack() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("coolant_discharge", ship)
	var ctx: EffectContext = _make_context(&"ATTACK_VALIDATE_TARGET")
	ctx.attacker = ship
	ctx.set_meta_value("ship_attacks_this_round", 0)
	assert_false(e.should_trigger(ctx),
			"Should not trigger for the first attack")


func test_coolant_discharge_bonus_at_close() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("coolant_discharge", ship)
	var ctx: EffectContext = _make_context(&"ATTACK_CALC_DAMAGE")
	ctx.attacker = ship
	ctx.range_band = "close"
	ctx.damage_total = 3
	assert_true(e.should_trigger(ctx), "Should trigger at close range")
	e.resolve(ctx)
	assert_eq(ctx.damage_total, 4, "Should add +1 damage at close range")


# ---------------------------------------------------------------------------
# Thrust Control Malfunction — reduce yaw at last joint
# ---------------------------------------------------------------------------


func test_thrust_control_reduces_last_yaw() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect(
			"thrust_control_malfunction", ship)
	var ctx: EffectContext = _make_context(&"MANEUVER_DETERMINE_YAWS")
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("yaw_values", [1, 2, 1])
	e.resolve(ctx)
	var yaws: Array = ctx.get_meta_value("yaw_values") as Array
	assert_eq(int(yaws[2]), 0,
			"Last joint yaw should be reduced from 1 to 0")
	assert_eq(int(yaws[0]), 1,
			"First joint should be unaffected")


# ---------------------------------------------------------------------------
# Ruptured Engine — suffer 1 facedown if speed > 1
# ---------------------------------------------------------------------------


func test_ruptured_engine_triggers_at_speed_2() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("ruptured_engine", ship)
	var ctx: EffectContext = _make_context(&"AFTER_MANEUVER_EXECUTE")
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("ship_speed", 2)
	assert_true(e.should_trigger(ctx),
			"Should trigger at speed > 1")


func test_ruptured_engine_no_trigger_at_speed_1() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("ruptured_engine", ship)
	var ctx: EffectContext = _make_context(&"AFTER_MANEUVER_EXECUTE")
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("ship_speed", 1)
	assert_false(e.should_trigger(ctx),
			"Should not trigger at speed 1")


func test_ruptured_engine_deals_facedown() -> void:
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var e: DamageCardEffect = _make_effect("ruptured_engine", ship)
	var ctx: EffectContext = _make_context(&"AFTER_MANEUVER_EXECUTE")
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("ship_speed", 2)
	ctx.set_meta_value("damage_deck", deck)
	var dmg_before: int = ship.facedown_damage.size()
	e.resolve(ctx)
	assert_eq(ship.facedown_damage.size(), dmg_before + 1,
			"Should add 1 facedown damage card")


# ---------------------------------------------------------------------------
# Damaged Controls — extra facedown on obstacle overlap
# ---------------------------------------------------------------------------


func test_damaged_controls_triggers_on_overlap() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("damaged_controls", ship)
	var ctx: EffectContext = _make_context(&"AFTER_MANEUVER_EXECUTE")
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("did_overlap", true)
	assert_true(e.should_trigger(ctx),
			"Should trigger when ship overlaps obstacle")


func test_damaged_controls_no_trigger_without_overlap() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("damaged_controls", ship)
	var ctx: EffectContext = _make_context(&"AFTER_MANEUVER_EXECUTE")
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("did_overlap", false)
	assert_false(e.should_trigger(ctx),
			"Should not trigger without overlap")


# ---------------------------------------------------------------------------
# Thruster Fissure — suffer 1 facedown on speed change
# ---------------------------------------------------------------------------


func test_thruster_fissure_triggers_on_speed_change() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("thruster_fissure", ship)
	var ctx: EffectContext = _make_context(&"ON_SPEED_CHANGE")
	ctx.set_meta_value("ship", ship)
	assert_true(e.should_trigger(ctx), "Should trigger for owning ship")


# ---------------------------------------------------------------------------
# Crew Panic — suffer 1 facedown OR discard this card
# ---------------------------------------------------------------------------


func test_crew_panic_suffer_damage() -> void:
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_card("crew_panic")
	var e: DamageCardEffect = _make_effect("crew_panic", ship, card)
	var ctx: EffectContext = _make_context(&"BEFORE_REVEAL_DIAL")
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("damage_deck", deck)
	ctx.set_meta_value("dial_discarded", false)
	var dmg_before: int = ship.facedown_damage.size()
	e.resolve(ctx)
	assert_eq(ship.facedown_damage.size(), dmg_before + 1,
			"Should suffer 1 facedown damage")


func test_crew_panic_discard_card() -> void:
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var card: DamageCard = _make_card("crew_panic")
	ship.add_faceup_damage(card)
	var e: DamageCardEffect = _make_effect("crew_panic", ship, card)
	var ctx: EffectContext = _make_context(&"BEFORE_REVEAL_DIAL")
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("damage_deck", deck)
	ctx.set_meta_value("dial_discarded", true)
	e.resolve(ctx)
	assert_false(ship.faceup_damage.has(card),
			"Card should be removed from ship")


# ---------------------------------------------------------------------------
# Power Failure — halve engineering value
# ---------------------------------------------------------------------------


func test_power_failure_halves_eng_value() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("power_failure", ship)
	var ctx: EffectContext = _make_context(&"CALC_ENGINEERING_VALUE")
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("engineering_value", 4)
	e.resolve(ctx)
	assert_eq(int(ctx.get_meta_value("engineering_value")), 2,
			"Should halve 4 → 2")


func test_power_failure_rounds_down() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("power_failure", ship)
	var ctx: EffectContext = _make_context(&"CALC_ENGINEERING_VALUE")
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("engineering_value", 3)
	e.resolve(ctx)
	assert_eq(int(ctx.get_meta_value("engineering_value")), 1,
			"Should halve 3 → 1 (rounded down)")


# ---------------------------------------------------------------------------
# Compartment Fire — cannot ready defense tokens
# ---------------------------------------------------------------------------


func test_compartment_fire_cancels_token_readying() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("compartment_fire", ship)
	var ctx: EffectContext = _make_context(&"STATUS_READY_TOKENS")
	ctx.set_meta_value("ship", ship)
	e.resolve(ctx)
	assert_true(ctx.cancelled,
			"Should cancel defense token readying")


# ---------------------------------------------------------------------------
# Life Support Failure (persistent) — cannot gain command tokens
# ---------------------------------------------------------------------------


func test_life_support_failure_blocks_token_gain() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("life_support_failure", ship)
	var ctx: EffectContext = _make_context(&"ON_COMMAND_TOKEN_GAIN")
	ctx.set_meta_value("ship", ship)
	e.resolve(ctx)
	assert_true(ctx.cancelled,
			"Should cancel command token gain")
