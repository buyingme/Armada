## Test: RuleSurface
##
## Verifies Phase N rule-surface scaffolding without registering production
## rules or changing legacy effect behaviour.
extends GutTest


const ATTACK_FLOW: Constants.InteractionFlow = Constants.InteractionFlow.ATTACK
const ATTACK_DAMAGE_STEP: Constants.InteractionStep = \
		Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE
const ATTACK_DECLARE_STEP: Constants.InteractionStep = \
		Constants.InteractionStep.ATTACK_DECLARE
const MANEUVER_FLOW: Constants.InteractionFlow = \
		Constants.InteractionFlow.SHIP_ACTIVATION
const MANEUVER_STEP: Constants.InteractionStep = \
		Constants.InteractionStep.MANEUVER_STEP


func before_each() -> void:
	RuleRegistry.clear()


func after_each() -> void:
	RuleRegistry.clear()


func test_surface_constants_cover_n1_blocker_targets() -> void:
	assert_eq(RuleSurface.TARGET_ATTACK_TARGET, "attack_target",
			"Attack-target blockers need a stable surface name.")
	assert_eq(RuleSurface.TARGET_ACCURACY_SPEND, "accuracy_spend",
			"Accuracy blockers need a stable surface name.")
	assert_eq(RuleSurface.TARGET_CRITICAL_EFFECT, "critical_effect",
			"Critical-effect blockers need a stable surface name.")
	assert_eq(RuleSurface.TARGET_COMMAND_TOKEN_GAIN, "command_token_gain",
			"Command-token blockers need a stable surface name.")


func test_surface_constants_cover_n1_modifier_targets() -> void:
	assert_eq(RuleSurface.TARGET_ATTACK_DAMAGE, "attack_damage",
			"Attack-damage modifiers need a stable surface name.")
	assert_eq(RuleSurface.TARGET_ENGINEERING_VALUE, "engineering_value",
			"Engineering modifiers need a stable surface name.")
	assert_eq(RuleSurface.TARGET_MANEUVER_YAW, "maneuver_yaw",
			"Maneuver-yaw modifiers need a stable surface name.")
	assert_eq(RuleSurface.TARGET_POST_MANEUVER, "post_maneuver",
			"Maneuver observers need a stable result surface name.")


func test_existing_surface_aliases_match_phase_m_strings() -> void:
	assert_eq(RuleSurface.TARGET_DICE_POOL, "dice_pool",
			"Dice-pool aliases should match existing migrated rules.")
	assert_eq(RuleSurface.TARGET_DEFENSE_TOKEN_SPEND, "defense_token_spend",
			"Defense-token aliases should match Capacitor Failure.")
	assert_eq(RuleSurface.TARGET_REPAIR_SHIELD, "repair_shield",
			"Repair aliases should match Capacitor Failure.")
	assert_eq(RuleSurface.TARGET_DEFENSE_TOKEN_READYING,
			"defense_token_readying",
			"Readying aliases should match status cleanup hooks.")


func test_surface_constants_cover_n17_keyword_foundation() -> void:
	assert_eq(RuleSurface.TARGET_SQUADRON_MOVEMENT, "squadron_movement",
			"Heavy needs a stable squadron-movement surface name.")
	assert_eq(RuleSurface.TARGET_ATTACK_MODIFIER_AFFORDANCE,
			"attack_modifier_affordance",
			"Optional attack modifiers need a stable affordance surface name.")
	assert_eq(RuleSurface.COMMAND_MOVE_SQUADRON, "move_squadron",
			"Heavy movement validation needs the move_squadron command id.")
	assert_eq(RuleSurface.COMMAND_PUBLISH_ATTACK_FLOW, "publish_attack_flow",
			"Target legality validation needs the attack-flow publish command id.")


func test_apply_modifiers_empty_registry_preserves_context() -> void:
	var context: EffectContext = EffectContext.new()
	context.damage_total = 5
	var result: EffectContext = RuleSurface.apply_modifiers(context,
			ATTACK_FLOW, ATTACK_DAMAGE_STEP, RuleSurface.TARGET_ATTACK_DAMAGE)
	assert_same(result, context,
			"No modifier hooks should return the original context object.")
	assert_eq(result.damage_total, 5,
			"No modifier hooks should preserve the old damage total.")


func test_apply_modifiers_runs_priority_then_rule_id() -> void:
	_register_damage_modifier("surface.zeta", Callable(self , "_append_zeta"), 10)
	_register_damage_modifier("surface.alpha", Callable(self , "_append_alpha"), 10)
	_register_damage_modifier("surface.low", Callable(self , "_append_low"), 1)
	var context: EffectContext = EffectContext.new()
	context.set_meta_value("order", [])
	var result: EffectContext = RuleSurface.apply_modifiers(context,
			ATTACK_FLOW, ATTACK_DAMAGE_STEP, RuleSurface.TARGET_ATTACK_DAMAGE)
	assert_eq(result.get_meta_value("order", []), ["alpha", "zeta", "low"],
			"Modifiers should use RuleRegistry's deterministic ordering.")


func test_apply_modifier_by_rule_runs_only_named_modifier() -> void:
	_register_damage_modifier("surface.skip", Callable(self , "_add_hundred"), 10)
	_register_damage_modifier("surface.pick", Callable(self , "_add_four"), 1)
	var context: EffectContext = EffectContext.new()
	context.damage_total = 2
	var result: EffectContext = RuleSurface.apply_modifier_by_rule(context,
			ATTACK_FLOW, ATTACK_DAMAGE_STEP, RuleSurface.TARGET_ATTACK_DAMAGE,
			"surface.pick")
	assert_eq(result.damage_total, 6,
			"Selected modifier execution should ignore other hooks on the surface.")


