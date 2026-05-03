## NetworkManager
##
## Autoload singleton that manages the game's network transport layer.
## Handles connection lifecycle, peer management, role tracking, and
## protocol versioning.
##
## Connection state machine:
## [codeblock]
## DISCONNECTED → CONNECTING → AUTHENTICATING → LOBBY → IN_GAME → DISCONNECTED
## [/codeblock]
##
## Architecture notes:
## - Server creates an [ENetMultiplayerPeer] and listens on the configured port.
## - Clients connect to the server's IP:port via ENet.
## - Heartbeat / keepalive runs at [constant HEARTBEAT_INTERVAL_SEC] intervals;
##   peers not responding within [constant HEARTBEAT_TIMEOUT_SEC] are disconnected.
## - Protocol versioning: handshake includes [constant PROTOCOL_VERSION].
##   Server rejects clients whose version does not match.
##
## G4 Network Plan: §3 — G4.1 Network Transport Foundation
extends Node


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Current protocol version.  Incremented whenever the message format changes.
const PROTOCOL_VERSION: int = 1

## Interval (seconds) between keepalive pings.
const HEARTBEAT_INTERVAL_SEC: float = 5.0

## Seconds without a heartbeat response before a peer is considered dead.
const HEARTBEAT_TIMEOUT_SEC: float = 15.0

## Maximum number of ENet clients the server will accept (2 players + spectators).
const MAX_CLIENTS: int = 8

## Default channel count for ENet (reliable + unreliable + keepalive).
const ENET_CHANNELS: int = 3


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

## Connection state machine.
## G4 Network Plan: §3 — G4.1.4
enum ConnectionState {
	DISCONNECTED, ## Not connected to any network session.
	CONNECTING, ## TCP/ENet handshake in progress.
	AUTHENTICATING, ## Handshake sent, waiting for server acknowledgement.
	LOBBY, ## In lobby, waiting for game start.
	IN_GAME, ## Game is running.
}

## Network role for this instance.
enum Role {
	NONE, ## Not in a network session.
	SERVER, ## Authoritative server (headless or host).
	CLIENT, ## Connected player.
	SPECTATOR, ## Read-only observer (future — G4.7).
}


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when the connection state changes.
signal state_changed(old_state: ConnectionState, new_state: ConnectionState)

## Emitted when a peer connects (server-side).  [param peer_id] is the
## ENet peer identifier.
signal peer_connected(peer_id: int)

## Emitted when a peer disconnects.
signal peer_disconnected(peer_id: int)

## Emitted when the handshake with the server is accepted (client-side).
signal handshake_accepted(player_index: int)

## Emitted when the handshake is rejected (client-side).
signal handshake_rejected(reason: String)

## Emitted on the server when a peer completes the handshake and is
## authenticated.  Used by [LobbyManager] to add the peer to the lobby.
signal peer_authenticated(peer_id: int, player_index: int,
		display_name: String)

## Emitted when a chat message is received (future — G4.6).
signal chat_received(sender: String, text: String, timestamp: int)

## Emitted when the server executes a command and broadcasts the result.
## [param command_data] — serialized command dictionary.
## [param result] — execution result dictionary.
signal command_result_received(command_data: Dictionary, result: Dictionary)

## Emitted on the client after the host has saved the game.  The UI
## listens for this and shows a toast.  Phase J6.
signal save_notification_received(display_name: String)


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Current connection state.
var connection_state: ConnectionState = ConnectionState.DISCONNECTED

## This instance's network role.
var role: Role = Role.NONE

## Map of connected peer IDs → peer info dictionaries.
## Each entry: [code]{peer_id: int, display_name: String, player_index: int,
## protocol_version: int, authenticated: bool}[/code].
var peers: Dictionary = {}

## The ENet multiplayer peer (created on host/connect).
## Transient — not serialized.
var _peer: ENetMultiplayerPeer = null

## Timer tracking heartbeat sends.
## Transient — not serialized.
var _heartbeat_timer: Timer = null

## Last heartbeat received time per peer_id → float (seconds).
## Transient — not serialized.
var _last_heartbeat: Dictionary = {}

## Logger for this system.
var _log: GameLogger = GameLogger.new("NetworkManager")

## Client-side lobby password (plaintext).  Set before calling
## [method connect_to_server].  Cleared after handshake.
## Transient — not serialized.
var _lobby_password: String = ""

