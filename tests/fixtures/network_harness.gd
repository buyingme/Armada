## TestNetworkHarness
##
## Reusable test fixture that provides in-memory server/client message
## passing for network integration tests.  Uses Godot's
## [code]OfflineMultiplayerPeer[/code] for zero-socket testing.
##
## Usage in a GUT test:
## [codeblock]
## var harness: TestNetworkHarness = TestNetworkHarness.new()
##
## func before_each() -> void:
##     harness.setup()
##
## func after_each() -> void:
##     harness.teardown()
## [/codeblock]
##
## G4 Network Plan: §3 — G4.1.8
extends RefCounted


## The "server" multiplayer API instance.
var server_api: SceneMultiplayer = null

## The "client" multiplayer API instance.
var client_api: SceneMultiplayer = null

## Simulated server peer.
var server_peer: OfflineMultiplayerPeer = null

## Simulated client peer.
var client_peer: OfflineMultiplayerPeer = null

## Whether the harness is currently active.
var is_active: bool = false


## Sets up the in-memory server and client peers.
## Call this in [code]before_each()[/code].
func setup() -> void:
	server_peer = OfflineMultiplayerPeer.new()
	client_peer = OfflineMultiplayerPeer.new()
	server_api = SceneMultiplayer.new()
	client_api = SceneMultiplayer.new()
	is_active = true


## Tears down all peers and multiplayer APIs.
## Call this in [code]after_each()[/code].
func teardown() -> void:
	server_peer = null
	client_peer = null
	server_api = null
	client_api = null
	is_active = false


## Creates a handshake payload dictionary matching the NetworkManager
## protocol format.
## [param protocol_version] — protocol version to include.
## [param client_id] — the client's UUID.
## [param display_name] — the client's display name.
func make_handshake(protocol_version: int = NetworkManager.PROTOCOL_VERSION,
		client_id: String = "test-uuid",
		display_name: String = "TestPlayer") -> Dictionary:
	return {
		"protocol_version": protocol_version,
		"client_id": client_id,
		"display_name": display_name,
	}


## Creates a minimal state snapshot dictionary for testing reconnection
## scenarios.
func make_state_snapshot() -> Dictionary:
	return {
		"round": 1,
		"phase": "COMMAND",
		"players": [],
	}
