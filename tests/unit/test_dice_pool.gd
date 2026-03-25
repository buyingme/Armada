## Unit tests for DicePool.
##
## Verifies dice pool gathering, range filtering, formatting, and edge cases.
extends GutTest


# ── get_attack_pool — range filtering ────────────────────────────────

func test_get_attack_pool_close_returns_all_colours() -> void:
	# Arrange
	var armament: Dictionary = {"RED": 2, "BLUE": 1, "BLACK": 1}
	# Act
	var pool: Dictionary = DicePool.get_attack_pool(
			armament, Constants.RANGE_BAND_CLOSE)
	# Assert
	assert_eq(pool.get("RED", 0), 2, "Red dice at close range")
	assert_eq(pool.get("BLUE", 0), 1, "Blue dice at close range")
	assert_eq(pool.get("BLACK", 0), 1, "Black dice at close range")


func test_get_attack_pool_medium_excludes_black() -> void:
	# Arrange
	var armament: Dictionary = {"RED": 2, "BLUE": 1, "BLACK": 1}
	# Act
	var pool: Dictionary = DicePool.get_attack_pool(
			armament, Constants.RANGE_BAND_MEDIUM)
	# Assert
	assert_eq(pool.get("RED", 0), 2, "Red dice at medium range")
	assert_eq(pool.get("BLUE", 0), 1, "Blue dice at medium range")
	assert_false(pool.has("BLACK"), "Black dice excluded at medium range")


func test_get_attack_pool_long_excludes_blue_and_black() -> void:
	# Arrange
	var armament: Dictionary = {"RED": 2, "BLUE": 1, "BLACK": 1}
	# Act
	var pool: Dictionary = DicePool.get_attack_pool(
			armament, Constants.RANGE_BAND_LONG)
	# Assert
	assert_eq(pool.get("RED", 0), 2, "Red dice at long range")
	assert_false(pool.has("BLUE"), "Blue dice excluded at long range")
	assert_false(pool.has("BLACK"), "Black dice excluded at long range")


func test_get_attack_pool_beyond_returns_empty() -> void:
	# Arrange
	var armament: Dictionary = {"RED": 2, "BLUE": 1, "BLACK": 1}
	# Act
	var pool: Dictionary = DicePool.get_attack_pool(
			armament, Constants.RANGE_BAND_BEYOND)
	# Assert
	assert_true(pool.is_empty(), "No dice at beyond range")


func test_get_attack_pool_empty_armament_returns_empty() -> void:
	# Arrange / Act
	var pool: Dictionary = DicePool.get_attack_pool(
			{}, Constants.RANGE_BAND_CLOSE)
	# Assert
	assert_true(pool.is_empty(), "Empty armament yields empty pool")


func test_get_attack_pool_omits_zero_count_colours() -> void:
	# Arrange — armament has only red dice.
	var armament: Dictionary = {"RED": 3}
	# Act
	var pool: Dictionary = DicePool.get_attack_pool(
			armament, Constants.RANGE_BAND_CLOSE)
	# Assert
	assert_eq(pool.size(), 1, "Only one colour in pool")
	assert_eq(pool.get("RED", 0), 3, "Red count correct")


func test_get_attack_pool_blue_only_at_close() -> void:
	# Arrange — only blue dice (e.g. anti-squadron armament).
	var armament: Dictionary = {"BLUE": 2}
	# Act
	var pool: Dictionary = DicePool.get_attack_pool(
			armament, Constants.RANGE_BAND_CLOSE)
	# Assert
	assert_eq(pool.get("BLUE", 0), 2, "Blue dice at close range")


func test_get_attack_pool_blue_only_at_long_returns_empty() -> void:
	# Arrange
	var armament: Dictionary = {"BLUE": 2}
	# Act
	var pool: Dictionary = DicePool.get_attack_pool(
			armament, Constants.RANGE_BAND_LONG)
	# Assert
	assert_true(pool.is_empty(), "Blue dice excluded at long range")


func test_get_attack_pool_black_only_at_medium_returns_empty() -> void:
	# Arrange
	var armament: Dictionary = {"BLACK": 2}
	# Act
	var pool: Dictionary = DicePool.get_attack_pool(
			armament, Constants.RANGE_BAND_MEDIUM)
	# Assert
	assert_true(pool.is_empty(), "Black dice excluded at medium range")


# ── get_total_count ──────────────────────────────────────────────────

func test_get_total_count_sums_all_colours() -> void:
	# Arrange
	var pool: Dictionary = {"RED": 2, "BLUE": 1, "BLACK": 3}
	# Act / Assert
	assert_eq(DicePool.get_total_count(pool), 6,
			"Total count is 2 + 1 + 3 = 6")


