## Command Applicability
##
## Static Phase M declarations for where each registered command may run.
## M3 adds this as metadata only; M4 will consume it from CommandProcessor.
extends RefCounted


const KEY_SCOPE: String = "scope"
const KEY_PHASES: String = "phases"
const KEY_FLOW_STEPS: String = "flow_steps"
const KEY_FLOW_ID: String = "flow_id"
const KEY_STEP_ID: String = "step_id"
const KEY_ALLOWED: String = "allowed"
const KEY_REASON: String = "reason"

const FLOW_SPEC_SCRIPT: GDScript = preload("res://src/core/state/flow_spec.gd")

static var _DECLARATIONS: Dictionary = {
	"assign_dials": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.COMMAND]},
	"start_round": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SETUP, Constants.GamePhase.STATUS]},
	"advance_phase": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.COMMAND, Constants.GamePhase.SHIP,
					Constants.GamePhase.SQUADRON]},
	"status_phase_cleanup": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.STATUS]},
	"debug_deal_damage": {KEY_SCOPE: Constants.CommandScope.GLOBAL},
	"destroy_unit": {KEY_SCOPE: Constants.CommandScope.GLOBAL},
	"publish_attack_flow": {KEY_SCOPE: Constants.CommandScope.GLOBAL},
	"activate_ship": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"reveal_dial": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"convert_dial_to_token": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"advance_activation_step": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"spend_dial": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"spend_token": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"discard_token": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"set_speed": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"repair_action": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"execute_maneuver": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"overlap_damage": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"start_displacement": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"commit_displacement": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
					Constants.InteractionStep.DISPLACEMENT_PLACE)]},
	"end_activation": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"activate_squadron": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SQUADRON]},
	"move_squadron": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP, Constants.GamePhase.SQUADRON]},
	"skip_attack": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP, Constants.GamePhase.SQUADRON]},
	"roll_dice": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP, Constants.GamePhase.SQUADRON]},
	"spend_defense_token": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP, Constants.GamePhase.SQUADRON]},
	"commit_defense": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP, Constants.GamePhase.SQUADRON]},
	"select_evade_die": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP, Constants.GamePhase.SQUADRON]},
	"select_redirect_zone": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP, Constants.GamePhase.SQUADRON]},
	"redirect_done": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP, Constants.GamePhase.SQUADRON]},
	"resolve_damage": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP, Constants.GamePhase.SQUADRON]},
	"resolve_immediate_effect": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP, Constants.GamePhase.SQUADRON]},
	"persistent_effect_damage": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
}


## Returns true when [param command_type] has an applicability declaration.
static func has_declaration(command_type: String) -> bool:
	return _DECLARATIONS.has(command_type)


## Returns a deep copy of [param command_type]'s declaration, or empty dict.
static func get_declaration(command_type: String) -> Dictionary:
	var declaration: Dictionary = _DECLARATIONS.get(command_type, {})
	return declaration.duplicate(true)


## Returns every declared command type in sorted order.
static func all_command_types() -> Array[String]:
	var command_types: Array[String] = []
	for command_type: Variant in _DECLARATIONS.keys():
		command_types.append(str(command_type))
	command_types.sort()
	return command_types


## Returns whether [param command_type] may run for the current state surface.
## The result is structured for CommandProcessor rejection diagnostics.
static func check_command(command_type: String,
		phase: Constants.GamePhase,
		interaction_flow: InteractionFlow) -> Dictionary:
	var declaration: Dictionary = get_declaration(command_type)
	if declaration.is_empty():
		return _denied_result(
				"command %s has no applicability declaration" % command_type)
	match int(declaration.get(KEY_SCOPE, -1)):
		Constants.CommandScope.GLOBAL:
			return _allowed_result()
		Constants.CommandScope.PHASE:
			return _phase_result(command_type, phase)
		Constants.CommandScope.FLOW_STEP:
			return _flow_step_result(command_type, interaction_flow)
		_:
			return _denied_result(
					"command %s has invalid applicability scope" % command_type)


## Returns the allowed game phases for a PHASE-scoped command.
static func allowed_phases_for(command_type: String) -> Array[int]:
	var phases: Array[int] = []
	var declaration: Dictionary = get_declaration(command_type)
	for phase: Variant in declaration.get(KEY_PHASES, []):
		phases.append(int(phase))
	return phases


## Returns the allowed FlowSpec pairs for a FLOW_STEP-scoped command.
static func allowed_flow_steps_for(command_type: String) -> Array[Dictionary]:
	var flow_steps: Array[Dictionary] = []
	var declaration: Dictionary = get_declaration(command_type)
	for step: Variant in declaration.get(KEY_FLOW_STEPS, []):
		flow_steps.append((step as Dictionary).duplicate(true))
	return flow_steps


## Returns true when [param command_type] is PHASE-scoped for [param phase].
static func is_phase_allowed(command_type: String,
		phase: Constants.GamePhase) -> bool:
	return allowed_phases_for(command_type).has(int(phase))


## Returns true when [param command_type] is FLOW_STEP-scoped for the pair.
static func is_flow_step_allowed(command_type: String,
		flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep) -> bool:
	for step: Dictionary in allowed_flow_steps_for(command_type):
		if int(step.get(KEY_FLOW_ID, -1)) == int(flow_id) \
				and int(step.get(KEY_STEP_ID, -1)) == int(step_id):
			return true
	return false


static func _pair(flow_id: Constants.InteractionFlow,
		step_id: Constants.InteractionStep) -> Dictionary:
	return {KEY_FLOW_ID: int(flow_id), KEY_STEP_ID: int(step_id)}


static func _phase_result(command_type: String,
		phase: Constants.GamePhase) -> Dictionary:
	if is_phase_allowed(command_type, phase):
		return _allowed_result()
	return _denied_result("command %s not allowed in phase %d" % [
		command_type,
		int(phase),
	])


static func _flow_step_result(command_type: String,
		interaction_flow: InteractionFlow) -> Dictionary:
	if interaction_flow == null:
		return _denied_result(
				"command %s not allowed in step <none>" % command_type)
	var flow_id: int = int(interaction_flow.flow_type)
	var step_id: int = int(interaction_flow.step_id)
	if _declares_flow_step(command_type, flow_id, step_id) \
			and _flowspec_allows_command(command_type, flow_id, step_id):
		return _allowed_result()
	return _denied_result("command %s not allowed in step %d/%d" % [
		command_type,
		flow_id,
		step_id,
	])


static func _declares_flow_step(command_type: String,
		flow_id: int,
		step_id: int) -> bool:
	for step: Dictionary in allowed_flow_steps_for(command_type):
		if int(step.get(KEY_FLOW_ID, -1)) == flow_id \
				and int(step.get(KEY_STEP_ID, -1)) == step_id:
			return true
	return false


static func _flowspec_allows_command(command_type: String,
		flow_id: int,
		step_id: int) -> bool:
	var spec: Dictionary = FLOW_SPEC_SCRIPT.get_spec(flow_id, step_id)
	var allowed_commands: Array = spec.get("allowed_commands", [])
	return allowed_commands.has(command_type)


static func _allowed_result() -> Dictionary:
	return {KEY_ALLOWED: true, KEY_REASON: ""}


static func _denied_result(reason: String) -> Dictionary:
	return {KEY_ALLOWED: false, KEY_REASON: reason}
