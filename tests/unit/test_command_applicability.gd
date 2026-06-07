## Test: CommandApplicability
##
## Unit tests for Phase M command scope declarations.
extends GutTest


const CommandApplicabilityScript: GDScript = \
		preload("res://src/core/commands/command_applicability.gd")
const CommandProcessorScript: GDScript = \
		preload("res://src/autoload/command_processor.gd")
const FlowSpecScript: GDScript = preload("res://src/core/state/flow_spec.gd")

var _saved_registry: Dictionary = {}


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	GameCommand._registry.clear()
	var processor: Node = CommandProcessorScript.new()
	add_child_autofree(processor)


func after_each() -> void:
	GameCommand._registry = _saved_registry


func test_registered_commands_have_applicability_declarations() -> void:
	var missing: Array[String] = []
	for command_type: String in GameCommand.registered_types():
		if not CommandApplicabilityScript.has_declaration(command_type):
			missing.append(command_type)
	assert_eq(missing, [],
			"Every registered production command should have M3 applicability metadata.")


func test_applicability_declarations_match_registered_commands() -> void:
	var stale: Array[String] = []
	var registered: Array[String] = GameCommand.registered_types()
	for command_type: String in CommandApplicabilityScript.all_command_types():
		if not registered.has(command_type):
			stale.append(command_type)
	assert_eq(stale, [],
			"Every M3 applicability declaration should point at a registered command.")


func test_declarations_have_scope_appropriate_targets() -> void:
	var errors: Array[String] = []
	for command_type: String in CommandApplicabilityScript.all_command_types():
		var declaration: Dictionary = \
				CommandApplicabilityScript.get_declaration(command_type)
		_check_scope_targets(command_type, declaration, errors)
	assert_eq(errors, [],
			"Command declarations should have the required scope target shape.")


func test_flow_step_declarations_reference_flowspec_pairs() -> void:
	var missing_pairs: Array[String] = []
	for command_type: String in CommandApplicabilityScript.all_command_types():
		for step: Dictionary in CommandApplicabilityScript.allowed_flow_steps_for(
				command_type):
			if not FlowSpecScript.has_spec(
					int(step[CommandApplicabilityScript.KEY_FLOW_ID]),
					int(step[CommandApplicabilityScript.KEY_STEP_ID])):
				missing_pairs.append(_flow_step_key(command_type, step))
	assert_eq(missing_pairs, [],
			"Every FLOW_STEP declaration should reference a registered FlowSpec pair.")


func test_flow_step_declarations_match_flowspec_allowed_commands() -> void:
	var mismatches: Array[String] = []
	for command_type: String in CommandApplicabilityScript.all_command_types():
		for step: Dictionary in CommandApplicabilityScript.allowed_flow_steps_for(
				command_type):
			var spec: Dictionary = FlowSpecScript.get_spec(
					int(step[CommandApplicabilityScript.KEY_FLOW_ID]),
					int(step[CommandApplicabilityScript.KEY_STEP_ID]))
			var allowed_commands: Array = spec.get("allowed_commands", [])
			if not allowed_commands.has(command_type):
				mismatches.append(_flow_step_key(command_type, step))
	assert_eq(mismatches, [],
			"FLOW_STEP declarations should agree with FlowSpec.allowed_commands.")


func test_resolve_immediate_effect_declared_for_ship_and_squadron_phases() -> void:
	assert_true(CommandApplicabilityScript.is_phase_allowed(
			"resolve_immediate_effect", Constants.GamePhase.SHIP),
			"resolve_immediate_effect should remain legal during Ship Phase.")
	assert_true(CommandApplicabilityScript.is_phase_allowed(
			"resolve_immediate_effect", Constants.GamePhase.SQUADRON),
			"resolve_immediate_effect should preserve debug follow-ups in Squadron Phase.")
	assert_false(CommandApplicabilityScript.is_phase_allowed(
			"resolve_immediate_effect", Constants.GamePhase.COMMAND),
			"resolve_immediate_effect should not be Command Phase-scoped.")


func test_publish_attack_flow_declared_global() -> void:
	var declaration: Dictionary = \
			CommandApplicabilityScript.get_declaration("publish_attack_flow")
	assert_eq(int(declaration.get(CommandApplicabilityScript.KEY_SCOPE, -1)),
			int(Constants.CommandScope.GLOBAL),
			"publish_attack_flow should be global so it can publish the next step.")


