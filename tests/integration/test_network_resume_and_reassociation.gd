## MATCH-003 integration seam coverage for explicit fresh resume.
extends GutTest

var _previous_game_state: GameState = null
var _previous_game_active: bool = false
var _previous_active_player: int = 0
var _previous_play_mode: PlayMode.Mode

const SHIP_KEY_CR90: String = "cr90_corvette_a"
const SHIP_KEY_NEBULON: String = "nebulon_b_escort_frigate"

func _state() -> GameState:
	var state := GameState.new()
	state.initialize()
	state.install_match_player_control_binding(MatchPlayerControlBinding.create_two_human())
	return state

func _meta() -> SaveGameMetadata:
	var meta := SaveGameMetadata.new()
	meta.scenario_id = "learning_scenario"
	meta.game_mode = SaveGameMetadata.MODE_NETWORK
	meta.next_command_sequence = 0
	return meta


func _ready_two_endpoint_lobby() -> LobbyState:
	var lobby := LobbyState.new()
	lobby.add_player(1, "Host", 0)
	lobby.add_player(42, "Client", 1)
	lobby.set_player_ready(1, true)
	lobby.set_player_ready(42, true)
	return lobby


func _make_ship(key: String, owner: int) -> ShipInstance:
	var template: ShipData = AssetLoader.load_ship_data(key)
	assert_not_null(template, "Resume fixture requires ship data for %s" % key)
	return ShipInstance.create_from_data(key, template, 2, owner)


func _assign_hidden_dials(ship: ShipInstance, command: int) -> void:
	var commands: Array[int] = []
	for _index: int in range(ship.command_dial_stack.get_dials_needed()):
		commands.append(command)
	assert_true(ship.command_dial_stack.assign_dials(commands, 1))


## Builds the exact canonical point reached after Player 0 completes the
## first Ship Phase activation.  EndActivationCommand persists Player 1 as
## the owner of the next WAIT_FOR_SHIP_SELECT decision.
func _completed_ship_activation_state() -> GameState:
	var state := _state()
	state.current_round = 1
	state.current_phase = Constants.GamePhase.SHIP
	state.initiative_player = 0
	var cr90: ShipInstance = _make_ship(SHIP_KEY_CR90, 0)
	var nebulon: ShipInstance = _make_ship(SHIP_KEY_NEBULON, 0)
	var imperial_ship: ShipInstance = _make_ship(SHIP_KEY_CR90, 1)
	state.player_states[0].ships.append_array([cr90, nebulon])
	state.player_states[1].ships.append(imperial_ship)
	_assign_hidden_dials(cr90, Constants.CommandType.NAVIGATE)
	_assign_hidden_dials(nebulon, Constants.CommandType.REPAIR)
	_assign_hidden_dials(imperial_ship, Constants.CommandType.SQUADRON)

	var activate := ActivateShipCommand.new(0, {"ship_index": 0})
	activate.sequence = 1
	assert_eq(activate.validate(state), "")
	var activation: Dictionary = activate.execute(state)
	var activation_id: String = str(activation.get("ship_activation_identity", ""))
	assert_false(activation_id.is_empty())
	assert_true(cr90.consume_unreached_squadron_command_opportunity(
			activation_id, true))
	assert_true(cr90.open_maneuver_opportunity(activation_id))
	assert_true(cr90.consume_open_maneuver_opportunity(activation_id))
	var finish := EndActivationCommand.new(0, {
		"ship_index": 0,
		"ship_activation_identity": activation_id,
	})
	assert_eq(finish.validate(state), "")
	finish.execute(state)
	assert_true(cr90.activated_this_round)
	assert_eq(state.interaction_flow.controller_player, 1)
	return state


func _assert_fresh_resume_preserves_next_actor(assignment: Dictionary) -> void:
	NetworkManager.peers[42] = {"authenticated": true, "player_index": 1}
	var saved_state: GameState = _completed_ship_activation_state()
	var restored: GameState = GameState.deserialize(saved_state.serialize())
	assert_not_null(restored,
			"The completed Ship Phase state must deserialize before resume")
	assert_eq(restored.interaction_flow.controller_player, 1,
			"The saved interaction flow must name Player 1 as next actor")
	assert_true(NetworkManager.begin_fresh_session_resume(restored, _meta()))
	assert_true(NetworkManager.submit_fresh_resume_assignment(assignment))

	assert_true(GameManager.start_new_game_from_state(restored, "network_resume"))
	assert_eq(GameManager.active_player, 1,
			"Fresh resume must restore the saved Player 1 decision owner")
	var rebel_reveal := RevealDialCommand.new(0, {
		"ship_index": 1,
		"action": "reveal",
	})
	var saved_log_level: GameLogger.Level = GameLogger.min_level
	GameLogger.min_level = GameLogger.Level.ERROR
	assert_true(CommandProcessor.submit(rebel_reveal).is_empty(),
			"Player 0 commands must be rejected until canonical play returns")
	GameLogger.min_level = saved_log_level
	assert_eq(restored.get_ship(0, 1).command_dial_stack.get_hidden_count(),
			restored.get_ship(0, 1).command_dial_stack.command_value,
			"Rejected Player 0 reveal must not mutate the saved gameplay state")
	var imperial_reveal := RevealDialCommand.new(1, {
		"ship_index": 0,
		"action": "reveal",
	})
	assert_false(CommandProcessor.submit(imperial_reveal).is_empty(),
			"The canonical Player 1 owner must remain the only legal next actor")

