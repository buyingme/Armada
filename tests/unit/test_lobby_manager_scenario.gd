## Test: LobbyManager Scenario Selection
##
## Unit tests for mapping lobby scenario state into game-start configuration.
extends GutTest


var _previous_lobby: LobbyState = null


func before_each() -> void:
	_previous_lobby = LobbyManager.current_lobby


func after_each() -> void:
	LobbyManager.current_lobby = _previous_lobby


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
