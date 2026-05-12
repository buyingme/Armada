## BaselineTrace
##
## Phase L0.5 — Baseline trace harness for the L1–L5 modal-lifecycle
## migration.  Subscribes to [signal CommandProcessor.command_executed]
## and writes a canonicalised JSON-Lines projection of
## [code](seq, command_type, flow.flow_type, flow.step_id,
## flow.controller_player)[/code] tuples to
## [code]<PathConfig.LOGS_DIR>/baseline_trace_<mode>_<role>.jsonl[/code].
##
## The output is the regression oracle for Phase L: each slice re-runs
## a fixed scenario (Learning Scenario rounds 1–2) and diffs the trace
## against the baseline committed under [code]tests/fixtures/baseline_traces/[/code].
## Non-trivial divergence (different command sequence, different flow
## projection per executed command) is a hard block on the slice.
##
## Activation: this autoload only writes when [member LoggingMode.enabled]
## is true (i.e. the [code]--logging[/code] CLI flag is passed).  In all
## other sessions it is inert.  No production code path consults it.
##
## Plan reference: [docs/refactoring_phase_lm_plan.md §4.1 L0.5].
extends Node


## Output filename pattern: see class doc above.
const FILENAME_FORMAT: String = "baseline_trace_%s_%s.jsonl"

## Trace format version. Bump only when the per-record schema changes.
const FORMAT_VERSION: int = 1

## Logger instance.
var _log: GameLogger = GameLogger.new("BaselineTrace")

## Absolute filesystem path of the trace file for this session
## (empty when [member LoggingMode.enabled] is false).
var _trace_file_path: String = ""

## Open file handle. Null when tracing is inactive.
var _file: FileAccess = null

## Whether the header line has been written yet.
var _header_written: bool = false

## When non-empty, overrides the auto-derived
## [code]<LOGS_DIR>/baseline_trace_<mode>_<role>.jsonl[/code] path.
## Set by [ReplayDriver] when invoked with [code]--baseline-output[/code]
## so the trace file lands at the location the calling shell script
## expects. Cleared after use.
var output_path_override: String = ""

## Whether [signal CommandProcessor.command_executed] has been
## subscribed.  Distinct from [member _file] != null so we can
## subscribe early (during [method _ready]) but defer file-open
## until the first command (when PlayMode / NetworkManager have
## settled — see [method _maybe_enable] doc comment).
var _connected: bool = false


func _ready() -> void:
	# The autoload is loaded unconditionally, but only opens a file
	# when --logging is active.  Defer connection until LoggingMode has
	# finished its own _ready (it parses the same CLI flag).
	call_deferred("_maybe_enable")


## Activates tracing if [member LoggingMode.enabled] is true.
## Idempotent; safe to call repeatedly.
##
## Live play note: this method is called once from [method _ready]'s
## deferred kick, but at that point [PlayMode] and [NetworkManager]
## are still in their pre-handshake state (HOT_SEAT / not host) — the
## user has not yet clicked "Host Game" or "Join Game" in the main
## menu.  Opening the file here would write all sessions to
## [code]baseline_trace_hot_seat_solo.jsonl[/code] and the two GUI
## instances in [code]run_network_test.sh --gui-host[/code] would
## clobber each other.  So we connect the signal but defer the
## actual file-open until [method _on_command_executed] sees its
## first command — by then [signal EventBus.game_started] has fired,
## [PlayMode] is settled, and each peer picks the right filename.
##
## [ReplayDriver] supplies [code]--baseline-output[/code] which makes
## the path explicit and immune to this timing issue, so the
## regression harness opens immediately and the captured trace lands
## at the requested path no matter when the first command arrives.
func _maybe_enable() -> void:
	if not LoggingMode.enabled:
		return
	if _connected:
		return
	CommandProcessor.command_executed.connect(_on_command_executed)
	_connected = true
	# Eager open only when an output path is supplied (replay driver
	# path).  Live-play sessions defer until first command.
	if not output_path_override.is_empty() and _file == null:
		_open_trace_file()


