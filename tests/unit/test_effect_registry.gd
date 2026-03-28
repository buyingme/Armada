## Test: GameEffect + EffectRegistry
##
## Unit tests for the effect system base classes.
## Rules Reference: "Effect Use and Timing", RRG p.5; ET-001–004.
extends GutTest


# ---------------------------------------------------------------------------
# Helper: concrete test effect
# ---------------------------------------------------------------------------

## A minimal concrete GameEffect used by tests.
class TestEffect extends GameEffect:
	var _hooks: Array[StringName] = []
	var _trigger: bool = true
	var resolve_count: int = 0

	func _init(hooks: Array[StringName] = [],
			trigger: bool = true) -> void:
		_hooks = hooks
		_trigger = trigger
		source_type = EffectSource.KEYWORD
		source_id = "test"

	func get_hooks() -> Array[StringName]:
		return _hooks

	func should_trigger(context: EffectContext) -> bool:
		if context == null:
			return false
		return _trigger

	func resolve(context: EffectContext) -> void:
		resolve_count += 1
		context.damage_total += 1


# ---------------------------------------------------------------------------
# GameEffect defaults
# ---------------------------------------------------------------------------

func test_game_effect_default_source_type() -> void:
	var e: GameEffect = GameEffect.new()
	assert_eq(e.source_type, GameEffect.EffectSource.KEYWORD,
			"Default source_type should be KEYWORD")


func test_game_effect_default_hooks_empty() -> void:
	var e: GameEffect = GameEffect.new()
	assert_eq(e.get_hooks().size(), 0,
			"Base get_hooks should return empty array")


func test_game_effect_default_should_trigger_true() -> void:
	var e: GameEffect = GameEffect.new()
	var ctx: EffectContext = EffectContext.new()
	assert_true(e.should_trigger(ctx),
			"Base should_trigger should return true for non-null context")


func test_game_effect_should_trigger_null_returns_false() -> void:
	var e: GameEffect = GameEffect.new()
	assert_false(e.should_trigger(null),
			"should_trigger should return false for null context")


# ---------------------------------------------------------------------------
# EffectRegistry: register / unregister
# ---------------------------------------------------------------------------

func test_register_adds_effect() -> void:
	var reg: EffectRegistry = EffectRegistry.new()
	var e: TestEffect = TestEffect.new([&"HOOK_A"])
	reg.register(e)
	assert_eq(reg.get_effect_count(), 1,
			"Registry should have 1 effect after register")


func test_register_deduplicates() -> void:
	var reg: EffectRegistry = EffectRegistry.new()
	var e: TestEffect = TestEffect.new([&"HOOK_A"])
	reg.register(e)
	reg.register(e)
	assert_eq(reg.get_effect_count(), 1,
			"Duplicate register should not add twice")


func test_unregister_removes_effect() -> void:
	var reg: EffectRegistry = EffectRegistry.new()
	var e: TestEffect = TestEffect.new([&"HOOK_A"])
	reg.register(e)
	reg.unregister(e)
	assert_eq(reg.get_effect_count(), 0,
			"Effect count should be 0 after unregister")


func test_get_effects_for_hook() -> void:
	var reg: EffectRegistry = EffectRegistry.new()
	var e: TestEffect = TestEffect.new([&"HOOK_A", &"HOOK_B"])
	reg.register(e)
	assert_eq(reg.get_effects_for_hook(&"HOOK_A").size(), 1,
			"HOOK_A should have 1 effect")
	assert_eq(reg.get_effects_for_hook(&"HOOK_B").size(), 1,
			"HOOK_B should have 1 effect")
	assert_eq(reg.get_effects_for_hook(&"HOOK_C").size(), 0,
			"HOOK_C should have 0 effects")


func test_unregister_by_owner() -> void:
	var reg: EffectRegistry = EffectRegistry.new()
	var owner_a: RefCounted = RefCounted.new()
	var owner_b: RefCounted = RefCounted.new()
	var e1: TestEffect = TestEffect.new([&"HOOK_A"])
	e1.owner = owner_a
	var e2: TestEffect = TestEffect.new([&"HOOK_A"])
	e2.owner = owner_b
	reg.register(e1)
	reg.register(e2)
	reg.unregister_by_owner(owner_a)
	assert_eq(reg.get_effect_count(), 1,
			"Only owner_b's effect should remain")
	assert_eq(reg.get_effects_for_hook(&"HOOK_A")[0].owner, owner_b,
			"Remaining effect should belong to owner_b")


