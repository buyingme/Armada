## Tests for DamageResolver
##
## Covers: ship damage (shield absorption, redirect, brace, standard crit,
## contain blocking crit, destruction), squadron damage (hull only).
##
## Rules Reference: "Attack", Step 5; "Damage"; "Critical Effects".
## Requirements: ATK-S5-001–006.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _make_resolver() -> DamageResolver:
	return DamageResolver.new()


func _make_defense() -> DefenseTokenResolver:
	return DefenseTokenResolver.new()


func _make_pool_with_results(
		results: Array[Dictionary]) -> AttackDicePool:
	var pool: AttackDicePool = AttackDicePool.new()
	pool._rolled_results = results
	pool._is_rolled = true
	return pool


func _make_ship(hull: int = 5, front_shields: int = 3,
		left_shields: int = 2, right_shields: int = 2,
		rear_shields: int = 1) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = hull
	data.max_speed = 3
	data.command_value = 2
	data.shields = {
		"FRONT": front_shields, "LEFT": left_shields,
		"RIGHT": right_shields, "REAR": rear_shields,
	}
	data.defense_tokens = []
	data.navigation_chart = [[2], [1, 2], [0, 1, 2]]
	return ShipInstance.create_from_data("test_ship", data, 2, 0)


func _make_squadron(hull: int = 3) -> RefCounted:
	## Minimal squadron stand-in.
	var squad: RefCounted = RefCounted.new()
	squad.set_meta("current_hull", hull)
	return squad


## Create a HIT result die.
func _hit(color: Constants.DiceColor = Constants.DiceColor.RED) -> Dictionary:
	return {"color": color, "face": Constants.DiceFace.HIT, "removed": false}


## Create a CRITICAL result die.
func _crit(
		color: Constants.DiceColor = Constants.DiceColor.RED) -> Dictionary:
	return {"color": color, "face": Constants.DiceFace.CRITICAL,
			"removed": false}


## Create a BLANK result die.
func _blank(
		color: Constants.DiceColor = Constants.DiceColor.RED) -> Dictionary:
	return {"color": color, "face": Constants.DiceFace.BLANK,
			"removed": false}


## Create a HIT_HIT result die (double hit).
func _hit_hit(
		color: Constants.DiceColor = Constants.DiceColor.RED) -> Dictionary:
	return {"color": color, "face": Constants.DiceFace.HIT_HIT,
			"removed": false}


# ---------------------------------------------------------------------------
# Ship damage — basic (shields absorb)
# ---------------------------------------------------------------------------


func test_ship_damage_absorbed_by_shields() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	var ship: ShipInstance = _make_ship(5, 3)
	var results: Array[Dictionary] = [_hit(), _hit()] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	var result: DamageResolver.DamageResult = \
			resolver.resolve_ship_damage(
			pool, defense, ship, Constants.HullZone.FRONT)

	assert_eq(result.raw_damage, 2, "Raw damage should be 2")
	assert_eq(result.final_damage, 2, "Final damage should be 2 (no brace)")
	assert_eq(result.shields_lost_defending, 2,
			"Should lose 2 shields on FRONT")
	assert_eq(result.facedown_cards, 0,
			"No damage cards when shields absorb all")
	assert_false(result.destroyed, "Ship should not be destroyed")


