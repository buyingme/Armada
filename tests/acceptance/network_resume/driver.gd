extends Node

## Process-isolated MATCH-003 acceptance driver.  It uses public lobby/network
## APIs and production RPC delivery; it never invokes private RPC handlers.
const TIMEOUT_MSEC := 20000
const INITIAL_CURSOR := 8
const GAME_BOARD_SCENE: PackedScene = preload(
		"res://src/scenes/game_board/game_board.tscn")
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
var _board_entries := 0
var _resume_publications := 0
var _resume_commits := 0
var _persisted_save_loaded := false
var _reconnect_offer_count := 0
var _host_fresh_live := false
var _assignment_events := 0
var _compatibility: Dictionary = {}
var _saved_evidence: Dictionary = {}
var _installed_evidence: Dictionary = {}
var _game_board: GameBoard = null
var _dice_submitted := false
var _accuracy_submitted := false
var _defense_submitted := false
var _acknowledged := false
var _repair_submitted := false
var _gameplay_evidence: Dictionary = {}
var _commanded_evidence: Dictionary = {}
var _commanded_attack_started := false
var _commanded_dice_submitted := false
var _commanded_confirm_submitted := false
var _commanded_defense_submitted := false
var _commanded_ack_submitted := false
var _commanded_move_submitted := false
var _commanded_projection_written := false
var _commanded_order: Array[String] = []
var _commanded_rejections: Array[String] = []
var _decline_evidence: Dictionary = {}
var _decline_submitted := false
var _decline_next_selected := false
var _decline_projection_written := false
var _activation_gate_evidence: Dictionary = {}
var _activation_gate_selected := false
var _activation_gate_projection_written := false
var _end_activation_evidence: Dictionary = {}
var _end_maneuver_submitted := false
var _end_done_seen_msec := 0
var _end_control_clicked := false
var _end_projection_written := false
var _end_rejections: Array[String] = []
var _finish_started := false

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
	EventBus.game_started.connect(_on_canonical_install)
	LobbyManager.lobby_error.connect(func(reason: String) -> void: _finish(false, reason))
	LobbyManager.resume_assignment_required.connect(
			func(_attempt: String, _endpoints: Array, _players: Array) -> void:
				_assignment_events += 1)
	NetworkManager.handshake_accepted.connect(_on_client_handshake)
	NetworkManager.peer_authenticated.connect(_on_host_peer)
	NetworkManager.reconnect_assignment_ready.connect(_on_reconnect_assignment)
	NetworkManager.fresh_resume_failed.connect(func(reason: String) -> void: _finish(false, reason))
	NetworkManager.fresh_resume_published.connect(
			func(_attempt: String) -> void: _resume_publications += 1)
	NetworkManager.resume_commit_received.connect(
			func(_state: GameState, _meta: SaveGameMetadata,
					_principal: String, _player: int, _attempt: String) -> void:
				_resume_commits += 1)
	CommandProcessor.command_executed.connect(_capture_commanded_command)
	CommandProcessor.command_rejected.connect(_capture_commanded_rejection)
	GameManager.network_command_rejected.connect(_capture_commanded_rejection)
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
	if _scenario == "fresh" and _host_fresh_live:
		_advance_fresh_gameplay()
	if _scenario == "commanded_squadron" and _host_fresh_live:
		_advance_commanded_squadron()
	if _scenario == "commanded_decline" and _host_fresh_live:
		_advance_commanded_decline()
	if _scenario in ["commanded_activation_gate",
			"commanded_activation_reject"] and _host_fresh_live:
		_advance_commanded_activation_gate()
	if _scenario == "ship_end_activation" and _host_fresh_live:
		_advance_ship_end_activation()

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
	var state: GameState = _build_commanded_squadron_state() \
			if _scenario in ["commanded_squadron", "commanded_decline"] else (
					_build_commanded_selection_state() \
					if _scenario in ["commanded_activation_gate",
							"commanded_activation_reject"] else (
					_build_ship_end_activation_state() \
					if _scenario == "ship_end_activation" \
					else _build_learning_resume_state()))
	if state == null:
		_finish(false, "learning_resume_state_failed")
		return
	var meta := SaveGameMetadata.new()
	meta.scenario_id = "learning_scenario"
	meta.game_mode = SaveGameMetadata.MODE_NETWORK
	meta.display_name = "match003-acceptance"
	meta.next_command_sequence = INITIAL_CURSOR
	_saved_evidence = _state_resume_evidence(state, INITIAL_CURSOR)
	CommandProcessor.reset()
	if not CommandProcessor.restore_next_sequence(INITIAL_CURSOR):
		_finish(false, "acceptance_cursor_install_failed")
		return
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
	var loaded_state: GameState = loaded.get("state") as GameState
	var loaded_meta: SaveGameMetadata = loaded.get("meta") as SaveGameMetadata
	if loaded_state == null or loaded_meta == null \
			or _state_resume_evidence(loaded_state,
					loaded_meta.next_command_sequence) != _saved_evidence:
		_finish(false, "persisted_learning_state_changed")
		return
	LobbyManager.resume_assignment_required.connect(_assign_explicitly, CONNECT_ONE_SHOT)
	LobbyManager.host_load_save(loaded_state, loaded_meta)


func _build_learning_resume_state() -> GameState:
	var state := GameState.new()
	state.rng = GameRng.new(424242)
	state.initialize()
	var prepared: Dictionary = LearningScenarioPreparer.prepare_game_state(
			LearningScenarioSetup.new(), state)
	if (prepared.get("ships", []) as Array).size() != 3 \
			or (prepared.get("squadrons", []) as Array).size() != 10 \
			or state.stable_ship_identity_error() != "" \
			or not state.install_match_player_control_binding(
					MatchPlayerControlBinding.create_two_human()):
		return null
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	var attacker: ShipInstance = state.get_ship(0, 0)
	var defender: ShipInstance = state.get_ship(1, 0)
	var repair_ship: ShipInstance = state.get_ship(0, 1)
	if attacker == null or defender == null or repair_ship == null \
			or not attacker.establish_ship_activation("ship-activation:acceptance"):
		return null
	attacker.begin_attack_step()
	# One prior declaration makes the resumed attack the second and ensures the
	# accepted result-inspection continuation closes the attack step.
	attacker.commit_attack(Constants.HullZone.LEFT, 1,
			CurrentAttackState.KIND_SHIP, 0)
	attacker.commit_attack(Constants.HullZone.FRONT, 1,
			CurrentAttackState.KIND_SHIP, 0)
	defender.current_shields["FRONT"] = 0
	repair_ship.current_shields["REAR"] = maxi(0,
			int(repair_ship.current_shields.get("REAR", 0)) - 1)
	var attack := CurrentAttackState.new()
	if not attack.configure_active("attack:%d" % (INITIAL_CURSOR - 1), {
		"attacker_player": 0,
		"attacker_kind": CurrentAttackState.KIND_SHIP,
		"attacker_index": 0,
		"attacker_zone": int(Constants.HullZone.FRONT),
		"defender_player": 1,
		"defender_kind": CurrentAttackState.KIND_SHIP,
		"defender_index": 0,
		"defender_zone": int(Constants.HullZone.FRONT),
		"attack_kind": SquadronKeywordRuleHelper.ATTACK_KIND_STANDARD,
		"range_band": Constants.RANGE_BAND_CLOSE,
		"obstructed": false,
		"obstruction_resolved": true,
		"dice_pool": {"BLUE": 4},
		"cf_dial_resolution": CurrentAttackState.RESOLUTION_UNAVAILABLE,
		"cf_token_resolution": CurrentAttackState.RESOLUTION_UNAVAILABLE,
	}) or not state.set_current_attack_state(attack):
		return null
	return state


