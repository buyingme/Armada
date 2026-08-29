extends Node

## Process-isolated MATCH-003 acceptance driver.  It uses public lobby/network
## APIs and production RPC delivery; it never invokes private RPC handlers.
const TIMEOUT_MSEC := 20000
var _args: Dictionary = {}
var _started := 0
var _role := ""
var _mapping := 0
var _shared := ""
var _scenario := "fresh"
var _started_resume := false
var _client_peer_seen := false
var _client_handshook := false
var _client_ready_sent := false
var _canonical_installs := 0
var _board_releases := 0
var _persisted_save_loaded := false
var _reconnect_offer_count := 0
var _host_fresh_live := false
var _assignment_events := 0
var _compatibility: Dictionary = {}

func _ready() -> void:
	_args = _parse_args(OS.get_cmdline_user_args())
	_role = str(_args.get("role", ""))
	_mapping = int(_args.get("mapping", "0"))
	_shared = str(_args.get("shared", ""))
	_scenario = str(_args.get("scenario", "fresh"))
	_started = Time.get_ticks_msec()
	if _role.is_empty() or _shared.is_empty():
		_finish(false, "invalid_arguments")
		return
	DirAccess.make_dir_recursive_absolute(_shared)
	LobbyManager.game_starting.connect(_on_game_starting)
	EventBus.game_started.connect(func() -> void: _canonical_installs += 1)
	LobbyManager.lobby_error.connect(func(reason: String) -> void: _finish(false, reason))
	LobbyManager.resume_assignment_required.connect(
			func(_attempt: String, _endpoints: Array, _players: Array) -> void:
				_assignment_events += 1)
	NetworkManager.handshake_accepted.connect(_on_client_handshake)
	NetworkManager.peer_authenticated.connect(_on_host_peer)
	NetworkManager.reconnect_assignment_ready.connect(_on_reconnect_assignment)
	NetworkManager.fresh_resume_failed.connect(func(reason: String) -> void: _finish(false, reason))
	if _role == "hot_seat":
		_begin_hot_seat_compatibility()
	elif _role == "host":
		if not NetworkManager.host(int(_args.get("port", "0"))):
			_finish(false, "host_failed")
			return
		LobbyManager.create_lobby("MATCH-003 acceptance")
		LobbyManager.set_ready(true)
	else:
		NetworkManager.connect_to_server("127.0.0.1", int(_args.get("port", "0")))

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _started > TIMEOUT_MSEC:
		_finish(false, "timeout")
	if _role == "host" and _client_peer_seen and not _started_resume \
			and LobbyManager.current_lobby != null \
			and LobbyManager.current_lobby.can_start():
		_begin_fresh_resume()
	if _role != "host" and _client_handshook and not _client_ready_sent \
			and LobbyManager.current_lobby != null:
		LobbyManager.set_ready(true)
		_client_ready_sent = true
	if _scenario == "reconnect" and _role == "host" and _host_fresh_live \
			and _reconnect_offer_count >= 2 and NetworkManager._resume_attempt.is_empty():
		for info: Dictionary in NetworkManager.peers.values():
			if bool(info.get("command_admission_enabled", false)) \
					and not str(info.get("match_principal_id", "")).is_empty():
				_finish(true, "reconnect_published_without_host_reload")

func _on_client_handshake(_player_index: int) -> void:
	_client_handshook = true
	if _scenario == "reconnect" and _role == "failed_reconnect":
		# Exercise production disconnect cleanup during reconnect staging.  The
		# server must make this endpoint explicitly assignable again before the
		# subsequent clean endpoint is proposed.
		NetworkManager.disconnect_from_server()
		_finish(true, "reconnect_staging_disconnect")

func _on_host_peer(_peer_id: int, _player_index: int, _name: String) -> void:
	_client_peer_seen = true


func _on_reconnect_assignment(endpoint_id: int, available_players: Array) -> void:
	if _role != "host" or _scenario != "reconnect" or available_players.is_empty():
		return
	_reconnect_offer_count += 1
	# This is the host's explicit acceptance-harness choice; it is not derived
	# from endpoint role or slot.
	NetworkManager.begin_reconnect_assignment(endpoint_id, int(available_players[0]))


