## Test: SquadronKeywordRuleHelper
##
## Unit tests for the Phase N17 squadron keyword predicate and payload
## foundation. These tests intentionally do not wire gameplay behaviour.
extends GutTest


func test_has_keyword_case_insensitive_returns_true() -> void:
	# Arrange
	var squadron: SquadronInstance = _make_squadron(0, [_keyword("heavy")])

	# Act / Assert
	assert_true(SquadronKeywordRuleHelper.has_keyword(squadron, "Heavy"),
			"Keyword lookup should be case-insensitive for source data.")
	assert_false(SquadronKeywordRuleHelper.has_keyword(squadron, "Escort"),
			"Unlisted keywords should not be reported as active.")


func test_get_keyword_value_counter_returns_numeric_value() -> void:
	# Arrange
	var squadron: SquadronInstance = _make_squadron(0, [
		_keyword("Counter", 2),
		_keyword("Bomber"),
	])

	# Act / Assert
	assert_eq(SquadronKeywordRuleHelper.get_keyword_value(squadron, "counter"), 2,
			"Counter X should expose its numeric value.")
	assert_eq(SquadronKeywordRuleHelper.get_keyword_value(squadron, "Bomber"), 0,
			"Valueless keywords should report zero.")
	assert_eq(SquadronKeywordRuleHelper.get_keyword_value(squadron, "Swarm"), 0,
			"Missing keywords should report zero.")


func test_attack_kind_payload_missing_or_unknown_defaults_standard() -> void:
	# Arrange
	var missing_payload: Dictionary = {}
	var unknown_payload: Dictionary = {
		SquadronKeywordRuleHelper.PAYLOAD_ATTACK_KIND: "snipe",
	}

	# Act / Assert
	assert_eq(SquadronKeywordRuleHelper.attack_kind_from_payload(missing_payload),
			SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
			"Missing attack kind should default to standard.")
	assert_eq(SquadronKeywordRuleHelper.attack_kind_from_payload(unknown_payload),
			SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
			"Unknown attack kind should remain conservative and standard.")


func test_attack_kind_context_counter_detected() -> void:
	# Arrange
	var context: EffectContext = EffectContext.new()
	context.metadata = SquadronKeywordRuleHelper.make_attack_kind_payload(
			SquadronKeywordRuleHelper.ATTACK_KIND_COUNTER)

	# Act / Assert
	assert_true(SquadronKeywordRuleHelper.is_counter_attack_context(context),
			"Counter metadata on EffectContext should identify Counter attacks.")
	assert_false(SquadronKeywordRuleHelper.is_counter_attack_payload({}),
			"Empty flow payloads should describe standard attacks.")


func test_is_engaged_by_non_heavy_ignores_heavy_only_engagement() -> void:
	# Arrange
	var attacker: SquadronInstance = _make_squadron(0, [])
	var heavy_enemy: SquadronInstance = _make_squadron(1, [_keyword("Heavy")])
	var all_squadrons: Array[Dictionary] = [
		_entry(attacker, Vector2.ZERO),
		_entry(heavy_enemy, _close_pos()),
	]

	# Act / Assert
	assert_true(EngagementResolver.is_engaged(attacker, Vector2.ZERO, all_squadrons),
			"Base engagement should still see the Heavy enemy.")
	assert_false(SquadronKeywordRuleHelper.is_engaged_by_non_heavy(
			attacker, Vector2.ZERO, all_squadrons),
			"Heavy enemies should not count as non-Heavy engagement.")


func test_non_heavy_engaged_enemies_finds_mixed_non_heavy_enemy() -> void:
	# Arrange
	var attacker: SquadronInstance = _make_squadron(0, [])
	var heavy_enemy: SquadronInstance = _make_squadron(1, [_keyword("Heavy")])
	var escort_enemy: SquadronInstance = _make_squadron(1, [_keyword("Escort")])
	var all_squadrons: Array[Dictionary] = [
		_entry(attacker, Vector2.ZERO),
		_entry(heavy_enemy, _close_pos()),
		_entry(escort_enemy, _close_pos() + Vector2(0.0, 1.0)),
	]

	# Act
	var result: Array[SquadronInstance] = \
			SquadronKeywordRuleHelper.non_heavy_engaged_enemies(
					attacker, Vector2.ZERO, all_squadrons)

	# Assert
	assert_eq(result.size(), 1,
			"Only non-Heavy engaged enemies should remain.")
	assert_same(result[0], escort_enemy,
			"Escort enemy should count as non-Heavy engagement.")


func test_is_engaged_by_non_heavy_false_when_enemy_obstructed() -> void:
	# Arrange
	var attacker: SquadronInstance = _make_squadron(0, [])
	var enemy: SquadronInstance = _make_squadron(1, [])
	var enemy_pos: Vector2 = _close_pos()
	var all_squadrons: Array[Dictionary] = [
		_entry(attacker, Vector2.ZERO),
		_entry(enemy, enemy_pos),
	]

	# Act / Assert
	assert_false(SquadronKeywordRuleHelper.is_engaged_by_non_heavy(
			attacker, Vector2.ZERO, all_squadrons,
			_obstruction_between(Vector2.ZERO, enemy_pos)),
			"Obstructed non-Heavy enemies should not create engagement.")