func test_get_total_count_empty_pool_returns_zero() -> void:
	# Arrange / Act / Assert
	assert_eq(DicePool.get_total_count({}), 0,
			"Empty pool has zero dice")


func test_get_total_count_single_colour() -> void:
	# Arrange / Act / Assert
	assert_eq(DicePool.get_total_count({"RED": 4}), 4,
			"Single colour count is correct")


# ── format_pool ──────────────────────────────────────────────────────

func test_format_pool_all_colours() -> void:
	# Arrange
	var pool: Dictionary = {"RED": 2, "BLUE": 1, "BLACK": 1}
	# Act / Assert
	assert_eq(DicePool.format_pool(pool), "2 red, 1 blue, 1 black",
			"All three colours formatted in order")


func test_format_pool_single_colour() -> void:
	# Arrange / Act / Assert
	assert_eq(DicePool.format_pool({"BLUE": 3}), "3 blue",
			"Single colour formatted correctly")


func test_format_pool_empty_returns_zero_dice() -> void:
	# Arrange / Act / Assert
	assert_eq(DicePool.format_pool({}), "0 dice",
			"Empty pool shows '0 dice'")


func test_format_pool_red_and_black_only() -> void:
	# Arrange — no blue.
	var pool: Dictionary = {"RED": 1, "BLACK": 2}
	# Act / Assert
	assert_eq(DicePool.format_pool(pool), "1 red, 2 black",
			"Red and black formatted without blue gap")


# ── format_attack_pool (convenience) ─────────────────────────────────

func test_format_attack_pool_close_shows_all() -> void:
	# Arrange — CR90 front armament.
	var armament: Dictionary = {"RED": 2, "BLUE": 1}
	# Act / Assert
	assert_eq(DicePool.format_attack_pool(armament, Constants.RANGE_BAND_CLOSE),
			"2 red, 1 blue",
			"Close range includes both colours")


func test_format_attack_pool_long_shows_red_only() -> void:
	# Arrange — CR90 front armament.
	var armament: Dictionary = {"RED": 2, "BLUE": 1}
	# Act / Assert
	assert_eq(DicePool.format_attack_pool(armament, Constants.RANGE_BAND_LONG),
			"2 red",
			"Long range includes only red")


func test_format_attack_pool_beyond_shows_zero() -> void:
	# Arrange
	var armament: Dictionary = {"RED": 2, "BLUE": 1, "BLACK": 1}
	# Act / Assert
	assert_eq(DicePool.format_attack_pool(
			armament, Constants.RANGE_BAND_BEYOND),
			"0 dice",
			"Beyond range shows 0 dice")


# ── to_engine_pool — string-key → DiceColor conversion ──────────────

func test_to_engine_pool_converts_all_colours() -> void:
	# Arrange
	var pool: Dictionary = {"RED": 2, "BLUE": 1, "BLACK": 3}
	# Act
	var result: Dictionary = DicePool.to_engine_pool(pool)
	# Assert
	assert_eq(result.get(Constants.DiceColor.RED, 0), 2,
			"RED → DiceColor.RED with count 2")
	assert_eq(result.get(Constants.DiceColor.BLUE, 0), 1,
			"BLUE → DiceColor.BLUE with count 1")
	assert_eq(result.get(Constants.DiceColor.BLACK, 0), 3,
			"BLACK → DiceColor.BLACK with count 3")


func test_to_engine_pool_omits_zero_count() -> void:
	# Arrange
	var pool: Dictionary = {"RED": 0, "BLUE": 2}
	# Act
	var result: Dictionary = DicePool.to_engine_pool(pool)
	# Assert
	assert_false(result.has(Constants.DiceColor.RED),
			"Zero-count colour should be omitted")
	assert_eq(result.get(Constants.DiceColor.BLUE, 0), 2,
			"Non-zero colour should be present")


func test_to_engine_pool_empty_returns_empty() -> void:
	# Arrange / Act
	var result: Dictionary = DicePool.to_engine_pool({})
	# Assert
	assert_true(result.is_empty(),
			"Empty pool should return empty dict")


func test_to_engine_pool_single_colour() -> void:
	# Arrange
	var pool: Dictionary = {"BLACK": 4}
	# Act
	var result: Dictionary = DicePool.to_engine_pool(pool)
	# Assert
	assert_eq(result.size(), 1, "Only one colour in result")
	assert_eq(result.get(Constants.DiceColor.BLACK, 0), 4,
			"BLACK count should be 4")
