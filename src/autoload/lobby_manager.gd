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


const SETUP_MATCH_OPTIONS_SCRIPT: GDScript = preload(
		"res://src/core/setup/setup_match_options.gd")

const SETUP_PHASE_FLEET_SELECTION: String = "fleet_selection"
const SETUP_PHASE_FLEETS_READY: String = "fleets_ready"
const SETUP_PHASE_INITIATIVE_CONFIRMATION: String = "initiative_confirmation"
const SETUP_PHASE_OBJECTIVE_SELECTION: String = "objective_selection"
const SETUP_PHASE_OBJECTIVE_CONFIRMATION: String = "objective_confirmation"
const SETUP_PHASE_READY_TO_START: String = "ready_to_start"

const SETUP_KEY_PHASE: String = "phase"
const SETUP_KEY_INITIATIVE_CHOOSER: String = "initiative_chooser"
const SETUP_KEY_INITIATIVE_CONFIRMATIONS: String = "initiative_confirmations"
const SETUP_KEY_INITIATIVE_RANDOM: String = "initiative_random_selection"
const SETUP_KEY_INITIATIVE_TIED: String = "initiative_tied"
const SETUP_KEY_PLAYER_POINTS: String = "player_points"
const SETUP_KEY_OBJECTIVE_CANDIDATES: String = "objective_candidates"
const SETUP_KEY_OBJECTIVE_CHOICE_LOCKED: String = "objective_choice_locked"
const SETUP_KEY_OBJECTIVE_CONFIRMATIONS: String = "objective_confirmations"
const SETUP_KEY_OBJECTIVE_OWNER_PLAYER: String = "objective_owner_player"
const SETUP_KEY_SELECTED_OBJECTIVE_KEY: String = "selected_objective_key"
const SETUP_KEY_VALIDATION_STATUS: String = "validation_status"

const VALIDATION_MESSAGE_NAMES_BLANK: String = "Player names must not be blank"
const VALIDATION_MESSAGE_NAMES_DIFFERENT: String = "Player names must be different"
const VALIDATION_MESSAGE_FACTIONS_DIFFERENT: String = \
		"Invalid fleet selection. Fleets must have different factions."


# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted when a lobby is created (host-side).
signal lobby_created(lobby_data: Dictionary)

## Emitted when this client has joined a lobby (client-side).
@warning_ignore("unused_signal")
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
	if SETUP_MATCH_OPTIONS_SCRIPT.is_setup_match_type(scenario_id):
		if not can_start_setup_match():
			lobby_error.emit("Both players must choose valid fleets before starting.")
			return
		var setup_package: FleetSetupPackage = _prepare_setup_draft_for_start()
		if setup_package == null:
			lobby_error.emit("Setup package draft is unavailable.")
			return
		NetworkManager.broadcast_setup_package_config(rng_seed, setup_package)
		_notify_game_start.rpc()
		NetworkManager.start_game()
		game_starting.emit()
		return
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
func set_ready(is_ready: bool) -> void:
	if current_lobby == null:
		return
	if NetworkManager.is_server():
		current_lobby.set_player_ready(1, is_ready)
		_broadcast_lobby_state()
	else:
		_request_set_ready.rpc_id(1, is_ready)


## Returns the lobby code, or empty if no lobby exists.
func get_lobby_code() -> String:
	if current_lobby:
		return current_lobby.code
	return ""


## Returns [code]true[/code] if the local player is the host.
func is_host() -> bool:
	return NetworkManager.is_server()


## Updates the selected New Game match type (host only).
## G4.5.4 / FB14A — scenario and setup picker.
func update_scenario(scenario_id: String) -> void:
	if not NetworkManager.is_server():
		return
	if current_lobby == null:
		return
	current_lobby.scenario = LobbyState.normalize_scenario_id(scenario_id)
	current_lobby.setup_draft = _setup_draft_for_match_type(current_lobby.scenario)
	_log.info("Scenario changed to '%s'." % current_lobby.scenario)
	_broadcast_lobby_state()


