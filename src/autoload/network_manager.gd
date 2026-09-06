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
const PROTOCOL_VERSION: int = 6

## Interval (seconds) between keepalive pings.
const HEARTBEAT_INTERVAL_SEC: float = 5.0

## Seconds without a heartbeat response before a peer is considered dead.
const HEARTBEAT_TIMEOUT_SEC: float = 15.0

## Maximum number of ENet clients the server will accept (2 players + spectators).
const MAX_CLIENTS: int = 8

## Default channel count for ENet (reliable + unreliable + keepalive).
const ENET_CHANNELS: int = 3

## Bound staging/install waits so a lost acknowledgement cannot strand the
## host or an admitted incumbent.
const RESUME_ACK_TIMEOUT_MSEC: int = 15000


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

## Emitted only on the submitting client when the server rejects a command.
## Rejections are not broadcast and do not enter accepted command history.
signal command_rejection_received(
		command_data: Dictionary, reason: String)

## Emitted on the client after the host has saved the game.  The UI
## listens for this and shows a toast.  Phase J6.
signal save_notification_received(display_name: String)

## Purpose-specific explicit-assignment orchestration signals consumed by
## LobbyManager and the narrow assignment presentation.  They carry no
## persistent identity assertion.
signal fresh_resume_assignment_ready(attempt_id: String,
		expected_endpoints: Array[int], available_players: Array[int])
signal fresh_resume_ready_to_commit(attempt_id: String)
signal fresh_resume_published(attempt_id: String)
signal fresh_resume_failed(reason: String)
signal fresh_start_ready_to_commit(attempt_id: String)
signal fresh_start_published(attempt_id: String)
signal fresh_start_failed(reason: String)
signal resume_commit_received(state: GameState, meta: SaveGameMetadata,
		principal_id: String, player_index: int, attempt_id: String)
signal reconnect_assignment_ready(endpoint_id: int, available_players: Array)
signal reconnect_client_released(attempt_id: String)
signal resume_status_changed(status: String)


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Current connection state.
var connection_state: ConnectionState = ConnectionState.DISCONNECTED

## This instance's network role.
var role: Role = Role.NONE

## Synchronous capture for the command currently submitted through the
## authoritative processor on the server.
var _captured_rejection_command: GameCommand = null
var _captured_rejection_reason: String = ""

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
## Contains [code]rng_seed[/code], [code]scenario_id[/code], and optionally
## a [code]setup_package[/code] dictionary for fleet-builder starts.
## Set by [method broadcast_game_config] (server) or [method _receive_game_config]
## (client).  Consumed by [GameBoard._ready].  G4.6.5.2/3.
var _pending_game_config: Dictionary = {}

## Host-local association with a canonical match principal. Never serialized.
var _host_match_principal_id: String = ""

## Server-side sync gate for the Command Phase.
## Holds [AssignDialCommand] results until both players have submitted all
## dials, then releases them in a single batch.
## Transient — not serialized.
var _sync_gate: CommandSyncGate = CommandSyncGate.new()

## ENet port the local instance is currently listening on (server) or
## connected to (client).  0 when disconnected.  Transient.
var _active_port: int = 0

## Purpose-specific fresh-resume/reconnect coordinators.  These are transient
## associations only; the canonical player/principal binding stays in GameState.
var _resume_attempt: Dictionary = {}
var _client_staged_resume: Dictionary = {}
var _post_publication_fresh_attempt_id: String = ""

## Player-originated admission gate. Normal new games and same-live loads keep
## this open; fresh resume/reconnect opens it only after installation ACK.
var _principal_command_admission_enabled: bool = true
var _host_remote_authored_sequences: Dictionary = {}


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


func _process(_delta: float) -> void:
	if _resume_attempt.is_empty():
		return
	var phase: String = str(_resume_attempt.get("phase", ""))
	if phase not in ["STAGING_SNAPSHOT", "AWAITING_INSTALL_ACKS"]:
		return
	if Time.get_ticks_msec() - int(_resume_attempt.get("phase_started_msec", 0)) \
			<= RESUME_ACK_TIMEOUT_MSEC:
		return
	_timeout_resume_attempt(phase)


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
	_active_port = port
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
	_active_port = port
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


## Returns the ENet port the local instance is hosting on (server) or
## connected to (client).  Returns 0 when disconnected.
func get_active_port() -> int:
	return _active_port


## Returns the first non-loopback IPv4 address bound to a local interface,
## suitable for showing as the LAN address other players can connect to.
## Returns an empty string when no LAN interface is found.
func get_local_lan_ip() -> String:
	for ip: String in IP.get_local_addresses():
		if ip.is_empty():
			continue
		if ip.begins_with("127."):
			continue
		if ip.find(":") != -1:
			continue # skip IPv6
		if ip.begins_with("169.254."):
			continue # skip link-local fallback
		return ip
	return ""


## Returns the pending game configuration dictionary.
## Contains [code]rng_seed[/code] and [code]scenario_id[/code].
## Consumed by [GameBoard._ready] after scene transition.  G4.6.5.2/3.
func get_pending_game_config() -> Dictionary:
	return _pending_game_config.duplicate(true)


## Returns and clears the one-shot authoritative bootstrap configuration.
func consume_pending_game_config() -> Dictionary:
	var config: Dictionary = _pending_game_config.duplicate(true)
	_pending_game_config = {}
	return config


func is_player_command_admission_enabled() -> bool:
	return _principal_command_admission_enabled


## Establishes ordinary new-match associations from the already accepted lobby
## slots.  This is not used for saved-match resume and creates no persistent
## credential or recovery material.
func establish_initial_match_principal_associations(
		binding: MatchPlayerControlBinding, lobby: LobbyState) -> bool:
	if connection_state != ConnectionState.LOBBY or binding == null \
			or not binding.is_valid() or lobby == null or not lobby.can_start() \
			or not _host_match_principal_id.is_empty():
		return false
	var slots: Dictionary = {}
	for player: Dictionary in lobby.players:
		var player_index: int = int(player.get("player_index", -1))
		var peer_id: int = int(player.get("peer_id", -1))
		if player_index < 0 or player_index >= Constants.PLAYER_COUNT \
				or slots.has(player_index):
			return false
		slots[player_index] = peer_id
	if slots.size() != Constants.PLAYER_COUNT:
		return false
	for player_index: int in range(Constants.PLAYER_COUNT):
		var endpoint_id: int = int(slots[player_index])
		var principal_id: String = binding.principal_id_for_player(player_index)
		if principal_id.is_empty():
			clear_match_principal_associations()
			return false
		if endpoint_id == 1:
			_host_match_principal_id = principal_id
			_local_player_index = player_index
		elif peers.has(endpoint_id):
			peers[endpoint_id]["match_principal_id"] = principal_id
			peers[endpoint_id]["command_admission_enabled"] = true
		else:
			clear_match_principal_associations()
			return false
	_principal_command_admission_enabled = true
	return true


func resume_availability_for_state(state: GameState) -> Dictionary:
	if state == null or not state.validate_for_live_installation():
		return {"resumable": false, "reason": "schema_invalid"}
	var binding: MatchPlayerControlBinding = _binding_for_state(state)
	if binding == null:
		return {"resumable": false, "reason": "schema_invalid"}
	var humans: Array[String] = binding.distinct_principal_ids(
			MatchPlayerControlBinding.KIND_HUMAN)
	if humans.size() != Constants.PLAYER_COUNT:
		return {"resumable": false, "reason": "unsupported_network_binding"}
	for player_index: int in range(Constants.PLAYER_COUNT):
		var principal_id: String = binding.principal_id_for_player(player_index)
		if principal_id.is_empty() or binding.principal_kind(principal_id) != \
				MatchPlayerControlBinding.KIND_HUMAN:
			return {"resumable": false, "reason": "unsupported_network_binding"}
	return {"resumable": true, "reason": ""}


