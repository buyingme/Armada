## ReplayDriver
##
## Phase L0.5b — Automated replay player.  When the game is launched
## with [code]--replay <path>[/code], this autoload loads the supplied
## [GameReplay] file, forces [member LoggingMode.enabled] /
## [BaselineTrace] on, drives the recorded commands through
## [CommandProcessor.submit] one-at-a-time, and quits the process when
## the replay is exhausted.  The resulting per-process baseline-trace
## JSONL file is the regression oracle for the L1–L5 modal-lifecycle
## migration (see [docs/refactoring_phase_lm_plan.md §4.1a]).
##
## Hot-seat (this commit): single process runs the full replay locally.
## Network (Phase L0.5c): two processes run the same replay; each
## submits only the commands whose [code]player[/code] matches its own
## seat index, and the [signal CommandProcessor.command_executed] echo
## from the authoritative server provides the cross-process sync
## barrier.
##
## CLI flags (passed via [code]godot -- --flag value[/code]):
## [br]- [code]--replay <path>[/code]: path to a [GameReplay] JSON
##     file produced by [GameReplay.save_to_file].  Required to
##     activate the driver — without it this autoload is inert.
## [br]- [code]--baseline-output <path>[/code] (optional): destination
##     filename for the baseline-trace JSONL.  When omitted,
##     [BaselineTrace] uses its default
##     [code]<LOGS_DIR>/baseline_trace_<mode>_<role>.jsonl[/code].
## [br]- [code]--replay-step-timeout <ms>[/code] (optional, default
##     [constant DEFAULT_STEP_TIMEOUT_MS]): maximum time to wait for a
##     [signal CommandProcessor.command_executed] echo before failing
##     the run with exit code [constant EXIT_TIMEOUT].  Network sync
##     barrier only — hot-seat submits are synchronous.
##
## Activation contract: this autoload always loads (see
## [code]project.godot[/code] AutoLoad section), but
## [member enabled] is [code]false[/code] unless [code]--replay[/code]
## was passed.  All production code paths gating on
## [member ReplayDriver.enabled] / [member ReplayDriver.pending_replay_seed]
## are no-ops in normal sessions.
extends Node


## Default per-step timeout in milliseconds.  Only consulted in
## network mode where command_executed fires asynchronously.
const DEFAULT_STEP_TIMEOUT_MS: int = 5000

## Process exit code when the replay completes successfully.
const EXIT_OK: int = 0

## Process exit code when the replay file fails to load.
const EXIT_LOAD_FAIL: int = 2

## Process exit code when waiting for a [signal command_executed]
## echo exceeds the configured timeout.
const EXIT_TIMEOUT: int = 3

## Process exit code when a recorded command fails to deserialize
## (unknown command type, malformed payload).
const EXIT_DESERIALIZE_FAIL: int = 4


## Whether the driver was activated by a [code]--replay[/code] CLI flag.
## All production hooks (see [GameManager.bootstrap_game],
## [MainMenu._ready]) gate on this and are no-ops when [code]false[/code].
var enabled: bool = false

## RNG seed to inject into the next [GameManager.bootstrap_game] call.
## Pre-seeded from the replay file header.  Cleared on consumption so
## subsequent bootstraps revert to random seeding.  Hot-seat only —
## network seeding flows through the lobby game-config RPC.
var pending_replay_seed: int = 0

## Loaded replay payload.  Null until [method _ready] succeeds.
var _replay: GameReplay = null

## Index of the next command in [member _replay.commands] to process.
var _cursor: int = 0

## Running count of [signal CommandProcessor.command_executed] emits
## observed by the driver.  Used as the per-step sync barrier.
var _observed_count: int = 0

## Per-step timeout (ms).
var _step_timeout_ms: int = DEFAULT_STEP_TIMEOUT_MS

## Override destination passed via [code]--baseline-output[/code].
var _baseline_output: String = ""