func _selected_scenario_id() -> String:
	if current_lobby == null:
		return LobbyState.SCENARIO_LEARNING_ID
	return LobbyState.normalize_scenario_id(current_lobby.scenario)


## Returns the local player's setup index in the lobby.
func local_setup_player_index() -> int:
	var local_player: int = NetworkManager.get_local_player_index()
	if NetworkManager.is_server():
		return 0 if local_player < 0 else local_player
	return local_player


## Loads and submits the local player's selected fleet into the shared setup draft.
func submit_local_setup_roster(fleet_id: String) -> Dictionary:
	if current_lobby == null:
		return _setup_failure("No lobby active.")
	if not SETUP_MATCH_OPTIONS_SCRIPT.is_setup_match_type(_selected_scenario_id()):
		return _setup_failure("Selected match type does not use fleet setup.")
	var load_result: Dictionary = FleetLibraryManager.new().load_roster(fleet_id)
	if not bool(load_result.get("ok", false)):
		var message: String = str(load_result.get("message", "Failed to load fleet."))
		lobby_error.emit(message)
		return _setup_failure(message)
	var roster: FleetRoster = load_result.get("roster") as FleetRoster
	var player_index: int = local_setup_player_index()
	if NetworkManager.is_server():
		_apply_setup_roster_data(player_index, roster.serialize())
		return {"ok": true}
	_request_setup_roster.rpc_id(1, roster.serialize())
	return {"awaiting_remote": true}


## Submits the controller's first-player choice into the shared setup draft.
func submit_first_player_choice(first_player: int) -> Dictionary:
	if current_lobby == null or not _selected_scenario_uses_setup():
		return _setup_failure("No active setup draft.")
	var player_index: int = local_setup_player_index()
	if NetworkManager.is_server():
		_apply_first_player_choice(player_index, first_player)
		return {"ok": true}
	_request_first_player_choice.rpc_id(1, first_player)
	return {"awaiting_remote": true}


## Confirms the post-lobby initiative screen for the local player.
func confirm_initiative_screen() -> Dictionary:
	if current_lobby == null or not _selected_scenario_uses_setup():
		return _setup_failure("No active setup draft.")
	var player_index: int = local_setup_player_index()
	if NetworkManager.is_server():
		_apply_initiative_confirmation(player_index)
		return {"ok": true}
	_request_initiative_confirmation.rpc_id(1)
	return {"awaiting_remote": true}


## Locks the selected objective or acknowledges the locked choice.
func confirm_setup_objective(objective_key: String = "") -> Dictionary:
	if current_lobby == null or not _selected_scenario_uses_setup():
		return _setup_failure("No active setup draft.")
	var player_index: int = local_setup_player_index()
	if NetworkManager.is_server():
		_apply_objective_confirmation(player_index, objective_key)
		return {"ok": true}
	_request_objective_confirmation.rpc_id(1, objective_key)
	return {"awaiting_remote": true}


## Returns true when the shared setup draft is ready for host start.
func can_start_setup_match() -> bool:
	if current_lobby == null:
		return false
	var state: Dictionary = _current_setup_state()
	var status: Dictionary = state.get(SETUP_KEY_VALIDATION_STATUS, {}) as Dictionary
	return str(state.get(SETUP_KEY_PHASE, "")) == SETUP_PHASE_FLEETS_READY \
			and bool(status.get("ok", false))


func _setup_draft_for_match_type(match_type_id: String) -> Dictionary:
	if not SETUP_MATCH_OPTIONS_SCRIPT.is_setup_match_type(match_type_id):
		return {}
	var draft: FleetSetupPackage = SETUP_MATCH_OPTIONS_SCRIPT.create_setup_package_draft(
			match_type_id)
	if draft == null:
		return {}
	draft.setup_state.merge(_default_setup_state(), true)
	return draft.serialize()


