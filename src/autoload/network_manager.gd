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

## Emitted when a chat message is received (future — G4.6).
signal chat_received(sender: String, text: String, timestamp: int)

## Emitted when the server executes a command and broadcasts the result.
## [param command_data] — serialized command dictionary.
## [param result] — execution result dictionary.
signal command_result_received(command_data: Dictionary, result: Dictionary)


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
	_set_state(ConnectionState.LOBBY)
	_start_heartbeat()
	_log.info("Server hosting on port %d (protocol v%d)." % [
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
	_send_handshake.rpc_id(1, PROTOCOL_VERSION, client_id, display_name)


## Client-side: connection attempt failed.
func _on_connection_failed() -> void:
	_log.warn("Connection failed.")
	_cleanup()


## Client-side: server disconnected.
func _on_server_disconnected() -> void:
	_log.warn("Server disconnected.")
	_cleanup()


# ---------------------------------------------------------------------------
# Handshake RPCs
# ---------------------------------------------------------------------------

## Client → Server: send handshake with protocol version and identity.
## G4 Network Plan: §1.3 — handshake message.
@rpc("any_peer", "reliable")
func _send_handshake(protocol_version: int, client_id: String,
		display_name: String) -> void:
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
		# Disconnect after a short delay so the rejection message arrives.
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


## Server → Client: handshake response (accept or reject).
@rpc("authority", "reliable")
func _handshake_response(accepted: bool, reason: String,
		player_index: int) -> void:
	if role != Role.CLIENT:
		return
	if accepted:
		_log.info("Handshake accepted — assigned player index %d." %
				player_index)
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
		_log.warn("Peer %d claims player %d but is assigned %d — rejecting." % [
				sender_id, cmd.player_index, expected_player])
		return
	var result: Dictionary = CommandProcessor.submit(cmd)
	if result.is_empty():
		_log.info("Command [%s] from peer %d rejected by validation." % [
				cmd.command_type, sender_id])
		return
	# Broadcast result to all connected clients.
	var cmd_data: Dictionary = cmd.serialize()
	_broadcast_command_result.rpc(cmd_data, result)


## Server → All: broadcasts an executed command and its result.
## Clients apply the result to their local state mirror.
@rpc("authority", "reliable")
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


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

## Assigns a player slot (0 or 1) to a connecting peer.
## Returns -1 if both slots are taken.
func _assign_player_slot(peer_id: int) -> int:
	var taken: Array[int] = []
	for info: Dictionary in peers.values():
		taken.append(info["player_index"] as int)
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


## Schedules a peer disconnect after the current frame (so RPCs can flush).
func _disconnect_peer_deferred(peer_id: int) -> void:
	if _peer:
		# Use call_deferred so the rejection RPC has time to send.
		(func() -> void: _peer.disconnect_peer(peer_id)).call_deferred()


## Tears down all network state and returns to DISCONNECTED.
func _cleanup() -> void:
	if _heartbeat_timer:
		_heartbeat_timer.stop()
		_heartbeat_timer.queue_free()
		_heartbeat_timer = null
	peers.clear()
	_last_heartbeat.clear()
	if _peer:
		multiplayer.multiplayer_peer = null
		_peer = null
	role = Role.NONE
	_set_state(ConnectionState.DISCONNECTED)
