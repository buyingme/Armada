## Lobby Manager
##
## Autoload singleton that manages game lobby lifecycle.
## Handles lobby creation, player joining/leaving, ready state,
## and game start coordination via RPCs.
##
## Server creates a [LobbyState] and broadcasts it to clients.
## Clients receive lobby state updates and emit local signals
## for the lobby UI to react.
##
## G4 Network Plan: §4 — G4.5.1, G4.5.2
extends Node


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a lobby is created (host-side).
signal lobby_created(lobby_data: Dictionary)

## Emitted when this client has joined a lobby (client-side).
signal lobby_joined(lobby_data: Dictionary)

## Emitted when this client has left the lobby.
signal lobby_left()

## Emitted when the lobby state is updated (player join/leave/ready).
signal lobby_updated(lobby_data: Dictionary)

## Emitted when an error occurs during a lobby operation.
signal lobby_error(message: String)

## Emitted when the game is about to start.
signal game_starting()

## Emitted on the client immediately after a load broadcast arrives,
## before the scene transition.  The board reacts indirectly because
## [signal game_starting] is emitted right after.  Phase J7.
signal load_state_received()


# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## The current lobby state (both server and client).
var current_lobby: LobbyState = null

## Logger for this system.
var _log: GameLogger = GameLogger.new("LobbyManager")


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	NetworkManager.peer_authenticated.connect(_on_peer_authenticated)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)


# ---------------------------------------------------------------------------
# Public API — Host
# ---------------------------------------------------------------------------

## Creates a new lobby (server-side).
## Must be called after [method NetworkManager.host].
## [param lobby_name] — human-readable name for the lobby.
## [param password] — optional plaintext password (hashed internally).
func create_lobby(lobby_name: String, password: String = "") -> void:
	if not NetworkManager.is_server():
		_log.warn("create_lobby() called but not server.")
		lobby_error.emit("Must be server to create lobby.")
		return
	current_lobby = LobbyState.new()
	current_lobby.lobby_id = PlayerProfile.get_client_id()
	current_lobby.code = LobbyState.generate_code()
	current_lobby.lobby_name = LobbyState.sanitize_name(lobby_name)
	current_lobby.host_peer_id = 1
	if password != "":
		current_lobby.password_hash = password.sha256_text()
	# Add host as player 0.
	var host_name: String = PlayerProfile.get_display_name()
	current_lobby.add_player(1, host_name, 0)
	_log.info("Lobby created: '%s' (code: %s)." % [
			current_lobby.lobby_name, current_lobby.code])
	lobby_created.emit(current_lobby.serialize())


## Starts the game (host only).
## Validates that the lobby is ready, generates the shared RNG seed,
## broadcasts game configuration, then notifies all peers to transition.
## G4.6.5.2 — server-side game initialisation.
func request_start_game() -> void:
	if not NetworkManager.is_server():
		_log.warn("request_start_game() called but not server.")
		return
	if current_lobby == null or not current_lobby.can_start():
		_log.warn("Cannot start game — lobby not ready.")
		lobby_error.emit("All players must be ready to start.")
		return
	_log.info("Starting game from lobby.")
	# Generate shared RNG seed and broadcast config BEFORE scene transition.
	var rng_seed: int = Time.get_ticks_usec()
	var scenario_id: String = _selected_scenario_id()
	NetworkManager.broadcast_game_config(rng_seed, scenario_id)
	_notify_game_start.rpc()
	NetworkManager.start_game()
	game_starting.emit()


