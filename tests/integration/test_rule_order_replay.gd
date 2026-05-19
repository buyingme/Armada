## Test: Rule Order Replay Determinism
##
## Phase M13 guard for RuleRegistry observer ordering across command history
## serialization. Hooks that share a FlowSpec surface must execute by
## priority DESC, then rule_id ASC, so hot-seat replay capture and the
## network authority path drain the same generated follow-up sequence.
extends GutTest


const BaselineTraceScript: GDScript = preload(
		"res://src/autoload/baseline_trace.gd")
const CmdProcessor: GDScript = preload("res://src/autoload/command_processor.gd")

const ROOT_TYPE: String = "debug_deal_damage"
const ROOT_SOURCE: String = "root"
const FOLLOWUP_ALPHA_TYPE: String = "destroy_unit"
const FOLLOWUP_DELTA_TYPE: String = "publish_attack_flow"
const FOLLOWUP_ZETA_TYPE: String = "skip_attack"
const RULE_ALPHA: String = "rule.alpha"
const RULE_DELTA: String = "rule.delta"
const RULE_ZETA: String = "rule.zeta"

const EXPECTED_HOOK_ORDER: Array[String] = [
	RULE_ALPHA,
	RULE_DELTA,
	RULE_ZETA,
]
const EXPECTED_FOLLOWUP_TYPES: Array[String] = [
	FOLLOWUP_ALPHA_TYPE,
	FOLLOWUP_DELTA_TYPE,
	FOLLOWUP_ZETA_TYPE,
]
const EXPECTED_HISTORY_TYPES: Array[String] = [
	ROOT_TYPE,
	FOLLOWUP_ALPHA_TYPE,
	FOLLOWUP_DELTA_TYPE,
	FOLLOWUP_ZETA_TYPE,
]

var _saved_registry: Dictionary = {}
var _hook_followups: Array[Dictionary] = []


func before_each() -> void:
	_saved_registry = GameCommand._registry.duplicate()
	RuleRegistry.clear()
	_hook_followups.clear()


func after_each() -> void:
	RuleRegistry.clear()
	GameManager.current_game_state = null
	GameCommand._registry = _saved_registry
	_hook_followups.clear()


func test_observer_hooks_serialize_in_priority_rule_id_order() -> void:
	var run: Dictionary = _run_hot_seat_order_scenario()
	var hook_followups: Array = run.get("hook_followups", [])
	var executed_followups: Array = run.get("executed_followups", [])
	assert_eq(hook_followups.size(), 3,
			"Scenario should trigger at least three hooks in one step.")
	assert_eq(_hook_ids(hook_followups), EXPECTED_HOOK_ORDER,
			"Hooks should run by priority DESC, then rule_id ASC.")
	assert_eq(_command_types(hook_followups), EXPECTED_FOLLOWUP_TYPES,
			"Hook trace should record generated command types in order.")
	assert_eq(executed_followups, hook_followups,
			"Replay history should preserve observer-generated follow-up order.")


func test_replay_history_records_generated_followups_in_execution_order() -> void:
	var run: Dictionary = _run_hot_seat_order_scenario()
	var replay_data: Dictionary = run.get("replay", {})
	var replay: GameReplay = GameReplay.deserialize(replay_data)
	assert_not_null(replay,
			"Serialized order scenario should deserialize as a replay.")
	assert_eq(_history_types(replay.commands), EXPECTED_HISTORY_TYPES,
			"Replay commands should record root then sorted follow-ups.")
	assert_eq(_executed_followups(replay.commands),
			run.get("hook_followups", []),
			"Deserialized replay should retain hook/follow-up ordering.")


func test_hot_seat_rule_order_replay_is_byte_identical() -> void:
	var first: String = str(_run_hot_seat_order_scenario().get(
			"canonical_json", ""))
	var second: String = str(_run_hot_seat_order_scenario().get(
			"canonical_json", ""))
	assert_eq(first, second,
			"Repeated hot-seat runs should serialize byte-identical order data.")


func _run_hot_seat_order_scenario() -> Dictionary:
	_hook_followups.clear()
	RuleRegistry.clear()
	var processor: Node = CmdProcessor.new()
	add_child_autofree(processor)
	_register_test_commands()
	_register_order_observers()
	GameManager.current_game_state = _make_attack_roll_state()
	processor.submit(_OrderCommand.new(ROOT_TYPE, 0, {"source": ROOT_SOURCE}))
	var replay: GameReplay = _make_replay(processor.serialize_history())
	return _result_payload(replay)


