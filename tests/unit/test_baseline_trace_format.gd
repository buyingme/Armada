## Test: BaselineTrace JSONL schema
##
## Phase L0.5 — verifies the [code]BaselineTrace.build_record[/code]
## pure-function produces the canonical schema documented in
## [src/autoload/baseline_trace.gd].  This is the contract the
## L1–L5 oracle diffs rely on; breaking it must require an
## explicit schema-version bump.
##
## Plan reference: [docs/refactoring_phase_lm_plan.md §4.1 L0.5].
extends GutTest


const BaselineTraceScript := preload(
		"res://src/autoload/baseline_trace.gd")

const SCHEMA_KEYS: Array[String] = [
	"seq",
	"command_type",
	"flow_flow_type",
	"flow_step_id",
	"flow_controller",
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


## Builds a no-side-effect [GameCommand] stand-in carrying just the
## fields [code]build_record[/code] reads (seq + command_type).  Avoids
## subclassing real command types that pull in validation pipelines.
func _make_command(seq: int, cmd_type: String) -> GameCommand:
	var cmd: GameCommand = GameCommand.new()
	cmd.sequence = seq
	cmd.command_type = cmd_type
	return cmd


## Builds a minimal [GameState] with an [InteractionFlow] in a known
## projection.  Mirrors how the runtime mutates flow before
## [signal CommandProcessor.command_executed] fires.
func _make_state(flow_type: int, step_id: int,
		controller: int) -> GameState:
	var state: GameState = GameState.new()
	state.interaction_flow = InteractionFlow.new()
	state.interaction_flow.flow_type = flow_type as Constants.InteractionFlow
	state.interaction_flow.step_id = step_id as Constants.InteractionStep
	state.interaction_flow.controller_player = controller
	return state


# ---------------------------------------------------------------------------
# Schema tests
# ---------------------------------------------------------------------------


func test_build_record_returns_all_schema_keys() -> void:
	var cmd: GameCommand = _make_command(7, "advance_phase")
	var state: GameState = _make_state(
			Constants.InteractionFlow.NONE,
			Constants.InteractionStep.NONE,
			-1)
	var record: Dictionary = BaselineTraceScript.build_record(cmd, state)
	for key: String in SCHEMA_KEYS:
		assert_true(record.has(key),
				"Record missing required schema key '%s'" % key)
	assert_eq(record.size(), SCHEMA_KEYS.size(),
			"Record has unexpected extra keys: %s" % str(record.keys()))


func test_build_record_captures_command_fields() -> void:
	var cmd: GameCommand = _make_command(42, "spend_defense_token")
	var state: GameState = _make_state(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			1)
	var record: Dictionary = BaselineTraceScript.build_record(cmd, state)
	assert_eq(record["seq"], 42, "seq should round-trip")
	assert_eq(record["command_type"], "spend_defense_token",
			"command_type should round-trip")


func test_build_record_captures_flow_fields() -> void:
	var cmd: GameCommand = _make_command(1, "publish_attack_flow")
	var state: GameState = _make_state(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DECLARE,
			0)
	var record: Dictionary = BaselineTraceScript.build_record(cmd, state)
	assert_eq(record["flow_flow_type"],
			int(Constants.InteractionFlow.ATTACK),
			"flow_flow_type should match interaction_flow.flow_type")
	assert_eq(record["flow_step_id"],
			int(Constants.InteractionStep.ATTACK_DECLARE),
			"flow_step_id should match interaction_flow.step_id")
	assert_eq(record["flow_controller"], 0,
			"flow_controller should match interaction_flow.controller_player")


func test_build_record_handles_null_command() -> void:
	var state: GameState = _make_state(
			Constants.InteractionFlow.NONE,
			Constants.InteractionStep.NONE,
			-1)
	var record: Dictionary = BaselineTraceScript.build_record(null, state)
	assert_eq(record["seq"], -1, "Null command should produce seq=-1")
	assert_eq(record["command_type"], "",
			"Null command should produce empty command_type")


func test_build_record_handles_null_state() -> void:
	var cmd: GameCommand = _make_command(3, "advance_phase")
	var record: Dictionary = BaselineTraceScript.build_record(cmd, null)
	assert_eq(record["flow_flow_type"],
			int(Constants.InteractionFlow.NONE),
			"Null state should yield InteractionFlow.NONE")
	assert_eq(record["flow_step_id"],
			int(Constants.InteractionStep.NONE),
			"Null state should yield InteractionStep.NONE")
	assert_eq(record["flow_controller"], -1,
			"Null state should yield controller=-1")


func test_build_record_handles_null_interaction_flow() -> void:
	var cmd: GameCommand = _make_command(5, "advance_phase")
	var state: GameState = GameState.new()
	state.interaction_flow = null
	var record: Dictionary = BaselineTraceScript.build_record(cmd, state)
	assert_eq(record["flow_flow_type"],
			int(Constants.InteractionFlow.NONE),
			"Null interaction_flow should yield InteractionFlow.NONE")
	assert_eq(record["flow_step_id"],
			int(Constants.InteractionStep.NONE),
			"Null interaction_flow should yield InteractionStep.NONE")
	assert_eq(record["flow_controller"], -1,
			"Null interaction_flow should yield controller=-1")


# ---------------------------------------------------------------------------
# JSON round-trip
# ---------------------------------------------------------------------------


## Records must survive a JSON.stringify → JSON.parse_string round-trip
## without loss so that the diff oracle can canonicalise on either side.
func test_record_round_trips_through_json() -> void:
	var cmd: GameCommand = _make_command(11, "select_evade_die")
	var state: GameState = _make_state(
			Constants.InteractionFlow.ATTACK,
			Constants.InteractionStep.ATTACK_DEFENSE_TOKENS,
			1)
	var record: Dictionary = BaselineTraceScript.build_record(cmd, state)
	var line: String = JSON.stringify(record)
	var parsed: Variant = JSON.parse_string(line)
	assert_typeof(parsed, TYPE_DICTIONARY,
			"JSON round-trip should yield a dictionary")
	var dict: Dictionary = parsed as Dictionary
	for key: String in SCHEMA_KEYS:
		assert_true(dict.has(key),
				"Round-tripped record missing key '%s'" % key)
	assert_eq(dict["command_type"], "select_evade_die",
			"command_type should survive JSON round-trip")
	assert_eq(int(dict["seq"]), 11,
			"seq should survive JSON round-trip")


# ---------------------------------------------------------------------------
# Final-state hash canonicalisation
# ---------------------------------------------------------------------------


func test_canonical_json_sorts_dictionary_keys_recursively() -> void:
	var left: Dictionary = {
		"b": 2,
		"a": {"d": 4, "c": 3},
		"items": [ {"z": 1, "y": 2}],
	}
	var right: Dictionary = {
		"items": [ {"y": 2, "z": 1}],
		"a": {"c": 3, "d": 4},
		"b": 2,
	}
	var left_json: String = CanonicalJson.stringify(left)
	var right_json: String = CanonicalJson.stringify(right)
	assert_eq(left_json, right_json,
			"Canonical JSON should ignore dictionary insertion order")


func test_canonical_json_preserves_array_order() -> void:
	var first: Dictionary = {"items": [1, 2, 3]}
	var second: Dictionary = {"items": [3, 2, 1]}
	var first_json: String = CanonicalJson.stringify(first)
	var second_json: String = CanonicalJson.stringify(second)
	assert_ne(first_json, second_json,
			"Canonical JSON should preserve array ordering")
