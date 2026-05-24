## Integration tests for NetworkManager — state transitions, guards, and signals.
## Tests the public API surface and state machine without creating real ENet peers.
## Real network integration requires manual testing (two processes).
##
## G4 Network Plan: §3 — G4.1 integration tests
extends GutTest


const NetworkHarnessScript: GDScript = preload(
		"res://tests/fixtures/network_harness.gd")


## Port used for integration tests (different from default to avoid conflicts).
const TEST_PORT: int = 17350


# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------

func after_each() -> void:
	# Reset NetworkManager state between tests without ENet cleanup.
	NetworkManager.peers.clear()
	NetworkManager._last_heartbeat.clear()
	if NetworkManager._heartbeat_timer:
		NetworkManager._heartbeat_timer.stop()
		NetworkManager._heartbeat_timer.queue_free()
		NetworkManager._heartbeat_timer = null
	if NetworkManager._peer:
		NetworkManager._peer.close()
		NetworkManager._peer = null
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	NetworkManager.role = NetworkManager.Role.NONE
	NetworkManager.connection_state = NetworkManager.ConnectionState.DISCONNECTED
	await get_tree().process_frame


# ---------------------------------------------------------------------------
# Host lifecycle
# ---------------------------------------------------------------------------

func test_host_creates_server_and_transitions_to_lobby() -> void:
	var result: bool = NetworkManager.host(TEST_PORT)
	assert_true(result, "host() should return true on success.")
	assert_eq(NetworkManager.role, NetworkManager.Role.SERVER,
			"Role should be SERVER after hosting.")
	assert_eq(NetworkManager.connection_state,
			NetworkManager.ConnectionState.LOBBY,
			"State should be LOBBY after hosting.")
	assert_true(NetworkManager.is_server(),
			"is_server() should be true after hosting.")
	assert_true(NetworkManager.is_connected_to_network(),
			"is_connected_to_network() should be true after hosting.")


func test_host_twice_returns_false() -> void:
	NetworkManager.host(TEST_PORT)
	var result: bool = NetworkManager.host(TEST_PORT + 1)
	assert_false(result,
			"Second host() should return false while already hosting.")
	# _log.warn triggers push_warning — mark handled.
	assert_engine_error(1,
			"Should warn about host() while already hosting.")


func test_disconnect_after_host_resets_state() -> void:
	NetworkManager.host(TEST_PORT)
	NetworkManager.disconnect_from_server()
	assert_eq(NetworkManager.connection_state,
			NetworkManager.ConnectionState.DISCONNECTED,
			"State should be DISCONNECTED after disconnect.")
	assert_eq(NetworkManager.role, NetworkManager.Role.NONE,
			"Role should be NONE after disconnect.")
	assert_false(NetworkManager.is_server(),
			"is_server() should be false after disconnect.")


# ---------------------------------------------------------------------------
# Client connection attempt
# ---------------------------------------------------------------------------

func test_connect_to_server_starts_connecting() -> void:
	var result: bool = NetworkManager.connect_to_server("127.0.0.1", TEST_PORT)
	assert_true(result, "connect_to_server() should return true.")
	assert_eq(NetworkManager.role, NetworkManager.Role.CLIENT,
			"Role should be CLIENT after connect_to_server().")
	assert_eq(NetworkManager.connection_state,
			NetworkManager.ConnectionState.CONNECTING,
			"State should be CONNECTING after connect_to_server().")


func test_connect_twice_returns_false() -> void:
	NetworkManager.connect_to_server("127.0.0.1", TEST_PORT)
	var result: bool = NetworkManager.connect_to_server("127.0.0.1", TEST_PORT + 1)
	assert_false(result,
			"Second connect_to_server() should return false while connecting.")
	# _log.warn triggers push_warning — mark handled.
	assert_engine_error(1,
			"Should warn about connect_to_server() while connecting.")


# ---------------------------------------------------------------------------
# Start game transition
# ---------------------------------------------------------------------------

func test_start_game_from_lobby_transitions_to_in_game() -> void:
	NetworkManager.host(TEST_PORT)
	assert_eq(NetworkManager.connection_state,
			NetworkManager.ConnectionState.LOBBY,
			"Should be in LOBBY state after host.")
	NetworkManager.start_game()
	assert_eq(NetworkManager.connection_state,
			NetworkManager.ConnectionState.IN_GAME,
			"start_game() should transition to IN_GAME from LOBBY.")


