## FlowHook
##
## Static descriptor for a rule hook registered against a FlowSpec pair.
## M5 introduces the descriptor only; later slices attach migrated rules to
## validator, modifier, observer, blocker, or enabler lists through RuleRegistry.
class_name FlowHook
extends RefCounted


## Kinds of static rule hooks supported by the Phase M registry.
enum HookKind {
	VALIDATOR,
	MODIFIER,
	OBSERVER,
	BLOCKER,
	ENABLER,
}

## Wildcard command/target value for hooks that apply to a whole step.
const ANY: String = "*"

## Hook category.
var kind: HookKind = HookKind.VALIDATOR

## Stable rule identifier used for diagnostics and deterministic ordering.
var rule_id: String = ""

## Higher priority hooks run before lower priority hooks.
var priority: int = 0

## Interaction flow this hook applies to.
var flow_id: Constants.InteractionFlow = Constants.InteractionFlow.NONE

## Interaction step this hook applies to.
var step_id: Constants.InteractionStep = Constants.InteractionStep.NONE

## Command type for validators/observers, or [constant ANY].
var command_type: String = ANY

## Modifier/blocker/enabler target surface, or [constant ANY].
var target: String = ANY

## Callable invoked by later rule-processing slices.
var callback: Callable = Callable()


## Creates a validator hook for [param p_command_type] at a FlowSpec pair.
static func validator(p_rule_id: String,
		p_flow_id: Constants.InteractionFlow,
		p_step_id: Constants.InteractionStep,
		p_command_type: String,
		p_callback: Callable,
		p_priority: int = 0) -> FlowHook:
	return create(HookKind.VALIDATOR, p_rule_id, p_flow_id, p_step_id,
			p_callback, p_priority, p_command_type, ANY)


## Creates a modifier hook for [param p_target] at a FlowSpec pair.
static func modifier(p_rule_id: String,
		p_flow_id: Constants.InteractionFlow,
		p_step_id: Constants.InteractionStep,
		p_target: String,
		p_callback: Callable,
		p_priority: int = 0) -> FlowHook:
	return create(HookKind.MODIFIER, p_rule_id, p_flow_id, p_step_id,
			p_callback, p_priority, ANY, p_target)


## Creates an observer hook for [param p_command_type] at a FlowSpec pair.
static func observer(p_rule_id: String,
		p_flow_id: Constants.InteractionFlow,
		p_step_id: Constants.InteractionStep,
		p_command_type: String,
		p_callback: Callable,
		p_priority: int = 0) -> FlowHook:
	return create(HookKind.OBSERVER, p_rule_id, p_flow_id, p_step_id,
			p_callback, p_priority, p_command_type, ANY)


## Creates a blocker hook for [param p_target] at a FlowSpec pair.
static func blocker(p_rule_id: String,
		p_flow_id: Constants.InteractionFlow,
		p_step_id: Constants.InteractionStep,
		p_target: String,
		p_callback: Callable,
		p_priority: int = 0) -> FlowHook:
	return create(HookKind.BLOCKER, p_rule_id, p_flow_id, p_step_id,
			p_callback, p_priority, ANY, p_target)


## Creates an enabler hook for [param p_target] at a FlowSpec pair.
static func enabler(p_rule_id: String,
		p_flow_id: Constants.InteractionFlow,
		p_step_id: Constants.InteractionStep,
		p_target: String,
		p_callback: Callable,
		p_priority: int = 0) -> FlowHook:
	return create(HookKind.ENABLER, p_rule_id, p_flow_id, p_step_id,
			p_callback, p_priority, ANY, p_target)


## Creates a hook descriptor with explicit fields.
static func create(p_kind: HookKind,
		p_rule_id: String,
		p_flow_id: Constants.InteractionFlow,
		p_step_id: Constants.InteractionStep,
		p_callback: Callable,
		p_priority: int = 0,
		p_command_type: String = ANY,
		p_target: String = ANY) -> FlowHook:
	var hook: FlowHook = FlowHook.new()
	hook.kind = p_kind
	hook.rule_id = p_rule_id
	hook.flow_id = p_flow_id
	hook.step_id = p_step_id
	hook.callback = p_callback
	hook.priority = p_priority
	hook.command_type = p_command_type
	hook.target = p_target
	return hook


## Returns true when this hook applies to the FlowSpec pair.
func matches_step(flow: int, step: int) -> bool:
	return int(flow_id) == flow and int(step_id) == step


## Returns true when this hook applies to [param command].
func matches_command(command: String) -> bool:
	return command_type == ANY or command_type == command


## Returns true when this hook applies to [param target_name].
func matches_target(target_name: String) -> bool:
	return target == ANY or target == target_name