# ---------------------------------------------------------------------------
# MATCH-003 explicit side assignment and filtered installation
# ---------------------------------------------------------------------------

func current_authenticated_lobby_peer_ids() -> Array[int]:
	var result: Array[int] = []
	for peer_value: Variant in peers.keys():
		var peer_id: int = int(peer_value)
		var info: Dictionary = peers[peer_id] as Dictionary
		if bool(info.get("authenticated", false)) \
				and int(info.get("player_index", -1)) >= 0:
			result.append(peer_id)
	result.sort()
	return result


func begin_fresh_session_resume(state: GameState, meta: SaveGameMetadata) -> bool:
	if role != Role.SERVER or connection_state != ConnectionState.LOBBY \
			or state == null or meta == null or not _resume_attempt.is_empty():
		return false
	var availability: Dictionary = resume_availability_for_state(state)
	if not bool(availability.get("resumable", false)):
		fresh_resume_failed.emit(str(availability.get("reason", "invalid_candidate")))
		return false
	var remote_ids: Array[int] = current_authenticated_lobby_peer_ids()
	if remote_ids.size() != 1:
		fresh_resume_failed.emit("Exactly one authenticated client is required.")
		return false
	var binding: MatchPlayerControlBinding = _binding_for_state(state)
	var attempt_id: String = _new_random_hex()
	var expected_endpoints: Array[int] = [1, remote_ids[0]]
	var available_players: Array[int] = [0, 1]
	_resume_attempt = {
		"attempt_id": attempt_id,
		"operation": "fresh_session_resume",
		"phase": "CANDIDATE_STAGED",
		"binding_data": binding.serialize(),
		"candidate_fingerprint": CanonicalJson.hash(state.serialize()),
		"cursor": meta.next_command_sequence,
		"expected_endpoints": expected_endpoints,
		"proposals": {},
		"associations": {},
		"ready": {},
		"installed": {},
		"metadata": meta.to_dict(),
		"phase_started_msec": Time.get_ticks_msec(),
		"old_host_principal": _host_match_principal_id,
		"old_host_player_index": _local_player_index,
		"old_peer_state": _peer_resume_state_snapshot(),
	}
	_principal_command_admission_enabled = false
	resume_status_changed.emit("Awaiting explicit side assignment")
	fresh_resume_assignment_ready.emit(attempt_id, expected_endpoints, available_players)
	return true


func begin_fresh_network_start(state: GameState, scenario_id: String) -> bool:
	if role != Role.SERVER or connection_state != ConnectionState.LOBBY \
			or state == null or not state.validate_for_full_authority_installation() \
			or not _resume_attempt.is_empty():
		return false
	var remote_ids: Array[int] = current_authenticated_lobby_peer_ids()
	if remote_ids.size() != 1:
		return false
	var binding: MatchPlayerControlBinding = _binding_for_state(state)
	if binding == null:
		return false
	var remote_id: int = remote_ids[0]
	var remote_player: int = int(peers[remote_id].get("player_index", -1))
	if remote_player < 0 or remote_player >= Constants.PLAYER_COUNT \
			or _local_player_index < 0:
		return false
	var attempt_id: String = _new_random_hex()
	var meta: SaveGameMetadata = SaveGameManager.build_metadata_for(
			state, "fresh_network_start")
	meta.scenario_id = scenario_id
	meta.set_next_command_sequence(0)
	_resume_attempt = {
		"attempt_id": attempt_id, "operation": "fresh_network_start",
		"phase": "STAGING_SNAPSHOT",
		"binding_data": binding.serialize(),
		"candidate_fingerprint": CanonicalJson.hash(state.serialize()),
		"cursor": 0, "expected_endpoints": [1, remote_id],
		"proposals": {1: _local_player_index, remote_id: remote_player},
		"associations": {1: _host_match_principal_id,
			remote_id: str(peers[remote_id].get("match_principal_id", ""))},
		"ready": {1: true}, "installed": {},
		"metadata": meta.to_dict(), "scenario_id": scenario_id,
		"phase_started_msec": Time.get_ticks_msec(),
	}
	_principal_command_admission_enabled = false
	peers[remote_id]["command_admission_enabled"] = false
	var filter_result: Dictionary = StateFilter.filter_for_player_checked(
			state.serialize(), remote_player)
	if not bool(filter_result.get(StateFilter.KEY_OK, false)):
		var reason: String = "Fresh Network staging rejected locally: %s" % str(
				filter_result.get(StateFilter.KEY_REASON, "filtering failed"))
		_log.error(reason)
		_abort_resume(reason)
		return false
	var filtered: Dictionary = filter_result.get(
			StateFilter.KEY_STATE, {}) as Dictionary
	_receive_resume_snapshot.rpc_id(remote_id, "fresh_network_start",
			attempt_id, filtered, meta.to_dict(),
			str(peers[remote_id].get("match_principal_id", "")), remote_player, 0)
	return true


func commit_fresh_network_start(state: GameState, attempt_id: String) -> bool:
	if role != Role.SERVER or _resume_attempt.get("operation", "") != \
			"fresh_network_start" or _resume_attempt.get("phase", "") != \
			"READY_TO_COMMIT" or _resume_attempt.get("attempt_id", "") != attempt_id \
			or CanonicalJson.hash(state.serialize()) != str(
					_resume_attempt.get("candidate_fingerprint", "")):
		return false
	_resume_attempt["phase"] = "COMMITTING"
	return true


func publish_fresh_network_start(attempt_id: String) -> bool:
	if role != Role.SERVER or _resume_attempt.get("operation", "") != \
			"fresh_network_start" or _resume_attempt.get("phase", "") != \
			"COMMITTING" or _resume_attempt.get("attempt_id", "") != attempt_id:
		return false
	if connection_state != ConnectionState.IN_GAME:
		_set_state(ConnectionState.IN_GAME)
	_resume_attempt["phase"] = "AWAITING_INSTALL_ACKS"
	_resume_attempt["installed"] = {1: true}
	_resume_attempt["phase_started_msec"] = Time.get_ticks_msec()
	for endpoint_value: Variant in _resume_attempt["expected_endpoints"] as Array:
		var endpoint_id: int = int(endpoint_value)
		if endpoint_id != 1:
			_commit_resume_snapshot.rpc_id(endpoint_id, attempt_id)
	return true


func abort_fresh_network_start(reason: String) -> void:
	if role == Role.SERVER and _resume_attempt.get("operation", "") == \
			"fresh_network_start" and _resume_attempt.get("phase", "") \
			not in ["AWAITING_INSTALL_ACKS", "PUBLISHED"]:
		_abort_resume(reason)


