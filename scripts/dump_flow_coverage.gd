## Dump Flow Coverage
##
## Headless Phase M debugging aid. Given an interaction flow and step, it
## reports the FlowSpec metadata plus the registered RuleRegistry hooks that
## can run on that surface.
extends MainLoop


const FlowSpecScript: GDScript = preload("res://src/core/state/flow_spec.gd")
const RuleBootstrapScript: GDScript = preload(
		"res://src/autoload/rule_bootstrap.gd")

const KEY_OK: String = "ok"
const KEY_HELP: String = "help"
const KEY_REASON: String = "reason"
const KEY_FLOW_ID: String = "flow_id"
const KEY_STEP_ID: String = "step_id"
const KEY_FLOW_TOKEN: String = "flow_token"
const KEY_STEP_TOKEN: String = "step_token"

var _has_run: bool = false


func _process(_delta: float) -> bool:
	if not _has_run:
		_has_run = true
		run_cli(OS.get_cmdline_user_args())
	return true


## Runs the command-line tool with [param args] and returns a process exit code.
static func run_cli(args: PackedStringArray) -> int:
	var parsed: Dictionary = parse_args(args)
	if bool(parsed.get(KEY_HELP, false)):
		_emit_lines(usage_lines())
		return 0
	if not bool(parsed.get(KEY_OK, false)):
		_emit_lines(PackedStringArray([
				str(parsed.get(KEY_REASON, "Invalid arguments."))]))
		_emit_lines(usage_lines())
		return 1
	_ensure_rules_bootstrapped()
	var lines: PackedStringArray = build_report(
			int(parsed[KEY_FLOW_ID]), int(parsed[KEY_STEP_ID]))
	_emit_lines(lines)
	return 0 if FlowSpecScript.has_spec(
			int(parsed[KEY_FLOW_ID]), int(parsed[KEY_STEP_ID])) else 1


## Parses positional or named flow/step arguments into enum ids.
static func parse_args(args: PackedStringArray) -> Dictionary:
	var tokens: Array[String] = _arg_tokens(args)
	if tokens.is_empty() or tokens.has("--help") or tokens.has("-h"):
		return {KEY_OK: false, KEY_HELP: true}
	var pair: Dictionary = _extract_pair_tokens(tokens)
	if str(pair.get(KEY_REASON, "")) != "":
		return _parse_error(str(pair[KEY_REASON]))
	return _resolve_pair(str(pair[KEY_FLOW_TOKEN]), str(pair[KEY_STEP_TOKEN]))


## Builds the coverage report for a registered FlowSpec pair.
static func build_report(flow_id: int, step_id: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Flow Coverage: %s / %s" % [
			_enum_name(Constants.InteractionFlow, flow_id),
			_enum_name(Constants.InteractionStep, step_id),
	])
	if not FlowSpecScript.has_spec(flow_id, step_id):
		lines.append("No FlowSpec metadata registered for this pair.")
		return lines
	_append_spec_lines(lines, FlowSpecScript.get_spec(flow_id, step_id))
	_append_rule_lines(lines, RuleRegistry.hooks_for_step(flow_id, step_id))
	return lines


## Returns usage text for the headless script.
static func usage_lines() -> PackedStringArray:
	return PackedStringArray([
		"Usage:",
		"  godot --headless --path . -s scripts/dump_flow_coverage.gd -- ATTACK ATTACK_ROLL",
		"  godot --headless --path . -s scripts/dump_flow_coverage.gd -- --flow ATTACK --step ATTACK_ROLL",
	])


static func _ensure_rules_bootstrapped() -> void:
	if RuleRegistry.registered_hook_count() > 0:
		return
	var bootstrap: Node = RuleBootstrapScript.new()
	bootstrap.bootstrap_rules()
	bootstrap.free()


static func _arg_tokens(args: PackedStringArray) -> Array[String]:
	var tokens: Array[String] = []
	for arg: String in args:
		if arg.strip_edges() != "" and arg != "--":
			tokens.append(arg.strip_edges())
	return tokens


static func _extract_pair_tokens(tokens: Array[String]) -> Dictionary:
	var flow_token: String = ""
	var step_token: String = ""
	var positionals: Array[String] = []
	var index: int = 0
	while index < tokens.size():
		var consumed: Dictionary = _consume_named_arg(tokens, index)
		if str(consumed.get(KEY_REASON, "")) != "":
			return consumed
		if bool(consumed.get(KEY_OK, false)):
			flow_token = str(consumed.get(KEY_FLOW_TOKEN, flow_token))
			step_token = str(consumed.get(KEY_STEP_TOKEN, step_token))
			index = int(consumed.get("next", index + 1))
		else:
			positionals.append(tokens[index])
			index += 1
	return _merge_pair_tokens(flow_token, step_token, positionals)


