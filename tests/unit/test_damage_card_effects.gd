## Test: DamageCardEffect + DamageCardEffectFactory
##
## Unit tests for legacy persistent damage card effects and the factory
## that registers/unregisters them in the EffectRegistry. Migrated
## RuleRegistry cards are asserted absent from the legacy bridge.
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


func test_capacitor_failure_no_longer_declares_legacy_hooks() -> void:
	var e: DamageCardEffect = _make_effect("capacitor_failure", _make_ship())
	var hooks: Array[StringName] = e.get_hooks()
	assert_false(hooks.has(&"DEFENSE_VALIDATE_TOKEN"),
			"Capacitor Failure should not use the legacy defense hook after M12.")
	assert_false(hooks.has(&"REPAIR_VALIDATE_SHIELD"),
			"Capacitor Failure should not use the legacy repair hook after M12.")


func test_faulty_countermeasures_no_longer_declares_legacy_hook() -> void:
	var e: DamageCardEffect = _make_effect(
			"faulty_countermeasures", _make_ship())
	var hooks: Array[StringName] = e.get_hooks()
	assert_false(hooks.has(&"DEFENSE_VALIDATE_TOKEN"),
			"Faulty Countermeasures should use RuleRegistry blockers after N2.")


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
# Damaged Munitions — migrated to RuleRegistry
# ---------------------------------------------------------------------------


func test_damaged_munitions_no_longer_registers_legacy_effect() -> void:
	var ship: ShipInstance = _make_ship()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("damaged_munitions")
	var effect: DamageCardEffect = DamageCardEffectFactory.register_effect(
			card, ship, reg)
	assert_null(effect,
			"Damaged Munitions should be handled by RuleRegistry after M9.")
	assert_eq(reg.get_effect_count(), 0,
			"Damaged Munitions should not add a legacy runtime hook.")


func test_damaged_munitions_no_longer_declares_gather_hook() -> void:
	var effect: DamageCardEffect = _make_effect(
			"damaged_munitions", _make_ship())
	var hooks: Array[StringName] = effect.get_hooks()
	assert_false(hooks.has(&"ATTACK_GATHER_DICE"),
			"Damaged Munitions should not use the legacy gather hook after M9.")


# ---------------------------------------------------------------------------
# Point-Defense Failure — migrated to RuleRegistry
# ---------------------------------------------------------------------------


func test_point_defense_failure_no_longer_registers_legacy_effect() -> void:
	var ship: ShipInstance = _make_ship()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("point_defense_failure")
	var effect: DamageCardEffect = DamageCardEffectFactory.register_effect(
			card, ship, reg)
	assert_null(effect,
			"Point-Defense Failure should be handled by RuleRegistry after M10.")
	assert_eq(reg.get_effect_count(), 0,
			"Point-Defense Failure should not add a legacy runtime hook.")


func test_point_defense_failure_no_longer_declares_gather_hook() -> void:
	var effect: DamageCardEffect = _make_effect(
			"point_defense_failure", _make_ship())
	var hooks: Array[StringName] = effect.get_hooks()
	assert_false(hooks.has(&"ATTACK_GATHER_DICE"),
			"Point-Defense Failure should not use the legacy gather hook after M10.")


# ---------------------------------------------------------------------------
# Faulty Countermeasures — migrated to RuleRegistry
# ---------------------------------------------------------------------------


func test_faulty_countermeasures_no_longer_triggers_legacy_effect() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("faulty_countermeasures", ship)
	var ctx: EffectContext = _make_context(&"DEFENSE_VALIDATE_TOKEN")
	ctx.defender = ship
	ctx.set_meta_value("token_state", Constants.DefenseTokenState.EXHAUSTED)
	assert_false(e.should_trigger(ctx),
			"Faulty Countermeasures should no longer trigger legacy effects.")


