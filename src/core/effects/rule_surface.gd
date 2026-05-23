## RuleSurface
##
## Shared RuleRegistry target names and callback runners for Phase N rule
## migrations. The registry remains a static catalogue; this helper only
## executes already-registered hooks for a known FlowSpec surface.
class_name RuleSurface
extends RefCounted


const RESULT_BLOCKED: String = "blocked"
const RESULT_REASON: String = "reason"

const TARGET_DICE_POOL: String = "dice_pool"
const TARGET_ATTACK_TARGET: String = "attack_target"
const TARGET_ATTACK_DAMAGE: String = "attack_damage"
const TARGET_ACCURACY_SPEND: String = "accuracy_spend"
const TARGET_CRITICAL_EFFECT: String = "critical_effect"
const TARGET_DEFENSE_TOKEN_SPEND: String = "defense_token_spend"
const TARGET_REPAIR_SHIELD: String = "repair_shield"
const TARGET_ENGINEERING_VALUE: String = "engineering_value"
const TARGET_COMMAND_TOKEN_GAIN: String = "command_token_gain"
const TARGET_DEFENSE_TOKEN_READYING: String = "defense_token_readying"
const TARGET_COMMAND_DIAL_REVEAL: String = "command_dial_reveal"
const TARGET_SQUADRON_MOVEMENT: String = "squadron_movement"
const TARGET_MANEUVER_YAW: String = "maneuver_yaw"
const TARGET_POST_MANEUVER: String = "post_maneuver"
const TARGET_SPEED_CHANGE: String = "speed_change"
const TARGET_ATTACK_MODIFIER_AFFORDANCE: String = "attack_modifier_affordance"

const COMMAND_EXECUTE_MANEUVER: String = "execute_maneuver"
const COMMAND_MOVE_SQUADRON: String = "move_squadron"
const COMMAND_PUBLISH_ATTACK_FLOW: String = "publish_attack_flow"


## Applies all modifier hooks for [param target] on the given FlowSpec pair.
## Hooks run in RuleRegistry order: priority descending, then rule id ascending.
static func apply_modifiers(context: EffectContext,
		flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep,
		target: String) -> EffectContext:
	if context == null:
		return context
	var current_context: EffectContext = context
	var hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			int(flow_id), int(step_id), target)
	for hook: FlowHook in hooks:
		current_context = _apply_modifier_hook(hook, current_context)
	return current_context


## Applies only the modifier hook with [param rule_id] on a FlowSpec pair.
## Used by player-choice rules after the first pass exposed the selected rule.
static func apply_modifier_by_rule(context: EffectContext,
		flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep,
		target: String,
		rule_id: String) -> EffectContext:
	if context == null:
		return context
	var current_context: EffectContext = context
	var hooks: Array[FlowHook] = RuleRegistry.modifiers_for(
			int(flow_id), int(step_id), target)
	for hook: FlowHook in hooks:
		if hook.rule_id == rule_id:
			current_context = _apply_modifier_hook(hook, current_context)
	return current_context


## Returns the first blocking result for [param target], or an allowed result.
## The returned dictionary is JSON-safe: `{ "blocked": bool, "reason": String }`.
static func block_result(context: EffectContext,
		flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep,
		target: String) -> Dictionary:
	var hooks: Array[FlowHook] = RuleRegistry.blockers_for(
			int(flow_id), int(step_id), target)
	for hook: FlowHook in hooks:
		var result: Dictionary = _run_blocker_hook(hook, context)
		if bool(result.get(RESULT_BLOCKED, false)):
			return _blocked(_block_reason(hook, result))
	return _not_blocked()


## Returns true when any blocker hook rejects [param target].
static func is_blocked(context: EffectContext,
		flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep,
		target: String) -> bool:
	var result: Dictionary = block_result(context, flow_id, step_id, target)
	return bool(result.get(RESULT_BLOCKED, false))


## Collects observer follow-up items without submitting them synchronously.
## Callers remain responsible for queueing returned commands or dictionaries.
static func collect_observer_followups(game_state: GameState,
		command: GameCommand,
		result: Dictionary,
		flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep) -> Array:
	var followups: Array = []
	if game_state == null or command == null:
		return followups
	var hooks: Array[FlowHook] = RuleRegistry.observers_for(
			int(flow_id), int(step_id), command.command_type)
	for hook: FlowHook in hooks:
		_append_observer_followups(followups, hook, game_state, command, result)
	return followups


static func _apply_modifier_hook(hook: FlowHook,
		context: EffectContext) -> EffectContext:
	if hook == null or not hook.callback.is_valid():
		return context
	var raw: Variant = hook.callback.call(context)
	if raw is EffectContext:
		return raw as EffectContext
	return context


static func _run_blocker_hook(hook: FlowHook,
		context: EffectContext) -> Dictionary:
	if hook == null or not hook.callback.is_valid():
		return {}
	var raw: Variant = hook.callback.call(context)
	if raw is Dictionary:
		return raw as Dictionary
	return {}


static func _append_observer_followups(target: Array,
		hook: FlowHook,
		game_state: GameState,
		command: GameCommand,
		result: Dictionary) -> void:
	if hook == null or not hook.callback.is_valid():
		return
	var raw: Variant = hook.callback.call(game_state, command, result)
	if raw is Array:
		_append_observer_array(target, raw as Array)
		return
	if raw != null:
		target.append(raw)


static func _append_observer_array(target: Array, items: Array) -> void:
	for item: Variant in items:
		if item != null:
			target.append(item)


static func _block_reason(hook: FlowHook, result: Dictionary) -> String:
	var reason: String = str(result.get(RESULT_REASON, ""))
	if reason != "":
		return reason
	return "Rule %s blocked this option." % hook.rule_id


static func _blocked(reason: String) -> Dictionary:
	return {RESULT_BLOCKED: true, RESULT_REASON: reason}


static func _not_blocked() -> Dictionary:
	return {RESULT_BLOCKED: false, RESULT_REASON: ""}
