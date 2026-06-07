## Test: SetupFlowScene
##
## Focused UI tests for the FB13C local setup-package confirmation screen.
extends GutTest


var _library_manager_script: GDScript = preload(
		"res://src/core/fleet/fleet_library_manager.gd")
var _setup_flow_script: GDScript = preload(
		"res://src/scenes/setup_flow/setup_flow.gd")
const SETUP_MATCH_OPTIONS_SCRIPT: GDScript = preload(
		"res://src/core/setup/setup_match_options.gd")
var _original_library_dir: String = ""
var _test_library_dir: String = "user://test_setup_flow_scene_library"
var _manager: FleetLibraryManager
var _scene: Variant = null
var _previous_lobby: LobbyState = null


func before_each() -> void:
	_previous_lobby = LobbyManager.current_lobby
	GameManager.consume_next_setup_match_type(SETUP_MATCH_OPTIONS_SCRIPT.MATCH_STANDARD_400)
	_original_library_dir = _library_manager_script.LIBRARY_DIR
	_library_manager_script.LIBRARY_DIR = _test_library_dir
	_cleanup_test_dir()
	_manager = FleetLibraryManager.new()
	_save_valid_rosters()
	_scene = _setup_flow_script.new()
	_scene.transition_on_confirm = false
	_scene.initialize(_manager)
	add_child(_scene)


func after_each() -> void:
	LobbyManager.current_lobby = _previous_lobby
	GameManager.consume_next_setup_package()
	GameManager.consume_next_setup_match_type(SETUP_MATCH_OPTIONS_SCRIPT.MATCH_STANDARD_400)
	if _scene != null and is_instance_valid(_scene):
		remove_child(_scene)
		_scene.free()
	_scene = null
	_cleanup_test_dir()
	_library_manager_script.LIBRARY_DIR = _original_library_dir


func test_ready_builds_required_controls_expected() -> void:
	assert_not_null(_scene.find_child("SetupFlowPanel", true, false),
		"Setup flow should build the main panel")
	assert_not_null(_scene.find_child("PackageSummary", true, false),
		"Setup flow should build the package summary section")
	assert_not_null(_find_button(_scene, "Confirm Choice"),
		"Setup flow should include an initiative confirmation button")
	assert_not_null(_find_button(_scene, "Cancel"),
		"Setup flow should include a cancel button")
	assert_eq(_scene._first_player_buttons.size(), 2,
		"Setup flow should build a two-button segmented first-player control")


func test_ready_initializes_package_draft_from_selected_match_type_expected() -> void:
	var draft: FleetSetupPackage = _scene.current_package_draft()

	assert_not_null(draft, "Setup flow should expose the selected match-type draft")
	assert_eq(int(draft.point_format.get("limit", 0)), FleetValidator.DEFAULT_POINT_LIMIT,
		"Default setup-flow draft should target Standard 400.")
	assert_eq(draft.setup_state.get("match_type", ""),
		SETUP_MATCH_OPTIONS_SCRIPT.MATCH_STANDARD_400,
		"Default setup-flow draft should record Standard 400.")


func test_ready_core_set_match_type_filters_fleet_options_expected() -> void:
	remove_child(_scene)
	_scene.free()
	_cleanup_test_dir()
	_manager = FleetLibraryManager.new()
	_manager.save_roster(_create_rebel_roster("rebel-180", "Rebel 180"))
	_manager.save_roster(_create_imperial_roster_for_limit(
			"imperial-180", "Imperial 180", FleetBuilderOptions.CORE_SET_POINT_LIMIT))
	_manager.save_roster(_create_imperial_roster_for_limit(
			"imperial-400", "Imperial 400", FleetValidator.DEFAULT_POINT_LIMIT))
	GameManager.set_next_setup_match_type(SETUP_MATCH_OPTIONS_SCRIPT.MATCH_CORE_SET_180)
	_scene = _setup_flow_script.new()
	_scene.transition_on_confirm = false
	_scene.initialize(_manager)
	add_child(_scene)

	var fleet_ids: Array[String] = []
	for index: int in range(_scene._player_one_option.get_item_count()):
		fleet_ids.append(str(_scene._player_one_option.get_item_metadata(index)))

	assert_true(fleet_ids.has("imperial-180"),
		"Core Set setup should include matching 180-point fleets")
	assert_false(fleet_ids.has("imperial-400"),
		"Core Set setup should hide fleets that do not match the selected point limit")