func _build_commanded_squadron_state() -> GameState:
	var state := GameState.new()
	state.rng = GameRng.new(424242)
	state.initialize()
	var prepared: Dictionary = LearningScenarioPreparer.prepare_game_state(
			LearningScenarioSetup.new(), state)
	if (prepared.get("ships", []) as Array).size() != 3 \
			or (prepared.get("squadrons", []) as Array).size() != 10 \
			or state.stable_ship_identity_error() != "" \
			or not state.install_match_player_control_binding(
					MatchPlayerControlBinding.create_two_human()):
		return null
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	var ship: ShipInstance = state.get_ship(1, 0)
	var attacker: SquadronInstance = state.get_squadron(1, 0)
	var defender: SquadronInstance = state.get_squadron(0, 0)
	if ship == null or attacker == null or defender == null:
		return null
	ship.pos_x = 0.5
	ship.pos_y = 0.56
	ship.command_dial_stack = CommandDialStack.create(1)
	if not ship.command_dial_stack.assign_dials(
			[Constants.CommandType.SQUADRON], 1) \
			or ship.command_dial_stack.reveal_top().is_empty() \
			or not ship.establish_ship_activation(
					"ship-activation:commanded-acceptance") \
			or not ship.open_squadron_command_opportunity(
					ship.ship_activation_identity) \
			or not ship.commit_squadron_command_activation(
					ship.ship_activation_identity):
		return null
	attacker.pos_x = 0.5
	attacker.pos_y = 0.51
	attacker.squadron_data = attacker.squadron_data.duplicate(true) as SquadronData
	attacker.squadron_data.anti_squadron_armament = {"BLACK": 8}
	defender.pos_x = 0.5
	defender.pos_y = 0.48
	defender.current_hull = 1
	var next_squadron: SquadronInstance = state.get_squadron(1, 1)
	if next_squadron != null:
		next_squadron.pos_x = 0.52
		next_squadron.pos_y = 0.51
	if not attacker.initialize_activation_action_state(
			"squadron-activation:commanded-acceptance",
			SquadronInstance.ACTIVATION_CONTEXT_SHIP_SQUADRON_COMMAND,
			1, 0):
		return null
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.SQUADRON_STEP,
			1, Constants.Visibility.ALL,
			{"ship_index": 0,
				"ship_activation_identity": ship.ship_activation_identity})
	if not state.validate_declaration_adjacent_state():
		return null
	return state


func _build_commanded_selection_state() -> GameState:
	var state: GameState = _build_commanded_squadron_state()
	if state == null:
		return null
	var ship: ShipInstance = state.get_ship(1, 0)
	var attacker: SquadronInstance = state.get_squadron(1, 0)
	attacker.reset_activation_action_state()
	ship.squadron_command_activations_committed = 0
	if not state.validate_declaration_adjacent_state():
		return null
	return state


func _build_ship_end_activation_state() -> GameState:
	var state := GameState.new()
	state.rng = GameRng.new(424242)
	state.initialize()
	var prepared: Dictionary = LearningScenarioPreparer.prepare_game_state(
			LearningScenarioSetup.new(), state)
	if (prepared.get("ships", []) as Array).size() != 3 \
			or state.stable_ship_identity_error() != "" \
			or not state.install_match_player_control_binding(
					MatchPlayerControlBinding.create_two_human()):
		return null
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	var ship: ShipInstance = state.get_ship(1, 0)
	if ship == null:
		return null
	ship.current_speed = 1
	ship.command_dial_stack = CommandDialStack.create(1)
	if not ship.command_dial_stack.assign_dials(
			[Constants.CommandType.NAVIGATE], 1) \
			or ship.command_dial_stack.reveal_top().is_empty() \
			or not ship.establish_ship_activation(
					"ship-activation:end-acceptance") \
			or not ship.consume_unreached_squadron_command_opportunity(
					ship.ship_activation_identity, true) \
			or not ship.open_maneuver_opportunity(
					ship.ship_activation_identity):
		return null
	state.interaction_flow = InteractionFlow.make(
			Constants.InteractionFlow.SHIP_ACTIVATION,
			Constants.InteractionStep.MANEUVER_STEP,
			1, Constants.Visibility.ALL,
			{"ship_index": 0,
				"ship_activation_identity": ship.ship_activation_identity})
	if not state.validate_declaration_adjacent_state():
		return null
	return state


func _state_resume_evidence(state: GameState, cursor: int) -> Dictionary:
	if state == null:
		return {}
	var ids: Array[String] = []
	var ship_count := 0
	var squadron_count := 0
	for player: int in range(Constants.PLAYER_COUNT):
		var player_state: PlayerState = state.get_player_state(player)
		ship_count += player_state.ships.size()
		squadron_count += player_state.squadrons.size()
		for raw_ship: Variant in player_state.ships:
			ids.append((raw_ship as ShipInstance).roster_entry_id)
	return {
		"cursor": cursor,
		"ship_ids": ids,
		"ship_count": ship_count,
		"squadron_count": squadron_count,
		"attack": CanonicalJson.hash(state.current_attack_state.serialize()),
		"damage_draw_count": state.damage_deck.get_draw_count()
				if state.damage_deck != null else
				state.passive_damage_ledger.draw_count,
		"deck": CanonicalJson.hash(state.damage_deck.serialize())
				if state.damage_deck != null else "passive",
	}


func _on_canonical_install() -> void:
	_canonical_installs += 1
	if _scenario not in ["fresh", "commanded_squadron", "commanded_decline",
			"commanded_activation_gate", "commanded_activation_reject",
			"ship_end_activation"] \
			or GameManager.current_game_state == null:
		return
	_installed_evidence = _state_resume_evidence(
			GameManager.current_game_state, CommandProcessor.get_next_sequence())


func _begin_hot_seat_compatibility() -> void:
	PlayMode.set_mode(PlayMode.Mode.HOT_SEAT)
	SaveGameManager.SAVE_DIR = _shared.path_join("hot-seat-save")
	SaveGameManager.SIGNING_KEY_FILE = _shared.path_join("hot-seat-save-key.bin")
	var state := GameState.new()
	state.initialize()
	state.damage_deck = DamageDeck.new()
	state.damage_deck.set_rng(state.rng)
	state.damage_deck.initialize()
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
		"named_save_v6": loaded_named_meta.save_format_version,
		"checkpoint_v6": checkpoint_meta.save_format_version,
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
	_compatibility["named_save_v6"] = loaded_meta.save_format_version
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
	_compatibility["checkpoint_v6"] = loaded_meta.save_format_version
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


