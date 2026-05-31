## Test: FleetBuilderScene
##
## Focused UI tests for the FB9 fleet-builder scene MVP.
extends GutTest


const MainMenuScript: GDScript = preload("res://src/scenes/main_menu/main_menu.gd")

var _scene: FleetBuilderScene = null
var _library_manager_script: GDScript = preload(
		"res://src/core/fleet/fleet_library_manager.gd")
var _original_library_dir: String = ""
var _test_library_dir: String = "user://test_fleet_builder_scene_library"


func before_each() -> void:
	_original_library_dir = _library_manager_script.LIBRARY_DIR
	_library_manager_script.LIBRARY_DIR = _test_library_dir
	_cleanup_test_dir()
	_scene = FleetBuilderScene.new()
	add_child(_scene)


func after_each() -> void:
	_free_node(_scene)
	_scene = null
	_cleanup_test_dir()
	_library_manager_script.LIBRARY_DIR = _original_library_dir


func test_ready_builds_required_sections_expected() -> void:
	assert_not_null(_find_button(_scene, "Add Component"), "Add Component button should exist")
	assert_null(_find_button(_scene, "Set Objective"), "Catalog should not include Set Objective")
	assert_not_null(_scene.find_child("FleetDataPanel", true, false),
		"Fleet builder should include the Fleet Data panel")
	assert_not_null(_scene.find_child("FleetDataTabs", true, false),
		"Fleet Data panel should expose Catalog/Fleets tabs")
	assert_not_null(_scene.find_child("Catalog", true, false),
		"Fleet Data should include the Catalog tab")
	assert_not_null(_scene.find_child("Fleets", true, false),
		"Fleet Data should include the Fleets tab")
	assert_not_null(_scene.find_child("ReferencePanel", true, false),
		"Fleet builder should include the Reference side panel")
	assert_not_null(_scene.find_child("ReferenceTabs", true, false),
		"Reference panel should expose tab navigation")
	assert_not_null(_scene.find_child("Standard", true, false), "Reference should include Standard tab")
	assert_not_null(_scene.find_child("Rules", true, false), "Reference should include Rules tab")
	assert_not_null(_scene.find_child("Component Art", true, false),
		"Reference should include Component Art tab")
	assert_true(_scene._catalog_list.item_count > 0, "Catalog should populate on ready")
	assert_true(_scene._rules_list.item_count > 0, "Rules reference should populate on ready")


func test_section_panels_use_standard_modal_style_expected() -> void:
	var panel: PanelContainer = _scene.find_child("FleetDataPanel", true, false) as PanelContainer
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat

	assert_not_null(style, "Fleet builder panels should use StyleBoxFlat styling")
	assert_eq(style.bg_color, UIStyleHelper.MODAL_BG,
		"Fleet builder panels should use the shared modal background")
	assert_eq(style.border_color, UIStyleHelper.MODAL_BORDER,
		"Fleet builder panels should use the shared modal border")


func test_reference_panel_fits_default_viewport_expected() -> void:
	var catalog_panel: PanelContainer = _scene.find_child("FleetDataPanel", true, false) as PanelContainer
	var roster_panel: PanelContainer = _scene.find_child("RosterPanel", true, false) as PanelContainer
	var reference_panel: PanelContainer = _scene.find_child("ReferencePanel", true, false) as PanelContainer
	var total_width: float = catalog_panel.custom_minimum_size.x \
			+ roster_panel.custom_minimum_size.x + reference_panel.custom_minimum_size.x

	assert_lte(total_width, 960.0,
		"Primary fleet-builder panels should leave room for spacing on small viewports")


func test_status_panel_uses_compact_height_expected() -> void:
	var status_panel: PanelContainer = _scene.find_child("StatusPanel", true, false) as PanelContainer

	assert_not_null(status_panel, "Fleet builder should include a compact status panel")
	assert_lte(status_panel.custom_minimum_size.y, 36.0,
		"Status panel should use the compact half-height layout")


