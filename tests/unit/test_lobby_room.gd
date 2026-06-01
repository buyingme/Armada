## Test: LobbyRoom
##
## Unit tests for the network lobby scenario picker.
extends GutTest


const SETUP_MATCH_OPTIONS_SCRIPT: GDScript = preload(
		"res://src/core/setup/setup_match_options.gd")

var _room: LobbyRoom = null
var _previous_lobby: LobbyState = null


func before_each() -> void:
	_previous_lobby = LobbyManager.current_lobby
	LobbyManager.current_lobby = null
	_room = LobbyRoom.new()
	add_child_autofree(_room)


func after_each() -> void:
	LobbyManager.current_lobby = _previous_lobby


func test_scenario_picker_contains_debug_scenario() -> void:
	var ids: Array[String] = _scenario_option_ids()
	assert_true(ids.has(LobbyState.MATCH_STANDARD_400_ID),
			"Lobby New Game picker should include Standard 400.")
	assert_true(ids.has(LobbyState.MATCH_INTERMEDIATE_300_ID),
			"Lobby New Game picker should include Intermediate 300.")
	assert_true(ids.has(LobbyState.MATCH_CORE_SET_180_ID),
			"Lobby New Game picker should include Core Set 180.")
	assert_true(ids.has(LobbyState.SCENARIO_LEARNING_ID),
			"Lobby New Game picker should include the learning scenario.")
	assert_true(ids.has(LobbyState.SCENARIO_DEBUG_ID),
			"Lobby New Game picker should include debug_scenario.")


func test_update_display_selects_debug_scenario_from_lobby() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.scenario = LobbyState.SCENARIO_DEBUG_ID
	LobbyManager.current_lobby = lobby

	_room._update_display()

	assert_eq(_selected_scenario_id(), LobbyState.SCENARIO_DEBUG_ID,
			"Lobby display should select the debug scenario from lobby state.")


func test_update_display_selects_standard_400_from_lobby() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.scenario = LobbyState.MATCH_STANDARD_400_ID
	LobbyManager.current_lobby = lobby

	_room._update_display()

	assert_eq(_selected_scenario_id(), LobbyState.MATCH_STANDARD_400_ID,
			"Lobby display should select Standard 400 from lobby state.")
	assert_true(_room._status_label.text.contains(
			SETUP_MATCH_OPTIONS_SCRIPT.LABEL_STANDARD_400),
			"Lobby status should display the host-selected match type.")


func _scenario_option_ids() -> Array[String]:
	var ids: Array[String] = []
	for i: int in range(_room._scenario_option.item_count):
		var metadata: Variant = _room._scenario_option.get_item_metadata(i)
		if metadata is String:
			ids.append(metadata as String)
	return ids


func _selected_scenario_id() -> String:
	var selected: int = _room._scenario_option.selected
	if selected < 0:
		return ""
	var metadata: Variant = _room._scenario_option.get_item_metadata(selected)
	if metadata is String:
		return metadata as String
	return ""