func _enter_game_board() -> void:
	if _game_board != null or GameManager.current_game_state == null:
		return
	_game_board = GAME_BOARD_SCENE.instantiate() as GameBoard
	if _game_board == null:
		_finish(false, "game_board_instantiation_failed")
		return
	add_child(_game_board)
	_board_entries += 1
	if _role == "client" and _scenario == "fresh":
		# The driver owns all acceptance choices. Keep the real reconstructed
		# board as a passive projection so its deferred UI helpers cannot race
		# the deterministic authority sequence with synthetic button actions.
		GameManager.set_command_submitter(CommandSubmitter.new())


func _advance_fresh_gameplay() -> void:
	if _game_board == null or GameManager.current_game_state == null:
		return
	var state: GameState = GameManager.current_game_state
	if _role != "host":
		_finish_client_after_convergence(state)
		return
	var attack: CurrentAttackState = state.current_attack_state
	if attack.active:
		if attack.stage == CurrentAttackState.STAGE_PRE_ROLL \
				and not _dice_submitted:
			_dice_submitted = true
			if GameManager.get_command_submitter().submit_authoritative(
					RollDiceCommand.new(attack.attacker_player, {
						"attack_id": attack.attack_id,
					})).is_empty():
				_finish(false, "dice_roll_failed")
		elif attack.stage == CurrentAttackState.STAGE_ACCURACY \
				and not _accuracy_submitted:
			_accuracy_submitted = true
			if GameManager.get_command_submitter().submit_authoritative(
					CommitAccuracyCommand.new(attack.attacker_player, {
						"attack_id": attack.attack_id,
						"locked_tokens": [],
					})).is_empty():
				_finish(false, "accuracy_commit_failed")
		elif attack.stage == CurrentAttackState.STAGE_DEFENSE \
				and attack.defense_stage == CurrentAttackState.DEFENSE_PENDING \
				and not _defense_submitted:
			_defense_submitted = true
			if GameManager.get_command_submitter().submit_authoritative(
					CommitDefenseCommand.new(attack.defender_player, {
						"attack_id": attack.attack_id,
						"defender_kind": attack.defender_kind,
						"defender_index": attack.defender_index,
						"selected_indices": [],
					})).is_empty():
				_finish(false, "defense_commit_failed")
		return
	var inspection: CompletedAttackInspection = state.completed_attack_inspection
	if inspection != null and inspection.is_satisfied() == false \
			and not _acknowledged:
		_acknowledged = true
		var inspection_id: String = inspection.inspection_id()
		for player: int in range(Constants.PLAYER_COUNT):
			if GameManager.get_command_submitter().submit_authoritative(
					AcknowledgeAttackResultCommand.new(player, {
						"inspection_id": inspection_id,
					})).is_empty():
				_finish(false, "attack_result_ack_failed")
				return
		return
	if inspection == null and not _repair_submitted:
		_repair_submitted = true
		var defender: ShipInstance = state.get_ship(1, 0)
		var repair_ship: ShipInstance = state.get_ship(0, 1)
		var pre_repair: int = int(repair_ship.current_shields.get("REAR", -1))
		var repair_result: Dictionary = \
				GameManager.get_command_submitter().submit_authoritative(
						RepairActionCommand.new(0, {
							"action_type": "recover_shields",
							"owner_player": 0,
							"ship_index": 1,
							"zone": "REAR",
						}))
		if repair_result.is_empty():
			_finish(false, "repair_command_failed")
			return
		_gameplay_evidence = {
			"dice_rolled": _history_has("roll_dice"),
			"damage_resolved": _history_has("resolve_damage"),
			"defender_damage": defender.get_total_damage(),
			"repair_applied": int(repair_ship.current_shields.get("REAR", -1))
					== pre_repair + 1,
			"repair_command": _history_has("repair_action"),
			"final_cursor": CommandProcessor.get_next_sequence(),
		}
		var remote_viewer: int = 1 if _mapping == 0 else 0
		var filtered: Dictionary = StateFilter.filter_for_player_checked(
				state.serialize(), remote_viewer)
		if not bool(filtered.get(StateFilter.KEY_OK, false)):
			_finish(false, "final_projection_failed:" + str(filtered.get(
					StateFilter.KEY_REASON, "")))
			return
		var projection_path: String = _shared.path_join(
				"fresh-projection-%d.txt" % _mapping)
		var file := FileAccess.open(projection_path, FileAccess.WRITE)
		if file == null:
			_finish(false, "projection_evidence_write_failed")
			return
		file.store_string(CanonicalJson.hash(
				filtered.get(StateFilter.KEY_STATE, {}) as Dictionary))
		_finish(true, "real_learning_resume_gameplay_completed")


func _finish_client_after_convergence(state: GameState) -> void:
	if _repair_submitted:
		return
	var projection_path: String = _shared.path_join(
			"fresh-projection-%d.txt" % _mapping)
	if not FileAccess.file_exists(projection_path):
		return
	var expected: String = FileAccess.get_file_as_string(
			projection_path).strip_edges()
	var actual: String = CanonicalJson.hash(state.serialize())
	if expected != actual:
		return
	_repair_submitted = true
	var defender: ShipInstance = state.get_ship(1, 0)
	var repair_ship: ShipInstance = state.get_ship(0, 1)
	_gameplay_evidence = {
		"dice_rolled": _history_has("roll_dice"),
		"damage_resolved": _history_has("resolve_damage"),
		"defender_damage": defender.get_total_damage(),
		"repair_applied": int(repair_ship.current_shields.get("REAR", -1))
				== repair_ship.get_max_shields("REAR"),
		"repair_command": _history_has("repair_action"),
		"final_cursor": CommandProcessor.get_next_sequence(),
		"projection_converged": true,
	}
	_finish(true, "passive_projection_converged")


func _advance_commanded_squadron() -> void:
	if _game_board == null or GameManager.current_game_state == null:
		return
	var state: GameState = GameManager.current_game_state
	var attack: CurrentAttackState = state.current_attack_state
	if _role == "client":
		_advance_commanded_client(state, attack)
	else:
		_advance_commanded_host(state, attack)