func test_map_selector_defaults_to_core_3x3_expected() -> void:
	assert_not_null(_scene._map_option, "Roster panel should include a map selector")
	assert_true(_scene._map_option.item_count > 0, "Map selector should be populated")
	assert_eq(_scene.current_roster().map.get("grid", ""), FleetBuilderOptions.MAP_GRID_3X3,
		"Default Core Set draft should use a 3x3 map")
	assert_true(_map_options_all_match_grid(FleetBuilderOptions.MAP_GRID_3X3),
		"Core Set 180 should only show 3x3 maps")


func test_format_change_refreshes_map_options_expected() -> void:
	_select_point_limit(400)

	assert_eq(_scene.current_roster().map.get("grid", ""), FleetBuilderOptions.MAP_GRID_3X6,
		"Standard 400 should switch the roster map to 3x6")
	assert_true(_map_options_all_match_grid(FleetBuilderOptions.MAP_GRID_3X6),
		"Standard 400 should only show 3x6 maps")


func test_map_selection_updates_roster_expected() -> void:
	_select_point_limit(400)
	var target_index: int = mini(1, _scene._map_option.item_count - 1)
	var payload: Dictionary = _scene._map_option.get_item_metadata(target_index) as Dictionary

	_scene._map_option.select(target_index)
	_scene._on_map_selected(target_index)

	assert_eq(_scene.current_roster().map.get("filename", ""), payload.get("filename", ""),
		"Selecting a map should update the active roster payload")
	assert_eq(str(_scene._selected_component_entry.get("data_key", "")),
		str(payload.get("filename", "")),
		"Selecting a map should make it the active reference component")
	assert_true(_scene._component_rules_text.text.contains(str(payload.get("label", ""))),
		"Selecting a map should show its details in the reference tab")
	assert_not_null(_scene._card_art_rect.texture,
		"Selecting a map should load its preview art")


func test_map_selector_includes_view_button_expected() -> void:
	var button: Button = _find_sibling_button(_scene._map_option, "View")

	assert_not_null(button, "Map selector should include a View button")


func test_map_view_reopens_current_map_expected() -> void:
	_select_point_limit(400)
	var target_index: int = mini(1, _scene._map_option.item_count - 1)
	var payload: Dictionary = _scene._map_option.get_item_metadata(target_index) as Dictionary
	_scene._map_option.select(target_index)
	_scene._on_map_selected(target_index)
	_select_catalog_key(FleetCatalog.COMPONENT_UPGRADE, "redemption")

	_scene._on_map_view_pressed()

	assert_eq(str(_scene._selected_component_entry.get("data_key", "")),
		str(payload.get("filename", "")),
		"View should make the current map inspectable again")
	assert_true(_scene._component_rules_text.text.contains(str(payload.get("label", ""))),
		"View should restore the selected map details")
	assert_not_null(_scene._card_art_rect.texture,
		"View should restore the selected map preview art")


func test_standard_tab_expands_selected_rules_text_expected() -> void:
	assert_eq(_scene._component_rules_text.size_flags_vertical,
		Control.SIZE_EXPAND_FILL,
		"Selected component rules text should use spare Standard tab height")
	assert_eq(_scene._validation_list.size_flags_vertical,
		Control.SIZE_FILL,
		"Validation should keep a fixed visible area instead of taking spare height")
	assert_gte(_scene._component_rules_list.custom_minimum_size.y, 96.0,
		"Selected rule picker should be tall enough for three rule rows")


func test_catalog_search_filters_visible_entries_expected() -> void:
	_select_catalog_type(FleetCatalog.COMPONENT_SHIP)
	_scene._catalog_search_input.text = "cr90"

	_scene._on_catalog_search_changed("cr90")

	assert_true(_scene._catalog_list.item_count > 0, "CR90 search should return entries")
	assert_true(_scene._catalog_list.get_item_text(0).to_lower().contains("cr90"),
		"First filtered catalog entry should mention CR90")