func _make_attack_roll_state() -> GameState:
	var state: GameState = GameState.new()
	state.initialize()
	state.current_phase = Constants.GamePhase.SHIP
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			0)
	return state


func _register_test_commands() -> void:
	for command_type: String in EXPECTED_HISTORY_TYPES:
		GameCommand.register_type(command_type, func(p: int,
				pl: Dictionary) -> GameCommand:
			return _OrderCommand.new(command_type, p, pl))


func _register_order_observers() -> void:
	RuleRegistry.register_observer(_observer(
			RULE_ZETA, Callable(self , "_observer_zeta"), 10))
	RuleRegistry.register_observer(_observer(
			RULE_DELTA, Callable(self , "_observer_delta"), 30))
	RuleRegistry.register_observer(_observer(
			RULE_ALPHA, Callable(self , "_observer_alpha"), 30))


func _observer(rule_id: String,
		callback: Callable,
		priority: int) -> FlowHook:
	return FlowHook.observer(rule_id,
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_ROLL,
			ROOT_TYPE,
			callback,
			priority)


func _observer_alpha(_game_state: GameState,
		command: GameCommand,
		_result: Dictionary) -> Array[Dictionary]:
	return _make_followup(command, RULE_ALPHA, FOLLOWUP_ALPHA_TYPE)


func _observer_delta(_game_state: GameState,
		command: GameCommand,
		_result: Dictionary) -> Array[Dictionary]:
	return _make_followup(command, RULE_DELTA, FOLLOWUP_DELTA_TYPE)


func _observer_zeta(_game_state: GameState,
		command: GameCommand,
		_result: Dictionary) -> Array[Dictionary]:
	return _make_followup(command, RULE_ZETA, FOLLOWUP_ZETA_TYPE)


func _make_followup(command: GameCommand,
		rule_id: String,
		command_type: String) -> Array[Dictionary]:
	var followups: Array[Dictionary] = []
	if str(command.payload.get("source", "")) != ROOT_SOURCE:
		return followups
	_hook_followups.append({"hook_id": rule_id, "command_type": command_type})
	followups.append({
		"type": command_type,
		"player": command.player_index,
		"sequence": - 1,
		"payload": {"source": rule_id, "generated_by": rule_id},
	})
	return followups


func _make_replay(commands: Array[Dictionary]) -> GameReplay:
	var replay: GameReplay = GameReplay.new()
	replay.header = {
		"format_version": GameReplay.FORMAT_VERSION,
		"scenario_id": "rule_order_replay",
		"rng_seed": 130013,
		"factions": [
			int(Constants.Faction.REBEL_ALLIANCE),
			int(Constants.Faction.GALACTIC_EMPIRE),
		],
		"initiative_player": 0,
	}
	replay.set_commands(commands)
	return replay


func _result_payload(replay: GameReplay) -> Dictionary:
	var payload: Dictionary = {
		"hook_followups": _hook_followups.duplicate(true),
		"executed_followups": _executed_followups(replay.commands),
		"replay": replay.serialize(),
	}
	payload["canonical_json"] = BaselineTraceScript._canonical_json(payload)
	return payload


func _hook_ids(trace: Array) -> Array[String]:
	var ids: Array[String] = []
	for entry: Variant in trace:
		ids.append(str((entry as Dictionary).get("hook_id", "")))
	return ids


func _command_types(trace: Array) -> Array[String]:
	var types: Array[String] = []
	for entry: Variant in trace:
		types.append(str((entry as Dictionary).get("command_type", "")))
	return types


func _history_types(commands: Array[Dictionary]) -> Array[String]:
	var types: Array[String] = []
	for command: Dictionary in commands:
		types.append(str(command.get("type", "")))
	return types


func _executed_followups(commands: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i: int in range(1, commands.size()):
		var command: Dictionary = commands[i]
		var payload: Dictionary = command.get("payload", {})
		result.append({
			"hook_id": str(payload.get("generated_by", "")),
			"command_type": str(command.get("type", "")),
		})
	return result


class _OrderCommand extends GameCommand:
	func _init(p_type: String = ROOT_TYPE,
			p_player: int = 0,
			p_payload: Dictionary = {}) -> void:
		super._init(p_player, p_type, p_payload)

	func execute(_game_state: GameState) -> Dictionary:
		return {"ok": true, "source": payload.get("source", "")}