## Host-only, non-RPC proposal commit.  The UI supplies player indices only;
## principal identities are derived exclusively from the immutable binding.
func submit_fresh_resume_assignment(proposals: Dictionary) -> bool:
	if role != Role.SERVER or _resume_attempt.get("operation", "") != \
			"fresh_session_resume" or _resume_attempt.get("phase", "") != \
			"CANDIDATE_STAGED":
		return false
	var binding: MatchPlayerControlBinding = MatchPlayerControlBinding.deserialize(
			_resume_attempt.get("binding_data", {}))
	if binding == null or not _validate_explicit_assignment(proposals, binding):
		return false
	var expected: Array = _resume_attempt["expected_endpoints"] as Array
	var associations: Dictionary = {}
	for endpoint_value: Variant in expected:
		var endpoint_id: int = int(endpoint_value)
		var player_index: int = int(proposals[endpoint_id])
		var principal_id: String = binding.principal_id_for_player(player_index)
		if principal_id.is_empty() or _active_principal_has_other_endpoint(
				principal_id, endpoint_id):
			return false
		associations[endpoint_id] = principal_id
	# Commit the complete transient association set atomically and keep all
	# player-originated admission closed until installation acknowledgements.
	_host_match_principal_id = str(associations[1])
	_local_player_index = int(proposals[1])
	for peer_value: Variant in peers.keys():
		(peers[peer_value] as Dictionary).erase("match_principal_id")
	for endpoint_value: Variant in expected:
		var endpoint_id: int = int(endpoint_value)
		if endpoint_id != 1 and peers.has(endpoint_id):
			peers[endpoint_id]["match_principal_id"] = associations[endpoint_id]
			peers[endpoint_id]["player_index"] = int(proposals[endpoint_id])
			peers[endpoint_id]["command_admission_enabled"] = false
	_resume_attempt["proposals"] = proposals.duplicate(true)
	_resume_attempt["associations"] = associations
	_resume_attempt["phase"] = "ASSOCIATIONS_COMMITTED_ADMISSION_CLOSED"
	resume_status_changed.emit("Assignment committed; staging filtered view")
	return true


func stage_fresh_resume_snapshots(state: GameState, meta: SaveGameMetadata) -> bool:
	if role != Role.SERVER or _resume_attempt.get("operation", "") != \
			"fresh_session_resume" or _resume_attempt.get("phase", "") != \
			"ASSOCIATIONS_COMMITTED_ADMISSION_CLOSED":
		return false
	var binding: MatchPlayerControlBinding = _binding_for_state(state)
	if not _resume_candidate_matches(state, meta, binding):
		_abort_resume("The staged save changed before distribution.")
		return false
	var expected: Array = _resume_attempt["expected_endpoints"] as Array
	var proposals: Dictionary = _resume_attempt["proposals"] as Dictionary
	for endpoint_value: Variant in expected:
		var endpoint_id: int = int(endpoint_value)
		if endpoint_id == 1:
			continue
		if not peers.has(endpoint_id):
			_abort_resume("The assigned client disconnected before staging.")
			return false
		var player_index: int = int(proposals[endpoint_id])
		var principal_id: String = binding.principal_id_for_player(player_index)
		var filter_result: Dictionary = StateFilter.filter_for_player_checked(
				state.serialize(), player_index)
		if not bool(filter_result.get(StateFilter.KEY_OK, false)):
			_abort_resume("Fresh resume filtering rejected locally: %s" % str(
					filter_result.get(StateFilter.KEY_REASON, "filtering failed")))
			return false
		var filtered: Dictionary = filter_result.get(
				StateFilter.KEY_STATE, {}) as Dictionary
		_receive_resume_snapshot.rpc_id(endpoint_id, "fresh_session_resume",
				_resume_attempt["attempt_id"], filtered, meta.to_dict(), principal_id,
				player_index, int(_resume_attempt["cursor"]))
	_resume_attempt["ready"] = {1: true}
	_resume_attempt["phase"] = "STAGING_SNAPSHOT"
	_resume_attempt["phase_started_msec"] = Time.get_ticks_msec()
	return true


func commit_fresh_resume_associations(state: GameState, meta: SaveGameMetadata) -> bool:
	if role != Role.SERVER or _resume_attempt.get("phase", "") != \
			"READY_TO_COMMIT":
		return false
	# Publication is permitted only while the same complete lobby remains in its
	# pre-game state.  This keeps a staged snapshot from crossing an unrelated
	# connection or lobby transition.
	if connection_state != ConnectionState.LOBBY:
		_abort_resume("Lobby state changed before publication.")
		return false
	var binding: MatchPlayerControlBinding = _binding_for_state(state)
	if not _resume_candidate_matches(state, meta, binding) \
			or not _revalidate_explicit_assignment(binding):
		_abort_resume("Resume changed during publication revalidation.")
		return false
	_resume_attempt["phase"] = "COMMITTING"
	return true


func rollback_fresh_resume_associations() -> void:
	if _resume_attempt.is_empty():
		return
	_restore_prepublication_attempt_state()
	_abort_resume("Host installation failed.")


func mark_fresh_resume_host_state_live(attempt_id: String) -> bool:
	if role != Role.SERVER or _resume_attempt.get("phase", "") != "COMMITTING" \
			or _resume_attempt.get("attempt_id", "") != attempt_id:
		return false
	if connection_state != ConnectionState.IN_GAME:
		_set_state(ConnectionState.IN_GAME)
	return true


func publish_fresh_resume_after_host_install(state: GameState,
		meta: SaveGameMetadata) -> bool:
	if role != Role.SERVER or _resume_attempt.get("phase", "") != "COMMITTING" \
			or not _resume_candidate_matches(state, meta, _binding_for_state(state)):
		return false
	_resume_attempt["phase"] = "AWAITING_INSTALL_ACKS"
	_resume_attempt["installed"] = {1: true}
	_resume_attempt["phase_started_msec"] = Time.get_ticks_msec()
	for endpoint_value: Variant in (_resume_attempt["expected_endpoints"] as Array):
		var endpoint_id: int = int(endpoint_value)
		if endpoint_id != 1:
			_commit_resume_snapshot.rpc_id(endpoint_id, _resume_attempt["attempt_id"])
	return true


func acknowledge_resume_installation(attempt_id: String) -> void:
	if role != Role.CLIENT or _client_staged_resume.get("attempt_id", "") != \
			attempt_id or bool(_client_staged_resume.get("acknowledged", false)):
		return
	_client_staged_resume["acknowledged"] = true
	if connection_state != ConnectionState.IN_GAME:
		_set_state(ConnectionState.IN_GAME)
	_acknowledge_resume_installation.rpc_id(1, attempt_id,
			int(_client_staged_resume["cursor"]))


func reject_client_resume_installation(attempt_id: String, reason: String) -> void:
	if role != Role.CLIENT or _client_staged_resume.get("attempt_id", "") != attempt_id:
		return
	_reject_resume_installation.rpc_id(1, attempt_id, reason)
	_client_staged_resume = {}
	_principal_command_admission_enabled = false


func install_client_principal_assignment(attempt_id: String,
		principal_id: String, player_index: int) -> bool:
	if role != Role.CLIENT or _client_staged_resume.get("attempt_id", "") != \
			attempt_id or _client_staged_resume.get("principal_id", "") != principal_id \
			or int(_client_staged_resume.get("player_index", -1)) != player_index:
		return false
	var state: GameState = _client_staged_resume.get("state") as GameState
	if state == null or not state.principal_controls_player(principal_id, player_index):
		return false
	_local_player_index = player_index
	return true


func client_staged_operation(attempt_id: String) -> String:
	if _client_staged_resume.get("attempt_id", "") != attempt_id:
		return ""
	return str(_client_staged_resume.get("operation", ""))


func cancel_fresh_resume() -> void:
	if role == Role.SERVER and _resume_attempt.get("operation", "") == \
			"fresh_session_resume":
		_abort_resume("Resume cancelled.")


## A reconnecting endpoint is transport-authenticated but remains unassigned
## and non-admitted until a host explicitly chooses an unoccupied saved side.
func _notify_unassigned_reconnect_endpoints() -> void:
	if role != Role.SERVER or connection_state != ConnectionState.IN_GAME \
			or not _resume_attempt.is_empty():
		return
	for endpoint_value: Variant in peers.keys():
		var endpoint_id: int = int(endpoint_value)
		var info: Dictionary = peers[endpoint_id] as Dictionary
		if bool(info.get("authenticated", false)) \
				and str(info.get("match_principal_id", "")).is_empty():
			_begin_reconnect_for_peer(endpoint_id)