## Opens the per-session trace file under [PathConfig.LOGS_DIR].
## Names the file after the active deployment mode and role so the
## same scenario produces three distinct fixtures (hot-seat, network
## host, network client).
func _open_trace_file() -> void:
	if output_path_override.is_empty():
		var dir_path: String = PathConfig.LOGS_DIR
		DirAccess.make_dir_recursive_absolute(dir_path)
		var mode_str: String = _mode_string()
		var role_str: String = _role_string()
		_trace_file_path = "%s/%s" % [
				dir_path,
				FILENAME_FORMAT % [mode_str, role_str],
		]
	else:
		_trace_file_path = output_path_override
		var parent_dir: String = _trace_file_path.get_base_dir()
		if not parent_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(parent_dir)
	_file = FileAccess.open(_trace_file_path, FileAccess.WRITE)
	if _file == null:
		_log.warn("BaselineTrace: could not open %s" % _trace_file_path)
		return
	_log.info("BaselineTrace: writing %s" % _trace_file_path)


## Flushes any pending data and closes the trace file.
## Called by [ReplayDriver] before quitting to ensure the trace is
## fully durable on disk before the process exits.  Idempotent.
func flush_and_close() -> void:
	if _file == null:
		return
	_file.flush()
	_file.close()
	_file = null


## Returns the deployment mode label used in the output filename:
## [code]"hot_seat"[/code] or [code]"network"[/code].
func _mode_string() -> String:
	if PlayMode.is_network():
		return "network"
	return "hot_seat"


## Returns the role label used in the output filename:
## [code]"host"[/code], [code]"client"[/code], or [code]"solo"[/code]
## (the last for hot-seat — there is only one process).
func _role_string() -> String:
	if not PlayMode.is_network():
		return "solo"
	if NetworkManager.is_server():
		return "host"
	return "client"


## Subscriber for [signal CommandProcessor.command_executed].
## Writes one JSON-Lines record per executed command.  Reads the
## post-execute snapshot of [member GameState.interaction_flow] from
## [member GameManager.current_game_state] (it has already been
## mutated by [method GameCommand.execute]).
func _on_command_executed(command: GameCommand, _result: Dictionary) -> void:
	# Live-play deferred open — see [method _maybe_enable] doc.  By
	# the time the first command executes, PlayMode is settled and
	# each peer picks its correct filename (host / client / solo).
	if _file == null:
		_open_trace_file()
	if _file == null:
		return
	if not _header_written:
		_write_header()
		_header_written = true
	var record: Dictionary = build_record(command,
			GameManager.current_game_state)
	_file.store_line(JSON.stringify(record))
	_file.flush()


## Writes the format-version header line.  Separate so unit tests can
## assert the schema without spinning up [CommandProcessor].
func _write_header() -> void:
	var header: Dictionary = {
			"_header": true,
			"format_version": FORMAT_VERSION,
			"mode": _mode_string(),
			"role": _role_string(),
	}
	_file.store_line(JSON.stringify(header))
	_file.flush()


## Builds the canonicalised record for one executed command.
##
## Exposed as a pure function so [test_baseline_trace_format.gd] can
## verify the schema without filesystem or autoload setup.  The output
## keys are stable; new keys must be added at the end of the schema
## comment block in the trace file's header.
##
## Schema:
##   seq:                int (-1 if the command had no sequence)
##   command_type:       String
##   flow_flow_type:     int (Constants.InteractionFlow enum value)
##   flow_step_id:       int (Constants.InteractionStep enum value)
##   flow_controller:    int (player index, -1 if no controller)
static func build_record(command: GameCommand,
		state: GameState) -> Dictionary:
	var seq: int = -1
	var cmd_type: String = ""
	if command != null:
		seq = command.sequence
		cmd_type = command.command_type
	var flow_type: int = Constants.InteractionFlow.NONE
	var step_id: int = Constants.InteractionStep.NONE
	var controller: int = -1
	if state != null and state.interaction_flow != null:
		flow_type = state.interaction_flow.flow_type
		step_id = state.interaction_flow.step_id
		controller = state.interaction_flow.controller_player
	return {
			"seq": seq,
			"command_type": cmd_type,
			"flow_flow_type": int(flow_type),
			"flow_step_id": int(step_id),
			"flow_controller": controller,
	}