func test_catalog_excludes_objectives_and_rules_expected() -> void:
	for index: int in range(_scene._catalog_type_option.item_count):
		var metadata: String = str(_scene._catalog_type_option.get_item_metadata(index))
		assert_ne(metadata, FleetCatalog.COMPONENT_OBJECTIVE,
			"Objectives should be edited only in the roster objective selectors")
		assert_ne(metadata, FleetCatalog.COMPONENT_RULE_REFERENCE,
			"Rules should live in the reference section instead of the catalog")


func test_header_options_use_core_provider_expected() -> void:
	assert_eq(_scene._format_option.item_count,
		FleetBuilderOptions.available_point_formats().size(),
		"Point-format option count should come from FleetBuilderOptions")
	assert_eq(_scene._faction_option.item_count,
		FleetBuilderOptions.available_factions(FleetCatalog.new()).size(),
		"Faction option count should come from FleetBuilderOptions")


func test_upgrade_type_filter_groups_and_filters_expected() -> void:
	_select_catalog_type(FleetCatalog.COMPONENT_UPGRADE)
	assert_true(_scene._catalog_upgrade_type_option.visible,
		"Upgrade type filter should show only for upgrade catalog")
	assert_true(_scene._catalog_upgrade_type_option.is_item_disabled(1),
		"First upgrade type group header should be disabled")

	_select_upgrade_type("TURBOLASERS")

	assert_true(_scene._catalog_list.item_count > 0, "Turbolasers filter should find entries")
	for index: int in range(_scene._catalog_list.item_count):
		var entry: Dictionary = _scene._catalog_list.get_item_metadata(index) as Dictionary
		assert_eq(str(entry.get("upgrade_type", "")), "TURBOLASERS",
			"Filtered upgrade catalog should only show Turbolasers")