func _begin_reconnect_for_peer(endpoint_id: int) -> void:
	if role != Role.SERVER or connection_state != ConnectionState.IN_GAME \
			or GameManager.current_game_state == null or not peers.has(endpoint_id) \
			or not _resume_attempt.is_empty():
		return
	var binding: MatchPlayerControlBinding = _binding_for_state(
			GameManager.current_game_state)
	if binding == null:
		return
	var available: Array[int] = []
	for player_index: int in range(Constants.PLAYER_COUNT):
		var principal_id: String = binding.principal_id_for_player(player_index)
		if binding.principal_kind(principal_id) == MatchPlayerControlBinding.KIND_HUMAN \
				and not _active_principal_has_other_endpoint(principal_id, endpoint_id):
			available.append(player_index)
	if available.is_empty():
		return
	peers[endpoint_id]["command_admission_enabled"] = false
	reconnect_assignment_ready.emit(endpoint_id, available)


func begin_reconnect_assignment(endpoint_id: int, player_index: int) -> bool:
	if role != Role.SERVER or connection_state != ConnectionState.IN_GAME \
			or GameManager.current_game_state == null or not peers.has(endpoint_id) \
			or not _resume_attempt.is_empty() or player_index < 0 \
			or player_index >= Constants.PLAYER_COUNT:
		return false
	var state: GameState = GameManager.current_game_state
	var binding: MatchPlayerControlBinding = _binding_for_state(state)
	var principal_id: String = binding.principal_id_for_player(player_index)
	if principal_id.is_empty() or binding.principal_kind(principal_id) != \
			MatchPlayerControlBinding.KIND_HUMAN or _active_principal_has_other_endpoint(
				principal_id, endpoint_id):
		return false
	var meta: SaveGameMetadata = SaveGameManager.build_metadata_for(state, "reconnect")
	meta.scenario_id = GameManager.get_scenario_id()
	meta.set_next_command_sequence(CommandProcessor.get_next_sequence())
	_resume_attempt = {
		"attempt_id": _new_random_hex(), "operation": "reconnect",
		"phase": "STAGING_SNAPSHOT", "binding_data": binding.serialize(),
		"candidate_fingerprint": CanonicalJson.hash(state.serialize()),
		"cursor": meta.next_command_sequence, "expected_endpoints": [endpoint_id],
		"proposals": {endpoint_id: player_index},
		"associations": {endpoint_id: principal_id}, "ready": {}, "installed": {},
		"metadata": meta.to_dict(),
		"phase_started_msec": Time.get_ticks_msec(),
	}
	peers[endpoint_id]["match_principal_id"] = principal_id
	peers[endpoint_id]["player_index"] = player_index
	peers[endpoint_id]["command_admission_enabled"] = false
	var filter_result: Dictionary = StateFilter.filter_for_player_checked(
			state.serialize(), player_index)
	if not bool(filter_result.get(StateFilter.KEY_OK, false)):
		_abort_resume("Reconnect filtering rejected locally: %s" % str(
				filter_result.get(StateFilter.KEY_REASON, "filtering failed")))
		return false
	var filtered: Dictionary = filter_result.get(
			StateFilter.KEY_STATE, {}) as Dictionary
	_receive_resume_snapshot.rpc_id(endpoint_id, "reconnect", _resume_attempt["attempt_id"],
			filtered, meta.to_dict(), principal_id, player_index, meta.next_command_sequence)
	return true


@rpc("authority", "reliable")
func _receive_resume_snapshot(operation: String, attempt_id: String,
		state_dict: Dictionary, meta_dict: Dictionary, principal_id: String,
		player_index: int, cursor: int) -> void:
	if role != Role.CLIENT or operation not in [
			"fresh_session_resume", "reconnect", "fresh_network_start"] \
			or not _is_attempt_id(attempt_id) or player_index < 0 \
			or player_index >= Constants.PLAYER_COUNT:
		return
	var state: GameState = GameState.deserialize_passive_network(state_dict)
	var meta: SaveGameMetadata = SaveGameMetadata.from_dict(meta_dict)
	var binding: MatchPlayerControlBinding = _binding_for_state(state)
	var reconstruction: Dictionary = SaveGameManager.reconstruction_cursor_for(meta, state)
	if state == null or meta == null or binding == null \
			or not state.principal_controls_player(principal_id, player_index) \
			or not bool(reconstruction.get("ok", false)) \
			or int(reconstruction.get("next_command_sequence", -1)) != cursor:
		_client_staged_resume = {}
		_acknowledge_resume_snapshot.rpc_id(1, attempt_id, false, -1)
		return
	_client_staged_resume = {"operation": operation, "attempt_id": attempt_id,
		"state": state, "meta": meta, "principal_id": principal_id,
		"player_index": player_index, "cursor": cursor, "acknowledged": false}
	_principal_command_admission_enabled = false
	_acknowledge_resume_snapshot.rpc_id(1, attempt_id, true, cursor)


@rpc("any_peer", "reliable")
func _acknowledge_resume_snapshot(attempt_id: String, accepted: bool, cursor: int) -> void:
	if role != Role.SERVER or _resume_attempt.is_empty() \
			or _resume_attempt.get("attempt_id", "") != attempt_id \
			or _resume_attempt.get("phase", "") != "STAGING_SNAPSHOT":
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id not in (_resume_attempt["expected_endpoints"] as Array) \
			or not accepted or cursor != int(_resume_attempt.get("cursor", -1)):
		_abort_resume("A client rejected the staged snapshot.")
		return
	var ready: Dictionary = _resume_attempt["ready"] as Dictionary
	if ready.has(sender_id):
		return
	ready[sender_id] = true
	if _resume_attempt["operation"] == "fresh_session_resume":
		_resume_attempt["phase"] = "READY_TO_COMMIT"
		fresh_resume_ready_to_commit.emit(attempt_id)
	elif _resume_attempt["operation"] == "fresh_network_start":
		_resume_attempt["phase"] = "READY_TO_COMMIT"
		fresh_start_ready_to_commit.emit(attempt_id)
	else:
		_resume_attempt["phase"] = "AWAITING_INSTALL_ACKS"
		_resume_attempt["installed"] = {}
		_resume_attempt["phase_started_msec"] = Time.get_ticks_msec()
		_commit_resume_snapshot.rpc_id(sender_id, attempt_id)


@rpc("authority", "reliable")
func _commit_resume_snapshot(attempt_id: String) -> void:
	if role != Role.CLIENT or _client_staged_resume.get("attempt_id", "") != attempt_id:
		return
	resume_commit_received.emit(_client_staged_resume["state"],
			_client_staged_resume["meta"], _client_staged_resume["principal_id"],
			int(_client_staged_resume["player_index"]), attempt_id)


@rpc("any_peer", "reliable")
func _acknowledge_resume_installation(attempt_id: String, cursor: int) -> void:
	if role != Role.SERVER or _resume_attempt.get("phase", "") != \
			"AWAITING_INSTALL_ACKS" or _resume_attempt.get("attempt_id", "") != attempt_id \
			or cursor != int(_resume_attempt.get("cursor", -1)):
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id not in (_resume_attempt["expected_endpoints"] as Array):
		return
	var installed: Dictionary = _resume_attempt["installed"] as Dictionary
	if installed.has(sender_id):
		return
	installed[sender_id] = true
	_maybe_publish_resume()