func _advance_commanded_client(
		state: GameState, attack: CurrentAttackState) -> void:
	var controller: SquadronPhaseController = \
			_game_board._squadron_phase_controller
	var modal: SquadronActivationModal = controller.get_modal()
	var attacker: SquadronInstance = state.get_squadron(1, 0)
	var defender: SquadronInstance = state.get_squadron(0, 0)
	if modal == null or attacker == null or defender == null:
		_finish(false, "commanded_client_projection_missing")
		return
	if not _commanded_attack_started:
		if modal.get_state() != SquadronActivationModal.State.ACTION_CHOICE \
				or modal._selected_instance != attacker:
			return
		modal._on_attack_pressed()
		var defender_token: SquadronToken = \
				_game_board._find_squadron_token_for_instance(defender)
		if defender_token == null \
				or not _game_board._target_selector.handle_squadron_click(
						defender_token):
			_finish(false, "commanded_real_modal_target_failed")
			return
		var panel: AttackSimPanel = _game_board._target_selector.get_panel()
		if panel == null or not panel._confirm_is_declaration:
			_finish(false, "commanded_declaration_confirmation_missing")
			return
		panel._on_confirm_pressed()
		_commanded_attack_started = true
		return
	if attack.active:
		if attack.stage == CurrentAttackState.STAGE_PRE_ROLL \
				and not _commanded_dice_submitted:
			_commanded_dice_submitted = true
			if GameManager.submit_roll_dice(1).is_empty():
				_finish(false, "commanded_roll_failed")
		elif attack.stage == CurrentAttackState.STAGE_ATTACK_MODIFY \
				and not _commanded_confirm_submitted:
			_commanded_confirm_submitted = true
			if GameManager.submit_confirm_attack_dice(1).is_empty():
				_finish(false, "commanded_attack_confirm_failed")
		return
	var inspection: CompletedAttackInspection = state.completed_attack_inspection
	if inspection != null and not inspection.is_satisfied():
		if not _commanded_ack_submitted:
			_commanded_ack_submitted = true
			if GameManager.submit_acknowledge_attack_result(
					1, inspection.inspection_id()).is_empty():
				_finish(false, "commanded_client_ack_failed")
		return
	if not _commanded_move_submitted:
		if modal.get_state() != SquadronActivationModal.State.ACTION_CHOICE \
				or modal._selected_instance != attacker \
				or not modal._move_button.visible:
			return
		var attacker_token: SquadronToken = \
				_game_board._find_squadron_token_for_instance(attacker)
		if attacker_token == null:
			_finish(false, "commanded_move_token_missing")
			return
		modal._on_move_pressed()
		attacker_token.global_position += Vector2(10.0, 0.0)
		modal._on_commit_move_pressed()
		_commanded_move_submitted = true
		_commanded_evidence["pending_after_move_submit"] = \
				modal.is_move_submission_pending()
		_commanded_evidence["same_squadron_after_move_submit"] = \
				modal._selected_instance == attacker
		_commanded_evidence["no_early_ready"] = \
				modal.get_state() == SquadronActivationModal.State.MOVING
		_commanded_evidence["no_completion_at_move_submit"] = \
				_history_count(CompleteSquadronActivationCommand.TYPE) == 0
		_commanded_evidence["no_second_activation_at_move_submit"] = \
				_history_count("activate_squadron") == 0
		_commanded_evidence["no_premature_resource_spend"] = \
				_history_count("spend_dial") == 0 \
				and _history_count("spend_command_token") == 0 \
				and not state.get_ship(1, 0).command_dial_stack \
						.get_revealed_dial().is_empty()
		return
	var projection_path := _shared.path_join("commanded-projection.txt")
	if not FileAccess.file_exists(projection_path):
		return
	var expected: String = FileAccess.get_file_as_string(
			projection_path).strip_edges()
	if expected != CanonicalJson.hash(state.serialize()):
		return
	var ship: ShipInstance = state.get_ship(1, 0)
	_commanded_evidence.merge({
		"projection_converged": true,
		"defender_destroyed": defender.is_destroyed(),
		"move_count": _history_count("move_squadron"),
		"completion_count": _history_count(
				CompleteSquadronActivationCommand.TYPE),
		"ack_count": _history_count(AcknowledgeAttackResultCommand.TYPE),
		"activate_count": _history_count("activate_squadron"),
		"completion_without_inspection": bool(_commanded_evidence.get(
				"completion_without_inspection", false)),
		"move_consumed_inspection": bool(_commanded_evidence.get(
				"move_consumed_inspection", false)),
		"no_stale_rejection": not _commanded_has_rejection(
				CompleteSquadronActivationCommand.TYPE),
		"next_choice_ready": modal.get_state() \
				== SquadronActivationModal.State.WAITING_FOR_SELECTION \
				and modal._activation_number == 2 \
				and modal._selected_instance == null,
		"attacker_activated": attacker.activated_this_round,
		"attacker_moved": attacker.move_action_disposition \
				== SquadronInstance.MOVE_ACTION_COMMITTED,
		"ship_committed": ship.squadron_command_activations_committed,
		"dial_still_revealed": not ship.command_dial_stack \
				.get_revealed_dial().is_empty(),
		"cursor": CommandProcessor.get_next_sequence(),
		"order": _commanded_order,
	}, true)
	_finish(true, "commanded_squadron_ordering_converged")


func _advance_commanded_host(
		state: GameState, attack: CurrentAttackState) -> void:
	if attack.active and attack.stage == CurrentAttackState.STAGE_DEFENSE \
			and attack.defense_stage == CurrentAttackState.DEFENSE_PENDING \
			and not _commanded_defense_submitted:
		_commanded_defense_submitted = true
		var defender: SquadronInstance = state.get_squadron(0, 0)
		if GameManager.submit_commit_defense(defender, []).is_empty():
			_finish(false, "commanded_defense_failed")
		return
	var inspection: CompletedAttackInspection = state.completed_attack_inspection
	if not attack.active and inspection != null and not inspection.is_satisfied() \
			and not _commanded_ack_submitted:
		_commanded_ack_submitted = true
		if GameManager.submit_acknowledge_attack_result(
				0, inspection.inspection_id()).is_empty():
			_finish(false, "commanded_host_ack_failed")
		return
	if _history_count(CompleteSquadronActivationCommand.TYPE) != 1 \
			or _commanded_projection_written:
		return
	var filtered: Dictionary = StateFilter.filter_for_player_checked(
			state.serialize(), 1)
	if not bool(filtered.get(StateFilter.KEY_OK, false)):
		_finish(false, "commanded_projection_failed:" + str(filtered.get(
				StateFilter.KEY_REASON, "")))
		return
	var file := FileAccess.open(
			_shared.path_join("commanded-projection.txt"), FileAccess.WRITE)
	if file == null:
		_finish(false, "commanded_projection_write_failed")
		return
	file.store_string(CanonicalJson.hash(
			filtered.get(StateFilter.KEY_STATE, {}) as Dictionary))
	_commanded_projection_written = true
	var ship: ShipInstance = state.get_ship(1, 0)
	var attacker: SquadronInstance = state.get_squadron(1, 0)
	var defender: SquadronInstance = state.get_squadron(0, 0)
	_commanded_evidence = {
		"defender_destroyed": defender.is_destroyed(),
		"move_count": _history_count("move_squadron"),
		"completion_count": _history_count(
				CompleteSquadronActivationCommand.TYPE),
		"ack_count": _history_count(AcknowledgeAttackResultCommand.TYPE),
		"activate_count": _history_count("activate_squadron"),
		"completion_without_inspection": bool(_commanded_evidence.get(
				"completion_without_inspection", false)),
		"move_consumed_inspection": bool(_commanded_evidence.get(
				"move_consumed_inspection", false)),
		"no_stale_rejection": not _commanded_has_rejection(
				CompleteSquadronActivationCommand.TYPE),
		"attacker_activated": attacker.activated_this_round,
		"attacker_moved": attacker.move_action_disposition \
				== SquadronInstance.MOVE_ACTION_COMMITTED,
		"ship_committed": ship.squadron_command_activations_committed,
		"dial_still_revealed": not ship.command_dial_stack \
				.get_revealed_dial().is_empty(),
		"cursor": CommandProcessor.get_next_sequence(),
		"order": _commanded_order,
	}
	_finish(true, "commanded_squadron_authority_completed")