func before_each() -> void:
	_previous_game_state = GameManager.current_game_state
	_previous_game_active = GameManager.is_game_active
	_previous_active_player = GameManager.active_player
	_previous_play_mode = PlayMode.current_mode
	PlayMode.set_mode(PlayMode.Mode.NETWORK)
	NetworkManager._peer = null
	NetworkManager._last_heartbeat.clear()
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager.connection_state = NetworkManager.ConnectionState.LOBBY
	NetworkManager.peers.clear()
	NetworkManager._resume_attempt = {}
	NetworkManager._host_match_principal_id = ""
	NetworkManager._local_player_index = -1
	NetworkManager._pending_game_config = {}
	NetworkManager._client_staged_resume = {}
	NetworkManager._post_publication_fresh_attempt_id = ""
	NetworkManager._principal_command_admission_enabled = true
	LobbyManager.current_lobby = null

func after_each() -> void:
	NetworkManager.peers.clear()
	NetworkManager._last_heartbeat.clear()
	NetworkManager._resume_attempt = {}
	NetworkManager._host_match_principal_id = ""
	NetworkManager._local_player_index = -1
	NetworkManager._pending_game_config = {}
	NetworkManager._client_staged_resume = {}
	NetworkManager._post_publication_fresh_attempt_id = ""
	NetworkManager._principal_command_admission_enabled = true
	NetworkManager.connection_state = NetworkManager.ConnectionState.DISCONNECTED
	NetworkManager.role = NetworkManager.Role.NONE
	LobbyManager.current_lobby = null
	GameManager.is_game_active = _previous_game_active
	GameManager.active_player = _previous_active_player
	GameManager.current_game_state = _previous_game_state
	PlayMode.set_mode(_previous_play_mode)

func test_swapped_explicit_assignment_is_staged_non_live() -> void:
	NetworkManager.peers[42] = {"authenticated": true, "player_index": 1}
	var state := _state()
	assert_true(NetworkManager.begin_fresh_session_resume(state, _meta()))
	assert_true(NetworkManager.submit_fresh_resume_assignment({1: 1, 42: 0}))
	assert_eq(NetworkManager._local_player_index, 1)
	assert_eq(NetworkManager.peers[42].player_index, 0)
	assert_false(NetworkManager.is_player_command_admission_enabled())


func test_normal_fresh_resume_preserves_saved_ship_phase_actor() -> void:
	_assert_fresh_resume_preserves_next_actor({1: 0, 42: 1})


func test_swapped_fresh_resume_preserves_saved_ship_phase_actor() -> void:
	_assert_fresh_resume_preserves_next_actor({1: 1, 42: 0})


func test_same_live_network_load_preserves_saved_ship_phase_actor() -> void:
	var saved_state: GameState = _completed_ship_activation_state()
	var restored: GameState = GameState.deserialize(saved_state.serialize())
	assert_not_null(restored)
	assert_true(GameManager.start_new_game_from_state(restored, "same_live_network"))
	assert_eq(GameManager.active_player, 1,
			"Same-live Network load must preserve the saved Player 1 decision owner")


func test_filtered_remote_reveal_hydrates_public_dial_before_spend() -> void:
	var authoritative: GameState = _completed_ship_activation_state()
	var filtered_data: Dictionary = StateFilter.filter_for_player(
		authoritative.serialize(), 0)
	var mirrored: GameState = GameState.deserialize(filtered_data)
	assert_not_null(mirrored)
	var remote_ship: ShipInstance = mirrored.get_ship(1, 0)
	assert_false(remote_ship.command_dial_stack.peek_top().has("command"),
			"The opponent's still-hidden dial must remain redacted in the mirror")
	GameManager.current_game_state = mirrored
	var reveal := RevealDialCommand.new(1, {
		"ship_index": 0,
		"action": "reveal",
	})
	var mirrored_result: Dictionary = reveal.execute(mirrored)
	assert_eq(int(mirrored_result.get("command", -1)), -1,
			"The filtered mirror cannot infer a hidden opponent command")
	GameManager._handle_remote_dial_change(reveal, {
		"command": int(Constants.CommandType.SQUADRON),
	})
	assert_eq(int(remote_ship.command_dial_stack.get_revealed_dial().get(
			"command", -1)), int(Constants.CommandType.SQUADRON),
			"The authoritative reveal result must hydrate the now-public face")
	var spent: Dictionary = remote_ship.command_dial_stack.spend_revealed()
	assert_eq(int(spent.get("command", -1)), int(Constants.CommandType.SQUADRON),
			"The mirrored spend must retain the public command without an error")