func test_is_engaged_with_target_checks_specific_defender() -> void:
	# Arrange
	var attacker: SquadronInstance = _make_squadron(0, [])
	var close_enemy: SquadronInstance = _make_squadron(1, [])
	var far_enemy: SquadronInstance = _make_squadron(1, [])
	var all_squadrons: Array[Dictionary] = [
		_entry(attacker, Vector2.ZERO),
		_entry(close_enemy, _close_pos()),
		_entry(far_enemy, _far_pos()),
	]

	# Act / Assert
	assert_true(EngagementResolver.is_engaged(attacker, Vector2.ZERO, all_squadrons),
			"The attacker should be engaged by some enemy.")
	assert_false(SquadronKeywordRuleHelper.is_engaged_with_target(
			attacker, Vector2.ZERO, far_enemy, _far_pos()),
			"A far selected defender should not count as engaged with attacker.")
	assert_true(SquadronKeywordRuleHelper.is_engaged_with_target(
			attacker, Vector2.ZERO, close_enemy, _close_pos()),
			"A close selected defender should count as engaged with attacker.")


func test_make_target_legality_payload_returns_json_safe_fields() -> void:
	# Arrange
	var rule_ids: Array[String] = ["squadron_keyword.escort"]

	# Act
	var payload: Dictionary = SquadronKeywordRuleHelper.make_target_legality_payload(
			3, true, "Escort blocks this target.", rule_ids)

	# Assert
	assert_eq(payload.get(SquadronKeywordRuleHelper.PAYLOAD_TARGET_INDEX, -1), 3,
			"Payload should carry target index as an int.")
	assert_true(bool(payload.get(SquadronKeywordRuleHelper.PAYLOAD_BLOCKED, false)),
			"Payload should carry blocked state as a bool.")
	assert_eq(payload.get(SquadronKeywordRuleHelper.PAYLOAD_RULE_IDS, []), rule_ids,
			"Payload should carry rule ids as strings.")


func test_make_optional_modifier_affordance_returns_json_safe_payload() -> void:
	# Arrange
	var dice_indices: Array[int] = [0, 2]

	# Act
	var payload: Dictionary = SquadronKeywordRuleHelper.make_optional_modifier_affordance(
			"squadron_keyword.swarm", 1, dice_indices, "Reroll 1 die")
	var affordances: Array = payload.get(
			SquadronKeywordRuleHelper.AFFORDANCE_ATTACK_MODIFIERS, []) as Array
	var affordance: Dictionary = affordances[0] as Dictionary

	# Assert
	assert_eq(affordance.get(SquadronKeywordRuleHelper.AFFORDANCE_RULE_ID, ""),
			"squadron_keyword.swarm",
			"Affordance should identify the source rule.")
	assert_eq(affordance.get(
			SquadronKeywordRuleHelper.AFFORDANCE_AVAILABLE_DIE_INDICES, []),
			dice_indices,
			"Affordance should carry selectable die indices.")
	assert_true(bool(affordance.get(
			SquadronKeywordRuleHelper.AFFORDANCE_OPTIONAL, false)),
			"Affordance should mark the rule as optional.")


func test_is_swarm_eligible_false_when_partner_obstructed() -> void:
	# Arrange
	var attacker: SquadronInstance = _make_squadron(0, [_keyword("Swarm")])
	var target: SquadronInstance = _make_squadron(1, [])
	var friendly: SquadronInstance = _make_squadron(0, [])
	var target_pos: Vector2 = _close_pos()
	var friendly_pos: Vector2 = target_pos + _close_pos()
	var all_squadrons: Array[Dictionary] = [
		_entry(attacker, Vector2.ZERO),
		_entry(target, target_pos),
		_entry(friendly, friendly_pos),
	]

	# Act / Assert
	assert_false(SquadronKeywordRuleHelper.is_swarm_eligible(
			attacker, Vector2.ZERO, target, target_pos, all_squadrons,
			_obstruction_between(target_pos, friendly_pos)),
			"Swarm should not be eligible through obstructed engagement.")


func _make_squadron(player: int,
		keywords: Array[Dictionary]) -> SquadronInstance:
	var data: SquadronData = SquadronData.new()
	data.squadron_name = "Test Squadron"
	data.hull = 3
	data.speed = 3
	data.keywords = keywords
	return SquadronInstance.create_from_data("test_squadron", data, player)


func _keyword(keyword_name: String, value: int = -1) -> Dictionary:
	var keyword: Dictionary = {"name": keyword_name}
	if value >= 0:
		keyword["value"] = value
	return keyword


func _entry(squadron: SquadronInstance, position: Vector2) -> Dictionary:
	return {"instance": squadron, "position": position}


func _close_pos() -> Vector2:
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var center_distance: float = \
			GameScale.distance_bands_px[0] + 2.0 * radius - 1.0
	return Vector2(center_distance, 0.0)


func _far_pos() -> Vector2:
	var radius: float = GameScale.squadron_base_diameter_px * 0.5
	var center_distance: float = \
			GameScale.distance_bands_px[0] + 2.0 * radius + 100.0
	return Vector2(center_distance, 0.0)


func _obstruction_between(pos_a: Vector2, pos_b: Vector2) -> Array:
	var mid_point: Vector2 = pos_a.lerp(pos_b, 0.5)
	return [LineOfSightChecker.ObstructionBody.from_ship_base(
			"Blocker", mid_point, 0.0, 40.0, 80.0)]