func test_ready_with_two_valid_fleets_builds_package_expected() -> void:
	_set_valid_player_names()
	_confirm_initiative_twice()
	_lock_and_acknowledge_objective("obj_ass_opening_salvo")
	var package: FleetSetupPackage = _scene.current_package()

	assert_not_null(package, "Two valid saved fleets should build a setup package")
	assert_false(_scene._confirm_button.disabled,
		"A valid setup package should enable confirmation")
	assert_true(_scene._hash_label.text.contains(package.canonical_hash()),
		"Summary should display the deterministic package hash")
	assert_true(_scene._summary_label.text.contains(
			str(package.selected_objective.get("objective_name", ""))),
		"Summary should show the selected objective name")


func test_ready_lets_lower_fleet_points_player_choose_first_player_expected() -> void:
	_set_valid_player_names()
	assert_false(_scene._first_player_buttons[0].disabled,
		"First-player choice should be selectable before initiative confirmation")
	assert_eq(_scene._initiative_chooser, 1,
		"Lower-point fleet should receive the first-player choice")
	_confirm_initiative_twice()
	_lock_and_acknowledge_objective("obj_ass_opening_salvo")
	var package: FleetSetupPackage = _scene.current_package()

	assert_not_null(package, "Valid setup should build a package")
	assert_eq(package.first_player, 1,
		"Chooser should default to choosing themselves as first player")
	assert_eq(package.selected_objective.get("owner_player", -1), 0,
		"Objective should come from the second player's roster")
	assert_true(_objective_keys().has("obj_ass_opening_salvo"),
		"Objective chooser should use the derived second player's objectives")


func test_initiative_summary_uses_names_for_tied_chooser_expected() -> void:
	_set_valid_player_names()
	_scene._initiative_random = true
	_scene._initiative_chooser = 1
	_scene._resolved_first_player = 0
	var rosters: Array[FleetRoster] = [
		_create_rebel_roster("rebel-tie", "Rebel Tie Fleet"),
		_create_imperial_roster_for_limit("imperial-tie", "Imperial Tie Fleet", 400),
	]
	var summary: String = _scene._initiative_summary_text(rosters)

	assert_true(summary.contains("Darth") and summary.contains("Leia"),
		"Initiative summary should use player display names.")
	assert_true(summary.contains("won the random tie-break chooser"),
		"Tied initiative summary should explain the random chooser, not a random first player.")
	assert_false(summary.contains("Player 1") or summary.contains("Player 2"),
		"Initiative summary should not fall back to Player 1 or Player 2 labels.")


func test_update_network_first_player_option_allows_tied_chooser_expected() -> void:
	var previous_role: NetworkManager.Role = NetworkManager.role
	NetworkManager.role = NetworkManager.Role.SERVER
	var state: Dictionary = {
		LobbyManager.SETUP_KEY_PHASE: LobbyManager.SETUP_PHASE_INITIATIVE_CONFIRMATION,
		LobbyManager.SETUP_KEY_INITIATIVE_CHOOSER: 0,
		LobbyManager.SETUP_KEY_INITIATIVE_TIED: true,
		"resolved_first_player": 0,
	}

	_scene._update_network_first_player_option(state)
	NetworkManager.role = previous_role

	assert_false(_scene._first_player_buttons[0].disabled,
		"The random tie-break chooser should still be able to select first player in network projection.")