func test_faulty_countermeasures_factory_no_longer_registers_effect() -> void:
	var ship: ShipInstance = _make_ship()
	var card: DamageCard = _make_card("faulty_countermeasures")
	var reg: EffectRegistry = EffectRegistry.new()
	var effect: DamageCardEffect = DamageCardEffectFactory.register_effect(
			card, ship, reg)
	assert_null(effect,
			"Faulty Countermeasures should not register a legacy effect after N2.")
	assert_eq(reg.get_effect_count(), 0,
			"Faulty Countermeasures should leave EffectRegistry empty.")


# ---------------------------------------------------------------------------
# Capacitor Failure — migrated to RuleRegistry
# ---------------------------------------------------------------------------


func test_capacitor_failure_no_longer_registers_legacy_effect() -> void:
	var ship: ShipInstance = _make_ship()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("capacitor_failure")
	var effect: DamageCardEffect = DamageCardEffectFactory.register_effect(
			card, ship, reg)
	assert_null(effect,
			"Capacitor Failure should be handled by RuleRegistry after M12.")
	assert_eq(reg.get_effect_count(), 0,
			"Capacitor Failure should not add a legacy runtime hook.")


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
	e.resolve(ctx)
	assert_true(ctx.get_meta_value("extra_damage_dealt", false),
			"Should flag extra_damage_dealt for command submission")


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
# Crew Panic — migrated to RuleRegistry
# ---------------------------------------------------------------------------


func test_crew_panic_no_longer_declares_before_reveal_hook() -> void:
	var ship: ShipInstance = _make_ship()
	var effect: DamageCardEffect = _make_effect("crew_panic", ship)
	assert_eq(effect.get_hooks().size(), 0,
			"Crew Panic should not expose legacy BEFORE_REVEAL_DIAL hooks.")


func test_crew_panic_no_longer_triggers_legacy_context() -> void:
	var ship: ShipInstance = _make_ship()
	var effect: DamageCardEffect = _make_effect("crew_panic", ship)
	var ctx: EffectContext = _make_context(&"BEFORE_REVEAL_DIAL")
	ctx.set_meta_value("ship", ship)
	assert_false(effect.should_trigger(ctx),
			"Crew Panic should be inactive in legacy EffectRegistry contexts.")


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
# Compartment Fire — migrated to RuleRegistry
# ---------------------------------------------------------------------------


func test_compartment_fire_no_longer_registers_legacy_effect() -> void:
	var ship: ShipInstance = _make_ship()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("compartment_fire")
	var effect: DamageCardEffect = DamageCardEffectFactory.register_effect(
			card, ship, reg)
	assert_null(effect,
			"Compartment Fire should be handled by RuleRegistry after M8.")
	assert_eq(reg.get_effect_count(), 0,
			"Compartment Fire should not add a legacy runtime hook.")


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


# ---------------------------------------------------------------------------
# Integration: Faulty Countermeasures migrated out of EffectRegistry
# ---------------------------------------------------------------------------


func test_faulty_countermeasures_pipeline_no_longer_blocks_tokens() -> void:
	var ship: ShipInstance = _make_ship()
	var e: DamageCardEffect = _make_effect("faulty_countermeasures", ship)
	var reg: EffectRegistry = EffectRegistry.new()
	reg.register(e)
	var ctx: EffectContext = EffectContext.new()
	ctx.defender = ship
	ctx.set_meta_value("token_state",
			Constants.DefenseTokenState.EXHAUSTED)
	ctx = reg.resolve_hook(&"DEFENSE_VALIDATE_TOKEN", ctx)
	assert_false(ctx.cancelled,
			"Legacy DEFENSE_VALIDATE_TOKEN should not block after N2.")
	assert_eq(reg.get_effects_for_hook(&"DEFENSE_VALIDATE_TOKEN").size(), 0,
			"Faulty Countermeasures should not register the legacy hook.")


# ---------------------------------------------------------------------------
# Integration: Crew Panic migrated out of EffectRegistry
# ---------------------------------------------------------------------------