## Loads a saved game and starts it for both peers (host only).
## Validates the lobby is in a startable state, installs the loaded
## state on the host, broadcasts it to the client, then triggers the
## same scene transition as [method request_start_game].  The board
## scene picks up the loaded state via [code]GameManager.is_state_preloaded[/code]
## (Phase J5.6).  Phase J7.
##
## [param state] — the deserialised [GameState] to install (host-side).
## [param meta] — the loaded save metadata (used for [code]scenario_id[/code]
##   and the broadcast payload).
func host_load_save(state: GameState, meta: SaveGameMetadata) -> void:
	if not NetworkManager.is_server():
		_log.warn("host_load_save() called but not server.")
		return
	if state == null or meta == null:
		_log.error("host_load_save() called with null state/meta.")
		return
	# Two valid call sites: from the lobby (current_lobby exists and is
	# Ready) or mid-session (no/stale lobby, but a peer is connected).
	# In both cases at least one peer must be reachable to receive the
	# broadcast.
	var lobby_ready: bool = (
			current_lobby != null and current_lobby.can_start())
	var in_session: bool = NetworkManager.get_peer_count() >= 1
	if not lobby_ready and not in_session:
		_log.warn("Cannot load game — lobby not ready and no peers.")
		lobby_error.emit("All players must be connected and Ready.")
		return
	_log.info("Host loading save '%s'." % meta.display_name)
	# Broadcast the serialised state to the client BEFORE installing on
	# the host, so both peers see the toast at roughly the same moment.
	var state_dict: Dictionary = state.serialize()
	_receive_loaded_state.rpc(
			state_dict, meta.scenario_id, meta.to_dict())
	# Install on host.  GameManager.start_new_game_from_state sets
	# is_state_preloaded so the GameBoard skips its bootstrap path.
	GameManager.start_new_game_from_state(state, meta.scenario_id)
	NetworkManager.start_game()
	game_starting.emit()
	# Phase J7 in-session: when called mid-game the host is already on
	# game_board, so the lobby_room → main_menu scene-transition chain
	# never runs.  Force a board-scene reload here so the host picks up
	# the preloaded state via the same code path as a lobby start.
	_maybe_force_board_reload()


# ---------------------------------------------------------------------------
# Public API — Common
# ---------------------------------------------------------------------------

## Leaves the current lobby and disconnects.
func leave_lobby() -> void:
	if current_lobby == null:
		return
	_log.info("Leaving lobby '%s'." % current_lobby.lobby_name)
	current_lobby = null
	NetworkManager.disconnect_from_server()
	lobby_left.emit()


## Sets the ready status of the local player.
func set_ready(ready: bool) -> void:
	if current_lobby == null:
		return
	if NetworkManager.is_server():
		current_lobby.set_player_ready(1, ready)
		_broadcast_lobby_state()
	else:
		_request_set_ready.rpc_id(1, ready)


## Returns the lobby code, or empty if no lobby exists.
func get_lobby_code() -> String:
	if current_lobby:
		return current_lobby.code
	return ""


## Returns [code]true[/code] if the local player is the host.
func is_host() -> bool:
	return NetworkManager.is_server()


## Updates the selected scenario (host only).
## G4.5.4 — scenario picker.
func update_scenario(scenario_id: String) -> void:
	if not NetworkManager.is_server():
		return
	if current_lobby == null:
		return
	current_lobby.scenario = LobbyState.normalize_scenario_id(scenario_id)
	_log.info("Scenario changed to '%s'." % current_lobby.scenario)
	_broadcast_lobby_state()


func _selected_scenario_id() -> String:
	if current_lobby == null:
		return LobbyState.SCENARIO_LEARNING_ID
	return LobbyState.normalize_scenario_id(current_lobby.scenario)


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Server-side: a peer completed handshake — add to lobby.
func _on_peer_authenticated(peer_id: int, player_index: int,
		display_name: String) -> void:
	if not NetworkManager.is_server():
		return
	if current_lobby == null:
		_log.warn("Peer %d authenticated but no lobby exists." % peer_id)
		return
	_log.info("Lobby has %d player(s) before add: %s." % [
			current_lobby.get_player_count(),
			str(current_lobby.players)])
	if current_lobby.add_player(peer_id, display_name, player_index):
		_log.info("Player '%s' (peer %d) joined lobby as player %d." % [
				display_name, peer_id, player_index])
		_log.info("Lobby now has %d player(s): %s." % [
				current_lobby.get_player_count(),
				str(current_lobby.players)])
		_broadcast_lobby_state()
	else:
		_log.warn("Failed to add player '%s' (peer %d, index %d) — lobby full or duplicate." % [
				display_name, peer_id, player_index])