func test_network_initiative_summary_uses_names_for_tied_chooser_expected() -> void:
	_set_valid_player_names()
	_scene._sync_package_draft_state()
	var state: Dictionary = {
		LobbyManager.SETUP_KEY_PLAYER_POINTS: [400, 400],
		LobbyManager.SETUP_KEY_INITIATIVE_CHOOSER: 1,
		LobbyManager.SETUP_KEY_INITIATIVE_TIED: true,
		"resolved_first_player": 0,
	}
	var summary: String = _scene._network_initiative_summary(_scene._package_draft, state)

	assert_true(summary.contains("Darth") and summary.contains("Leia"),
		"Network initiative summary should use player display names.")
	assert_true(summary.contains("won the random tie-break chooser"),
		"Network initiative summary should explain the random chooser.")
	assert_false(summary.contains("Player 1") or summary.contains("Player 2"),
		"Network initiative summary should not use Player 1 or Player 2 labels.")
	assert_true(summary.contains("REBEL_ALLIANCE") and summary.contains("GALACTIC_EMPIRE"),
		"Network initiative summary should include player factions.")


func test_refresh_first_player_options_network_uses_lobby_names_expected() -> void:
	var lobby: LobbyState = LobbyState.new()
	lobby.players = [
		{"peer_id": 1, "display_name": "Luke", "player_index": 0, "ready": true},
		{"peer_id": 2, "display_name": "Darth", "player_index": 1, "ready": true},
	]
	LobbyManager.current_lobby = lobby
	_scene._is_network_setup = true
	var players: Array[Dictionary] = [
		{"player_index": 0, "display_name": "Fleet 1"},
		{"player_index": 1, "display_name": "Fleet 2"},
	]
	_scene._package_draft.players = players

	_scene._refresh_first_player_options()

	assert_eq(_scene._first_player_buttons[0].text, "Luke",
		"Network initiative buttons should use lobby player names instead of local hot-seat defaults.")
	assert_eq(_scene._first_player_buttons[1].text, "Darth",
		"Network initiative buttons should show the remote player's lobby display name.")


func test_first_player_selection_rebuilds_objective_owner_expected() -> void:
	_set_valid_player_names()
	_scene._on_first_player_selected(0)
	_confirm_initiative_twice()
	_lock_and_acknowledge_objective("obj_ass_most_wanted")
	var package: FleetSetupPackage = _scene.current_package()

	assert_not_null(package, "Changing first player should rebuild a setup package")
	assert_eq(package.first_player, 0,
		"The initiative chooser should be able to choose either player as first")
	assert_eq(package.selected_objective.get("owner_player", -1), 1,
		"Objective choices should move to the chosen second player's roster")
	assert_true(_objective_keys().has("obj_ass_most_wanted"),
		"Objective chooser should show the new second player's objectives")


func test_objective_choice_requires_explicit_confirmation_expected() -> void:
	_set_valid_player_names()
	assert_null(_scene.current_package(),
		"Setup flow should not build a package until an objective is confirmed")
	assert_false(_scene._confirm_button.disabled,
		"Valid fleets should enable initiative confirmation first")
	assert_false(_scene._objective_panel.visible,
		"Objective chooser should stay hidden until initiative is confirmed")

	_confirm_initiative_once()

	assert_false(_scene._objective_panel.visible,
		"Hot-seat setup should require the second initiative confirmation before objectives appear")
	assert_true(_scene._status_label.text.contains("confirmed")
			or _scene._status_label.text.contains("pending"),
		"Initiative status should show per-player confirmation state.")

	_confirm_initiative_once()

	assert_true(_scene._confirm_button.disabled,
		"Setup confirmation should stay disabled until objective choice is confirmed")
	assert_true(_scene._objective_panel.visible,
		"Objective chooser should appear after initiative is confirmed")
	assert_true(_objective_keys().has("obj_ass_opening_salvo"),
		"Objective chooser should render the second player's three objective cards")

	_lock_objective("obj_ass_opening_salvo")

	assert_true(_scene._confirm_button.disabled,
		"Start setup should stay disabled until the second objective acknowledgement completes")
	assert_true(_scene._status_label.text.contains("acknowledge"),
		"Objective status should prompt the second player acknowledgement after lock")

	_acknowledge_objective()

	assert_false(_scene._confirm_button.disabled,
		"Both objective confirmations should enable setup start when the package is valid")


