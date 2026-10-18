extends Node

## Real ENet valid receiver control, then one-field malformed rejection.

const ATTACK_FIXTURE: GDScript = preload(
		"res://tests/fixtures/current_attack_state_fixture.gd")
const CONTROL_ID: String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const REJECT_ID: String = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
const CURSOR: int = 1


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3 or args[0] not in ["host", "client"] \
			or args[2] not in ["0", "1"]:
		_fail("expected host/client, port, and player mapping")
		return
	var viewer: int = int(args[2])
	var peer := ENetMultiplayerPeer.new()
	var port: int = int(args[1])
	var err: Error = peer.create_server(port, 1) if args[0] == "host" \
			else peer.create_client("127.0.0.1", port)
	if err != OK:
		_fail("peer setup: %s" % err)
		return
	get_tree().root.multiplayer.multiplayer_peer = peer
	NetworkManager._peer = peer
	NetworkManager.role = NetworkManager.Role.SERVER if args[0] == "host" \
			else NetworkManager.Role.CLIENT
	if args[0] == "host":
		await _host(viewer)
	else:
		await _client(viewer)


func _host(viewer: int) -> void:
	var deadline: int = Time.get_ticks_msec() + 10000
	while get_tree().root.multiplayer.get_peers().is_empty() \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if get_tree().root.multiplayer.get_peers().is_empty():
		_fail("host did not receive client")
		return
	var endpoint: int = get_tree().root.multiplayer.get_peers()[0]
	var state := GameState.new()
	state.initialize()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.damage_deck = DamageDeck.new()
	state.damage_deck.set_rng(state.rng)
	state.damage_deck.initialize()
	if not state.install_match_player_control_binding(
			MatchPlayerControlBinding.create_two_human()):
		_fail("network principal binding")
		return
	var attack: CurrentAttackState = ATTACK_FIXTURE.install(state, {
		"stage": CurrentAttackState.STAGE_RESOLVED,
		"defender_kind": CurrentAttackState.KIND_SQUADRON,
	})
	if attack == null or attack.attack_id != "attack:0":
		_fail("host attack fixture or sequence")
		return
	var principal: String = state.principal_id_for_player(viewer)
	if principal.is_empty() or not state.principal_controls_player(
			principal, viewer):
		_fail("principal does not control player")
		return
	var meta := SaveGameMetadata.new()
	meta.scenario_id = "boundary_c"
	meta.scenario_name = "Boundary C"
	meta.game_mode = SaveGameMetadata.MODE_NETWORK
	meta.current_round = state.current_round
	meta.phase = SaveGameMetadata.phase_label(state.current_phase)
	meta.display_name = "Boundary C control"
	if not meta.set_next_command_sequence(CURSOR) \
			or not meta.validate().get("ok", false) \
			or not SaveGameManager.reconstruction_cursor_for(
					meta, state).get("ok", false):
		_fail("invalid metadata or command cursor")
		return
	var filtered: Dictionary = StateFilter.filter_for_player_checked(
			state.serialize(), viewer)
	if not filtered.get(StateFilter.KEY_OK, false):
		_fail("host filter")
		return
	var control: Dictionary = filtered[StateFilter.KEY_STATE]
	if GameState.deserialize_passive_network(control) == null:
		_fail("control passive reconstruction")
		return
	GameManager.current_game_state = state
	var authority_hash: String = CanonicalJson.hash(state.serialize())
	NetworkManager._resume_attempt = _attempt(
			"fresh_session_resume", CONTROL_ID, endpoint)
	NetworkManager._principal_command_admission_enabled = false
	NetworkManager._receive_resume_snapshot.rpc_id(endpoint,
			"fresh_session_resume", CONTROL_ID, control, meta.to_dict(),
			principal, viewer, CURSOR)
	deadline = Time.get_ticks_msec() + 10000
	while NetworkManager._resume_attempt.get("phase", "") \
			!= "READY_TO_COMMIT" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if NetworkManager._resume_attempt.get("phase", "") \
			!= "READY_TO_COMMIT" or not NetworkManager._resume_attempt.get(
			"ready", {}).get(endpoint, false):
		_fail("valid control was not acknowledged as staged")
		return
	print("BOUNDARY_C_PASS control_staged viewer=", viewer)
	var malformed: Dictionary = control.duplicate(true)
	var original_value: Variant = control["current_attack_state"][
			"resolved_outcome"]["requested_hull_damage"]
	malformed["current_attack_state"]["resolved_outcome"][
			"requested_hull_damage"] = 1e20
	var unchanged_copy: Dictionary = malformed.duplicate(true)
	unchanged_copy["current_attack_state"]["resolved_outcome"][
			"requested_hull_damage"] = original_value
	if unchanged_copy != control:
		_fail("rejection changed more than one field")
		return
	NetworkManager._resume_attempt = _attempt("reconnect", REJECT_ID, endpoint)
	NetworkManager._receive_resume_snapshot.rpc_id(endpoint, "reconnect",
			REJECT_ID, malformed, meta.to_dict(), principal, viewer, CURSOR)
	deadline = Time.get_ticks_msec() + 10000
	while not NetworkManager._resume_attempt.is_empty() \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not NetworkManager._resume_attempt.is_empty() \
			or not NetworkManager._principal_command_admission_enabled \
			or GameManager.current_game_state != state \
			or CanonicalJson.hash(state.serialize()) != authority_hash:
		_fail("negative acknowledgement did not abort unchanged authority")
		return
	print("BOUNDARY_C_PASS negative_ack_authority_unchanged viewer=", viewer)
	get_tree().quit()