func _default_setup_state() -> Dictionary:
	return {
		SETUP_KEY_PHASE: SETUP_PHASE_FLEET_SELECTION,
		SETUP_KEY_INITIATIVE_CHOOSER: - 1,
		SETUP_KEY_INITIATIVE_CONFIRMATIONS: {"0": false, "1": false},
		SETUP_KEY_INITIATIVE_RANDOM: false,
		SETUP_KEY_INITIATIVE_TIED: false,
		SETUP_KEY_PLAYER_POINTS: [],
		SETUP_KEY_OBJECTIVE_CANDIDATES: [],
		SETUP_KEY_OBJECTIVE_CHOICE_LOCKED: false,
		SETUP_KEY_OBJECTIVE_CONFIRMATIONS: {"0": false, "1": false},
		SETUP_KEY_OBJECTIVE_OWNER_PLAYER: - 1,
		SETUP_KEY_SELECTED_OBJECTIVE_KEY: "",
		SETUP_KEY_VALIDATION_STATUS: {
			"ok": false,
			"messages": ["Both players must choose a fleet."],
			"package_hash": "",
		},
	}


func _selected_scenario_uses_setup() -> bool:
	return SETUP_MATCH_OPTIONS_SCRIPT.is_setup_match_type(_selected_scenario_id())


func _setup_failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}


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
func _request_set_ready(is_ready: bool) -> void:
	if not NetworkManager.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if current_lobby == null:
		return
	if current_lobby.set_player_ready(sender_id, is_ready):
		_log.info("Player (peer %d) ready = %s." % [
				sender_id, str(is_ready)])
		_broadcast_lobby_state()


@rpc("any_peer", "reliable")
func _request_setup_roster(roster_data: Dictionary) -> void:
	if not NetworkManager.is_server():
		return
	var player_index: int = _sender_player_index()
	_apply_setup_roster_data(player_index, roster_data)


@rpc("any_peer", "reliable")
func _request_first_player_choice(first_player: int) -> void:
	if not NetworkManager.is_server():
		return
	var player_index: int = _sender_player_index()
	_apply_first_player_choice(player_index, first_player)


@rpc("any_peer", "reliable")
func _request_initiative_confirmation() -> void:
	if not NetworkManager.is_server():
		return
	var player_index: int = _sender_player_index()
	_apply_initiative_confirmation(player_index)


@rpc("any_peer", "reliable")
func _request_objective_confirmation(objective_key: String) -> void:
	if not NetworkManager.is_server():
		return
	var player_index: int = _sender_player_index()
	_apply_objective_confirmation(player_index, objective_key)


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


func _sender_player_index() -> int:
	if current_lobby == null:
		return -1
	var sender_id: int = multiplayer.get_remote_sender_id()
	var player: Dictionary = current_lobby.get_player(sender_id)
	return int(player.get("player_index", -1))


func _apply_setup_roster_data(player_index: int, roster_data: Dictionary) -> void:
	var draft: FleetSetupPackage = _active_setup_draft()
	if draft == null or not _player_index_valid(player_index):
		return
	var roster: FleetRoster = FleetRoster.deserialize(roster_data)
	_upsert_roster_entry(draft, player_index, roster)
	_reset_objective_choice_state(draft.setup_state)
	_rebuild_setup_draft(draft)
	_store_setup_draft(draft)
	_broadcast_lobby_state()


func _apply_first_player_choice(player_index: int, first_player: int) -> void:
	var draft: FleetSetupPackage = _active_setup_draft()
	if draft == null or not _player_index_valid(first_player):
		return
	var state: Dictionary = _draft_state(draft)
	if player_index != int(state.get(SETUP_KEY_INITIATIVE_CHOOSER, -1)):
		return
	if bool(state.get(SETUP_KEY_INITIATIVE_TIED, false)):
		return
	state["resolved_first_player"] = first_player
	state[SETUP_KEY_INITIATIVE_CONFIRMATIONS] = _confirmations_for_player(-1)
	draft.setup_state = state
	_store_setup_draft(draft)
	_broadcast_lobby_state()


