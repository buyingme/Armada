## Test: LobbyManager Scenario Selection
##
## Unit tests for mapping lobby scenario state into game-start configuration.
extends GutTest


var _previous_lobby: LobbyState = null
var _previous_role: int = NetworkManager.Role.NONE


func before_each() -> void:
	_previous_lobby = LobbyManager.current_lobby
	_previous_role = NetworkManager.role


func after_each() -> void:
	LobbyManager.current_lobby = _previous_lobby
	NetworkManager.role = _previous_role


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