func _capture_commanded_command(command: GameCommand, _result: Dictionary) -> void:
	if command == null:
		return
	if _scenario == "ship_end_activation":
		if command.command_type == "end_activation":
			_end_activation_evidence["end_payload_identity"] = not str(
					command.payload.get("ship_activation_identity", "")).is_empty()
		return
	if _scenario not in ["commanded_squadron", "commanded_decline",
			"commanded_activation_gate", "commanded_activation_reject"]:
		return
	_commanded_order.append(command.command_type)
	if command.command_type == "move_squadron":
		_commanded_evidence["move_consumed_inspection"] = not str(
				command.payload.get("completed_attack_inspection_id", "")).is_empty()
		if _role == "client" and _game_board != null:
			var modal: SquadronActivationModal = \
					_game_board._squadron_phase_controller.get_modal()
			_commanded_evidence["pending_at_move_acceptance"] = \
					modal != null and modal.is_move_submission_pending()
			_commanded_evidence["no_completion_at_move_acceptance"] = \
					_history_count(CompleteSquadronActivationCommand.TYPE) == 0
	elif command.command_type == CompleteSquadronActivationCommand.TYPE:
		_commanded_evidence["completion_without_inspection"] = str(
				command.payload.get(
						"completed_attack_inspection_id", "")).is_empty()
	elif command.command_type == DeclineSquadronMoveCommand.TYPE:
		_decline_evidence["matching_activation_identity"] = not str(
				command.payload.get("activation_id", "")).is_empty()
		_decline_evidence["matching_ship_identity"] = not str(
				command.payload.get("ship_activation_identity", "")).is_empty()
		_decline_evidence["matching_inspection_identity"] = not str(
				command.payload.get(
						"completed_attack_inspection_id", "")).is_empty()
		_decline_evidence["matching_squadron_index"] = int(
				command.payload.get("squadron_index", -1)) == 0


func _capture_commanded_rejection(command: GameCommand, reason: String) -> void:
	if _scenario == "ship_end_activation" and command != null:
		_end_rejections.append(command.command_type + ":" + reason)
		return
	if _scenario in ["commanded_squadron", "commanded_decline",
			"commanded_activation_gate", "commanded_activation_reject"] \
			and command != null:
		_commanded_rejections.append(command.command_type + ":" + reason)


func _commanded_has_rejection(command_type: String) -> bool:
	for rejection: String in _commanded_rejections:
		if rejection.begins_with(command_type + ":"):
			return true
	return false


func _advance_commanded_decline() -> void:
	if _game_board == null or GameManager.current_game_state == null:
		return
	var state: GameState = GameManager.current_game_state
	if _role == "client":
		_advance_commanded_decline_client(state)
	else:
		_advance_commanded_decline_host(state)


func _advance_commanded_decline_client(state: GameState) -> void:
	var controller: SquadronPhaseController = \
			_game_board._squadron_phase_controller
	var modal: SquadronActivationModal = controller.get_modal()
	var attacker: SquadronInstance = state.get_squadron(1, 0)
	var defender: SquadronInstance = state.get_squadron(0, 0)
	if modal == null or attacker == null or defender == null:
		_finish(false, "decline_client_projection_missing")
		return
	if not _commanded_attack_started:
		if modal.get_state() != SquadronActivationModal.State.ACTION_CHOICE \
				or modal._selected_instance != attacker:
			return
		modal._on_attack_pressed()
		var target: SquadronToken = \
				_game_board._find_squadron_token_for_instance(defender)
		if target == null \
				or not _game_board._target_selector.handle_squadron_click(target):
			_finish(false, "decline_target_failed")
			return
		var panel: AttackSimPanel = _game_board._target_selector.get_panel()
		if panel == null or not panel._confirm_is_declaration:
			_finish(false, "decline_confirmation_missing")
			return
		panel._on_confirm_pressed()
		_commanded_attack_started = true
		return
	var attack: CurrentAttackState = state.current_attack_state
	if attack.active:
		if attack.stage == CurrentAttackState.STAGE_PRE_ROLL \
				and not _commanded_dice_submitted:
			_commanded_dice_submitted = true
			if GameManager.submit_roll_dice(1).is_empty():
				_finish(false, "decline_roll_failed")
		elif attack.stage == CurrentAttackState.STAGE_ATTACK_MODIFY \
				and not _commanded_confirm_submitted:
			_commanded_confirm_submitted = true
			if GameManager.submit_confirm_attack_dice(1).is_empty():
				_finish(false, "decline_confirm_failed")
		return
	var inspection: CompletedAttackInspection = state.completed_attack_inspection
	if inspection != null and not inspection.is_satisfied():
		if not _commanded_ack_submitted:
			_commanded_ack_submitted = true
			if GameManager.submit_acknowledge_attack_result(
					1, inspection.inspection_id()).is_empty():
				_finish(false, "decline_client_ack_failed")
		return
	if not _decline_submitted:
		if inspection == null \
				or modal.get_state() != SquadronActivationModal.State.ACTION_CHOICE \
				or modal._selected_instance != attacker:
			return
		var before := Vector2(attacker.pos_x, attacker.pos_y)
		modal._on_skip_pressed()
		_decline_submitted = true
		_decline_evidence.merge({
			"pending_after_submit": modal._move_decline_pending,
			"same_squadron_after_submit": modal._selected_instance == attacker,
			"no_early_ready": modal.get_state() \
					== SquadronActivationModal.State.ACTION_CHOICE,
			"no_position_change_at_submit":
					Vector2(attacker.pos_x, attacker.pos_y) == before,
			"no_completion_at_submit": _history_count(
					CompleteSquadronActivationCommand.TYPE) == 0,
		}, true)
		return
	if not _decline_next_selected:
		if _history_count(CompleteSquadronActivationCommand.TYPE) != 1 \
				or modal.get_state() \
						!= SquadronActivationModal.State.WAITING_FOR_SELECTION:
			return
		var next: SquadronInstance = state.get_squadron(1, 1)
		var next_token: SquadronToken = \
				_game_board._find_squadron_token_for_instance(next)
		if next_token == null or not controller.try_handle_squadron_click(next_token):
			_finish(false, "decline_next_selection_failed")
			return
		_decline_next_selected = true
		_decline_evidence["next_pending_before_acceptance"] = \
				modal.is_activation_acceptance_pending()
		_decline_evidence["no_second_capacity_before_acceptance"] = \
				state.get_ship(1, 0).squadron_command_activations_committed == 1
		return
	var projection_path := _shared.path_join("decline-projection.txt")
	if not FileAccess.file_exists(projection_path):
		return
	if FileAccess.get_file_as_string(projection_path).strip_edges() \
			!= CanonicalJson.hash(state.serialize()):
		return
	var next: SquadronInstance = state.get_squadron(1, 1)
	_decline_evidence.merge({
		"projection_converged": true,
		"decline_count": _history_count(DeclineSquadronMoveCommand.TYPE),
		"move_count": _history_count("move_squadron"),
		"completion_count": _history_count(
				CompleteSquadronActivationCommand.TYPE),
		"ack_count": _history_count(AcknowledgeAttackResultCommand.TYPE),
		"inspection_consumed": state.completed_attack_inspection == null,
		"attacker_declined": attacker.move_action_disposition \
				== SquadronInstance.MOVE_ACTION_DECLINED,
		"attacker_activated": attacker.activated_this_round,
		"next_activation_accepted": next.has_activation_action_state(),
		"ship_committed": state.get_ship(1, 0) \
				.squadron_command_activations_committed,
		"no_rejection": not _commanded_has_rejection(
				DeclineSquadronMoveCommand.TYPE) \
				and not _commanded_has_rejection(
						CompleteSquadronActivationCommand.TYPE) \
				and not _commanded_has_rejection("activate_squadron"),
		"cursor": CommandProcessor.get_next_sequence(),
	}, true)
	_finish(true, "commanded_decline_converged")