@rpc("authority", "reliable")
func _enable_resume_admission(operation: String, attempt_id: String) -> void:
	if role != Role.CLIENT or _client_staged_resume.get("attempt_id", "") != attempt_id \
			or _client_staged_resume.get("operation", "") != operation \
			or not bool(_client_staged_resume.get("acknowledged", false)):
		return
	_principal_command_admission_enabled = true
	resume_status_changed.emit("Resume ready")
	if operation == "fresh_session_resume":
		fresh_resume_published.emit(attempt_id)
	elif operation == "fresh_network_start":
		_client_staged_resume = {}
		fresh_start_published.emit(attempt_id)
	else:
		_client_staged_resume = {}
		reconnect_client_released.emit(attempt_id)


@rpc("authority", "reliable")
func _abort_resume_attempt(attempt_id: String, reason: String) -> void:
	if role != Role.CLIENT or _client_staged_resume.get("attempt_id", "") != attempt_id:
		return
	var operation: String = str(_client_staged_resume.get("operation", ""))
	_client_staged_resume = {}
	_principal_command_admission_enabled = true
	resume_status_changed.emit("Resume aborted")
	if operation == "fresh_session_resume":
		fresh_resume_failed.emit(reason)
	elif operation == "fresh_network_start":
		fresh_start_failed.emit(reason)


@rpc("any_peer", "reliable")
func _reject_resume_installation(attempt_id: String, reason: String) -> void:
	if role != Role.SERVER or _resume_attempt.get("attempt_id", "") != attempt_id \
			or _resume_attempt.get("phase", "") != "AWAITING_INSTALL_ACKS":
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id not in (_resume_attempt.get("expected_endpoints", []) as Array):
		return
	var operation: String = str(_resume_attempt.get("operation", ""))
	if operation == "fresh_session_resume":
		# Host publication has already linearized; retain it and close only the
		# missing endpoint rather than waiting forever for its acknowledgement.
		if peers.has(sender_id):
			peers[sender_id].erase("match_principal_id")
			peers[sender_id]["command_admission_enabled"] = false
		_resume_attempt = {}
		_principal_command_admission_enabled = true
		resume_status_changed.emit("Client installation rejected: " + reason)
		_notify_unassigned_reconnect_endpoints()
	else:
		if peers.has(sender_id):
			peers[sender_id].erase("match_principal_id")
			peers[sender_id]["command_admission_enabled"] = false
		_resume_attempt = {}
		_principal_command_admission_enabled = true
		resume_status_changed.emit("Reconnect installation rejected: " + reason)
		_notify_unassigned_reconnect_endpoints()


func _maybe_publish_resume() -> void:
	if _resume_attempt.get("phase", "") != "AWAITING_INSTALL_ACKS":
		return
	var expected: Array = _resume_attempt["expected_endpoints"] as Array
	if (_resume_attempt["installed"] as Dictionary).size() != expected.size():
		return
	var operation: String = str(_resume_attempt["operation"])
	var attempt_id: String = str(_resume_attempt["attempt_id"])
	_principal_command_admission_enabled = true
	for endpoint_value: Variant in expected:
		var endpoint_id: int = int(endpoint_value)
		if endpoint_id != 1 and peers.has(endpoint_id):
			peers[endpoint_id]["command_admission_enabled"] = true
			_enable_resume_admission.rpc_id(endpoint_id, operation, attempt_id)
	_resume_attempt = {}
	resume_status_changed.emit("Resume ready")
	if operation == "fresh_session_resume":
		fresh_resume_published.emit(attempt_id)
	elif operation == "fresh_network_start":
		fresh_start_published.emit(attempt_id)


func _validate_explicit_assignment(proposals: Dictionary,
		binding: MatchPlayerControlBinding) -> bool:
	var expected: Array = _resume_attempt.get("expected_endpoints", []) as Array
	if proposals.size() != expected.size() or binding == null:
		return false
	var selected: Dictionary = {}
	for endpoint_value: Variant in expected:
		var endpoint_id: int = int(endpoint_value)
		if not proposals.has(endpoint_id) or not (proposals[endpoint_id] is int):
			return false
		var player_index: int = int(proposals[endpoint_id])
		if player_index < 0 or player_index >= Constants.PLAYER_COUNT \
				or selected.has(player_index):
			return false
		var principal_id: String = binding.principal_id_for_player(player_index)
		if principal_id.is_empty() or binding.principal_kind(principal_id) != \
				MatchPlayerControlBinding.KIND_HUMAN:
			return false
		selected[player_index] = true
	return selected.size() == Constants.PLAYER_COUNT


func _resume_candidate_matches(state: GameState, meta: SaveGameMetadata,
		binding: MatchPlayerControlBinding) -> bool:
	return state != null and meta != null and binding != null \
			and not _resume_attempt.is_empty() \
			and _resume_attempt.get("binding_data", {}) == binding.serialize() \
			and _resume_attempt.get("candidate_fingerprint", "") == \
				CanonicalJson.hash(state.serialize()) \
			and _resume_attempt.get("metadata", {}) == meta.to_dict() \
			and int(_resume_attempt.get("cursor", -1)) == meta.next_command_sequence


func _revalidate_explicit_assignment(binding: MatchPlayerControlBinding) -> bool:
	var proposals: Dictionary = _resume_attempt.get("proposals", {}) as Dictionary
	if not _validate_explicit_assignment(proposals, binding) \
			or (_resume_attempt.get("associations", {}) as Dictionary).size() != \
				Constants.PLAYER_COUNT:
		return false
	var expected: Array = _resume_attempt["expected_endpoints"] as Array
	if expected.size() != Constants.PLAYER_COUNT \
			or not (_resume_attempt.get("metadata", {}) is Dictionary):
		return false
	if role != Role.SERVER or connection_state != ConnectionState.LOBBY \
			or peers.size() != 1 or _principal_command_admission_enabled:
		return false
	if LobbyManager.current_lobby == null or not LobbyManager.current_lobby.can_start():
		return false
	var current_remote: Array[int] = current_authenticated_lobby_peer_ids()
	if current_remote.size() != 1 or int(expected[0]) != 1 \
			or int(expected[1]) != current_remote[0]:
		return false
	var lobby_endpoints: Dictionary = {}
	for player: Dictionary in LobbyManager.current_lobby.players:
		var lobby_peer_id: int = int(player.get("peer_id", -1))
		if lobby_peer_id < 0 or lobby_endpoints.has(lobby_peer_id):
			return false
		lobby_endpoints[lobby_peer_id] = true
	if lobby_endpoints.size() != Constants.PLAYER_COUNT \
			or not lobby_endpoints.has(1) or not lobby_endpoints.has(current_remote[0]):
		return false
	for endpoint_value: Variant in (_resume_attempt["expected_endpoints"] as Array):
		var endpoint_id: int = int(endpoint_value)
		var player_index: int = int(proposals.get(endpoint_id, -1))
		var principal_id: String = binding.principal_id_for_player(player_index)
		if principal_id.is_empty() \
				or (_resume_attempt["associations"] as Dictionary).get(
						endpoint_id, "") != principal_id:
			return false
		if endpoint_id == 1:
			if _host_match_principal_id != principal_id \
					or _local_player_index != player_index:
				return false
		elif not peers.has(endpoint_id) \
				or not bool((peers[endpoint_id] as Dictionary).get(
						"authenticated", false)) \
				or str((peers[endpoint_id] as Dictionary).get(
						"match_principal_id", "")) != principal_id \
				or int((peers[endpoint_id] as Dictionary).get(
						"player_index", -1)) != player_index \
				or bool((peers[endpoint_id] as Dictionary).get(
						"command_admission_enabled", true)):
			return false
	return true