func _apply_initiative_confirmation(player_index: int) -> void:
	var draft: FleetSetupPackage = _active_setup_draft()
	if draft == null or not _player_index_valid(player_index):
		return
	var state: Dictionary = _draft_state(draft)
	if str(state.get(SETUP_KEY_PHASE, "")) != SETUP_PHASE_INITIATIVE_CONFIRMATION:
		return
	var confirmations: Dictionary = _initiative_confirmations(state)
	confirmations[str(player_index)] = true
	state[SETUP_KEY_INITIATIVE_CONFIRMATIONS] = confirmations
	if bool(confirmations.get("0", false)) and bool(confirmations.get("1", false)):
		state[SETUP_KEY_PHASE] = SETUP_PHASE_OBJECTIVE_SELECTION
		_populate_objective_candidates(_rosters_from_draft(draft), state)
	draft.setup_state = state
	_store_setup_draft(draft)
	_broadcast_lobby_state()


func _apply_objective_confirmation(player_index: int, objective_key: String) -> void:
	var draft: FleetSetupPackage = _active_setup_draft()
	if draft == null or not _player_index_valid(player_index):
		return
	var state: Dictionary = _draft_state(draft)
	if not bool(state.get(SETUP_KEY_OBJECTIVE_CHOICE_LOCKED, false)):
		if str(state.get(SETUP_KEY_PHASE, "")) != SETUP_PHASE_OBJECTIVE_SELECTION:
			return
		if player_index != _first_player_from_state(state):
			return
		if not _candidate_keys(state).has(objective_key):
			return
		state[SETUP_KEY_SELECTED_OBJECTIVE_KEY] = objective_key
		state[SETUP_KEY_OBJECTIVE_CHOICE_LOCKED] = true
		state[SETUP_KEY_OBJECTIVE_CONFIRMATIONS] = _confirmations_for_player(player_index)
	else:
		if str(state.get(SETUP_KEY_PHASE, "")) != SETUP_PHASE_OBJECTIVE_CONFIRMATION:
			return
		var confirmations: Dictionary = _confirmations(state)
		confirmations[str(player_index)] = true
		state[SETUP_KEY_OBJECTIVE_CONFIRMATIONS] = confirmations
	draft.setup_state = state
	_apply_locked_objective_phase(draft, _rosters_from_draft(draft), state)
	_store_setup_draft(draft)
	_broadcast_lobby_state()


func _active_setup_draft() -> FleetSetupPackage:
	if current_lobby == null or not _selected_scenario_uses_setup():
		return null
	if current_lobby.setup_draft.is_empty():
		current_lobby.setup_draft = _setup_draft_for_match_type(current_lobby.scenario)
	if current_lobby.setup_draft.is_empty():
		return null
	return FleetSetupPackage.deserialize(current_lobby.setup_draft)


func _store_setup_draft(draft: FleetSetupPackage) -> void:
	if current_lobby == null or draft == null:
		return
	current_lobby.setup_draft = draft.serialize()


func _draft_state(draft: FleetSetupPackage) -> Dictionary:
	var state: Dictionary = _default_setup_state()
	state.merge(draft.setup_state, true)
	return state


func _current_setup_state() -> Dictionary:
	if current_lobby == null:
		return _default_setup_state()
	var draft_data: Dictionary = current_lobby.setup_draft
	return _default_setup_state() if draft_data.is_empty() else _draft_state(
			FleetSetupPackage.deserialize(draft_data))


