## Test: Bomber Keyword Rule
##
## Verifies the Phase N10 RuleRegistry damage modifier for the Bomber
## squadron keyword.
extends GutTest


var _resolver: AttackDiceResolver = null


func before_each() -> void:
	RuleRegistry.clear()
	BomberKeyword.register()
	_resolver = AttackDiceResolver.new()


func after_each() -> void:
	RuleRegistry.clear()


func test_register_adds_attack_damage_modifier() -> void:
	var modifiers: Array[FlowHook] = RuleRegistry.modifiers_for(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE,
			RuleSurface.TARGET_ATTACK_DAMAGE)
	assert_eq(modifiers.size(), 1,
			"Bomber should expose one attack-damage modifier.")
	assert_eq(RuleRegistry.registered_hook_count(), 1,
			"Bomber should register one hook.")


func test_modifier_counts_critical_icons_against_ship() -> void:
	var context: EffectContext = _damage_context(
			_make_squadron(["Bomber"]), _make_ship(), 1)
	var result: EffectContext = BomberKeyword.new().modify_attack_damage(context)
	assert_eq(result.damage_total, 2,
			"Bomber should count HIT plus CRITICAL as two damage against ships.")


func test_modifier_ignores_non_bomber_squadron() -> void:
	var context: EffectContext = _damage_context(
			_make_squadron([]), _make_ship(), 1)
	var result: EffectContext = BomberKeyword.new().modify_attack_damage(context)
	assert_eq(result.damage_total, 1,
			"Squadrons without Bomber should keep the base damage total.")


func test_modifier_ignores_squadron_defender() -> void:
	var context: EffectContext = _damage_context(
			_make_squadron(["Bomber"]), _make_squadron([]), 1)
	var result: EffectContext = BomberKeyword.new().modify_attack_damage(context)
	assert_eq(result.damage_total, 1,
			"Bomber should not count critical icons against squadrons.")


func test_attack_dice_resolver_uses_rule_without_legacy_registry() -> void:
	var attacker_token: SquadronToken = _make_squadron_token(["Bomber"])
	var defender_token: ShipToken = _make_ship_token(_make_ship())
	var parts: CombatParticipants = CombatParticipants.create(
			null, -1, attacker_token, defender_token,
			Constants.HullZone.FRONT, null)
	var damage: int = _resolver.calc_damage(_hit_critical_results(), parts, null)
	assert_eq(damage, 2,
			"AttackDiceResolver should apply Bomber from squadron data.")


func test_attack_dice_resolver_keeps_non_bomber_critical_at_zero() -> void:
	var attacker_token: SquadronToken = _make_squadron_token([])
	var defender_token: ShipToken = _make_ship_token(_make_ship())
	var parts: CombatParticipants = CombatParticipants.create(
			null, -1, attacker_token, defender_token,
			Constants.HullZone.FRONT, null)
	var damage: int = _resolver.calc_damage(_critical_only_results(), parts, null)
	assert_eq(damage, 0,
			"Non-Bomber squadron critical icons should not add ship damage.")


func _damage_context(attacker: SquadronInstance,
		defender: RefCounted,
		base_damage: int) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.attacker = attacker
	context.defender = defender
	context.damage_total = base_damage
	context.dice_results = _hit_critical_results()
	return context


func _hit_critical_results() -> Array[Dictionary]:
	return [
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.CRITICAL},
	]


func _critical_only_results() -> Array[Dictionary]:
	return [
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.CRITICAL},
	]


func _make_squadron(keywords: Array[String]) -> SquadronInstance:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "Test Squadron"
	data.hull = 3
	data.speed = 3
	data.keywords = _keyword_data(keywords)
	return SquadronInstance.create_from_data("test_squadron", data, 0)


func _make_ship() -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.ship_name = "Test Ship"
	data.hull = 5
	data.shields = {"FRONT": 3, "LEFT": 2, "RIGHT": 2, "REAR": 1}
	data.defense_tokens = []
	data.navigation_chart = [[1], [1, 1]]
	return ShipInstance.create_from_data("test_ship", data, 2, 1)


func _make_squadron_token(keywords: Array[String]) -> SquadronToken:
	var token: SquadronToken = SquadronToken.new()
	token._placement = TokenPlacement.new("test_squadron", false,
			Constants.Faction.REBEL_ALLIANCE, 0.5, 0.5, 0.0)
	token._radius_px = 20.0
	token._squadron_instance = _make_squadron(keywords)
	add_child_autofree(token)
	return token


func _make_ship_token(instance: ShipInstance) -> ShipToken:
	var token: ShipToken = ShipToken.new()
	token._placement = TokenPlacement.new("test_ship", true,
			Constants.Faction.GALACTIC_EMPIRE, 0.5, 0.5, 0.0,
			Constants.ShipSize.SMALL)
	token._half_w = 30.0
	token._half_l = 50.0
	token._ship_data = instance.ship_data
	token._ship_instance = instance
	add_child_autofree(token)
	return token


func _keyword_data(keywords: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for keyword_name: String in keywords:
		result.append({"name": keyword_name})
	return result