func _timeout_resume_attempt(phase: String) -> void:
	var operation: String = str(_resume_attempt.get("operation", ""))
	if phase == "STAGING_SNAPSHOT":
		_abort_resume("Resume staging acknowledgement timed out.")
		return
	# Host publication has already happened. Preserve host/incumbent admission;
	# remove only the unavailable endpoint and leave it eligible for explicit
	# reconnect when transport confirms/re-establishes it.
	for endpoint_value: Variant in (_resume_attempt.get("expected_endpoints", []) as Array):
		var endpoint_id: int = int(endpoint_value)
		if endpoint_id != 1 and peers.has(endpoint_id):
			peers[endpoint_id].erase("match_principal_id")
			peers[endpoint_id]["command_admission_enabled"] = false
	_resume_attempt = {}
	_principal_command_admission_enabled = true
	resume_status_changed.emit("%s installation acknowledgement timed out." % operation)
	_notify_unassigned_reconnect_endpoints()


func _abort_resume(reason: String) -> void:
	if _resume_attempt.is_empty():
		return
	var operation: String = str(_resume_attempt.get("operation", ""))
	var is_prepublication_fresh: bool = _resume_attempt.get("operation", "") \
			in ["fresh_session_resume", "fresh_network_start"] \
			and _resume_attempt.get("phase", "") \
			not in ["AWAITING_INSTALL_ACKS", "PUBLISHED"]
	var attempt_id: String = str(_resume_attempt.get("attempt_id", ""))
	for endpoint_value: Variant in (_resume_attempt.get("expected_endpoints", []) as Array):
		var endpoint_id: int = int(endpoint_value)
		if endpoint_id != 1 and peers.has(endpoint_id) and _peer != null:
			_abort_resume_attempt.rpc_id(endpoint_id, attempt_id, reason)
	if is_prepublication_fresh:
		if operation == "fresh_session_resume":
			_restore_prepublication_attempt_state()
		else:
			for endpoint_value: Variant in (_resume_attempt.get(
					"expected_endpoints", []) as Array):
				var endpoint_id: int = int(endpoint_value)
				if endpoint_id != 1 and peers.has(endpoint_id):
					peers[endpoint_id]["command_admission_enabled"] = true
	elif operation == "reconnect":
		# A reconnect association exists only for this purpose-specific attempt.
		# Failed staging must return that endpoint to the unassigned state so a
		# later explicit host proposal can choose from the still-vacant side.
		_clear_failed_reconnect_associations()
	_resume_attempt = {}
	_principal_command_admission_enabled = true
	resume_status_changed.emit("Resume aborted")
	if operation == "fresh_session_resume":
		fresh_resume_failed.emit(reason)
	elif operation == "fresh_network_start":
		fresh_start_failed.emit(reason)
	if operation == "reconnect":
		_notify_unassigned_reconnect_endpoints()


func _clear_failed_reconnect_associations() -> void:
	for endpoint_value: Variant in (_resume_attempt.get("expected_endpoints", []) as Array):
		var endpoint_id: int = int(endpoint_value)
		if endpoint_id != 1 and peers.has(endpoint_id):
			peers[endpoint_id].erase("match_principal_id")
			peers[endpoint_id]["command_admission_enabled"] = false


func _active_principal_has_other_endpoint(principal_id: String,
		endpoint_id: int) -> bool:
	if endpoint_id != 1 and _host_match_principal_id == principal_id:
		return true
	for peer_value: Variant in peers.keys():
		var peer_id: int = int(peer_value)
		if peer_id != endpoint_id and str((peers[peer_id] as Dictionary).get(
				"match_principal_id", "")) == principal_id:
			return true
	return false


func _binding_for_state(state: GameState) -> MatchPlayerControlBinding:
	if state == null:
		return null
	return MatchPlayerControlBinding.deserialize(
			state.serialize().get("match_player_control_binding", {}))


func _peer_association_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for endpoint_value: Variant in peers.keys():
		var endpoint_id: int = int(endpoint_value)
		var principal_id: String = str((peers[endpoint_id] as Dictionary).get(
				"match_principal_id", ""))
		if not principal_id.is_empty():
			result[endpoint_id] = principal_id
	return result


func _peer_resume_state_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for endpoint_value: Variant in peers.keys():
		var endpoint_id: int = int(endpoint_value)
		var info: Dictionary = peers[endpoint_id] as Dictionary
		result[endpoint_id] = {
			"match_principal_id": str(info.get("match_principal_id", "")),
			"player_index": int(info.get("player_index", -1)),
			"command_admission_enabled": bool(info.get(
					"command_admission_enabled", true)),
		}
	return result


func _restore_prepublication_attempt_state() -> void:
	if _resume_attempt.get("operation", "") != "fresh_session_resume":
		return
	_host_match_principal_id = str(_resume_attempt.get("old_host_principal", ""))
	_local_player_index = int(_resume_attempt.get("old_host_player_index", -1))
	var old: Dictionary = _resume_attempt.get("old_peer_state", {}) as Dictionary
	for endpoint_value: Variant in peers.keys():
		var endpoint_id: int = int(endpoint_value)
		var info: Dictionary = peers[endpoint_id] as Dictionary
		info.erase("match_principal_id")
		if old.has(endpoint_id):
			var previous: Dictionary = old[endpoint_id] as Dictionary
			var principal_id: String = str(previous.get("match_principal_id", ""))
			if not principal_id.is_empty():
				info["match_principal_id"] = principal_id
			info["player_index"] = int(previous.get("player_index", -1))
			info["command_admission_enabled"] = bool(previous.get(
					"command_admission_enabled", true))


func _new_random_hex() -> String:
	return Crypto.new().generate_random_bytes(32).hex_encode()


func _is_attempt_id(value: Variant) -> bool:
	if not (value is String) or (value as String).length() != 64:
		return false
	var regex: RegEx = RegEx.new()
	regex.compile("^[0-9a-f]{64}$")
	return regex.search(value as String) != null


func clear_match_principal_associations() -> void:
	_host_match_principal_id = ""
	for peer_id: Variant in peers.keys():
		peers[peer_id].erase("match_principal_id")


func host_principal_controls_player(player_index: int) -> bool:
	return _principal_command_admission_enabled \
			and GameManager.current_game_state != null \
			and GameManager.current_game_state.principal_controls_player(
				_host_match_principal_id, player_index)


func can_install_loaded_binding(state: GameState) -> bool:
	if role != Role.SERVER or connection_state != ConnectionState.IN_GAME \
			or state == null or GameManager.current_game_state == null \
			or _host_match_principal_id.is_empty():
		return false
	if GameManager.current_game_state.serialize().get(
			"match_player_control_binding", {}) != state.serialize().get(
			"match_player_control_binding", {}):
		return false
	if not state.principal_controls_player(
			_host_match_principal_id, _local_player_index):
		return false
	for info: Dictionary in peers.values():
		var principal_id: String = str(info.get("match_principal_id", ""))
		var player_index: int = int(info.get("player_index", -1))
		if principal_id.is_empty() \
				or not state.principal_controls_player(principal_id, player_index):
			return false
	return true


## Returns the current connection state as a human-readable name.
func get_connection_state_name() -> String:
	return _state_name(connection_state)


## Returns the current role as a human-readable name.
func get_role_name() -> String:
	return _role_name(role)


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


