## Unit tests for NetworkManager autoload.
## Tests connection state machine, protocol versioning, peer management,
## heartbeat configuration, and public query methods.
##
## G4 Network Plan: §3 — G4.1 tests
extends GutTest


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

func test_protocol_version_is_positive() -> void:
	assert_gt(NetworkManager.PROTOCOL_VERSION, 0,
			"Protocol version should be positive.")


func test_heartbeat_interval_is_positive() -> void:
	assert_gt(NetworkManager.HEARTBEAT_INTERVAL_SEC, 0.0,
			"Heartbeat interval should be positive.")


func test_heartbeat_timeout_greater_than_interval() -> void:
	assert_gt(NetworkManager.HEARTBEAT_TIMEOUT_SEC,
			NetworkManager.HEARTBEAT_INTERVAL_SEC,
			"Heartbeat timeout should exceed interval.")


func test_max_clients_at_least_two() -> void:
	assert_gte(NetworkManager.MAX_CLIENTS, 2,
			"Max clients should be at least 2 (two players).")


func test_enet_channels_positive() -> void:
	assert_gt(NetworkManager.ENET_CHANNELS, 0,
			"ENet channel count should be positive.")


# ---------------------------------------------------------------------------
# Initial state
# ---------------------------------------------------------------------------

func test_initial_connection_state_is_disconnected() -> void:
	assert_eq(NetworkManager.connection_state,
			NetworkManager.ConnectionState.DISCONNECTED,
			"Initial state should be DISCONNECTED.")


func test_initial_role_is_none() -> void:
	assert_eq(NetworkManager.role, NetworkManager.Role.NONE,
			"Initial role should be NONE.")


func test_initial_peers_empty() -> void:
	assert_eq(NetworkManager.peers.size(), 0,
			"Peers should be empty on init.")


func test_is_server_returns_false_by_default() -> void:
	assert_false(NetworkManager.is_server(),
			"is_server() should be false when role is NONE.")


func test_is_connected_returns_false_by_default() -> void:
	assert_false(NetworkManager.is_connected_to_network(),
			"is_connected_to_network() should be false when DISCONNECTED.")


func test_get_peer_count_returns_zero_by_default() -> void:
	assert_eq(NetworkManager.get_peer_count(), 0,
			"Peer count should be 0 when no peers are connected.")


# ---------------------------------------------------------------------------
# State machine — _state_name
# ---------------------------------------------------------------------------

func test_state_name_disconnected() -> void:
	assert_eq(NetworkManager._state_name(
			NetworkManager.ConnectionState.DISCONNECTED), "DISCONNECTED",
			"Should return 'DISCONNECTED'.")


func test_state_name_connecting() -> void:
	assert_eq(NetworkManager._state_name(
			NetworkManager.ConnectionState.CONNECTING), "CONNECTING",
			"Should return 'CONNECTING'.")


func test_state_name_authenticating() -> void:
	assert_eq(NetworkManager._state_name(
			NetworkManager.ConnectionState.AUTHENTICATING), "AUTHENTICATING",
			"Should return 'AUTHENTICATING'.")


func test_state_name_lobby() -> void:
	assert_eq(NetworkManager._state_name(
			NetworkManager.ConnectionState.LOBBY), "LOBBY",
			"Should return 'LOBBY'.")


func test_state_name_in_game() -> void:
	assert_eq(NetworkManager._state_name(
			NetworkManager.ConnectionState.IN_GAME), "IN_GAME",
			"Should return 'IN_GAME'.")


# ---------------------------------------------------------------------------
# State transitions
# ---------------------------------------------------------------------------

func test_set_state_emits_signal() -> void:
	var received: Array = []
	NetworkManager.state_changed.connect(
			func(old: NetworkManager.ConnectionState,
					new: NetworkManager.ConnectionState) -> void:
				received.append({"old": old, "new": new}))
	NetworkManager._set_state(NetworkManager.ConnectionState.CONNECTING)
	assert_eq(received.size(), 1, "state_changed should emit once.")
	assert_eq(received[0]["old"], NetworkManager.ConnectionState.DISCONNECTED,
			"Old state should be DISCONNECTED.")
	assert_eq(received[0]["new"], NetworkManager.ConnectionState.CONNECTING,
			"New state should be CONNECTING.")
	# Cleanup.
	NetworkManager._set_state(NetworkManager.ConnectionState.DISCONNECTED)


func test_start_game_transitions_from_lobby() -> void:
	NetworkManager.connection_state = NetworkManager.ConnectionState.LOBBY
	NetworkManager.start_game()
	assert_eq(NetworkManager.connection_state,
			NetworkManager.ConnectionState.IN_GAME,
			"start_game() should transition LOBBY → IN_GAME.")
	# Cleanup.
	NetworkManager.connection_state = NetworkManager.ConnectionState.DISCONNECTED


