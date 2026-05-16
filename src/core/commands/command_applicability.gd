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
	"activate_ship": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.WAIT_FOR_SHIP_SELECT),
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.REVEAL_DIAL),
			]},
	"reveal_dial": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.WAIT_FOR_SHIP_SELECT),
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.REVEAL_DIAL),
			]},
	"convert_dial_to_token": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.WAIT_FOR_SHIP_SELECT),
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.ACTIVATION_MODAL_OPEN),
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.SPEND_DIAL),
			]},
	"advance_activation_step": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.ACTIVATION_MODAL_OPEN),
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.SQUADRON_STEP),
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.REPAIR_STEP),
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.ATTACK_STEP),
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.MANEUVER_STEP),
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.ACTIVATION_DONE),
			]},
	"spend_dial": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"spend_token": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"discard_token": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"set_speed": {KEY_SCOPE: Constants.CommandScope.PHASE,
			KEY_PHASES: [Constants.GamePhase.SHIP]},
	"repair_action": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
					Constants.InteractionStep.REPAIR_STEP)]},
	"execute_maneuver": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
					Constants.InteractionStep.MANEUVER_STEP)]},
	"overlap_damage": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
					Constants.InteractionStep.MANEUVER_STEP)]},
	"start_displacement": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
					Constants.InteractionStep.MANEUVER_STEP)]},
	"commit_displacement": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
					Constants.InteractionStep.DISPLACEMENT_PLACE)]},
	"end_activation": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.MANEUVER_STEP),
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.ACTIVATION_DONE),
			]},
	"activate_squadron": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.SQUADRON_ACTIVATION,
					Constants.InteractionStep.WAIT_FOR_SQUAD_SELECT)]},
	"move_squadron": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [
				_pair(Constants.InteractionFlow.SQUADRON_ACTIVATION,
						Constants.InteractionStep.ACTION_CHOICE),
				_pair(Constants.InteractionFlow.SQUADRON_ACTIVATION,
						Constants.InteractionStep.SQUAD_MOVE),
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.SQUADRON_STEP),
			]},
	"skip_attack": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [
				_pair(Constants.InteractionFlow.SHIP_ACTIVATION,
						Constants.InteractionStep.ATTACK_STEP),
				_pair(Constants.InteractionFlow.SQUADRON_ACTIVATION,
						Constants.InteractionStep.SQUAD_ATTACK),
				_pair(Constants.InteractionFlow.ATTACK,
						Constants.InteractionStep.ATTACK_DECLARE),
				_pair(Constants.InteractionFlow.ATTACK,
						Constants.InteractionStep.ATTACK_ROLL),
				_pair(Constants.InteractionFlow.ATTACK,
						Constants.InteractionStep.ATTACK_MODIFY),
			]},
	"roll_dice": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.ATTACK,
					Constants.InteractionStep.ATTACK_ROLL)]},
	"spend_defense_token": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.ATTACK,
					Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)]},
	"commit_defense": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.ATTACK,
					Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)]},
	"select_evade_die": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.ATTACK,
					Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)]},
	"select_redirect_zone": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.ATTACK,
					Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)]},
	"redirect_done": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.ATTACK,
					Constants.InteractionStep.ATTACK_DEFENSE_TOKENS)]},
	"resolve_damage": {KEY_SCOPE: Constants.CommandScope.FLOW_STEP,
			KEY_FLOW_STEPS: [_pair(Constants.InteractionFlow.ATTACK,
					Constants.InteractionStep.ATTACK_RESOLVE_DAMAGE)]},
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