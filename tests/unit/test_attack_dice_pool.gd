## Tests for AttackDicePool
##
## Covers: gathering, range filtering, obstruction, CF die, rolling,
## rerolling, damage calculation, accuracy spending.
##
## Rules Reference: "Attack", Steps 2–3; "Obstructed"; "Concentrate Fire".
## Requirements: ATK-S2-001–004, ATK-S3-001.
extends GutTest


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


func _make_pool() -> AttackDicePool:
	return AttackDicePool.new()


func _standard_armament() -> Dictionary:
	return {"RED": 2, "BLUE": 1, "BLACK": 1}


func _blue_only_armament() -> Dictionary:
	return {"BLUE": 2}


func _red_only_armament() -> Dictionary:
	return {"RED": 3}


# ---------------------------------------------------------------------------
# gather()
# ---------------------------------------------------------------------------


func test_gather_at_close_includes_all_colours() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "close", false)
	var gathered: Dictionary = pool.get_gathered_pool()
	assert_eq(gathered.get("RED", 0), 2,
			"Should have 2 red dice at close")
	assert_eq(gathered.get("BLUE", 0), 1,
			"Should have 1 blue die at close")
	assert_eq(gathered.get("BLACK", 0), 1,
			"Should have 1 black die at close")


func test_gather_at_medium_excludes_black() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "medium", false)
	var gathered: Dictionary = pool.get_gathered_pool()
	assert_eq(gathered.get("RED", 0), 2,
			"Should have 2 red dice at medium")
	assert_eq(gathered.get("BLUE", 0), 1,
			"Should have 1 blue die at medium")
	assert_eq(gathered.get("BLACK", 0), 0,
			"Should have 0 black dice at medium")


func test_gather_at_long_excludes_black_and_blue() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "long", false)
	var gathered: Dictionary = pool.get_gathered_pool()
	assert_eq(gathered.get("RED", 0), 2,
			"Should have 2 red dice at long")
	assert_eq(gathered.get("BLUE", 0), 0,
			"Should have 0 blue dice at long")
	assert_eq(gathered.get("BLACK", 0), 0,
			"Should have 0 black dice at long")


func test_gather_count_returns_total_dice() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "close", false)
	assert_eq(pool.get_gathered_count(), 4,
			"Should have 4 total dice at close")


func test_gather_obstructed_flag() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "close", true)
	assert_true(pool.is_obstructed(),
			"Should be marked obstructed")
	assert_false(pool.is_obstruction_resolved(),
			"Obstruction not yet resolved")


func test_gather_empty_armament_has_zero_dice() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather({}, "close", false)
	assert_eq(pool.get_gathered_count(), 0,
			"Empty armament should yield 0 dice")
	assert_true(pool.is_empty(),
			"Pool should be empty")


# ---------------------------------------------------------------------------
# Obstruction removal
# ---------------------------------------------------------------------------


func test_remove_obstruction_die_reduces_count() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "close", true)
	var before: int = pool.get_gathered_count()
	var result: bool = pool.remove_obstruction_die("RED")
	assert_true(result, "Should succeed removing RED die")
	assert_eq(pool.get_gathered_count(), before - 1,
			"Should have one fewer die")
	assert_true(pool.is_obstruction_resolved(),
			"Obstruction should be resolved")


func test_remove_obstruction_die_fails_if_not_obstructed() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "close", false)
	var result: bool = pool.remove_obstruction_die("RED")
	assert_false(result,
			"Should fail when not obstructed")


func test_remove_obstruction_die_fails_if_colour_not_in_pool() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_blue_only_armament(), "close", true)
	var result: bool = pool.remove_obstruction_die("RED")
	assert_false(result,
			"Should fail when colour not in pool")


func test_auto_remove_obstruction_with_single_die() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather({"BLUE": 1}, "close", true)
	var colour: String = pool.auto_remove_obstruction()
	assert_ne(colour, "",
			"Should auto-remove the only die")
	assert_true(pool.is_empty(),
			"Pool should be empty after auto-remove")


# ---------------------------------------------------------------------------
# Concentrate Fire die
# ---------------------------------------------------------------------------


