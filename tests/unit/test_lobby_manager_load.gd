## Test: LobbyManager — host-driven load (Phase J7)
##
## Unit tests for the host_load_save guard rails and the
## _receive_loaded_state RPC handler.  The full host→client
## broadcast round-trip is covered by MT-J.7.
extends GutTest


var _prev_role: int = NetworkManager.Role.NONE
var _prev_log_level: int = GameLogger.Level.DEBUG


func before_each() -> void:
	_prev_role = NetworkManager.role
	_prev_log_level = GameLogger.min_level
	# Suppress warn-level logs (host_load_save warns when guards trip).
	GameLogger.min_level = GameLogger.Level.ERROR + 1


func after_each() -> void:
	NetworkManager.role = _prev_role
	GameLogger.min_level = _prev_log_level
	LobbyManager.current_lobby = null


func test_host_load_save_refused_when_not_server() -> void:
	NetworkManager.role = NetworkManager.Role.CLIENT
	var state: GameState = GameState.new()
	state.initialize()
	var meta: SaveGameMetadata = SaveGameMetadata.new()
	meta.scenario_id = "learning_scenario"
	meta.display_name = "test"
	# Should be a no-op — no game_starting emit.
	watch_signals(LobbyManager)
	LobbyManager.host_load_save(state, meta)
	assert_signal_not_emitted(LobbyManager, "game_starting",
			"Client must not be able to drive a load.")


func test_host_load_save_refused_with_null_args() -> void:
	NetworkManager.role = NetworkManager.Role.SERVER
	watch_signals(LobbyManager)
	LobbyManager.host_load_save(null, null)
	assert_signal_not_emitted(LobbyManager, "game_starting",
			"Null state/meta must not start a game.")


func test_host_load_save_refused_when_lobby_not_startable() -> void:
	NetworkManager.role = NetworkManager.Role.SERVER
	# No current_lobby AND no peers connected → not allowed.
	# (In-session loads with peers connected ARE allowed; that path
	# is exercised by MT-J.7 since it requires a real ENet peer.)
	LobbyManager.current_lobby = null
	NetworkManager.peers.clear()
	var state: GameState = GameState.new()
	state.initialize()
	var meta: SaveGameMetadata = SaveGameMetadata.new()
	meta.scenario_id = "learning_scenario"
	meta.display_name = "test"
	watch_signals(LobbyManager)
	LobbyManager.host_load_save(state, meta)
	assert_signal_not_emitted(LobbyManager, "game_starting",
			"Load must be blocked when no lobby AND no peers.")


func test_load_state_received_signal_emittable() -> void:
	# The _receive_loaded_state RPC body emits load_state_received and
	# game_starting after a successful deserialise.  We exercise the
	# body directly; full RPC delivery is covered by MT-J.7.
	var src: GameState = GameState.new()
	src.initialize()
	src.current_round = 4
	var dict: Dictionary = src.serialize()
	watch_signals(LobbyManager)
	LobbyManager._receive_loaded_state(
			dict, "learning_scenario", {})
	assert_signal_emitted(LobbyManager, "load_state_received",
			"load_state_received should fire on RPC body.")
	assert_signal_emitted(LobbyManager, "game_starting",
			"game_starting should fire after install.")
	assert_eq(GameManager.current_game_state.current_round, 4,
			"Loaded state should be installed on the receiver.")
