## Tests for DefenseTokenResolver
##
## Covers: evade (long/medium/close), brace, scatter, redirect, contain,
## token locking, token spending (ready→exhausted→discarded), speed-0 check.
##
## Rules Reference: "Defense Tokens", pp. 4–5; "Attack", Step 4.
## Requirements: ATK-S4-001–009.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _make_resolver() -> DefenseTokenResolver:
	return DefenseTokenResolver.new()


func _make_pool_with_results(
		results: Array[Dictionary]) -> AttackDicePool:
	var pool: AttackDicePool = AttackDicePool.new()
	pool._rolled_results = results
	pool._is_rolled = true
	return pool


func _make_ship_with_tokens(
		token_types: Array[int]) -> ShipInstance:
	var data: ShipData = ShipData.new()
	data.hull = 5
	data.max_speed = 3
	data.command_value = 2
	data.shields = {"front": 3, "left": 2, "right": 2, "rear": 1}
	var token_defs: Array[String] = []
	for t: int in token_types:
		token_defs.append(Constants.DefenseToken.keys()[t])
	data.defense_tokens = token_defs
	data.navigation_chart = [[2], [1, 2], [0, 1, 2]]
	return ShipInstance.create_from_data("test_ship", data, 2, 0)


# ---------------------------------------------------------------------------
# reset
# ---------------------------------------------------------------------------


func test_reset_clears_state() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	resolver.brace_active = true
	resolver.contain_active = true
	resolver.redirect_zone = 1
	resolver.accuracy_locked_indices = [0, 2]
	resolver.reset()
	assert_false(resolver.brace_active, "Brace should be false after reset")
	assert_false(resolver.contain_active, "Contain should be false")
	assert_eq(resolver.redirect_zone, -1, "Redirect zone should be -1")
	assert_eq(resolver.accuracy_locked_indices.size(), 0,
			"Locked indices should be empty")


# ---------------------------------------------------------------------------
# lock_token
# ---------------------------------------------------------------------------


func test_lock_token_adds_index() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	resolver.lock_token(2)
	assert_true(2 in resolver.accuracy_locked_indices,
			"Index 2 should be locked")


func test_lock_token_no_duplicates() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	resolver.lock_token(1)
	resolver.lock_token(1)
	assert_eq(resolver.accuracy_locked_indices.size(), 1,
			"Should not duplicate locked index")


func test_is_token_locked() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	resolver.lock_token(3)
	assert_true(resolver.is_token_locked(3),
			"Token 3 should be locked")
	assert_false(resolver.is_token_locked(0),
			"Token 0 should not be locked")


# ---------------------------------------------------------------------------
# Evade — long range (cancel 1 die)
# ---------------------------------------------------------------------------


func test_evade_long_range_cancels_die() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.HIT},
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)
	var before_size: int = pool._rolled_results.size()
	resolver.resolve_evade(pool, "long", 0)
	assert_eq(pool._rolled_results.size(), before_size - 1,
			"Die at index 0 should be removed at long range")


# ---------------------------------------------------------------------------
# Evade — medium & close (reroll 1 die)
# ---------------------------------------------------------------------------


func test_evade_medium_range_rerolls_die() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT,
				"removed": false},
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)
	resolver.resolve_evade(pool, "medium", 0)
	# After resolve_evade, die 0 should still exist (rerolled, not removed).
	assert_false(pool._rolled_results[0].get("removed", false),
			"Die should not be removed at medium range (only rerolled)")


func test_evade_close_range_rerolls_die() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)
	var before_size: int = pool._rolled_results.size()
	resolver.resolve_evade(pool, "close", 0)
	assert_eq(pool._rolled_results.size(), before_size,
			"Die should not be removed at close range (only rerolled)")


# ---------------------------------------------------------------------------
# Brace
# ---------------------------------------------------------------------------


func test_activate_brace_sets_flag() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	resolver.activate_brace()
	assert_true(resolver.brace_active,
			"Brace should be active")


func test_apply_brace_halves_damage_rounded_up() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	resolver.activate_brace()
	assert_eq(resolver.apply_brace(5), 3,
			"5 / 2 rounded up = 3")
	assert_eq(resolver.apply_brace(4), 2,
			"4 / 2 = 2")
	assert_eq(resolver.apply_brace(1), 1,
			"1 / 2 rounded up = 1")
	assert_eq(resolver.apply_brace(0), 0,
			"0 / 2 = 0")


