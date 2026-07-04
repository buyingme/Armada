## Test: LobbyRoom
##
## Unit tests for the network lobby scenario picker.
extends GutTest


const SETUP_MATCH_OPTIONS_SCRIPT: GDScript = preload(
		"res://src/core/setup/setup_match_options.gd")
var _library_manager_script: GDScript = preload(
		"res://src/core/fleet/fleet_library_manager.gd")

var _room: LobbyRoom = null
var _previous_lobby: LobbyState = null
var _previous_role: NetworkManager.Role = NetworkManager.Role.NONE
var _original_library_dir: String = ""
var _test_library_dir: String = "user://test_lobby_room_library"


func before_each() -> void:
	_previous_lobby = LobbyManager.current_lobby
	_previous_role = NetworkManager.role
	_original_library_dir = _library_manager_script.LIBRARY_DIR
	_library_manager_script.LIBRARY_DIR = _test_library_dir
	_cleanup_test_dir()
	_save_valid_roster()
	NetworkManager.role = NetworkManager.Role.SERVER
	LobbyManager.current_lobby = null
	_room = LobbyRoom.new()
	add_child_autofree(_room)


func after_each() -> void:
	LobbyManager.current_lobby = _previous_lobby
	NetworkManager.role = _previous_role
	_cleanup_test_dir()
	_library_manager_script.LIBRARY_DIR = _original_library_dir


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


func test_update_display_keeps_initiative_and_objectives_out_of_lobby() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.scenario = LobbyState.MATCH_STANDARD_400_ID
	lobby.players = [
		{"peer_id": 1, "display_name": "Host", "player_index": 0, "ready": true},
		{"peer_id": 2, "display_name": "Client", "player_index": 1, "ready": true},
	]
	lobby.setup_draft = LobbyManager._setup_draft_for_match_type(lobby.scenario)
	var draft_state: Dictionary = (lobby.setup_draft.get("setup_state", {}) as Dictionary)
	draft_state[LobbyManager.SETUP_KEY_PHASE] = LobbyManager.SETUP_PHASE_FLEETS_READY
	draft_state[LobbyManager.SETUP_KEY_VALIDATION_STATUS] = {"ok": true, "messages": []}
	lobby.setup_draft["setup_state"] = draft_state
	LobbyManager.current_lobby = lobby

	_room._update_display()

	assert_true(_room._setup_section.visible,
			"Setup matches should display the shared setup section in the lobby.")
	assert_null(_room.find_child("ObjectiveChoicePanel", true, false),
			"Objective choice UI should not be present in the lobby.")
	assert_true(_room._status_label.text.contains("Fleets are ready"),
			"Lobby status should describe fleet readiness, not objective confirmation.")


func test_update_display_enables_start_when_fleets_are_valid() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.scenario = LobbyState.MATCH_STANDARD_400_ID
	lobby.players = [
		{"peer_id": 1, "display_name": "Host", "player_index": 0, "ready": true},
		{"peer_id": 2, "display_name": "Client", "player_index": 1, "ready": true},
	]
	lobby.setup_draft = LobbyManager._setup_draft_for_match_type(lobby.scenario)
	var draft_state: Dictionary = (lobby.setup_draft.get("setup_state", {}) as Dictionary)
	draft_state[LobbyManager.SETUP_KEY_PHASE] = LobbyManager.SETUP_PHASE_FLEETS_READY
	draft_state[LobbyManager.SETUP_KEY_VALIDATION_STATUS] = {"ok": true, "messages": []}
	lobby.setup_draft["setup_state"] = draft_state
	LobbyManager.current_lobby = lobby

	_room._update_display()

	assert_false(_room._start_button.disabled,
			"The host should be able to start once both players are Ready with valid fleets.")


func test_update_display_shows_exact_setup_validation_messages_expected() -> void:
	var lobby: LobbyState = _setup_lobby()
	var draft_state: Dictionary = (lobby.setup_draft.get("setup_state", {}) as Dictionary)
	draft_state[LobbyManager.SETUP_KEY_PHASE] = LobbyManager.SETUP_PHASE_FLEET_SELECTION
	draft_state[LobbyManager.SETUP_KEY_VALIDATION_STATUS] = {
		"ok": false,
		"messages": [LobbyManager.VALIDATION_MESSAGE_NAMES_BLANK],
	}
	lobby.setup_draft["setup_state"] = draft_state
	LobbyManager.current_lobby = lobby

	_room._update_display()

	assert_true(_room._status_label.text.contains(LobbyManager.VALIDATION_MESSAGE_NAMES_BLANK),
			"Lobby status should surface the accepted fleet-selection validation messages.")


func test_update_display_with_local_ready_locks_setup_fleet_selector_expected() -> void:
	var lobby: LobbyState = _setup_lobby()
	lobby.players[0]["ready"] = true
	LobbyManager.current_lobby = lobby

	_room._update_display()

	assert_true(_room._setup_local_fleet_option.disabled,
			"Ready should lock the submitted local fleet selector until the player unreadies.")


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


func _setup_lobby() -> LobbyState:
	var lobby: LobbyState = LobbyState.new()
	lobby.scenario = LobbyState.MATCH_STANDARD_400_ID
	lobby.players = [
		{"peer_id": 1, "display_name": "Host", "player_index": 0, "ready": true},
		{"peer_id": 2, "display_name": "Client", "player_index": 1, "ready": true},
	]
	lobby.setup_draft = LobbyManager._setup_draft_for_match_type(lobby.scenario)
	return lobby


func _save_valid_roster() -> void:
	var manager: FleetLibraryManager = FleetLibraryManager.new()
	manager.save_roster(_create_rebel_roster())


func _create_rebel_roster() -> FleetRoster:
	var roster: FleetRoster = FleetRoster.create("rebel-fleet", "Rebel Setup Fleet", "REBEL_ALLIANCE")
	roster.point_format = {
		"id": FleetBuilderOptions.FORMAT_STANDARD_400,
		"limit": FleetValidator.DEFAULT_POINT_LIMIT,
	}
	roster.map = FleetBuilderOptions.default_map_for_point_format(roster.point_format)
	var ship: FleetShipEntry = FleetShipEntry.new()
	ship.entry_id = "rebel-ship-1"
	ship.data_key = "cr90_corvette_a"
	var assignment: FleetUpgradeAssignment = FleetUpgradeAssignment.new()
	assignment.entry_id = "rebel-cmd"
	assignment.data_key = "general_dodonna"
	assignment.slot = "COMMANDER"
	ship.add_upgrade(assignment)
	roster.add_ship(ship)
	return roster


func _cleanup_test_dir() -> void:
	if not DirAccess.dir_exists_absolute(_test_library_dir):
		return
	var dir: DirAccess = DirAccess.open(_test_library_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir():
			DirAccess.remove_absolute("%s/%s" % [_test_library_dir, entry])
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(_test_library_dir)
