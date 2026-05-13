## BaselineTrace
##
## Phase L0.5 - Baseline trace harness for the L1-L5 modal-lifecycle
## migration.  Subscribes to [signal CommandProcessor.command_executed]
## and writes a canonicalised JSON-Lines projection of
## [code](seq, command_type, flow.flow_type, flow.step_id,
## flow.controller_player)[/code] tuples to
## [code]<PathConfig.LOGS_DIR>/baseline_trace_<mode>_<role>.jsonl[/code].
##
## Hot-seat output is the per-command regression oracle for Phase L:
## each slice re-runs a fixed scenario (Learning Scenario rounds 1-2)
## and diffs the trace against the baseline committed under
## [code]tests/fixtures/baseline_traces/[/code].  Network output is a
## diagnostic trace only; network pass/fail uses host/client equality
## of the final-state hash written by [method write_final_state_hash],
## because real ENet RPC timing can produce different valid command
## interleavings.
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
## settled - see [method _maybe_enable] doc comment).
var _connected: bool = false

## Buffered records pending sort-and-flush.  Only populated when
## [member _buffered_mode] is true (replay-driver / regression
## harness path).  See [method flush_and_close].
var _buffered_records: Array[Dictionary] = []

## True when the trace must be sorted by [code]seq[/code] before
## being written.  Enabled when [member output_path_override] is
## non-empty (i.e. the regression harness drives this session) so
## that the network client's mix of locally-submitted commands and
## host broadcast-echoes, which arrive in non-deterministic order,
## still produces a canonical diagnostic trace.  Live-play sessions
## keep streaming writes (no [method flush_and_close] is called on
## window close, so buffering would lose the trace on crash).
var _buffered_mode: bool = false


func _ready() -> void:
	# The autoload is loaded unconditionally, but only opens a file
	# when --logging is active.  Defer connection until LoggingMode has
	# finished its own _ready (it parses the same CLI flag).
	call_deferred("_maybe_enable")


## Activates tracing if [member LoggingMode.enabled] is true.
## Idempotent; safe to call repeatedly.
##
## Live play defers file-open until the first command so PlayMode and
## NetworkManager have settled on the correct mode/role.  ReplayDriver
## passes [code]--baseline-output[/code], so harness sessions open eagerly
## at a known path.
##
## The live-play defer is intentional: during [method _ready], the main menu
## has not yet chosen hot-seat, host, or client. Opening here would label GUI
## network sessions as [code]hot_seat_solo[/code], and two logging processes
## could clobber the same file. By the first executed command, the game has
## started and each peer can choose the correct mode/role filename.
func _maybe_enable() -> void:
	if not LoggingMode.enabled:
		return
	if _connected:
		return
	CommandProcessor.command_executed.connect(_on_command_executed)
	_connected = true
	# Eager open only when an output path is supplied (replay driver
	# path).  Live-play sessions defer until first command.
	if not output_path_override.is_empty():
		_buffered_mode = true
		if _file == null:
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
##
## In [member _buffered_mode] (regression harness) the buffered
## records are sorted by [code]seq[/code] and written here. This
## hides the non-deterministic interleaving between the network
## client's locally-submitted commands and host broadcast-echoes.
func flush_and_close() -> void:
	if _file == null:
		return
	if _buffered_mode:
		_buffered_records.sort_custom(_record_seq_lt)
		for record: Dictionary in _buffered_records:
			_file.store_line(JSON.stringify(record))
		_buffered_records.clear()
	_file.flush()
	_file.close()
	_file = null


## Comparator for [method Array.sort_custom], ascending by
## [code]seq[/code].  Ties (which should not occur; sequence is
## monotonically assigned by [CommandProcessor]) compare as equal.
static func _record_seq_lt(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("seq", -1)) < int(b.get("seq", -1))


## Writes a canonical [param state] hash to
## [code]<trace_path>.state_hash[/code].  Hot-seat compares it to a
## committed fixture; network compares host/client hashes within a run.
## [method GameState.serialize] must not include timestamps, peer IDs,
## or per-process fields.
func write_final_state_hash(state: GameState) -> String:
	if state == null:
		_log.warn("BaselineTrace: write_final_state_hash called with null state")
		return ""
	if _trace_file_path.is_empty():
		return ""
	var canonical: String = _canonical_json(state.serialize())
	var hash_hex: String = canonical.sha256_text()
	var hash_path: String = _trace_file_path + ".state_hash"
	var f: FileAccess = FileAccess.open(hash_path, FileAccess.WRITE)
	if f == null:
		_log.warn("BaselineTrace: could not open %s" % hash_path)
		return hash_hex
	f.store_line(hash_hex)
	f.flush()
	f.close()
	_log.info("BaselineTrace: wrote state hash %s -> %s" % [
			hash_hex.substr(0, 12), hash_path])
	return hash_hex


## Serializes [param value] to JSON with dictionary keys sorted at every level.
static func _canonical_json(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort()
		var parts: PackedStringArray = PackedStringArray()
		for key: Variant in keys:
			parts.append("%s:%s" % [
					JSON.stringify(key),
					_canonical_json((value as Dictionary)[key]),
			])
		return "{" + ",".join(parts) + "}"
	if value is Array:
		var arr_parts: PackedStringArray = PackedStringArray()
		for item: Variant in (value as Array):
			arr_parts.append(_canonical_json(item))
		return "[" + ",".join(arr_parts) + "]"
	return JSON.stringify(value)


## Returns the deployment mode label used in the output filename:
## [code]"hot_seat"[/code] or [code]"network"[/code].
func _mode_string() -> String:
	if PlayMode.is_network():
		return "network"
	return "hot_seat"


## Returns the role label used in the output filename:
## [code]"host"[/code], [code]"client"[/code], or [code]"solo"[/code]
## (the last for hot-seat - there is only one process).
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
	# Live-play deferred open - see [method _maybe_enable] doc.  By
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
	if _buffered_mode:
		_buffered_records.append(record)
	else:
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