func test_add_and_remove_roster_components_expected() -> void:
	_select_catalog_key(FleetCatalog.COMPONENT_SHIP, "cr90_corvette_a")
	_scene._on_add_component_pressed()
	_select_catalog_key(FleetCatalog.COMPONENT_SQUADRON, "x_wing_squadron")
	_scene._on_add_component_pressed()
	_select_catalog_key(FleetCatalog.COMPONENT_UPGRADE, "general_dodonna")
	_scene._on_add_component_pressed()
	_select_objective_key(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")

	assert_eq(_scene.current_roster().ships.size(), 1, "One ship should be added")
	assert_eq(_scene.current_roster().squadrons.size(), 1, "One squadron should be added")
	assert_eq(_scene.current_roster().ships[0].upgrades.size(), 1,
		"One upgrade should be assigned to the selected ship")
	assert_eq(_scene.current_roster().objectives.assault_objective_key,
		"obj_ass_most_wanted", "Assault objective should be selected")

	_scene._ship_list.select(0)
	_scene._on_remove_ship_pressed()
	assert_true(_scene.current_roster().ships.is_empty(), "Selected ship should be removable")


func test_objective_selection_updates_component_rule_and_card_art_expected() -> void:
	_select_objective_key(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")

	assert_eq(str(_scene._selected_component_entry.get("component_type", "")),
		FleetCatalog.COMPONENT_OBJECTIVE,
		"Selecting a roster objective should make it the active component")
	assert_true(_scene._component_rules_text.text.contains("Most Wanted"),
		"Selecting Most Wanted should show its objective card text")
	assert_true(_scene._component_rules_text.text.contains("add 1 die"),
		"Objective card text should include the special rule")
	assert_not_null(_scene._card_art_rect.texture,
		"Selecting an objective should load its card art")


func test_objective_placeholder_clears_selected_component_expected() -> void:
	_select_objective_key(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")

	_select_objective_key(FleetObjectiveSelection.CATEGORY_ASSAULT, "")

	assert_true(_scene._selected_component_entry.is_empty(),
		"Selecting the objective placeholder should clear the active component")
	assert_true(_scene._component_rules_text.text.contains("No component selected"),
		"Clearing an objective should clear selected component rules")
	assert_null(_scene._card_art_rect.texture,
		"Clearing an objective should clear selected component card art")


func test_objective_view_reopens_current_objective_expected() -> void:
	_select_objective_key(FleetObjectiveSelection.CATEGORY_ASSAULT, "obj_ass_most_wanted")
	_select_catalog_key(FleetCatalog.COMPONENT_UPGRADE, "redemption")

	_scene._on_objective_view_pressed(FleetObjectiveSelection.CATEGORY_ASSAULT)

	assert_eq(str(_scene._selected_component_entry.get("data_key", "")),
		"obj_ass_most_wanted",
		"View should make the currently selected objective inspectable again")
	assert_true(_scene._component_rules_text.text.contains("Most Wanted"),
		"View should restore the objective card text")


func test_loaded_roster_objective_becomes_inspectable_expected() -> void:
	var roster: FleetRoster = FleetRosterDraftHelper.create_default_roster()
	roster.objectives.set_objective(
		FleetObjectiveSelection.CATEGORY_ASSAULT,
		"obj_ass_most_wanted")

	_scene._on_library_roster_loaded(roster)

	assert_eq(str(_scene._selected_component_entry.get("data_key", "")),
		"obj_ass_most_wanted",
		"Loading a roster should make its first objective inspectable")
	assert_not_null(_scene._card_art_rect.texture,
		"Loaded objective reference should include card art")


func test_library_tab_saves_and_loads_current_roster_expected() -> void:
	_select_catalog_key(FleetCatalog.COMPONENT_SHIP, "cr90_corvette_a")
	_scene._on_add_component_pressed()
	_scene._on_name_changed("Scene Library Fleet")

	_scene._library_panel._on_save_pressed()
	_scene.current_roster().name = "Unsaved Local"
	_scene.current_roster().ships.clear()
	_scene._library_panel._on_open_pressed()

	assert_eq(_scene.current_roster().name, "Scene Library Fleet",
		"Library Open should replace the scene roster with the saved snapshot")
	assert_eq(_scene.current_roster().ships.size(), 1,
		"Library Open should restore saved roster components")


func test_library_loaded_roster_rebuilds_entry_counters_expected() -> void:
	var roster: FleetRoster = FleetRosterDraftHelper.create_default_roster()
	FleetRosterDraftHelper.add_ship(roster, "cr90_corvette_a", "ship-5")

	_scene._on_library_roster_loaded(roster)
	_select_catalog_key(FleetCatalog.COMPONENT_SHIP, "nebulon_b_support_refit")
	_scene._on_add_component_pressed()

	assert_not_null(_scene.current_roster().get_ship("ship-6"),
		"Adding after library load should continue from the highest ship entry id")
	assert_eq(_scene.current_roster().ships.size(), 2,
		"Loaded roster and new roster entries should coexist")


func test_validation_panel_renders_core_errors_expected() -> void:
	assert_eq(_scene._validation_list.name, "ValidationList",
		"Validation output should have a stable widget name")
	assert_gte(_scene._validation_list.custom_minimum_size.y, 120.0,
		"Validation output should reserve visible vertical space")
	assert_true(_scene._validation_list.item_count > 0,
		"Initial draft should render validation issues")
	assert_true(_scene._validation_list.get_item_text(0).contains("fleet."),
		"Validation list should render core rule ids")


func test_rules_reference_selection_updates_text_expected() -> void:
	_select_rule_key("squadron_keyword.bomber")

	assert_true(_scene._rules_text.text.contains("Bomber"),
		"Selecting Bomber should show rule text")
	assert_true(_scene._rules_text.text.contains("critical"),
		"Bomber rules text should include its damage reminder")


func test_rules_reference_search_filters_expected() -> void:
	_scene._rules_search_input.text = "bomber"

	_scene._on_rules_search_changed("bomber")

	assert_eq(_scene._rules_list.item_count, 1, "Bomber search should narrow rules list")
	assert_true(_scene._rules_text.text.contains("Bomber"),
		"Filtered rules reference should show the selected rule text")


func test_catalog_selection_updates_component_rule_and_card_art_expected() -> void:
	_select_catalog_key(FleetCatalog.COMPONENT_UPGRADE, "redemption")

	assert_true(_scene._component_rules_text.text.contains("additional engineering point"),
		"Selecting Redemption should show its title card text")
	assert_not_null(_scene._card_art_rect.texture,
		"Selecting Redemption should load its card art")
	assert_almost_eq(_scene._card_art_rect.anchor_left, 0.05, 0.001,
		"Card art should leave a 5 percent left margin")
	assert_almost_eq(_scene._card_art_rect.anchor_right, 0.95, 0.001,
		"Card art should leave a 5 percent right margin")


func test_roster_upgrade_selection_updates_component_rule_expected() -> void:
	_select_catalog_key(FleetCatalog.COMPONENT_SHIP, "nebulon_b_support_refit")
	_scene._on_add_component_pressed()
	_select_catalog_key(FleetCatalog.COMPONENT_UPGRADE, "redemption")
	_scene._on_add_component_pressed()

	_scene._upgrade_list.select(0)
	_scene._on_upgrade_selected(0)

	assert_true(_scene._component_rules_text.text.contains("Redemption"),
		"Roster upgrade selection should update selected component rules")
	assert_not_null(_scene._card_art_rect.texture,
		"Roster upgrade selection should update selected component card art")


func test_roster_squadron_selection_updates_component_rule_expected() -> void:
	_select_catalog_key(FleetCatalog.COMPONENT_SQUADRON, "x_wing_luke_skywalker")
	_scene._on_add_component_pressed()

	_scene._squadron_list.select(0)
	_scene._on_squadron_selected(0)

	assert_true(_scene._component_rules_text.text.contains("no shields"),
		"Roster squadron selection should show named squadron card text")
	assert_not_null(_scene._card_art_rect.texture,
		"Roster squadron selection should update selected component card art")


func test_roster_click_after_catalog_selection_clears_catalog_expected() -> void:
	_add_roster_ship_and_squadron()
	_select_catalog_key(FleetCatalog.COMPONENT_UPGRADE, "redemption")
	assert_true(_scene._component_rules_text.text.contains("Redemption"),
		"Arrange should leave Redemption active in the catalog")

	_scene._squadron_list.select(0)
	_scene._on_squadron_item_clicked(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)

	assert_eq(str(_scene._selected_component_entry.get("data_key", "")), "x_wing_squadron",
		"Clicking a roster squadron should make it the active component")
	assert_true(_scene._catalog_list.get_selected_items().is_empty(),
		"Catalog selection should clear when roster component is activated")
	assert_true(_scene._component_rules_text.text.contains("Bomber"),
		"Roster squadron click should refresh selected component rules")


func test_roster_ship_click_after_catalog_selection_updates_art_expected() -> void:
	_add_roster_ship_and_squadron()
	_select_catalog_key(FleetCatalog.COMPONENT_UPGRADE, "redemption")

	_scene._ship_list.select(0)
	_scene._on_ship_item_clicked(0, Vector2.ZERO, MOUSE_BUTTON_LEFT)

	assert_eq(str(_scene._selected_component_entry.get("data_key", "")),
		"nebulon_b_support_refit", "Clicking a roster ship should make it active")
	assert_true(_scene._catalog_list.get_selected_items().is_empty(),
		"Catalog selection should clear when roster ship is activated")
	assert_not_null(_scene._card_art_rect.texture,
		"Roster ship click should refresh selected component card art")


func test_main_menu_includes_fleet_builder_button_expected() -> void:
	var menu: Control = MainMenuScript.new()
	add_child(menu)

	assert_not_null(_find_button(menu, "Fleet Builder"),
		"Main menu should expose the Fleet Builder entry")

	_free_node(menu)


func _select_catalog_key(component_type: String, data_key: String) -> void:
	_select_catalog_type(component_type)
	for index: int in range(_scene._catalog_list.item_count):
		var entry: Dictionary = _scene._catalog_list.get_item_metadata(index) as Dictionary
		if str(entry.get("data_key", "")) == data_key:
			_scene._catalog_list.select(index)
			_scene._on_catalog_item_selected(index)
			return
	fail_test("Catalog key not found: %s" % data_key)


func _select_catalog_type(component_type: String) -> void:
	for index: int in range(_scene._catalog_type_option.item_count):
		if str(_scene._catalog_type_option.get_item_metadata(index)) == component_type:
			_scene._catalog_type_option.select(index)
			_scene._on_catalog_filter_selected(index)
			return
	fail_test("Catalog type not found: %s" % component_type)


func _select_upgrade_type(upgrade_type: String) -> void:
	for index: int in range(_scene._catalog_upgrade_type_option.item_count):
		if str(_scene._catalog_upgrade_type_option.get_item_metadata(index)) == upgrade_type:
			_scene._catalog_upgrade_type_option.select(index)
			_scene._on_upgrade_type_filter_selected(index)
			return
	fail_test("Upgrade type not found: %s" % upgrade_type)


func _select_objective_key(category: String, data_key: String) -> void:
	var option: OptionButton = _scene._objective_options.get(category, null)
	assert_not_null(option, "Objective option should exist for %s" % category)
	for index: int in range(option.item_count):
		if str(option.get_item_metadata(index)) == data_key:
			option.select(index)
			_scene._on_objective_selected(index, category)
			return
	fail_test("Objective key not found: %s" % data_key)


func _select_point_limit(point_limit: int) -> void:
	for index: int in range(_scene._format_option.item_count):
		var format: Dictionary = _scene._format_option.get_item_metadata(index) as Dictionary
		if int(format.get("limit", 0)) == point_limit:
			_scene._format_option.select(index)
			_scene._on_format_selected(index)
			return
	fail_test("Point limit not found: %d" % point_limit)


func _map_options_all_match_grid(grid: String) -> bool:
	for index: int in range(_scene._map_option.item_count):
		var payload: Dictionary = _scene._map_option.get_item_metadata(index) as Dictionary
		if str(payload.get("grid", "")) != grid:
			return false
	return true


func _select_rule_key(data_key: String) -> void:
	for index: int in range(_scene._rules_list.item_count):
		var rule: RuleReferenceData = _scene._rules_list.get_item_metadata(index) as RuleReferenceData
		if rule != null and rule.data_key == data_key:
			_scene._rules_list.select(index)
			_scene._on_rules_item_selected(index)
			return
	fail_test("Rule key not found: %s" % data_key)


func _add_roster_ship_and_squadron() -> void:
	_select_catalog_key(FleetCatalog.COMPONENT_SHIP, "nebulon_b_support_refit")
	_scene._on_add_component_pressed()
	_select_catalog_key(FleetCatalog.COMPONENT_SQUADRON, "x_wing_squadron")
	_scene._on_add_component_pressed()


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


func _find_button(root: Node, label_text: String) -> Button:
	for child: Node in root.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button != null and button.text == label_text:
			return button
	return null


func _find_sibling_button(control: Control, label_text: String) -> Button:
	if control == null:
		return null
	var parent: Node = control.get_parent()
	if parent == null:
		return null
	for child: Node in parent.get_children():
		var button: Button = child as Button
		if button != null and button.text == label_text:
			return button
	return null


func _free_node(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