# ---------------------------------------------------------------------------
# Scatter
# ---------------------------------------------------------------------------


func test_scatter_cancels_all_dice() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.CRITICAL},
	] as Array[Dictionary]
	var pool: AttackDicePool = _make_pool_with_results(results)
	resolver.resolve_scatter(pool)
	assert_eq(pool.calculate_ship_damage(), 0,
			"All damage should be 0 after scatter")


# ---------------------------------------------------------------------------
# Redirect
# ---------------------------------------------------------------------------


func test_activate_redirect_sets_zone() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	resolver.activate_redirect(Constants.HullZone.LEFT, 2)
	assert_eq(resolver.redirect_zone, int(Constants.HullZone.LEFT),
			"Redirect zone should be LEFT")
	assert_eq(resolver.redirect_max_shields, 2,
			"Max redirect shields should be 2")


# ---------------------------------------------------------------------------
# Contain
# ---------------------------------------------------------------------------


func test_activate_contain_sets_flag() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	resolver.activate_contain()
	assert_true(resolver.contain_active,
			"Contain should be active")


# ---------------------------------------------------------------------------
# Speed-0 check
# ---------------------------------------------------------------------------


func test_can_spend_tokens_at_speed_0_returns_false() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	assert_false(resolver.can_defender_spend_tokens(0),
			"Speed 0 should not be able to spend tokens")


func test_can_spend_tokens_at_speed_1_returns_true() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	assert_true(resolver.can_defender_spend_tokens(1),
			"Speed 1 should be able to spend tokens")


# ---------------------------------------------------------------------------
# get_spendable_tokens
# ---------------------------------------------------------------------------


func test_get_spendable_tokens_excludes_locked() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	resolver.lock_token(0)
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.READY},
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	] as Array[Dictionary]
	var spendable: Array[int] = resolver.get_spendable_tokens(tokens, 2)
	assert_false(0 in spendable, "Locked token should not be spendable")
	assert_true(1 in spendable, "Unlocked token should be spendable")


func test_get_spendable_tokens_excludes_discarded() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.EVADE,
				"state": Constants.DefenseTokenState.DISCARDED},
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	] as Array[Dictionary]
	var spendable: Array[int] = resolver.get_spendable_tokens(tokens, 2)
	assert_false(0 in spendable, "Discarded token should not be spendable")
	assert_true(1 in spendable, "Ready token should be spendable")


func test_get_spendable_tokens_speed_0_returns_empty() -> void:
	var resolver: DefenseTokenResolver = _make_resolver()
	var tokens: Array[Dictionary] = [
		{"type": Constants.DefenseToken.BRACE,
				"state": Constants.DefenseTokenState.READY},
	] as Array[Dictionary]
	var spendable: Array[int] = resolver.get_spendable_tokens(tokens, 0)
	assert_eq(spendable.size(), 0,
			"Speed 0 should have no spendable tokens")


# ---------------------------------------------------------------------------
# spend_token — ready → exhausted, exhausted → discarded
# ---------------------------------------------------------------------------


func test_spend_ready_token_becomes_exhausted() -> void:
	var ship: ShipInstance = _make_ship_with_tokens(
			[Constants.DefenseToken.BRACE])
	assert_eq(ship.defense_tokens[0]["state"],
			Constants.DefenseTokenState.READY,
			"Token should start READY")
	DefenseTokenResolver.spend_token(ship, 0)
	assert_eq(ship.defense_tokens[0]["state"],
			Constants.DefenseTokenState.EXHAUSTED,
			"Token should be EXHAUSTED after spending")


func test_spend_exhausted_token_becomes_discarded() -> void:
	var ship: ShipInstance = _make_ship_with_tokens(
			[Constants.DefenseToken.BRACE])
	ship.defense_tokens[0]["state"] = Constants.DefenseTokenState.EXHAUSTED
	DefenseTokenResolver.spend_token(ship, 0)
	assert_eq(ship.defense_tokens[0]["state"],
			Constants.DefenseTokenState.DISCARDED,
			"Exhausted token should be DISCARDED after spending")
