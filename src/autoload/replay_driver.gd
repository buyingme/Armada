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

## Running count of [signal CommandProcessor.command_executed] emits
## observed by the driver.  Doubles as the cursor into
## [member _replay.commands] — see [method _run_step_loop].
var _observed_count: int = 0

## Per-step timeout (ms).
var _step_timeout_ms: int = DEFAULT_STEP_TIMEOUT_MS

## Override destination passed via [code]--baseline-output[/code].
var _baseline_output: String = ""

## Host:port string passed via [code]--connect[/code] (network client only).
var _connect_target: String = ""

## Whether the host has already triggered [method LobbyManager.request_start_game]
## (one-shot — repeated lobby-updated signals are ignored after).
var _host_started: bool = false

## Logger.
var _log: GameLogger = GameLogger.new("ReplayDriver")


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var replay_path: String = _flag_value(args, "--replay")
	if replay_path.is_empty():
		return  # No --replay flag → autoload is inert.
	enabled = true
	_baseline_output = _flag_value(args, "--baseline-output")
	_connect_target = _flag_value(args, "--connect")
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
	# loads its first frame.  Network host receives its seed via the
	# lobby game-config RPC, so only hot-seat consumes
	# pending_replay_seed (see GameManager.bootstrap_game).
	pending_replay_seed = int(_replay.header.get("rng_seed", 0))
	LoggingMode.enabled = true
	BaselineTrace.output_path_override = _baseline_output
	BaselineTrace._maybe_enable()
	CommandProcessor.command_executed.connect(_on_command_executed)
	CommandProcessor.command_rejected.connect(_on_command_rejected)
	EventBus.game_started.connect(_on_game_started)
	# Network client: kick off connect once everything is wired.
	if not _connect_target.is_empty():
		call_deferred("_start_network_client")
	# Network host: ServerMain already calls NetworkManager.host() on
	# --server, but the lobby auto-bootstrap (create lobby + ready +
	# start game) is driven from here.  See _start_network_host.
	if _is_server_session():
		call_deferred("_start_network_host")


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


## Returns whether the [code]--server[/code] CLI flag is set on either
## the engine-args side or the user-args side.  Used to decide whether
## to bootstrap the host lobby on replay start.
func _is_server_session() -> bool:
	for arg: String in OS.get_cmdline_args():
		if arg == "--server":
			return true
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--server":
			return true
	return false


## Instance wrapper around [method parse_flag] for the
## [code]_ready[/code] hot path.
func _flag_value(args: PackedStringArray, flag: String) -> String:
	return parse_flag(args, flag)


## Triggered after [GameManager.start_new_game] succeeds.  Kicks off
## the step loop on the next idle frame so the game-board scene has
## a chance to finish wiring its controllers before commands arrive.
func _on_game_started() -> void:
	call_deferred("_run_step_loop")


## Drives the recorded commands.  The board's scenario setup
## auto-submits a small prefix (start_round + round-1 dial assignments
## + advance to Ship Phase via [code]GameManager.apply_fixed_round1_commands[/code]),
## so the loop reads [member _observed_count] as a global cursor:
## the next command to drive is always [code]replay.commands[_observed_count][/code].
## Auto-submitted prefix commands are simply observed and the cursor
## advances past them without an explicit submit.
##
## In network mode the cursor advances on remote echoes too — only
## commands whose [code]player[/code] field matches the local seat
## are submitted by this peer; the rest are awaited as broadcasts.
func _run_step_loop() -> void:
	# Settle phase — give auto-submitted scenario-setup commands and
	# any remote game-start commands one frame to fire before we
	# inspect the cursor.
	await get_tree().process_frame
	while _observed_count < _replay.commands.size():
		var cmd_data: Dictionary = _replay.commands[_observed_count]
		var ok: bool = await _execute_step(cmd_data)
		if not ok:
			return  # _quit already called.
	_log.info("ReplayDriver: replay exhausted (%d commands)." %
			_observed_count)
	BaselineTrace.flush_and_close()
	_quit(EXIT_OK)


