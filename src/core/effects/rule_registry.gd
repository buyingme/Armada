## RuleRegistry
##
## Static catalogue of rule hooks keyed by FlowSpec surfaces.
## Rule definitions are static; active rule state is derived from serialized
## game entities such as ships, squadrons, faceup damage cards, and tokens.
class_name RuleRegistry
extends RefCounted


static var _validators: Array[FlowHook] = []
static var _modifiers: Array[FlowHook] = []
static var _observers: Array[FlowHook] = []
static var _blockers: Array[FlowHook] = []
static var _enablers: Array[FlowHook] = []


## Removes all static hook declarations.
static func clear() -> void:
	_validators.clear()
	_modifiers.clear()
	_observers.clear()
	_blockers.clear()
	_enablers.clear()


## Registers every hook for one rule identifier.
static func register_rule(rule_id: String, hooks: Array[FlowHook]) -> void:
	for hook: FlowHook in hooks:
		if hook == null:
			continue
		hook.rule_id = rule_id
		match hook.kind:
			FlowHook.HookKind.VALIDATOR:
				register_validator(hook)
			FlowHook.HookKind.MODIFIER:
				register_modifier(hook)
			FlowHook.HookKind.OBSERVER:
				register_observer(hook)
			FlowHook.HookKind.BLOCKER:
				register_blocker(hook)
			FlowHook.HookKind.ENABLER:
				register_enabler(hook)


## Registers a validator hook.
static func register_validator(hook: FlowHook) -> void:
	_register_hook(_validators, hook, FlowHook.HookKind.VALIDATOR)


## Registers a modifier hook.
static func register_modifier(hook: FlowHook) -> void:
	_register_hook(_modifiers, hook, FlowHook.HookKind.MODIFIER)


## Registers an observer hook.
static func register_observer(hook: FlowHook) -> void:
	_register_hook(_observers, hook, FlowHook.HookKind.OBSERVER)


## Registers a blocker hook.
static func register_blocker(hook: FlowHook) -> void:
	_register_hook(_blockers, hook, FlowHook.HookKind.BLOCKER)


## Registers an enabler hook.
static func register_enabler(hook: FlowHook) -> void:
	_register_hook(_enablers, hook, FlowHook.HookKind.ENABLER)


## Returns validators matching a FlowSpec pair and command type.
static func validators_for(flow_id: int,
		step_id: int,
		command_type: String) -> Array[FlowHook]:
	return _matching_command_hooks(_validators, flow_id, step_id, command_type)


## Returns modifiers matching a FlowSpec pair and target surface.
static func modifiers_for(flow_id: int,
		step_id: int,
		target: String) -> Array[FlowHook]:
	return _matching_target_hooks(_modifiers, flow_id, step_id, target)


## Returns observers matching a FlowSpec pair and command type.
static func observers_for(flow_id: int,
		step_id: int,
		command_type: String) -> Array[FlowHook]:
	return _matching_command_hooks(_observers, flow_id, step_id, command_type)


## Returns blockers matching a FlowSpec pair and target surface.
static func blockers_for(flow_id: int,
		step_id: int,
		target: String) -> Array[FlowHook]:
	return _matching_target_hooks(_blockers, flow_id, step_id, target)


## Returns enablers matching a FlowSpec pair and target surface.
static func enablers_for(flow_id: int,
		step_id: int,
		target: String) -> Array[FlowHook]:
	return _matching_target_hooks(_enablers, flow_id, step_id, target)


## Returns all enablers matching a FlowSpec pair, regardless of target.
static func enablers_for_step(flow_id: int,
		step_id: int) -> Array[FlowHook]:
	return _matching_step_hooks(_enablers, flow_id, step_id)


## Returns every hook matching a FlowSpec pair, regardless of command or target.
static func hooks_for_step(flow_id: int, step_id: int) -> Array[FlowHook]:
	var result: Array[FlowHook] = []
	_append_step_hooks(result, _validators, flow_id, step_id)
	_append_step_hooks(result, _modifiers, flow_id, step_id)
	_append_step_hooks(result, _observers, flow_id, step_id)
	_append_step_hooks(result, _blockers, flow_id, step_id)
	_append_step_hooks(result, _enablers, flow_id, step_id)
	return _sorted_hooks(result)


## Returns the total registered hook count across every kind.
static func registered_hook_count() -> int:
	return _validators.size() + _modifiers.size() \
			+ _observers.size() + _blockers.size() + _enablers.size()


static func _register_hook(targets: Array[FlowHook],
		hook: FlowHook,
		expected_kind: FlowHook.HookKind) -> void:
	if hook == null or hook.kind != expected_kind:
		return
	if targets.has(hook):
		return
	targets.append(hook)


static func _matching_command_hooks(hooks: Array[FlowHook],
		flow_id: int,
		step_id: int,
		command_type: String) -> Array[FlowHook]:
	var result: Array[FlowHook] = []
	for hook: FlowHook in hooks:
		if hook.matches_step(flow_id, step_id) \
				and hook.matches_command(command_type):
			result.append(hook)
	return _sorted_hooks(result)


static func _matching_target_hooks(hooks: Array[FlowHook],
		flow_id: int,
		step_id: int,
		target: String) -> Array[FlowHook]:
	var result: Array[FlowHook] = []
	for hook: FlowHook in hooks:
		if hook.matches_step(flow_id, step_id) \
				and hook.matches_target(target):
			result.append(hook)
	return _sorted_hooks(result)


static func _matching_step_hooks(hooks: Array[FlowHook],
		flow_id: int,
		step_id: int) -> Array[FlowHook]:
	var result: Array[FlowHook] = []
	_append_step_hooks(result, hooks, flow_id, step_id)
	return _sorted_hooks(result)


static func _append_step_hooks(targets: Array[FlowHook],
		hooks: Array[FlowHook],
		flow_id: int,
		step_id: int) -> void:
	for hook: FlowHook in hooks:
		if hook.matches_step(flow_id, step_id):
			targets.append(hook)


static func _sorted_hooks(hooks: Array[FlowHook]) -> Array[FlowHook]:
	var result: Array[FlowHook] = hooks.duplicate()
	result.sort_custom(_hook_before)
	return result


static func _hook_before(left_hook: FlowHook, right_hook: FlowHook) -> bool:
	if left_hook.priority == right_hook.priority:
		return left_hook.rule_id < right_hook.rule_id
	return left_hook.priority > right_hook.priority