func _advance_commanded_decline_host(state: GameState) -> void:
	var attack: CurrentAttackState = state.current_attack_state
	if attack.active and attack.stage == CurrentAttackState.STAGE_DEFENSE \
			and attack.defense_stage == CurrentAttackState.DEFENSE_PENDING \
			and not _commanded_defense_submitted:
		_commanded_defense_submitted = true
		if GameManager.submit_commit_defense(state.get_squadron(0, 0), []).is_empty():
			_finish(false, "decline_defense_failed")
		return
	var inspection: CompletedAttackInspection = state.completed_attack_inspection
	if not attack.active and inspection != null and not inspection.is_satisfied() \
			and not _commanded_ack_submitted:
		_commanded_ack_submitted = true
		if GameManager.submit_acknowledge_attack_result(
				0, inspection.inspection_id()).is_empty():
			_finish(false, "decline_host_ack_failed")
		return
	if _history_count("activate_squadron") != 1 \
			or _decline_projection_written:
		return
	var filtered: Dictionary = StateFilter.filter_for_player_checked(
			state.serialize(), 1)
	if not bool(filtered.get(StateFilter.KEY_OK, false)):
		_finish(false, "decline_projection_failed")
		return
	var passive: GameState = GameState.deserialize_passive_network(
			filtered.get(StateFilter.KEY_STATE, {}) as Dictionary)
	var restored: GameState = GameState.deserialize(state.serialize())
	var attacker: SquadronInstance = state.get_squadron(1, 0)
	if passive == null or restored == null:
		_finish(false, "decline_restore_failed")
		return
	var file := FileAccess.open(
			_shared.path_join("decline-projection.txt"), FileAccess.WRITE)
	if file == null:
		_finish(false, "decline_projection_write_failed")
		return
	file.store_string(CanonicalJson.hash(
			filtered.get(StateFilter.KEY_STATE, {}) as Dictionary))
	_decline_projection_written = true
	_decline_evidence = {
		"decline_count": _history_count(DeclineSquadronMoveCommand.TYPE),
		"move_count": _history_count("move_squadron"),
		"completion_count": _history_count(
				CompleteSquadronActivationCommand.TYPE),
		"ack_count": _history_count(AcknowledgeAttackResultCommand.TYPE),
		"inspection_consumed": state.completed_attack_inspection == null,
		"attacker_declined": attacker.move_action_disposition \
				== SquadronInstance.MOVE_ACTION_DECLINED,
		"attacker_activated": attacker.activated_this_round,
		"save_restored_decline": restored.get_squadron(1, 0) \
				.move_action_disposition == SquadronInstance.MOVE_ACTION_DECLINED,
		"reconnect_restored_decline": passive.get_squadron(1, 0) \
				.move_action_disposition == SquadronInstance.MOVE_ACTION_DECLINED,
		"ship_committed": state.get_ship(1, 0) \
				.squadron_command_activations_committed,
		"no_rejection": not _commanded_has_rejection(
				DeclineSquadronMoveCommand.TYPE) \
				and not _commanded_has_rejection(
						CompleteSquadronActivationCommand.TYPE) \
				and not _commanded_has_rejection("activate_squadron"),
		"cursor": CommandProcessor.get_next_sequence(),
	}
	_finish(true, "commanded_decline_authority_completed")


