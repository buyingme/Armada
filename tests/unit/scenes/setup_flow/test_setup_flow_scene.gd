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


func before_each() -> void:
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
	assert_not_null(_find_button(_scene, "Confirm"),
		"Setup flow should include a confirm button")
	assert_not_null(_find_button(_scene, "Cancel"),
		"Setup flow should include a cancel button")


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
	var package: FleetSetupPackage = _scene.current_package()

	assert_not_null(package, "Valid setup should build a package")
	assert_false(_scene._first_player_option.disabled,
		"First-player choice should be selectable by the initiative chooser")
	assert_eq(_scene._initiative_chooser, 1,
		"Lower-point fleet should receive the first-player choice")
	assert_eq(package.first_player, 1,
		"Chooser should default to choosing themselves as first player")
	assert_eq(package.selected_objective.get("owner_player", -1), 0,
		"Objective should come from the second player's roster")
	assert_true(_objective_options_contain("Opening Salvo"),
		"Objective picker should use the derived second player's objectives")


func test_first_player_selection_rebuilds_objective_owner_expected() -> void:
	_scene._first_player_option.select(0)
	_scene._on_first_player_selected(0)
	var package: FleetSetupPackage = _scene.current_package()

	assert_not_null(package, "Changing first player should rebuild a setup package")
	assert_eq(package.first_player, 0,
		"The initiative chooser should be able to choose either player as first")
	assert_eq(package.selected_objective.get("owner_player", -1), 1,
		"Objective choices should move to the chosen second player's roster")
	assert_true(_objective_options_contain("Most Wanted"),
		"Objective picker should show the new second player's objectives")


func test_invalid_fleet_selection_disables_confirmation_expected() -> void:
	_manager.save_roster(_invalid_rebel_roster())
	_scene._refresh_fleets()
	_select_fleet(_scene._player_zero_option, "invalid-rebel-fleet")
	_select_fleet(_scene._player_one_option, "imperial-fleet")
	_scene._on_fleet_selected(_scene._player_zero_option.selected)

	assert_null(_scene.current_package(), "Invalid fleet selection should not build a package")
	assert_true(_scene._confirm_button.disabled,
		"Invalid setup packages should disable confirmation")
	assert_true(_scene._validation_list.item_count > 0,
		"Validation errors should be visible")


func test_confirm_stores_next_setup_package_expected() -> void:
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


func _objective_options_contain(text: String) -> bool:
	for index: int in range(_scene._objective_option.get_item_count()):
		if _scene._objective_option.get_item_text(index).contains(text):
			return true
	return false


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