## Logger.
var _log: GameLogger = GameLogger.new("ReplayDriver")


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var replay_path: String = _flag_value(args, "--replay")
	if replay_path.is_empty():
		return  # No --replay flag → autoload is inert.
	enabled = true
	_baseline_output = _flag_value(args, "--baseline-output")
	var timeout_str: String = _flag_value(args, "--replay-step-timeout")
	if not timeout_str.is_empty() and timeout_str.is_valid_int():
		_step_timeout_ms = timeout_str.to_int()
	_replay = GameReplay.load_from_file(replay_path)
	if _replay == null:
		_log.error("ReplayDriver: failed to load %s" % replay_path)
		_quit(EXIT_LOAD_FAIL)
		return
	_log.info("ReplayDriver: loaded %d commands from %s" % [
			_replay.commands.size(), replay_path])
	# Pre-seed the RNG and the trace output path before any scene
	# loads its first frame.
	pending_replay_seed = int(_replay.header.get("rng_seed", 0))
	LoggingMode.enabled = true
	BaselineTrace.output_path_override = _baseline_output
	BaselineTrace._maybe_enable()
	CommandProcessor.command_executed.connect(_on_command_executed)
	EventBus.game_started.connect(_on_game_started)


## Returns the value following [param flag] in [param args], or
## [code]""[/code] if the flag is absent or has no value.
##
## Exposed as a static-equivalent (read-only over args) so unit tests
## can assert the parsing without booting the autoload.
static func parse_flag(args: PackedStringArray, flag: String) -> String:
	for i: int in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return args[i + 1]
	return ""


## Instance wrapper around [method parse_flag] for the
## [code]_ready[/code] hot path.
func _flag_value(args: PackedStringArray, flag: String) -> String:
	return parse_flag(args, flag)


## Triggered after [GameManager.start_new_game] succeeds.  Kicks off
## the step loop on the next idle frame so the game-board scene has
## a chance to finish wiring its controllers before commands arrive.
func _on_game_started() -> void:
	call_deferred("_run_step_loop")


## Drives the recorded commands through [CommandProcessor.submit]
## one-at-a-time, waiting for the [signal CommandProcessor.command_executed]
## echo before advancing.  Quits the process when the replay is
## exhausted or a step times out.
func _run_step_loop() -> void:
	while _cursor < _replay.commands.size():
		var ok: bool = await _execute_step(_replay.commands[_cursor])
		if not ok:
			return  # _quit already called.
		_cursor += 1
	_log.info("ReplayDriver: replay exhausted (%d commands)." % _cursor)
	BaselineTrace.flush_and_close()
	_quit(EXIT_OK)


## Executes one recorded command.  Returns [code]true[/code] on
## success (command executed and observed), [code]false[/code] if the
## step failed and [method _quit] has been called.
func _execute_step(cmd_data: Dictionary) -> bool:
	var expected_count: int = _observed_count + 1
	var is_local: bool = _is_local_command(cmd_data)
	if is_local:
		var cmd: GameCommand = GameCommand.deserialize(cmd_data)
		if cmd == null:
			_log.error("ReplayDriver: deserialize failed: %s" % cmd_data)
			_quit(EXIT_DESERIALIZE_FAIL)
			return false
		CommandProcessor.submit(cmd)
	# Wait until we've observed the matching command_executed echo
	# (synchronous in hot-seat, async in network).  Hot-seat submits
	# usually complete before the await returns the first time, but
	# guard against missed-edge races by polling.
	var deadline_ms: int = Time.get_ticks_msec() + _step_timeout_ms
	while _observed_count < expected_count:
		if Time.get_ticks_msec() > deadline_ms:
			_log.error("ReplayDriver: timeout waiting for command_executed (cursor=%d)" % _cursor)
			_quit(EXIT_TIMEOUT)
			return false
		await get_tree().process_frame
	return true


## Returns whether this peer is responsible for submitting
## [param cmd_data].  In hot-seat every command is local; in network
## only those whose [code]player[/code] field matches the local seat.
func _is_local_command(cmd_data: Dictionary) -> bool:
	if not PlayMode.is_network():
		return true
	var local: int = NetworkManager.get_local_player_index()
	return int(cmd_data.get("player", -1)) == local


## Counts [signal CommandProcessor.command_executed] emissions.  The
## driver advances its cursor once the count reaches the value it
## expected before submitting / waiting.
func _on_command_executed(_command: GameCommand,
		_result: Dictionary) -> void:
	_observed_count += 1


## Wrapper around [code]get_tree().quit(code)[/code] for testability.
func _quit(code: int) -> void:
	if not is_inside_tree():
		return
	get_tree().quit(code)