func _advance_commanded_activation_gate() -> void:
	var state: GameState = GameManager.current_game_state
	var modal: SquadronActivationModal = \
			_game_board._squadron_phase_controller.get_modal()
	if state == null or modal == null:
		return
	if not modal.visible or not modal.is_command_mode():
		_game_board._ship_activation_controller \
				.open_squadron_command_from_interaction_state()
		return
	if _role == "client" and not _activation_gate_selected:
		if modal.get_state() != SquadronActivationModal.State.WAITING_FOR_SELECTION:
			return
		var first: SquadronInstance = state.get_squadron(1, 0)
		var first_token: SquadronToken = \
				_game_board._find_squadron_token_for_instance(first)
		if first_token == null \
				or not _game_board._squadron_phase_controller \
						.try_handle_squadron_click(first_token):
			_finish(false, "activation_gate_selection_failed")
			return
		_activation_gate_selected = true
		var second: SquadronInstance = state.get_squadron(1, 1)
		var second_token: SquadronToken = \
				_game_board._find_squadron_token_for_instance(second)
		var second_consumed: bool = _game_board._squadron_phase_controller \
				.try_handle_squadron_click(second_token)
		_activation_gate_evidence = {
			"pending_before_acceptance": modal.is_activation_acceptance_pending(),
			"one_candidate_retained": modal._selected_instance == first,
			"controls_non_actionable": not modal._move_button.visible \
					and not modal._attack_button.visible \
					and not modal._skip_button.visible,
			"second_selection_blocked": second_consumed \
					and modal._selected_instance == first,
			"no_local_identity": not first.has_activation_action_state(),
			"no_local_capacity": state.get_ship(1, 0) \
					.squadron_command_activations_committed == 0,
			"no_ready_progress": modal._activation_number == 1,
		}
		return
	var rejecting: bool = _scenario == "commanded_activation_reject"
	if rejecting:
		if _commanded_rejections.is_empty():
			return
		if _role == "client":
			_activation_gate_evidence.merge({
				"rejection_recovered":
						not modal.is_activation_acceptance_pending() \
						and modal._selected_instance == null \
						and modal.get_state() \
								== SquadronActivationModal.State.WAITING_FOR_SELECTION,
				"no_phantom_capacity": state.get_ship(1, 0) \
						.squadron_command_activations_committed == 0,
				"no_phantom_activation": not state.get_squadron(1, 0) \
						.has_activation_action_state(),
				"activate_count": _history_count("activate_squadron"),
				"rejections": _commanded_rejections.duplicate(),
			}, true)
		_finish(true, "activation_gate_rejection_recovered")
		return
	if _history_count("activate_squadron") != 1:
		return
	if _role == "host" and not _activation_gate_projection_written:
		var filtered: Dictionary = StateFilter.filter_for_player_checked(
				state.serialize(), 1)
		var file := FileAccess.open(
				_shared.path_join("activation-gate-projection.txt"), FileAccess.WRITE)
		if not bool(filtered.get(StateFilter.KEY_OK, false)) or file == null:
			_finish(false, "activation_gate_projection_failed")
			return
		file.store_string(CanonicalJson.hash(
				filtered.get(StateFilter.KEY_STATE, {}) as Dictionary))
		_activation_gate_projection_written = true
		_activation_gate_evidence = {
			"activate_count": 1,
			"identity_installed": state.get_squadron(1, 0) \
					.has_activation_action_state(),
			"capacity_installed": state.get_ship(1, 0) \
					.squadron_command_activations_committed == 1,
			"no_rejection": not _commanded_has_rejection("activate_squadron"),
			"cursor": CommandProcessor.get_next_sequence(),
		}
		_finish(true, "activation_gate_authority_accepted")
		return
	if _role == "client":
		var path := _shared.path_join("activation-gate-projection.txt")
		if not FileAccess.file_exists(path) \
				or FileAccess.get_file_as_string(path).strip_edges() \
						!= CanonicalJson.hash(state.serialize()):
			return
		_activation_gate_evidence.merge({
			"activate_count": 1,
			"identity_installed": state.get_squadron(1, 0) \
					.has_activation_action_state(),
			"capacity_installed": state.get_ship(1, 0) \
					.squadron_command_activations_committed == 1,
			"controls_enabled_once": modal.get_state() \
					== SquadronActivationModal.State.ACTION_CHOICE \
					and modal._selected_instance == state.get_squadron(1, 0),
			"projection_converged": true,
			"no_rejection": not _commanded_has_rejection("activate_squadron"),
			"cursor": CommandProcessor.get_next_sequence(),
		}, true)
		_finish(true, "activation_gate_client_accepted")


func _advance_ship_end_activation() -> void:
	if _game_board == null or GameManager.current_game_state == null:
		return
	var state: GameState = GameManager.current_game_state
	var ship: ShipInstance = state.get_ship(1, 0)
	if ship == null:
		_finish(false, "end_activation_ship_missing")
		return
	if _role == "host":
		_finish_ship_end_activation_host(state, ship)
		return
	var controller: ShipActivationController = \
			_game_board._ship_activation_controller
	var modal: ActivationModal = _game_board._panel_mgr.activation_modal
	if controller == null or modal == null:
		_finish(false, "end_activation_real_control_missing")
		return
	if not _end_maneuver_submitted:
		var maneuver: Dictionary = GameManager.submit_execute_maneuver(
				ship, 1, [0], ship.pos_x, ship.pos_y, ship.rotation_deg)
		if maneuver.is_empty():
			_finish(false, "end_activation_maneuver_submit_failed")
			return
		_end_maneuver_submitted = true
		# This is the existing production tail of a committed maneuver. It
		# requests the command-backed DONE projection without ending activation.
		controller.show_end_activation_after_maneuver()
		return
	if not _end_control_clicked:
		if state.interaction_flow.step_id \
				!= Constants.InteractionStep.ACTIVATION_DONE:
			return
		if _end_done_seen_msec == 0:
			_end_done_seen_msec = Time.get_ticks_msec()
			_end_activation_evidence["done_before_input"] = true
			_end_activation_evidence["identity_before_input"] = \
					not ship.ship_activation_identity.is_empty()
			_end_activation_evidence["not_activated_before_input"] = \
					not ship.activated_this_round
			_end_activation_evidence["no_end_before_input"] = \
					_history_count("end_activation") == 0
			return
		if Time.get_ticks_msec() - _end_done_seen_msec < 150:
			return
		if state.interaction_flow.step_id \
					!= Constants.InteractionStep.ACTIVATION_DONE \
				or ship.ship_activation_identity.is_empty() \
				or ship.activated_this_round \
				or not modal.is_open() \
				or not modal._end_activation_button.visible \
				or modal._end_activation_button.disabled:
			_finish(false, "end_activation_done_did_not_persist")
			return
		_end_activation_evidence["done_persisted_before_click"] = true
		_end_control_clicked = true
		modal._on_end_activation_pressed()
		return
	var projection_path := _shared.path_join("end-activation-projection.txt")
	if not FileAccess.file_exists(projection_path):
		return
	var client_hash := CanonicalJson.hash(state.serialize())
	var authority_hash := FileAccess.get_file_as_string(
			projection_path).strip_edges()
	if client_hash != authority_hash:
		_end_activation_evidence["client_hash"] = client_hash
		_end_activation_evidence["authority_hash"] = authority_hash
		return
	_end_activation_evidence.merge({
		"maneuver_count": _history_count("execute_maneuver"),
		"done_count": _history_count("advance_activation_step"),
		"end_count": _history_count("end_activation"),
		"identity_cleared": ship.ship_activation_identity.is_empty(),
		"ship_activated": ship.activated_this_round,
		"control_returned_player_zero": state.interaction_flow.controller_player == 0 \
				and GameManager.get_active_player() == 0,
		"projection_converged": true,
		"cursor": CommandProcessor.get_next_sequence(),
		"no_rejection": _end_rejections.is_empty(),
	}, true)
	_finish(true, "client_end_activation_converged")


func _finish_ship_end_activation_host(
		state: GameState, ship: ShipInstance) -> void:
	if _history_count("end_activation") != 1 or _end_projection_written:
		return
	var filtered: Dictionary = StateFilter.filter_for_player_checked(
			state.serialize(), 1)
	if not bool(filtered.get(StateFilter.KEY_OK, false)):
		_finish(false, "end_activation_projection_failed")
		return
	var file := FileAccess.open(
			_shared.path_join("end-activation-projection.txt"), FileAccess.WRITE)
	if file == null:
		_finish(false, "end_activation_projection_write_failed")
		return
	file.store_string(CanonicalJson.hash(
			filtered.get(StateFilter.KEY_STATE, {}) as Dictionary))
	_end_projection_written = true
	_end_activation_evidence = {
		"maneuver_count": _history_count("execute_maneuver"),
		"done_count": _history_count("advance_activation_step"),
		"end_count": _history_count("end_activation"),
		"end_payload_identity": bool(_end_activation_evidence.get(
				"end_payload_identity", false)),
		"identity_cleared": ship.ship_activation_identity.is_empty(),
		"ship_activated": ship.activated_this_round,
		"control_returned_player_zero": state.interaction_flow.controller_player == 0 \
				and GameManager.get_active_player() == 0,
		"cursor": CommandProcessor.get_next_sequence(),
		"no_rejection": _end_rejections.is_empty(),
	}
	_finish(true, "authority_end_activation_completed")