func _upsert_roster_entry(draft: FleetSetupPackage, player_index: int,
		roster: FleetRoster) -> void:
	var entries: Array[Dictionary] = draft.players.duplicate(true)
	var replacement: Dictionary = {
		"player_index": player_index,
		"display_name": _setup_player_display_name(player_index),
		"faction": roster.faction,
		"roster": roster.serialize(),
	}
	for entry_index: int in range(entries.size()):
		if int(entries[entry_index].get("player_index", -1)) == player_index:
			entries[entry_index] = replacement
			draft.players = entries
			return
	entries.append(replacement)
	draft.players = entries


func _rebuild_setup_draft(draft: FleetSetupPackage) -> void:
	var state: Dictionary = _draft_state(draft)
	var rosters: Array = _rosters_from_draft(draft)
	if _apply_roster_phase(draft, rosters, state):
		return
	state[SETUP_KEY_PHASE] = SETUP_PHASE_FLEETS_READY
	_set_validation_status(state, true, [])
	draft.setup_state = state


func _apply_roster_phase(draft: FleetSetupPackage, rosters: Array,
		state: Dictionary) -> bool:
	var messages: Array[String] = _roster_validation_messages(draft, rosters)
	if messages.is_empty():
		return false
	_reset_objective_choice_state(state)
	state[SETUP_KEY_PHASE] = SETUP_PHASE_FLEET_SELECTION
	_set_validation_status(state, false, messages)
	draft.selected_objective = {}
	draft.first_player = 0
	draft.setup_state = state
	return true


func _apply_locked_objective_phase(draft: FleetSetupPackage, rosters: Array,
		state: Dictionary) -> void:
	var result: Dictionary = _build_setup_package_result(draft, rosters, state)
	if not bool(result.get("ok", false)):
		state[SETUP_KEY_PHASE] = SETUP_PHASE_OBJECTIVE_SELECTION
		state[SETUP_KEY_OBJECTIVE_CHOICE_LOCKED] = false
		_set_validation_status(state, false, ["Selected objective is not legal for this setup."])
		draft.selected_objective = {}
		draft.setup_state = state
		return
	var package: FleetSetupPackage = result.get("package") as FleetSetupPackage
	_copy_built_package_fields(draft, package)
	state[SETUP_KEY_PHASE] = SETUP_PHASE_READY_TO_START \
			if _all_players_confirmed(state) else SETUP_PHASE_OBJECTIVE_CONFIRMATION
	_set_validation_status(state, true, [], package.canonical_hash())
	draft.setup_state = state


func _prepare_setup_draft_for_start() -> FleetSetupPackage:
	var draft: FleetSetupPackage = _active_setup_draft()
	if draft == null:
		return null
	var rosters: Array = _rosters_from_draft(draft)
	var state: Dictionary = _draft_state(draft)
	if not _roster_validation_messages(draft, rosters).is_empty():
		return null
	_resolve_initiative_state(rosters, state)
	_reset_objective_choice_state(state)
	state[SETUP_KEY_PHASE] = SETUP_PHASE_INITIATIVE_CONFIRMATION
	state[SETUP_KEY_INITIATIVE_CONFIRMATIONS] = _confirmations_for_player(-1)
	draft.first_player = _first_player_from_state(state)
	draft.selected_objective = {}
	draft.setup_state = state
	_store_setup_draft(draft)
	return draft


func _rosters_from_draft(draft: FleetSetupPackage) -> Array:
	var rosters: Array = [null, null]
	for entry: Dictionary in draft.players:
		var player_index: int = int(entry.get("player_index", -1))
		if not _player_index_valid(player_index):
			continue
		var roster_data: Dictionary = entry.get("roster", {}) as Dictionary
		rosters[player_index] = FleetRoster.deserialize(roster_data)
	return rosters