func test_get_declaration_returns_deep_copy() -> void:
	var declaration: Dictionary = \
			CommandApplicabilityScript.get_declaration("advance_phase")
	(declaration[CommandApplicabilityScript.KEY_PHASES] as Array).append(
			Constants.GamePhase.STATUS)
	assert_false(CommandApplicabilityScript.is_phase_allowed(
			"advance_phase", Constants.GamePhase.STATUS),
			"get_declaration() should deep-copy declaration arrays.")


func test_flow_step_query_matches_declared_pair() -> void:
	assert_true(CommandApplicabilityScript.is_flow_step_allowed(
			"commit_displacement",
			Constants.InteractionFlow.SQUADRON_DISPLACEMENT,
			Constants.InteractionStep.DISPLACEMENT_PLACE),
			"commit_displacement should be scoped to the displacement placement step.")
	assert_false(CommandApplicabilityScript.is_flow_step_allowed(
			"commit_displacement",
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP),
			"commit_displacement should not be legal at the maneuver producer step.")
	assert_true(CommandApplicabilityScript.is_flow_step_allowed(
			"commit_setup_obstacle",
			Constants.InteractionFlow.SETUP,
			Constants.InteractionStep.SETUP_OBSTACLE_PLACEMENT),
			"Setup obstacle placement should be scoped to the setup obstacle step.")
	assert_true(CommandApplicabilityScript.is_flow_step_allowed(
			"commit_setup_deployment",
			Constants.InteractionFlow.SETUP,
			Constants.InteractionStep.SETUP_SHIP_DEPLOYMENT),
			"Setup deployment should be legal in the setup ship-deployment step.")
	assert_true(CommandApplicabilityScript.is_flow_step_allowed(
			"commit_setup_deployment",
			Constants.InteractionFlow.SETUP,
			Constants.InteractionStep.SETUP_SQUADRON_DEPLOYMENT),
			"Setup deployment should remain legal in the setup squadron-deployment step.")


func _check_scope_targets(command_type: String,
		declaration: Dictionary,
		errors: Array[String]) -> void:
	var scope: Constants.CommandScope = int(declaration.get(
			CommandApplicabilityScript.KEY_SCOPE, -1)) as Constants.CommandScope
	match scope:
		Constants.CommandScope.GLOBAL:
			_check_global_targets(command_type, declaration, errors)
		Constants.CommandScope.PHASE:
			_check_phase_targets(command_type, declaration, errors)
		Constants.CommandScope.FLOW_STEP:
			_check_flow_step_targets(command_type, declaration, errors)
		_:
			errors.append("%s has invalid scope" % command_type)


func _check_global_targets(command_type: String,
		declaration: Dictionary,
		errors: Array[String]) -> void:
	if declaration.has(CommandApplicabilityScript.KEY_PHASES) \
			or declaration.has(CommandApplicabilityScript.KEY_FLOW_STEPS):
		errors.append("%s GLOBAL should not carry targets" % command_type)


func _check_phase_targets(command_type: String,
		declaration: Dictionary,
		errors: Array[String]) -> void:
	var phases: Array = declaration.get(CommandApplicabilityScript.KEY_PHASES, [])
	if phases.is_empty():
		errors.append("%s PHASE has no phases" % command_type)
	if declaration.has(CommandApplicabilityScript.KEY_FLOW_STEPS):
		errors.append("%s PHASE should not carry flow steps" % command_type)


func _check_flow_step_targets(command_type: String,
		declaration: Dictionary,
		errors: Array[String]) -> void:
	var flow_steps: Array = declaration.get(
			CommandApplicabilityScript.KEY_FLOW_STEPS, [])
	if flow_steps.is_empty():
		errors.append("%s FLOW_STEP has no flow steps" % command_type)
	if declaration.has(CommandApplicabilityScript.KEY_PHASES):
		errors.append("%s FLOW_STEP should not carry phases" % command_type)


func _flow_step_key(command_type: String, step: Dictionary) -> String:
	return "%s:%d/%d" % [
		command_type,
		int(step[CommandApplicabilityScript.KEY_FLOW_ID]),
		int(step[CommandApplicabilityScript.KEY_STEP_ID]),
	]