func test_ship_damage_exceeds_shields() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	var ship: ShipInstance = _make_ship(5, 1)  # Only 1 front shield.
	var results: Array[Dictionary] = [
		_hit(), _hit(), _hit(),
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	var result: DamageResolver.DamageResult = \
			resolver.resolve_ship_damage(
			pool, defense, ship, Constants.HullZone.FRONT)

	assert_eq(result.shields_lost_defending, 1,
			"Only 1 shield to lose")
	assert_eq(result.facedown_cards, 2,
			"2 remaining points become facedown cards")


func test_ship_damage_zero_damage() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	var ship: ShipInstance = _make_ship()
	var results: Array[Dictionary] = [_blank()] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	var result: DamageResolver.DamageResult = \
			resolver.resolve_ship_damage(
			pool, defense, ship, Constants.HullZone.FRONT)

	assert_eq(result.raw_damage, 0, "Blank = 0 damage")
	assert_eq(result.final_damage, 0, "Final = 0")
	assert_eq(result.shields_lost_defending, 0, "No shields lost")
	assert_eq(result.facedown_cards, 0, "No cards dealt")


# ---------------------------------------------------------------------------
# Ship damage — Brace
# ---------------------------------------------------------------------------


func test_ship_damage_with_brace() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	defense.activate_brace()
	var ship: ShipInstance = _make_ship(5, 0)  # No shields.
	var results: Array[Dictionary] = [
		_hit(), _hit(), _hit(), _hit(), _hit(),
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	var result: DamageResolver.DamageResult = \
			resolver.resolve_ship_damage(
			pool, defense, ship, Constants.HullZone.FRONT)

	assert_eq(result.raw_damage, 5, "Raw damage = 5")
	assert_eq(result.final_damage, 3, "Braced: ceil(5/2) = 3")
	assert_eq(result.facedown_cards, 3,
			"3 facedown cards (no shields)")


# ---------------------------------------------------------------------------
# Ship damage — Redirect
# ---------------------------------------------------------------------------


func test_ship_damage_with_redirect() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	defense.activate_redirect(Constants.HullZone.LEFT, 2)
	var ship: ShipInstance = _make_ship(5, 1, 2)  # FRONT=1, LEFT=2.
	var results: Array[Dictionary] = [
		_hit(), _hit(), _hit(), _hit(),
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	var result: DamageResolver.DamageResult = \
			resolver.resolve_ship_damage(
			pool, defense, ship, Constants.HullZone.FRONT)

	# 4 damage: redirect absorbs up to 2 on LEFT shields, then 1 on FRONT,
	# 1 remaining → 1 facedown card.
	assert_eq(result.shields_lost_redirect, 2,
			"2 shields lost on redirect zone")
	assert_eq(result.shields_lost_defending, 1,
			"1 shield lost on defending zone")
	assert_eq(result.facedown_cards, 1, "1 remaining → 1 card")


# ---------------------------------------------------------------------------
# Ship damage — Standard Critical
# ---------------------------------------------------------------------------


func test_ship_damage_standard_crit_first_card_faceup() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	var ship: ShipInstance = _make_ship(5, 0)  # No shields.
	var results: Array[Dictionary] = [
		_crit(), _hit(), _hit(),
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	var result: DamageResolver.DamageResult = \
			resolver.resolve_ship_damage(
			pool, defense, ship, Constants.HullZone.FRONT)

	assert_true(result.standard_crit_triggered,
			"Standard crit should trigger (has critical + no contain)")
	# First card faceup, rest facedown.
	assert_eq(result.facedown_cards, 2,
			"2 facedown cards (3 total damage minus 1 faceup)")
	assert_eq(ship.faceup_damage.size(), 1,
			"Ship should have 1 faceup damage card")
	assert_eq(ship.facedown_damage.size(), 2,
			"Ship should have 2 facedown damage cards")


# ---------------------------------------------------------------------------
# Ship damage — Contain blocks standard crit
# ---------------------------------------------------------------------------


func test_ship_damage_contain_blocks_standard_crit() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	defense.activate_contain()
	var ship: ShipInstance = _make_ship(5, 0)  # No shields.
	var results: Array[Dictionary] = [
		_crit(), _hit(),
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	var result: DamageResolver.DamageResult = \
			resolver.resolve_ship_damage(
			pool, defense, ship, Constants.HullZone.FRONT)

	assert_false(result.standard_crit_triggered,
			"Contain should block standard crit")
	assert_eq(result.facedown_cards, 2,
			"All damage cards should be facedown")
	assert_eq(ship.faceup_damage.size(), 0,
			"No faceup cards with contain")


# ---------------------------------------------------------------------------
# Ship damage — HIT_HIT counts as 2
# ---------------------------------------------------------------------------


func test_ship_damage_hit_hit_counts_double() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	var ship: ShipInstance = _make_ship(5, 0)
	var results: Array[Dictionary] = [_hit_hit()] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	var result: DamageResolver.DamageResult = \
			resolver.resolve_ship_damage(
			pool, defense, ship, Constants.HullZone.FRONT)

	assert_eq(result.raw_damage, 2, "HIT_HIT = 2 damage")
	assert_eq(result.facedown_cards, 2, "2 facedown cards")


# ---------------------------------------------------------------------------
# Ship damage — Destruction
# ---------------------------------------------------------------------------


func test_ship_destroyed_when_damage_exceeds_hull() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	var ship: ShipInstance = _make_ship(3, 0)  # hull=3, no shields.
	var results: Array[Dictionary] = [
		_hit(), _hit(), _hit(),
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	var result: DamageResolver.DamageResult = \
			resolver.resolve_ship_damage(
			pool, defense, ship, Constants.HullZone.FRONT)

	assert_true(result.destroyed,
			"Ship should be destroyed (3 damage >= 3 hull)")


func test_ship_not_destroyed_when_damage_below_hull() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	var ship: ShipInstance = _make_ship(5, 0)  # hull=5.
	var results: Array[Dictionary] = [
		_hit(), _hit(),
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	var result: DamageResolver.DamageResult = \
			resolver.resolve_ship_damage(
			pool, defense, ship, Constants.HullZone.FRONT)

	assert_false(result.destroyed,
			"Ship should not be destroyed (2 damage < 5 hull)")


# ---------------------------------------------------------------------------
# Squadron damage
# ---------------------------------------------------------------------------


func test_squadron_damage_pool_calculation() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	var results: Array[Dictionary] = [
		_hit(), _hit(), _crit(),
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)
	# Squadron damage counts hits only, not crits.
	var raw_dmg: int = pool.calculate_squadron_damage()
	assert_eq(raw_dmg, 2,
			"Squadron damage should be 2 (2 hits, 1 crit ignored)")


func test_squadron_damage_basic() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	var results: Array[Dictionary] = [
		_hit(), _hit(),
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	# Squadron damage = hits only. Both are HIT → 2 damage.
	var raw_dmg: int = pool.calculate_squadron_damage()
	assert_eq(raw_dmg, 2, "Squadron should take 2 hit damage")


func test_squadron_damage_crit_ignored() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	var results: Array[Dictionary] = [
		_crit(), _hit(),
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	# CRITICAL alone does 0 to squadrons, HIT does 1.
	var raw_dmg: int = pool.calculate_squadron_damage()
	assert_eq(raw_dmg, 1, "Crits should not count for squadron damage")


func test_squadron_damage_hit_crit_counts_as_one() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.BLACK,
				"face": Constants.DiceFace.HIT_CRITICAL,
				"removed": false},
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	# HIT_CRITICAL = 1 hit + 1 crit, but squadron damage only counts hits.
	var raw_dmg: int = pool.calculate_squadron_damage()
	assert_eq(raw_dmg, 1,
			"HIT_CRITICAL should count as 1 for squadron damage")


# ---------------------------------------------------------------------------
# Ship damage — Brace + Redirect combined
# ---------------------------------------------------------------------------


func test_ship_damage_brace_and_redirect_combined() -> void:
	var resolver: DamageResolver = _make_resolver()
	var defense: DefenseTokenResolver = _make_defense()
	defense.activate_brace()
	defense.activate_redirect(Constants.HullZone.RIGHT, 2)
	var ship: ShipInstance = _make_ship(5, 1, 2, 2)  # FRONT=1, RIGHT=2.
	var results: Array[Dictionary] = [
		_hit(), _hit(), _hit(), _hit(), _hit(), _hit(),
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)

	var result: DamageResolver.DamageResult = \
			resolver.resolve_ship_damage(
			pool, defense, ship, Constants.HullZone.FRONT)

	# 6 raw → brace → ceil(6/2) = 3 final.
	# Redirect absorbs up to 2 on RIGHT shields → 2 shields lost redirect.
	# 1 remaining → FRONT has 1 shield → 1 shield lost defending.
	# 0 remaining → no cards.
	assert_eq(result.raw_damage, 6, "Raw = 6")
	assert_eq(result.final_damage, 3, "Braced = 3")
	assert_eq(result.shields_lost_redirect, 2, "2 redirect shields")
	assert_eq(result.shields_lost_defending, 1, "1 defending shield")
	assert_eq(result.facedown_cards, 0, "All absorbed by shields")