func _roster_validation_messages(draft: FleetSetupPackage, rosters: Array) -> Array[String]:
	var messages: Array[String] = []
	messages.append_array(_display_name_validation_messages(draft))
	if rosters.size() != Constants.PLAYER_COUNT or rosters[0] == null or rosters[1] == null:
		messages.append("Both players must choose a fleet.")
		return messages
	var validator: FleetValidator = FleetValidator.new()
	for player_index: int in range(Constants.PLAYER_COUNT):
		var validation: FleetValidationResult = validator.validate(rosters[player_index] as FleetRoster)
		if not validation.is_valid():
			messages.append("Player %d fleet is invalid." % (player_index + 1))
	if str((rosters[0] as FleetRoster).faction) == str((rosters[1] as FleetRoster).faction):
		messages.append(VALIDATION_MESSAGE_FACTIONS_DIFFERENT)
	if not FleetBuilderOptions.point_formats_match(
			(rosters[0] as FleetRoster).point_format,
			(rosters[1] as FleetRoster).point_format):
		messages.append("Both fleets must match the selected point format.")
	return messages


func _display_name_validation_messages(draft: FleetSetupPackage) -> Array[String]:
	var messages: Array[String] = []
	var names: Array[String] = _setup_player_display_names(draft)
	if names[0].is_empty() or names[1].is_empty():
		messages.append(VALIDATION_MESSAGE_NAMES_BLANK)
		return messages
	if names[0] == names[1]:
		messages.append(VALIDATION_MESSAGE_NAMES_DIFFERENT)
	return messages


func _setup_player_display_names(draft: FleetSetupPackage) -> Array[String]:
	var names: Array[String] = []
	for player_index: int in range(Constants.PLAYER_COUNT):
		names.append(_setup_player_display_name_from_draft(draft, player_index))
	return names


func _setup_player_display_name_from_draft(
		draft: FleetSetupPackage,
		player_index: int) -> String:
	var entry_name: String = _draft_player_display_name(draft, player_index)
	if not entry_name.is_empty():
		return entry_name
	return _setup_player_display_name(player_index)


func _draft_player_display_name(draft: FleetSetupPackage, player_index: int) -> String:
	if draft == null:
		return ""
	for entry: Dictionary in draft.players:
		if int(entry.get("player_index", -1)) != player_index:
			continue
		return str(entry.get("display_name", "")).strip_edges()
	return ""


func _setup_player_display_name(player_index: int) -> String:
	if current_lobby == null:
		return ""
	for player: Dictionary in current_lobby.players:
		if int(player.get("player_index", -1)) != player_index:
			continue
		return str(player.get("display_name", "")).strip_edges()
	return ""


func _resolve_initiative_state(rosters: Array, state: Dictionary) -> void:
	var player_zero_points: int = _fleet_points(rosters[0] as FleetRoster)
	var player_one_points: int = _fleet_points(rosters[1] as FleetRoster)
	var is_tied: bool = player_zero_points == player_one_points
	var chooser: int = 0 if is_tied else (0 if player_zero_points < player_one_points else 1)
	state[SETUP_KEY_PLAYER_POINTS] = [player_zero_points, player_one_points]
	state[SETUP_KEY_INITIATIVE_TIED] = is_tied
	state[SETUP_KEY_INITIATIVE_CHOOSER] = chooser
	state[SETUP_KEY_INITIATIVE_RANDOM] = is_tied
	if is_tied:
		state["resolved_first_player"] = randi_range(0, Constants.PLAYER_COUNT - 1)
	else:
		state["resolved_first_player"] = chooser


func _populate_objective_candidates(rosters: Array, state: Dictionary) -> void:
	var first_player: int = _first_player_from_state(state)
	var owner_player: int = 1 - first_player
	state[SETUP_KEY_OBJECTIVE_OWNER_PLAYER] = owner_player
	state[SETUP_KEY_OBJECTIVE_CANDIDATES] = _objective_candidates(rosters[owner_player] as FleetRoster)
	if not _candidate_keys(state).has(str(state.get(SETUP_KEY_SELECTED_OBJECTIVE_KEY, ""))):
		_reset_objective_choice_state(state)
		state[SETUP_KEY_OBJECTIVE_OWNER_PLAYER] = owner_player
		state[SETUP_KEY_OBJECTIVE_CANDIDATES] = _objective_candidates(rosters[owner_player] as FleetRoster)