## The player index assigned to this instance during the handshake.
## 0 for the host (set in [method host]), assigned by server for clients.
## -1 when not connected.  G4.6.5.5.
var _local_player_index: int = -1

## Pending game configuration received from the server before scene transition.
## Contains [code]rng_seed[/code] and [code]scenario_id[/code].
## Set by [method broadcast_game_config] (server) or [method _receive_game_config]
## (client).  Consumed by [GameBoard._ready].  G4.6.5.2/3.
var _pending_game_config: Dictionary = {}

## Server-side sync gate for the Command Phase.
## Holds [AssignDialCommand] results until both players have submitted all
## dials, then releases them in a single batch.
## Transient — not serialized.
var _sync_gate: CommandSyncGate = CommandSyncGate.new()


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Connect to SceneTree multiplayer signals.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ---------------------------------------------------------------------------
# Public API — Server
# ---------------------------------------------------------------------------

## Starts hosting a game server on the given port.
## Called by [ServerMain] in server mode or by a player choosing "Host Game".
## [param port] — the ENet port to listen on.
## Returns [code]true[/code] on success.
func host(port: int = ServerMain.DEFAULT_PORT) -> bool:
	if connection_state != ConnectionState.DISCONNECTED:
		_log.warn("host() called while in state %s — ignoring." %
				_state_name(connection_state))
		return false
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_server(port, MAX_CLIENTS, ENET_CHANNELS)
	if err != OK:
		_log.error("Failed to create server on port %d: %s" % [port, error_string(err)])
		_peer = null
		return false
	multiplayer.multiplayer_peer = _peer
	role = Role.SERVER
	_local_player_index = 0
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	_set_state(ConnectionState.LOBBY)
	_start_heartbeat()
	_log.info("Server hosting on port %d (protocol v%d) — PlayMode=NETWORK." % [
			port, PROTOCOL_VERSION])
	return true


## Broadcasts a shutdown notice to all connected clients.
## Called by [ServerMain] during graceful shutdown.
func broadcast_shutdown() -> void:
	if role != Role.SERVER:
		return
	_log.info("Broadcasting shutdown to %d peers." % peers.size())
	_server_shutdown_notice.rpc()


# ---------------------------------------------------------------------------
# Public API — Client
# ---------------------------------------------------------------------------

## Connects to a server at the given address and port.
## [param address] — the server's IP or hostname.
## [param port] — the server's ENet port.
## Returns [code]true[/code] if the connection attempt started.
func connect_to_server(address: String, port: int = ServerMain.DEFAULT_PORT) -> bool:
	if connection_state != ConnectionState.DISCONNECTED:
		_log.warn("connect_to_server() called while in state %s — ignoring." %
				_state_name(connection_state))
		return false
	_peer = ENetMultiplayerPeer.new()
	var err: Error = _peer.create_client(address, port, ENET_CHANNELS)
	if err != OK:
		_log.error("Failed to connect to %s:%d: %s" % [
				address, port, error_string(err)])
		_peer = null
		return false
	multiplayer.multiplayer_peer = _peer
	role = Role.CLIENT
	_set_state(ConnectionState.CONNECTING)
	_log.info("Connecting to %s:%d…" % [address, port])
	return true


## Disconnects from the current session and resets state.
func disconnect_from_server() -> void:
	if connection_state == ConnectionState.DISCONNECTED:
		return
	_log.info("Disconnecting (was %s)." % _state_name(connection_state))
	_cleanup()


## Sets the lobby password for the next [method connect_to_server] call.
## The password is sent during the handshake and cleared afterwards.
## G4.5.6 — password-protected lobbies.
func set_lobby_password(password: String) -> void:
	_lobby_password = password


# ---------------------------------------------------------------------------
# Public API — Queries
# ---------------------------------------------------------------------------

## Returns [code]true[/code] if this instance is the authoritative server.
func is_server() -> bool:
	return role == Role.SERVER


## Returns [code]true[/code] if currently connected (any state except DISCONNECTED).
func is_connected_to_network() -> bool:
	return connection_state != ConnectionState.DISCONNECTED


## Returns the number of authenticated peers (excluding self on server).
func get_peer_count() -> int:
	return peers.size()


## Returns the player index assigned to this instance (0 or 1).
## Returns -1 if not connected.  G4.6.5.5.
func get_local_player_index() -> int:
	return _local_player_index


