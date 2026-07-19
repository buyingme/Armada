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
static var _timing_window_participants: Array[Dictionary] = []
static var _invalid_timing_window_participant_keys: Dictionary = {}

const PARTICIPANT_KEY_CAPABILITY_ID: String = "capability_id"
const PARTICIPANT_KEY_WINDOW: String = "participant_key"
const PARTICIPANT_KEY_SOURCE_OWNER_KIND: String = "source_owner_kind"
const PARTICIPANT_KEY_RULE_SCRIPT: String = "rule_script"
const PARTICIPANT_KEY_DIAGNOSTIC_ID: String = "diagnostic_id"

const SOURCE_ENUMERATION_METHOD: String = "enumerate_timing_window_sources"
const OPPORTUNITY_DERIVATION_METHOD: String = "derive_timing_window_opportunities"


## Removes all static hook declarations.
static func clear() -> void:
	_validators.clear()
	_modifiers.clear()
	_observers.clear()
	_blockers.clear()
	_enablers.clear()
	_timing_window_participants.clear()
	_invalid_timing_window_participant_keys.clear()


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


## Registers static candidate metadata only. Runtime sources are never stored.
static func register_timing_window_participant(descriptor: Dictionary) -> bool:
	var participant_key: String = str(descriptor.get(
			PARTICIPANT_KEY_WINDOW, ""))
	if not _is_valid_timing_window_participant(descriptor):
		_invalid_timing_window_participant_keys[
				participant_key if not participant_key.is_empty() else "*"] = true
		return false
	_timing_window_participants.append(descriptor.duplicate(true))
	return true


## Returns deterministic static candidates or one fail-closed diagnostic.
static func timing_window_participants_for(participant_key: String) -> Dictionary:
	if bool(_invalid_timing_window_participant_keys.get("*", false)) \
			or bool(_invalid_timing_window_participant_keys.get(
					participant_key, false)):
		return {
			"ok": false,
			"reason": "Invalid timing-window participant registration.",
			"candidates": [],
		}
	var candidates: Array[Dictionary] = []
	for descriptor: Dictionary in _timing_window_participants:
		if str(descriptor.get(PARTICIPANT_KEY_WINDOW, "")) == participant_key:
			candidates.append(descriptor.duplicate(true))
	candidates.sort_custom(_timing_window_participant_before)
	return {"ok": true, "reason": "", "candidates": candidates}


static func registered_timing_window_participant_count() -> int:
	return _timing_window_participants.size()


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


static func _is_valid_timing_window_participant(descriptor: Dictionary) -> bool:
	var expected_keys: Array[String] = [
		PARTICIPANT_KEY_CAPABILITY_ID,
		PARTICIPANT_KEY_WINDOW,
		PARTICIPANT_KEY_SOURCE_OWNER_KIND,
		PARTICIPANT_KEY_RULE_SCRIPT,
		PARTICIPANT_KEY_DIAGNOSTIC_ID,
	]
	for raw_key: Variant in descriptor.keys():
		if typeof(raw_key) != TYPE_STRING or not expected_keys.has(str(raw_key)):
			return false
	for key: String in [
		PARTICIPANT_KEY_CAPABILITY_ID,
		PARTICIPANT_KEY_WINDOW,
		PARTICIPANT_KEY_SOURCE_OWNER_KIND,
		PARTICIPANT_KEY_DIAGNOSTIC_ID,
	]:
		if typeof(descriptor.get(key)) != TYPE_STRING \
				or str(descriptor.get(key, "")).is_empty():
			return false
	var rule_script: Variant = descriptor.get(PARTICIPANT_KEY_RULE_SCRIPT)
	if not rule_script is GDScript:
		return false
	return (rule_script as GDScript).has_method(SOURCE_ENUMERATION_METHOD) \
			and (rule_script as GDScript).has_method(OPPORTUNITY_DERIVATION_METHOD)


static func _timing_window_participant_before(
		left: Dictionary, right: Dictionary) -> bool:
	var left_key: String = "%s|%s|%s" % [
		str(left.get(PARTICIPANT_KEY_CAPABILITY_ID, "")),
		str(left.get(PARTICIPANT_KEY_SOURCE_OWNER_KIND, "")),
		str(left.get(PARTICIPANT_KEY_DIAGNOSTIC_ID, "")),
	]
	var right_key: String = "%s|%s|%s" % [
		str(right.get(PARTICIPANT_KEY_CAPABILITY_ID, "")),
		str(right.get(PARTICIPANT_KEY_SOURCE_OWNER_KIND, "")),
		str(right.get(PARTICIPANT_KEY_DIAGNOSTIC_ID, "")),
	]
	return left_key < right_key