# ---------------------------------------------------------------------------
# State change signal
# ---------------------------------------------------------------------------

func test_host_emits_state_changed_signal() -> void:
	var transitions: Array = []
	NetworkManager.state_changed.connect(
			func(old: NetworkManager.ConnectionState,
					new: NetworkManager.ConnectionState) -> void:
				transitions.append({"old": old, "new": new}))
	NetworkManager.host(TEST_PORT)
	assert_eq(transitions.size(), 1,
			"host() should emit state_changed once.")
	assert_eq(transitions[0]["old"],
			NetworkManager.ConnectionState.DISCONNECTED,
			"Old state should be DISCONNECTED.")
	assert_eq(transitions[0]["new"],
			NetworkManager.ConnectionState.LOBBY,
			"New state should be LOBBY.")
	# Disconnect the lambda to prevent it from firing during cleanup.
	for conn: Dictionary in NetworkManager.state_changed.get_connections():
		NetworkManager.state_changed.disconnect(conn["callable"])


# ---------------------------------------------------------------------------
# Peer management
# ---------------------------------------------------------------------------

func test_peer_connected_signal_emitted_on_new_peer() -> void:
	var received_ids: Array = []
	NetworkManager.peer_connected.connect(
			func(peer_id: int) -> void: received_ids.append(peer_id))
	# Simulate a peer connection callback.
	NetworkManager._on_peer_connected(42)
	assert_eq(received_ids.size(), 1,
			"peer_connected should emit once.")
	assert_eq(received_ids[0], 42,
			"Peer ID should be 42.")
	# Cleanup heartbeat entry.
	NetworkManager._last_heartbeat.clear()


func test_peer_disconnected_cleans_up_state() -> void:
	NetworkManager.peers[42] = {"player_index": 0}
	NetworkManager._last_heartbeat[42] = 100.0
	NetworkManager._on_peer_disconnected(42)
	assert_false(NetworkManager.peers.has(42),
			"Peer 42 should be removed from peers.")
	assert_false(NetworkManager._last_heartbeat.has(42),
			"Peer 42 heartbeat should be removed.")


# ---------------------------------------------------------------------------
# TestNetworkHarness basic validation
# ---------------------------------------------------------------------------

func test_harness_setup_creates_peers() -> void:
	var harness: Variant = NetworkHarnessScript.new()
	harness.setup()
	assert_not_null(harness.server_peer,
			"Server peer should be created.")
	assert_not_null(harness.client_peer,
			"Client peer should be created.")
	assert_true(harness.is_active,
			"Harness should be active after setup.")
	harness.teardown()


func test_harness_teardown_clears_peers() -> void:
	var harness: Variant = NetworkHarnessScript.new()
	harness.setup()
	harness.teardown()
	assert_null(harness.server_peer,
			"Server peer should be null after teardown.")
	assert_null(harness.client_peer,
			"Client peer should be null after teardown.")
	assert_false(harness.is_active,
			"Harness should be inactive after teardown.")


func test_harness_make_handshake_uses_defaults() -> void:
	var harness: Variant = NetworkHarnessScript.new()
	var hs: Dictionary = harness.make_handshake()
	assert_eq(hs["protocol_version"], NetworkManager.PROTOCOL_VERSION,
			"Default protocol version should match NetworkManager.")
	assert_eq(hs["client_id"], "test-uuid",
			"Default client_id should be 'test-uuid'.")
	assert_eq(hs["display_name"], "TestPlayer",
			"Default display name should be 'TestPlayer'.")


func test_harness_make_handshake_custom_values() -> void:
	var harness: Variant = NetworkHarnessScript.new()
	var hs: Dictionary = harness.make_handshake(99, "custom-id", "CustomName")
	assert_eq(hs["protocol_version"], 99,
			"Custom protocol version should be 99.")
	assert_eq(hs["client_id"], "custom-id",
			"Custom client_id should be 'custom-id'.")
	assert_eq(hs["display_name"], "CustomName",
			"Custom display name should be 'CustomName'.")