## Server-side: a peer disconnected — remove from lobby.
func _on_peer_disconnected(peer_id: int) -> void:
	if not NetworkManager.is_server():
		return
	if current_lobby == null:
		return
	if current_lobby.remove_player(peer_id):
		_log.info("Player (peer %d) removed from lobby." % peer_id)
		_broadcast_lobby_state()


# ---------------------------------------------------------------------------
# RPCs
# ---------------------------------------------------------------------------

## Client → Server: request to set ready status.
@rpc("any_peer", "reliable")
func _request_set_ready(ready: bool) -> void:
	if not NetworkManager.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if current_lobby == null:
		return
	if current_lobby.set_player_ready(sender_id, ready):
		_log.info("Player (peer %d) ready = %s." % [
				sender_id, str(ready)])
		_broadcast_lobby_state()


## Server → All: broadcasts the full lobby state to all clients.
@rpc("authority", "reliable")
func _sync_lobby_state(data: Dictionary) -> void:
	current_lobby = LobbyState.deserialize(data)
	lobby_updated.emit(data)


## Server → All: notifies that the game is starting.
@rpc("authority", "reliable")
func _notify_game_start() -> void:
	_log.info("Game starting notification received.")
	game_starting.emit()


## Server → Client: delivers a serialised [GameState] for a host-driven
## load.  The client deserialises, installs via
## [code]GameManager.start_new_game_from_state[/code], shows a brief
## "Host is loading…" toast, then emits [signal game_starting] so the
## same scene-transition path runs as for a fresh lobby start.  Phase J7.
@rpc("authority", "reliable")
func _receive_loaded_state(
		state_dict: Dictionary,
		scenario_id: String,
		_meta_dict: Dictionary) -> void:
	_log.info("Received loaded state from host (scenario='%s')." %
			scenario_id)
	if is_instance_valid(TooltipManager):
		TooltipManager.show_text(
				"Host is loading the game…", Vector2.INF, 2.0, true)
	var state: GameState = GameState.deserialize(state_dict)
	if state == null:
		_log.error("Failed to deserialise host's loaded state.")
		lobby_error.emit("Failed to deserialise loaded game from host.")
		return
	GameManager.start_new_game_from_state(state, scenario_id)
	load_state_received.emit()
	game_starting.emit()
	# Phase J7 in-session: same reasoning as host_load_save — when the
	# client receives this RPC mid-session it is already on the board,
	# so the lobby_room transition chain never fires.  Force a reload.
	_maybe_force_board_reload()


## When the receiver is currently on the game-board scene, force a
## scene reload so the new preloaded [GameState] is consumed via the
## standard [GameBoard._ready] path.  When the receiver is still on
## the lobby/main-menu scene the existing
## [signal game_starting] → [code]_on_lobby_game_start[/code] chain
## handles the transition, so this is a no-op there.  Phase J7.
func _maybe_force_board_reload() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var current: Node = tree.current_scene
	if current == null:
		return
	var path: String = current.scene_file_path
	if path.find("game_board") == -1:
		return
	tree.change_scene_to_file(
			"res://src/scenes/game_board/game_board.tscn")


# ---------------------------------------------------------------------------
# Server helpers
# ---------------------------------------------------------------------------

## Broadcasts the current lobby state to all connected peers.
func _broadcast_lobby_state() -> void:
	if not NetworkManager.is_server():
		return
	if current_lobby == null:
		return
	var data: Dictionary = current_lobby.serialize()
	# Send to all connected clients.
	_sync_lobby_state.rpc(data)
	# Also update locally on the server.
	lobby_updated.emit(data)