func _begin_fresh_resume() -> void:
	if _started_resume:
		return
	_started_resume = true
	var state := GameState.new()
	state.initialize()
	state.install_match_player_control_binding(MatchPlayerControlBinding.create_two_human())
	var meta := SaveGameMetadata.new()
	meta.scenario_id = "learning_scenario"
	meta.game_mode = SaveGameMetadata.MODE_NETWORK
	meta.display_name = "match003-acceptance"
	meta.next_command_sequence = 0
	# The save stays under this host process's isolated acceptance root.  The
	# candidate passed to LobbyManager is the production load result, never the
	# in-memory state used to create the save.
	SaveGameManager.SAVE_DIR = _shared.path_join("host-owned-save")
	SaveGameManager.SIGNING_KEY_FILE = _shared.path_join("host-owned-save-key.bin")
	if not SaveGameManager.save_game(state, "match003-host-owned", meta):
		_finish(false, "persisted_save_failed")
		return
	var loaded: Dictionary = SaveGameManager.load_game("match003-host-owned")
	if not bool(loaded.get("ok", false)):
		_finish(false, "persisted_save_load_failed:" + str(loaded.get("reason", "")))
		return
	_persisted_save_loaded = true
	LobbyManager.resume_assignment_required.connect(_assign_explicitly, CONNECT_ONE_SHOT)
	LobbyManager.host_load_save(loaded.get("state") as GameState,
			loaded.get("meta") as SaveGameMetadata)


func _begin_hot_seat_compatibility() -> void:
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	SaveGameManager.SAVE_DIR = _shared.path_join("hot-seat-save")
	SaveGameManager.SIGNING_KEY_FILE = _shared.path_join("hot-seat-save-key.bin")
	var state := GameState.new()
	state.initialize()
	if not state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_hot_seat_human()):
		_finish(false, "hot_seat_binding_install_failed")
		return
	var expected_binding: Dictionary = state.serialize().get(
			"match_player_control_binding", {}) as Dictionary
	var named_meta := SaveGameManager.build_metadata_for(state, "match003-hot-seat-named")
	if not SaveGameManager.save_game(state, "match003-hot-seat-named", named_meta):
		_finish(false, "hot_seat_named_save_failed")
		return
	var named: Dictionary = SaveGameManager.load_game("match003-hot-seat-named")
	if not bool(named.get("ok", false)):
		_finish(false, "hot_seat_named_load_failed:" + str(named.get("reason", "")))
		return
	var named_state: GameState = named.get("state") as GameState
	var loaded_named_meta: SaveGameMetadata = named.get("meta") as SaveGameMetadata
	if named_state == null or loaded_named_meta == null \
			or loaded_named_meta.save_format_version != SaveGameMetadata.CURRENT_VERSION \
			or named_state.serialize().get("match_player_control_binding", {}) != expected_binding:
		_finish(false, "hot_seat_named_compatibility_mismatch")
		return
	if not GameManager.start_new_game_from_state(
			named_state, loaded_named_meta.scenario_id, loaded_named_meta.next_command_sequence):
		_finish(false, "hot_seat_named_install_failed")
		return
	var checkpoint_source_meta := SaveGameManager.build_metadata_for(
			state, "match003-hot-seat-checkpoint-source")
	if not SaveGameManager.save_game(
			state, "match003-hot-seat-checkpoint-source", checkpoint_source_meta):
		_finish(false, "hot_seat_checkpoint_source_save_failed")
		return
	if not _install_checkpoint_from_named("match003-hot-seat-checkpoint-source",
			SaveGameMetadata.MODE_HOT_SEAT):
		_finish(false, "hot_seat_checkpoint_artifact_failed")
		return
	var checkpoint: Dictionary = SaveGameManager.load_game_from_checkpoint(
			SaveGameMetadata.MODE_HOT_SEAT)
	if not bool(checkpoint.get("ok", false)):
		_finish(false, "hot_seat_checkpoint_load_failed:" + str(checkpoint.get("reason", "")))
		return
	var checkpoint_state: GameState = checkpoint.get("state") as GameState
	var checkpoint_meta: SaveGameMetadata = checkpoint.get("meta") as SaveGameMetadata
	if checkpoint_state == null or checkpoint_meta == null \
			or checkpoint_meta.save_format_version != SaveGameMetadata.CURRENT_VERSION \
			or checkpoint_state.serialize().get("match_player_control_binding", {}) != expected_binding:
		_finish(false, "hot_seat_checkpoint_compatibility_mismatch")
		return
	if not GameManager.start_new_game_from_state(
			checkpoint_state, checkpoint_meta.scenario_id, checkpoint_meta.next_command_sequence):
		_finish(false, "hot_seat_checkpoint_install_failed")
		return
	_compatibility = {
		"named_save_v5": loaded_named_meta.save_format_version,
		"checkpoint_v5": checkpoint_meta.save_format_version,
		"binding_before": expected_binding,
		"binding_after": GameManager.current_game_state.serialize().get(
				"match_player_control_binding", {}),
		"checkpoint_persisted": true,
		"network_role": int(NetworkManager.role),
		"network_peers": NetworkManager.get_peer_count(),
	}
	call_deferred("_finish", true, "hot_seat_named_and_checkpoint_loaded")