func test_start_game_does_nothing_if_not_lobby() -> void:
	NetworkManager.connection_state = NetworkManager.ConnectionState.DISCONNECTED
	NetworkManager.start_game()
	assert_eq(NetworkManager.connection_state,
			NetworkManager.ConnectionState.DISCONNECTED,
			"start_game() should not change state if not in LOBBY.")


# ---------------------------------------------------------------------------
# Player slot assignment
# ---------------------------------------------------------------------------

func test_assign_player_slot_first_peer_gets_zero() -> void:
	NetworkManager.peers.clear()
	LobbyManager.current_lobby = null
	var slot: int = NetworkManager._assign_player_slot(100)
	assert_eq(slot, 0, "First peer should get slot 0.")
	NetworkManager.peers.clear()


func test_assign_player_slot_second_peer_gets_one() -> void:
	NetworkManager.peers.clear()
	LobbyManager.current_lobby = null
	NetworkManager.peers[100] = {"player_index": 0}
	var slot: int = NetworkManager._assign_player_slot(200)
	assert_eq(slot, 1, "Second peer should get slot 1.")
	NetworkManager.peers.clear()


func test_assign_player_slot_full_returns_negative() -> void:
	NetworkManager.peers.clear()
	LobbyManager.current_lobby = null
	NetworkManager.peers[100] = {"player_index": 0}
	NetworkManager.peers[200] = {"player_index": 1}
	var slot: int = NetworkManager._assign_player_slot(300)
	assert_eq(slot, -1, "Third peer should get -1 (full).")
	NetworkManager.peers.clear()


func test_assign_player_slot_accounts_for_host_in_lobby() -> void:
	NetworkManager.peers.clear()
	var lobby: LobbyState = LobbyState.new()
	lobby.add_player(1, "Host", 0)
	LobbyManager.current_lobby = lobby
	var slot: int = NetworkManager._assign_player_slot(200)
	assert_eq(slot, 1,
			"Peer should get slot 1 when host occupies slot 0 in lobby.")
	NetworkManager.peers.clear()
	LobbyManager.current_lobby = null


# ---------------------------------------------------------------------------
# Host guards
# ---------------------------------------------------------------------------

func test_host_rejects_if_not_disconnected() -> void:
	NetworkManager.connection_state = NetworkManager.ConnectionState.LOBBY
	var result: bool = NetworkManager.host(7350)
	assert_false(result, "host() should return false if not DISCONNECTED.")
	# _log.warn triggers push_warning — mark handled.
	assert_engine_error(1, "Should warn about host() while not DISCONNECTED.")
	# Cleanup.
	NetworkManager.connection_state = NetworkManager.ConnectionState.DISCONNECTED


func test_connect_rejects_if_not_disconnected() -> void:
	NetworkManager.connection_state = NetworkManager.ConnectionState.LOBBY
	var result: bool = NetworkManager.connect_to_server("127.0.0.1", 7350)
	assert_false(result,
			"connect_to_server() should return false if not DISCONNECTED.")
	# _log.warn triggers push_warning — mark handled.
	assert_engine_error(1, "Should warn about connect_to_server() while not DISCONNECTED.")
	# Cleanup.
	NetworkManager.connection_state = NetworkManager.ConnectionState.DISCONNECTED


# ---------------------------------------------------------------------------
# Disconnect
# ---------------------------------------------------------------------------

func test_disconnect_from_server_when_already_disconnected() -> void:
	NetworkManager.connection_state = NetworkManager.ConnectionState.DISCONNECTED
	NetworkManager.disconnect_from_server()
	assert_eq(NetworkManager.connection_state,
			NetworkManager.ConnectionState.DISCONNECTED,
			"disconnect_from_server() should be no-op when already DISCONNECTED.")


# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

func test_cleanup_resets_all_state() -> void:
	# Setup some state.
	NetworkManager.peers[42] = {"player_index": 0}
	NetworkManager._last_heartbeat[42] = 100.0
	NetworkManager.role = NetworkManager.Role.SERVER
	NetworkManager.connection_state = NetworkManager.ConnectionState.IN_GAME
	# Cleanup.
	NetworkManager._cleanup()
	assert_eq(NetworkManager.peers.size(), 0, "Peers should be cleared.")
	assert_eq(NetworkManager._last_heartbeat.size(), 0,
			"Heartbeat map should be cleared.")
	assert_eq(NetworkManager.role, NetworkManager.Role.NONE,
			"Role should be NONE.")
	assert_eq(NetworkManager.connection_state,
			NetworkManager.ConnectionState.DISCONNECTED,
			"State should be DISCONNECTED.")


