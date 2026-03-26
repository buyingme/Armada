## Test: Dice — accuracy counting and critical detection.
##
## Unit tests for Dice.count_accuracy() and Dice.has_any_critical().
## Requirements: AE-ACC-001, AE-DMG-010.
extends GutTest


# =========================================================================
# count_accuracy
# =========================================================================

func test_count_accuracy_no_accuracy_returns_zero() -> void:
	# Arrange
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.CRITICAL},
	]
	# Act
	var count: int = Dice.count_accuracy(results)
	# Assert
	assert_eq(count, 0, "Pool with no accuracy should return 0")


func test_count_accuracy_one_accuracy() -> void:
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.ACCURACY},
	]
	assert_eq(Dice.count_accuracy(results), 1,
			"Pool with 1 accuracy should return 1")


func test_count_accuracy_multiple_accuracy() -> void:
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.ACCURACY},
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.ACCURACY},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.HIT},
	]
	assert_eq(Dice.count_accuracy(results), 2,
			"Pool with 2 accuracy should return 2")


func test_count_accuracy_empty_pool() -> void:
	var results: Array[Dictionary] = []
	assert_eq(Dice.count_accuracy(results), 0,
			"Empty pool should return 0")


func test_count_accuracy_all_accuracy() -> void:
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.ACCURACY},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.ACCURACY},
	]
	assert_eq(Dice.count_accuracy(results), 2,
			"All-accuracy pool should return correct count")


# =========================================================================
# has_any_critical
# =========================================================================

func test_has_any_critical_with_crit_returns_true() -> void:
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.CRITICAL},
	]
	assert_true(Dice.has_any_critical(results),
			"Pool with CRITICAL should return true")


func test_has_any_critical_with_hit_crit_returns_true() -> void:
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.BLACK, "face": Constants.DiceFace.HIT_CRITICAL},
	]
	assert_true(Dice.has_any_critical(results),
			"Pool with HIT_CRITICAL should return true")


func test_has_any_critical_no_crit_returns_false() -> void:
	var results: Array[Dictionary] = [
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.HIT},
		{"color": Constants.DiceColor.BLUE, "face": Constants.DiceFace.ACCURACY},
		{"color": Constants.DiceColor.RED, "face": Constants.DiceFace.BLANK},
	]
	assert_false(Dice.has_any_critical(results),
			"Pool without critical should return false")


func test_has_any_critical_empty_pool_returns_false() -> void:
	var results: Array[Dictionary] = []
	assert_false(Dice.has_any_critical(results),
			"Empty pool should return false")