func _client(viewer: int) -> void:
	var previous := GameState.new()
	previous.initialize()
	GameManager.current_game_state = previous
	var before: String = CanonicalJson.hash(previous.serialize())
	var deadline: int = Time.get_ticks_msec() + 10000
	while NetworkManager._client_staged_resume.get("attempt_id", "") \
			!= CONTROL_ID and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var staged: Dictionary = NetworkManager._client_staged_resume
	var reconstructed: GameState = staged.get("state") as GameState
	var meta: SaveGameMetadata = staged.get("meta") as SaveGameMetadata
	if staged.get("attempt_id", "") != CONTROL_ID \
			or staged.get("player_index", -1) != viewer \
			or staged.get("cursor", -1) != CURSOR \
			or reconstructed == null or meta == null \
			or meta.next_command_sequence != CURSOR \
			or not reconstructed.principal_controls_player(
					str(staged.get("principal_id", "")), viewer) \
			or typeof(reconstructed.current_attack_state.resolved_outcome.get(
					"requested_hull_damage")) != TYPE_INT \
			or GameManager.current_game_state != previous \
			or CanonicalJson.hash(previous.serialize()) != before:
		_fail("valid receiver control did not stage correctly")
		return
	print("BOUNDARY_C_PASS receiver_control viewer=", viewer)
	deadline = Time.get_ticks_msec() + 10000
	while not NetworkManager._client_staged_resume.is_empty() \
			and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not NetworkManager._client_staged_resume.is_empty() \
			or GameManager.current_game_state != previous \
			or CanonicalJson.hash(previous.serialize()) != before:
		_fail("malformed receiver snapshot staged or installed")
		return
	print("BOUNDARY_C_PASS rejection_no_stage_no_commit viewer=", viewer)
	get_tree().quit()


func _attempt(operation: String, attempt_id: String,
		endpoint: int) -> Dictionary:
	return {
		"operation": operation, "phase": "STAGING_SNAPSHOT",
		"attempt_id": attempt_id, "expected_endpoints": [endpoint],
		"cursor": CURSOR, "ready": {},
	}


func _fail(reason: String) -> void:
	push_error("BOUNDARY_C_FAIL %s" % reason)
	get_tree().quit(1)