# ---------------------------------------------------------------------------
# Broadcast shutdown guard
# ---------------------------------------------------------------------------

func test_broadcast_shutdown_no_crash_when_not_server() -> void:
	NetworkManager.role = NetworkManager.Role.NONE
	# Should not crash — just silently return.
	NetworkManager.broadcast_shutdown()
	assert_eq(NetworkManager.role, NetworkManager.Role.NONE,
			"broadcast_shutdown() should be safe to call when not server.")


# ---------------------------------------------------------------------------
# ConnectionState enum completeness
# ---------------------------------------------------------------------------

func test_connection_state_enum_has_five_values() -> void:
	# DISCONNECTED=0, CONNECTING=1, AUTHENTICATING=2, LOBBY=3, IN_GAME=4
	assert_eq(NetworkManager.ConnectionState.IN_GAME, 4,
			"IN_GAME should be the fifth enum value (index 4).")


func test_role_enum_has_four_values() -> void:
	# NONE=0, SERVER=1, CLIENT=2, SPECTATOR=3
	assert_eq(NetworkManager.Role.SPECTATOR, 3,
			"SPECTATOR should be the fourth enum value (index 3).")


# ---------------------------------------------------------------------------
# Command RPC guards (G4.2)
# ---------------------------------------------------------------------------

func test_send_command_to_server_warns_if_not_client() -> void:
	NetworkManager.role = NetworkManager.Role.NONE
	NetworkManager.send_command_to_server({"type": "test"})
	# _log.warn triggers push_warning — mark handled.
	assert_engine_error(1,
			"Should warn about calling send_command_to_server when not CLIENT.")


func test_command_result_received_signal_exists() -> void:
	# Verify the signal exists by checking it can be connected.
	var received: Array = []
	NetworkManager.command_result_received.connect(
			func(cmd_data: Dictionary, result: Dictionary) -> void:
				received.append({"cmd": cmd_data, "result": result}))
	# Simulate server broadcasting a result.
	NetworkManager.command_result_received.emit(
			{"type": "test"}, {"status": "ok"})
	assert_eq(received.size(), 1,
			"command_result_received signal should be emittable.")
	assert_eq(received[0]["result"]["status"], "ok",
			"Result should propagate through signal.")
	# Disconnect lambda.
	for conn: Dictionary in NetworkManager.command_result_received.get_connections():
		NetworkManager.command_result_received.disconnect(conn["callable"])


func test_role_name_returns_valid_strings() -> void:
	assert_eq(NetworkManager._role_name(NetworkManager.Role.NONE), "NONE",
			"NONE role name should be 'NONE'.")
	assert_eq(NetworkManager._role_name(NetworkManager.Role.SERVER), "SERVER",
			"SERVER role name should be 'SERVER'.")
	assert_eq(NetworkManager._role_name(NetworkManager.Role.CLIENT), "CLIENT",
			"CLIENT role name should be 'CLIENT'.")
	assert_eq(NetworkManager._role_name(NetworkManager.Role.SPECTATOR), "SPECTATOR",
			"SPECTATOR role name should be 'SPECTATOR'.")


# ---------------------------------------------------------------------------
# Phase J6 — save notification broadcast
# ---------------------------------------------------------------------------

func test_save_notification_signal_emittable() -> void:
	var received: Array[String] = []
	var lam: Callable = func(name: String) -> void:
		received.append(name)
	NetworkManager.save_notification_received.connect(lam)
	NetworkManager._receive_save_notification("Mid-Game R3")
	assert_eq(received.size(), 1,
			"save_notification_received should be emittable.")
	assert_eq(received[0], "Mid-Game R3",
			"Display name should propagate through the signal.")
	NetworkManager.save_notification_received.disconnect(lam)


func test_broadcast_save_notification_warns_when_not_server() -> void:
	# Not server → no-op (and warn).  Ensures clients can never trigger
	# the broadcast even if they call the helper directly.
	var prev_role: int = NetworkManager.role
	var prev_log_level: int = GameLogger.min_level
	GameLogger.min_level = GameLogger.Level.ERROR + 1
	NetworkManager.role = NetworkManager.Role.CLIENT
	var received: Array[String] = []
	var lam: Callable = func(name: String) -> void:
		received.append(name)
	NetworkManager.save_notification_received.connect(lam)
	NetworkManager.broadcast_save_notification("Should-Not-Send")
	assert_eq(received.size(), 0,
			"Client must not trigger save_notification_received.")
	NetworkManager.save_notification_received.disconnect(lam)
	NetworkManager.role = prev_role
	GameLogger.min_level = prev_log_level