func test_blank_hot_seat_name_disables_initiative_confirmation_expected() -> void:
	_scene._player_zero_name_input.text = "Darth"
	_scene._on_player_name_changed("Darth", 0)

	assert_true(_scene._confirm_button.disabled,
		"Hot-seat setup should require both display names before initiative confirmation")
	assert_true(_validation_messages().has(
			FleetSetupPackageBuilder.VALIDATION_MESSAGE_NAMES_BLANK),
		"Blank display names should use the accepted fleet-selection validation message")


func test_invalid_fleet_selection_disables_confirmation_expected() -> void:
	_set_valid_player_names()
	_manager.save_roster(_invalid_rebel_roster())
	_scene._refresh_fleets()
	_select_fleet(_scene._player_zero_option, "invalid-rebel-fleet")
	_select_fleet(_scene._player_one_option, "imperial-fleet")
	_scene._on_fleet_selected(_scene._player_zero_option.selected)
	_confirm_initiative_twice()
	_lock_and_acknowledge_objective("obj_ass_opening_salvo")

	assert_null(_scene.current_package(), "Invalid fleet selection should not build a package")
	assert_true(_scene._confirm_button.disabled,
		"Invalid setup packages should disable confirmation")
	assert_true(_scene._validation_list.item_count > 0,
		"Validation errors should be visible")


func test_confirm_stores_next_setup_package_expected() -> void:
	_set_valid_player_names()
	_confirm_initiative_twice()
	_lock_and_acknowledge_objective("obj_ass_opening_salvo")
	var package: FleetSetupPackage = _scene.current_package()

	_scene._on_confirm_pressed()
	var stored: FleetSetupPackage = GameManager.consume_next_setup_package()

	assert_not_null(stored, "Confirm should store the next setup package")
	assert_eq(stored.canonical_hash(), package.canonical_hash(),
		"Stored package should match the confirmed package")


func _save_valid_rosters() -> void:
	_manager.save_roster(_create_rebel_roster("rebel-fleet", "Rebel Setup Fleet"))
	_manager.save_roster(_create_imperial_roster())


func _create_rebel_roster(fleet_id: String, fleet_name: String) -> FleetRoster:
	var roster: FleetRoster = FleetRoster.create(fleet_id, fleet_name, "REBEL_ALLIANCE")
	roster.point_format = _point_format()
	roster.map = FleetBuilderOptions.default_map_for_point_format(roster.point_format)
	var ship: FleetShipEntry = _create_ship("rebel-ship-1", "cr90_corvette_a")
	_add_upgrade(ship, "rebel-cmd", "general_dodonna", "OFFICER")
	roster.add_ship(ship)
	roster.add_squadron(_create_squadron("rebel-squadron-1", "x_wing_squadron"))
	_set_rebel_objectives(roster)
	return roster


func _invalid_rebel_roster() -> FleetRoster:
	var roster: FleetRoster = _create_rebel_roster("invalid-rebel-fleet", "Invalid Rebel")
	roster.get_ship("rebel-ship-1").upgrades.clear()
	return roster


func _create_imperial_roster() -> FleetRoster:
	return _create_imperial_roster_for_limit(
			"imperial-fleet", "Imperial Setup Fleet", FleetValidator.DEFAULT_POINT_LIMIT)


func _create_imperial_roster_for_limit(
		fleet_id: String, fleet_name: String, point_limit: int) -> FleetRoster:
	var roster: FleetRoster = FleetRoster.create(
			fleet_id, fleet_name, "GALACTIC_EMPIRE")
	roster.point_format = _point_format(point_limit)
	roster.map = FleetBuilderOptions.default_map_for_point_format(roster.point_format)
	var ship: FleetShipEntry = _create_ship(
			"imperial-ship-1", "victory_ii_class_star_destroyer")
	_add_upgrade(ship, "imperial-cmd", "grand_moff_tarkin", "OFFICER")
	roster.add_ship(ship)
	roster.add_squadron(_create_squadron("imperial-squadron-1", "tie_fighter_squadron"))
	_set_imperial_objectives(roster)
	return roster