## Returns the pending game configuration dictionary.
## Contains [code]rng_seed[/code] and [code]scenario_id[/code].
## Consumed by [GameBoard._ready] after scene transition.  G4.6.5.2/3.
func get_pending_game_config() -> Dictionary:
	return _pending_game_config


## Returns a human-readable name for a [enum ConnectionState].
func _state_name(state: ConnectionState) -> String:
	match state:
		ConnectionState.DISCONNECTED:
			return "DISCONNECTED"
		ConnectionState.CONNECTING:
			return "CONNECTING"
		ConnectionState.AUTHENTICATING:
			return "AUTHENTICATING"
		ConnectionState.LOBBY:
			return "LOBBY"
		ConnectionState.IN_GAME:
			return "IN_GAME"
	return "UNKNOWN"


## Returns a human-readable name for a [enum Role].
func _role_name(r: Role) -> String:
	match r:
		Role.NONE:
			return "NONE"
		Role.SERVER:
			return "SERVER"
		Role.CLIENT:
			return "CLIENT"
		Role.SPECTATOR:
			return "SPECTATOR"
	return "UNKNOWN"


# ---------------------------------------------------------------------------
# Connection callbacks
# ---------------------------------------------------------------------------

## Server-side: a new ENet peer has connected.
func _on_peer_connected(peer_id: int) -> void:
	_log.info("Peer connected: %d" % peer_id)
	_last_heartbeat[peer_id] = Time.get_ticks_msec() / 1000.0
	peer_connected.emit(peer_id)


## Server-side: a peer has disconnected.
func _on_peer_disconnected(peer_id: int) -> void:
	_log.info("Peer disconnected: %d" % peer_id)
	peers.erase(peer_id)
	_last_heartbeat.erase(peer_id)
	peer_disconnected.emit(peer_id)


## Client-side: successfully connected to the server's ENet layer.
## Now send the handshake.
func _on_connected_to_server() -> void:
	_log.info("ENet connection established — sending handshake.")
	_set_state(ConnectionState.AUTHENTICATING)
	var client_id: String = PlayerProfile.get_client_id() if PlayerProfile else ""
	var display_name: String = PlayerProfile.get_display_name() if PlayerProfile else "Player"
	_send_handshake.rpc_id(1, PROTOCOL_VERSION, client_id, display_name,
			_lobby_password)
	_lobby_password = ""


## Client-side: connection attempt failed.
func _on_connection_failed() -> void:
	_log.warn("Connection failed.")
	_cleanup()


## Client-side: server disconnected.
func _on_server_disconnected() -> void:
	_log.warn("Server disconnected.")
	var was_authenticating: bool = (
			connection_state == ConnectionState.AUTHENTICATING)
	_cleanup()
	if was_authenticating:
		_log.warn("Disconnected during handshake — treating as rejection.")
		handshake_rejected.emit("Connection rejected by server.")


# ---------------------------------------------------------------------------
# Handshake RPCs
# ---------------------------------------------------------------------------

## Client → Server: send handshake with protocol version, identity,
## and optional lobby password.
## G4 Network Plan: §1.3 — handshake message.  G4.5.6 — password.
@rpc("any_peer", "reliable")
func _send_handshake(protocol_version: int, client_id: String,
		display_name: String, password: String = "") -> void:
	if role != Role.SERVER:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	_log.info("Handshake from peer %d: v%d, name='%s', client_id='%s'." % [
			sender_id, protocol_version, display_name, client_id])
	# --- Protocol version check ---
	if protocol_version != PROTOCOL_VERSION:
		var reason: String = (
				"Protocol mismatch: server requires v%d, you have v%d — please update." %
				[PROTOCOL_VERSION, protocol_version])
		_log.warn("Rejecting peer %d: %s" % [sender_id, reason])
		_handshake_response.rpc_id(sender_id, false, reason, -1)
		_disconnect_peer_deferred(sender_id)
		return
	# --- Password check (G4.5.6) ---
	if not _verify_lobby_password(password):
		var reason: String = "Incorrect lobby password."
		_log.warn("Rejecting peer %d: %s" % [sender_id, reason])
		_handshake_response.rpc_id(sender_id, false, reason, -1)
		_disconnect_peer_deferred(sender_id)
		return
	# --- Assign player slot ---
	var player_index: int = _assign_player_slot(sender_id)
	if player_index < 0:
		var reason: String = "Server is full — no player slots available."
		_log.warn("Rejecting peer %d: %s" % [sender_id, reason])
		_handshake_response.rpc_id(sender_id, false, reason, -1)
		_disconnect_peer_deferred(sender_id)
		return
	# --- Accept ---
	peers[sender_id] = {
		"peer_id": sender_id,
		"display_name": display_name,
		"client_id": client_id,
		"player_index": player_index,
		"protocol_version": protocol_version,
		"authenticated": true,
	}
	_log.info("Peer %d accepted as player %d ('%s')." % [
			sender_id, player_index, display_name])
	_handshake_response.rpc_id(sender_id, true, "", player_index)
	peer_authenticated.emit(sender_id, player_index, display_name)


