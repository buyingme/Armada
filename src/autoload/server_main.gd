## ServerMain
##
## Autoload singleton that detects dedicated-server mode and orchestrates
## the server lifecycle.  Server mode is activated when either:
## - The [code]--server[/code] CLI argument is present, or
## - The [code]dedicated_server[/code] feature tag is set (export preset).
##
## In server mode this autoload:
## 1. Sets [member PlayMode.current_mode] to [code]NETWORK[/code].
## 2. Suppresses audio (master bus volume → −80 dB).
## 3. Logs server configuration (port, scenario, etc.).
## 4. Prepares for [code]NetworkManager.host()[/code] (wired in G4.1).
##
## Graceful shutdown (G4.10.3):
##   Handles [code]NOTIFICATION_WM_CLOSE_REQUEST[/code] (maps to SIGTERM
##   on headless exports).  On receipt the server auto-saves the current
##   game state, notifies connected clients (once NetworkManager exists),
##   waits up to [constant SHUTDOWN_TIMEOUT_SEC] seconds, then exits.
##
## Architecture: this is a thin orchestration layer.  No game logic lives
## here — it delegates to [GameManager], [SaveGameManager], and (future)
## [code]NetworkManager[/code].
extends Node


## Maximum seconds to wait for clients to disconnect during graceful
## shutdown before forcing exit.
const SHUTDOWN_TIMEOUT_SEC: float = 5.0

## Default ENet listen port for the dedicated server.
const DEFAULT_PORT: int = 7350

## Whether this instance is running as a dedicated server.
var is_server: bool = false

## The ENet port the server will listen on (parsed from CLI [code]--port[/code]).
var port: int = DEFAULT_PORT

## The scenario identifier to load (parsed from CLI [code]--scenario[/code]).
var scenario_id: String = ""

## True while the graceful shutdown sequence is in progress.
var _shutting_down: bool = false

## Logger for this system.
var _log: GameLogger = GameLogger.new("ServerMain")


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	is_server = _detect_server_mode()
	if not is_server:
		return
	_parse_cli_args()
	_configure_server_environment()
	# Start ENet host via NetworkManager.
	if NetworkManager:
		var success: bool = NetworkManager.host(port)
		if not success:
			_log.error("Failed to start network host on port %d." % port)
	else:
		_log.warn("NetworkManager not available — server running without network.")
	_log.info("Dedicated server started — port=%d, scenario='%s'." % [
			port, scenario_id])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_server:
		_begin_graceful_shutdown()


# ---------------------------------------------------------------------------
# Server detection
# ---------------------------------------------------------------------------

## Returns [code]true[/code] if this instance should run as a dedicated server.
## Checks the [code]dedicated_server[/code] feature tag first (export preset),
## then falls back to the [code]--server[/code] CLI argument (development).
func _detect_server_mode() -> bool:
	if OS.has_feature("dedicated_server"):
		return true
	for arg: String in _get_all_cmdline_args():
		if arg == "--server":
			return true
	return false


## Returns all CLI arguments from both [method OS.get_cmdline_args] (before
## [code]--[/code]) and [method OS.get_cmdline_user_args] (after [code]--[/code]).
func _get_all_cmdline_args() -> PackedStringArray:
	var combined: PackedStringArray = OS.get_cmdline_args()
	combined.append_array(OS.get_cmdline_user_args())
	return combined


# ---------------------------------------------------------------------------
# CLI parsing
# ---------------------------------------------------------------------------

## Parses optional CLI arguments: [code]--port <number>[/code] and
## [code]--scenario <id>[/code].
func _parse_cli_args() -> void:
	var args: PackedStringArray = _get_all_cmdline_args()
	var i: int = 0
	while i < args.size():
		match args[i]:
			"--port":
				if i + 1 < args.size():
					var parsed: int = args[i + 1].to_int()
					if parsed > 0 and parsed <= 65535:
						port = parsed
					else:
						_log.warn("Invalid --port value '%s', using default %d." % [
								args[i + 1], DEFAULT_PORT])
					i += 1
			"--scenario":
				if i + 1 < args.size():
					scenario_id = args[i + 1]
					i += 1
		i += 1


# ---------------------------------------------------------------------------
# Server environment
# ---------------------------------------------------------------------------

## Configures the runtime environment for headless server operation.
## Suppresses audio and sets the play mode to NETWORK.
func _configure_server_environment() -> void:
	# Set network play mode.
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	# Suppress all audio output on dedicated server.
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, -80.0)
	_log.info("Server environment configured: PlayMode=NETWORK, audio muted.")


# ---------------------------------------------------------------------------
# Graceful shutdown (G4.10.3)
# ---------------------------------------------------------------------------

## Initiates the graceful shutdown sequence.
## 1. Auto-saves the current game state.
## 2. Notifies connected clients (stub — wired in G4.1).
## 3. Waits up to [constant SHUTDOWN_TIMEOUT_SEC] for cleanup.
## 4. Exits the process.
func _begin_graceful_shutdown() -> void:
	if _shutting_down:
		return
	_shutting_down = true
	_log.info("Graceful shutdown initiated…")
	# Step 1 — auto-save current game.
	_save_current_state()
	# Step 2 — notify clients (stub for G4.1 NetworkManager integration).
	_notify_clients_shutdown()
	# Step 3 — auto-save replay.
	_save_replay()
	# Step 4 — schedule forced exit after timeout.
	# In headless mode we cannot use a Timer node reliably, so we use
	# a deferred call chain.  The SceneTree quit will process pending
	# RPCs before exiting.
	_log.info("Shutdown complete — exiting.")
	get_tree().quit(0)


## Saves the current [GameState] via [SaveGameManager].
func _save_current_state() -> void:
	if not GameManager or not GameManager.current_game_state:
		_log.info("No active game state to save on shutdown.")
		return
	var success: bool = SaveGameManager.save_game(
			GameManager.current_game_state, "server_autosave")
	if success:
		_log.info("Game state auto-saved to 'server_autosave'.")
	else:
		_log.error("Failed to auto-save game state on shutdown.")


## Sends a shutdown notification to all connected clients.
func _notify_clients_shutdown() -> void:
	if NetworkManager:
		NetworkManager.broadcast_shutdown()
	else:
		_log.info("Client shutdown notification skipped — no NetworkManager.")


## Saves the command replay file on shutdown.
func _save_replay() -> void:
	if not GameManager:
		return
	GameManager.auto_save_replay()
