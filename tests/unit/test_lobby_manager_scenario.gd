## Test: LobbyManager Scenario Selection
##
## Unit tests for mapping lobby scenario state into game-start configuration.
extends GutTest


var _previous_lobby: LobbyState = null
var _previous_role: int = NetworkManager.Role.NONE
var _previous_replay_enabled: bool = false
var _previous_replay_seed: int = 0
var _previous_replay_connect_target: String = ""


func before_each() -> void:
	_previous_lobby = LobbyManager.current_lobby
	_previous_role = NetworkManager.role
	_previous_replay_enabled = ReplayDriver.enabled
	_previous_replay_seed = ReplayDriver.pending_replay_seed
	_previous_replay_connect_target = ReplayDriver._connect_target


func after_each() -> void:
	LobbyManager.current_lobby = _previous_lobby
	NetworkManager.role = _previous_role
	ReplayDriver.enabled = _previous_replay_enabled
	ReplayDriver.pending_replay_seed = _previous_replay_seed
	ReplayDriver._connect_target = _previous_replay_connect_target


func test_selected_scenario_id_uses_debug_scenario_from_lobby() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.scenario = LobbyState.SCENARIO_DEBUG_ID
	LobbyManager.current_lobby = lobby

	assert_eq(LobbyManager._selected_scenario_id(),
			LobbyState.SCENARIO_DEBUG_ID,
			"Game start should use the debug scenario selected in the lobby.")


func test_selected_scenario_id_uses_setup_match_type_from_lobby() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.scenario = LobbyState.MATCH_CORE_SET_180_ID
	LobbyManager.current_lobby = lobby

	assert_eq(LobbyManager._selected_scenario_id(),
			LobbyState.MATCH_CORE_SET_180_ID,
			"Lobby selection should preserve setup match types for FB14B handoff.")


func test_selected_scenario_id_defaults_to_learning_without_lobby() -> void:
	LobbyManager.current_lobby = null

	assert_eq(LobbyManager._selected_scenario_id(),
			LobbyState.SCENARIO_LEARNING_ID,
			"Game start should default to the learning scenario without lobby state.")


func test_update_scenario_seeds_setup_draft_for_setup_match_type() -> void:
	var lobby: LobbyState = LobbyState.new()
	LobbyManager.current_lobby = lobby
	NetworkManager.role = NetworkManager.Role.SERVER

	LobbyManager.update_scenario(LobbyState.MATCH_INTERMEDIATE_300_ID)

	assert_eq(str(lobby.setup_draft.get("scenario_id", "")), "standard_3x6",
			"Setup-match lobby updates should seed a setup draft shell.")
	assert_eq(int((lobby.setup_draft.get("point_format", {}) as Dictionary).get("limit", 0)), 300,
			"Setup-match lobby updates should seed the selected point-format limit.")
	assert_eq(str((lobby.setup_draft.get("setup_state", {}) as Dictionary).get("match_type", "")),
			LobbyState.MATCH_INTERMEDIATE_300_ID,
			"Setup-match lobby updates should record the selected match type in setup state.")


func test_update_scenario_clears_setup_draft_for_fixed_scenario() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.setup_draft = {"phase": "objective_selection"}
	LobbyManager.current_lobby = lobby
	NetworkManager.role = NetworkManager.Role.SERVER

	LobbyManager.update_scenario(LobbyState.SCENARIO_DEBUG_ID)

	assert_true(lobby.setup_draft.is_empty(),
			"Fixed-scenario lobby updates should clear any pending setup draft.")


func test_network_replay_start_selects_exact_header_seed_without_consuming() -> void:
	ReplayDriver.enabled = true
	ReplayDriver._connect_target = "127.0.0.1:7350"
	ReplayDriver.pending_replay_seed = 30671017

	var selection: Dictionary = LobbyManager._select_start_rng_seed()

	assert_true(bool(selection.get("ok", false)),
			"Valid network replay seed selection should succeed.")
	assert_eq(int(selection.get("rng_seed", 0)), 30671017,
			"Lobby start should select the exact accepted replay seed.")
	assert_eq(ReplayDriver.pending_replay_seed, 30671017,
			"Lobby selection must not consume before GameState installation.")


func test_network_replay_start_fails_closed_without_header_seed() -> void:
	ReplayDriver.enabled = true
	ReplayDriver._connect_target = "127.0.0.1:7350"
	ReplayDriver.pending_replay_seed = 0

	var selection: Dictionary = LobbyManager._select_start_rng_seed()

	assert_false(bool(selection.get("ok", true)),
			"Missing network replay seed must stop lobby bootstrap.")
	assert_false(selection.has("rng_seed"),
			"Failed replay bootstrap must not provide a fallback seed.")


func test_normal_network_start_retains_fresh_seed_selection() -> void:
	ReplayDriver.enabled = false
	ReplayDriver._connect_target = "127.0.0.1:7350"
	ReplayDriver.pending_replay_seed = -9223372036854775807

	var selection: Dictionary = LobbyManager._select_start_rng_seed()

	assert_true(bool(selection.get("ok", false)),
			"Normal network start should retain fresh seed selection.")
	assert_ne(int(selection.get("rng_seed", 0)), 0,
			"Normal network start should select a non-zero fresh seed.")
	assert_ne(int(selection.get("rng_seed", 0)),
			ReplayDriver.pending_replay_seed,
			"Normal network start must not consume a replay seed.")
	assert_eq(ReplayDriver.pending_replay_seed, -9223372036854775807,
			"Normal network start must leave replay-bootstrap state untouched.")