func _set_rebel_objectives(roster: FleetRoster) -> void:
	var objectives: FleetObjectiveSelection = FleetObjectiveSelection.new()
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_DEFENSE, "obj_def_fire_lanes")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_NAVIGATION, "obj_nav_intel_sweep")
	roster.set_objectives(objectives)


func _set_imperial_objectives(roster: FleetRoster) -> void:
	var objectives: FleetObjectiveSelection = FleetObjectiveSelection.new()
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_opening_salvo")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_DEFENSE, "obj_def_fleet_ambush")
	objectives.set_objective(FleetObjectiveSelection.CATEGORY_NAVIGATION, "obj_nav_minefields")
	roster.set_objectives(objectives)


func _create_ship(entry_id: String, data_key: String) -> FleetShipEntry:
	var ship_entry: FleetShipEntry = FleetShipEntry.new()
	ship_entry.entry_id = entry_id
	ship_entry.data_key = data_key
	return ship_entry


func _create_squadron(entry_id: String, data_key: String) -> FleetSquadronEntry:
	var squadron_entry: FleetSquadronEntry = FleetSquadronEntry.new()
	squadron_entry.entry_id = entry_id
	squadron_entry.data_key = data_key
	return squadron_entry


func _add_upgrade(ship_entry: FleetShipEntry, upgrade_id: String,
		upgrade_key: String, slot: String) -> void:
	var assignment: FleetUpgradeAssignment = FleetUpgradeAssignment.new()
	assignment.entry_id = upgrade_id
	assignment.data_key = upgrade_key
	assignment.slot = slot
	ship_entry.add_upgrade(assignment)


func _point_format(point_limit: int = FleetValidator.DEFAULT_POINT_LIMIT) -> Dictionary:
	match point_limit:
		FleetBuilderOptions.CORE_SET_POINT_LIMIT:
			return {"id": FleetBuilderOptions.FORMAT_CORE_SET_180, "limit": point_limit}
		FleetBuilderOptions.CUSTOM_POINT_LIMIT:
			return {"id": FleetBuilderOptions.FORMAT_CUSTOM, "limit": point_limit}
		_:
			return {"id": FleetBuilderOptions.FORMAT_STANDARD_400, "limit": point_limit}


func _select_fleet(option: OptionButton, fleet_id: String) -> void:
	for index: int in range(option.get_item_count()):
		if str(option.get_item_metadata(index)) == fleet_id:
			option.select(index)
			return


func _objective_keys() -> Array[String]:
	return _scene._objective_panel.available_objective_keys()


func _validation_messages() -> Array[String]:
	var messages: Array[String] = []
	for index: int in range(_scene._validation_list.item_count):
		messages.append(_scene._validation_list.get_item_text(index))
	return messages


func _set_valid_player_names() -> void:
	_scene._player_zero_name_input.text = "Darth"
	_scene._on_player_name_changed("Darth", 0)
	_scene._player_one_name_input.text = "Leia"
	_scene._on_player_name_changed("Leia", 1)


func _lock_objective(objective_key: String) -> void:
	_scene._objective_panel.choose_objective(objective_key)
	_scene._objective_panel.confirm_current_selection()


func _acknowledge_objective() -> void:
	_scene._objective_panel.confirm_current_selection()


func _lock_and_acknowledge_objective(objective_key: String) -> void:
	_lock_objective(objective_key)
	_acknowledge_objective()


func _confirm_initiative_once() -> void:
	_scene._on_confirm_pressed()


func _confirm_initiative_twice() -> void:
	_confirm_initiative_once()
	_confirm_initiative_once()


func _confirm_initiative() -> void:
	_scene._on_confirm_pressed()


func _find_button(root: Node, text: String) -> Button:
	for child: Node in root.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button != null and button.text == text:
			return button
	return null


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