func _history_has(command_type: String) -> bool:
	for command: GameCommand in CommandProcessor.get_history():
		if command.command_type == command_type:
			return true
	return false


func _history_count(command_type: String) -> int:
	var count := 0
	for command: GameCommand in CommandProcessor.get_history():
		if command.command_type == command_type:
			count += 1
	return count

func _on_game_starting() -> void:
	_board_releases += 1
	# The acceptance scene intentionally bypasses MainMenu, so install the same
	# production submitter strategy that MainMenu installs before board entry.
	if NetworkManager.is_server():
		GameManager.set_command_submitter(NetworkHostCommandSubmitter.new())
	elif PlayMode.is_network():
		GameManager.set_command_submitter(NetworkCommandSubmitter.new())
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
		_host_fresh_live = true
		call_deferred("_enter_game_board")
		return
	if _scenario == "fresh" and _role == "client":
		_host_fresh_live = true
		call_deferred("_enter_game_board")
		return
	if _scenario == "commanded_squadron" \
			and _role in ["host", "client"]:
		_host_fresh_live = true
		call_deferred("_enter_game_board")
		return
	if _scenario in ["commanded_decline", "commanded_activation_gate",
			"commanded_activation_reject"] \
			and _role in ["host", "client"]:
		if _scenario == "commanded_activation_reject" and _role == "host":
			RuleRegistry.register_validator(FlowHook.validator(
					"acceptance.bug031.activation_rejection",
					Constants.InteractionFlow.SHIP_ACTIVATION,
					Constants.InteractionStep.SQUADRON_STEP,
					"activate_squadron",
					func(_state: GameState, _command: GameCommand) -> Dictionary:
						return {"allowed": false,
								"reason": "Controlled activation rejection."},
					1000))
		_host_fresh_live = true
		call_deferred("_enter_game_board")
		return
	if _scenario == "ship_end_activation" \
			and _role in ["host", "client"]:
		_host_fresh_live = true
		call_deferred("_enter_game_board")
		return
	_finish(true, "published")


func _finish_after_delay(ok: bool, reason: String) -> void:
	await get_tree().create_timer(0.5).timeout
	_finish(ok, reason)

func _finish(ok: bool, reason: String) -> void:
	if _finish_started:
		return
	_finish_started = true
	var file := FileAccess.open(_shared.path_join(_evidence_file_name() + ".json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"ok": ok, "reason": reason,
			"protocol": NetworkManager.PROTOCOL_VERSION, "mapping": _mapping,
			"role": _role, "admission": NetworkManager.is_player_command_admission_enabled(),
			"player_index": NetworkManager.get_local_player_index(),
			"canonical_installs": _canonical_installs, "board_releases": _board_releases,
			"board_entries": _board_entries,
			"resume_publications": _resume_publications,
			"resume_commits": _resume_commits,
			"persisted_save_loaded": _persisted_save_loaded,
			"reconnect_offers": _reconnect_offer_count,
			"assignment_events": _assignment_events,
			"resume_attempt_active": not NetworkManager._resume_attempt.is_empty(),
			"saved": _saved_evidence, "installed": _installed_evidence,
			"gameplay": _gameplay_evidence,
			"commanded": _commanded_evidence,
			"decline": _decline_evidence,
			"activation_gate": _activation_gate_evidence,
			"end_activation": _end_activation_evidence,
			"compatibility": _compatibility}))
	call_deferred("_shutdown_after_evidence", ok)


func _shutdown_after_evidence(ok: bool) -> void:
	if _role == "host":
		var peer_path: String = _peer_evidence_path()
		var deadline: int = Time.get_ticks_msec() + 3000
		while not peer_path.is_empty() and not FileAccess.file_exists(peer_path) \
				and Time.get_ticks_msec() < deadline:
			await get_tree().create_timer(0.1).timeout
		if _scenario == "commanded_activation_reject":
			# Release the acceptance-only validator closure before transport and
			# scene teardown. Production validators are process-static resources.
			RuleRegistry.clear()
		# The client owns its acceptance-process disconnect. Let process teardown
		# follow the authority's close after its evidence is durable; explicitly
		# closing both ENet peers in the same frame races ENet's disconnect callback.
		var host_settle_seconds := 1.5 \
				if _scenario == "commanded_activation_reject" else 0.35
		await get_tree().create_timer(host_settle_seconds).timeout
		NetworkManager.disconnect_from_server()
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if ok else 1)
		return
	# Keep the evidence-writing client alive long enough for the authority to
	# observe it and exit first. Simultaneous explicit ENet teardown can race the
	# peer-disconnected callback in headless two-process acceptance runs.
	var client_settle_seconds := 3.0 \
			if _scenario == "commanded_activation_reject" else 1.0
	await get_tree().create_timer(client_settle_seconds).timeout
	get_tree().quit(0 if ok else 1)


func _peer_evidence_path() -> String:
	if _scenario == "fresh":
		return _shared.path_join("fresh-client-%d.json" % _mapping)
	if _scenario == "commanded_squadron":
		return _shared.path_join("commanded-client.json")
	if _scenario == "commanded_decline":
		return _shared.path_join("decline-client.json")
	if _scenario in ["commanded_activation_gate",
			"commanded_activation_reject"]:
		return _shared.path_join(
				("activation-reject" if _scenario.ends_with("reject") \
				else "activation-gate") + "-client.json")
	if _scenario == "ship_end_activation":
		return _shared.path_join("end-activation-client.json")
	if _scenario == "compatibility_network":
		return _shared.path_join("compat-network-client.json")
	if _scenario == "reconnect":
		return _shared.path_join("reconnect-reconnect.json")
	return ""


func _evidence_file_name() -> String:
	if _scenario == "reconnect":
		return "reconnect-" + _role
	if _scenario == "compatibility_network":
		return "compat-network-" + _role
	if _scenario == "compatibility_hot_seat":
		return "compat-hot-seat"
	if _scenario == "commanded_squadron":
		return "commanded-" + _role
	if _scenario == "commanded_decline":
		return "decline-" + _role
	if _scenario == "commanded_activation_gate":
		return "activation-gate-" + _role
	if _scenario == "commanded_activation_reject":
		return "activation-reject-" + _role
	if _scenario == "ship_end_activation":
		return "end-activation-" + _role
	return "fresh-" + _role + "-" + str(_mapping)

func _parse_args(values: PackedStringArray) -> Dictionary:
	var result := {}
	for value: String in values:
		var parts := value.trim_prefix("--").split("=", false, 1)
		if parts.size() == 2:
			result[parts[0]] = parts[1]
	return result