func test_clear_removes_all() -> void:
	var reg: EffectRegistry = EffectRegistry.new()
	reg.register(TestEffect.new([&"X"]))
	reg.register(TestEffect.new([&"Y"]))
	reg.clear()
	assert_eq(reg.get_effect_count(), 0,
			"clear() should remove all effects")


# ---------------------------------------------------------------------------
# EffectRegistry: resolve_hook
# ---------------------------------------------------------------------------

func test_resolve_hook_calls_matching_effects() -> void:
	var reg: EffectRegistry = EffectRegistry.new()
	var e: TestEffect = TestEffect.new([&"HOOK_A"])
	reg.register(e)
	var ctx: EffectContext = EffectContext.new()
	reg.resolve_hook(&"HOOK_A", ctx)
	assert_eq(e.resolve_count, 1,
			"Effect should have been resolved once")
	assert_eq(ctx.damage_total, 1,
			"Context damage should have been incremented by effect")


func test_resolve_hook_skips_non_matching() -> void:
	var reg: EffectRegistry = EffectRegistry.new()
	var e: TestEffect = TestEffect.new([&"HOOK_A"])
	reg.register(e)
	var ctx: EffectContext = EffectContext.new()
	reg.resolve_hook(&"HOOK_B", ctx)
	assert_eq(e.resolve_count, 0,
			"Effect should not fire on a different hook")


func test_resolve_hook_skips_when_should_trigger_false() -> void:
	var reg: EffectRegistry = EffectRegistry.new()
	var e: TestEffect = TestEffect.new([&"HOOK_A"], false)
	reg.register(e)
	var ctx: EffectContext = EffectContext.new()
	reg.resolve_hook(&"HOOK_A", ctx)
	assert_eq(e.resolve_count, 0,
			"Effect should not fire when should_trigger returns false")


func test_resolve_hook_priority_order() -> void:
	var reg: EffectRegistry = EffectRegistry.new()
	var order: Array[String] = []
	# Player 1 effect (priority 1, registered first)
	var e1: GameEffect = _make_order_effect(&"H", 1, "second", order)
	# Player 0 effect (priority 0, registered second)
	var e0: GameEffect = _make_order_effect(&"H", 0, "first", order)
	reg.register(e1)
	reg.register(e0)
	var ctx: EffectContext = EffectContext.new()
	reg.resolve_hook(&"H", ctx)
	assert_eq(order, ["first", "second"],
			"Priority 0 (first player) should resolve before priority 1")


func test_resolve_hook_sets_context_hook() -> void:
	var reg: EffectRegistry = EffectRegistry.new()
	var ctx: EffectContext = EffectContext.new()
	reg.resolve_hook(&"MY_HOOK", ctx)
	assert_eq(ctx.hook, &"MY_HOOK",
			"resolve_hook should set the context's hook field")


# ---------------------------------------------------------------------------
# Helper: effect that records resolve order
# ---------------------------------------------------------------------------

func _make_order_effect(hook: StringName, prio: int,
		label: String, order_array: Array[String]) -> GameEffect:
	var e: TestEffect = TestEffect.new([hook])
	e.player_priority = prio
	# Override resolve to record label instead of incrementing damage.
	var oe: _OrderEffect = _OrderEffect.new(hook, label, order_array)
	oe.player_priority = prio
	return oe


## Inner effect that records its label into an external array on resolve.
class _OrderEffect extends GameEffect:
	var _hook: StringName
	var _label: String
	var _order: Array[String]

	func _init(hook: StringName, label: String,
			order: Array[String]) -> void:
		_hook = hook
		_label = label
		_order = order
		source_type = EffectSource.KEYWORD

	func get_hooks() -> Array[StringName]:
		return [_hook]

	func should_trigger(context: EffectContext) -> bool:
		return context != null

	func resolve(_context: EffectContext) -> void:
		_order.append(_label)