func test_crew_panic_no_longer_registers_legacy_effect() -> void:
	var ship: ShipInstance = _make_ship()
	var card: DamageCard = _make_card("crew_panic")
	ship.add_faceup_damage(card)
	var reg: EffectRegistry = EffectRegistry.new()
	var effect: DamageCardEffect = DamageCardEffectFactory.register_effect(
			card, ship, reg)
	assert_null(effect, "Crew Panic should not create a legacy effect.")
	assert_eq(reg.get_effect_count(), 0,
			"Crew Panic should not be present in the legacy registry.")


func test_crew_panic_factory_is_not_persistent() -> void:
	var card: DamageCard = _make_card("crew_panic")
	assert_false(DamageCardEffectFactory.is_persistent(card),
			"Crew Panic should be registered by RuleRegistry, not EffectRegistry.")


# ---------------------------------------------------------------------------
# Integration: ATTACK_VALIDATE_TARGET pipeline (multiple effects)
# ---------------------------------------------------------------------------


func test_attack_validate_pipeline_coolant_discharge_blocks() -> void:
	# Arrange — register Coolant Discharge.
	var ship: ShipInstance = _make_ship()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("coolant_discharge")
	DamageCardEffectFactory.register_effect(card, ship, reg)
	# Act — ship already attacked once.
	var ctx: EffectContext = EffectContext.new()
	ctx.attacker = ship
	ctx.set_meta_value("ship_attacks_this_round", 1)
	ctx = reg.resolve_hook(&"ATTACK_VALIDATE_TARGET", ctx)
	# Assert
	assert_true(ctx.cancelled,
			"Second attack should be cancelled by Coolant Discharge pipeline")


func test_attack_validate_pipeline_depowered_armament_blocks_long() -> void:
	# Arrange
	var ship: ShipInstance = _make_ship()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("depowered_armament")
	DamageCardEffectFactory.register_effect(card, ship, reg)
	# Act — attack at long range.
	var ctx: EffectContext = EffectContext.new()
	ctx.attacker = ship
	ctx.range_band = "long"
	ctx = reg.resolve_hook(&"ATTACK_VALIDATE_TARGET", ctx)
	# Assert
	assert_true(ctx.cancelled,
			"Long-range attack should be cancelled by Depowered Armament")


func test_attack_validate_pipeline_disengaged_fire_blocks_obstructed() -> void:
	# Arrange
	var ship: ShipInstance = _make_ship()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("disengaged_fire_control")
	DamageCardEffectFactory.register_effect(card, ship, reg)
	# Act — obstructed attack.
	var ctx: EffectContext = EffectContext.new()
	ctx.attacker = ship
	ctx.set_meta_value("is_obstructed", true)
	ctx = reg.resolve_hook(&"ATTACK_VALIDATE_TARGET", ctx)
	# Assert
	assert_true(ctx.cancelled,
			"Obstructed attack should be cancelled by Disengaged Fire Control")


# ---------------------------------------------------------------------------
# Integration: REPAIR_VALIDATE_SHIELD pipeline
# ---------------------------------------------------------------------------


func test_repair_validate_pipeline_capacitor_has_no_legacy_bridge() -> void:
	var ship: ShipInstance = _make_ship()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("capacitor_failure")
	var effect: DamageCardEffect = DamageCardEffectFactory.register_effect(
			card, ship, reg)
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("target_zone_shields", 0)
	ctx = reg.resolve_hook(&"REPAIR_VALIDATE_SHIELD", ctx)
	assert_null(effect,
			"Capacitor Failure should not register a legacy repair hook.")
	assert_false(ctx.cancelled,
			"Legacy repair hook should not cancel after M12 migration.")


# ---------------------------------------------------------------------------
# Integration: STATUS_READY_TOKENS pipeline
# ---------------------------------------------------------------------------


func test_status_ready_pipeline_compartment_fire_has_no_legacy_bridge() -> void:
	# Arrange
	var ship: ShipInstance = _make_ship()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("compartment_fire")
	DamageCardEffectFactory.register_effect(card, ship, reg)
	# Act
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx = reg.resolve_hook(&"STATUS_READY_TOKENS", ctx)
	# Assert
	assert_false(ctx.cancelled,
			"Compartment Fire token readying is now blocked by RuleRegistry.")