static func _consume_named_arg(tokens: Array[String], index: int) -> Dictionary:
	var token: String = tokens[index]
	if not ["--flow", "-f", "--step", "-s"].has(token):
		return {KEY_OK: false}
	if index + 1 >= tokens.size():
		return {KEY_OK: false, KEY_REASON: "Missing value for %s." % token}
	var result: Dictionary = {KEY_OK: true, "next": index + 2}
	if token == "--flow" or token == "-f":
		result[KEY_FLOW_TOKEN] = tokens[index + 1]
	else:
		result[KEY_STEP_TOKEN] = tokens[index + 1]
	return result


static func _merge_pair_tokens(flow_token: String,
		step_token: String,
		positionals: Array[String]) -> Dictionary:
	if positionals.size() > 2:
		return {KEY_REASON: "Expected only flow and step arguments."}
	if flow_token == "" and positionals.size() >= 1:
		flow_token = positionals[0]
	if step_token == "" and positionals.size() >= 2:
		step_token = positionals[1]
	if flow_token == "" or step_token == "":
		return {KEY_REASON: "Both flow and step are required."}
	return {KEY_FLOW_TOKEN: flow_token, KEY_STEP_TOKEN: step_token}


static func _resolve_pair(flow_token: String, step_token: String) -> Dictionary:
	var flow_id: int = _enum_value(Constants.InteractionFlow, flow_token)
	var step_id: int = _enum_value(Constants.InteractionStep, step_token)
	if flow_id < 0:
		return _parse_error("Unknown flow '%s'." % flow_token)
	if step_id < 0:
		return _parse_error("Unknown step '%s'." % step_token)
	return {KEY_OK: true, KEY_FLOW_ID: flow_id, KEY_STEP_ID: step_id}


static func _parse_error(reason: String) -> Dictionary:
	return {KEY_OK: false, KEY_HELP: false, KEY_REASON: reason}


static func _append_spec_lines(lines: PackedStringArray,
		spec: Dictionary) -> void:
	lines.append("source: %s" % str(spec.get("source", "")))
	lines.append("controller_role: %s" % _enum_name(
			Constants.ControllerRole, int(spec.get("controller_role", 0))))
	lines.append("modals: %s" % _format_enum_list(
			Constants.ModalKind, spec.get("modals", [])))
	lines.append("allowed_commands: %s" % _format_string_list(
			spec.get("allowed_commands", [])))
	lines.append("transitions: %s" % _format_transitions(
			spec.get("transitions", {})))
	lines.append("rule_citation: %s" % str(spec.get("rule_citation", "")))


static func _append_rule_lines(lines: PackedStringArray,
		hooks: Array[FlowHook]) -> void:
	lines.append("registered_rule_hooks: %d" % hooks.size())
	if hooks.is_empty():
		lines.append("  (none)")
		return
	for hook: FlowHook in hooks:
		lines.append(_hook_line(hook))


static func _hook_line(hook: FlowHook) -> String:
	return "  - %s %s priority=%d %s" % [
			_enum_name(FlowHook.HookKind, int(hook.kind)),
			hook.rule_id,
			hook.priority,
			_hook_surface(hook),
	]


static func _hook_surface(hook: FlowHook) -> String:
	match hook.kind:
		FlowHook.HookKind.VALIDATOR, FlowHook.HookKind.OBSERVER:
			return "command=%s" % hook.command_type
		_:
			return "target=%s" % hook.target


static func _format_enum_list(enum_map: Dictionary, values: Array) -> String:
	if values.is_empty():
		return "(none)"
	var names: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		names.append(_enum_name(enum_map, int(value)))
	return ", ".join(names)


static func _format_string_list(values: Array) -> String:
	if values.is_empty():
		return "(none)"
	var parts: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		parts.append(str(value))
	return ", ".join(parts)


static func _format_transitions(transitions: Dictionary) -> String:
	if transitions.is_empty():
		return "(none)"
	var keys: Array = transitions.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for key: Variant in keys:
		parts.append("%s -> %s" % [str(key), str(transitions[key])])
	return ", ".join(parts)


static func _enum_value(enum_map: Dictionary, token: String) -> int:
	var normalized: String = token.strip_edges().to_upper()
	if normalized.is_valid_int():
		return int(normalized)
	if enum_map.has(normalized):
		return int(enum_map[normalized])
	return -1


static func _enum_name(enum_map: Dictionary, value: int) -> String:
	var found: Variant = enum_map.find_key(value)
	if found == null:
		return str(value)
	return str(found)


static func _emit_lines(lines: PackedStringArray) -> void:
	var output: FileAccess = FileAccess.open("/dev/stdout", FileAccess.WRITE)
	if output != null:
		_write_stdout_lines(output, lines)
		return
	var fallback_log: GameLogger = GameLogger.new("FlowCoverage")
	for line: String in lines:
		fallback_log.info(line)


static func _write_stdout_lines(output: FileAccess,
		lines: PackedStringArray) -> void:
	for line: String in lines:
		output.store_line(line)
	output.flush()
	output.close()