## Server-side: a peer has disconnected.  Association loss is transient only;
## the canonical state and saved binding are never changed here.
func _on_peer_disconnected(peer_id: int) -> void:
	_log.info("Peer disconnected: %d" % peer_id)
	var affected_attempt: bool = not _resume_attempt.is_empty() \
			and peer_id in (_resume_attempt.get("expected_endpoints", []) as Array)
	var pre_publication: bool = _resume_attempt.get("phase", "") not in [
			"AWAITING_INSTALL_ACKS", "PUBLISHED"]
	peers.erase(peer_id)
	_last_heartbeat.erase(peer_id)
	if affected_attempt and pre_publication:
		_abort_resume("A participant disconnected before publication.")
	elif affected_attempt:
		# The host state is already live. Preserve the host/other admitted side;
		# only the disconnected endpoint becomes unassociated and non-admitted.
		_resume_attempt = {}
		_principal_command_admission_enabled = true
		resume_status_changed.emit("Waiting for explicit reconnect assignment")
	if connection_state == ConnectionState.IN_GAME and _resume_attempt.is_empty():
		_notify_unassigned_reconnect_endpoints()
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
	# An already-running host authenticates transport only. No vacant lobby
	# slot, peer/profile identity, or display name becomes gameplay authority.
	if connection_state == ConnectionState.IN_GAME:
		peers[sender_id] = {
			"peer_id": sender_id,
			"display_name": display_name,
			"client_id": client_id,
			"player_index": -1,
			"protocol_version": protocol_version,
			"authenticated": true,
			"command_admission_enabled": false,
		}
		_handshake_response.rpc_id(sender_id, true, "", -1, true)
		_begin_reconnect_for_peer(sender_id)
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
	_handshake_response.rpc_id(sender_id, true, "", player_index, false)
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
		player_index: int, server_in_game: bool = false) -> void:
	if role != Role.CLIENT:
		return
	if accepted:
		_log.info("Handshake accepted — assigned player index %d." %
				player_index)
		_local_player_index = player_index
		PlayMode.set_mode(PlayMode.Mode.NETWORK)
		_log.info("PlayMode set to NETWORK (client, player_index=%d)." % player_index)
		if server_in_game:
			# Remain AUTHENTICATING until the host sends a filtered staged state.
			resume_status_changed.emit("Waiting for explicit reconnect assignment")
		else:
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
	if role != Role.CLIENT or not _principal_command_admission_enabled:
		_log.warn("send_command_to_server() called but role is %s." %
				_role_name(role))
		return
	_submit_command_to_server.rpc_id(1, data)


## Client-side accepted-history submission. This is available only to the
## CLI replay harness; it deliberately does not represent a live principal.
func send_replay_command_to_server(data: Dictionary) -> void:
	if role != Role.CLIENT or not ReplayDriver.is_network_replay_bootstrap_active():
		_log.warn("send_replay_command_to_server() rejected outside network replay.")
		return
	_submit_replay_command_to_server.rpc_id(1, data)


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
	if not _principal_command_admission_enabled \
			or not bool((peers[sender_id] as Dictionary).get(
					"command_admission_enabled", true)):
		_send_command_rejection(sender_id, data,
				"Principal command admission is not enabled.")
		return
	var cmd: GameCommand = GameCommand.deserialize(data)
	if cmd == null:
		_log.warn("Failed to deserialize command from peer %d." % sender_id)
		return
	if cmd.command_type in ["debug_reposition", "debug_deal_damage"]:
		_log.warn("Remote peer %d attempted host-only debug command [%s]." % [
			sender_id, cmd.command_type])
		_send_command_rejection(sender_id, data,
				"State-changing debug commands are host-only.")
		return
	var principal_id: String = str(peers[sender_id].get("match_principal_id", ""))
	if GameManager.current_game_state == null \
			or not GameManager.current_game_state.principal_controls_player(
				principal_id, cmd.player_index):
		_log.warn("Peer %d has no matching principal association for [%s]." % [
				sender_id, cmd.command_type])
		_send_command_rejection(sender_id, data,
				"Submitting principal is not authorized for this player.")
		return
	_begin_rejection_capture(cmd)
	var result: Dictionary
	if ReplayDriver.enabled:
		result = CommandProcessor.submit_replay_deferred_followups(cmd)
	else:
		result = CommandProcessor.submit_deferred_followups(cmd)
	var rejection_reason: String = _end_rejection_capture()
	if result.is_empty():
		_log.info("Command [%s] from peer %d rejected by validation." % [
				cmd.command_type, sender_id])
		_send_command_rejection(sender_id, data, rejection_reason)
		return
	# Phase I6b-3 R2 follow-up: tag remote-authored commands so the host's
	# [_on_network_command_result] runs side effects even when
	# [code]cmd.player_index[/code] equals the host's local slot (e.g. the
	# attacker peer authored a [code]resolve_damage[/code] for the
	# host-owned defender).  Without this flag the host's existing
	# [code]player_index != local[/code] gate silently drops the
	# damage-summary / damage-card-dealt re-emits.
	var cmd_data: Dictionary = cmd.serialize()
	# --- Sync gate: hold dial assignments until both players are done ---
	if _sync_gate.is_active() and cmd.command_type == "assign_dials":
		_sync_gate.hold(cmd_data, result, true)
		if _all_dials_assigned(cmd.player_index):
			_sync_gate.mark_ready(cmd.player_index)
			_log.info("Player %d dials complete — held in sync gate." %
					cmd.player_index)
		if _sync_gate.is_open():
			_log.info("Sync gate open — broadcasting %d held dial commands." %
					_sync_gate.get_held_count())
			for entry: Dictionary in _sync_gate.release():
				_distribute_command_result_data(entry["command_data"],
						entry["result"], bool(entry.get("remote_authored", false)))
			_drain_server_observer_followups()
		return
	# --- Normal path: broadcast immediately ---
	_distribute_command_result(cmd, result, true)
	_drain_server_observer_followups()


## Client -> Server: applies one accepted replay-history command. Network
## replay harness peers are transport routing only and intentionally have no
## live principal association (MATCH-001 §6.1).
@rpc("any_peer", "reliable")
func _submit_replay_command_to_server(data: Dictionary) -> void:
	if role != Role.SERVER or not ReplayDriver.is_network_replay_bootstrap_active():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not peers.has(sender_id):
		_log.warn("Replay command from unknown peer %d — ignoring." % sender_id)
		return
	var cmd: GameCommand = GameCommand.deserialize(data)
	if cmd == null:
		_log.warn("Failed to deserialize replay command from peer %d." % sender_id)
		return
	_begin_rejection_capture(cmd)
	var result: Dictionary = CommandProcessor.submit_replay_deferred_followups(cmd)
	var rejection_reason: String = _end_rejection_capture()
	if result.is_empty():
		_log.info("Replay command [%s] from peer %d rejected by validation." % [
				cmd.command_type, sender_id])
		_send_command_rejection(sender_id, data, rejection_reason)
		return
	var cmd_data: Dictionary = cmd.serialize()
	if _sync_gate.is_active() and cmd.command_type == "assign_dials":
		_sync_gate.hold(cmd_data, result, true)
		if _all_dials_assigned(cmd.player_index):
			_sync_gate.mark_ready(cmd.player_index)
		if _sync_gate.is_open():
			for entry: Dictionary in _sync_gate.release():
				_distribute_command_result_data(entry["command_data"],
						entry["result"], true)
			_drain_server_observer_followups()
		return
	_distribute_command_result(cmd, result, true)
	_drain_server_observer_followups()


## Server → All: broadcasts an executed command and its result.
## Clients apply the result to their local state mirror.
## [code]call_local[/code] ensures the server also receives the signal so
## [GameManager._on_network_command_result] can process side effects for
## commands submitted by the remote player.  G4.6.5 BF-2.
@rpc("authority", "reliable")
func _receive_command_result(command_data: Dictionary,
		result_envelope: Dictionary) -> void:
	command_result_received.emit(command_data, result_envelope)