## Executes one cursor position.  If the command at the current
## cursor is the local peer's responsibility, attempts a submit (but
## skips if the auto-flow already fired one in the meantime).  Then
## waits for [signal CommandProcessor.command_executed] to advance
## the cursor.  Returns [code]false[/code] iff the step failed and
## [method _quit] has been called.
func _execute_step(cmd_data: Dictionary) -> bool:
	var snapshot: int = _observed_count
	var is_local: bool = _is_local_command(cmd_data)
	if is_local:
		# Give the running auto-flow / inbound RPC one extra frame to
		# fire so we don't double-submit a prefix command.
		await get_tree().process_frame
		if _observed_count > snapshot:
			return true  # auto-flow / remote already advanced the cursor.
		var cmd: GameCommand = GameCommand.deserialize(cmd_data)
		if cmd == null:
			_log.error("ReplayDriver: deserialize failed: %s" % cmd_data)
			_quit(EXIT_DESERIALIZE_FAIL)
			return false
		CommandProcessor.submit(cmd)
	# Wait for the cursor to advance past `snapshot` — either via
	# the submit above (hot-seat: synchronous), an auto-flow firing,
	# or a remote broadcast echo (network).
	var deadline_ms: int = Time.get_ticks_msec() + _step_timeout_ms
	while _observed_count <= snapshot:
		if Time.get_ticks_msec() > deadline_ms:
			_log.error(
					"ReplayDriver: timeout waiting for command_executed "
					+ "(cursor=%d, type=%s, is_local=%s)"
					% [snapshot, str(cmd_data.get("type", "?")),
					str(is_local)])
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
## driver advances its cursor by reading this counter (it equals the
## next replay-file index to process).
func _on_command_executed(_command: GameCommand,
		_result: Dictionary) -> void:
	_observed_count += 1


## Surfaces validation rejections during replay.  These are usually
## benign (auto-flow already fired the same command from a different
## site), but log them so a regression is visible in the run log.
func _on_command_rejected(command: GameCommand, reason: String) -> void:
	_log.warn("ReplayDriver: rejected [%s] seq=%d: %s" % [
			command.command_type, command.sequence, reason])


# ---------------------------------------------------------------------------
# Network orchestration (Phase L0.5c)
# ---------------------------------------------------------------------------

## Network client entry point — connects to the running host, drives
## the lobby ready handshake, and waits for the game-start broadcast.
## The step loop then runs on [signal EventBus.game_started] like in
## hot-seat.
func _start_network_client() -> void:
	var host: String = _connect_host()
	var port: int = _connect_port()
	if host.is_empty() or port <= 0:
		_log.error("ReplayDriver: malformed --connect '%s'" % _connect_target)
		_quit(EXIT_LOAD_FAIL)
		return
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	# Ready the lobby once authentication completes.
	NetworkManager.handshake_accepted.connect(
			_on_client_handshake_accepted, CONNECT_ONE_SHOT)
	if not NetworkManager.connect_to_server(host, port):
		_log.error("ReplayDriver: connect_to_server failed (%s:%d)" % [
				host, port])
		_quit(EXIT_LOAD_FAIL)


## Returns the host portion of [member _connect_target] (e.g.
## [code]"127.0.0.1"[/code] from [code]"127.0.0.1:7350"[/code]).
func _connect_host() -> String:
	var idx: int = _connect_target.rfind(":")
	if idx <= 0:
		return _connect_target  # no port supplied — caller will use default
	return _connect_target.substr(0, idx)


## Returns the port portion of [member _connect_target] (default
## [constant ServerMain.DEFAULT_PORT] when unspecified).
func _connect_port() -> int:
	var idx: int = _connect_target.rfind(":")
	if idx <= 0:
		return ServerMain.DEFAULT_PORT
	var port_str: String = _connect_target.substr(idx + 1)
	if port_str.is_valid_int():
		return port_str.to_int()
	return ServerMain.DEFAULT_PORT


## Client-side: handshake completed, set ready in the lobby so the
## host can start the game.
func _on_client_handshake_accepted(_player_index: int) -> void:
	LobbyManager.set_ready(true)


## Network host entry point — creates a lobby and watches the lobby
## state for both-players-ready, then triggers
## [method LobbyManager.request_start_game].
func _start_network_host() -> void:
	# Wait until ServerMain has finished its own _ready (host on ENet).
	await get_tree().process_frame
	# Defensive: only proceed if we ended up in server role.
	if not NetworkManager.is_server():
		return
	LobbyManager.create_lobby("ReplayHost", "")
	LobbyManager.set_ready(true)
	LobbyManager.lobby_updated.connect(_on_host_lobby_updated)


## Host-side lobby watcher: triggers game start as soon as the lobby
## reports [code]can_start[/code] (both peers ready).
func _on_host_lobby_updated(_data: Dictionary) -> void:
	var lobby: LobbyState = LobbyManager.current_lobby
	if lobby == null or not lobby.can_start():
		return
	if _host_started:
		return
	_host_started = true
	LobbyManager.request_start_game()


## Wrapper around [code]get_tree().quit(code)[/code] for testability.
func _quit(code: int) -> void:
	if not is_inside_tree():
		return
	get_tree().quit(code)