## Server-side: check if the supplied password matches the lobby password.
## Returns [code]true[/code] if no password is set or the hash matches.
## G4.5.6 — password-protected lobbies.
func _verify_lobby_password(password: String) -> bool:
	if not LobbyManager:
		return true
	var lobby: LobbyState = LobbyManager.current_lobby
	if lobby == null or not lobby.has_password():
		return true
	# Compare SHA-256 hash of supplied password against stored hash.
	var supplied_hash: String = password.sha256_text()
	return supplied_hash == lobby.password_hash


## Server → Client: handshake response (accept or reject).
@rpc("authority", "reliable")
func _handshake_response(accepted: bool, reason: String,
		player_index: int) -> void:
	if role != Role.CLIENT:
		return
	if accepted:
		_log.info("Handshake accepted — assigned player index %d." %
				player_index)
		_local_player_index = player_index
		PlayMode.set_mode(PlayMode.Mode.NETWORK)
		_log.info("PlayMode set to NETWORK (client, player_index=%d)." % player_index)
		_set_state(ConnectionState.LOBBY)
		_start_heartbeat()
		handshake_accepted.emit(player_index)
	else:
		_log.warn("Handshake rejected: %s" % reason)
		handshake_rejected.emit(reason)
		_cleanup()


# ---------------------------------------------------------------------------
# Heartbeat / Keepalive (G4.1.5)
# ---------------------------------------------------------------------------

## Server → All / Client → Server: keepalive ping.
@rpc("any_peer", "unreliable")
func _heartbeat_ping() -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	_last_heartbeat[sender_id] = Time.get_ticks_msec() / 1000.0
	# Reply with pong if server received a client ping.
	if role == Role.SERVER:
		_heartbeat_pong.rpc_id(sender_id)


## Server → Client: keepalive pong response.
@rpc("authority", "unreliable")
func _heartbeat_pong() -> void:
	# Client received pong — server is alive.
	_last_heartbeat[1] = Time.get_ticks_msec() / 1000.0


## Starts the heartbeat timer.
func _start_heartbeat() -> void:
	if _heartbeat_timer != null:
		return
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL_SEC
	_heartbeat_timer.timeout.connect(_on_heartbeat_tick)
	_heartbeat_timer.autostart = true
	add_child(_heartbeat_timer)


## Called every [constant HEARTBEAT_INTERVAL_SEC] seconds.
func _on_heartbeat_tick() -> void:
	if role == Role.SERVER:
		# Send ping to all clients and check for timeouts.
		for peer_id: int in _last_heartbeat.keys():
			_heartbeat_ping.rpc_id(peer_id)
		_check_heartbeat_timeouts()
	elif role == Role.CLIENT:
		# Send ping to server.
		_heartbeat_ping.rpc_id(1)
		_check_heartbeat_timeouts()


## Disconnects peers whose last heartbeat exceeds [constant HEARTBEAT_TIMEOUT_SEC].
func _check_heartbeat_timeouts() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var timed_out: Array[int] = []
	for peer_id: int in _last_heartbeat.keys():
		var elapsed: float = now - _last_heartbeat[peer_id]
		if elapsed > HEARTBEAT_TIMEOUT_SEC:
			timed_out.append(peer_id)
	for peer_id: int in timed_out:
		_log.warn("Peer %d heartbeat timeout (%.1fs)." % [
				peer_id, Time.get_ticks_msec() / 1000.0 - _last_heartbeat[peer_id]])
		if role == Role.SERVER:
			_disconnect_peer_deferred(peer_id)
		elif role == Role.CLIENT and peer_id == 1:
			# Server timed out — disconnect.
			_log.warn("Server heartbeat timeout — disconnecting.")
			_cleanup()


# ---------------------------------------------------------------------------
# Shutdown RPC (G4.10.3)
# ---------------------------------------------------------------------------

