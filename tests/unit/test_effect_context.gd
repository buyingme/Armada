## Test: EffectContext
##
## Unit tests for the EffectContext mutable data bag.
## Rules Reference: "Effect Use and Timing", RRG p.5; ET-001–004.
extends GutTest


# --- Default State ---

func test_default_hook_is_empty() -> void:
	var ctx: EffectContext = EffectContext.new()
	assert_eq(ctx.hook, &"",
			"Hook should default to empty StringName")


func test_default_damage_total_is_zero() -> void:
	var ctx: EffectContext = EffectContext.new()
	assert_eq(ctx.damage_total, 0,
			"Damage total should default to 0")


func test_default_critical_allowed_is_true() -> void:
	var ctx: EffectContext = EffectContext.new()
	assert_true(ctx.critical_allowed,
			"Critical should be allowed by default")


func test_default_can_move_is_true() -> void:
	var ctx: EffectContext = EffectContext.new()
	assert_true(ctx.can_move,
			"Squadron should be able to move by default")


func test_default_cancelled_is_false() -> void:
	var ctx: EffectContext = EffectContext.new()
	assert_false(ctx.cancelled,
			"Cancelled should be false by default")


func test_default_must_attack_engaged_is_false() -> void:
	var ctx: EffectContext = EffectContext.new()
	assert_false(ctx.must_attack_engaged,
			"must_attack_engaged should default to false")


# --- Metadata ---

func test_set_meta_value_stores_value() -> void:
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("swarm_eligible", true)
	assert_true(ctx.metadata.has("swarm_eligible"),
			"Metadata key should exist after set_meta_value")


func test_get_meta_value_returns_stored() -> void:
	var ctx: EffectContext = EffectContext.new()
	ctx.set_meta_value("redirect_max", 3)
	assert_eq(ctx.get_meta_value("redirect_max"), 3,
			"get_meta_value should return the stored value")


func test_get_meta_value_returns_default_when_missing() -> void:
	var ctx: EffectContext = EffectContext.new()
	assert_eq(ctx.get_meta_value("nonexistent", 42), 42,
			"get_meta_value should return default for missing keys")


func test_get_meta_value_returns_null_default() -> void:
	var ctx: EffectContext = EffectContext.new()
	assert_null(ctx.get_meta_value("nope"),
			"get_meta_value should return null when no default given")


# --- Mutation ---

func test_damage_total_can_be_mutated() -> void:
	var ctx: EffectContext = EffectContext.new()
	ctx.damage_total = 5
	assert_eq(ctx.damage_total, 5,
			"damage_total should be mutable")


func test_cancelled_can_be_set_true() -> void:
	var ctx: EffectContext = EffectContext.new()
	ctx.cancelled = true
	assert_true(ctx.cancelled,
			"cancelled should be settable to true")


func test_dice_results_can_be_populated() -> void:
	var ctx: EffectContext = EffectContext.new()
	ctx.dice_results.append({"color": Constants.DiceColor.RED,
			"face": Constants.DiceFace.HIT})
	assert_eq(ctx.dice_results.size(), 1,
			"dice_results should accept appended entries")