func _install_checkpoint_from_named(source_name: String, mode: String) -> bool:
	var source_path := SaveGameManager.SAVE_DIR.path_join(source_name + SaveGameManager.SAVE_EXT)
	var checkpoint_name := SaveGameManager.CHECKPOINT_NETWORK_NAME \
			if mode == SaveGameMetadata.MODE_NETWORK \
			else SaveGameManager.CHECKPOINT_HOT_SEAT_NAME
	var checkpoint_path := SaveGameManager.SAVE_DIR.path_join(
			checkpoint_name + SaveGameManager.SAVE_EXT)
	if DirAccess.copy_absolute(source_path, checkpoint_path) != OK:
		return false
	# This is the same validation and persisted-slot reconstruction performed
	# at process startup; the live Network case cannot restart its session.
	SaveGameManager._restore_checkpoint_slot(mode)
	return SaveGameManager.has_checkpoint(mode)


func _begin_network_same_live_named_load() -> void:
	var live_state: GameState = GameManager.current_game_state
	if live_state == null:
		_finish(false, "network_named_missing_live_state")
		return
	_compatibility["before"] = _network_compatibility_snapshot()
	var meta := SaveGameManager.build_metadata_for(live_state, "match003-network-named")
	if not SaveGameManager.save_game(live_state, "match003-network-named", meta):
		_finish(false, "network_named_save_failed")
		return
	var loaded: Dictionary = SaveGameManager.load_game("match003-network-named")
	if not bool(loaded.get("ok", false)):
		_finish(false, "network_named_load_failed:" + str(loaded.get("reason", "")))
		return
	var loaded_state: GameState = loaded.get("state") as GameState
	var loaded_meta: SaveGameMetadata = loaded.get("meta") as SaveGameMetadata
	if loaded_state == null or loaded_meta == null \
			or loaded_meta.save_format_version != SaveGameMetadata.CURRENT_VERSION \
			or loaded_state.serialize().get("match_player_control_binding", {}) != \
			_compatibility["before"].get("binding", {}):
		_finish(false, "network_named_compatibility_mismatch")
		return
	_compatibility["named_save_v5"] = loaded_meta.save_format_version
	LobbyManager.host_load_save(loaded_state, loaded_meta)


func _begin_network_same_live_checkpoint_load() -> void:
	var live_state: GameState = GameManager.current_game_state
	if live_state == null:
		_finish(false, "network_checkpoint_missing_live_state")
		return
	var source_meta := SaveGameManager.build_metadata_for(
			live_state, "match003-network-checkpoint-source")
	if not SaveGameManager.save_game(
			live_state, "match003-network-checkpoint-source", source_meta):
		_finish(false, "network_checkpoint_source_save_failed")
		return
	if not _install_checkpoint_from_named("match003-network-checkpoint-source",
			SaveGameMetadata.MODE_NETWORK):
		_finish(false, "network_checkpoint_artifact_failed")
		return
	var loaded: Dictionary = SaveGameManager.load_game_from_checkpoint(
			SaveGameMetadata.MODE_NETWORK)
	if not bool(loaded.get("ok", false)):
		_finish(false, "network_checkpoint_load_failed:" + str(loaded.get("reason", "")))
		return
	var loaded_state: GameState = loaded.get("state") as GameState
	var loaded_meta: SaveGameMetadata = loaded.get("meta") as SaveGameMetadata
	if loaded_state == null or loaded_meta == null \
			or loaded_meta.save_format_version != SaveGameMetadata.CURRENT_VERSION \
			or loaded_state.serialize().get("match_player_control_binding", {}) != \
			_compatibility["before"].get("binding", {}):
		_finish(false, "network_checkpoint_compatibility_mismatch")
		return
	_compatibility["checkpoint_v5"] = loaded_meta.save_format_version
	_compatibility["checkpoint_persisted"] = true
	LobbyManager.host_load_save(loaded_state, loaded_meta)