## Server → All: notifies clients that the server is shutting down.
@rpc("authority", "reliable")
func _server_shutdown_notice() -> void:
	_log.info("Server shutdown notice received.")
	_cleanup()


# ---------------------------------------------------------------------------
# Command Submission RPCs (G4.2.3 / G4.2.4)
# ---------------------------------------------------------------------------

## Client-side helper: sends a serialized command to the server.
## Called by [NetworkCommandSubmitter.submit].
func send_command_to_server(data: Dictionary) -> void:
	if role != Role.CLIENT:
		_log.warn("send_command_to_server() called but role is %s." %
				_role_name(role))
		return
	_submit_command_to_server.rpc_id(1, data)


## Client → Server: receives a command submission from a client.
## The server deserializes, validates, executes via [CommandProcessor],
## and broadcasts the result to all peers.
## For [AssignDialCommand]s during the Command Phase, the result is held
## in the [CommandSyncGate] until both players have submitted all dials
## (G4.4 — Command Phase Sync Gate).
@rpc("any_peer", "reliable")
func _submit_command_to_server(data: Dictionary) -> void:
	if role != Role.SERVER:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not peers.has(sender_id):
		_log.warn("Command from unknown peer %d — ignoring." % sender_id)
		return
	var cmd: GameCommand = GameCommand.deserialize(data)
	if cmd == null:
		_log.warn("Failed to deserialize command from peer %d." % sender_id)
		return
	# Verify the command's player_index matches the peer's assigned slot.
	var expected_player: int = peers[sender_id].get("player_index", -1)
	if cmd.player_index != expected_player:
		# Phase I6b-3 R2 follow-up: during an active attack flow the
		# attacker peer is the de-facto controller for defense-side
		# follow-ups (token spending, redirect, damage resolution).
		# Allow these commands when the sender is the attacker
		# (the [code]controller_player[/code] of the attack flow) and
		# the command's [code]player_index[/code] is the defender's
		# slot.  Without this exception, any client-as-attacker /
		# host-as-defender attack stalls when the client tries to
		# submit a [SpendDefenseTokenCommand] / [ResolveDamageCommand]
		# for the host-owned defender.
		if not _is_attacker_authored_defense_command(cmd, expected_player):
			_log.warn("Peer %d claims player %d but is assigned %d — rejecting [%s]." % [
					sender_id, cmd.player_index, expected_player,
					cmd.command_type])
			return
	var result: Dictionary = CommandProcessor.submit(cmd)
	if result.is_empty():
		_log.info("Command [%s] from peer %d rejected by validation." % [
				cmd.command_type, sender_id])
		return
	# Phase I6b-3 R2 follow-up: tag remote-authored commands so the host's
	# [_on_network_command_result] runs side effects even when
	# [code]cmd.player_index[/code] equals the host's local slot (e.g. the
	# attacker peer authored a [code]resolve_damage[/code] for the
	# host-owned defender).  Without this flag the host's existing
	# [code]player_index != local[/code] gate silently drops the
	# damage-summary / damage-card-dealt re-emits.
	result["__remote_authored"] = true
	var cmd_data: Dictionary = cmd.serialize()
	# --- Sync gate: hold dial assignments until both players are done ---
	if _sync_gate.is_active() and cmd.command_type == "assign_dials":
		_sync_gate.hold(cmd_data, result)
		if _all_dials_assigned(cmd.player_index):
			_sync_gate.mark_ready(cmd.player_index)
			_log.info("Player %d dials complete — held in sync gate." %
					cmd.player_index)
		if _sync_gate.is_open():
			_log.info("Sync gate open — broadcasting %d held dial commands." %
					_sync_gate.get_held_count())
			for entry: Dictionary in _sync_gate.release():
				_broadcast_command_result.rpc(
						entry["command_data"], entry["result"])
		return
	# --- Normal path: broadcast immediately ---
	_broadcast_command_result.rpc(cmd_data, result)


## Server → All: broadcasts an executed command and its result.
## Clients apply the result to their local state mirror.
## [code]call_local[/code] ensures the server also receives the signal so
## [GameManager._on_network_command_result] can process side effects for
## commands submitted by the remote player.  G4.6.5 BF-2.
@rpc("authority", "call_local", "reliable")
func _broadcast_command_result(command_data: Dictionary,
		result: Dictionary) -> void:
	command_result_received.emit(command_data, result)