# ---------------------------------------------------------------------------
# Integration: ON_COMMAND_TOKEN_GAIN pipeline
# ---------------------------------------------------------------------------


func test_token_gain_pipeline_life_support_blocks() -> void:
	# Arrange
	var ship: ShipInstance = _make_ship()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("life_support_failure")
	DamageCardEffectFactory.register_effect(card, ship, reg)
	# Act
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx = reg.resolve_hook(&"ON_COMMAND_TOKEN_GAIN", ctx)
	# Assert
	assert_true(ctx.cancelled,
			"Token gain should be blocked by Life Support Failure")


# ---------------------------------------------------------------------------
# Integration: MANEUVER_DETERMINE_YAWS pipeline
# ---------------------------------------------------------------------------


func test_yaw_pipeline_thrust_control_reduces_last() -> void:
	# Arrange
	var ship: ShipInstance = _make_ship()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("thrust_control_malfunction")
	DamageCardEffectFactory.register_effect(card, ship, reg)
	# Act — speed 3 with yaw_values [0, 1, 1].
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("yaw_values", [0, 1, 1])
	ctx = reg.resolve_hook(&"MANEUVER_DETERMINE_YAWS", ctx)
	# Assert
	var yaws: Array = ctx.get_meta_value("yaw_values") as Array
	assert_eq(int(yaws[2]), 0,
			"Last joint yaw should be reduced from 1 to 0")
	assert_eq(int(yaws[0]), 0,
			"First joint should be unaffected")


# ---------------------------------------------------------------------------
# Integration: AFTER_MANEUVER_EXECUTE pipeline
# ---------------------------------------------------------------------------


func test_after_maneuver_pipeline_ruptured_engine_damage() -> void:
	# Arrange
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("ruptured_engine")
	DamageCardEffectFactory.register_effect(card, ship, reg)
	# Act — speed 2.
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("ship_speed", 2)
	ctx.set_meta_value("damage_deck", deck)
	ctx.set_meta_value("did_overlap", false)
	ctx = reg.resolve_hook(&"AFTER_MANEUVER_EXECUTE", ctx)
	# Assert
	assert_true(ctx.get_meta_value("extra_damage_dealt", false),
			"Ruptured Engine should flag extra_damage_dealt at speed 2 via pipeline")


func test_after_maneuver_pipeline_damaged_controls_on_overlap() -> void:
	# Arrange
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("damaged_controls")
	DamageCardEffectFactory.register_effect(card, ship, reg)
	# Act — overlapped obstacle.
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("ship_speed", 1)
	ctx.set_meta_value("damage_deck", deck)
	ctx.set_meta_value("did_overlap", true)
	ctx = reg.resolve_hook(&"AFTER_MANEUVER_EXECUTE", ctx)
	# Assert
	assert_true(ctx.get_meta_value("extra_damage_dealt", false),
			"Damaged Controls should flag extra_damage_dealt on overlap via pipeline")


# ---------------------------------------------------------------------------
# Integration: ON_SPEED_CHANGE pipeline
# ---------------------------------------------------------------------------


func test_speed_change_pipeline_thruster_fissure_damage() -> void:
	# Arrange
	var ship: ShipInstance = _make_ship()
	var deck: DamageDeck = _make_deck()
	var reg: EffectRegistry = EffectRegistry.new()
	var card: DamageCard = _make_card("thruster_fissure")
	DamageCardEffectFactory.register_effect(card, ship, reg)
	# Act
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("ship", ship)
	ctx.set_meta_value("damage_deck", deck)
	ctx = reg.resolve_hook(&"ON_SPEED_CHANGE", ctx)
	# Assert
	assert_true(ctx.get_meta_value("extra_damage_dealt", false),
			"Thruster Fissure should flag extra_damage_dealt on speed change")