func _objective_candidates(roster: FleetRoster) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if roster == null:
		return candidates
	for category: String in FleetObjectiveSelection.categories():
		var key: String = roster.objectives.get_objective(category)
		if key.strip_edges().is_empty():
			continue
		var data: ObjectiveData = AssetLoader.load_objective_data(key)
		candidates.append({
			"data_key": key,
			"category": category,
			"objective_name": key if data == null else data.objective_name,
		})
	return candidates


func _build_setup_package_result(draft: FleetSetupPackage, rosters: Array,
		state: Dictionary) -> Dictionary:
	var builder: FleetSetupPackageBuilder = FleetSetupPackageBuilder.new()
	return builder.build_from_peer_rosters_for_draft(
			rosters[0] as FleetRoster,
			rosters[1] as FleetRoster,
			0,
			_first_player_from_state(state),
			str(state.get(SETUP_KEY_SELECTED_OBJECTIVE_KEY, "")),
			draft)


func _copy_built_package_fields(target: FleetSetupPackage,
		built: FleetSetupPackage) -> void:
	target.point_format = built.point_format.duplicate(true)
	target.map = built.map.duplicate(true)
	target.first_player = built.first_player
	target.players = built.players.duplicate(true)
	target.selected_objective = built.selected_objective.duplicate(true)
	target.setup_state = target.setup_state.duplicate(true)


func _reset_objective_choice_state(state: Dictionary) -> void:
	state[SETUP_KEY_OBJECTIVE_CHOICE_LOCKED] = false
	state[SETUP_KEY_OBJECTIVE_CONFIRMATIONS] = _confirmations_for_player(-1)
	state[SETUP_KEY_OBJECTIVE_OWNER_PLAYER] = -1
	state[SETUP_KEY_SELECTED_OBJECTIVE_KEY] = ""
	state[SETUP_KEY_OBJECTIVE_CANDIDATES] = []


func _set_validation_status(state: Dictionary, ok: bool,
		messages: Array[String], package_hash: String = "") -> void:
	state[SETUP_KEY_VALIDATION_STATUS] = {
		"ok": ok,
		"messages": messages.duplicate(),
		"package_hash": package_hash,
	}


func _confirmations_for_player(player_index: int) -> Dictionary:
	return {
		"0": player_index == 0,
		"1": player_index == 1,
	}


func _confirmations(state: Dictionary) -> Dictionary:
	return (state.get(SETUP_KEY_OBJECTIVE_CONFIRMATIONS, {}) as Dictionary).duplicate(true)


func _initiative_confirmations(state: Dictionary) -> Dictionary:
	return (state.get(SETUP_KEY_INITIATIVE_CONFIRMATIONS, {}) as Dictionary).duplicate(true)


func _candidate_keys(state: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	var raw_candidates: Variant = state.get(SETUP_KEY_OBJECTIVE_CANDIDATES, [])
	if not raw_candidates is Array:
		return keys
	for raw_candidate: Variant in raw_candidates as Array:
		if raw_candidate is Dictionary:
			keys.append(str((raw_candidate as Dictionary).get("data_key", "")))
	return keys


func _first_player_from_state(state: Dictionary) -> int:
	return int(state.get("resolved_first_player", -1))


func _all_players_confirmed(state: Dictionary) -> bool:
	var confirmations: Dictionary = _confirmations(state)
	return bool(confirmations.get("0", false)) and bool(confirmations.get("1", false))


func _fleet_points(roster: FleetRoster) -> int:
	return int(FleetRosterSummary.calculate(roster).get(
			FleetRosterSummary.KEY_TOTAL_POINTS, 0))


func _player_index_valid(player_index: int) -> bool:
	return player_index >= 0 and player_index < Constants.PLAYER_COUNT


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