# ---------------------------------------------------------------------------
# Transition to IN_GAME
# ---------------------------------------------------------------------------

## Transitions the connection state to IN_GAME.
## Called by the lobby or game start logic when the match begins.
func start_game() -> void:
	if connection_state == ConnectionState.LOBBY:
		_set_state(ConnectionState.IN_GAME)
		_log.info("Transitioned to IN_GAME.")


## Server: generates and broadcasts game configuration (RNG seed + scenario)
## to all clients, and stores it locally for the host.
## Must be called BEFORE [method start_game] and scene transition so clients
## receive the config before [GameBoard._ready] fires.
## G4.6.5.2.
func broadcast_game_config(rng_seed: int, scenario_id: String) -> void:
	if role != Role.SERVER:
		_log.warn("broadcast_game_config() called but not server.")
		return
	_pending_game_config = {
		"rng_seed": rng_seed,
		"scenario_id": scenario_id,
	}
	_receive_game_config.rpc(rng_seed, scenario_id)
	_log.info("Broadcast game config: seed=%d, scenario='%s'." % [
			rng_seed, scenario_id])


## Server → All: delivers game configuration before scene transition.
## G4.6.5.3.
@rpc("authority", "reliable")
func _receive_game_config(rng_seed: int, scenario_id: String) -> void:
	_pending_game_config = {
		"rng_seed": rng_seed,
		"scenario_id": scenario_id,
	}
	_log.info("Received game config: seed=%d, scenario='%s'." % [
			rng_seed, scenario_id])


## Server: notifies all peers that the host has saved the game.  The
## host sees no toast (it already saw the dialog close); clients show a
## brief "Host saved the game as ..." toast.  Phase J6.
##
## [param display_name] — the user-facing save name.
func broadcast_save_notification(display_name: String) -> void:
	if role != Role.SERVER:
		_log.warn("broadcast_save_notification() called but not server.")
		return
	_receive_save_notification.rpc(display_name)
	_log.info("Broadcast save notification: '%s'." % display_name)


## Server → Clients: delivers the post-save notification.  The host
## skips its own emission since [code]call_local[/code] is omitted.
## Phase J6.
@rpc("authority", "reliable")
func _receive_save_notification(display_name: String) -> void:
	save_notification_received.emit(display_name)
	_log.info("Received save notification from host: '%s'." % display_name)


## Server-side: processes a command submitted by the host player.
## Validates, executes via [CommandProcessor], broadcasts result to clients.
## Called by [NetworkHostCommandSubmitter].
## G4.6.5.1.
func handle_host_command(command: GameCommand, result: Dictionary) -> void:
	if role != Role.SERVER:
		_log.warn("handle_host_command() called but not server.")
		return
	var cmd_data: Dictionary = command.serialize()
	# --- Sync gate: hold dial assignments until both players are done ---
	if _sync_gate.is_active() and command.command_type == "assign_dials":
		_sync_gate.hold(cmd_data, result)
		if _all_dials_assigned(command.player_index):
			_sync_gate.mark_ready(command.player_index)
			_log.info("Player %d dials complete (host) — held in sync gate." %
					command.player_index)
		if _sync_gate.is_open():
			_log.info("Sync gate open — broadcasting %d held dial commands." %
					_sync_gate.get_held_count())
			for entry: Dictionary in _sync_gate.release():
				_broadcast_command_result.rpc(
						entry["command_data"], entry["result"])
		return
	# --- Normal path: broadcast immediately ---
	_broadcast_command_result.rpc(cmd_data, result)


# ---------------------------------------------------------------------------
# Sync Gate helpers (G4.4)
# ---------------------------------------------------------------------------

## Activates the Command Phase sync gate.
## Called by [GameManager] at the start of the Command Phase in network mode.
func activate_sync_gate() -> void:
	_sync_gate.activate()
	_log.info("Sync gate activated for Command Phase.")


## Deactivates the Command Phase sync gate.
func deactivate_sync_gate() -> void:
	_sync_gate.deactivate()


## Returns [code]true[/code] if every non-destroyed ship of [param player_index]
## has had its dials assigned (i.e. [code]get_dials_needed() == 0[/code]).
## Queries the authoritative [GameState] via [GameManager].
func _all_dials_assigned(player_index: int) -> bool:
	var gs: GameState = GameManager.current_game_state if GameManager else null
	if gs == null:
		return false
	var ps: PlayerState = gs.get_player_state(player_index)
	if ps == null:
		return false
	for s: Variant in ps.ships:
		if s is ShipInstance:
			var si: ShipInstance = s as ShipInstance
			if si.is_destroyed():
				continue
			if si.command_dial_stack == null:
				continue
			if si.command_dial_stack.get_dials_needed() > 0:
				return false
	return true