func test_incomplete_or_duplicate_assignment_fails_before_distribution() -> void:
	NetworkManager.peers[42] = {"authenticated": true, "player_index": 1}
	assert_true(NetworkManager.begin_fresh_session_resume(_state(), _meta()))
	assert_false(NetworkManager.submit_fresh_resume_assignment({1: 0}))
	assert_false(NetworkManager.submit_fresh_resume_assignment({1: 0, 42: 0}))
	assert_eq(NetworkManager._resume_attempt.get("phase", ""), "CANDIDATE_STAGED")


func test_commit_revalidates_complete_staged_metadata_and_current_lobby() -> void:
	NetworkManager.peers[42] = {"authenticated": true, "player_index": 1}
	LobbyManager.current_lobby = _ready_two_endpoint_lobby()
	var state := _state()
	var meta := _meta()
	assert_true(NetworkManager.begin_fresh_session_resume(state, meta))
	assert_true(NetworkManager.submit_fresh_resume_assignment({1: 1, 42: 0}))
	assert_true(NetworkManager._resume_candidate_matches(
			state, meta, NetworkManager._binding_for_state(state)))
	NetworkManager._resume_attempt["phase"] = "READY_TO_COMMIT"
	meta.display_name = "changed-after-client-staging"
	assert_false(NetworkManager.commit_fresh_resume_associations(state, meta))
	assert_true(NetworkManager._resume_attempt.is_empty())
	assert_eq(NetworkManager._host_match_principal_id, "")
	assert_eq(NetworkManager._local_player_index, -1)
	assert_true(NetworkManager.is_player_command_admission_enabled())


func test_post_publication_timeout_preserves_host_admission_and_reoffers_peer() -> void:
	NetworkManager.connection_state = NetworkManager.ConnectionState.IN_GAME
	NetworkManager.peers[42] = {"authenticated": true, "player_index": 1,
		"match_principal_id": "player-1", "command_admission_enabled": false}
	NetworkManager._resume_attempt = {"operation": "fresh_session_resume",
		"phase": "AWAITING_INSTALL_ACKS", "expected_endpoints": [1, 42]}
	NetworkManager._principal_command_admission_enabled = false
	NetworkManager._timeout_resume_attempt("AWAITING_INSTALL_ACKS")
	assert_true(NetworkManager._resume_attempt.is_empty())
	assert_true(NetworkManager.is_player_command_admission_enabled())
	assert_eq(str(NetworkManager.peers[42].get("match_principal_id", "")), "")
	assert_false(bool(NetworkManager.peers[42].get("command_admission_enabled", true)))


func _prepare_reconnect_staging_attempt() -> void:
	NetworkManager.connection_state = NetworkManager.ConnectionState.IN_GAME
	GameManager.current_game_state = _state()
	var binding := NetworkManager._binding_for_state(GameManager.current_game_state)
	var host_principal: String = binding.principal_id_for_player(0)
	var reconnect_principal: String = binding.principal_id_for_player(1)
	NetworkManager._host_match_principal_id = host_principal
	NetworkManager._local_player_index = 0
	NetworkManager.peers[42] = {"authenticated": true, "player_index": 1,
		"match_principal_id": reconnect_principal, "command_admission_enabled": false}
	NetworkManager._resume_attempt = {"attempt_id": "a".repeat(64),
		"operation": "reconnect", "phase": "STAGING_SNAPSHOT",
		"expected_endpoints": [42], "associations": {42: reconnect_principal}}


func test_reconnect_staging_rejection_clears_association_and_reoffers_endpoint() -> void:
	_prepare_reconnect_staging_attempt()
	watch_signals(NetworkManager)
	NetworkManager._abort_resume("Client rejected staged reconnect snapshot.")
	assert_true(NetworkManager._resume_attempt.is_empty())
	assert_eq(str(NetworkManager.peers[42].get("match_principal_id", "")), "")
	assert_false(bool(NetworkManager.peers[42].get("command_admission_enabled", true)))
	assert_eq(NetworkManager._host_match_principal_id,
			NetworkManager._binding_for_state(GameManager.current_game_state).principal_id_for_player(0))
	assert_signal_emitted_with_parameters(NetworkManager,
		"reconnect_assignment_ready", [42, [1]])


func test_reconnect_staging_ack_timeout_clears_association_and_reoffers_endpoint() -> void:
	_prepare_reconnect_staging_attempt()
	watch_signals(NetworkManager)
	NetworkManager._timeout_resume_attempt("STAGING_SNAPSHOT")
	assert_true(NetworkManager._resume_attempt.is_empty())
	assert_eq(str(NetworkManager.peers[42].get("match_principal_id", "")), "")
	assert_false(bool(NetworkManager.peers[42].get("command_admission_enabled", true)))
	assert_eq(NetworkManager._host_match_principal_id,
			NetworkManager._binding_for_state(GameManager.current_game_state).principal_id_for_player(0))
	assert_signal_emitted_with_parameters(NetworkManager,
		"reconnect_assignment_ready", [42, [1]])