func _distribute_command_result(command: GameCommand, result: Dictionary,
		remote_authored: bool = false) -> void:
	_distribute_command_result_data(command.serialize(), result, remote_authored,
			command)


func _distribute_command_result_data(command_data: Dictionary,
		result: Dictionary, remote_authored: bool = false,
		command: GameCommand = null) -> void:
	var cmd: GameCommand = command
	if cmd == null:
		cmd = GameCommand.deserialize(command_data)
	if cmd == null:
		return
	if remote_authored:
		_host_remote_authored_sequences[cmd.sequence] = true
	command_result_received.emit(command_data,
			_build_result_envelope(cmd, result, _local_player_index))
	_host_remote_authored_sequences.erase(cmd.sequence)
	for peer_value: Variant in peers.keys():
		var peer_id: int = int(peer_value)
		var peer_info: Dictionary = peers[peer_id] as Dictionary
		if not bool(peer_info.get("authenticated", false)):
			continue
		var viewer: int = int(peer_info.get("player_index", -1))
		if viewer < 0 or viewer >= Constants.PLAYER_COUNT:
			continue
		_receive_command_result.rpc_id(peer_id, command_data,
				_build_result_envelope(cmd, result, viewer))


func _build_result_envelope(command: GameCommand, authority_result: Dictionary,
		viewer_player: int) -> Dictionary:
	var contract: String = command.application_contract_id()
	return {
		"protocol_version": PROTOCOL_VERSION,
		"application_contract": contract if not contract.is_empty() else "none",
		"application_contract_version": command.application_contract_version() \
				if not contract.is_empty() else 0,
		"viewer_player": viewer_player,
		"application_result": command.project_application_result(
				authority_result, viewer_player) if not contract.is_empty() else {},
		"presentation_result": {} if not contract.is_empty() \
				else authority_result.duplicate(true),
	}


func consume_host_remote_authored(sequence: int) -> bool:
	return bool(_host_remote_authored_sequences.get(sequence, false))


func _begin_rejection_capture(command: GameCommand) -> void:
	_captured_rejection_command = command
	_captured_rejection_reason = ""
	if not CommandProcessor.command_rejected.is_connected(
			_capture_submitted_command_rejection):
		CommandProcessor.command_rejected.connect(
				_capture_submitted_command_rejection)


func _end_rejection_capture() -> String:
	if CommandProcessor.command_rejected.is_connected(
			_capture_submitted_command_rejection):
		CommandProcessor.command_rejected.disconnect(
				_capture_submitted_command_rejection)
	var reason: String = _captured_rejection_reason
	_captured_rejection_command = null
	_captured_rejection_reason = ""
	return reason


func _capture_submitted_command_rejection(
		command: GameCommand, reason: String) -> void:
	if command == _captured_rejection_command:
		_captured_rejection_reason = reason


func _send_command_rejection(
		peer_id: int, command_data: Dictionary, reason: String) -> void:
	var deterministic_reason: String = reason
	if deterministic_reason.is_empty():
		deterministic_reason = "Command rejected by authoritative validation."
	_receive_command_rejection.rpc_id(
			peer_id, command_data, deterministic_reason)


## Server → submitting client only: acknowledges authoritative rejection
## without creating an accepted command result or broadcast.
@rpc("authority", "reliable")
func _receive_command_rejection(
		command_data: Dictionary, reason: String) -> void:
	command_rejection_received.emit(command_data, reason)


## Server-side observer follow-up submitter.
## Called by [CommandProcessor.drain_observer_followups] after the triggering
## command has already been broadcast, preserving command-result order.
func _submit_observer_followup_from_server(command: GameCommand) -> void:
	if role != Role.SERVER:
		return
	var result: Dictionary = CommandProcessor.submit_deferred_followups(command)
	if result.is_empty():
		_log.info("Observer follow-up [%s] rejected by validation." %
				command.command_type)
		return
	_distribute_command_result(command, result)


func _drain_server_observer_followups() -> void:
	CommandProcessor.drain_observer_followups(
			Callable(self, "_submit_observer_followup_from_server"))


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
func broadcast_game_config(rng_seed: int, scenario_id: String,
		binding_data: Dictionary = {}) -> void:
	if role != Role.SERVER:
		_log.warn("broadcast_game_config() called but not server.")
		return
	_pending_game_config = {
		"rng_seed": rng_seed,
		"scenario_id": scenario_id,
		"match_player_control_binding": binding_data.duplicate(true),
	}
	_receive_game_config.rpc(rng_seed, scenario_id, binding_data)
	_log.info("Broadcast game config: seed=%d, scenario='%s'." % [
			rng_seed, scenario_id])


## Server: broadcasts deterministic game configuration with a setup package.
## The package remains player-indexed core JSON; no transport peer ids are added.
func broadcast_setup_package_config(
		rng_seed: int,
		package: FleetSetupPackage, binding_data: Dictionary = {}) -> void:
	if role != Role.SERVER:
		_log.warn("broadcast_setup_package_config() called but not server.")
		return
	if package == null:
		_log.warn("broadcast_setup_package_config() called with null package.")
		return
	var package_data: Dictionary = package.to_hashed_dict()
	_pending_game_config = _setup_package_config(rng_seed, package_data,
			binding_data)
	_receive_setup_package_config.rpc(rng_seed, package_data, binding_data)
	_log.info("Broadcast setup package config: seed=%d, hash=%s." % [
			rng_seed, package.canonical_hash().substr(0, 12)])


## Server → All: delivers game configuration before scene transition.
## G4.6.5.3.
@rpc("authority", "reliable")
func _receive_game_config(rng_seed: int, scenario_id: String,
		binding_data: Dictionary = {}) -> void:
	_pending_game_config = {
		"rng_seed": rng_seed,
		"scenario_id": scenario_id,
		"match_player_control_binding": binding_data.duplicate(true),
	}
	_log.info("Received game config: seed=%d, scenario='%s'." % [
			rng_seed, scenario_id])


## Server -> All: delivers a setup-package start before scene transition.
@rpc("authority", "reliable")
func _receive_setup_package_config(
		rng_seed: int,
		package_data: Dictionary, binding_data: Dictionary = {}) -> void:
	_pending_game_config = _setup_package_config(rng_seed, package_data,
			binding_data)
	_log.info("Received setup package config: seed=%d, hash=%s." % [
			rng_seed, str(package_data.get("package_hash", "")).substr(0, 12)])


func _setup_package_config(rng_seed: int, package_data: Dictionary,
		binding_data: Dictionary) -> Dictionary:
	var package: FleetSetupPackage = FleetSetupPackage.deserialize(package_data)
	return {
		"rng_seed": rng_seed,
		"scenario_id": package.scenario_id,
		"setup_package": package_data.duplicate(true),
		"match_player_control_binding": binding_data.duplicate(true),
	}


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
				_distribute_command_result_data(entry["command_data"], entry["result"])
			_drain_server_observer_followups()
		return
	# --- Normal path: broadcast immediately ---
	_distribute_command_result(command, result)
	_drain_server_observer_followups()


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
	_sync_gate.deactivate()
	peers.clear()
	_last_heartbeat.clear()
	_local_player_index = -1
	_pending_game_config = {}
	_host_match_principal_id = ""
	_resume_attempt = {}
	_post_publication_fresh_attempt_id = ""
	_client_staged_resume = {}
	_principal_command_admission_enabled = true
	_captured_rejection_command = null
	_captured_rejection_reason = ""
	_lobby_password = ""
	_active_port = 0
	if _peer:
		multiplayer.multiplayer_peer = null
		_peer.close()
		_peer = null
	role = Role.NONE
	_set_state(ConnectionState.DISCONNECTED)
