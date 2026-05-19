## Test: Dump Flow Coverage
##
## Verifies the Phase M14 headless FlowSpec/RuleRegistry coverage tool.
extends GutTest


const DumpFlowCoverageScript: GDScript = preload(
		"res://scripts/dump_flow_coverage.gd")


func before_each() -> void:
	RuleRegistry.clear()


func after_each() -> void:
	RuleRegistry.clear()


func test_parse_args_accepts_positional_flow_and_step() -> void:
	var parsed: Dictionary = DumpFlowCoverageScript.parse_args(
			PackedStringArray(["ATTACK", "ATTACK_ROLL"]))
	assert_true(bool(parsed.get("ok", false)),
			"Positional flow/step arguments should parse.")
	assert_eq(int(parsed.get("flow_id", -1)),
			int(Constants.InteractionFlow.ATTACK),
			"Flow token should resolve to ATTACK.")
	assert_eq(int(parsed.get("step_id", -1)),
			int(Constants.InteractionStep.ATTACK_ROLL),
			"Step token should resolve to ATTACK_ROLL.")


func test_parse_args_accepts_named_flow_and_step() -> void:
	var parsed: Dictionary = DumpFlowCoverageScript.parse_args(
			PackedStringArray(["--flow", "SHIP_ACTIVATION",
					"--step", "REPAIR_STEP"]))
	assert_true(bool(parsed.get("ok", false)),
			"Named flow/step arguments should parse.")
	assert_eq(int(parsed.get("flow_id", -1)),
			int(Constants.InteractionFlow.SHIP_ACTIVATION),
			"Named flow should resolve to SHIP_ACTIVATION.")
	assert_eq(int(parsed.get("step_id", -1)),
			int(Constants.InteractionStep.REPAIR_STEP),
			"Named step should resolve to REPAIR_STEP.")


func test_build_report_includes_flowspec_metadata() -> void:
	var lines: PackedStringArray = DumpFlowCoverageScript.build_report(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL)
	assert_true(_has_line(lines, "Flow Coverage: ATTACK / ATTACK_ROLL"),
			"Report should name the requested FlowSpec pair.")
	assert_true(_has_line(lines, "controller_role: ATTACKER"),
			"Report should include controller-role metadata.")
	assert_true(_has_line(lines,
			"allowed_commands: roll_dice, publish_attack_flow, skip_attack"),
			"Report should include allowed command metadata.")


func test_build_report_includes_registered_rule_hooks() -> void:
	RuleRegistry.register_modifier(FlowHook.modifier("z_rule",
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"dice_pool", Callable(), 5))
	RuleRegistry.register_modifier(FlowHook.modifier("a_rule",
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			"dice_pool", Callable(), 10))
	var lines: PackedStringArray = DumpFlowCoverageScript.build_report(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL)
	assert_true(_has_line(lines, "registered_rule_hooks: 2"),
			"Report should include the registered hook count.")
	assert_lt(_line_index(lines, "a_rule"), _line_index(lines, "z_rule"),
			"Rule hooks should be listed in deterministic registry order.")
	assert_true(_has_line(lines,
			"  - MODIFIER a_rule priority=10 target=dice_pool"),
			"Report should include hook kind, id, priority, and target.")


func test_build_report_invalid_pair_returns_diagnostic() -> void:
	var lines: PackedStringArray = DumpFlowCoverageScript.build_report(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.WAIT_FOR_SHIP_SELECT)
	assert_true(_has_line(lines,
			"No FlowSpec metadata registered for this pair."),
			"Invalid pairs should produce a useful diagnostic.")


func _has_line(lines: PackedStringArray, expected: String) -> bool:
	for line: String in lines:
		if line == expected:
			return true
	return false


func _line_index(lines: PackedStringArray, needle: String) -> int:
	for line_index: int in range(lines.size()):
		if lines[line_index].contains(needle):
			return line_index
	return -1