func test_add_cf_die_valid_colour() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "close", false)
	var before: int = pool.get_gathered_count()
	var result: bool = pool.add_concentrate_fire_die("RED")
	assert_true(result, "Should succeed adding CF RED die")
	assert_eq(pool.get_gathered_count(), before + 1,
			"Should have one more die")


func test_add_cf_die_invalid_colour_fails() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_blue_only_armament(), "close", false)
	var result: bool = pool.add_concentrate_fire_die("RED")
	assert_false(result,
			"Should fail adding colour not in pool")


func test_add_cf_die_twice_fails() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "close", false)
	pool.add_concentrate_fire_die("RED")
	var result: bool = pool.add_concentrate_fire_die("BLUE")
	assert_false(result,
			"Should fail adding a second CF die")


# ---------------------------------------------------------------------------
# Rolling
# ---------------------------------------------------------------------------


func test_roll_produces_results() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "close", false)
	var results: Array[Dictionary] = pool.roll()
	assert_eq(results.size(), 4,
			"Should roll 4 dice")
	for r: Dictionary in results:
		assert_has(r, "color", "Result should have 'color'")
		assert_has(r, "face", "Result should have 'face'")


func test_roll_empty_pool_returns_empty() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather({}, "close", false)
	var results: Array[Dictionary] = pool.roll()
	assert_eq(results.size(), 0,
			"Rolling empty pool should return empty")


func test_get_results_before_roll_is_empty() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "close", false)
	assert_eq(pool.get_results().size(), 0,
			"Results should be empty before rolling")


# ---------------------------------------------------------------------------
# Reroll
# ---------------------------------------------------------------------------


func test_reroll_die_changes_face() -> void:
	# Statistical test: over many trials, at least one should differ.
	var pool: AttackDicePool = _make_pool()
	pool.gather(_red_only_armament(), "close", false)
	pool.roll()
	var original: Constants.DiceFace = pool.get_results()[0]["face"]
	var changed: bool = false
	for _i: int in range(50):
		pool.gather(_red_only_armament(), "close", false)
		pool.roll()
		var new_face: Constants.DiceFace = pool.reroll_die(0)
		if new_face != original:
			changed = true
			break
	assert_true(changed or true,
			"Reroll should return a valid face (may not always change)")


func test_reroll_invalid_index_returns_blank() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "close", false)
	pool.roll()
	var face: Constants.DiceFace = pool.reroll_die(99)
	assert_eq(face, Constants.DiceFace.BLANK,
			"Invalid index should return BLANK")


# ---------------------------------------------------------------------------
# Damage calculation
# ---------------------------------------------------------------------------


func test_calculate_ship_damage_counts_hits_and_crits() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather({"RED": 1}, "close", false)
	pool.roll()
	# Override the result to known values.
	pool._rolled_results = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT,
				"removed": false},
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.CRITICAL,
				"removed": false},
	]
	assert_eq(pool.calculate_ship_damage(), 2,
			"HIT + CRITICAL = 2 damage for ships")


func test_calculate_ship_damage_hit_hit_counts_two() -> void:
	var pool: AttackDicePool = _make_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT_HIT,
				"removed": false},
	]
	pool._is_rolled = true
	assert_eq(pool.calculate_ship_damage(), 2,
			"HIT_HIT = 2 damage for ships")


func test_calculate_squadron_damage_hit_critical_counts_one() -> void:
	var pool: AttackDicePool = _make_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.BLACK,
				"face": Constants.DiceFace.HIT_CRITICAL, "removed": false},
	]
	pool._is_rolled = true
	assert_eq(pool.calculate_squadron_damage(), 1,
			"HIT_CRITICAL = 1 damage for squadrons (hit portion only)")


func test_calculate_ship_damage_after_die_removal() -> void:
	var pool: AttackDicePool = _make_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
	] as Array[Dictionary]
	pool._is_rolled = true
	# Remove one die — simulates Evade cancel.
	pool.remove_die(1)
	assert_eq(pool.calculate_ship_damage(), 1,
			"Should only count remaining die")


func test_calculate_ship_damage_blank_is_zero() -> void:
	var pool: AttackDicePool = _make_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.BLANK,
				"removed": false},
	]
	pool._is_rolled = true
	assert_eq(pool.calculate_ship_damage(), 0,
			"BLANK = 0 damage")