func _network_compatibility_snapshot() -> Dictionary:
	var state: GameState = GameManager.current_game_state
	var peer_associations := {}
	for endpoint: Variant in NetworkManager.peers:
		var info: Dictionary = NetworkManager.peers[endpoint] as Dictionary
		peer_associations[str(endpoint)] = {
			"principal": str(info.get("match_principal_id", "")),
			"player": int(info.get("player_index", -1)),
			"admission": bool(info.get("command_admission_enabled", false)),
		}
	var snapshot := {
		"binding": state.serialize().get("match_player_control_binding", {}),
		"cursor": CommandProcessor.get_next_sequence(),
		"player_index": NetworkManager.get_local_player_index(),
		"host_principal": str(NetworkManager._host_match_principal_id),
		"peers": peer_associations,
	}
	# The fresh-resume client starts from its production filtered mirror; the
	# pre-existing same-live load path installs the authorized canonical save.
	# Binding, association and cursor are the compatibility invariant shared by
	# both representations; the host additionally proves canonical hash stability.
	if NetworkManager.is_server():
		snapshot["state_hash"] = CanonicalJson.hash(state.serialize())
	return snapshot


func _finish_network_compatibility() -> void:
	_compatibility["after"] = _network_compatibility_snapshot()
	_compatibility["assignment_events_after_initial"] = _assignment_events - 1 if _role == "host" else _assignment_events
	if _compatibility.get("before", {}) != _compatibility.get("after", {}):
		_finish(false, "same_live_network_binding_or_association_changed")
		return
	call_deferred("_finish", true, "same_live_network_named_and_checkpoint_loaded")

func _assign_explicitly(_attempt: String, endpoints: Array, _players: Array) -> void:
	if endpoints.size() != 2:
		_finish(false, "unexpected_endpoint_shape")
	var remote := int(endpoints[1])
	var proposals := {1: 0 if _mapping == 0 else 1, remote: 1 if _mapping == 0 else 0}
	LobbyManager.submit_fresh_session_assignment(proposals)

func _on_game_starting() -> void:
	_board_releases += 1
	if _scenario == "compatibility_network":
		if _role == "host":
			if _board_releases == 1:
				call_deferred("_begin_network_same_live_named_load")
			elif _board_releases == 2:
				# Give the client a bounded frame window to install the named load
				# before the host starts the next same-live production load.
				await get_tree().create_timer(0.25).timeout
				_begin_network_same_live_checkpoint_load()
			elif _board_releases == 3:
				_finish_network_compatibility()
		elif _role == "client" and _board_releases == 3:
			_finish_network_compatibility()
		elif _role == "client" and _board_releases == 1:
			_compatibility["before"] = _network_compatibility_snapshot()
		return
	if _scenario == "reconnect":
		if _role == "host":
			_host_fresh_live = true
			return
		if _role == "incumbent":
			NetworkManager.disconnect_from_server()
			_finish(true, "incumbent_confirmed_loss")
			return
		if _role == "reconnect":
			_finish(true, "reconnect_released")
			return
	if _scenario == "fresh" and _role == "host":
		# Keep the production ENet pump alive long enough for the remote board
		# release RPC to arrive; this is harness lifecycle only.
		call_deferred("_finish_after_delay", true, "published")
		return
	_finish(true, "published")


func _finish_after_delay(ok: bool, reason: String) -> void:
	await get_tree().create_timer(0.5).timeout
	_finish(ok, reason)

func _finish(ok: bool, reason: String) -> void:
	if is_queued_for_deletion():
		return
	var file := FileAccess.open(_shared.path_join(_evidence_file_name() + ".json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"ok": ok, "reason": reason,
			"protocol": NetworkManager.PROTOCOL_VERSION, "mapping": _mapping,
			"role": _role, "admission": NetworkManager.is_player_command_admission_enabled(),
			"player_index": NetworkManager.get_local_player_index(),
			"canonical_installs": _canonical_installs, "board_releases": _board_releases,
			"persisted_save_loaded": _persisted_save_loaded,
			"reconnect_offers": _reconnect_offer_count,
			"assignment_events": _assignment_events,
			"resume_attempt_active": not NetworkManager._resume_attempt.is_empty(),
			"compatibility": _compatibility}))
	queue_free()
	get_tree().quit(0 if ok else 1)


func _evidence_file_name() -> String:
	if _scenario == "reconnect":
		return "reconnect-" + _role
	if _scenario == "compatibility_network":
		return "compat-network-" + _role
	if _scenario == "compatibility_hot_seat":
		return "compat-hot-seat"
	return "fresh-" + _role + "-" + str(_mapping)

func _parse_args(values: PackedStringArray) -> Dictionary:
	var result := {}
	for value: String in values:
		var parts := value.trim_prefix("--").split("=", false, 1)
		if parts.size() == 2:
			result[parts[0]] = parts[1]
	return result