func test_apply_modifiers_invalid_callback_preserves_context() -> void:
	RuleRegistry.register_rule("surface.invalid", [FlowHook.modifier(
			"surface.invalid", ATTACK_FLOW, ATTACK_DAMAGE_STEP,
			RuleSurface.TARGET_ATTACK_DAMAGE, Callable(), 10)])
	var context: EffectContext = EffectContext.new()
	context.damage_total = 7
	var result: EffectContext = RuleSurface.apply_modifiers(context,
			ATTACK_FLOW, ATTACK_DAMAGE_STEP, RuleSurface.TARGET_ATTACK_DAMAGE)
	assert_same(result, context,
			"Invalid modifier callbacks should keep the original context.")


func test_block_result_empty_registry_allows_surface() -> void:
	var result: Dictionary = RuleSurface.block_result(EffectContext.new(),
			ATTACK_FLOW, ATTACK_DECLARE_STEP, RuleSurface.TARGET_ATTACK_TARGET)
	assert_false(bool(result.get(RuleSurface.RESULT_BLOCKED, true)),
			"No blockers should allow the target surface.")
	assert_eq(str(result.get(RuleSurface.RESULT_REASON, "x")), "",
			"Allowed blocker results should carry an empty reason.")


func test_block_result_returns_first_blocker_in_registry_order() -> void:
	_register_attack_target_blocker("surface.zeta", Callable(self , "_block_zeta"), 10)
	_register_attack_target_blocker("surface.alpha", Callable(self , "_block_alpha"), 10)
	var result: Dictionary = RuleSurface.block_result(EffectContext.new(),
			ATTACK_FLOW, ATTACK_DECLARE_STEP, RuleSurface.TARGET_ATTACK_TARGET)
	assert_true(bool(result.get(RuleSurface.RESULT_BLOCKED, false)),
			"A blocking hook should reject the surface.")
	assert_eq(str(result.get(RuleSurface.RESULT_REASON, "")), "alpha block",
			"First blocker should follow deterministic registry order.")


func test_collect_observer_followups_empty_registry_returns_empty() -> void:
	var followups: Array = RuleSurface.collect_observer_followups(_make_state(),
			_make_maneuver_command(), {"ok": true}, MANEUVER_FLOW, MANEUVER_STEP)
	assert_eq(followups, [],
			"No maneuver observers should produce no follow-ups.")


func test_collect_observer_followups_runs_deterministic_order() -> void:
	_register_maneuver_observer("surface.zeta", Callable(self , "_observe_zeta"), 5)
	_register_maneuver_observer("surface.alpha", Callable(self , "_observe_alpha"), 5)
	var followups: Array = RuleSurface.collect_observer_followups(_make_state(),
			_make_maneuver_command(), {"ok": true}, MANEUVER_FLOW, MANEUVER_STEP)
	assert_eq((followups[0] as Dictionary).get("source", ""), "alpha",
			"Observer follow-ups should start with the first sorted rule id.")
	assert_eq((followups[1] as Dictionary).get("source", ""), "zeta",
			"Observer follow-ups should preserve registry order.")


func _register_damage_modifier(rule_id: String,
		callback: Callable,
		priority: int) -> void:
	RuleRegistry.register_rule(rule_id, [FlowHook.modifier(rule_id,
			ATTACK_FLOW, ATTACK_DAMAGE_STEP,
			RuleSurface.TARGET_ATTACK_DAMAGE, callback, priority)])


func _register_attack_target_blocker(rule_id: String,
		callback: Callable,
		priority: int) -> void:
	RuleRegistry.register_rule(rule_id, [FlowHook.blocker(rule_id,
			ATTACK_FLOW, ATTACK_DECLARE_STEP,
			RuleSurface.TARGET_ATTACK_TARGET, callback, priority)])


func _register_maneuver_observer(rule_id: String,
		callback: Callable,
		priority: int) -> void:
	RuleRegistry.register_rule(rule_id, [FlowHook.observer(rule_id,
			MANEUVER_FLOW, MANEUVER_STEP,
			RuleSurface.COMMAND_EXECUTE_MANEUVER, callback, priority)])


func _append_alpha(context: EffectContext) -> EffectContext:
	return _append_modifier_label(context, "alpha")


func _append_zeta(context: EffectContext) -> EffectContext:
	return _append_modifier_label(context, "zeta")


func _append_low(context: EffectContext) -> EffectContext:
	return _append_modifier_label(context, "low")


func _append_modifier_label(context: EffectContext, label: String) -> EffectContext:
	var order: Array = context.get_meta_value("order", []) as Array
	order.append(label)
	context.set_meta_value("order", order)
	return context


func _add_four(context: EffectContext) -> EffectContext:
	context.damage_total += 4
	return context


func _add_hundred(context: EffectContext) -> EffectContext:
	context.damage_total += 100
	return context


func _block_alpha(_context: EffectContext) -> Dictionary:
	return {"blocked": true, "reason": "alpha block"}


func _block_zeta(_context: EffectContext) -> Dictionary:
	return {"blocked": true, "reason": "zeta block"}


func _observe_alpha(_game_state: GameState,
		_command: GameCommand,
		_result: Dictionary) -> Array[Dictionary]:
	return [ {"source": "alpha"}]


func _observe_zeta(_game_state: GameState,
		_command: GameCommand,
		_result: Dictionary) -> Dictionary:
	return {"source": "zeta"}


func _make_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	return state


func _make_maneuver_command() -> GameCommand:
	return GameCommand.new(0, RuleSurface.COMMAND_EXECUTE_MANEUVER, {})