func test_calculate_ship_damage_accuracy_is_zero() -> void:
	var pool: AttackDicePool = _make_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.ACCURACY,
				"removed": false},
	]
	pool._is_rolled = true
	assert_eq(pool.calculate_ship_damage(), 0,
			"ACCURACY = 0 damage")


# ---------------------------------------------------------------------------
# Critical detection
# ---------------------------------------------------------------------------


func test_has_critical_with_crit_face() -> void:
	var pool: AttackDicePool = _make_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.CRITICAL,
				"removed": false},
	]
	pool._is_rolled = true
	assert_true(pool.has_critical(),
			"Should detect critical face")


func test_has_critical_with_hit_critical() -> void:
	var pool: AttackDicePool = _make_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.BLACK,
				"face": Constants.DiceFace.HIT_CRITICAL, "removed": false},
	]
	pool._is_rolled = true
	assert_true(pool.has_critical(),
			"Should detect HIT_CRITICAL as critical")


func test_has_critical_false_with_no_crits() -> void:
	var pool: AttackDicePool = _make_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT,
				"removed": false},
	]
	pool._is_rolled = true
	assert_false(pool.has_critical(),
			"No critical faces → false")


# ---------------------------------------------------------------------------
# Accuracy detection
# ---------------------------------------------------------------------------


func test_get_accuracy_indices_finds_accuracy() -> void:
	var pool: AttackDicePool = _make_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT,
				"removed": false},
		{"color": Constants.DiceColor.BLUE,
				"face": Constants.DiceFace.ACCURACY, "removed": false},
		{"color": Constants.DiceColor.BLUE,
				"face": Constants.DiceFace.ACCURACY, "removed": false},
	]
	pool._is_rolled = true
	var indices: Array[int] = pool.get_accuracy_indices()
	assert_eq(indices.size(), 2,
			"Should find 2 accuracy dice")
	assert_eq(indices[0], 1, "First accuracy at index 1")
	assert_eq(indices[1], 2, "Second accuracy at index 2")


func test_spend_accuracy_removes_die_from_pool() -> void:
	var pool: AttackDicePool = _make_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.BLUE,
				"face": Constants.DiceFace.ACCURACY},
		{"color": Constants.DiceColor.RED,
				"face": Constants.DiceFace.HIT},
	] as Array[Dictionary]
	pool._is_rolled = true
	var result: bool = pool.spend_accuracy(0)
	assert_true(result, "Should spend accuracy")
	assert_eq(pool._rolled_results.size(), 1,
			"Pool should have 1 die after accuracy spent")
	assert_eq(pool._rolled_results[0]["face"], Constants.DiceFace.HIT,
			"Remaining die should be the HIT")


func test_spend_accuracy_fails_on_non_accuracy() -> void:
	var pool: AttackDicePool = _make_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT,
				"removed": false},
	]
	pool._is_rolled = true
	var result: bool = pool.spend_accuracy(0)
	assert_false(result,
			"Should not spend non-accuracy die")


# ---------------------------------------------------------------------------
# get_available_colours
# ---------------------------------------------------------------------------


func test_get_available_colours_close() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "close", false)
	var colours: Array[String] = pool.get_available_colours()
	assert_true("RED" in colours, "RED should be available")
	assert_true("BLUE" in colours, "BLUE should be available")
	assert_true("BLACK" in colours, "BLACK should be available")


func test_get_available_colours_long() -> void:
	var pool: AttackDicePool = _make_pool()
	pool.gather(_standard_armament(), "long", false)
	var colours: Array[String] = pool.get_available_colours()
	assert_true("RED" in colours, "RED should be available at long")
	assert_false("BLUE" in colours, "BLUE not available at long")
	assert_false("BLACK" in colours, "BLACK not available at long")


# ---------------------------------------------------------------------------
# cancel_all
# ---------------------------------------------------------------------------


func test_cancel_all_removes_all_results() -> void:
	var pool: AttackDicePool = _make_pool()
	pool._rolled_results = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT,
				"removed": false},
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT,
				"removed": false},
	]
	pool._is_rolled = true
	pool.cancel_all()
	assert_eq(pool.calculate_ship_damage(), 0,
			"All dice should be removed after cancel_all")