## Phase I6b-3 R2 follow-up: command-types the attacker peer may
## author against the defender's [code]player_index[/code] during an
## active attack flow.  These are the post-hand-off submissions the
## [AttackExecutor] makes after the defender's
## [CommitDefenseCommand] has been broadcast — the attacker peer
## still drives [code]_state.modified_damage[/code] / sub-step UI
## (Evade / Redirect) and resolves damage at the end.
const _ATTACKER_DEFENSE_COMMANDS: PackedStringArray = [
	"spend_defense_token",
	"select_redirect_zone",
	"resolve_damage",
]


## Returns [code]true[/code] when [param cmd] is a defense-side
## follow-up authored by the current attack flow's attacker peer
## against the defender's [code]player_index[/code].
## Used to relax the strict peer/player check in
## [method _submit_command_to_server].
func _is_attacker_authored_defense_command(cmd: GameCommand,
		sender_player: int) -> bool:
	if not _ATTACKER_DEFENSE_COMMANDS.has(cmd.command_type):
		return false
	var gs: GameState = GameManager.current_game_state if GameManager else null
	if gs == null or gs.interaction_flow == null:
		return false
	var flow: InteractionFlow = gs.interaction_flow
	if flow.flow_type != Constants.InteractionFlow.ATTACK:
		return false
	# The flow's [code]controller_player[/code] is the attacker only
	# during DECLARE/ROLL/MODIFY/RESOLVE_DAMAGE; during DEFENSE_TOKENS
	# and CRITICAL_CHOICE it is the [b]defender[/b].  Read the attacker
	# from the flow payload, which is populated by [AttackExecutor]
	# when the target is locked in.
	var attacker_player: int = int(flow.payload.get("attacker_player", -1))
	if attacker_player < 0:
		return false
	# The sender must be the attacker peer (the one driving the
	# [AttackExecutor] sub-step pipeline).
	return attacker_player == sender_player


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Assigns a player slot (0 or 1) to a connecting peer.
## Checks both [member peers] (authenticated network peers) and
## [member LobbyManager.current_lobby] players (includes the host).
## Returns -1 if both slots are taken.
func _assign_player_slot(_peer_id: int) -> int:
	var taken: Array[int] = []
	# Collect slots already claimed by authenticated peers.
	for info: Dictionary in peers.values():
		taken.append(info["player_index"] as int)
	# Also collect slots occupied in the lobby (includes the host).
	if LobbyManager and LobbyManager.current_lobby:
		for p: Dictionary in LobbyManager.current_lobby.players:
			var idx: int = p.get("player_index", -1)
			if idx >= 0 and idx not in taken:
				taken.append(idx)
	_log.info("Slot assignment — taken slots: %s." % str(taken))
	for slot: int in [0, 1]:
		if slot not in taken:
			return slot
	return -1


## Sets the connection state and emits [signal state_changed].
func _set_state(new_state: ConnectionState) -> void:
	var old_state: ConnectionState = connection_state
	connection_state = new_state
	_log.info("State: %s → %s" % [_state_name(old_state), _state_name(new_state)])
	state_changed.emit(old_state, new_state)


## Schedules a peer disconnect with a delay so the rejection RPC can arrive.
func _disconnect_peer_deferred(peer_id: int) -> void:
	if not _peer:
		return
	var peer_ref: ENetMultiplayerPeer = _peer
	get_tree().create_timer(1.0).timeout.connect(
			func() -> void:
				if peer_ref and peer_ref.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
					peer_ref.disconnect_peer(peer_id)
	)


## Tears down all network state and returns to DISCONNECTED.
func _cleanup() -> void:
	if _heartbeat_timer:
		_heartbeat_timer.stop()
		_heartbeat_timer.queue_free()
		_heartbeat_timer = null
	peers.clear()
	_last_heartbeat.clear()
	_local_player_index = -1
	_pending_game_config = {}
	if _peer:
		multiplayer.multiplayer_peer = null
		_peer = null
	role = Role.NONE
	_set_state(ConnectionState.DISCONNECTED)
